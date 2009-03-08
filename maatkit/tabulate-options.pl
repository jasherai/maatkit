#!/usr/bin/env perl

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use List::Util qw(max);

my %progs;
my %opts;

foreach my $prog ( <../mk-*/mk-*> ) {
   open my $fh, "<", $prog or die $OS_ERROR;
   my ($program) = $prog =~ m{/([a-z-]+)$};
   local $INPUT_RECORD_SEPARATOR = '';
   my $para;

   while ( $para = <$fh> ) {
      next unless $para =~ m/^=head1 OPTIONS/;
      last;
   }

   while ( $para = <$fh> ) {
      if ( my ($option) = $para =~ m/^=item --(?:\[no\])?(.*)/ ) {
         $progs{$program}->{$option} = $option;
         $opts{$option}++;
         $para = <$fh>;
         if ( $para =~ m/short form: / ) {
            $para =~ s/\s+\Z//g;
            my %props = map { split(/: /, $_) } split(/; /, $para);
            if ( $props{'short form'} ) {
               $props{'short form'} =~ s/-//;
               $progs{$program}->{$option} = $props{'short form'};
               $progs{$program}->{$props{'short form'}} = $option;
               $opts{$props{'short form'}}++;
            }
         }
      }
   }

   close $fh;
}

my $max = max( map { length($_) } (keys %progs, keys %opts) );
my @progs = sort keys %progs;
my $fmt = "%${max}s | %3s | " . join(' | ', map { "%-${max}s" } @progs) . " |\n";
printf $fmt, "option", "cnt", @progs;
printf $fmt, ' ', '---', map { '-' x $max } (1, @progs);

foreach my $o ( sort { lc $a cmp lc $b } keys %opts ) {
   printf $fmt, $o, $opts{$o}, map { $progs{$_}->{$o} || '' } @progs;
}
