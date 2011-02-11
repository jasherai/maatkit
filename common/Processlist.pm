# This program is copyright 2008-2011 Baron Schwartz.
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
# Processlist package $Revision$
# ###########################################################################

# Package: Processlist
# Processlist makes events when used to poll SHOW FULL PROCESSLIST.
package Processlist;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG} || 0;
use constant {
   # 0-7 are the standard processlist columns.
   ID      => 0,  
   USER    => 1,  
   HOST    => 2,
   DB      => 3,
   COMMAND => 4,
   TIME    => 5,
   STATE   => 6,
   INFO    => 7,
   # 8, 9 and 10 are extra info we calculate.
   START   => 8,  # Calculated start time of statement ($misc->{time} - TIME)
   ETIME   => 9,  # Exec time of SHOW PROCESSLIST (margin of error in START)
   FSEEN   => 10, # First time ever seen
   PROFILE => 11, # Profile of individual STATE times
};


# Sub: new
#
# Parameters:
#   %args - Arguments
#
# Required Arguments:
#   MasterSlave - MasterSlave obj for finding replicationt threads
#
# Returns:
#   Processlist object
sub new {
   my ( $class, %args ) = @_;
   foreach my $arg ( qw(MasterSlave) ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my $self = {
      %args,
      prev_rows => [],
      new_rows  => [],
      curr_row  => undef,
      prev_row  => undef,
   };
   return bless $self, $class;
}

# This method accepts a $code coderef, which is typically going to return SHOW
# FULL PROCESSLIST, and an array of callbacks.  The $code coderef can be any
# subroutine that can return an array of arrayrefs that have the same structure
# as SHOW FULL PRCESSLIST (see the defined constants above).  When it sees a
# query complete, it turns the query into an "event" and calls the callbacks
# with it.  It may find more than one event per call.  It also expects a $misc
# hashref, which it will use to maintain state in the caller's namespace across
# calls.  It expects this hashref to have the following:
#
#  my $misc = { prev => [], time => time(), etime => ? };
#
# Where etime is how long SHOW FULL PROCESSLIST took to execute.
#
# Each event is a hashref of attribute => value pairs like:
#
#  my $event = {
#     ts  => '',    # Timestamp
#     id  => '',    # Connection ID
#     arg => '',    # Argument to the command
#     other attributes...
#  };
#
# Returns the number of events it finds.
#
# Technical details: keeps the previous run's processes in an array, gets the
# current processes, and iterates through them, comparing prev and curr.  There
# are several cases:
#
# 1) Connection is in curr, not in prev.  This is a new connection.  Calculate
#    the time at which the statement must have started to execute.  Save this as
#    a property of the event.
# 2) Connection is in curr and prev, and the statement is the same, and the
#    current time minus the start time of the event in prev matches the Time
#    column of the curr.  This is the same statement we saw last time we looked
#    at this connection, so do nothing.
# 3) Same as 2) but the Info is different.  Then sometime between the prev
#    and curr snapshots, that statement finished.  Assume it finished
#    immediately after we saw it last time.  Fire the event handlers.
#    TODO: if the statement is now running something else or Sleep for a certain
#    time, then that shows the max end time of the last statement.  If it's 10s
#    later and it's now been Sleep for 8s, then it might have ended up to 8s
#    ago.
# 4) Connection went away, or Info went NULL.  Same as 3).
#
# The default MySQL server has one-second granularity in the Time column.  This
# means that a statement that starts at X.9 seconds shows 0 seconds for only 0.1
# second.  A statement that starts at X.0 seconds shows 0 secs for a second, and
# 1 second up until it has actually been running 2 seconds.  This makes it
# tricky to determine when a statement has been re-issued.  Further, this
# program and MySQL may have some clock skew.  Even if they are running on the
# same machine, it's possible that at X.999999 seconds we get the time, and at
# X+1.000001 seconds we get the snapshot from MySQL.  (Fortunately MySQL doesn't
# re-evaluate now() for every process, or that would cause even more problems.)
# And a query that's issued to MySQL may stall for any amount of time before
# it's executed, making even more skew between the times.
#
# As a result of all this, this program assumes that the time it is passed in
# $misc is measured consistently *after* calling SHOW PROCESSLIST, and is
# measured with high precision (not second-level precision, which would
# introduce an extra second of possible error in each direction).  That is a
# convention that's up to the caller to follow.  One worst case is this:
#
#  * The processlist measures time at 100.01 and it's 100.
#  * We measure the time.  It says 100.02.
#  * A query was started at 90.  Processlist says Time=10.
#  * We calculate that the query was started at 90.02.
#  * Processlist measures it at 100.998 and it's 100.
#  * We measure time again, it says 100.999.
#  * Time has passed, but the Time column still says 10.
#
# Another:
#
#  * We get the processlist, then the time.
#  * A second later we get the processlist, but it takes 2 sec to fetch.
#  * We measure the time and it looks like 3 sec have passed, but ps says only
#    one has passed.  (This is why $misc->{etime} is necessary).
#
# What should we do?  Well, the key thing to notice here is that a new statement
# has started if a) the Time column actually decreases since we last saw the
# process, or b) the Time column does not increase for 2 seconds, plus the etime
# of the first and second measurements combined!
#
# The $code shouldn't return itself, e.g. if it's a PROCESSLIST you should
# filter out $dbh->{mysql_thread_id}.
sub parse_event {
   my ( $self, %args ) = @_;
   my @required_args = qw(misc);
   foreach my $arg ( @required_args ) {
      die "I need a $arg argument" unless $args{$arg};
   }
   my ($misc) = @args{@required_args};

   # The code callback should return an arrayref of events from the proclist.
   my $code = $misc->{code};
   die "I need a code arg to misc" unless $code;

   # If there are current rows from the last time we were called, continue
   # using/parsing them.  Else, try to get new rows from $code.  Else, the
   # proecesslist is probably empty so do nothing.
   my @curr;
   if ( $self->{curr_rows} ) {
      MKDEBUG && _d('Current rows from last call');
      @curr = @{$self->{curr_rows}};
   }
   else {
      my $rows = $code->();
      if ( $rows && scalar @$rows ) {
         MKDEBUG && _d('Got new current rows');
         @curr = sort { $a->[ID] <=> $b->[ID] } @$rows;
      }
      else {
         MKDEBUG && _d('No current rows');
      }
   }

   my @prev = @{$self->{prev_rows} ||= []};
   my @new  = @{$self->{new_rows}  ||= []};; # Becomes next invocation's @prev
   my $curr = $self->{curr_row}; # Rows from each source
   my $prev = $self->{prev_row};
   my $event;

   MKDEBUG && _d('Rows:', scalar @prev, 'prev,', scalar @curr, 'current');

   if ( !$curr && @curr ) {
      MKDEBUG && _d('Fetching row from curr');
      $curr = shift @curr;
   }
   if ( !$prev && @prev ) {
      MKDEBUG && _d('Fetching row from prev');
      $prev = shift @prev;
   }
   if ( $curr || $prev ) {
      # In each of the if/elses, something must be undef'ed to prevent
      # infinite looping.
      if ( $curr && $prev && $curr->[ID] == $prev->[ID] ) {
         MKDEBUG && _d('Checking existing cxn', $curr->[ID]);

         # XXX Does this refer to...
         # Or, if its start time seems to be after the start time of
         # the previously seen one, it's also a new query.

         # If this is true, then the cxn was executing a query last time
         # we saw it.  Determine if the cxn is executing a new query.
         my $new_query = 0;
         my $fudge     = $curr->[TIME] =~ m/\D/ ? 0.001 : 1; # Micro-precision?
         if ( $prev->[INFO] ) {
            if ( !$curr->[INFO] || $prev->[INFO] ne $curr->[INFO] ) {
               # This is a new/different query because what's currently
               # executing is different from what the cxn was previously
               # executing.
               MKDEBUG && _d('Info is different; new query');
               $new_query = 1;
            }
            elsif ( defined $curr->[TIME] && $curr->[TIME] < $prev->[TIME] ) {
               # This is a new/different query because the current exec
               # time is less than the previous exec time, so the previous
               # query ended and a new one began between polls.
               MKDEBUG && _d('Current Time is less than previous; new query');
               $new_query = 1;
            }
            elsif ( $curr->[INFO]
                    && defined $curr->[TIME]
                    &&   $misc->{time}   # current wallclock time
                       - $curr->[TIME]   # current exec time
                       - $prev->[START]  # prev wallclock
                       - $prev->[ETIME]  # prev poll time
                       - $misc->{etime}  # current poll time
                       > $fudge
            ) {
               # XXX ...this?
               MKDEBUG && _d('$curr has same query that restarted; new query');
               $new_query = 1;
            }

            if ( $new_query ) {
               # The cxn is executing a new query, so the previous query ended.
               # Make an event for the previous query.
               $self->_update_profile($prev, $curr, $misc);
               $event = $self->make_event($prev, $misc->{time});
            }
         }

         # If this is true, the cxn is currently executing a query.
         # Determine if that query is old (i.e. same one running previously),
         # or new.  In either case, we save it to recheck it next poll.
         if ( $curr->[INFO] ) {
            if ( $prev->[INFO] && !$new_query ) {
               MKDEBUG && _d('Saving old (still running) query');
               $self->_update_profile($prev, $curr, $misc);
               push @new, [ @$prev ];
            }
            else {
               MKDEBUG && _d('Saving new query');
               push @new, [
                  @$curr,                              # proc info
                  int($misc->{time} - $curr->[TIME]),  # START
                  $misc->{etime},                      # ETIME
                  $misc->{time},                       # FSEEN
                  { $curr->[STATE] => 0 },             # PROFILE
               ];
            }
         }

         $curr = $prev = undef; # Fetch another from each.
      }
      elsif ( !$curr
              || ($curr && $prev && $curr->[ID] > $prev->[ID]) ) {
         # If there's no curr, then the prev ended between polls.
         # Or, if there's a curr but its ID is greater than the last
         # ID we saw for this cxn, then it's actually a new/different
         # cxn, also meaning that prev ended between polls.
         MKDEBUG && _d('cxn', $prev->[ID], 'ended');
         $event = $self->make_event($prev, $misc->{time});
         $prev = undef;
      }
      else { # This else must be entered, to prevent infinite loops.
         # The cxn is new because curr isn't in prev.  Begin saving
         # its info for comparison in later polls.
         MKDEBUG && _d('New cxn', $curr->[ID]);
         if ( $curr->[INFO] && defined $curr->[TIME] ) {
            # But only save the new cxn if it's executing.
            MKDEBUG && _d('Saving query of new cxn');
            push @new, [
               @$curr,                              # proc info
               int($misc->{time} - $curr->[TIME]),  # START
               $misc->{etime},                      # ETIME
               $misc->{time},                       # FSEEN
               { $curr->[STATE] => 0 },             # PROFILE
            ];
         }
         $curr = undef; # No infinite loops.
      }
   }

   $self->{prev_rows} = \@new;
   $self->{prev_row}  = $prev;
   $self->{curr_rows} = scalar @curr ? \@curr : undef;
   $self->{curr_row}  = $curr;

   return $event;
}

# The exec time of the query is the max of the time from the processlist, or the
# time during which we've actually observed the query running.  In case two
# back-to-back queries executed as the same one and we weren't able to tell them
# apart, their time will add up, which is kind of what we want.
sub make_event {
   my ( $self, $row, $time ) = @_;
   my $Query_time = $row->[TIME];
   if ( $row->[TIME] < $time - $row->[FSEEN] ) {
      $Query_time = $time - $row->[FSEEN];
   }
   my $event = {
      id         => $row->[ID],
      db         => $row->[DB],
      user       => $row->[USER],
      host       => $row->[HOST],
      arg        => $row->[INFO],
      bytes      => length($row->[INFO]),
      ts         => Transformers::ts($row->[START] + $row->[TIME]), # Query END time
      Query_time => $Query_time,
      Lock_time  => $row->[PROFILE]->{Locked} || 0,
   };
   MKDEBUG && _d('Properties of event:', Dumper($event));
   return $event;
}

sub _get_rows {
   my ( $self ) = @_;
   my %rows = map { $_ => $self->{$_} }
      qw(prev_rows new_rows curr_row prev_row);
   return \%rows;
}

# Sub: _update_profile
#   Update a query's PROFILE of STATE times.  The given cxn arrayrefs
#   ($prev and $curr) should be the same cxn and same query.  If the
#   query' state hasn't changed, the current state's time is incremented
#   by the poll time (ETIME).  Else, half the poll time is added to the
#   previous state and half to the current state (re issue 1246).
#
#   We cannot calculate a START for any state because the query's TIME
#   covers all states, so there's no way a posteriori to know how much
#   of TIME was spent in any given state.  The best we can do is count
#   how long we see the query in each state where ETIME (poll time)
#   defines our resolution.
#
# Parameters:
#   $prev - Arrayref of cxn's previous info
#   $curr - Arrayref of cxn's current info
#   $misc - Hashref with etime of poll
sub _update_profile {
   my ( $self, $prev, $curr, $misc ) = @_;
   return unless $prev && $curr;

   # Update only $prev because the caller should only be saving that arrayref.

   if ( ($prev->[STATE] || "") eq ($curr->[STATE] || "") ) {
      MKDEBUG && _d("Query is still in", $curr->[STATE], "state");
      $prev->[PROFILE]->{$prev->[STATE] || ""} += $misc->{etime};
   }
   else {
      # XXX The State of this cxn changed between polls.  How long
      # was it in its previous state, and how long has it been in
      # its current state?  We can't tell, so this is a compromise
      # re http://code.google.com/p/maatkit/issues/detail?id=1246
      MKDEBUG && _d("Query changed from state", $prev->[STATE],
         "to", $curr->[STATE]);
      my $half_etime = ($misc->{etime} || 0) / 2;

      # Previous state ends.
      $prev->[PROFILE]->{$prev->[STATE] || ""} += $half_etime;

      # Query assumes new state and we presume that the query has been
      # in that state for half the poll time.
      $prev->[STATE] = $curr->[STATE];
      $prev->[PROFILE]->{$curr->[STATE] || ""}  = $half_etime;
   }

   return;
}

# Accepts a PROCESSLIST and a specification of filters to use against it.
# Returns queries that match the filters.  The standard process properties
# are: Id, User, Host, db, Command, Time, State, Info.  These are used for
# ignore and match.
#
# Possible find_spec are:
#   * all            Match all not-ignored queries
#   * busy_time      Match queries that have been Command=Query for longer than
#                    this time
#   * idle_time      Match queries that have been Command=Sleep for longer than
#                    this time
#   * ignore         A hashref of properties => regex patterns to ignore
#   * match          A hashref of properties => regex patterns to match
#
sub find {
   my ( $self, $proclist, %find_spec ) = @_;
   MKDEBUG && _d('find specs:', Dumper(\%find_spec));
   my $ms  = $self->{MasterSlave};

   my @matches;
   QUERY:
   foreach my $query ( @$proclist ) {
      MKDEBUG && _d('Checking query', Dumper($query));
      my $matched = 0;

      # Don't allow matching replication threads.
      if (    !$find_spec{replication_threads}
           && $ms->is_replication_thread($query) ) {
         MKDEBUG && _d('Skipping replication thread');
         next QUERY;
      }

      # Match special busy_time.
      if ( $find_spec{busy_time} && ($query->{Command} || '') eq 'Query' ) {
         if ( $query->{Time} < $find_spec{busy_time} ) {
            MKDEBUG && _d("Query isn't running long enough");
            next QUERY;
         }
         MKDEBUG && _d('Exceeds busy time');
         $matched++;
      }

      # Match special idle_time.
      if ( $find_spec{idle_time} && ($query->{Command} || '') eq 'Sleep' ) {
         if ( $query->{Time} < $find_spec{idle_time} ) {
            MKDEBUG && _d("Query isn't idle long enough");
            next QUERY;
         }
         MKDEBUG && _d('Exceeds idle time');
         $matched++;
      }
 
      PROPERTY:
      foreach my $property ( qw(Id User Host db State Command Info) ) {
         my $filter = "_find_match_$property";
         # Check ignored properties first.  If the proc has at least one
         # property that matches an ignore value, then it is totally ignored.
         # and we can skip to the next proc (query).
         if ( defined $find_spec{ignore}->{$property}
              && $self->$filter($query, $find_spec{ignore}->{$property}) ) {
            MKDEBUG && _d('Query matches ignore', $property, 'spec');
            next QUERY;
         }
         # If the proc's property value isn't ignored, then check if it matches.
         if ( defined $find_spec{match}->{$property} ) {
            if ( !$self->$filter($query, $find_spec{match}->{$property}) ) {
               MKDEBUG && _d('Query does not match', $property, 'spec');
               next QUERY;
            }
            MKDEBUG && _d('Query matches', $property, 'spec');
            $matched++;
         }
      }
      if ( $matched || $find_spec{all} ) {
         MKDEBUG && _d("Query matched one or more specs, adding");
         push @matches, $query;
         next QUERY;
      }
      MKDEBUG && _d('Query does not match any specs, ignoring');
   } # QUERY

   return @matches;
}

sub _find_match_Id {
   my ( $self, $query, $property ) = @_;
   return defined $property && defined $query->{Id} && $query->{Id} == $property;
}

sub _find_match_User {
   my ( $self, $query, $property ) = @_;
   return defined $property && defined $query->{User}
      && $query->{User} =~ m/$property/;
}

sub _find_match_Host {
   my ( $self, $query, $property ) = @_;
   return defined $property && defined $query->{Host}
      && $query->{Host} =~ m/$property/;
}

sub _find_match_db {
   my ( $self, $query, $property ) = @_;
   return defined $property && defined $query->{db}
      && $query->{db} =~ m/$property/;
}

sub _find_match_State {
   my ( $self, $query, $property ) = @_;
   return defined $property && defined $query->{State}
      && $query->{State} =~ m/$property/;
}

sub _find_match_Command {
   my ( $self, $query, $property ) = @_;
   return defined $property && defined $query->{Command}
      && $query->{Command} =~ m/$property/;
}

sub _find_match_Info {
   my ( $self, $query, $property ) = @_;
   return defined $property && defined $query->{Info}
      && $query->{Info} =~ m/$property/;
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
# End Processlist package
# ###########################################################################
