#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 1;

use MaatkitTest;
require "$trunk/mk-table-checksum/mk-table-checksum";

my $output;

# Test DSN value inheritance
$output = `$trunk/mk-table-checksum/mk-table-checksum h=127.1 --replicate table`;
like(
   $output,
   qr/--replicate table must be database-qualified/,
   "--replicate table must be db-qualified"
);

# #############################################################################
# Done.
# #############################################################################
exit;
