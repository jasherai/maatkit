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

my $output = `perl ../mk-slave-prefetch --help`;
like($output, qr/Prompt for a password/, 'It compiles');

# Cannot daemonize and debug
$output = `MKDEBUG=1 ../mk-slave-prefetch --daemonize 2>&1`;
like($output, qr/Cannot debug while daemonized/, 'Cannot debug while daemonized');

my $cmd = '../mk-slave-prefetch -F /tmp/12346/my.sandbox.cnf --daemonize --pid /tmp/mk-slave-prefetch.pid';

`$cmd`;

# Check daemonization
$output = `ps -eaf | grep 'mk-slave-prefetch \-F'`;
like($output, qr/$cmd/, 'It lives daemonized');

ok(-f '/tmp/mk-slave-prefetch.pid', 'PID file created');
my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-slave-prefetch.pid`;
is($output, $pid, 'PID file has correct PID');

# Kill it
`kill $pid`;
sleep 1;
ok(! -f '/tmp/mk-slave-prefetch.pid', 'PID file removed');

exit;
