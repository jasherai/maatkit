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

# #############################################################################
# Issue 565: mk-query-digest isn't compiling filter correctly
# #############################################################################
my $output = `$trunk/mk-query-digest/mk-query-digest --type tcpdump --filter '\$event->{No_index_used} || \$event->{No_good_index_used}' --group-by tables  $trunk/common/t/samples/tcpdump014.txt 2>&1`;
unlike(
   $output,
   qr/Can't use string/,
   '--filter compiles correctly (issue 565)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
