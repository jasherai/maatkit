#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 9;

use MaatkitTest;
require "$trunk/mk-error-log/mk-error-log";

# #############################################################################
# Basic input-output diffs to make sure that the analyses are correct.
# #############################################################################

my $sample = "$trunk/common/t/samples/errlogs/";

# trf => 'sort' because mk-error-log sorts its output by the
# events' count and the events come from a hash so events with
# the same count are printed together but in random order.
# So the output isn't what the user would normally see; e.g.
# the first header line appears at the bottom.

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog001.txt') },
      "mk-error-log/t/samples/errlog001-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog001.txt'
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog002.txt') },
      "mk-error-log/t/samples/errlog002-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog002.txt'
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog003.txt') },
      "mk-error-log/t/samples/errlog003-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog003.txt'
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog004.txt') },
      "mk-error-log/t/samples/errlog004-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog004.txt'
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog005.txt') },
      "mk-error-log/t/samples/errlog005-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog005.txt'
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog006.txt') },
      "mk-error-log/t/samples/errlog006-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog006.txt'
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog007.txt') },
      "mk-error-log/t/samples/errlog007-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog007.txt'
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog008.txt') },
      "mk-error-log/t/samples/errlog008-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog008.txt'
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog009.txt') },
      "mk-error-log/t/samples/errlog009-report.txt",
      trf => 'sort'
   ),
   'Analysis for errlog009.txt'
);


# #############################################################################
# Done.
# #############################################################################
exit;
