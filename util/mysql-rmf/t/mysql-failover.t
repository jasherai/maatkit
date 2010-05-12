#!/usr/bin/env perl

# This tests a topology like,
#   S1   <-  M1  <=>  M2  -> S2    (short names)
#   2902 <- 2900 <=> 2901 -> 2903  (ports)
# with IDEMPOTENT RBR.  (Names in servers table are "server-PORT").
# M1 dies (we stop it) and S1 takes its place.

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

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

# #############################################################################
# Get setup.  Real tests begin at the next section.
# #############################################################################
sub remove_servers {
   foreach my $port ( qw(2900 2901 2902 2903) ) {
      diag(`/tmp/$port/stop >/dev/null 2>&1`);
      diag(`rm -rf /tmp/$port >/dev/null 2>&1`);
      diag(`rm -rf /tmp/heartbeat.$port >/dev/null 2>&1`);
   }
}
remove_servers();

$ENV{BINLOG_FORMAT}='row';
$ENV{SLAVE_EXEC_MODE}='IDEMPOTENT';
$ENV{READ_ONLY}='1';
diag(`$trunk/sandbox/start-sandbox master-master 2900 2901 >/dev/null`);
diag(`$trunk/sandbox/start-sandbox slave 2902 2900 >/dev/null`);
diag(`$trunk/sandbox/start-sandbox slave 2903 2901 >/dev/null`);

my $dp = new DSNParser(opts=>$dsn_opts);
sub get_cxn {
   my ( $port ) = @_;
   my $dsn = $dp->parse("h=127.1,u=msandbox,p=msandbox,P=$port");
   my $dbh = $dp->get_dbh($dp->get_cxn_params($dsn), {AutoCommit=>1});
   $dbh->{InactiveDestroy} = 1;
   $dbh->{FetchHashKeyName} = 'NAME_lc';
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
   plan tests => 32;
}

my $output;
my $rows;
my $retval;
my $check_logs_dir = '/tmp/checks/';
my $dsn  = "h=127.1,u=msandbox,p=msandbox";
my $args = "--check-logs-dir $check_logs_dir --observer perconabot --mk-heartbeat-dir /tmp --servers $dsn,P=2901,t=repl.servers --state $dsn,P=2901,t=repl.state";
my $cmd  = "$trunk/util/mysql-rmf/mysql-replication-monitor $args";

# Failover tool args and cmd for failing M1.
my $fargs = "--servers F=/tmp/2901/my.sandbox.cnf,t=repl.servers --state F=/tmp/2901/my.sandbox.cnf,t=repl.state --dead-master 'server-2900' --new-master 'server-2902' --live-master 'server-2901'";
my $fcmd  = "$trunk/util/mysql-rmf/mysql-failover $fargs";

diag(`rm -rf $check_logs_dir >/dev/null 2>&1`);
diag(`mkdir $check_logs_dir`);

$m1->do('drop database if exists repl');
$m1->do('create database repl');
$m1->do('drop database if exists new_db');

# Create the servers and state tables.
`$cmd --create-servers-table --create-state-table --servers $dsn,P=2900,t=repl.servers --state $dsn,P=2900,t=repl.state --run-once --quiet`;
my $sql = "insert into repl.servers values ";
my @vals;
foreach my $port ( qw(2900 2901 2902 2903) ) {
   push @vals, "('server-$port', '$dsn,P=$port', 'heartbeat.$port', null)";
}
$sql .= join(',', @vals);
$m1->do($sql);
$rows = $m1->selectall_arrayref('select * from repl.servers order by server');
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

# #############################################################################
# Finally ready to work.  First step: do 2 mysql-replication-monitor checks.
# Everything should be ok at this point.
# #############################################################################

# Check one.
$retval = system("$cmd --run-once --quiet");
is(
   $retval >> 8,
   0,
   "Check one ok"
);
sleep 1;  # ts resolution in state table is 1 second

# Check two.
$retval = system("$cmd --run-once --quiet");
is(
   $retval >> 8,
   0,
   "Check two ok"
);
sleep 1;

