---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mon/HTTPProtocolParser.pm   85.6   71.4   66.7   90.9    0.0   99.4   79.9
HTTPProtocolParser.t          100.0   50.0   33.3  100.0    n/a    0.6   94.9
Total                          89.3   70.7   63.0   95.0    0.0  100.0   83.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:26 2010
Finish:       Thu Jun 24 19:33:26 2010

Run:          HTTPProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:28 2010
Finish:       Thu Jun 24 19:33:30 2010

/home/daniel/dev/maatkit/common/HTTPProtocolParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009 Percona Inc.
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
18                                                    # HTTPProtocolParser package $Revision: 5811 $
19                                                    # ###########################################################################
20                                                    package HTTPProtocolParser;
21             1                    1             5   use base 'ProtocolParser';
               1                                  2   
               1                                  9   
22                                                    
23             1                    1             6   use strict;
               1                                  6   
               1                                  5   
24             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
25             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
26                                                    
27             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  5   
28                                                    $Data::Dumper::Indent    = 1;
29                                                    $Data::Dumper::Sortkeys  = 1;
30                                                    $Data::Dumper::Quotekeys = 0;
31                                                    
32    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 13   
33                                                    
34                                                    # server is the "host:port" of the sever being watched.  It's auto-guessed if
35                                                    # not specified.
36                                                    sub new {
37    ***      8                    8      0     54      my ( $class, %args ) = @_;
38             8                                112      my $self = $class->SUPER::new(
39                                                          %args,
40                                                          port => 80,
41                                                       );
42             8                                252      return $self;
43                                                    }
44                                                    
45                                                    # Handles a packet from the server given the state of the session.  Returns an
46                                                    # event if one was ready to be created, otherwise returns nothing.
47                                                    sub _packet_from_server {
48            37                   37         55901      my ( $self, $packet, $session, $misc ) = @_;
49    ***     37     50                         162      die "I need a packet"  unless $packet;
50    ***     37     50                         132      die "I need a session" unless $session;
51                                                    
52            37                                 89      MKDEBUG && _d('Packet is from server; client state:', $session->{state}); 
53                                                    
54                                                       # If there's no session state, then we're catching a server response
55                                                       # mid-stream.
56    ***     37     50                         182      if ( !$session->{state} ) {
57    ***      0                                  0         MKDEBUG && _d('Ignoring mid-stream server response');
58    ***      0                                  0         return;
59                                                       }
60                                                    
61            37    100                         161      if ( $session->{out_of_order} ) {
62                                                          # We're waiting for the header so we can get the content length.
63                                                          # Once we know this, we can determine how many out of order packets
64                                                          # we need to complete the request, then order them and re-process.
65            10                                 29         my ($line1, $content);
66            10    100                          42         if ( !$session->{have_header} ) {
67             4                                 22            ($line1, $content) = $self->_parse_header(
68                                                                $session, $packet->{data}, $packet->{data_len});
69                                                          }
70            10    100                          36         if ( $line1 ) {
71             2                                  8            $session->{have_header} = 1;
72             2                                  9            $packet->{content_len}  = length $content;
73             2                                  4            MKDEBUG && _d('Got out of order header with',
74                                                                $packet->{content_len}, 'bytes of content');
75                                                          }
76    ***     10            66                   85         my $have_len = $packet->{content_len} || $packet->{data_len};
77            39                                147         map { $have_len += $_->{data_len} }
              10                                 37   
78            10                                 27            @{$session->{packets}};
79            10    100    100                  114         $session->{have_all_packets}
80                                                             = 1 if $session->{attribs}->{bytes}
81                                                                    && $have_len >= $session->{attribs}->{bytes};
82            10                                 20         MKDEBUG && _d('Have', $have_len, 'of', $session->{attribs}->{bytes});
83            10                                 41         return;
84                                                       }
85                                                    
86                                                       # Assume that the server is returning only one value. 
87                                                       # TODO: make it handle multiple.
88            27    100                         149      if ( $session->{state} eq 'awaiting reply' ) {
      ***            50                               
89                                                    
90                                                          # Save this early because we may return early if the packets
91                                                          # are being received out of order.  Also, save it only once
92                                                          # in case we re-process packets if they're out of order.
93            19    100                         131         $session->{start_reply} = $packet->{ts} unless $session->{start_reply};
94                                                    
95                                                          # Get first line of header and first chunk of contents/data.
96            19                                115         my ($line1, $content) = $self->_parse_header($session, $packet->{data},
97                                                                $packet->{data_len});
98                                                    
99                                                          # The reponse, when in order, is text header followed by data.
100                                                         # If there's no line1, then we didn't get the text header first
101                                                         # which means we're getting the response in out of order packets.
102           19    100                          94         if ( !$line1 ) {
103            2                                  9            $session->{out_of_order}     = 1;  # alert parent
104            2                                  8            $session->{have_all_packets} = 0;
105            2                                  9            return;
106                                                         }
107                                                   
108                                                         # First line should be: version  code phrase
109                                                         # E.g.:                 HTTP/1.1  200 OK
110           17                                134         my ($version, $code, $phrase) = $line1 =~ m/(\S+)/g;
111           17                                 89         $session->{attribs}->{Status_code} = $code;
112           17                                 42         MKDEBUG && _d('Status code for last', $session->{attribs}->{arg},
113                                                            'request:', $session->{attribs}->{Status_code});
114                                                   
115   ***     17     50                          72         my $content_len = $content ? length $content : 0;
116           17                                 40         MKDEBUG && _d('Got', $content_len, 'bytes of content');
117   ***     17    100     66                  234         if ( $session->{attribs}->{bytes}
118                                                              && $content_len < $session->{attribs}->{bytes} ) {
119            8                                 48            $session->{data_len}  = $session->{attribs}->{bytes};
120            8                                 37            $session->{buff}      = $content;
121            8                                 50            $session->{buff_left} = $session->{attribs}->{bytes} - $content_len;
122            8                                 21            MKDEBUG && _d('Contents not complete,', $session->{buff_left},
123                                                               'bytes left');
124            8                                 29            $session->{state} = 'recving content';
125            8                                 38            return;
126                                                         }
127                                                      }
128                                                      elsif ( $session->{state} eq 'recving content' ) {
129   ***      8     50                          35         if ( $session->{buff} ) {
130   ***      0                                  0            MKDEBUG && _d('Receiving content,', $session->{buff_left},
131                                                               'bytes left');
132   ***      0                                  0            return;
133                                                         }
134            8                                 23         MKDEBUG && _d('Contents received');
135                                                      }
136                                                      else {
137                                                         # TODO:
138   ***      0                                  0         warn "Server response in unknown state"; 
139   ***      0                                  0         return;
140                                                      }
141                                                   
142           17                                 40      MKDEBUG && _d('Creating event, deleting session');
143   ***     17            66                  166      $session->{end_reply} = $session->{ts_max} || $packet->{ts};
144           17                                 99      my $event = $self->make_event($session, $packet);
145           17                               3249      delete $self->{sessions}->{$session->{client}}; # http is stateless!
146           17                                 72      return $event;
147                                                   }
148                                                   
149                                                   # Handles a packet from the client given the state of the session.
150                                                   sub _packet_from_client {
151           18                   18         45359      my ( $self, $packet, $session, $misc ) = @_;
152   ***     18     50                          91      die "I need a packet"  unless $packet;
153   ***     18     50                          74      die "I need a session" unless $session;
154                                                   
155           18                                 46      MKDEBUG && _d('Packet is from client; state:', $session->{state});
156                                                   
157           18                                 54      my $event;
158           18    100    100                  190      if ( ($session->{state} || '') =~ m/awaiting / ) {
159            1                                  3         MKDEBUG && _d('More client headers:', $packet->{data});
160            1                                  4         return;
161                                                      }
162                                                   
163   ***     17     50                          85      if ( !$session->{state} ) {
164           17                                 70         $session->{state} = 'awaiting reply';
165           17                                108         my ($line1, undef) = $self->_parse_header($session, $packet->{data}, $packet->{data_len});
166                                                         # First line should be: request page      version
167                                                         # E.g.:                 GET     /foo.html HTTP/1.1
168           17                                152         my ($request, $page, $version) = $line1 =~ m/(\S+)/g;
169   ***     17     50     33                  166         if ( !$request || !$page ) {
170   ***      0                                  0            MKDEBUG && _d("Didn't get a request or page:", $request, $page);
171   ***      0                                  0            return;
172                                                         }
173           17                                 62         $request = lc $request;
174   ***     17            50                   99         my $vh   = $session->{attribs}->{Virtual_host} || '';
175           17                                 82         my $arg = "$request $vh$page";
176           17                                 41         MKDEBUG && _d('arg:', $arg);
177                                                   
178   ***     17     50     66                  116         if ( $request eq 'get' || $request eq 'post' ) {
179           17                                 64            @{$session->{attribs}}{qw(arg)} = ($arg);
              17                                 92   
180                                                         }
181                                                         else {
182   ***      0                                  0            MKDEBUG && _d("Don't know how to handle a", $request, "request");
183   ***      0                                  0            return;
184                                                         }
185                                                   
186           17                                 80         $session->{start_request}         = $packet->{ts};
187           17                                 85         $session->{attribs}->{host}       = $packet->{src_host};
188           17                                 79         $session->{attribs}->{pos_in_log} = $packet->{pos_in_log};
189           17                                 87         $session->{attribs}->{ts}         = $packet->{ts};
190                                                      }
191                                                      else {
192                                                         # TODO:
193   ***      0                                  0         die "Probably multiple GETs from client before a server response?"; 
194                                                      }
195                                                   
196           17                                 79      return $event;
197                                                   }
198                                                   
199                                                   sub _parse_header {
200           40                   40           225      my ( $self, $session, $data, $len, $no_recurse ) = @_;
201   ***     40     50                         171      die "I need data" unless $data;
202           40                                297      my ($header, $content)    = split(/\r\n\r\n/, $data);
203           40                                414      my ($line1, $header_vals) = $header  =~ m/\A(\S+ \S+ .+?)\r\n(.+)?/s;
204           40                                112      MKDEBUG && _d('HTTP header:', $line1);
205           40    100                         171      return unless $line1;
206                                                   
207   ***     36     50                         143      if ( !$header_vals ) {
208   ***      0                                  0         MKDEBUG && _d('No header vals');
209   ***      0                                  0         return $line1, undef;
210                                                      }
211           36                                 90      my @headers;
212           36                                289      foreach my $val ( split(/\r\n/, $header_vals) ) {
213   ***    348     50                        1223         last unless $val;
214                                                         # Capture and save any useful header values.
215          348                                780         MKDEBUG && _d('HTTP header:', $val);
216          348    100                        1410         if ( $val =~ m/^Content-Length/i ) {
217           20                                155            ($session->{attribs}->{bytes}) = $val =~ /: (\d+)/;
218           20                                 59            MKDEBUG && _d('Saved Content-Length:', $session->{attribs}->{bytes});
219                                                         }
220          348    100                        1392         if ( $val =~ m/Content-Encoding/i ) {
221           10                                 77            ($session->{compressed}) = $val =~ /: (\w+)/;
222           10                                 28            MKDEBUG && _d('Saved Content-Encoding:', $session->{compressed});
223                                                         }
224          348    100                        1546         if ( $val =~ m/^Host/i ) {
225                                                            # The "host" attribute is already taken, so we call this "domain".
226           17                                167            ($session->{attribs}->{Virtual_host}) = $val =~ /: (\S+)/;
227           17                                 61            MKDEBUG && _d('Saved Host:', ($session->{attribs}->{Virtual_host}));
228                                                         }
229                                                      }
230           36                                253      return $line1, $content;
231                                                   }
232                                                   
233                                                   sub _d {
234   ***      0                    0                    my ($package, undef, $line) = caller 0;
235   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
236   ***      0                                              map { defined $_ ? $_ : 'undef' }
237                                                           @_;
238   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
239                                                   }
240                                                   
241                                                   1;
242                                                   
243                                                   # ###########################################################################
244                                                   # End HTTPProtocolParser package
245                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
49    ***     50      0     37   unless $packet
50    ***     50      0     37   unless $session
56    ***     50      0     37   if (not $$session{'state'})
61           100     10     27   if ($$session{'out_of_order'})
66           100      4      6   if (not $$session{'have_header'})
70           100      2      8   if ($line1)
79           100      2      8   if $$session{'attribs'}{'bytes'} and $have_len >= $$session{'attribs'}{'bytes'}
88           100     19      8   if ($$session{'state'} eq 'awaiting reply') { }
      ***     50      8      0   elsif ($$session{'state'} eq 'recving content') { }
