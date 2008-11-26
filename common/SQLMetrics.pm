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

use constant MKDEBUG => $ENV{MKDEBUG};

use constant METRIC_TYPE_NUMERIC => 1;
use constant METRIC_TYPE_STRING  => 2;
my %metric_type_for = (
   'number' => METRIC_TYPE_NUMERIC,
   'string' => METRIC_TYPE_STRING,
);

# TODO: 'time' metric type?
# TODO: metric operations can be abstracted like:
# %metric_operation_for = (
#    min => sub { ... }
#    max => sub { ... }
#    ...
# )

use Data::Dumper;
$Data::Dumper::Indent = 1;

# A note on terminology:
# - Metric and attribute are the same; they refer to things like Query_time.
# - Event and query are the same; they refer to individual log entries (which
#   are not always queries proper).

# make_handler_for() returns a hashref which should be used to construct
# an arrayref for the handlers arg to new(). Example:
# my $handlers = [
#    make_handler_for('Query_time', 'number', ...),
#    make_handler_for('user',       'string', ...),
# ]
# Then:
# $sm = new SQLMetrics(
#   key_metric      => 'arg',
#   fingerprint     => \&QueryRerwriter::fingerprint,
#   handlers        => $handlers,
#   buffer_n_events => 1_000,
#   ...
# );
#
# NOTE: The first handler is special: it is the metric by which queries
# will be considered "worse" (i.e. worse than one another). Subsequent
# handlers can be in any order.
#
# Optional args to make_handler_for():
#    transformer : sub ref called and passed the metric value before any
#                  calculations (e.g. to transform 'Yes' to 1)
#                  (default none)
#    all_vals    : boolean, save all metric vals for each unique query
#                  (default 1 for numeric types, 0 for strings) 
#    grand_total : boolean, save grand (all-events) total of metric
#                  (e.g. grand total Query_time, most minimal Lock_time, etc.)
#                  For strings, this is the number of times each unique string
#                  appears.
#                  (default 1)
sub make_handler_for {
   my ( $metric, $type, %args ) = @_;
   die "I need a metric"      if !$metric;
   die "I need a metric type" if !$type;
   $type = $metric_type_for{$type} || die 'Invalid metric type';
   my %default_handler = (
      metric       => $metric,
      type         => $type,
      transformer  => undef,
      all_vals     => $type == METRIC_TYPE_NUMERIC ? 1 : 0,
      grand_total  => 1,
   );
   my %handler = ( %default_handler, %args );
   MKDEBUG && _d("Handler for $metric: " . Dumper(\%handler));
   return \%handler;
}

sub new {
   my ( $class, %args ) = @_;
   my @required_args = (
      'key_metric',       # event attribute by which events are grouped
      'fingerprint',      # callback sub to fingerprint key_metric
      'handlers',         # arrayref to metric handlers (see make_handler_for)
   );
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   bless {
      key_metric            => $args{key_metric},
      fingerprint           => $args{fingerprint},
      handlers              => $args{handlers},
      buffer_n_events       => $args{buffer_n_events} || 1,
      worst_metric          => $args{worst_metric},
      metrics               => { all => {}, unique => {} },
      n_events              => 0,
      n_queries             => 0,
      n_unique_queries      => 0,
   }, $class;
}

