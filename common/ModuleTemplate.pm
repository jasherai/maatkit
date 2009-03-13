# This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
# ModuleTemplate package $Revision$
# ###########################################################################
package ModuleTemplate;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw() ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {};
   return bless $self, $class;
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
# End ModuleTemplate package
# ###########################################################################
