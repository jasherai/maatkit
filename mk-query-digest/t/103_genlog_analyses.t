#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use MaatkitTest;

# #############################################################################
# Issue 172: Make mk-query-digest able to read general logs
# #############################################################################
my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format header,query_report,profile --type genlog $trunk/common/t/samples";

like(
   `$run_with/genlog001.txt --help`,
   qr/--order-by\s+Query_time:cnt/,
   '--order-by defaults to Query_time:cnt for --type genlog',
);

ok(
   no_diff("$run_with/genlog001.txt", "mk-query-digest/t/samples/genlog001.txt"),
   'Analysis for genlog001',
);

# #############################################################################
# Done.
# #############################################################################
exit;
