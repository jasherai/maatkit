#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 12;
use Data::Dumper;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

$sb->load_file('master', 'samples/log.sql');

my $tmpdir = '/tmp/mk-log-player';
diag(`rm -rf $tmpdir; mkdir $tmpdir`);

# Test option sanity.
my $output;
$output = `../mk-log-player 2>&1`;
like($output, qr/Specify at least one of --play or --split/, 'Needs --play or --split to run');

$output = `../mk-log-player --play foo 2>&1`;
like($output, qr/DSN is required with --play/, 'DSN is required with --play');

$output = `../mk-log-player --play foo h=127.1,P=12345 2>&1`;
like($output, qr/Cannot open session file/, 'Dies if no session file');

# Test that it actually splits a log.
$output = `../mk-log-player -v --saveto $tmpdir -s Thread_id samples/log001.txt`;
like($output, qr/Parsed 4 sessions/, 'Reports 4 sessions parsed');
foreach my $n ( 1..4 ) {
   my $retval = system("diff $tmpdir/1/mysql_log_session_000$n samples/log001_session_$n.txt 1>/dev/null 2>/dev/null");
   cmp_ok($retval >> 8, '==', 0, "Session $n of 4 has correct quries");
}

# Test that it can play those sessions.
$output = `../mk-log-player -p $tmpdir/1 h=127.1,P=12345`;
# This SELECT stmt should be the last (session 4, query 1)
like($output, qr/SELECT a FROM tbl1 WHERE a = 3/, 'Reports 4 sessions played');
my $r = $dbh->selectall_arrayref('select * from mk_log_player_1.tbl1 where a = 100 OR a = 555;');
is_deeply(
   $r,
   [[100], [555]],
   'Expected table changes were made',
);

$sb->load_file('master', 'samples/log.sql');
$output = `../mk-log-player --onlyselect -p $tmpdir/1 h=127.1,P=12345`;
$r = $dbh->selectall_arrayref('select * from mk_log_player_1.tbl1 where a = 100 OR a = 555;');
is_deeply(
   $r,
   [],
   'Tables were not changed with --onlyselect',
);

# Test --print
$output = `../mk-log-player --play $tmpdir/1 --print`;
like($output, qr/session 4 query 2/, "Prints sessions' queries without DSN");

diag(`rm -rf $tmpdir`);
$sb->wipe_clean($dbh);
exit;
