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
use base 'ProtocolParser';

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
   my $self = $class->SUPER::new(
      %args,
      server_port => 80,
   );
   return $self;
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

      $session->{attribs}->{response} = $code;
      MKDEBUG && _d('Reponse code for last', 
         $session->{request}, $session->{page},
         'request:', $session->{response});

      MKDEBUG && _d('HTTP header:', $header);
      my @headers;
      foreach my $val ( split(/\r\n/, $header) ) {
         last unless $val;
         # Capture and save any useful header values.
         if ( $val =~ m/^Content-Length/i ) {
            ($session->{attribs}->{bytes}) = $val =~ /: (\d+)/;
         }
      }
   }
   else {
         return; # Prevent firing event.
   }

   MKDEBUG && _d('Creating event, deleting session');
   my $event = $self->make_event($session, $packet);
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
      $event = $self->make_event($session, $packet);
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

      @{$session->{attribs}}{qw(request page)} = ($request, $page);
      $session->{attribs}->{host}       = $packet->{src_host};
      $session->{attribs}->{pos_in_log} = $packet->{pos_in_log};
      $session->{attribs}->{ts}         = $packet->{ts};
   }
   else {
      MKDEBUG && _d('Session state: ', $session->{state});
      $val = $packet->{data};
   }

   return $event;
}

1;

# ###########################################################################
# End HTTPProtocolParser package
# ###########################################################################
