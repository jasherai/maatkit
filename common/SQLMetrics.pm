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

# #############################################################################
# SQLMetrics package $Revision$
# #############################################################################
package SQLMetrics;
# Since this module is pretty advanced and abstract, it is difficult to
# understand what it does by looking at the code without some background
# information. Here is the relevant background information.
#
# Fundamentally, this module is a calculator. Its is given numbers
# (and sometimes strings, but we care mostly about the numbers) and it
# returns "metrics" derived and calculated from those numbers.
#
# The numbers (and strings) are the values of "attributes," and the attributes
# belong to "events." Events usually come from LogParser. Therefore, an event
# is usually a single log entry, but it does not have to be. mk-log-player,
# for example, makes different kinds of events. In any case, an event is a
# hashref of attributes => values. The attributes and their values (should)
# describe something about the event. For a slowlog event, Query_time is
# a familiar attribute.
#
# SQLMetrics is thus a streaming metrics calculator for event attributes.
# In other scripts, a SQLMetrics object is fed events and from those events
# it calculates various metrics from the events' attributes.
#
# The real magick of this script lies in its agnostic approach to attributes.
# Looking through the module, you may wonder, "Where is all the basic math
# other than calc_statistical_metrics()?" A quick glance reveals no code
# blocks doing sums, greater than, less than, etc. Instead, these code blocks
# are dynamically created in dynamically created anonymous subroutines.
# These "dynanonymous subs" are created in make_handler() because they are
# "handlers": subs which handle the metric calculations for a given attribute.
# Each attribute has its own unique handler.
#
# Handlers are created and assigned to attributes either dynamically or
# manually. When a SQLMetrics object is instantiated, one required arg to
# the new() method is an arrayref of attributes for which to calculate metrics.
# If no explicit handlers for this attributes are given, then SQLMetrics will
# auto-create handlers when needed by determining the attribute's value type
# (number, string, bool, or timestamp) and using default options. Or, handlers
# for each attribute can be created manually by make_handler() and then passed
# as an arg to new().

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use POSIX qw(floor);

use constant MKDEBUG => $ENV{MKDEBUG};

