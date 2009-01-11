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

use English qw(-no_match_vars);
use POSIX qw(ceil);
use List::Util qw(min max);
use Data::Dumper;
$Data::Dumper::Quotekeys = 0;
$Data::Dumper::Indent    = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   die "I need a quoter" unless $args{quoter};
   bless { %args }, $class;
}

my $EPOCH      = '1970-01-01';
my %int_types  = map { $_ => 1 }
   qw( bigint date datetime int mediumint smallint time timestamp tinyint year );
my %real_types = map { $_ => 1 }
   qw( decimal double float );

# $table  hashref returned from TableParser::parse
# $opts   hashref of options
#         exact: try to support exact chunk sizes (may still chunk fuzzily)
#         possible_keys: arrayref of keys to prefer, in order.  These can be
#                        generated from EXPLAIN by TableParser.pm
# Returns an array:
#   whether the table can be chunked exactly, if requested (zero otherwise)
#   arrayref of columns that support chunking
sub find_chunk_columns {
   my ( $self, $table, $opts ) = @_;
   $opts ||= {};

   my %prefer;
   if ( $opts->{possible_keys} && @{$opts->{possible_keys}} ) {
      my $i = 1;
      %prefer = map { $_ => $i++ } @{$opts->{possible_keys}};
      MKDEBUG && _d("Preferred indexes for chunking: "
         . join(', ', @{$opts->{possible_keys}}));
   }

   # See if there's an index that will support chunking.
   my @possible_keys;
   KEY:
   foreach my $key ( values %{ $table->{keys} } ) {

      # Accept only BTREE indexes.
      next unless $key->{type} eq 'BTREE';

      # Reject indexes with prefixed columns.
      defined $_ && next KEY for @{ $key->{col_prefixes} };

      # If exact, accept only unique, single-column indexes.
      if ( $opts->{exact} ) {
         next unless $key->{unique} && @{$key->{cols}} == 1;
      }

      push @possible_keys, $key;
   }

   # Sort keys by preferred-ness.
   @possible_keys = sort {
      ($prefer{$a->{name}} || 9999) <=> ($prefer{$b->{name}} || 9999)
   } @possible_keys;

   MKDEBUG && _d('Possible keys in order: '
      . join(', ', map { $_->{name} } @possible_keys));

   # Build list of candidate chunk columns.   
   my $can_chunk_exact = 0;
   my @candidate_cols;
   foreach my $key ( @possible_keys ) { 
      my $col = $key->{cols}->[0];

      # Accept only integer or real number type columns.
      next unless ( $int_types{$table->{type_for}->{$col}}
                    || $real_types{$table->{type_for}->{$col}} );

      # Save the candidate column and its index.
      push @candidate_cols, { column => $col, index => $key->{name} };
   }

   $can_chunk_exact = 1 if ( $opts->{exact} && scalar @candidate_cols );

   if ( MKDEBUG ) {
      my $chunk_type = $opts->{exact} ? 'Exact' : 'Inexact';
      _d("$chunk_type chunkable: "
         . join(', ', map { "$_->{column} on $_->{index}" } @candidate_cols));
   }

   # Order the candidates by their original column order.
   # Put the PK's first column first, if it's a candidate.
   my @result;
   if ( !%prefer ) {
      MKDEBUG && _d('Ordering columns by order in tbl, PK first');
      if ( $table->{keys}->{PRIMARY} ) {
         my $pk_first_col = $table->{keys}->{PRIMARY}->{cols}->[0];
         @result = grep { $_->{column} eq $pk_first_col } @candidate_cols;
         @candidate_cols = grep { $_->{column} ne $pk_first_col } @candidate_cols;
      }
      my $i = 0;
      my %col_pos = map { $_ => $i++ } @{$table->{cols}};
      push @result, sort { $col_pos{$a->{column}} <=> $col_pos{$b->{column}} }
                       @candidate_cols;
   }
   else {
      @result = @candidate_cols;
   }

   if ( MKDEBUG ) {
      _d('Chunkable columns: '
         . join(', ', map { "$_->{column} on $_->{index}" } @result));
      _d("Can chunk exactly: $can_chunk_exact");
   }

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
   MKDEBUG && _d("Arguments: "
      . join(', ',
         map { "$_=" . (defined $args{$_} ? $args{$_} : 'undef') } keys %args));

   my @chunks;
   my ($range_func, $start_point, $end_point);
   my $col_type = $args{table}->{type_for}->{$args{col}};
   MKDEBUG && _d("Chunking on $args{col} ($col_type)");

   # Determine chunk size in "distance between endpoints" that will give
   # approximately the right number of rows between the endpoints.  Also
   # find the start/end points as a number that Perl can do + and < on.

   if ( $col_type =~ m/(?:int|year|float|double|decimal)$/ ) {
      $start_point = $args{min};
      $end_point   = $args{max};
      $range_func  = 'range_num';
   }
   elsif ( $col_type eq 'timestamp' ) {
      my $sql = "SELECT UNIX_TIMESTAMP('$args{min}'), UNIX_TIMESTAMP('$args{max}')";
      MKDEBUG && _d($sql);
      ($start_point, $end_point) = $args{dbh}->selectrow_array($sql);
      $range_func  = 'range_timestamp';
   }
   elsif ( $col_type eq 'date' ) {
      my $sql = "SELECT TO_DAYS('$args{min}'), TO_DAYS('$args{max}')";
      MKDEBUG && _d($sql);
      ($start_point, $end_point) = $args{dbh}->selectrow_array($sql);
      $range_func  = 'range_date';
   }
   elsif ( $col_type eq 'time' ) {
      my $sql = "SELECT TIME_TO_SEC('$args{min}'), TIME_TO_SEC('$args{max}')";
      MKDEBUG && _d($sql);
      ($start_point, $end_point) = $args{dbh}->selectrow_array($sql);
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
      MKDEBUG && _d('Start point is undefined');
      $start_point = 0;
   }
   if ( !defined $end_point || $end_point < $start_point ) {
      MKDEBUG && _d('End point is undefined or before start point');
      $end_point = 0;
   }
   MKDEBUG && _d("Start and end of chunk range: $start_point, $end_point");

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
   MKDEBUG && _d("Chunk interval: $interval units");

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
   return ( $cols->[0]->{column}, $cols->[0]->{index} );
}

