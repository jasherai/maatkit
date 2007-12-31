#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 1;

my $output = `perl ../mk-slave-prefetch --help`;
like($output, qr/Prompt for password/, 'It compiles');

# TODO: comparatively hard to set up tests for this...
