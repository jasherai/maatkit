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

# This is kind of a contrived test, but it's better than nothing.
$output = `$cmd samples/issue_31 --progress --dry-run`;
like($output, qr/done: [\d\.]+[Mk]\/[\d\.]+[Mk]/, 'Reporting progress by bytes');

# #############################################################################
# Done.
# #############################################################################
exit;
