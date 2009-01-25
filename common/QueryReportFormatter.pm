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
Transformers->import(qw(shorten micro_t parse_timestamp unix_timestamp));

use constant LINE_LENGTH => 74;

# Special formatting functions
my %formatting_function = (
   db => sub {
   },
   ts => sub {
      my ( $stats ) = @_;
      my $min = parse_timestamp($stats->{min} || '');
      my $max = parse_timestamp($stats->{max} || '');
      return "$min to $max";
   },
   user => sub {
      my ( $stats ) = @_;
      my $cnt_for = $stats->{unq};
      my $line = '';
      my @top
         = reverse sort { $cnt_for->{$a} <=> $cnt_for->{$b} } keys %$cnt_for;
      foreach my $user ( @top ) {
         last if length($line) < LINE_LENGTH - 27;
         $line .= " $user($cnt_for->{$user})";
      }
      return (scalar keys %$cnt_for, $line);
   },
);

sub new {
   my ( $class, %args ) = @_;
   return bless { }, $class;
}

sub header {
   my ( $self ) = @_;

   my ( $rss, $vsz, $user, $system );
   eval {
      my $mem = `ps -o rss,vsz $PID`;
      ($rss, $vsz) = $mem =~ m/(\d+)/g;
   };
   ($user, $system) = times();

   sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
         micro_t($user, p_s => 1, p_ms => 1),
         micro_t($system, p_s => 1, p_ms => 1),
         shorten($rss * 1_024),
         shorten($vsz * 1_024);
}

