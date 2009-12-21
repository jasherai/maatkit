#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Issue 31: Make mk-parallel-dump and mk-parallel-restore do biggest-first
# #############################################################################

# Tables in order of size: t4 t1 t3 t2

$output = `$cmd samples/issue_31 --create-databases --dry-run --threads 1 2>&1 | grep 'Dumping data for table'`;
is(
   $output,
"-- Dumping data for table `t4`
-- Dumping data for table `t1`
-- Dumping data for table `t3`
-- Dumping data for table `t2`
",
   "Restores largest tables first by default (issue 31)"
);

# Do it again with > 1 arg to test that it does NOT restore largest first.
# It should restore the tables in the given order.
$output = `$cmd --create-databases --dry-run --threads 1 samples/issue_31/issue_31/t1.000000.sql samples/issue_31/issue_31/t2.000000.sql samples/issue_31/issue_31/t3.000000.sql samples/issue_31/issue_31/t4.000000.sql 2>&1 | grep 'Dumping data for table'`;
is(
   $output,
"-- Dumping data for table `t1`
-- Dumping data for table `t2`
-- Dumping data for table `t3`
-- Dumping data for table `t4`
",
   "Restores tables in given order (issue 31)"
);

# And yet again, but this time test that a given order of tables is
# ignored if --biggest-first is explicitly given
$output = `$cmd --biggest-first --create-databases --dry-run --threads 1 samples/issue_31/issue_31/t1.000000.sql samples/issue_31/issue_31/t2.000000.sql samples/issue_31/issue_31/t3.000000.sql samples/issue_31/issue_31/t4.000000.sql 2>&1 | grep 'Dumping data for table'`;
is(
   $output,
"-- Dumping data for table `t4`
-- Dumping data for table `t1`
-- Dumping data for table `t3`
-- Dumping data for table `t2`
",
   "Given order overriden by explicit --biggest-first (issue 31)"
);

# #############################################################################
# Done.
# #############################################################################
exit;