# %args is a hash containing:
# REQUIRED:
# group_by     The attribute by which events are aggregated.  Usually this will
#              be 'arg' because $event->{arg} is the query in a parsed slowlog
#              event.  Events with the same group_by are treated as a class.
# attributes   An arrayref of attributes for which to calculate metrics. If
#              you don't specify handlers for them (see handlers below),
#              they'll be auto-created.  In most cases this will work fine.
#              If you specify an attribute with an | symbol, it means that
#              the subsequent attributes are aliases.  For example,
#              db|Schema means if db is available, it'll be used, and if
#              Schema is available it will be used and saved as db.
#
# Optional:
# handlers     A hashref with explicit attribute => subref handlers. Handler
#              subrefs are returned by make_handler(). If a handler is given
#              for an attribute that is not in the attributes list (see above),
#              the handler is not used and the attribute is not auto-created.
#              You generally do NOT need to specify any handlers.
# worst_attrib An attribute name.  When an event is seen, its worst_attrib
#              value is compared to the greatest worst_attrib value ever seen
#              for this class of event.  If it's greater, the event's
#              group_by value is stored as the representative sample of this
#              class of event, and the event's position in the log is stored
#              too.  TODO: we could make this a subroutine.  For example,
#              'worst' might be rows_examined/rows_returned, or just
#              rows_returned, and we might want to see queries that returned
#              0 rows. TODO: we should store the whole 'worst' event instead of
#              adding properties.
# unroll_limit If this many events have been processed and some handlers haven't
#              been generated yet (due to lack of sample data) unroll the loop
#              anyway.  Defaults to 50.
# attrib_limit Sanity limit for attribute values.  If the value exceeds the
#              limit, use the last-seen for this fingerprint; if none, then 0.
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(group_by attributes) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   # Parse attribute aliases like db|Schema where db is the real attribute
   # name and Schema is an alias.
   my %attributes = map {
      my ($name, @aliases) = split qr/\|/, $_;
      $name => \@aliases;
   } @{$args{attributes}};

   my $self = {
      group_by     => $args{group_by},
      attributes   => \%attributes,
      handlers     => $args{handlers} || {},
      worst_attrib => $args{worst_attrib},
      metrics      => { all => {}, unique => {} },
      n_events     => 0,
      n_queries    => 0,
      unroll_limit => 50,
      attrib_limit => $args{attrib_limit},
   };

   return bless $self, $class;
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
#     all => keep a list of all values seen per class (default for numerics)
#     glo => keep stats globally as well as per-class (default)
#     trf => An expression to transform the value before working with it
#     wor => Whether to keep worst-samples for this attrib (default no)
#     alt => Arrayref of other name(s) for the attribute, like db => Schema.
#
# Return value:
# a subroutine with this signature:
#    my ( $event, $class, $global ) = @_;
# where
#  $event   is the event
#  $class   is the stats for the event's class
#  $global  is the global data store
sub make_handler {
   my ( $self, $attrib, $event, %args ) = @_;
   die "I need an attrib" unless defined $attrib;
   return unless $event;
   my ($val) =
      grep { defined $_ }
      map  { $event->{$_} }
           ( $attrib, @{ $args{alt} || [] } );
   return unless defined $val; # Can't decide type if it's undef.

   # Ripped off from Regexp::Common::number.
   my $float_re = qr{[+-]?(?:(?=\d|[.])\d*(?:[.])\d{0,})?(?:[E](?:[+-]?\d+)|)}i;
   my $type = $val  =~ m/^(?:\d+|$float_re)$/o ? 'num'
            : $val  =~ m/^(?:Yes|No)$/         ? 'bool'
            :                                    'string';
   MKDEBUG && _d("Type for $attrib is $type (sample: $val)");

   %args = ( # Set up defaults
      min => 1,
      max => 1,
      sum => $type =~ m/num|bool/    ? 1 : 0,
      cnt => $type eq 'string'       ? 0 : 1,
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

   foreach my $place ( $args{glo} ? qw($class $global) : qw($class) ) {
      my @tmp;
      if ( $args{min} ) {
         my $op   = $type eq 'num' ? '<' : 'lt';
         push @tmp, 'PLACE->{min} = $val if !defined PLACE->{min} || $val '
            . $op . ' PLACE->{min};';
      }
      if ( $args{max} ) {
         my $op = ($type eq 'num') ? '>' : 'gt';
         push @tmp, 'PLACE->{max} = $val if !defined PLACE->{max} || $val '
            . $op . ' PLACE->{max};';
      }
      if ( $args{sum} ) {
         push @tmp, 'PLACE->{sum} += $val;';
      }
      if ( $args{cnt} ) {
         push @tmp, '++PLACE->{cnt};';
      }
      if ( $place eq '$class' ) {
         if ( $args{unq} ) {
            push @tmp, '++PLACE->{unq}->{$val};';
         }
         if ( $args{all} ) {
            push @tmp, 'push @{PLACE->{all}}, $val;';
         }
         if ( $args{wor} ) {
            my $op = $type eq 'num' ? '>=' : 'ge';
            push @tmp, (
               'if ( $val ' . $op . ' ($class->{max} || 0) ) {',
               '   $class->{sample} = $event;',
               '}',
            );
         }
      }
      push @lines, map { s/PLACE/$place/g; $_ } @tmp;
   }

   # Make sure the value is constrained to legal limits
   my @limit;
   if ( $args{all} && $type eq 'num' && $self->{attrib_limit} ) {
      push @limit, (
         "if ( \$val > $self->{attrib_limit} ) {",
         '   $val = $class->{all}->[-1] || 0;',
         '}',
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
      'my $val = $event->{' . $attrib . '};',
      (map { "\$val = \$event->{$_} unless defined \$val;" } @{$args{alt}}),
      'return unless defined $val;',
      @limit,
   );
   push @lines, '}';
   my $code = join("\n", @lines);
   $self->{code_for}->{$attrib} = $code;

   MKDEBUG && _d("Metric handler for $attrib: ", @lines);
   my $sub = eval join("\n", @lines);
   die if $EVAL_ERROR;
   return $sub;
}

# Calculate metrics about a single event.  Usually an event will be something
# like a query from a slow log, and the $event->{arg} will be the query text.
sub calc_event_metrics {
   my ( $self, $event ) = @_;

   $self->{n_events}++;

   # Skip events which do not have the group_by attribute.
   my $group_by = $event->{ $self->{group_by} };
   return unless defined $group_by;

   $self->{n_queries}++;

   # There might be a specially built sub that handles the work.
   if ( defined $self->{unrolled_loops} ) {
      return $self->{unrolled_loops}->($self, $event, $group_by);
   }

   # Get a shortcut to the data store (ds) for this class of events.  
   my @attrs = sort keys %{$self->{attributes}};
   my $fp_ds = $self->{metrics}->{unique}->{ $group_by }
      ||= { map { $_ => {} } @attrs };

   # Calculate the metrics for all our attributes.  Handlers are auto-vivified
   # as needed, based on the actual data being passed in.  (They can't be
   # pre-generated for that reason.)
   ATTRIB:
   foreach my $attrib ( @attrs ) {
      # Get data store shortcuts.
      my $stats_for_attrib = $self->{metrics}->{all}->{ $attrib } ||= {};
      my $stats_for_class  = $fp_ds->{ $attrib } ||= {};

      my $handler = $self->{handlers}->{ $attrib };
      if ( !$handler ) {
         $handler = $self->make_handler(
            $attrib,
            $event,
            wor => (($self->{worst_attrib} || '') eq $attrib),
            alt => $self->{attributes}->{$attrib},
         );
         if ( $handler ) {
            $self->{handlers}->{$attrib} = $handler;
         }
      }
      next ATTRIB unless $handler;
      $handler->($event, $stats_for_class, $stats_for_attrib);
   }

   # Figure out whether we are ready to generate a faster version.
   if ( $self->{n_queries} > $self->{unroll_limit}
      || !grep {ref $self->{handlers}->{$_} ne 'CODE'} @attrs)
   {
      # All attributes have handlers, so let's combine them into one faster sub.
      # Start by getting direct handles to the location of each data store and
      # thing that would otherwise be looked up via hash keys.
      my @attrs = grep { $self->{handlers}->{$_} } @attrs;
      my @handl = @{$self->{handlers}}{@attrs};
      my @st_fa = @{$self->{metrics}->{all}}{@attrs}; # Stats for attribute

      # Now the tricky part -- must make sure only the desired variables from
      # the outer scope are re-used, and any variables that should have their
      # own scope are declared within the subroutine.
      my @lines = (
         'my ( $self, $event, $group_by ) = @_;',
         'my ($val, $class, $global);',
         # Must re-create; it may not exist for this $group_by yet.
         'my $fp_ds = $self->{metrics}->{unique}->{ $group_by }
            ||= { map { $_ => {} } @attrs };',
         'my @st_fc = @{$fp_ds}{@attrs};', # Stats for class
      );
      foreach my $i ( 0 .. $#attrs ) {
         push @lines, (
            '$class  = $st_fc[' . $i . '];',
            '$global = $st_fa[' . $i . '];',
            $self->{unrolled_for}->{$attrs[$i]},
         );
      }
      @lines = map { s/^/   /gm; $_ } @lines; # Indent for debugging
      unshift @lines, 'sub {';
      push @lines, '}';

      # Make the subroutine
      my $code = join("\n", @lines);
      MKDEBUG && _d("Unrolled subroutine: ", @lines);
      my $sub = eval $code;
      die if $EVAL_ERROR;
      $self->{unrolled_loops} = $sub;
   }

   return;
}

sub reset_metrics {
   my ( $self ) = @_;
   $self->{n_events}          = 0;
   $self->{n_queries}         = 0;
   $self->{metrics}->{all}    = {};
   $self->{metrics}->{unique} = {};
   return;
}

# Given an arrayref of vals, returns a hashref with the following
# statistical metrics:
# {
#    avg       => (of 95% vals),
#    max       => (of 95% vals -- thus the 95th percentile),
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
      max       => 0,
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
   my $max    = 0; # 95th percentile
   my $i      = 0; # for knowing when we've reached the 95%
   foreach my $val ( sort { $a <=> $b } @$vals ) {
      # Distribution of vals for all vals, if requested.
      if ( defined $val && $val > 0 && $args{distro} ) {
         # The buckets are powers of ten. Bucket 0 represents (0 <= val < 10us) 
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
         $max   = $val;
         $i++;

         # Needed for calcing median when list has even number of elements.
         $previous_val = $val;
      }
   }

   my $stddev = sqrt (($sumsq - (($sum**2) / $cutoff)) / ($cutoff -1 || 1));

   MKDEBUG && _d("95 cutoff $cutoff, sum $sum, sumsq $sumsq, stddev $stddev");

   $statistical_metrics->{stddev} = $stddev;
   $statistical_metrics->{avg}    = $sum / $cutoff;
   $statistical_metrics->{max}    = $max;

   return $statistical_metrics;
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

# #############################################################################
# End SQLMetrics package
# #############################################################################
