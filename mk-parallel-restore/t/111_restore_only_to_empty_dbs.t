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

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 4;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Issue 300: restore only to empty databases
# #############################################################################

`$cmd --create-databases samples/issue_625`;

$dbh->do('truncate table issue_625.t');
$output = `$cmd --only-empty-databases samples/issue_625`;

is_deeply(
   $dbh->selectall_arrayref('select * from issue_625.t'),
   [],
   'Did not restore non-empty database (issue 300)',
);
like(
   $output,
   qr/database issue_625 is not empty/,
   'Says file was skipped because database is not empty (issue 300)'
);
like(
   $output,
   qr/0\s+files/,
   'Zero files restored (issue 300)'
);

$dbh->do('drop database if exists issue_625');
$output = `$cmd --create-databases --only-empty-databases samples/issue_625`;

is_deeply(
   $dbh->selectall_arrayref('select * from issue_625.t'),
   [[1],[2],[3]],
   '--create-databases --only-empty-databases (issue 300)',
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;