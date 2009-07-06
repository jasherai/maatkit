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
# MemcachedProtocolParser package $Revision$
# ###########################################################################
package MemcachedProtocolParser;

use strict;
use warnings FATAL => 'all';
use English qw(-no_match_vars);

use Data::Dumper;
$Data::Dumper::Indent    = 1;
$Data::Dumper::Sortkeys  = 1;
$Data::Dumper::Quotekeys = 0;

use constant MKDEBUG => $ENV{MKDEBUG};

# server is the "host:port" of the sever being watched.  It's auto-guessed if
# not specified.
sub new {
   my ( $class, %args ) = @_;
   my $self = {
      server      => $args{server},
      sessions    => {},
      o           => $args{o},
      raw_packets => [],  # Raw tcpdump packets before event.
   };
   return bless $self, $class;
}

# The packet arg should be a hashref from TcpdumpParser::parse_event().
# misc is a placeholder for future features.
sub parse_packet {
   my ( $self, $packet, $misc ) = @_;

   # Auto-detect the server by looking for port 11211
   my $from  = "$packet->{src_host}:$packet->{src_port}";
   my $to    = "$packet->{dst_host}:$packet->{dst_port}";
   $self->{server} ||= $from =~ m/:(?:11211)$/ ? $from
                     : $to   =~ m/:(?:11211)$/ ? $to
                     :                           undef;
   my $client = $from eq $self->{server} ? $to : $from;
   MKDEBUG && _d('Client:', $client);

   # Get the client's session info or create a new session if the
   # client hasn't been seen before.
   if ( !exists $self->{sessions}->{$client} ) {
      MKDEBUG && _d('New session');
      $self->{sessions}->{$client} = {
         client      => $client,
         ts          => $packet->{ts},
         state       => undef,
      };
   };
   my $session = $self->{sessions}->{$client};

   # Return early if there's no TCP data.  These are usually ACK packets, but
   # they could also be FINs in which case, we should close and delete the
   # client's session.
   if ( $packet->{data_len} == 0 ) {
      MKDEBUG && _d('No TCP data');
      # Is the session ready to close? TODO: the session is never set to this
      # state is it?
      if ( ($session->{state} || '') eq 'closing' ) {
         delete $self->{sessions}->{$session->{client}};
         MKDEBUG && _d('Session deleted'); 
      }
      return;
   }

   # Finally, parse the packet and maybe create an event.
   $packet->{data} = pack('H*', $packet->{data});
   my $event;
   if ( $from eq $self->{server} ) {
      $event = $self->_packet_from_server($packet, $session, $misc);
   }
   elsif ( $from eq $client ) {
      $self->_packet_from_client($packet, $session, $misc);
   }
   else {
      MKDEBUG && _d('Packet origin unknown');
   }

   MKDEBUG && _d('Done parsing packet; client state:', $session->{state});
   return $event;
}

# Handles a packet from the server given the state of the session.  Returns an
# event if one was ready to be created, otherwise returns nothing.
sub _packet_from_server {
   my ( $self, $packet, $session, $misc ) = @_;
   die "I need a packet"  unless $packet;
   die "I need a session" unless $session;

   MKDEBUG && _d('Packet is from server; client state:', $session->{state});
   push @{$self->{raw_packets}}, $packet->{raw_packet};

   my $data = $packet->{data};

   # If there's no session state, then we're catching a server response
   # mid-stream.
   if ( !$session->{state} ) {
      MKDEBUG && _d('Ignoring mid-stream server response');
      return;
   }
   else {
      # Assume that the server is returning only one value.  TODO: make it
      # handle multi-gets.
      my ($line1, $rest) = $packet->{data} =~ m/\A(.*?)\r\n(.*)?/s;

      # Split up the first line into its parts.
      my ($res, $key, $flags, $bytes, $val);
      my @vals = $line1 =~ m/(\S+)/g;
      $res = shift @vals;
      if ( $session->{cmd} eq 'incr' || $session->{cmd} eq 'decr' ) {
         if ( $res !~ m/\D/ ) { # It's an integer, not an error
            $val = $res;
            $res = '';
         }
      }
      elsif ( $res eq 'VALUE' ) {
         ($key, $flags, $bytes) = @vals;
         # Get the value from the $rest.  TODO: there might be multiple responses,
         # and we might not get the whole thing in one packet.
         if ( $rest && $bytes && length($rest) > $bytes ) {
            $val = substr($rest, 0, $bytes);
         }
      }

      $session->{state} = 'awaiting command';
      return {
         ts         => $session->{ts},
         host       => $session->{host},
         flags      => defined $session->{flags} ? $session->{flags} : $flags,
         exptime    => $session->{exptime},
         bytes      => defined $session->{bytes} ? $session->{bytes} : $bytes,
         cmd        => $session->{cmd},
         key        => $session->{key},
         val        => defined $session->{val} ? $session->{val} : $val,
         res        => $res,
         Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
         pos_in_log => $session->{pos_in_log},
      };
   }

   return;
}

# Handles a packet from the client given the state of the session.  Doesn't
# return events, but creates the event that'll be returned later.
sub _packet_from_client {
   my ( $self, $packet, $session, $misc ) = @_;
   die "I need a packet"  unless $packet;
   die "I need a session" unless $session;

   MKDEBUG && _d('Packet is from client; state:', $session->{state});
   push @{$self->{raw_packets}}, $packet->{raw_packet};
   my ($line1, $val) = $packet->{data} =~ m/\A(.*?)\r\n(.+)?/s;

   # Split up the first line into its parts.
   # TODO: handle <cas unique> and [noreply]
   my ($cmd, $key, $flags, $exptime, $bytes);
   my @vals = $line1 =~ m/(\S+)/g;
   $cmd = lc shift @vals;
   if ( $cmd eq 'set' ) {
      ($key, $flags, $exptime, $bytes) = @vals;
   }
   elsif ( $cmd eq 'get' ) {
      ($key) = @vals;
   }
   elsif ( $cmd eq 'incr' || $cmd eq 'decr' ) {
      ($key) = @vals;
   }

   # Handle the rest of the packet.  It might not be the whole packet.  We need
   # to look at the number of bytes in a SET and see if we got it all.  TODO
   if ( $val ) {
      $val =~ s/\r\n\Z//;
   }

   @{$session}{qw(cmd key flags exptime bytes val)}
      = ($cmd, $key, $flags, $exptime, $bytes, $val);
   $session->{host}  = $packet->{src_host};
   $session->{state} = 'awaiting reply'; # TODO: might not be done
   $session->{pos_in_log} = $packet->{pos_in_log};

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
      my $session_dump = '# ' . Dumper($session);
      chomp $session_dump;
      $session_dump =~ s/\n/\n# /g;
      print $errors_fh "$session_dump\n";
      {
         local $LIST_SEPARATOR = "\n";
         print $errors_fh "@{$self->{raw_packets}}";
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

# Returns the difference between two tcpdump timestamps.  TODO: this is in
# MySQLProtocolParser too, best to factor it out somewhere common.
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

1;

# ###########################################################################
# End MemcachedProtocolParser package
# ###########################################################################
