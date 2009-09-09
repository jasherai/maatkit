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
# TableSyncer package $Revision$
# ###########################################################################
package TableSyncer;

use strict;
use warnings FATAL => 'all';

use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

sub new {
   return bless {}, shift;
}

# Return the first plugin from the arrayref of TableSync* plugins
# that can sync the given table struct.  plugin->can_sync() should
# return a hash of args that it wants back when plugin->prepare_to_sync()
# is called.
sub get_best_plugin {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(plugins tbl_struct) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   foreach my $plugin ( @{$args{plugins}} ) {
      my %plugin_args = $plugin->can_sync(%args);
      if ( %plugin_args ) {
        MKDEBUG && _d('Can sync with', $plugin, Dumper(\%plugin_args));
        return $plugin, %plugin_args;
      }
   }
   return;
}

sub sync_table {
   my ( $self, %args ) = @_;
   my @required_args = qw(src_dbh src_db src_tbl dst_dbh dst_db dst_tbl
                          tbl_struct cols chunk_size function plugins
                          TableChecksum TableChunker VersionParser Quoter
                          master_slave);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   MKDEBUG && _d('Syncing table with args',
      join(', ',
         map { "$_=" . (defined $args{$_} ? $args{$_} : 'undef') }
         sort keys %args));
   my $dbh = $args{src_dbh};
   my $vp  = $args{VersionParser};
   my $q   = $args{Quoter};

   # ########################################################################
   # Get the first plugin that says it can sync this table.
   # ########################################################################
   my ($plugin, %plugin_args) = $self->get_best_plugin(%args);
   die "No plugin can sync `$args{src_db}`.`$args{src_tbl}`" unless $plugin;

   # ########################################################################
   # Check permissions on writable tables (TODO: 2-way needs to check both)
   # TODO: for two-way sync, the change handler needs both DBHs.
   # ########################################################################
   my $update_func;
   my $change_dbh;
   my $use_replace;
   if ( $args{execute} ) {
      if ( $args{replicate} ) {
         $change_dbh = $args{src_dbh};
         $self->check_permissions(@args{qw(src_dbh src_db src_tbl quoter)});
         # Is it possible to make changes on the master?  Only if REPLACE will
         # work OK.
         my $can_replace
            = grep { $_->{is_unique} } values %{$args{tbl_struct}->{keys}};
         MKDEBUG && _d("This table's replace-ability:", $can_replace);
         $use_replace = $args{replace} || $args{replicate};
         if ( !$can_replace ) {
            die "Can't make changes on the master: no unique index exists";
         }
      }
      else {
         $change_dbh = $args{dst_dbh};
         $self->check_permissions(@args{qw(dst_dbh dst_db dst_tbl quoter)});
         # Is it safe to change data on $change_dbh?  It's only safe if it's not
         # a slave.  We don't change tables on slaves directly.  If we are
         # forced to change data on a slave, we require either that a) binary
         # logging is disabled, or b) the check is bypassed.  By the way, just
         # because the server is a slave doesn't mean it's not also the master
         # of the master (master-master replication).
         my $slave_status = $args{master_slave}->get_slave_status($change_dbh);
         my (undef, $log_bin) = $change_dbh->selectrow_array(
            'SHOW VARIABLES LIKE "log_bin"');
         my ($sql_log_bin) = $change_dbh->selectrow_array(
            'SELECT @@SQL_LOG_BIN');
         MKDEBUG && _d('Variables: log_bin=',
            (defined $log_bin ? $log_bin : 'NULL'),
            ' @@SQL_LOG_BIN=',
            (defined $sql_log_bin ? $sql_log_bin : 'NULL'));
         if ( !$args{skipslavecheck} && $slave_status && $sql_log_bin
            && ($log_bin || 'OFF') eq 'ON' )
         {
            die "Can't make changes on $change_dbh because it's a slave: see "
               . "the documentation section 'REPLICATION SAFETY' for solutions "
               . "to this problem.";
         }
      }
      MKDEBUG && _d('Will make changes via', $change_dbh);
      $update_func = sub {
         map {
            MKDEBUG && _d('About to execute:', $_);
            $change_dbh->do($_);
         } @_;
      };

      # Set default database in case replicate-do-db is being used (issue 533).
      $args{src_dbh}->do("USE `$args{src_db}`");
      $args{dst_dbh}->do("USE `$args{dst_db}`");
   }

   # TODO: these should be given as args so caller can make them as they wish
   my $ch = new ChangeHandler(
      %args,
      queue     => $args{buffer} ? 0 : 1,
      replace   => $use_replace,
      actions   => [
         ( $update_func ? $update_func            : () ),
         # Print AFTER executing, so the print isn't misleading in case of an
         # index violation etc that doesn't actually get executed.
         ( $args{print}
            ? sub { print(@_, ";\n") or die "Cannot print: $OS_ERROR" }
            : () ),
      ],
   );
   my $rd = $args{RowDiff} || new RowDiff( dbh => $args{misc_dbh} );

   if ( $args{dry_run} ) {
      return $ch->get_changes(), ALGORITHM => $plugin->get_name();
   }

   # ########################################################################
   # Prepare the plugin.
   # ########################################################################

   # The row-level (state 2) checksums use __crc, so the table can't use that.
   my $crc_col = '__crc';
   while ( $args{tbl_struct}->{is_col}->{$args{crc_col}} ) {
      $crc_col = "_$crc_col"; # Prepend more _ until not a column.
   }
   MKDEBUG && _d('CRC column:', $crc_col);

   my $index_hint;
   if ( $args{index_struct} ) {
      my $hint = $vp->version_ge($dbh, '4.0.9') ? 'FORCE' : 'USE';
      $index_hint = "$hint (" . $q->quote($args{index_struct}->{name}) . ")";
   }

   $plugin->prepare_to_sync(
      %args,
      %plugin_args,
      crc_col    => $crc_col,
      index_hint => $index_hint,
   );

   if ( $plugin->uses_checksum() ) {
      my ($chunk_sql, $row_sql) = make_checksum_queries(%args);
      $plugin->set_chunk_sql($chunk_sql);
      $plugin->set_row_sql($row_sql);
   } 

   # ########################################################################
   # Start syncing the table.
   # ########################################################################
   $self->lock_and_wait(%args, lock_level => 2);

   my $cycle = 0;
   while ( !$plugin->done() ) {

      # Do as much of the work as possible before opening a transaction or
      # locking the tables.
      MKDEBUG && _d('Beginning sync cycle', $cycle);
      my $src_sql = $plugin->get_sql(
         database   => $args{src_db},
         table      => $args{src_tbl},
         where      => $args{where},
      );
      my $dst_sql = $plugin->get_sql(
         quoter     => $args{quoter},
         database   => $args{dst_db},
         table      => $args{dst_tbl},
         where      => $args{where},
      );
      if ( $args{transaction} ) {
         # TODO: update this for 2-way sync.
         if ( $change_dbh && $change_dbh eq $args{src_dbh} ) {
            $src_sql .= ' FOR UPDATE';
            $dst_sql .= ' LOCK IN SHARE MODE';
         }
         elsif ( $change_dbh ) {
            $src_sql .= ' LOCK IN SHARE MODE';
            $dst_sql .= ' FOR UPDATE';
         }
         else {
            $src_sql .= ' LOCK IN SHARE MODE';
            $dst_sql .= ' LOCK IN SHARE MODE';
         }
      }
      $plugin->prepare_sync_cycle($args{src_dbh});
      $plugin->prepare_sync_cycle($args{dst_dbh});
      MKDEBUG && _d('src:', $src_sql);
      MKDEBUG && _d('dst:', $dst_sql);
      my $src_sth = $args{src_dbh}
         ->prepare( $src_sql, { mysql_use_result => !$args{buffer} } );
      my $dst_sth = $args{dst_dbh}
         ->prepare( $dst_sql, { mysql_use_result => !$args{buffer} } );

      # The first cycle should lock to begin work; after that, unlock only if
      # the plugin says it's OK (it may want to dig deeper on the rows it
      # currently has locked).
      my $executed_src = 0;
      if ( !$cycle || !$plugin->pending_changes() ) {
         $executed_src
            = $self->lock_and_wait(%args, src_sth => $src_sth, lock_level => 1);
      }

      # The source sth might have already been executed by lock_and_wait().
      $src_sth->execute() unless $executed_src;
      $dst_sth->execute();

      $rd->compare_sets(
         left   => $src_sth,
         right  => $dst_sth,
         syncer => $plugin,
         tbl    => $args{tbl_struct},
      );
      MKDEBUG && _d('Finished sync cycle', $cycle);
      $ch->process_rows(1);

      $cycle++;
   }

   $ch->process_rows();

   $self->unlock(%args, lock_level => 2);

   return ($ch->get_changes(), ALGORITHM => $args{algorithm});
}

