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
require "$trunk/mk-log-player/mk-log-player";

my $output;
my $tmpdir = '/tmp/mk-log-player';
diag(`rm -rf $tmpdir; mkdir $tmpdir`);

# #############################################################################
# Issue 798: Make mk-log-player --split work without an attribute
# #############################################################################
$output = `$trunk/mk-log-player/mk-log-player --base-dir $tmpdir --session-files 2 --split-random $trunk/common/t/samples/slow006.txt`;

like(
   $output,
   qr/Events saved\s+6/,
   'Reports 6 events saved'
);
ok(
   -f "$tmpdir/sessions-1.txt",
   "sessions-1.txt created"
);
ok(
   -f "$tmpdir/sessions-2.txt",
   "sessions-2.txt created"
);

$output = `diff $tmpdir/sessions-1.txt $trunk/common/t/samples/LogSplitter/slow006-random-1.txt`;
is(
   $output,
   '',
   'Random file 1 file has correct SQL statements'
);

$output = `diff $tmpdir/sessions-2.txt $trunk/common/t/samples/LogSplitter/slow006-random-2.txt`;
is(
   $output,
   '',
   'Random file 2 file has correct SQL statements'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $tmpdir`);
diag(`rm -rf ./session-results-*`);
exit;
