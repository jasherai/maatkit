#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 3;

my ($output, $output2);

$output = `perl ../mk-checksum-filter sample_1`;
chomp $output;
is($output, '', 'No output from single file');

$output = `perl ../mk-checksum-filter sample_1 --equaldbs sakila,sakila2`;
chomp $output;
like($output, qr/sakila2.*actor/, 'sakila2.actor is different with --equaldbs');

$output = `perl ../mk-checksum-filter sample_1 -i`;
chomp $output;
like($output, qr/sakila2.*actor/, 'sakila2.actor is different with --ignoredb');
