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
require "$trunk/mk-parallel-dump/mk-parallel-dump";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 2;
}

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-parallel-dump/mk-parallel-dump -F $cnf ";
my $mysql = $sb->_use_for('master');

$sb->create_dbs($dbh, ['test']);

my $output;
my $basedir = '/tmp/dump/';
diag(`rm -rf $basedir`);

my @tbls;

# ##########################################################################
# Issue 31: Make mk-parallel-dump and mk-parallel-restore do biggest-first
############################################################################
$sb->load_file('master', 'mk-parallel-dump/t/samples/issue_31.sql');

# Tables in order of size: t4 t1 t3 t2

$output = `$cmd --base-dir $basedir -d issue_31 --dry-run --threads 1 2>&1 | grep SELECT`;
@tbls = grep { $_ !~ m/^$/ } split(/\n/, $output);
is_deeply(
   \@tbls,
   [
      "SELECT /*chunk 0*/ `t` FROM `issue_31`.`t4` WHERE  1=1;",
      "SELECT /*chunk 0*/ `t` FROM `issue_31`.`t1` WHERE  1=1;",
      "SELECT /*chunk 0*/ `t` FROM `issue_31`.`t3` WHERE  1=1;",
      "SELECT /*chunk 0*/ `t` FROM `issue_31`.`t2` WHERE  1=1;",
   ],
   'Dumps largest tables first'
);

$output = `$cmd --base-dir $basedir -d issue_31 --tab --dry-run --threads 1 2>&1 | grep SELECT`;
is(
   $output,
"SELECT `t` INTO OUTFILE '/tmp/dump/issue_31/t4.000000.txt' FROM `issue_31`.`t4` WHERE 1=1;
SELECT `t` INTO OUTFILE '/tmp/dump/issue_31/t1.000000.txt' FROM `issue_31`.`t1` WHERE 1=1;
SELECT `t` INTO OUTFILE '/tmp/dump/issue_31/t3.000000.txt' FROM `issue_31`.`t3` WHERE 1=1;
SELECT `t` INTO OUTFILE '/tmp/dump/issue_31/t2.000000.txt' FROM `issue_31`.`t2` WHERE 1=1;
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
