#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('no_match_vars);
use Test::More tests => 3;

my $output;

$output = `mysql -e 'show databases'`;
SKIP: {
   skip 'Sakila is not installed', 3 unless $output =~ m/sakila/;

   $output = `perl ../mk-parallel-dump --C 100 --basedir /tmp -T --d sakila --t film`;
   like(
      $output,
      qr/default:\s+1 tables,\s+11 chunks,\s+11 successes/,
      'Dumped successfully',
   );
   ok(-s '/tmp/default/sakila/film.010.txt.gz', 'chunk 11 exists');
   ok(-s '/tmp/default/00_master_data.sql', 'master_data exists');
   `rm -rf /tmp/default`;
}
