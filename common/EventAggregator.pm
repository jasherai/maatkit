# This program is copyright 2008-@CURRENTYEAR@ Percona Inc.
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
# EventAggregator package $Revision$
# ###########################################################################

package EventAggregator;

# This package's function is to take hashrefs and aggregate them as you specify.
# It basically does a GROUP BY.  If you say to group by z and calculate
# aggregate statistics for a, b, c then it manufactures functions to record
# various kinds of stats for the a per z, b per z, and c per z in incoming
# hashrefs.  Usually you'll use it a little less abstractly: you'll say the
# incoming hashrefs are parsed query events from the MySQL slow query log, and
# you want it to calculate stats for Query_time, Rows_read etc aggregated by
# query fingerprint.  It automatically determines whether a specified property
# is a string, number or Yes/No value and aggregates them appropriately.  It can
# collect and aggregate by several things simultaneously, e.g. you could group
# by fingerprint at the same time that you group by user.

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use POSIX qw(floor);

# ###########################################################################
# Set up some constants for bucketing values.  It is impossible to keep all
# values seen in memory, but putting them into logarithmically scaled buckets
# and just incrementing the bucket each time works, although it is imprecise.
# ###########################################################################
use constant MKDEBUG      => $ENV{MKDEBUG};
use constant BUCK_SIZE    => 1.05;
use constant BASE_LOG     => log(BUCK_SIZE);
use constant BASE_OFFSET  => -floor(log(.000001) / BASE_LOG); # typically 284
use constant NUM_BUCK     => 1000;
use constant MIN_BUCK     => .000001;

our @buckets  = map { 0 } (1 .. NUM_BUCK);
my @buck_vals = (MIN_BUCK, MIN_BUCK * BUCK_SIZE);
{
   my $cur = BUCK_SIZE;
   for ( 2 .. NUM_BUCK - 1 ) {
      push @buck_vals, MIN_BUCK * ($cur *= BUCK_SIZE);
   }
}

# The best way to see how to use this is to look at the .t file.
#
# %args is a hash containing:
# groupby      The name of the property to group/aggregate by.
# attributes   A hashref.  Each key is the name of an element to aggregate.
#              And the values of those elements are arrayrefs of the
#              values to pull from the hashref, with any second or subsequent
#              values being fallbacks for the first in case it's not defined.
# worst        The name of an element which defines the "worst" hashref in its
#              class.  If this is Query_time, then each class will contain
#              a sample that holds the event with the largest Query_time.
# unroll_limit If this many events have been processed and some handlers haven't
#              been generated yet (due to lack of sample data) unroll the loop
#              anyway.  Defaults to 50.
# attrib_limit Sanity limit for attribute values.  If the value exceeds the
#              limit, use the last-seen for this class; if none, then 0.
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(groupby worst attributes) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   return bless {
      groupby      => $args{groupby},
      attributes   => {
         map  { $_ => $args{attributes}->{$_} }
         grep { $_ ne $args{groupby} }
         keys %{$args{attributes}}
      },
      worst        => $args{worst},
      unroll_limit => $args{unroll_limit} || 50,
      attrib_limit => $args{attrib_limit},
   }, $class;
}

# Aggregate an event hashref's properties.
sub aggregate {
   my ( $self, $event ) = @_;

   my $group_by = $event->{$self->{groupby}};
   return unless defined $group_by;

   ATTRIB:
   foreach my $attrib ( keys %{$self->{attributes}} ) {
      # The value of the attribute ( $group_by ) may be an arrayref.
      GROUPBY:
      foreach my $val ( ref $group_by ? @$group_by : ($group_by) ) {
         my $class_attrib  = $self->{result_class}->{$val}->{$attrib} ||= {};
         my $global_attrib = $self->{result_globals}->{$attrib} ||= {};
         my $handler = $self->{handlers}->{ $attrib };
         if ( !$handler ) {
            $handler = $self->make_handler(
               $attrib,
               $event,
               wor => $self->{worst} eq $attrib,
               alt => $self->{attributes}->{$attrib},
            );
            $self->{handlers}->{$attrib} = $handler;
         }
         next GROUPBY unless $handler;
         $handler->($event, $class_attrib, $global_attrib);
      }
   }
}

