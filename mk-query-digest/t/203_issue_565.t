#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

# #############################################################################
# Issue 565: mk-query-digest isn't compiling filter correctly
# #############################################################################
my $output = `../mk-query-digest --type tcpdump --filter '\$event->{No_index_used} || \$event->{No_good_index_used}' --group-by tables  ../../common/t/samples/tcpdump014.txt 2>&1`;
unlike(
   $output,
   qr/Can't use string/,
   '--filter compiles correctly (issue 565)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
