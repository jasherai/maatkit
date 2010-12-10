# This program is copyright 2009-2010 Percona Inc.
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

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Eventually _d() will be exported by default.  We can't do this until
# we remove it from all other modules else we'll get a "redefined" error.
sub _d {
   my ($package, undef, $line) = caller 0;
   @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
        map { defined $_ ? $_ : 'undef' }
        @_;
   print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
}

# Returns the number of CPUs.  If no sys info is given, then it's gotten
# from /proc/cpuinfo, sysctl or whatever method will work.  If sys info
# is given, then we try to parse the number of CPUs from it.  Passing in
# $sys_info makes this code easy to test.
sub get_number_of_cpus {
   my ( $sys_info ) = @_;
   my $n_cpus; 

   # Try to read the number of CPUs in /proc/cpuinfo.
   # This only works on GNU/Linux.
   my $cpuinfo;
   if ( $sys_info || (open $cpuinfo, "<", "/proc/cpuinfo") ) {
      local $INPUT_RECORD_SEPARATOR = undef;
      my $contents = $sys_info || <$cpuinfo>;
      MKDEBUG && _d('sys info:', $contents);
      close $cpuinfo if $cpuinfo;
      $n_cpus = scalar( map { $_ } $contents =~ m/(processor)/g );
      MKDEBUG && _d('Got', $n_cpus, 'cpus from /proc/cpuinfo');
      return $n_cpus if $n_cpus;
   }

   # Alternatives to /proc/cpuinfo:

   # FreeBSD and Mac OS X
   if ( $sys_info || ($OSNAME =~ m/freebsd/i) || ($OSNAME =~ m/darwin/i) ) { 
      my $contents = $sys_info || `sysctl hw.ncpu`;
      MKDEBUG && _d('sys info:', $contents);
      ($n_cpus) = $contents =~ m/(\d)/ if $contents;
      MKDEBUG && _d('Got', $n_cpus, 'cpus from sysctl hw.ncpu');
      return $n_cpus if $n_cpus;
   } 

   # Windows   
   $n_cpus ||= $ENV{NUMBER_OF_PROCESSORS};

   return $n_cpus || 1; # There has to be at least 1 CPU.
}

1;

# ###########################################################################
# End MaatkitCommon package
# ###########################################################################
