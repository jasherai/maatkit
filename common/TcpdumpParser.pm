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
# TcpdumpParser package $Revision$
# ###########################################################################
package TcpdumpParser;

# This is a parser for tcpdump output.  It expects the output to be formatted a
# certain way.  See the t/samples/tcpdumpxxx.txt files for examples.  Here's a
# sample command on Ubuntu to produce the right formatted output:
# tcpdump -i lo port 3306 -s 1500 -x -n -q -tttt

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;

use constant MKDEBUG => $ENV{MKDEBUG};
use constant {
   COM_SLEEP               => '00',
   COM_QUIT                => '01',
   COM_INIT_DB             => '02',
   COM_QUERY               => '03',
   COM_FIELD_LIST          => '04',
   COM_CREATE_DB           => '05',
   COM_DROP_DB             => '06',
   COM_REFRESH             => '07',
   COM_SHUTDOWN            => '08',
   COM_STATISTICS          => '09',
   COM_PROCESS_INFO        => '0a',
   COM_CONNECT             => '0b',
   COM_PROCESS_KILL        => '0c',
   COM_DEBUG               => '0d',
   COM_PING                => '0e',
   COM_TIME                => '0f',
   COM_DELAYED_INSERT      => '10',
   COM_CHANGE_USER         => '11',
   COM_BINLOG_DUMP         => '12',
   COM_TABLE_DUMP          => '13',
   COM_CONNECT_OUT         => '14',
   COM_REGISTER_SLAVE      => '15',
   COM_STMT_PREPARE        => '16',
   COM_STMT_EXECUTE        => '17',
   COM_STMT_SEND_LONG_DATA => '18',
   COM_STMT_CLOSE          => '19',
   COM_STMT_RESET          => '1a',
   COM_SET_OPTION          => '1b',
   COM_STMT_FETCH          => '1c',
};

my %com_for = (
   '00' => 'COM_SLEEP',
   '01' => 'COM_QUIT',
   '02' => 'COM_INIT_DB',
   '03' => 'COM_QUERY',
   '04' => 'COM_FIELD_LIST',
   '05' => 'COM_CREATE_DB',
   '06' => 'COM_DROP_DB',
   '07' => 'COM_REFRESH',
   '08' => 'COM_SHUTDOWN',
   '09' => 'COM_STATISTICS',
   '0a' => 'COM_PROCESS_INFO',
   '0b' => 'COM_CONNECT',
   '0c' => 'COM_PROCESS_KILL',
   '0d' => 'COM_DEBUG',
   '0e' => 'COM_PING',
   '0f' => 'COM_TIME',
   '10' => 'COM_DELAYED_INSERT',
   '11' => 'COM_CHANGE_USER',
   '12' => 'COM_BINLOG_DUMP',
   '13' => 'COM_TABLE_DUMP',
   '14' => 'COM_CONNECT_OUT',
   '15' => 'COM_REGISTER_SLAVE',
   '16' => 'COM_STMT_PREPARE',
   '17' => 'COM_STMT_EXECUTE',
   '18' => 'COM_STMT_SEND_LONG_DATA',
   '19' => 'COM_STMT_CLOSE',
   '1a' => 'COM_STMT_RESET',
   '1b' => 'COM_SET_OPTION',
   '1c' => 'COM_STMT_FETCH',
);

sub new {
   my ( $class ) = @_;
   bless {
      sessions => {},
   }, $class;
}

my $handshake_pat = qr{
                        # Bytes                Name
      ^                 # -----                ----
      ..                # 1                    protocol_version
      (?:..)+?00        # n Null-Term String   server_version
      (.{8})            # 4                    thread_id
      .{16}             # 8                    scramble_buff
      .{2}              # 1                    filler: always 0x00
      .{4}              # 2                    server_capabilities
      .{2}              # 1                    server_language
      .{4}              # 2                    server_status
      .{26}             # 13                   filler: always 0x00
                        # 13                   rest of scramble_buff
   }x;


