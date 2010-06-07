# This program is copyright 2007-2010 Baron Schwartz.
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
package ChangeHandler;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

my $DUPE_KEY  = qr/Duplicate entry/;
our @ACTIONS  = qw(DELETE REPLACE INSERT UPDATE);

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Arguments:
# * Quoter     Quoter object
# * left_db    Left database (src by default)
# * left_tbl   Left table (src by default)
# * right_db   Right database (dst by default)
# * right_tbl  Right table (dst by default)
# * actions    arrayref of subroutines to call when handling a change.
# * replace    Do UPDATE/INSERT as REPLACE.
# * queue      Queue changes until process_rows is called with a greater
#              queue level.
# * tbl_struct (optional) Used to sort columns and detect binary columns
# * hex_blob   (optional) HEX() BLOB columns (default yes)
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(Quoter left_db left_tbl right_db right_tbl
                        replace queue) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   my $q = $args{Quoter};

   my $self = {
      hex_blob     => 1,
      %args,
      left_db_tbl  => $q->quote(@args{qw(left_db left_tbl)}),
      right_db_tbl => $q->quote(@args{qw(right_db right_tbl)}),
   };

   # By default left is source and right is dest.  With bidirectional
   # syncing this can change.  See set_src().
   $self->{src_db_tbl} = $self->{left_db_tbl};
   $self->{dst_db_tbl} = $self->{right_db_tbl};

   # Init and zero changes for all actions.
   map { $self->{$_} = [] } @ACTIONS;
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
   MKDEBUG && _d('Set fetch back dbh', $dbh);
   return;
}

# For bidirectional syncing both tables are src and dst.  Internally,
# we refer to the tables generically as the left and right.  Either
# one can be src or dst, as set by this sub when called by the caller.
# Other subs don't know to which table src or dst point.  They just
# fetchback from src and change dst.  If the optional $dbh arg is
# given, fetch_back() is set with it, too.
sub set_src {
   my ( $self, $src, $dbh ) = @_;
   die "I need a src argument" unless $src;
   if ( lc $src eq 'left' ) {
      $self->{src_db_tbl} = $self->{left_db_tbl};
      $self->{dst_db_tbl} = $self->{right_db_tbl};
   }
   elsif ( lc $src eq 'right' ) {
      $self->{src_db_tbl} = $self->{right_db_tbl};
      $self->{dst_db_tbl} = $self->{left_db_tbl}; 
   }
   else {
      die "src argument must be either 'left' or 'right'"
   }
   MKDEBUG && _d('Set src to', $src);
   $self->fetch_back($dbh) if $dbh;
   return;
}

# Return current source db.tbl (could be left or right table).
sub src {
   my ( $self ) = @_;
   return $self->{src_db_tbl};
}

# Return current destination db.tbl (could be left or right table).
sub dst {
   my ( $self ) = @_;
   return $self->{dst_db_tbl};
}

# Arguments:
#   * sql   scalar: a SQL statement
#   * dbh   obj: (optional) dbh
# This sub calls the user-provided actions, passing them an
# action statement and an option dbh.  This sub is not called
# directly, it's called by change() or process_rows().
sub _take_action {
   my ( $self, $sql, $dbh ) = @_;
   MKDEBUG && _d('Calling subroutines on', $dbh, $sql);
   foreach my $action ( @{$self->{actions}} ) {
      $action->($sql, $dbh);
   }
   return;
}

# Arguments:
#   * action   scalar: string, one of @ACTIONS
#   * row      hashref: row data
#   * cols     arrayref: column names
#   * dbh      obj: (optional) dbh, passed to _take_action()
# If not queueing, this sub makes an action SQL statment for the given
# action, row and columns.  It calls _take_action(), passing the action
# statement and the optional dbh.  If queueing, the args are saved and
# the same work is done in process_rows().  Queueing does not work with
# bidirectional syncs.
sub change {
   my ( $self, $action, $row, $cols, $dbh ) = @_;
   MKDEBUG && _d($dbh, $action, 'where', $self->make_where_clause($row, $cols));

   # Undef action means don't do anything.  This allows deeply
   # nested callers to avoid/skip a change without dying.
   return unless $action;

   $self->{changes}->{
      $self->{replace} && $action ne 'DELETE' ? 'REPLACE' : $action
   }++;
   if ( $self->{queue} ) {
      $self->__queue($action, $row, $cols, $dbh);
   }
   else {
      eval {
         my $func = "make_$action";
         $self->_take_action($self->$func($row, $cols), $dbh);
      };
      if ( $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
         MKDEBUG && _d('Duplicate key violation; will queue and rewrite');
         $self->{queue}++;
         $self->{replace} = 1;
         $self->__queue($action, $row, $cols, $dbh);
      }
      elsif ( $EVAL_ERROR ) {
         die $EVAL_ERROR;
      }
   }
   return;
}

sub __queue {
   my ( $self, $action, $row, $cols, $dbh ) = @_;
   MKDEBUG && _d('Queueing change for later');
   if ( $self->{replace} ) {
      $action = $action eq 'DELETE' ? $action : 'REPLACE';
   }
   push @{$self->{$action}}, [ $row, $cols, $dbh ];
}

