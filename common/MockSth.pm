# This program is copyright 2007-2009 Baron Schwartz.
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

# A package to mock up a $sth.
package MockSth;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, @rows ) = @_;
   my $self = {
      cursor => 0,
      Active => scalar(@rows),
      rows   => \@rows,
   };
   return bless $self, $class;
}

sub fetchrow_hashref {
   my ( $self ) = @_;
   my $row;
   if ( $self->{cursor} < @{$self->{rows}} ) {
      $row = $self->{rows}->[$self->{cursor}++];
   }
   $self->{Active} = $self->{cursor} < @{$self->{rows}};
   return $row;
}

1;
