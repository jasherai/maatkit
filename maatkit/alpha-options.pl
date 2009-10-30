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
   next unless $program;
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
   my $fmt    = "%-20s %-20s\n";
   OPT:
   foreach my $opt( 0 .. $#sorted ) {
      if ( $sorted[$opt] ne $opts[$opt] ) {
         printf "$program has unsorted options\n";
         printf $fmt, 'CORRECT', 'ACTUAL';
         printf $fmt, '=======', '======';
         map { printf $fmt, $sorted[$_], $opts[$_]; }
         grep { $sorted[$_] ne $opts[$_] }
         (0 .. $#sorted);
         print "\n";
         last OPT;
      }
      
   }
}
