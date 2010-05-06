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
   plan tests => 16;
}

my $output;
my $rows;
my $dsn  = "h=127.1,u=msandbox,p=msandbox";
my $cmd  = "$trunk/util/mysql-rmf/mysql-replication-monitor";
my @args = ();

$sb->create_dbs($master_dbh, [qw(test)]);
$master_dbh->do('DROP TABLE IF EXISTS test.servers');
$master_dbh->do('DROP TABLE IF EXISTS test.state');

# #############################################################################
# First some option sanity checks.
# #############################################################################
like(
   `$cmd`,
   qr/Required option --monitor must be specified/,
   "Requires --monitor"
);

like(
   `$cmd`,
   qr/Required option --update must be specified/,
   "Requires --update"
);

like(
   `$cmd --update h=foo,D=foo,t=foo --monitor localhost`,
   qr/--monitor DSN does not specify a table/,
   "Requires --monitor DSN to have database and table"
);

like(
   `$cmd --monitor h=foo,D=foo,t=foo --update localhost`,
   qr/--update DSN does not specify a table/,
   "Requires --update DSN to have database and table"
);

# #############################################################################
# Test --create-*-table and --run-once.
# #############################################################################
my $timeout = wait_for(
   sub { mysql_replication_monitor::main(
         '--monitor', "$dsn,P=12345,t=test.servers",
         '--update',  "$dsn,P=12345,t=test.state",
         qw(--create-monitor-table --create-update-table),
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
   '--create-monitor-table'
);

like(
   $master_dbh->selectrow_arrayref('show create table test.state')->[1],
   qr/create table/i,
   '--create-update-table'
);

# Insert a row into each table, run --create-*-table again and make sure
# the tables are only created if they do not exist, i.e. that they're
# not dropped and recreated.

$master_dbh->do("insert into test.servers (server,dsn,mk_heartbeat_file) values ('master', '$dsn,P=12345', '/tmp/mk-heartbeat.master')");
$master_dbh->do("insert into test.state values ('percoabot', 'master', NULL, 'binlog file', 1, 'master', 1, '', 1, 0, 0, 1, 1, 0)");


mysql_replication_monitor::main(
   '--monitor', "$dsn,P=12345,t=test.servers",
   '--update',  "$dsn,P=12345,t=test.state",
   qw(--create-monitor-table --create-update-table),
   qw(--run-once --quiet)
);


$rows = $master_dbh->selectall_arrayref('select * from test.servers');
is(
   scalar @$rows,
   1,
   "--create-monitor-table didn't affect the existing table"
);

$rows = $master_dbh->selectall_arrayref('select * from test.state');
is(
   scalar @$rows,
   1,
   "--create-update-table didn't affect the existing table"
);

$master_dbh->do("truncate table test.state");

# #############################################################################
# Test --quiet.
# #############################################################################
$output = output(
   sub { mysql_replication_monitor::main(
         '--monitor', "$dsn,P=12345,t=test.servers",
         '--update',  "$dsn,P=12345,t=test.state",
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
   sub { mysql_replication_monitor::main(
         '--monitor', "$dsn,P=12345,t=test.servers",
         '--update',  "$dsn,P=12345,t=test.state",
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

system("$cmd --monitor $dsn,P=12345,t=test.servers --update $dsn,P=12345,t=test.state --daemonize --log $log");

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
# Done.
# #############################################################################
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
