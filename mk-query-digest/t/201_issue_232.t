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

my $run_with = "$trunk/mk-query-digest/mk-query-digest --report-format=query_report --limit 10 $trunk/common/t/samples/";

# #############################################################################
# Issue 232: mk-query-digest does not properly handle logs with an empty Schema:
# #############################################################################
my $output = 'foo'; # clear previous test results
my $cmd = "${run_with}slow026.txt";
$output = `MKDEBUG=1 $cmd 2>&1`;
# Changed qr// from matching db to Schema because attribs are auto-detected.
like(
   $output,
   qr/Type for db is string /,
   'Type for empty Schema: is string (issue 232)',
);

unlike(
   $output,
   qr/Argument "" isn't numeric in numeric gt/,
   'No error message in debug output for empty Schema: (issue 232)'
);

# #############################################################################
# Done.
# #############################################################################
exit;
