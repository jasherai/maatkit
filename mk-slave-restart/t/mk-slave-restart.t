#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 12;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $master_dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $slave_dbh  = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

$sb->create_dbs($master_dbh, ['test']);
$master_dbh->do('CREATE TABLE test.t (a INT)');
sleep 1; # wait for that CREATE TABLE to replicate

# Bust replication
$slave_dbh->do('DROP TABLE test.t');
$master_dbh->do('INSERT INTO test.t SELECT 1');
my $output = `/tmp/12346/use -e 'show slave status'`;
like($output, qr/Table 'test.t' doesn't exist'/, 'It is busted');

# Start an instance
diag(`perl ../mk-slave-restart --max-sleep .25 -h 127.0.0.1 -P 12346 --daemonize --pid /tmp/mk-slave-restart.pid --log /tmp/mk-slave-restart.log`);
$output = `ps -eaf | grep 'perl ../mk-slave-restart' | grep -v grep | grep -v mk-slave-restart.t`;
like($output, qr/mk-slave-restart --max/, 'It lives');

unlike($output, qr/Table 'test.t' doesn't exist'/, 'It is not busted');

ok(-f '/tmp/mk-slave-restart.pid', 'PID file created');
ok(-f '/tmp/mk-slave-restart.log', 'Log file created');

my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-slave-restart.pid`;
is($output, $pid, 'PID file has correct PID');

diag(`perl ../mk-slave-restart --stop -q`);
sleep 1;
$output = `ps -eaf | grep mk-slave-restart | grep -v grep`;
unlike($output, qr/mk-slave-restart --max/, 'It is dead');

diag(`rm -f /tmp/mk-slave-re*`);
ok(! -f '/tmp/mk-slave-restart.pid', 'PID file removed');

# #############################################################################
# Issue 118: mk-slave-restart --error-numbers option is broken
# #############################################################################
$output = `../mk-slave-restart --stop --sentinel /tmp/mk-slave-restartup --error-numbers=1205,1317`;
like($output, qr{Successfully created file /tmp/mk-slave-restartup}, '--error-numbers works (issue 118)');

diag(`rm -f /tmp/mk-slave-re*`);

# #############################################################################
# Issue 459: mk-slave-restart --error-text is broken
# #############################################################################
# Bust replication again.  At this point, the master has test.t but
# the slave does not.
$master_dbh->do('DROP TABLE IF EXISTS test.t');
$master_dbh->do('CREATE TABLE test.t (a INT)');
sleep 1;
$slave_dbh->do('DROP TABLE test.t');
$master_dbh->do('INSERT INTO test.t SELECT 1');
$output = `/tmp/12346/use -e 'show slave status'`;
like(
   $output,
   qr/Table 'test.t' doesn't exist'/,
   'It is busted again'
);

# Start an instance
$output = `perl ../mk-slave-restart --max-sleep .25 -h 127.0.0.1 -P 12346 --error-text "doesn't exist" --run-time 1s 2>&1`;
unlike(
   $output,
   qr/Error does not match/,
   '--error-text works (issue 459)'
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `../mk-slave-restart --max-sleep .25 -h 127.0.0.1 -P 12346 --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #############################################################################
# Done.
# #############################################################################
diag(`rm -f /tmp/mk-slave-re*`);
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
