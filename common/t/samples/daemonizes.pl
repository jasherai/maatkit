#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';

use POSIX qw(setsid);
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

require '../../Daemon.pm';

if ( scalar @ARGV != 2 ) {
   die "Usage: daemonizes.pl sleep exit|die\n";
}
my ( $s, $e ) = ( $ARGV[0], $ARGV[1] );

my $d = new Daemon() or die;
$d->daemonize();
$d->create_PID_file();

sleep $s;

exit if $e eq 'exit';
die  if $e eq 'die';
