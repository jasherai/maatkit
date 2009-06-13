#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

require '../mk-visual-explain';

sub run {
   my $output;
   open OUTPUT, '>', \$output
      or BAIL_OUT('Cannot open output to variable');
   select OUTPUT;
   mk_visual_explain::main(@_);
   select STDOUT;
   close $output;
   return $output;
}

like(
   run('samples/simple_union.sql'),
   qr/\+\- UNION/,
   'Read optional input file (issue 394)',
);

like(
   run(qw(samples/simple_union.sql --format dump)),
   qr/\$VAR1 = {/,
   '--format dump (issue 393)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