# Return the aggregated results.
sub results {
   my ( $self ) = @_;
   return {
      classes => $self->{result_class},
      globals => $self->{result_globals},
   };
}

# Return the attributes that this object is tracking, and their data types, as
# a hashref of name => type.
sub attributes {
   my ( $self ) = @_;
   return $self->{type_for};
}

# Make subroutines that do things with events.
#
# $attrib: the name of the attrib (Query_time, Rows_read, etc)
# $event:  a sample event
# %args:
#     min => keep min for this attrib (default except strings)
#     max => keep max (default except strings)
#     sum => keep sum (default for numerics)
#     cnt => keep count (default except strings)
#     unq => keep all unique values per-class (default for strings and bools)
#     all => keep a bucketed list of values seen per class (default for numerics)
#     glo => keep stats globally as well as per-class (default)
#     trf => An expression to transform the value before working with it
#     wor => Whether to keep worst-samples for this attrib (default no)
#     alt => Arrayref of other name(s) for the attribute, like db => Schema.
#
# The bucketed list works this way: each range of values from MIN_BUCK in
# increments of BUCK_SIZE (that is 5%) we consider a bucket.  We keep NUM_BUCK
# buckets.  The upper end of the range is more than 1.5e15 so it should be big
# enough for almost anything.  The buckets are accessed by a log base BUCK_SIZE,
# so floor(log(N)/log(BUCK_SIZE)).  The smallest bucket's index is -284. We
# shift all values up 284 so we have values from 0 to 999 that can be used as
# array indexes.  A value that falls into a bucket simply increments the array
# entry.
#
# This eliminates the need to keep and sort all values to calculate median,
# standard deviation, 95th percentile etc.  Thus the memory usage is bounded by
# the number of distinct aggregated values, not the number of events.
#
# Return value:
# a subroutine with this signature:
#    my ( $event, $class, $global ) = @_;
# where
#  $event   is the event
#  $class   is the container to store the aggregated values
#  $global  is is the container to store the globally aggregated values
sub make_handler {
   my ( $self, $attrib, $event, %args ) = @_;
   die "I need an attrib" unless defined $attrib;
   my ($val) = grep { defined $_ } map { $event->{$_} } @{ $args{alt} };
   my $is_array = 0;
   if (ref $val eq 'ARRAY') {
      $is_array = 1;
      $val      = $val->[0];
   }
   return unless defined $val; # Can't decide type if it's undef.

   # Ripped off from Regexp::Common::number.
   my $float_re = qr{[+-]?(?:(?=\d|[.])\d*(?:[.])\d{0,})?(?:[E](?:[+-]?\d+)|)}i;
   my $type = $val  =~ m/^(?:\d+|$float_re)$/o ? 'num'
            : $val  =~ m/^(?:Yes|No)$/         ? 'bool'
            :                                    'string';
   MKDEBUG && _d("Type for $attrib is $type (sample: $val), is array: $is_array");
   $self->{type_for}->{$attrib} = $type;

   %args = ( # Set up defaults
      min => 1,
      max => 1,
      sum => $type =~ m/num|bool/    ? 1 : 0,
      cnt => 1,
      unq => $type =~ m/bool|string/ ? 1 : 0,
      all => $type eq 'num'          ? 1 : 0,
      glo => 1,
      trf => ($type eq 'bool') ? q{($val || '' eq 'Yes') ? 1 : 0} : undef,
      wor => 0,
      alt => [],
      %args,
   );

   my @lines = ("# type: $type"); # Lines of code for the subroutine
   if ( $args{trf} ) {
      push @lines, q{$val = } . $args{trf} . ';';
   }

   foreach my $place ( qw($class $global) ) {
      my @tmp;
      if ( $args{min} ) {
         my $op   = $type eq 'num' ? '<' : 'lt';
         push @tmp, (
            'PLACE->{min} = $val if !defined PLACE->{min} || $val '
               . $op . ' PLACE->{min};',
         );
      }
      if ( $args{max} ) {
         my $op = ($type eq 'num') ? '>' : 'gt';
         push @tmp, (
            'PLACE->{max} = $val if !defined PLACE->{max} || $val '
               . $op . ' PLACE->{max};',
         );
      }
      if ( $args{sum} ) {
         push @tmp, 'PLACE->{sum} += $val;';
      }
      if ( $args{cnt} ) {
         push @tmp, '++PLACE->{cnt};';
      }
      if ( $args{all} ) {
         push @tmp, (
            # If you change this code, change the similar code in bucketize.
            'PLACE->{all} ||= [ @buckets ];',
            '$idx = BASE_OFFSET + ($val > 0 ? floor(log($val) / BASE_LOG) : 0);',
            '++PLACE->{all}->[ $idx > NUM_BUCK ? NUM_BUCK : $idx ];',
         );
      }
      push @lines, map { s/PLACE/$place/g; $_ } @tmp;
   }

   # We only save unique/worst values for the class, not globally.
   if ( $args{unq} ) {
      push @lines, '++$class->{unq}->{$val};';
   }
   if ( $args{wor} ) {
      my $op = $type eq 'num' ? '>=' : 'ge';
      push @lines, (
         'if ( $val ' . $op . ' ($class->{max} || 0) ) {',
         '   $class->{sample} = $event;',
         '}',
      );
   }

   # Make sure the value is constrained to legal limits.  If it's out of bounds,
   # just use the last-seen value for it.
   my @limit;
   if ( $args{all} && $type eq 'num' && $self->{attrib_limit} ) {
      push @limit, (
         "if ( \$val > $self->{attrib_limit} ) {",
         '   $val = $class->{last} ||= 0;',
         '}',
         '$class->{last} = $val;',
      );
   }

   # Save the code for later, as part of an "unrolled" subroutine.
   my @unrolled = (
      '$val = $event->{' . $attrib . '};',
      (map { "\$val = \$event->{$_} unless defined \$val;" } @{$args{alt}}),
      'defined $val && do {',
      ( map { s/^/   /gm; $_ } (@limit, @lines) ), # Indent for debugging
      '};',
   );
   $self->{unrolled_for}->{$attrib} = join("\n", @unrolled);

   # Build a subroutine with the code.
   unshift @lines, (
      'sub {',
      'my ( $event, $class, $global ) = @_;',
      'my ($val, $idx);', # NOTE: define all variables here
      (map { "\$val = \$event->{$_} unless defined \$val;" } @{$args{alt}}),
      'return unless defined $val;',
      ($is_array ? ('foreach my $val ( @$val ) {') : ()),
      @limit,
      ($is_array ? ('}') : ()),
   );
   push @lines, '}';
   my $code = join("\n", @lines);
   $self->{code_for}->{$attrib} = $code;

   MKDEBUG && _d("Metric handler for $attrib: ", @lines);
   my $sub = eval join("\n", @lines);
   die if $EVAL_ERROR;
   return $sub;
}

