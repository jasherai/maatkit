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

my $vp  = new VersionParser();
my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

my $output;
my $cnf='/tmp/12345/my.sandbox.cnf';
my @args = ('-F', $cnf, 'h=127.1', qw(--explain --replicate test.checksums));

$sb->create_dbs($dbh, [qw(test)]);

# Add a replication filter to the slave.
diag(`/tmp/12346/stop >/dev/null`);
diag(`cp /tmp/12346/my.sandbox.cnf /tmp/12346/orig.cnf`);
diag(`echo "replicate-ignore-db=foo" >> /tmp/12346/my.sandbox.cnf`);
diag(`/tmp/12346/start >/dev/null`);

$output = output(
   sub { mk_table_checksum::main(@args, '--create-replicate-table') },
   undef,
   stderr => 1,
);
unlike(
   $output,
   qr/mysql\s+user/,
   "Did not checksum with replication filter"
);

like(
   $output,
   qr/replication filters are set/,
   "Warns about replication fitlers"
);

# Remove the replication filter from the slave.
diag(`/tmp/12346/stop >/dev/null`);
diag(`mv /tmp/12346/orig.cnf /tmp/12346/my.sandbox.cnf`);
diag(`/tmp/12346/start >/dev/null`);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
