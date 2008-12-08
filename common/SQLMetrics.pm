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
# SQLMetrics package $Revision$
# ###########################################################################
package SQLMetrics;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use POSIX qw(floor);
use Time::Local qw(timelocal);

use constant MKDEBUG => $ENV{MKDEBUG};

# %args is a hash containing:
# key_metric   the attribute by which events are aggregated.  Usually this will
#              be 'arg' because $event->{arg} is the query in a parsed slowlog
#              event.  Events with the same key_metric (after fingerprinting)
#              are treated as a class.
# fingerprint  A subroutine to transform the key_metric if desired.  Usually
#              this will be QueryRewriter::fingerprint() for slowlog parsing.
# handlers     An optional hashref that explicitly says how to handle an
#              attribute for which you want to calculate metrics.
# attributes   An arrayref of attributes you want to calculate metrics for.  If
#              you don't specify handlers for them, they'll be auto-created.  In
#              most cases this will work fine.  If you specify an attribute with
#              an | symbol, it means that the subsequent attributes are
#              fallbacks.  For example, ts|timestamp means if ts is available,
#              it'll be used; else timestamp will be used.  Similarly with db|Schema.
# worst_metric An attribute name.  When an event is seen, its worst_metric is
#              compared to the greatest worst_metric ever seen for this class of
#              event.  If it's greater, the event's key_metric is stored as the
#              representative sample of this class of event, and the event's
#              position in the log is stored too.  TODO: we could
#              make this a subroutine.  For example, 'worst' might be
#              rows_examined/rows_returned, or just rows_returned, and we might
#              want to see queries that returned 0 rows.
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(key_metric attributes) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   $args{handlers} ||= {};

   my %attribute_spec = map {
      (my $key = $_) =~ s/\|.*//;
      $key => $_;
   } @{$args{attributes}};
   foreach my $metric ( keys %{$args{handlers}} ) {
      $attribute_spec{$metric}++;
   }

   my $self = {
      key_metric            => $args{key_metric},
      fingerprint           => $args{fingerprint}
                               || sub { $_[0]->{$args{key_metric}} },
      attributes            => \%attribute_spec,
      handlers              => $args{handlers},
      buffer_n_events       => $args{buffer_n_events} || 1,
      worst_metric          => $args{worst_metric},
      metrics               => { all => {}, unique => {} },
      n_events              => 0,
      n_queries             => 0,
   };

   return bless $self, $class;
}

