#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 6;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $master_dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $slave_dbh  = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

my $output = `perl ../mk-slave-delay --help`;
like($output, qr/Prompt for a password/, 'It compiles');

# Check daemonization
my $cmd = '../mk-slave-delay --delay 1m --interval 15s --time 10m --daemonize --pid /tmp/mk-slave-delay.pid h=127.1,P=12346';
diag(`$cmd`);
$output = `ps -eaf | grep 'mk-slave-delay \-\-delay'`;
like($output, qr/$cmd/, 'It lives daemonized');

ok(-f '/tmp/mk-slave-delay.pid', 'PID file created');
my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-slave-delay.pid`;
# If this test fails, it may be because another instances of
# mk-slave-delay is running.
is($output, $pid, 'PID file has correct PID');

# Kill it
diag(`kill $pid`);
sleep 1;
ok(! -f '/tmp/mk-slave-delay.pid', 'PID file removed');

# #############################################################################
# Issue 149: h is required even with S, for slavehost argument
# #############################################################################
$output = `../mk-slave-delay --time 1s --delay 1s --interval 1s S=/tmp/12346/mysql_sandbox12346.sock 2>&1`;
unlike($output, qr/Missing DSN part 'h'/, 'Does not require h DSN part');

exit;