my @buffered_events;
sub record_event {
   my ( $self, $event ) = @_;
   return if !$event;

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

# Calc metrics for the given events or the buffered events if no
# events are given. events is an arrayref containing events returned
# from LogParser::parse_event().
sub calc_metrics {
   my ( $self, $events ) = @_;
   $events ||= \@buffered_events;
   foreach my $event ( @$events ) {
      $self->calc_event_metrics($event);
   }
   return;
}

sub calc_event_metrics {
   my ( $self, $event ) = @_;

   $self->{n_events}++;

   # Skip events which do not have the key_metric attribute.
   my $key_metric_val = $event->{ $self->{key_metric} };
   return if !defined $key_metric_val;
   $self->{n_queries}++;

   # Get the fingerprint (fp) for this event.
   my $fp = $self->{fingerprint}->($key_metric_val);

   # Get a shortcut to the data store (ds) for this fingerprint.
   my $fp_ds;
   if ( exists $self->{metrics}->{unique}->{ $fp } ) {
      $fp_ds = $self->{metrics}->{unique}->{ $fp };

      # Update the sample if this query has a worst metric val
      # than previous occurrences.
      if (    defined $self->{worst_metric}
           && defined $event->{ $self->{worst_metric} }
           && defined $fp_ds->{ $self->{worst_metric} }->{last}
           && $event->{ $self->{worst_metric} }
              > $fp_ds->{ $self->{worst_metric} }->{last} ) {
         $fp_ds->{sample} = $key_metric_val;
      }
   }
   else {
      $fp_ds = $self->{metrics}->{unique}->{ $fp } = {
         sample => $key_metric_val,
         count => 0,
      };
      $self->{n_unique_queries}++;
   }

   # Count the occurrences of this fingerprint.
   $fp_ds->{count}++;

   # Calc the metrics.
   METRIC:
   foreach my $handler ( @{ $self->{handlers} } ) {
      # Skip metrics which do not exist in this event.
      my $metric_val = $event->{ $handler->{metric} };
      next METRIC if !defined $metric_val;

      $self->_calc_metric($metric_val, $handler, $fp_ds);
   }

   return;
}

sub _calc_metric {
   my ( $self, $metric_val, $handler, $fp_ds ) = @_;
   my $metric = $handler->{metric};

   $metric_val = $handler->{transformer}->($metric_val)
      if defined $handler->{transformer};

   # Get data store shortcuts: one for this event (e_ds)
   # and another for grand totals (g_ds).
   my $e_ds = $fp_ds->{ $metric } ||= {};
   my $g_ds = $self->{metrics}->{all}->{ $metric } ||= {};

   if ( $handler->{type} == METRIC_TYPE_NUMERIC ) {

      # Save the current val for this metric.
      # This is used later to determine if the query sample
      # should be updated.
      $e_ds->{last} = $metric_val;

      $e_ds->{total} += $metric_val;

      $e_ds->{min} = $metric_val if !defined $e_ds->{min};
      $e_ds->{min} = $metric_val if $metric_val < $e_ds->{min};

      $e_ds->{max} = $metric_val if !defined $e_ds->{max};
      $e_ds->{max} = $metric_val if $metric_val > $e_ds->{max};

      my $avg = $e_ds->{total} / $fp_ds->{count};
      $avg = $handler->{transformer}->($avg)
         if defined $handler->{transformer};
      $e_ds->{avg} = $avg;

      push @{ $e_ds->{all_vals} }, $metric_val
         if $handler->{all_vals};

      if ( $handler->{grand_total} ) {
         $g_ds->{total} += $metric_val;

         $g_ds->{min} = $metric_val if !defined $g_ds->{min};
         $g_ds->{min} = $metric_val if $metric_val < $g_ds->{min};

         $g_ds->{max} = $metric_val if !defined $g_ds->{max};
         $g_ds->{max} = $metric_val if $metric_val > $g_ds->{max};

         my $avg = $g_ds->{total} / $self->{n_queries};
         $avg = $handler->{transformer}->($avg)
            if defined $handler->{transformer};
         $g_ds->{avg} = $avg;
      }
   }
   elsif ( $handler->{type} == METRIC_TYPE_STRING ) {
      $e_ds->{ $metric_val }++;
      push @{ $e_ds->{all_vals} }, $metric_val
         if $handler->{all_vals};
      $g_ds->{ $metric_val }++ if $handler->{grand_total};
   }
   else {
      # This should not happen.
      die "Unknown metric type: $handler->{type}";
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
   $self->{n_unique_queries}  = 0;
   $self->{metrics}->{all}    = {};
   $self->{metrics}->{unique} = {};
   return;
}

# Returns a hashref with the following statistical metrcis:
# {
#    avg       => (of 95% vals), 
#    stddev    => (of 95% vals),
#    median    => (of 95% vals),
#    distro    => (if $arg{distro})
#       [
#          vals 0-1us,
#          vals 1us-10us,
#          ...
#       ],
#    cutoff    => cutoff point for 95% vals
# }
sub calculate_statistical_metrics {
   my ( $self, $vals, %args ) = @_;
   my $statistical_metrics = {
      avg       => 0,
      stddev    => 0,
      median    => 0,
      distro    => [],
      cutoff    => undef,
   };
   return $statistical_metrics if !defined $vals;

   my $n_vals = scalar @$vals;
   return $statistical_metrics if !$n_vals;

   if ( $n_vals == 1 ) {
      $statistical_metrics->{avg}    = $vals->[0];
      $statistical_metrics->{median} = $vals->[0];
      return $statistical_metrics;
   }

   # Reduce vals to lower 95% percent if there is at least 10 vals.
   if ( $n_vals >= 10 ) {
      $statistical_metrics->{cutoff} = int ( scalar @$vals * 0.95 );
   }
   else {
      $statistical_metrics->{cutoff} = $n_vals;
   }

   # Note: cutoff serves also for the number of vals left in the 95%.
   # E.g. with 50 vals the cutoff is 47 which means there are 47 vals: 0..46.

   # Used for getting the median val.
   my $middle_val_n = int $statistical_metrics->{cutoff} / 2;
   my $previous_val;

   my $sum    = 0; # stddev and 95% avg
   my $sumsq  = 0; # stddev
   my $val_n  = 0; # val number for knowing when we've reach the 95%
   foreach my $val ( sort { $a <=> $b } @$vals ) {
      # Distribution of vals for all vals, if requested.
      if ( $args{distro} ) {
      }

      # stddev and median only for 95% vals.
      if ( $val_n < $statistical_metrics->{cutoff} ) {

         # Median
         if ( $val_n == $middle_val_n ) {
            if ( $statistical_metrics->{cutoff} % 2 ) {
               $statistical_metrics->{median} = $val;
            }
            else {
               $statistical_metrics->{median} = ($previous_val + $val) / 2;
            }
         }

         # The following stddev algo was adapted from
         # http://www.linuxjournal.com/article/6540
         $sum   += $val;
         $sumsq += ($val **2);

         $val_n++;

         # Needed for calcing median when list has even number of elements.
         $previous_val = $val;
      }
   }

   $statistical_metrics->{stddev}
      = sprintf "%.1f",
         sqrt $sumsq / $statistical_metrics->{cutoff}
            - (($sum / $statistical_metrics->{cutoff}) ** 2);

   $statistical_metrics->{avg} = $sum / $statistical_metrics->{cutoff};

   return $statistical_metrics;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# SQLMetrics:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End SQLMetrics package
# ###########################################################################
