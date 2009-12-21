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
   plan tests => 1;
}

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $mysql   = $sb->_use_for('master');
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
#  Issue 624: mk-parallel-dump --databases does not filter restored databases
# #############################################################################
$dbh->do('DROP DATABASE IF EXISTS issue_624');
$dbh->do('CREATE DATABASE issue_624');
$dbh->do('USE issue_624');

$output = `$cmd samples/issue_624/ -D issue_624 -d d2`;

is_deeply(
   $dbh->selectall_arrayref('SELECT * FROM issue_624.t2'),
   [ [4],[5],[6] ],
   '--databases filters restored dbs (issue 624)'
);


# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