# Convert a size in rows or bytes to a number of rows in the table, using SHOW
# TABLE STATUS.  If the size is a string with a suffix of M/G/k, interpret it as
# mebibytes, gibibytes, or kibibytes respectively.  If it's just a number, treat
# it as a number of rows and return right away.
sub size_to_rows {
   my ( $self, $dbh, $db, $tbl, $size, $dumper ) = @_;
  
   my ( $num, $suffix ) = $size =~ m/^(\d+)([MGk])?$/;
   if ( $suffix ) { # Convert to bytes.
      $size = $suffix eq 'k' ? $num * 1_024
            : $suffix eq 'M' ? $num * 1_024 * 1_024
            :                  $num * 1_024 * 1_024 * 1_024;
   }
   elsif ( $num ) {
      return $num;
   }
   else {
      die "Invalid size spec $size; must be an integer with optional suffix kMG";
   }

   my @status = $dumper->get_table_status($dbh, $self->{quoter}, $db);
   my ($status) = grep { $_->{name} eq $tbl } @status;
   my $avg_row_length = $status->{avg_row_length};
   return $avg_row_length ? ceil($size / $avg_row_length) : undef;
}

# Determine the range of values for the chunk_col column on this table.
# The $where could come from many places; it is not trustworthy.
sub get_range_statistics {
   my ( $self, $dbh, $db, $tbl, $col, $where ) = @_;
   my $q = $self->{quoter};
   my $sql = "SELECT MIN(" . $q->quote($col) . "), MAX(" . $q->quote($col)
      . ") FROM " . $q->quote($db, $tbl)
      . ($where ? " WHERE $where" : '');
   MKDEBUG && _d($sql);
   my ( $min, $max );
   eval {
      ( $min, $max ) = $dbh->selectrow_array($sql);
   };
   if ( $EVAL_ERROR ) {
      chomp $EVAL_ERROR;
      if ( $EVAL_ERROR =~ m/in your SQL syntax/ ) {
         die "$EVAL_ERROR (WHERE clause: $where)";
      }
      else {
         die $EVAL_ERROR;
      }
   }
   $sql = "EXPLAIN SELECT * FROM " . $q->quote($db, $tbl)
      . ($where ? " WHERE $where" : '');
   MKDEBUG && _d($sql);
   my $expl = $dbh->selectrow_hashref($sql);
   return (
      min           => $min,
      max           => $max,
      rows_in_range => $expl->{rows},
   );
}

# Quotes values only when needed, and uses double-quotes instead of
# single-quotes (see comments earlier).
sub quote {
   my ( $self, $val ) = @_;
   return $val =~ m/\d[:-]/ ? qq{"$val"} : $val;
}

