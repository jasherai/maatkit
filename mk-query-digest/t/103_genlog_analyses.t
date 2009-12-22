#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../../common/MaatkitTest.pm';

MaatkitTest->import(qw(no_diff));

# #############################################################################
# Issue 172: Make mk-query-digest able to read general logs
# #############################################################################
{ # Isolate $run_with locally
   my $run_with = 'perl ../mk-query-digest --report-format header,query_report,profile --type genlog ../../common/t/samples';

   like(
      `$run_with/genlog001.txt --help`,
      qr/--order-by\s+Query_time:cnt/,
      '--order-by defaults to Query_time:cnt for --type genlog',
   );

   ok(
      no_diff("$run_with/genlog001.txt", 'samples/genlog001.txt'),
      'Analysis for genlog001',
   );
}

# #############################################################################
# Done.
# #############################################################################
exit;
