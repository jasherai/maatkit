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
shift @INC;  # These two shifts are required for tools that use base and
shift @INC;  # derived classes.  See mk-query-digest/t/101_slowlog_analyses.t
require "$trunk/mk-query-advisor/mk-query-advisor";

my $output;
my @args   = ();
my $sample = "$trunk/common/t/samples/";

$output = output(
   sub { mk_query_advisor::main(@args, "$sample/slow018.txt") },
);
like(
   $output,
   qr/COL.002/,
   "Parse slowlog"
);

$output = output(
   sub { mk_query_advisor::main(@args, qw(--type genlog),
      "$sample/genlogs/genlog001.txt") },
);
like(
   $output,
   qr/CLA.005/,
   "Parse genlog"
);

# #############################################################################
# Done.
# #############################################################################
exit;
