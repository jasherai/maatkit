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
# CompareQueryTimes package $Revision: 4970 $
# ###########################################################################
package CompareQueryTimes;

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
   my @required_args = qw();
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      %args,
   };
   return bless $self, $class;
}

sub before_execute {
   my ( $self, %args ) = @_;
   return;
}

sub execute {
   my ( $self, %args ) = @_;
   return;
}

sub after_execute {
   my ( $self, %args ) = @_;
   return;
}

sub compare {
   my ( $t1, $t2 ) = @_;
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
# End CompareQueryTimes package
# ###########################################################################
