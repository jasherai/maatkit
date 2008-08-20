#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 2;

my $output = `perl ../mk-slave-prefetch --help`;
like($output, qr/Prompt for a password/, 'It compiles');

# Cannot daemonize and debug
$output = `MKDEBUG=1 ../mk-slave-prefetch --daemonize 2>&1`;
like($output, qr/Cannot debug while daemonized/, 'Cannot debug while daemonized');

# TODO: comparatively hard to set up tests for this...

exit;
