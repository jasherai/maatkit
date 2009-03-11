#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

my @progs = @ARGV;
if ( !@progs ) {
   @progs = <../mk-*/mk-*>;
}

foreach my $prog ( @progs ) {
   open my $fh, "<", $prog or die $OS_ERROR;
   my ($program) = $prog =~ m{/([a-z-]+)$};
   local $INPUT_RECORD_SEPARATOR = '';
   my $para;

   my @opts;

   while ( $para = <$fh> ) {
      next unless $para =~ m/^=head1 OPTIONS/;
      last;
   }

   while ( $para = <$fh> ) {
      if ( my ($option) = $para =~ m/^=item --(?:\[no\])?(.*)/ ) {
         push @opts, $option;
      }
   }

   close $fh;

   my @sorted = sort @opts;
   OPT:
   foreach my $opt( 0 .. $#sorted ) {
      if ( $sorted[$opt] ne $opts[$opt] ) {
         print "$program has unsorted options\n";
         map { printf "%-20s %-20s\n", $sorted[$_], $opts[$_] } (0 .. $#sorted);
         last OPT;
      }
   }
}
