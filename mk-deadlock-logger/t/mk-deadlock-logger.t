#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 21;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh1 = $sb->get_dbh_for('master', { PrintError => 0, RaiseError => 1, AutoCommit => 0 })
or BAIL_OUT('Cannot connect to sandbox master');
my $dbh2 = $sb->get_dbh_for('master', { PrintError => 0, RaiseError => 1, AutoCommit => 0 })
or BAIL_OUT('Cannot connect to sandbox master');

$sb->create_dbs($dbh1, ['test']);

# Set up the table for creating a deadlock.
$dbh1->do("drop table if exists test.dl");
$dbh1->do("create table test.dl(a int) engine=innodb");
$dbh1->do("insert into test.dl(a) values(0), (1)");
$dbh1->commit;
$dbh1->{InactiveDestroy} = 1;
$dbh2->{InactiveDestroy} = 1;

# Fork off two children to deadlock against each other.
my %children;
foreach my $child ( 0..1 ) {
   my $pid = fork();
   if ( defined($pid) && $pid == 0 ) { # I am a child
      eval {
         my $dbh = ($dbh1, $dbh2)[$child];
         my @stmts = (
            "set transaction isolation level serializable",
            "begin",
            "select * from test.dl where a = $child",
            "update test.dl set a = $child where a <> $child",
         );
         foreach my $stmt (@stmts[0..2]) {
            $dbh->do($stmt);
         }
         sleep(1 + $child);
         $dbh->do($stmts[-1]);
      };
      if ( $EVAL_ERROR ) {
         if ( $EVAL_ERROR !~ m/Deadlock found/ ) {
            die $EVAL_ERROR;
         }
      }
      exit(0);
   }
   elsif ( !defined($pid) ) {
      die("Unable to fork for clearing deadlocks!\n");
   }

   # I already exited if I'm a child, so I'm the parent.
   $children{$child} = $pid;
}

# Wait for the children to exit.
foreach my $child ( keys %children ) {
   my $pid = waitpid($children{$child}, 0);
}

# Test that there is a deadlock
my ($stat) = $dbh1->selectrow_array('show innodb status');
like($stat, qr/WE ROLL BACK/, 'There was a deadlock');

my $output = `perl ../mk-deadlock-logger --print h=127.1,P=12345`;
like(
   $output,
   qr/127\.1.+msandbox.+GEN_CLUST_INDEX/,
   'Deadlock logger prints the output'
);

$output = `perl ../mk-deadlock-logger h=127.1,P=12345`;
like(
   $output,
   qr/127\.1.+msandbox.+GEN_CLUST_INDEX/,
   '--print is implicit'
);

$dbh1->do('drop table test.dl');

# #############################################################################
# Check daemonization
# #############################################################################
my $deadlocks_tbl = `cat deadlocks_tbl.sql`;
$dbh1->do('USE test');
$dbh1->do('DROP TABLE IF EXISTS deadlocks');
$dbh1->do("$deadlocks_tbl");

my $cmd = '../mk-deadlock-logger --dest D=test,t=deadlocks h=127.1,P=12345 --daemonize --run-time 1s --interval 1s --pid /tmp/mk-deadlock-logger.pid';
`$cmd 1>/dev/null 2>/dev/null`;
$output = `ps -eaf | grep 'mk-deadlock-logger \-\-dest '`;
like($output, qr/$cmd/, 'It lives daemonized');
ok(-f '/tmp/mk-deadlock-logger.pid', 'PID file created');

my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-deadlock-logger.pid`;
is($output, $pid, 'PID file has correct PID');

# Kill it
sleep 2;
ok(! -f '/tmp/mk-deadlock-logger.pid', 'PID file removed');

# Check that it won't run if the PID file already exists (issue 383).
diag(`touch /tmp/mk-deadlock-logger.pid`);
ok(
   -f '/tmp/mk-deadlock-logger.pid',
   'PID file already exists'
);

$cmd = '../mk-deadlock-logger --dest D=test,t=deadlocks h=127.1,P=12345 --daemonize --run-time 1s --interval 1s --pid /tmp/mk-deadlock-logger.pid';
$output = `$cmd 2>&1`;
like(
   $output,
   qr/PID file .+ already exists/,
   'Does not run if PID file already exists'
);

$output = `ps -eaf | grep 'mk-deadlock-logger \-\-dest '`;
unlike(
   $output,
   qr/$cmd/,
   'It does not lived daemonized'
);

diag(`rm -rf /tmp/mk-deadlock-logger.pid`);

# #############################################################################
# Check that deadlocks from previous test were stored in table.
# #############################################################################
my $res = $dbh1->selectall_arrayref('SELECT * FROM test.deadlocks');
ok(
   scalar @$res,
   'Deadlocks recorded in table'
);

# #############################################################################
# Check that --dest suppress --print output unless --print is explicit.
# #############################################################################
$output = 'foo';
$dbh1->do('TRUNCATE TABLE test.deadlocks');
$cmd = '../mk-deadlock-logger --dest D=test,t=deadlocks h=127.1,P=12345';
$output = `$cmd`;
is(
   $output,
   '',
   'No output with --dest'
);

$res = $dbh1->selectall_arrayref('SELECT * FROM test.deadlocks');
ok(
   scalar @$res,
   'Deadlocks still recorded in table'
);

$output = '';
$dbh1->do('TRUNCATE TABLE test.deadlocks');
$cmd = '../mk-deadlock-logger --print --dest D=test,t=deadlocks --host 127.1 --port 12345';
$output = `$cmd`;
like(
   $output,
   qr/127\.1.+msandbox.+GEN_CLUST_INDEX/,
   'Prints output with --dest and explicit --print'
);

$res = $dbh1->selectall_arrayref('SELECT * FROM test.deadlocks');
ok(
   scalar @$res,
   'Deadlocks recorded in table again'
);

# #############################################################################
# Sanity tests.
# #############################################################################
$output = `../mk-deadlock-logger --dest D=test,t=deadlocks 2>&1`;
like(
   $output,
   qr/Missing or invalid source host/,
   'Requires source host'
);

$output = `../mk-deadlock-logger h=127.1 --dest t=deadlocks 2>&1`;
like(
   $output,
   qr/requires a 'D'/, 
   'Dest DSN requires D',
);

$output = `../mk-deadlock-logger --dest D=test 2>&1`;
like(
   $output,
   qr/requires a 't'/,
   'Dest DSN requires t'
);

# #############################################################################
# Test --clear-deadlocks
# #############################################################################

# The clear-deadlocks table comes and goes quickly so we can really
# only search the debug output for evidence that it was created.
$output = `MKDEBUG=1 ../mk-deadlock-logger h=127.1,P=12345,D=test --clear-deadlocks test.make_deadlock 2>&1`;
like(
   $output,
   qr/INSERT INTO test.make_deadlock/,
   'Create --clear-deadlocks table (output)'
);
like(
   $output,
   qr/CREATE TABLE test.make_deadlock/,
   'Create --clear-deadlocks table (debug)'
);

# #############################################################################
# Issue 248: Add --user, --pass, --host, etc to all tools
# #############################################################################

# Test that source DSN inherits from --user, etc.
$output = `../mk-deadlock-logger h=127.1,D=test --clear-deadlocks test.make_deadlock --port 12345 2>&1`;
unlike(
   $output,
   qr/failed/,
   'Source DSN inherits from standard connection options (issue 248)'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh1);
exit;
