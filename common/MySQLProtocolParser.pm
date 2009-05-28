# This program is copyright 2007-2009 Percona Inc.
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
# MySQLProtocolParser package $Revision$
# ###########################################################################
package MySQLProtocolParser;

# This creates events suitable for mk-query-digest from raw MySQL packets.
# The packets come from TcpdumpParser.  MySQLProtocolParse::parse_packet()
# should be first in the callback chain because it creates events for
# subsequent callbacks.  So the sequence is:
#    1. mk-query-digest calls TcpdumpParser::parse_event($fh, ..., @callbacks)
#    2. TcpdumpParser::parse_event() extracts raw MySQL packets from $fh and
#       passes them to the callbacks, the first of which is
#       MySQLProtocolParser::parse_packet().
#    3. MySQLProtocolParser::parse_packet() makes events from the packets
#       and returns them to TcpdumpParser::parse_event().
#    4. TcpdumpParser::parse_event() passes the newly created events to
#       the subsequent callbacks.
# At times MySQLProtocolParser::parse_packet() will not return an event
# because it usually takes a few packets to create one event.  In such
# cases, TcpdumpParser::parse_event() will not call the other callbacks.

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);
use Data::Dumper;
$Data::Dumper::Indent = 1;

require Exporter;
our @ISA         = qw(Exporter);
our %EXPORT_TAGS = ();
our @EXPORT      = ();
our @EXPORT_OK   = qw(
   parse_error_packet
   parse_ok_packet
   parse_server_handshake_packet
   parse_client_handshake_packet
   parse_com_packet
);

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
   SERVER_QUERY_NO_GOOD_INDEX_USED => 16,
   SERVER_QUERY_NO_INDEX_USED      => 32,
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

# server is the "host:port" of the sever being watched.  It's auto-guessed if
# not specified.  version is a placeholder for handling differences between
# MySQL v4.0 and older and v4.1 and newer.  Currently, we only handle v4.1.
sub new {
   my ( $class, %args ) = @_;
   my $self = {
      server    => $args{server},
      version   => '41',
      sessions  => {},
   };
   return bless $self, $class;
}

# The packet arg should be a hashref from TcpdumpParser::parse_event().
# misc is a placeholder for future features.
sub parse_packet {
   my ( $self, $packet, $misc ) = @_;

   my $from   = "$packet->{src_host}:$packet->{src_port}";
   my $to     = "$packet->{dst_host}:$packet->{dst_port}";

   # Auto-detect the server by looking for port 3306 or port "mysql" (sometimes
   # tcpdump will substitute the port by a lookup in /etc/protocols or
   # something).
   $self->{server} ||= $from =~ m/:(?:3306|mysql)$/ ? $from
                     : $to   =~ m/:(?:3306|mysql)$/ ? $to
                     :                                undef;

   my $client = $from eq $self->{server} ? $to : $from;
   MKDEBUG && _d('Client:', $client);

   if ( !exists $self->{sessions}->{$client} ) {
      MKDEBUG && _d('New session');
      $self->{sessions}->{$client} = {
         client => $client,
         ts     => $packet->{ts},
         state  => undef,
      };
   };
   my $session = $self->{sessions}->{$client};

   # Use ref so we modify $packet->{data} in substr(substr($data, ...)) below.
   my $data = \$packet->{data};
   if ( !$$data  ) {
      MKDEBUG && _d('No data in TCP packet');
      # Is the session ready to close?
      if ( ($session->{state} || '') eq 'closing' ) {
         delete $self->{sessions}->{$session->{client}};
      }
      return;
   }

   # A single TCP packet can contain many MySQL packets, but we only
   # look at the first.  The 2nd and subsequent packets are usually
   # parts of a resultset returned by the server, but we're not interested
   # in resultsets.  The first 4 bytes are the packet header: a 3-byte
   # length and a 1-byte sequence.  After that, it depends on what type
   # of packet this is.
   #
   # NOTE: the data is modified by the inmost substr call here!  If we
   # had all the data in the TCP packets, we could change this to a while
   # loop; while get-a-packet-from-$data, do stuff, etc.  But we don't,
   # and we don't want to either.
   my $mysql_hdr = substr($$data, 0, 8, '');
   my $data_len  = to_num(substr($mysql_hdr, 0, 6));
   my $pkt_num   = oct('0x'.substr($mysql_hdr, 6, 2));
   MKDEBUG && _d('MySQL packet: header data', $mysql_hdr,
      'data len (bytes)', $data_len, 'number', $pkt_num);

   $packet->{data_len} = $data_len;

   if ( !$$data ) {
      MKDEBUG && _d('No MySQL data');
      return;
   }

   # The returned event may be empty if no event was ready to be created.
   my $event;
   if ( $from eq $self->{server} ) {
      $event = _packet_from_server($packet, $session, $misc);
   }
   elsif ( $from eq $client ) {
      $event = _packet_from_client($packet, $session, $misc);
   }
   else {
      MKDEBUG && _d('Packet origin unknown');
   }

   MKDEBUG && _d('Done parsing packet; client state:', $session->{state});
   return $event;
}

