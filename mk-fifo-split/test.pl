#!/usr/bin/perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use POSIX qw(mkfifo);
use IO::File;

# TODO: binmode
# TODO: allow arguments...
# TODO: is it possible for this to work without either sleeping or removing and
# recreating the fifo?

my $file = '/tmp/baron-fifo';

if ( -e $file ) {
   unlink($file) or die "Can't unlink $file: $OS_ERROR";
}
mkfifo($file, 0777) or die "Can't make fifo $file: $OS_ERROR";

my $fh;

$fh = IO::File->new($file, '>') or die "Can't open $file: $OS_ERROR";
$fh->autoflush(1);

my $lines = 2;
my $i = 0;

while ( my $line = <> ) {
   $i++;
   print "$i\n";
   if ( $i % $lines == 0 ) {
      print $fh "\cD" or die "Can't print CTRL-D: $OS_ERROR";
      close $fh or die "Can't close: $OS_ERROR";

      # Or, just sleep 1
      unlink($file) or die "Can't unlink $file: $OS_ERROR";
      mkfifo($file, 0777) or die "Can't make fifo $file: $OS_ERROR";

      $fh = IO::File->new($file, '>') or die "Can't open $file: $OS_ERROR";
      $fh->autoflush(1);
      print "closed and opened\n";
   }
   print $fh $line or die "Can't print: $OS_ERROR";
}
close $fh or die "Can't close: $OS_ERROR";

unlink($file) or die "Can't unlink $file: $OS_ERROR";
