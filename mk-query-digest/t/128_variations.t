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

my $in   = "$trunk/common/t/samples/";
my $out  = "mk-query-digest/t/samples/";
my @args = qw(--variations arg --limit 5 --report-format query_report);

# #############################################################################
# Issue 511: Make mk-query-digest report number of query variations
# #############################################################################
ok(
   no_diff(
      sub { mk_query_digest::main(@args, "$in/slow053.txt") },
      "$out/slow053.txt"
   ),
   "Variations in slow053.txt"
);

# #############################################################################
# Done.
# #############################################################################
exit;
