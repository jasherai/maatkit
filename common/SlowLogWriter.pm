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
# ###########################################################################
# SlowLogWriter package $Revision$
# ###########################################################################
package SlowLogWriter;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

# Print out in slow-log format.
sub write {
   my ( $self, $fh, $event ) = @_;
   if ( $event->{ts} ) {
      print $fh "# Time: $event->{ts}\n";
   }
   if ( $event->{user} ) {
      printf $fh "# User\@Host: %s[%s] \@ %s []\n",
         $event->{user}, $event->{user}, $event->{host};
   }
   printf $fh
      "# Query_time: %d  Lock_time: %d  Rows_sent: %d  Rows_examined: %d\n",
      # TODO 0  Rows_affected: 0  Rows_read: 1
      map { $_ || 0 }
         @{$event}{qw(Query_time Lock_time Rows_sent Rows_examined)};
   if ( $event->{db} ) {
      printf $fh "use %s;\n", $event->{db};
   }
   if ( $event->{arg} =~ m/^administrator command/ ) {
      print $fh '# ';
   }
   print $fh $event->{arg}, ";\n";
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
# End SlowLogWriter package
# ###########################################################################
