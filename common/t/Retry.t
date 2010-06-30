#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.
com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";

};

use strict;
use warnings FATAL => 'all';
use English qw( -no_match_vars );
use Test::More tests => 1;

use Retry;
use MaatkitTest;

my $retry = new Retry();
isa_ok($retry, 'Retry');

# #############################################################################
# Done.
# #############################################################################
exit;
