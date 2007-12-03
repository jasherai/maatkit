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
      if ( $EVAL_ERROR =~ m/TODO/ ) { # TODO
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

sub process_rows {
   my ( $self ) = @_;
   map { $self->take_action($_) }
      (map { $self->make_DELETE(@$_) } @{$self->{DELETE}}),
      (map { $self->make_UPDATE(@$_) } @{$self->{UPDATE}}),
      (map { $self->make_INSERT(@$_) } @{$self->{INSERT}});
}

sub make_DELETE {
   my ( $self, $row, $cols ) = @_;
   return "DELETE FROM $self->{db_tbl} WHERE "
      . $self->make_where_clause($row, $cols)
      . ' LIMIT 1';
}

sub make_UPDATE {
   my ( $self, $row, $cols ) = @_;
   my %in_where = map { $_ => 1 } @$cols;
   return "UPDATE $self->{db_tbl} SET "
      . join(', ', map {
            $self->{quoter}->quote($_)
            . '=' .  $self->{quoter}->quote_val($row->{$_})
         } grep { !$in_where{$_} } sort keys %$row)
      . ' WHERE ' . $self->make_where_clause($row, $cols) . ' LIMIT 1';
}

sub make_INSERT {
   my ( $self, $row, $cols ) = @_;
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
