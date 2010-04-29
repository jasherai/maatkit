#!/usr/bin/perl

BEGIN {
   die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
   unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 44;

use MasterSlave;
use DSNParser;
use VersionParser;
use Sandbox;
use MaatkitTest;

my $vp = new VersionParser();
my $ms = new MasterSlave(VersionParser => $vp);
my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $slave_dbh  = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

# Create slave2 as slave of slave1.
#diag(`/tmp/12347/stop 2> /dev/null`);
#diag(`rm -rf /tmp/12347 2> /dev/null`);
#diag(`$trunk/sandbox/make_sandbox 12347`);
#diag(`/tmp/12347/use -e "change master to master_host='127.0.0.1', master_log_file='mysql-bin.000001', master_log_pos=0, master_user='msandbox', master_password='msandbox', master_port=12346"`);
#diag(`/tmp/12347/use -e "start slave"`);
my $slave_2_dbh = $sb->get_dbh_for('slave2');
#   or BAIL_OUT('Cannot connect to sandbox slave2');

# Make slave2 slave of master.
#diag(`$trunk/mk-slave-move/mk-slave-move --sibling-of-master h=127.1,P=12347`);

#SKIP: {
#   skip 'idea for future improvement', 3;
#
## Make sure we're messed up nicely.
#my $rows = $master_dbh->selectall_arrayref('SHOW SLAVE HOSTS', {Slice => {}});
#is_deeply(
#   $rows,
#   [
#      {
#         Server_id => '12346',
#         Host      => '127.0.0.1',
#         Port      => '12346',
#         Rpl_recovery_rank => '0',
#         Master_id => '12345',
#      },
#   ],
#   'show slave hosts on master is precisely inaccurate'
#);
#
#$rows = $slave_dbh->selectall_arrayref('SHOW SLAVE HOSTS', {Slice => {}});
#is_deeply(
#   $rows,
#   [
#      {
#         Server_id => '12347',     # This is what's messed up because
#         Host      => '127.0.0.1', # slave2 (12347) was made a slave
#         Port      => '12347',     # of the master (12345), yet here
#         Rpl_recovery_rank => '0', # it still shows as a slave of
#         Master_id => '12346', # <-- slave1 (12346)
#      },
#      {
#         Server_id => '12346',
#         Host      => '127.0.0.1',
#         Port      => '12346',
#         Rpl_recovery_rank => '0',
#         Master_id => '12345',
#      },
#   ],
#   'show slave hosts on slave1 is precisely inaccurate'
#);
#
#$rows = $slave_2_dbh->selectall_arrayref('SHOW SLAVE HOSTS', {Slice => {}});
#is_deeply(
#   $rows,
#   [
#      {
#         Server_id => '12347',     
#         Host      => '127.0.0.1', 
#         Port      => '12347',     # Even slave2 itself is confused about
#         Rpl_recovery_rank => '0', # which sever it is really a slave to:
#         Master_id => '12346', # <-- slave1 (123456) wrong again
#      },
#      {
#         Server_id => '12346',
#         Host      => '127.0.0.1',
#         Port      => '12346',
#         Rpl_recovery_rank => '0',
#         Master_id => '12345',
#      },
#   ],
#   'show slave hosts on slave2 is precisely inaccurate'
#);

# The real picture is:
#    12345
#    +- 12346
#    +- 12347
# And here's what MySQL would have us wrongly see:
#   12345
#   +- 12346
#      +- 12347
#is_deeply(
#   $ms->new_recurse_to_salves(),
#   [
#      '127.0.0.1:12345',
#      [
#         '127.0.0.1:12346',
#         '127.0.0.1:12357',
#      ],
#   ],
#   '_new_rts()'
#);

# Stop and remove slave2.
#diag(`/tmp/12347/stop`);
#diag(`rm -rf /tmp/12347`);
#};

# #############################################################################
# First we need to setup a special replication sandbox environment apart from
# the usual persistent sandbox servers on ports 12345 and 12346.
# The tests in this script require a master with 3 slaves in a setup like:
#    127.0.0.1:master
#    +- 127.0.0.1:slave0
#    |  +- 127.0.0.1:slave1
#    +- 127.0.0.1:slave2
# The servers will have the ports (which won't conflict with the persistent
# sandbox servers) as seen in the %port_for hash below.
# #############################################################################
my %port_for = (
   master => 2900,
   slave0 => 2901,
   slave1 => 2902,
   slave2 => 2903,
);
diag(`$trunk/sandbox/start-sandbox master 2900 >/dev/null`);
diag(`$trunk/sandbox/start-sandbox slave 2903 2900 >/dev/null`);
diag(`$trunk/sandbox/start-sandbox slave 2901 2900 >/dev/null`);
diag(`$trunk/sandbox/start-sandbox slave 2902 2901 >/dev/null`);

# I discovered something weird while updating this test. Above, you see that
# slave2 is started first, then the others. Before, slave2 was started last,
# but this caused the tests to fail because SHOW SLAVE HOSTS on the master
# returned:
# +-----------+-----------+------+-------------------+-----------+
# | Server_id | Host      | Port | Rpl_recovery_rank | Master_id |
# +-----------+-----------+------+-------------------+-----------+
# |      2903 | 127.0.0.1 | 2903 |                 0 |      2900 | 
# |      2901 | 127.0.0.1 | 2901 |                 0 |      2900 | 
# +-----------+-----------+------+-------------------+-----------+
# This caused recurse_to_slaves() to report 2903, 2901, 2902.
# Since the tests are senstive to the order of @slaves, they failed
# because $slaves->[1] was no longer slave1 but slave0. Starting slave2
# last fixes/works around this.

# #############################################################################
# Now the test.
# #############################################################################
my $dbh;
my @slaves;
my @sldsns;

my $dsn = $dp->parse("h=127.0.0.1,P=$port_for{master},u=msandbox,p=msandbox");
$dbh    = $dp->get_dbh($dp->get_cxn_params($dsn), { AutoCommit => 1 });

my $callback = sub {
   my ( $dsn, $dbh, $level, $parent ) = @_;
   return unless $level;
   ok($dsn, "Connected to one slave "
      . ($dp->as_string($dsn) || '<none>')
      . " from $dsn->{source}");
   push @slaves, $dbh;
   push @sldsns, $dsn;
};

my $skip_callback = sub {
   my ( $dsn, $dbh, $level ) = @_;
   return unless $level;
   ok($dsn, "Skipped one slave "
      . ($dp->as_string($dsn) || '<none>')
      . " from $dsn->{source}");
};

$ms->recurse_to_slaves(
   {  dsn_parser    => $dp,
      dbh           => $dbh,
      dsn           => $dsn,
      recurse       => 2,
      callback      => $callback,
      skip_callback => $skip_callback,
   });

is_deeply(
   $ms->get_master_dsn( $slaves[0], undef, $dp ),
   {  h => '127.0.0.1',
      u => undef,
      P => $port_for{master},
      S => undef,
      F => undef,
      p => undef,
      D => undef,
      A => undef,
      t => undef,
   },
   'Got master DSN',
);

# The picture:
# 127.0.0.1:master
# +- 127.0.0.1:slave0
# |  +- 127.0.0.1:slave1
# +- 127.0.0.1:slave2
is($ms->get_slave_status($slaves[0])->{master_port}, $port_for{master}, 'slave 1 port');
is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{slave0}, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');

ok($ms->is_master_of($slaves[0], $slaves[1]), 'slave 1 is slave of slave 0');
eval {
   $ms->is_master_of($slaves[0], $slaves[2]);
};
like($EVAL_ERROR, qr/but the master's port/, 'slave 2 is not slave of slave 0');
eval {
   $ms->is_master_of($slaves[2], $slaves[1]);
};
like($EVAL_ERROR, qr/has no connected slaves/, 'slave 1 is not slave of slave 2');

map { $ms->stop_slave($_) } @slaves;
map { $ms->start_slave($_) } @slaves;

my $res;
$res = $ms->wait_for_master($dbh, $slaves[0], 1, 0);
ok(defined $res && $res >= 0, 'Wait was successful');

$ms->stop_slave($slaves[0]);
$dbh->do('drop database if exists test'); # Any stmt will do
diag(`(sleep 1; echo "start slave" | /tmp/$port_for{slave0}/use)&`);
eval {
   $res = $ms->wait_for_master($dbh, $slaves[0], 1, 0);
};
ok($res, 'Waited for some events');

# Clear any START SLAVE UNTIL conditions.
map { $ms->stop_slave($_) } @slaves;
map { $ms->start_slave($_) } @slaves;
sleep 1;

$ms->stop_slave($slaves[0]);
$dbh->do('drop database if exists test'); # Any stmt will do
eval {
   $res = $ms->catchup_to_master($slaves[0], $dbh, 10);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'No eval error catching up');
my $master_stat = $ms->get_master_status($dbh);
my $slave_stat = $ms->get_slave_status($slaves[0]);
is_deeply(
   $ms->repl_posn($master_stat),
   $ms->repl_posn($slave_stat),
   'Caught up');

eval {
   map { $ms->start_slave($_) } @slaves;
   $ms->make_sibling_of_master($slaves[1], $sldsns[1], $dp, 100);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'Made slave sibling of master');

# Clear any START SLAVE UNTIL conditions.
map { $ms->stop_slave($_) } @slaves;
map { $ms->start_slave($_) } @slaves;

# The picture now:
# 127.0.0.1:master
# +- 127.0.0.1:slave0
# +- 127.0.0.1:slave1
# +- 127.0.0.1:slave2
is($ms->get_slave_status($slaves[0])->{master_port}, $port_for{master}, 'slave 1 port');
is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{master}, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');

eval {
   map { $ms->start_slave($_) } @slaves;
   $ms->make_slave_of_sibling(
      $slaves[0], $sldsns[0],
      $slaves[0], $sldsns[0], $dp, 100);
};
like($EVAL_ERROR, qr/slave of itself/, 'Cannot make slave slave of itself');

eval {
   map { $ms->start_slave($_) } @slaves;
   $ms->make_slave_of_sibling(
      $slaves[0], $sldsns[0],
      $slaves[1], $sldsns[1], $dp, 100);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'Made slave of sibling');

# The picture now:
# 127.0.0.1:master
# +- 127.0.0.1:slave1
# |  +- 127.0.0.1:slave0
# +- 127.0.0.1:slave2
is($ms->get_slave_status($slaves[0])->{master_port}, $port_for{slave1}, 'slave 1 port');
is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{master}, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');

eval {
   map { $ms->start_slave($_) } @slaves;
   $ms->make_slave_of_uncle(
      $slaves[0], $sldsns[0],
      $slaves[2], $sldsns[2], $dp, 100);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'Made slave of uncle');

# The picture now:
# 127.0.0.1:master
# +- 127.0.0.1:slave1
# +- 127.0.0.1:slave2
#    +- 127.0.0.1:slave0
is($ms->get_slave_status($slaves[0])->{master_port}, $port_for{slave2}, 'slave 1 port');
is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{master}, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');

eval {
   map { $ms->start_slave($_) } @slaves;
   $ms->detach_slave($slaves[0]);
};
diag $EVAL_ERROR if $EVAL_ERROR;
ok(!$EVAL_ERROR, 'Detached slave');

# The picture now:
# 127.0.0.1:master
# +- 127.0.0.1:slave1
# +- 127.0.0.1:slave2
is($ms->get_slave_status($slaves[0]), 0, 'slave 1 detached');
is($ms->get_slave_status($slaves[1])->{master_port}, $port_for{master}, 'slave 2 port');
is($ms->get_slave_status($slaves[2])->{master_port}, $port_for{master}, 'slave 3 port');

# #############################################################################
# Test is_replication_thread()
# #############################################################################
my $query = {
   Id      => '302',
   User    => 'msandbox',
   Host    => 'localhost',
   db      => 'NULL',
   Command => 'Query',
   Time    => '0',
   State   => 'NULL',
   Info    => 'show processlist',
};

ok(
   !$ms->is_replication_thread($query),
   "Non-rpl thd is not repl thd"
);

ok(
   !$ms->is_replication_thread($query, 'binlog_dump'),
   "Non-rpl thd is not binlog dump thd"
);

ok(
   !$ms->is_replication_thread($query, 'slave_io'),
   "Non-rpl thd is not slave io thd"
);

ok(
   !$ms->is_replication_thread($query, 'slave_sql'),
   "Non-rpl thd is not slave sql thd"
);

$query = {
   Id      => '7',
   User    => 'msandbox',
   Host    => 'localhost:53246',
   db      => 'NULL',
   Command => 'Binlog Dump',
   Time    => '1174',
   State   => 'Sending binlog event to slave',
   Info    => 'NULL',
},

ok(
   $ms->is_replication_thread($query),
   'Binlog Dump is a repl thd'
);

ok(
   !$ms->is_replication_thread($query, 'slave_io'),
   'Binlog Dump is not a slave io thd'
);

ok(
   !$ms->is_replication_thread($query, 'slave_sql'),
   'Binlog Dump is not a slave sql thd'
);

$query = {
   Id      => '7',
   User    => 'system user',
   Host    => '',
   db      => 'NULL',
   Command => 'Connect',
   Time    => '1174',
   State   => 'Waiting for master to send event',
   Info    => 'NULL',
},

ok(
   $ms->is_replication_thread($query),
   'Slave io thd is a repl thd'
);

ok(
   $ms->is_replication_thread($query, 'slave_io'),
   'Slave io thd is a slave io thd'
);

ok(
   !$ms->is_replication_thread($query, 'slave_sql'),
   'Slave io thd is not a slave sql thd',
);

$query = {
   Id      => '7',
   User    => 'system user',
   Host    => '',
   db      => 'NULL',
   Command => 'Connect',
   Time    => '1174',
   State   => 'Has read all relay log; waiting for the slave I/O thread to update it',
   Info    => 'NULL',
},

ok(
   $ms->is_replication_thread($query),
   'Slave sql thd is a repl thd'
);

ok(
   !$ms->is_replication_thread($query, 'slave_io'),
   'Slave sql thd is not a slave io thd'
);

ok(
   $ms->is_replication_thread($query, 'slave_sql'),
   'Slave sql thd is a slave sql thd',
);

# #############################################################################
# Done.
# #############################################################################
diag(`$trunk/sandbox/stop-sandbox remove 2903 2902 2901 2900 >/dev/null`);
exit;