sub make_checksum_queries {
   my ( $self, %args ) = @_;
   my @required_args = qw(TableChecksum dbh db tbl tbl_struct);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($checksum, $dbh) = @args{@required_args};

   # Decide on checksumming strategy and store checksum query prototypes for
   # later.
   my $algorithm  = $checksum->best_algorithm(
      algorithm => 'BIT_XOR',
      dbh       => $dbh,
      where     => 1,
      chunk     => 1,
      count     => 1,
   );
   my $func       = $checksum->choose_hash_func(%args);
   my $crc_wid    = $checksum->get_crc_wid($dbh, $func);
   my ($crc_type) = $checksum->get_crc_type($dbh, $func);
   my $opt_slice;
   if ( $algorithm eq 'BIT_XOR' && $crc_type !~ m/int$/ ) {
      $opt_slice = $checksum->optimize_xor($dbh, $func);
   }
   
   my $chunk_sql = $checksum->make_checksum_query(
      %args,
      algorithm => $algorithm,
      function  => $func,
      crc_wid   => $crc_wid,
      crc_type  => $crc_type,
      opt_slice => $opt_slice,
   );
   MKDEBUG && _d('Chunk sql:', $chunk_sql);
   my $row_sql = $checksum->make_row_checksum(
      %args,
      function => $func,
   );
   MKDEBUG && _d('Row sql:', $row_sql);
   return $chunk_sql, $row_sql;
}

