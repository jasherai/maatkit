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
# TableSyncStream package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

# This package implements the simplest possible table-sync algorithm: read every
# row from the tables and compare them.
package TableSyncStream;

# Arguments:
# * rowsyncer RowSyncer
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(rowsyncer cols) ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   return bless { %args }, $class;
}

# Arguments:
# * quoter   Quoter
# * database Database name
# * table    Table name
# * where    WHERE clause
sub get_sql {
   my ( $self, %args ) = @_;
   return "SELECT "
      . join(', ', map { $args{quoter}->quote($_) } @{$self->{cols}})
      . ' FROM ' . $args{quoter}->quote(@args{qw(database table)})
      . ' WHERE ' . ( $args{where} || '1=1' );
}

sub same_row {
   my ( $self, $lr, $rr ) = @_;
}

sub not_in_right {
   my ( $self, $lr ) = @_;
   $self->{rowsyncer}->ins($lr);
}

sub not_in_left {
   my ( $self, $rr ) = @_;
   $self->{rowsyncer}->del($rr);
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

1;

# ###########################################################################
# End TableSyncStream package
# ###########################################################################
