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
# LogParser package $Revision$
# ###########################################################################
use strict;
use warnings FATAL => 'all';

package LogParser;

use constant MKDEBUG => $ENV{MKDEBUG};

# TODO: support events that are 'commented out' in the slow query log, such as
# administrative commands like ping and statistics.

use English qw(-no_match_vars);

sub new {
   my ( $class ) = @_;
   bless {}, $class;
}

my $general_log_first_line = qr{
   \A
   (?:(\d{6}\s+\d{1,2}:\d\d:\d\d)|\t)? # Timestamp
   \t
   (?:\s*(\d+))                        # Thread ID
   \s
   (.*)                                # Everything else
   \Z
}xs;

my $general_log_any_line = qr{
   \A(
      Connect
      |Field\sList
      |Init\sDB
      |Query
      |Quit
   )
   (?:\s+(.*\Z))?
}xs;

my $slow_log_ts_line = qr/^# Time: (\d{6}\s+\d{1,2}:\d\d:\d\d)/;
my $slow_log_uh_line = qr/# User\@Host: ([^\[]+).*?@ (\S*) \[(.*)\]/;

my $binlog_line_1 = qr{^# at (\d+)};
my $binlog_line_2 = qr/^#(\d{6}\s+\d{1,2}:\d\d:\d\d)\s+server\s+id\s+(\d+)\s+end_log_pos\s+(\d+)\s+(\S+)\s*([^\n]*)$/;
my $binlog_line_2_rest = qr{Query\s+thread_id=(\d+)\s+exec_time=(\d+)\s+error_code=(\d+)};

# This method accepts an open filehandle, a callback function, and a mode
# (slow, log, undef).  It reads events from the filehandle and calls the
# callback with each event.
#
# Each event looks like this:
#  my $event = {
#     ts  => '',    # Timestamp
#     id  => '',    # Connection ID
#     cmd => '',    # Command (type of event)
#     arg => '',    # Argument to the command
#  };
#
# Returns true if it was able to find an event.  It auto-detects the log
# format most of the time.
sub parse_event {
   my ( $self, $fh, $code, $mode ) = @_;
   my $event; # Don't initialize, that'll cause a loop.

   my $done = 0;
   my $type = 0; # 0 = comments, 1 = USE and SET etc, 2 = the actual query
   my $line = defined $self->{last_line} ? $self->{last_line} : <$fh>;
   $mode  ||= '';

   LINE:
   while ( !$done && defined $line ) {
      MKDEBUG && _d('type: ', $type, ' ', $line);
      my $handled_line = 0;

      if ( !$mode && $line =~ m/^# [A-Z]/ ) {
         MKDEBUG && _d('Setting mode to slow log');
         $mode ||= 'slow';
      }

      # These can appear in the log file when it's opened -- for example, when
      # someone runs FLUSH LOGS.
      if ( $line =~ m/Version:.+ started with:/ ) {
         MKDEBUG && _d('Chomping out header lines');
         <$fh>; # Tcp port: etc
         <$fh>; # Column headers
         $line = <$fh>;
         $type = 0;
         redo LINE;
      }

      # Match the beginning of an event in the general log.
      elsif ( $mode ne 'slow'
         && (my ( $ts, $id, $rest ) = $line =~ m/$general_log_first_line/s)
      ) {
         MKDEBUG && _d('Beginning of general log event');
         $handled_line = 1;
         $mode ||= 'log';
         $self->{last_line} = undef;
         if ( $type == 0 ) {
            MKDEBUG && _d('Type 0');
            my ( $cmd, $arg ) = $rest =~ m/$general_log_any_line/;
            $event = {
               ts  => $ts || '',
               id  => $id,
               cmd => $cmd,
               arg => $arg || '',
            };
            if ( $cmd ne 'Query' ) {
               MKDEBUG && _d('Not a query, done with this event');
               $done = 1;
               chomp $event->{arg} if $event->{arg};
            }
            $type = 2;
         }
         else {
            # The last line was the end of the query; this is the beginning of
            # the next.  Save it for the next round.
            MKDEBUG && _d('Saving line for next invocation');
            $self->{last_line} = $line;
            $done = 1;
            chomp $event->{arg} if $event->{arg};
         }
      }

      elsif ( $mode eq 'slow' ) {
         if ( $line =~ m/^# No InnoDB statistics available/ ) {
            $handled_line = 1;
            MKDEBUG && _d('Ignoring line');
            $line = <$fh>;
            $type = 0;
            next LINE;
         }

         # Maybe it's the beginning of a slow query log event.
         # # Time: 071015 21:43:52
         elsif ( my ( $time ) = $line =~ m/$slow_log_ts_line/ ) {
            $handled_line = 1;
            MKDEBUG && _d('Beginning of slow log event');
            $self->{last_line} = undef;
            if ( $type == 0 ) {
               MKDEBUG && _d('Type 0');
               $event->{ts} = $time;
               # The User@Host might be concatenated onto the end of the Time.
               if ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/ ) {
                  @{$event}{qw(user host ip)} = ($user, $host, $ip);
               }
            }
            else {
               # Last line was the end of a query; this is the beginning of the
               # next.
               MKDEBUG && _d('Saving line for next invocation');
               $self->{last_line} = $line;
               $done = 1;
            }
            $type = 0;
         }

         # Maybe it's the user/host line of a slow query log, which could be the
         # first line of a new event in many cases.
         # # User@Host: root[root] @ localhost []
         elsif ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/ ) {
            $handled_line = 1;
            if ( $type == 0 ) {
               MKDEBUG && _d('Type 0');
               @{$event}{qw(user host ip)} = ($user, $host, $ip);
            }
            else {
               # Last line was the end of a query; this is the beginning of the
               # next.
               MKDEBUG && _d('Saving line for next invocation');
               $self->{last_line} = $line;
               $done = 1;
            }
            $type = 0;
         }

         # Maybe it's the timing line of a slow query log, or another line such
         # as that... they typically look like this:
         # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
         elsif ( $line =~ m/^# / && (my %hash = $line =~ m/(\w+):\s+(\S+)/g ) ) {
            if ( $type == 0 ) {
               $handled_line = 1;
               MKDEBUG && _d('Splitting line into fields');
               @{$event}{keys %hash} = values %hash;
            }
            else {
               # Last line was the end of a query; this is the beginning of the
               # next.
               $handled_line = 1;
               MKDEBUG && _d('Saving line for next invocation');
               $self->{last_line} = $line;
               $done = 1;
            }
            $type = 0;
         }
      }

      if ( !$handled_line ) {
         if ( $mode eq 'slow' && $line =~ m/;\s+\Z/ ) {
            MKDEBUG && _d('Line is the end of a query within event');
            if ( my ( $db ) = $line =~ m/^use (.*);/ ) {
               MKDEBUG && _d('Setting event DB to ', $db);
               $event->{db} = $db;
               $type = 1;
            }
            elsif ( $type < 2 && (my ( $setting ) = $line =~ m/^(SET .*);\s+\Z/ ) ) {
               MKDEBUG && _d('Setting a property for event');
               push @{$event->{settings}}, $setting;
               $type = 1;
            }
            else {
               MKDEBUG && _d('Line is a continuation of prev line');
               $event->{arg} .= $line;
               $type = 2;
            }
         }
         else {
            MKDEBUG && _d('Line is a continuation of prev line');
            $event->{arg} .= $line;
            $type = 2;
         }
         $event->{cmd} = 'Query';
      }

      $event->{NR} = $NR;

      $line = <$fh> unless $done;
   }

   # If it was EOF, discard the last line so statefulness doesn't interfere with
   # the next log file.
   if ( !defined $line ) {
      MKDEBUG && _d('EOF found');
      $self->{last_line} = undef;
   }

   if ( $mode && $mode eq 'slow' ) {
      MKDEBUG && _d('Slow log, trimming');
      $event->{arg} =~ s/;\s*\Z// if $event->{arg};
   }

   $code->($event) if $event && $code;
   return $event;
}

