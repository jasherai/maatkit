#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 8;

require '../Daemon.pm';

my $d = new Daemon();

isa_ok($d, 'Daemon');

my $cmd     = 'samples/daemonizes.pl';
my $ret_val = system("$cmd 2 >/dev/null 2>/dev/null");
SKIP: {
   skip 'Cannot test Daemon.pm because t/daemonizes.pl is not working',
      8 unless $ret_val == 0;

   my $output = `ps x | grep '$cmd 2' | grep -v grep`;
   like($output, qr/$cmd/, 'Daemonizes');
   ok(-f '/tmp/daemonizes.pl.pid', 'Creates PID file');

   my ($pid) = $output =~ /\s*(\d+)\s+/;
   $output = `cat /tmp/daemonizes.pl.pid`;
   is($output, $pid, 'PID file has correct PID');

   sleep 2;
   ok(! -f '/tmp/daemonizes.pl.pid', 'Removes PID file upon exit');

   # Check that STDOUT can be redirected
   system("$cmd 2 'log_file => /tmp/mk-daemon.log'");
   ok(-f '/tmp/mk-daemon.log', 'Log file exists');

   sleep 2;
   $output = `cat /tmp/mk-daemon.log`;
   like($output, qr/STDOUT\nSTDERR\n/, 'STDOUT and STDERR went to log file');

   # Check that the log file is appended to.
   system("$cmd 0 'log_file => /tmp/mk-daemon.log'");
   $output = `cat /tmp/mk-daemon.log`;
   like(
      $output,
      qr/STDOUT\nSTDERR\nSTDOUT\nSTDERR\n/,
      'Appends to log file'
   );

   `rm -f /tmp/mk-daemon.log`;
}

exit;
