#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

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
# Issue 223: mk-parallel-dump includes trig definitions into each chunk file
# #############################################################################

# Triggers are no longer dumped, but we'll keep part of this test to make
# sure triggers really aren't dumped.

$sb->load_file('master', 'samples/issue_223.sql');
diag(`rm -rf $basedir`);

# Dump table t1 and make sure its trig def is not in any chunk.
diag(`MKDEBUG=1 $cmd --base-dir $basedir --chunk-size 30 -d test 1>/dev/null 2>/dev/null`);
is(
   `cat $basedir/test/t1.000000.sql | grep TRIGGER`,
   '',
   'No trigger def in chunk 0 (issue 223)'
);
is(
   `cat $basedir/test/t1.000001.sql | grep TRIGGER`,
   '',
   'No trigger def in chunk 1 (issue 223)'
);
ok(
   !-f '$basedir/test/t1.000000.trg',
   'No triggers dumped'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
