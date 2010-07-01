#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 22;

use LogSplitter;
use SlowLogParser;
use MaatkitTest;

my $output;
my $tmpdir = '/tmp/LogSplitter';
diag(`rm -rf $tmpdir ; mkdir $tmpdir`);

my $lp = new SlowLogParser();
my $ls = new LogSplitter(
   attribute     => 'foo',
   base_dir      => $tmpdir,
   parser        => $lp,
   session_files => 3,
   quiet         => 1,
);

isa_ok($ls, 'LogSplitter');

diag(`rm -rf $tmpdir ; mkdir $tmpdir`);

# This creates an implicit test to make sure that
# split_logs() will not die if the saveto_dir already
# exists. It should just use the existing dir.
diag(`mkdir $tmpdir/1`); 

$ls->split("$trunk/common/t/samples/slow006.txt");
is(
   $ls->{n_sessions_saved},
   0,
   'Parsed zero sessions for bad attribute'
);

is(
   $ls->{n_events_total},
   6,
   'Parsed all events'
);

# #############################################################################
# Test a simple split of 6 events, 3 sessions into 3 session files.
# #############################################################################
diag(`rm -rf $tmpdir/*`);
$ls = new LogSplitter(
   attribute      => 'Thread_id',
   base_dir       => $tmpdir,
   parser         => $lp,
   session_files  => 3,
   quiet          => 1,
   merge_sessions => 0,
);
$ls->split("$trunk/common/t/samples/slow006.txt");
ok(-f "$tmpdir/1/session-1.txt", 'Basic split session 1 file exists');
ok(-f "$tmpdir/1/session-2.txt", 'Basic split session 2 file exists');
ok(-f "$tmpdir/1/session-3.txt", 'Basic split session 3 file exists');

$output = `diff $tmpdir/1/session-1.txt $trunk/common/t/samples/slow006-session-1.txt`;
is(
   $output,
   '',
   'Session 1 file has correct SQL statements'
);

$output = `diff $tmpdir/1/session-2.txt $trunk/common/t/samples/slow006-session-2.txt`;
is(
   $output,
   '',
   'Session 2 file has correct SQL statements'
);

$output = `diff $tmpdir/1/session-3.txt $trunk/common/t/samples/slow006-session-3.txt`;
is(
   $output,
   '',
   'Session 3 file has correct SQL statements'
);

# #############################################################################
# Test splitting more sessions than we can have open filehandles at once.
# #############################################################################
diag(`rm -rf $tmpdir/*`);
$ls = new LogSplitter(
   attribute      => 'Thread_id',
   base_dir       => $tmpdir,
   parser         => $lp,
   session_files  => 10,
   quiet          => 1,
   merge_sessions => 0,
);
$ls->split("$trunk/common/t/samples/slow009.txt");
chomp($output = `ls -1 $tmpdir/1/ | wc -l`);
is(
   $output,
   2000,
   'Splits 2_000 sessions'
);

$output = `cat $tmpdir/1/session-2000.txt`;
like(
   $output,
   qr/SELECT 2001 FROM foo/,
   '2_000th session has correct SQL'
);

$output = `cat $tmpdir/1/session-12.txt`;
like(
   $output, qr/SELECT 12 FROM foo\n\nSELECT 1234 FROM foo/,
   'Reopened and appended to previously closed session'
);

# #############################################################################
# Test max_sessions.
# #############################################################################
diag(`rm -rf $tmpdir/*`);
$ls = new LogSplitter(
   attribute      => 'Thread_id',
   base_dir       => $tmpdir,
   parser         => $lp,
   session_files  => 10,
   quiet          => 1,
   merge_sessions => 0,
   max_sessions   => 10,
);
$ls->split("$trunk/common/t/samples/slow009.txt");
chomp($output = `ls -1 $tmpdir/1/ | wc -l`);
is(
   $output,
   '10',
   'max_sessions works (1/3)',
);
is(
   $ls->{n_sessions_saved},
   '10',
   'max_sessions works (2/3)'
);
is(
   $ls->{n_files_total},
   '10',
   'max_sessions works (3/3)'
);

