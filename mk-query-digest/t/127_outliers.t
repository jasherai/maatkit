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
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift
require "$trunk/mk-query-digest/mk-query-digest";

my @args   = qw(--report-format=query_report --limit 10);
my $sample = "$trunk/common/t/samples/";

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow013.txt',
            qw(--group-by user --outliers Query_time:.0000001:1)) },
      "mk-query-digest/t/samples/slow013_report_outliers.txt"
   ),
   'slow013 --outliers'
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'slow049.txt',
            qw(--limit 2 --outliers Query_time:5:3),
            '--report-format', 'header,profile,query_report') },
      "mk-query-digest/t/samples/slow049.txt",
   ),
   'slow049 --outliers'
);

# #############################################################################
# Done.
# #############################################################################
exit;
