# This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
# Feedback and improvements are welcome.
#
# THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
# MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
# systems, you can issue `man perlgpl' or `man perlartistic' to read these
# licenses.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place, Suite 330, Boston, MA  02111-1307  USA.
# ###########################################################################
# QueryRanker package $Revision$
# ###########################################################################
package QueryRanker;

# Read http://code.google.com/p/maatkit/wiki/QueryRankerInternals for
# details about this module.

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use POSIX qw(floor);

use constant MKDEBUG => $ENV{MKDEBUG};

# Significant percentage increase for each bucket.  For example,
# 1us to 4us is a 300% increase, but in reality that is not significant.
# But a 500% increase to 6us may be significant.  In the 1s+ range (last
# bucket), since the time is already so bad, even a 20% increase (e.g. 1s
# to 1.2s) is significant.
# If you change these values, you'll need to update the threshold tests
# in QueryRanker.t.
my @bucket_threshold = qw(500 100  100   500 50   50    20 1   );
my @bucket_labels    = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw() ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
   };
   return bless $self, $class;
}

# Ranks execution results from QueryExecutor::exec().  Returns an array:
#   (
#      rank,         # Integer rank value
#      ( reasons ),  # List of reasons for each rank increase
#   )
sub rank_execution {
   my ( $self, $results ) = @_;
   die "I need a results argument" unless $results;
   
   my $rank    = 0;   # total rank
   my @reasons = ();  # all reasons
   my @res     = ();  # ($rank, @reasons) for each comparison
   my $host1   = $results->{host1};
   my $host2   = $results->{host2};

   @res = $self->compare_query_times($host1->{Query_time},$host2->{Query_time});
   $rank += shift @res;
   push @reasons, @res;

   # Always rank queries with warnings above queries without warnings
   # or queries with identical warnings and no significant time difference.
   # So any query with a warning will have a minimum rank of 1.
   if ( $host1->{warning_count} > 0 || $host2->{warning_count} > 0 ) {
      $rank += 1;
      push @reasons, "Query has warnings (rank+1)";
   }

   if ( my $diff = abs($host1->{warning_count} - $host2->{warning_count}) ) {
      $rank += $diff;
      push @reasons, "Warning counts differ by $diff (rank+$diff)";
   }

   @res = $self->compare_warnings($host1->{warnings}, $host2->{warnings});
   $rank += shift @res;
   push @reasons, @res;

   return $rank, @reasons;
}

# Compares query times and returns a rank increase value if the
# times differ significantly or 0 if they don't.
sub compare_query_times {
   my ( $self, $t1, $t2 ) = @_;
   die "I need a t1 argument" unless defined $t1;
   die "I need a t2 argument" unless defined $t2;

   MKDEBUG && _d('host1 query time:', $t1, 'host2 query time:', $t2);

   my $t1_bucket = bucket_for($t1);
   my $t2_bucket = bucket_for($t2);

   # Times are in different buckets so they differ significantly.
   if ( $t1_bucket != $t2_bucket ) {
      my $rank_inc = 2 * abs($t1_bucket - $t2_bucket);
      return $rank_inc, "Query times differ significantly: "
         . "host1 in ".$bucket_labels[$t1_bucket]." range, "
         . "host2 in ".$bucket_labels[$t2_bucket]." range (rank+2)";
   }

   # Times are in same bucket; check if they differ by that bucket's threshold.
   my $inc = percentage_increase($t1, $t2);
   if ( $inc >= $bucket_threshold[$t1_bucket] ) {
      return 1, "Query time increase $inc\% exceeds "
         . $bucket_threshold[$t1_bucket] . "\% increase threshold for "
         . $bucket_labels[$t1_bucket] . " range (rank+1)";
   }

   return (0);  # No significant difference.
}

# Compares warnings and returns a rank increase value for two times the
# number of warnings with the same code but different level and 3 times
# the number of new warnings.
sub compare_warnings {
   my ( $self, $warnings1, $warnings2 ) = @_;
   die "I need a warnings1 argument" unless defined $warnings1;
   die "I need a warnings2 argument" unless defined $warnings2;

   my %new_warnings;
   my $rank_inc = 0;
   my @reasons;

   foreach my $code ( keys %$warnings1 ) {
      if ( exists $warnings2->{$code} ) {
         if ( $warnings2->{$code}->{Level} ne $warnings1->{$code}->{Level} ) {
            $rank_inc += 2;
            push @reasons, "Error $code changes level: "
               . $warnings1->{$code}->{Level} . " on host1, "
               . $warnings2->{$code}->{Level} . " on host2 (rank+2)";
         }
      }
      else {
         MKDEBUG && _d('New warning on host1:', $code);
         push @reasons, "Error $code on host1 is new (rank+3)";
         %{ $new_warnings{$code} } = %{ $warnings1->{$code} };
      }
   }

   foreach my $code ( keys %$warnings2 ) {
      if ( !exists $warnings1->{$code} && !exists $new_warnings{$code} ) {
         MKDEBUG && _d('New warning on host2:', $code);
         push @reasons, "Error $code on host2 is new (rank+3)";
         %{ $new_warnings{$code} } = %{ $warnings2->{$code} };
      }
   }

   $rank_inc += 3 * scalar keys %new_warnings;

   # TODO: if we ever want to see the new warnings, we'll just have to
   #       modify this sub a litte.  %new_warnings is a placeholder for now.

   return $rank_inc, @reasons;
}

