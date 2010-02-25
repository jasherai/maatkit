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

my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format=query_report --type http --limit 10 $trunk/common/t/samples/";

ok(
   no_diff($run_with.'http_tcpdump002.txt', "mk-query-digest/t/samples/http_tcpdump002.txt"),
   'Analysis for http_tcpdump002.txt'
);

# #############################################################################
# Done.
# #############################################################################
exit;
