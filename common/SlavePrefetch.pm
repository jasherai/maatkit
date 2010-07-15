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

use constant MKDEBUG => $ENV{MKDEBUG} || 0;

# Arguments:
#   * dbh                dbh: slave
#   * oktorun            coderef: callback to terminate when waiting for window
#   * chk_int            scalar: check interval
#   * chk_min            scalar: minimum check interval
#   * chk_max            scalar: maximum check interval 
#   * QueryRewriter      obj
# Optional arguments:
#   * TableParser        obj: allows rewrite_query() to rewrite more
#   * QueryParser        obj: allows rewrite_query() to rewrite more
#   * Quoter             obj: allows rewrite_query() to rewrite more
#   * mysqlbinlog        scalar: mysqlbinlog command
#   * stats              hashref: stats counter
#   * stats_file         scalar filename with saved stats
#   * have_subqueries    bool: yes if MySQL >= 4.1.0
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
   my @required_args = qw(dbh oktorun chk_int chk_min chk_max QueryRewriter);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   my $self = {
      # Defaults
      offset              => 128,
      window              => 4_096,
      'io-lag'            => 1_024,
      'query-sample-size' => 4,
      'max-query-time'    => 1,
      mysqlbinlog         => 'mysqlbinlog',

      # Override defaults
      %args,

      # Private variables
      pos          => 0,
      next         => 0,
      last_ts      => 0,
      slave        => undef,
      last_chk     => 0,
      query_stats  => {},
      query_errors => {},
      tbl_cols     => {},
      callbacks    => {
         show_slave_status => sub {
            my ( $dbh ) = @_;
            return $dbh->selectrow_hashref("SHOW SLAVE STATUS");
         }, 
         use_db            => sub {
            my ( $dbh, $db ) = @_;
            eval {
               MKDEBUG && _d('USE', $db);
               $dbh->do("USE `$db`");
            };
            MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
            return;
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

sub get_stats {
   my ( $self ) = @_;
   return $self->{stats}, $self->{query_stats}, $self->{query_errors};
}

sub reset_stats {
   my ( $self, %args ) = @_;
   $self->{stats} = { events => 0, } if $args{all} || $args{stats};
   $self->{query_stats}  = {}        if $args{all} || $args{query_stats};
   $self->{query_errors} = {}        if $args{all} || $args{query_errors};
   return;
}


# Arguments:
#   * relay_log      scalar: full /path/relay-log file name
# Optional arguments:
#   * tmpdir         (optional) dir for mysqlbinlog --local-load
#   * start_pos      (optional) start pos for mysqlbinlog --start-pos
sub open_relay_log {
   my ( $self, %args ) = @_;
   foreach my $arg ( qw(relay_log) ) {
      die "I need a $arg argument" unless $args{$arg};
   }

   # Ensure file is readable
   if ( !-r $args{relay_log} ) {
      die "Relay log $args{relay_log} does not exist or is not readable";
   }

   my $cmd = $self->_mysqlbinlog_cmd(%args);

   open my $fh, "$cmd |" or die $OS_ERROR; # Succeeds even on error
   if ( $CHILD_ERROR >> 8 ) {
      die "$cmd returned exit code " . ($CHILD_ERROR >> 8)
         . '.  Try running the command manually or using MKDEBUG=1' ;
   }
   $self->{cmd} = $cmd;
   $self->{stats}->{mysqlbinlog}++;
   return $fh;
}

sub _mysqlbinlog_cmd {
   my ( $self, %args ) = @_;
   my $cmd = $self->{mysqlbinlog}
           . ($args{tmpdir}    ? " --local-load=$args{tmpdir} "   : '')
           . ($args{start_pos} ? " --start-pos=$args{start_pos} " : '')
           . $args{relay_log}
           . (MKDEBUG ? ' 2>/dev/null' : '');
   MKDEBUG && _d($cmd);
   return $cmd;
}

# The $pid arg is in hopes that some day I can test this.
# See SlavePrefetch.t for why it's not testable right now.
sub close_relay_log {
   my ( $self, $fh, $pid ) = @_;
   MKDEBUG && _d('Closing relay log');

   # Unfortunately, mysqlbinlog does NOT like me to close the pipe
   # before reading all data from it.  It hangs and prints angry
   # messages about a closed file.  So I'll find the mysqlbinlog
   # process created by the open() and kill it.
   if ( !$pid ) {
      my $procs = `ps -eaf | grep mysqlbinlog | grep -v grep`;
      my $cmd   = $self->{cmd};
      MKDEBUG && _d($procs);
      if ( $procs ) {
         if ( my ($line) = $procs =~ m/^(.*?\d\s+$cmd)$/m ) {
            chomp $line;
            MKDEBUG && _d("mysqlbinlog process:", $line);
            ($pid) = $line =~ m/(\d+)/;
         }
      }
      else {
         warn "Cannot find mysqlbinlog process in ps";
      }
   }

   if ( $pid ) {
      MKDEBUG && _d('Killing mysqlbinlog pid:', $pid);
      kill(15, $pid);
   }
   else {
      warn "Cannot determine mysqlbinlog PID";
   }

   close $fh;
   MKDEBUG && _d('mysqlbinlog exit status:', $CHILD_ERROR >> 8);
   warn "Error closing mysqlbinlog pipe: $OS_ERROR" if $OS_ERROR;

   return;
}

# Returns true if it's time to _get_slave_status() again.
sub _check_slave_status {
   my ( $self ) = @_;
   return 1 unless defined $self->{slave};
   return
      $self->{pos} > $self->{slave}->{pos}
      && ($self->{stats}->{events} - $self->{last_chk}) >= $self->{chk_int}
         ? 1 : 0;
}

# Returns the next check interval.
sub _get_next_chk_int {
   my ( $self ) = @_;
   if ( $self->{pos} <= $self->{slave}->{pos} ) {
      # The slave caught up to us so do another check sooner than usual.
      return max($self->{chk_min}, $self->{chk_int} / 2);
   }
   else {
      # We're ahead of the slave so wait a little longer until the next check.
      return min($self->{chk_max}, $self->{chk_int} * 2);
   }
}

# This is the private interface, called internally to update
# $self->{slave}.  The public interface to return $self->{slave}
# is get_slave_status().
sub _get_slave_status {
   my ( $self ) = @_;
   $self->{stats}->{show_slave_status}++;

   # Remember to $dbh->{FetchHashKeyName} = 'NAME_lc'.

   my $show_slave_status = $self->{callbacks}->{show_slave_status};
   my $status            = $show_slave_status->($self->{dbh}); 
   if ( !$status || !%$status ) {
      die "No output from SHOW SLAVE STATUS";
   }
   my %status = (
      running => ($status->{slave_sql_running} || '') eq 'Yes' ? 1 : 0,
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
   $self->{last_chk} = $self->{stats}->{events};
   MKDEBUG && _d('Slave status:', Dumper($self->{slave}));
   return;
}

# Public interface for returning the current/last slave status.
sub get_slave_status {
   my ( $self ) = @_;
   $self->_get_slave_status();
   return $self->{slave};
}

sub slave_is_running {
   my ( $self, $dbh ) = @_;
   $self->_get_slave_status() unless defined $self->{slave};
   return $self->{slave}->{running};
}

sub get_interval {
   my ( $self ) = @_;
   return $self->{stats}->{events}, $self->{last_chk};
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

# Check if we're in the "window".  If yes, returns the event; if no,
# returns nothing.  This is the public interface; _in_window() should
# not be called directly.
sub in_window {
   my ( $self, %args ) = @_;
   my ($event, $oktorun) = @args{qw(event oktorun)};

   # The caller must incr stats->events!  We use this to determine
   # if it's time to check the slave's status again.

   if ( !$event->{offset} ) {
      # This will happen for start/end of log stuff like:
      #   End of log file
      #   ROLLBACK /* added by mysqlbinlog */;
      #   /*!50003 SET COMPLETION_TYPE=@OLD_COMPLETION_TYPE*/;
      MKDEBUG && _d('Event has no offset, skipping');
      $self->{stats}->{no_offset}++;
      return;
   }

   # Update pos and next.
   $self->{pos}  = $event->{offset} if $event->{offset};
   $self->{next} = max($self->{next},$self->{pos}+($event->{end_log_pos} || 0));

   if ( $self->{progress}
        && $self->{stats}->{events} % $self->{progress} == 0 ) {
      print("# $self->{slave}->{file} $self->{pos} ",
         join(' ', map { "$_:$self->{stats}->{$_}" } keys %{$self->{stats}}),
         "\n");
   }

   # Time to check the slave's status again?
   if ( $self->_check_slave_status() ) { 
      MKDEBUG && _d('Checking slave status at interval',
         $self->{stats}->{events});
      my $current_relay_log = $self->{slave}->{file};
      $self->_get_slave_status();
      if (    $current_relay_log
           && $current_relay_log ne $self->{slave}->{file} ) {
         MKDEBUG && _d('Relay log file has changed from',
            $current_relay_log, 'to', $self->{slave}->{file});
         $self->reset_pipeline_pos();
         $args{oktorun}->(0) if $args{oktorun};
         return;
      }
      $self->{chk_int} = $self->_get_next_chk_int();
      MKDEBUG && _d('Next check interval:', $self->{chk_int});
   }

   # We're in the window if we're not behind the slave or too far
   # ahead of it.  We can only execute queries while in the window.
   return $event if $self->_in_window();
}

# Checks, prepares and rewrites the event's arg to a SELECT.
# If successful, returns the event with the original arg replaced
# with the SELECT query (and the original arg saved as "arg_original");
# else returns nothing.
sub rewrite_query { 
   my ( $self, $event, %args ) = @_;

   if ( !$event->{arg} ) {
      # The caller shouldn't give us an arg-less event, but just in case...
      $self->{stats}->{no_arg}++;
      return;
   }

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

   my ($query, $fingerprint) = $self->prepare_query($event->{arg});

   # Maybe rewrite failed INSERT|REPLACE by injecting missing columns list.
   # http://code.google.com/p/maatkit/issues/detail?id=1003
   if ( !$query
        && $event->{arg} =~ m/^INSERT|REPLACE/i
        && $self->{TableParser}
        && $self->{QueryParser} )
   {
      my $new_arg = $self->inject_columns_list($event->{arg}, %args);
      return unless $new_arg;
      $event->{arg} = $new_arg;
      return $self->rewrite_query($event);
   }

   if ( !$query ) {
      MKDEBUG && _d('Failed to prepare query, skipping');
      return;
   }
   $event->{arg_original} = $event->{arg};
   $event->{arg}          = $query;  # SELECT query
   $event->{fingerprint}  = $fingerprint;

   return $event;
}

sub inject_columns_list {
   my ( $self, $query, %args ) = @_; 
   my $tp   = $self->{TableParser};
   my $qp   = $self->{QueryParser};
   my $q    = $self->{Quoter};
   my $dbh  = $self->{dbh};
   return unless $tp && $qp;
   MKDEBUG && _d('Attempting to inject columns list into query');

   my $default_db = $args{default_db};

   my @tbls = $qp->get_tables($query);
   if ( !@tbls ) {
      MKDEBUG && _d("Can't get tables from query");
      return;
   }
   if ( @tbls > 1 ) {
      MKDEBUG && _d("Query has more than one table");
      return;
   }

   if ( $q ) {
      my ($db, $tbl) = $q->split_unquote($tbls[0]);
      if ( !$db && $default_db ) {
         MKDEBUG && _d('Using default db:', $default_db);
         $tbls[0] = "$default_db.$tbl";
      }
   }

   my $tbl_cols = $self->{tbl_cols}->{$tbls[0]};
   if ( !$tbl_cols ) {
      my $sql = "SHOW CREATE TABLE $tbls[0]";
      MKDEBUG && _d($sql);
      eval {
         my $show_create = $dbh->selectrow_arrayref($sql)->[1];
         if ( !$show_create ) {
            MKDEBUG && _d("Failed to", $sql);
            return;
         }
         my $tbl_struct = $tp->parse($show_create);
         if ( !$tbl_struct ) {
            MKDEBUG && _d("Failed to parse table struct");
            return;
         }
         $tbl_cols = join(',', map { "`$_`" } @{$tbl_struct->{cols}});
         $self->{tbl_cols}->{$tbls[0]} = $tbl_cols;
      };
      if ( $EVAL_ERROR ) {
         MKDEBUG && _d($EVAL_ERROR);
         return;
      }
   }
   else {
      MKDEBUG && _d('Using cached columns for', $tbls[0]);
   }

   if ( !($query =~ s/ VALUES?/ ($tbl_cols) VALUES/i) ) {
      MKDEBUG && _d("Failed to inject columns list");
      return;
   }

   MKDEBUG && _d('Successfully inject columns list:',
      substr($query, 0, 100), '...');

   return $query;
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

# Returns false if the current pos is out of the window, else returns true.
# The window is a throttle (if the caller chooses to use it).  This is a
# private method called by in_window(); it should not be called directly.
sub _in_window {
   my ( $self ) = @_;
   MKDEBUG && _d('Checking window, pos:', $self->{pos},
      'next', $self->{next},
      'slave pos:', $self->{slave}->{pos},
      'master pos', $self->{slave}->{mpos});

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
   my %wait_args       = (
      dbh       => $self->{dbh},
      mfile     => $self->{slave}->{mfile},
      until_pos => $self->next_window(),
   );

   my $oktorun = $self->{oktorun};
   while ( $oktorun->()
           && $self->{slave}->{running}
           && ($self->_too_far_ahead() || $self->_too_close_to_io()) ) {
      # Don't increment stats if the slave didn't catch up while we
      # slept.
      $self->{stats}->{master_pos_wait}++;
      if ( $wait_for_master->(%wait_args) > 0 ) {
         if ( $self->_too_far_ahead() ) {
            $self->{stats}->{too_far_ahead}++;
         }
         elsif ( $self->_too_close_to_io() ) {
            $self->{stats}->{too_close_to_io_thread}++;
         }
      }
      else {
         MKDEBUG && _d('SQL thread did not advance');
      }
      $self->_get_slave_status();
   }

   if (     $self->{slave}->{running}
        &&  $self->_far_enough_ahead()
        && !$self->_too_far_ahead()
        && !$self->_too_close_to_io() )
   {
      MKDEBUG && _d('Event', $self->{stats}->{events}, 'is in the window');
      return 1;
   }

   MKDEBUG && _d('Event', $self->{stats}->{events}, 'is not in the window');
   return 0;
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
   my $too_far =
      $self->{pos}
         > $self->{slave}->{pos} + $self->{offset} + $self->{window} ? 1 : 0;
   MKDEBUG && _d('pos', $self->{pos}, 'too far ahead of',
      'slave pos', $self->{slave}->{pos}, ':', $too_far ? 'yes' : 'no');
   return $too_far;
}

# Whether we are too close to where the I/O thread is writing.
sub _too_close_to_io {
   my ( $self ) = @_;
   my $too_close= $self->{slave}->{lag}
      && $self->{pos}
         >= $self->{slave}->{pos} + $self->{slave}->{lag} - $self->{'io-lag'};
   MKDEBUG && _d('pos', $self->{pos},
      'too close to I/O thread pos', $self->{slave}->{pos}, '+',
      $self->{slave}->{lag}, ':', $too_close ? 'yes' : 'no');
   return $too_close;
}

sub _wait_for_master {
   my ( %args ) = @_;
   my @required_args = qw(dbh mfile until_pos);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $timeout = $args{timeout} || 1;
   my ($dbh, $mfile, $until_pos) = @args{@required_args};
   my $sql = "SELECT COALESCE(MASTER_POS_WAIT('$mfile',$until_pos,$timeout),0)";
   MKDEBUG && _d('Waiting for master:', $sql);
   my $start = gettimeofday();
   my ($events) = $dbh->selectrow_array($sql);
   MKDEBUG && _d('Waited', (gettimeofday - $start), 'and got', $events);
   return $events;
}

# The next window is pos-offset, assuming that master/slave pos
# are behind pos.  If we get too far ahead, we need to wait until
# the slave is right behind us.  The closest it can get is offset
# bytes behind us, thus pos-offset.  However, the return value is
# in terms of master pos because this is what MASTER_POS_WAIT()
# expects.
sub next_window {
   my ( $self ) = @_;
   my $next_window = 
         $self->{slave}->{mpos}                    # master pos
         + ($self->{pos} - $self->{slave}->{pos})  # how far we're ahead
         - $self->{offset};                        # offset;
   MKDEBUG && _d('Next window, master pos:', $self->{slave}->{mpos},
      'next window:', $next_window,
      'bytes left:', $next_window - $self->{offset} - $self->{slave}->{mpos});
   return $next_window;
}

# Does everything necessary to make the given DMS query ready for
# execution as a SELECT.  If successful, the prepared query and its
# fingerprint are returned; else nothing is returned.
sub prepare_query {
   my ( $self, $query ) = @_;
   my $qr = $self->{QueryRewriter};

   $query = $qr->strip_comments($query);

   return unless $self->query_is_allowed($query);

   # If the event is SET TIMESTAMP and we've already set the
   # timestamp to that value, skip it.
   if ( (my ($new_ts) = $query =~ m/SET timestamp=(\d+)/) ) {
      MKDEBUG && _d('timestamp query:', $query);
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
      MKDEBUG && _d('Cannot rewrite query as SELECT:',
         (length $query > 240 ? substr($query, 0, 237) . '...' : $query));
      _d("Not rewritten: $query") if $self->{'print-nonrewritten'};
      $self->{stats}->{query_not_rewritten}++;
      return;
   }

   my $fingerprint = $qr->fingerprint(
      $select,
      { prefixes => $self->{'num-prefix'} }
   );

   # If the query's average execution time is longer than the specified
   # limit, we wait for the slave to execute it then skip it ourself.
   # We do *not* want to skip it and continue pipelining events because
   # the caches that we would warm while executing ahead of the slave
   # would become cold once the slave hits this slow query and stalls.
   # In general, we want to always be just a little ahead of the slave
   # so it executes in the warmth of our pipelining wake.
   if ((my $avg = $self->get_avg($fingerprint)) >= $self->{'max-query-time'}) {
      MKDEBUG && _d('Avg time', $avg, 'too long for', $fingerprint);
      $self->{stats}->{query_too_long}++;
      return $self->_wait_skip_query($avg);
   }

   # Safeguard as much as possible against enormous result sets.
   $select = $qr->convert_select_list($select);

   # The following block is/was meant to prevent huge insert/select queries
   # from slowing us, and maybe the network, down by wrapping the query like
   # select 1 from (<query>) as x limit 1.  This way, the huge result set of
   # the query is not transmitted but the query itself is still executed.
   # If someone has a similar problem, we can re-enable (and fix) this block.
   # The bug here is that by this point the query is already seen so the if()
   # is always false.
   # if ( $self->{have_subqueries} && !$self->have_seen($fingerprint) ) {
   #    # Wrap in a "derived table," but only if it hasn't been
   #    # seen before.  This way, really short queries avoid the
   #    # overhead of creating the temp table.
   #    # $select = $qr->wrap_in_derived($select);
   # }

   # Success: the prepared and converted query ready to execute.
   return $select, $fingerprint;
}

# Waits for the slave to catch up, execute the query at our current
# pos, and then move on.  This is usually used to wait-skip slow queries,
# so the wait arg is important.  If a slow query takes 3 seconds, and
# it takes the slave another 1 second to reach our pos, then we can
# either wait_for_master 4 times (1s each) or just wait twice, 3s each
# time but the 2nd time will return as soon as the slave has moved
# past the slow query.
sub _wait_skip_query {
   my ( $self, $wait ) = @_;
   my $wait_for_master = $self->{callbacks}->{wait_for_master};
   my $until_pos = 
         $self->{slave}->{mpos}                    # master pos
         + ($self->{pos} - $self->{slave}->{pos})  # how far we're ahead
         + 1;                                      # 1 past this query
   my %wait_args       = (
      dbh       => $self->{dbh},
      mfile     => $self->{slave}->{mfile},
      until_pos => $until_pos,
      timeout   => $wait,
   );
   my $start = gettimeofday();
   while ( $self->{slave}->{running}
           && ($self->{slave}->{pos} <= $self->{pos}) ) {
      $self->{stats}->{master_pos_wait}++;
      $wait_for_master->(%wait_args);
      $self->_get_slave_status();
      MKDEBUG && _d('Bytes until slave reaches wait-skip query:',
         $self->{pos} - $self->{slave}->{pos});
   }
   MKDEBUG && _d('Waited', (gettimeofday - $start), 'to skip query');
   $self->_get_slave_status();
   return;
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
   my ( $self, %args ) = @_;
   my $query       = $args{query};
   my $fingerprint = $args{fingerprint};
   eval {
      my $start = gettimeofday();
      $self->{dbh}->do($query);
      $self->__store_avg($fingerprint, gettimeofday() - $start);
   };
   if ( $EVAL_ERROR ) {
      $self->{stats}->{query_error}++;
      $self->{query_errors}->{$fingerprint}++;
      if ( (($self->{errors} || 0) == 2) || MKDEBUG ) {
         _d($EVAL_ERROR);
         _d('SQL was:', $query);
      }
   }
   return;
}

# The average is weighted so we don't quit trying a statement when we have
# only a few samples.  So if we want to collect 16 samples and the first one
# is huge, it will be weighted as 1/16th of its size.
sub __store_avg {
   my ( $self, $fingerprint, $time ) = @_;
   MKDEBUG && _d('Execution time:', $fingerprint, $time);
   my $query_stats = $self->{query_stats}->{$fingerprint} ||= {};
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

sub get_avg {
   my ( $self, $fingerprint ) = @_;
   $self->{query_stats}->{$fingerprint}->{seen}++;
   return $self->{query_stats}->{$fingerprint}->{avg} || 0;
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
