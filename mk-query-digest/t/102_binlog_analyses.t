#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use constant MKDEBUG => $ENV{MKDEBUG};

require '../../common/MaatkitTest.pm';

MaatkitTest->import(qw(no_diff));

# #############################################################################
# Issue 476: parse binary logs.
# #############################################################################
{ # Isolate $run_with locally
   # We want the profile report so we can check that queries like
   # CREATE DATABASE are distilled correctly.
   my $run_with = 'perl ../mk-query-digest --report-format header,query_report,profile --type binlog ../../common/t/samples';

   ok(
      no_diff("$run_with/binlog001.txt", 'samples/binlog001.txt'),
      'Analysis for binlog001',
   );

   ok(
      no_diff("$run_with/binlog002.txt", 'samples/binlog002.txt'),
      'Analysis for binlog002',
   );
}

# #############################################################################
# Done.
# #############################################################################
exit;
