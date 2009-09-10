# This program is copyright 2009 Percona Inc.
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
# SlavePrefetch package $Revision$
# ###########################################################################
package SlavePrefetch;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use List::Util qw(min max sum);
use Time::HiRes qw(gettimeofday);
use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

# Arguments:
#   * dbh                Slave dbh
#   * oktorun            Callback for early termination
#   * callbacks          Arrayref of callbacks to execute valid queries
#   * chk_int            Check interval
#   * chk_min            Minimum check interval
#   * chk_max            Maximum check interval 
#   * datadir            datadir system var
#   * QueryRewriter      Common module
#   * stats_file         (optional) Filename with saved stats
#   * have_subqueries    (optional) bool: Yes if MySQL >= 4.1.0
#   * offset             # The remaining args are equivalent mk-slave-prefetch
#   * window             # options.  Defaults are provided to make testing
#   * io-lag             # easier, so they are technically optional.
#   * query-sample-size  #
#   * max-query-time     #
#   * errors             #
#   * num-prefix         #
#   * print-nonrewritten #
#   * regject-regexp     #
#   * permit-regexp      #
#   * progress           #
sub new {
   my ( $class, %args ) = @_;
   my @required_args = qw(dbh oktorun callbacks chk_int chk_min chk_max
                          datadir QueryRewriter);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   $args{'offset'}            ||= 128;
   $args{'window'}            ||= 4_096;
   $args{'io-lag'}            ||= 1_024;
   $args{'query-sample-size'} ||= 4;
   $args{'max-query-time'}    ||= 1;

   my $self = {
      %args, 
      pos          => 0,
      next         => 0,
      last_ts      => 0,
      slave        => undef,
      n_events     => 0,
      last_chk     => 0,
      stats        => {},
      query_stats  => {},
      query_errors => {},
      callbacks    => {
         show_slave_status => sub {
            my ( $dbh ) = @_;
            return $dbh->selectrow_hashref("SHOW SLAVE STATUS");
         }, 
         wait_for_master   => \&_wait_for_master,
      },
   };

   # Pre-init saved stats from file.
   init_stats($self->{stats}, $args{stats_file}, $args{'query-sample-size'})
      if $args{stats_file};

   return bless $self, $class;
}

sub set_callbacks {
   my ( $self, %callbacks ) = @_;
   foreach my $func ( keys %callbacks ) {
      die "Callback $func does not exist"
         unless exists $self->{callbacks}->{$func};
      $self->{callbacks}->{$func} = $callbacks{$func};
      MKDEBUG && _d('Set new callback for', $func);
   }
   return;
}

sub init_stats {
   my ( $stats, $file, $n_samples ) = @_;
   open my $fh, "<", $file or die $OS_ERROR;
   MKDEBUG && _d('Reading saved stats from', $file);
   my ($type, $rest);
   while ( my $line = <$fh> ) {
      ($type, $rest) = $line =~ m/^# (query|stats): (.*)$/;
      next unless $type;
      if ( $type eq 'query' ) {
         $stats->{$rest} = { seen => 1, samples => [] };
      }
      else {
         my ( $seen, $exec, $sum, $avg )
            = $rest =~ m/seen=(\S+) exec=(\S+) sum=(\S+) avg=(\S+)/;
         if ( $seen ) {
            $stats->{$rest}->{samples}
               = [ map { $avg } (1..$n_samples) ];
            $stats->{$rest}->{avg} = $avg;
         }
      }
   }
   close $fh or die $OS_ERROR;
   return;
}

sub incr_stat {
   my ( $self, $stat ) = @_;
   $self->{stats}->{$stat}++;
   return;
}

sub get_stats {
   my ( $self ) = @_;
   return $self->{stats}, $self->{query_stats}, $self->{query_errors};
}

