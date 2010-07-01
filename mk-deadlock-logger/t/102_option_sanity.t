#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

use MaatkitTest;

my $output;

# #############################################################################
# Sanity tests.
# #############################################################################
$output = `$trunk/mk-deadlock-logger/mk-deadlock-logger --dest D=test,t=deadlocks 2>&1`;
like(
   $output,
   qr/Missing or invalid source host/,
   'Requires source host'
);

$output = `$trunk/mk-deadlock-logger/mk-deadlock-logger h=127.1 --dest t=deadlocks 2>&1`;
like(
   $output,
   qr/requires a 'D'/, 
   'Dest DSN requires D',
);

$output = `$trunk/mk-deadlock-logger/mk-deadlock-logger --dest D=test 2>&1`;
like(
   $output,
   qr/requires a 't'/,
   'Dest DSN requires t'
);

# #############################################################################
# Done.
# #############################################################################
exit;
