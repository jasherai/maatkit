#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-table-checksum/mk-table-checksum";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
if ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
else {
   plan tests => 6;
}

my $rows;
my $output;
my $cnf = '/tmp/12345/my.sandbox.cnf';
$sb->create_dbs($master_dbh, [qw(test)]);
$sb->load_file('master', 'mk-table-checksum/t/samples/checksum_tbl.sql');

# #############################################################################
# Issue 982: --empty-replicate-table does not work with binlog-ignore-db
# #############################################################################

$master_dbh->do("insert into test.checksum (db,tbl,chunk) values ('db','tbl',0)");
sleep 1;

$rows = $slave_dbh->selectall_arrayref('select * from test.checksum');
is(
   scalar @$rows,
   1,
   "Slave checksum table has row"
);

# Add a replication filter to the slave.
diag(`/tmp/12346/stop >/dev/null`);
diag(`/tmp/12345/stop >/dev/null`);
diag(`cp /tmp/12345/my.sandbox.cnf /tmp/12345/orig.cnf`);
diag(`echo "binlog-ignore-db=sakila" >> /tmp/12345/my.sandbox.cnf`);
diag(`echo "binlog-ignore-db=mysql"  >> /tmp/12345/my.sandbox.cnf`);
diag(`/tmp/12345/start >/dev/null`);
diag(`/tmp/12346/start >/dev/null`);

$output = output(
   sub { mk_table_checksum::main("F=$cnf", qw(--no-check-replication-filters),
      qw(--replicate=test.checksum -d mysql -t user --empty-replicate-table))
   },
   undef,
   stderr  => 1,
);

$master_dbh = $sb->get_dbh_for('master');
$slave_dbh  = $sb->get_dbh_for('slave1');

$rows = $slave_dbh->selectall_arrayref("select * from test.checksum where db='db'");
ok(
   @$rows == 0,
   "Slave checksum table deleted"
);

# Clear checksum table for next tests.
$master_dbh->do("truncate table test.checksum");
sleep 1;
$rows = $slave_dbh->selectall_arrayref("select * from test.checksum");
ok(
   !@$rows,
   "Checksum table empty on slave"
);

$master_dbh->disconnect();
$slave_dbh->disconnect();

# Restore original config.
diag(`/tmp/12346/stop >/dev/null`);
diag(`/tmp/12345/stop >/dev/null`);
diag(`cp /tmp/12345/orig.cnf /tmp/12345/my.sandbox.cnf`);

# #############################################################################
# Test --replicate-database which resulted from this issue.
# #############################################################################

# Add a binlog-do-db filter so master will only replicate
# statements when USE mysql is in effect.
diag(`echo "binlog-do-db=mysql" >> /tmp/12345/my.sandbox.cnf`);
diag(`/tmp/12345/start >/dev/null`);
diag(`/tmp/12346/start >/dev/null`);

$master_dbh = $sb->get_dbh_for('master');
$slave_dbh  = $sb->get_dbh_for('slave1');

$output = output(
   sub { mk_table_checksum::main("F=$cnf", qw(--no-check-replication-filters),
      qw(--replicate=test.checksum -d mysql -t user))
   },
   undef,
   stderr => 1,
);

# Because we did not use --replicate-database, mk-table-checksum should
# have done USE mysql before updating the checksum table.  Thus, the
# checksums should show up on the slave.
sleep 1;
$rows = $slave_dbh->selectall_arrayref("select * from test.checksum where db='mysql' AND tbl='user'");
ok(
   @$rows == 1,
   "Checksum replicated with binlog-do-db, without --replicate-database"
);

# Now force --replicate-database test and the checksums should not replicate.

$master_dbh->do("use mysql");
$master_dbh->do("truncate table test.checksum");
sleep 1;
$rows = $slave_dbh->selectall_arrayref("select * from test.checksum");
ok(
   !@$rows,
   "Checksum table empty on slave"
);

$output = output(
   sub { mk_table_checksum::main("F=$cnf", qw(--no-check-replication-filters),
      qw(--replicate=test.checksum -d mysql -t user),
      qw(--replicate-database test))
   },
   undef,
   stderr => 1,
);
sleep 1;
$rows = $slave_dbh->selectall_arrayref("select * from test.checksum where db='mysql' AND tbl='user'");
ok(
   !@$rows,
   "Checksum did not replicated with binlog-do-db, with --replicate-database"
);

# #############################################################################
# Done.
# #############################################################################
# Restore original config.
$sb->wipe_clean($master_dbh);
diag(`/tmp/12346/stop >/dev/null`);
diag(`/tmp/12345/stop >/dev/null`);
diag(`mv /tmp/12345/orig.cnf /tmp/12345/my.sandbox.cnf`);
diag(`/tmp/12345/start >/dev/null`);
diag(`/tmp/12346/start >/dev/null`);
exit;
