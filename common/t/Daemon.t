#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 9;

require '../Daemon.pm';

my $d = new Daemon();

isa_ok($d, 'Daemon');

my $cmd     = 'samples/daemonizes.pl';
my $ret_val = system("$cmd 2 'stderr => /dev/null'");
SKIP: {
   skip 'Cannot test Daemon.pm because t/daemonizes.pl is not working.',
      8 unless $ret_val == 0;

   my $output = `ps ax | grep '$cmd 2 ' | grep -v grep`;
   like($output, qr/$cmd/, 'Daemonizes');
   ok(-f '/tmp/daemonizes.pl.pid', 'Creates PID file');

   my ($pid) = $output =~ /\s*(\d+)\s+/;
   $output = `cat /tmp/daemonizes.pl.pid`;
   is($output, $pid, 'PID file has correct PID');

   sleep 2;
   ok(! -f '/tmp/daemonizes.pl.pid', 'Removes PID file upon exit');

   # Check that STDOUT can be redirected
   `$cmd 2 'stdout => /tmp/daemon.stdout','stderr => /tmp/daemon.stderr'`;
   ok(-f '/tmp/daemon.stdout', 'File for redirected STDOUT exists');
   ok(-f '/tmp/daemon.stderr', 'File for redirected STDERR exists');

   sleep 2;
   $output = `cat /tmp/daemon.stdout`;
   like($output, qr/ STDOUT /, 'Print to STDOUT went to file');

   $output = `cat /tmp/daemon.stderr`;
   like($output, qr/ STDERR /, 'Print to STDERR went to file');

   `rm -f /tmp/daemon.stdout`;
   `rm -f /tmp/daemon.stderr`;
}

exit;
