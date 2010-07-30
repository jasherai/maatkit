#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-parallel-restore/mk-parallel-restore";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh       = $sb->get_dbh_for('master');
my $slave_dbh = $sb->get_dbh_for('slave1');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Canot connect to sandbox slave';
}
else {
   plan tests => 4;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);
$sb->load_file('master', 'mk-parallel-restore/t/samples/issue_506.sql');

# #############################################################################
# Issue 506: mk-parallel-restore might cause a slave error when checking if
# table exists
# #############################################################################

`$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d issue_506 --chunk-size 5`;
$dbh->do('TRUNCATE TABLE issue_506.t');
sleep 1;
$slave_dbh->do('DROP TABLE issue_506.t');

is_deeply(
   $slave_dbh->selectall_arrayref('show tables from issue_506'),
   [],
   'Table does not exist on slave (issue 506)'
);

is(
   $slave_dbh->selectrow_hashref('show slave status')->{last_error},
   '',
   'No slave error before restore (issue 506)'
);

`$cmd $basedir/issue_506`;

is(
   $slave_dbh->selectrow_hashref('show slave status')->{last_error},
   '',
   'No slave error after restore (issue 506)'
);

$slave_dbh->do('stop slave');
$slave_dbh->do('set global SQL_SLAVE_SKIP_COUNTER=1');
$slave_dbh->do('start slave');

is_deeply(
   $slave_dbh->selectrow_hashref('show slave status')->{last_error},
   '',
   'No slave error (issue 506)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
