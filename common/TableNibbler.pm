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
# * pk_cols       The column names of the PK in first_sql & next_sql.
# * pk_slice      Ditto, column ordinals.
# * asc_cols      The column names of the columns we'll ascend.
# * asc_slice     Ditto, column ordinals.
# * next_cols     Column names to pass to next_sql
# * next_slice    Ditto, column ordinals.
# * index         The index to ascend.
#
# A "SQL hashref" is the column list, values list, and WHERE clause, with ?
# placeholders where needed.
#
# Arguments are as follows:
# * tbl           Hashref as provided by TableParser.
# * cols          Arrayref of columns to SELECT from the table.
# * index         Which index to ascend; defaults to PRIMARY.
# * ascendfirst   Ascend the first column of the given index.
sub generate_nibble {
   my ( $self, %opts ) = @_;

   my $tbl  = $opts{tbl};
   my @cols = @{$opts{cols}};
   my $idx  = (!$opts{index} || uc $opts{index} eq 'PRIMARY') ? 'PRIMARY' : $opts{index};

   my ($first_sql, $next_sql, $del_sql, $ins_sql);
   my (@asc_cols, @pk_slice, @asc_slice, @get_next_slice);

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
   @asc_cols = @{$src->{info}->{keys}->{$idx}->{cols}};
   if ( $opts{ascendfirst} ) {
      @asc_cols = $asc_cols[0];
   }

   # Check that each column is defined as NOT NULL.
   foreach my $col ( @asc_cols ) {
      if ( $tbl->{is_nullable}->{$col} ) {
         die "Column '$col' in index '$idx' is NULLable";
      }
   }

   # We found the columns by name, now find their positions for use as
   # array slices.
   @asc_slice = map { $src->{info}->{col_posn}->{$_} } @asc_cols;
   die "Can't find ordinal position of all columns"
      if grep { !defined($_) } @asc_slice;

   # ##########################################################################
   # Prepare SQL.
   # ##########################################################################
   $first_sql
      = 'SELECT'
      . ( $opts{hpselect}           ? ' HIGH_PRIORITY' : '' )
      . ' /*!40001 SQL_NO_CACHE */ '
      . join(',', map { $q->quote($_) } @cols)
      . " FROM $src->{db_tbl}"
      . ( $src->{i}
         ? (($vp->version_ge($dbh, '4.0.9') ? " FORCE" : " USE") . " INDEX(`$src->{i}`)")
         : '')
      . " WHERE ($opts{W})";

   # At this point the fetch-first and fetch-next queries may diverge.
   $next_sql = $first_sql;
   if ( @asc_slice ) {
      my @clauses;
      foreach my $i ( 0 .. $#asc_slice ) {
         my @clause;
         foreach my $j ( 0 .. $i - 1 ) {
            push @clause, "`$cols[$asc_slice[$j]]` = ?";
            push @get_next_slice, $asc_slice[$j];
         }
         # Only the very last clause should be >=, all others strictly > UNLESS
         # there is a chance the row will not be deleted, in which case everything
         # must be strictly > and there is a chance some rows can be skipped in
         # non-unique indexes.
         my $op = ($i == $#asc_slice && !$src->{m}) ? '>=' : '>';
         push @clause, "`$cols[$asc_slice[$i]]` $op ?";
         push @get_next_slice, $asc_slice[$i];
         push @clauses, '(' . join(' AND ', @clause) . ')';
      }
      $next_sql .= ' AND '
         . (@clauses > 1 ? '(' : '')
         . join(' OR ', @clauses)
         . (@clauses > 1 ? ')' : '');
   }

   $first_sql .= " LIMIT $opts{l}";
   $next_sql  .= " LIMIT $opts{l}";

   if ( $opts{forupdate} ) {
      $first_sql .= ' FOR UPDATE';
      $next_sql  .= ' FOR UPDATE';
   }
   elsif ( $opts{sharelock} ) {
      $first_sql .= ' LOCK IN SHARE MODE';
      $next_sql  .= ' LOCK IN SHARE MODE';
   }

   # DELETE requires either a PK or all columns.  In theory, a UNIQUE index could
   # be used, but I am not going to fool with that.
   if ( $src->{info}->{keys}->{PRIMARY} ) {
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

   # The LIMIT is *always* 1 here, because even though a SELECT can return many
   # rows, an INSERT only does one at a time.  It would not be safe to iterate
   # over a SELECT that was LIMIT-ed to 500 rows, read and INSERT one, and then
   # delete with a LIMIT of 500.  Only one row would be written to the file; only
   # one would be INSERT-ed at the destination.  Every DELETE must be LIMIT 1.
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

1;

# ###########################################################################
# End TableNibbler package
# ###########################################################################
