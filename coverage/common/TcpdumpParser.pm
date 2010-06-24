---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/TcpdumpParser.pm  100.0   67.9   50.0  100.0    0.0   99.0   88.2
TcpdumpParser.t               100.0   50.0   33.3  100.0    n/a    1.0   94.4
Total                         100.0   66.7   40.0  100.0    0.0  100.0   90.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:32 2010
Finish:       Thu Jun 24 19:38:32 2010

Run:          TcpdumpParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:34 2010
Finish:       Thu Jun 24 19:38:34 2010

/home/daniel/dev/maatkit/common/TcpdumpParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2010 Baron Schwartz.
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
18                                                    # TcpdumpParser package $Revision: 5818 $
19                                                    # ###########################################################################
20                                                    package TcpdumpParser;
21                                                    
22                                                    # This is a parser for tcpdump output.  It expects the output to be formatted a
23                                                    # certain way.  See the t/samples/tcpdumpxxx.txt files for examples.  Here's a
24                                                    # sample command on Ubuntu to produce the right formatted output:
25                                                    # tcpdump -i lo port 3306 -s 1500 -x -n -q -tttt
26                                                    
27             1                    1             5   use strict;
               1                                  2   
               1                                 15   
28             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
29             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  6   
30             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
31                                                    $Data::Dumper::Indent   = 1;
32                                                    $Data::Dumper::Sortkeys = 1;
33                                                    
34    ***      1            50      1             5   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 18   
35                                                    
36                                                    sub new {
37    ***      1                    1      0      5      my ( $class, %args ) = @_;
38             1                                  4      my $self = {};
39             1                                 11      return bless $self, $class;
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
68    ***      8                    8      0    606      my ( $self, %args ) = @_;
69             8                                 41      my @required_args = qw(next_event tell);
70             8                                 32      foreach my $arg ( @required_args ) {
71    ***     16     50                          85         die "I need a $arg argument" unless $args{$arg};
72                                                       }
73             8                                 38      my ($next_event, $tell) = @args{@required_args};
74                                                    
75                                                       # We read a packet at a time.  Assuming that all packets begin with a
76                                                       # timestamp "20.....", we just use that as the separator, and restore it.
77                                                       # This will be good until the year 2100.
78             8                                 44      local $INPUT_RECORD_SEPARATOR = "\n20";
79                                                    
80             8                                 35      my $pos_in_log = $tell->();
81             8                                 87      while ( defined(my $raw_packet = $next_event->()) ) {
82             5    100                      103370         next if $raw_packet =~ m/^$/;  # issue 564
83             4    100                          22         $pos_in_log -= 1 if $pos_in_log;
84                                                    
85                                                          # Remove the separator from the packet, and restore it to the front if
86                                                          # necessary.
87             4                                 24         $raw_packet =~ s/\n20\Z//;
88             4    100                          29         $raw_packet = "20$raw_packet" unless $raw_packet =~ m/\A20/;
89                                                    
90                                                          # Remove special headers (e.g. vlan) before the IPv4 header.
91                                                          # The vast majority of IPv4 headers begin with 4508 (or 4500).  
92                                                          # http://code.google.com/p/maatkit/issues/detail?id=906
93             4                                137         $raw_packet =~ s/0x0000:.+?(450.) /0x0000:  $1 /;
94                                                    
95             4                                 34         my $packet = $self->_parse_packet($raw_packet);
96             4                                 19         $packet->{pos_in_log} = $pos_in_log;
97             4                                 24         $packet->{raw_packet} = $raw_packet;
98                                                    
99             4                                 57         return $packet;
100                                                      }
101                                                   
102            4    100                         135      $args{oktorun}->(0) if $args{oktorun};
103            4                                 47      return;
104                                                   }
105                                                   
106                                                   # Takes a hex description of a TCP/IP packet and returns the interesting bits.
107                                                   sub _parse_packet {
108            5                    5            43      my ( $self, $packet ) = @_;
109   ***      5     50                          31      die "I need a packet" unless $packet;
110                                                   
111            5                                106      my ( $ts, $source, $dest )  = $packet =~ m/\A(\S+ \S+).*? IP .*?(\S+) > (\S+):/;
112            5                                 50      my ( $src_host, $src_port ) = $source =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
113            5                                 39      my ( $dst_host, $dst_port ) = $dest   =~ m/((?:\d+\.){3}\d+)\.(\w+)/;
114                                                   
115                                                      # Change ports from service name to number.
116            5                                 30      $src_port = $self->port_number($src_port);
117            5                                 21      $dst_port = $self->port_number($dst_port);
118                                                      
119            5                                 46      my $hex = qr/[0-9a-f]/;
120            5                                372      (my $data = join('', $packet =~ m/\s+0x$hex+:\s((?:\s$hex{2,4})+)/go)) =~ s/\s+//g; 
121                                                   
122                                                      # Find length information in the IPv4 header.  Typically 5 32-bit
123                                                      # words.  See http://en.wikipedia.org/wiki/IPv4#Header
124            5                                 37      my $ip_hlen = hex(substr($data, 1, 1)); # Num of 32-bit words in header.
125                                                      # The total length of the entire datagram, including header.  This is
126                                                      # useful because it lets us see whether we got the whole thing.
127            5                                 19      my $ip_plen = hex(substr($data, 4, 4)); # Num of BYTES in IPv4 datagram.
128   ***      5     50                          33      my $complete = length($data) == 2 * $ip_plen ? 1 : 0;
129                                                   
130                                                      # Same thing in a different position, with the TCP header.  See
131                                                      # http://en.wikipedia.org/wiki/Transmission_Control_Protocol.
132            5                                 24      my $tcp_hlen = hex(substr($data, ($ip_hlen + 3) * 8, 1));
133                                                   
134                                                      # Get sequence and ack numbers.
135            5                                 25      my $seq = hex(substr($data, ($ip_hlen + 1) * 8, 8));
136            5                                 26      my $ack = hex(substr($data, ($ip_hlen + 2) * 8, 8));
137                                                   
138            5                                 28      my $flags = hex(substr($data, (($ip_hlen + 3) * 8) + 2, 2));
139                                                   
140                                                      # Throw away the IP and TCP headers.
141            5                                 23      $data = substr($data, ($ip_hlen + $tcp_hlen) * 8);
142                                                   
143   ***      5     50                         126      my $pkt = {
      ***            50                               
144                                                         ts        => $ts,
145                                                         seq       => $seq,
146                                                         ack       => $ack,
147                                                         fin       => $flags & 0x01,
148                                                         syn       => $flags & 0x02,
149                                                         rst       => $flags & 0x04,
150                                                         src_host  => $src_host,
151                                                         src_port  => $src_port,
152                                                         dst_host  => $dst_host,
153                                                         dst_port  => $dst_port,
154                                                         complete  => $complete,
155                                                         ip_hlen   => $ip_hlen,
156                                                         tcp_hlen  => $tcp_hlen,
157                                                         dgram_len => $ip_plen,
158                                                         data_len  => $ip_plen - (($ip_hlen + $tcp_hlen) * 4),
159                                                         data      => $data ? substr($data, 0, 10).(length $data > 10 ? '...' : '')
160                                                                            : '',
161                                                      };
162            5                                 15      MKDEBUG && _d('packet:', Dumper($pkt));
163            5                                 24      $pkt->{data} = $data;
164            5                                102      return $pkt;
165                                                   }
166                                                   
167                                                   sub port_number {
168   ***     10                   10      0     47      my ( $self, $port ) = @_;
169   ***     10     50                          42      return unless $port;
170           10    100                          85      return $port eq 'memcached' ? 11211
      ***            50                               
      ***            50                               
171                                                           : $port eq 'http'      ? 80
172                                                           : $port eq 'mysql'     ? 3306
173                                                           :                        $port; 
174                                                   }
175                                                   
176                                                   sub _d {
177            1                    1            13      my ($package, undef, $line) = caller 0;
178   ***      2     50                          17      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 17   
179            1                                  8           map { defined $_ ? $_ : 'undef' }
180                                                           @_;
181            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
182                                                   }
183                                                   
184                                                   1;
185                                                   
186                                                   # ###########################################################################
187                                                   # End TcpdumpParser package
188                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
71    ***     50      0     16   unless $args{$arg}
82           100      1      4   if $raw_packet =~ /^$/
83           100      1      3   if $pos_in_log
88           100      1      3   unless $raw_packet =~ /\A20/
102          100      1      3   if $args{'oktorun'}
109   ***     50      0      5   unless $packet
128   ***     50      5      0   length $data == 2 * $ip_plen ? :
143   ***     50      5      0   length $data > 10 ? :
      ***     50      5      0   $data ? :
