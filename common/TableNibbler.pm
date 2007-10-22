# ###########################################################################
# TableNibbler package
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableNibbler;

sub new {
   bless {}, shift;
}

   my ($first_sql, $next_sql, $del_sql, $ins_sql);

   # These are lists of columns by ordinal position, not by name.  This is
   # necessary because the rows are fetched from the DB as arrays, not as hashes,
   # for efficiency, but for various statements I want one or the other subset of
   # columns.  @pk_slice is the slice that will extract the primary key columns
   # for DELETEs.  @asc_slice is only used to generate queries; it is the column
   # ordinals of the index the get_next query will ascend.  @get_next_slice
   # is the column ordinals in the order in which they appear in the get_next
   # query's WHERE clause.

   my (@pk_slice, @asc_slice, @get_next_slice);

   my @cols = $opts{c} ? split(/,/, $opts{c})                       # Explicitly specified columns
            : $opts{k} ? @{$src->{info}->{keys}->{PRIMARY}->{cols}} # PK only
            :            @{$src->{info}->{cols}};                   # All columns

   # Do we have an index to ascend?  Use PRIMARY if nothing specified.
   if ( $opts{N} && ($src->{i} || $src->{info}->{keys}->{PRIMARY}) ) {
      # Make sure the lettercase is right and find the index...
      my $ixname = $src->{i} || '';
      if ( uc $ixname eq 'PRIMARY' || !$src->{i} ) {
         $ixname = 'PRIMARY';
      }
      else {
         ($ixname) = grep { uc $_ eq uc $src->{i} } keys %{$src->{info}->{keys}};
      }

      if ( $ixname ) {
         $src->{i} = $ixname; # Corrects lettercase if it's wrong
         my @asc_cols = @{$src->{info}->{keys}->{$ixname}->{cols}};

         if ( @asc_cols ) {
            if ( $opts{ascendfirst} ) {
               @asc_cols = $asc_cols[0];
            }

            # Check that each column is defined as NOT NULL.
            foreach my $col ( @asc_cols ) {
               if ( $src->{info}->{is_nullable}->{$col} ) {
                  die "Column '$col' in index '$ixname' is NULLable.\n";
               }
            }

            # We found the columns by name, now find their positions for use as
            # array slices.
            @asc_slice = map { $src->{info}->{col_posn}->{$_} } @asc_cols;
            die "Can't find ordinal position of all columns"
               if grep { !defined($_) } @asc_slice;
         }

      }
      else {
         die "The specified index could not be found, or there is no PRIMARY key.\n";
      }
   }

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

