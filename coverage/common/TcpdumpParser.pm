---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/TcpdumpParser.pm   96.9   65.0  100.0  100.0    n/a  100.0   90.6
Total                          96.9   65.0  100.0  100.0    n/a  100.0   90.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TcpdumpParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:04:28 2009
Finish:       Sat Aug 29 15:04:28 2009

/home/daniel/dev/maatkit/common/TcpdumpParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2009 Baron Schwartz.
2                                                     # Feedback and improvements are welcome.
3                                                     #
4                                                     # THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
5                                                     # WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
6                                                     # MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
7                                                     #
8                                                     # This program is free software; you can redistribute it and/or modify it under
9                                                     # the terms of the GNU General Public License as published by the Free Software
10                                                    # Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
11                                                    # systems, you can issue `man perlgpl' or `man perlartistic' to read these
12                                                    # licenses.
13                                                    #
14                                                    # You should have received a copy of the GNU General Public License along with
15                                                    # this program; if not, write to the Free Software Foundation, Inc., 59 Temple
16                                                    # Place, Suite 330, Boston, MA  02111-1307  USA.
17                                                    # ###########################################################################
18                                                    # TcpdumpParser package $Revision: 4502 $
19                                                    # ###########################################################################
20                                                    package TcpdumpParser;
21                                                    
22                                                    # This is a parser for tcpdump output.  It expects the output to be formatted a
23                                                    # certain way.  See the t/samples/tcpdumpxxx.txt files for examples.  Here's a
24                                                    # sample command on Ubuntu to produce the right formatted output:
25                                                    # tcpdump -i lo port 3306 -s 1500 -x -n -q -tttt
26                                                    
27             1                    1             9   use strict;
               1                                  2   
               1                                  6   