# Print a report about the global statistics in the EventAggregator.  %opts is a
# hash that has the following keys:
#  * attributes   An arrayref of attributes to print statistics lines for.
#  * groupby      The group-by attribute (usually 'fingerprint')
sub global_report {
   my ( $self, $ea, %opts ) = @_;
   my $stats = $ea->results;
   my @result;

   # Pick the first attribute to get global count
   my $global_cnt = $stats->{globals}->{$opts{attributes}->[0]}->{cnt};

   # Calculate QPS (queries per second) by looking at the min/max timestamp.
   my $qps = 0;
   if ( $global_cnt
      && ($stats->{globals}->{ts}->{max} || '')
         gt ($stats->{globals}->{ts}->{min} || '')
   ) {
      eval {
         my $min = parse_timestamp($stats->{globals}->{ts}->{min});
         my $max = parse_timestamp($stats->{globals}->{ts}->{max});
         $qps = $global_cnt / (unix_timestamp($max) - unix_timestamp($min));
      };
   }

   # First line
   my $line = sprintf('# Overall: %s total, %s unique, %s QPS ',
      shorten($global_cnt),
      shorten(scalar keys %{$stats->{classes}->{$opts{groupby}}}),
      shorten($qps));
   $line .= ('_' x (LINE_LENGTH - length($line)));
   push @result, $line;

   # Column header line
   my ($format, @headers) = make_header('global');
   push @result, sprintf($format, '', @headers);

   # Each additional line
   foreach my $attrib ( @{$opts{attributes}} ) {
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

# Makes a header format and returns the format and the column header names.  The
# argument is either 'global' or anything else.
sub make_header {
   my ( $global ) = @_;
   my $format = "# %-9s %6s %7s %7s %7s %7s %7s %7s %7s";
   my @headers = qw(% total min max avg 95% stddev median);
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

1;

__DATA__

sub print_analysis_report {
   my ( $opts, @worst ) = @_;
   my $u = $ea->results->{classes};
   my $g = $ea->results->{globals};
   my $Query_time_distro;

   my $query_hdr_fmt   = "# Query %03d (%s QPS) ID: 0x%s at byte %d ";
   my $metrics_hdr_fmt = "#              total    %%     min     max     "
                       . "avg     95%%  stddev  median\n";
   my $count_line_fmt  = "# %9s %8s  %3d\n";
   my $metric_line_fmt = "# %9s %8s  %3d %7s %7s %7s %7s %7s %7s\n";
   my $list_line_fmt   = "# %9s  %s\n";
   my $timestamp_fmt   = "# Time range %s to %s\n";
   my $review_info_fmt = "# %13s: %-s\n";

   # Prepare to get review values from the --review table.
   my $review_sth;
   my @review_cols;
   if ( $opts->{R} ) {
      my %exclude_cols = (fingerprint => 1, sample => 1, checksum => 1);
      @review_cols = grep { !$exclude_cols{$_} }
                        (@{$qv->{basic_cols}}, @{$qv->{extra_cols}});
      my $sql = "SELECT "
              . join(', ', map { $q->quote($_) } @review_cols)
              . ", CONV(checksum, 10, 16) AS checksum_conv FROM "
              . $q->quote($opts->{R}->{D}, $opts->{R}->{t})
              . " WHERE checksum=CONV(?, 16, 10)";
      MKDEBUG && _d("select for review vals: $sql");
      $review_sth = $qv_dbh->prepare($sql);
   }

   QUERY:
   foreach my $i ( 0..$#worst ) {
      my $class       = $worst[$i];
      my $fingerprint = $class->{fingerprint};
      my $checksum    =  QueryReview::make_checksum($fingerprint);

      my $review_vals;
      if ( $opts->{R} ) {
         $review_sth->execute($checksum);
         $review_vals = $review_sth->fetchall_arrayref({});
         if ( $review_vals && @$review_vals == 1 ) {
            $review_vals = $review_vals->[0];
            delete $review_vals->{checksum};
            if ( defined $review_vals->{reviewed_by} && !$opts->{reportall} ) {
               next QUERY;
            }
         }
      }

      # Calculate QPS (queries per second) by looking at the min/max timestamp.
      my $qps = 0;
      if ( $class->{$opts->{w}}->{cnt} > 1
            && $class->{ts}->{min}
            && $class->{ts}->{max} gt $class->{ts}->{min}
      ) {
         my $min = parse_timestamp($class->{ts}->{min});
         my $max = parse_timestamp($class->{ts}->{max});
         $qps = $class->{$opts->{w}}->{cnt} / ( $max - $min );
      }

      my $header = sprintf $query_hdr_fmt, $i + 1, shorten($qps,p=>1,d=>1000),
            $checksum, $class->{$opts->{w}}->{sample}->{pos_in_log} || 0;

      print  $header, ('_' x (73 - length($header))), "\n";
      printf $metrics_hdr_fmt;
      printf $count_line_fmt,
         'Count',
         $class->{$opts->{w}}->{cnt},
         percentage_of($class->{$opts->{w}}->{cnt}, $ea->{n_queries});

      # TODO: get this list from cmdline arguments
      foreach my $metric ( qw(Query_time Lock_time Rows_sent Rows_examined) ) {
         my $val = $class->{ $metric };
         next unless $val->{cnt}; # There's nothing to report.

         next unless $val && %$val;
         MKDEBUG && _d("Reporting metrics for $metric");

         my $stats = $ea->calculate_statistical_metrics($val->{all}, $val);

         # TODO: this should be the $worst.  And of course that means we need an
         # adaptable distribution, because Rows_sent has a larger typical range
         # than Query_time for example.
         $Query_time_distro = $stats->{distro} if $metric eq 'Query_time';

         my $fmt_sub = $metric =~ m/time/
            ? sub { return micro_t(@_, p_ms => 1, p_s => 1); }
            : sub { return shorten(@_, p => 1, d => 1000); };

         (my $name = $metric) =~ s/_/ /g;
         $name = substr($name, 0, 9);
         # Special case :-) TODO
         if ( $metric eq 'Query_time' ) {
            $name = 'Exec time';
         }
         printf $metric_line_fmt,
            $name,                                 # friendly metric name
            $fmt_sub->($val->{sum}),               # total
            percentage_of($val->{sum},
                          $g->{$metric}->{sum}),   # % total/grand total
            $fmt_sub->($val->{min}),               # min
            $fmt_sub->($val->{max}),               # max
            $fmt_sub->($val->{sum}/$val->{cnt}),   # avg
            $fmt_sub->($stats->{max}),             # 95% are within this
            $fmt_sub->($stats->{stddev}),          # 95% stdev
            $fmt_sub->($stats->{median});          # 95% med
      }

      printf $list_line_fmt, 'DBs',   join(', ', keys %{$class->{db}->{unq}});
      printf $list_line_fmt, 'Users', join(', ', keys %{$class->{user}->{unq}});
      # TODO: also print hosts
      # TODO: print DBs, Users, Hosts in this format: foo(8), bar(10)
      # so the count follows the value
      # TODO: when there are a TON of unique user/host/whatever, just print "<N>
      # distinct values" and maybe also print the top 5 by default (make an
      # option to control this).  Good example of this is in issue 2193.

      # TODO: permit to switch off with cmdline option --verbosity or --quiet
      if ( $class->{ts}->{min} ) {
         printf $timestamp_fmt,
            map { ts(parse_timestamp($_)) } @{$class->{ts}}{qw(min max)};
      }
      print "# Execution times\n";
      print chart_distro($Query_time_distro);

      # TODO
      # print "# Time clustering\n";

      if ( $opts->{R} ) {
         print "# Review information\n";
         foreach my $col ( @review_cols ) {
            my $val = $review_vals->{$col};
            printf $review_info_fmt, $col, (defined $val ? $val : '');
         }
      }

      print "# Fingerprint\n#    $fingerprint\n" if $opts->{f};

      # If the query uses qualified table names (db.tbl), print_tables()
      # will print SHOW TABLE STATUS FROM `db` LIKE 'tbl'. Otherwise,
      # if a default_db is given, print_tables() will use it for queries
      # without qualified table names. We pass a default db only if the
      # query logged one db because there is no reliable way to choose
      # between multiple logged dbs. As a last report, print_tables()
      # will simply omit the FROM `db` clause and it's left to the user
      # to determine the correct db.
      my ( $default_db ) = keys %{$class->{db}->{unq}}
         if scalar keys %{$class->{db}->{unq}} == 1;

      # Get the sample query and shorten it for readability if necessary (issue
      # 216).
      my $sample = $class->{$opts->{w}}->{sample}->{arg};
      $sample =~ s{\A(INSERT INTO \S+ VALUES \(.*?\)),\(.*\Z}
                  {$1/*multi-value INSERT omitted*/}s;

      my $select_pattern = qr/^[\s\(]*SELECT /i;
      if ( $sample =~ m/$select_pattern/ ) {
         print_tables($sample, $default_db) if $opts->{forexplain};
         print "# EXPLAIN\n$sample\\G\n";
      }
      else {
         my $converted_sample = $qr->convert_to_select($sample);
         if ( $converted_sample =~ m/$select_pattern/ ) {
            print_tables($converted_sample, $default_db) if $opts->{forexplain};
            print "$sample\\G\n";
            print "# Converted for EXPLAIN\n# EXPLAIN\n" if $opts->{forexplain};
         }
         # converted_sample will be the original sample if it
         # failed to convert. Otherwise, it will be a SELECT.
         print "$converted_sample\\G\n" if $opts->{forexplain};
      }
      print "\n";
   }

   return;
}

sub chart_distro {
   my ( $distro ) = @_;
   return "\n" if !defined $distro || scalar @$distro== 0;
   my $max_val = 0;
   my $vals_per_mark; # number of vals represented by 1 #-mark
   my $max_disp_width = 64;
   my $bar_fmt = "# %5s%s\n";
   my @distro_labels = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);

   # Find the distro with the most values. This will set
   # vals_per_mark and become the bar at max_disp_width.
   foreach my $n_vals ( @$distro ) {
      $max_val = $n_vals if $n_vals > $max_val;
   }
   $vals_per_mark = $max_val / $max_disp_width;

   MKDEBUG && _d("vals per mark $vals_per_mark, max val $max_val");

   my $i = 0;
   foreach my $n_vals ( @$distro ) {
      MKDEBUG && _d("$n_vals vals in $distro_labels[$i] bucket");

      my $n_marks = $n_vals / $vals_per_mark;

      # Always print at least 1 mark for any bucket that has at least
      # 1 value. This skews the graph a tiny bit, but it allows us to
      # see all buckets that have values.
      $n_marks = 1 if $n_marks < 1 && $n_vals > 0;

      my $bar = ($n_marks ? '  ' : '') . '#' x $n_marks;

      printf $bar_fmt, $distro_labels[$i++], $bar;
   }

   return;
}

sub print_tables {
   my ( $query, $default_db ) = @_;
   my $qp = new QueryParser();
   my $table_aliases = $qp->parse_table_aliases( $qp->get_table_ref($query) );
   print "# Tables\n";
   foreach my $table_alias ( keys %$table_aliases ) {
      next if $table_alias eq 'DATABASE';
      my $tbl = $table_aliases->{$table_alias};
      my $db  = $table_aliases->{DATABASE}->{$tbl} || $default_db;
      print '#    SHOW TABLE STATUS',
         (defined $db && $db ? " FROM `$db`" : ''),
         " LIKE '$tbl'\\G\n";
      print "#    SHOW CREATE TABLE ",
         (defined $db && $db ? "`$db`." : ''),
         "`$tbl`\\G\n";
   }
   # If no tables are printed, this may be due to a query like
   #    SELECT col FROM (SELECT col FROM tbl2) AS tbl1
   # because QueryParser ignores subquery tables.
   return;
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
