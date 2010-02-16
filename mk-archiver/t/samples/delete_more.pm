# This program is copyright 2010 Percona Inc.
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

package delete_more;

# This mk-archiver plugin demonstrates how to archive/DELETE rows on one
# table--the main table--and also DELETE related rows on other tables.
# The picture is:
#
#   main table:  other table 1:  other table 1:
#     pk 1         opk 1            opk 1
#     pk 2         opk 2            opk 2
#
# When rows on main table are deleted, corresponding rows on the other
# tables are deleted where main table pk = other table opk.  This works
# for both single and --bulk-delete.
#
# Limitations:
#   * all tables must be on the same server
#   * other table column (e.g. opk) must be the same on all other tables
#   * main table column and other table columns must be numeric
#   * no NULL values

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG  => $ENV{MKDEBUG};

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

# ###########################################################################
# Customize these values for your tables.
# ###########################################################################
my $main_table_col  = 'id';
my $other_table_col = 'id';

# Use full db.table names.
my @other_tables = qw(
   dm.other_table_1
   dm.other_table_2
);

# ###########################################################################
# Don't modify anything below here.
# ###########################################################################
sub new {
   my ( $class, %args ) = @_;
   my $o = $args{OptionParser};
   my $self = {
      dbh          => $args{dbh},
      bulk_delete  => $o->get('bulk-delete'),
      limit        => $o->get('limit'),
      delete_rows  => [],  # saved main table col vals for --bulk-delete
      main_col_pos => -1,
   };
   return bless $self, $class;
}

sub before_begin {
   my ( $self, %args ) = @_;
   my $allcols = $args{allcols};
   MKDEBUG && _d('allcols:', Dumper($allcols));
   my $colpos = -1;
   foreach my $col ( @$allcols ) {
      $colpos++;
      last if $col eq $main_table_col;
   }
   if ( $colpos < 0 ) {
      die "Main table column $main_table_col not selected by mk-archiver: "
         . join(', ', @$allcols);
   }
   MKDEBUG && _d('main col pos:', $colpos);
   $self->{main_col_pos} = $colpos;
   return;
}

sub is_archivable {
   my ( $self, %args ) = @_;
   my $row = $args{row};
   push @{$self->{delete_rows}}, $row->[$self->{main_col_pos}]
      if $self->{bulk_delete};
   return 1;
}

sub before_delete {
   my ( $self, %args ) = @_;
   my $row = $args{row};
   my $val = $row->[ $self->{main_col_pos} ];
   my $dbh = $self->{dbh};

   foreach my $other_tbl ( @other_tables ) {
      my $sql = "DELETE FROM $other_tbl WHERE $other_table_col=$val LIMIT 1";
      MKDEBUG && _d($sql);
      eval {
         $dbh->do($sql);
      };
      if ( $EVAL_ERROR ) {
         MKDEBUG && _d($EVAL_ERROR);
         warn $EVAL_ERROR;
      }
   }
   return;
}

sub before_bulk_delete {
   my ( $self, %args ) = @_;

   if ( !scalar @{$self->{delete_rows}} ) {
      warn "before_bulk_delete() called without any rows to delete";
      return;
   }

   my $dbh              = $self->{dbh};
   my $delete_rows      = join(',', @{$self->{delete_rows}});
   $self->{delete_rows} = [];  # clear for next call

   foreach my $other_tbl ( @other_tables ) {
      my $sql = "DELETE FROM $other_tbl "
              . "WHERE $other_table_col IN ($delete_rows) "
              . "LIMIT $self->{limit}";
      MKDEBUG && _d($sql);
      eval {
         $dbh->do($sql);
      };
      if ( $EVAL_ERROR ) {
         MKDEBUG && _d($EVAL_ERROR);
         warn $EVAL_ERROR;
      }
   }
   return;
}

sub after_finish {
   my ( $self ) = @_;
   return;
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;
