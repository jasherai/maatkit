#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 30;

require '../LogSplitter.pm';
require '../SlowLogParser.pm';

# Returns true (1) if there's no difference between the
# output and the expected output.
sub test_diff {
   my ( $output, $expected_output ) = @_;
   my $retval = system("diff $output $expected_output");
   $retval = $retval >> 8;
   return !$retval;
}

my $tmpdir = '/tmp/logettes';
diag(`rm -rf $tmpdir ; mkdir $tmpdir`);

my $lp = new SlowLogParser();
my $ls = new LogSplitter(
   attribute  => 'foo',
   saveto_dir => "$tmpdir/",
   lp         => $lp,
   verbose    => 0,
);

isa_ok($ls, 'LogSplitter');

# This creates an implicit test to make sure that
# split_logs() will not die if the saveto_dir already
# exists. It should just use the existing dir.
diag(`mkdir $tmpdir/1`); 

$ls->split_logs(['samples/slow006.txt']);
ok($ls->{n_sessions} == 0, 'Parsed zero sessions for bad attribute');

$ls = new LogSplitter(
   attribute  => 'Thread_id',
   saveto_dir => "$tmpdir/",
   lp         => $lp,
   verbose    => 0,
);
$ls->split_logs(['samples/slow006.txt' ]);
ok(-f "$tmpdir/1/mysql_log_session_0001", 'Basic log split 0001 exists');
ok(-f "$tmpdir/1/mysql_log_session_0002", 'Basic log split 0002 exists');
ok(-f "$tmpdir/1/mysql_log_session_0003", 'Basic log split 0003 exists');

my $output;

$output = `diff $tmpdir/1/mysql_log_session_0001 samples/slow006_split-0001.txt`;
ok(!$output, 'Basic log split 0001 has correct SQL statements');
$output = `diff $tmpdir/1/mysql_log_session_0002 samples/slow006_split-0002.txt`;
ok(!$output, 'Basic log split 0002 has correct SQL statements');
$output = `diff $tmpdir/1/mysql_log_session_0003 samples/slow006_split-0003.txt`;
ok(!$output, 'Basic log split 0003 has correct SQL statements');

diag(`rm -rf $tmpdir/*`);

$ls->split_logs(['samples/slow009.txt']);
chomp($output = `ls -1 $tmpdir/20/ | tail -n 1`);
is($output, 'mysql_log_session_2000', 'Makes 20 dirs for 2,000 sessions');
$output = `cat $tmpdir/20/mysql_log_session_2000`;
like($output, qr/SELECT 2001 FROM foo/, '2,000th session has correct SQL');
$output = `cat $tmpdir/1/mysql_log_session_0012`;
like($output, qr/SELECT 12 FROM foo\n\nSELECT 1234 FROM foo/, 'Reopened and appended to previously closed session');

diag(`rm -rf $tmpdir/*`);

$ls->{maxsessions} = 10;
$ls->split_logs(['samples/slow009.txt']);
chomp($output = `ls -1 $tmpdir/1/ | tail -n 1`);
is($output, 'mysql_log_session_0010', 'maxsessions works (1/3)');
is($ls->{n_sessions}, '10', 'maxsessions works (2/3)');
is($ls->{n_files}, '10', 'maxsessions works (3/3)');

is_deeply(
   $ls->{session_fhs},
   [],
   'Closes open fhs'
);

diag(`rm -rf $tmpdir/*`);
$output = `cat samples/slow006.txt | samples/log_splitter.pl`;
like($output, qr/Parsed sessions\s+3/, 'Reads STDIN implicitly');

diag(`rm -rf $tmpdir/*`);
$output = `cat samples/slow006.txt | samples/log_splitter.pl -`;
like($output, qr/Parsed sessions\s+3/, 'Reads STDIN explicitly');

diag(`rm -rf $tmpdir/*`);
$output = `cat samples/slow006.txt | samples/log_splitter.pl blahblah`;
like($output, qr/Parsed sessions\s+0/, 'Does nothing if no valid logs are given');

diag(`rm -rf $tmpdir/*`);
$ls = new LogSplitter(
   attribute   => 'Thread_id',
   saveto_dir  => "$tmpdir/",
   lp          => $lp,
   verbose           => undef,
   maxsessions       => undef,
   maxfiles          => undef,
   maxdirs           => undef,
   session_file_name => undef,
);
cmp_ok($ls->{verbose}, '==', '0', 'Undef verbose gets default');
cmp_ok($ls->{maxsessions}, '==', '100000', 'Undef maxsessions gets default');
cmp_ok($ls->{maxfiles}, '==', '100', 'Undef maxfiles gets default');
cmp_ok($ls->{maxdirs}, '==', '100', 'Undef maxdirs gets default');
is($ls->{session_file_name}, 'mysql_log_session_', 'Undef session_file_name gets default');

# Test maxsessionfiles (multiple sessions in a limited number of files).
$ls = new LogSplitter(
   attribute       => 'Thread_id',
   saveto_dir      => "$tmpdir/",
   lp              => $lp,
   verbose         => 1,
   maxsessionfiles => 2,
);

open OUTPUT, '>', \$output;
select OUTPUT;

$ls->split_logs(['samples/slow006.txt' ]);

close OUTPUT;
select STDOUT;

is(`ls -1 $tmpdir/1/ | wc -l`, "2\n", 'maxsessionfiles created only 2 files');
ok(
   test_diff("$tmpdir/1/mysql_log_session_0001", 'samples/maxsessionfiles_01'),
   'maxsessionfiles file 1 of 2'
);
ok(
   test_diff("$tmpdir/1/mysql_log_session_0002", 'samples/maxsessionfiles_02'),
   'maxsessionfiles file 2 of 2'
);
like(
   $output,
   qr/Events read\s+6/,
   'Counts total events'
);
like(
   $output,
   qr/Events saved\s+6/,
   'Counts saved events'
);

# #############################################################################
# Issue 418: mk-log-player dies trying to play statements with blank lines
# #############################################################################

# LogSplitter should pre-process queries before writing them so that they
# do not contain blank lines.
diag(`rm -rf $tmpdir/*`);
$ls = new LogSplitter(
   attribute  => 'Thread_id',
   saveto_dir => "$tmpdir/",
   lp         => $lp,
   verbose    => 0,
);
$ls->split_logs(['samples/slow020.txt' ]);
$output = `diff $tmpdir/1/mysql_log_session_0001 samples/split_slow020.txt`;
is(
   $output,
   '',
   'Collapse multiple \n and \s (issue 418)'
);

# Make sure it works for --maxsessionfiles
diag(`rm -rf $tmpdir/*`);
$ls = new LogSplitter(
   attribute       => 'Thread_id',
   saveto_dir      => "$tmpdir/",
   lp              => $lp,
   verbose         => 0,
   maxsessionfiles => 1,
);
$ls->split_logs(['samples/slow020.txt' ]);
$output = `diff $tmpdir/1/mysql_log_session_0001 samples/split_slow020_msf.txt`;
is(
   $output,
   '',
   'Collapse multiple \n and \s with --maxsessionfiles (issue 418)'
);

diag(`rm -rf $tmpdir`);
exit;
