#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;
shift @INC;  # These two shifts are required for tools that use base and
shift @INC;  # derived classes.  See mk-query-digest/t/101_slowlog_analyses.t
require "$trunk/mk-query-advisor/mk-query-advisor";

my @args = qw(--print-all --report-format full);

ok(
   no_diff(sub { mk_query_advisor::main(@args,
         qw(--ignore-rules COL.001),
         '--query', 'SELECT * FROM tbl WHERE id=1') },
      'mk-query-advisor/t/samples/tbl-001-01-ignored.txt',
   ),
   'Ignore a rule'
);

# #############################################################################
# Done.
# #############################################################################
exit;
