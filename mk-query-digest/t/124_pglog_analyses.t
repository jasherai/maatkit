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

# See 101_slowlog_analyses.t or http://code.google.com/p/maatkit/wiki/Testing
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift

require "$trunk/mk-query-digest/mk-query-digest";

# #############################################################################
# Issue 535: Make mk-query-digest able to read PostgreSQL logs
# #############################################################################

my @args   = qw(--report-format profile --type pglog);
my $sample = "$trunk/common/t/samples/";

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'pg-sample1') },
      "mk-query-digest/t/samples/pg-sample1"
   ),
   'Analysis for pg-sample1',
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'pg-syslog-sample1') },
      "mk-query-digest/t/samples/pg-syslog-sample1"
   ),
   'Analysis for pg-syslog-sample1',
);

# #############################################################################
# Done.
# #############################################################################
exit;
