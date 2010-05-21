#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift
require "$trunk/mk-query-digest/mk-query-digest";

# #############################################################################
# Issue 736: mk-query-digest doesn't handle badly distilled queries
# #############################################################################

my @args   = qw(--report-format=profile --limit 10);
my $sample = "$trunk/mk-query-digest/t/samples/";

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'cannot-distill.log') },
      "mk-query-digest/t/samples/cannot-distill-profile.txt",
   ),
   'Distill nonsense and non-SQL'
);

# #############################################################################
# Done.
# #############################################################################
exit;
