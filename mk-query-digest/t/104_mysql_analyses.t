#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../../common/MaatkitTest.pm';

MaatkitTest->import(qw(no_diff));

my $run_with = '../mk-query-digest --report-format=query_report --limit 10 ../../common/t/samples/';

ok(
   no_diff($run_with . 'tcpdump003.txt --type tcpdump',
      'samples/tcpdump003.txt'),
   'Analysis for tcpdump003 with numeric Error_no'
);

# #############################################################################
# Issue 228: parse tcpdump.
# #############################################################################
{ # Isolate $run_with locally
   my $run_with = 'perl ../mk-query-digest --report-format=query_report --limit 100 '
      . '--type tcpdump ../../common/t/samples';
   ok(
      no_diff("$run_with/tcpdump002.txt", 'samples/tcpdump002_report.txt'),
      'Analysis for tcpdump002',
   );
}

# #############################################################################
# Issue 398: Fix mk-query-digest to handle timestamps that have microseconds
# #############################################################################
ok(
   no_diff('../mk-query-digest ../../common/t/samples/tcpdump017.txt --type tcpdump --report-format header,query_report,profile',
      'samples/tcpdump017_report.txt'),
   'Analysis for tcpdump017 with microsecond timestamps (issue 398)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
