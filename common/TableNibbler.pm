# ###########################################################################
# TableNibbler package
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableNibbler;

sub new {
   bless {}, shift;
}

# Sorts indexes in this order: PRIMARY, unique, non-nullable, any (shortest
# first, alphabetical).  Only BTREE indexes are considered.  TODO: consider
# length as # of bytes instead of # of columns.
sub sort_indexes {
   my ( $self, $tbl ) = @_;
   my @indexes
      = sort {
         (($a ne 'PRIMARY') <=> ($b ne 'PRIMARY'))
         || ( !$tbl->{keys}->{$a}->{unique} <=> !$tbl->{keys}->{$b}->{unique} )
         || ( $tbl->{keys}->{$a}->{is_nullable} <=> $tbl->{keys}->{$b}->{is_nullable} )
         || ( scalar(@{$tbl->{keys}->{$a}->{cols}}) <=> scalar(@{$tbl->{keys}->{$b}->{cols}}) )
      }
      grep {
         $tbl->{keys}->{$_}->{type} eq 'BTREE'
      }
      sort keys %{$tbl->{keys}};
   return @indexes;
}

# Arguments are as follows:
# * tbl      Hashref as provided by TableParser.
# * cols     Arrayref of columns to SELECT from the table. Defaults to all.
# * index    Which index to ascend; optional.
# * ascfirst Ascend the first column of the given index.
# * quoter   a Quoter object
# * asconly  Whether to ascend strictly, that is, the WHERE clause for
#            the asc_stmt will fetch the next row > the given arguments.
#            The option is to fetch the row >=, which could loop
#            infinitely.  Default is false.
sub generate_asc_stmt {
   my ( $self, %opts ) = @_;

   my $tbl  = $opts{tbl};
   my @cols = $opts{cols} ? @{$opts{cols}} : @{$tbl->{cols}};
   my $idx  = (!$opts{index} || uc $opts{index} eq 'PRIMARY') ? 'PRIMARY' : $opts{index};
   my $q    = $opts{quoter};

   my @asc_cols;
   my @asc_slice;

   # ##########################################################################
   # Detect indexes and columns needed.
   # ##########################################################################
   # Make sure the lettercase is right and verify that the index exists.
   my $index = $idx;
   if ( $idx ne 'PRIMARY' ) {
      ($index) = grep { uc $_ eq uc $idx } keys %{$tbl->{keys}};
   }
   # TODO: needs tests.
   if ( !$index || !$tbl->{keys}->{$index} ) {
      if ( $idx ) {
         # The user specified an index, so we can't choose our own.
         die "Index '$idx' does not exist in table";
      }
      else {
         # Try to pick the best index.
         ($index) = $self->sort_indexes($tbl);
         if ( !$index ) {
            die "Cannot find an ascendable index in table";
         }
      }
   }

   # These are the columns we'll ascend.
   @asc_cols = @{$tbl->{keys}->{$index}->{cols}};
   if ( $opts{ascfirst} ) {
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
      index => $index,
      where => '',
      slice => [],
      scols => [],
   };

   # ##########################################################################
   # Figure out how to ascend the index by building a possibly complicated
   # WHERE clause that will define a range beginning with a row retrieved by
   # asc_stmt.  If asconly is given, the row's lower end should not include
   # the row.
   # Assuming a non-NULLable two-column index, the WHERE clause should look
   # like this:
   # WHERE (col1 > ?) OR (col1 = ? AND col2 >= ?)
   # Ascending-only and nullable require variations on this.  The general
   # pattern is (>), (= >), (= = >), (= = = >=).
   # ##########################################################################
   if ( @asc_slice ) {
      my @clauses;
      foreach my $i ( 0 .. $#asc_slice ) {
         my @clause;

         # Most of the clauses should be strict equality.
         foreach my $j ( 0 .. $i - 1 ) {
            my $ord = $asc_slice[$j];
            my $col = $cols[$ord];
            my $quo = $q->quote($col);
            if ( $tbl->{is_nullable}->{$col} ) {
               push @clause, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
               push @{$asc_stmt->{slice}}, $ord, $ord;
               push @{$asc_stmt->{scols}}, $col, $col;
            }
            else {
               push @clause, "$quo = ?";
               push @{$asc_stmt->{slice}}, $ord;
               push @{$asc_stmt->{scols}}, $col;
            }
         }

         # The last clause in each parenthesized group should be >, but the
         # very last of the whole WHERE clause should be >=, unless we are
         # ascending strictly, in which case everything must be strictly >.
         my $ord = $asc_slice[$i];
         my $col = $cols[$ord];
         my $quo = $q->quote($col);
         my $end = $i == $#asc_slice; # Last clause of the whole group.
         if ( $tbl->{is_nullable}->{$col} ) {
            if ( !$opts{asconly} && $end ) {
               push @clause, "(? IS NULL OR $quo >= ?)";
            }
            else {
               push @clause, "((? IS NULL AND $quo IS NOT NULL) OR ($quo > ?))";
            }
            push @{$asc_stmt->{slice}}, $ord, $ord;
            push @{$asc_stmt->{scols}}, $col, $col;
         }
         else {
            push @{$asc_stmt->{slice}}, $ord;
            push @{$asc_stmt->{scols}}, $col;
            push @clause, (!$opts{asconly} && $end ? "$quo >= ?" : "$quo > ?");
         }

         # Add the clause to the larger WHERE clause.
         push @clauses, '(' . join(' AND ', @clause) . ')';
      }
      $asc_stmt->{where} = '(' . join(' OR ', @clauses) . ')';
   }

   return $asc_stmt;
}

