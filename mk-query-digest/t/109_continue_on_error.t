#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

my $output;

# Test --continue-on-error.
$output = `../mk-query-digest --no-continue-on-error --type tcpdump samples/bad_tcpdump.txt 2>&1`;
unlike(
   $output,
   qr/Query 1/,
   'Does not continue on error with --no-continue-on-error'
);
$output = `../mk-query-digest --type tcpdump samples/bad_tcpdump.txt 2>&1`;
like(
   $output,
   qr/paris in the the spring/,
   'Continues on error by default'
);


# #############################################################################
# Done.
# #############################################################################
exit;
