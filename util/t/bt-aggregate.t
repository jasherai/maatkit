#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use MaatkitTest;

# #############################################################################
# Begin.
# #############################################################################

ok(
   no_diff(
      "$trunk/util/bt-aggregate $trunk/util/t/samples/stacktrace-001.txt",
      'util/t/samples/stacktrace-001-result.txt',
   ),
   'bt-aggregate 001',
);

ok(
   no_diff(
      "$trunk/util/bt-aggregate $trunk/util/t/samples/stacktrace-002.txt",
      "util/t/samples/stacktrace-002-result.txt",
   ),
   'bt-aggregate 002',
);

# #############################################################################
# Done.
# #############################################################################
exit;