# This method is for testing only.  If you change this code, change the code
# above too (look for bucketize).
sub bucketize {
   my ( $self, $vals ) = @_;
   my @bucketed = @buckets;
   my ($sum, $max, $min);
   $max = $min = $vals->[0];
   foreach my $val ( @$vals ) {
      my $idx = BASE_OFFSET + ($val > 0 ? floor(log($val) / BASE_LOG) : 0);
      ++$bucketed[ $idx > NUM_BUCK ? NUM_BUCK : $idx ];
      $max = $max > $val ? $max : $val;
      $min = $min < $val ? $min : $val;
      $sum += $val;
   }
   return (\@bucketed, { sum => $sum, max => $max, min => $min, cnt => scalar @$vals});
}

# This method is for testing only.
sub unbucketize {
   my ( $self, $vals ) = @_;
   my @result;
   foreach my $i ( 0 .. NUM_BUCK - 1 ) {
      next unless $vals->[$i];
      foreach my $j ( 1 .. $vals->[$i] ) {
         push @result, $buck_vals[$i];
      }
   }
   return @result;
}

# Break the buckets down into powers of ten, in 8 coarser buckets.  Bucket 0
# represents (0 <= val < 10us) and 7 represents 10s and greater.  The powers are
# thus constrained to between -6 and 1.  Because these are used as array
# indexes, we shift up so it's non-negative, to get 0 to 7.  Now you have a list
# of 1000 buckets that act as a lookup table between the 5% buckets and buckets
# of 10. TODO: right now it's hardcoded to buckets of 10, in the future maybe
# not.
{
   my @buck_tens;
   sub buckets_of {
      return @buck_tens if @buck_tens;
      @buck_tens = map {
         my $f = floor(log($_) / log(10)) + 6;
         $f > 7 ? 7 : $f;
      } @buck_vals;
      return @buck_tens;
   }
}