# This method accepts an open filehandle and a callback function.  It reads
# events from the filehandle and calls the callback with each event.
sub parse_binlog_event {
   my ( $self, $fh, $code ) = @_;
   my $event;

   my $term  = $self->{term} || ";\n"; # Corresponds to DELIMITER
   my $tpat  = quotemeta $term;
   local $RS = $term;
   my $line  = <$fh>;

   LINE: {
      return unless $line;

      # Catch changes in DELIMITER
      if ( $line =~ m/^DELIMITER/m ) {
         my($del)      = $line =~ m/^DELIMITER ([^\n]+)/m;
         $self->{term} = $del;
         local $RS     = $del;
         $line         = <$fh>; # Throw away DELIMITER line
         MKDEBUG && _d('New record separator: ', $del);
         redo LINE;
      }

      # Throw away the delimiter
      $line =~ s/$tpat\Z//;

      # Match the beginning of an event in the binary log.
      if ( my ( $offset ) = $line =~ m/$binlog_line_1/m ) {
         $self->{last_line} = undef;
         $event = {
            offset => $offset,
         };
         my ( $ts, $sid, $end, $type, $rest ) = $line =~ m/$binlog_line_2/m;
         @{$event}{qw(ts server_id end type)} = ($ts, $sid, $end, $type);
         (my $arg = $line) =~ s/\n*^#.*\n//gm; # Remove comment lines
         $event->{arg} = $arg;
         if ( $type eq 'Xid' ) {
            my ($xid) = $rest =~ m/(\d+)/;
            $event->{xid} = $xid;
         }
         elsif ( $type eq 'Query' ) {
            @{$event}{qw(id time code)} = $rest =~ m/$binlog_line_2_rest/;
         }
         else {
            die "Unknown event type $type"
               unless $type =~ m/Rotate|Start|Execute_load_query|Append_block|Begin_load_query|Rand|User_var|Intvar/;
         }
      }
      else {
         $event = {
            arg => $line,
         };
      }
   }

   # If it was EOF, discard the terminator so statefulness doesn't interfere with
   # the next log file.
   if ( !defined $line ) {
      delete $self->{term};
   }

   $code->($event) if $event && $code;
   return $event;
}

sub _d {
   my ( $line ) = (caller(0))[2];
   print "# LogParser:$line $PID ", @_, "\n";
}

1;

# ###########################################################################
# End LogParser package
# ###########################################################################
