package method2;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use constant MKDEBUG => $ENV{MKDEBUG};
use POSIX qw(floor);

sub new {
   my ( $class, %args ) = @_;
   my $self = {
      %args
   };
   return bless $self, $class;
}

sub chunk {
   my ( $self, %args ) = @_;
   my ($base, $col) = @args{qw(base col)};

   my ($m, $c);
   for my $power ( 1..$args{max_col_len} ) {
      $c = $power;
      $m = $base**$c;
      print "$base**$c = $m\n";
      last if $m >= $args{chunk_size};
   }
   my $n = floor($m / $args{n_chunks}) || 1;
   print "m=$m c=$c n=$n\n";

   my @chunk_boundaries;
   for ( my $i = 0; $i < $m; $i += $n ) {
      my $char = $args{base_count}->(
         count_to => $i,
         base     => $base,
         symbols  => $args{chars},
      );
      $char =~ s/(['\\])/\\$1/g;
      push @chunk_boundaries, $char;
   }

   $col = "`$col`";

   my @chunks;
   my $lower_boundary;
   foreach my $upper_boundary ( @chunk_boundaries ) {
      if ( $lower_boundary ) {
         push @chunks, "$col >= '$lower_boundary' "
            . "AND $col < '$upper_boundary'";
      }
      else {
         push @chunks, "$col < '$upper_boundary' "
      }
      $lower_boundary = $upper_boundary;
   }
   $chunks[-1] =~ s/ AND .+?$//;

   return @chunks;
}

1;
