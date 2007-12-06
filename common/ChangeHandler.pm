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

my $DEFER_PAT = qr/Commands out of sync/;
my $DUPE_KEY  = qr/Duplicate entry/;
our @ACTIONS  = qw(DELETE REPLACE INSERT UPDATE);

# Arguments:
# * quoter     Quoter()
# * database   database name
# * table      table name
# * sdatabase  source database name
# * stable     source table name
# * actions    arrayref of subroutines to call when handling a change.
# * replace    Do UPDATE/INSERT as REPLACE.
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(quoter database table sdatabase stable replace) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my $self = { %args, map { $_ => [] } @ACTIONS };
   $self->{db_tbl}  = $self->{quoter}->quote(@args{qw(database table)});
   $self->{sdb_tbl} = $self->{quoter}->quote(@args{qw(sdatabase stable)});
   $self->{queue}   = 0; # Do changes immediately if possible.
   $self->{changes} = { map { $_ => 0 } @ACTIONS };
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
   $ENV{MKDEBUG} && _d('Will fetch rows from source when updating destination');
}

sub take_action {
   my ( $self, @sql ) = @_;
   $ENV{MKDEBUG} && _d('Calling subroutines on ', @sql);
   foreach my $action ( @{$self->{actions}} ) {
      $action->(@sql);
   }
}

sub change {
   my ( $self, $action, $row, $cols ) = @_;
   $ENV{MKDEBUG} && _d("$action where ", $self->make_where_clause($row, $cols));
   $self->{changes}->{$self->{replace} && $action ne 'DELETE' ? 'REPLACE' : $action}++;
   if ( $self->{queue} ) {
      $self->__queue($action, $row, $cols);
   }
   else {
      eval {
         my $func = "make_$action";
         $self->take_action($self->$func($row, $cols));
      };
      if ( $EVAL_ERROR =~ m/$DEFER_PAT/ ) {
         $ENV{MKDEBUG} && _d('The DBH is busy; queueing further changes');
         $self->{queue}++; # Defer further rows
         $self->__queue($action, $row, $cols);
      }
      elsif ( $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
         $ENV{MKDEBUG} && _d('Duplicate key violation; queueing and rewriting');
         $self->{queue}++;
         $self->{replace} = 1;
         $self->__queue($action, $row, $cols);
      }
      elsif ( $EVAL_ERROR ) {
         die $EVAL_ERROR;
      }
   }
}

sub __queue {
   my ( $self, $action, $row, $cols ) = @_;
   $ENV{MKDEBUG} && _d('Queueing change for later');
   if ( $self->{replace} ) {
      $action = $action eq 'DELETE' ? $action : 'REPLACE';
   }
   push @{$self->{$action}}, [ $row, $cols ];
}

# If called with 1, will process rows that have been deferred from instant
# processing.  If no arg, will process all rows.
sub process_rows {
   my ( $self, $queue_level ) = @_;
   my $error_count = 0;
   TRY: {
      if ( $queue_level && $queue_level < $self->{queue} ) { # see redo below!
         $ENV{MKDEBUG} && _d("Not processing now $queue_level<$self->{queue}");
         return;
      }

      my ($row, $cur_act);
      eval {
         foreach my $action ( @ACTIONS ) {
            my $func = "make_$action";
            my $rows = $self->{$action};
            $ENV{MKDEBUG} && _d(scalar(@$rows) . " to $action");
            $cur_act = $action;
            while ( @$rows ) {
               $row = shift @$rows;
               $self->take_action($self->$func(@$row));
            }
         }
         $error_count = 0;
      };
      if ( $EVAL_ERROR =~ m/$DEFER_PAT/ ) {
         unshift @{$self->{$cur_act}}, $row;
         $ENV{MKDEBUG} && _d('The DBH is still busy; increasing queue level');
         $self->{queue}++; # Defer rows to the very end
      }
      elsif ( !$error_count++ && $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
         $ENV{MKDEBUG} && _d('Duplicate key violation; re-queueing and rewriting');
         $self->{queue}++; # Defer rows to the very end
         $self->{replace} = 1;
         $self->__queue($cur_act, @$row);
         redo TRY;
      }
      elsif ( $EVAL_ERROR ) {
         die $EVAL_ERROR;
      }
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
   if ( $self->{replace} ) {
      return $self->make_row('REPLACE', $row, $cols);
   }
   my %in_where = map { $_ => 1 } @$cols;
   my $where = $self->make_where_clause($row, $cols);
   if ( my $dbh = $self->{fetch_back} ) {
      my $sql = "SELECT * FROM $self->{sdb_tbl} WHERE $where LIMIT 1";
      $ENV{MKDEBUG} && _d("Fetching data for UPDATE: $sql");
      my $res = $dbh->selectrow_hashref($sql);
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
   if ( $self->{replace} ) {
      return $self->make_row('REPLACE', $row, $cols);
   }
   return $self->make_row('INSERT', $row, $cols);
}

sub make_REPLACE {
   my ( $self, $row, $cols ) = @_;
   return $self->make_row('REPLACE', $row, $cols);
}

sub make_row {
   my ( $self, $verb, $row, $cols ) = @_;
   my @cols = sort keys %$row;
   if ( my $dbh = $self->{fetch_back} ) {
      my $where = $self->make_where_clause($row, $cols);
      my $sql = "SELECT * FROM $self->{sdb_tbl} WHERE $where LIMIT 1";
      $ENV{MKDEBUG} && _d("Fetching data for UPDATE: $sql");
      my $res = $dbh->selectrow_hashref($sql);
      @{$row}{keys %$res} = values %$res;
      @cols = sort keys %$res;
   }
   return "$verb INTO $self->{db_tbl}("
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

sub get_changes {
   my ( $self ) = @_;
   return %{$self->{changes}};
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# ChangeHandler:$line ", @_, "\n";
}

1;

# ###########################################################################
# End ChangeHandler package
# ###########################################################################
