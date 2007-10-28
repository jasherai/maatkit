# ###########################################################################
# TableNibbler package $Revision$
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

sub find_best_index {
   my ( $self, $tbl, $index ) = @_;
   my $best;
   if ( $index ) {
      ($best) = grep { uc $_ eq uc $index } keys %{$tbl->{keys}};
   }
   if ( !$best ) {
      if ( $index ) {
         # The user specified an index, so we can't choose our own.
         die "Index '$index' does not exist in table";
      }
      else {
         # Try to pick the best index.
         ($best) = $self->sort_indexes($tbl);
         if ( !$best ) {
            die "Cannot find an ascendable index in table";
         }
      }
   }
   return $best;
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
#
# Returns a hashref of
# * cols:  columns in the select stmt, with required extras appended
# * index: index chosen to ascend
# * where: WHERE clause
# * slice: col ordinals to pull from a row that will satisfy ? placeholders
# * scols: ditto, but column names instead of ordinals
#
# In other words,
# $first = $dbh->prepare <....>;
# $next  = $dbh->prepare <....>;
# $row = $first->fetchrow_arrayref();
# $row = $next->fetchrow_arrayref(@{$row}[@slice]);
sub generate_asc_stmt {
   my ( $self, %opts ) = @_;

   my $tbl  = $opts{tbl};
   my @cols = $opts{cols} ? @{$opts{cols}} : @{$tbl->{cols}};
   my $q    = $opts{quoter};

   my @asc_cols;
   my @asc_slice;

   # ##########################################################################
   # Detect indexes and columns needed.
   # ##########################################################################
   my $index = $self->find_best_index($tbl, $opts{index});

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

# Figure out how to delete rows. DELETE requires either an index or all
# columns.  For that reason you should call this before calling
# generate_asc_stmt(), so you know what columns you'll need to fetch from the
# table.  Arguments:
# * tbl * cols * quoter * index
# These are the same as the arguments to generate_asc_stmt().  Return value is
# similar too.
sub generate_del_stmt {
   my ( $self, %opts ) = @_;

   my $tbl  = $opts{tbl};
   my @cols = $opts{cols} ? @{$opts{cols}} : ();
   my $q    = $opts{quoter};

   my @del_cols;
   my @del_slice;

   # ##########################################################################
   # Detect the best or preferred index to use for the WHERE clause needed to
   # delete the rows.
   # ##########################################################################
   my $index = $self->find_best_index($tbl, $opts{index});

   # These are the columns needed for the DELETE statement's WHERE clause.
   if ( $index ) {
      @del_cols = @{$tbl->{keys}->{$index}->{cols}};
   }
   else {
      @del_cols = @{$tbl->{cols}};
   }

   # We found the columns by name, now find their positions for use as
   # array slices, and make sure they are included in the SELECT list.
   my %col_posn = do { my $i = 0; map { $_ => $i++ } @cols };
   foreach my $col ( @del_cols ) {
      if ( !exists $col_posn{$col} ) {
         push @cols, $col;
         $col_posn{$col} = $#cols;
      }
      push @del_slice, $col_posn{$col};
   }

   my $del_stmt = {
      cols  => \@cols,
      index => $index,
      where => '',
      slice => [],
      scols => [],
   };

   # ##########################################################################
   # Figure out how to target a single row with a WHERE clause.
   # ##########################################################################
   my @clauses;
   foreach my $i ( 0 .. $#del_slice ) {
      my $ord = $del_slice[$i];
      my $col = $cols[$ord];
      my $quo = $q->quote($col);
      if ( $tbl->{is_nullable}->{$col} ) {
         push @clauses, "((? IS NULL AND $quo IS NULL) OR ($quo = ?))";
         push @{$del_stmt->{slice}}, $ord, $ord;
         push @{$del_stmt->{scols}}, $col, $col;
      }
      else {
         push @clauses, "$quo = ?";
         push @{$del_stmt->{slice}}, $ord;
         push @{$del_stmt->{scols}}, $col;
      }
   }

   $del_stmt->{where} = '(' . join(' AND ', @clauses) . ')';

   return $del_stmt;
}

# Design an INSERT statement.  This actually does very little; it just maps
# the columns you know you'll get from the SELECT statement onto the columns
# in the INSERT statement, returning only those that exist in both sets.
# Arguments:
# * tbl * cols
# These are the same as the arguments to generate_asc_stmt().  Return value is
# similar too, but you only get back cols and slice.
sub generate_ins_stmt {
   my ( $self, %opts ) = @_;

   my $tbl  = $opts{tbl};
   my @cols = @{$opts{cols}};

   die "You didn't specify any columns" unless @cols;

   # Find column positions for use as array slices.
   my %col_posn = do { my $i = 0; map { $_ => $i++ } @{$tbl->{cols}} };
   my @ins_cols;
   my @ins_slice;

   foreach my $col ( @cols ) {
      if ( exists $col_posn{$col} ) {
         push @ins_cols, $col;
         push @ins_slice, $col_posn{$col};
      }
   }

   my $ins_stmt = {
      cols  => \@ins_cols,
      slice => \@ins_slice,
   };

   return $ins_stmt;
}

1;

# ###########################################################################
# End TableNibbler package
# ###########################################################################