# #############################################################################
# Check that all filehandles are closed.
# #############################################################################
is_deeply(
   $ls->{session_fhs},
   [],
   'Closes open fhs'
);

#diag(`rm -rf $tmpdir/*`);
#$output = `cat $trunk/common/t/samples/slow006.txt | $trunk/common/t/samples/log_splitter.pl`;
#like($output, qr/Parsed sessions\s+3/, 'Reads STDIN implicitly');

#diag(`rm -rf $tmpdir/*`);
#$output = `cat $trunk/common/t/samples/slow006.txt | $trunk/common/t/samples/log_splitter.pl -`;
#like($output, qr/Parsed sessions\s+3/, 'Reads STDIN explicitly');

#diag(`rm -rf $tmpdir/*`);
#$output = `cat $trunk/common/t/samples/slow006.txt | $trunk/common/t/samples/log_splitter.pl blahblah`;
#like($output, qr/Parsed sessions\s+0/, 'Does nothing if no valid logs are given');

# #############################################################################
# Test session file merging.
# #############################################################################
diag(`rm -rf $tmpdir/*`);
$ls = new LogSplitter(
   attribute      => 'Thread_id',
   base_dir       => $tmpdir,
   parser         => $lp,
   session_files  => 10,
   quiet          => 1,
);
$ls->split("$trunk/common/t/samples/slow009.txt");
$output = `grep 'START SESSION' $tmpdir/sessions-*.txt | cut -d' ' -f 4 | sort -n`;
like(
   $output,
   qr/^1\n2\n3\n[\d\n]+2001$/,
   'Merges 2_000 sessions'
);

ok(
   !-d "$tmpdir/1",
   'Removes tmp dirs after merging'
);

# #############################################################################
# Issue 418: mk-log-player dies trying to play statements with blank lines
# #############################################################################

# LogSplitter should pre-process queries before writing them so that they
# do not contain blank lines.
diag(`rm -rf $tmpdir/*`);
$ls = new LogSplitter(
   attribute     => 'Thread_id',
   base_dir      => $tmpdir,
   parser        => $lp,
   quiet         => 1,
   session_files => 1,
);
$ls->split("$trunk/common/t/samples/slow020.txt");
$output = `diff $tmpdir/sessions-1.txt $trunk/common/t/samples/split_slow020.txt`;
is(
   $output,
   '',
   'Collapse multiple \n and \s (issue 418)'
);

# Make sure it works for --maxsessionfiles
#diag(`rm -rf $tmpdir/*`);
#$ls = new LogSplitter(
#   attribute       => 'Thread_id',
#   saveto_dir      => "$tmpdir/",
#   lp              => $lp,
#   verbose         => 0,
#   maxsessionfiles => 1,
#);
#$ls->split(['common/t/samples/slow020.txt' ]);
#$output = `diff $tmpdir/1/session-0001 $trunk/common/t/samples/split_slow020_msf.txt`;
#is(
#   $output,
#   '',
#   'Collapse multiple \n and \s with --maxsessionfiles (issue 418)'
#);

# #############################################################################
# Issue 571: Add --filter to mk-log-player
# #############################################################################
my $callback = sub {
   return;
};
$ls = new LogSplitter(
   attribute     => 'Thread_id',
   base_dir      => $tmpdir,
   parser        => $lp,
   session_files => 3,
   quiet         => 1,
   callbacks     => [$callback],
);
$ls->split("$trunk/common/t/samples/slow006.txt");
is(
   $ls->{n_sessions_saved},
   0,
   'callbacks'
);

# #############################################################################
# Issue 798: Make mk-log-player --split work without an attribute
# #############################################################################
diag(`rm -rf $tmpdir/*`);
$ls = new LogSplitter(
   attribute      => 'Thread_id',
   split_random   => 1,
   base_dir       => $tmpdir,
   parser         => $lp,
   session_files  => 2,
   quiet          => 1,

);
$ls->split("$trunk/common/t/samples/slow006.txt");

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
exit;
