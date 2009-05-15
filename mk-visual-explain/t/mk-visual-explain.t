#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

my $output = `../mk-visual-explain samples/simple_union.sql`;
like(
   $output,
   qr/\+\- UNION/,
   'Read optional input file (issue 394)',
);

exit;
