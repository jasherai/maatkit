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
# Issue 462: Filter out all but first N of each
# #############################################################################
ok(
   no_diff("$trunk/mk-query-digest/mk-query-digest $trunk/common/t/samples/slow006.txt "
      . '--no-report --print --sample 2',
      "mk-query-digest/t/samples/slow006-first2.txt"),
   'Print only first N unique occurrences with explicit --group-by',
);

# #############################################################################
# Issue 470: mk-query-digest --sample does not work with --report ''
# #############################################################################
ok(
   no_diff("$trunk/mk-query-digest/mk-query-digest $trunk/common/t/samples/slow006.txt "
      . '--no-report --print --sample 2',
      "mk-query-digest/t/samples/slow006-first2.txt"),
   'Print only first N unique occurrences, --no-report',
);

# #############################################################################
# Done.
# #############################################################################
exit;
