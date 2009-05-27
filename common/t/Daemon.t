#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 11;

require '../Daemon.pm';
require '../OptionParser.pm';

my $o = new OptionParser(
   description => 'foo',
);
my $d = new Daemon(o=>$o);

isa_ok($d, 'Daemon');

my $cmd     = 'samples/daemonizes.pl';
my $ret_val = system("$cmd 2 --daemonize --pid /tmp/daemonizes.pl.pid >/dev/null 2>/dev/null");
SKIP: {
   skip 'Cannot test Daemon.pm because t/daemonizes.pl is not working',
      11 unless $ret_val == 0;

   my $output = `ps x | grep '$cmd 2' | grep -v grep`;
   like($output, qr/$cmd/, 'Daemonizes');
   ok(-f '/tmp/daemonizes.pl.pid', 'Creates PID file');

   my ($pid) = $output =~ /\s*(\d+)\s+/;
   $output = `cat /tmp/daemonizes.pl.pid`;
   is($output, $pid, 'PID file has correct PID');

   sleep 2;
   ok(! -f '/tmp/daemonizes.pl.pid', 'Removes PID file upon exit');

   # Check that STDOUT can be redirected
   system("$cmd 2 --daemonize --log /tmp/mk-daemon.log");
   ok(-f '/tmp/mk-daemon.log', 'Log file exists');

   sleep 2;
   $output = `cat /tmp/mk-daemon.log`;
   like($output, qr/STDOUT\nSTDERR\n/, 'STDOUT and STDERR went to log file');

   # Check that the log file is appended to.
   system("$cmd 0 --daemonize --log /tmp/mk-daemon.log");
   $output = `cat /tmp/mk-daemon.log`;
   like(
      $output,
      qr/STDOUT\nSTDERR\nSTDOUT\nSTDERR\n/,
      'Appends to log file'
   );

   `rm -f /tmp/mk-daemon.log`;

   # ##########################################################################
   # Issue 383: mk-deadlock-logger should die if --pid file specified exists
   # ##########################################################################
   diag(`touch /tmp/daemonizes.pl.pid`);
   ok(
      -f  '/tmp/daemonizes.pl.pid',
      'PID file already exists'
   );
   
   $output = `$cmd 0 --daemonize --pid /tmp/daemonizes.pl.pid 2>&1`;
   like(
      $output,
      qr{The PID file /tmp/daemonizes\.pl\.pid already exists},
      'Dies if PID file already exists'
   );

    $output = `ps x | grep '$cmd 0' | grep -v grep`;
    unlike(
      $output,
      qr/$cmd/,
      'Does not daemonizes'
   );
   
   diag(`rm -rf /tmp/daemonizes.pl.pid`);  
}

exit;
