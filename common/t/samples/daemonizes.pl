#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use POSIX qw(setsid);
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

require '../Daemon.pm';

if ( scalar @ARGV < 2 ) {
   die "Usage: daemonizes.pl sleep exit|die\n";
}
my ( $s, $e, $a ) = ( $ARGV[0], $ARGV[1], $ARGV[2] );

my $d;
if ( defined $a ) {
   my %args = map {
      my ( $k, $v ) = m/(.*) \=\> (.*)/;
      $k => $v;
   } split /,/, $a;
   $d = new Daemon(%args);
}
else {
   $d = new Daemon();
}
$d->daemonize();
$d->create_PID_file('/tmp/daemonizes.pl.pid');

print STDOUT ' STDOUT ';
print STDERR ' STDERR ';

sleep $s;

exit if $e eq 'exit';
die  if $e eq 'die';
