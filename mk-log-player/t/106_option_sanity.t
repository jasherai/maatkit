#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 4;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-log-player/mk-log-player";

my $output;
my $tmpdir = '/tmp/mk-log-player';

diag(`rm -rf $tmpdir 2>/dev/null; mkdir $tmpdir`);

# #############################################################################
# Test option sanity.
# #############################################################################
$output = `$trunk/mk-log-player/mk-log-player 2>&1`;
like(
   $output,
   qr/Specify at least one of --play, --split or --split-random/,
   'Needs --play or --split to run'
);

$output = `$trunk/mk-log-player/mk-log-player --play foo 2>&1`;
like(
   $output,
   qr/Missing or invalid host/,
   '--play requires host'
);

$output = `$trunk/mk-log-player/mk-log-player --play foo h=localhost --print 2>&1`;
like(
   $output,
   qr/foo is not a file/,
   'Dies if no valid session files are given'
);

`$trunk/mk-log-player/mk-log-player --split Thread_id --base-dir $tmpdir $trunk/mk-log-player/t/samples/log001.txt`;
`$trunk/mk-log-player/mk-log-player --threads 1 --play $tmpdir/sessions-1.txt --print`;
$output = `cat $tmpdir/*`;
like(
   $output,
   qr/use mk_log/,
   "Prints sessions' queries without DSN"
);
diag(`rm session-results-*.txt 2>/dev/null`);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $tmpdir 2>/dev/null`);
exit;
