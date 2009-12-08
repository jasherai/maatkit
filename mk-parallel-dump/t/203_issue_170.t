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
# Issue 170: mk-parallel-dump dies when table-status Data_length is NULL
# #############################################################################
diag(`rm -rf $basedir`);
diag(`cp samples/broken_tbl.frm /tmp/12345/data/test/broken_tbl.frm`);
$output = `$cmd --base-dir $basedir -d test 2>&1`;
like(
   $output,
   qr/all\s+\S+\s+1\s+0\s+\-/,
   'Runs but does not die on broken table'
);
diag(`rm -rf /tmp/12345/data/test/broken_tbl.frm`);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