# Arguments:
#   * tmpdir         Dir for mysqlbinlog --local-load
#   * datadir        (optional) Datadir for file
#   * start_pos      (optional) Start pos for mysqlbinlog --start-pos
#   * file           (optional) Name of the relay log
#   * mysqlbinlog    (optional) mysqlbinlog command (if not in PATH)
sub open_relay_log {
   my ( $self, %args ) = @_;
   my @required_args = qw(tmpdir);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($tmpdir)    = @args{@required_args};
   my $datadir     = $args{datadir}     || $self->{datadir};
   my $start_pos   = $args{start_pos}   || $self->{slave}->{pos};
   my $file        = $args{file}        || $self->{slave}->{file};
   my $mysqlbinlog = $args{mysqlbinlog} || 'mysqlbinlog';

   # Ensure file is readable
   if ( !-r "$datadir/$file" ) {
      die "Relay log $datadir/$file does not exist or is not readable";
   }

   my $cmd = "$mysqlbinlog -l $tmpdir "
           . " --start-pos=$start_pos $datadir/$file"
           . (MKDEBUG ? ' 2>/dev/null' : '');
   MKDEBUG && _d('Opening relay log:', $cmd);

   open my $fh, "$cmd |" or die $OS_ERROR; # Succeeds even on error
   if ( $CHILD_ERROR ) {
      die "$cmd returned exit code " . ($CHILD_ERROR >> 8)
         . '.  Try running the command manually or using MKDEBUG=1' ;
   }
   $self->{cmd} = $cmd;
   $self->{stats}->{mysqlbinlog}++;
   return $fh;
}

sub close_relay_log {
   my ( $self, $fh ) = @_;
   MKDEBUG && _d('Closing relay log');
   # Unfortunately, mysqlbinlog does NOT like me to close the pipe
   # before reading all data from it.  It hangs and prints angry
   # messages about a closed file.  So I'll find the mysqlbinlog
   # process created by the open() and kill it.
   my $procs = `ps -eaf | grep mysqlbinlog | grep -v grep`;
   my $cmd   = $self->{cmd};
   MKDEBUG && _d($procs);
   if ( my ($line) = $procs =~ m/^(.*?\d\s+$cmd)$/m ) {
      chomp $line;
      MKDEBUG && _d($line);
      if ( my ( $proc ) = $line =~ m/(\d+)/ ) {
         MKDEBUG && _d('Will kill process', $proc);
         kill(15, $proc);
      }
   }
   else {
      warn "Cannot find mysqlbinlog command in ps";
   }
   if ( !close($fh) ) {
      if ( $OS_ERROR ) {
         warn "Error closing mysqlbinlog pipe: $OS_ERROR\n";
      }
      else {
         MKDEBUG && _d('Exit status', $CHILD_ERROR,'from mysqlbinlog');
      }
   }
   return;
}

# This is the private interface, called internally to update
# $self->{slave}.  The public interface to return $self->{slave}
# is get_slave_status().
sub _get_slave_status {
   my ( $self, $callback ) = @_;
   $self->{stats}->{show_slave_status}++;

   # Remember to $dbh->{FetchHashKeyName} = 'NAME_lc'.

   my $show_slave_status = $self->{callbacks}->{show_slave_status};
   my $status            = $show_slave_status->($self->{dbh}); 
   if ( !$status || !%$status ) {
      die "No output from SHOW SLAVE STATUS";
   }
   my %status = (
      running => ($status->{slave_sql_running} || '') eq 'Yes',
      file    => $status->{relay_log_file},
      pos     => $status->{relay_log_pos},
                 # If the slave SQL thread is executing from the same log the
                 # I/O thread is reading from, in general (except when the
                 # master or slave starts a new binlog or relay log) we can
                 # tell how many bytes the SQL thread lags the I/O thread.
      lag   => $status->{master_log_file} eq $status->{relay_master_log_file}
             ? $status->{read_master_log_pos} - $status->{exec_master_log_pos}
             : 0,
      mfile => $status->{relay_master_log_file},
      mpos  => $status->{exec_master_log_pos},
   );

   $self->{slave}    = \%status;
   $self->{last_chk} = $self->{n_events};
   MKDEBUG && _d('Slave status:', Dumper($self->{slave}));
   return;
}

# Public interface for returning the current/last slave status.
sub get_slave_status {
   my ( $self ) = @_;
   return $self->{slave};
}

sub slave_is_running {
   my ( $self ) = @_;
   return $self->{slave}->{running};
}

sub get_interval {
   my ( $self ) = @_;
   return $self->{n_events}, $self->{last_chk};
}

