#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use Test::More tests => 6;

my ($output, $output2);

$output = `perl ../mk-checksum-filter sample_1`;
chomp $output;
is($output, '', 'No output from single file');
is($CHILD_ERROR >> 8, 0, 'Exit status is 0');

$output = `perl ../mk-checksum-filter sample_1 --equaldbs sakila,sakila2`;
chomp $output;
like($output, qr/sakila2.*actor/, 'sakila2.actor is different with --equaldbs');
is($CHILD_ERROR >> 8, 1, 'Exit status is 1');

$output = `perl ../mk-checksum-filter sample_1 -i`;
chomp $output;
like($output, qr/sakila2.*actor/, 'sakila2.actor is different with --ignoredb');
is($CHILD_ERROR >> 8, 1, 'Exit status is 1');
