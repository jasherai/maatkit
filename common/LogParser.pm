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
package LogParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use constant MKDEBUG => $ENV{MKDEBUG};

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
               # Handle commented events like # administrator command: Quit;
               if ( $line =~ m/^#.+;/ ) {
                  MKDEBUG && _d('Commented event line ends header');
               }
               else {
                  $handled_line = 1;
                  MKDEBUG && _d('Splitting line into fields');
                  @{$event}{keys %hash} = values %hash;
               }
            }
            elsif ( $type == 1 && $line =~ m/^#.+;/ ) {
               # Handle commented event lines preceded by other lines; e.g.:
               # USE db;
               # # administrator command: Quit;
               MKDEBUG && _d('Commented event line after type 1 line');
               $handled_line = 0;
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
         $event->{cmd} = 'Query';
         if ( $mode eq 'slow' && $line =~ m/;\s+\Z/ ) {
            MKDEBUG && _d('Line is the end of a query within event');
            if ( my ( $db ) = $line =~ m/^use (.*);/i ) {
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
               if ( $line =~ m/^# / ) {
                  # Example: # administrator command: Quit
                  MKDEBUG && _d('Line is a commented event line');
                  $line =~ s/.+: (.+);\n/$1/;
                  $event->{cmd} = 'Admin';
               }
               $event->{arg} .= $line;
               $type = 2;
            }
         }
         else {
            MKDEBUG && _d('Line is a continuation of prev line');
            $event->{arg} .= $line;
            $type = 2;
         } 
      }

      # TODO: I think $NR may be misleading because Perl may not distinguish
      # one file from the next.
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

# This method accepts an open slow log filehandle and a callback function.
# It reads events from the filehandle and calls the callback with each event.
#
# Each event looks like this:
#  my $event = {
#     ts  => '',    # Timestamp
#     id  => '',    # Connection ID
#     arg => '',    # Argument to the command
#     other properties...
#  };
#
# Returns true if it finds an event.  NOTE: If you change anything inside this
# subroutine, you need to profile the result.  Sometimes a line of code has been
# changed from an alternate form for performance reasons -- sometimes as much as
# 20x better performance.
sub parse_slowlog_event {
   my ( $self, $fh, $code ) = @_;

   # Read a whole stmt at a time.  But, to make things even more fun, sometimes
   # part of the log entry might continue past the separator.  In these cases we
   # peek ahead (see code below.)  We do it this way because in the general
   # case, reading line-by-line is too slow, and the special-case code is
   # acceptable.
   local $INPUT_RECORD_SEPARATOR = ";\n#";
   my $trimlen    = length($INPUT_RECORD_SEPARATOR);
   my @properties = ('cmd', 'Query', 'pos_in_log', tell($fh));
   my $stmt       = <$fh>;
   return unless defined $stmt;

   # These can appear in the log file when it's opened -- for example, when
   # someone runs FLUSH LOGS or the server starts.
   # /usr/sbin/mysqld, Version: 5.0.67-0ubuntu6-log ((Ubuntu)). started with:
   # Tcp port: 3306  Unix socket: /var/run/mysqld/mysqld.sock
   # Time                 Id Command    Argument
   $stmt =~ s{
      ^(?:
      Tcp\sport:\s+\d+
      |
      /.*Version.*started
      |
      Time\s+Id\s+Command
      ).*\n
   }{}gmxo;

   # There will not be a leading '#' because $INPUT_RECORD_SEPARATOR will
   # have gobbled that up.  And the end may have all/part of the separator.
   $stmt = '#' . $stmt unless $stmt =~ m/\A#/;
   $stmt =~ s/;\n#?\Z//;

   # The beginning of a slow-query-log event should be something like
   # # Time: 071015 21:43:52
   # Or, it might look like this, sometimes at the end of the Time: line:
   # # User@Host: root[root] @ localhost []

   my $pos = 0;
   my $found_arg = 0;
   while ( $stmt =~ m/^(.*)$/mg ) { # /g is important, requires scalar match.
      $pos     = pos($stmt);  # Be careful not to mess this up!
      my $line = $1;          # Necessary for /g and pos() to work.

      # Handle meta-data lines.
      if ( $line =~ m/^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o ) {

         # Maybe it's the beginning of a slow query log event.
         if ( my ( $time ) = $line =~ m/$slow_log_ts_line/o ) {
            push @properties, 'ts', $time;
            # The User@Host might be concatenated onto the end of the Time.
            if ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o ) {
               push @properties, 'user', $user, 'host', $host, 'ip', $ip;
            }
         }

         # Maybe it's the user/host line of a slow query log
         # # User@Host: root[root] @ localhost []
         elsif ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o ) {
            push @properties, 'user', $user, 'host', $host, 'ip', $ip;
         }

         # A line that looks like meta-data but is not:
         # # administrator command: Quit;
         elsif ( $line =~ m/^# (?:administrator command:.*)$/ ) {
            push @properties, 'cmd', 'Admin', 'arg', $line;
            $found_arg++;
         }

         # Maybe it's the timing line of a slow query log, or another line such
         # as that... they typically look like this:
         # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
         elsif ( my @temp = $line =~ m/(\w+):\s+(\S+)/g ) {
            push @properties, @temp;
         }

         # Include the current default database given by 'use <db>;'
         elsif ( my ( $db ) = $line =~ m/^use ([^;]+)/ ) {
            push @properties, 'db', $db;
         }

         # Some things you might see in the log output:
         # set timestamp=foo;
         # set timestamp=foo,insert_id=bar;
         # set names utf8;
         elsif ( my ( $setting ) = $line =~ m/^SET\s+([^;]*)/ ) {
            # Note: this assumes settings won't be complex things like
            # SQL_MODE, which as of 5.0.51 appears to be true (see sql/log.cc,
            # function MYSQL_LOG::write(THD, char*, uint, time_t)).
            push @properties, split(/,|\s*=\s*/, $setting);
         }

         # Handle pathological special cases.  The "# administrator command" is one
         # example: it can come AFTER lines that are not commented, so it looks
         # like it belongs to the next event, and it won't be in $stmt.
         if ( !$found_arg && $pos == length($stmt) ) {
            local $INPUT_RECORD_SEPARATOR = ";\n";
            if ( chomp(my $l = <$fh>) ) {
               push @properties, 'cmd', 'Admin', 'arg', '#' . $l;
               $found_arg++;
            }
         }
      }
      else {
         # This isn't a meta-data line.  It's the first line of the whole query.
         # Grab from here to the end of the string and put that into the 'arg'
         # for the event.  Then we are done.  Note that if this line really IS
         # the query but we skip in the 'if' above because it looks like
         # meta-data, later we'll remedy that.
         push @properties, 'arg', substr($stmt, $pos - length($line));
         last;
      }
   }

   my $event = { @properties };
   $code->($event) if $code;
   return 1;
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