# Takes a query prototype and fills in placeholders.  The 'where' arg should be
# an arrayref of WHERE clauses that will be joined with AND.
sub inject_chunks {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(database table chunks chunk_num query) ) {
      die "$arg is required" unless defined $args{$arg};
   }
   MKDEBUG && _d("Injecting chunk $args{chunk_num}");
   my $comment = sprintf("/*%s.%s:%d/%d*/",
      $args{database}, $args{table},
      $args{chunk_num} + 1, scalar @{$args{chunks}});
   $args{query} =~ s!/\*PROGRESS_COMMENT\*/!$comment!;
   my $where = "WHERE (" . $args{chunks}->[$args{chunk_num}] . ')';
   if ( $args{where} && grep { $_ } @{$args{where}} ) {
      $where .= " AND ("
         . join(" AND ", map { "($_)" } grep { $_ } @{$args{where}} )
         . ")";
   }
   my $db_tbl     = $self->{quoter}->quote(@args{qw(database table)});
   my $index_hint = defined $args{index_hint}
                    ? "USE INDEX (`$args{index_hint}`)"
                    : '';
   MKDEBUG && _d("Parameters: ",
      Dumper({WHERE => $where, DB_TBL => $db_tbl, INDEX_HINT => $index_hint}));
   $args{query} =~ s!/\*WHERE\*/! $where!;
   $args{query} =~ s!/\*DB_TBL\*/!$db_tbl!;
   $args{query} =~ s!/\*INDEX_HINT\*/! $index_hint!;
   $args{query} =~ s!/\*CHUNK_NUM\*/! $args{chunk_num} AS chunk_num,!;
   return $args{query};
}

# ###########################################################################
# Range functions.
# ###########################################################################
sub range_num {
   my ( $self, $dbh, $start, $interval, $max ) = @_;
   my $end = min($max, $start + $interval);


   # "Remove" scientific notation so the regex below does not make
   # 6.123456e+18 into 6.12345.
   $start = sprintf('%.17f', $start) if $start =~ /e/;
   $end   = sprintf('%.17f', $end)   if $end   =~ /e/;

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
   my $sql = "SELECT SEC_TO_TIME($start), SEC_TO_TIME(LEAST($max, $start + $interval))";
   MKDEBUG && _d($sql);
   return $dbh->selectrow_array($sql);
}

sub range_date {
   my ( $self, $dbh, $start, $interval, $max ) = @_;
   my $sql = "SELECT FROM_DAYS($start), FROM_DAYS(LEAST($max, $start + $interval))";
   MKDEBUG && _d($sql);
   return $dbh->selectrow_array($sql);
}

sub range_datetime {
   my ( $self, $dbh, $start, $interval, $max ) = @_;
   my $sql = "SELECT DATE_ADD('$EPOCH', INTERVAL $start SECOND), "
       . "DATE_ADD('$EPOCH', INTERVAL LEAST($max, $start + $interval) SECOND)";
   MKDEBUG && _d($sql);
   return $dbh->selectrow_array($sql);
}

sub range_timestamp {
   my ( $self, $dbh, $start, $interval, $max ) = @_;
   my $sql = "SELECT FROM_UNIXTIME($start), FROM_UNIXTIME(LEAST($max, $start + $interval))";
   MKDEBUG && _d($sql);
   return $dbh->selectrow_array($sql);
}

# Returns the number of seconds between $EPOCH and the value, according to
# the MySQL server.  (The server can do no wrong).  I believe this code is right
# after looking at the source of sql/time.cc but I am paranoid and add in an
# extra check just to make sure.  Earlier versions overflow on large interval
# values, such as on 3.23.58, '1970-01-01' - interval 58000000000 second is
# 2037-06-25 11:29:04.  I know of no workaround.  TO_DAYS('0000-....') is NULL,
# so we treat it as 0.
sub timestampdiff {
   my ( $self, $dbh, $time ) = @_;
   my $sql = "SELECT (COALESCE(TO_DAYS('$time'), 0) * 86400 + TIME_TO_SEC('$time')) "
      . "- TO_DAYS('$EPOCH 00:00:00') * 86400";
   MKDEBUG && _d($sql);
   my ( $diff ) = $dbh->selectrow_array($sql);
   $sql = "SELECT DATE_ADD('$EPOCH', INTERVAL $diff SECOND)";
   MKDEBUG && _d($sql);
   my ( $check ) = $dbh->selectrow_array($sql);
   die <<"   EOF"
   Incorrect datetime math: given $time, calculated $diff but checked to $check.
   This is probably because you are using a version of MySQL that overflows on
   large interval values to DATE_ADD().  If not, please report this as a bug.
   EOF
      unless $check eq $time;
   return $diff;
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
# End TableChunker package
# ###########################################################################
