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
# * use_proclist  Optional: whether to ignore SHOW SLAVE HOSTS.
# * parent        Optional: the DSN from which this call descended.
#
# The callback gets the slave's DSN, dbh, parent, and the recursion level as args.
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
         $args->{skip_callback}->($dsn, $dbh, $level, $args->{parent});
      }
      return;
   }

   # Call the callback!
   $args->{callback}->($dsn, $dbh, $level, $args->{parent});

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
            { %$args, dsn => $slave, dbh => undef, parent => $dsn }, $level + 1 );
      }
   }
}

# Finds slave hosts by trying SHOW SLAVE HOSTS, and if that doesn't reveal
# anything, looks at SHOW PROCESSLIST and tries to guess which ones are slaves.
# Returns a list of DSN hashes.  Optional extra keys in the DSN hash are
# master_id and server_id.  Also, the 'source' key is either 'processlist' or
# 'hosts'.  If $use_processlist is given, skips SHOW SLAVE HOSTS.
sub find_slave_hosts {
   my ( $self, $dsn_parser, $dbh, $dsn, $use_processlist ) = @_;
   $ENV{MKDEBUG} && _d('Looking for slaves on ', $dsn_parser->as_string($dsn));

   my @slaves;

   if ( !$use_processlist ) {
      # Try SHOW SLAVE HOSTS first.
      my $sql = 'SHOW SLAVE HOSTS';
      $ENV{MKDEBUG} && _d($sql);
      @slaves = @{$dbh->selectall_arrayref($sql, { Slice => {} })};

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
   }

   if ( !@slaves ) {
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

# Figures out how to connect to the master, by examining SHOW SLAVE STATUS.  But
# does NOT use the value from Master_User for the username, because typically we
# want to perform operations as the username that was specified (usually to the
# program's --user option, or in a DSN), rather than as the replication user,
# which is often restricted.
sub get_master_dsn {
   my ( $self, $dbh, $dsn, $dsn_parser ) = @_;
   my $master = $self->get_slave_status($dbh) or return undef;
   my $spec   = "h=$master->{master_host},P=$master->{master_port}";
   return       $dsn_parser->parse($spec, $dsn);
}

# Gets SHOW SLAVE STATUS, with column names all lowercased, as a hashref.
sub get_slave_status {
   my ( $self, $dbh ) = @_;
   if ( !$self->{not_a_slave}->{$dbh} ) {
      my $sth = $self->{sths}->{$dbh}->{SLAVE_STATUS}
            ||= $dbh->prepare('SHOW SLAVE STATUS');
      $ENV{MKDEBUG} && _d('SHOW SLAVE STATUS');
      $sth->execute();
      my $ss = $sth->fetchrow_hashref();

      if ( $ss && %$ss ) {
         $ss = { map { lc($_) => $ss->{$_} } keys %$ss }; # lowercase the keys
         return $ss;
      }

      $ENV{MKDEBUG} && _d('This server returns nothing for SHOW SLAVE STATUS');
      $self->{not_a_slave}->{$dbh}++;
   }
}

# Gets SHOW MASTER STATUS, with column names all lowercased, as a hashref.
sub get_master_status {
   my ( $self, $dbh ) = @_;
   if ( !$self->{not_a_master}->{$dbh} ) {
      my $sth = $self->{sths}->{$dbh}->{MASTER_STATUS}
            ||= $dbh->prepare('SHOW MASTER STATUS');
      $ENV{MKDEBUG} && _d('SHOW MASTER STATUS');
      $sth->execute();
      my $ms = $sth->fetchrow_hashref();

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

# Executes STOP SLAVE.
sub stop_slave {
   my ( $self, $dbh ) = @_;
   my $sth = $self->{sths}->{$dbh}->{STOP_SLAVE}
         ||= $dbh->prepare('STOP SLAVE');
   $ENV{MKDEBUG} && _d($sth->{Statement});
   $sth->execute();
}

# Executes START SLAVE, optionally with UNTIL.
sub start_slave {
   my ( $self, $dbh, $pos ) = @_;
   if ( $pos ) {
      # Just like with CHANGE MASTER TO, you can't quote the position.
      my $sql = "START SLAVE UNTIL MASTER_LOG_FILE='$pos->{file}', "
              . "MASTER_LOG_POS=$pos->{position}";
      $ENV{MKDEBUG} && _d($sql);
      $dbh->do($sql);
   }
   else {
      my $sth = $self->{sths}->{$dbh}->{START_SLAVE}
            ||= $dbh->prepare('START SLAVE');
      $ENV{MKDEBUG} && _d($sth->{Statement});
      $sth->execute();
   }
}

# Waits for the slave to catch up to its master, using START SLAVE UNTIL.
sub catchup_to_master {
   my ( $self, $slave, $master, $time ) = @_;
   my $slave_status  = $self->get_slave_status($slave);
   my $slave_pos     = $self->repl_posn($slave_status);
   my $master_status = $self->get_master_status($master);
   my $master_pos    = $self->repl_posn($master_status);
   $ENV{MKDEBUG} && _d("Master position: ", $self->pos_to_string($master_pos),
      " Slave position: ", $self->pos_to_string($slave_pos));
   if ( $self->pos_cmp($slave_pos, $master_pos) < 0 ) {
      $ENV{MKDEBUG} && _d('Waiting for slave to catch up to master');
      $self->start_slave($slave, $master_pos);
      $self->wait_for_master($master, $slave, $time, 0, $master_status);
   }
}

# Uses CHANGE MASTER TO to change a slave's master.
sub change_master_to {
   my ( $self, $dbh, $master_dsn, $master_pos ) = @_;
   # Don't prepare a $sth because CHANGE MASTER TO doesn't like quotes around
   # port numbers, etc.  It's possible to specify the bind type, but it's easier
   # to just not use a prepared statement.
   my $sql = "CHANGE MASTER TO MASTER_HOST='$master_dsn->{h}', "
      . "MASTER_PORT= $master_dsn->{P}, MASTER_LOG_FILE='$master_pos->{file}', "
      . "MASTER_LOG_POS=$master_pos->{position}";
   $ENV{MKDEBUG} && _d($sql);
   $dbh->do($sql);
}

# Moves a slave to be a slave of its grandmaster: a sibling of its master.
sub make_sibling_of_master {
   my ( $self, $slave_dbh, $slave_dsn, $dsn_parser, $timeout) = @_;

   # Connect to the master and the grand-master, and verify that the master is
   # also a slave.  Also verify that the grand-master isn't the slave!
   # (master-master replication).
   my $master_dsn  = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
      or die "This server is not a slave";
   my $master_dbh  = $dsn_parser->get_dbh(
      $dsn_parser->get_cxn_params($master_dsn), { AutoCommit => 1 });
   my $gmaster_dsn
      = $self->get_master_dsn($master_dbh, $master_dsn, $dsn_parser)
      or die "This server's master is not a slave";
   my $gmaster_dbh = $dsn_parser->get_dbh(
      $dsn_parser->get_cxn_params($gmaster_dsn), { AutoCommit => 1 });
   if ( $self->short_host($slave_dsn) eq $self->short_host($gmaster_dsn) ) {
      die "The slave's master's master is the slave: master-master replication";
   }

   # Stop the master, and make the slave catch up to it.
   $self->stop_slave($master_dbh);
   $self->catchup_to_master($slave_dbh, $master_dbh, $timeout);
   $self->stop_slave($slave_dbh);

   # Get the replication statuses and positions.
   my $master_status = $self->get_master_status($master_dbh);
   my $mslave_status = $self->get_slave_status($master_dbh);
   my $slave_status  = $self->get_slave_status($slave_dbh);
   my $master_pos    = $self->repl_posn($master_status);
   my $slave_pos     = $self->repl_posn($slave_status);

   # Verify that they are both stopped and are at the same position.
   if ( !$self->slave_is_running($mslave_status)
     && !$self->slave_is_running($slave_status)
     && $self->pos_cmp($master_pos, $slave_pos) == 0)
   {
      $self->change_master_to($slave_dbh, $gmaster_dsn,
         $self->repl_posn($mslave_status)); # Note it's not $master_pos!
   }
   else {
      die "The servers aren't both stopped at the same position";
   }

   # Verify that they have the same master and are at the same position.
   $mslave_status = $self->get_slave_status($master_dbh);
   $slave_status  = $self->get_slave_status($slave_dbh);
   my $mslave_pos = $self->repl_posn($mslave_status);
   $slave_pos     = $self->repl_posn($slave_status);
   if ( $self->short_host($mslave_status) ne $self->short_host($slave_status)
     || $self->pos_cmp($mslave_pos, $slave_pos) != 0)
   {
      die "The servers don't have the same master/position after the change";
   }
}

# Moves a slave to be a slave of its sibling.
# 1. Connect to the sibling and verify that it has the same master.
# 2. Stop the slave processes on the server and its sibling.
# 3. If one of the servers is behind the other, make it catch up.
# 4. Point the slave to its sibling.
sub make_slave_of_sibling {
   my ( $self, $slave_dbh, $slave_dsn, $sib_dbh, $sib_dsn,
        $dsn_parser, $timeout) = @_;

   # Verify that the sibling is a different server.
   if ( $self->short_host($slave_dsn) eq $self->short_host($sib_dsn) ) {
      die "You are trying to make the slave a slave of itself";
   }

   # Verify that the sibling has the same master, and that it is a master.
   my $master_dsn1 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
      or die "This server is not a slave";
   my $master_dbh1 = $dsn_parser->get_dbh(
      $dsn_parser->get_cxn_params($master_dsn1), { AutoCommit => 1 });
   my $master_dsn2 = $self->get_master_dsn($slave_dbh, $slave_dsn, $dsn_parser)
      or die "The sibling is not a slave";
   if ( $self->short_host($master_dsn1) ne $self->short_host($master_dsn2) ) {
      die "This server isn't a sibling of the slave";
   }
   my $sib_master_stat = $self->get_master_status($sib_dbh)
      or die "Binary logging is not enabled on the sibling";
   die "The log_slave_updates option is not enabled on the sibling"
      unless $self->has_slave_updates($sib_dbh);

   # Stop the slave and its sibling, then if one is behind the other, make it
   # catch up.
   $self->stop_slave($slave_dbh);
   $self->stop_slave($sib_dbh);
   my $slave_status = $self->get_slave_status($slave_dbh);
   my $sib_status   = $self->get_slave_status($sib_dbh);
   my $slave_pos    = $self->repl_posn($slave_status);
   my $sib_pos      = $self->repl_posn($sib_status);
   if ( $self->pos_cmp($slave_pos, $sib_pos) < 0 ) {
      # The slave is behind the sibling.
      $self->start_slave($slave_dbh, $sib_pos);
   }
   elsif ( $self->pos_cmp($slave_pos, $sib_pos) > 0 ) {
      $self->start_slave($sib_dbh, $slave_pos);
   }

   # Re-fetch the replication statuses and positions.
   $slave_status    = $self->get_slave_status($slave_dbh);
   $sib_status      = $self->get_slave_status($sib_dbh);
   $slave_pos       = $self->repl_posn($slave_status);
   $sib_pos         = $self->repl_posn($sib_status);
   $sib_master_stat = $self->get_master_status($sib_dbh);

   # Verify that they are both stopped and are at the same position.
   if ( !$self->slave_is_running($slave_status)
     && !$self->slave_is_running($sib_status)
     && $self->pos_cmp($slave_pos, $sib_pos) == 0)
   {
      $self->change_master_to($slave_dbh, $sib_dsn,
         $self->repl_posn($sib_master_stat));
   }
   else {
      die "The servers aren't both stopped at the same position";
   }

   # Verify that the slave's master is the sibling and that it is at the same
   # position.
   $slave_status    = $self->get_slave_status($slave_dbh);
   $slave_pos       = $self->repl_posn($slave_status);
   $sib_master_stat = $self->get_master_status($sib_dbh);
   if ( $self->short_host($slave_status) ne $self->short_host($sib_dsn)
     || $self->pos_cmp($self->repl_posn($sib_master_stat), $slave_pos) != 0)
   {
      die "After changing the slave's master, it isn't a slave of the sibling, "
         . "or it has a different replication position than the sibling";
   }
}

# Returns true if the slave is running.
sub slave_is_running {
   my ( $self, $slave_status ) = @_;
   return ($slave_status->{slave_sql_running} || 'No') eq 'Yes';
}

# Returns true if the server's log_slave_updates option is enabled.
sub has_slave_updates {
   my ( $self, $dbh ) = @_;
   my $sql = q{SHOW VARIABLES LIKE 'log_slave_updates'};
   $ENV{MKDEBUG} && _d($sql);
   my ($name, $value) = $dbh->selectrow_array($sql);
   return $value && $value =~ m/^(1|ON)$/;
}

# Extracts the replication position out of either SHOW MASTER STATUS or SHOW
# SLAVE STATUS, and returns it as a hashref { file, position }
sub repl_posn {
   my ( $self, $status ) = @_;
   if ( exists $status->{file} && exists $status->{position} ) {
      # It's the output of SHOW MASTER STATUS
      return {
         file     => $status->{file},
         position => $status->{position},
      };
   }
   else {
      return {
         file     => $status->{relay_master_log_file},
         position => $status->{exec_master_log_pos},
      };
   }
}

# Compares two replication positions and returns -1, 0, or 1 just as the cmp
# operator does.
sub pos_cmp {
   my ( $self, $a, $b ) = @_;
   return $self->pos_to_string($a) cmp $self->pos_to_string($b);
}

# Simplifies a hostname as much as possible.  For purposes of replication, a
# hostname is really just the combination of hostname and port, since
# replication always uses TCP connections (it does not work via sockets).  If
# the port is the default 3306, it is omitted.  As a convenience, this sub
# accepts either SHOW SLAVE STATUS or a DSN.
sub short_host {
   my ( $self, $dsn ) = @_;
   my ($host, $port);
   if ( $dsn->{master_host} ) {
      $host = $dsn->{master_host};
      $port = $dsn->{master_port};
   }
   else {
      $host = $dsn->{h};
      $port = $dsn->{P};
   }
   return ($host || '[default]') . ( ($port || 3306) == 3306 ? '' : ":$port" );
}

# Stringifies a position in a way that's string-comparable.
sub pos_to_string {
   my ( $self, $pos ) = @_;
   my $fmt  = '%s/%020d';
   return sprintf($fmt, @{$pos}{qw(file position)});
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# MasterSlave:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End MasterSlave package
# ###########################################################################