169   ***     50      0     10   unless $port
170          100      1      9   $port eq 'mysql' ? :
      ***     50      0     10   $port eq 'http' ? :
      ***     50      0     10   $port eq 'memcached' ? :
178   ***     50      2      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
34    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine    Count Pod Location                                            
------------- ----- --- ----------------------------------------------------
BEGIN             1     /home/daniel/dev/maatkit/common/TcpdumpParser.pm:27 
BEGIN             1     /home/daniel/dev/maatkit/common/TcpdumpParser.pm:28 
BEGIN             1     /home/daniel/dev/maatkit/common/TcpdumpParser.pm:29 
BEGIN             1     /home/daniel/dev/maatkit/common/TcpdumpParser.pm:30 
BEGIN             1     /home/daniel/dev/maatkit/common/TcpdumpParser.pm:34 
_d                1     /home/daniel/dev/maatkit/common/TcpdumpParser.pm:177
_parse_packet     5     /home/daniel/dev/maatkit/common/TcpdumpParser.pm:108
new               1   0 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:37 
parse_event       8   0 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:68 
port_number      10   0 /home/daniel/dev/maatkit/common/TcpdumpParser.pm:168


TcpdumpParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1            10   use Test::More tests => 7;
               1                                  4   
               1                                  9   
