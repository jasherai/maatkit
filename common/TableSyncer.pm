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
# TableSyncer package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package TableSyncer;

use English qw(-no_match_vars);

our %ALGOS = map { lc $_ => $_ } qw(Stream Chunk Nibble);

sub new {
   bless {}, shift;
}

# Choose the best algorithm for syncing a given table.
sub best_algorithm {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(tbl_struct parser nibbler chunker) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $result;

   # See if Chunker says it can handle the table
   my ($exact, $cols) = $args{chunker}
      ->find_chunk_columns($args{tbl_struct}, { exact => 1 });
   if ( $exact ) {
      $ENV{MKDEBUG} && _d("Chunker says $cols->[0] supports chunking exactly");
      $result = 'Chunk';
      # If Chunker can handle it OK, but not with exact chunk sizes, it means
      # it's using only the first column of a multi-column index, which could
      # be really bad.  It's better to use Nibble for these, because at least
      # it can reliably select a chunk of rows of the desired size.
   }
   else {
      # If there's an index, $nibbler->generate_asc_stmt() will use it, so it
      # is an indication that the nibble algorithm will work.
      my ($idx) = $args{parser}->find_best_index($args{tbl_struct});
      if ( $idx ) {
         $ENV{MKDEBUG} && _d("Parser found best index $idx, so Nibbler will work");
         $result = 'Nibble';
      }
      else {
         # If not, Stream is the only choice.
         $ENV{MKDEBUG} && _d("No primary or unique non-null key in table");
         $result = 'Stream';
      }
   }
   $ENV{MKDEBUG} && _d("Algorithm: $result");
   return $result;
}

sub sync_table {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(
      buffer checksum chunker chunksize dst_db dst_dbh dst_tbl execute lock
      misc_dbh quoter replace replicate src_db src_dbh src_tbl test tbl_struct
      timeoutok transaction versionparser wait where possible_keys cols
      nibbler parser master_slave func) )
   {
      die "I need a $arg argument" unless defined $args{$arg};
   }
   $ENV{MKDEBUG} && _d("Syncing table with args "
      . join(', ',
         map { "$_=" . (defined $args{$_} ? $args{$_} : 'undef') }
         sort keys %args));

   # TODO: for two-way sync, the change handler needs both DBHs.
   # Check permissions on writable tables (TODO: 2-way needs to check both)
   my $update_func;
   my $change_dbh;
   if ( $args{execute} ) {
      if ( $args{replicate} ) {
         $change_dbh = $args{src_dbh};
         $self->check_permissions(@args{qw(src_dbh src_db src_tbl quoter)});
      }
      else {
         $change_dbh = $args{dst_dbh};
         $self->check_permissions(@args{qw(dst_dbh dst_db dst_tbl quoter)});
      }
      $ENV{MKDEBUG} && _d('Will make changes via ' . $change_dbh);
      $update_func = sub {  map { $change_dbh->do($_) } @_ };
   }

   my $ch = new ChangeHandler(
      queue     => $args{buffer} ? 0 : 1,
      quoter    => $args{quoter},
      database  => $args{dst_db},
      table     => $args{dst_tbl},
      sdatabase => $args{src_db},
      stable    => $args{src_tbl},
      replace   => $args{replace} || $args{replicate},
      actions   => [
         ( $update_func ? $update_func            : () ),
         # Print AFTER executing, so the print isn't misleading in case of an
         # index violation etc that doesn't actually get executed.
         ( $args{print} ? sub { print @_, ";\n" } : () ),
      ],
   );
   my $rd = new RowDiff( dbh => $args{misc_dbh} );

   $args{algorithm} ||= $self->best_algorithm(
      map { $_ => $args{$_} } qw(tbl_struct parser nibbler chunker));

   if ( !$ALGOS{ lc $args{algorithm} } ) {
      die "No such algorithm $args{algorithm}; try one of "
         . join(', ', values %ALGOS) . "\n";
   }
   $args{algorithm} = $ALGOS{ lc $args{algorithm} };

   if ( $args{test} ) {
      return ($ch->get_changes(), ALGORITHM => $args{algorithm});
   }

   my $class  = "TableSync$args{algorithm}";
   my $plugin = $class->new(
      handler   => $ch,
      cols      => $args{cols},
      dbh       => $args{src_dbh},
      database  => $args{src_db},
      table     => $args{src_tbl},
      chunker   => $args{chunker},
      nibbler   => $args{nibbler},
      parser    => $args{parser},
      struct    => $args{tbl_struct},
      checksum  => $args{checksum},
      vp        => $args{versionparser},
      quoter    => $args{quoter},
      chunksize => $args{chunksize},
      where     => $args{where},
      possible_keys => [],
      versionparser => $args{versionparser},
      func          => $args{func},
   );

   $self->lock_and_wait(%args, lock_level => 2);

   my $cycle = 0;
   while ( !$plugin->done ) {

      # Do as much of the work as possible before opening a transaction or
      # locking the tables.
      $ENV{MKDEBUG} && _d("Beginning sync cycle $cycle");
      my $src_sql = $plugin->get_sql(
         quoter   => $args{quoter},
         database => $args{src_db},
         table    => $args{src_tbl},
         where    => $args{where},
      );
      my $dst_sql = $plugin->get_sql(
         quoter   => $args{quoter},
         database => $args{dst_db},
         table    => $args{dst_tbl},
         where    => $args{where},
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
      $plugin->prepare($args{src_dbh});
      $plugin->prepare($args{dst_dbh});
      $ENV{MKDEBUG} && _d("src: " . $src_sql);
      $ENV{MKDEBUG} && _d("dst: " . $dst_sql);
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
      $ENV{MKDEBUG} && _d("Finished sync cycle $cycle");
      $ch->process_rows(1);

      $cycle++;
   }

   $ch->process_rows();

   $self->unlock(%args, lock_level => 2);

   return ($ch->get_changes(), ALGORITHM => $args{algorithm});
}

