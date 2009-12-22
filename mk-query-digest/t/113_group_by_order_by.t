#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

my $output;

# #############################################################################
# Test that --group-by cascades to --order-by.
# #############################################################################
$output = `../mk-query-digest --group-by foo,bar --help`;
like($output, qr/--order-by\s+Query_time:sum,Query_time:sum/,
   '--group-by cascades to --order-by');


$output = `../mk-query-digest --no-report --help 2>&1`;
like(
   $output,
   qr/--group-by\s+fingerprint/,
   "Default --group-by with --no-report"
);

# #############################################################################
# Done.
# #############################################################################
exit;
