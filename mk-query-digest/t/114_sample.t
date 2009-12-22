#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

require '../../common/MaatkitTest.pm';

MaatkitTest->import(qw(no_diff));

# #############################################################################
# Issue 462: Filter out all but first N of each
# #############################################################################
ok(
   no_diff('../mk-query-digest ../../common/t/samples/slow006.txt '
      . '--no-report --print --sample 2',
      'samples/slow006-first2.txt'),
   'Print only first N unique occurrences with explicit --group-by',
);

# #############################################################################
# Issue 470: mk-query-digest --sample does not work with --report ''
# #############################################################################
ok(
   no_diff('../mk-query-digest ../../common/t/samples/slow006.txt '
      . '--no-report --print --sample 2',
      'samples/slow006-first2.txt'),
   'Print only first N unique occurrences, --no-report',
);

# #############################################################################
# Done.
# #############################################################################
exit;
