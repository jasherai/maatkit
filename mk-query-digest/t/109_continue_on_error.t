#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use MaatkitTest;

my $output;

# Test --continue-on-error.
$output = `$trunk/mk-query-digest/mk-query-digest --no-continue-on-error --type tcpdump $trunk/mk-query-digest/t/samples/bad_tcpdump.txt 2>&1`;
unlike(
   $output,
   qr/Query 1/,
   'Does not continue on error with --no-continue-on-error'
);

$output = `$trunk/mk-query-digest/mk-query-digest --type tcpdump $trunk/mk-query-digest/t/samples/bad_tcpdump.txt 2>&1`;
like(
   $output,
   qr/paris in the the spring/,
   'Continues on error by default'
);


# #############################################################################
# Done.
# #############################################################################
exit;
