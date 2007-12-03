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
# ChangeHandler package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package ChangeHandler;

use English qw(-no_match_vars);

my $DEFER_PAT = qr/Duplicate entry|Commands out of sync/;

# Arguments:
# * quoter     Quoter()
# * database   database name
# * table      table name
# * actions    arrayref of subroutines to call when handling a change.
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(quoter database table) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my $self = { %args, map { $_ => [] } qw(DELETE INSERT UPDATE) };
   $self->{db_tbl} = $self->{quoter}->quote(@args{qw(database table)});
   $self->{queue}  = 0; # Do changes immediately if possible.
   return bless $self, $class;
}

# If I'm supposed to fetch-back, that means I have to get the full row from the
# database.  For example, someone might call me like so:
# $me->change('UPDATE', { a => 1 })
# but 'a' is only the primary key. I now need to select that row and make an
# UPDATE statement with all of its columns.  The argument is the DB handle used
# to fetch.
sub fetch_back {
   my ( $self, $dbh ) = @_;
   $self->{fetch_back} = $dbh;
}

sub take_action {
   my ( $self, $sql ) = @_;
   foreach my $action ( @{$self->{actions}} ) {
      $action->($sql);
   }
}

sub change {
   my ( $self, $action, $row, $cols ) = @_;
   if ( !$self->{queue} ) {
      eval {
         my $func = "make_$action";
         my $sql  = $self->$func($row, $cols);
         $self->take_action($sql);
      };
      if ( $EVAL_ERROR =~ m/$DEFER_PAT/ ) {
         push @{$self->{$action}}, [ $row, $cols ];
         $self->{queue}++; # Defer further rows
      }
      elsif ( $EVAL_ERROR ) {
         die $EVAL_ERROR;
      }
   }
   else {
      push @{$self->{$action}}, [ $row, $cols ];
   }
}

# If called with 1, will process rows that have been deferred from instant
# processing.  If no arg, will process all rows.
sub process_rows {
   my ( $self, $queue_level ) = @_;
   return if $queue_level && $queue_level < $self->{queue};
   my ($row, $cur_act);
   eval {
      foreach my $action ( qw(DELETE UPDATE INSERT) ) {
         my $func = "make_$action";
         my $rows = $self->{$action};
         $cur_act = $action;
         while ( @$rows ) {
            $row = shift @$rows;
            my $sql = $self->$func(@$row);
            $self->take_action($sql);
         }
      }
   };
   if ( $EVAL_ERROR =~ m/$DEFER_PAT/ ) {
      unshift @{$self->{$cur_act}}, $row;
      $self->{queue}++; # Defer rows to the very end
   }
   elsif ( $EVAL_ERROR ) {
      die $EVAL_ERROR;
   }
}

# DELETE never needs to be fetched back.
sub make_DELETE {
   my ( $self, $row, $cols ) = @_;
   return "DELETE FROM $self->{db_tbl} WHERE "
      . $self->make_where_clause($row, $cols)
      . ' LIMIT 1';
}

sub make_UPDATE {
   my ( $self, $row, $cols ) = @_;
   my %in_where = map { $_ => 1 } @$cols;
   my $where = $self->make_where_clause($row, $cols);
   if ( my $dbh = $self->{fetch_back} ) {
      my $res = $dbh->selectrow_hashref(
         "SELECT * FROM $self->{db_tbl} WHERE $where LIMIT 1");
      @{$row}{keys %$res} = values %$res;
      $cols = [sort keys %$res];
   }
   else {
      $cols = [ sort keys %$row ];
   }
   return "UPDATE $self->{db_tbl} SET "
      . join(', ', map {
            $self->{quoter}->quote($_)
            . '=' .  $self->{quoter}->quote_val($row->{$_})
         } grep { !$in_where{$_} } @$cols)
      . " WHERE $where LIMIT 1";
}

sub make_INSERT {
   my ( $self, $row, $cols ) = @_;
   if ( my $dbh = $self->{fetch_back} ) {
      my $where = $self->make_where_clause($row, $cols);
      my $res = $dbh->selectrow_hashref(
         "SELECT * FROM $self->{db_tbl} WHERE $where LIMIT 1");
      @{$row}{keys %$res} = values %$res;
   }
   my @cols = sort keys %$row;
   return "INSERT INTO $self->{db_tbl}("
      . join(', ', map { $self->{quoter}->quote($_) } @cols)
      . ') VALUES ('
      . $self->{quoter}->quote_val( @{$row}{@cols} )
      . ')';
}

sub make_where_clause {
   my ( $self, $row, $cols ) = @_;
   my @clauses = map {
      my $val = $row->{$_};
      my $sep = defined $val ? '=' : ' IS ';
      $self->{quoter}->quote($_) . $sep . $self->{quoter}->quote_val($val);
   } @$cols;
   return join(' AND ', @clauses);
}

=pod
sub handle_data_change {
   my ( $self, $action, $where) = @_;
   my $dbh   = $which->{dbh};
   my $crit  = make_where_clause($dbh, $where);

   if ( $action eq 'DELETE' ) {
      my $query = "DELETE FROM $which->{db_tbl} $crit";
      if ( $opts{p} ) {
         print STDOUT $query, ";\n";
      }
      if ( $opts{x} ) {
         $dbh->do($query);
      }
   }

   else {
      my $query = "SELECT $source->{cols} FROM $source->{db_tbl} $crit";
      debug_print($query);
      my $sth = $source->{dbh}->prepare($query);
      $sth->execute();
      while ( my $res = $sth->fetchrow_hashref() ) {
         if ( $opts{s} eq 'r' || $action eq 'INSERT' ) {
            my $verb = $opts{s} eq 'r' ? 'REPLACE' : 'INSERT';
            $query = "$verb INTO $which->{db_tbl}($which->{cols}) VALUES("
               . join(',', map { $dbh->quote($res->{$_}) }
                  @{$which->{info}->{cols}}) . ")";
         }
         else {
            my @cols = grep { !exists($where->{$_}) } @{$which->{info}->{cols}};
            $query = "UPDATE $which->{db_tbl} SET "
               . join(',',
                  map { $q->quote($_) . '=' .  $dbh->quote($res->{$_}) } @cols)
               . ' ' . $crit;
         }
         if ( $opts{p} ) {
            print STDOUT $query, ";\n";
         }
         if ( $opts{x} ) {
            eval { $dbh->do($query) };
            if ( $EVAL_ERROR ) {
               if ( $EVAL_ERROR =~ m/Duplicate entry/ ) {
                  die "Your tables probably have some differences "
                     . "that cannot be resolved with UPDATE statements.  "
                     . "Re-run mk-table-sync with --deleteinsert to proceed.\n";
               }
               else {
                  die $EVAL_ERROR;
               }
            }
         }
      }
   }
}
=cut

1;

# ###########################################################################
# End ChangeHandler package
# ###########################################################################
