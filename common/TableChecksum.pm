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
# TableChecksum package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableChecksum;

use POSIX qw(ceil);
use List::Util qw(min max);

sub new {
   bless {}, shift;
}

# Options:
#   algorithm   Optional: one of CHECKSUM, ACCUM, BIT_XOR
#   vp          VersionParser object
#   dbh         DB handle
#   where       bool: whether user wants a WHERE clause applied
#   chunk       bool: whether user wants to checksum in chunks
#   replicate   bool: whether user wants to do via replication
#   count       bool: whether user wants a row count too
sub best_algorithm {
   my ( $self, %opts ) = @_;
   my ($a, $vp, $dbh) = @opts{ qw(algorithm vp dbh) };
   my @choices  = qw(CHECKSUM ACCUM BIT_XOR);
   die "Invalid checksum algorithm $a"
      if $a && ! grep { $_ eq $a } @choices;

   # CHECKSUM is eliminated by lots of things...
   if ( 
      $opts{where} || $opts{chunk}        # CHECKSUM does whole table
      || $opts{replicate}                 # CHECKSUM can't do INSERT.. SELECT
      || !$vp->version_ge($dbh, '4.1.1')) # CHECKSUM doesn't exist
   {
      @choices = grep { $_ ne 'CHECKSUM' } @choices;
   }

   # BIT_XOR isn't available till 4.1.1 either
   if ( !$vp->version_ge($dbh, '4.1.1') ) {
      @choices = grep { $_ ne 'BIT_XOR' } @choices;
   }

   # Choose the best (fastest) among the remaining choices.
   if ( $a && grep { $_ eq $a } @choices ) {
      # Honor explicit choices.
      return $a;
   }

   # If the user wants a count, prefer something other than CHECKSUM, because it
   # requires an extra query for the count.
   if ( $opts{count} && grep { $_ ne 'CHECKSUM' } @choices ) {
      @choices = grep { $_ ne 'CHECKSUM' } @choices;
   }

   return $choices[0];
}

1;

# ###########################################################################
# End TableChecksum package
# ###########################################################################