# Make subroutines that do things with events.
#
# $metric: the name of the metric (Query_time, Rows_read, etc)
# $value:  a sample of the metric's value
# %args:
#     min => keep min for this metric (default)
#     max => keep max (default)
#     sum => keep sum (default for numerics)
#     cnt => keep count (default)
#     unq => keep all unique values per-class (default for strings and bools)
#     all => keep a list of all values seen per class (default for numerics)
#     glo => keep stats globally as well as per-class (default)
#     trx => An expression to transform the value before working with it
#     wor => Whether to keep worst-samples for this metric (default no)
#
# Return value:
# a subroutine with this signature:
#    my ( $event, $val, $class, $global ) = @_;
# where
#  $event   is the event
#  $val     is the metric value for an event
#  $class   is the stats for the event's class
#  $global  is the global data store.
sub make_handler {
   my ( $metric, $value, %args ) = @_;
   die "I need a metric and value" unless $metric && $value;
   return unless defined $value; # Can't decide type if it's undef.
   my $type = $metric =~ m/^(?:ts|timestamp)$/ ? 'time'
            : $value  =~ m/^\d+/               ? 'num'
            : $value  =~ m/^(?:Yes|No)$/       ? 'bool'
            :                                    'string';
   %args = ( # Set up defaults
      min => 1,
      max => 1,
      sum => $type eq 'num' ? 1 : 0,
      cnt => 1,
      unq => $type =~ m/bool|string/ ? 1 : 0,
      all => $type eq 'num' ? 1 : 0,
      glo => 1,
      trx => ($type eq 'time') ? 'parse_timestamp($val)'
           : ($type eq 'bool') ? q{$val eq 'Yes'}
           :                     undef,
      wor => 0,
      %args,
   );

   my @lines = ( # Lines of code for the subroutine
      'sub {',
      'my ( $event, $val, $class, $global ) = @_;',
      'return unless defined $val;',
   );
   if ( $args{trx} ) {
      push @lines, q{$val = } . $args{trx} . ';';
   }
   foreach my $place ( $args{glo} ? qw($class $global) : qw($class) ) {
      if ( $args{min} ) {
         my $op = $type =~ m/num|time/ ? '<' : 'lt';
         my $code = 'PLACE->{min} = $val if !defined PLACE->{min} || $val '
            . $op . ' PLACE->{min};';
         $code =~ s/PLACE/$place/g;
         push @lines, $code;
      }
      if ( $args{max} ) {
         my $op = $type eq 'num' ? '>' : 'gt';
         my $code = 'PLACE->{max} = $val if !defined PLACE->{max} || $val '
            . $op . ' PLACE->{max};';
         $code =~ s/PLACE/$place/g;
         push @lines, $code;
      }
      if ( $args{sum} ) {
         my $code = 'PLACE->{sum} += $val;';
         $code =~ s/PLACE/$place/g;
         push @lines, $code;
      }
      if ( $args{cnt} ) {
         my $code = '++PLACE->{cnt};';
         $code =~ s/PLACE/$place/g;
         push @lines, $code;
      }
      if ( $place eq '$class' ) {
         if ( $args{unq} ) {
            my $code = '++PLACE->{unq}->{$val};';
            $code =~ s/PLACE/$place/g;
            push @lines, $code;
         }
         if ( $args{all} ) {
            my $code = 'push @{PLACE->{all}}, $val;';
            $code =~ s/PLACE/$place/g;
            push @lines, $code;
         }
         if ( $args{wor} ) {
            my $op = $type eq 'num' ? '>=' : 'ge';
            # Update the sample and pos_in_log if this event is worst in class.
            push @lines, (
               'if ( $val ' . $op . ' ($class->{max} || 0) ) {',
               '$class->{sample}     = $event->{arg};',
               '$class->{pos_in_log} = $event->{pos_in_log};',
               '}',
            );
         }
      }
   }
   push @lines, '}';
   MKDEBUG && _d("Metric handler for $metric: ", @lines);
   my $sub = eval join("\n", @lines);
   die if $EVAL_ERROR;
   return $sub;
}

# TODO: is record_event and event buffering used?  If not, let's remove it.
my @buffered_events;
sub record_event {
   my ( $self, $event ) = @_;
   return unless $event;

   push @buffered_events, $event;
   MKDEBUG && _d(scalar @buffered_events . " events in buffer");

   # Return if we are to buffer every event.
   return if $self->{buffer_n_events} < 0;

   # Return if we are to buffer N events and buffer space remains.
   return if scalar @buffered_events < $self->{buffer_n_events};

   $self->calc_metrics(\@buffered_events);

   # Reset buffer if it is full.
   $self->reset_buffer() if scalar @buffered_events >= $self->{buffer_n_events};

   return;
}

# Calculate metrics for the given events or the buffered events if no
# events are given. $events is an arrayref containing events returned
# from LogParser::parse_event().
sub calc_metrics {
   my ( $self, $events ) = @_;
   $events ||= \@buffered_events;
   foreach my $event ( @$events ) {
      $self->calc_event_metrics($event);
   }
   return;
}

# Calculate metrics about a single event.  Usually an event will be something
# like a query from a slow log, and the $event->{arg} will be the query text.
sub calc_event_metrics {
   my ( $self, $event ) = @_;

   $self->{n_events}++;

   # Skip events which do not have the key_metric attribute.
   my $key_metric_val = $event->{ $self->{key_metric} };
   return unless defined $key_metric_val;

   $self->{n_queries}++;

   # Get the fingerprint (fp) for this event.
   my $fp = $self->{fingerprint}->($key_metric_val);

   # Get a shortcut to the data store (ds) for this class of events.
   my $fp_ds = $self->{metrics}->{unique}->{ $fp } ||= {};

   # Calculate the metrics.  Auto-vivify handler subs as they are needed.
   METRIC:
   foreach my $metric ( keys %{ $self->{attributes} } ) {
      my $metric_val = $event->{ $metric };
      next METRIC unless defined $metric_val;
      # Get data store shortcuts.
      my $stats_for_metric = $self->{metrics}->{all}->{ $metric } ||= {};
      my $stats_for_class  = $fp_ds->{ $metric } ||= {};
      my $sub = $self->{handlers}->{$metric} ||= make_handler(
         $self->{attributes}->{$metric}, $metric_val,
         wor => (($self->{worst_metric} || '') eq $metric)
      );
      if ( ref $sub ) {
         $sub->($event, $metric_val, $stats_for_class, $stats_for_metric);
      }
   }

   return;
}

