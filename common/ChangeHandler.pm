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

# Arguments:
# * quoter     Quoter()
# * database   database name
# * table      table name
# * queue      whether to queue rows for later, or print/execute on the fly.
#              Default is to queue until dump_rows() or dump_sql() is called.
# TODO: implement non-queued stuff.
# * actions    arrayref of subroutines to call when handling a change.
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(quoter database table) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   $args{queue} = 1 unless defined $args{queue};
   my $self = { %args, map { $_ => [] } qw(del upd ins) };
   $self->{db_tbl} = $self->{quoter}->quote(@args{qw(database table)});
   return bless $self, $class;
}

sub del {
   my ( $self, $row, $cols ) = @_;
   if ( $self->{queue} ) {
      push @{$self->{del}}, [ $row, $cols ];
   }
}

sub ins {
   my ( $self, $row, $cols ) = @_;
   if ( $self->{queue} ) {
      push @{$self->{ins}}, [ $row, $cols ];
   }
}

sub upd {
   my ( $self, $row, $cols ) = @_;
   if ( $self->{queue} ) {
      push @{$self->{upd}}, [ $row, $cols ];
   }
}

sub process_rows {
   my ( $self ) = @_;
   foreach my $row (
      (map { $self->make_del(@$_) } @{$self->{del}}),
      (map { $self->make_upd(@$_) } @{$self->{upd}}),
      (map { $self->make_ins(@$_) } @{$self->{ins}}),
   ) {
      foreach my $action ( @{$self->{actions}} ) {
         $action->($row);
      }
   }
}

sub make_del {
   my ( $self, $row, $cols ) = @_;
   return "DELETE FROM $self->{db_tbl} WHERE "
      . $self->make_where_clause($row, $cols)
      . ' LIMIT 1';
}

sub make_upd {
   my ( $self, $row, $cols ) = @_;
   my %in_where = map { $_ => 1 } @$cols;
   return "UPDATE $self->{db_tbl} SET "
      . join(', ', map {
            $self->{quoter}->quote($_)
            . '=' .  $self->{quoter}->quote_val($row->{$_})
         } grep { !$in_where{$_} } sort keys %$row)
      . ' WHERE ' . $self->make_where_clause($row, $cols) . ' LIMIT 1';
}

sub make_ins {
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

1;

# ###########################################################################
# End ChangeHandler package
# ###########################################################################