28             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
29             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
30             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  8   
31                                                    $Data::Dumper::Indent   = 1;
32                                                    $Data::Dumper::Sortkeys = 1;
33                                                    
34             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
35                                                    
36                                                    sub new {
37             1                    1            13      my ( $class, %args ) = @_;
38             1                                  4      my $self = {};
39             1                                 15      return bless $self, $class;
40                                                    }
41                                                    
42                                                    # This method accepts an open filehandle and callback functions.
43                                                    # It reads packets from the filehandle and calls the callbacks with each packet.
44                                                    # $misc is some placeholder for the future and for compatibility with other
45                                                    # query sources.
46                                                    #
47                                                    # Each packet is a hashref of attribute => value pairs like:
48                                                    #
49                                                    #  my $packet = {
50                                                    #     ts          => '2009-04-12 21:18:40.638244',
51                                                    #     src_host    => '192.168.1.5',
52                                                    #     src_port    => '54321',
53                                                    #     dst_host    => '192.168.1.1',
54                                                    #     dst_port    => '3306',
55                                                    #     complete    => 1|0,    # If this packet is a fragment or not
56                                                    #     ip_hlen     => 5,      # Number of 32-bit words in IP header
57                                                    #     tcp_hlen    => 8,      # Number of 32-bit words in TCP header
58                                                    #     dgram_len   => 140,    # Length of entire datagram, IP+TCP+data, in bytes
59                                                    #     data_len    => 30      # Length of data in bytes
60                                                    #     data        => '...',  # TCP data
61                                                    #     pos_in_log  => 10,     # Position of this packet in the log
62                                                    #  };
63                                                    #
64                                                    # Returns the number of packets parsed.  The sub is called parse_event
65                                                    # instead of parse_packet because mk-query-digest expects this for its
66                                                    # modular parser objects.
67                                                    sub parse_event {
68             5                    5            24      my ( $self, $fh, $misc, @callbacks ) = @_;
69             5                                 17      my $oktorun_here = 1;
70             5    100                          25      my $oktorun      = $misc->{oktorun} ? $misc->{oktorun} : \$oktorun_here;
71             5                                 13      my $num_packets = 0;
72                                                    
73                                                       # In case we get a closed fh, trying tell() on it will cause an error.
74    ***      5     50                          25      if ( !$fh ) {
75    ***      0                                  0         MKDEBUG && _d('No filehandle');
76    ***      0                                  0         return 0;
77                                                       }
78                                                    
79                                                       # We read a packet at a time.  Assuming that all packets begin with a
80                                                       # timestamp "20.....", we just use that as the separator, and restore it.
81                                                       # This will be good until the year 2100.
82             5                                 29      local $INPUT_RECORD_SEPARATOR = "\n20";
83                                                    
84             5                                 24      my $pos_in_log = tell($fh);
85             5           100                  124      while ( $$oktorun && defined(my $raw_packet = <$fh>) ) {
86             6    100                          39         next if $raw_packet =~ m/^$/;  # issue 564
87                                                    
88                                                          # Remove the separator from the packet, and restore it to the front if
89                                                          # necessary.
90             5                                 19         $raw_packet =~ s/\n20\Z//;
91             5    100                          26         $raw_packet = "20$raw_packet" unless $raw_packet =~ m/\A20/;
92                                                    
93             5                                 13         MKDEBUG && _d('packet:', ++$num_packets, 'pos:', $pos_in_log);
94             5                                 21         my $packet = $self->_parse_packet($raw_packet);
95             5                                 16         $packet->{pos_in_log} = $pos_in_log;
96             5                                 19         $packet->{raw_packet} = $raw_packet;
97                                                    
98             5                                 16         foreach my $callback ( @callbacks ) {
99    ***      5     50                          19            last unless $packet = $callback->($packet);
100                                                         }
101                                                   
102            5                                122         $pos_in_log = tell($fh) - 1;
103                                                      }
104                                                   
105            5                                 12      MKDEBUG && _d('Done parsing packets;', $num_packets, 'parsed');
106            5                                 25      return $num_packets;
107                                                   }
108                                                   
109                                                   # Takes a hex description of a TCP/IP packet and returns the interesting bits.
110                                                   sub _parse_packet {
111            6                    6            35      my ( $self, $packet ) = @_;
112   ***      6     50                          23      die "I need a packet" unless $packet;
113                                                   
114            6                                 78      my ( $ts, $source, $dest )  = $packet =~ m/\A(\S+ \S+) IP .*?(\S+) > (\S+):/;
115            6                                 50      my ( $src_host, $src_port ) = $source =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
116            6                                 36      my ( $dst_host, $dst_port ) = $dest   =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
117                                                   
118            6                                 36      my $hex = qr/[0-9a-f]/;
119            6                                295      (my $data = join('', $packet =~ m/\s+0x$hex+:\s((?:\s$hex{2,4})+)/go)) =~ s/\s+//g; 
120                                                   
121                                                      # Find length information in the IPv4 header.  Typically 5 32-bit
122                                                      # words.  See http://en.wikipedia.org/wiki/IPv4#Header
123            6                                 32      my $ip_hlen = hex(substr($data, 1, 1)); # Num of 32-bit words in header.
124                                                      # The total length of the entire datagram, including header.  This is
125                                                      # useful because it lets us see whether we got the whole thing.
126            6                                 18      my $ip_plen = hex(substr($data, 4, 4)); # Num of BYTES in IPv4 datagram.
127   ***      6     50                          32      my $complete = length($data) == 2 * $ip_plen ? 1 : 0;
128                                                   
129                                                      # Same thing in a different position, with the TCP header.  See
130                                                      # http://en.wikipedia.org/wiki/Transmission_Control_Protocol.
131            6                                 25      my $tcp_hlen = hex(substr($data, ($ip_hlen + 3) * 8, 1));
132                                                   
133                                                      # Get sequence and ack numbers.
134            6                                 23      my $seq = hex(substr($data, ($ip_hlen + 1) * 8, 8));
135            6                                 24      my $ack = hex(substr($data, ($ip_hlen + 2) * 8, 8));
136                                                   
137                                                      # Throw away the IP and TCP headers.
138            6                                 22      $data = substr($data, ($ip_hlen + $tcp_hlen) * 8);
139                                                   
140   ***      6     50                          95      my $pkt = {
      ***            50                               
141                                                         ts        => $ts,
142                                                         seq       => $seq,
143                                                         ack       => $ack,
144                                                         src_host  => $src_host,
145                                                         src_port  => $src_port,
146                                                         dst_host  => $dst_host,
147                                                         dst_port  => $dst_port,
148                                                         complete  => $complete,
149                                                         ip_hlen   => $ip_hlen,
150                                                         tcp_hlen  => $tcp_hlen,
151                                                         dgram_len => $ip_plen,
152                                                         data_len  => $ip_plen - (($ip_hlen + $tcp_hlen) * 4),
153                                                         data      => $data ? substr($data, 0, 8).(length $data > 8 ? '...' : '')
154                                                                            : '',
155                                                      };
156            6                                 13      MKDEBUG && _d('packet:', Dumper($pkt));
157            6                                 24      $pkt->{data} = $data;
158            6                                 79      return $pkt;
159                                                   }
160                                                   
161                                                   sub _d {
162            1                    1            27      my ($package, undef, $line) = caller 0;
163   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 12   
164            1                                  5           map { defined $_ ? $_ : 'undef' }
165                                                           @_;
166            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
167                                                   }
168                                                   
169                                                   1;
170                                                   
171                                                   # ###########################################################################
172                                                   # End TcpdumpParser package
173                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
70           100      4      1   $$misc{'oktorun'} ? :
74    ***     50      0      5   if (not $fh)
86           100      1      5   if $raw_packet =~ /^$/
91           100      2      3   unless $raw_packet =~ /\A20/
99    ***     50      5      0   unless $packet = &$callback($packet)
112   ***     50      0      6   unless $packet
127   ***     50      6      0   length $data == 2 * $ip_plen ? :
140   ***     50      6      0   length $data > 8 ? :
      ***     50      6      0   $data ? :
163   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
85           100      1      4      6   $$oktorun and defined(my $raw_packet = <$fh>)


Covered Subroutines
-------------------

Subroutine    Count Location                                            
------------- ----- ----------------------------------------------------
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:27 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:28 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:29 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:30 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:34 
_d                1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:162
_parse_packet     6 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:111
new               1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:37 
parse_event       5 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:68 


