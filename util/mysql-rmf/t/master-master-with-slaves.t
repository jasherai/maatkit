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
require "$trunk/util/mysql-rmf/mysql-replication-monitor";

# This tests a topology like, S1 <- M1 <=> M2 -> S2, with IDEMPOTENT RBR.

my $dp = new DSNParser(opts=>$dsn_opts);

sub remove_servers {
   foreach my $port ( qw(2900 2901 2902 2903) ) {
      diag(`/tmp/$port/stop >/dev/null 2>&1`);
      diag(`rm -rf /tmp/$port >/dev/null 2>&1`);
      diag(`rm -rf /tmp/heartbeat.$port >/dev/null 2>&1`);
   }
}

$ENV{BINLOG_FORMAT}='row';
$ENV{SLAVE_EXEC_MODE}='IDEMPOTENT';

remove_servers();
diag(`$trunk/sandbox/start-sandbox master-master 2900 2901 >/dev/null`);
diag(`$trunk/sandbox/start-sandbox slave 2902 2900 >/dev/null`);
diag(`$trunk/sandbox/start-sandbox slave 2903 2901 >/dev/null`);

sub get_cxn {
   my ( $port ) = @_;
   my $dsn = $dp->parse("h=127.1,u=msandbox,p=msandbox,P=$port");
   my $dbh = $dp->get_dbh($dp->get_cxn_params($dsn), {AutoCommit=>1});
   $dbh->{InactiveDestroy} = 1;
   return $dbh;
}

my $m1 = get_cxn(2900);
my $m2 = get_cxn(2901);
my $s1 = get_cxn(2902);
my $s2 = get_cxn(2903);

if ( !($m1 && $m2 && $s1 && $s2) ) {
   plan skip_all => 'Cannot connect to all sandbox servers';
}
else {
   plan tests => 14;
}

my $output;
my $rows;
my $retval;
my $check_logs_dir = '/tmp/checks/';
my $dsn  = "h=127.1,u=msandbox,p=msandbox";
my $args = "--check-logs all --check-logs-dir $check_logs_dir --observer perconabot --mk-heartbeat-dir /tmp";
my $cmd  = "$trunk/util/mysql-rmf/mysql-replication-monitor $args";

diag(`rm -rf $check_logs_dir >/dev/null 2>&1`);
diag(`mkdir $check_logs_dir`);

$m1->do('drop database if exists repl');
$m1->do('create database repl');

# Create the servers and state tables.
`$cmd --create-servers-table --create-state-table --servers $dsn,P=2900,t=repl.servers --state $dsn,P=2900,t=repl.state --run-once --quiet`;

my $sql = "insert into repl.servers values ";
my @vals;
foreach my $port ( qw(2900 2901 2902 2903) ) {
   push @vals, "('server-$port', '$dsn,P=$port', 'heartbeat.$port', null)";
}
$sql .= join(',', @vals);
$m1->do($sql);

# Start heartbeat on m1.
system("$trunk/mk-heartbeat/mk-heartbeat -D repl --create-table --update $dsn,P=2900 --daemonize --pid /tmp/mk-heartbeat.pid >/dev/null 2>&1");

# Start heartbeat monitors for each server.
foreach my $port ( qw(2900 2901 2902 2903) ) {
   system("$trunk/mk-heartbeat/mk-heartbeat -D repl --monitor $dsn,P=$port --daemonize --pid /tmp/mk-heartbeat-$port.pid --file /tmp/heartbeat.$port >/dev/null 2>&1");
}

sleep 2;

# Check that we're up and running.
$rows = $s2->selectall_arrayref('select * from repl.servers order by server');
is_deeply(
   $rows,
   [
      ['server-2900','h=127.1,u=msandbox,p=msandbox,P=2900','heartbeat.2900',undef],
      ['server-2901','h=127.1,u=msandbox,p=msandbox,P=2901','heartbeat.2901',undef],
      ['server-2902','h=127.1,u=msandbox,p=msandbox,P=2902','heartbeat.2902',undef],
      ['server-2903','h=127.1,u=msandbox,p=msandbox,P=2903','heartbeat.2903',undef],
   ],
   "Populated servers table"
);

ok(
      -f "/tmp/heartbeat.2900" && -f "/tmp/mk-heartbeat-2900.pid"
   && -f "/tmp/heartbeat.2901" && -f "/tmp/mk-heartbeat-2901.pid"
   && -f "/tmp/heartbeat.2902" && -f "/tmp/mk-heartbeat-2902.pid"
   && -f "/tmp/heartbeat.2903" && -f "/tmp/mk-heartbeat-2903.pid",
   "mk-heartbeat instances running"
);

# Run the tool.
$output = `$cmd --servers $dsn,P=2900,t=repl.servers --state $dsn,P=2900,t=repl.state --run-once`;

