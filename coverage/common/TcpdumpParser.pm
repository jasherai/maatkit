---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/TcpdumpParser.pm  100.0   57.1   80.0  100.0    n/a  100.0   91.7
Total                         100.0   57.1   80.0  100.0    n/a  100.0   91.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TcpdumpParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jun 12 20:44:17 2009
Finish:       Fri Jun 12 20:44:17 2009

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
18                                                    # TcpdumpParser package $Revision: 3910 $
19                                                    # ###########################################################################
20                                                    package TcpdumpParser;
21                                                    
22                                                    # This is a parser for tcpdump output.  It expects the output to be formatted a
23                                                    # certain way.  See the t/samples/tcpdumpxxx.txt files for examples.  Here's a
24                                                    # sample command on Ubuntu to produce the right formatted output:
25                                                    # tcpdump -i lo port 3306 -s 1500 -x -n -q -tttt
26                                                    
27             1                    1             8   use strict;
               1                                  2   
               1                                  7   
28             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
29             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
30             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
31                                                    $Data::Dumper::Indent   = 1;
32                                                    $Data::Dumper::Sortkeys = 1;
33                                                    
34             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
35                                                    
36                                                    sub new {
37             1                    1            11      my ( $class, %args ) = @_;
38             1                                  4      my $self = {};
39             1                                 12      return bless $self, $class;
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
68             2                    2             9      my ( $self, $fh, $misc, @callbacks ) = @_;
69    ***      2            50                   10      my $oktorun = $misc->{oktorun} || 1;
70             2                                  5      my $num_packets = 0;
71                                                    
72                                                       # We read a packet at a time.  Assuming that all packets begin with a
73                                                       # timestamp "20.....", we just use that as the separator, and restore it.
74                                                       # This will be good until the year 2100.
75             2                                 10      local $INPUT_RECORD_SEPARATOR = "\n20";
76                                                    
77             2                                 13      my $pos_in_log = tell($fh);
78             2           100                   37      while ( $$oktorun && defined(my $raw_packet = <$fh>) ) {
79                                                          # Remove the separator from the packet, and restore it to the front if
80                                                          # necessary.
81             2                                  8         $raw_packet =~ s/\n20\Z//;
82             2    100                          14         $raw_packet = "20$raw_packet" unless $raw_packet =~ m/\A20/;
83                                                    
84             2                                  4         MKDEBUG && _d('packet:', ++$num_packets, 'pos:', $pos_in_log);
85             2                                  7         my $packet = $self->_parse_packet($raw_packet);
86             2                                  7         $packet->{pos_in_log} = $pos_in_log;
87             2                                  6         $packet->{raw_packet} = $raw_packet;
88                                                    
89             2                                  7         foreach my $callback ( @callbacks ) {
90    ***      2     50                           8            last unless $packet = $callback->($packet);
91                                                          }
92                                                    
93             2                                 50         $pos_in_log = tell($fh) - 1;
94                                                       }
95                                                    
96             2                                  4      MKDEBUG && _d('Done parsing packets;', $num_packets, 'parsed');
97             2                                 14      return $num_packets;
98                                                    }
99                                                    
100                                                   # Takes a hex description of a TCP/IP packet and returns the interesting bits.
101                                                   sub _parse_packet {
102            3                    3            21      my ( $self, $packet ) = @_;
103   ***      3     50                          13      die "I need a packet" unless $packet;
104                                                   
105            3                                 27      my ( $ts, $source, $dest )  = $packet =~ m/\A(\S+ \S+) IP (\S+) > (\S+):/;
106            3                                 22      my ( $src_host, $src_port ) = $source =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
107            3                                 18      my ( $dst_host, $dst_port ) = $dest   =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
108                                                   
109            3                                114      (my $data = join('', $packet =~ m/\t0x[0-9a-f]+:  (.*)/g)) =~ s/\s+//g; 
110                                                   
111                                                      # Find length information in the IPv4 header.  Typically 5 32-bit
112                                                      # words.  See http://en.wikipedia.org/wiki/IPv4#Header
113            3                                 15      my $ip_hlen = hex(substr($data, 1, 1)); # Num of 32-bit words in header.
114                                                      # The total length of the entire datagram, including header.  This is
115                                                      # useful because it lets us see whether we got the whole thing.
116            3                                 10      my $ip_plen = hex(substr($data, 4, 4)); # Num of BYTES in IPv4 datagram.
117   ***      3     50                          14      my $complete = length($data) == 2 * $ip_plen ? 1 : 0;
118                                                   
119                                                      # Same thing in a different position, with the TCP header.  See
120                                                      # http://en.wikipedia.org/wiki/Transmission_Control_Protocol.
121            3                                 12      my $tcp_hlen = hex(substr($data, ($ip_hlen + 3) * 8, 1));
122                                                      # Throw away the IP and TCP headers.
123            3                                 11      $data = substr($data, ($ip_hlen + $tcp_hlen) * 8);
124                                                   
125   ***      3     50                          41      my $pkt = {
      ***            50                               
126                                                         ts        => $ts,
127                                                         src_host  => $src_host,
128                                                         src_port  => $src_port,
129                                                         dst_host  => $dst_host,
130                                                         dst_port  => $dst_port,
131                                                         complete  => $complete,
132                                                         ip_hlen   => $ip_hlen,
133                                                         tcp_hlen  => $tcp_hlen,
134                                                         dgram_len => $ip_plen,
135                                                         data_len  => $ip_plen - (($ip_hlen + $tcp_hlen) * 4),
136                                                         data      => $data ? substr($data, 0, 8).(length $data > 8 ? '...' : '')
137                                                                            : '',
138                                                      };
139            3                                  8      MKDEBUG && _d('packet:', Dumper($pkt));
140            3                                 10      $pkt->{data} = $data;
141            3                                 45      return $pkt;
142                                                   }
143                                                   
144                                                   sub _d {
145            1                    1            36      my ($package, undef, $line) = caller 0;
146   ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 11   
               2                                 10   
147            1                                  5           map { defined $_ ? $_ : 'undef' }
148                                                           @_;
149            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
150                                                   }
151                                                   
152                                                   1;
153                                                   
154                                                   # ###########################################################################
155                                                   # End TcpdumpParser package
156                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
82           100      1      1   unless $raw_packet =~ /\A20/
90    ***     50      2      0   unless $packet = &$callback($packet)
103   ***     50      0      3   unless $packet
117   ***     50      3      0   length $data == 2 * $ip_plen ? :
125   ***     50      3      0   length $data > 8 ? :
      ***     50      3      0   $data ? :
146   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
78           100      1      1      2   $$oktorun and defined(my $raw_packet = <$fh>)

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
69    ***     50      2      0   $$misc{'oktorun'} || 1


Covered Subroutines
-------------------

Subroutine    Count Location                                            
------------- ----- ----------------------------------------------------
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:27 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:28 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:29 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:30 
BEGIN             1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:34 
_d                1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:145
_parse_packet     3 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:102
new               1 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:37 
parse_event       2 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:68 