93           100     17      2   unless $$session{'start_reply'}
102          100      2     17   if (not $line1)
115   ***     50     17      0   $content ? :
117          100      8      9   if ($$session{'attribs'}{'bytes'} and $content_len < $$session{'attribs'}{'bytes'})
129   ***     50      0      8   if ($$session{'buff'})
152   ***     50      0     18   unless $packet
153   ***     50      0     18   unless $session
158          100      1     17   if (($$session{'state'} || '') =~ /awaiting /)
163   ***     50     17      0   if (not $$session{'state'}) { }
169   ***     50      0     17   if (not $request or not $page)
178   ***     50     17      0   if ($request eq 'get' or $request eq 'post') { }
201   ***     50      0     40   unless $data
205          100      4     36   unless $line1
207   ***     50      0     36   if (not $header_vals)
213   ***     50      0    348   unless $val
216          100     20    328   if ($val =~ /^Content-Length/i)
220          100     10    338   if ($val =~ /Content-Encoding/i)
224          100     17    331   if ($val =~ /^Host/i)
235   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
79           100      2      6      2   $$session{'attribs'}{'bytes'} and $have_len >= $$session{'attribs'}{'bytes'}
117   ***     66      0      9      8   $$session{'attribs'}{'bytes'} and $content_len < $$session{'attribs'}{'bytes'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
32    ***     50      0      1   $ENV{'MKDEBUG'} || 0
158          100      1     17   $$session{'state'} || ''
174   ***     50     17      0   $$session{'attribs'}{'Virtual_host'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
76    ***     66      2      8      0   $$packet{'content_len'} || $$packet{'data_len'}
143   ***     66      2     15      0   $$session{'ts_max'} || $$packet{'ts'}
169   ***     33      0      0     17   not $request or not $page
178   ***     66     16      1      0   $request eq 'get' or $request eq 'post'


Covered Subroutines
-------------------

Subroutine          Count Pod Location                                                 
------------------- ----- --- ---------------------------------------------------------
BEGIN                   1     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:21 
BEGIN                   1     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:23 
BEGIN                   1     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:24 
BEGIN                   1     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:25 
BEGIN                   1     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:27 
BEGIN                   1     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:32 
_packet_from_client    18     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:151
_packet_from_server    37     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:48 
_parse_header          40     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:200
new                     8   0 /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:37 

Uncovered Subroutines
---------------------

Subroutine          Count Pod Location                                                 
------------------- ----- --- ---------------------------------------------------------
_d                      0     /home/daniel/dev/maatkit/common/HTTPProtocolParser.pm:234


HTTPProtocolParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1             9   use Test::More tests => 16;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            12   use TcpdumpParser;
               1                                  3   
               1                                 11   
15             1                    1            11   use ProtocolParser;
               1                                  3   
               1                                 11   
16             1                    1            11   use HTTPProtocolParser;
               1                                  3   
               1                                 16   
17             1                    1            12   use MaatkitTest;
               1                                  5   
               1                                 34   
18                                                    
19             1                                  8   my $tcpdump  = new TcpdumpParser();
20             1                                 27   my $protocol; # Create a new HTTPProtocolParser for each test.
21                                                    
22                                                    # GET a very simple page.
23             1                                  5   $protocol = new HTTPProtocolParser();
24             1                                 22   test_protocol_parser(
25                                                       parser   => $tcpdump,
26                                                       protocol => $protocol,
27                                                       file     => 'common/t/samples/http_tcpdump001.txt',
28                                                       result   => [
29                                                          { ts              => '2009-11-09 11:31:52.341907',
30                                                            bytes           => '715',
31                                                            host            => '10.112.2.144',
32                                                            pos_in_log      => 0,
33                                                            Virtual_host    => 'hackmysql.com',
34                                                            arg             => 'get hackmysql.com/contact',
35                                                            Status_code     => '200',
36                                                            Query_time      => '0.651419',
37                                                            Transmit_time   => '0.000000',
38                                                          },
39                                                       ],
40                                                    );
41                                                    
42                                                    # Get http://www.percona.com/about-us.html
43             1                                 36   $protocol = new HTTPProtocolParser();
44             1                                 75   test_protocol_parser(
45                                                       parser   => $tcpdump,
46                                                       protocol => $protocol,
47                                                       file     => 'common/t/samples/http_tcpdump002.txt',
48                                                       result   => [
49                                                          {
50                                                             ts             => '2009-11-09 15:31:09.074855',
51                                                             Query_time     => '0.070097',
52                                                             Status_code    => '200',
53                                                             Transmit_time  => '0.000720',
54                                                             Virtual_host   => 'www.percona.com',
55                                                             arg            => 'get www.percona.com/about-us.html',
56                                                             bytes          => 3832,
57                                                             host           => '10.112.2.144',
58                                                             pos_in_log     => 206,
59                                                          },
60                                                          {
61                                                             ts             => '2009-11-09 15:31:09.157215',
62                                                             Query_time     => '0.068558',
63                                                             Status_code    => '200',
64                                                             Transmit_time  => '0.066490',
65                                                             Virtual_host   => 'www.percona.com',
66                                                             arg            => 'get www.percona.com/js/jquery.js',
67                                                             bytes          => 9921,
68                                                             host           => '10.112.2.144',
69                                                             pos_in_log     => 16362,
70                                                          },
71                                                          {
72                                                             ts             => '2009-11-09 15:31:09.346763',
73                                                             Query_time     => '0.066506',
74                                                             Status_code    => '200',
75                                                             Transmit_time  => '0.000000',
76                                                             Virtual_host   => 'www.percona.com',
77                                                             arg            => 'get www.percona.com/images/menu_team.gif',
78                                                             bytes          => 344,
79                                                             host           => '10.112.2.144',
80                                                             pos_in_log     => 53100,
81                                                          },
82                                                          {
83                                                             ts             => '2009-11-09 15:31:09.373800',
84                                                             Query_time     => '0.045442',
85                                                             Status_code    => '200',
86                                                             Transmit_time  => '0.000000',
87                                                             Virtual_host   => 'www.google-analytics.com',
88                                                             arg            => 'get www.google-analytics.com/__utm.gif?utmwv=1.3&utmn=1710381507&utmcs=UTF-8&utmsr=1280x800&utmsc=24-bit&utmul=en-us&utmje=1&utmfl=10.0%20r22&utmdt=About%20Percona&utmhn=www.percona.com&utmhid=1947703805&utmr=0&utmp=/about-us.html&utmac=UA-343802-3&utmcc=__utma%3D154442809.1969570579.1256593671.1256825719.1257805869.3%3B%2B__utmz%3D154442809.1256593671.1.1.utmccn%3D(direct)%7Cutmcsr%3D(direct)%7Cutmcmd%3D(none)%3B%2B',
89                                                             bytes          => 35,
90                                                             host           => '10.112.2.144',
91                                                             pos_in_log     => 55942,
92                                                          },
93                                                          {
94                                                             ts             => '2009-11-09 15:31:09.411349',
95                                                             Query_time     => '0.073882',
96                                                             Status_code    => '200',
97                                                             Transmit_time  => '0.000000',
98                                                             Virtual_host   => 'www.percona.com',
99                                                             arg            => 'get www.percona.com/images/menu_our-vision.gif',
100                                                            bytes          => 414,
101                                                            host           => '10.112.2.144',
102                                                            pos_in_log     => 59213,
103                                                         },
104                                                         {
105                                                            ts             => '2009-11-09 15:31:09.420851',
106                                                            Query_time     => '0.067669',
107                                                            Status_code    => '200',
108                                                            Transmit_time  => '0.000000',
109                                                            Virtual_host   => 'www.percona.com',
110                                                            arg            => 'get www.percona.com/images/bg-gray-corner-top.gif',
111                                                            bytes          => 170,
112                                                            host           => '10.112.2.144',
113                                                            pos_in_log     => 65644,
114                                                         },
115                                                         {
116                                                            ts             => '2009-11-09 15:31:09.420996',
117                                                            Query_time     => '0.067345',
118                                                            Status_code    => '200',
119                                                            Transmit_time  => '0.134909',
120                                                            Virtual_host   => 'www.percona.com',
121                                                            arg            => 'get www.percona.com/images/handshake.jpg',
122                                                            bytes          => 20017,
123                                                            host           => '10.112.2.144',
124                                                            pos_in_log     => 67956,
125                                                         },
126                                                         {
127                                                            ts             => '2009-11-09 15:31:14.536149',
128                                                            Query_time     => '0.061528',
129                                                            Status_code    => '200',
130                                                            Transmit_time  => '0.059577',
131                                                            Virtual_host   => 'hit.clickaider.com',
132                                                            arg            => 'get hit.clickaider.com/clickaider.js',
133                                                            bytes          => 4009,
134                                                            host           => '10.112.2.144',
135                                                            pos_in_log     => 147447,
136                                                         },
137                                                         {
138                                                            ts             => '2009-11-09 15:31:14.678713',
139                                                            Query_time     => '0.060436',
140                                                            Status_code    => '200',
141                                                            Transmit_time  => '0.000000',
142                                                            Virtual_host   => 'hit.clickaider.com',
143                                                            arg            => 'get hit.clickaider.com/pv?lng=140&&lnks=&t=About%20Percona&c=73a41b95-2926&r=http%3A%2F%2Fwww.percona.com%2F&tz=-420&loc=http%3A%2F%2Fwww.percona.com%2Fabout-us.html&rnd=3688',
144                                                            bytes          => 43,
145                                                            host           => '10.112.2.144',
146                                                            pos_in_log     => 167245,
147                                                         },
148                                                         {
149                                                            ts             => '2009-11-09 15:31:14.737890',
150                                                            Query_time     => '0.061937',
151                                                            Status_code    => '200',
152                                                            Transmit_time  => '0.000000',
153                                                            Virtual_host   => 'hit.clickaider.com',
154                                                            arg            => 'get hit.clickaider.com/s/forms.js',
155                                                            bytes          => 822,
156                                                            host           => '10.112.2.144',
157                                                            pos_in_log     => 170117,
158                                                         },
159                                                      ],
160                                                   );
161                                                   
162                                                   # A reponse received in out of order packet.
163            1                                 58   $protocol = new HTTPProtocolParser();
164            1                                 17   test_protocol_parser(
165                                                      parser   => $tcpdump,
166                                                      protocol => $protocol,
167                                                      file     => 'common/t/samples/http_tcpdump004.txt',
168                                                      result   => [
169                                                         {  ts             => '2009-11-12 11:27:10.757573',
170                                                            Query_time     => '0.327356',
171                                                            Status_code    => '200',
172                                                            Transmit_time  => '0.549501',
173                                                            Virtual_host   => 'dev.mysql.com',
174                                                            arg            => 'get dev.mysql.com/common/css/mysql.css',
175                                                            bytes          => 11283,
176                                                            host           => '10.67.237.92',
177                                                            pos_in_log     => 776,
178                                                         },
179                                                      ],
180                                                   );
181                                                   
182                                                   # A client request broken over 2 packets.
183            1                                 33   $protocol = new HTTPProtocolParser();
184            1                                 16   test_protocol_parser(
185                                                      parser   => $tcpdump,
186                                                      protocol => $protocol,
187                                                      file     => 'common/t/samples/http_tcpdump005.txt',
188                                                      result   => [
189                                                         {  ts             => '2009-11-13 09:20:31.041924',
190                                                            Query_time     => '0.342166',
191                                                            Status_code    => '200',
192                                                            Transmit_time  => '0.012780',
193                                                            Virtual_host   => 'dev.mysql.com',
194                                                            arg            => 'get dev.mysql.com/doc/refman/5.0/fr/retrieving-data.html',
195                                                            bytes          => 4382,
196                                                            host           => '192.168.200.110',
197                                                            pos_in_log     => 785, 
198                                                         },
199                                                      ],
200                                                   );
201                                                   
202                                                   # Out of order header that might look like the text header
203                                                   # but is really data; text header arrives last.
204            1                                 28   $protocol = new HTTPProtocolParser();
205            1                                 17   test_protocol_parser(
206                                                      parser   => $tcpdump,
207                                                      protocol => $protocol,
208                                                      file     => 'common/t/samples/http_tcpdump006.txt',
209                                                      result   => [
210                                                         {  ts             => '2009-11-13 09:50:44.432099',
211                                                            Query_time     => '0.140878',
212                                                            Status_code    => '200',
213                                                            Transmit_time  => '0.237153',
214                                                            Virtual_host   => '247wallst.files.wordpress.com',
215                                                            arg            => 'get 247wallst.files.wordpress.com/2009/11/airplane4.jpg?w=139&h=93',
216                                                            bytes          => 3391,
217                                                            host           => '192.168.200.110',
218                                                            pos_in_log     => 782,
219                                                         },
220                                                      ],
221                                                   );
222                                                   
223                                                   # One 2.6M image that took almost a minute to load (very slow wifi).
224            1                                 51   $protocol = new HTTPProtocolParser();
225            1                                 28   test_protocol_parser(
226                                                      parser   => $tcpdump,
227                                                      protocol => $protocol,
228                                                      file     => 'common/t/samples/http_tcpdump007.txt',
229                                                      result   => [
230                                                         {  ts             => '2009-11-13 10:09:53.251620',
231                                                            Query_time     => '0.121971',
232                                                            Status_code    => '200',
233                                                            Transmit_time  => '40.311228',
234                                                            Virtual_host   => 'apod.nasa.gov',
235                                                            arg            => 'get apod.nasa.gov/apod/image/0911/Ophcloud_spitzer.jpg',
236                                                            bytes          => 2706737,
237                                                            host           => '192.168.200.110',
238                                                            pos_in_log     => 640,
239                                                         }
240                                                      ],
241                                                   );
242                                                   
243                                                   # A simple POST.
244            1                                 33   $protocol = new HTTPProtocolParser();
245            1                                 17   test_protocol_parser(
246                                                      parser   => $tcpdump,
247                                                      protocol => $protocol,
248                                                      file     => 'common/t/samples/http_tcpdump008.txt',
249                                                      result   => [
250                                                         {  ts             => '2009-11-13 10:53:48.349465',
251                                                            Query_time     => '0.030740',
252                                                            Status_code    => '200',
253                                                            Transmit_time  => '0.000000',
254                                                            Virtual_host   => 'www.google.com',
255                                                            arg            => 'post www.google.com/finance/qs/channel?VER=6&RID=481&CVER=1&zx=5xccsz-eg9chk&t=1',
256                                                            bytes          => 54,
257                                                            host           => '192.168.200.110',
258                                                            pos_in_log     => 0,
259                                                         }
260                                                      ],
261                                                   );
262                                                   
263                                                   # .http instead of .80
264            1                                 31   $protocol = new HTTPProtocolParser();
265            1                                 16   test_protocol_parser(
266                                                      parser   => $tcpdump,
267                                                      protocol => $protocol,
268                                                      file     => 'common/t/samples/http_tcpdump009.txt',
269                                                      result   => [
270                                                         { ts              => '2009-11-09 11:31:52.341907',
271                                                           bytes           => '715',
272                                                           host            => '10.112.2.144',
273                                                           pos_in_log      => 0,
274                                                           Virtual_host    => 'hackmysql.com',
275                                                           arg             => 'get hackmysql.com/contact',
276                                                           Status_code     => '200',
277                                                           Query_time      => '0.651419',
278                                                           Transmit_time   => '0.000000',
279                                                         },
280                                                      ],
281                                                   );
282                                                   
283                                                   # #############################################################################
284                                                   # Done.
285                                                   # #############################################################################
286            1                                  4   exit;


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
---------- ----- -----------------------
BEGIN          1 HTTPProtocolParser.t:10
BEGIN          1 HTTPProtocolParser.t:11
BEGIN          1 HTTPProtocolParser.t:12
BEGIN          1 HTTPProtocolParser.t:14
BEGIN          1 HTTPProtocolParser.t:15
BEGIN          1 HTTPProtocolParser.t:16
BEGIN          1 HTTPProtocolParser.t:17
BEGIN          1 HTTPProtocolParser.t:4 
BEGIN          1 HTTPProtocolParser.t:9 


