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

# make_handler_for() returns a key-value pair which should be used to construct
# a hash for the handlers arg to new(). Example:
# my $handlers = {
#    make_handler_for('Query_time', 'number', ...),
#    make_handler_for('user',       'string', ...),
# }
# Then:
# $sm = new SQLMetrics(
#   key_metric      => 'arg',
#   fingerprint     => \&QueryRerwriter::fingerprint,
#   handlers        => $handlers,
#   buffer_n_events => 1_000,
# );
# Optional args:
#    transformer  : sub ref called and passed the metric value before any
#                   calculations
#                   (default none)
#    total        : boolean, if total value should be saved (e.g. total
#                   Query_time for each unique query)
#                   (default 1)
#    min, max, avg: boolean, if min max and/or avg values should be saved
#                   (default 1 1 1)
#    all_vals     : boolean, save all metric vals for each enabled
#                   query-specific metric
#                   (default 1) 
#    all_events   : boolean, for any of the query-specific metrics above which
#                   are enabled, save also the metric for all queries
#                   (e.g. grand total Query_time for all queries)
#                   (default 0)
#    all_all_vals : boolean, like all_vals but saves all vals for all enabled
#                   query metrics, which can result in very large arrays of vals
#                   (default 0)
sub make_handler_for {
   my ( $metric, $type, %args ) = @_;
   die "I need a metric"      if !$metric;
   die "I need a metric type" if !$type;

   $type = $metric_type_for{$type} || die 'Invalid metric type';

   my %default_handler = (
      type         => $type,
      transformer  => undef,
      all_vals     => 1,
      all_events   => 0,
      all_all_vals => 0,
   );
   @default_handler{ qw(total min max avg) } = qw(1 1 1 1)
      if $type == METRIC_TYPE_NUMERIC;

   my %handler = ( %default_handler, %args );

   if ( $type == METRIC_TYPE_NUMERIC ) {
      # total is required to calc avg
      $handler{total} = 1 if $handler{avg} == 1;
   }

   MKDEBUG && _d("Handler for $metric: " . Dumper(\%handler));

   return ( $metric => \%handler );
}

sub new {
   my ( $class, %args ) = @_;
   my @required_args = (
      'key_metric',      # event attribute by which events are grouped
      'fingerprint',     # callback sub to fingerprint key_metric
      'handlers',        # hash ref to metric handlers (see make_handler_for)
      'buffer_n_events', # save N events before calcing their metrics
   );
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   bless {
      key_metric         => $args{key_metric},
      fingerprint        => $args{fingerprint},
      handlers           => $args{handlers},
      buffer_n_events    => $args{buffer_n_events},
      metrics            => { all => {}, unique => {} },
      n_events           => 0,
      n_queries          => 0,
   }, $class;
}

my @buffered_events;
sub record_event {
   my ( $self, $event ) = @_;
   return if !$event;

   $self->{n_events}++;
   push @buffered_events, $event;
   MKDEBUG && _d("$self->{n_events} events total, "
                 . scalar @buffered_events . " events in buffer");

   # Return if we are to buffer every event.
   return if $self->{buffer_n_events} < 0;

   # Return if we are to buffer N events and buffer space remains.
   return if scalar @buffered_events < $self->{buffer_n_events};

   $self->calc_metrics();

   # Reset buffer if it is full.
   $self->reset_buffer() if scalar @buffered_events >= $self->{buffer_n_events};

   return;
}