# If called with 1, will process rows that have been deferred from instant
# processing.  If no arg, will process all rows.
sub process_rows {
   my ( $self, $queue_level ) = @_;
   my $error_count = 0;
   TRY: {
      if ( $queue_level && $queue_level < $self->{queue} ) { # see redo below!
         MKDEBUG && _d('Not processing now', $queue_level, '<', $self->{queue});
         return;
      }
      MKDEBUG && _d('Processing rows:');
      my ($row, $cur_act);
      eval {
         foreach my $action ( @ACTIONS ) {
            my $func = "make_$action";
            my $rows = $self->{$action};
            MKDEBUG && _d(scalar(@$rows), 'to', $action);
            $cur_act = $action;
            while ( @$rows ) {
               $row    = shift @$rows;
               my $dbh = $row->[2] if $row->[2];  # dbh is optional
               $self->_take_action($self->$func(@$row), $dbh);
            }
         }
         $error_count = 0;
      };
      if ( !$error_count++ && $EVAL_ERROR =~ m/$DUPE_KEY/ ) {
         MKDEBUG && _d('Duplicate key violation; re-queueing and rewriting');
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
   MKDEBUG && _d('Make DELETE');
   return "DELETE FROM $self->{dst_db_tbl} WHERE "
      . $self->make_where_clause($row, $cols)
      . ' LIMIT 1';
}

sub make_UPDATE {
   my ( $self, $row, $cols ) = @_;
   MKDEBUG && _d('Make UPDATE');
   if ( $self->{replace} ) {
      return $self->make_row('REPLACE', $row, $cols);
   }
   my %in_where = map { $_ => 1 } @$cols;
   my $where = $self->make_where_clause($row, $cols);
   my @cols;
   if ( my $dbh = $self->{fetch_back} ) {
      my $sql = $self->make_fetch_back_query($where);
      MKDEBUG && _d('Fetching data on dbh', $dbh, 'for UPDATE:', $sql);
      my $res = $dbh->selectrow_hashref($sql);
      @{$row}{keys %$res} = values %$res;
      @cols = $self->sort_cols($res);
   }
   else {
      @cols = $self->sort_cols($row);
   }
   return "UPDATE $self->{dst_db_tbl} SET "
      . join(', ', map {
            $self->{Quoter}->quote($_)
            . '=' .  $self->{Quoter}->quote_val($row->{$_})
         } grep { !$in_where{$_} } @cols)
      . " WHERE $where LIMIT 1";
}

sub make_INSERT {
   my ( $self, $row, $cols ) = @_;
   MKDEBUG && _d('Make INSERT');
   if ( $self->{replace} ) {
      return $self->make_row('REPLACE', $row, $cols);
   }
   return $self->make_row('INSERT', $row, $cols);
}

sub make_REPLACE {
   my ( $self, $row, $cols ) = @_;
   MKDEBUG && _d('Make REPLACE');
   return $self->make_row('REPLACE', $row, $cols);
}

sub make_row {
   my ( $self, $verb, $row, $cols ) = @_;
   my @cols; 
   if ( my $dbh = $self->{fetch_back} ) {
      my $where = $self->make_where_clause($row, $cols);
      my $sql   = $self->make_fetch_back_query($where);
      MKDEBUG && _d('Fetching data on dbh', $dbh, 'for', $verb, ':', $sql);
      my $res = $dbh->selectrow_hashref($sql);
      @{$row}{keys %$res} = values %$res;
      @cols = $self->sort_cols($res);
   }
   else {
      @cols = $self->sort_cols($row);
   }
   my $q = $self->{Quoter};
   return "$verb INTO $self->{dst_db_tbl}("
      . join(', ', map { $q->quote($_) } @cols)
      . ') VALUES ('
      . join(', ', map { $q->quote_val($_) } @{$row}{@cols} )
      . ')';
}

sub make_where_clause {
   my ( $self, $row, $cols ) = @_;
   my @clauses = map {
      my $val = $row->{$_};
      my $sep = defined $val ? '=' : ' IS ';
      $self->{Quoter}->quote($_) . $sep . $self->{Quoter}->quote_val($val);
   } @$cols;
   return join(' AND ', @clauses);
}

sub get_changes {
   my ( $self ) = @_;
   return %{$self->{changes}};
}

sub sort_cols {
   my ( $self, $row ) = @_;
   my @cols;
   if ( $self->{tbl_struct} ) { 
      my $pos = $self->{tbl_struct}->{col_posn};
      my @not_in_tbl;
      @cols = sort {
            $pos->{$a} <=> $pos->{$b}
         }
         grep {
            if ( !defined $pos->{$_} ) {
               push @not_in_tbl, $_;
               0;
            }
            else {
               1;
            }
         }
         keys %$row;
      push @cols, @not_in_tbl if @not_in_tbl;
   }
   else {
      @cols = sort keys %$row;
   }
   return @cols;
}

sub make_fetch_back_query {
   my ( $self, $where ) = @_;
   die "I need a where argument" unless $where;
   my $cols       = '*';
   my $tbl_struct = $self->{tbl_struct};
   if ( $tbl_struct ) {
      $cols = join(', ',
         map {
            my $col = $_;
            if (    $self->{hex_blob}
                 && $tbl_struct->{type_for}->{$col} =~ m/blob|text|binary/ ) {
               $col = "IF(`$col`='', '', CONCAT('0x', HEX(`$col`))) AS `$col`";
            }
            else {
               $col = "`$col`";
            }
            $col;
         } @{ $tbl_struct->{cols} }
      );

      if ( !$cols ) {
         # This shouldn't happen in the real world.
         MKDEBUG && _d('Failed to make explicit columns list from tbl struct');
         $cols = '*';
      }
   }
   return "SELECT $cols FROM $self->{src_db_tbl} WHERE $where LIMIT 1";
}

sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

1;

# ###########################################################################
# End ChangeHandler package
# ###########################################################################
