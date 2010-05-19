# This program is copyright 2007-2009 Baron Schwartz.
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
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# MySQL functions used to evalute whether a value for a column type is
# valid or not.  If func(val) returns any defined value then it's valid.
my %mysql_func_for = (
   timestamp => 'UNIX_TIMESTAMP',
   date      => 'TO_DAYS',
   time      => 'TIME_TO_SEC',
   datetime  => 'TO_DAYS',
);

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(Quoter MySQLDump) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = { %args };
   return bless $self, $class;
}

my $EPOCH      = '1970-01-01';
my %int_types  = map { $_ => 1 }
   qw(bigint date datetime int mediumint smallint time timestamp tinyint year);
my %real_types = map { $_ => 1 }
   qw(decimal double float);

# Arguments:
#   * table_struct    Hashref returned from TableParser::parse
#   * exact           (optional) bool: Try to support exact chunk sizes
#                     (may still chunk fuzzily)
# Returns an array:
#   whether the table can be chunked exactly, if requested (zero otherwise)
#   arrayref of columns that support chunking
sub find_chunk_columns {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(tbl_struct) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $tbl_struct = $args{tbl_struct};

   # See if there's an index that will support chunking.
   my @possible_indexes;
   foreach my $index ( values %{ $tbl_struct->{keys} } ) {

      # Accept only BTREE indexes.
      next unless $index->{type} eq 'BTREE';

      # Reject indexes with prefixed columns.
      defined $_ && next for @{ $index->{col_prefixes} };

      # If exact, accept only unique, single-column indexes.
      if ( $args{exact} ) {
         next unless $index->{is_unique} && @{$index->{cols}} == 1;
      }

      push @possible_indexes, $index;
   }
   MKDEBUG && _d('Possible chunk indexes in order:',
      join(', ', map { $_->{name} } @possible_indexes));

   # Build list of candidate chunk columns.   
   my $can_chunk_exact = 0;
   my @candidate_cols;
   foreach my $index ( @possible_indexes ) { 
      my $col = $index->{cols}->[0];

      # Accept only integer or real number type columns.
      next unless ( $int_types{$tbl_struct->{type_for}->{$col}}
                    || $real_types{$tbl_struct->{type_for}->{$col}} );

      # Save the candidate column and its index.
      push @candidate_cols, { column => $col, index => $index->{name} };
   }

   $can_chunk_exact = 1 if $args{exact} && scalar @candidate_cols;

   if ( MKDEBUG ) {
      my $chunk_type = $args{exact} ? 'Exact' : 'Inexact';
      _d($chunk_type, 'chunkable:',
         join(', ', map { "$_->{column} on $_->{index}" } @candidate_cols));
   }

   # Order the candidates by their original column order.
   # Put the PK's first column first, if it's a candidate.
   my @result;
   MKDEBUG && _d('Ordering columns by order in tbl, PK first');
   if ( $tbl_struct->{keys}->{PRIMARY} ) {
      my $pk_first_col = $tbl_struct->{keys}->{PRIMARY}->{cols}->[0];
      @result          = grep { $_->{column} eq $pk_first_col } @candidate_cols;
      @candidate_cols  = grep { $_->{column} ne $pk_first_col } @candidate_cols;
   }
   my $i = 0;
   my %col_pos = map { $_ => $i++ } @{$tbl_struct->{cols}};
   push @result, sort { $col_pos{$a->{column}} <=> $col_pos{$b->{column}} }
                    @candidate_cols;

   if ( MKDEBUG ) {
      _d('Chunkable columns:',
         join(', ', map { "$_->{column} on $_->{index}" } @result));
      _d('Can chunk exactly:', $can_chunk_exact);
   }

   return ($can_chunk_exact, @result);
}

