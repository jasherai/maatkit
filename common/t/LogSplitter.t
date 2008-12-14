#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 23;
use English qw(-no_match_vars);

require '../LogSplitter.pm';
require '../LogParser.pm';

my $tmpdir = '/tmp/logettes';
diag(`rm -rf $tmpdir ; mkdir $tmpdir`);

my $lp = new LogParser();
my $ls = new LogSplitter(
   attribute  => 'foo',
   saveto_dir => "$tmpdir/",
   LogParser  => $lp,
   verbosity  => 0,
);

isa_ok($ls, 'LogSplitter');

$ls->split_logs(['samples/slow006.txt']);
ok($ls->{n_sessions} == 0, 'Parsed zero sessions for bad attribute');

$ls = new LogSplitter(
   attribute  => 'Thread_id',
   saveto_dir => "$tmpdir/",
   LogParser  => $lp,
   verbosity  => 0,
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
like($output, qr/Parsed 3 sessions/, 'Reads STDIN implicitly');

diag(`rm -rf $tmpdir/*`);
$output = `cat samples/slow006.txt | samples/log_splitter.pl -`;
like($output, qr/Parsed 3 sessions/, 'Reads STDIN explicitly');

diag(`rm -rf $tmpdir/*`);
$output = `cat samples/slow006.txt | samples/log_splitter.pl blahblah`;
like($output, qr/Parsed 0 sessions/, 'Does nothing if no valid logs are given');

diag(`rm -rf $tmpdir`);


$ls = new LogSplitter(
   attribute   => 'Thread_id',
   saveto_dir  => "$tmpdir/",
   LogParser   => $lp,
   verbosity         => undef,
   maxsessions       => undef,
   maxfiles          => undef,
   maxdirs           => undef,
   session_file_name => undef,
);
cmp_ok($ls->{verbosity}, '==', '0', 'Undef verbosity gets default');
cmp_ok($ls->{maxsessions}, '==', '100000', 'Undef maxsessions gets default');
cmp_ok($ls->{maxfiles}, '==', '100', 'Undef maxfiles gets default');
cmp_ok($ls->{maxdirs}, '==', '100', 'Undef maxdirs gets default');
is($ls->{session_file_name}, 'mysql_log_session_', 'Undef session_file_name gets default');

exit;
