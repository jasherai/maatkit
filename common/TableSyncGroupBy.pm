#!/usr/bin/perl

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
# TableSyncGroupBy package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

# This package syncs tables without primary keys by doing an all-columns GROUP
# BY with a count, and then streaming through the results to see how many of
# each group exist.
package TableSyncGroupBy;

use English qw(-no_match_vars);

# Arguments:
# * handler ChangeHandler
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(handler cols) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   $args{count_col} = '__maatkit_count';
   while ( $args{struct}->{is_col}->{$args{count_col}} ) {
      # Prepend more _ until not a column.
      $args{count_col} = "_$args{count_col}";
   }
   $ENV{MKDEBUG} && _d('COUNT column will be named ' . $args{count_col});
   return bless { %args }, $class;
}

# Arguments:
# * quoter   Quoter
# * database Database name
# * table    Table name
# * where    WHERE clause
sub get_sql {
   my ( $self, %args ) = @_;
   my $cols = join(', ', map { $args{quoter}->quote($_) } @{$self->{cols}});
   return "SELECT $cols, COUNT(*) AS $self->{count_col}"
      . ' FROM ' . $args{quoter}->quote(@args{qw(database table)})
      . ' WHERE ' . ( $args{where} || '1=1' )
      . " GROUP BY $cols ORDER BY $cols";
}

# The same row means that the key columns are equal, so there are rows with the
# same columns in both tables; but there are different numbers of rows.  So we
# must either delete or insert the required number of rows to the table.
sub same_row {
   my ( $self, $lr, $rr ) = @_;
   my $cc = $self->{count_col};
   my $lc = $lr->{$cc};
   my $rc = $rr->{$cc};
   my $diff = abs($lc - $rc);
   return unless $diff;
   $lr = { %$lr };
   delete $lr->{$cc};
   $rr = { %$rr };
   delete $rr->{$cc};
   foreach my $i ( 1 .. $diff ) {
      if ( $lc > $rc ) {
         $self->{handler}->change('INSERT', $lr, $self->key_cols());
      }
      else {
         $self->{handler}->change('DELETE', $rr, $self->key_cols());
      }
   }
}

# Insert into the table the specified number of times.
sub not_in_right {
   my ( $self, $lr ) = @_;
   $lr = { %$lr };
   my $cnt = delete $lr->{$self->{count_col}};
   foreach my $i ( 1 .. $cnt ) {
      $self->{handler}->change('INSERT', $lr, $self->key_cols());
   }
}

# Delete from the table the specified number of times.
sub not_in_left {
   my ( $self, $rr ) = @_;
   $rr = { %$rr };
   my $cnt = delete $rr->{$self->{count_col}};
   foreach my $i ( 1 .. $cnt ) {
      $self->{handler}->change('DELETE', $rr, $self->key_cols());
   }
}

sub done_with_rows {
   my ( $self ) = @_;
   $self->{done} = 1;
}

sub done {
   my ( $self ) = @_;
   return $self->{done};
}

sub key_cols {
   my ( $self ) = @_;
   return $self->{cols};
}

# Do any required setup before executing the SQL (such as setting up user
# variables for checksum queries).
sub prepare {
   my ( $self, $dbh ) = @_;
}

# Return 1 if you have changes yet to make and you don't want the TableSyncer to
# commit your transaction or release your locks.
sub pending_changes {
   my ( $self ) = @_;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# TableSyncGroupBy:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End TableSyncGroupBy package
# ###########################################################################
