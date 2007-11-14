# This program is copyright (c) 2007 Baron Schwartz.
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
# TableChunker package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableChunker;

use POSIX qw(ceil);
use List::Util qw(min max);

sub new {
   bless {}, shift;
}

my $EPOCH      = '1970-01-01';
my %int_types  = map { $_ => 1 }
   qw( bigint date datetime int mediumint smallint time timestamp tinyint year );
my %real_types = map { $_ => 1 }
   qw( decimal double float );

# $table  hashref returned from TableParser::parse
# $opts   hashref of options
#         exact: try to support exact chunk sizes (may still chunk fuzzily)
# Returns an array:
#   whether the table can be chunked exactly, if requested (zero otherwise)
#   arrayref of columns that support chunking
sub find_chunk_columns {
   my ( $self, $table, $opts ) = @_;
   $opts ||= {};

   # See if there's an index that will support chunking.  If exact
   # is specified, it must be single column unique or primary.
   my @candidate_cols;

   # Only BTREE are good for range queries.
   my @possible_keys = grep { $_->{type} eq 'BTREE' } values %{$table->{keys}};

   my $can_chunk_exact = 0;
   if ($opts->{exact}) {
      # Find the first column of every single-column unique index.
      @candidate_cols =
         grep {
            $int_types{$table->{type_for}->{$_}}
            || $real_types{$table->{type_for}->{$_}}
         }
         map  { $_->{cols}->[0] }
         grep { $_->{unique} && @{$_->{cols}} == 1 }
              @possible_keys;
      if ( @candidate_cols ) {
         $can_chunk_exact = 1;
      }
   }

   # If an exactly chunk-able index was not found, fall back to non-exact.
   if ( !@candidate_cols ) {
      @candidate_cols =
         grep {
            $int_types{$table->{type_for}->{$_}}
            || $real_types{$table->{type_for}->{$_}}
         }
         map { $_->{cols}->[0] }
         @possible_keys;
   }

   # Order the candidates by their original column order.  Put the PK's
   # first column first, if it's a candidate.
   my @result;
   if ( $table->{keys}->{PRIMARY} ) {
      my $pk_first_col = $table->{keys}->{PRIMARY}->{cols}->[0];
      @result = grep { $_ eq $pk_first_col } @candidate_cols;
      @candidate_cols = grep { $_ ne $pk_first_col } @candidate_cols;
   }
   my $i = 0;
   my %col_pos = map { $_ => $i++ } @{$table->{cols}};
   push @result, sort { $col_pos{$a} <=> $col_pos{$b} } @candidate_cols;

   return ($can_chunk_exact, \@result);
}

