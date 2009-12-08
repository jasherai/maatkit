#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

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

# ##########################################################################
# Issue 31: Make mk-parallel-dump and mk-parallel-restore do biggest-first
############################################################################
$sb->load_file('master', 'samples/issue_31.sql');
# Tables in order of size: t4 t1 t3 t2

$output = `$cmd --base-dir $basedir -d issue_31 --dry-run --threads 1 2>&1 | grep 'result\-file'`;
# There will be several lines like:
# mysqldump '--defaults-file='/tmp/12345/my.sandbox.cnf'' --skip-lock-all-tables --skip-lock-tables --add-drop-table --add-locks --allow-keywords --comments --complete-insert --create-options --disable-keys --extended-insert --quick --quote-names --set-charset --skip-triggers --tz-utc issue_31 t4 --result-file '/tmp/dump/issue_31/t4.000000.sql'
# These vary from system to system due to varying mysqldump.  All we really
# need is the last arg: the table name.
@tbls = map {
   my @args = split(/\s+/, $_);
   $args[-1];
} split(/\n/, $output);

is_deeply(
   \@tbls,
   [
      "/tmp/dump/'issue_31'/'t4.000000.sql'",
      "/tmp/dump/'issue_31'/'t1.000000.sql'",
      "/tmp/dump/'issue_31'/'t3.000000.sql'",
      "/tmp/dump/'issue_31'/'t2.000000.sql'",
   ],
   'Dumps largest tables first'
);

$output = `$cmd --base-dir $basedir -d issue_31 --tab --dry-run --threads 1 2>&1 | grep SELECT`;
is(
   $output,
"SELECT * INTO OUTFILE '/tmp/dump/issue_31/t4.000000.txt' FROM `issue_31`.`t4` WHERE 1=1
SELECT * INTO OUTFILE '/tmp/dump/issue_31/t1.000000.txt' FROM `issue_31`.`t1` WHERE 1=1
SELECT * INTO OUTFILE '/tmp/dump/issue_31/t3.000000.txt' FROM `issue_31`.`t3` WHERE 1=1
SELECT * INTO OUTFILE '/tmp/dump/issue_31/t2.000000.txt' FROM `issue_31`.`t2` WHERE 1=1
",
   'Dumps largest tables first with --tab'
);

diag(`rm -rf $basedir`);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $basedir`);
$sb->wipe_clean($dbh);
exit;
