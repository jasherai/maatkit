#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 7;

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

# Check daemonization.
my $cmd = '../mk-slave-prefetch -F /tmp/12346/my.sandbox.cnf --daemonize --pid /tmp/mk-slave-prefetch.pid --print';
diag(`$cmd 1>/dev/null 2>/dev/null`);
$output = `ps -eaf | grep 'mk-slave-prefetch \-F' | grep -v grep`;
like($output, qr/$cmd/, 'It lives daemonized');
ok(-f '/tmp/mk-slave-prefetch.pid', 'PID file created');

my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-slave-prefetch.pid`;
is($output, $pid, 'PID file has correct PID');

# Kill it by testing --stop.
$output = `../mk-slave-prefetch --stop`;
like(
   $output,
   qr{created file /tmp/mk-slave-prefetch-sentinel},
   'Create sentinel file'
);

sleep 1;
$output = `ps -eaf | grep 'mk-slave-prefetch \-F' | grep -v grep`;
is($output, '', 'Stops for sentinel');
ok(! -f '/tmp/mk-slave-prefetch.pid', 'PID file removed');

`rm -f /tmp/mk-slave-prefetch-sentinel`;

exit;