# This query will check all needed privileges on the table without actually
# changing anything in it.  We can't use REPLACE..SELECT because that doesn't
# work inside of LOCK TABLES.
sub check_permissions {
   my ( $self, $dbh, $db, $tbl, $quoter ) = @_;
   my $db_tbl = $quoter->quote($db, $tbl);
   my $sql = "SHOW FULL COLUMNS FROM $db_tbl";
   MKDEBUG && _d('Permissions check:', $sql);
   my $cols = $dbh->selectall_arrayref($sql, {Slice => {}});
   my ($hdr_name) = grep { m/privileges/i } keys %{$cols->[0]};
   my $privs = $cols->[0]->{$hdr_name};
   die "$privs does not include all needed privileges for $db_tbl"
      unless $privs =~ m/select/ && $privs =~ m/insert/ && $privs =~ m/update/;
   $sql = "DELETE FROM $db_tbl LIMIT 0"; # FULL COLUMNS doesn't show all privs
   MKDEBUG && _d('Permissions check:', $sql);
   $dbh->do($sql);
}

sub lock_table {
   my ( $self, $dbh, $where, $db_tbl, $mode ) = @_;
   my $query = "LOCK TABLES $db_tbl $mode";
   MKDEBUG && _d($query);
   $dbh->do($query);
   MKDEBUG && _d('Acquired table lock on', $where, 'in', $mode, 'mode');
}

# Doesn't work quite the same way as lock_and_wait. It will unlock any LOWER
# priority lock level, not just the exact same one.
sub unlock {
   my ( $self, %args ) = @_;

   foreach my $arg ( qw(
      dst_db dst_dbh dst_tbl lock quoter replicate src_db src_dbh src_tbl
      timeoutok transaction wait lock_level) )
   {
      die "I need a $arg argument" unless defined $args{$arg};
   }

   return unless $args{lock} && $args{lock} <= $args{lock_level};

   # First, unlock/commit.
   foreach my $dbh( @args{qw(src_dbh dst_dbh)} ) {
      if ( $args{transaction} ) {
         MKDEBUG && _d('Committing', $dbh);
         $dbh->commit;
      }
      else {
         my $sql = 'UNLOCK TABLES';
         MKDEBUG && _d($dbh, $sql);
         $dbh->do($sql);
      }
   }
}