$rows = $m1->selectall_arrayref('select server, connection_ok, slave_sql_running, slave_io_running from repl.state where 1=1 order by server');
is_deeply(
   $rows,
   [
      ['server-2900',1,1,1], ['server-2900',1,1,1],
      ['server-2901',1,1,1], ['server-2901',1,1,1],
      ['server-2902',1,1,1], ['server-2902',1,1,1],
      ['server-2903',1,1,1], ['server-2903',1,1,1],
   ],
   "Two checks, all servers ok"
);

# #############################################################################
# Test that failover won't happen (without --force) if the dead master does
# not appear to be dead to all observers.
# #############################################################################
$output = `$fcmd --dry-run`;
like(
   $output,
   qr/dead master completely dead: no.+?new master ok: yes.+?No failover/ms,
   "Doesn't failover if dead master isn't dead"
);

# #############################################################################
# Before stopping M1 to simulate its death, get the status of S1, M1 and M2
# and check that they're all in sync.  Later we should failover and start
# S1 and M2 at pos <= this point, M1's time of death.
# #############################################################################
my $s1_master_status = $s1->selectrow_hashref('show master status');
my $s1_slave_status  = $s1->selectrow_hashref('show slave status');
my $m1_master_status = $m1->selectrow_hashref('show master status');
my $m1_slave_status  = $m1->selectrow_hashref('show slave status');
my $m2_master_status = $m2->selectrow_hashref('show master status');
my $m2_slave_status  = $m2->selectrow_hashref('show slave status');

is(
   $s1_slave_status->{exec_master_log_pos},
   $m1_master_status->{position},
   "S1 caught up to M1 ($m1_master_status->{position})"
);

is(
   $m1_slave_status->{exec_master_log_pos},
   $m2_master_status->{position},
   "M1 caught up to M2 ($m2_master_status->{position})"
);

is(
   $m2_slave_status->{exec_master_log_pos},
   $m1_master_status->{position},
   "M2 caught up to M1 ($m1_master_status->{position})"
);

# #############################################################################
# Kill M1.
# #############################################################################
$m1->disconnect();
diag(`/tmp/2900/stop >/dev/null`);

# #############################################################################
# Verify that S1 and M2 SLAVE STATUS show that M1 has gone away.
# #############################################################################
$rows = $s1->selectrow_hashref('show slave status');
is(
   $rows->{slave_io_running},
   'No',
   "IO thread not running on S1"
);

is(
   $rows->{master_port},
   2900,
   "S1 still slaved to M1"
);

$rows = $s1->selectall_arrayref('show processlist');
$retval = grep { $_->[4] eq 'Binlog Dump' } @$rows;
is(
   $retval,
   0,
   "S1 is not a master (no Binlog Dump command)"
);

$rows = $m2->selectrow_hashref('show slave status');
is(
   $rows->{slave_io_running},
   'No',
   "IO thread not running on M2"
);

is(
   $rows->{master_port},
   2900,
   "M2 still slaved to M1"
);


# #############################################################################
# Check that slave is read-only before failover.
# #############################################################################
is_deeply(
   $s1->selectrow_arrayref('SELECT @@read_only'),
   [1],
   "S1 is read-only"
);

# #############################################################################
# Do a third check, get the state history of S1, M1 and M2 and test that
# they show a dead M1.
# #############################################################################

# Check three.
$retval = system("$cmd --run-once --quiet");
is(
   $retval >> 8,
   1,
   "Check three exit 1 for dead master"
);

my $sth = $m2->prepare("select * from repl.state where server=? order by ts asc");
$sth->execute('server-2900');
my @m1_state;
while ( my $row = $sth->fetchrow_hashref() ) {
   push @m1_state, $row;
}
$sth->execute('server-2902');
my @s1_state;
while ( my $row = $sth->fetchrow_hashref() ) {
   push @s1_state, $row;
}
$sth->execute('server-2901');
my @m2_state;
while ( my $row = $sth->fetchrow_hashref() ) {
   push @m2_state, $row;
}

is(
   $m1_state[-1]->{connection_ok},
   0,
   "M1 dead in last check"
);

