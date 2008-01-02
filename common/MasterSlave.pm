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
# MasterSlave package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

# TODO:
# * separate find-slaves from recurse-slaves
# * use PROCESSLIST to find slaves, too
# * use this in table-sync, table-checksum

package MasterSlave;

use English qw(-no_match_vars);
use List::Util qw(min max);

sub new {
   bless {}, shift;
}

# Descends to slaves by examining SHOW SLAVE HOSTS.  Arguments is a hashref:
#
# * dbh           (Optional) a DBH.
# * dsn           The DSN to connect to; if no DBH, will connect using this.
# * dsn_parser    A DSNParser object.
# * recurse       How many levels to recurse. 0 = none, undef = infinite.
# * callback      Code to execute after finding a new slave.
#
# The callback gets the slave's DSN, dbh, and the recursion level as args.
# The recursion is tail recursion.
sub recurse_to_slaves {
   my ( $self, $args, $level ) = @_;
   $level ||= 0;
   my $dp   = $args->{dsn_parser};
   my $dsn  = $args->{dsn};

   my $dbh;
   eval {
      $dbh = $args->{dbh} || $dp->get_dbh(
         $dp->get_cxn_params($dsn), { AutoCommit => 1 });
      $ENV{MKDEBUG} && _d('Connected to ', $dp->as_string($dsn));
   };
   if ( $EVAL_ERROR ) {
      print STDERR "Cannot connect to ", $dp->as_string($dsn), "\n";
      return;
   }

   # SHOW SLAVE HOSTS sometimes has obsolete information.  Verify that this
   # server has the ID its master thought, and that we have not seen it before
   # in any case.
   my $sql  = 'SELECT @@SERVER_ID';
   $ENV{MKDEBUG} && _d($sql);
   my ($id) = $dbh->selectrow_array($sql);
   $ENV{MKDEBUG} && _d('Working on server ID ', $id);
   my $master_thinks_i_am = $dsn->{server_id};
   if ( !defined $id
       || ( defined $master_thinks_i_am && $master_thinks_i_am != $id )
       || $args->{server_ids_seen}->{$id}++
   ) {
      $ENV{MKDEBUG} && _d('Server ID seen, or not what master said');
      print STDERR "Skipping ", $dp->as_string($dsn), "\n";
      return;
   }

   # Call the callback!
   $args->{callback}->($dsn, $dbh, $level);

   if ( !defined $args->{recurse} || $level < $args->{recurse} ) {

      # Find the slave hosts.  Eliminate hosts that aren't slaves of me (as
      # revealed by server_id and master_id).  SHOW SLAVE HOSTS can be wacky.
      my @slaves =
         grep { $_->{master_id} == $id } # Only my own slaves.
         map  {                          # Convert each to all-lowercase keys.
            my %hash;
            @hash{ map { lc $_ } keys %$_ } = values %$_;
            \%hash;
         }
         @{$dbh->selectall_arrayref("SHOW SLAVE HOSTS", { Slice => {} })};

      foreach my $slave ( @slaves ) {
         my $spec = "h=$slave->{host},P=$slave->{port}"
            . ( $slave->{user} ? ",u=$slave->{user}" : '')
            . ( $slave->{password} ? ",p=$slave->{password}" : '');
         my $dsn = $dp->parse($spec, $dsn);
         $dsn->{server_id} = $slave->{server_id};
         $ENV{MKDEBUG} && _d('Recursing from ',
            $dp->as_string($dsn), ' to ', $dp->as_string($dsn));
         $self->recurse_to_slaves(
            { %$args, dsn => $dsn, dbh => undef }, $level + 1 );
      }
   }
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# MasterSlave:$line ", @_, "\n";
}

1;

# ###########################################################################
# End MasterSlave package
# ###########################################################################