# We can't select the ts or any log pos related columsn because
# they're non-deterministic.
$rows = $m1->selectall_arrayref('select observer,server,file,master_host,master_port,master_log_file,seconds_behind_master,slave_io_running,slave_sql_running,real_lag from repl.state order by server');
is_deeply(
   $rows,
   [
      ['perconabot', 'server-2900', 'mysql-bin.000001', '127.0.0.1', '2901', 'mysql-bin.000001', '0', '1', '1', '0'],
      ['perconabot', 'server-2901', 'mysql-bin.000001', '127.0.0.1', '2900', 'mysql-bin.000001', '0', '1', '1', '0'],
      ['perconabot', 'server-2902', 'mysql-bin.000001', '127.0.0.1', '2900', 'mysql-bin.000001', '0', '1', '1', '0'],
      ['perconabot', 'server-2903', 'mysql-bin.000001', '127.0.0.1', '2901', 'mysql-bin.000001', '0', '1', '1', '0'],
   ],
   'Updated state table for all servers'
);

$m1->do('truncate table repl.state');
diag(`rm -rf /tmp/mrf.log /tmp/mrf.pid >/dev/null 2>&1`);

system("$cmd --servers $dsn,P=2900,t=repl.servers --state $dsn,P=2900,t=repl.state --daemonize --pid /tmp/mrf.pid --log /tmp/mrf.log --run-time 3 --interval 1 >/dev/null 2>&1");

sleep 1;

ok(
   -f "/tmp/mrf.pid",
   "Tool is running daemonized"
);

ok(
   -f "/tmp/mrf.log",
   "Created its log file"
);

sleep 3;
$rows = $s2->selectall_arrayref('select connection_ok from repl.state order by server');
# Sometimes the 3s run does 2 checks and sometimes it does 3.  
ok(
   @$rows == 8 || @$rows == 12,
   "Updated state table several times"
);

is(
   $rows->[0]->[0],
   1,
   "connection_ok=1"
);

ok(
   !-f "/tmp/mrf.pid",
   "Removed its PID file"
);

like(
   `tail -n 1 /tmp/mrf.log`,
   qr/ended, exit status 0/,
   "Wrote to its log file"
);


# #############################################################################
# Stop M2 and test that tool continues to work.
# #############################################################################
$m1->do('truncate table repl.state');
diag(`rm -rf /tmp/mrf.log`);
diag(`rm -rf $check_logs_dir/*`);

diag(`/tmp/2901/stop >/dev/null`);

$retval = system("$cmd --servers $dsn,P=2900,t=repl.servers --state $dsn,P=2900,t=repl.state --run-once > /tmp/mrf.log");

is(
   $retval >> 8,
   1,
   "Exit status 1"
);

ok(
   `grep "finished checking server-2901, exit status 1" /tmp/mrf.log`,
   "Logged that M2 check failed, exit status 1"
);

$rows = $m1->selectall_arrayref('select connection_ok from repl.state where server="server-2901"');
is_deeply(
   $rows,
   [[0]],
   "connection_ok=0 row in state table for dead M2"
);

diag(`rm -rf /tmp/mrf.log`);
diag(`/tmp/2901/start >/dev/null`);

# #############################################################################
# Turn off slave2's io thread, see that this gets logged.
# #############################################################################
$m1->do('truncate table repl.state');
diag(`rm -rf $check_logs_dir/*`);
$s2->do('slave stop io_thread');

$retval = system("$cmd --servers $dsn,P=2900,t=repl.servers --state $dsn,P=2900,t=repl.state --run-once > /tmp/mrf.log");

$rows = $m1->selectall_arrayref('select slave_io_running, slave_sql_running from repl.state where server="server-2903"');
is_deeply(
   $rows,
   [[0, 1]],
   "Catches stopped slave IO thread"
);

$s2->do('slave start io_thread');
sleep 1;
$retval = system("$cmd --servers $dsn,P=2900,t=repl.servers --state $dsn,P=2900,t=repl.state --run-once > /tmp/mrf.log");

$rows = $m1->selectall_arrayref('select slave_io_running, slave_sql_running from repl.state where server="server-2903" order by ts asc');
is_deeply(
   $rows,
   [[0, 1], [1, 1]],
   "Catches that slave IO thread started again"
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf /tmp/mrf.log`);
diag(`touch /tmp/mk-heartbeat-sentinel`);
diag(`touch /tmp/mysql-replication-monitor-sentinel`);
sleep 2;
diag(`rm -rf /tmp/mk-heartbeat-sentinel`);
diag(`rm -rf /tmp/mysql-replication-monitor-sentinel`);
remove_servers();
diag(`rm -rf $check_logs_dir >/dev/null 2>&1`);
exit;
