#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/util/mysql-rmf/mysql-replication-monitor";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master');
my $slave_dbh  = $sb->get_dbh_for('slave1');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave1';
}
else {
   plan tests => 23;
}

$master_dbh->{InactiveDestroy} = 1;
$slave_dbh->{InactiveDestroy}  = 1;

my $output;
my $rows;
my $retval;
my $check_logs_dir = '/tmp/checks/';
my $dsn  = "h=127.1,u=msandbox,p=msandbox";
my $cmd  = "$trunk/util/mysql-rmf/mysql-replication-monitor";
my @args = (qw(--check-logs all --check-logs-dir), $check_logs_dir);

diag(`rm -rf $check_logs_dir >/dev/null 2>&1`);
diag(`mkdir $check_logs_dir`);

$sb->create_dbs($master_dbh, [qw(test)]);
$master_dbh->do('DROP TABLE IF EXISTS test.servers');
$master_dbh->do('DROP TABLE IF EXISTS test.state');

# #############################################################################
# First some option sanity checks.
# #############################################################################
like(
   `$cmd`,
   qr/Required option --servers must be specified/,
   "Requires --servers"
);

like(
   `$cmd`,
   qr/Required option --state must be specified/,
   "Requires --state"
);

like(
   `$cmd --state h=foo,D=foo,t=foo --servers localhost`,
   qr/--servers DSN does not specify a table/,
   "Requires --servers DSN to have database and table"
);

like(
   `$cmd --servers h=foo,D=foo,t=foo --state localhost`,
   qr/--state DSN does not specify a table/,
   "Requires --state DSN to have database and table"
);

# #############################################################################
# Test --create-*-table and --run-once.
# #############################################################################
my $timeout = wait_for(
   sub { mysql_replication_monitor::main(@args,
         '--servers', "$dsn,P=12345,t=test.servers",
         '--state',  "$dsn,P=12345,t=test.state",
         qw(--create-servers-table --create-state-table),
         qw(--run-once --quiet)
      );
   },
   5
);

is(
   $timeout,
   0,
   '--run-once'
);

like(
   $master_dbh->selectrow_arrayref('show create table test.servers')->[1],
   qr/create table/i,
   '--create-servers-table'
);

like(
   $master_dbh->selectrow_arrayref('show create table test.state')->[1],
   qr/create table/i,
   '--create-state-table'
);

# Insert a row into each table, run --create-*-table again and make sure
# the tables are only created if they do not exist, i.e. that they're
# not dropped and recreated.

$master_dbh->do("insert into test.servers (server,dsn,mk_heartbeat_file) values ('master', '$dsn,P=12345', '/tmp/mk-heartbeat.master')");
$master_dbh->do("insert into test.state values ('percoabot', 'master', NULL, 'binlog file', 1, 'master', 1, '', 1, 0, 0, 1, 1)");

$retval = mysql_replication_monitor::main(@args,
   '--servers', "$dsn,P=12345,t=test.servers",
   '--state',  "$dsn,P=12345,t=test.state",
   qw(--create-servers-table --create-state-table),
   qw(--run-once --quiet)
);

$rows = $master_dbh->selectall_arrayref('select * from test.servers');
is(
   scalar @$rows,
   1,
   "--create-servers-table didn't affect the existing table"
);

# Should be 2 rows in state table now: the one we manually inserted above
# and the one inserted by calling main().
$rows = $master_dbh->selectall_arrayref('select * from test.state');
is(
   scalar @$rows,
   2,
   "--create-state-table didn't affect the existing table"
);

$master_dbh->do("truncate table test.state");

# #############################################################################
# Test --quiet.
# #############################################################################
$output = output(
   sub { mysql_replication_monitor::main(@args,
         '--servers', "$dsn,P=12345,t=test.servers",
         '--state',  "$dsn,P=12345,t=test.state",
         qw(--run-once),
      );
   }
);

like(
   $output,
   qr/started.+?ended/ms,
   "Verbose output by default"
);

$output = output(
   sub { mysql_replication_monitor::main(@args,
         '--servers', "$dsn,P=12345,t=test.servers",
         '--state',  "$dsn,P=12345,t=test.state",
         qw(--run-once --quiet),
      );
   }
);

is(
   $output,
   '',
   "--quiet"
);

