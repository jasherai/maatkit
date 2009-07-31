---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/TcpdumpParser.pm   96.8   61.1  100.0  100.0    n/a  100.0   90.2
Total                          96.8   61.1  100.0  100.0    n/a  100.0   90.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TcpdumpParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:54:06 2009
Finish:       Fri Jul 31 18:54:06 2009

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
18                                                    # TcpdumpParser package $Revision: 4195 $
19                                                    # ###########################################################################
20                                                    package TcpdumpParser;
21                                                    
22                                                    # This is a parser for tcpdump output.  It expects the output to be formatted a
23                                                    # certain way.  See the t/samples/tcpdumpxxx.txt files for examples.  Here's a
24                                                    # sample command on Ubuntu to produce the right formatted output:
25                                                    # tcpdump -i lo port 3306 -s 1500 -x -n -q -tttt
26                                                    
27             1                    1             8   use strict;
               1                                  3   
               1                                  6   
28             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
29             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
30             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  8   
31                                                    $Data::Dumper::Indent   = 1;
32                                                    $Data::Dumper::Sortkeys = 1;
33                                                    
34             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 11   
35                                                    
36                                                    sub new {
37             1                    1            12      my ( $class, %args ) = @_;
38             1                                  3      my $self = {};
39             1                                 13      return bless $self, $class;
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
68             3                    3            14      my ( $self, $fh, $misc, @callbacks ) = @_;
69             3                                  8      my $oktorun_here = 1;
70             3    100                          15      my $oktorun      = $misc->{oktorun} ? $misc->{oktorun} : \$oktorun_here;
71             3                                  6      my $num_packets = 0;
72                                                    
73                                                       # In case we get a closed fh, trying tell() on it will cause an error.
74    ***      3     50                          12      if ( !$fh ) {
75    ***      0                                  0         MKDEBUG && _d('No filehandle');
76    ***      0                                  0         return 0;
77                                                       }
78                                                    
79                                                       # We read a packet at a time.  Assuming that all packets begin with a
80                                                       # timestamp "20.....", we just use that as the separator, and restore it.
81                                                       # This will be good until the year 2100.
82             3                                 17      local $INPUT_RECORD_SEPARATOR = "\n20";
83                                                    
84             3                                 16      my $pos_in_log = tell($fh);
85             3           100                   59      while ( $$oktorun && defined(my $raw_packet = <$fh>) ) {
86                                                          # Remove the separator from the packet, and restore it to the front if
87                                                          # necessary.
88             4                                 15         $raw_packet =~ s/\n20\Z//;
89             4    100                          19         $raw_packet = "20$raw_packet" unless $raw_packet =~ m/\A20/;
90                                                    
91             4                                  9         MKDEBUG && _d('packet:', ++$num_packets, 'pos:', $pos_in_log);
92             4                                 17         my $packet = $self->_parse_packet($raw_packet);
93             4                                 14         $packet->{pos_in_log} = $pos_in_log;
94             4                                 36         $packet->{raw_packet} = $raw_packet;
95                                                    
96             4                                 15         foreach my $callback ( @callbacks ) {
97    ***      4     50                          15            last unless $packet = $callback->($packet);
98                                                          }
99                                                    
100            4                                 98         $pos_in_log = tell($fh) - 1;
101                                                      }
102                                                   
103            3                                  7      MKDEBUG && _d('Done parsing packets;', $num_packets, 'parsed');
104            3                                 14      return $num_packets;
105                                                   }
106                                                   
107                                                   # Takes a hex description of a TCP/IP packet and returns the interesting bits.
108                                                   sub _parse_packet {
109            5                    5            29      my ( $self, $packet ) = @_;
110   ***      5     50                          19      die "I need a packet" unless $packet;
111                                                   
112            5                                 46      my ( $ts, $source, $dest )  = $packet =~ m/\A(\S+ \S+) IP (\S+) > (\S+):/;
113            5                                 34      my ( $src_host, $src_port ) = $source =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
114            5                                 29      my ( $dst_host, $dst_port ) = $dest   =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
115                                                   
116            5                                169      (my $data = join('', $packet =~ m/\s+0x[0-9a-f]+:\s+(.*)/g)) =~ s/\s+//g; 
117                                                   
118                                                      # Find length information in the IPv4 header.  Typically 5 32-bit
119                                                      # words.  See http://en.wikipedia.org/wiki/IPv4#Header
120            5                                 23      my $ip_hlen = hex(substr($data, 1, 1)); # Num of 32-bit words in header.
121                                                      # The total length of the entire datagram, including header.  This is
122                                                      # useful because it lets us see whether we got the whole thing.
123            5                                 17      my $ip_plen = hex(substr($data, 4, 4)); # Num of BYTES in IPv4 datagram.
124   ***      5     50                          23      my $complete = length($data) == 2 * $ip_plen ? 1 : 0;
125                                                   
126                                                      # Same thing in a different position, with the TCP header.  See
127                                                      # http://en.wikipedia.org/wiki/Transmission_Control_Protocol.
128            5                                 19      my $tcp_hlen = hex(substr($data, ($ip_hlen + 3) * 8, 1));
129                                                   
130                                                      # Get sequence and ack numbers.
131            5                                 18      my $seq = hex(substr($data, ($ip_hlen + 1) * 8, 8));
132            5                                 19      my $ack = hex(substr($data, ($ip_hlen + 2) * 8, 8));
133                                                   
134                                                      # Throw away the IP and TCP headers.
135            5                                 18      $data = substr($data, ($ip_hlen + $tcp_hlen) * 8);
136                                                   
137   ***      5     50                          74      my $pkt = {
      ***            50                               
138                                                         ts        => $ts,
139                                                         seq       => $seq,
140                                                         ack       => $ack,
141                                                         src_host  => $src_host,
142                                                         src_port  => $src_port,
143                                                         dst_host  => $dst_host,
144                                                         dst_port  => $dst_port,
145                                                         complete  => $complete,
146                                                         ip_hlen   => $ip_hlen,
147                                                         tcp_hlen  => $tcp_hlen,
148                                                         dgram_len => $ip_plen,
149                                                         data_len  => $ip_plen - (($ip_hlen + $tcp_hlen) * 4),
150                                                         data      => $data ? substr($data, 0, 8).(length $data > 8 ? '...' : '')
151                                                                            : '',
152                                                      };
153            5                                 11      MKDEBUG && _d('packet:', Dumper($pkt));
154            5                                 18      $pkt->{data} = $data;
155            5                                 51      return $pkt;
156                                                   }
157                                                   
158                                                   sub _d {
159            1                    1            20      my ($package, undef, $line) = caller 0;
160   ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                  9   
161            1                                  5           map { defined $_ ? $_ : 'undef' }
162                                                           @_;
163            1                                  2      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
164                                                   }
165                                                   
166                                                   1;
167                                                   
168                                                   # ###########################################################################
169                                                   # End TcpdumpParser package
170                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
70           100      2      1   $$misc{'oktorun'} ? :
74    ***     50      0      3   if (not $fh)
89           100      2      2   unless $raw_packet =~ /\A20/
97    ***     50      4      0   unless $packet = &$callback($packet)
110   ***     50      0      5   unless $packet
124   ***     50      5      0   length $data == 2 * $ip_plen ? :
137   ***     50      5      0   length $data > 8 ? :
      ***     50      5      0   $data ? :
160   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
85           100      1      2      4   $$oktorun and defined(my $raw_packet = <$fh>)


Covered Subroutines
-------------------

Subroutine    Count Location                                            
------------- ----- ----------------------------------------------------
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:27 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:28 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:29 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:30 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:34 
_d                1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:159
_parse_packet     5 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:109
new               1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:37 
parse_event       3 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:68 


