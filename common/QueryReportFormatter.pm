# This program is copyright 2008-2010 Percona Inc.
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

# This package is used primarily by mk-query-digest to print its reports.
# The main sub is print_reports() which prints the various reports for
# mk-query-digest --report-format.  Each report is produced in a sub of
# the same name; e.g. --report-format=query_report == sub query_report().
# The given ea (EventAggregator object) is expected to be "complete"; i.e.
# fully aggregated and $ea->calculate_statistical_metrics() already called.
# Subreports "profile" and "prepared" require the ReportFormatter module,
# which is also in mk-query-digest.

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

Transformers->import(qw(
   shorten micro_t parse_timestamp unix_timestamp make_checksum percentage_of
));

use constant MKDEBUG           => $ENV{MKDEBUG} || 0;
use constant LINE_LENGTH       => 74;
use constant MAX_STRING_LENGTH => 10;

# Special formatting functions
my %formatting_function = (
   ts => sub {
      my ( $vals ) = @_;
      my $min = parse_timestamp($vals->{min} || '');
      my $max = parse_timestamp($vals->{max} || '');
      return $min && $max ? "$min to $max" : '';
   },
);

# Arguments:
#   * OptionParser
#   * QueryRewriter
#   * Quoter
# Optional arguments:
#   * QueryReview    Used in query_report()
#   * dbh            Used in explain_report()
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(OptionParser QueryRewriter Quoter) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   # If ever someone wishes for a wider label width.
   my $label_width = $args{label_width} || 9;
   MKDEBUG && _d('Label width:', $label_width);

   my $self = {
      %args,
      bool_format => '# %3s%% %-6s %s',
      label_width => $label_width,
      dont_print  => {         # don't print these attribs in these reports
         header => {
            user        => 1,
            db          => 1,
            pos_in_log  => 1,
            fingerprint => 1,
         },
         query_report => {
            pos_in_log  => 1,
            fingerprint => 1,
         }
      },
   };
   return bless $self, $class;
}

# Arguments:
#   * reports       arrayref: reports to print
#   * ea            obj: EventAggregator
#   * worst         arrayref: worst items
#   * orderby       scalar: attrib worst items ordered by
#   * groupby       scalar: attrib worst items grouped by
# Optional arguments:
#   * other         arrayref: other items (that didn't make it into top worst)
#   * files         arrayref: files read for input
#   * group         hashref: don't add blank line between these reports
#                            if they appear together
# Prints the given reports (rusage, heade (global), query_report, etc.) in
# the given order.  These usually come from mk-query-digest --report-format.
# Most of the required args are for header() and query_report().
sub print_reports {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(reports ea worst orderby groupby) ) {
      die "I need a $arg argument" unless exists $args{$arg};
   }
   my $reports = $args{reports};
   my $group   = $args{group};
   my $last_report;

   foreach my $report ( @$reports ) {
      MKDEBUG && _d('Printing', $report, 'report'); 
      my $report_output = $self->$report(%args);
      if ( $report_output ) {
         print "\n"
            if !$last_report || !($group->{$last_report} && $group->{$report});
         print $report_output;
      }
      else {
         MKDEBUG && _d('No', $report, 'report');
      }
      $last_report = $report;
   }

   return;
}

sub rusage {
   my ( $self ) = @_;
   my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
   my $rusage = '';
   eval {
      my $mem = `ps -o rss,vsz -p $PID 2>&1`;
      ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
      ( $user, $system ) = times();
      $rusage = sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
         micro_t( $user,   p_s => 1, p_ms => 1 ),
         micro_t( $system, p_s => 1, p_ms => 1 ),
         shorten( ($rss || 0) * 1_024 ),
         shorten( ($vsz || 0) * 1_024 );
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d($EVAL_ERROR);
   }
   return $rusage ? $rusage : "# Could not get rusage\n";
}

sub date {
   my ( $self ) = @_;
   return "# Current date: " . (scalar localtime) . "\n";
}

sub hostname {
   my ( $self ) = @_;
   my $hostname = `hostname`;
   if ( $hostname ) {
      chomp $hostname;
      return "# Hostname: $hostname\n";
   }
   return;
}

sub files {
   my ( $self, %args ) = @_;
   if ( $args{files} ) {
      return "# Files: " . join(', ', @{$args{files}}) . "\n";
   }
   return;
}

