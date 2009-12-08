#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

require '../mk-parallel-dump';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-parallel-dump -F $cnf ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);

my $output;
my $basedir = '/tmp/dump/';
diag(`rm -rf $basedir`);

my @tbls;

# #############################################################################
# Issue 446: mk-parallel-dump cannot make filenames for tables with spaces
# in their names
# #############################################################################
diag(`rm -rf $basedir`);
$dbh->do('USE test');
$dbh->do('CREATE TABLE `issue 446` (i int)');
$dbh->do('INSERT INTO test.`issue 446` VALUES (1),(2),(3)');

`$cmd --base-dir $basedir --ignore-databases sakila --databases test --tables 'issue 446'`;
ok(
   -f "$basedir/test/issue 446.000000.sql",
   'Dumped table with space in name (issue 446)'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
