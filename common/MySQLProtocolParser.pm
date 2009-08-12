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

eval {
   require IO::Uncompress::Inflate;
   IO::Uncompress::Inflate->import(qw(inflate $InflateError));
};

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

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
   parse_flags
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

my %flag_for = (
   'CLIENT_LONG_PASSWORD'     => 1,       # new more secure passwords 
   'CLIENT_FOUND_ROWS'        => 2,       # Found instead of affected rows 
   'CLIENT_LONG_FLAG'         => 4,       # Get all column flags 
   'CLIENT_CONNECT_WITH_DB'   => 8,       # One can specify db on connect 
   'CLIENT_NO_SCHEMA'         => 16,      # Don't allow database.table.column 
   'CLIENT_COMPRESS'          => 32,      # Can use compression protocol 
   'CLIENT_ODBC'              => 64,      # Odbc client 
   'CLIENT_LOCAL_FILES'       => 128,     # Can use LOAD DATA LOCAL 
   'CLIENT_IGNORE_SPACE'      => 256,     # Ignore spaces before '(' 
   'CLIENT_PROTOCOL_41'       => 512,     # New 4.1 protocol 
   'CLIENT_INTERACTIVE'       => 1024,    # This is an interactive client 
   'CLIENT_SSL'               => 2048,    # Switch to SSL after handshake 
   'CLIENT_IGNORE_SIGPIPE'    => 4096,    # IGNORE sigpipes 
   'CLIENT_TRANSACTIONS'      => 8192,    # Client knows about transactions 
   'CLIENT_RESERVED'          => 16384,   # Old flag for 4.1 protocol  
   'CLIENT_SECURE_CONNECTION' => 32768,   # New 4.1 authentication 
   'CLIENT_MULTI_STATEMENTS'  => 65536,   # Enable/disable multi-stmt support 
   'CLIENT_MULTI_RESULTS'     => 131072,  # Enable/disable multi-results 
);

# server is the "host:port" of the sever being watched.  It's auto-guessed if
# not specified.  version is a placeholder for handling differences between
# MySQL v4.0 and older and v4.1 and newer.  Currently, we only handle v4.1.
sub new {
   my ( $class, %args ) = @_;

   my ( $server_port )
      = $args{server} ? $args{server} =~ m/:(\w+)/ : ('3306|mysql');
   $server_port ||= '3306|mysql';  # In case $args{server} doesn't have a port.

   my $self = {
      server         => $args{server},
      server_port    => $server_port,
      version        => '41',    # MySQL proto version; not used yet
      sessions       => {},
      o              => $args{o},
      fake_thread_id => 2**32,   # see _make_event()
   };
   MKDEBUG && $self->{server} && _d('Watching only server', $self->{server});
   return bless $self, $class;
}

