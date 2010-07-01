#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

use MaatkitTest;

# #############################################################################
# Issue 687: Test segfaults on old version of Perl
# #############################################################################
my $output = `zcat $trunk/common/t/samples/slow039.txt.gz | $trunk/mk-query-digest/mk-query-digest 2>/tmp/mqd-warnings.txt`;
like(
   $output,
   qr/Query 1:/,
   'INSERT that segfaulted fingerprint() (issue 687)'
);

$output = `cat /tmp/mqd-warnings.txt`;
chomp $output;
is(
   $output,
   '',
   'No warnings on INSERT that segfaulted fingerprint() (issue 687)',
);

diag(`rm -rf /tmp/mqd-warnings.txt`);

# #############################################################################
# Done.
# #############################################################################
exit;
