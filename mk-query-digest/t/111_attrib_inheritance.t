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

my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format=query_report --limit 10 $trunk/common/t/samples/";

# #############################################################################
# Issue 479: Make mk-query-digest carry Schema and ts attributes along the
# pipeline
# #############################################################################
ok(
   no_diff($run_with.'slow034.txt --no-report --print', "mk-query-digest/t/samples/slow034-inheritance.txt"),
   'Analysis for slow034 with inheritance'
);

# Make sure we can turn off some default inheritance, 'ts' in this test.
ok(
   no_diff($run_with.'slow034.txt --no-report --print --inherit-attributes db', "mk-query-digest/t/samples/slow034-no-ts-inheritance.txt"),
   'Analysis for slow034 without default ts inheritance'
);

# #############################################################################
# Done.
# #############################################################################
exit;