# The packet arg should be a hashref from TcpdumpParser::parse_event().
# misc is a placeholder for future features.
sub parse_packet {
   my ( $self, $packet, $misc ) = @_;

   my $src_host = "$packet->{src_host}:$packet->{src_port}";
   my $dst_host = "$packet->{dst_host}:$packet->{dst_port}";

   if ( my $server = $self->{server} ) {  # Watch only the given server.
      if ( $src_host ne $server && $dst_host ne $server ) {
         MKDEBUG && _d('Packet is not to or from', $server);
         return;
      }
   }

   # Auto-detect the server by looking for port 3306 or port "mysql" (sometimes
   # tcpdump will substitute the port by a lookup in /etc/protocols).
   my $packet_from;
   my $client;
   if ( $src_host =~ m/:$self->{server_port}$/ ) {
      $packet_from = 'server';
      $client      = $dst_host;
   }
   elsif ( $dst_host =~ m/:$self->{server_port}$/ ) {
      $packet_from = 'client';
      $client      = $src_host;
   }
   else {
      warn 'Packet is not to or from MySQL server: ', Dumper($packet);
      return;
   }
   MKDEBUG && _d('Client:', $client);

   # Get the client's session info or create a new session if the
   # client hasn't been seen before.
   if ( !exists $self->{sessions}->{$client} ) {
      MKDEBUG && _d('New session');
      $self->{sessions}->{$client} = {
         client      => $client,
         ts          => $packet->{ts},
         state       => undef,
         compress    => undef,
         raw_packets => [],
      };
   };
   my $session = $self->{sessions}->{$client};

   # Return early if there's TCP/MySQL data.  These are usually ACK
   # packets, but they could also be FINs in which case, we should close
   # and delete the client's session.
   if ( $packet->{data_len} == 0 ) {
      MKDEBUG && _d('No TCP/MySQL data');
      # Is the session ready to close?
      if ( ($session->{state} || '') eq 'closing' ) {
         delete $self->{sessions}->{$session->{client}};
         MKDEBUG && _d('Session deleted'); 
      }
      return;
   }

   # Save raw packets to dump later in case something fails.
   push @{$session->{raw_packets}}, $packet->{raw_packet};

   # Return unless the compressed packet can be uncompressed.
   # If it cannot, then we're helpless and must return.
   if ( $session->{compress} ) {
      return unless $self->uncompress_packet($packet, $session);
   }

   # Remove the first MySQL header.  A single TCP packet can contain many
   # MySQL packets, but we only look at the first.  The 2nd and subsequent
   # packets are usually parts of a resultset returned by the server, but
   # we're not interested in resultsets.
   eval {
      remove_mysql_header($packet);
   };
   if ( $EVAL_ERROR ) {
      MKDEBUG && _d('remove_mysql_header() failed; failing session');
      $session->{EVAL_ERROR} = $EVAL_ERROR;
      $self->fail_session($session, 'remove_mysql_header() failed');
      return;
   }

   # Finally, parse the packet and maybe create an event.
   # The returned event may be empty if no event was ready to be created.
   my $event;
   if ( $packet_from eq 'server' ) {
      $event = $self->_packet_from_server($packet, $session, $misc);
   }
   elsif ( $packet_from eq 'client' ) {
      $event = $self->_packet_from_client($packet, $session, $misc);
   }
   else {
      # Should not get here.
      die 'Packet origin unknown';
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
   my ( $self, $packet, $session, $misc ) = @_;
   die "I need a packet"  unless $packet;
   die "I need a session" unless $session;

   MKDEBUG && _d('Packet is from server; client state:', $session->{state}); 

   if ( ($session->{server_seq} || '') eq $packet->{seq} ) {
      push @{ $session->{server_retransmissions} }, $packet->{seq};
      MKDEBUG && _d('TCP retransmission');
      return;
   }
   $session->{server_seq} = $packet->{seq};

   my $data = $packet->{data};

   # The first byte in the packet indicates whether it's an OK,
   # ERROR, EOF packet.  If it's not one of those, we test
   # whether it's an initialization packet (the first thing the
   # server ever sends the client).  If it's not that, it could
   # be a result set header, field, row data, etc.

   my ( $first_byte ) = substr($data, 0, 2, '');
   MKDEBUG && _d('First byte of packet:', $first_byte);
   if ( !$first_byte ) {
      $self->fail_session($session, 'no first byte');
      return;
   }

   # If there's no session state, then we're catching a server response
   # mid-stream.  It's only safe to wait until the client sends a command
   # or to look for the server handshake.
   if ( !$session->{state} ) {
      if ( $first_byte eq '0a' && length $data >= 33 && $data =~ m/00{13}/ ) {
         # It's the handshake packet from the server to the client.
         # 0a is protocol v10 which is essentially the only version used
         # today.  33 is the minimum possible length for a valid server
         # handshake packet.  It's probably a lot longer.  Other packets
         # may start with 0a, but none that can would be >= 33.  The 13-byte
         # 00 scramble buffer is another indicator.
         my $handshake = parse_server_handshake_packet($data);
         if ( !$handshake ) {
            $self->fail_session($session, 'failed to parse server handshake');
            return;
         }
         $session->{state}     = 'server_handshake';
         $session->{thread_id} = $handshake->{thread_id};
      }
      else {
         MKDEBUG && _d('Ignoring mid-stream server response');
         return;
      }
   }
   else {
      if ( $first_byte eq '00' ) { 
         if ( ($session->{state} || '') eq 'client_auth' ) {
            # We logged in OK!  Trigger an admin Connect command.

            $session->{compress} = $session->{will_compress};
            delete $session->{will_compress};
            MKDEBUG && $session->{compress} && _d('Packets will be compressed');

            MKDEBUG && _d('Admin command: Connect');
            return $self->_make_event(
               {  cmd => 'Admin',
                  arg => 'administrator command: Connect',
                  ts  => $packet->{ts}, # Events are timestamped when they end
               },
               $packet, $session
            );
         }
         elsif ( $session->{cmd} ) {
            # This OK should be ack'ing a query or something sent earlier
            # by the client.
            my $ok  = parse_ok_packet($data);
            if ( !$ok ) {
               $self->fail_session($session, 'failed to parse OK packet');
               return;
            }
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

            return $self->_make_event(
               {  cmd           => $com,
                  arg           => $arg,
                  ts            => $packet->{ts},
                  Insert_id     => $ok->{insert_id},
                  Warning_count => $ok->{warnings},
                  Rows_affected => $ok->{affected_rows},
               },
               $packet, $session
            );
         } 
         else {
            MKDEBUG && _d('Looks like an OK packet but session has no cmd');
         }
      }
      elsif ( $first_byte eq 'ff' ) {
         my $error = parse_error_packet($data);
         if ( !$error ) {
            $self->fail_session($session, 'failed to parse error packet');
            return;
         }
         my $event;

         if ( $session->{state} eq 'client_auth' ) {
            MKDEBUG && _d('Connection failed');
            $event = {
               cmd       => 'Admin',
               arg       => 'administrator command: Connect',
               ts        => $packet->{ts},
               Error_no  => $error->{errno} ? "#$error->{errno}" : 'none',
            };
            return $self->_make_event($event, $packet, $session);
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
               ts        => $packet->{ts},
               Error_no  => $error->{errno} ? "#$error->{errno}" : 'none',
            };
            return $self->_make_event($event, $packet, $session);
         }
         else {
            MKDEBUG && _d('Looks like an error packet but client is not '
               . 'authenticating and session has no cmd');
         }
      }
      elsif ( $first_byte eq 'fe' && $packet->{mysql_data_len} < 9 ) {
         # EOF packet
         if ( $packet->{mysql_data_len} == 1
              && $session->{state} eq 'client_auth'
              && $packet->{number} == 2 )
         {
            MKDEBUG && _d('Server has old password table;',
               'client will resend password using old algorithm');
            $session->{state} = 'client_auth_resend';
         }
         else {
            MKDEBUG && _d('Got an EOF packet');
            die "Got an unexpected EOF packet";
            # ^^^ We shouldn't reach this because EOF should come after a
            # header, field, or row data packet; and we should be firing the
            # event and returning when we see that.  See SVN history for some
            # good stuff we could do if we wanted to handle EOF packets.
         }
      }
      else {
         # Since we do NOT always have all the data the server sent to the
         # client, we can't always do any processing of results.  So when
         # we get one of these, we just fire the event even if the query
         # is not done.  This means we will NOT process EOF packets
         # themselves (see above).
         if ( $session->{cmd} ) {
            MKDEBUG && _d('Got a row/field/result packet');
            my $com = $session->{cmd}->{cmd};
            MKDEBUG && _d('Responding to client', $com_for{$com});
            my $event = { ts  => $packet->{ts} };
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

            return $self->_make_event($event, $packet, $session);
         }
         else {
            MKDEBUG && _d('Unknown in-stream server response');
         }
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
   my ( $self, $packet, $session, $misc ) = @_;
   die "I need a packet"  unless $packet;
   die "I need a session" unless $session;

   MKDEBUG && _d('Packet is from client; state:', $session->{state}); 

   if ( ($session->{client_seq} || '') eq $packet->{seq} ) {
      push @{ $session->{client_retransmissions} }, $packet->{seq};
      MKDEBUG && _d('TCP retransmission');
      return;
   }
   $session->{client_seq} = $packet->{seq};

   my $data  = $packet->{data};
   my $ts    = $packet->{ts};

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
      if ( !$handshake ) {
         $self->fail_session($session, 'failed to parse client handshake');
         return;
      }
      $session->{state}         = 'client_auth';
      $session->{pos_in_log}    = $packet->{pos_in_log};
      $session->{user}          = $handshake->{user};
      $session->{db}            = $handshake->{db};

      # $session->{will_compress} will become $session->{compress} when
      # the server's final handshake packet is received.  This prevents
      # parse_packet() from trying to decompress that final packet.
      # Compressed packets can only begin after the full handshake is done.
      $session->{will_compress} = $handshake->{flags}->{CLIENT_COMPRESS};
   }
   elsif ( ($session->{state} || '') eq 'client_auth_resend' ) {
      # Don't know how to parse this packet.
      MKDEBUG && _d('Client resending password using old algorithm');
      $session->{state} = 'client_auth';
   }
   elsif ( ($session->{state} || '') eq 'awaiting_reply' ) {
      my $arg = $session->{cmd}->{arg} ? substr($session->{cmd}->{arg}, 0, 50)
              : 'unknown';
      MKDEBUG && _d('More data for previous command:', $arg, '...'); 
      return;
   }
   else {
      # Otherwise, it should be a query.  We ignore the commands
      # that take arguments (COM_CHANGE_USER, COM_PROCESS_KILL).

      # Detect compression in-stream only if $session->{compress} is
      # not defined.  This means we didn't see the client handshake.
      # If we had seen it, $session->{compress} would be defined as 0 or 1.
      if ( !defined $session->{compress} ) {
         return unless $self->detect_compression($packet, $session);
         $data = $packet->{data};
      }

      my $com = parse_com_packet($data, $packet->{mysql_data_len});
      if ( !$com ) {
         $self->fail_session($session, 'failed to parse COM packet');
         return;
      }
      $session->{state}      = 'awaiting_reply';
      $session->{pos_in_log} = $packet->{pos_in_log};
      $session->{ts}         = $ts;
      $session->{cmd}        = {
         cmd => $com->{code},
         arg => $com->{data},
      };

      if ( $com->{code} eq COM_QUIT ) { # Fire right away; will cleanup later.
         MKDEBUG && _d('Got a COM_QUIT');
         return $self->_make_event(
            {  cmd       => 'Admin',
               arg       => 'administrator command: Quit',
               ts        => $ts,
            },
            $packet, $session
         );
         $session->{state} = 'closing';
      }
   }

   return;
}

# Make and return an event from the given packet and session.
sub _make_event {
   my ( $self, $event, $packet, $session ) = @_;
   MKDEBUG && _d('Making event');

   # Clear packets that preceded this event.
   $session->{raw_packets} = [];

   if ( !$session->{thread_id} ) {
      # Only the server handshake packet gives the thread id, so for
      # sessions caught mid-stream we assign a fake thread id.
      MKDEBUG && _d('Giving session fake thread id', $self->{fake_thread_id});
      $session->{thread_id} = $self->{fake_thread_id}++;
   }

   my ($host, $port) = $session->{client} =~ m/((?:\d+\.){3}\d+)\:(\w+)/;
   my $new_event = {
      cmd        => $event->{cmd},
      arg        => $event->{arg},
      bytes      => length( $event->{arg} ),
      ts         => tcp_timestamp( $event->{ts} ),
      host       => $host,
      Client     => "$host:$port",
      ip         => $host,
      port       => $port,
      db         => $session->{db},
      user       => $session->{user},
      Thread_id  => $session->{thread_id},
      pos_in_log => $session->{pos_in_log},
      Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
      Error_no   => $event->{Error_no} || 'none',
      Rows_affected      => ($event->{Rows_affected} || 0),
      Warning_count      => ($event->{Warning_count} || 0),
      No_good_index_used => ($event->{No_good_index_used} ? 'Yes' : 'No'),
      No_index_used      => ($event->{No_index_used}      ? 'Yes' : 'No'),
   };
   MKDEBUG && _d('Properties of event:', Dumper($new_event));

   # Delete cmd to prevent re-making the same event if the
   # server sends extra stuff that looks like a result set, etc.
   delete $session->{cmd};

   # Undef the session state so that we ignore everything from
   # the server and wait until the client says something again.
   $session->{state} = undef;

   return $new_event;
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
# 4       23                  SQL state marker, always '#'
# 6       00 00 00 00 00      SQL state
# 16      00 ...              Error message
# The sqlstate marker and actual sqlstate are combined into one value. 
sub parse_error_packet {
   my ( $data ) = @_;
   die "I need data" unless $data;
   MKDEBUG && _d('ERROR data:', $data);
   if ( length $data < 16 ) {
      MKDEBUG && _d('Error packet is too short:', $data);
      return;
   }
   my $errno    = to_num(substr($data, 0, 4));
   my $marker   = to_string(substr($data, 4, 2));
   return unless $marker eq '#';
   my $sqlstate = to_string(substr($data, 6, 10));
   my $message  = to_string(substr($data, 16));
   my $pkt = {
      errno    => $errno,
      sqlstate => $marker . $sqlstate,
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
   if ( length $data < 12 ) {
      MKDEBUG && _d('OK packet is too short:', $data);
      return;
   }
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
      (.{4})            # 2                    server_capabilities
      .{2}              # 1                    server_language
      .{4}              # 2                    server_status
      .{26}             # 13                   filler: always 0x00
                        # 13                   rest of scramble_buff
   }x;
   my ( $server_version, $thread_id, $flags ) = $data =~ m/$handshake_pattern/;
   my $pkt = {
      server_version => to_string($server_version),
      thread_id      => to_num($thread_id),
      flags          => parse_flags($flags),
   };
   MKDEBUG && _d('Server handshake packet:', Dumper($pkt));
   return $pkt;
}

# Currently we only capture and return the user and default database.
sub parse_client_handshake_packet {
   my ( $data ) = @_;
   die "I need data" unless $data;
   MKDEBUG && _d('Client handshake data:', $data);
   my ( $flags, $user, $buff_len ) = $data =~ m{
      ^
      (.{8})         # Client flags
      .{10}          # Max packet size, charset
      (?:00){23}     # Filler
      ((?:..)+?)00   # Null-terminated user name
      (..)           # Length-coding byte for scramble buff
   }x;

   # This packet is easy to detect because it's the only case where
   # the server sends the client a packet first (its handshake) and
   # then the client only and ever sends back its handshake.
   if ( !$buff_len ) {
      MKDEBUG && _d('Did not match client handshake packet');
      return;
   }

   # This length-coded binary doesn't seem to be a normal one, it
   # seems more like a length-coded string actually.
   my $code_len = hex($buff_len);
   my ( $db ) = $data =~ m!
      ^.{64}${user}00..   # Everything matched before
      (?:..){$code_len}   # The scramble buffer
      (.*)00\Z            # The database name
   !x;
   my $pkt = {
      user  => to_string($user),
      db    => $db ? to_string($db) : '',
      flags => parse_flags($flags),
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
   if ( !$com ) {
      MKDEBUG && _d('Did not match COM packet');
      return;
   }
   $data    = to_string(substr($data, 2, ($len - 1) * 2));
   my $pkt = {
      code => $code,
      com  => $com,
      data => $data,
   };
   MKDEBUG && _d('COM packet:', Dumper($pkt));
   return $pkt;
}

sub parse_flags {
   my ( $flags ) = @_;
   die "I need flags" unless $flags;
   MKDEBUG && _d('Flag data:', $flags);
   my %flags     = %flag_for;
   my $flags_dec = to_num($flags);
   foreach my $flag ( keys %flag_for ) {
      my $flagno    = $flag_for{$flag};
      $flags{$flag} = ($flags_dec & $flagno ? 1 : 0);
   }
   return \%flags;
}

# Takes a scalarref to a hex string of compressed data.
# Returns a scalarref to a hex string of the uncompressed data.
# The given hex string of compressed data is not modified.
sub uncompress_data {
   my ( $data, $len ) = @_;
   die "I need data" unless $data;
   die "I need a len argument" unless $len;
   die "I need a scalar reference to data" unless ref $data eq 'SCALAR';
   MKDEBUG && _d('Uncompressing data');
   our $InflateError;

   # Pack hex string into compressed binary data.
   my $comp_bin_data = pack('H*', $$data);

   # Uncompress the compressed binary data.
   my $uncomp_bin_data = '';
   my $z = new IO::Uncompress::Inflate(
      \$comp_bin_data
   ) or die "IO::Uncompress::Inflate failed: $InflateError";
   my $status = $z->read(\$uncomp_bin_data, $len)
      or die "IO::Uncompress::Inflate failed: $InflateError";

   # Unpack the uncompressed binary data back into a hex string.
   # This is the original MySQL packet(s).
   my $uncomp_data = unpack('H*', $uncomp_bin_data);

   return \$uncomp_data;
}

# Returns 1 on success or 0 on failure.  Failure is probably
# detecting compression but not being able to uncompress
# (uncompress_packet() returns 0).
sub detect_compression {
   my ( $self, $packet, $session ) = @_;
   MKDEBUG && _d('Checking for client compression');
   # This is a necessary hack for detecting compression in-stream without
   # having seen the client handshake and CLIENT_COMPRESS flag.  If the
   # client is compressing packets, there will be an extra 7 bytes before
   # the regular MySQL header.  For short COM_QUERY commands, these 7 bytes
   # are usually zero where we'd expect to see 03 for COM_QUERY.  So if we
   # parse this packet and it looks like a COM_SLEEP (00) which is not a
   # command that the client can send, then chances are the client is using
   # compression.
   my $com = parse_com_packet($packet->{data}, $packet->{data_len});
   if ( $com && $com->{code} eq COM_SLEEP ) {
      MKDEBUG && _d('Client is using compression');
      $session->{compress} = 1;

      # Since parse_packet() didn't know the packet was compressed, it
      # called remove_mysql_header() which removed the first 4 of 7 bytes
      # of the compression header.  We must restore these 4 bytes, then
      # uncompress and remove the MySQL header.  We only do this once.
      $packet->{data} = $packet->{mysql_hdr} . $packet->{data};
      return 0 unless $self->uncompress_packet($packet, $session);
      remove_mysql_header($packet);
   }
   else {
      MKDEBUG && _d('Client is NOT using compression');
      $session->{compress} = 0;
   }
   return 1;
}

# Returns 1 if the packet was uncompressed or 0 if we can't uncompress.
# Failure is usually due to IO::Uncompress not being available.
sub uncompress_packet {
   my ( $self, $packet, $session ) = @_;
   die "I need a packet"  unless $packet;
   die "I need a session" unless $session;

   # From the doc: "A compressed packet header is:
   #    packet length (3 bytes),
   #    packet number (1 byte),
   #    and Uncompressed Packet Length (3 bytes).
   # The Uncompressed Packet Length is the number of bytes
   # in the original, uncompressed packet. If this is zero
   # then the data is not compressed."

   my $data;
   my $comp_hdr;
   my $comp_data_len;
   my $pkt_num;
   my $uncomp_data_len;
   eval {
      $data            = \$packet->{data};
      $comp_hdr        = substr($$data, 0, 14, '');
      $comp_data_len   = to_num(substr($comp_hdr, 0, 6));
      $pkt_num         = to_num(substr($comp_hdr, 6, 2));
      $uncomp_data_len = to_num(substr($comp_hdr, 8, 6));
      MKDEBUG && _d('Compression header data:', $comp_hdr,
         'compressed data len (bytes)', $comp_data_len,
         'number', $pkt_num,
         'uncompressed data len (bytes)', $uncomp_data_len);
   };
   if ( $EVAL_ERROR ) {
      $session->{EVAL_ERROR} = $EVAL_ERROR;
      $self->fail_session($session, 'failed to parse compression header');
      return 0;
   }

   if ( $uncomp_data_len ) {
      eval {
         $data = uncompress_data($data, $uncomp_data_len);
         $packet->{data} = $$data;
      };
      if ( $EVAL_ERROR ) {
         $session->{EVAL_ERROR} = $EVAL_ERROR;
         $self->fail_session($session, 'failed to uncompress data');
         die "Cannot uncompress packet.  Check that IO::Uncompress::Inflate "
            . "is installed.\nError: $EVAL_ERROR";
      }
   }
   else {
      MKDEBUG && _d('Packet is not really compressed');
      $packet->{data} = $$data;
   }

   return 1;
}

# Removes the first 4 bytes of the packet data which should be
# a MySQL header: 3 bytes packet length, 1 byte packet number.
sub remove_mysql_header {
   my ( $packet ) = @_;
   die "I need a packet" unless $packet;

   # NOTE: the data is modified by the inmost substr call here!  If we
   # had all the data in the TCP packets, we could change this to a while
   # loop; while get-a-packet-from-$data, do stuff, etc.  But we don't,
   # and we don't want to either.
   my $mysql_hdr      = substr($packet->{data}, 0, 8, '');
   my $mysql_data_len = to_num(substr($mysql_hdr, 0, 6));
   my $pkt_num        = to_num(substr($mysql_hdr, 6, 2));
   MKDEBUG && _d('MySQL packet: header data', $mysql_hdr,
      'data len (bytes)', $mysql_data_len, 'number', $pkt_num);

   $packet->{mysql_hdr}      = $mysql_hdr;
   $packet->{mysql_data_len} = $mysql_data_len;
   $packet->{number}         = $pkt_num;

   return;
}

sub _get_errors_fh {
   my ( $self ) = @_;
   my $errors_fh = $self->{errors_fh};
   return $errors_fh if $errors_fh;

   # Errors file isn't open yet; try to open it.
   my $o = $self->{o};
   if ( $o && $o->has('tcpdump-errors') && $o->got('tcpdump-errors') ) {
      my $errors_file = $o->get('tcpdump-errors');
      MKDEBUG && _d('tcpdump-errors file:', $errors_file);
      open $errors_fh, '>>', $errors_file
         or die "Cannot open tcpdump-errors file $errors_file: $OS_ERROR";
   }

   $self->{errors_fh} = $errors_fh;
   return $errors_fh;
}

sub fail_session {
   my ( $self, $session, $reason ) = @_;
   my $errors_fh = $self->_get_errors_fh();
   if ( $errors_fh ) {
      $session->{reason_for_failure} = $reason;
      my $session_dump = '# ' . Dumper($session);
      chomp $session_dump;
      $session_dump =~ s/\n/\n# /g;
      print $errors_fh "$session_dump\n";
      {
         local $LIST_SEPARATOR = "\n";
         print $errors_fh "@{$session->{raw_packets}}";
         print $errors_fh "\n";
      }
   }
   MKDEBUG && _d('Failed session', $session->{client}, 'because', $reason);
   delete $self->{sessions}->{$session->{client}};
   return;
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
