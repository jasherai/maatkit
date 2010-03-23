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
require "$trunk/mk-heartbeat/mk-heartbeat";

my $dp  = new DSNParser(opts=>$dsn_opts);
my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

if ( !$dbh ) {
   plan skip_all => 'Cannot connect to sandbox master';
}
else {
   plan tests => 16;
}

$sb->create_dbs($dbh, ['test']);

my $output;
my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "$trunk/mk-heartbeat/mk-heartbeat -F $cnf ";

$dbh->do('drop table if exists test.heartbeat');
$dbh->do(q{CREATE TABLE test.heartbeat (
             id int NOT NULL PRIMARY KEY,
             ts datetime NOT NULL
          )});

# Issue: mk-heartbeat should check that the heartbeat table has a row
$output = `$cmd -D test --check 2>&1`;
like($output, qr/heartbeat table is empty/ms, 'Dies on empty heartbeat table with --check (issue 45)');

$output = `$cmd -D test --monitor --run-time 1s 2>&1`;
like($output, qr/heartbeat table is empty/ms, 'Dies on empty heartbeat table with --monitor (issue 45)');

# Run one instance with --replace to create the table.
`$cmd -D test --update --replace --run-time 1s`;
ok($dbh->selectrow_array('select id from test.heartbeat'), 'Record is there');

# Check the delay and ensure it is only a single line with nothing but the
# delay (no leading whitespace or anything).
$output = `$cmd -D test --check`;
chomp $output;
like($output, qr/^\d+$/, 'Output is just a number');

# Start one daemonized instance to update it
`$cmd --daemonize -D test --update --run-time 5s --pid /tmp/mk-heartbeat.pid 1>/dev/null 2>/dev/null`;
$output = `ps -eaf | grep mk-heartbeat | grep daemonize`;
like($output, qr/$cmd/, 'It is running');

ok(-f '/tmp/mk-heartbeat.pid', 'PID file created');
my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-heartbeat.pid`;
is($output, $pid, 'PID file has correct PID');

$output = `$cmd -D test --monitor --run-time 1s`;
chomp ($output);
is (
   $output,
   '   0s [  0.00s,  0.00s,  0.00s ]',
   'It is being updated',
);
sleep(5);
$output = `ps -eaf | grep mk-heartbeat | grep daemonize`;
chomp $output;
unlike($output, qr/perl ...mk-heartbeat/, 'It is not running anymore');
ok(! -f '/tmp/mk-heartbeat.pid', 'PID file removed');

# Run again, create the sentinel, and check that the sentinel makes the
# daemon quit.
`$cmd --daemonize -D test --update 1>/dev/null 2>/dev/null`;
$output = `ps -eaf | grep mk-heartbeat | grep daemonize`;
like($output, qr/$cmd/, 'It is running');
$output = `$cmd -D test --stop`;
like($output, qr/Successfully created/, 'created sentinel');
sleep(2);
$output = `ps -eaf | grep mk-heartbeat | grep daemonize`;
unlike($output, qr/$cmd/, 'It is not running');
ok(-f '/tmp/mk-heartbeat-sentinel', 'Sentinel file is there');
unlink('/tmp/mk-heartbeat-sentinel');
$dbh->do('drop table if exists test.heartbeat'); # This will kill it

# #############################################################################
# Issue 353: Add --create-table to mk-heartbeat
# #############################################################################
$dbh->do('drop table if exists test.heartbeat');
diag(`$cmd --update --run-time 1s --database test --table heartbeat --create-table`);
$dbh->do('use test');
$output = $dbh->selectcol_arrayref('SHOW TABLES LIKE "heartbeat"');
is(
   $output->[0],
   'heartbeat', 
   '--create-table creates heartbeat table'
); 

# #############################################################################
# Issue 352: Add port to mk-heartbeat --check output
# #############################################################################
sleep 1;
$output = `$cmd --host 127.1 --user msandbox --password msandbox --port 12345 -D test --check --recurse 1`;
like(
   $output,
   qr/:12346\s+\d/,
   '--check output has :port'
);

# #############################################################################
# Done.
# #############################################################################
$sb->wipe_clean($dbh);
exit;
