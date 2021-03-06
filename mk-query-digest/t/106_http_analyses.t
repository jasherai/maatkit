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

my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format=query_report --type http --limit 10 $trunk/common/t/samples/";

ok(
   no_diff($run_with.'http_tcpdump002.txt', "mk-query-digest/t/samples/http_tcpdump002.txt"),
   'Analysis for http_tcpdump002.txt'
);

# #############################################################################
# Done.
# #############################################################################
exit;
