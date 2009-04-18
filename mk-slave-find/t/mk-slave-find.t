#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 3;

my $output = `perl ../mk-slave-find --help`;
like($output, qr/Prompt for a password/, 'It compiles');

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $slave_dbh  = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

# Create slave2 as slave of slave1.
diag(`/tmp/12347/stop 2> /dev/null`);
diag(`rm -rf /tmp/12347 2> /dev/null`);
diag(`../../sandbox/make_sandbox 12347`);
diag(`/tmp/12347/use -e "change master to master_host='127.0.0.1', master_log_file='mysql-bin.000001', master_log_pos=0, master_user='msandbox', master_password='msandbox', master_port=12346"`);
diag(`/tmp/12347/use -e "start slave"`);
my $slave_2_dbh = $sb->get_dbh_for('slave2')
   or BAIL_OUT('Cannot connect to sandbox slave2');

# Double check that we're setup correctly.
my $row = $slave_2_dbh->selectall_arrayref('SHOW SLAVE STATUS', {Slice => {}});
is(
   $row->[0]->{Master_Port},
   '12346',
   'slave2 is slave of slave1'
);

$output = `perl ../mk-slave-find -h 127.0.0.1 -P 12345`;
my $expected = <<EOF;
127.0.0.1:12345
+- 127.0.0.1:12346
   +- 127.0.0.1:12347
EOF
is($output, $expected, 'Master with slave and slave of slave');

# #############################################################################
# Until MasterSlave::find_slave_hosts() is improved to overcome the problems
# with SHOW SLAVE HOSTS, this test won't work.
# #############################################################################
# Make slave2 slave of master.
#diag(`../../mk-slave-move/mk-slave-move --sibling-of-master h=127.1,P=12347`);
#$output = `perl ../mk-slave-find -h 127.0.0.1 -P 12345 -u msandbox -p msandbox`;
#$expected = <<EOF;
#127.0.0.1:12345
#+- 127.0.0.1:12346
#+- 127.0.0.1:12347
#EOF
#is($output, $expected, 'Master with two slaves');

# Stop and remove slave2.
diag(`/tmp/12347/stop`);
diag(`rm -rf /tmp/12347`);
exit;
