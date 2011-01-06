#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use MaatkitTest;
shift @INC;  # These two shifts are required for tools that use base and
shift @INC;  # derived classes.  See mk-query-digest/t/101_slowlog_analyses.t
require "$trunk/mk-query-advisor/mk-query-advisor";

ok(
   no_diff(
      sub { mk_query_advisor::main(
         qw(--group-by none),
         "$trunk/mk-query-advisor/t/samples/slow001.txt",) },
      "mk-query-advisor/t/samples/group-by-none-001.txt",
   ),
   "group by none"
);

ok(
   no_diff(
      sub { mk_query_advisor::main(
         "$trunk/mk-query-advisor/t/samples/slow001.txt",) },
      "mk-query-advisor/t/samples/group-by-rule-id-001.txt",
   ),
   "group by rule id (default)"
);

ok(
   no_diff(
      sub { mk_query_advisor::main(
         qw(--group-by query_id),
         "$trunk/mk-query-advisor/t/samples/slow001.txt",) },
      "mk-query-advisor/t/samples/group-by-query-id-001.txt",
   ),
   "group by query_id"
);

# #############################################################################
# Done.
# #############################################################################
exit;
