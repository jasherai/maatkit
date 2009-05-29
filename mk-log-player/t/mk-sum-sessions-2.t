#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

my $output = `../mk-sum-sessions-2 --help`;
like(
   $output,
   qr/--csv/,
   'It runs'
);

$output = `../mk-sum-sessions-2 samples/new_results.csv | diff samples/sum_new_results.txt -`;
is(
   $output,
   '',
   'Sum results'
);

exit;
