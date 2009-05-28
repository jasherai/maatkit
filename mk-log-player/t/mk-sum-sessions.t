#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

my $output = `../mk-sum-sessions --help`;
like(
   $output,
   qr/--csv/,
   'It runs'
);

exit;
