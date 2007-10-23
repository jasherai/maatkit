# ###########################################################################
# TableNibbler package
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableNibbler;

sub new {
   bless {}, shift;
}

   # These are lists of columns by ordinal position, not by name.  This is
   # necessary because the rows are fetched from the DB as arrays, not as hashes,
   # for efficiency, but for various statements I want one or the other subset of
   # columns.  @pk_slice is the slice that will extract the primary key columns
   # for DELETEs.  @asc_slice is only used to generate queries; it is the column
   # ordinals of the index the get_next query will ascend.  @get_next_slice
   # is the column ordinals in the order in which they appear in the get_next
   # query's WHERE clause.

# Creates the SQL needed to fetch the first row, fetch next rows, insert, and
# delete.  Returns a hashref of
# * first_sql     SQL hashref for fetching first row.
# * next_sql      Ditto, but given last row and a slice, will fetch next row.
# * del_sql       Ditto, to delete a row.
# * ins_sql       Ditto, to insert a row.
# * del_cols      The column names of the PK in first_sql & next_sql.
# * del_slice     Ditto, column ordinals.
# * asc_cols      The column names of the columns we'll ascend.
# * asc_slice     Ditto, column ordinals.
# * next_cols     Column names to pass to next_sql
# * next_slice    Ditto, column ordinals.
# * index         The index to ascend.
#
# A "SQL hashref" is the column list, values list, index name, and WHERE clause, with ?
# placeholders where needed.
#
# Arguments are as follows:
# * tbl           Hashref as provided by TableParser.
# * cols          Arrayref of columns to SELECT from the table.
# * index         Which index to ascend; defaults to PRIMARY.
# * ascendfirst   Ascend the first column of the given index.
# * quoter        a Quoter object
# * asconly       Whether to ascend strictly, that is, the WHERE clause for
#                 the asc_stmt will fetch the next row > the given arguments.
#                 The option is to fetch the row >=, which could loop
#                 infinitely.  Default is false.
sub generate_asc_stmt {
   my ( $self, %opts ) = @_;

   my $tbl  = $opts{tbl};
   my @cols = @{$opts{cols}};
   my $idx  = (!$opts{index} || uc $opts{index} eq 'PRIMARY') ? 'PRIMARY' : $opts{index};
   my $q    = $opts{quoter};

   my ($idx, @asc_cols, @asc_slice);

   # ##########################################################################
   # Detect indexes and columns needed.
   # ##########################################################################
   # Make sure the lettercase is right and verify that the index exists.
   if ( $idx ne 'PRIMARY' ) {
      ($idx) = grep { uc $_ eq uc $idx } keys %{$tbl->{keys}};
   }
   if ( !$tbl->{keys}->{$idx} ) {
      die "Index '$idx' does not exist in table";
   }

   # These are the columns we'll ascend.
   @asc_cols = @{$tbl->{keys}->{$idx}->{cols}};
   if ( $opts{ascendfirst} ) {
      @asc_cols = $asc_cols[0];
   }

   # We found the columns by name, now find their positions for use as
   # array slices, and make sure they are included in the SELECT list.
   my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
   foreach my $col ( @asc_cols ) {
      if ( !exists $col_posn{$col} ) {
         push @cols, $col;
         $col_posn{$col} = $#cols;
      }
      push @asc_slice, $col_posn{$col};
   }

   my $asc_stmt = {
      cols  => \@cols,
      idx   => $idx,
      where => '',
      slice => [],
      scols => [],
   };

   # ##########################################################################
   # Figure out how to ascend the index.
   # ##########################################################################
   if ( @asc_slice ) {
      my @clauses;
      foreach my $i ( 0 .. $#asc_slice ) {
         my @clause;
         foreach my $j ( 0 .. $i - 1 ) {
            my $ord = $asc_slice[$j];
            my $col = $cols[$ord];
            my $quo = $q->quote($col);
            if ( $tbl->{is_nullable}->{$col} ) {
               push @clause, 
                  "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
               push @{$asc_stmt->{slice}}, $ord, $ord;
               push @{$asc_stmt->{scols}}, $col, $col;
            }
            else {
               push @clause, "$quo = ?";
               push @{$asc_stmt->{slice}}, $ord;
               push @{$asc_stmt->{scols}}, $col;
            }
         }
         # The last clause should be >=, all others strictly >, unless we are
         # ascending strictly, in which case everything must be strictly > and
         # there is a chance some rows can be skipped in non-unique indexes.
         my $ord = $asc_slice[$i];
         my $col = $cols[$ord];
         my $quo = $q->quote($col);
         if ( $tbl->{is_nullable}->{$col} ) {
            # TODO
         }
         else {
            push @{$asc_stmt->{slice}}, $ord;
            push @{$asc_stmt->{scols}}, $col;
            push @clause, $q->quote($col) . ($opts{asconly} ? ' > ?' : ' >= ?');
            push @clauses, '(' . join(' AND ', @clause) . ')';
         }
      }
      $asc_stmt->{where} = '(' . join(' OR ', @clauses) . ')';
   }
}

1;

__DATA__

   # ##########################################################################
   # Figure out how to delete rows. DELETE requires a PK, a unique non-NULL
   # index, or all columns.
   # ##########################################################################
   $del_stmt = {
      where => '',
      slice => [],
      cols  => [],
   };

=pod
   if ( $tbl->{keys}->{PRIMARY} ) {
      @pk_slice = map {
         $src->{info}->{col_posn}->{$_}
      } @{$src->{info}->{keys}->{PRIMARY}->{cols}};
      die "Can't find ordinal position of all columns"
         if grep { !defined($_) } @pk_slice;
   }
   else {
      # At this time, issues with NULLs (=null vs. IS NULL) will prevent DELETEs
      # from working right without a PRIMARY key.
      die "The source table does not have a primary key.  Cannot continue.\n";
      @pk_slice = (0 .. $#cols);
   }

   $del_sql = 'DELETE'
      . ($opts{lpdel}    ? ' LOW_PRIORITY' : '')
      . ($opts{quickdel} ? ' QUICK'        : '')
      . " FROM $src->{db_tbl} WHERE "
      . join(' AND ', map { "`$cols[$_]` = ?" } @pk_slice)
      . " LIMIT 1";

   # INSERT is all columns.  I can't think of why you'd want to archive to a
   # table with different columns than the source.
   if ( $dst ) {
      $ins_sql = ($opts{r}          ? 'REPLACE'       : 'INSERT')
               . ($opts{lpins}      ? ' LOW_PRIORITY' : '')
               . ($opts{delayedins} ? ' DELAYED'      : '')
               . ($opts{i}          ? ' IGNORE'       : '');
      $ins_sql .= " INTO $dst->{db_tbl}("
         . join(",", map { "`$_`" } @cols)
         . ") VALUES ("
         . join(",", map { "?" } @cols)
         . ")";
   }
   else {
      $ins_sql = '';
   }

   if ( $opts{t} ) {
      print join("\n", ($opts{f} || ''), $first_sql, $next_sql, $del_sql, $ins_sql), "\n";
      exit(0);
   }
=cut

   return {
      asc_stmt => $asc_stmt,
      del_stmt => $del_stmt,
   };

}

1;

# ###########################################################################
# End TableNibbler package
# ###########################################################################
