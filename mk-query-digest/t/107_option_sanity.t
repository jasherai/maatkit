#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

# #############################################################################
# Test cmd line op sanity.
# #############################################################################
my $output = `../mk-query-digest --review h=127.1,P=12345,u=msandbox,p=msandbox`;
like($output, qr/--review DSN requires a D/, 'Dies if no D part in --review DSN');

$output = `../mk-query-digest --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test`;
like($output, qr/--review DSN requires a D/, 'Dies if no t part in --review DSN');


# #############################################################################
# Done.
# #############################################################################
exit;
