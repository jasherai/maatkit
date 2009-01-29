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
# QueryReportFormatter package $Revision: 2880 $
# ###########################################################################

package QueryReportFormatter;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
Transformers->import(
   qw(shorten micro_t parse_timestamp unix_timestamp
      make_checksum percentage_of));

use constant LINE_LENGTH => 74;

# Special formatting functions
my %formatting_function = (
   db => sub {
      my ( $stats ) = @_;
      my $cnt_for = $stats->{unq};
      if ( 1 == keys %$cnt_for ) {
         return 1, keys %$cnt_for;
      }
      my $line = '';
      my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
                     keys %$cnt_for;
      my $i = 0;
      foreach my $db ( @top ) {
         last if length($line) > LINE_LENGTH - 27;
         $line .= "$db ($cnt_for->{$db}), ";
         $i++;
      }
      $line =~ s/, $//;
      if ( $i < $#top ) {
         $line .= "... " . ($#top - $i) . " more";
      }
      return (scalar keys %$cnt_for, $line);
   },
   ts => sub {
      my ( $stats ) = @_;
      my $min = parse_timestamp($stats->{min} || '');
      my $max = parse_timestamp($stats->{max} || '');
      return $min && $max ? "$min to $max" : '';
   },
   user => sub {
      my ( $stats ) = @_;
      my $cnt_for = $stats->{unq};
      if ( 1 == keys %$cnt_for ) {
         return 1, keys %$cnt_for;
      }
      my $line = '';
      my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
                     keys %$cnt_for;
      my $i = 0;
      foreach my $user ( @top ) {
         last if length($line) > LINE_LENGTH - 27;
         $line .= "$user ($cnt_for->{$user}), ";
         $i++;
      }
      $line =~ s/, $//;
      if ( $i < $#top ) {
         $line .= "... " . ($#top - $i) . " more";
      }
      return (scalar keys %$cnt_for, $line);
   },
);

sub new {
   my ( $class, %args ) = @_;
   return bless { }, $class;
}

sub header {
   my ($self) = @_;

   my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
   eval {
      my $mem = `ps -o rss,vsz $PID`;
      ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
   };
   ( $user, $system ) = times();

   sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
      micro_t( $user,   p_s => 1, p_ms => 1 ),
      micro_t( $system, p_s => 1, p_ms => 1 ),
      shorten( $rss * 1_024 ),
      shorten( $vsz * 1_024 );
}

# Print a report about the global statistics in the EventAggregator.  %opts is a
# hash that has the following keys:
#  * select       An arrayref of attributes to print statistics lines for.
#  * worst        The attribute in which the sample is stored.
sub global_report {
   my ( $self, $ea, %opts ) = @_;
   my $stats = $ea->results;
   my @result;

   # Get global count
   my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};

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
   my $line = sprintf(
      '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
      shorten($global_cnt),
      shorten(scalar keys %{$stats->{classes}}),
      shorten($qps),
      shorten($conc));
   $line .= ('_' x (LINE_LENGTH - length($line)));
   push @result, $line;

   # Column header line
   my ($format, @headers) = make_header('global');
   push @result, sprintf($format, '', @headers);

   # Each additional line
   foreach my $attrib ( @{$opts{select}} ) {
      next unless $ea->attributes->{$attrib};
      if ( $formatting_function{$attrib} ) { # Handle special cases
         push @result, sprintf $format, make_label($attrib),
            $formatting_function{$attrib}->($stats->{globals}->{$attrib}),
            (map { '' } 0..9);# just for good measure
      }
      else {
         my $store = $stats->{globals}->{$attrib};
         my @values;
         if ( $ea->attributes->{$attrib} eq 'num' ) {
            my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
            my $metrics = $ea->calculate_statistical_metrics($store->{all}, $store);
            @values = (
               @{$store}{qw(sum min max)},
               $store->{sum} / $store->{cnt},
               @{$metrics}{qw(pct_95 stddev median)},
            );
            @values = map { defined $_ ? $func->($_) : '' } @values;
         }
         else {
            @values = ('', $store->{min}, $store->{max}, '', '', '', '');
         }
         push @result, sprintf $format, make_label($attrib), @values;
      }
   }

   return join("\n", map { s/\s+$//; $_ } @result) . "\n";
}

# Print a report about the statistics in the EventAggregator.  %opts is a
# hash that has the following keys:
#  * select       An arrayref of attributes to print statistics lines for.
#  * where        The value of the group-by attribute, such as the fingerprint.
#  * rank         The (optional) rank of the query, for the header
#  * worst        The attribute in which the sample is stored.
sub event_report {
   my ( $self, $ea, %opts ) = @_;
   my $stats = $ea->results;
   my @result;

   # Is there a sample event?
   my $store = $stats->{classes}->{$opts{where}};
   return "# No such event $opts{where}\n" unless $store;
   my $sample = $store->{$opts{worst}}->{sample};

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
         $qps     = $global_cnt / $diff;
         $conc    = $store->{$opts{worst}}->{sum} / $diff;
      };
   }

   # First line
   my $line = sprintf(
      '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
      ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
      $opts{rank} || 0,
      shorten($qps),
      shorten($conc),
      make_checksum($opts{where}),
      $sample->{pos_in_log} || 0);
   $line .= ('_' x (LINE_LENGTH - length($line)));
   push @result, $line;

   # Column header line
   my ($format, @headers) = make_header();
   push @result, sprintf($format, '', @headers);

   # Count line
   push @result, sprintf
      $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
         map { '' } (1 ..9);

   # Each additional line
   foreach my $attrib ( @{$opts{select}} ) {
      next unless $ea->attributes->{$attrib};
      my $vals = $store->{$attrib};
      if ( $formatting_function{$attrib} ) { # Handle special cases
         push @result, sprintf $format, make_label($attrib),
            $formatting_function{$attrib}->($vals),
            (map { '' } 0..9);# just for good measure
      }
      else {
         my @values;
         my $pct;
         if ( $ea->attributes->{$attrib} eq 'num' ) {
            my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
            my $metrics
               = $ea->calculate_statistical_metrics($vals->{all}, $vals);
            @values = (
               @{$vals}{qw(sum min max)},
               $vals->{sum} / $vals->{cnt},
               @{$metrics}{qw(pct_95 stddev median)},
            );
            @values = map { defined $_ ? $func->($_) : '' } @values;
            $pct = percentage_of($vals->{sum},
               $stats->{globals}->{$attrib}->{sum});
         }
         else {
            @values = ('', $vals->{min}, $vals->{max}, '', '', '', '');
            $pct = 0;
         }
         push @result, sprintf $format, make_label($attrib), $pct, @values;
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
   my $store
      = $stats->{classes}->{$opts{where}}->{$opts{attribute}};
   my $vals = $store->{all};
   return "" unless defined $vals && scalar @$vals;

   my @buck_tens = $ea->buckets_of(10);
   my @distro = map { 0 } (0 .. 7);
   map { $distro[$buck_tens[$_]] += $vals->[$_] } (0 .. @$vals - 1);

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
      my $n_marks = $n_vals / $vals_per_mark;
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
   my ( $global ) = @_;
   my $format = "# %-9s %6s %7s %7s %7s %7s %7s %7s %7s";
   my @headers = qw(pct total min max avg 95% stddev median);
   if ( $global ) {
      $format =~ s/%(\d+)s/' ' x $1/e;
      shift @headers;
   }
   return $format, @headers;
}

# Convert attribute names into labels
sub make_label {
   my ( $val ) = @_;
   return $val eq 'ts'          ? 'Time range'
         : $val eq 'user'       ? 'Users'
         : $val eq 'db'         ? 'Databases'
         : $val eq 'Query_time' ? 'Exec time'
         : do { $val =~ s/_/ /g; $val = substr($val, 0, 9); $val };
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
# End QueryReportFormatter package
# ###########################################################################