# Lock levels:
# 0 => none
# 1 => per sync cycle
# 2 => per table
# 3 => global
# This function might actually execute the $src_sth.  If we're using
# transactions instead of table locks, the $src_sth has to be executed before
# the MASTER_POS_WAIT() on the slave.  The return value is whether the
# $src_sth was executed.
sub lock_and_wait {
   my ( $self, %args ) = @_;
   my $result = 0;

   foreach my $arg ( qw(
      dst_db dst_dbh dst_tbl lock quoter replicate src_db src_dbh src_tbl
      timeoutok transaction wait lock_level misc_dbh master_slave) )
   {
      die "I need a $arg argument" unless defined $args{$arg};
   }

   return unless $args{lock} && $args{lock} == $args{lock_level};

   # First, unlock/commit.
   foreach my $dbh( @args{qw(src_dbh dst_dbh)} ) {
      if ( $args{transaction} ) {
         MKDEBUG && _d('Committing', $dbh);
         $dbh->commit;
      }
      else {
         my $sql = 'UNLOCK TABLES';
         MKDEBUG && _d($dbh, $sql);
         $dbh->do($sql);
      }
   }

   # User wants us to lock for consistency.  But lock only on source initially;
   # might have to wait for the slave to catch up before locking on the dest.
   if ( $args{lock} == 3 ) {
      my $sql = 'FLUSH TABLES WITH READ LOCK';
      MKDEBUG && _d($args{src_dbh}, ',', $sql);
      $args{src_dbh}->do($sql);
   }
   else {
      if ( $args{transaction} ) {
         if ( $args{src_sth} ) {
            # Execute the $src_sth on the source, so LOCK IN SHARE MODE/FOR
            # UPDATE will lock the rows examined.
            MKDEBUG && _d('Executing statement on source to lock rows');
            $args{src_sth}->execute();
            $result = 1;
         }
      }
      else {
         $self->lock_table($args{src_dbh}, 'source',
            $args{quoter}->quote($args{src_db}, $args{src_tbl}),
            $args{replicate} ? 'WRITE' : 'READ');
      }
   }

   # If there is any error beyond this point, we need to unlock/commit.
   eval {
      if ( $args{wait} ) {
         # Always use the $misc_dbh dbh to check the master's position, because
         # the $src_dbh might be in use due to executing $src_sth.
         $args{master_slave}->wait_for_master(
            $args{misc_dbh}, $args{dst_dbh}, $args{wait}, $args{timeoutok});
      }

      # Don't lock on destination if it's a replication slave, or the
      # replication thread will not be able to make changes.
      if ( $args{replicate} ) {
         MKDEBUG
            && _d('Not locking destination because syncing via replication');
      }
      else {
         if ( $args{lock} == 3 ) {
            my $sql = 'FLUSH TABLES WITH READ LOCK';
            MKDEBUG && _d($args{dst_dbh}, ',', $sql);
            $args{dst_dbh}->do($sql);
         }
         elsif ( !$args{transaction} ) {
            $self->lock_table($args{dst_dbh}, 'dest',
               $args{quoter}->quote($args{dst_db}, $args{dst_tbl}),
               $args{execute} ? 'WRITE' : 'READ');
         }
      }
   };

   if ( $EVAL_ERROR ) {
      # Must abort/unlock/commit so that we don't interfere with any further
      # tables we try to do.
      if ( $args{src_sth}->{Active} ) {
         $args{src_sth}->finish();
      }
      foreach my $dbh ( @args{qw(src_dbh dst_dbh misc_dbh)} ) {
         next unless $dbh;
         MKDEBUG && _d('Caught error, unlocking/committing on', $dbh);
         $dbh->do('UNLOCK TABLES');
         $dbh->commit() unless $dbh->{AutoCommit};
      }
      # ... and then re-throw the error.
      die $EVAL_ERROR;
   }

   return $result;
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
# End TableSyncer package
# ###########################################################################
