#!/usr/bin/env perl

BEGIN {
   die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
      unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
   unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
};

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More;

use MaatkitTest;
use Sandbox;
require "$trunk/mk-slave-move/mk-slave-move";

my $dp = new DSNParser(opts=>$dsn_opts);
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $master_dbh  = $sb->get_dbh_for('master');
my $slave_1_dbh = $sb->get_dbh_for('slave1');

# Reset master and slave relay logs so the second slave
# starts faster (i.e. so it doesn't have to replay the
# masters logs which is stuff from previous tests that we
# don't care about).
diag(`$trunk/sandbox/mk-test-env reset`) if $master_dbh && $slave_1_dbh;

# Create slave2 as slave of slave1.
diag(`/tmp/12347/stop >/dev/null 2>&1`);
diag(`rm -rf /tmp/12347 >/dev/null 2>&1`);
diag(`$trunk/sandbox/start-sandbox slave 12347 12346 >/dev/null`);
my $slave_2_dbh = $sb->get_dbh_for('slave2');

if ( !$master_dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
elsif ( !$slave_1_dbh ) {
   plan skip_all => 'Cannot connect to sandbox slave';
}
elsif ( !$slave_2_dbh ) {
   plan skip_all => 'Cannot connect to second sandbox slave';
}
else {
   plan tests => 7;
}

my $output = '';

# #############################################################################
# Sanity tests.
# #############################################################################
$output = `$trunk/mk-slave-move/mk-slave-move --help`;
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
$output = `$trunk/mk-slave-move/mk-slave-move --sibling-of-master h=127.1,P=12347,u=msandbox,p=msandbox --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# Stop and remove slave2.
diag(`/tmp/12347/stop >/dev/null`);
diag(`rm -rf /tmp/12347 >/dev/null`);

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
