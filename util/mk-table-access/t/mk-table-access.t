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
shift @INC;  # our unshift (above)
shift @INC;  # MaatkitTest's unshift

require "$trunk/util/mk-table-access/mk-table-access";

my @args = qw();
my $in   = "$trunk/util/mk-table-access/t/samples/in/";
my $out  = "util/mk-table-access/t/samples/out/";

ok(
   no_diff(
      sub { mk_table_access::main(@args, "$in/slow001.txt") },
      "$out/slow001.txt",
   ),
   'Analysis for slow001.txt'
);

ok(
   no_diff(
      sub { mk_table_access::main(@args, "$in/slow002.txt") },
      "$out/slow002.txt",
   ),
   'Analysis for slow002.txt (issue 1237)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
