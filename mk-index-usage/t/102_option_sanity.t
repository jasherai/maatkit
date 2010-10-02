#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-index-usage/mk-index-usage";
my $output;

$output = `$cmd --save-results-database h=127.1,P=12345 2>&1`;
like(
   $output,
   qr/specify a D/,
   "--save-results-database requires D part"
);

# #############################################################################
# Done.
# #############################################################################
exit;