# table:         output from TableParser::parse
# col:           which column to chunk on
# min:           min value of col
# max:           max value of col
# rows_in_range: how many rows are in the table between min and max
# size:          how large each chunk should be
# dbh:           a DBI connection to MySQL
# exact:         whether to chunk exactly (optional)
#
# Returns a list of WHERE clauses, one for each chunk.  Each is quoted with
# double-quotes, so it'll be easy to enclose them in single-quotes when used as
# command-line arguments.
sub calculate_chunks {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(table col min max rows_in_range size dbh) ) {
      die "Required argument $arg not given or undefined"
         unless defined $args{$arg};
   }

   my @chunks;
   my ($range_func, $start_point, $end_point);
   my $col_type = $args{table}->{type_for}->{$args{col}};

   # Determine chunk size in "distance between endpoints" that will give
   # approximately the right number of rows between the endpoints.  Also
   # find the start/end points as a number that Perl can do + and < on.

   if ( $col_type =~ m/(?:int|year|float|double|decimal)$/ ) {
      $start_point = $args{min};
      $end_point   = $args{max};
      $range_func  = 'range_num';
   }
   elsif ( $col_type eq 'timestamp' ) {
      ($start_point, $end_point) = $args{dbh}->selectrow_array(
         "SELECT UNIX_TIMESTAMP('$args{min}'), UNIX_TIMESTAMP('$args{max}')");
      $range_func  = 'range_timestamp';
   }
   elsif ( $col_type eq 'date' ) {
      ($start_point, $end_point) = $args{dbh}->selectrow_array(
         "SELECT TO_DAYS('$args{min}'), TO_DAYS('$args{max}')");
      $range_func  = 'range_date';
   }
   elsif ( $col_type eq 'time' ) {
      ($start_point, $end_point) = $args{dbh}->selectrow_array(
         "SELECT TIME_TO_SEC('$args{min}'), TIME_TO_SEC('$args{max}')");
      $range_func  = 'range_time';
   }
   elsif ( $col_type eq 'datetime' ) {
      # Newer versions of MySQL could use TIMESTAMPDIFF, but it's easier
      # to maintain just one kind of code, so I do it all with DATE_ADD().
      $start_point = $self->timestampdiff($args{dbh}, $args{min});
      $end_point   = $self->timestampdiff($args{dbh}, $args{max});
      $range_func  = 'range_datetime';
   }
   else {
      die "I don't know how to chunk $col_type\n";
   }

   # The endpoints could easily be undef, because of things like dates that
   # are '0000-00-00'.  The only thing to do is make them zeroes and
   # they'll be done in a single chunk then.
   if ( !defined $start_point ) {
      $start_point = 0;
   }
   if ( !defined $end_point || $end_point < $start_point ) {
      $end_point = 0;
   }

   # Calculate the chunk size, in terms of "distance between endpoints."  If
   # possible and requested, forbid chunks from being any bigger than
   # specified.
   my $interval = $args{size} * ($end_point - $start_point) / $args{rows_in_range};
   if ( $int_types{$col_type} ) {
      $interval = ceil($interval);
   }
   $interval ||= $args{size};
   if ( $args{exact} ) {
      $interval = $args{size};
   }

   # Generate a list of chunk boundaries.  The first and last chunks are
   # inclusive, and will catch any rows before or after the end of the
   # supposed range.  So 1-100 divided into chunks of 30 should actually end
   # up with chunks like this:
   #           < 30
   # >= 30 AND < 60
   # >= 60 AND < 90
   # >= 90
   my $col = "`$args{col}`";
   if ( $start_point < $end_point ) {
      my ( $beg, $end );
      my $iter = 0;
      for ( my $i = $start_point; $i < $end_point; $i += $interval ) {
         ( $beg, $end ) = $self->$range_func($args{dbh}, $i, $interval, $end_point);

         # The first chunk.
         if ( $iter++ == 0 ) {
            push @chunks, "$col < " . $self->quote($end);
         }
         else {
            # The normal case is a chunk in the middle of the range somewhere.
            push @chunks, "$col >= " . $self->quote($beg) . " AND $col < " . $self->quote($end);
         }
      }

      # Remove the last chunk and replace it with one that matches everything
      # from the beginning of the last chunk to infinity.  If the chunk column
      # is nullable, do NULL separately.
      my $nullable = $args{table}->{is_nullable}->{$args{col}};
      pop @chunks;
      if ( @chunks ) {
         push @chunks, "$col >= " . $self->quote($beg);
      }
      else {
         push @chunks, $nullable ? "$col IS NOT NULL" : '1=1';
      }
      if ( $nullable ) {
         push @chunks, "$col IS NULL";
      }

   }
   else {
      # There are no chunks; just do the whole table in one chunk.
      push @chunks, '1=1';
   }

   return @chunks;
}

sub get_first_chunkable_column {
   my ( $self, $table, $opts ) = @_;
   my ($exact, $cols) = $self->find_chunk_columns($table, $opts);
   return $cols->[0];
}

# Convert a size in bytes to a number of rows in the table, using SHOW TABLE
# STATUS.  The $cache may hold the table's status already; if so we use it
# (because it's expensive).
sub size_to_rows {
   my ( $self, $dbh, $db, $tbl, $size, $cache ) = @_;
   my $avg_row_length;
   my $status;
   if ( !$cache || !($status = $cache->{$db}->{$tbl}) ) {
      $tbl =~ s/_/\\_/g;
      my $sth = $dbh->prepare(
         "SHOW TABLE STATUS FROM `$db` LIKE '$tbl'");
      $sth->execute;
      $status = $sth->fetchrow_hashref();
      if ( $cache ) {
         $cache->{$db}->{$tbl} = $status;
      }
   }
   my ($key) = grep { /avg_row_length/i } keys %$status;
   $avg_row_length = $status->{$key};
   return $avg_row_length ? ceil($size / $avg_row_length) : undef;
}

