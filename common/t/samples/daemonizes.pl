#!/usr/bin/env perl

# This script is used by Daemon.t because that test script
# cannot daemonize itself.

use strict;
use warnings FATAL => 'all';

use POSIX qw(setsid);
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

require '../Daemon.pm';

if ( scalar @ARGV < 1 ) {
   die "Usage: daemonizes.pl sleep_time [args]\n";
}
my ( $t, $args ) = ( $ARGV[0], $ARGV[1] );
my $d;

# Turn comma-separated args from cmd line into a hash that
# we pass to new(). Each arg should be a quoted string like
# 'key => val' (must quote to preserve spaces).
if ( defined $args ) {
   my %args = map {
      my ( $k, $v ) = m/(.*) \=\> (.*)/;
      $k => $v;
   } split /,/, $args;
   $d = new Daemon(%args);
}
else {
   $d = new Daemon();
}
$d->daemonize();
$d->create_PID_file('/tmp/daemonizes.pl.pid');
print STDOUT ' STDOUT ';
print STDERR ' STDERR ';
sleep $t;
exit;
