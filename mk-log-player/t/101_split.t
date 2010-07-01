#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-log-player/mk-log-player";

my $output;
my $tmpdir = '/tmp/mk-log-player';
my $cmd = "$trunk/mk-log-player/mk-log-player --base-dir $tmpdir";

diag(`rm -rf $tmpdir 2>/dev/null; mkdir $tmpdir`);

# #############################################################################
# Test log splitting.
# #############################################################################
$output = `$cmd --session-files 2 --split Thread_id $trunk/mk-log-player/t/samples/log001.txt`;
like(
   $output,
   qr/Sessions saved\s+4/,
   'Reports 2 sessions saved'
);

ok(
   -f "$tmpdir/sessions-1.txt",
   "sessions-1.txt created"
);
ok(
   -f "$tmpdir/sessions-2.txt",
   "sessions-2.txt created"
);

chomp($output = `cat $tmpdir/sessions-[12].txt | wc -l`);
is(
   $output,
   34,
   'Session files have correct number of lines'
);

# #############################################################################
# Issue 570: Integrate BinaryLogPrarser into mk-log-player
# #############################################################################
diag(`rm -rf $tmpdir/*`);
`$cmd --split Thread_id $trunk/common/t/samples/binlogs/binlog001.txt --type binlog --session-files 1`;
$output = `diff $tmpdir/sessions-1.txt $trunk/mk-log-player/t/samples/split_binlog001.txt`;

is(
   $output,
   '',
   'Split binlog001.txt'
);

# #############################################################################
# Issue 172: Make mk-query-digest able to read general logs
# #############################################################################
diag(`rm -rf $tmpdir/*`);
`$cmd --split Thread_id $trunk/common/t/samples/genlogs/genlog001.txt --type genlog --session-files 1`;

$output = `diff $tmpdir/sessions-1.txt $trunk/mk-log-player/t/samples/split_genlog001.txt`;

is(
   $output,
   '',
   'Split genlog001.txt'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $tmpdir 2>/dev/null`);
exit;
