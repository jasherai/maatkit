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

# TODO: tcpdump -i lo port 3306 -s 1500 -x -n -q

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

sub new {
   my ( $class ) = @_;
   bless {
      pending  => [],
      sessions => {},
   }, $class;
}

my $hdr_line  = qr/^\d\d:/;
my $data_line = qr/^\t0x/;
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
   my $pos_in_log = tell($fh);
   my $packet;

   # there might be a pending line from a previous call
   my $line = shift @{$self->{pending}};

   EVENT:
   while ( defined $line or defined($line = <$fh>) ) {
      chomp $line;

      # It is a data line that belongs to the current packet.
      if ( $line =~ m/$data_line/o ) {
         push @{$packet->{lines}}, substr($line, 10);
      }

      elsif ( $line =~ m/$hdr_line/o ) {

         if ( $packet ) { # Finish off the previous packet
            my ( $ts, $from, $to )
               = $packet->{header} =~ m/^(\S+) IP (\S+) > (\S+):/;
            (my $data = join('', @{$packet->{lines}})) =~ s/\s+//g; 
            my $sess = $self->{sessions}->{$from eq $watching ? $to : $from};

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

               # Now we're down to the MySQL protocol.  The first 4 bytes are the
               # packet header: a 3-byte length and a 1-byte sequence.  After that,
               # it depends on what type of packet this is.  NOTE: the data is
               # modified by the inmost substr call here!
               my $packet_len = to_num(substr(substr($data, 0, 8, ''), 0, 6));
               MKDEBUG && _d('Packet length:', $packet_len);

               # If it's from the server to the client, I care about
               # 1) during the initialization sequence, the thread_id.
               # 2) after that, I care about things like the warning count, etc.
               if ( $from eq $watching ) { # From server to client
                  MKDEBUG && _d('Packet is from server to client');

                  # The first byte in the packet indicates whether it's an OK,
                  # ERROR, EOF packet.  If it's not one of those, we test whether
                  # it's an initialization packet (the first thing the server ever
                  # sends the client).  If it's not that, it could be a result set
                  # header, field, row data, etc.
                  my ( $first_byte ) = substr($data, 0, 2);
                  if ( $first_byte eq '00' ) {
                     MKDEBUG && _d('Got an OK packet');
                     if ( ($sess->{state} || '') eq 'client_auth' ) {
                        $sess->{state} = 'ready';
                        # We logged in OK!  Trigger an admin Connect command.
                        # TODO: how can we capture the time it takes to log in?
                        fire_event(
                           {  cmd => 'Admin',
                              arg => 'administrator command: Connect',
                              ts  => $ts, # Events are timestamped when they end
                           },
                           $packet, $sess, @callbacks
                        );
                        push @{$self->{pending}}, $line;
                        return 1;
                     }
                  }
                  elsif ( $first_byte eq 'ff' ) {
                     MKDEBUG && _d('Got an ERROR packet');
                     MKDEBUG && _d('ERROR',
                        hex(substr($data, 1, 2)),
                        to_string(substring($data, 3)));
                     if ( $sess->{status} eq 'client_auth' ) {
                        MKDEBUG && _d('Connection failed');
                        # TODO: Fire an event?
                        delete $self->{sessions}->{$to};
                     }
                  }
                  elsif ( $first_byte eq 'fe' && $packet_len < 9 ) {
                     MKDEBUG && _d('Got an EOF packet');
                     # The 2nd and 3rd bytes are the warning count.
                     # The 4th and 5th bytes are the server status flags.  The
                     # good ones to look at are SERVER_QUERY_NO_GOOD_INDEX_USED
                     # (16) and SERVER_QUERY_NO_INDEX_USED (32).
                  }
                  elsif ( !$self->{sessions}->{$to}
                     && (my ($thread_id) = $data =~ m/$handshake_pat/o )
                  ) {
                     # It's the handshake packet from the server to the client.
                     # Make a new session.
                     MKDEBUG && _d('Got a handshake for thread_id', $thread_id);
                     $self->{sessions}->{$to} = {
                        id         => to_num($thread_id),
                        state      => 'server_handshake',
                        client     => $to,
                        ts         => $ts,
                        pos_in_log => tell($fh),
                     };
                  }
                  else { # Row data, field, result set header.
                     MKDEBUG && _d('Got a row/field/result packet');
                  }
               }

               # If it's from the client to the server, I care about
               # 1) during the initialization sequence, I want to know the user and
               #    the initial database.  It looks like the best way to detect
               #    this command is by looking for the 23-byte 0x00... filler.  I
               #    only need to do this for sessions that aren't yet initialized.
               # 2) after that, I want to know the query text.
               else {  # From client to server
                  if ( ($sess->{state} || '') eq 'server_handshake' ) {
                     MKDEBUG && _d('Expect client authentication packet');
                     my ( $user, $code_len ) = $data =~ m{
                        ^.{18}         # Client flags, max packet size, charset
                        (?:00){23}     # Filler
                        ((?:..)+?)00   # Null-terminated user name
                        (..)           # Length-coding byte for scramble buff
                     }x;
                     if ( $code_len ) { # We matched.  Continue.
                        MKDEBUG && _d('Found user', $user, 'bufflen', $code_len);
                        $code_len = hex($code_len);
                        my ( $database ) = $data =~ m!
                           ^.{64}${user}00..   # Everything matched before
                           (?:..){$code_len}   # The scramble buffer
                           (.*)00\Z            # The database name
                        !x;
                        MKDEBUG && _d('Found databasename', $database);
                        $sess->{state}    = 'client_auth';
                        $sess->{user}     = to_string($user);
                        $sess->{database} = to_string($database || '');
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
                     $sess->{cmd} = {
                        cmd => $COM,
                        arg => $data,
                     };
                  }
               }
            } # There was data in the TCP packet.
            else {
               MKDEBUG && _d('No data in TCP packet');
            }

         }

         # Start a new packet.
         $packet = {
            header => $line,
            lines  => [],
         };

      }

      $line = undef;
   }
   return 0;
}

sub fire_event {
   my ( $event, $packet, $session, @callbacks ) = @_;

   my ($host, $port) = $session->{client} =~ m/((?:\d+\.){3}\d+)\.(\d+)/;
   $event = {
      cmd => $event->{cmd},
      arg => $event->{arg},
      bytes => length($event->{arg}),
      ts    => tcp_timestamp($event->{ts}),
      host  => $host,
      ip    => $host,
      port  => $port,
      db    => $session->{db},
      user  => $session->{user},
      pos_in_log => $session->{pos_in_log},
      Query_time => timestamp_diff($session->{ts}, $packet->{header} =~ m/^(\S+)/g),
   };
   foreach my $callback ( @callbacks ) {
      last unless $event = $callback->($event);
   }
   return 1;

}

# Assumes the day is today.
sub tcp_timestamp {
   my ( $ts ) = @_;
   my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime;
   $mon  += 1;
   $year += 1900;
   return sprintf("%02d%02d%02d %s", substr($year, 2), $mon, $mday, $ts);
}

sub timestamp_diff {
   my ( $start, $end ) = @_;
   my ( $sh, $sm, $ss ) = split(/:/, $start);
   my ( $eh, $em, $es ) = split(/:/, $end);
   return ($eh * 3600 + $em * 60 + $es) - ($sh * 3600 + $sm * 60 + $ss);
}

sub to_string {
   my ( $data ) = @_;
   $data =~ s/(..)/chr(hex $1)/eg;
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
