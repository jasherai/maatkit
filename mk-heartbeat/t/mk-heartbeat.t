#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use DBI;
use Test::More tests => 15;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master')
   or BAIL_OUT('Cannot connect to sandbox master');

$sb->create_dbs($dbh, ['test']);

my $cnf = '/tmp/12345/my.sandbox.cnf';
my $cmd = "perl ../mk-heartbeat -F $cnf ";

my $output;

$dbh->do('drop table if exists test.heartbeat');
$dbh->do(q{CREATE TABLE test.heartbeat (
             id int NOT NULL PRIMARY KEY,
             ts datetime NOT NULL
          )});

# Issue: mk-heartbeat should check that the heartbeat table has a row
$output = `$cmd -D test --check 2>&1`;
like($output, qr/heartbeat table is empty/ms, 'Dies on empty heartbeat table with --check (issue 45)');

$output = `$cmd -D test --monitor -m 1s 2>&1`;
like($output, qr/heartbeat table is empty/ms, 'Dies on empty heartbeat table with --monitor (issue 45)');


# Run one instance with --replace to create the table.
`$cmd -D test --update --replace -m 1s`;
ok($dbh->selectrow_array('select id from test.heartbeat'), 'Record is there');

# Check the delay and ensure it is only a single line with nothing but the
# delay (no leading whitespace or anything).
$output = `$cmd -D test --check`;
chomp $output;
like($output, qr/^\d+$/, 'Output is just a number');

# Start one daemonized instance to update it
`$cmd --daemonize -D test --update -m 5s --pid /tmp/mk-heartbeat.pid`;
$output = `ps -eaf | grep mk-heartbeat | grep daemonize`;
like($output, qr/perl ...mk-heartbeat/, 'It is running');

ok(-f '/tmp/mk-heartbeat.pid', 'PID file created');
my ($pid) = $output =~ /\s+(\d+)\s+/;
$output = `cat /tmp/mk-heartbeat.pid`;
is($output, $pid, 'PID file has correct PID');

$output = `$cmd -D test --monitor -m 1s`;
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
`$cmd --daemonize -D test --update`;
$output = `ps -eaf | grep mk-heartbeat | grep daemonize`;
like($output, qr/perl ...mk-heartbeat/, 'It is running');
$output = `$cmd -D test --stop`;
like($output, qr/Successfully created/, 'created sentinel');
sleep(2);
$output = `ps -eaf | grep mk-heartbeat | grep daemonize`;
unlike($output, qr/perl ...mk-heartbeat/, 'It is not running');
ok(-f '/tmp/mk-heartbeat-sentinel', 'Sentinel file is there');
unlink('/tmp/mk-heartbeat-sentinel');
$dbh->do('drop table if exists test.heartbeat'); # This will kill it

# Cannot daemonize and debug
$output = `MKDEBUG=1 $cmd --daemonize -D test 2>&1`;
like($output, qr/Cannot debug while daemonized/, 'Cannot debug while daemonized');

$sb->wipe_clean($dbh);
exit;