# Handles a packet from the server given the state of the session.
# The server can send back a lot of different stuff, but luckily
# we're only interested in
#    * Connection handshake packets for the thread_id
#    * OK and Error packets for errors, warnings, etc.
# Anything else is ignored.  Returns an event if one was ready to be
# created, otherwise returns nothing.
sub _packet_from_server {
   my ( $packet, $session, $misc ) = @_;
   die "I need a packet"  unless $packet;
   die "I need a session" unless $session;

   MKDEBUG && _d('Packet is from server; client state:', $session->{state});

   my $data = $packet->{data};
   my $ts   = $packet->{ts};

   # The first byte in the packet indicates whether it's an OK,
   # ERROR, EOF packet.  If it's not one of those, we test
   # whether it's an initialization packet (the first thing the
   # server ever sends the client).  If it's not that, it could
   # be a result set header, field, row data, etc.

   my ( $first_byte ) = substr($data, 0, 2, '');
   MKDEBUG && _d("First byte of packet:", $first_byte);

   if ( $first_byte eq '00' ) { 
      if ( ($session->{state} || '') eq 'client_auth' ) {
         # We logged in OK!  Trigger an admin Connect command.
         $session->{state} = 'ready';
         MKDEBUG && _d('Admin command: Connect');
         return _make_event(
            {  cmd => 'Admin',
               arg => 'administrator command: Connect',
               ts  => $ts, # Events are timestamped when they end
            },
            $packet, $session
         );
      }
      elsif ( $session->{cmd} ) {
         # This OK should be ack'ing a query or something sent earlier
         # by the client.
         my $ok  = parse_ok_packet($data);
         my $com = $session->{cmd}->{cmd};
         my $arg;

         if ( $com eq COM_QUERY ) {
            $com = 'Query';
            $arg = $session->{cmd}->{arg};
         }
         else {
            $arg = 'administrator command: '
                 . ucfirst(lc(substr($com_for{$com}, 4)));
            $com = 'Admin';
         }

         $session->{state} = 'ready';
         return _make_event(
            {  cmd           => $com,
               arg           => $arg,
               ts            => $ts,
               Insert_id     => $ok->{insert_id},
               Warning_count => $ok->{warnings},
               Rows_affected => $ok->{affected_rows},
            },
            $packet, $session
         );
      } 
   }
   elsif ( $first_byte eq 'ff' ) {
      my $error = parse_error_packet($data);
      my $event;

      if ( $session->{state} eq 'client_auth' ) {
         MKDEBUG && _d('Connection failed');
         $event = {
            cmd       => 'Admin',
            arg       => 'administrator command: Connect',
            ts        => $ts,
            Error_no  => $error->{errno},
         };
         $session->{state} = 'closing';
      }
      elsif ( $session->{cmd} ) {
         # This error should be in response to a query or something
         # sent earlier by the client.
         my $com = $session->{cmd}->{cmd};
         my $arg;

         if ( $com eq COM_QUERY ) {
            $com = 'Query';
            $arg = $session->{cmd}->{arg};
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
            Error_no  => $error->{errno},
         };
         $session->{state} = 'ready';
      }

      return _make_event($event, $packet, $session);
   }
   elsif ( $first_byte eq 'fe' && $packet->{data_len} < 9 ) {
      MKDEBUG && _d('Got an EOF packet');
      die "You should not have gotten here";
      # ^^^ We shouldn't reach this because EOF should come after a
      # header, field, or row data packet; and we should be firing the
      # event and returning when we see that.  See SVN history for some
      # good stuff we could do if we wanted to handle EOF packets.
   }
   elsif ( !$session->{state}
           && $first_byte eq '0a'
           && length $data >= 33 )
   {
      # It's the handshake packet from the server to the client.
      # 0a is protocol v10 which is essentially the only version used
      # today.  33 is the minimum possible length for a valid server
      # handshake packet.  It's probably a lot longer.  Other packets
      # may start with 0a, but none that can would be >= 33.
      my $handshake = parse_server_handshake_packet($data);
      $session->{state}     = 'server_handshake';
      $session->{thread_id} = $handshake->{thread_id};
   }
   else {
      MKDEBUG && _d('Got a row/field/result packet');
      # Since we do NOT always have all the data the server sent to the
      # client, we can't always do any processing of results.  So when
      # we get one of these, we just fire the event even if the query
      # is not done.  This means we will NOT process EOF packets
      # themselves (see above).
      if ( $session->{cmd} ) {
         my $com = $session->{cmd}->{cmd};
         MKDEBUG && _d('COM:', $com_for{$com});
         my $event = { ts  => $ts };
         if ( $com eq COM_QUERY ) {
            $event->{cmd} = 'Query';
            $event->{arg} = $session->{cmd}->{arg};
         }
         else {
            $event->{arg} = 'administrator command: '
                 . ucfirst(lc(substr($com_for{$com}, 4)));
            $event->{cmd} = 'Admin';
         }

         # We DID get all the data in the packet.
         if ( $packet->{complete} ) {
            # Look to see if the end of the data appears to be an EOF
            # packet.
            my ( $warning_count, $status_flags )
               = $data =~ m/fe(.{4})(.{4})\Z/;
            if ( $warning_count ) { 
               $event->{Warnings} = to_num($warning_count);
               my $flags = to_num($status_flags); # TODO set all flags?
               $event->{No_good_index_used}
                  = $flags & SERVER_QUERY_NO_GOOD_INDEX_USED ? 1 : 0;
               $event->{No_index_used}
                  = $flags & SERVER_QUERY_NO_INDEX_USED ? 1 : 0;
            }
         }

         $session->{state} = 'ready';
         return _make_event($event, $packet, $session);
      }
   }

   return;
}