is(
   $s1_state[-1]->{slave_io_running},
   0,
   "S1 IO not running in last check"
);

is(
   $m2_state[-1]->{slave_io_running},
   0,
   "M2 IO not running in last check"
);

# #############################################################################
# Now that M1 is dead, S1 should not receive changes written to M2.  So
# write something to M2 and test that it does not appear on S1.  Later
# we'll use this new db.tbl to confirm that S1 gets connect to M2 properly;
# if it does, it will get this new db.tbl.
# #############################################################################
$m2->do('create database new_db');
$m2->do('create table new_db.new_tbl (i int)');
$m2->do('insert into new_db.new_tbl values (42)');
sleep 1;

$rows = $s1->selectall_arrayref('show databases like "new_db"');
is_deeply(
   $rows,
   [],
   "Write to M2 did not replicate to S1"
);

# Double check that S2 gets the new db.tbl.
$rows = $s2->selectall_arrayref('show databases like "new_db"');
is_deeply(
   $rows,
   [['new_db']],
   "Write to M2 did replicate to S2"
);

# #############################################################################
# Do a dry run failover.  It should work now that M1 is dead and the state
# table confirms that.
# #############################################################################
$output = `$fcmd --dry-run`;
like(
   $output,
   qr/Failover procedure complete/,
   "Failover procedure complete (dry run)"
);

like(
   $output,
   qr/SELECT MASTER_POS_WAIT\('mysql-bin.000001', $s1_slave_status->{read_master_log_pos}, 60\) \/\* server-2902 \*\//,
   "MATER_POS_WAIT() on S1"
);

like(
   $output,
   qr/SELECT MASTER_POS_WAIT\('mysql-bin.000001', $m2_slave_status->{read_master_log_pos}, 60\) \/\* server-2901 \*\//,
   "MATER_POS_WAIT() on M2"
);

like(
   $output,
   qr/CHANGE MASTER TO MASTER_HOST='127.0.0.1', MASTER_PORT=2901, MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=$m1_state[-2]->{exec_master_log_pos} \/\* server-2902 \*\//,
   "CHANGE S1 MASTER TO M2"
);

like(
   $output,
   qr/CHANGE MASTER TO MASTER_HOST='127.1', MASTER_PORT=2902, MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=$s1_master_status->{position} \/\* server-2901 \*\//,
   "CHANGE M2 MASTER TO S1"
);

# #############################################################################
# Do the real failover.
# #############################################################################
$output = `$fcmd`;
# print $output;

# #############################################################################
# Verify that the setup has become S1 <=> M2 and the servers are running
# as slaves.
# #############################################################################
$rows = $s1->selectrow_hashref('show slave status');
is(
   $rows->{slave_io_running},
   'Yes',
   "IO thread running on S1"
);

is(
   $rows->{master_port},
   2901,
   "S1 slaved to M2"
);

$rows = $s1->selectall_arrayref('show processlist');
$retval = grep { $_->[4] eq 'Binlog Dump' } @$rows;
is(
   $retval,
   1,
   "S1 is a master (has a Binlog Dump command)"
);

$rows = $m2->selectrow_hashref('show slave status');
is(
   $rows->{slave_io_running},
   'Yes',
   "IO thread running on M2"
);

is(
   $rows->{master_port},
   2902,
   "M2 slaved to S1"
);

# #############################################################################
# Double check new S1 <=> M2 setup by looking for the new_db.new_tbl
# written to M2 after M1 died.  It should have replicated to S1 now.
# #############################################################################
sleep 1;
$rows = $s1->selectall_arrayref('select * from new_db.new_tbl');
is_deeply(
   $rows,
   [[42]],
   "S1 got new data written to M2 after M1 died"
);

# #############################################################################
# Check that slave is not read-only after failover.
# #############################################################################
is_deeply(
   $s1->selectrow_arrayref('SELECT @@read_only'),
   [0],
   "S1 is not read-only"
);

# #############################################################################
# Done.
# #############################################################################
remove_servers();
diag(`rm -rf $check_logs_dir >/dev/null 2>&1`);
exit;
