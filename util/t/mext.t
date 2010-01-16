#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use MaatkitTest;

# #############################################################################
# Begin.
# #############################################################################

ok(
   no_diff(
      "$trunk/util/mext -- cat $trunk/util/t/samples/mext-001.txt",
      'util/t/samples/mext-001-result.txt',
   ),
   'mext mext-001.txt'
);

ok(
   no_diff(
      "$trunk/util/mext -r -- cat $trunk/util/t/samples/mext-002.txt",
      'util/t/samples/mext-002-result.txt',
   ),
   'mext mext-002.txt'
);

ok(
   no_diff(
      "$trunk/util/mext2 c=4 i=1 r=falsetest \"ma=cat $trunk/util/t/samples/mext-001.txt\"",
      'util/t/samples/mext-001-result.txt',
   ),
   'mext2 mext-001.txt'
);

ok(
   no_diff(
      "$trunk/util/mext2 c=4 i=1 r=truetest \"ma=cat $trunk/util/t/samples/mext-002.txt\"",
      'util/t/samples/mext-002-result.txt',
   ),
   'mext2 mext-002.txt'
);

# #############################################################################
# Done.
# #############################################################################
exit;
