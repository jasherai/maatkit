#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 5;

my $output = `perl ../mk-slave-delay --help`;
like($output, qr/Prompt for a password/, 'It compiles');

# TODO: comparatively hard to set up replication tests :-(

diag(`../../sandbox/stop_all`);
diag(`../../sandbox/make_sandbox 12345`);
diag(`../../sandbox/make_slave   12346`);

my $cmd = '../mk-slave-delay --delay 1m --interval 15s --time 10m --daemonize --pid /tmp/mk-slave-delay.pid h=127.1,P=12346';

`$cmd`;

# Check daemonization
$output = `ps -eaf | grep 'mk-slave-delay \-\-delay'`;
like($output, qr/$cmd/, 'It lives daemonized');

ok(-f '/tmp/mk-slave-delay.pid', 'PID file created');
my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-slave-delay.pid`;
is($output, $pid, 'PID file has correct PID');

# Kill it
`kill $pid`;
sleep 1;
ok(! -f '/tmp/mk-slave-delay.pid', 'PID file removed');

diag(`../../sandbox/stop_all`);
exit;
