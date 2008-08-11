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
   my $self = defined $params ? { %{ $params } } : {};
   $self->{undef_value} ||= '';
   return bless $self, $class;
}

sub aggregate_processlist {
   my ( $self, $recset ) = @_;
   my $agg_proclist = {};
   foreach my $proc ( @{ $recset } ) {
      foreach my $field ( keys %{ $proc } ) {
         next if $field eq 'Id';
         next if $field eq 'Info';
         next if $field eq 'Time';
         my $val = $proc->{ $field };
            $val = $self->{undef_value} if !defined $val;
            $val = lc $val if ( $field eq 'Command' || $field eq 'State' );
         $field = lc $field;
         $agg_proclist->{ $field }->{ $val }->{time}  += $proc->{Time};
         $agg_proclist->{ $field }->{ $val }->{count} += 1;
      }
   }
   return $agg_proclist;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# AggregateProcessList:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End AggregateProcessList package
# ###########################################################################