# This method accepts an open filehandle and callback functions.
# It reads events from the filehandle and calls the callbacks with each event.
# It may find more than one event per call.  $misc is some placeholder for the
# future and for compatibility with other query sources.
#
# Each event is a hashref of attribute => value pairs like:
#  my $event = {
#     ts  => '',    # Timestamp
#     id  => '',    # Connection ID
#     arg => '',    # Argument to the command
#     other attributes...
#  };
#
# Returns the number of events it finds.
sub parse_event {
   my ( $self, $fh, $misc, @callbacks ) = @_;
   my $watching   = $misc->{watching};

   # We read a packet at a time.  Assuming that all packets begin with a
   # timestamp "200.....", we just use that as the separator, and restore it.
   # This will be good until the year 2100.
   local $INPUT_RECORD_SEPARATOR = "\n200";

   my $pos_in_log = tell($fh);
   EVENT:
   while ( defined(my $pack = <$fh>) ) {
      # Remove the separator from the packet, and restore it to the front if
      # necessary.
      $pack =~ s/\n200\Z//;
      $pack = "200$pack" unless $pack =~ m/\A200/;

      my ( $ts, $from, $to ) = $pack =~ m/\A(\S+ \S+) IP (\S+) > (\S+):/;
      (my $data = join('', $pack =~ m/\t0x\d+:  (.*)/g))=~ s/\s+//g; 
      my $sess = $self->{sessions}->{$from eq $watching ? $to : $from}
            ||= {
               client     => ($from eq $watching ? $to : $from),
               ts         => $ts,
               pos_in_log => $pos_in_log,
            };

      # Find length information in the IPv4 header.  Typically 5 32-bit
      # words.  See http://en.wikipedia.org/wiki/IPv4#Header
      my $ip_hlen = hex(substr($data, 1, 1)); # Number of 32-bit words.

      # Same thing in a different position, with the TCP header.  See
      # http://en.wikipedia.org/wiki/Transmission_Control_Protocol.
      my $tcp_hlen = hex(substr($data, ($ip_hlen + 3) * 8, 1));
      # Throw away the IP and TCP headers.
      MKDEBUG && _d('Header len: IP', $ip_hlen, 'TCP', $tcp_hlen);
      $data = substr($data, ($ip_hlen + $tcp_hlen) * 8);
      if ( $data ) {

         # Now we're down to the MySQL protocol.  A single TCP packet can
         # contain many MySQL protocol packets!  The first 4 bytes are the
         # packet header: a 3-byte length and a 1-byte sequence.  After that, it
         # depends on what type of packet this is.  NOTE: the data is modified
         # by the inmost substr call here!  If we had all the data in the TCP
         # packets, we could change this to a while loop; while
         # get-a-packet-from-$data, do stuff, etc.  But we don't, and we don't
         # want to either.
         my $packet_len = to_num(substr(substr($data, 0, 8, ''), 0, 6));
         MKDEBUG && _d('Packet length:', $packet_len);

         # If it's from the server to the client, I care about
         # 1) during the initialization sequence, the thread_id.
         # 2) after that, I care about things like the warning count, etc.
         if ( $from eq $watching ) { # From server to client
            MKDEBUG && _d('Packet is from server to client');

            # The first byte in the packet indicates whether it's an OK,
            # ERROR, EOF packet.  If it's not one of those, we test
            # whether it's an initialization packet (the first thing the
            # server ever sends the client).  If it's not that, it could
            # be a result set header, field, row data, etc.
            my ( $first_byte ) = substr($data, 0, 2, '');
            MKDEBUG && _d("First byte of packet:", $first_byte);
            if ( $first_byte eq '00' ) {
               MKDEBUG && _d('Got an OK packet', $data);

               # Gather all the data from the packet.
               $first_byte = hex(substr($data, 0, 2, '')); # LCB aff_rows
               my $affected_rows = $first_byte
                  ? to_num(substr($data, 0, $first_byte * 2, ''))
                  : 0;
               $first_byte = hex(substr($data, 0, 2, '')); # LCB insert_id
               my $insert_id = $first_byte
                  ? to_num(substr($data, 0, $first_byte * 2, ''))
                  : 0;
               my $status   = to_num(substr($data, 0, 4, ''));
               my $warnings = to_num(substr($data, 0, 4, ''));
               my $message  = to_string($data);
               MKDEBUG && _d('OK data: affected_rows', $affected_rows,
                  'insert_id', $insert_id, 'status', $status, 'warnings',
                  $warnings, 'message', $message);

               if ( ($sess->{state} || '') eq 'client_auth' ) {
                  # We logged in OK!  Trigger an admin Connect command.
                  fire_event(
                     {  cmd => 'Admin',
                        arg => 'administrator command: Connect',
                        ts  => $ts, # Events are timestamped when they end
                     },
                     $pack, $sess, @callbacks
                  );
               }
               elsif ( $sess->{cmd} ) { # It should be a query or something
                  my $com = $sess->{cmd}->{cmd};
                  my $arg;
                  if ( $com eq COM_QUERY ) {
                     $com = 'Query';
                     $arg = $sess->{cmd}->{arg};
                  }
                  else {
                     $arg = 'administrator command: '
                          . ucfirst(lc(substr($com_for{$com}, 4)));
                     $com = 'Admin';
                  }
                  fire_event(
                     {  cmd           => $com,
                        arg           => $arg,
                        ts            => $ts,
                        Insert_id     => $insert_id,
                        Warnings      => $warnings,
                        Rows_affected => $affected_rows,
                     },
                     $pack, $sess, @callbacks
                  );
               }
               $sess->{state} = 'ready';
               return 1;
            }
            elsif ( $first_byte eq 'ff' ) {
               MKDEBUG && _d('Got an ERROR packet');
               my $errno = to_num(substr($data, 0, 4));
               my $messg = to_string(substr($data, 4));
               MKDEBUG && _d('ERROR', $errno, $messg);
               my $event;
               if ( $sess->{state} eq 'client_auth' ) {
                  MKDEBUG && _d('Connection failed');
                  $event = {
                     cmd       => 'Admin',
                     arg       => 'administrator command: Connect',
                     ts        => $ts,
                     Error_no  => $errno,
                  };
                  $sess->{state} = 'closing';
               }
               elsif ( $sess->{cmd} ) { # It should be a query or something
                  my $com = $sess->{cmd}->{cmd};
                  my $arg;
                  if ( $com eq COM_QUERY ) {
                     $com = 'Query';
                     $arg = $sess->{cmd}->{arg};
                  }
                  else {
                     $arg = 'administrator command: '
                          . ucfirst(lc(substr($com_for{$com}, 4)));
                     $com = 'Admin';
                  }
                  $event = {
                     cmd       => $com,
                     arg       => $arg,
                     ts        => $ts,
                     Error_no  => $errno,
                  };
                  $sess->{state} = 'ready';
               }
               fire_event($event, $pack, $sess, @callbacks);
               return 1;
            }
            elsif ( $first_byte eq 'fe' && $packet_len < 9 ) {
               MKDEBUG && _d('Got an EOF packet');
               die "You should not have gotten here";
               # ^^^ We shouldn't reach this because EOF should come after a
               # header, field, or row data packet; and we should be firing the
               # event and returning when we see that.  See SVN history for some
               # good stuff we could do if we wanted to handle EOF packets.
            }
            elsif ( !$sess->{state}
               && (my ($thread_id) = $data =~ m/$handshake_pat/o )
            ) {
               # It's the handshake packet from the server to the client.
               MKDEBUG && _d('Got a handshake for thread_id', $thread_id);
               $sess->{thread_id} = to_num($thread_id);
               $sess->{state}     = 'server_handshake';
            }
            else { # Row data, field, result set header.
               MKDEBUG && _d('Got a row/field/result packet');
               # Since we do NOT have all the data the server sent to the
               # client, we can't really do any processing of results.  So when
               # we get one of these, we just fire the event and assume the
               # query is done.
               if ( $sess->{cmd} ) {
                  my $com = $sess->{cmd}->{cmd};
                  my $arg;
                  if ( $com eq COM_QUERY ) {
                     $com = 'Query';
                     $arg = $sess->{cmd}->{arg};
                  }
                  else {
                     $arg = 'administrator command: '
                          . ucfirst(lc(substr($com_for{$com}, 4)));
                     $com = 'Admin';
                  }
                  fire_event(
                     {  cmd           => $com,
                        arg           => $arg,
                        ts            => $ts,
                     },
                     $pack, $sess, @callbacks
                  );
                  $sess->{state} = 'ready';
                  return 1;
               }
            }
         } # From server to client

         # If it's from the client to the server, I care about
         # 1) during the initialization sequence, I want to know the user
         #    and the initial database.  It looks like the best way to
         #    detect this command is by looking for the 23-byte 0x00...
         #    filler.  I only need to do this for sessions that aren't yet
         #    initialized.
         # 2) after that, I want to know the query text.
         else {  # From client to server
            if ( ($sess->{state} || '') eq 'server_handshake' ) {
               MKDEBUG && _d('Expect client authentication packet');
               my ( $user, $buff_len ) = $data =~ m{
                  ^.{18}         # Client flags, max packet size, charset
                  (?:00){23}     # Filler
                  ((?:..)+?)00   # Null-terminated user name
                  (..)           # Length-coding byte for scramble buff
               }x;
               if ( defined $buff_len ) {
                  MKDEBUG && _d('Found user', $user, 'buff_len', $buff_len);
                  my $code_len = hex($buff_len);
                  my ( $database ) = $data =~ m!
                     ^.{64}${user}00..   # Everything matched before
                     (?:..){$code_len}   # The scramble buffer
                     (.*)00\Z            # The database name
                  !x;
                  MKDEBUG && _d('Found databasename', $database);
                  $sess->{state}    = 'client_auth';
                  $sess->{user}     = to_string($user);
                  $sess->{db}       = to_string($database || '');
               }
               else {
                  MKDEBUG && _d('Did not match client auth packet');
               }
            }

            # Otherwise, it should be a query.  We ignore the commands
            # that take arguments (COM_CHANGE_USER, COM_PROCESS_KILL).
            else {
               my $COM = substr($data, 0, 2);
               $data = to_string(substr($data, 2));
               $sess->{ts}         = $ts;
               $sess->{state}      = 'awaiting_reply';
               $sess->{pos_in_log} = $pos_in_log;
               $sess->{cmd}        = {
                  cmd => $COM,
                  arg => $data,
               };
               if ( $COM eq COM_QUIT ) { # Fire right away; will cleanup later.
                  MKDEBUG && _d('Got a COM_QUIT');
                  fire_event(
                     {  cmd       => 'Admin',
                        arg       => 'administrator command: Quit',
                        ts        => $ts,
                     },
                     $pack, $sess, @callbacks
                  );
                  $sess->{state} = 'closing';
                  return 1;
               }
            }
         } # From client to server

      } # There was data in the TCP packet.
      else {
         MKDEBUG && _d('No data in TCP packet');
         # Is the session ready to close?
         if ( ($sess->{state} || '') eq 'closing' ) {
            delete $self->{sessions}->{$sess->{client}};
         }
      }

      $pos_in_log = tell($fh);
   }

   return 0;
}

