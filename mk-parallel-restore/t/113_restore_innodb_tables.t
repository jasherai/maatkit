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
   plan tests => 2;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Issue 683: mk-parellel-restore innodb table empty 
# #############################################################################
`$cmd --drop-tables --create-databases samples/issue_683`;
is_deeply(
   $dbh->selectall_arrayref('select count(*) from `f4all-LIVE`.`Season`'),
   [[47]],
   'Commit after restore (issue 683)'
);

`$cmd --drop-tables --create-databases --no-resume --no-commit samples/issue_683`;

is_deeply(
   $dbh->selectall_arrayref('select count(*) from `f4all-LIVE`.`Season`'),
   [[0]],
   '--no-commit'
);


# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
