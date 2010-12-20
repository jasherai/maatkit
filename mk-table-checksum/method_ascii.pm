package method_ascii;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use constant MKDEBUG => $ENV{MKDEBUG};
use POSIX qw(ceil);

sub new {
   my ( $class, %args ) = @_;
   my $self = {
      %args
   };
   return bless $self, $class;
}

sub chunk {
   my ( $self, %args ) = @_;
   my ($col) = $args{col};

   my $dbh = $args{dbh};
   my ($sql, $sth, $row);

   my @chars = map { chr $_ } (32..126);
   my $base  = scalar @chars;

   my $n_chars = 2;
   $sql = "SELECT LEFT(?, $n_chars), LEFT(?, $n_chars)";
   $sth = $dbh->prepare($sql);
   $sth->execute($args{min_col}, $args{max_col});
   $row = $sth->fetchrow_arrayref();
   my ($low, $high) = @$row;

   $low = base_decode(
      base    => $base,
      number  => $low,
   );

   $high = base_decode(
      base    => $base,
      number  => $high,
   );
   print "range $low - $high\n";

   my $interval = ceil($args{chunk_size}
                * ($high - $low)
                / $args{rows_in_range});
   print "interval: $interval\n";

   my @chunk_boundaries;
   for ( my $i = $low; $i < $high; $i += $interval ) {
      my $char = $args{base_count}->(
         count_to => $i,
         base     => $base,
         symbols  => \@chars,
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

sub base_decode {
   my ( %args ) = @_;
   my @required_args = qw(base number);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my ($base, $n) = @args{@required_args};
   
   my $number = 0;
   my @powers = reverse $n =~ m/./g;
   for my $power ( 0..$#powers ) {
      my $char = $powers[$power];
      $number += (ord($char) - 32) * $base**$power;
   }
   return $number;
}

1;
