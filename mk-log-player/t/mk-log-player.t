#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 15;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

my $tmpdir = '/tmp/mk-log-player';
diag(`rm -rf $tmpdir; mkdir $tmpdir`);

# #############################################################################
# Test option sanity.
# #############################################################################
my $output;
$output = `../mk-log-player 2>&1`;
like(
   $output,
   qr/Specify at least one of --play or --split/,
   'Needs --play or --split to run'
);

$output = `../mk-log-player --play foo 2>&1`;
like(
   $output,
   qr/Missing or invalid host/,
   '--play requires host'
);

$output = `../mk-log-player --play foo h=localhost --print 2>&1`;
like(
   $output,
   qr/foo is not a file/,
   'Dies if no valid session files are given'
);

# #############################################################################
# Test log splitting.
# #############################################################################
$output = `../mk-log-player --base-dir $tmpdir --session-files 2 --split Thread_id samples/log001.txt`;
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
# Test --print.
# #############################################################################
diag(`mkdir $tmpdir/results`);
`../mk-log-player --threads 1 --base-dir $tmpdir/results --play $tmpdir/sessions-1.txt --print`;
$output = `cat $tmpdir/results/*`;
like(
   $output,
   qr/use mk_log/,
   "Prints sessions' queries without DSN"
);

# #############################################################################
# Test session playing.
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 3 unless $dbh;

   $sb->load_file('master', 'samples/log.sql');

   # Using --port implicitly tests that the DSN inherits
   # values from --port, etc. (issue 248).
   $output = `../mk-log-player --play $tmpdir/ h=127.1,u=msandbox,p=msandbox --port 12345`;

   my $r = $dbh->selectall_arrayref('select * from mk_log_player_1.tbl1 where a = 100 OR a = 555;');
   is_deeply(
      $r,
      [[100], [555]],
      '--play made table changes',
   );

   $sb->load_file('master', 'samples/log.sql');
   $output = `../mk-log-player --only-select --play $tmpdir/ F=/tmp/12345/my.sandbox.cnf`;
   $r = $dbh->selectall_arrayref('select * from mk_log_player_1.tbl1 where a = 100 OR a = 555;');
   is_deeply(
      $r,
      [],
      'No table changes with --only-select',
   );

   $sb->wipe_clean($dbh);
};

# #############################################################################
# Issue 418: mk-log-player dies trying to play statements with blank lines
# #############################################################################
diag(`rm -rf $tmpdir/*; mkdir $tmpdir/results`);
$output = `../mk-log-player --split Thread_id --base-dir $tmpdir ../../common/t/samples/slow020.txt`;
$output = `../mk-log-player --play $tmpdir --threads 1 --base-dir $tmpdir/results --print | diff samples/play_slow020.txt -`;

is(
   $output,
   '',
   'Play session from log with blank lines in queries (issue 418)' 
);

# #############################################################################
# Issue 570: Integrate BinaryLogPrarser into mk-log-player
# #############################################################################
diag(`rm -rf $tmpdir/*`);
`../mk-log-player --split Thread_id --base-dir $tmpdir ../../common/t/samples/binlog001.txt --type binlog --session-files 1`;
$output = `diff $tmpdir/sessions-1.txt samples/split_binlog001.txt`;

is(
   $output,
   '',
   'Split binlog001.txt'
);

# #############################################################################
# Issue 571: Add --filter to mk-log-player
# #############################################################################
diag(`rm -rf $tmpdir/*`);
`../mk-log-player --split Thread_id --base-dir $tmpdir ../../common/t/samples/binlog001.txt --type binlog --session-files 1 --filter '\$event->{arg} && \$event->{arg} eq \"foo\"'`;
ok(
   !-f "$tmpdir/sessions-1.txt",
   '--filter'
);


# #############################################################################
# Issue 391: Add --pid option to all scripts
# #############################################################################
`touch /tmp/mk-script.pid`;
$output = `../mk-log-player --split Thread_id ../../common/t/samples/binlog001.txt --type binlog --session-files 1  --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;


# #############################################################################
# Issue 172: Make mk-query-digest able to read general logs
# #############################################################################
diag(`rm -rf $tmpdir/*`);
`../mk-log-player --split Thread_id --base-dir $tmpdir ../../common/t/samples/genlog001.txt --type genlog --session-files 1`;

$output = `diff $tmpdir/sessions-1.txt samples/split_genlog001.txt`;

is(
   $output,
   '',
   'Split genlog001.txt'
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $tmpdir`);
diag(`rm -rf ./session-results-*`);
exit;
