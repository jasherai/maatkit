#!/usr/bin/perl

# This program is copyright (c) 2007 Baron Schwartz.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
use strict;
use warnings FATAL => 'all';

use Test::More tests => 31;
use English qw(-no_match_vars);

require "../MasterSlave.pm";
require "../DSNParser.pm";

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
foreach my $port ( sort values %port_for ) {
   diag(`../../sandbox/make_sandbox $port`);
}

# I discovered something weird while updating this test. Below, you see that
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
diag(`/tmp/$port_for{slave2}/use -e "change master to master_host='127.0.0.1', master_log_file='mysql-bin.000001', master_log_pos=0, master_user='msandbox', master_password='msandbox', master_port=$port_for{master}"`);
diag(`/tmp/$port_for{slave2}/use -e "start slave"`);

diag(`/tmp/$port_for{slave0}/use -e "change master to master_host='127.0.0.1', master_log_file='mysql-bin.000001', master_log_pos=0, master_user='msandbox', master_password='msandbox', master_port=$port_for{master}"`);
diag(`/tmp/$port_for{slave0}/use -e "start slave"`);

diag(`/tmp/$port_for{slave1}/use -e "change master to master_host='127.0.0.1', master_log_file='mysql-bin.000001', master_log_pos=0, master_user='msandbox', master_password='msandbox', master_port=$port_for{slave0}"`);
diag(`/tmp/$port_for{slave1}/use -e "start slave"`);

# #############################################################################
# Now the test.
# #############################################################################
my $dbh;
my @slaves;
my @sldsns;
my $ms = new MasterSlave();
my $dp = new DSNParser();

my $dsn = $dp->parse("h=127.0.0.1,P=$port_for{master}");
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

foreach my $port ( reverse sort values %port_for ) {
   diag(`/tmp/$port/stop`);
   diag(`rm -rf /tmp/$port`);
}
exit;
