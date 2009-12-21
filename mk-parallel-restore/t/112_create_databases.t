#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

my $slave_dbh = $sb->get_dbh_for('slave1');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Canot connect to sandbox slave';
}
else {
   plan tests => 3;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Test that --create-databases won't replicate with --no-bin-log.
# #############################################################################
$dbh->do('DROP DATABASE IF EXISTS issue_625');

is_deeply(
   $slave_dbh->selectall_arrayref("show databases like 'issue_625'"),
   [],
   "Database doesn't exist on slave"
);

my $master_pos = $dbh->selectall_arrayref('SHOW MASTER STATUS')->[0]->[1];

`$cmd samples/issue_625 --create-databases --no-bin-log`;

is_deeply(
   $slave_dbh->selectall_arrayref("show databases like 'issue_625'"),
   [],
   "Database still doesn't exist on slave"
);
is(
   $dbh->selectall_arrayref('SHOW MASTER STATUS')->[0]->[1],
   $master_pos,
   "Bin log pos unchanged ($master_pos)"
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
