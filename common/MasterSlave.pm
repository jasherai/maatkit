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
# * skip_callback Optional: execute with slaves that will be skipped.
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
      if ( $args->{skip_callback} ) {
         $args->{skip_callback}->($dsn, $dbh, $level);
      }
      return;
   }

   # Call the callback!
   $args->{callback}->($dsn, $dbh, $level);

   if ( !defined $args->{recurse} || $level < $args->{recurse} ) {

      # Find the slave hosts.  Eliminate hosts that aren't slaves of me (as
      # revealed by server_id and master_id).
      my @slaves =
         grep { !$_->{master_id} || $_->{master_id} == $id } # Only my slaves.
         $self->find_slave_hosts($dp, $dbh, $dsn);

      foreach my $slave ( @slaves ) {
         $ENV{MKDEBUG} && _d('Recursing from ',
            $dp->as_string($dsn), ' to ', $dp->as_string($slave));
         $self->recurse_to_slaves(
            { %$args, dsn => $slave, dbh => undef }, $level + 1 );
      }
   }
}

# Finds slave hosts by trying SHOW SLAVE HOSTS, and if that doesn't reveal
# anything, looks at SHOW PROCESSLIST and tries to guess which ones are slaves.
# Returns a list of DSN hashes.  Optional extra keys in the DSN hash are
# master_id and server_id.  Also, the 'source' key is either 'processlist' or
# 'hosts'.
sub find_slave_hosts {
   my ( $self, $dsn_parser, $dbh, $dsn ) = @_;
   $ENV{MKDEBUG} && _d('Looking for slaves on ', $dsn_parser->as_string($dsn));

   # Try SHOW SLAVE HOSTS first.
   my $sql = 'SHOW SLAVE HOSTS';
   $ENV{MKDEBUG} && _d($sql);
   my @slaves = 
      @{$dbh->selectall_arrayref($sql, { Slice => {} })};

   # Convert SHOW SLAVE HOSTS into DSN hashes.
   if ( @slaves ) {
      $ENV{MKDEBUG} && _d('Found some SHOW SLAVE HOSTS info');
      @slaves = map {
         my %hash;
         @hash{ map { lc $_ } keys %$_ } = values %$_;
         my $spec = "h=$hash{host},P=$hash{port}"
            . ( $hash{user} ? ",u=$hash{user}" : '')
            . ( $hash{password} ? ",p=$hash{password}" : '');
         my $dsn           = $dsn_parser->parse($spec, $dsn);
         $dsn->{server_id} = $hash{server_id};
         $dsn->{master_id} = $hash{master_id};
         $dsn->{source}    = 'hosts';
         $dsn;
      } @slaves;
   }

   else {
      my $sql = 'SHOW PROCESSLIST';
      $ENV{MKDEBUG} && _d($sql);
      @slaves =
         map  {
            my $slave        = $dsn_parser->parse("h=$_", $dsn);
            $slave->{source} = 'processlist';
            $slave;
         }
         grep { $_ }
         map  {
            my ( $host ) = $_->{host} =~ m/^([^:]+):/;
            if ( $host eq 'localhost' ) {
               $host = '127.0.0.1'; # Replication never uses sockets.
            }
            $host;
         }
         # It's probably a slave if it's doing a binlog dump.
         grep { $_->{command} =~ m/Binlog Dump/i }
         map  {
            my %hash;
            @hash{ map { lc $_ } keys %$_ } = values %$_;
            \%hash;
         }
         @{$dbh->selectall_arrayref($sql, { Slice => {} })};
   }

   $ENV{MKDEBUG} && _d('Found ', scalar(@slaves), ' slaves');
   return @slaves;
}

sub get_master_dsn {
   my ( $self, $dbh, $dsn, $dsn_parser ) = @_;
   $ENV{MKDEBUG} && _d("Getting master cxn params via SHOW SLAVE STATUS");
   my $query  = 'SHOW SLAVE STATUS';
   $ENV{MKDEBUG} && _d($query);
   my $status = $dbh->selectrow_hashref($query);
   $status    = { map { lc($_) => $status->{$_} } keys %$status };
   my $spec   = "h=$status->{master_host},P=$status->{master_port}";
   return       $dsn_parser->parse($spec, $dsn);
}

# Returns a hashref of SHOW MASTER STATUS output, with keys lowercased.
sub get_master_status {
   my ( $self, $dbh ) = @_;
   if ( !$self->{not_a_master}->{$dbh} ) {
      my $query = 'SHOW MASTER STATUS';
      $ENV{MKDEBUG} && _d($query);
      my $ms = $dbh->selectrow_hashref($query);

      if ( $ms && %$ms ) {
         $ms = { map { lc($_) => $ms->{$_} } keys %$ms }; # lowercase the keys
         if ( $ms->{file} && $ms->{position} ) {
            return $ms;
         }
      }

      $ENV{MKDEBUG} && _d('This server returns nothing for SHOW MASTER STATUS');
      $self->{not_a_master}->{$dbh}++;
   }
}

# Waits for a slave to catch up to the master, with MASTER_POS_WAIT().  Returns
# the return value of MASTER_POS_WAIT().  $ms is the optional result of calling
# get_master_status().
sub wait_for_master {
   my ( $self, $master, $slave, $time, $timeoutok, $ms ) = @_;
   my $result;
   $ENV{MKDEBUG} && _d('Waiting for slave to catch up to master');
   $ms ||= $self->get_master_status($master);
   if ( $ms ) {
      my $query = "SELECT MASTER_POS_WAIT('$ms->{file}', $ms->{position}, $time)";
      $ENV{MKDEBUG} && _d($query);
      ($result) = $slave->selectrow_array($query);
      my $stat = defined $result ? $result : 'NULL';
      if ( $stat eq 'NULL' || $stat < 0 && !$timeoutok ) {
         die "MASTER_POS_WAIT returned $stat";
      }
      $ENV{MKDEBUG} && _d("Result of waiting: $stat");
   }
   else {
      $ENV{MKDEBUG} && _d("Not waiting: this server is not a master");
   }
   return $result;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# MasterSlave:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End MasterSlave package
# ###########################################################################
