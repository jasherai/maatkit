# This program is copyright 2009 Percona Inc.
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
# HTTPProtocolParser package $Revision$
# ###########################################################################
package HTTPProtocolParser;

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

   my ( $server_port )
      = $args{server} ? $args{server} =~ m/:(\w+)/ : ('80');
   $server_port ||= '80';  # In case $args{server} doesn't have a port.

   my $self = {
      server      => $args{server},
      server_port => $server_port,
      sessions    => {},
      o           => $args{o},
   };
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

   # Auto-detect the server by looking for port 80.
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
      warn 'Packet is not to or from web server: ', Dumper($packet);
      return;
   }
   MKDEBUG && _d('Client:', $client);

   # Get the client's session info or create a new session if the
   # client hasn't been seen before.
   if ( !exists $self->{sessions}->{$client} ) {
      MKDEBUG && _d('New session');
      $self->{sessions}->{$client} = {
         client      => $client,
         state       => undef,
         raw_packets => [],
         # ts -- wait for ts later.
      };
   };
   my $session = $self->{sessions}->{$client};

   # Return early if there's no TCP data.  These are usually ACK packets, but
   # they could also be FINs in which case, we should close and delete the
   # client's session.
   if ( $packet->{data_len} == 0 ) {
      MKDEBUG && _d('No TCP data');
      return;
   }

   # Save raw packets to dump later in case something fails.
   push @{$session->{raw_packets}}, $packet->{raw_packet};

   # Finally, parse the packet and maybe create an event.
   $packet->{data} = pack('H*', $packet->{data});
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

   MKDEBUG && _d('Done with packet; event:', Dumper($event));
   return $event;
}

# Handles a packet from the server given the state of the session.  Returns an
# event if one was ready to be created, otherwise returns nothing.
sub _packet_from_server {
   my ( $self, $packet, $session, $misc ) = @_;
   die "I need a packet"  unless $packet;
   die "I need a session" unless $session;

   MKDEBUG && _d('Packet is from server; client state:', $session->{state}); 

   my $data = $packet->{data};

   # If there's no session state, then we're catching a server response
   # mid-stream.
   if ( !$session->{state} ) {
      MKDEBUG && _d('Ignoring mid-stream server response');
      return;
   }

   # Assume that the server is returning only one value. 
   # TODO: make it handle multiple.
   if ( $session->{state} eq 'awaiting headers' ) {
      MKDEBUG && _d('State:', $session->{state});

      my ($line1, $header) = $packet->{data} =~ m/\A(.*?)\r\n(.+)?/s;
      # First header val should be: version  code phrase
      # E.g.:                       HTTP/1.1  200 OK
      my ($version, $code, $phrase) = $line1 =~ m/(\S+)/g;

      $session->{response} = $code;
      MKDEBUG && _d('Reponse code for last', 
         $session->{request}, $session->{page},
         'request:', $session->{response});

      MKDEBUG && _d('HTTP header:', $header);
      my @headers;
      foreach my $val ( split(/\r\n/, $header) ) {
         last unless $val;
         # Capture and save any useful header values.
         if ( $val =~ m/^Content-Length/i ) {
            ($session->{bytes}) = $val =~ /: (\d+)/;
         }
      }
   }
   else {
         return; # Prevent firing event.
   }

   MKDEBUG && _d('Creating event, deleting session');
   my $event = make_event($session, $packet);
   delete $self->{sessions}->{$session->{client}}; # http is stateless!
   $session->{raw_packets} = []; # Avoid keeping forever
   return $event;
}

# Handles a packet from the client given the state of the session.
sub _packet_from_client {
   my ( $self, $packet, $session, $misc ) = @_;
   die "I need a packet"  unless $packet;
   die "I need a session" unless $session;

   MKDEBUG && _d('Packet is from client; state:', $session->{state});

   my $event;
   if ( ($session->{state} || '') =~ m/awaiting / ) {
      # Whoa, we expected something from the server, not the client.  Fire an
      # INTERRUPTED with what we've got, and create a new session.
      MKDEBUG && _d("Expected data from the client, looks like interrupted");
      $session->{res} = 'INTERRUPTED';
      $event = make_event($session, $packet);
      my $client = $session->{client};
      delete @{$session}{keys %$session};
      $session->{client} = $client;
   }

   my ($line1, $val);
   my ($request, $page);
   if ( !$session->{state} ) {
      MKDEBUG && _d('Session state: ', $session->{state});
      $session->{state} = 'awaiting headers';

      # Split up the first line into its parts.
      ($line1, $val) = $packet->{data} =~ m/\A(.*?)\r\n(.+)?/s;
      my @vals = $line1 =~ m/(\S+)/g;
      $request = lc shift @vals;
      MKDEBUG && _d('Request:', $request);
      if ( $request eq 'get' ) {
         ($page) = shift @vals;
         MKDEBUG && _d('Page:', $page);
      }
      else {
         MKDEBUG && _d("Don't know how to handle", $request);
      }

      @{$session}{qw(request page)} = ($request, $page);
      $session->{host}       = $packet->{src_host};
      $session->{pos_in_log} = $packet->{pos_in_log};
      $session->{ts}         = $packet->{ts};
   }
   else {
      MKDEBUG && _d('Session state: ', $session->{state});
      $val = $packet->{data};
   }

   return $event;
}

# The event is not yet suitable for mk-query-digest.  It lacks, for example,
# an arg and fingerprint attribute.  The event should be passed to
# HTTPEvent::make_event() to transform it.
sub make_event {
   my ( $session, $packet ) = @_;
   my $event = {
      request      => $session->{request},
      page         => $session->{page},
      response     => $session->{response},
      ts           => $session->{ts},
      host         => $session->{host},
      bytes        => $session->{bytes} || 0,
      reponse_time => timestamp_diff($session->{ts}, $packet->{ts}),
      pos_in_log   => $session->{pos_in_log},
   };
   return $event;
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
# End HTTPProtocolParser package
# ###########################################################################
