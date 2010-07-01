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
# Issue 476: parse binary logs.
# #############################################################################
# We want the profile report so we can check that queries like
# CREATE DATABASE are distilled correctly.
my @args   = ('--report-format', 'header,query_report,profile', '--type', 'binlog');
my $sample = "$trunk/common/t/samples/binlogs/";

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'binlog001.txt') },
      "mk-query-digest/t/samples/binlog001.txt"
   ),
   'Analysis for binlog001',
);

ok(
   no_diff(
      sub { mk_query_digest::main(@args, $sample.'binlog002.txt') },
      "mk-query-digest/t/samples/binlog002.txt"
   ),
   'Analysis for binlog002',
);

# #############################################################################
# Done.
# #############################################################################
exit;
