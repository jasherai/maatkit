package method_static_latin1;

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

sub char_map {
   my ( $self, %args ) = @_;
   my ($min_col_ord, $max_col_ord) = @args{qw(min_col_ord max_col_ord)};
   return unless defined $min_col_ord && defined $max_col_ord;

   my $base;
   my @chars;
   my @sorted_latin1_chars = (
      32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,  48,
      49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 192,
      193, 194, 195, 227, 224, 225, 226, 97, 65, 66, 98, 199, 99, 231, 67,
      240, 100, 208, 68, 232, 69, 233, 101, 235, 201, 200, 202, 234, 203,
      102, 70, 103, 71, 104, 72, 73, 206, 207, 204, 205, 236, 105, 239, 238,
      237, 74, 106, 75, 107, 76, 108, 109, 77, 78, 110, 209, 241, 212, 245,
      244, 210, 243, 242, 111, 211, 79, 213, 80, 112, 113, 81, 114, 82, 115,
      83, 84, 116, 218, 219, 217, 251, 117, 85, 249, 250, 118, 86, 87, 119,
      120, 88, 121, 252, 89, 220, 221, 253, 122, 90, 229, 197, 91, 92, 198,
      230, 196, 228, 214, 93, 246, 94, 95, 96, 123, 124, 125, 126, 127, 128,
      129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142,
      143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156,
      157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170,
      171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184,
      185, 186, 187, 188, 189, 190, 191, 215, 216, 248, 254, 222, 223, 247,
      255);

   my ($first_char, $last_char);
   CHAR:
   for my $i ( 0..$#sorted_latin1_chars ) {
      $first_char = $i and last if $sorted_latin1_chars[$i] == $min_col_ord;
   }
   for my $i ( $first_char..$#sorted_latin1_chars ) {
      $last_char = $i and last if $sorted_latin1_chars[$i] == $max_col_ord;
   };
   @chars = map { chr $_; } @sorted_latin1_chars[$first_char..$last_char];
   $base  = scalar @chars;

   return $base, @chars;
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