# Handles a packet from the client given the state of the session.
# The client doesn't send a wide and exotic array of packets like
# the server.  Even so, we're only interested in:
#    * Users and dbs from connection handshake packets
#    * SQL statements from COM_QUERY commands
# Anything else is ignored.  Returns an event if one was ready to be
# created, otherwise returns nothing.
sub _packet_from_client {
   my ( $packet, $session, $misc ) = @_;
   die "I need a packet"  unless $packet;
   die "I need a session" unless $session;

   MKDEBUG && _d('Packet is from client; state:', $session->{state});

   my $data = $packet->{data};
   my $ts   = $packet->{ts};
 
   if ( ($session->{state} || '') eq 'server_handshake' ) {
      MKDEBUG && _d('Expecting client authentication packet');
      # The connection is a 3-way handshake:
      #    server > client  (protocol version, thread id, etc.)
      #    client > server  (user, pass, default db, etc.)
      #    server > client  OK if login succeeds
      # pos_in_log refers to 2nd handshake from the client.
      # A connection is logged even if the client fails to
      # login (bad password, etc.).
      my $handshake = parse_client_handshake_packet($data);
      $session->{state}      = 'client_auth';
      $session->{pos_in_log} = $packet->{pos_in_log};
      $session->{user}       = $handshake->{user};
      $session->{db}         = $handshake->{db};
   }
   else {
      # Otherwise, it should be a query.  We ignore the commands
      # that take arguments (COM_CHANGE_USER, COM_PROCESS_KILL).
      my $com = parse_com_packet($data, $packet->{data_len});
      $session->{state}      = 'awaiting_reply';
      $session->{pos_in_log} = $packet->{pos_in_log};
      $session->{ts}         = $ts;
      $session->{cmd}        = {
         cmd => $com->{code},
         arg => $com->{data},
      };

      if ( $com->{code} eq COM_QUIT ) { # Fire right away; will cleanup later.
         MKDEBUG && _d('Got a COM_QUIT');
         $session->{state} = 'closing';
         return _make_event(
            {  cmd       => 'Admin',
               arg       => 'administrator command: Quit',
               ts        => $ts,
            },
            $packet, $session
         );
      }
   }

   return;
}

