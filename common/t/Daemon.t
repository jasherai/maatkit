#!/usr/bin/perl

# This program is copyright 2008 Percona Inc.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.

use strict;
use warnings FATAL => 'all';

use Test::More tests => 8;
use English qw(-no_match_vars);

require '../Daemon.pm';

my $d = new Daemon();

isa_ok($d, 'Daemon');

my $cmd     = 'samples/daemonizes.pl 2 exit';
my $ret_val = system($cmd);
SKIP: {
   skip 'Cannot test Daemon.pm because t/daemonizes.pl is not working.',
      7 unless $ret_val == 0;

   my $output = `ps ax | grep '$cmd' | grep -v grep`;
   like($output, qr/$cmd/, 'Daemonizes');
   my ($pid) = $output =~ /\s*(\d+)\s+/;

   ok(-f '/tmp/daemonizes.pl.pid', 'Creates PID file');

   $output = `cat /tmp/daemonizes.pl.pid`;
   is($output, $pid, 'PID file has correct PID');

   sleep 2;

   ok(! -f '/tmp/daemonizes.pl.pid', 'Removes PID file upon exit');

   # Check that STDOUT can be redirected
   $cmd .= " 'reopen_STDOUT => /tmp/daemon.foo'";
   `$cmd`;
   ok(-f '/tmp/daemon.foo', 'File for redirected STDOUT exists');
   sleep 2;
   $output = `cat /tmp/daemon.foo`;
   like($output, qr/ STDOUT /, 'Print to STDOUT went to file');
   like($output, qr/ STDERR /, 'Print to STDERR went to file');
   `rm /tmp/daemon.foo`;
}

exit;
