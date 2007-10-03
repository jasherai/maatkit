# ###########################################################################
# TableChunker package
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableChunker;

sub new {
   bless {}, shift;
}

my %int_types = map { $_ => 1 }
   qw( bigint date datetime int mediumint smallint time timestamp tinyint year );
my %real_types = map { $_ => 1 }
   qw( decimal double float );

# $table  hashref returned from TableParser::parse
# $opts   hashref of options
#         exact: try to support exact chunk sizes (may still chunk fuzzily)
sub find_chunk_columns {
   my ( $self, $table, $opts ) = @_;
   $opts ||= {};

   # See if there's an index that will support chunking.  If exact
   # is specified, it must be single column unique or primary.
   my @candidate_cols;

   # Only BTREE are good for range queries.
   my @possible_keys = grep { $_->{type} eq 'BTREE' } values %{$table->{keys}};

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

   # Order the candidates by their original column order.
   my $i = 0;
   my %col_pos = map { $_ => $i++ } @{$table->{cols}};
   @candidate_cols = sort { $col_pos{$a} <=> $col_pos{$b} } @candidate_cols;

   return @candidate_cols;
}

sub calculate_chunks {
   my ( $self, $table, $opts ) = @_;
   $opts ||= {};

   my $table_min;
   my $table_max;
   my $num_rows;
   my $chunk_size;
   my @chunks;

=pod
   # Determine the range of values for the chunk_col column on this table.
   my $chunk_sql = "SELECT MIN($table->{chunk_col}), MAX($table->{chunk_col}) "
      . "FROM `$table->{database}`.`$table->{table}`$opts{W}";
   if ( $table->{chunk_null} && !version_ge($main_dbh, '4.0.0') ) {
      # MySQL 3.23 will return NULL as the minimum column value and break my
      # test suite when there is a row with NULL in the chunk column.
      $chunk_sql .= "AND $table->{chunk_col} IS NOT NULL";
   }

   ( $table_min, $table_max ) = $main_dbh->selectrow_array($chunk_sql);

   my $expl = $main_dbh->selectrow_hashref(
      "EXPLAIN SELECT * FROM `$table->{database}`.`$table->{table}"
      . "`$opts{W} AND $table->{chunk_col} IS NOT NULL");

   # This isn't always reliable.  Sometimes EXPLAIN will say there are rows
   # when the table is empty.
   $num_rows = $expl->{rows};

   if ( $num_rows && defined $table_min && defined $table_max ) { # $num_rows is unreliable

      # Determine chunk size in "distance between endpoints" that will give
      # approximately the right number of rows between the endpoints.  Also
      # find the start/end points as a number that Perl can do + and < on.
      my ($range_func, $start_point, $end_point);
      if ( $table->{chunk_type} =~ m/(?:int|year|float|double|decimal)$/ ) {
         $start_point = $table_min;
         $end_point   = $table_max;
         $range_func  = \&range_num;
      }
      elsif ( $table->{chunk_type} eq 'timestamp' ) {
         ($start_point, $end_point) = $main_dbh->selectrow_array(
            "SELECT UNIX_TIMESTAMP('$table_min'), UNIX_TIMESTAMP('$table_max')");
         $range_func  = \&range_timestamp;
      }
      elsif ( $table->{chunk_type} eq 'date' ) {
         ($start_point, $end_point) = $main_dbh->selectrow_array(
            "SELECT TO_DAYS('$table_min'), TO_DAYS('$table_max')");
         $range_func  = \&range_date;
      }
      elsif ( $table->{chunk_type} eq 'time' ) {
         ($start_point, $end_point) = $main_dbh->selectrow_array(
            "SELECT TIME_TO_SEC('$table_min'), TIME_TO_SEC('$table_max')");
         $range_func  = \&range_time;
      }
      elsif ( $table->{chunk_type} eq 'datetime' ) {
         # Newer versions of MySQL could use TIMESTAMPDIFF, but it's easier
         # to maintain just one kind of code, so I do it all with DATE_ADD().
         $start_point = timestampdiff($main_dbh, $table_min);
         $end_point   = timestampdiff($main_dbh, $table_max);
         $range_func  = \&range_datetime;
      }
      else {
         die "I don't know how to chunk $table->{chunk_type}\n";
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
      # specified.  Add 1 to the range because the interval is half-open,
      # that is, it is inclusive on the upper end.  (If the table's min value is
      # 1 and the max is 100, that's 100 values to cover, not 99).
      $chunk_size = ceil( $opts{C} * (($end_point - $start_point) + 1) / $num_rows ) || $opts{C};
      if ( $opts{'chunksize-exact'} && $table->{chunk_exact} ) {
         $chunk_size = $opts{C};
      }

      # Generate a list of chunk boundaries.
      for ( my $i = $start_point; $i < $end_point; $i += $chunk_size ) {
         push @chunks, [ $range_func->($main_dbh, $i, $chunk_size, $end_point) ];
      }

      if ( $start_point < $end_point ) {
         # A final chunk that matches the end of the range, and anything outside it
         # on the upper end, which should not happen on the master but may on a
         # slave that has extra rows.
         push @chunks, [ $chunks[-1]->[1], undef ];

         # Ditto for rows below the lower boundary, but this one should not match
         # anything at all on the master, unlike the one above.
         push @chunks, [ undef, $chunks[0]->[0] ];
      }
      else {
         # There are no chunks; just do the whole table in one chunk.
         push @chunks, '';
      }

   }
   else {
      push @chunks, '';
   }

   # If the chunk column is nullable, we need to do NULL separately.
   if ( $table->{chunk_null} ) {
      push @chunks, undef;
   }

   $table->{chunks}    = \@chunks;
   $table->{chunk_tot} = scalar(@chunks);
=cut
}
1;

# ###########################################################################
# End TableChunker package
# ###########################################################################

