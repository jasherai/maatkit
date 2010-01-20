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

# #############################################################################
# Begin.
# #############################################################################

ok(
   no_diff(
      "$trunk/util/snoop-to-tcpdump $trunk/util/t/samples/snoop001.txt",
      'util/t/samples/snoop001-result.txt',
   ),
   'snoop-to-tcpdump 001',
);

# #############################################################################
# Done.
# #############################################################################
exit;
