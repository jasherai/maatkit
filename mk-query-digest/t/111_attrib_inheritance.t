#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

require '../../common/MaatkitTest.pm';

MaatkitTest->import(qw(no_diff));

my $run_with = '../mk-query-digest --report-format=query_report --limit 10 ../../common/t/samples/';
my $run_notop = '../mk-query-digest --report-format=query_report ../../common/t/samples/';

# #############################################################################
# Issue 479: Make mk-query-digest carry Schema and ts attributes along the
# pipeline
# #############################################################################
ok(
   no_diff($run_with.'slow034.txt --no-report --print', 'samples/slow034-inheritance.txt'),
   'Analysis for slow034 with inheritance'
);

# Make sure we can turn off some default inheritance, 'ts' in this test.
ok(
   no_diff($run_with.'slow034.txt --no-report --print --inherit-attributes db', 'samples/slow034-no-ts-inheritance.txt'),
   'Analysis for slow034 without default ts inheritance'
);

# #############################################################################
# Done.
# #############################################################################
exit;
