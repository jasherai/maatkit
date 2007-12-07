#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('no_match_vars);
use Test::More tests => 3;

my $output;

$output = `echo "select * from sakila.film" | perl ../mk-query-profiler`;
like(
   $output,
   qr{Questions\s+1},
   'It lives with input on STDIN',
);

$output = `perl ../mk-query-profiler -vvv -i sample.sql`;
like(
   $output,
   qr{Temp files\s+0},
   'It lives with verbosity, InnoDB, and a file input',
);

like(
   $output,
   qr{Handler _+ InnoDB},
   'I found InnoDB stats',
);
