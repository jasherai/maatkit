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
   my $user  = $aggregated_proclist->{user}    = {};
   my $host  = $aggregated_proclist->{host}    = {};
   my $cmd   = $aggregated_proclist->{command} = {};
   my $state = $aggregated_proclist->{state}   = {};
   my $db    = $aggregated_proclist->{db}      = {};
   foreach my $proc ( @{ $recset } ) {
      my $proc_user  =    $proc->{User};
      my $proc_host  =    $proc->{Host};
      my $proc_cmd   = lc $proc->{Command};
      my $proc_state = lc $proc->{State};
      my $proc_db    =    $proc->{db};

      $user->{ $proc_user }->{time}   += $proc->{Time};
      $host->{ $proc_host }->{time}   += $proc->{Time};
      $cmd->{ $proc_cmd }->{time}     += $proc->{Time};
      $state->{ $proc_state }->{time} += $proc->{Time};

      $user->{ $proc_user }->{count}   += 1;
      $host->{ $proc_host }->{count}   += 1;
      $cmd->{ $proc_cmd }->{count}     += 1;
      $state->{ $proc_state }->{count} += 1;
      $db->{ $proc_db }->{count}       += 1;
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
