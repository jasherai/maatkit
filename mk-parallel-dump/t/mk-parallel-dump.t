#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('no_match_vars);
use Test::More tests => 4;

my $output;

$output = `mysql -e 'show databases'`;
SKIP: {
   skip 'Sakila is not installed', 3 unless $output =~ m/sakila/;

   $output = `perl ../mk-parallel-dump --C 100 --basedir /tmp -T --d sakila --t film`;
   my ($tbl, $chunk) = $output =~ m/default:\s+(\d+) tables,\s+(\d+) chunks,\s+\2 successes/;
   is($tbl, 1, 'One table dumped');
   ok($chunk >= 5 && $chunk <= 15, 'Got some chunks');
   ok(-s '/tmp/default/sakila/film.005.txt.gz', 'chunk 5 exists');
   ok(-s '/tmp/default/00_master_data.sql', 'master_data exists');
   `rm -rf /tmp/default`;
}