sub get_pipeline_pos {
   my ( $self ) = @_;
   return $self->{pos}, $self->{next}, $self->{last_ts};
}

sub set_pipeline_pos {
   my ( $self, $pos, $next, $ts ) = @_;
   die "pos must be >= 0"  unless defined $pos && $pos >= 0;
   die "next must be >= 0" unless defined $pos && $pos >= 0;
   $self->{pos}     = $pos;
   $self->{next}    = $next;
   $self->{last_ts} = $ts || 0;  # undef same as zero
   MKDEBUG && _d('Set pipeline pos', @_);
   return;
}

sub reset_pipeline_pos {
   my ( $self ) = @_;
   $self->{pos}     = 0; # Current position we're reading in relay log.
   $self->{next}    = 0; # Start of next relay log event.
   $self->{last_ts} = 0; # Last seen timestamp.
   MKDEBUG && _d('Reset pipeline');
   return;
}

sub pipeline_event {
   my ( $self, $event ) = @_;

   # Update pos and next.
   $self->{stats}->{events}++;
   $self->{pos}  = $event->{offset} if $event->{offset};
   $self->{next} = max($self->{next}, $self->{pos} + ($event->{end} || 0));
   MKDEBUG && _d('pos:', $self->{pos}, 'next:', $self->{next},
      'slave pos:', $self->{slave}->{pos});

   if ( $self->{progress}
        && $self->{stats}->{events} % $self->{progress} == 0 ) {
      print("# $self->{slave}->{file} $self->{pos} ",
         join(' ', map { "$_:$self->{stats}->{$_}" } keys %{$self->{stats}}),
         "\n");
   }

   # Time to check the slave's status again?
   # TODO: factor this, too
   if ( $self->{pos} > $self->{slave}->{pos}
        && ($self->{n_events} - $self->{last_chk}) >= $self->{chk_int} ) {
      $self->_get_slave_status();
      $self->{chk_int} = $self->{pos} <= $self->{slave_pos}  
         ? max($self->{chk_min}, $self->{chk_int} / 2) # slave caught up to us
         : min($self->{chk_max}, $self->{chk_int} * 2);
   }

   # We're in the window if we're not behind the slave or too far
   # ahead of it.  We can only execute queries while in the window.
   return unless $self->_in_window();

   if ( $event->{arg} ) {
      # If it's a LOAD DATA INFILE, rm the temp file.
      # TODO: maybe this should still be before _in_window()?
      if ( my ($file) = $event->{arg} =~ m/INFILE ('[^']+')/i ) {
         $self->{stats}->{load_data_infile}++;
         if ( !unlink($file) ) {
            MKDEBUG && _d('Could not unlink', $file);
            $self->{stats}->{could_not_unlink}++;
         }
         return;
      }

      my ($query, $fingerprint) = prepare_query($event->{arg});
      if ( !$query ) {
         MKDEBUG && _d('Failed to prepare query, skipping');
         return;
      }

      # Do it!
      $self->{stats}->{do_query}++;
      foreach my $callback ( @{$self->{callbacks}} ) {
         $callback->($query, $fingerprint);
      }
   }

   return;
}

sub get_window {
   my ( $self ) = @_;
   return $self->{offset}, $self->{window};
}

sub set_window {
   my ( $self, $offset, $window ) = @_;
   die "offset must be > 0" unless $offset;
   die "window must be > 0" unless $window;
   $self->{offset} = $offset;
   $self->{window} = $window;
   MKDEBUG && _d('Set window', @_);
   return;
}

