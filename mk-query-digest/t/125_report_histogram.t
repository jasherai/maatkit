#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift
require "$trunk/mk-query-digest/mk-query-digest";

my @args   = ('--report-format', 'query_report,profile', qw(--limit 10));
my $sample = "$trunk/common/t/samples/";

ok(
   no_diff(
      sub { mk_query_digest::main(@args, qw(--report-histogram Lock_time),
         qw(--order-by Lock_time:sum), $sample.'slow034.txt') },
      "mk-query-digest/t/samples/slow034-order-by-Locktime-sum-with-Locktime-distro.txt",
   ),
   '--report-histogram Lock_time'
);

# #############################################################################
# Done.
# #############################################################################
exit;
