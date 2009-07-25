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
# MaatkitCommon package $Revision$
# ###########################################################################
package MaatkitCommon;

# These are common subs used in Maatkit scripts.

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);

require Exporter;
our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ();
our @EXPORT      = qw();
our @EXPORT_OK   = qw(
   _d
   get_number_of_cpus
);

use constant MKDEBUG => $ENV{MKDEBUG};

# Eventually _d() will be exported by default.  We can't do this until
# we remove it from all other modules else we'll get a "redefined" error.
sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

sub get_number_of_cpus {
   my $n_cpus; 

   # Try to read the number of CPUs in /proc/cpuinfo.
   # This only works on GNU/Linux.
   my $cpuinfo;
   if ( !open $cpuinfo, "<", "/proc/cpuinfo" ) {
      MKDEBUG && _d('Cannot read /proc/cpuinfo:', $OS_ERROR);
   }
   else { 
      local $INPUT_RECORD_SEPARATOR = undef;
      my $contents = <$cpuinfo>;
      close $cpuinfo;
      $n_cpus = scalar( map { $_ } $contents =~ m/(processor)/g );
   }

   # Alternatives to /proc/cpuinfo.
   $n_cpus ||= $ENV{NUMBER_OF_PROCESSORS}; # MSWin32

   return $n_cpus || 2; # default if all else fails
}

1;

# ###########################################################################
# End MaatkitCommon package
# ###########################################################################
