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
my $slow_log_uh_line = qr/^# User\@Host: ([^\[]+).*?@ (\S*) \[(.*)\]/;
my $slow_log_tr_line = qr{^# Query_time: (\d+(?:\.\d+)?)  Lock_time: (\d+(?:\.\d+)?)  Rows_sent: (\d+)  Rows_examined: (\d+)};

my $binlog_line_1 = qr{^# at (\d+)};
my $binlog_line_2 = qr/^#(\d{6}\s+\d{1,2}:\d\d:\d\d)\s+server\s+id\s+(\d+)\s+end_log_pos\s+(\d+)\s+(\S+)\s*([^\n]*)$/;
my $binlog_line_2_rest = qr{Query\s+thread_id=(\d+)\s+exec_time=(\d+)\s+error_code=(\d+)};

# This method accepts an open filehandle and a callback function.  It reads
# events from the filehandle and calls the callback with each event.
#
# Each event looks like this:
#  my $event = {
#     ts  => '',    # Timestamp
#     id  => '',    # Connection ID
#     cmd => '',    # Command (type of event)
#     arg => '',    # Argument to the command
#  };
#
# Returns true if it was able to find an event.
sub parse_event {
   my ( $self, $fh, $code ) = @_;
   my $event;

   my $done = 0;
   my $mode = '';
   my $i    = 0;
   my $line = defined $self->{last_line} ? $self->{last_line} : <$fh>;

   LINE:
   while ( !$done && defined $line ) {

      # These can appear in the log file when it's opened -- for example, when
      # someone runs FLUSH LOGS.
      if ( $line =~ m/Version:.+ started with:/ ) {
         <$fh>; # Tcp port: etc
         <$fh>; # Column headers
         $line = <$fh>;
         redo LINE;
      }

      # Match the beginning of an event in the general log.
      elsif ( my ( $ts, $id, $rest ) = $line =~ m/$general_log_first_line/s ) {
         $mode = 'log';
         $self->{last_line} = undef;
         if ( $i == 0 ) {
            my ( $cmd, $arg ) = $rest =~ m/$general_log_any_line/;
            $event = {
               ts  => $ts || '',
               id  => $id,
               cmd => $cmd,
               arg => $arg || '',
            };
            if ( $cmd ne 'Query' ) {
               $done = 1;
               chomp $event->{arg};
            }
         }
         else {
            # The last line was the end of the query; this is the beginning of
            # the next.  Save it for the next round.
            $self->{last_line} = $line;
            $done = 1;
            chomp $event->{arg};
         }
      }

      # Maybe it's the beginning of a slow query log event.
      # # Time: 071015 21:43:52
      elsif ( my ( $time ) = $line =~ m/$slow_log_ts_line/ ) {
         $mode              = 'slow';
         $self->{last_line} = undef;
         if ( $i == 0 ) {
            $event->{ts} = $time;
         }
         else {
            # Last line was the end of a query; this is the beginning of the
            # next.
            $self->{last_line} = $line;
            $done = 1;
         }
      }

      # Maybe it's the user/host line of a slow query log.
      # # User@Host: root[root] @ localhost []
      elsif ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/ ) {
         @{$event}{qw(user host ip)} = ($user, $host, $ip);
      }

      # Maybe it's the timing line of a slow query log.
      # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
      elsif ( my ( $q, $l, $s, $e ) = $line =~ m/$slow_log_tr_line/ ) {
         @{$event}{qw(query_time lock_time rows_sent rows_exam)}
            = ( $q, $l, $s, $e );
      }

      else {
         if ( $mode eq 'slow' && ( my ( $db ) = $line =~ m/^use (.*);/ ) ) {
            $event->{cmd} = 'Init DB';
            $event->{arg} = $db;
            $code->($event);
            $event = {
               map { $_ => $event->{$_} }
                  qw(ts user host ip query_time lock_time rows_sent rows_exam)
            };
         }
         else {
            $event->{arg} .= $line;
            if ( $mode eq 'slow' ) {
               $event->{cmd} = 'Query';
            }
         }
      }

      $i++;
      $line = <$fh> unless $done;
   }

   # If it was EOF, discard the last line so statefulness doesn't interfere with
   # the next log file.
   if ( !defined $line ) {
      $self->{last_line} = undef;
   }

   if ( $mode eq 'slow' ) {
      $event->{arg} =~ s/;\s*//g;
   }

   $code->($event) if $event;
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
         local $RS     = $term;
         $tpat         = quotemeta $term;
         $line         = <$fh>; # Throw away DELIMITER line
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
         @{$event}{qw(ts server_id end type arg)}
            = ($ts, $sid, $end, $type, $line);
         if ( $type eq 'Xid' ) {
            my ($xid) = $rest =~ m/(\d+)/;
            $event->{xid} = $xid;
         }
         elsif ( $type eq 'Query' ) {
            @{$event}{qw(id time code)} = $rest =~ m/$binlog_line_2_rest/;
         }
         else {
            die "Unknown event type $type"
               unless $type =~ m/Intvar/;
         }
      }
      else {
         $event = {
            arg => $line,
         };
      }
   }

   # If it was EOF, discard the last line so statefulness doesn't interfere with
   # the next log file.
   if ( !defined $line ) {
      delete $self->{term};
   }

   $code->($event) if $event;
   return $event;
}

1;

# ###########################################################################
# End LogParser package
# ###########################################################################