# Given an arrayref of vals, returns a hashref with the following
# statistical metrics:
#
#    pct_95    => The 95th percentile
#    cutoff    => How many values fall into the 95th percentile
#    stddev    => of 95% values
#    median    => of 95% values
#
# The vals arrayref is the buckets as per the above (see the comments at the top
# of this file).  $args should contain cnt, min, max and sum properties.
sub calculate_statistical_metrics {
   my ( $self, $vals, $args ) = @_;
   my $statistical_metrics = {
      pct_95    => 0,
      stddev    => 0,
      median    => 0,
      cutoff    => undef,
   };

   # These cases might happen when there is nothing to get from the event, for
   # example, processlist sniffing doesn't gather Rows_examined, so $args won't
   # have {cnt} or other properties.
   return $statistical_metrics
      unless defined $vals && @$vals && $args->{cnt};

   # Return accurate metrics for some cases.
   my $n_vals = $args->{cnt};
   if ( $n_vals == 1 || $args->{max} == $args->{min} ) {
      my $v      = $args->{max} || 0;
      my $bucket = floor( log($v > 0 ? $v : MIN_BUCK) / log(10)) + 6;
      $bucket    = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      return {
         pct_95 => $v,
         stddev => 0,
         median => $v,
         cutoff => $n_vals,
      };
   }
   elsif ( $n_vals == 2 ) {
      foreach my $v ( $args->{min}, $args->{max} ) {
         my $bucket = floor( log($v && $v > 0 ? $v : MIN_BUCK) / log(10)) + 6;
         $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      }
      my $v      = $args->{max} || 0;
      my $mean = (($args->{min} || 0) + $v) / 2;
      return {
         pct_95 => $v,
         stddev => sqrt((($v - $mean) ** 2) *2),
         median => $mean,
         cutoff => $n_vals,
      };
   }

   # Determine cutoff point for 95% if there are at least 10 vals.  Cutoff
   # serves also for the number of vals left in the 95%.  E.g. with 50 vals the
   # cutoff is 47 which means there are 47 vals: 0..46.  $cutoff is NOT an array
   # index.
   my $cutoff = $n_vals >= 10 ? int ( $n_vals * 0.95 ) : $n_vals;
   $statistical_metrics->{cutoff} = $cutoff;

   my $total_left = $n_vals;
   my $i = NUM_BUCK - 1;

   # Find the 95th percentile biggest value.  And calculate the values of the
   # ones we exclude.
   my $sum_excl  = 0;
   while ( $i-- && $total_left > $cutoff ) {
      if ( $vals->[$i] ) {
         $total_left -= $vals->[$i];
         $sum_excl   += $buck_vals[$i] * $vals->[$i];
      }
   }

   # Continue until we find the next array element that has a value.
   my $bucket_95;
   while ( $i-- ){
      $bucket_95 = $i;
      last if $vals->[$i];
   }
   return $statistical_metrics unless $vals->[$bucket_95];
   # At this point, $bucket_95 points to the first value we want to keep.

   # Calculate the standard deviation, median, and max value of the 95th
   # percentile of values.
   my $sum    = $buck_vals[$bucket_95] * $vals->[$bucket_95];
   my $sumsq  = $sum ** 2;
   my $mid    = int($cutoff / 2);
   my $median = 0;
   my $prev   = $bucket_95; # Used for getting median when $cutoff is odd

   # Continue through the rest of the values.
   while ( $i-- ) {
      my $val = $vals->[$i];
      if ( $val ) {
         $total_left -= $val;
         if ( !$median && $total_left <= $mid ) {
            $median = (($cutoff % 2) || ($val > 1)) ? $buck_vals[$i]
                    : ($buck_vals[$i] + $buck_vals[$prev]) / 2;
         }
         $sum        += $buck_vals[$i] * $val;
         $sumsq      += ($buck_vals[$i] ** 2 ) * $val;
         $prev       =  $i;
      }
   }

   my $stddev   = sqrt (($sumsq - (($sum**2) / $cutoff)) / ($cutoff -1 || 1));
   my $maxstdev = (($args->{max} || 0) - ($args->{min} || 0)) / 2;
   $stddev      = $stddev > $maxstdev ? $maxstdev : $stddev;

   MKDEBUG && _d("95 cutoff $cutoff, sum $sum, sumsq $sumsq, stddev $stddev");

   $statistical_metrics->{stddev} = $stddev;
   $statistical_metrics->{pct_95} = $buck_vals[$bucket_95];
   $statistical_metrics->{median} = $median;

   return $statistical_metrics;
}