# Ranks results from QueryExecutor::compare_results().  Returns an array:
#   (
#      rank,         # Integer rank value
#      ( reasons ),  # List of reasons for each rank increase
#   )
sub rank_results {
   my ( $self, $results ) = @_;
   die "I need a results argument" unless $results;

   my $rank    = 0;   # total rank
   my @reasons = ();  # all reasons
   my @res     = ();  # ($rank, @reasons) for each comparison
   my $host1   = $results->{host1};
   my $host2   = $results->{host2};

   if ( $host1->{table_checksum} ne $host2->{table_checksum} ) {
      $rank += 50;
      push @reasons, "Table checksums do not match (rank+50)";
   }

   if ( $host1->{n_rows} != $host2->{n_rows} ) {
      $rank += 50;
      push @reasons, "Number of rows do not match (rank+50)";
   }

   @res = $self->compare_table_structs($host1->{table_struct},
                                       $host2->{table_struct});
   $rank += shift @res;
   push @reasons, @res;

   return $rank, @reasons;
}

sub compare_table_structs {
   my ( $self, $s1, $s2 ) = @_;
   die "I need a s1 argument" unless defined $s1;
   die "I need a s2 argument" unless defined $s2;

   my $rank_inc = 0;
   my @reasons  = ();

   # Compare number of columns.
   if ( scalar @{$s1->{cols}} != scalar @{$s2->{cols}} ) {
      my $inc = 2 * abs( scalar @{$s1->{cols}} - scalar @{$s2->{cols}} );
      $rank_inc += $inc;
      push @reasons, 'Tables have different columns counts: '
         . scalar @{$s1->{cols}} . ' columns on host1, '
         . scalar @{$s2->{cols}} . " columns on host2 (rank+$inc)";
   }

   # Compare column types.
   my %host1_missing_cols = %{$s2->{type_for}};  # Make a copy to modify.
   my @host2_missing_cols;
   foreach my $col ( keys %{$s1->{type_for}} ) {
      if ( exists $s2->{type_for}->{$col} ) {
         if ( $s1->{type_for}->{$col} ne $s2->{type_for}->{$col} ) {
            $rank_inc += 3;
            push @reasons, "Types for $col column differ: "
               . "'$s1->{type_for}->{$col}' on host1, "
               . "'$s2->{type_for}->{$col}' on host2 (rank+3)";
         }
         delete $host1_missing_cols{$col};
      }
      else {
         push @host2_missing_cols, $col;
      }
   }

   foreach my $col ( @host2_missing_cols ) {
      $rank_inc += 5;
      push @reasons, "Column $col exists on host1 but not on host2 (rank+5)";
   }
   foreach my $col ( keys %host1_missing_cols ) {
      $rank_inc += 5;
      push @reasons, "Column $col exists on host2 but not on host1 (rank+5)";
   }

   return $rank_inc, @reasons;
}

sub bucket_for {
   my ( $val ) = @_;
   die "I need a val" unless defined $val;
   return 0 if $val == 0;
   # The buckets are powers of ten.  Bucket 0 represents (0 <= val < 10us) 
   # and 7 represents 10s and greater.  The powers are thus constrained to
   # between -6 and 1.  Because these are used as array indexes, we shift
   # up so it's non-negative, to get 0 - 7.
   my $bucket = floor(log($val) / log(10)) + 6;
   $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
   return $bucket;
}

# Returns the percentage increase between two values.
sub percentage_increase {
   my ( $x, $y ) = @_;
   return 0 if $x == $y;

   # Swap values if x > y to keep things simple.
   if ( $x > $y ) {
      my $z = $y;
         $y = $x;
         $x = $z;
   }

   if ( $x == 0 ) {
      # TODO: increase from 0 to some value.  Is this defined mathematically?
      return 1000;  # This should trigger all buckets' thresholds.
   }

   return sprintf '%.2f', (($y - $x) / $x) * 100;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End QueryRanker package
# ###########################################################################
