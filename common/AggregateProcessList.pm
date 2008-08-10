# This program is copyright 2008 Percona Inc.
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
# AggregateProcessList package $Revision$
# ###########################################################################

# AggregateProcessList - Aggregate snapshots of SHOW PROCESSLIST
package AggregateProcessList;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Carp;
use Data::Dumper;

sub new {
   my ( $class, $dbh, $params ) = @_;
   # $params is a placeholder for when we later expand the functionality
   # of this module. For now, we fully aggregate 1 snapshot by default.
   my $self = {};
   return bless $self, $class;
}

sub aggregate_processlist {
   my ( $self, $recset ) = @_;
   my $aggregated_proclist = {};
   my $User    = $aggregated_proclist->{User}    = {};
   my $Host    = $aggregated_proclist->{Host}    = {};
   my $db      = $aggregated_proclist->{db}      = {};
   my $Command = $aggregated_proclist->{Command} = {};
   my $State   = $aggregated_proclist->{State}   = {};
   foreach my $proc ( @{ $recset } ) {
      $User->{ $proc->{User} }->{Time}       += $proc->{Time};
      $Host->{ $proc->{Host} }->{Time}       += $proc->{Time};
      $db->{ $proc->{db} }->{Time}           += $proc->{Time};
      $Command->{ $proc->{Command} }->{Time} += $proc->{Time};
      $State->{ $proc->{State} }->{Time}     += $proc->{Time};

      $User->{ $proc->{User} }->{Count}       += 1;
      $Host->{ $proc->{Host} }->{Count}       += 1;
      $db->{ $proc->{db} }->{Count}           += 1;
      $Command->{ $proc->{Command} }->{Count} += 1;
      $State->{ $proc->{State} }->{Count}     += 1;
   }
   return $aggregated_proclist;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# AggregateProcessList:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End AggregateProcessList package
# ###########################################################################