1;

# Figure out how to delete rows. DELETE requires a PK, a unique non-NULL
# index, or all columns.  For that reason you should call this before calling
# generate_asc_stmt(), so you know what columns you'll need to fetch from the
# table.
sub generate_del_stmt {
   my ( $self, %opts ) = @_;

   my $tbl  = $opts{tbl};
   my @cols = $opts{cols} ? @{$opts{cols}} : @{$tbl->{cols}};
   my $idx  = (!$opts{index} || uc $opts{index} eq 'PRIMARY') ? 'PRIMARY' : $opts{index};
   my $q    = $opts{quoter};

   # ##########################################################################
   # Detect the best or preferred index to use for the WHERE clause.
   # ##########################################################################
   # Make sure the lettercase is right and verify that the index exists.
   my $index = $idx;
   if ( $idx ne 'PRIMARY' ) {
      ($index) = grep { uc $_ eq uc $idx } keys %{$tbl->{keys}};
   }
   if ( !$index || !$tbl->{keys}->{$index} ) {
      # TODO
   }

   my $del_stmt = {
      cols  => \@cols,
      index => $index,
      where => '',
      slice => [],
      scols => [],
   };

   return $del_stmt;
}

1;

__DATA__

   # These are the columns we'll ascend.
   @asc_cols = @{$tbl->{keys}->{$index}->{cols}};
   if ( $opts{ascfirst} ) {
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

   # ##########################################################################
   # Figure out how to ascend the index by building a possibly complicated
   # WHERE clause that will define a range beginning with a row retrieved by
   # asc_stmt.  If asconly is given, the row's lower end should not include
   # the row.
   # Assuming a non-NULLable two-column index, the WHERE clause should look
   # like this:
   # WHERE (col1 > ?) OR (col1 = ? AND col2 >= ?)
   # Ascending-only and nullable require variations on this.  The general
   # pattern is (>), (= >), (= = >), (= = = >=).
   # ##########################################################################
   if ( @asc_slice ) {
      my @clauses;
      foreach my $i ( 0 .. $#asc_slice ) {
         my @clause;

         # Most of the clauses should be strict equality.
         foreach my $j ( 0 .. $i - 1 ) {
            my $ord = $asc_slice[$j];
            my $col = $cols[$ord];
            my $quo = $q->quote($col);
            if ( $tbl->{is_nullable}->{$col} ) {
               push @clause, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
               push @{$asc_stmt->{slice}}, $ord, $ord;
               push @{$asc_stmt->{scols}}, $col, $col;
            }
            else {
               push @clause, "$quo = ?";
               push @{$asc_stmt->{slice}}, $ord;
               push @{$asc_stmt->{scols}}, $col;
            }
         }

         # The last clause in each parenthesized group should be >, but the
         # very last of the whole WHERE clause should be >=, unless we are
         # ascending strictly, in which case everything must be strictly >.
         my $ord = $asc_slice[$i];
         my $col = $cols[$ord];
         my $quo = $q->quote($col);
         my $end = $i == $#asc_slice; # Last clause of the whole group.
         if ( $tbl->{is_nullable}->{$col} ) {
            if ( !$opts{asconly} && $end ) {
               push @clause, "(? IS NULL OR $quo >= ?)";
            }
            else {
               push @clause, "((? IS NULL AND $quo IS NOT NULL) OR ($quo > ?))";
            }
            push @{$asc_stmt->{slice}}, $ord, $ord;
            push @{$asc_stmt->{scols}}, $col, $col;
         }
         else {
            push @{$asc_stmt->{slice}}, $ord;
            push @{$asc_stmt->{scols}}, $col;
            push @clause, (!$opts{asconly} && $end ? "$quo >= ?" : "$quo > ?");
         }

         # Add the clause to the larger WHERE clause.
         push @clauses, '(' . join(' AND ', @clause) . ')';
      }
      $asc_stmt->{where} = '(' . join(' OR ', @clauses) . ')';
   }

   return $asc_stmt;
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
