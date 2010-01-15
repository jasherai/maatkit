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
require "$trunk/mk-parallel-restore/mk-parallel-restore";

my $cnf     = '/tmp/12345/my.sandbox.cnf';
my $cmd     = "$trunk/mk-parallel-restore/mk-parallel-restore -F $cnf ";
my $output;

# #############################################################################
# Issue 534: mk-parallel-restore --threads is being ignored
# #############################################################################
$output = `$cmd --help --threads 32 2>&1`;
like(
   $output,
   qr/--threads\s+32/,
   '--threads overrides /proc/cpuinfo (issue 534)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
