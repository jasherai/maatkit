#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 8;
use English qw(-no_match_vars);

require '../LogSplitter.pm';
require '../LogParser.pm';

my $lp = new LogParser;
my $ls = new LogSplitter;

isa_ok($ls, 'LogSplitter');

my $tmpdir = '/tmp/logettes';
diag(`mkdir $tmpdir`);

$ls->split_logs(
   log_files  => [ 'samples/slow006.txt' ],
   attribute  => 'foo',
   saveto_dir => "$tmpdir/",
   LogParser  => $lp,
   silent     => 1,
);
ok($ls->{n_sessions} == 0, 'Parsed zero sessions for bad attribute');

$ls->split_logs(
   log_files  => [ 'samples/slow006.txt' ],
   attribute  => 'Thread_id',
   saveto_dir => "$tmpdir",
   LogParser  => $lp,
   silent     => 1,
);

ok(-f "$tmpdir/mysql_log_split-0001", 'Basic log split 0001 exists');
ok(-f "$tmpdir/mysql_log_split-0002", 'Basic log split 0002 exists');
ok(-f "$tmpdir/mysql_log_split-0003", 'Basic log split 0003 exists');

my $output;

$output = `diff $tmpdir/mysql_log_split-0001 samples/slow006_split-0001.txt`;
ok(!$output, 'Basic log split 0001 has correct SQL statements');
$output = `diff $tmpdir/mysql_log_split-0002 samples/slow006_split-0002.txt`;
ok(!$output, 'Basic log split 0002 has correct SQL statements');
$output = `diff $tmpdir/mysql_log_split-0003 samples/slow006_split-0003.txt`;
ok(!$output, 'Basic log split 0003 has correct SQL statements');

diag(`rm -rf $tmpdir`);
exit;