# Determine the range of values for the chunk_col column on this table.
sub get_range_statistics {
   my ( $self, $dbh, $db, $tbl, $col, $opts ) = @_;
   my ( $min, $max ) = $dbh->selectrow_array(
      "SELECT MIN(`$col`), MAX(`$col`) FROM `$db`.`$tbl`");
   my $expl = $dbh->selectrow_hashref(
      "EXPLAIN SELECT * FROM `$db`.`$tbl");
   return (
      min           => $min,
      max           => $max,
      rows_in_range => $expl->{rows},
   );
}

sub quote {
   my ( $self, $val ) = @_;
   return $val =~ m/\d[:-]/ ? qq{"$val"} : $val;
}

sub inject_chunks {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(database table chunks chunk_num) ) {
      die "$arg is required" unless defined $args{$arg};
   }
   my $comment = sprintf("/*%s.%s:%d/%d*/",
      $args{database}, $args{table},
      $args{chunk_num} + 1, scalar @{$args{chunks}});
   $args{query} =~ s!/\*progress_comment\*/!$comment!;
   my $where = "WHERE (" . $args{chunks}->[$args{chunk_num}] . ')';
   if ( $args{where} ) {
      $where .= " AND ($args{where})";
   }
   $args{query} =~ s!/\*WHERE\*/! $where!;
   return $args{query};
}

# ###########################################################################
# Range functions.
# ###########################################################################
sub range_num {
   my ( $self, $dbh, $start, $interval, $max ) = @_;
   my $end = min($max, $start + $interval);
   # Trim decimal places, if needed.  This helps avoid issues with float
   # precision differing on different platforms.
   $start =~ s/\.(\d{5}).*$/.$1/;
   $end   =~ s/\.(\d{5}).*$/.$1/;
   if ( $end > $start ) {
      return ( $start, $end );
   }
   else {
      die "Chunk size is too small: $end !> $start\n";
   }
}

sub range_time {
   my ( $self, $dbh, $start, $interval, $max ) = @_;
   return $dbh->selectrow_array(
      "SELECT SEC_TO_TIME($start), SEC_TO_TIME(LEAST($max, $start + $interval))");
}

sub range_date {
   my ( $self, $dbh, $start, $interval, $max ) = @_;
   return $dbh->selectrow_array(
      "SELECT FROM_DAYS($start), FROM_DAYS(LEAST($max, $start + $interval))");
}

sub range_datetime {
   my ( $self, $dbh, $start, $interval, $max ) = @_;
   return $dbh->selectrow_array(
      "SELECT DATE_ADD('$EPOCH', INTERVAL $start SECOND),
       DATE_ADD('$EPOCH', INTERVAL LEAST($max, $start + $interval) SECOND)");
}

sub range_timestamp {
   my ( $self, $dbh, $start, $interval, $max ) = @_;
   return $dbh->selectrow_array(
      "SELECT FROM_UNIXTIME($start), FROM_UNIXTIME(LEAST($max, $start + $interval))");
}

# Returns the number of seconds between $EPOCH and the value, according to
# the MySQL server.  (The server can do no wrong).  I believe this code is right
# after looking at the source of sql/time.cc but I am paranoid and add in an
# extra check just to make sure.  Earlier versions overflow on large interval
# values, such as on 3.23.58, '1970-01-01' - interval 58000000000 second is
# 2037-06-25 11:29:04.  I know of no workaround.
sub timestampdiff {
   my ( $self, $dbh, $time ) = @_;
   my ( $diff ) = $dbh->selectrow_array(
      "SELECT (TO_DAYS('$time') * 86400 + TIME_TO_SEC('$time')) "
      . "- TO_DAYS('$EPOCH 00:00:00') * 86400");
   my ( $check ) = $dbh->selectrow_array(
      "SELECT DATE_ADD('$EPOCH', INTERVAL $diff SECOND)");
   die <<"   EOF"
   Incorrect datetime math: given $time, calculated $diff but checked to $check.
   This is probably because you are using a version of MySQL that overflows on
   large interval values to DATE_ADD().  If not, please report this as a bug.
   EOF
      unless $check eq $time;
   return $diff;
}

1;

# ###########################################################################
# End TableChunker package
# ###########################################################################