sub check_permissions {
   my ( $self, $dbh, $db, $tbl, $quoter ) = @_;
   my $db_tbl = $quoter->quote($db, $tbl);
   my $sql = "REPLACE INTO $db_tbl SELECT * FROM $db_tbl LIMIT 0";
   $ENV{MKDEBUG} && _d('Permissions check: ', $sql);
   $dbh->do($sql);
}

sub lock_table {
   my ( $self, $dbh, $where, $db_tbl, $mode ) = @_;
   my $query = "LOCK TABLES $db_tbl $mode";
   $ENV{MKDEBUG} && _d($query);
   $dbh->do($query);
   $ENV{MKDEBUG} && _d("Acquired table lock on $where in $mode mode");
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
         $ENV{MKDEBUG} && _d("Committing $dbh");
         $dbh->commit;
      }
      else {
         my $sql = 'UNLOCK TABLES';
         $ENV{MKDEBUG} && _d($dbh, $sql);
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
         $ENV{MKDEBUG} && _d("Committing $dbh");
         $dbh->commit;
      }
      else {
         my $sql = 'UNLOCK TABLES';
         $ENV{MKDEBUG} && _d($dbh, $sql);
         $dbh->do($sql);
      }
   }

   # User wants us to lock for consistency.  But lock only on source initially;
   # might have to wait for the slave to catch up before locking on the dest.
   if ( $args{lock} == 3 ) {
      my $sql = 'FLUSH TABLES WITH READ LOCK';
      $ENV{MKDEBUG} && _d("$args{src_dbh}, $sql");
      $args{src_dbh}->do($sql);
   }
   else {
      if ( $args{transaction} ) {
         if ( $args{src_sth} ) {
            # Execute the $src_sth on the source, so LOCK IN SHARE MODE/FOR
            # UPDATE will lock the rows examined.
            $ENV{MKDEBUG} && _d('Executing statement on source to lock rows');
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

   if ( $args{wait} ) {
      # Always use the $misc_dbh dbh to check the master's position, because
      # the $src_dbh might be in use due to executing $src_sth.
      $args{master_slave}->wait_for_master(
         $args{misc_dbh}, $args{dst_dbh}, $args{wait}, $args{timeoutok});
   }

   # Don't lock on destination if it's a replication slave, or the replication
   # thread will not be able to make changes.
   if ( $args{replicate} ) {
      $ENV{MKDEBUG}
         && _d('Not locking destination because syncing via replication');
   }
   else {
      if ( $args{lock} == 3 ) {
         my $sql = 'FLUSH TABLES WITH READ LOCK';
         $ENV{MKDEBUG} && _d("$args{dst_dbh}, $sql");
         $args{dst_dbh}->do($sql);
      }
      elsif ( !$args{transaction} ) {
         $self->lock_table($args{dst_dbh}, 'dest',
            $args{quoter}->quote($args{dst_db}, $args{dst_tbl}),
            $args{execute} ? 'WRITE' : 'READ');
      }
   }

   return $result;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# TableSyncer:$line ", @_, "\n";
}

1;

# ###########################################################################
# End TableSyncer package
# ###########################################################################