# Make and return an event from the given packet and session.
sub _make_event {
   my ( $event, $packet, $session ) = @_;
   MKDEBUG && _d('Making event');
   my ($host, $port) = $session->{client} =~ m/((?:\d+\.){3}\d+)\:(\w+)/;
   return $event = {
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
      Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
      Error_no   => ($event->{Error_no} || 0),
      Rows_affected      => ($event->{Rows_affected} || 0),
      Warning_count      => ($event->{Warning_count} || 0),
      No_good_index_used => ($event->{No_good_index_used} ? 'Yes' : 'No'),
      No_index_used      => ($event->{No_index_used}      ? 'Yes' : 'No'),
   };
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
   my $result = 0;
   foreach my $i ( 0 .. $#bytes ) {
      $result += hex($bytes[$i]) * (16 ** ($i * 2));
   }
   return $result;
}

# Accepts a reference to a string, which it will modify.  Extracts a
# length-coded binary off the front of the string and returns that value as an
# integer.
sub get_lcb {
   my ( $string ) = @_;
   my $first_byte = hex(substr($$string, 0, 2, ''));
   if ( $first_byte < 251 ) {
      return $first_byte;
   }
   elsif ( $first_byte == 252 ) {
      return to_num(substr($$string, 0, 4, ''));
   }
   elsif ( $first_byte == 253 ) {
      return to_num(substr($$string, 0, 6, ''));
   }
   elsif ( $first_byte == 254 ) {
      return to_num(substr($$string, 0, 16, ''));
   }
}

# Error packet structure:
# Offset  Bytes               Field
# ======  =================   ====================================
#         00 00 00 01         MySQL proto header (already removed)
#         ff                  Error  (already removed)
# 0       00 00               Error number
# 4       00                  SQL state marker, always '#'
# 6       00 00 00 00 00      SQL state
# 16      00 ...              Error message
# The sqlstate marker and actual sqlstate are combined into one value. 
sub parse_error_packet {
   my ( $data ) = @_;
   die "I need data" unless $data;
   MKDEBUG && _d('ERROR data:', $data);
   die "Error packet is too short: $data" if length $data < 16;
   my $errno    = to_num(substr($data, 0, 4));
   my $sqlstate = to_string(substr($data, 4, 12));
   my $message  = to_string(substr($data, 16));
   my $pkt = {
      errno    => $errno,
      sqlstate => $sqlstate,
      message  => $message,
   };
   MKDEBUG && _d('Error packet:', Dumper($pkt));
   return $pkt;
}

