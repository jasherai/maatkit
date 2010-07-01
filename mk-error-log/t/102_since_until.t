#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 5;

use MaatkitTest;
require "$trunk/mk-error-log/mk-error-log";

# #############################################################################
# Test --since and --until.
# #############################################################################

my $sample = "$trunk/common/t/samples/errlogs/";

# trf => 'sort' because mk-error-log sorts its output by the
# events' count and the events come from a hash so events with
# the same count are printed together but in random order.
# So the output isn't what the user would normally see; e.g.
# the first header line appears at the bottom.

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog001.txt', qw(--since 081117)) },
      "mk-error-log/t/samples/errlog001-since-yymmdd.txt",
      trf => 'sort',
   ),
   '--since 081117',
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog001.txt', qw(--since 2008-11-17)) },
      "mk-error-log/t/samples/errlog001-since-yymmdd.txt",
      trf => 'sort',
   ),
   '--since 2008-11-17',
);


ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog001.txt', '--since', '081117 16:32:55') },
      "mk-error-log/t/samples/errlog001-since-yymmdd-hhmmss.txt",
      trf => 'sort',
   ),
   '--since 081117 16:32:55',
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog001.txt', qw(--until 100101)) },
      "mk-error-log/t/samples/errlog001-report.txt",
      trf => 'sort',
   ),
   '--until 100101',
);

ok(
   no_diff(
      sub { mk_error_log::main($sample.'errlog001.txt', '--until', '081117 16:15:16') },
      "mk-error-log/t/samples/errlog001-until-yymmdd-hhmmss.txt",
      trf => 'sort',
   ),
   '--until 081117 16:15:16',
);

# #############################################################################
# Done.
# #############################################################################
exit;