# Arguments:
#   * ea         obj: EventAggregator
#   * orderby    scalar: attrib items ordered by
# Optional arguments:
#   * select     arrayref: attribs to print, mostly for testing; see dont_print
#   * zero_bool  bool: print zero bool values (0%)
# Print a report about the global statistics in the EventAggregator.
# Formerly called "global_report()."
sub header {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(ea orderby) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $ea      = $args{ea};
   my $orderby = $args{orderby};

   my $dont_print = $self->{dont_print}->{header};
   my $results    = $ea->results();
   my @result;

   # Get global count
   my $global_cnt = $results->{globals}->{$orderby}->{cnt} || 0;

   # Calculate QPS (queries per second) by looking at the min/max timestamp.
   my ($qps, $conc) = (0, 0);
   if ( $global_cnt && $results->{globals}->{ts}
      && ($results->{globals}->{ts}->{max} || '')
         gt ($results->{globals}->{ts}->{min} || '')
   ) {
      eval {
         my $min  = parse_timestamp($results->{globals}->{ts}->{min});
         my $max  = parse_timestamp($results->{globals}->{ts}->{max});
         my $diff = unix_timestamp($max) - unix_timestamp($min);
         $qps     = $global_cnt / ($diff || 1);
         $conc    = $results->{globals}->{$args{orderby}}->{sum} / $diff;
      };
   }

   # First line
   MKDEBUG && _d('global_cnt:', $global_cnt, 'unique:',
      scalar keys %{$results->{classes}}, 'qps:', $qps, 'conc:', $conc);
   my $line = sprintf(
      '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
      shorten($global_cnt, d=>1_000),
      shorten(scalar keys %{$results->{classes}}, d=>1_000),
      shorten($qps  || 0, d=>1_000),
      shorten($conc || 0, d=>1_000));
   $line .= ('_' x (LINE_LENGTH - length($line) + $self->{label_width} - 9));
   push @result, $line;

   # Column header line
   my ($format, @headers) = $self->make_header('global');
   push @result, sprintf($format, "Attribute", @headers);
   # The numbers 7, 7, 7, etc. are the field widths from make_header().
   # Hard-coded values aren't ideal but this code rarely changes.
   push @result, sprintf($format,
      map { "=" x $_ } ($self->{label_width}, qw(7 7 7 7 7 7 7)));

   # Each additional line
   my $attribs = $args{select} ? $args{select} : $ea->get_attributes();
   foreach my $attrib ( $self->sorted_attribs($attribs, $ea) ) {
      next if $dont_print->{$attrib};
      my $attrib_type = $ea->type_for($attrib);
      next unless $attrib_type; 
      next unless exists $results->{globals}->{$attrib};
      if ( $formatting_function{$attrib} ) { # Handle special cases
         push @result, sprintf $format, $self->make_label($attrib),
            $formatting_function{$attrib}->($results->{globals}->{$attrib}),
            (map { '' } 0..9); # just for good measure
      }
      else {
         my $store = $results->{globals}->{$attrib};
         my @values;
         if ( $attrib_type eq 'num' ) {
            my $func    = $attrib =~ m/time|wait$/ ? \&micro_t : \&shorten;
            my $metrics = $ea->stats()->{globals}->{$attrib};
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
            if ( $store->{sum} > 0 || $args{zero_bool} ) {
               push @result,
                  sprintf $self->{bool_format},
                     $self->format_bool_attrib($store), $attrib;
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

# Arguments:
#   * ea       obj: EventAggregator
#   * worst    arrayref: worst items
#   * orderby  scalar: attrib worst items ordered by
#   * groupby  scalar: attrib worst items grouped by
# Optional arguments:
#   * select       arrayref: attribs to print, mostly for test; see dont_print
#   * explain_why  bool: print reason why item is reported
#   * print_header  bool: "Report grouped by" header
sub query_report {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(ea worst orderby groupby) ) {
      die "I need a $arg argument" unless defined $arg;
   }
   my $ea      = $args{ea};
   my $groupby = $args{groupby};
   my $worst   = $args{worst};

   my $o   = $self->{OptionParser};
   my $q   = $self->{Quoter};
   my $qv  = $self->{QueryReview};
   my $qr  = $self->{QueryRewriter};

   my $report = '';

   if ( $args{print_header} ) {
      $report .= "# " . ( '#' x 72 ) . "\n"
               . "# Report grouped by $groupby\n"
               . '# ' . ( '#' x 72 ) . "\n\n";
   }

   # Print each worst item: its stats/metrics (sum/min/max/95%/etc.),
   # Query_time distro chart, tables, EXPLAIN, fingerprint, etc.
   # Items are usually unique queries/fingerprints--depends on how
   # the events were grouped.
   ITEM:
   foreach my $top_event ( @$worst ) {
      my $item       = $top_event->[0];
      my $reason     = $args{explain_why} ? $top_event->[1] : '';
      my $rank       = $top_event->[2];
      my $stats      = $ea->results->{classes}->{$item};
      my $sample     = $ea->results->{samples}->{$item};
      my $samp_query = $sample->{arg} || '';

      # ###############################################################
      # Possibly skip item for --review.
      # ###############################################################
      my $review_vals;
      if ( $qv ) {
         $review_vals = $qv->get_review_info($item);
         next ITEM if $review_vals->{reviewed_by} && !$o->get('report-all');
      }

      # ###############################################################
      # Get tables for --for-explain.
      # ###############################################################
      my ($default_db) = $sample->{db}       ? $sample->{db}
                       : $stats->{db}->{unq} ? keys %{$stats->{db}->{unq}}
                       :                       undef;
      my @tables;
      if ( $o->get('for-explain') ) {
         @tables = $self->{QueryParser}->extract_tables(
            query      => $samp_query,
            default_db => $default_db,
            Quoter     => $self->{Quoter},
         );
      }

      # ###############################################################
      # Print the standard query analysis report.
      # ###############################################################
      $report .= "\n" if $rank > 1;  # space between each event report
      $report .= $self->event_report(
         %args,
         item  => $item,
         rank   => $rank,
         reason => $reason,
      );

      if ( $o->get('report-histogram') ) {
         $report .= $self->chart_distro(
            %args,
            attrib => $o->get('report-histogram'),
            item   => $item,
         );
      }

      if ( $qv && $review_vals ) {
         # Print the review information that is already in the table
         # before putting anything new into the table.
         $report .= "# Review information\n";
         foreach my $col ( $qv->review_cols() ) {
            my $val = $review_vals->{$col};
            if ( !$val || $val ne '0000-00-00 00:00:00' ) { # issue 202
               $report .= sprintf "# %13s: %-s\n", $col, ($val ? $val : '');
            }
         }
      }

      if ( $groupby eq 'fingerprint' ) {
         # Shorten it if necessary (issue 216 and 292).           
         $samp_query = $qr->shorten($samp_query, $o->get('shorten'))
            if $o->get('shorten');

         # Print query fingerprint.
         $report .= "# Fingerprint\n#    $item\n"
            if $o->get('fingerprints');

         # Print tables used by query.
         $report .= $self->tables_report(@tables)
            if $o->get('for-explain');

         if ( $item =~ m/^(?:[\(\s]*select|insert|replace)/ ) {
            if ( $item =~ m/^(?:insert|replace)/ ) { # No EXPLAIN
               $report .= "$samp_query\\G\n";
            }
            else {
               $report .= "# EXPLAIN /*!50100 PARTITIONS*/\n$samp_query\\G\n"; 
               $report .= $self->explain_report($samp_query, $default_db);
            }
         }
         else {
            $report .= "$samp_query\\G\n"; 
            my $converted = $qr->convert_to_select($samp_query);
            if ( $o->get('for-explain')
                 && $converted
                 && $converted =~ m/^[\(\s]*select/i ) {
               # It converted OK to a SELECT
               $report .= "# Converted for EXPLAIN\n# EXPLAIN /*!50100 PARTITIONS*/\n$converted\\G\n";
            }
         }
      }
      else {
         if ( $groupby eq 'tables' ) {
            my ( $db, $tbl ) = $q->split_unquote($item);
            $report .= $self->tables_report([$db, $tbl]);
         }
         $report .= "$item\n";
      }
   }

   return $report;
}

# Arguments:
#   * ea          obj: EventAggregator
#   * item        scalar: Item in ea results
#   * orderby     scalar: attribute that events are ordered by
# Optional arguments:
#   * select      arrayref: attribs to print, mostly for testing; see dont_print
#   * reason      scalar: why this item is being reported (top|outlier)
#   * rank        scalar: item rank among the worst
#   * zero_bool   bool: print zero bool values (0%)
# Print a report about the statistics in the EventAggregator.
# Called by query_report().
sub event_report {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(ea item orderby) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $ea      = $args{ea};
   my $item    = $args{item};
   my $orderby = $args{orderby};

   my $dont_print = $self->{dont_print}->{query_report};
   my $results    = $ea->results();
   my @result;

   # Return unless the item exists in the results (it should).
   my $store = $results->{classes}->{$item};
   return "# No such event $item\n" unless $store;

   # Pick the first attribute to get counts
   my $global_cnt = $results->{globals}->{$orderby}->{cnt};
   my $class_cnt  = $store->{$orderby}->{cnt};

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
         $conc    = $store->{$orderby}->{sum} / $diff;
      };
   }

   # First line like:
   # Query 1: 9 QPS, 0x concurrency, ID 0x7F7D57ACDD8A346E at byte 5 ________
   my $line = sprintf(
      '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
      ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
      $args{rank} || 0,
      shorten($qps  || 0, d=>1_000),
      shorten($conc || 0, d=>1_000),
      make_checksum($item),
      $results->{samples}->{$item}->{pos_in_log} || 0,
   );
   $line .= ('_' x (LINE_LENGTH - length($line) + $self->{label_width} - 9));
   push @result, $line;

   if ( $args{reason} ) {
      push @result,
         "# This item is included in the report because it matches "
            . ($args{reason} eq 'top' ? '--limit.' : '--outliers.');
   }

   # Column header line
   my ($format, @headers) = $self->make_header();
   push @result, sprintf($format, "Attribute", @headers);
   # The numbers 6, 7, 7, etc. are the field widths from make_header().
   # Hard-coded values aren't ideal but this code rarely changes.
   push @result, sprintf($format,
      map { "=" x $_ } ($self->{label_width}, qw(6 7 7 7 7 7 7 7)));

   # Count line
   push @result, sprintf
      $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
         map { '' } (1 ..9);

   # Each additional line
   my $attribs = $args{select} ? $args{select} : $ea->get_attributes();
   foreach my $attrib ( $self->sorted_attribs($attribs, $ea) ) {
      next if $dont_print->{$attrib};
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
            my $func    = $attrib =~ m/time|wait$/ ? \&micro_t : \&shorten;
            my $metrics = $ea->stats()->{classes}->{$item}->{$attrib};
            @values = (
               @{$vals}{qw(sum min max)},
               $vals->{sum} / $vals->{cnt},
               @{$metrics}{qw(pct_95 stddev median)},
            );
            @values = map { defined $_ ? $func->($_) : '' } @values;
            $pct = percentage_of($vals->{sum},
               $results->{globals}->{$attrib}->{sum});
         }
         elsif ( $attrib_type eq 'string' ) {
            push @values,
               $self->format_string_list($attrib, $vals, $class_cnt),
               (map { '' } 0..9); # just for good measure
            $pct = '';
         }
         elsif ( $attrib_type eq 'bool' ) {
            if ( $vals->{sum} > 0 || $args{zero_bool} ) {
               push @result,
                  sprintf $self->{bool_format},
                     $self->format_bool_attrib($vals), $attrib;
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

# Arguments:
#  * ea      obj: EventAggregator
#  * item    scalar: item in ea results
#  * attrib  scalar: item's attribute to chart
# Creates a chart of value distributions in buckets.  Right now it bucketizes
# into 8 buckets, powers of ten starting with .000001.
sub chart_distro {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(ea item attrib) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $ea     = $args{ea};
   my $item   = $args{item};
   my $attrib = $args{attrib};

   my $results = $ea->results();
   my $store   = $results->{classes}->{$item}->{$attrib};
   my $vals    = $store->{all};
   return "" unless defined $vals && scalar %$vals;

   # TODO: this is broken.
   my @buck_tens = $ea->buckets_of(10);
   my @distro = map { 0 } (0 .. 7);

   # See similar code in EventAggregator::_calc_metrics() or
   # http://code.google.com/p/maatkit/issues/detail?id=866
   my @buckets = map { 0 } (0..999);
   map { $buckets[$_] = $vals->{$_} } keys %$vals;
   $vals = \@buckets;  # repoint vals from given hashref to our array

   map { $distro[$buck_tens[$_]] += $vals->[$_] } (1 .. @$vals - 1);

   my $vals_per_mark; # number of vals represented by 1 #-mark
   my $max_val        = 0;
   my $max_disp_width = 64;
   my $bar_fmt        = "# %5s%s";
   my @distro_labels  = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
   my @results        = "# $attrib distribution";

   # Find the distro with the most values. This will set
   # vals_per_mark and become the bar at max_disp_width.
   foreach my $n_vals ( @distro ) {
      $max_val = $n_vals if $n_vals > $max_val;
   }
   $vals_per_mark = $max_val / $max_disp_width;

   foreach my $i ( 0 .. $#distro ) {
      my $n_vals  = $distro[$i];
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

# Profile subreport (issue 381).
# Arguments:
#   * ea            obj: EventAggregator
#   * worst         arrayref: worst items
#   * groupby       scalar: attrib worst items grouped by
# Optional arguments:
#   * other            arrayref: other items (that didn't make it into top worst)
#   * distill_args     hashref: extra args for distill()
#   * ReportFormatter  obj: passed-in ReportFormatter for testing
sub profile {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(ea worst groupby) ) {
      die "I need a $arg argument" unless defined $arg;
   }
   my $ea      = $args{ea};
   my $worst   = $args{worst};
   my $other   = $args{other};
   my $groupby = $args{groupby};

   my $qr  = $self->{QueryRewriter};

   # Total response time of all events.
   my $results = $ea->results();
   my $total_r = $results->{globals}->{Query_time}->{sum} || 0;

   my @profiles;
   foreach my $top_event ( @$worst ) {
      my $item       = $top_event->[0];
      my $rank       = $top_event->[2];
      my $stats      = $ea->results->{classes}->{$item};
      my $sample     = $ea->results->{samples}->{$item};
      my $samp_query = $sample->{arg} || '';
      my $query_time = $ea->metrics(where => $item, attrib => 'Query_time');
      my %profile    = (
         rank   => $rank,
         r      => $stats->{Query_time}->{sum},
         cnt    => $stats->{Query_time}->{cnt},
         sample => $groupby eq 'fingerprint' ?
                    $qr->distill($samp_query, %{$args{distill_args}}) : $item,
         id     => $groupby eq 'fingerprint' ? make_checksum($item)   : '',
         vmr    => ($query_time->{stddev}**2) / ($query_time->{avg} || 1),
      ); 
      push @profiles, \%profile;
   }

   my $report = $args{ReportFormatter} || new ReportFormatter(
      line_width       => LINE_LENGTH,
      long_last_column => 1,
      extend_right     => 1,
   );
   $report->set_title('Profile');
   $report->set_columns(
      { name => 'Rank',          right_justify => 1, },
      { name => 'Query ID',                          },
      { name => 'Response time', right_justify => 1, },
      { name => 'Calls',         right_justify => 1, },
      { name => 'R/Call',        right_justify => 1, },
      { name => 'V/M',           right_justify => 1, },
      { name => 'Item',                              },
   );

   foreach my $item ( sort { $a->{rank} <=> $b->{rank} } @profiles ) {
      my $rt  = sprintf('%10.4f', $item->{r});
      my $rtp = sprintf('%4.1f%%', $item->{r} / ($total_r || 1) * 100);
      my $rc  = sprintf('%8.4f', $item->{r} / $item->{cnt});
      my $vmr = sprintf('%4.1f', $item->{vmr});
      $report->add_line(
         $item->{rank},
         "0x$item->{id}",
         "$rt $rtp",
         $item->{cnt},
         $rc,
         $vmr,
         $item->{sample},
      );
   }

   # The last line of the profile is for all the other, non-worst items.
   # http://code.google.com/p/maatkit/issues/detail?id=1043
   if ( $other && @$other ) {
      my $misc = {
            r   => 0,
            cnt => 0,
      };
      foreach my $other_event ( @$other ) {
         my $item      = $other_event->[0];
         my $stats     = $ea->results->{classes}->{$item};
         $misc->{r}   += $stats->{Query_time}->{sum};
         $misc->{cnt} += $stats->{Query_time}->{cnt};
      }
      my $rt  = sprintf('%10.4f', $misc->{r});
      my $rtp = sprintf('%4.1f%%', $misc->{r} / ($total_r || 1) * 100);
      my $rc  = sprintf('%8.4f', $misc->{r} / $misc->{cnt});
      $report->add_line(
         "MISC",
         "0xMISC",
         "$rt $rtp",
         $misc->{cnt},
         $rc,
         '0.0',  # variance-to-mean ratio is not meaningful here
         "<".scalar @$other." ITEMS>",
      );
   }

   return $report->get_report();
}

# Prepared statements subreport (issue 740).
# Arguments:
#   * ea            obj: EventAggregator
#   * worst         arrayref: worst items
#   * groupby       scalar: attrib worst items grouped by
# Optional arguments:
#   * distill_args  hashref: extra args for distill()
#   * ReportFormatter  obj: passed-in ReportFormatter for testing
sub prepared {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(ea worst groupby) ) {
      die "I need a $arg argument" unless defined $arg;
   }
   my $ea      = $args{ea};
   my $worst   = $args{worst};
   my $groupby = $args{groupby};

   my $qr = $self->{QueryRewriter};

   my @prepared;       # prepared statements
   my %seen_prepared;  # report each PREP-EXEC pair once
   my $total_r = 0;

   foreach my $top_event ( @$worst ) {
      my $item       = $top_event->[0];
      my $rank       = $top_event->[2];
      my $stats      = $ea->results->{classes}->{$item};
      my $sample     = $ea->results->{samples}->{$item};
      my $samp_query = $sample->{arg} || '';

      $total_r += $stats->{Query_time}->{sum};
      next unless $stats->{Statement_id} && $item =~ m/^(?:prepare|execute) /;

      # Each PREPARE (probably) has some EXECUTE and each EXECUTE (should)
      # have some PREPARE.  But these are only the top N events so we can get
      # here a PREPARE but not its EXECUTE or vice-versa.  The prepared
      # statements report requires both so this code gets the missing pair
      # from the ea stats.
      my ($prep_stmt, $prep, $prep_r, $prep_cnt);
      my ($exec_stmt, $exec, $exec_r, $exec_cnt);

      if ( $item =~ m/^prepare / ) {
         $prep_stmt           = $item;
         ($exec_stmt = $item) =~ s/^prepare /execute /;
      }
      else {
         ($prep_stmt = $item) =~ s/^execute /prepare /;
         $exec_stmt           = $item;
      }

      # Report each PREPARE/EXECUTE pair once.
      if ( !$seen_prepared{$prep_stmt}++ ) {
         $exec     = $ea->results->{classes}->{$exec_stmt};
         $exec_r   = $exec->{Query_time}->{sum};
         $exec_cnt = $exec->{Query_time}->{cnt};
         $prep     = $ea->results->{classes}->{$prep_stmt};
         $prep_r   = $prep->{Query_time}->{sum};
         $prep_cnt = scalar keys %{$prep->{Statement_id}->{unq}},
         push @prepared, {
            prep_r   => $prep_r, 
            prep_cnt => $prep_cnt,
            exec_r   => $exec_r,
            exec_cnt => $exec_cnt,
            rank     => $rank,
            sample   => $groupby eq 'fingerprint'
                          ? $qr->distill($samp_query, %{$args{distill_args}})
                          : $item,
            id       => $groupby eq 'fingerprint' ? make_checksum($item)
                                                  : '',
         };
      }
   }

   # Return unless there are prepared statements to report.
   return unless scalar @prepared;

   my $report = $args{ReportFormatter} || new ReportFormatter(
      line_width       => LINE_LENGTH,
      long_last_column => 1,
      extend_right     => 1,     
   );
   $report->set_title('Prepared statements');
   $report->set_columns(
      { name => 'Rank',          right_justify => 1, },
      { name => 'Query ID',                          },
      { name => 'PREP',          right_justify => 1, },
      { name => 'PREP Response', right_justify => 1, },
      { name => 'EXEC',          right_justify => 1, },
      { name => 'EXEC Response', right_justify => 1, },
      { name => 'Item',                              },
   );

   foreach my $item ( sort { $a->{rank} <=> $b->{rank} } @prepared ) {
      my $exec_rt  = sprintf('%10.4f', $item->{exec_r});
      my $exec_rtp = sprintf('%4.1f%%',$item->{exec_r}/($total_r || 1) * 100);
      my $prep_rt  = sprintf('%10.4f', $item->{prep_r});
      my $prep_rtp = sprintf('%4.1f%%',$item->{prep_r}/($total_r || 1) * 100);
      $report->add_line(
         $item->{rank},
         "0x$item->{id}",
         $item->{prep_cnt} || 0,
         "$prep_rt $prep_rtp",
         $item->{exec_cnt} || 0,
         "$exec_rt $exec_rtp",
         $item->{sample},
      );
   }
   return $report->get_report();
}

# Makes a header format and returns the format and the column header names
# The argument is either 'global' or anything else.
sub make_header {
   my ( $self, $global ) = @_;
   my $format  = "# %-$self->{label_width}s %6s %7s %7s %7s %7s %7s %7s %7s";
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
   my ( $self, $vals ) = @_;
   # Since the value is either 1 or 0, the sum is the number of
   # all true events and the number of false events is the total
   # number of events minus those that were true.
   my $p_true = percentage_of($vals->{sum},  $vals->{cnt});
   my $n_true = '(' . shorten($vals->{sum} || 0, d=>1_000, p=>0) . ')';
   return $p_true, $n_true;
}

# Does pretty-printing for lists of strings like users, hosts, db.
sub format_string_list {
   my ( $self, $attrib, $vals, $class_cnt ) = @_;
   my $o        = $self->{OptionParser};
   my $show_all = $o->get('show-all');

   # Only class result values have unq.  So if unq doesn't exist,
   # then we've been given global values.
   if ( !exists $vals->{unq} ) {
      return ($vals->{cnt});
   }

   my $cnt_for = $vals->{unq};
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
      if ( $str =~ m/(?:\d+\.){3}\d+/ ) {
         $print_str = $str;  # Do not shorten IP addresses.
      }
      elsif ( length $str > MAX_STRING_LENGTH ) {
         $print_str = substr($str, 0, MAX_STRING_LENGTH) . '...';
      }
      else {
         $print_str = $str;
      }
      my $p = percentage_of($cnt_for->{$str}, $class_cnt);
      $print_str .= " ($cnt_for->{$str}/$p%)";
      if ( !$show_all->{$attrib} ) {
         last if (length $line) + (length $print_str)  > LINE_LENGTH - 27;
      }
      $line .= "$print_str, ";
      $i++;
   }

   $line =~ s/, $//;

   if ( $i < @top ) {
      $line .= "... " . (@top - $i) . " more";
   }

   return (scalar keys %$cnt_for, $line);
}

# Attribs are sorted into three groups: basic attributes (Query_time, etc.),
# other non-bool attributes sorted by name, and bool attributes sorted by name.
sub sorted_attribs {
   my ( $self, $attribs, $ea ) = @_;
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
   foreach my $attrib ( @$attribs ) {
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

# Gets a default database and a list of arrayrefs of [db, tbl] to print out
sub tables_report {
   my ( $self, @tables ) = @_;
   return '' unless @tables;
   my $q      = $self->{Quoter};
   my $tables = "";
   foreach my $db_tbl ( @tables ) {
      my ( $db, $tbl ) = @$db_tbl;
      $tables .= '#    SHOW TABLE STATUS'
               . ($db ? " FROM `$db`" : '')
               . " LIKE '$tbl'\\G\n";
      $tables .= "#    SHOW CREATE TABLE "
               . $q->quote(grep { $_ } @$db_tbl)
               . "\\G\n";
   }
   return $tables ? "# Tables\n$tables" : "# No tables\n";
}

sub explain_report {
   my ( $self, $query, $db ) = @_;
   my $dbh = $self->{dbh};
   my $q   = $self->{Quoter};
   my $qp  = $self->{QueryParser};
   return '' unless $dbh && $query;
   my $explain = '';
   eval {
      if ( !$qp->has_derived_table($query) ) {
         if ( $db ) {
            $dbh->do("USE " . $q->quote($db));
         }
         my $sth = $dbh->prepare("EXPLAIN /*!50100 PARTITIONS */ $query");
         $sth->execute();
         my $i = 1;
         while ( my @row = $sth->fetchrow_array() ) {
            $explain .= "# *************************** $i. "
                      . "row ***************************\n";
            foreach my $j ( 0 .. $#row ) {
               $explain .= sprintf "# %13s: %s\n", $sth->{NAME}->[$j],
                  defined $row[$j] ? $row[$j] : 'NULL';
            }
            $i++;  # next row number
         }
      }
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d("EXPLAIN failed:", $query, $EVAL_ERROR);
   }
   return $explain ? $explain : "# EXPLAIN failed: $EVAL_ERROR";
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
