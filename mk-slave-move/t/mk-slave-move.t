#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Test::More tests => 1;

my $output = `perl ../mk-slave-move --help`;
like($output, qr/Prompt for a password/, 'It compiles');
