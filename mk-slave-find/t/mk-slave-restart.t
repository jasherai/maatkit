#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 1;

my $output = `perl ../mk-slave-find --help`;
like($output, qr/Prompt for a password/, 'It compiles');

$output = `perl ../mk-slave-find -h 127.0.0.1 -P 12345 -u msandbox -p msandbox`;
print $output;
