#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 13;

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
my $cmd = '../mk-slave-delay --delay 1m --interval 15s --run-time 10m --daemonize --pid /tmp/mk-slave-delay.pid h=127.1,P=12346';
diag(`$cmd 1>/dev/null 2>/dev/null`);
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
sleep 2;
ok(! -f '/tmp/mk-slave-delay.pid', 'PID file removed');

# #############################################################################
# Issue 149: h is required even with S, for slavehost argument
# #############################################################################
$output = `../mk-slave-delay --run-time 1s --delay 1s --interval 1s S=/tmp/12346/mysql_sandbox12346.sock 2>&1`;
unlike($output, qr/Missing DSN part 'h'/, 'Does not require h DSN part');

# #############################################################################
# Issue 215.  Specify SLAVE-HOST and MASTER-HOST, but MASTER-HOST does not have
# binary logging turned on, so SHOW MASTER STATUS is empty.  (This happens quite
# easily when you connect to a SLAVE-HOST twice by accident.)  To reproduce,
# just disable log-bin and log-slave-updates on the slave.
# #############################################################################
diag `sed -i '/log.bin\\|log.slave/d' /tmp/12346/my.sandbox.cnf`;
diag `/tmp/12346/stop; /tmp/12346/start;`;
$output = `../mk-slave-delay --delay 1s h=127.1,P=12346 h=127.1 2>&1`;
like($output, qr/Binary logging is disabled/,
   'Detects master that is not a master');
diag `/tmp/12346/stop; rm -rf /tmp/12346; ../../sandbox/make_slave 12346`;

# #############################################################################
# Check that SLAVE-HOST can be given by cmd line opts.
# #############################################################################
$output = `../mk-slave-delay --run-time 1s --interval 1s --host 127.1 --port 12346`;
sleep 1;
like(
   $output,
   qr/slave running /,
   'slave host given by cmd line opts'
);

# And check issue 248: that the slave host will inhert from --port, etc.
$output = `../mk-slave-delay --run-time 1s --interval 1s 127.1 --port 12346`;
sleep 1;
like(
   $output,
   qr/slave running /,
   'slave host inherits --port, etc. (issue 248)'
);

# #############################################################################
# Check --use-master
# #############################################################################
$output = `../mk-slave-delay --run-time 1s --interval 1s --use-master --host 127.1 --port 12346`;
sleep 1;
like(
   $output,
   qr/slave running /,
   '--use-master'
);

$output = `../mk-slave-delay --run-time 1s --interval 1s --use-master --host 127.1 --port 12345 2>&1`;
like(
   $output,
   qr/No SLAVE STATUS found/,
   'No SLAVE STATUS on master'
);

# #############################################################################
# Check --log.
# #############################################################################
`../mk-slave-delay --run-time 1s --interval 1s -h 127.1 -P 12346 --log /tmp/mk-slave-delay.log --daemonize`;
sleep 2;
$output = `cat /tmp/mk-slave-delay.log`;
`rm -f /tmp/mk-slave-delay.log`;
like(
   $output,
   qr/slave running /,
   '--log'
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `../mk-slave-delay --run-time 1s --interval 1s --use-master --host 127.1 --port 12346 --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
exit;
