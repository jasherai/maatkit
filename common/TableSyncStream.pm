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

use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

# Arguments:
# * handler ChangeHandler
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(handler cols) ) {
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
      . ($self->{bufferinmysql} ? 'SQL_BUFFER_RESULT ' : '')
      . join(', ', map { $args{quoter}->quote($_) } @{$self->{cols}})
      . ' FROM ' . $args{quoter}->quote(@args{qw(database table)})
      . ' WHERE ' . ( $args{where} || '1=1' );
}

sub same_row {
   my ( $self, $lr, $rr ) = @_;
}

sub not_in_right {
   my ( $self, $lr ) = @_;
   $self->{handler}->change('INSERT', $lr, $self->key_cols());
}

sub not_in_left {
   my ( $self, $rr ) = @_;
   $self->{handler}->change('DELETE', $rr, $self->key_cols());
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
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   # Use $$ instead of $PID in case the package
   # does not use English.
   print "# $package:$line $$ ", @_, "\n";
}

1;

# ###########################################################################
# End TableSyncStream package
# ###########################################################################
