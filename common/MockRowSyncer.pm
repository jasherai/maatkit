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
use strict;
use warnings FATAL => 'all';

# A package to mock up a RowSyncer.
package MockRowSyncer;

sub new {
   my ( $class ) = @_;
   return bless {}, $class;
}

sub del {
   my ( $self, $row ) = @_;
   push @{$self->{del}}, $row;
}

sub ins {
   my ( $self, $row ) = @_;
   push @{$self->{ins}}, $row;
}

sub upd {
   my ( $self, $row ) = @_;
   push @{$self->{upd}}, $row;
}

1;
