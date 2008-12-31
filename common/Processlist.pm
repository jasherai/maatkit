# This program is copyright (c) 2008 Baron Schwartz.
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
package Processlist;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;

use constant MKDEBUG => $ENV{MKDEBUG};
use constant {
   ID      => 0,
   USER    => 1,
   HOST    => 2,
   DB      => 3,
   COMMAND => 4,
   TIME    => 5,
   STATE   => 6,
   INFO    => 7,
   START   => 8,
};

sub new {
   my ( $class ) = @_;
   bless {}, $class;
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
#  my $misc = { prev => [], time => time() };
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
# The $code shouldn't return itself, e.g. if it's a PROCESSLIST you should
# filter out $dbh->{mysql_thread_id}.
#
# TODO: unresolved issues are
# 1) What about Lock_time?  It's unclear if a query starts at 100, unlocks at
#    105 and completes at 110, is it 5s lock and 5s exec?  Or 5s lock, 10s exec?
#    This code should match that behavior.
# 2) What about splitting the difference?  If I see a query now with 0s, and one
#    second later I look and see it's gone, should I split the middle and say it
#    ran for .5s?
# 3) I think user/host needs to do user/host/ip, really.  And actually, port
#    will show up in the processlist -- make that a property too.
# 4) It should put cmd => Query, cmd => Admin, or whatever
sub parse_event {
   my ( $self, $code, $misc, @callbacks ) = @_;
   my $num_events = 0;

   my @curr = sort { $a->[ID] <=> $b->[ID] } @{$code->()};
   my @prev = @{$misc->{prev} ||= []};
   my @new; # Will become next invocation's @prev
   my ($curr, $prev); # Rows from each source

   do { 
      if ( !$curr && @curr ) {
         # MKDEBUG && _d('Fetching row from curr');
         $curr = shift @curr;
      }
      if ( !$prev && @prev ) {
         # MKDEBUG && _d('Fetching row from prev');
         $prev = shift @prev;
      }
      if ( $curr || $prev ) {
         # In each of the if/elses, something must be undef'ed to prevent
         # infinite looping.
         if ( $curr && $prev && $curr->[ID] == $prev->[ID] ) {
            MKDEBUG && _d('$curr and $prev are the same cxn');
            # If the query is different from the previously seen one, it's a new
            # query.  Or, if its start time seems to be after the start time of
            # the previously seen one, it's also a new query.  Because of the
            # limited precision of the standard processlist, it's easy to get
            # into a race condition and fire before the query is done, so we add
            # 1 second when the time is a whole number.
            my $fudge = $curr->[TIME] =~ m/\D/ ? 0.001 : 1;
            my $is_new = 0;
            if ( $prev->[INFO] ) {
               if (!$curr->[INFO] || $prev->[INFO] ne $curr->[INFO]) {
                  # This is a different query or a new query
                  MKDEBUG && _d('$curr has a new query');
                  $is_new = 1;
               }
               elsif ( $curr->[INFO] && defined $curr->[TIME]
                     && $misc->{time} - $curr->[TIME] - $fudge > $prev->[START]
               ) {
                  MKDEBUG && _d('$curr has same query that restarted');
                  $is_new = 1;
               }
               if ( $is_new ) {
                  fire_event( $prev, @callbacks );
               }
            }
            if ( $curr->[INFO] ) {
               if ( $prev->[INFO] && !$is_new ) {
                  MKDEBUG && _d('Pushing old history item back onto $prev');
                  push @new, [ @$prev ];
               }
               else {
                  MKDEBUG && _d('Pushing new history item onto $prev');
                  push @new, [ @$curr, $misc->{time} - $curr->[TIME] ];
               }
            }
            $curr = $prev = undef; # Fetch another from each.
         }
         # The row in the prev doesn't exist in the curr.  Fire an event.
         elsif ( !$curr
               || ( $curr && $prev && $curr->[ID] > $prev->[ID] )) {
            #MKDEBUG && _d('$curr is not in $prev');
            fire_event( $prev, @callbacks );
            $prev = undef;
         }
         # The row in curr isn't in prev; start a new event.
         else { # This else must be entered, to prevent infinite loops.
            #MKDEBUG && _d('$prev is not in $curr');
            if ( $curr->[INFO] && defined $curr->[TIME] ) {
               MKDEBUG && _d('Pushing new history item onto $prev');
               push @new, [ @$curr, $misc->{time} - $curr->[TIME] ];
            }
            $curr = undef; # No infinite loops.
         }
      }
   } while ( @curr || @prev || $curr || $prev );

   @{$misc->{prev}} = @new;

   return $num_events;
}

sub fire_event {
   my ( $row, @callbacks ) = @_;
   #print Dumper($row);
   my $event = {
      id         => $row->[ID],
      db         => $row->[DB],
      user       => $row->[USER],
      host       => $row->[HOST],
      arg        => $row->[INFO],
      ts         => $row->[START] + $row->[TIME], # Query END time
      Query_time => $row->[TIME],
      Lock_time  => 0,               # TODO
   };
   map { return unless $_->($event) } @callbacks;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# Processlist:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End Processlist package
# ###########################################################################
