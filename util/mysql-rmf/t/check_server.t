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

my $o  = new OptionParser(description=>'foo');
my $q  = new Quoter();
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
   plan tests => 13;
}

my $output;
my $rows;
my $dsn  = "h=127.1,u=msandbox,p=msandbox";
my $cmd  = "$trunk/util/mysql-rmf/mysql-replication-monitor";

$sb->create_dbs($master_dbh, [qw(test)]);
$master_dbh->do('DROP TABLE IF EXISTS test.servers');
$master_dbh->do('DROP TABLE IF EXISTS test.state');

# #############################################################################
# check_server() is what each child process does to update the state table.
# #############################################################################

# Normally the check log would have the PID of the child proc,
# but we're not forking so it's going to have our PID.  And
# "daniel" is the observer name passed to sub call below.
# diag("PID $PID");
my $check_logs_dir = '/tmp/checks/';
my $check_log      = "$check_logs_dir/daniel.$PID";
diag(`rm -rf $check_logs_dir; mkdir $check_logs_dir`);

$o->get_specs("$trunk/util/mysql-rmf/mysql-replication-monitor");
@ARGV=('--check-logs-dir', $check_logs_dir);
$o->get_opts();

my $server = {
   name => 'master',
   dsn  => {
      h => '127.1',
      P => 12345,
      u => 'msandbox',
      p => 'msandbox',
   },
};

my $update_dsn = {
   h => '127.1',
   P => 12345,
   u => 'msandbox',
   p => 'msandbox',
   t => 'test.state',
};

my %args = (
   server       => $server,
   update_dsn   => $update_dsn,
   observer     => 'daniel',
   OptionParser => $o,
   Quoter       => $q,
   DSNParser    => $dp,
);

# First let's make sure it does crash when the update table doesn't exit.
$output = output(
   sub { mysql_replication_monitor::check_server(%args) },
   undef,
   stderr => 1,
);

ok(
   -f "$check_logs_dir/daniel.$PID",
   "Created and left failed check log"
);

is(
   $output,
   '',
   "Logged all output to check log"
);

ok(
   `cat $check_log | grep 'Got master status: yes'`,
   "Got master status"
);

ok(
   `cat $check_log | grep 'Got slave status: no'`,
   "Did not get slave status"
);

like(
   `cat $check_log | grep exist`,
   qr/Table .+? doesn't exist/,
   "INSERT failed because update table doesn't exist"
);

like(
   `tail -n 1 $check_log`,
   qr/child process ended, exit status 1$/,
   "Ended gracefully, exit status 1"
);

# #############################################################################
# Change --check-logs from default "failed" to "none" and test that
# the check log is deleted.
# #############################################################################
diag(`rm $check_logs_dir/*`);
@ARGV=('--check-logs-dir', $check_logs_dir, '--check-logs', 'none');
$o->get_opts();

mysql_replication_monitor::check_server(%args);

ok(
   !-f "$check_logs_dir/daniel.$PID",
   "Deleted failed check log with --check-logs=none"
);


# #############################################################################
# Create the tables and do a successful run.
# #############################################################################
output(sub {
   mysql_replication_monitor::main(
      '--monitor', "$dsn,P=12345,t=test.servers",
      '--update',  "$dsn,P=12345,t=test.state",
      qw(--create-monitor-table --create-update-table),
      qw(--run-once)
   );
});
sleep 1;

diag(`rm $check_logs_dir/* >/dev/null 2>&1`);
@ARGV=('--check-logs-dir', $check_logs_dir);
$o->get_opts();

# Get master stats before checking server because the INSERT into
# the state table will change Position.
my $mstat = $master_dbh->selectrow_hashref('show master status');

mysql_replication_monitor::check_server(%args);

ok(
   !-f "$check_logs_dir/daniel.$PID",
   "Deleted successful check log"
);

$rows = $master_dbh->selectall_hashref('select * from test.state', 'server');

# ts is non-deterministic so check that it's there then delete it.
ok(
   $rows->{master}->{ts},
   "Set ts column"
);
delete $rows->{master}->{ts};

is_deeply(
   $rows,
   {
      'master' => {
         observer              => 'daniel',
         server                => 'master',
         file                  => $mstat->{File},
         position              => $mstat->{Position},
         # These are all undef because they're from SHOW SLAVE STATUS
         # but we checked a master.
         master_host           => undef,
         master_port           => undef,
         master_log_file       => undef,
         read_master_log_pos   => undef,
         seconds_behind_master => undef,
         slave_io_running      => undef,
         slave_sql_running     => undef,
         real_lag              => undef,
      },
   },
   "Updated state table for master"
);

# Now check the slave.

$server->{name}     = 'slave';
$server->{dsn}->{P} = 12346;

$master_dbh->do('truncate table test.state');

diag(`rm $check_logs_dir/* >/dev/null 2>&1`);
@ARGV=('--check-logs-dir', $check_logs_dir, '--check-logs', 'all');
$o->get_opts();

# Get stats before checking server because the INSERT into
# the state table will change Position.

$mstat    = $slave_dbh->selectrow_hashref('show master status');
my $sstat = $slave_dbh->selectrow_hashref('show slave status');

mysql_replication_monitor::check_server(%args);

$rows = $master_dbh->selectall_hashref('select * from test.state', 'server');

# ts is non-deterministic so check that it's there then delete it.
ok(
   $rows->{slave}->{ts},
   "Set ts column"
);
delete $rows->{slave}->{ts};

is_deeply(
   $rows,
   {
      'slave' => {
         observer              => 'daniel',
         server                => 'slave',
         file                  => $mstat->{File},
         position              => $mstat->{Position},
         master_host           => $sstat->{Master_Host},
         master_port           => $sstat->{Master_Port},
         master_log_file       => $sstat->{Master_Log_File},
         read_master_log_pos   => $sstat->{Read_Master_Log_Pos},
         seconds_behind_master => $sstat->{Seconds_Behind_Master},
         slave_io_running      => 1,
         slave_sql_running     => 1,
         real_lag              => undef,
      },
   },
   "Updated state table for slave"
);

ok(
   -f $check_log,
   "Kept successful check log with --check-logs=all"
);

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf $check_logs_dir >/dev/null 2>&1`);
$sb->wipe_clean($master_dbh);
$sb->wipe_clean($slave_dbh);
exit;
