#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Test::More tests => 16;

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

   # ##########################################################################
   # Issue 417: --daemonize doesn't let me log out of terminal cleanly
   # ##########################################################################
   SKIP: {
      skip 'No /proc', 2 unless -d '/proc';

      $output = `$cmd 1 --daemonize --pid /tmp/daemonizes.pl.pid --log /tmp/daemonizes.output 2>&1`;
      chomp($pid = `cat /tmp/daemonizes.pl.pid`);
      my $proc_fd_0 = -l "/proc/$pid/0"    ? "/proc/$pid/0"
                    : -l "/proc/$pid/fd/0" ? "/proc/$pid/fd/0"
                    : BAIL_OUT("Cannot find fd 0 symlink in /proc/$pid");
      my $stdin = readlink $proc_fd_0;
      is(
         $stdin,
         '/dev/null',
         'Reopens STDIN to /dev/null if not piped',
      );

      sleep 1;
      $output = `echo "foo" | $cmd 1 --daemonize --pid /tmp/daemonizes.pl.pid --log /tmp/daemonizes.output 2>&1`;
      chomp($pid = `cat /tmp/daemonizes.pl.pid`);
      $proc_fd_0 = -l "/proc/$pid/0"    ? "/proc/$pid/0"
                 : -l "/proc/$pid/fd/0" ? "/proc/$pid/fd/0"
                 : BAIL_OUT("Cannot find fd 0 symlink in /proc/$pid");
      $stdin = readlink $proc_fd_0;
      like(
         $stdin,
         qr/pipe/,
         'Does not reopen STDIN to /dev/null when piped',
      );

   };
}

# #############################################################################
# Test auto-PID file removal without having to daemonize (for issue 391).
# #############################################################################
{
   @ARGV = qw(--pid /tmp/d2.pid);
   $o->get_specs('samples/daemonizes.pl');
   $o->get_opts();
   my $d2 = new Daemon(o=>$o);
   $d2->make_PID_file();
   ok(
      -f '/tmp/d2.pid',
      'PID file for non-daemon exists'
   );
}
# Since $d2 was locally scoped, it should have been destoryed by now.
# This should have caused the PID file to be automatically removed.
ok(
   !-f '/tmpo/d2.pid',
   'PID file auto-removed for non-daemon'
);

# We should still die if the PID file already exists,
# even if we're not a daemon.
{
   `touch /tmp/d2.pid`;
   @ARGV = qw(--pid /tmp/d2.pid);
   $o->get_opts();
   eval {
      my $d2 = new Daemon(o=>$o);  # should die here actually
      $d2->make_PID_file();
   };
   like(
      $EVAL_ERROR,
      qr{PID file /tmp/d2.pid already exists},
      'Dies if PID file already exists for non-daemon'
   );

   `rm -rf /tmp/d2.pid`;
}

# #############################################################################
# Done.
# #############################################################################
diag(`rm -rf /tmp/daemonizes.*`);
exit;
