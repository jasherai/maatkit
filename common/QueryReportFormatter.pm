# This program is copyright 2008-2009 Percona Inc.
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
# QueryReportFormatter package $Revision$
# ###########################################################################

package QueryReportFormatter;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

Transformers->import(
   qw(shorten micro_t parse_timestamp unix_timestamp
      make_checksum percentage_of));

use constant MKDEBUG           => $ENV{MKDEBUG};
use constant LINE_LENGTH       => 74;
use constant MAX_STRING_LENGTH => 10;

# Special formatting functions
my %formatting_function = (
   ts => sub {
      my ( $stats ) = @_;
      my $min = parse_timestamp($stats->{min} || '');
      my $max = parse_timestamp($stats->{max} || '');
      return $min && $max ? "$min to $max" : '';
   },
);

my $bool_format = '# %3s%% %-6s %s';

sub new {
   my ( $class, %args ) = @_;

   # If ever someone wishes for a wider label width.
   my $label_width = $args{label_width} || 9;
   MKDEBUG && _d('Label width:', $label_width);

   my $self = {
      %args,
      label_width => $label_width,
   };
   return bless $self, $class;
}

sub header {
   my ($self) = @_;

   my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
   my $result = '';
   eval {
      my $mem = `ps -o rss,vsz -p $PID 2>&1`;
      ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
      ( $user, $system ) = times();
      $result = sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
         micro_t( $user,   p_s => 1, p_ms => 1 ),
         micro_t( $system, p_s => 1, p_ms => 1 ),
         shorten( ($rss || 0) * 1_024 ),
         shorten( ($vsz || 0) * 1_024 );
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d($EVAL_ERROR);
   }
   return $result;
}