# Returns false if the current pos is out of the window,
# else returns true.  This "throttles" pipeline_event()
# so that it only executes queries when we're in the window.
sub _in_window {
   my ( $self ) = @_;

   # We're behind the slave which is bad because we're no
   # longer prefetching.  We need to stop pipelining events
   # and start skipping them until we're back in the window
   # or ahead of the slave.
   return 0 unless $self->_far_enough_ahead();

   # We're ahead of the slave, but check that we're not too
   # far ahead, i.e. out of the window or too close to the end
   # of the binlog.  If we are, wait for the slave to catch up
   # then go back to pipelining events.
   my $wait_for_master = $self->{callbacks}->{wait_for_master};
   while ( $self->{oktorun}->(only_if_slave_is_running => 1,
                              slave_is_running => $self->slave_is_running())
           && ($self->_too_far_ahead() || $self->_too_close_to_io()) )
   {
      # Don't increment stats if the slave didn't catch up while we
      # slept.
      my %wait_args       = (
         dbh       => $self->{dbh},
         mfile     => $self->{slave}->{mfile},
         mpos      => $self->{slave}->{mpos},
         until_pos => $self->{pos} - $self->{window} + 1, 
         slave_pos => $self->{slave}->{pos},
      );
      $self->{stats}->{master_pos_wait}++;
      if ( $wait_for_master->(%wait_args) > 0 ) {
         if ( $self->_too_far_ahead() ) {
            MKDEBUG && _d('Event', $self->{pos}, 'too far ahead of',
               $self->{slave}->{pos});
            $self->{stats}->{too_far_ahead}++;
         }
         elsif ( $self->_too_close_to_io() ) {
            MKDEBUG && _d('Event', $self->{pos}, 'too close to I/O thread',
                          '(', $self->{slave}->{pos}, '+',
                          $self->{slave}->{lag}, ')');
            $self->{stats}->{too_close_to_io_thread}++;
         }
      }
      else {
         MKDEBUG && _d('SQL thread did not advance');
      }
      $self->_get_slave_status();
   }

   return 1;
}

# Whether we are slave pos+offset ahead of the slave.
sub _far_enough_ahead {
   my ( $self ) = @_;
   if ( $self->{pos} < $self->{slave}->{pos} + $self->{offset} ) {
      MKDEBUG && _d($self->{pos}, 'is not',
         $self->{offset}, 'ahead of', $self->{slave}->{pos});
      $self->{stats}->{not_far_enough_ahead}++;
      return 0;
   }
   return 1;
}

# Whether we are slave pos+offset+window ahead of the slave.
sub _too_far_ahead {
   my ( $self ) = @_;
   return $self->{pos}
      > $self->{slave}->{pos} + $self->{offset} + $self->{window} ? 1 : 0;
}

# Whether we are too close to where the I/O thread is writing.
sub _too_close_to_io {
   my ( $self ) = @_;
   return $self->{slave}->{lag}
      && $self->{pos}
         >= $self->{slave}->{pos} + $self->{slave}->{lag} - $self->{'io-lag'};
}

sub _wait_for_master {
   my ( %args ) = @_;
   my @required_args = qw(dbh mfile mpos until_pos slave_pos);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($dbh, $mfile, $mpos, $until_pos, $slave_pos) = @args{@required_args};
   my $sql = "SELECT COALESCE(MASTER_POS_WAIT('$mfile', "
      . $mpos + ($until_pos - $slave_pos)
      . ", 1), 0)";
   MKDEBUG && _d('Waiting for master:', $sql);
   my $start = gettimeofday();
   my ($events) = $dbh->selectrow_array($sql);
   MKDEBUG && _d('Waited', (gettimeofday - $start), 'and got', $events);
   return $events;
}