# #############################################################################
# Test --daemonize and --log.
# #############################################################################
my $log = '/tmp/mysql-replication-monitor.log';
diag(`rm -rf $log >/dev/null`);

system("$cmd --servers $dsn,P=12345,t=test.servers --state $dsn,P=12345,t=test.state --daemonize --log $log --check-logs-dir /tmp/checks/");

ok(
   -f $log,
   "--log file created"
);

$output   = `head -n 1 $log`;
my ($pid) = $output =~ m/PID (\d+)/;

ok(
   $pid,
   "Got PID $pid from log file"
);

my $pid_is_alive = kill 0, $pid;
ok(
   $pid_is_alive,
   "Tool is alive"
);

kill 15, $pid;
sleep 1;
kill 15, $pid;

$pid_is_alive = kill 0, $pid;
ok(
   $pid_is_alive,
   "Tool terminated"
);

$output = `tail -n 1 $log`;
like(
   $output,
   qr/Exiting on SIGTERM/,
   "Exit on SIGTERM logged"
);

diag(`rm -rf $log >/dev/null`);

# #############################################################################
# Test real_lag with mk-heartbeat.
# #############################################################################
$master_dbh->do('TRUNCATE TABLE test.servers');
$master_dbh->do('TRUNCATE TABLE test.state');
diag(`rm -rf $check_logs_dir/* >/dev/null 2>&1`);

my $mkhb_update_pid  = '/tmp/mkhb-update.pid';
my $mkhb_monitor_pid = '/tmp/mkhb-monitor.pid';
my $mkhb_file        = '/tmp/mk-heartbeat.slave';

$master_dbh->do("insert into test.servers (server,dsn,mk_heartbeat_file) values ('slave', '$dsn,P=12346', 'mk-heartbeat.slave')");

system("$trunk/mk-heartbeat/mk-heartbeat -D test --update --create-table F=/tmp/12345/my.sandbox.cnf --daemonize --pid $mkhb_update_pid 1>/dev/null 2>/dev/null");

system("$trunk/mk-heartbeat/mk-heartbeat -D test --monitor h=127.1,P=12346,u=msandbox,p=msandbox --pid $mkhb_monitor_pid --file $mkhb_file --daemonize 1>/dev/null 2>/dev/null");

sleep 2;

ok(
   -f $mkhb_update_pid,
   "mk-heartbeat --update is running"
);

ok(
   -f $mkhb_monitor_pid,
   "mk-heartbeat --update is running"
);

ok(
   -f $mkhb_file,
   "Heartbeat file created"
);

mysql_replication_monitor::main(@args,
   '--servers', "$dsn,P=12345,t=test.servers",
   '--state',  "$dsn,P=12345,t=test.state",
   qw(--mk-heartbeat-dir /tmp),
   qw(--run-once --quiet));

diag(`touch /tmp/mk-heartbeat-sentinel`);
sleep 1;

is(
   $master_dbh->selectrow_arrayref("select real_lag from test.state where server='slave'")->[0],
   0,
   "Set real_lag in state table"
);

diag(`rm -rf /tmp/mk-heartbeat-sentinel`);
diag(`rm -rf $mkhb_file`);


# #############################################################################
# Test --run-time and --interval.
# #############################################################################
$output = '/tmp/mrf.txt';

# If that looks confusing it does this: runs main(), capturing output()
# to file=>$output, all inside wait_for() on a 5s timer.  We want to test
# that main() finishes in --run-time where --run-time is < 5s and test
# that the output logged multiple checks given --interval 1.
$timeout = wait_for(
   sub {
      output(
         sub {
            $retval = mysql_replication_monitor::main(@args,
               '--servers', "$dsn,P=12345,t=test.servers",
               '--state',  "$dsn,P=12345,t=test.state",
               qw(--run-time 3 --interval 1));
         },
         $output
      ),
   },
   5,
);

ok(
   !$timeout,
   "Ran for --run-time 3"
);

is(
   $retval,
   0,
   "Exit status 0"
);

# reuse $retval
chomp($retval = `cat $output | grep -c 'End check number'`);
ok(
   $retval > 1 && $retval <= 3,
   "Ran $retval checks for --run-time 3 --interval 1"
);

diag(`rm -rf $output >/dev/null`);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $check_logs_dir >/dev/null 2>&1`);
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
