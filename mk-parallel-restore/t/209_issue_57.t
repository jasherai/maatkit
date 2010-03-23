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
   plan tests => 10;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);
$sb->create_dbs($dbh, ['test']);
`$mysql < $trunk/mk-parallel-restore/t/samples/issue_30.sql`;

# #############################################################################
# Issue 57: mk-parallel-restore with --tab doesn't fully replicate 
# #############################################################################

`$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --tab`;

# By default a --tab restore should not replicate.
diag(`/tmp/12345/use -e 'DROP TABLE IF EXISTS test.issue_30'`);
$slave_dbh->do('USE test');
my $res = $slave_dbh->selectall_arrayref('SHOW TABLES LIKE "issue_30"');
ok(!scalar @$res, 'Slave does not have table before --tab restore');

$res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
my $master_pos = $res->[0]->[1];

`$cmd --tab --replace --local --database test $basedir`;
sleep 1;

$slave_dbh->do('USE test');
$res = $slave_dbh->selectall_arrayref('SHOW TABLES LIKE "issue_30"');
ok(!scalar @$res, 'Slave does not have table after --tab restore');

$res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
is($master_pos, $res->[0]->[1], 'Bin log pos unchanged');

# Test that a --tab --bin-log overrides default behavoir
# and replicates the restore.
diag(`/tmp/12345/use -e 'SET SQL_LOG_BIN=0; DROP TABLE IF EXISTS test.issue_30'`);
`$cmd --bin-log --tab --replace --local --database test $basedir`;
sleep 1;

$slave_dbh->do('USE test');
$res = $slave_dbh->selectall_arrayref('SELECT * FROM test.issue_30');
is(scalar @$res, 100, '--tab with --bin-log allows replication');

# Check that non-tab restores do replicate by default.
`rm -rf $basedir/`;
`$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf --base-dir $basedir -d test -t issue_30 --chunk-size 25`;

diag(`/tmp/12345/use -e 'DROP TABLE IF EXISTS test.issue_30'`);
`$cmd $basedir`;
sleep 1;

$slave_dbh->do('USE test');
$res = $slave_dbh->selectall_arrayref('SELECT * FROM test.issue_30');
is(scalar @$res, 100, 'Non-tab restore replicates by default');

# Make doubly sure that for a restore that defaults to bin-log
# that --no-bin-log truly prevents binary logging/replication.
diag(`/tmp/12345/use -e 'DROP TABLE IF EXISTS test.issue_30'`);
$res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
$master_pos = $res->[0]->[1];

`$cmd --no-bin-log $basedir`;
sleep 1;

$slave_dbh->do('USE test');
$res = $slave_dbh->selectall_arrayref('SHOW TABLES LIKE "issue_30"');
ok(!scalar @$res, 'Non-tab restore does not replicate with --no-bin-log');

$res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
is($master_pos, $res->[0]->[1], 'Bin log pos unchanged');

# Check that triggers are neither restored nor replicated.
`$cmd $trunk/mk-parallel-restore/t/samples/tbls_with_trig/ --no-bin-log`;
sleep 1;

$dbh->do('USE test');
$res = $dbh->selectall_arrayref('SHOW TRIGGERS');
is_deeply($res, [], 'Triggers are not restored');

$slave_dbh->do('USE test');
$res = $slave_dbh->selectall_arrayref('SHOW TRIGGERS');
is_deeply($res, [], 'Triggers are not replicated');

$res = $dbh->selectall_arrayref('SHOW MASTER STATUS');
is($master_pos, $res->[0]->[1], 'Bin log pos unchanged');

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
