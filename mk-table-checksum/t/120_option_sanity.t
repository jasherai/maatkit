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