sub reset_buffer {
   my ( $self ) = @_;
   @buffered_events = ();
   MKDEBUG && _d('Reset event buffer');
   return;
}

sub reset_metrics {
   my ( $self ) = @_;
   @buffered_events           = ();
   $self->{n_events}          = 0;
   $self->{n_queries}         = 0;
   $self->{metrics}->{all}    = {};
   $self->{metrics}->{unique} = {};
   return;
}

# Returns a hashref with the following statistical metrics:
# {
#    avg       => (of 95% vals), 
#    stddev    => (of 95% vals),
#    median    => (of 95% vals),
#    distro    => (if $arg{distro})
#       [
#          0: number of vals in the 1us range  (0    <= val < 10us)
#          1: number of vals in the 10us range (10us <= val < 100us)
#             ...
#          7: number of vals >= 10s
#       ],
#    cutoff    => cutoff point for 95% vals
# }
sub calculate_statistical_metrics {
   my ( $self, $vals, %args ) = @_;
   my @distro              = qw(0 0 0 0 0 0 0 0);
   my $statistical_metrics = {
      avg       => 0,
      stddev    => 0,
      median    => 0,
      distro    => \@distro,
      cutoff    => undef,
   };
   return $statistical_metrics unless defined $vals;

   my $n_vals = scalar @$vals;
   return $statistical_metrics unless $n_vals;

   # Determine cutoff point for 95% if there are at least 10 vals.
   # Cutoff serves also for the number of vals left in the 95%.
   # E.g. with 50 vals the cutoff is 47 which means there are 47 vals: 0..46.
   my $cutoff = $n_vals >= 10 ? int ( scalar @$vals * 0.95 ) : $n_vals;
   $statistical_metrics->{cutoff} = $cutoff;

   # Used for getting the median val.
   my $middle_val_n = int $statistical_metrics->{cutoff} / 2;
   my $previous_val;

   my $sum    = 0; # stddev and 95% avg
   my $sumsq  = 0; # stddev
   my $i      = 0; # for knowing when we've reached the 95%
   foreach my $val ( sort { $a <=> $b } @$vals ) {
      # Distribution of vals for all vals, if requested.
      if ( defined $val && $args{distro} ) {
         # The buckets are powers of ten.  Bucket 0 represents (0 <= val < 10us) 
         # and 7 represents 10s and greater.  The powers are thus constrained to
         # between -6 and 1.  Because these are used as array indexes, we shift
         # up so it's non-negative, to get 0 - 7.
         my $bucket = floor(log($val) / log(10)) + 6;
         $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
         $distro[ $bucket ]++;
      }

      # stddev and median only for 95% vals.
      if ( $i < $cutoff ) {
         # Median
         if ( $i == $middle_val_n ) {
            $statistical_metrics->{median}
               = $cutoff % 2 ? $val : ($previous_val + $val) / 2;
         }

         $sum   += $val;
         $sumsq += ($val **2);
         $i++;

         # Needed for calcing median when list has even number of elements.
         $previous_val = $val;
      }
   }

   my $stddev = sqrt (($sumsq - (($sum**2) / $cutoff)) / ($cutoff -1 || 1));

   MKDEBUG && _d("95 cutoff $cutoff, sum $sum, sumsq $sumsq, stddev $stddev");

   $statistical_metrics->{stddev} = $stddev;
   $statistical_metrics->{avg}    = $sum / $cutoff;

   return $statistical_metrics;
}

# Turns 071015 21:43:52 into a Unix timestamp.
sub parse_timestamp {
   my ( $val ) = @_;
   if ( my($y, $m, $d, $h, $i, $s)
         = $val =~ m/^(\d\d)(\d\d)(\d\d) +(\d+):(\d+):(\d+)$/ )
   {
      $val = timelocal($s, $i, $h, $d, $m - 1, $y + 2000);
   }
   return $val;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# SQLMetrics:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End SQLMetrics package
# ###########################################################################