# OK packet structure:
# Offset  Bytes               Field
# ======  =================   ====================================
#         00 00 00 01         MySQL proto header (already removed)
#         00                  OK  (already removed)
#         1-9                 Affected rows (LCB)
#         1-9                 Insert ID (LCB)
#         00 00               Server status
#         00 00               Warning count
#         00 ...              Message (optional)
sub parse_ok_packet {
   my ( $data ) = @_;
   die "I need data" unless $data;
   MKDEBUG && _d('OK data:', $data);
   die "OK packet is too short: $data" if length $data < 12;
   my $affected_rows = get_lcb(\$data);
   my $insert_id     = get_lcb(\$data);
   my $status        = to_num(substr($data, 0, 4, ''));
   my $warnings      = to_num(substr($data, 0, 4, ''));
   my $message       = to_string($data);
   # Note: $message is discarded.  It might be something like
   # Records: 2  Duplicates: 0  Warnings: 0
   my $pkt = {
      affected_rows => $affected_rows,
      insert_id     => $insert_id,
      status        => $status,
      warnings      => $warnings,
      message       => $message,
   };
   MKDEBUG && _d('OK packet:', Dumper($pkt));
   return $pkt;
}

# Currently we only capture and return the thread id.
sub parse_server_handshake_packet {
   my ( $data ) = @_;
   die "I need data" unless $data;
   MKDEBUG && _d('Server handshake data:', $data);
   my $handshake_pattern = qr{
                        # Bytes                Name
      ^                 # -----                ----
      (.+?)00           # n Null-Term String   server_version
      (.{8})            # 4                    thread_id
      .{16}             # 8                    scramble_buff
      .{2}              # 1                    filler: always 0x00
      .{4}              # 2                    server_capabilities
      .{2}              # 1                    server_language
      .{4}              # 2                    server_status
      .{26}             # 13                   filler: always 0x00
                        # 13                   rest of scramble_buff
   }x;
   my ( $server_version, $thread_id ) = $data =~ m/$handshake_pattern/;
   my $pkt = {
      server_version => to_string($server_version),
      thread_id      => to_num($thread_id),
   };
   MKDEBUG && _d('Server handshake packet:', Dumper($pkt));
   return $pkt;
}

# Currently we only capture and return the user and default database.
sub parse_client_handshake_packet {
   my ( $data ) = @_;
   die "I need data" unless $data;
   MKDEBUG && _d('Client handshake data:', $data);
   my ( $user, $buff_len ) = $data =~ m{
      ^.{18}         # Client flags, max packet size, charset
      (?:00){23}     # Filler
      ((?:..)+?)00   # Null-terminated user name
      (..)           # Length-coding byte for scramble buff
   }x;

   # This packet is easy to detect because it's the only case where
   # the server sends the client a packet first (its handshake) and
   # then the client only and ever sends back its handshake.
   die "Did not match client handshake packet" unless $buff_len;

   # This length-coded binary doesn't seem to be a normal one, it
   # seems more like a length-coded string actually.
   my $code_len = hex($buff_len);
   my ( $db ) = $data =~ m!
      ^.{64}${user}00..   # Everything matched before
      (?:..){$code_len}   # The scramble buffer
      (.*)00\Z            # The database name
   !x;
   my $pkt = {
      user => to_string($user),
      db   => $db ? to_string($db) : '',
   };
   MKDEBUG && _d('Client handshake packet:', Dumper($pkt));
   return $pkt;
}

# COM data is not 00-terminated, but the the MySQL client appends \0,
# so we have to use the packet length to know where the data ends.
sub parse_com_packet {
   my ( $data, $len ) = @_;
   die "I need data"  unless $data;
   die "I need a len" unless $len;
   MKDEBUG && _d('COM data:', $data, 'len:', $len);
   my $code = substr($data, 0, 2);
   my $com  = $com_for{$code};
   die "Did not match COM packet" unless $com;
   $data    = to_string(substr($data, 2, ($len - 1) * 2));
   my $pkt = {
      code => $code,
      com  => $com,
      data => $data,
   };
   MKDEBUG && _d('COM packet:', Dumper($pkt));
   return $pkt;
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
# End MySQLProtocolParser package
# ###########################################################################
