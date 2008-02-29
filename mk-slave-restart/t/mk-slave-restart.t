#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw('-no_match_vars);
use Test::More tests => 5;

my $output = `perl ../mk-slave-restart --help`;
like($output, qr/Prompt for a password/, 'It compiles');

print `./make_repl_sandbox`;
print `/tmp/12345/use -e 'create database test; create table test.t(a int)'`;
sleep 1;

# Bust replication
print `/tmp/12346/use -e 'drop table test.t'`;
print `/tmp/12345/use -e 'insert into test.t select 1'`;
$output = `/tmp/12346/use -e 'show slave status'`;
like($output, qr/Table 'test.t' doesn't exist'/, 'It is busted');


# Start an instance
print `perl ../mk-slave-restart -M .25 -h 127.0.0.1 -u msandbox -p msandbox -P 12346 --daemonize`;
$output = `ps -eaf | grep mk-slave-restart | grep -v grep`;
like($output, qr/mk-slave-restart -M/, 'It lives');

unlike($output, qr/Table 'test.t' doesn't exist'/, 'It is not busted');

print `perl ../mk-slave-restart --stop`;
sleep 1;
$output = `ps -eaf | grep mk-slave-restart | grep -v grep`;
unlike($output, qr/mk-slave-restart -M/, 'It is dead');
print `rm /tmp/mk-slave-re*`;
