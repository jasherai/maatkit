# This program is copyright 2008-2009 Percona Inc.
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
# Grants package $Revision$
# ###########################################################################
package Grants;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

my %check_for_priv = (
   'PROCESS' => sub {
      my ( $dbh ) = @_;
      my $priv =
         grep { m/ALL PRIVILEGES.*?\*\.\*|PROCESS/ }
         @{$dbh->selectcol_arrayref('SHOW GRANTS')};
         return 0 if !$priv;
         return 1;
   },
);
      
sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

sub have_priv {
   my ( $self, $dbh, $priv ) = @_;
   $priv = uc $priv;
   if ( !exists $check_for_priv{$priv} ) {
      die "There is no check for privilege $priv";
   }
   return $check_for_priv{$priv}->($dbh);
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
# End Grants package
# ###########################################################################