sub fire_event {
   my ( $event, $packet, $session, @callbacks ) = @_;

   my ($host, $port) = $session->{client} =~ m/((?:\d+\.){3}\d+)\.(\d+)/;
   $event = {
      cmd        => $event->{cmd},
      arg        => $event->{arg},
      bytes      => length( $event->{arg} ),
      ts         => tcp_timestamp( $event->{ts} ),
      host       => $host,
      ip         => $host,
      port       => $port,
      db         => $session->{db},
      user       => $session->{user},
      Thread_id  => $session->{thread_id},
      pos_in_log => $session->{pos_in_log},
      Query_time => timestamp_diff($session->{ts}, $packet =~ m/\A(\S+ \S+)/g),
      Error_no   => ($event->{Error_no} || 0),
   };
   foreach my $callback ( @callbacks ) {
      last unless $event = $callback->($event);
   }
   return 1;

}

# Extracts a slow-log-formatted timestamp from the tcpdump timestamp format.
sub tcp_timestamp {
   my ( $ts ) = @_;
   $ts =~ s/^\d\d(\d\d)-(\d\d)-(\d\d)/$1$2$3/;
   return $ts;
}

# Returns the difference between two tcpdump timestamps.
sub timestamp_diff {
   my ( $start, $end ) = @_;
   my $sd = substr($start, 0, 11, '');
   my $ed = substr($end,   0, 11, '');
   my ( $sh, $sm, $ss ) = split(/:/, $start);
   my ( $eh, $em, $es ) = split(/:/, $end);
   my $esecs = ($eh * 3600 + $em * 60 + $es);
   my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
   if ( $sd eq $ed ) {
      return sprintf '%.6f', $esecs - $ssecs;
   }
   else { # Assume only one day boundary has been crossed, no DST, etc
      return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
   }
}

# Converts hexadecimal to string.
sub to_string {
   my ( $data ) = @_;
   # $data =~ s/(..)/chr(hex $1)/eg;
   $data = pack('H*', $data);
   return $data;
}

# All numbers are stored with the least significant byte first in the MySQL
# protocol.
sub to_num {
   my ( $str ) = @_;
   my @bytes = $str =~ m/(..)/g;
   return hex(join('', reverse @bytes));
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
# End TcpdumpParser package
# ###########################################################################
