#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 6;

require '../../common/DSNParser.pm';
require '../../common/Sandbox.pm';
my $dp = new DSNParser();
my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
my $dbh = $sb->get_dbh_for('master');

my $output;

# #########################################################################
# Issue 391: Add --pid option to all scripts
# #########################################################################
`touch /tmp/mk-script.pid`;
$output = `../mk-query-digest ../../commont/t/samples/slow002.txt --pid /tmp/mk-script.pid 2>&1`;
like(
   $output,
   qr{PID file /tmp/mk-script.pid already exists},
   'Dies if PID file already exists (--pid without --daemonize) (issue 391)'
);
`rm -rf /tmp/mk-script.pid`;

# #########################################################################
# Daemonizing and pid creation
# #########################################################################
SKIP: {
   skip "Cannot connect to sandbox master", 5 unless $dbh;

   `../mk-query-digest --daemonize --pid /tmp/mk-query-digest.pid --processlist h=127.1,P=12345,u=msandbox,p=msandbox --log /dev/null`;
   $output = `ps -eaf | grep mk-query-digest | grep daemonize`;
   like($output, qr/perl ...mk-query-digest/, 'It is running');
   ok(-f '/tmp/mk-query-digest.pid', 'PID file created');

   my ($pid) = $output =~ /\s+(\d+)\s+/;
   $output = `cat /tmp/mk-query-digest.pid`;
   is($output, $pid, 'PID file has correct PID');

   kill 15, $pid;
   sleep 1;
   $output = `ps -eaf | grep mk-query-digest | grep daemonize`;
   unlike($output, qr/perl ...mk-query-digest/, 'It is not running');
   ok(
      !-f '/tmp/mk-query-digest.pid',
      'Removes its PID file'
   );
};

# #############################################################################
# Done.
# #############################################################################
exit;