# Print a report about the global statistics in the EventAggregator.  %opts is a
# hash that has the following keys:
#  * select       An arrayref of attributes to print statistics lines for.
#  * worst        The --orderby attribute.
sub global_report {
   my ( $self, $ea, %opts ) = @_;
   my $stats = $ea->results;
   my @result;

   # Get global count
   my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt} || 0;

   # Calculate QPS (queries per second) by looking at the min/max timestamp.
   my ($qps, $conc) = (0, 0);
   if ( $global_cnt && $stats->{globals}->{ts}
      && ($stats->{globals}->{ts}->{max} || '')
         gt ($stats->{globals}->{ts}->{min} || '')
   ) {
      eval {
         my $min  = parse_timestamp($stats->{globals}->{ts}->{min});
         my $max  = parse_timestamp($stats->{globals}->{ts}->{max});
         my $diff = unix_timestamp($max) - unix_timestamp($min);
         $qps     = $global_cnt / $diff;
         $conc    = $stats->{globals}->{$opts{worst}}->{sum} / $diff;
      };
   }

   # First line
   MKDEBUG && _d('global_cnt:', $global_cnt, 'unique:',
      scalar keys %{$stats->{classes}}, 'qps:', $qps, 'conc:', $conc);
   my $line = sprintf(
      '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
      shorten($global_cnt, d=>1_000),
      shorten(scalar keys %{$stats->{classes}}, d=>1_000),
      shorten($qps  || 0, d=>1_000),
      shorten($conc || 0, d=>1_000));
   $line .= ('_' x (LINE_LENGTH - length($line) + $self->{label_width} - 9));
   push @result, $line;

   # Column header line
   my ($format, @headers) = $self->make_header('global');
   push @result, sprintf($format, '', @headers);

   # Each additional line
   foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
      my $attrib_type = $ea->type_for($attrib);
      next unless $attrib_type; 
      next unless exists $stats->{globals}->{$attrib};
      if ( $formatting_function{$attrib} ) { # Handle special cases
         push @result, sprintf $format, $self->make_label($attrib),
            $formatting_function{$attrib}->($stats->{globals}->{$attrib}),
            (map { '' } 0..9); # just for good measure
      }
      else {
         my $store = $stats->{globals}->{$attrib};
         my @values;
         if ( $attrib_type eq 'num' ) {
            my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
            MKDEBUG && _d('Calculating global statistical_metrics for', $attrib);
            my $metrics = $ea->calculate_statistical_metrics($store->{all}, $store);
            @values = (
               @{$store}{qw(sum min max)},
               $store->{sum} / $store->{cnt},
               @{$metrics}{qw(pct_95 stddev median)},
            );
            @values = map { defined $_ ? $func->($_) : '' } @values;
         }
         elsif ( $attrib_type eq 'string' ) {
            MKDEBUG && _d('Ignoring string attrib', $attrib);
            next;
         }
         elsif ( $attrib_type eq 'bool' ) {
            if ( $store->{sum} > 0 || !$opts{no_zero_bool} ) {
               push @result,
                  sprintf $bool_format, format_bool_attrib($store), $attrib;
            }
         }
         else {
            @values = ('', $store->{min}, $store->{max}, '', '', '', '');
         }

         push @result, sprintf $format, $self->make_label($attrib), @values
            unless $attrib_type eq 'bool';  # bool does its own thing.
      }
   }

   return join("\n", map { s/\s+$//; $_ } @result) . "\n";
}

# Print a report about the statistics in the EventAggregator.  %opts is a
# hash that has the following keys:
#  * select       An arrayref of attributes to print statistics lines for.
#  * where        The value of the group-by attribute, such as the fingerprint.
#  * rank         The (optional) rank of the query, for the header
#  * worst        The --orderby attribute
#  * reason       Why this one is being reported on: top|outlier
# TODO: it would be good to start using $ea->metrics() here for simplicity and
# uniform code.
sub event_report {
   my ( $self, $ea, %opts ) = @_;
   my $stats = $ea->results;
   my @result;

   # Does the data exist?  Is there a sample event?
   my $store = $stats->{classes}->{$opts{where}};
   return "# No such event $opts{where}\n" unless $store;
   my $sample = $stats->{samples}->{$opts{where}};

   # Pick the first attribute to get counts
   my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
   my $class_cnt  = $store->{$opts{worst}}->{cnt};

   # Calculate QPS (queries per second) by looking at the min/max timestamp.
   my ($qps, $conc) = (0, 0);
   if ( $global_cnt && $store->{ts}
      && ($store->{ts}->{max} || '')
         gt ($store->{ts}->{min} || '')
   ) {
      eval {
         my $min  = parse_timestamp($store->{ts}->{min});
         my $max  = parse_timestamp($store->{ts}->{max});
         my $diff = unix_timestamp($max) - unix_timestamp($min);
         $qps     = $class_cnt / $diff;
         $conc    = $store->{$opts{worst}}->{sum} / $diff;
      };
   }

   # First line
   my $line = sprintf(
      '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
      ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
      $opts{rank} || 0,
      shorten($qps  || 0, d=>1_000),
      shorten($conc || 0, d=>1_000),
      make_checksum($opts{where}),
      $sample->{pos_in_log} || 0);
   $line .= ('_' x (LINE_LENGTH - length($line) + $self->{label_width} - 9));
   push @result, $line;

   if ( $opts{reason} ) {
      push @result, "# This item is included in the report because it matches "
         . ($opts{reason} eq 'top' ? '--limit.' : '--outliers.');
   }

   # Column header line
   my ($format, @headers) = $self->make_header();
   push @result, sprintf($format, '', @headers);

   # Count line
   push @result, sprintf
      $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
         map { '' } (1 ..9);

   # Each additional line
   foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
      my $attrib_type = $ea->type_for($attrib);
      next unless $attrib_type; 
      next unless exists $store->{$attrib};
      my $vals = $store->{$attrib};
      next unless scalar %$vals;
      if ( $formatting_function{$attrib} ) { # Handle special cases
         push @result, sprintf $format, $self->make_label($attrib),
            $formatting_function{$attrib}->($vals),
            (map { '' } 0..9); # just for good measure
      }
      else {
         my @values;
         my $pct;
         if ( $attrib_type eq 'num' ) {
            my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
            my $metrics = $ea->calculate_statistical_metrics($vals->{all}, $vals);
            @values = (
               @{$vals}{qw(sum min max)},
               $vals->{sum} / $vals->{cnt},
               @{$metrics}{qw(pct_95 stddev median)},
            );
            @values = map { defined $_ ? $func->($_) : '' } @values;
            $pct = percentage_of($vals->{sum},
               $stats->{globals}->{$attrib}->{sum});
         }
         elsif ( $attrib_type eq 'string' ) {
            push @values,
               format_string_list($vals),
               (map { '' } 0..9); # just for good measure
            $pct = '';
         }
         elsif ( $attrib_type eq 'bool' ) {
            if ( $vals->{sum} > 0 || !$opts{no_zero_bool} ) {
               push @result,
                  sprintf $bool_format, format_bool_attrib($vals), $attrib;
            }
         }
         else {
            @values = ('', $vals->{min}, $vals->{max}, '', '', '', '');
            $pct = 0;
         }

         push @result, sprintf $format, $self->make_label($attrib), $pct, @values
            unless $attrib_type eq 'bool';  # bool does its own thing.
      }
   }

   return join("\n", map { s/\s+$//; $_ } @result) . "\n";
}

# Creates a chart of value distributions in buckets.  Right now it bucketizes
# into 8 buckets, powers of ten starting with .000001. %opts has:
#  * where        The value of the group-by attribute, such as the fingerprint.
#  * attribute    An attribute to chart.
sub chart_distro {
   my ( $self, $ea, %opts ) = @_;
   my $stats = $ea->results;
   my $store = $stats->{classes}->{$opts{where}}->{$opts{attribute}};
   my $vals  = $store->{all};
   return "" unless defined $vals && scalar @$vals;
   # TODO: this is broken.
   my @buck_tens = $ea->buckets_of(10);
   my @distro = map { 0 } (0 .. 7);
   map { $distro[$buck_tens[$_]] += $vals->[$_] } (1 .. @$vals - 1);

   my $max_val = 0;
   my $vals_per_mark; # number of vals represented by 1 #-mark
   my $max_disp_width = 64;
   my $bar_fmt = "# %5s%s";
   my @distro_labels = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
   my @results = "# $opts{attribute} distribution";

   # Find the distro with the most values. This will set
   # vals_per_mark and become the bar at max_disp_width.
   foreach my $n_vals ( @distro ) {
      $max_val = $n_vals if $n_vals > $max_val;
   }
   $vals_per_mark = $max_val / $max_disp_width;

   foreach my $i ( 0 .. $#distro ) {
      my $n_vals = $distro[$i];
      my $n_marks = $n_vals / ($vals_per_mark || 1);
      # Always print at least 1 mark for any bucket that has at least
      # 1 value. This skews the graph a tiny bit, but it allows us to
      # see all buckets that have values.
      $n_marks = 1 if $n_marks < 1 && $n_vals > 0;
      my $bar = ($n_marks ? '  ' : '') . '#' x $n_marks;
      push @results, sprintf $bar_fmt, $distro_labels[$i], $bar;
   }

   return join("\n", @results) . "\n";
}

# Makes a header format and returns the format and the column header names.  The
# argument is either 'global' or anything else.
sub make_header {
   my ( $self, $global ) = @_;
   my $format = "# %-$self->{label_width}s %6s %7s %7s %7s %7s %7s %7s %7s";
   my @headers = qw(pct total min max avg 95% stddev median);
   if ( $global ) {
      $format =~ s/%(\d+)s/' ' x $1/e;
      shift @headers;
   }
   return $format, @headers;
}

# Convert attribute names into labels
sub make_label {
   my ( $self, $val ) = @_;

   if ( $val =~ m/^InnoDB/ ) {
      # Shorten InnoDB attributes otherwise their short labels
      # are indistinguishable.
      $val =~ s/^InnoDB_(\w+)/IDB_$1/;
      $val =~ s/r_(\w+)/r$1/;
   }

   return  $val eq 'ts'         ? 'Time range'
         : $val eq 'user'       ? 'Users'
         : $val eq 'db'         ? 'Databases'
         : $val eq 'Query_time' ? 'Exec time'
         : $val eq 'host'       ? 'Hosts'
         : $val eq 'Error_no'   ? 'Errors'
         : do { $val =~ s/_/ /g; $val = substr($val, 0, $self->{label_width}); $val };
}

# Does pretty-printing for bool (Yes/No) attributes like QC_Hit.
sub format_bool_attrib {
   my ( $stats ) = @_;
   # Since the value is either 1 or 0, the sum is the number of
   # all true events and the number of false events is the total
   # number of events minus those that were true.
   my $p_true  = percentage_of($stats->{sum},  $stats->{cnt});
   # my $p_false = percentage_of($stats->{cnt} - $stats->{sum}, $stats->{cnt});
   my $n_true = '(' . shorten($stats->{sum} || 0, d=>1_000, p=>0) . ')';
   return $p_true, $n_true;
}

# Does pretty-printing for lists of strings like users, hosts, db.
sub format_string_list {
   my ( $stats ) = @_;
   if ( exists $stats->{unq} ) {
      # Only class stats have unq.
      my $cnt_for = $stats->{unq};
      if ( 1 == keys %$cnt_for ) {
         my ($str) = keys %$cnt_for;
         # - 30 for label, spacing etc.
         $str = substr($str, 0, LINE_LENGTH - 30) . '...'
            if length $str > LINE_LENGTH - 30;
         return (1, $str);
      }
      my $line = '';
      my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
                     keys %$cnt_for;
      my $i = 0;
      foreach my $str ( @top ) {
         my $print_str;
         if ( length $str > MAX_STRING_LENGTH ) {
            $print_str = substr($str, 0, MAX_STRING_LENGTH) . '...';
         }
         else {
            $print_str = $str;
         }
         last if (length $line) + (length $print_str)  > LINE_LENGTH - 27;
         $line .= "$print_str ($cnt_for->{$str}), ";
         $i++;
      }
      $line =~ s/, $//;
      if ( $i < @top ) {
         $line .= "... " . (@top - $i) . " more";
      }
      return (scalar keys %$cnt_for, $line);
   }
   else {
      # Global stats don't have unq.
      return ($stats->{cnt});
   }
}

# Attribs are sorted into three groups: basic attributes (Query_time, etc.),
# other non-bool attributes sorted by name, and bool attributes sorted by name.
sub sort_attribs {
   my ( $ea, @attribs ) = @_;
   my %basic_attrib = (
      Query_time    => 0,
      Lock_time     => 1,
      Rows_sent     => 2,
      Rows_examined => 3,
      user          => 4,
      host          => 5,
      db            => 6,
      ts            => 7,
   );
   my @basic_attribs;
   my @non_bool_attribs;
   my @bool_attribs;

   ATTRIB:
   foreach my $attrib ( @attribs ) {
      if ( exists $basic_attrib{$attrib} ) {
         push @basic_attribs, $attrib;
      }
      else {
         if ( ($ea->type_for($attrib) || '') ne 'bool' ) {
            push @non_bool_attribs, $attrib;
         }
         else {
            push @bool_attribs, $attrib;
         }
      }
   }

   @non_bool_attribs = sort { uc $a cmp uc $b } @non_bool_attribs;
   @bool_attribs     = sort { uc $a cmp uc $b } @bool_attribs;
   @basic_attribs    = sort {
         $basic_attrib{$a} <=> $basic_attrib{$b} } @basic_attribs;

   return @basic_attribs, @non_bool_attribs, @bool_attribs;
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
# End QueryReportFormatter package
# ###########################################################################
