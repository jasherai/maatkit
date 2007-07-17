use strict;
use warnings FATAL => 'all';

package ExplainParser;

sub new {
   bless {}, shift;
}

sub parse {
   my ($self, $text) = @_;
   my $started = 0;
   my $lines   = 0;
   my @cols    = ();
   my @result  = ();
   foreach my $line ( $text =~ m/^(.*)[\r\n]+/gm ) {
      $started ||= $line =~ m/^\+[+-]+$/;
      if ( $started && $line =~ m/[^+-]/ ) {
         my @vals = $line  =~ m/\| +(.*?)(?= +\|)/g;
         if ( $lines++ ) {
            my %row;
            @row{@cols} = map { $_ eq 'NULL' ? undef : $_ } @vals;
            push @result, \%row;
         }
         else { # header row
            @cols = @vals
         }
      }
   }
   return \@result;
}

1;
