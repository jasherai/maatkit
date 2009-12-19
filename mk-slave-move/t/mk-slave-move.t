#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 7;

require '../mk-slave-move';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);

my $master_dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');
my $slave_1_dbh  = $sb->get_dbh_for('slave1')
   or BAIL_OUT('Cannot connect to sandbox slave1');

# Create slave2 as slave of slave1.
diag(`/tmp/12347/stop 2> /dev/null`);
diag(`rm -rf /tmp/12347 2> /dev/null`);
diag(`../../sandbox/start-sandbox slave 12347 12346`);
my $slave_2_dbh = $sb->get_dbh_for('slave2')
   or BAIL_OUT('Cannot connect to sandbox slave2');

my $output = '';
# open my $output_fh, '>', \$output or die "Cannot open OUTPUT: $OS_ERROR";

# #############################################################################
# Sanity tests.
# #############################################################################
$output = `perl ../mk-slave-move --help`;
like($output, qr/Prompt for a password/, 'It compiles');


# #############################################################################
# Test the moves.
# #############################################################################

# Double-check that we're setup correctly.
my $row = $slave_2_dbh->selectall_arrayref('SHOW SLAVE STATUS', {Slice => {}});
is(
   $row->[0]->{Master_Port},
   '12346',
   'slave2 is slave of slave1 before move'
);

# Move slave2 from being slave of slave1 to slave of master.
mk_slave_move::main('--sibling-of-master', 'h=127.1,P=12347,u=msandbox,p=msandbox');
$row = $slave_2_dbh->selectall_arrayref('SHOW SLAVE STATUS', {Slice => {}});
ok(
   $row->[0]->{Master_Port} eq '12345',
   'slave2 is slave of master after --sibling-of-master'
);

# Move slave2 back to being slave of slave1.
mk_slave_move::main('--slave-of-sibling', 'h=127.1,u=msandbox,p=msandbox', qw(--port 12347), 'h=127.1,P=12346,u=msandbox,p=msandbox');
$row = $slave_2_dbh->selectall_arrayref('SHOW SLAVE STATUS', {Slice => {}});
ok(
   $row->[0]->{Master_Port} eq '12346',
   'slave2 is slave of slave1 again after --slave-of-sibling'
);

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `../mk-slave-move --sibling-of-master h=127.1,P=12347,u=msandbox,p=msandbox --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# Stop and remove slave2.
diag(`/tmp/12347/stop`);
diag(`rm -rf /tmp/12347`);

# Make sure the sandbox slave is still running.
eval { $slave_1_dbh->do('start slave'); };
sleep 1;
is_deeply(
   $slave_1_dbh->selectrow_hashref('show slave status')->{Slave_IO_Running},
   'Yes',
   'Sandbox slave IO running'
);
is_deeply(
   $slave_1_dbh->selectrow_hashref('show slave status')->{Slave_SQL_Running},
   'Yes',
   'Sandbox slave SQL running'
);

exit;
