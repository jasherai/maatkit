---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/TcpdumpParser.pm   88.9   50.0    n/a   88.9    n/a  100.0   81.8
Total                          88.9   50.0    n/a   88.9    n/a  100.0   81.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TcpdumpParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:41 2009
Finish:       Wed Jun 10 17:21:41 2009

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
18                                                    # TcpdumpParser package $Revision: 3744 $
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
               1                                  3   
               1                                  8   
29             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
30             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  7   
31                                                    $Data::Dumper::Indent   = 1;
32                                                    $Data::Dumper::Sortkeys = 1;
33                                                    
34             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
35                                                    
36                                                    sub new {
37             1                    1            11      my ( $class, %args ) = @_;
38             1                                  4      my $self = {};
39             1                                 13      return bless $self, $class;
40                                                    }
41                                                    
42                                                    # This method accepts an open filehandle and callback functions.
43                                                    # It reads packets from the filehandle and calls the callbacks with each packet.
44                                                    # $misc is some placeholder for the future and for compatibility with other
45                                                    # query sources.
46                                                    #
47                                                    # Each packet is a hashref of attribute => value pairs like:
48                                                    #  my $packet = {
49                                                    #     ts          => '2009-04-12 21:18:40.638244',
50                                                    #     src_host    => '192.168.1.5',
51                                                    #     src_port    => '54321',
52                                                    #     dst_host    => '192.168.1.1',
53                                                    #     dst_port    => '3306',
54                                                    #     complete    => 1|0,    # If this packet is a fragment or not
55                                                    #     ip_hlen     => 5,      # Length of IP header in bytes (so * 8 for size)
56                                                    #     tcp_hlen    => 8,      # Length of TCP header in bytes
57                                                    #     data        => '...',  # TCP data
58                                                    #     pos_in_log  => 10,     # Position of this packet in the log
59                                                    #  };
60                                                    # Returns the number of packets parsed.  The sub is called parse_event
61                                                    # instead of parse_packet because mk-query-digest expects this for its
62                                                    # modular parser objects.
63                                                    sub parse_event {
64             1                    1             4      my ( $self, $fh, $misc, @callbacks ) = @_;
65                                                    
66             1                                  3      my $num_packets = 0;
67                                                    
68                                                       # We read a packet at a time.  Assuming that all packets begin with a
69                                                       # timestamp "20.....", we just use that as the separator, and restore it.
70                                                       # This will be good until the year 2100.
71             1                                  5      local $INPUT_RECORD_SEPARATOR = "\n20";
72                                                    
73             1                                 10      my $pos_in_log = tell($fh);
74             1                                 24      while ( defined(my $raw_packet = <$fh>) ) {
75                                                          # Remove the separator from the packet, and restore it to the front if
76                                                          # necessary.
77             2                                  8         $raw_packet =~ s/\n20\Z//;
78             2    100                          10         $raw_packet = "20$raw_packet" unless $raw_packet =~ m/\A20/;
79                                                    
80             2                                  5         MKDEBUG && _d('packet:', ++$num_packets, 'pos:', $pos_in_log);
81             2                                  7         my $packet = $self->_parse_packet($raw_packet);
82             2                                  6         $packet->{pos_in_log} = $pos_in_log;
83                                                    
84             2                                  7         foreach my $callback ( @callbacks ) {
85    ***      2     50                           8            last unless $packet = $callback->($packet);
86                                                          }
87                                                    
88             2                                 42         $pos_in_log = tell($fh) - 1;
89                                                       }
90                                                    
91             1                                  4      MKDEBUG && _d('Done parsing packets;', $num_packets, 'parsed');
92             1                                  6      return $num_packets;
93                                                    }
94                                                    
95                                                    # Takes a hex description of a TCP/IP packet and returns the interesting bits.
96                                                    sub _parse_packet {
97             3                    3            20      my ( $self, $packet ) = @_;
98    ***      3     50                          13      die "I need a packet" unless $packet;
99                                                    
100            3                                 27      my ( $ts, $source, $dest )  = $packet =~ m/\A(\S+ \S+) IP (\S+) > (\S+):/;
101            3                                 23      my ( $src_host, $src_port ) = $source =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
102            3                                 18      my ( $dst_host, $dst_port ) = $dest   =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
103                                                   
104            3                                114      (my $data = join('', $packet =~ m/\t0x[0-9a-f]+:  (.*)/g)) =~ s/\s+//g; 
105                                                   
106                                                      # Find length information in the IPv4 header.  Typically 5 32-bit
107                                                      # words.  See http://en.wikipedia.org/wiki/IPv4#Header
108            3                                 15      my $ip_hlen = hex(substr($data, 1, 1)); # Num of 32-bit words in header.
109                                                      # The total length of the entire datagram, including header.  This is
110                                                      # useful because it lets us see whether we got the whole thing.
111            3                                  9      my $ip_plen = hex(substr($data, 4, 4)); # Num of BYTES in IPv4 datagram.
112   ***      3     50                          15      my $complete = length($data) == 2 * $ip_plen ? 1 : 0;
113                                                   
114                                                      # Same thing in a different position, with the TCP header.  See
115                                                      # http://en.wikipedia.org/wiki/Transmission_Control_Protocol.
116            3                                 12      my $tcp_hlen = hex(substr($data, ($ip_hlen + 3) * 8, 1));
117                                                      # Throw away the IP and TCP headers.
118            3                                 11      $data = substr($data, ($ip_hlen + $tcp_hlen) * 8);
119                                                   
120   ***      3     50                          52      my $pkt = {
      ***            50                               
121                                                         ts        => $ts,
122                                                         src_host  => $src_host,
123                                                         src_port  => $src_port,
124                                                         dst_host  => $dst_host,
125                                                         dst_port  => $dst_port,
126                                                         complete  => $complete,
127                                                         ip_hlen   => $ip_hlen,
128                                                         tcp_hlen  => $tcp_hlen,
129                                                         dgram_len => $ip_plen,
130                                                         data_len  => $ip_plen - (($ip_hlen + $tcp_hlen) * 4),
131                                                         data      => $data ? substr($data, 0, 8).(length $data > 8 ? '...' : '')
132                                                                            : '',
133                                                      };
134            3                                  7      MKDEBUG && _d('packet:', Dumper($pkt));
135            3                                 12      $pkt->{data} = $data;
136            3                                 44      return $pkt;
137                                                   }
138                                                   
139                                                   sub _d {
140   ***      0                    0                    my ($package, undef, $line) = caller 0;
141   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
142   ***      0                                              map { defined $_ ? $_ : 'undef' }
143                                                           @_;
144   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
145                                                   }
146                                                   
147                                                   1;
148                                                   
149                                                   # ###########################################################################
150                                                   # End TcpdumpParser package
151                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
78           100      1      1   unless $raw_packet =~ /\A20/
85    ***     50      2      0   unless $packet = &$callback($packet)
98    ***     50      0      3   unless $packet
112   ***     50      3      0   length $data == 2 * $ip_plen ? :
120   ***     50      3      0   length $data > 8 ? :
      ***     50      3      0   $data ? :
141   ***      0      0      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine    Count Location                                            
------------- ----- ----------------------------------------------------
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:27 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:28 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:29 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:30 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:34 
_parse_packet     3 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:97 
new               1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:37 
parse_event       1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:64 

Uncovered Subroutines
---------------------

Subroutine    Count Location                                            
------------- ----- ----------------------------------------------------
_d                0 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:140