13                                                    
14             1                    1            12   use TcpdumpParser;
               1                                  2   
               1                                 11   
15             1                    1            12   use MaatkitTest;
               1                                  5   
               1                                 35   
16                                                    
17             1                                  5   my $sample = "common/t/samples/tcpdump/";
18             1                                  6   my $p = new TcpdumpParser();
19                                                    
20                                                    # First, parse the TCP and IP packet...
21             1                                 13   my $contents = <<EOF;
22                                                    2009-04-12 21:18:40.638244 IP 192.168.28.223.56462 > 192.168.28.213.mysql: tcp 301
23                                                    \t0x0000:  4508 0161 7dc5 4000 4006 00c5 c0a8 1cdf
24                                                    \t0x0010:  c0a8 1cd5 dc8e 0cea adc4 5111 ad6f 995e
25                                                    \t0x0020:  8018 005b 0987 0000 0101 080a 62e6 32e7
26                                                    \t0x0030:  62e4 a103 2901 0000 0353 454c 4543 5420
27                                                    \t0x0040:  6469 7374 696e 6374 2074 702e 6964 2c20
28                                                    \t0x0050:  7470 2e70 726f 6475 6374 5f69 6d61 6765
29                                                    \t0x0060:  5f6c 696e 6b20 6173 2069 6d67 2c20 7470
30                                                    \t0x0070:  2e69 6e6e 6572 5f76 6572 7365 3220 6173
31                                                    \t0x0080:  2074 6974 6c65 2c20 7470 2e70 7269 6365
32                                                    \t0x0090:  2046 524f 4d20 7470 726f 6475 6374 7320
33                                                    \t0x00a0:  7470 2c20 6667 6966 745f 6c69 6e6b 2065
34                                                    \t0x00b0:  2057 4845 5245 2074 702e 7072 6f64 7563
35                                                    \t0x00c0:  745f 6465 7363 203d 2027 6667 6966 7427
36                                                    \t0x00d0:  2041 4e44 2074 702e 6964 3d65 2e70 726f
37                                                    \t0x00e0:  6475 6374 5f69 6420 2061 6e64 2074 702e
38                                                    \t0x00f0:  7072 6f64 7563 745f 7374 6174 7573 3d35
39                                                    \t0x0100:  2041 4e44 2065 2e63 6174 5f69 6420 696e
40                                                    \t0x0110:  2028 322c 3131 2c2d 3129 2041 4e44 2074
41                                                    \t0x0120:  702e 696e 7369 6465 5f69 6d61 6765 203d
42                                                    \t0x0130:  2027 456e 676c 6973 6827 2020 4f52 4445
43                                                    \t0x0140:  5220 4259 2074 702e 7072 696e 7461 626c
44                                                    \t0x0150:  6520 6465 7363 204c 494d 4954 2030 2c20
45                                                    \t0x0160:  38
46                                                    EOF
47                                                    
48             1                                  9   is_deeply(
49                                                       $p->_parse_packet($contents),
50                                                       {  ts         => '2009-04-12 21:18:40.638244',
51                                                          seq        => '2915324177',
52                                                          ack        => '2909772126',
53                                                          src_host   => '192.168.28.223',
54                                                          src_port   =>  '56462',
55                                                          dst_host   => '192.168.28.213',
56                                                          dst_port   => '3306',
57                                                          complete   => 1,
58                                                          ip_hlen    => 5,
59                                                          tcp_hlen   => 8,
60                                                          dgram_len  => 353,
61                                                          data_len   => 301,
62                                                          syn        => 0,
63                                                          fin        => 0,
64                                                          rst        => 0,
65                                                          data => join('', qw(
66                                                             2901 0000 0353 454c 4543 5420
67                                                             6469 7374 696e 6374 2074 702e 6964 2c20
68                                                             7470 2e70 726f 6475 6374 5f69 6d61 6765
69                                                             5f6c 696e 6b20 6173 2069 6d67 2c20 7470
70                                                             2e69 6e6e 6572 5f76 6572 7365 3220 6173
71                                                             2074 6974 6c65 2c20 7470 2e70 7269 6365
72                                                             2046 524f 4d20 7470 726f 6475 6374 7320
73                                                             7470 2c20 6667 6966 745f 6c69 6e6b 2065
74                                                             2057 4845 5245 2074 702e 7072 6f64 7563
75                                                             745f 6465 7363 203d 2027 6667 6966 7427
76                                                             2041 4e44 2074 702e 6964 3d65 2e70 726f
77                                                             6475 6374 5f69 6420 2061 6e64 2074 702e
78                                                             7072 6f64 7563 745f 7374 6174 7573 3d35
79                                                             2041 4e44 2065 2e63 6174 5f69 6420 696e
80                                                             2028 322c 3131 2c2d 3129 2041 4e44 2074
81                                                             702e 696e 7369 6465 5f69 6d61 6765 203d
82                                                             2027 456e 676c 6973 6827 2020 4f52 4445
83                                                             5220 4259 2074 702e 7072 696e 7461 626c
84                                                             6520 6465 7363 204c 494d 4954 2030 2c20
85                                                             38)),
86                                                       },
87                                                       'Parsed packet OK');
88                                                    
89             1                                 14   my $oktorun = 1;
90                                                    
91                                                    # Check that parsing multiple packets and callback works.
92                                                    test_packet_parser(
93                                                       parser  => $p,
94             1                    1             4      oktorun => sub { $oktorun = $_[0]; },
95             1                                 51      file    => "$sample/tcpdump001.txt",
96                                                       desc    => 'basic packets',
97                                                       result  => 
98                                                       [
99                                                          {  ts          => '2009-04-12 09:50:16.804849',
100                                                            ack         => '2903937561',
101                                                            seq         => '2894758931',
102                                                            src_host    => '127.0.0.1',
103                                                            src_port    => '42167',
104                                                            dst_host    => '127.0.0.1',
105                                                            dst_port    => '3306',
106                                                            complete    => 1,
107                                                            pos_in_log  => 0,
108                                                            ip_hlen     => 5,
109                                                            tcp_hlen    => 8,
110                                                            dgram_len   => 89,
111                                                            data_len    => 37,
112                                                            syn         => 0,
113                                                            fin         => 0,
114                                                            rst         => 0,
115                                                            data        => join('', qw(
116                                                               2100 0000 0373 656c 6563 7420
117                                                               2268 656c 6c6f 2077 6f72 6c64 2220 6173
118                                                               2067 7265 6574 696e 67)),
119                                                         },
120                                                         {  ts          => '2009-04-12 09:50:16.805123',
121                                                            ack         => '2894758968',
122                                                            seq         => '2903937561',
123                                                            src_host    => '127.0.0.1',
124                                                            src_port    => '3306',
125                                                            dst_host    => '127.0.0.1',
126                                                            dst_port    => '42167',
127                                                            complete    => 1,
128                                                            pos_in_log  => 355,
129                                                            ip_hlen     => 5,
130                                                            tcp_hlen    => 8,
131                                                            dgram_len   => 125,
132                                                            data_len    => 73,
133                                                            syn         => 0,
134                                                            fin         => 0,
135                                                            rst         => 0,
136                                                            data          => join('', qw(
137                                                               0100 0001 011e 0000 0203 6465
138                                                               6600 0000 0867 7265 6574 696e 6700 0c08
139                                                               000b 0000 00fd 0100 1f00 0005 0000 03fe
140                                                               0000 0200 0c00 0004 0b68 656c 6c6f 2077
141                                                               6f72 6c64 0500 0005 fe00 0002 00)),
142                                                         },
143                                                      ],
144                                                   );
145                                                   
146            1                                 42   is(
147                                                      $oktorun,
148                                                      0,
149                                                      'Sets oktorun'
150                                                   );
151                                                   
152                                                   # #############################################################################
153                                                   # Issue 544: memcached parse error: Use of uninitialized value in pattern match 
154                                                   # #############################################################################
155                                                   
156                                                   # This issue is caused by having extra info in the tcpdump output.
157            1                                 25   test_packet_parser(
158                                                      parser => $p,
159                                                      file   => "common/t/samples/memc_tcpdump013.txt",
160                                                      desc   => 'verbose tcpdump output with ascii dump',
161                                                      result =>
162                                                      [
163                                                         {  ts          => '2009-08-03 19:56:37.683157',
164                                                            ack         => '1391934401',
165                                                            seq         => '1393769400',
166                                                            src_host    => '75.126.27.210',
167                                                            src_port    => '42819',
168                                                            dst_host    => '75.126.27.210',
169                                                            dst_port    => '11211',
170                                                            complete    => 1,
171                                                            pos_in_log  => 0,
172                                                            ip_hlen     => 5,
173                                                            tcp_hlen    => 5,
174                                                            dgram_len   => 66,
175                                                            data_len    => 26,
176                                                            syn         => 0,
177                                                            fin         => 0,
178                                                            rst         => 0,
179                                                            data        => join('', qw(
180                                                               6765 7420 323a 6f70 7469 6f6e 733a 616c 6c6f 7074 696f 6e73 0d0a
181                                                            )),
182                                                         },
183                                                      ],
184                                                   );
185                                                   
186                                                   # #############################################################################
187                                                   # Issue 564: mk-query-digest --type tcpdump|memcached crashes on empty input
188                                                   # #############################################################################
189            1                                 35   test_packet_parser(
190                                                      parser => $p,
191                                                      file   => "$sample/tcpdump020.txt",
192                                                      desc   => 'Empty input (issue 564)',
193                                                      result =>
194                                                      [
195                                                      ],
196                                                   );
197                                                   
198                                                   # #############################################################################
199                                                   # Issue 906: mk-query-digest --tcpdump doesn't work if dumped packet header
200                                                   # has extra info
201                                                   # #############################################################################
202            1                                 40   test_packet_parser(
203                                                      parser => $p,
204                                                      file   => "$sample/tcpdump039.txt",
205                                                      desc   => 'Extra packet header info (issue 906)',
206                                                      result =>
207                                                      [
208                                                         {
209                                                            ack         => 3203084012,
210                                                            complete    => 1,
211                                                            data_len    => 154,
212                                                            dgram_len   => 206,
213                                                            dst_host    => '192.168.1.220',
214                                                            dst_port    => '3310',
215                                                            fin         => 0,
216                                                            ip_hlen     => 5,
217                                                            pos_in_log  => 0,
218                                                            rst         => 0,
219                                                            seq         => 3474524,
220                                                            src_host    => '192.168.1.81',
221                                                            src_port    => '36762',
222                                                            syn         => 0,
223                                                            tcp_hlen    => 8,
224                                                            ts          => '2009-11-10 09:49:31.864481',
225                                                            data        => '960000000353454c45435420636f757273655f73656374696f6e5f69642c20636f757273655f69642c20636f64652c206465736372697074696f6e2c206578745f69642c20626f6172645f69642c207374617475732c206c6f636174696f6e0a46524f4d202020636f757273655f73656374696f6e0a57484552452020636f757273655f73656374696f6e5f6964203d2027313435383133270a',
226                                                         },
227                                                      ],
228                                                   );
229                                                   
230                                                   # #############################################################################
231                                                   # Done.
232                                                   # #############################################################################
233            1                                 49   my $output = '';
234                                                   {
235            1                                  4      local *STDERR;
               1                                 12   
236            1                    1             3      open STDERR, '>', \$output;
               1                                521   
               1                                  5   
               1                                 13   
237            1                                 27      $p->_d('Complete test coverage');
238                                                   }
239                                                   like(
240            1                                 23      $output,
241                                                      qr/Complete test coverage/,
242                                                      '_d() works'
243                                                   );
244                                                   


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location           
---------- ----- -------------------
BEGIN          1 TcpdumpParser.t:10 
BEGIN          1 TcpdumpParser.t:11 
BEGIN          1 TcpdumpParser.t:12 
BEGIN          1 TcpdumpParser.t:14 
BEGIN          1 TcpdumpParser.t:15 
BEGIN          1 TcpdumpParser.t:236
BEGIN          1 TcpdumpParser.t:4  
BEGIN          1 TcpdumpParser.t:9  
__ANON__       1 TcpdumpParser.t:94 


