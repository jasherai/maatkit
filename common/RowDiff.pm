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
# RowDiff package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package RowDiff;

use English qw(-no_match_vars);

sub new {
   my ( $class, %args ) = @_;
   die "I need a dbh" unless $args{dbh};
   my $self = \%args;
   return bless $self, $class;
}

# Iterates through two sets of rows and finds differences.  Calls various
# methods on the $syncer object when it finds differences.  $left and $right
# should be DBI $sth, or should at least behave like them.  $tbl
# is a struct from TableParser.
sub compare_sets {
   my ( $self, %args ) = @_;
   my ( $left, $right, $syncer, $tbl )
      = @args{qw(left right syncer tbl)};

   my ($lr, $rr);       # Current row from the left/right sources.

   do {

      if ( !$lr && $left->{Active} ) {
         $ENV{MKDEBUG} && _d('Fetching row from left');
         $lr = $left->fetchrow_hashref;
      }
      if ( !$rr && $right->{Active} ) {
         $ENV{MKDEBUG} && _d('Fetching row from right');
         $rr = $right->fetchrow_hashref;
      }

      my $cmp;
      if ( $lr && $rr ) {
         $cmp = $self->key_cmp($lr, $rr, $syncer->key_cols(), $tbl);
         $ENV{MKDEBUG} && _d('Key comparison on left and right: '
            . (defined $cmp ? $cmp : 'undef'));
      }
      if ( $lr || $rr ) {
         # If the current row is the "same row" on both sides, meaning the two
         # rows have the same key, check the contents of the row to see if
         # they're the same.
         if ( $lr && $rr && defined $cmp && $cmp == 0 ) {
            $ENV{MKDEBUG} && _d('Left and right have the same key');
            $syncer->same_row($lr, $rr);
            $lr = $rr = undef; # Fetch another row from each side.
         }
         # The row in the left doesn't exist in the right.
         elsif ( !$rr || ( defined $cmp && $cmp < 0 ) ) {
            $ENV{MKDEBUG} && _d('Left is not in right');
            $syncer->not_in_right($lr);
            $lr = undef;
         }
         # Symmetric to the above.
         else {
            $ENV{MKDEBUG} && _d('Right is not in left');
            $syncer->not_in_left($rr);
            $rr = undef;
         }
      }
   } while ( $left->{Active} || $right->{Active} );
   $ENV{MKDEBUG} && _d('No more rows');
   $syncer->done_with_rows();
}

# Compare two rows to determine how they should be ordered.  NULL sorts before
# defined values in MySQL, so I consider undef "less than." Numbers are easy to
# compare.  Otherwise string comparison is tricky.  This function must match
# MySQL exactly or the merge algorithm runs off the rails, so when in doubt I
# ask MySQL to compare strings for me.  I can handle numbers and "normal" latin1
# characters without asking MySQL.  See
# http://dev.mysql.com/doc/refman/5.0/en/charset-literal.html.  $r1 and $r2 are
# row hashrefs.  $key_cols is an arrayref of the key columns to compare.  $tbl is the
# structure returned by TableParser.  The result matches Perl's cmp or <=>
# operators:
# 1 cmp 0 =>  1
# 1 cmp 1 =>  0
# 1 cmp 2 => -1
sub key_cmp {
   my ( $self, $lr, $rr, $key_cols, $tbl ) = @_;
   $ENV{MKDEBUG} && _d("Comparing keys using columns " . join(',', @$key_cols));
   foreach my $col ( @$key_cols ) {
      my $l = $lr->{$col};
      my $r = $rr->{$col};
      if ( !defined $l || !defined $r ) {
         $ENV{MKDEBUG} && _d("$col is not defined in both rows");
         return defined $l || -1;
      }
      else {
         if ($tbl->{is_numeric}->{$col} ) {   # Numeric column
            $ENV{MKDEBUG} && _d("$col is numeric");
            my $cmp = $l <=> $r;
            return $cmp unless $cmp == 0;
         }
         # Do case-sensitive cmp, expecting most will be eq.  If that fails, try
         # a case-insensitive cmp if possible; otherwise ask MySQL how to sort.
         elsif ( $l ne $r ) {
            my $cmp;
            my $coll = $tbl->{collation_for}->{$col};
            if ( $coll && ( $coll ne 'latin1_swedish_ci'
                           || $l =~ m/[^\040-\177]/ || $r =~ m/[^\040-\177]/) ) {
               $ENV{MKDEBUG} && _d("Comparing $col via MySQL");
               $cmp = $self->db_cmp($coll, $l, $r);
            }
            else {
               $ENV{MKDEBUG} && _d("Comparing $col in lowercase");
               $cmp = lc $l cmp lc $r;
            }
            return $cmp unless $cmp == 0;
         }
      }
   }
   return 0;
}

sub db_cmp {
   my ( $self, $collation, $l, $r ) = @_;
   if ( !$self->{sth}->{$collation} ) {
      if ( !$self->{charset_for} ) {
         $ENV{MKDEBUG} && _d("Fetching collations from MySQL");
         my @collations = @{$self->{dbh}->selectall_arrayref(
            'SHOW COLLATION', {Slice => { collation => 1, charset => 1 }})};
         foreach my $collation ( @collations ) {
            $self->{charset_for}->{$collation->{collation}}
               = $collation->{charset};
         }
      }
      my $sql = "SELECT STRCMP(_$self->{charset_for}->{$collation}? COLLATE $collation, "
         . "_$self->{charset_for}->{$collation}? COLLATE $collation) AS res";
      $ENV{MKDEBUG} && _d($sql);
      $self->{sth}->{$collation} = $self->{dbh}->prepare($sql);
   }
   my $sth = $self->{sth}->{$collation};
   $sth->execute($l, $r);
   return $sth->fetchall_arrayref()->[0]->[0];
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# RowDiff:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End RowDiff package
# ###########################################################################
