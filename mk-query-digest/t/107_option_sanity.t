#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use MaatkitTest;

# #############################################################################
# Test cmd line op sanity.
# #############################################################################
my $output = `$trunk/mk-query-digest/mk-query-digest --review h=127.1,P=12345,u=msandbox,p=msandbox`;
like($output, qr/--review DSN requires a D/, 'Dies if no D part in --review DSN');

$output = `$trunk/mk-query-digest/mk-query-digest --review h=127.1,P=12345,u=msandbox,p=msandbox,D=test`;
like($output, qr/--review DSN requires a D/, 'Dies if no t part in --review DSN');


# #############################################################################
# Done.
# #############################################################################
exit;
