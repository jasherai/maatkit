#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "perl ../mk-parallel-restore -F $cnf ";
my $basedir = '/tmp/dump/';
my $output;

diag(`rm -rf $basedir`);

# #############################################################################
# Issue 534: mk-parallel-restore --threads is being ignored
# #############################################################################
$output = `$cmd --help --threads 32 2>&1`;
like(
   $output,
   qr/--threads\s+32/,
   '--threads overrides /proc/cpuinfo (issue 534)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
