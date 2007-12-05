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
# TableNibbler package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableNibbler;

sub new {
   bless {}, shift;
}

# Arguments are as follows:
# * parser   TableParser
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
   my ( $self, %args ) = @_;

   my $tbl  = $args{tbl};
   my @cols = $args{cols} ? @{$args{cols}} : @{$tbl->{cols}};
   my $q    = $args{quoter};

   my @asc_cols;
   my @asc_slice;

   # ##########################################################################
   # Detect indexes and columns needed.
   # ##########################################################################
   my $index = $args{parser}->find_best_index($tbl, $args{index});
   die "Cannot find an ascendable index in table" unless $index;

   # These are the columns we'll ascend.
   @asc_cols = @{$tbl->{keys}->{$index}->{cols}};
   $ENV{MKDEBUG} && _d("Will ascend index $index");
   $ENV{MKDEBUG} && _d("Will ascend columns " . join(', ', @asc_cols));
   if ( $args{ascfirst} ) {
      @asc_cols = $asc_cols[0];
      $ENV{MKDEBUG} && _d("Ascending only first column");
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
   $ENV{MKDEBUG}
      && _d('Will ascend, in ordinal position: ' . join(', ', @asc_slice));

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
            if ( !$args{asconly} && $end ) {
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
            push @clause, (!$args{asconly} && $end ? "$quo >= ?" : "$quo > ?");
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
# * parser * tbl * cols * quoter * index
# These are the same as the arguments to generate_asc_stmt().  Return value is
# similar too.
sub generate_del_stmt {
   my ( $self, %args ) = @_;

   my $tbl  = $args{tbl};
   my @cols = $args{cols} ? @{$args{cols}} : ();
   my $q    = $args{quoter};

   my @del_cols;
   my @del_slice;

   # ##########################################################################
   # Detect the best or preferred index to use for the WHERE clause needed to
   # delete the rows.
   # ##########################################################################
   my $index = $args{parser}->find_best_index($tbl, $args{index});
   die "Cannot find an ascendable index in table" unless $index;

   # These are the columns needed for the DELETE statement's WHERE clause.
   if ( $index ) {
      @del_cols = @{$tbl->{keys}->{$index}->{cols}};
   }
   else {
      @del_cols = @{$tbl->{cols}};
   }
   $ENV{MKDEBUG} && _d('Columns needed for DELETE: ' . join(', ', @del_cols));

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
   $ENV{MKDEBUG} && _d('Ordinals needed for DELETE: ' . join(', ', @del_slice));

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
   my ( $self, %args ) = @_;

   my $tbl  = $args{tbl};
   my @cols = @{$args{cols}};

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

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# TableNibbler:$line ", @_, "\n";
}

1;

# ###########################################################################
# End TableNibbler package
# ###########################################################################
