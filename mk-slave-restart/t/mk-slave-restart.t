#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 7;

diag(`../../sandbox/stop_all`);
diag(`../../sandbox/make_sandbox 12345`);
diag(`../../sandbox/make_slave 12346`);

`/tmp/12345/use -e 'create database test; create table test.t(a int)'`;
sleep 1;

# Bust replication
print `/tmp/12346/use -e 'drop table test.t'`;
print `/tmp/12345/use -e 'insert into test.t select 1'`;
my $output = `/tmp/12346/use -e 'show slave status'`;
like($output, qr/Table 'test.t' doesn't exist'/, 'It is busted');

# Start an instance
print `perl ../mk-slave-restart -M .25 -h 127.0.0.1 -u msandbox -p msandbox -P 12346 --daemonize --pid /tmp/mk-slave-restart.pid`;
$output = `ps -eaf | grep 'perl ../mk-slave-restart' | grep -v grep | grep -v mk-slave-restart.t`;
like($output, qr/mk-slave-restart -M/, 'It lives');

unlike($output, qr/Table 'test.t' doesn't exist'/, 'It is not busted');

ok(-f '/tmp/mk-slave-restart.pid', 'PID file created');
my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-slave-restart.pid`;
is($output, $pid, 'PID file has correct PID');

print `perl ../mk-slave-restart --stop`;
sleep 1;
$output = `ps -eaf | grep mk-slave-restart | grep -v grep`;
unlike($output, qr/mk-slave-restart -M/, 'It is dead');
print `rm /tmp/mk-slave-re*`;

ok(! -f '/tmp/mk-slave-restart.pid', 'PID file removed');


diag(`../../sandbox/stop_all`);
exit;
