#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 14;

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

$output = `../mk-log-player --play foo --print 2>&1`;
like(
   $output,
   qr/Cannot open session file/,
   'Dies if no session file'
);

# #############################################################################
# Test log splitting.
# #############################################################################
$output = `../mk-log-player -v --saveto $tmpdir --split Thread_id samples/log001.txt`;
like($output, qr/Parsed sessions\s+4/, 'Reports 4 sessions parsed');
foreach my $n ( 1..4 ) {
   my $retval = system("diff $tmpdir/1/mysql_log_session_000$n samples/log001_session_$n.txt 1>/dev/null 2>/dev/null");
   cmp_ok($retval >> 8, '==', 0, "Session $n of 4 has correct quries");
}

# #############################################################################
# Test --print.
# #############################################################################
$output = `../mk-log-player --play $tmpdir/1 --print`;
like($output, qr/session 4 query 2/, "Prints sessions' queries without DSN");

# #############################################################################
# Test session playing.
# #############################################################################
SKIP: {
   skip 'Cannot connect to sandbox master', 4 unless $dbh;

   $sb->load_file('master', 'samples/log.sql');

   $output = `../mk-log-player --play $tmpdir/1 h=127.1,P=12345`;
   # This SELECT stmt should be the last (session 4, query 1)
   like($output, qr/SELECT a FROM tbl1 WHERE a = 3/, 'Reports 4 sessions played');

   my $r = $dbh->selectall_arrayref('select * from mk_log_player_1.tbl1 where a = 100 OR a = 555;');
   is_deeply(
      $r,
      [[100], [555]],
      'Expected table changes were made',
   );

   $sb->load_file('master', 'samples/log.sql');
   $output = `../mk-log-player --onlyselect --play $tmpdir/1 h=127.1,P=12345`;
   $r = $dbh->selectall_arrayref('select * from mk_log_player_1.tbl1 where a = 100 OR a = 555;');
   is_deeply(
      $r,
      [],
      'Tables were not changed with --onlyselect',
   );

   # #########################################################################
   # Issue 356: mk-log-player doesn't calculate queries per second correctly
   # #########################################################################
   $output = `../mk-log-player --play samples/one_big_session.txt --csv --host 127.1 --port 12345 > $tmpdir/res`;
   my $res = `head -n 2 $tmpdir/res | tail -n 1 | cut -d',' -f 2,6,7`;
   my ($total_time, $n_queries, $qps) = split(',', $res);
   is(
      sprintf('%.6f', $qps),
      sprintf('%.6f', $total_time / $n_queries),
      'calculate queries per second correctly (issue 356)'
   );

   $sb->wipe_clean($dbh);
};

# #############################################################################
# Issue 418: mk-log-player dies trying to play statements with blank lines
# #############################################################################
diag(`rm -rf $tmpdir/*`);
$output = `../mk-log-player --split Thread_id --saveto $tmpdir ../../common/t/samples/slow020.txt`;
$output = `../mk-log-player --play $tmpdir/1 --print | diff samples/play_slow020.txt -`;
is(
   $output,
   '',
   'Play session from log with blank lines in queries (issue 418)' 
);

diag(`rm -rf $tmpdir`);
exit;
