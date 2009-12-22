#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 2;

# #############################################################################
# Issue 687: Test segfaults on old version of Perl
# #############################################################################
my $output = `zcat ../../common/t/samples/slow039.txt.gz | ../mk-query-digest 2>/tmp/mqd-warnings.txt`;
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
