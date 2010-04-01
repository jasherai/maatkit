#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use MaatkitTest;

# See 101_slowlog_analyses.t or http://code.google.com/p/maatkit/wiki/Testing
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift

require "$trunk/mk-query-digest/mk-query-digest";

# #############################################################################
# Issue 172: Make mk-query-digest able to read general logs
# #############################################################################

my @args   = ('--report-format', 'header,query_report,profile', '--type', 'genlog');
my $sample = "$trunk/common/t/samples/genlogs/";

# --help exists so don't run mqd as a module else --help's exit will
# exit this test script.
like(
   `$trunk/mk-query-digest/mk-query-digest --type genlog genlog001.txt --help`,
   qr/--order-by\s+Query_time:cnt/,
   '--order-by defaults to Query_time:cnt for --type genlog',
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'genlog001.txt') },
      "mk-query-digest/t/samples/genlog001.txt"
   ),
   'Analysis for genlog001',
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'genlog002.txt') },
      "mk-query-digest/t/samples/genlog002.txt",
   ),
   'Analysis for genlog002',
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'genlog003.txt') },
      "mk-query-digest/t/samples/genlog003.txt"
   ),
   'Analysis for genlog003',
);

# #############################################################################
# Done.
# #############################################################################
exit;
