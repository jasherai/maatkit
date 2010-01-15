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
# Issue 476: parse binary logs.
# #############################################################################
# We want the profile report so we can check that queries like
# CREATE DATABASE are distilled correctly.
my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format header,query_report,profile --type binlog $trunk/common/t/samples";

ok(
   no_diff("$run_with/binlog001.txt", "mk-query-digest/t/samples/binlog001.txt"),
   'Analysis for binlog001',
);

ok(
   no_diff("$run_with/binlog002.txt", "mk-query-digest/t/samples/binlog002.txt"),
   'Analysis for binlog002',
);

# #############################################################################
# Done.
# #############################################################################
exit;