# Find the top N or top % event keys, in sorted order, optionally including
# outliers (ol_...) that are notable for some reason.  %args looks like this:
#
#  attrib      order-by attribute (usually Query_time)
#  orderby     order-by aggregate expression (should be numeric, usually sum)
#  total       include events whose summed attribs are <= this number...
#  count       ...or this many events, whichever is less...
#  ol_attrib   ...or events where the 95th percentile of this attribute...
#  ol_limit    ...is greater than this value, AND...
#  ol_freq     ...the event occurred at least this many times.
sub top_events {
   my ( $self, %args ) = @_;
   my $classes = $self->{result_class};
   my @sorted = reverse sort { # Sorted list of $groupby values
      $classes->{$a}->{$args{attrib}}->{$args{orderby}}
         <=> $classes->{$b}->{$args{attrib}}->{$args{orderby}}
      } keys %$classes;
   my @chosen;
   my ($total, $count) = (0, 0);
   foreach my $groupby ( @sorted ) {
      # Events that fall into the top criterion for some reason
      if ( 
         (!$args{total} || $total < $args{total} )
         && ( !$args{count} || $count < $args{count} )
      ) {
         push @chosen, $groupby;
      }

      # Events that are notable outliers
      elsif ( $args{ol_attrib} && (!$args{ol_freq}
         || $classes->{$groupby}->{$args{ol_attrib}}->{cnt} >= $args{ol_freq})
      ) {
         # Calculate the 95th percentile of this event's specified attribute.
         my $stats = $self->calculate_statistical_metrics(
            $classes->{$groupby}->{$args{ol_attrib}}->{all},
            $classes->{$groupby}->{$args{ol_attrib}}
         );
         if ( $stats->{pct_95} >= $args{ol_limit} ) {
            push @chosen, $groupby;
         }
      }

      $total += $classes->{$groupby}->{$args{attrib}}->{$args{orderby}};
      $count++;
   }
   return @chosen;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   # Use $$ instead of $PID in case the package
   # does not use English.
   print "# $package:$line $$ ", @_, "\n";
}

1;

# ###########################################################################
# End EventAggregator package
# ###########################################################################