# Arguments:
#   * tbl_struct     Return value from TableParser::parse()
#   * chunk_col      Which column to chunk on
#   * min            Min value of col
#   * max            Max value of col
#   * rows_in_range  How many rows are in the table between min and max
#   * chunk_size     How large each chunk should be (not adjusted)
#   * dbh            A DBI connection to MySQL
#   * exact          Whether to chunk exactly (optional)
#
# Returns a list of WHERE clauses, one for each chunk.  Each is quoted with
# double-quotes, so it'll be easy to enclose them in single-quotes when used as
# command-line arguments.
sub calculate_chunks {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(dbh tbl_struct chunk_col min max rows_in_range
                        chunk_size dbh) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   MKDEBUG && _d('Calculate chunks for', Dumper(\%args));
   my $dbh = $args{dbh};

   my @chunks;
   my ($range_func, $start_point, $end_point);
   my $col_type = $args{tbl_struct}->{type_for}->{$args{chunk_col}};
   MKDEBUG && _d('chunk col type:', $col_type);

   # Determine chunk size in "distance between endpoints" that will give
   # approximately the right number of rows between the endpoints.  Also
   # find the start/end points as a number that Perl can do + and < on.

   eval {
      my $func = $mysql_func_for{$col_type};
      if ( $col_type =~ m/(?:int|year|float|double|decimal)$/ ) {
         $start_point = $args{min};
         $end_point   = $args{max};
         $range_func  = 'range_num';
      }
      elsif ( $col_type eq 'timestamp' ) {
         my $sql = "SELECT $func('$args{min}'), $func('$args{max}')";
         MKDEBUG && _d($sql);
         ($start_point, $end_point) = $dbh->selectrow_array($sql);
         $range_func  = 'range_timestamp';
      }
      elsif ( $col_type eq 'date' ) {
         my $sql = "SELECT $func('$args{min}'), $func('$args{max}')";
         MKDEBUG && _d($sql);
         ($start_point, $end_point) = $dbh->selectrow_array($sql);
         $range_func  = 'range_date';
      }
      elsif ( $col_type eq 'time' ) {
         my $sql = "SELECT $func('$args{min}'), $func('$args{max}')";
         MKDEBUG && _d($sql);
         ($start_point, $end_point) = $dbh->selectrow_array($sql);
         $range_func  = 'range_time';
      }
      elsif ( $col_type eq 'datetime' ) {
         # Newer versions of MySQL could use TIMESTAMPDIFF, but it's easier
         # to maintain just one kind of code, so I do it all with DATE_ADD().
         $start_point = $self->timestampdiff($dbh, $args{min});
         $end_point   = $self->timestampdiff($dbh, $args{max});
         $range_func  = 'range_datetime';
      }
      else {
         die "I don't know how to chunk $col_type\n";
      }
   };
   if ( $EVAL_ERROR ) {
      if ( $EVAL_ERROR =~ m/don't know how to chunk/ ) {
         # Special kind of error doesn't make sense with the more verbose
         # description below.
         die $EVAL_ERROR;
      }
      else {
         die "Error calculating chunk start and end points for table "
            . "`$args{tbl_struct}->{name}` on column `$args{chunk_col}` "
            . "with min/max values "
            . join('/',
                  map { defined $args{$_} ? $args{$_} : 'undef' } qw(min max))
            . ":\n\n"
            . $EVAL_ERROR
            . "\nVerify that the min and max values are valid for the column.  "
            . "If they are valid, this error could be caused by a bug in the "
            . "tool.";
      }
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
   MKDEBUG && _d('Start and end of chunk range:',$start_point,',', $end_point);

   # Calculate the chunk size, in terms of "distance between endpoints."  If
   # possible and requested, forbid chunks from being any bigger than
   # specified.
   my $interval = $args{chunk_size}
                * ($end_point - $start_point)
                / $args{rows_in_range};
   if ( $int_types{$col_type} ) {
      $interval = ceil($interval);
   }
   $interval ||= $args{chunk_size};
   if ( $args{exact} ) {
      $interval = $args{chunk_size};
   }
   MKDEBUG && _d('Chunk interval:', $interval, 'units');

   # Generate a list of chunk boundaries.  The first and last chunks are
   # inclusive, and will catch any rows before or after the end of the
   # supposed range.  So 1-100 divided into chunks of 30 should actually end
   # up with chunks like this:
   #           < 30
   # >= 30 AND < 60
   # >= 60 AND < 90
   # >= 90
   my $col = $self->{Quoter}->quote($args{chunk_col});
   if ( $start_point < $end_point ) {
      my ( $beg, $end );
      my $iter = 0;
      for ( my $i = $start_point; $i < $end_point; $i += $interval ) {
         ( $beg, $end ) = $self->$range_func($dbh, $i, $interval, $end_point);

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
      my $nullable = $args{tbl_struct}->{is_nullable}->{$args{chunk_col}};
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
      MKDEBUG && _d('No chunks; using single chunk 1=1');
      push @chunks, '1=1';
   }

   return @chunks;
}

sub get_first_chunkable_column {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(tbl_struct) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($exact, @cols) = $self->find_chunk_columns(%args);
   return ( $cols[0]->{column}, $cols[0]->{index} );
}

# Convert a size in rows or bytes to a number of rows in the table, using SHOW
# TABLE STATUS.  If the size is a string with a suffix of M/G/k, interpret it as
# mebibytes, gibibytes, or kibibytes respectively.  If it's just a number, treat
# it as a number of rows and return right away.
sub size_to_rows {
   my ( $self, %args ) = @_;
   my @required_args = qw(dbh db tbl chunk_size);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dbh, $db, $tbl, $chunk_size) = @args{@required_args};
   my $q  = $self->{Quoter};
   my $du = $self->{MySQLDump};

   my ($n_rows, $avg_row_length);

   my ( $num, $suffix ) = $chunk_size =~ m/^(\d+)([MGk])?$/;
   if ( $suffix ) { # Convert to bytes.
      $chunk_size = $suffix eq 'k' ? $num * 1_024
                  : $suffix eq 'M' ? $num * 1_024 * 1_024
                  :                  $num * 1_024 * 1_024 * 1_024;
   }
   elsif ( $num ) {
      $n_rows = $num;
   }
   else {
      die "Invalid chunk size $chunk_size; must be an integer "
         . "with optional suffix kMG";
   }

   if ( $suffix || $args{avg_row_length} ) {
      my ($status) = $du->get_table_status($dbh, $q, $db, $tbl);
      $avg_row_length = $status->{avg_row_length};
      if ( !defined $n_rows ) {
         $n_rows = $avg_row_length ? ceil($chunk_size / $avg_row_length) : undef;
      }
   }

   return wantarray ? ($n_rows, $avg_row_length) : $n_rows;
}

# Determine the range of values for the chunk_col column on this table.
# The $where could come from many places; it is not trustworthy.
sub get_range_statistics {
   my ( $self, %args ) = @_;
   my @required_args = qw(dbh db tbl chunk_col col_type);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dbh, $db, $tbl, $col) = @args{@required_args};
   my $where  = $args{where};
   my $q      = $self->{Quoter};

   # Quote these once so we don't have to do it again. 
   my $db_tbl = $q->quote($db, $tbl);
   $col       = $q->quote($col);

   my $sql = "SELECT MIN($col), MAX($col) FROM $db_tbl"
           . ($where ? " WHERE $where" : '');
   MKDEBUG && _d($dbh, $sql);
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

   # Check that min is valid.  If not, find the first valid min value.
   # If there isn't one, this will return undef, so don't overwrite
   # $min so we can report it in the error message.
   my $valid_min = $self->first_valid_value(
      val      => $min,
      col_type => $args{col_type},
      endpoint => 'min',
      tries    => $args{tries},
      dbh      => $dbh,
      db_tbl   => $db_tbl,
      col      => $col,
      where    => $where,
   );
   if ( !defined $valid_min ) {
      die "Error finding a valid minimum value for table $db_tbl on column "
         . "$col. The real minimum value $min is invalid and no other valid "
         . "values were found.  Verify that the table has at least one valid "
         . "value for this column" . ($where ? " where $where." : ".");
   }
   $min = $valid_min;  # may be original $min, maybe next valid min value

   # Same as above but for max value, although it should be pretty rare
   # that the max value is invalid.
   my $valid_max = $self->first_valid_value(
      val      => $max,
      col_type => $args{col_type},
      endpoint => 'max',
      tries    => $args{tries},
      dbh      => $dbh,
      db_tbl   => $db_tbl,
      col      => $col,
      where    => $where,
   );
   if ( !defined $valid_max ) {
      die "Error finding a valid maximum value for table $db_tbl on column "
         . "$col. The real maximum value $max is invalid and no other valid "
         . "values were found.  Verify that the table has at least one valid "
         . "value for this column " . ($where ? "where $where." : ".");
   }
   $max = $valid_max;  # may be original $max, maybe next valid max value

   # Don't want minimum row if its zero or NULL.
   if ( !$args{zero_row} ) {
      if ( !$min
           || $min eq '0'
           || $min eq '0000-00-00'
           || $min eq '0000-00-00 00:00:00'
         )
      {
         MKDEBUG && _d('Discarding zero min:', $min);
         $sql = "SELECT MIN($col) FROM $db_tbl "
              . "WHERE $col > ? "
              . ($where ? " AND $where " : '')
              . "LIMIT 1";
         MKDEBUG && _d($sql);
         my $sth = $dbh->prepare($sql);
         $sth->execute($min);
         ($min) = $sth->fetchrow_array();
         MKDEBUG && _d('New min:', $min);
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
      die "I need a $arg argument" unless defined $args{$arg};
   }
   MKDEBUG && _d('Injecting chunk', $args{chunk_num});
   my $query   = $args{query};
   my $comment = sprintf("/*%s.%s:%d/%d*/",
      $args{database}, $args{table},
      $args{chunk_num} + 1, scalar @{$args{chunks}});
   $query =~ s!/\*PROGRESS_COMMENT\*/!$comment!;
   my $where = "WHERE (" . $args{chunks}->[$args{chunk_num}] . ')';
   if ( $args{where} && grep { $_ } @{$args{where}} ) {
      $where .= " AND ("
         . join(" AND ", map { "($_)" } grep { $_ } @{$args{where}} )
         . ")";
   }
   my $db_tbl     = $self->{Quoter}->quote(@args{qw(database table)});
   my $index_hint = $args{index_hint} || '';

   MKDEBUG && _d('Parameters:',
      Dumper({WHERE => $where, DB_TBL => $db_tbl, INDEX_HINT => $index_hint}));
   $query =~ s!/\*WHERE\*/! $where!;
   $query =~ s!/\*DB_TBL\*/!$db_tbl!;
   $query =~ s!/\*INDEX_HINT\*/! $index_hint!;
   $query =~ s!/\*CHUNK_NUM\*/! $args{chunk_num} AS chunk_num,!;

   return $query;
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
   This could be due to a version of MySQL that overflows on large interval
   values to DATE_ADD(), or the given datetime is not a valid date.  If not,
   please report this as a bug.
   EOF
      unless $check eq $time;
   return $diff;
}

# Arguments:
#   * val       scalar: the current value, may be valid, maybe not
#   * col_type  scalar: column type, e.g. "datetime"
#   * endpoint  scalar: "min" or "max", i.e. find first endpoint() valid val
#   * dbh       dbh
#   * db_tbl    scalar: quoted db.tbl
#   * col       scalar: quoted column name
# Find and return first valid (i.e. defined) value in the given db.tbl.col.
# Returns the first valid value, which may be zero, else returns undef.
sub first_valid_value {
   my ( $self, %args ) = @_;
   my @required_args = qw(val col_type endpoint dbh db_tbl col);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my ($val, $col_type, $endpoint, $dbh, $db_tbl, $col) = @args{@required_args};
   my $tries = defined $args{tries} ? $args{tries} : 5;

   # We don't eval all column types, just those in %mysql_func_for.
   if ( !$mysql_func_for{$col_type} ) {
      MKDEBUG && _d('No MySQL func to eval', $col_type, 'type column');
      return $val;
   }

   # Evaluate the current value.  It may be valid.  If so, return it.
   my $valid_val = $self->_eval_val(
      dbh  => $dbh,
      val  => $val,
      func => $mysql_func_for{$col_type},
   );

   # Current value isn't valid so start looking for the first valid val.
   if ( !defined $valid_val ) {  # 0 is valid so check defined
      MKDEBUG && _d($endpoint, 'value is invalid, finding first valid',
         $endpoint, 'value');

      # Prep a sth for fetching the next col val.
      my $cmp = $endpoint =~ m/min/i ? '>' : '<';
      my $sql = "SELECT $col FROM $db_tbl WHERE $col $cmp ? "
              . ($args{where} ? "WHERE $args{where} " : "")
              . "LIMIT 1";
      MKDEBUG && _d($dbh, $sql);
      my $sth = $dbh->prepare($sql);

      # Fetch the next col val from the db.tbl until we find a valid one
      # or run out of rows.  Only try a limited number of next rows.
      my $last_val = $val;
      while ( $tries-- && !defined $valid_val ) {
         $sth->execute($last_val);
         my ($alt_val) = $sth->fetchrow_array();
         MKDEBUG && _d('Next value:', $alt_val, '; tries left:', $tries);
         if ( !defined $alt_val ) {
            MKDEBUG && _d('No more rows in table');
            last;
         }
         $valid_val = $self->_eval_val(
            dbh  => $dbh,
            val  => $alt_val,
            func => $mysql_func_for{$col_type},
         );
         $val      = $alt_val if defined $valid_val;
         $last_val = $alt_val;
      }
   }

   # Set val to first valid valid, if any was found, then return it.
   $val = undef unless defined $valid_val;
   return $val;
}

# Evaluate the given val with the given MySQL func(tion).
# E.g. SELECT TO_DAYS('2010-00-09') evaluates to NULL/undef,
# so val is invalid.  Any valid combination of val and func
# should eval to a defined value (so zero is valid).
sub _eval_val {
   my ( $self, %args ) = @_;
   my @required_args = qw(dbh val func);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dbh, $val, $func) = @args{@required_args};

   my $sql = "SELECT $func('$val')";
   MKDEBUG && _d($dbh, $sql);
   my $eval_val;
   eval {
      ($eval_val) = $dbh->selectrow_array($sql);
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d($EVAL_ERROR);
      return;
   }
   MKDEBUG && _d('Value evaluates to', $eval_val);
   return $eval_val;
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
# End TableChunker package
# ###########################################################################