# Calc metrics for every buffered event.
sub calc_metrics {
   my ( $self ) = @_;

   EVENT:
   foreach my $event ( @buffered_events ) {

      # Skip events which do not have key_metric.
      my $key_metric_val = $event->{ $self->{key_metric} };
      next EVENT if !defined $key_metric_val;
      $self->{n_queries}++;

      # Get fingerprint for this event.
      # The undef is because the fingerprint sub is usually a class
      # method, therefore it's expecting its first arg to be $self,
      # but our sub ref is not from any instantiation of the class.
      my $fp = $self->{fingerprint}->(undef, $key_metric_val);

      # Get shortcuts to data store for this fingerprint.
      my $fp_ds   = $self->{metrics}->{unique}->{ $fp }
                ||= { sample => $key_metric_val, count => 0 };

      # Count occurrences of this fingerprint.
      $fp_ds->{count}++;

      # Handle each event attribute (metric) for which there is a handler.
      METRIC:
      foreach my $metric ( keys %{ $self->{handlers} } ) {

         # Skip metrics which do not exist in this event.
         my $metric_val = $event->{ $metric };
         next METRIC if !defined $metric_val;
         
         # Get shortcut to this metric's handlers.
         my $handler = $self->{handlers}->{ $metric };

         # Get shortcut to data store for this metric, for this event
         # and for all events
         my $m_ds = $fp_ds->{ $metric } ||= { };
         my $a_ds = $self->{metrics}->{all}->{ $metric } ||= { };

         # ################# #
         # Calc this metric. #
         # ################# #
         $metric_val = $handler->{transformer}->($metric_val)
            if defined $handler->{transformer};

         if ( $handler->{type} == METRIC_TYPE_NUMERIC ) {
            push @{ $m_ds->{all_vals} }, $metric_val
               if $handler->{all_vals};
            push @{ $a_ds->{all_vals} }, $metric_val
               if $handler->{all_all_vals};

            if ( $handler->{total} ) {
               $m_ds->{total} += $metric_val;
               $a_ds->{total} += $metric_val if $handler->{all_events};
            }

            if ( $handler->{min} ) {
               $m_ds->{min} = $m_ds->{min} if !defined $m_ds->{min};
               $m_ds->{min} = $metric_val if $metric_val < $m_ds->{min};

               if ( $handler->{all_events} ) {
                  $a_ds->{min} = $a_ds->{min} if !defined $a_ds->{min};
                  $a_ds->{min} = $metric_val if $metric_val < $a_ds->{min};
               }
            }
            if ( $handler->{max} ) {
               $m_ds->{max} = $m_ds->{max} if !defined $m_ds->{max};
               $m_ds->{max} = $metric_val if $metric_val > $m_ds->{max};

               if ( $handler->{all_events} ) {
                  $a_ds->{max} = $a_ds->{max} if !defined $a_ds->{max};
                  $a_ds->{max} = $metric_val if $metric_val > $a_ds->{max};
               }
            }
            if ( $handler->{avg} ) {
               my $avg = $m_ds->{total} / $fp_ds->{count};
               $avg = $handler->{transformer}->($avg)
                  if defined $handler->{transformer};
               $m_ds->{avg} = $avg;

               if ( $handler->{all_events} ) {
                  $avg = $a_ds->{total} / $self->{n_queries};
                  $avg = $handler->{transformer}->($avg)
                     if defined $handler->{transformer};
                  $a_ds->{avg} = $avg;
               }
            }
         }
         elsif ( $handler->{type} == METRIC_TYPE_STRING ) {
            # Save and count unique occurrences of strings.
            $m_ds->{ $metric_val }++;

            $a_ds->{ $metric_val }++ if $handler->{all_events};
         }
      }
   }

   return;
}

sub nth_percent {
   my ( $vals, %args ) = @_;
   my %default_args = (
      sorted  => 0,     # vals are not yet sorted
      atleast => 10,    # require at least 10 vals
      nth     => 95,    # 95th percentile of vals
      from    => 'top', # from the top
   );
   my %op = ( %default_args, %args );
   return if scalar @$vals < $op{atleast};

   my @s = @$vals;
   my $n;

   @s = sort { $a <=> $b } @s unless $op{sorted};
   $n = ((scalar @s) * $op{nth}) / 100;  # cut-off percent
   @s = splice(@s, 0, $n); # remove vals after cut-off percent

   return \@s;
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

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# SQLMetrics:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End SQLMetrics package
# ###########################################################################
