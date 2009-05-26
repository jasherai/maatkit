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

sub new {
   my ( $class, %args ) = @_;
   my $self = {};
   return bless $self, $class;
}

# This method accepts an open filehandle and callback functions.
# It reads events from the filehandle and calls the callbacks with each packet.
# $misc is some placeholder for the future and for compatibility with other
# query sources.
#
# Each packet is a hashref of attribute => value pairs like:
#  my $packet = {
#     ts          => '2009-04-12 21:18:40.638244',
#     src_host    => '192.168.1.5',
#     src_port    => '54321',
#     dst_host    => '192.168.1.1',
#     dst_port    => '3306',
#     complete    => 1|0,    # If this packet is a fragment or not
#     ip_hlen     => 5,      # Length of IP header in bytes (so * 8 for size)
#     tcp_hlen    => 8,      # Length of TCP header in bytes
#     data        => '...',  # TCP data
#     pos_in_log  => 10,     # Position of this packet in the log
#  };
#
# Returns the number of packets parsed.
sub parse_packet {
   my ( $self, $fh, $misc, @callbacks ) = @_;

   my $num_packets = 0;

   # We read a packet at a time.  Assuming that all packets begin with a
   # timestamp "20.....", we just use that as the separator, and restore it.
   # This will be good until the year 2100.
   local $INPUT_RECORD_SEPARATOR = "\n20";

   my $pos_in_log = tell($fh);
   while ( defined(my $raw_packet = <$fh>) ) {
      # Remove the separator from the packet, and restore it to the front if
      # necessary.
      $raw_packet =~ s/\n20\Z//;
      $raw_packet = "20$raw_packet" unless $raw_packet =~ m/\A20/;

      MKDEBUG && _d('packet:', ++$num_packets, 'pos:', $pos_in_log);
      my $packet = $self->_parse_packet($raw_packet);
      $packet->{pos_in_log} = $pos_in_log;

      foreach my $callback ( @callbacks ) {
         last unless $packet = $callback->($packet);
      }

      $pos_in_log = tell($fh) - 1;
   }

   MKDEBUG && _d('Done parsing packets;', $num_packets, 'parsed');
   return $num_packets;
}

# Takes a hex description of a TCP/IP packet and returns the interesting bits.
sub _parse_packet {
   my ( $self, $packet ) = @_;
   die "I need a packet" unless $packet;

   my ( $ts, $source, $dest )  = $packet =~ m/\A(\S+ \S+) IP (\S+) > (\S+):/;
   my ( $src_host, $src_port ) = $source =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
   my ( $dst_host, $dst_port ) = $dest   =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
   MKDEBUG && _d($src_host, ':', $src_port, '>', $dst_host, ':', $dst_port);

   (my $data = join('', $packet =~ m/\t0x[0-9a-f]+:  (.*)/g)) =~ s/\s+//g; 

   # Find length information in the IPv4 header.  Typically 5 32-bit
   # words.  See http://en.wikipedia.org/wiki/IPv4#Header
   my $ip_hlen = hex(substr($data, 1, 1)); # Num of 32-bit words in header.
   # The total length of the entire datagram, including header.  This is
   # useful because it lets us see whether we got the whole thing.
   my $ip_plen = hex(substr($data, 4, 4)); # Num of BYTES in IPv4 datagram.
   my $complete = length($data) == 2 * $ip_plen ? 1 : 0;

   # Same thing in a different position, with the TCP header.  See
   # http://en.wikipedia.org/wiki/Transmission_Control_Protocol.
   my $tcp_hlen = hex(substr($data, ($ip_hlen + 3) * 8, 1));
   # Throw away the IP and TCP headers.
   MKDEBUG && _d('Header len: IP', $ip_hlen, 'TCP', $tcp_hlen,
      'complete:', $complete);
   $data = substr($data, ($ip_hlen + $tcp_hlen) * 8);

   return {
      ts       => $ts,
      src_host => $src_host,
      src_port => $src_port,
      dst_host => $dst_host,
      dst_port => $dst_port,
      complete => $complete,
      ip_hlen  => $ip_hlen,
      tcp_hlen => $tcp_hlen,
      data     => $data,
   };
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