# Does everything necessary to make the given DMS query ready for
# pipelined execution in pipeline_event() if the query can/should
# be executed.  If yes, then the prepared query and its fingerprint
# are returned; else nothing is returned.
sub prepare_query {
   my ( $self, $query ) = @_;
   my $qr = $self->{QueryRewriter};

   $query = $qr->strip_comments($query);

   return unless $self->query_is_allowed($query);

   # If the event is SET TIMESTAMP and we've already set the
   # timestamp to that value, skip it.
   if ( (my ($new_ts) = $query =~ m/SET TIMESTAMP=(\d+)/) ) {
      if ( $new_ts == $self->{last_ts} ) {
         MKDEBUG && _d('Already saw timestamp', $new_ts);
         $self->{stats}->{same_timestamp}++;
         return;
      }
      else {
         $self->{last_ts} = $new_ts;
      }
   }

   my $select = $qr->convert_to_select($query);
   if ( $select !~ m/\A\s*(?:set|select|use)/i ) {
      MKDEBUG && _d('Cannot rewrite query as SELECT');
      _d($query) if $self->{'print-nonrewritten'};
      $self->{stats}->{query_not_rewritten}++;
   }

   my $fingerprint = $qr->fingerprint(
      $select,
      { prefixes => $self->{'num-prefix'} }
   );

   if ((my $avg = $self->__get_avg($fingerprint))>=$self->{'max-query-time'}) {
      # The query's average execution time is longer than the
      # specified limit, so we skip it and just wait for the
      # master to pass it by.
      MKDEBUG && _d('Avg time', $avg, 'too long for', $fingerprint);
      $self->{stats}->{query_too_long}++;
      my $wait_for_master = $self->{callbacks}->{wait_for_master};
      my %wait_args       = (
         dbh       => $self->{dbh},
         mfile     => $self->{slave}->{mfile},
         mpos      => $self->{slave}->{mpos},
         until_pos => $self->{pos} + 1,
         slave_pos => $self->{slave}->{pos},
      );
      $self->{stats}->{master_pos_wait}++;
      $wait_for_master->(%wait_args);
      $self->_get_slave_status();
      return;
   }

   # Safeguard as much as possible against enormous result sets.
   $select = $qr->convert_select_list($select);
   if ( $self->{have_subqueries}
        && !$self->__have_seen_query($fingerprint) ) {
      # Wrap in a "derived table," but only if it hasn't been
      # seen before.  This way, really short queries avoid the
      # overhead of creating the temp table.
      $select = $qr->wrap_in_derived($select);
   }

   # Success: the prepared and converted query ready to execute.
   return $select, $fingerprint;
}

sub query_is_allowed {
   my ( $self, $query ) = @_;
   return unless $query;
   if ( $query =~ m/\A\s*(?:set [t@]|use|insert|update|delete|replace)/i ) {
      my $reject_regexp = $self->{reject_regexp};
      my $permit_regexp = $self->{permit_regexp};
      if ( ($reject_regexp && $query =~ m/$reject_regexp/o)
           || ($permit_regexp && $query !~ m/$permit_regexp/o) )
      {
         MKDEBUG && _d('Query is not allowed, fails permit/reject regexp');
         $self->{stats}->{event_filtered_out}++;
         return 0;
      }
      return 1;
   }
   MKDEBUG && _d('Query is not allowed, wrong type');
   $self->{stats}->{event_not_allowed}++;
   return 0;
}

sub exec {
   my ( $self, $query, $fingerprint ) = @_;
   eval {
      my $start = gettimeofday();
      $self->{dbh}->do($query);
      $self->__store_avg($fingerprint, gettimeofday() - $start);
   };
   if ( $EVAL_ERROR ) {
      $self->{stats}->{query_error}++;
      if ( (($self->{errors} || 0) == 2) || MKDEBUG ) {
         _d($EVAL_ERROR);
         _d('SQL was:', $query);
      }
      elsif ( ($self->{errors} || 0) == 1 ) {
         $self->{query_errors}->{$fingerprint}++;
      }
   }
   return;
}

# The average is weighted so we don't quit trying a statement when we have
# only a few samples.  So if we want to collect 16 samples and the first one
# is huge, it will be weighted as 1/16th of its size.
sub __store_avg {
   my ( $self, $query, $time ) = @_;
   MKDEBUG && _d('Execution time:', $query, $time);
   my $query_stats = $self->{query_stats}->{$query};
   my $samples     = $query_stats->{samples} ||= [];
   push @$samples, $time;
   if ( @$samples > $self->{'query-sample-size'} ) {
      shift @$samples;
   }
   $query_stats->{avg} = sum(@$samples) / $self->{'query-sample-size'};
   $query_stats->{exec}++;
   $query_stats->{sum} += $time;
   MKDEBUG && _d('Average time:', $query_stats->{avg});
   return;
}

sub __have_seen_query {
   my ( $self, $query ) = @_;
   return $self->{query_stats}->{$query}->{seen};
}

sub __get_avg {
   my ( $self, $query ) = @_;
   $self->{query_stats}->{$query}->{seen}++;
   return $self->{query_stats}->{$query}->{avg} || 0;
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
# End SlavePrefetch package
# ###########################################################################
