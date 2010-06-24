---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/MySQLProtocolParser.pm   82.8   65.3   70.8   97.3    0.0   98.7   75.7
MySQLProtocolParser.t         100.0   50.0   33.3  100.0    n/a    1.3   97.4
Total                          85.3   65.2   69.7   97.8    0.0  100.0   77.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:20 2010
Finish:       Thu Jun 24 19:35:20 2010

Run:          MySQLProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:22 2010
Finish:       Thu Jun 24 19:35:23 2010

/home/daniel/dev/maatkit/common/MySQLProtocolParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2010 Percona Inc.
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
18                                                    # MySQLProtocolParser package $Revision: 5809 $
19                                                    # ###########################################################################
20                                                    package MySQLProtocolParser;
21                                                    
22                                                    # This creates events suitable for mk-query-digest from raw MySQL packets.
23                                                    # The packets come from TcpdumpParser.  MySQLProtocolParse::parse_packet()
24                                                    # should be first in the callback chain because it creates events for
25                                                    # subsequent callbacks.  So the sequence is:
26                                                    #    1. mk-query-digest calls TcpdumpParser::parse_event($fh, ..., @callbacks)
27                                                    #    2. TcpdumpParser::parse_event() extracts raw MySQL packets from $fh and
28                                                    #       passes them to the callbacks, the first of which is
29                                                    #       MySQLProtocolParser::parse_packet().
30                                                    #    3. MySQLProtocolParser::parse_packet() makes events from the packets
31                                                    #       and returns them to TcpdumpParser::parse_event().
32                                                    #    4. TcpdumpParser::parse_event() passes the newly created events to
33                                                    #       the subsequent callbacks.
34                                                    # At times MySQLProtocolParser::parse_packet() will not return an event
35                                                    # because it usually takes a few packets to create one event.  In such
36                                                    # cases, TcpdumpParser::parse_event() will not call the other callbacks.
37                                                    
38             1                    1             4   use strict;
               1                                  2   
               1                                 12   
39             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
40             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
41                                                    
42                                                    eval {
43                                                       require IO::Uncompress::Inflate;
44                                                       IO::Uncompress::Inflate->import(qw(inflate $InflateError));
45                                                    };
46                                                    
47             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  5   
48                                                    $Data::Dumper::Indent    = 1;
49                                                    $Data::Dumper::Sortkeys  = 1;
50                                                    $Data::Dumper::Quotekeys = 0;
51                                                    
52                                                    require Exporter;
53                                                    our @ISA         = qw(Exporter);
54                                                    our %EXPORT_TAGS = ();
55                                                    our @EXPORT      = ();
56                                                    our @EXPORT_OK   = qw(
57                                                       parse_error_packet
58                                                       parse_ok_packet
59                                                       parse_ok_prepared_statement_packet
60                                                       parse_server_handshake_packet
61                                                       parse_client_handshake_packet
62                                                       parse_com_packet
63                                                       parse_flags
64                                                    );
65                                                    
66    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
67                                                    use constant {
68             1                                 35      COM_SLEEP               => '00',
69                                                       COM_QUIT                => '01',
70                                                       COM_INIT_DB             => '02',
71                                                       COM_QUERY               => '03',
72                                                       COM_FIELD_LIST          => '04',
73                                                       COM_CREATE_DB           => '05',
74                                                       COM_DROP_DB             => '06',
75                                                       COM_REFRESH             => '07',
76                                                       COM_SHUTDOWN            => '08',
77                                                       COM_STATISTICS          => '09',
78                                                       COM_PROCESS_INFO        => '0a',
79                                                       COM_CONNECT             => '0b',
80                                                       COM_PROCESS_KILL        => '0c',
81                                                       COM_DEBUG               => '0d',
82                                                       COM_PING                => '0e',
83                                                       COM_TIME                => '0f',
84                                                       COM_DELAYED_INSERT      => '10',
85                                                       COM_CHANGE_USER         => '11',
86                                                       COM_BINLOG_DUMP         => '12',
87                                                       COM_TABLE_DUMP          => '13',
88                                                       COM_CONNECT_OUT         => '14',
89                                                       COM_REGISTER_SLAVE      => '15',
90                                                       COM_STMT_PREPARE        => '16',
91                                                       COM_STMT_EXECUTE        => '17',
92                                                       COM_STMT_SEND_LONG_DATA => '18',
93                                                       COM_STMT_CLOSE          => '19',
94                                                       COM_STMT_RESET          => '1a',
95                                                       COM_SET_OPTION          => '1b',
96                                                       COM_STMT_FETCH          => '1c',
97                                                       SERVER_QUERY_NO_GOOD_INDEX_USED => 16,
98                                                       SERVER_QUERY_NO_INDEX_USED      => 32,
99             1                    1             6   };
               1                                  2   
100                                                   
101                                                   my %com_for = (
102                                                      '00' => 'COM_SLEEP',
103                                                      '01' => 'COM_QUIT',
104                                                      '02' => 'COM_INIT_DB',
105                                                      '03' => 'COM_QUERY',
106                                                      '04' => 'COM_FIELD_LIST',
107                                                      '05' => 'COM_CREATE_DB',
108                                                      '06' => 'COM_DROP_DB',
109                                                      '07' => 'COM_REFRESH',
110                                                      '08' => 'COM_SHUTDOWN',
111                                                      '09' => 'COM_STATISTICS',
112                                                      '0a' => 'COM_PROCESS_INFO',
113                                                      '0b' => 'COM_CONNECT',
114                                                      '0c' => 'COM_PROCESS_KILL',
115                                                      '0d' => 'COM_DEBUG',
116                                                      '0e' => 'COM_PING',
117                                                      '0f' => 'COM_TIME',
118                                                      '10' => 'COM_DELAYED_INSERT',
119                                                      '11' => 'COM_CHANGE_USER',
120                                                      '12' => 'COM_BINLOG_DUMP',
121                                                      '13' => 'COM_TABLE_DUMP',
122                                                      '14' => 'COM_CONNECT_OUT',
123                                                      '15' => 'COM_REGISTER_SLAVE',
124                                                      '16' => 'COM_STMT_PREPARE',
125                                                      '17' => 'COM_STMT_EXECUTE',
126                                                      '18' => 'COM_STMT_SEND_LONG_DATA',
127                                                      '19' => 'COM_STMT_CLOSE',
128                                                      '1a' => 'COM_STMT_RESET',
129                                                      '1b' => 'COM_SET_OPTION',
130                                                      '1c' => 'COM_STMT_FETCH',
131                                                   );
132                                                   
133                                                   my %flag_for = (
134                                                      'CLIENT_LONG_PASSWORD'     => 1,       # new more secure passwords 
135                                                      'CLIENT_FOUND_ROWS'        => 2,       # Found instead of affected rows 
136                                                      'CLIENT_LONG_FLAG'         => 4,       # Get all column flags 
137                                                      'CLIENT_CONNECT_WITH_DB'   => 8,       # One can specify db on connect 
138                                                      'CLIENT_NO_SCHEMA'         => 16,      # Don't allow database.table.column 
139                                                      'CLIENT_COMPRESS'          => 32,      # Can use compression protocol 
140                                                      'CLIENT_ODBC'              => 64,      # Odbc client 
141                                                      'CLIENT_LOCAL_FILES'       => 128,     # Can use LOAD DATA LOCAL 
142                                                      'CLIENT_IGNORE_SPACE'      => 256,     # Ignore spaces before '(' 
143                                                      'CLIENT_PROTOCOL_41'       => 512,     # New 4.1 protocol 
144                                                      'CLIENT_INTERACTIVE'       => 1024,    # This is an interactive client 
145                                                      'CLIENT_SSL'               => 2048,    # Switch to SSL after handshake 
146                                                      'CLIENT_IGNORE_SIGPIPE'    => 4096,    # IGNORE sigpipes 
147                                                      'CLIENT_TRANSACTIONS'      => 8192,    # Client knows about transactions 
148                                                      'CLIENT_RESERVED'          => 16384,   # Old flag for 4.1 protocol  
149                                                      'CLIENT_SECURE_CONNECTION' => 32768,   # New 4.1 authentication 
150                                                      'CLIENT_MULTI_STATEMENTS'  => 65536,   # Enable/disable multi-stmt support 
151                                                      'CLIENT_MULTI_RESULTS'     => 131072,  # Enable/disable multi-results 
152                                                   );
153                                                   
154                                                   use constant {
155            1                                 25      MYSQL_TYPE_DECIMAL      => 0,
156                                                      MYSQL_TYPE_TINY         => 1,
157                                                      MYSQL_TYPE_SHORT        => 2,
158                                                      MYSQL_TYPE_LONG         => 3,
159                                                      MYSQL_TYPE_FLOAT        => 4,
160                                                      MYSQL_TYPE_DOUBLE       => 5,
161                                                      MYSQL_TYPE_NULL         => 6,
162                                                      MYSQL_TYPE_TIMESTAMP    => 7,
163                                                      MYSQL_TYPE_LONGLONG     => 8,
164                                                      MYSQL_TYPE_INT24        => 9,
165                                                      MYSQL_TYPE_DATE         => 10,
166                                                      MYSQL_TYPE_TIME         => 11,
167                                                      MYSQL_TYPE_DATETIME     => 12,
168                                                      MYSQL_TYPE_YEAR         => 13,
169                                                      MYSQL_TYPE_NEWDATE      => 14,
170                                                      MYSQL_TYPE_VARCHAR      => 15,
171                                                      MYSQL_TYPE_BIT          => 16,
172                                                      MYSQL_TYPE_NEWDECIMAL   => 246,
173                                                      MYSQL_TYPE_ENUM         => 247,
174                                                      MYSQL_TYPE_SET          => 248,
175                                                      MYSQL_TYPE_TINY_BLOB    => 249,
176                                                      MYSQL_TYPE_MEDIUM_BLOB  => 250,
177                                                      MYSQL_TYPE_LONG_BLOB    => 251,
178                                                      MYSQL_TYPE_BLOB         => 252,
179                                                      MYSQL_TYPE_VAR_STRING   => 253,
180                                                      MYSQL_TYPE_STRING       => 254,
181                                                      MYSQL_TYPE_GEOMETRY     => 255,
182            1                    1             7   };
               1                                 76   
183                                                   
184                                                   my %type_for = (
185                                                      0   => 'MYSQL_TYPE_DECIMAL',
186                                                      1   => 'MYSQL_TYPE_TINY',
187                                                      2   => 'MYSQL_TYPE_SHORT',
188                                                      3   => 'MYSQL_TYPE_LONG',
189                                                      4   => 'MYSQL_TYPE_FLOAT',
190                                                      5   => 'MYSQL_TYPE_DOUBLE',
191                                                      6   => 'MYSQL_TYPE_NULL',
192                                                      7   => 'MYSQL_TYPE_TIMESTAMP',
193                                                      8   => 'MYSQL_TYPE_LONGLONG',
194                                                      9   => 'MYSQL_TYPE_INT24',
195                                                      10  => 'MYSQL_TYPE_DATE',
196                                                      11  => 'MYSQL_TYPE_TIME',
197                                                      12  => 'MYSQL_TYPE_DATETIME',
198                                                      13  => 'MYSQL_TYPE_YEAR',
199                                                      14  => 'MYSQL_TYPE_NEWDATE',
200                                                      15  => 'MYSQL_TYPE_VARCHAR',
201                                                      16  => 'MYSQL_TYPE_BIT',
202                                                      246 => 'MYSQL_TYPE_NEWDECIMAL',
203                                                      247 => 'MYSQL_TYPE_ENUM',
204                                                      248 => 'MYSQL_TYPE_SET',
205                                                      249 => 'MYSQL_TYPE_TINY_BLOB',
206                                                      250 => 'MYSQL_TYPE_MEDIUM_BLOB',
207                                                      251 => 'MYSQL_TYPE_LONG_BLOB',
208                                                      252 => 'MYSQL_TYPE_BLOB',
209                                                      253 => 'MYSQL_TYPE_VAR_STRING',
210                                                      254 => 'MYSQL_TYPE_STRING',
211                                                      255 => 'MYSQL_TYPE_GEOMETRY',
212                                                   );
213                                                   
214                                                   my %unpack_type = (
215                                                      MYSQL_TYPE_NULL       => sub { return 'NULL', 0; },
216                                                      MYSQL_TYPE_TINY       => sub { return to_num(@_, 1), 1; },
217                                                      MySQL_TYPE_SHORT      => sub { return to_num(@_, 2), 2; },
218                                                      MYSQL_TYPE_LONG       => sub { return to_num(@_, 4), 4; },
219                                                      MYSQL_TYPE_LONGLONG   => sub { return to_num(@_, 8), 8; },
220                                                      MYSQL_TYPE_DOUBLE     => sub { return to_double(@_), 8; },
221                                                      MYSQL_TYPE_VARCHAR    => \&unpack_string,
222                                                      MYSQL_TYPE_VAR_STRING => \&unpack_string,
223                                                      MYSQL_TYPE_STRING     => \&unpack_string,
224                                                   );
225                                                   
226                                                   # server is the "host:port" of the sever being watched.  It's auto-guessed if
227                                                   # not specified.  version is a placeholder for handling differences between
228                                                   # MySQL v4.0 and older and v4.1 and newer.  Currently, we only handle v4.1.
229                                                   sub new {
230   ***     32                   32      0    262      my ( $class, %args ) = @_;
231                                                   
232           32           100                  548      my $self = {
233                                                         server         => $args{server},
234                                                         port           => $args{port} || '3306',
235                                                         version        => '41',    # MySQL proto version; not used yet
236                                                         sessions       => {},
237                                                         o              => $args{o},
238                                                         fake_thread_id => 2**32,   # see _make_event()
239                                                      };
240           32                                109      MKDEBUG && $self->{server} && _d('Watching only server', $self->{server});
241           32                                270      return bless $self, $class;
242                                                   }
243                                                   
244                                                   # The packet arg should be a hashref from TcpdumpParser::parse_event().
245                                                   # misc is a placeholder for future features.
246                                                   sub parse_event {
247   ***    239                  239      0 170886      my ( $self, %args ) = @_;
248          239                               1148      my @required_args = qw(event);
249          239                                965      foreach my $arg ( @required_args ) {
250   ***    239     50                        1568         die "I need a $arg argument" unless $args{$arg};
251                                                      }
252          239                                969      my $packet = @args{@required_args};
253                                                   
254          239                               1327      my $src_host = "$packet->{src_host}:$packet->{src_port}";
255          239                               1240      my $dst_host = "$packet->{dst_host}:$packet->{dst_port}";
256                                                   
257          239    100                        1304      if ( my $server = $self->{server} ) {  # Watch only the given server.
258          132                                569         $server .= ":$self->{port}";
259          132    100    100                 1245         if ( $src_host ne $server && $dst_host ne $server ) {
260            3                                  7            MKDEBUG && _d('Packet is not to or from', $server);
261            3                                 15            return;
262                                                         }
263                                                      }
264                                                   
265                                                      # Auto-detect the server by looking for port 3306 or port "mysql" (sometimes
266                                                      # tcpdump will substitute the port by a lookup in /etc/protocols).
267          236                                661      my $packet_from;
268          236                                605      my $client;
269          236    100                        2398      if ( $src_host =~ m/:$self->{port}$/ ) {
      ***            50                               
270          105                                375         $packet_from = 'server';
271          105                                363         $client      = $dst_host;
272                                                      }
273                                                      elsif ( $dst_host =~ m/:$self->{port}$/ ) {
274          131                                540         $packet_from = 'client';
275          131                                448         $client      = $src_host;
276                                                      }
277                                                      else {
278   ***      0                                  0         MKDEBUG && _d('Packet is not to or from a MySQL server');
279   ***      0                                  0         return;
280                                                      }
281          236                                588      MKDEBUG && _d('Client', $client);
282                                                   
283                                                      # Get the client's session info or create a new session if
284                                                      # we catch the TCP SYN sequence or the packetno is 0.
285          236                                726      my $packetno = -1;
286          236    100                        1280      if ( $packet->{data_len} >= 5 ) {
287                                                         # 5 bytes is the minimum length of any valid MySQL packet.
288                                                         # If there's less, it's probably some TCP control packet
289                                                         # with other data.  Peek at the MySQL packet number.  The
290                                                         # only time a server sends packetno 0 is for its handshake.
291                                                         # Client packetno 0 marks start of new query.
292          136                                844         $packetno = to_num(substr($packet->{data}, 6, 2));
293                                                      }
294          236    100                        1414      if ( !exists $self->{sessions}->{$client} ) {
295           65    100                         397         if ( $packet->{syn} ) {
                    100                               
296            7                                 19            MKDEBUG && _d('New session (SYN)');
297                                                         }
298                                                         elsif ( $packetno == 0 ) {
299           32                                 86            MKDEBUG && _d('New session (packetno 0)');
300                                                         }
301                                                         else {
302           26                                 63            MKDEBUG && _d('Ignoring mid-stream', $packet_from, 'data,',
303                                                               'packetno', $packetno);
304           26                                159            return;
305                                                         }
306                                                   
307           39                                606         $self->{sessions}->{$client} = {
308                                                            client        => $client,
309                                                            ts            => $packet->{ts},
310                                                            state         => undef,
311                                                            compress      => undef,
312                                                            raw_packets   => [],
313                                                            buff          => '',
314                                                            sths          => {},
315                                                            attribs       => {},
316                                                            n_queries     => 0,
317                                                         };
318                                                      }
319          210                                936      my $session = $self->{sessions}->{$client};
320          210                                532      MKDEBUG && _d('Client state:', $session->{state});
321                                                   
322                                                      # Save raw packets to dump later in case something fails.
323          210                                600      push @{$session->{raw_packets}}, $packet->{raw_packet};
             210                               1445   
324                                                   
325                                                      # Check client port reuse.
326                                                      # http://code.google.com/p/maatkit/issues/detail?id=794
327   ***    210    100     66                 1445      if ( $packet->{syn} && ($session->{n_queries} > 0 || $session->{state}) ) {
                           100                        
328            1                                  3         MKDEBUG && _d('Client port reuse and last session did not quit');
329                                                         # Fail the session so we can see the last thing the previous
330                                                         # session was doing.
331            1                                  6         $self->fail_session($session,
332                                                               'client port reuse and last session did not quit');
333                                                         # Then recurse to create a New session.
334            1                                 29         return $self->parse_event(%args);
335                                                      }
336                                                   
337                                                      # Return early if there's no TCP/MySQL data.  These are usually
338                                                      # TCP control packets: SYN, ACK, FIN, etc.
339          209    100                        1068      if ( $packet->{data_len} == 0 ) {
340                                                         MKDEBUG && _d('TCP control:',
341           69                                184            map { uc $_ } grep { $packet->{$_} } qw(syn ack fin rst));
342           69                                448         return;
343                                                      }
344                                                   
345                                                      # Return unless the compressed packet can be uncompressed.
346                                                      # If it cannot, then we're helpless and must return.
347          140    100                         672      if ( $session->{compress} ) {
348   ***      5     50                          38         return unless $self->uncompress_packet($packet, $session);
349                                                      }
350                                                   
351          140    100    100                  863      if ( $session->{buff} && $packet_from eq 'client' ) {
352                                                         # Previous packets were not complete so append this data
353                                                         # to what we've been buffering.  Afterwards, do *not* attempt
354                                                         # to remove_mysql_header() because it was already done (from
355                                                         # the first packet).
356            7                                 45         $session->{buff}      .= $packet->{data};
357            7                                 53         $packet->{data}        = $session->{buff};
358            7                                 30         $session->{buff_left} -= $packet->{data_len};
359                                                   
360                                                         # We didn't remove_mysql_header(), so mysql_data_len isn't set.
361                                                         # So set it to the real, complete data len (from the first
362                                                         # packet's MySQL header).
363            7                                 31         $packet->{mysql_data_len} = $session->{mysql_data_len};
364            7                                 30         $packet->{number}         = $session->{number};
365                                                   
366            7                                 20         MKDEBUG && _d('Appending data to buff; expecting',
367                                                            $session->{buff_left}, 'more bytes');
368                                                      }
369                                                      else { 
370                                                         # Remove the first MySQL header.  A single TCP packet can contain many
371                                                         # MySQL packets, but we only look at the first.  The 2nd and subsequent
372                                                         # packets are usually parts of a result set returned by the server, but
373                                                         # we're not interested in result sets.
374          133                                399         eval {
375          133                                574            remove_mysql_header($packet);
376                                                         };
377   ***    133     50                         603         if ( $EVAL_ERROR ) {
378   ***      0                                  0            MKDEBUG && _d('remove_mysql_header() failed; failing session');
379   ***      0                                  0            $session->{EVAL_ERROR} = $EVAL_ERROR;
380   ***      0                                  0            $self->fail_session($session, 'remove_mysql_header() failed');
381   ***      0                                  0            return;
382                                                         }
383                                                      }
384                                                   
385                                                      # Finally, parse the packet and maybe create an event.
386                                                      # The returned event may be empty if no event was ready to be created.
387          140                                384      my $event;
388          140    100                         758      if ( $packet_from eq 'server' ) {
      ***            50                               
389           63                                360         $event = $self->_packet_from_server($packet, $session, $args{misc});
390                                                      }
391                                                      elsif ( $packet_from eq 'client' ) {
392           77    100                         597         if ( $session->{buff} ) {
                    100                               
393            7    100                          33            if ( $session->{buff_left} <= 0 ) {
394            4                                 11               MKDEBUG && _d('Data is complete');
395            4                                 23               $self->_delete_buff($session);
396                                                            }
397                                                            else {
398            3                                 19               return;  # waiting for more data; buff_left was reported earlier
399                                                            }
400                                                         }
401                                                         elsif ( $packet->{mysql_data_len} > ($packet->{data_len} - 4) ) {
402                                                   
403                                                            # http://code.google.com/p/maatkit/issues/detail?id=832
404   ***      6    100     50                   78            if ( $session->{cmd} && ($session->{state} || '') eq 'awaiting_reply' ) {
      ***                   66                        
405            1                                  3               MKDEBUG && _d('No server OK to previous command (frag)');
406            1                                  6               $self->fail_session($session, 'no server OK to previous command');
407                                                               # The MySQL header is removed by this point, so put it back.
408            1                                 50               $packet->{data} = $packet->{mysql_hdr} . $packet->{data};
409            1                                  8               return $self->parse_event(%args);
410                                                            }
411                                                   
412                                                            # There is more MySQL data than this packet contains.
413                                                            # Save the data and the original MySQL header values
414                                                            # then wait for the rest of the data.
415            5                                 94            $session->{buff}           = $packet->{data};
416            5                                 24            $session->{mysql_data_len} = $packet->{mysql_data_len};
417            5                                 24            $session->{number}         = $packet->{number};
418                                                   
419                                                            # Do this just once here.  For the next packets, buff_left
420                                                            # will be decremented above.
421   ***      5            50                   40            $session->{buff_left}
422                                                               ||= $packet->{mysql_data_len} - ($packet->{data_len} - 4);
423                                                   
424            5                                 15            MKDEBUG && _d('Data not complete; expecting',
425                                                               $session->{buff_left}, 'more bytes');
426            5                                 41            return;
427                                                         }
428                                                   
429   ***     68    100     50                  440         if ( $session->{cmd} && ($session->{state} || '') eq 'awaiting_reply' ) {
      ***                   66                        
430                                                            # Buffer handling above should ensure that by this point we have
431                                                            # the full client query.  If there's a previous client query for
432                                                            # which we're "awaiting_reply" and then we get another client
433                                                            # query, chances are we missed the server's OK response to the
434                                                            # first query.  So fail the first query and re-parse this second
435                                                            # query.
436            1                                  3            MKDEBUG && _d('No server OK to previous command');
437            1                                  6            $self->fail_session($session, 'no server OK to previous command');
438                                                            # The MySQL header is removed by this point, so put it back.
439            1                                  6            $packet->{data} = $packet->{mysql_hdr} . $packet->{data};
440            1                                 65            return $self->parse_event(%args);
441                                                         }
442                                                   
443           67                                385         $event = $self->_packet_from_client($packet, $session, $args{misc});
444                                                      }
445                                                      else {
446                                                         # Should not get here.
447   ***      0                                  0         die 'Packet origin unknown';
448                                                      }
449                                                   
450          130                                354      MKDEBUG && _d('Done parsing packet; client state:', $session->{state});
451          130    100                         662      if ( $session->{closed} ) {
452            9                                 46         delete $self->{sessions}->{$session->{client}};
453            9                                 27         MKDEBUG && _d('Session deleted');
454                                                      }
455                                                   
456          130                                925      return $event;
457                                                   }
458                                                   
459                                                   # Handles a packet from the server given the state of the session.
460                                                   # The server can send back a lot of different stuff, but luckily
461                                                   # we're only interested in
462                                                   #    * Connection handshake packets for the thread_id
463                                                   #    * OK and Error packets for errors, warnings, etc.
464                                                   # Anything else is ignored.  Returns an event if one was ready to be
465                                                   # created, otherwise returns nothing.
466                                                   sub _packet_from_server {
467           63                   63           328      my ( $self, $packet, $session, $misc ) = @_;
468   ***     63     50                         283      die "I need a packet"  unless $packet;
469   ***     63     50                         394      die "I need a session" unless $session;
470                                                   
471           63                                157      MKDEBUG && _d('Packet is from server; client state:', $session->{state}); 
472                                                   
473   ***     63     50    100                  661      if ( ($session->{server_seq} || '') eq $packet->{seq} ) {
474   ***      0                                  0         push @{ $session->{server_retransmissions} }, $packet->{seq};
      ***      0                                  0   
475   ***      0                                  0         MKDEBUG && _d('TCP retransmission');
476   ***      0                                  0         return;
477                                                      }
478           63                                298      $session->{server_seq} = $packet->{seq};
479                                                   
480           63                                261      my $data = $packet->{data};
481                                                   
482                                                      # The first byte in the packet indicates whether it's an OK,
483                                                      # ERROR, EOF packet.  If it's not one of those, we test
484                                                      # whether it's an initialization packet (the first thing the
485                                                      # server ever sends the client).  If it's not that, it could
486                                                      # be a result set header, field, row data, etc.
487                                                   
488           63                                292      my ( $first_byte ) = substr($data, 0, 2, '');
489           63                                159      MKDEBUG && _d('First byte of packet:', $first_byte);
490   ***     63     50                         265      if ( !$first_byte ) {
491   ***      0                                  0         $self->fail_session($session, 'no first byte');
492   ***      0                                  0         return;
493                                                      }
494                                                   
495                                                      # If there's no session state, then we're catching a server response
496                                                      # mid-stream.  It's only safe to wait until the client sends a command
497                                                      # or to look for the server handshake.
498           63    100                         298      if ( !$session->{state} ) {
499   ***     10    100     66                  219         if ( $first_byte eq '0a' && length $data >= 33 && $data =~ m/00{13}/ ) {
      ***            50     66                        
500                                                            # It's the handshake packet from the server to the client.
501                                                            # 0a is protocol v10 which is essentially the only version used
502                                                            # today.  33 is the minimum possible length for a valid server
503                                                            # handshake packet.  It's probably a lot longer.  Other packets
504                                                            # may start with 0a, but none that can would be >= 33.  The 13-byte
505                                                            # 00 scramble buffer is another indicator.
506            9                                 48            my $handshake = parse_server_handshake_packet($data);
507   ***      9     50                          51            if ( !$handshake ) {
508   ***      0                                  0               $self->fail_session($session, 'failed to parse server handshake');
509   ***      0                                  0               return;
510                                                            }
511            9                                 47            $session->{state}     = 'server_handshake';
512            9                                 46            $session->{thread_id} = $handshake->{thread_id};
513                                                   
514                                                            # See http://code.google.com/p/maatkit/issues/detail?id=794
515   ***      9     50                          87            $session->{ts} = $packet->{ts} unless $session->{ts};
516                                                         }
517                                                         elsif ( $session->{buff} ) {
518            1                                  7            $self->fail_session($session,
519                                                               'got server response before full buffer');
520            1                                  5            return;
521                                                         }
522                                                         else {
523   ***      0                                  0            MKDEBUG && _d('Ignoring mid-stream server response');
524   ***      0                                  0            return;
525                                                         }
526                                                      }
527                                                      else {
528   ***     53    100     66                  378         if ( $first_byte eq '00' ) { 
                    100                               
                    100                               
529   ***     26    100     50                  206            if ( ($session->{state} || '') eq 'client_auth' ) {
      ***            50                               
530                                                               # We logged in OK!  Trigger an admin Connect command.
531                                                   
532            8                                 44               $session->{compress} = $session->{will_compress};
533            8                                 36               delete $session->{will_compress};
534            8                                 28               MKDEBUG && $session->{compress} && _d('Packets will be compressed');
535                                                   
536            8                                 24               MKDEBUG && _d('Admin command: Connect');
537            8                                 84               return $self->_make_event(
538                                                                  {  cmd => 'Admin',
539                                                                     arg => 'administrator command: Connect',
540                                                                     ts  => $packet->{ts}, # Events are timestamped when they end
541                                                                  },
542                                                                  $packet, $session
543                                                               );
544                                                            }
545                                                            elsif ( $session->{cmd} ) {
546                                                               # This OK should be ack'ing a query or something sent earlier
547                                                               # by the client.  OK for prepared statement are special.
548           18                                 88               my $com = $session->{cmd}->{cmd};
549           18                                 48               my $ok;
550           18    100                          79               if ( $com eq COM_STMT_PREPARE ) {
551            9                                 24                  MKDEBUG && _d('OK for prepared statement');
552            9                                 47                  $ok = parse_ok_prepared_statement_packet($data);
553   ***      9     50                          37                  if ( !$ok ) {
554   ***      0                                  0                     $self->fail_session($session,
555                                                                        'failed to parse OK prepared statement packet');
556   ***      0                                  0                     return;
557                                                                  }
558            9                                 34                  my $sth_id = $ok->{sth_id};
559            9                                 42                  $session->{attribs}->{Statement_id} = $sth_id;
560                                                   
561                                                                  # Save all sth info, used in parse_execute_packet().
562            9                                 44                  $session->{sths}->{$sth_id} = $ok;
563            9                                 61                  $session->{sths}->{$sth_id}->{statement}
564                                                                     = $session->{cmd}->{arg};
565                                                               }
566                                                               else {
567            9                                 44                  $ok  = parse_ok_packet($data);
568   ***      9     50                          46                  if ( !$ok ) {
569   ***      0                                  0                     $self->fail_session($session, 'failed to parse OK packet');
570   ***      0                                  0                     return;
571                                                                  }
572                                                               }
573                                                   
574           18                                 53               my $arg;
575           18    100    100                  220               if ( $com eq COM_QUERY
      ***            50    100                        
576                                                                    || $com eq COM_STMT_EXECUTE || $com eq COM_STMT_RESET ) {
577            9                                 28                  $com = 'Query';
578            9                                 60                  $arg = $session->{cmd}->{arg};
579                                                               }
580                                                               elsif ( $com eq COM_STMT_PREPARE ) {
581            9                                 32                  $com = 'Query';
582            9                                 42                  $arg = "PREPARE $session->{cmd}->{arg}";
583                                                               }
584                                                               else {
585   ***      0                                  0                  $arg = 'administrator command: '
586                                                                       . ucfirst(lc(substr($com_for{$com}, 4)));
587   ***      0                                  0                  $com = 'Admin';
588                                                               }
589                                                   
590           18                                245               return $self->_make_event(
591                                                                  {  cmd           => $com,
592                                                                     arg           => $arg,
593                                                                     ts            => $packet->{ts},
594                                                                     Insert_id     => $ok->{insert_id},
595                                                                     Warning_count => $ok->{warnings},
596                                                                     Rows_affected => $ok->{affected_rows},
597                                                                  },
598                                                                  $packet, $session
599                                                               );
600                                                            } 
601                                                            else {
602   ***      0                                  0               MKDEBUG && _d('Looks like an OK packet but session has no cmd');
603                                                            }
604                                                         }
605                                                         elsif ( $first_byte eq 'ff' ) {
606            2                                 14            my $error = parse_error_packet($data);
607   ***      2     50                           9            if ( !$error ) {
608   ***      0                                  0               $self->fail_session($session, 'failed to parse error packet');
609   ***      0                                  0               return;
610                                                            }
611            2                                  6            my $event;
612                                                   
613            2    100                          14            if ( $session->{state} eq 'client_auth' ) {
      ***            50                               
614            1                                  6               MKDEBUG && _d('Connection failed');
615            1                                  8               $event = {
616                                                                  cmd       => 'Admin',
617                                                                  arg       => 'administrator command: Connect',
618                                                                  ts        => $packet->{ts},
619                                                                  Error_no  => $error->{errno},
620                                                               };
621            1                                  4               $session->{closed} = 1;  # delete session when done
622            1                                  5               return $self->_make_event($event, $packet, $session);
623                                                            }
624                                                            elsif ( $session->{cmd} ) {
625                                                               # This error should be in response to a query or something
626                                                               # sent earlier by the client.
627            1                                  4               my $com = $session->{cmd}->{cmd};
628            1                                  2               my $arg;
629                                                   
630   ***      1     50     33                    6               if ( $com eq COM_QUERY || $com eq COM_STMT_EXECUTE ) {
631            1                                  3                  $com = 'Query';
632            1                                  4                  $arg = $session->{cmd}->{arg};
633                                                               }
634                                                               else {
635   ***      0                                  0                  $arg = 'administrator command: '
636                                                                       . ucfirst(lc(substr($com_for{$com}, 4)));
637   ***      0                                  0                  $com = 'Admin';
638                                                               }
639                                                   
640   ***      1     50                          11               $event = {
641                                                                  cmd       => $com,
642                                                                  arg       => $arg,
643                                                                  ts        => $packet->{ts},
644                                                                  Error_no  => $error->{errno} ? "#$error->{errno}" : 'none',
645                                                               };
646            1                                  6               return $self->_make_event($event, $packet, $session);
647                                                            }
648                                                            else {
649   ***      0                                  0               MKDEBUG && _d('Looks like an error packet but client is not '
650                                                                  . 'authenticating and session has no cmd');
651                                                            }
652                                                         }
653                                                         elsif ( $first_byte eq 'fe' && $packet->{mysql_data_len} < 9 ) {
654                                                            # EOF packet
655   ***      1     50     33                   50            if ( $packet->{mysql_data_len} == 1
      ***                   33                        
656                                                                 && $session->{state} eq 'client_auth'
657                                                                 && $packet->{number} == 2 )
658                                                            {
659            1                                  5               MKDEBUG && _d('Server has old password table;',
660                                                                  'client will resend password using old algorithm');
661            1                                  7               $session->{state} = 'client_auth_resend';
662                                                            }
663                                                            else {
664   ***      0                                  0               MKDEBUG && _d('Got an EOF packet');
665   ***      0                                  0               $self->fail_session($session, 'got an unexpected EOF packet');
666                                                               # ^^^ We shouldn't reach this because EOF should come after a
667                                                               # header, field, or row data packet; and we should be firing the
668                                                               # event and returning when we see that.  See SVN history for some
669                                                               # good stuff we could do if we wanted to handle EOF packets.
670                                                            }
671                                                         }
672                                                         else {
673                                                            # Since we do NOT always have all the data the server sent to the
674                                                            # client, we can't always do any processing of results.  So when
675                                                            # we get one of these, we just fire the event even if the query
676                                                            # is not done.  This means we will NOT process EOF packets
677                                                            # themselves (see above).
678   ***     24     50                         126            if ( $session->{cmd} ) {
679           24                                 59               MKDEBUG && _d('Got a row/field/result packet');
680           24                                112               my $com = $session->{cmd}->{cmd};
681           24                                 80               MKDEBUG && _d('Responding to client', $com_for{$com});
682           24                                124               my $event = { ts  => $packet->{ts} };
683   ***     24     50     66                  194               if ( $com eq COM_QUERY || $com eq COM_STMT_EXECUTE ) {
684           24                                 98                  $event->{cmd} = 'Query';
685           24                                133                  $event->{arg} = $session->{cmd}->{arg};
686                                                               }
687                                                               else {
688   ***      0                                  0                  $event->{arg} = 'administrator command: '
689                                                                       . ucfirst(lc(substr($com_for{$com}, 4)));
690   ***      0                                  0                  $event->{cmd} = 'Admin';
691                                                               }
692                                                   
693                                                               # We DID get all the data in the packet.
694   ***     24     50                         126               if ( $packet->{complete} ) {
695                                                                  # Look to see if the end of the data appears to be an EOF
696                                                                  # packet.
697           24                                299                  my ( $warning_count, $status_flags )
698                                                                     = $data =~ m/fe(.{4})(.{4})\Z/;
699           24    100                         123                  if ( $warning_count ) { 
700           23                                 84                     $event->{Warnings} = to_num($warning_count);
701           23                                 88                     my $flags = to_num($status_flags); # TODO set all flags?
702   ***     23     50                         129                     $event->{No_good_index_used}
703                                                                        = $flags & SERVER_QUERY_NO_GOOD_INDEX_USED ? 1 : 0;
704           23    100                         128                     $event->{No_index_used}
705                                                                        = $flags & SERVER_QUERY_NO_INDEX_USED ? 1 : 0;
706                                                                  }
707                                                               }
708                                                   
709           24                                124               return $self->_make_event($event, $packet, $session);
710                                                            }
711                                                            else {
712   ***      0                                  0               MKDEBUG && _d('Unknown in-stream server response');
713                                                            }
714                                                         }
715                                                      }
716                                                   
717           10                                 51      return;
718                                                   }
719                                                   
720                                                   # Handles a packet from the client given the state of the session.
721                                                   # The client doesn't send a wide and exotic array of packets like
722                                                   # the server.  Even so, we're only interested in:
723                                                   #    * Users and dbs from connection handshake packets
724                                                   #    * SQL statements from COM_QUERY commands
725                                                   # Anything else is ignored.  Returns an event if one was ready to be
726                                                   # created, otherwise returns nothing.
727                                                   sub _packet_from_client {
728           67                   67           339      my ( $self, $packet, $session, $misc ) = @_;
729   ***     67     50                         295      die "I need a packet"  unless $packet;
730   ***     67     50                         284      die "I need a session" unless $session;
731                                                   
732           67                                163      MKDEBUG && _d('Packet is from client; state:', $session->{state}); 
733                                                   
734           67    100    100                  698      if ( ($session->{client_seq} || '') eq $packet->{seq} ) {
735            1                                  3         push @{ $session->{client_retransmissions} }, $packet->{seq};
               1                                  6   
736            1                                  3         MKDEBUG && _d('TCP retransmission');
737            1                                  4         return;
738                                                      }
739           66                                339      $session->{client_seq} = $packet->{seq};
740                                                   
741           66                                288      my $data  = $packet->{data};
742           66                                258      my $ts    = $packet->{ts};
743                                                   
744           66    100    100                 1299      if ( ($session->{state} || '') eq 'server_handshake' ) {
                    100    100                        
      ***            50     50                        
745            9                                 26         MKDEBUG && _d('Expecting client authentication packet');
746                                                         # The connection is a 3-way handshake:
747                                                         #    server > client  (protocol version, thread id, etc.)
748                                                         #    client > server  (user, pass, default db, etc.)
749                                                         #    server > client  OK if login succeeds
750                                                         # pos_in_log refers to 2nd handshake from the client.
751                                                         # A connection is logged even if the client fails to
752                                                         # login (bad password, etc.).
753            9                                 40         my $handshake = parse_client_handshake_packet($data);
754   ***      9     50                          55         if ( !$handshake ) {
755   ***      0                                  0            $self->fail_session($session, 'failed to parse client handshake');
756   ***      0                                  0            return;
757                                                         }
758            9                                 41         $session->{state}         = 'client_auth';
759            9                                 49         $session->{pos_in_log}    = $packet->{pos_in_log};
760            9                                 49         $session->{user}          = $handshake->{user};
761            9                                 40         $session->{db}            = $handshake->{db};
762                                                   
763                                                         # $session->{will_compress} will become $session->{compress} when
764                                                         # the server's final handshake packet is received.  This prevents
765                                                         # parse_packet() from trying to decompress that final packet.
766                                                         # Compressed packets can only begin after the full handshake is done.
767            9                                 95         $session->{will_compress} = $handshake->{flags}->{CLIENT_COMPRESS};
768                                                      }
769                                                      elsif ( ($session->{state} || '') eq 'client_auth_resend' ) {
770                                                         # Don't know how to parse this packet.
771            1                                  4         MKDEBUG && _d('Client resending password using old algorithm');
772            1                                  5         $session->{state} = 'client_auth';
773                                                      }
774                                                      elsif ( ($session->{state} || '') eq 'awaiting_reply' ) {
775   ***      0      0                           0         my $arg = $session->{cmd}->{arg} ? substr($session->{cmd}->{arg}, 0, 50)
776                                                                 : 'unknown';
777   ***      0                                  0         MKDEBUG && _d('More data for previous command:', $arg, '...'); 
778   ***      0                                  0         return;
779                                                      }
780                                                      else {
781                                                         # Otherwise, it should be a query if its the first packet (number 0).
782                                                         # We ignore the commands that take arguments (COM_CHANGE_USER,
783                                                         # COM_PROCESS_KILL).
784   ***     56     50                         298         if ( $packet->{number} != 0 ) {
785   ***      0                                  0            $self->fail_session($session, 'client cmd not packet 0');
786   ***      0                                  0            return;
787                                                         }
788                                                   
789                                                         # Detect compression in-stream only if $session->{compress} is
790                                                         # not defined.  This means we didn't see the client handshake.
791                                                         # If we had seen it, $session->{compress} would be defined as 0 or 1.
792           56    100                         271         if ( !defined $session->{compress} ) {
793   ***     29     50                         157            return unless $self->detect_compression($packet, $session);
794           29                                130            $data = $packet->{data};
795                                                         }
796                                                   
797           56                                264         my $com = parse_com_packet($data, $packet->{mysql_data_len});
798   ***     56     50                         286         if ( !$com ) {
799   ***      0                                  0            $self->fail_session($session, 'failed to parse COM packet');
800   ***      0                                  0            return;
801                                                         }
802                                                   
803           56    100                         414         if ( $com->{code} eq COM_STMT_EXECUTE ) {
                    100                               
804           11                                 33            MKDEBUG && _d('Execute prepared statement');
805           11                                 69            my $exec = parse_execute_packet($com->{data}, $session->{sths});
806   ***     11     50                          45            if ( !$exec ) {
807                                                               # This does not signal a failure, it could just be that
808                                                               # the statement handle ID is unknown.
809   ***      0                                  0               MKDEBUG && _d('Failed to parse execute packet');
810   ***      0                                  0               $session->{state} = undef;
811   ***      0                                  0               return;
812                                                            }
813           11                                 53            $com->{data} = $exec->{arg};
814           11                                534            $session->{attribs}->{Statement_id} = $exec->{sth_id};
815                                                         }
816                                                         elsif ( $com->{code} eq COM_STMT_RESET ) {
817            1                                  5            my $sth_id = get_sth_id($com->{data});
818   ***      1     50                           5            if ( !$sth_id ) {
819   ***      0                                  0               $self->fail_session($session,
820                                                                  'failed to parse prepared statement reset packet');
821   ***      0                                  0               return;
822                                                            }
823            1                                  6            $com->{data} = "RESET $sth_id";
824            1                                  5            $session->{attribs}->{Statement_id} = $sth_id;
825                                                         }
826                                                   
827           56                                230         $session->{state}      = 'awaiting_reply';
828           56                                239         $session->{pos_in_log} = $packet->{pos_in_log};
829           56                                228         $session->{ts}         = $ts;
830           56                                395         $session->{cmd}        = {
831                                                            cmd => $com->{code},
832                                                            arg => $com->{data},
833                                                         };
834                                                   
835           56    100                         452         if ( $com->{code} eq COM_QUIT ) { # Fire right away; will cleanup later.
                    100                               
836            8                                 21            MKDEBUG && _d('Got a COM_QUIT');
837                                                   
838                                                            # See http://code.google.com/p/maatkit/issues/detail?id=794
839            8                                 37            $session->{closed} = 1;  # delete session when done
840                                                   
841            8                                 63            return $self->_make_event(
842                                                               {  cmd       => 'Admin',
843                                                                  arg       => 'administrator command: Quit',
844                                                                  ts        => $ts,
845                                                               },
846                                                               $packet, $session
847                                                            );
848                                                         }
849                                                         elsif ( $com->{code} eq COM_STMT_CLOSE ) {
850                                                            # Apparently, these are not acknowledged by the server.
851            2                                 14            my $sth_id = get_sth_id($com->{data});
852   ***      2     50                           8            if ( !$sth_id ) {
853   ***      0                                  0               $self->fail_session($session,
854                                                                  'failed to parse prepared statement close packet');
855   ***      0                                  0               return;
856                                                            }
857            2                                 11            delete $session->{sths}->{$sth_id};
858            2                                 16            return $self->_make_event(
859                                                               {  cmd       => 'Query',
860                                                                  arg       => "DEALLOCATE PREPARE $sth_id",
861                                                                  ts        => $ts,
862                                                               },
863                                                               $packet, $session
864                                                            );
865                                                         }
866                                                      }
867                                                   
868           56                                229      return;
869                                                   }
870                                                   
871                                                   # Make and return an event from the given packet and session.
872                                                   sub _make_event {
873           62                   62           313      my ( $self, $event, $packet, $session ) = @_;
874           62                                181      MKDEBUG && _d('Making event');
875                                                   
876                                                      # Clear packets that preceded this event.
877           62                                257      $session->{raw_packets}  = [];
878           62                                431      $self->_delete_buff($session);
879                                                   
880           62    100                         329      if ( !$session->{thread_id} ) {
881                                                         # Only the server handshake packet gives the thread id, so for
882                                                         # sessions caught mid-stream we assign a fake thread id.
883           27                                 63         MKDEBUG && _d('Giving session fake thread id', $self->{fake_thread_id});
884           27                                186         $session->{thread_id} = $self->{fake_thread_id}++;
885                                                      }
886                                                   
887           62                                639      my ($host, $port) = $session->{client} =~ m/((?:\d+\.){3}\d+)\:(\w+)/;
888   ***     62     50    100                  539      my $new_event = {
                    100    100                        
                           100                        
889                                                         cmd        => $event->{cmd},
890                                                         arg        => $event->{arg},
891                                                         bytes      => length( $event->{arg} ),
892                                                         ts         => tcp_timestamp( $event->{ts} ),
893                                                         host       => $host,
894                                                         ip         => $host,
895                                                         port       => $port,
896                                                         db         => $session->{db},
897                                                         user       => $session->{user},
898                                                         Thread_id  => $session->{thread_id},
899                                                         pos_in_log => $session->{pos_in_log},
900                                                         Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
901                                                         Error_no   => $event->{Error_no} || 'none',
902                                                         Rows_affected      => ($event->{Rows_affected} || 0),
903                                                         Warning_count      => ($event->{Warning_count} || 0),
904                                                         No_good_index_used => ($event->{No_good_index_used} ? 'Yes' : 'No'),
905                                                         No_index_used      => ($event->{No_index_used}      ? 'Yes' : 'No'),
906                                                      };
907           62                                237      @{$new_event}{keys %{$session->{attribs}}} = values %{$session->{attribs}};
              62                                227   
              62                                254   
              62                                340   
908           62                                168      MKDEBUG && _d('Properties of event:', Dumper($new_event));
909                                                   
910                                                      # Delete cmd to prevent re-making the same event if the
911                                                      # server sends extra stuff that looks like a result set, etc.
912           62                                265      delete $session->{cmd};
913                                                   
914                                                      # Undef the session state so that we ignore everything from
915                                                      # the server and wait until the client says something again.
916           62                                221      $session->{state} = undef;
917                                                   
918                                                      # Clear the attribs for this event.
919           62                                264      $session->{attribs} = {};
920                                                   
921           62                                248      $session->{n_queries}++;
922           62                                278      $session->{server_retransmissions} = [];
923           62                                262      $session->{client_retransmissions} = [];
924                                                   
925           62                                422      return $new_event;
926                                                   }
927                                                   
928                                                   # Extracts a slow-log-formatted timestamp from the tcpdump timestamp format.
929                                                   sub tcp_timestamp {
930   ***     62                   62      0    297      my ( $ts ) = @_;
931           62                                713      $ts =~ s/^\d\d(\d\d)-(\d\d)-(\d\d)/$1$2$3/;
932           62                               1142      return $ts;
933                                                   }
934                                                   
935                                                   # Returns the difference between two tcpdump timestamps.
936                                                   sub timestamp_diff {
937   ***     62                   62      0    292      my ( $start, $end ) = @_;
938           62                                278      my $sd = substr($start, 0, 11, '');
939           62                                225      my $ed = substr($end,   0, 11, '');
940           62                                410      my ( $sh, $sm, $ss ) = split(/:/, $start);
941           62                                317      my ( $eh, $em, $es ) = split(/:/, $end);
942           62                                445      my $esecs = ($eh * 3600 + $em * 60 + $es);
943           62                                292      my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
944   ***     62     50                         262      if ( $sd eq $ed ) {
945           62                               2995         return sprintf '%.6f', $esecs - $ssecs;
946                                                      }
947                                                      else { # Assume only one day boundary has been crossed, no DST, etc
948   ***      0                                  0         return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
949                                                      }
950                                                   }
951                                                   
952                                                   # Converts hexadecimal to string.
953                                                   sub to_string {
954   ***    116                  116      0    648      my ( $data ) = @_;
955          116                               1940      return pack('H*', $data);
956                                                   }
957                                                   
958                                                   sub unpack_string {
959   ***     13                   13      0     53      my ( $data ) = @_;
960           13                                 40      my $len        = 0;
961           13                                 34      my $encode_len = 0;
962           13                                 51      ($data, $len, $encode_len) = decode_len($data);
963   ***     13     50                          69      my $t = 'H' . ($len ? $len * 2 : '*');
964           13                                 56      $data = pack($t, $data);
965           13                                 76      return "\"$data\"", $encode_len + $len;
966                                                   }
967                                                   
968                                                   sub decode_len {
969   ***     13                   13      0     52      my ( $data ) = @_;
970   ***     13     50                          51      return unless $data;
971                                                   
972                                                      # first byte hex   len
973                                                      # ========== ====  =============
974                                                      # 0-251      0-FB  Same
975                                                      # 252        FC    Len in next 2
976                                                      # 253        FD    Len in next 4
977                                                      # 254        FE    Len in next 8
978           13                                 62      my $first_byte = to_num(substr($data, 0, 2, ''));
979                                                   
980           13                                 32      my $len;
981           13                                 33      my $encode_len;
982   ***     13     50                          53      if ( $first_byte <= 251 ) {
      ***             0                               
      ***             0                               
      ***             0                               
983           13                                 32         $len        = $first_byte;
984           13                                 40         $encode_len = 1;
985                                                      }
986                                                      elsif ( $first_byte == 252 ) {
987   ***      0                                  0         $len        = to_num(substr($data, 4, ''));
988   ***      0                                  0         $encode_len = 2;
989                                                      }
990                                                      elsif ( $first_byte == 253 ) {
991   ***      0                                  0         $len        = to_num(substr($data, 6, ''));
992   ***      0                                  0         $encode_len = 3;
993                                                      }
994                                                      elsif ( $first_byte == 254 ) {
995   ***      0                                  0         $len        = to_num(substr($data, 16, ''));
996   ***      0                                  0         $encode_len = 8;
997                                                      }
998                                                      else {
999                                                         # This shouldn't happen, but it may if we're passed data
1000                                                        # that isn't length encoded.
1001  ***      0                                  0         MKDEBUG && _d('data:', $data, 'first byte:', $first_byte);
1002  ***      0                                  0         die "Invalid length encoded byte: $first_byte";
1003                                                     }
1004                                                  
1005          13                                 31      MKDEBUG && _d('len:', $len, 'encode len', $encode_len);
1006          13                                 64      return $data, $len, $encode_len;
1007                                                  }
1008                                                  
1009                                                  # All numbers are stored with the least significant byte first in the MySQL
1010                                                  # protocol.
1011                                                  sub to_num {
1012  ***    629                  629      0   2878      my ( $str, $len ) = @_;
1013         629    100                        2673      if ( $len ) {
1014           4                                 16         $str = substr($str, 0, $len * 2);
1015                                                     }
1016         629                               4376      my @bytes = $str =~ m/(..)/g;
1017         629                               2231      my $result = 0;
1018         629                               3471      foreach my $i ( 0 .. $#bytes ) {
1019        1184                               7052         $result += hex($bytes[$i]) * (16 ** ($i * 2));
1020                                                     }
1021         629                               2972      return $result;
1022                                                  }
1023                                                  
1024                                                  sub to_double {
1025  ***      4                    4      0     16      my ( $str ) = @_;
1026           4                                 38      return unpack('d', pack('H*', $str));
1027                                                  }
1028                                                  
1029                                                  # Accepts a reference to a string, which it will modify.  Extracts a
1030                                                  # length-coded binary off the front of the string and returns that value as an
1031                                                  # integer.
1032                                                  sub get_lcb {
1033  ***     20                   20      0     77      my ( $string ) = @_;
1034          20                                 99      my $first_byte = hex(substr($$string, 0, 2, ''));
1035  ***     20     50                          78      if ( $first_byte < 251 ) {
      ***             0                               
      ***             0                               
      ***             0                               
1036          20                                 78         return $first_byte;
1037                                                     }
1038                                                     elsif ( $first_byte == 252 ) {
1039  ***      0                                  0         return to_num(substr($$string, 0, 4, ''));
1040                                                     }
1041                                                     elsif ( $first_byte == 253 ) {
1042  ***      0                                  0         return to_num(substr($$string, 0, 6, ''));
1043                                                     }
1044                                                     elsif ( $first_byte == 254 ) {
1045  ***      0                                  0         return to_num(substr($$string, 0, 16, ''));
1046                                                     }
1047                                                  }
1048                                                  
1049                                                  # Error packet structure:
1050                                                  # Offset  Bytes               Field
1051                                                  # ======  =================   ====================================
1052                                                  #         00 00 00 01         MySQL proto header (already removed)
1053                                                  #         ff                  Error  (already removed)
1054                                                  # 0       00 00               Error number
1055                                                  # 4       23                  SQL state marker, always '#'
1056                                                  # 6       00 00 00 00 00      SQL state
1057                                                  # 16      00 ...              Error message
1058                                                  # The sqlstate marker and actual sqlstate are combined into one value. 
1059                                                  sub parse_error_packet {
1060  ***      3                    3      0     42      my ( $data ) = @_;
1061  ***      3     50                          18      return unless $data;
1062           3                                  8      MKDEBUG && _d('ERROR data:', $data);
1063  ***      3     50                          18      if ( length $data < 16 ) {
1064  ***      0                                  0         MKDEBUG && _d('Error packet is too short:', $data);
1065  ***      0                                  0         return;
1066                                                     }
1067           3                                 19      my $errno    = to_num(substr($data, 0, 4));
1068           3                                 18      my $marker   = to_string(substr($data, 4, 2));
1069  ***      3     50                          19      return unless $marker eq '#';
1070           3                                 15      my $sqlstate = to_string(substr($data, 6, 10));
1071           3                                 18      my $message  = to_string(substr($data, 16));
1072           3                                 27      my $pkt = {
1073                                                        errno    => $errno,
1074                                                        sqlstate => $marker . $sqlstate,
1075                                                        message  => $message,
1076                                                     };
1077           3                                  9      MKDEBUG && _d('Error packet:', Dumper($pkt));
1078           3                                 28      return $pkt;
1079                                                  }
1080                                                  
1081                                                  # OK packet structure:
1082                                                  # Bytes         Field
1083                                                  # ===========   ====================================
1084                                                  # 00 00 00 01   MySQL proto header (already removed)
1085                                                  # 00            OK/Field count (already removed)
1086                                                  # 1-9           Affected rows (LCB)
1087                                                  # 1-9           Insert ID (LCB)
1088                                                  # 00 00         Server status
1089                                                  # 00 00         Warning count
1090                                                  # 00 ...        Message (optional)
1091                                                  sub parse_ok_packet {
1092  ***     10                   10      0     50      my ( $data ) = @_;
1093  ***     10     50                          51      return unless $data;
1094          10                                 26      MKDEBUG && _d('OK data:', $data);
1095  ***     10     50                          56      if ( length $data < 12 ) {
1096  ***      0                                  0         MKDEBUG && _d('OK packet is too short:', $data);
1097  ***      0                                  0         return;
1098                                                     }
1099          10                                 52      my $affected_rows = get_lcb(\$data);
1100          10                                 43      my $insert_id     = get_lcb(\$data);
1101          10                                 57      my $status        = to_num(substr($data, 0, 4, ''));
1102          10                                 58      my $warnings      = to_num(substr($data, 0, 4, ''));
1103          10                                 44      my $message       = to_string($data);
1104                                                     # Note: $message is discarded.  It might be something like
1105                                                     # Records: 2  Duplicates: 0  Warnings: 0
1106          10                                 96      my $pkt = {
1107                                                        affected_rows => $affected_rows,
1108                                                        insert_id     => $insert_id,
1109                                                        status        => $status,
1110                                                        warnings      => $warnings,
1111                                                        message       => $message,
1112                                                     };
1113          10                                 29      MKDEBUG && _d('OK packet:', Dumper($pkt));
1114          10                                 51      return $pkt;
1115                                                  }
1116                                                  
1117                                                  # OK prepared statement packet structure:
1118                                                  # Bytes         Field
1119                                                  # ===========   ====================================
1120                                                  # 00            OK  (already removed)
1121                                                  # 00 00 00 00   Statement handler ID
1122                                                  # 00 00         Number of columns in result set
1123                                                  # 00 00         Number of parameters (?) in query
1124                                                  sub parse_ok_prepared_statement_packet {
1125  ***      9                    9      0     46      my ( $data ) = @_;
1126  ***      9     50                          42      return unless $data;
1127           9                                 23      MKDEBUG && _d('OK prepared statement data:', $data);
1128  ***      9     50                          47      if ( length $data < 8 ) {
1129  ***      0                                  0         MKDEBUG && _d('OK prepared statement packet is too short:', $data);
1130  ***      0                                  0         return;
1131                                                     }
1132           9                                 45      my $sth_id     = to_num(substr($data, 0, 8, ''));
1133           9                                 46      my $num_cols   = to_num(substr($data, 0, 4, ''));
1134           9                                 43      my $num_params = to_num(substr($data, 0, 4, ''));
1135           9                                 54      my $pkt = {
1136                                                        sth_id     => $sth_id,
1137                                                        num_cols   => $num_cols,
1138                                                        num_params => $num_params,
1139                                                     };
1140           9                                 20      MKDEBUG && _d('OK prepared packet:', Dumper($pkt));
1141           9                                 38      return $pkt;
1142                                                  }
1143                                                  
1144                                                  # Currently we only capture and return the thread id.
1145                                                  sub parse_server_handshake_packet {
1146  ***     10                   10      0     82      my ( $data ) = @_;
1147  ***     10     50                          58      return unless $data;
1148          10                                 27      MKDEBUG && _d('Server handshake data:', $data);
1149          10                                 74      my $handshake_pattern = qr{
1150                                                                          # Bytes                Name
1151                                                        ^                 # -----                ----
1152                                                        (.+?)00           # n Null-Term String   server_version
1153                                                        (.{8})            # 4                    thread_id
1154                                                        .{16}             # 8                    scramble_buff
1155                                                        .{2}              # 1                    filler: always 0x00
1156                                                        (.{4})            # 2                    server_capabilities
1157                                                        .{2}              # 1                    server_language
1158                                                        .{4}              # 2                    server_status
1159                                                        .{26}             # 13                   filler: always 0x00
1160                                                                          # 13                   rest of scramble_buff
1161                                                     }x;
1162          10                                169      my ( $server_version, $thread_id, $flags ) = $data =~ m/$handshake_pattern/;
1163          10                                 67      my $pkt = {
1164                                                        server_version => to_string($server_version),
1165                                                        thread_id      => to_num($thread_id),
1166                                                        flags          => parse_flags($flags),
1167                                                     };
1168          10                                 34      MKDEBUG && _d('Server handshake packet:', Dumper($pkt));
1169          10                                120      return $pkt;
1170                                                  }
1171                                                  
1172                                                  # Currently we only capture and return the user and default database.
1173                                                  sub parse_client_handshake_packet {
1174  ***     10                   10      0     73      my ( $data ) = @_;
1175  ***     10     50                          53      return unless $data;
1176          10                                 31      MKDEBUG && _d('Client handshake data:', $data);
1177          10                                154      my ( $flags, $user, $buff_len ) = $data =~ m{
1178                                                        ^
1179                                                        (.{8})         # Client flags
1180                                                        .{10}          # Max packet size, charset
1181                                                        (?:00){23}     # Filler
1182                                                        ((?:..)+?)00   # Null-terminated user name
1183                                                        (..)           # Length-coding byte for scramble buff
1184                                                     }x;
1185                                                  
1186                                                     # This packet is easy to detect because it's the only case where
1187                                                     # the server sends the client a packet first (its handshake) and
1188                                                     # then the client only and ever sends back its handshake.
1189  ***     10     50                          57      if ( !$buff_len ) {
1190  ***      0                                  0         MKDEBUG && _d('Did not match client handshake packet');
1191  ***      0                                  0         return;
1192                                                     }
1193                                                  
1194                                                     # This length-coded binary doesn't seem to be a normal one, it
1195                                                     # seems more like a length-coded string actually.
1196          10                                 42      my $code_len = hex($buff_len);
1197          10                                298      my ( $db ) = $data =~ m!
1198                                                        ^.{64}${user}00..   # Everything matched before
1199                                                        (?:..){$code_len}   # The scramble buffer
1200                                                        (.*)00\Z            # The database name
1201                                                     !x;
1202          10    100                          54      my $pkt = {
1203                                                        user  => to_string($user),
1204                                                        db    => $db ? to_string($db) : '',
1205                                                        flags => parse_flags($flags),
1206                                                     };
1207          10                                 33      MKDEBUG && _d('Client handshake packet:', Dumper($pkt));
1208          10                                 73      return $pkt;
1209                                                  }
1210                                                  
1211                                                  # COM data is not 00-terminated, but the the MySQL client appends \0,
1212                                                  # so we have to use the packet length to know where the data ends.
1213                                                  sub parse_com_packet {
1214  ***     86                   86      0    633      my ( $data, $len ) = @_;
1215  ***     86     50     33                  772      return unless $data && $len;
1216          86                                203      MKDEBUG && _d('COM data:',
1217                                                        (substr($data, 0, 100).(length $data > 100 ? '...' : '')),
1218                                                        'len:', $len);
1219          86                                317      my $code = substr($data, 0, 2);
1220          86                                327      my $com  = $com_for{$code};
1221  ***     86     50                         341      if ( !$com ) {
1222  ***      0                                  0         MKDEBUG && _d('Did not match COM packet');
1223  ***      0                                  0         return;
1224                                                     }
1225          86    100    100                 1080      if (    $code ne COM_STMT_EXECUTE
                           100                        
1226                                                          && $code ne COM_STMT_CLOSE
1227                                                          && $code ne COM_STMT_RESET )
1228                                                     {
1229                                                        # Data for the most common COM, e.g. COM_QUERY, is text.
1230                                                        # COM_STMT_EXECUTE is not, so we leave it binary; it can
1231                                                        # be parsed by parse_execute_packet().
1232          70                                512         $data = to_string(substr($data, 2, ($len - 1) * 2));
1233                                                     }
1234          86                                620      my $pkt = {
1235                                                        code => $code,
1236                                                        com  => $com,
1237                                                        data => $data,
1238                                                     };
1239          86                                216      MKDEBUG && _d('COM packet:', Dumper($pkt));
1240          86                                340      return $pkt;
1241                                                  }
1242                                                  
1243                                                  # Execute prepared statement packet structure:
1244                                                  # Bytes              Field
1245                                                  # ===========        ========================================
1246                                                  # 00                 Code 17, COM_STMT_EXECUTE
1247                                                  # 00 00 00 00        Statement handler ID
1248                                                  # 00                 flags
1249                                                  # 00 00 00 00        Iteration count (reserved, always 1)
1250                                                  # (param_count+7)/8  NULL bitmap
1251                                                  # 00                 1 if new parameters, else 0
1252                                                  # n*2                Parameter types (only if new parameters)
1253                                                  sub parse_execute_packet {
1254  ***     11                   11      0     51      my ( $data, $sths ) = @_;
1255  ***     11     50     33                   98      return unless $data && $sths;
1256                                                  
1257          11                                 56      my $sth_id = to_num(substr($data, 2, 8));
1258  ***     11     50                          52      return unless defined $sth_id;
1259                                                  
1260          11                                 44      my $sth = $sths->{$sth_id};
1261  ***     11     50                          56      if ( !$sth ) {
1262  ***      0                                  0         MKDEBUG && _d('Skipping unknown statement handle', $sth_id);
1263  ***      0                                  0         return;
1264                                                     }
1265          11           100                   99      my $null_count  = int(($sth->{num_params} + 7) / 8) || 1;
1266          11                                 58      my $null_bitmap = to_num(substr($data, 20, $null_count * 2));
1267          11                                 27      MKDEBUG && _d('NULL bitmap:', $null_bitmap, 'count:', $null_count);
1268                                                     
1269                                                     # This chops off everything up to the byte for new params.
1270          11                                 52      substr($data, 0, 20 + ($null_count * 2), '');
1271                                                  
1272          11                                 46      my $new_params = to_num(substr($data, 0, 2, ''));
1273          11                                 35      my @types; 
1274          11    100                          39      if ( $new_params ) {
1275           8                                 24         MKDEBUG && _d('New param types');
1276                                                        # It seems all params are type 254, MYSQL_TYPE_STRING.  Perhaps
1277                                                        # this depends on the client.  If we ever need these types, they
1278                                                        # can be saved here.  Otherwise for now I just want to see the
1279                                                        # types in debug output.
1280           8                                 45         for my $i ( 0..($sth->{num_params}-1) ) {
1281          28                                123            my $type = to_num(substr($data, 0, 4, ''));
1282          28                                112            push @types, $type_for{$type};
1283          28                                 81            MKDEBUG && _d('Param', $i, 'type:', $type, $type_for{$type});
1284                                                        }
1285           8                                 43         $sth->{types} = \@types;
1286                                                     }
1287                                                     else {
1288                                                        # Retrieve previous param types if there are param vals (data).
1289           3    100                          14         @types = @{$sth->{types}} if $data;
               1                                  6   
1290                                                     }
1291                                                  
1292                                                     # $data should now be truncated up to the parameter values.
1293                                                  
1294          11                                 46      my $arg  = $sth->{statement};
1295          11                                 29      MKDEBUG && _d('Statement:', $arg);
1296          11                                 55      for my $i ( 0..($sth->{num_params}-1) ) {
1297          29                                 67         my $val;
1298          29                                 67         my $len;  # in bytes
1299          29    100                         138         if ( $null_bitmap & (2**$i) ) {
1300           8                                 20            MKDEBUG && _d('Param', $i, 'is NULL (bitmap)');
1301           8                                 23            $val = 'NULL';
1302           8                                 24            $len = 0;
1303                                                        }
1304                                                        else {
1305  ***     21     50                          92            if ( $unpack_type{$types[$i]} ) {
1306          21                                 99               ($val, $len) = $unpack_type{$types[$i]}->($data);
1307                                                           }
1308                                                           else {
1309                                                              # TODO: this is probably going to break parsing other param vals
1310  ***      0                                  0               MKDEBUG && _d('No handler for param', $i, 'type', $types[$i]);
1311  ***      0                                  0               $val = '?';
1312  ***      0                                  0               $len = 0;
1313                                                           }
1314                                                        }
1315                                                  
1316                                                        # Replace ? in prepared statement with value.
1317          29                                 71         MKDEBUG && _d('Param', $i, 'val:', $val);
1318          29                                183         $arg =~ s/\?/$val/;
1319                                                  
1320                                                        # Remove this param val from the data, putting us at the next one.
1321          29    100                         171         substr($data, 0, $len * 2, '') if $len;
1322                                                     }
1323                                                  
1324          11                                 69      my $pkt = {
1325                                                        sth_id => $sth_id,
1326                                                        arg    => "EXECUTE $arg",
1327                                                     };
1328          11                                 25      MKDEBUG && _d('Execute packet:', Dumper($pkt));
1329          11                                 48      return $pkt;
1330                                                  }
1331                                                  
1332                                                  sub get_sth_id {
1333  ***      3                    3      0     16      my ( $data ) = @_;
1334  ***      3     50                          12      return unless $data;
1335           3                                 14      my $sth_id = to_num(substr($data, 2, 8));
1336           3                                 11      return $sth_id;
1337                                                  }
1338                                                  
1339                                                  sub parse_flags {
1340  ***     20                   20      0     94      my ( $flags ) = @_;
1341  ***     20     50                         100      die "I need flags" unless $flags;
1342          20                                 55      MKDEBUG && _d('Flag data:', $flags);
1343          20                                371      my %flags     = %flag_for;
1344          20                                114      my $flags_dec = to_num($flags);
1345          20                                148      foreach my $flag ( keys %flag_for ) {
1346         360                               1224         my $flagno    = $flag_for{$flag};
1347         360    100                        1973         $flags{$flag} = ($flags_dec & $flagno ? 1 : 0);
1348                                                     }
1349          20                                189      return \%flags;
1350                                                  }
1351                                                  
1352                                                  # Takes a scalarref to a hex string of compressed data.
1353                                                  # Returns a scalarref to a hex string of the uncompressed data.
1354                                                  # The given hex string of compressed data is not modified.
1355                                                  sub uncompress_data {
1356  ***      1                    1      0      8      my ( $data, $len ) = @_;
1357  ***      1     50                           9      die "I need data" unless $data;
1358  ***      1     50                           7      die "I need a len argument" unless $len;
1359  ***      1     50                           9      die "I need a scalar reference to data" unless ref $data eq 'SCALAR';
1360           1                                  3      MKDEBUG && _d('Uncompressing data');
1361           1                                  4      our $InflateError;
1362                                                  
1363                                                     # Pack hex string into compressed binary data.
1364           1                                175      my $comp_bin_data = pack('H*', $$data);
1365                                                  
1366                                                     # Uncompress the compressed binary data.
1367           1                                  5      my $uncomp_bin_data = '';
1368  ***      1     50                          24      my $z = new IO::Uncompress::Inflate(
1369                                                        \$comp_bin_data
1370                                                     ) or die "IO::Uncompress::Inflate failed: $InflateError";
1371  ***      1     50                        7032      my $status = $z->read(\$uncomp_bin_data, $len)
1372                                                        or die "IO::Uncompress::Inflate failed: $InflateError";
1373                                                  
1374                                                     # Unpack the uncompressed binary data back into a hex string.
1375                                                     # This is the original MySQL packet(s).
1376           1                               2110      my $uncomp_data = unpack('H*', $uncomp_bin_data);
1377                                                  
1378           1                                  4      return \$uncomp_data;
1379                                                  }
1380                                                  
1381                                                  # Returns 1 on success or 0 on failure.  Failure is probably
1382                                                  # detecting compression but not being able to uncompress
1383                                                  # (uncompress_packet() returns 0).
1384                                                  sub detect_compression {
1385  ***     29                   29      0    146      my ( $self, $packet, $session ) = @_;
1386          29                                 84      MKDEBUG && _d('Checking for client compression');
1387                                                     # This is a necessary hack for detecting compression in-stream without
1388                                                     # having seen the client handshake and CLIENT_COMPRESS flag.  If the
1389                                                     # client is compressing packets, there will be an extra 7 bytes before
1390                                                     # the regular MySQL header.  For short COM_QUERY commands, these 7 bytes
1391                                                     # are usually zero where we'd expect to see 03 for COM_QUERY.  So if we
1392                                                     # parse this packet and it looks like a COM_SLEEP (00) which is not a
1393                                                     # command that the client can send, then chances are the client is using
1394                                                     # compression.
1395          29                                198      my $com = parse_com_packet($packet->{data}, $packet->{mysql_data_len});
1396  ***     29    100     66                  343      if ( $com && $com->{code} eq COM_SLEEP ) {
1397           1                                 18         MKDEBUG && _d('Client is using compression');
1398           1                                  6         $session->{compress} = 1;
1399                                                  
1400                                                        # Since parse_packet() didn't know the packet was compressed, it
1401                                                        # called remove_mysql_header() which removed the first 4 of 7 bytes
1402                                                        # of the compression header.  We must restore these 4 bytes, then
1403                                                        # uncompress and remove the MySQL header.  We only do this once.
1404           1                                 10         $packet->{data} = $packet->{mysql_hdr} . $packet->{data};
1405  ***      1     50                           8         return 0 unless $self->uncompress_packet($packet, $session);
1406           1                                  6         remove_mysql_header($packet);
1407                                                     }
1408                                                     else {
1409          28                                 61         MKDEBUG && _d('Client is NOT using compression');
1410          28                                107         $session->{compress} = 0;
1411                                                     }
1412          29                                182      return 1;
1413                                                  }
1414                                                  
1415                                                  # Returns 1 if the packet was uncompressed or 0 if we can't uncompress.
1416                                                  # Failure is usually due to IO::Uncompress not being available.
1417                                                  sub uncompress_packet {
1418  ***      6                    6      0     43      my ( $self, $packet, $session ) = @_;
1419  ***      6     50                          41      die "I need a packet"  unless $packet;
1420  ***      6     50                          36      die "I need a session" unless $session;
1421                                                  
1422                                                     # From the doc: "A compressed packet header is:
1423                                                     #    packet length (3 bytes),
1424                                                     #    packet number (1 byte),
1425                                                     #    and Uncompressed Packet Length (3 bytes).
1426                                                     # The Uncompressed Packet Length is the number of bytes
1427                                                     # in the original, uncompressed packet. If this is zero
1428                                                     # then the data is not compressed."
1429                                                  
1430           6                                 23      my $data;
1431           6                                 21      my $comp_hdr;
1432           6                                 24      my $comp_data_len;
1433           6                                 18      my $pkt_num;
1434           6                                 23      my $uncomp_data_len;
1435           6                                 24      eval {
1436           6                                 35         $data            = \$packet->{data};
1437           6                                 46         $comp_hdr        = substr($$data, 0, 14, '');
1438           6                                 39         $comp_data_len   = to_num(substr($comp_hdr, 0, 6));
1439           6                                 45         $pkt_num         = to_num(substr($comp_hdr, 6, 2));
1440           6                                 43         $uncomp_data_len = to_num(substr($comp_hdr, 8, 6));
1441           6                                 34         MKDEBUG && _d('Compression header data:', $comp_hdr,
1442                                                           'compressed data len (bytes)', $comp_data_len,
1443                                                           'number', $pkt_num,
1444                                                           'uncompressed data len (bytes)', $uncomp_data_len);
1445                                                     };
1446  ***      6     50                          39      if ( $EVAL_ERROR ) {
1447  ***      0                                  0         $session->{EVAL_ERROR} = $EVAL_ERROR;
1448  ***      0                                  0         $self->fail_session($session, 'failed to parse compression header');
1449  ***      0                                  0         return 0;
1450                                                     }
1451                                                  
1452           6    100                          34      if ( $uncomp_data_len ) {
1453           1                                  5         eval {
1454           1                                  7            $data = uncompress_data($data, $uncomp_data_len);
1455           1                                 72            $packet->{data} = $$data;
1456                                                        };
1457  ***      1     50                           9         if ( $EVAL_ERROR ) {
1458  ***      0                                  0            $session->{EVAL_ERROR} = $EVAL_ERROR;
1459  ***      0                                  0            $self->fail_session($session, 'failed to uncompress data');
1460  ***      0                                  0            die "Cannot uncompress packet.  Check that IO::Uncompress::Inflate "
1461                                                              . "is installed.\nError: $EVAL_ERROR";
1462                                                        }
1463                                                     }
1464                                                     else {
1465           5                                 17         MKDEBUG && _d('Packet is not really compressed');
1466           5                                 31         $packet->{data} = $$data;
1467                                                     }
1468                                                  
1469           6                                 52      return 1;
1470                                                  }
1471                                                  
1472                                                  # Removes the first 4 bytes of the packet data which should be
1473                                                  # a MySQL header: 3 bytes packet length, 1 byte packet number.
1474                                                  sub remove_mysql_header {
1475  ***    134                  134      0    540      my ( $packet ) = @_;
1476  ***    134     50                         656      die "I need a packet" unless $packet;
1477                                                  
1478                                                     # NOTE: the data is modified by the inmost substr call here!  If we
1479                                                     # had all the data in the TCP packets, we could change this to a while
1480                                                     # loop; while get-a-packet-from-$data, do stuff, etc.  But we don't,
1481                                                     # and we don't want to either.
1482         134                                718      my $mysql_hdr      = substr($packet->{data}, 0, 8, '');
1483         134                                613      my $mysql_data_len = to_num(substr($mysql_hdr, 0, 6));
1484         134                                629      my $pkt_num        = to_num(substr($mysql_hdr, 6, 2));
1485         134                                327      MKDEBUG && _d('MySQL packet: header data', $mysql_hdr,
1486                                                        'data len (bytes)', $mysql_data_len, 'number', $pkt_num);
1487                                                  
1488         134                                592      $packet->{mysql_hdr}      = $mysql_hdr;
1489         134                                546      $packet->{mysql_data_len} = $mysql_data_len;
1490         134                                496      $packet->{number}         = $pkt_num;
1491                                                  
1492         134                                480      return;
1493                                                  }
1494                                                  
1495                                                  sub _get_errors_fh {
1496           4                    4            17      my ( $self ) = @_;
1497           4                                 16      my $errors_fh = $self->{errors_fh};
1498  ***      4     50                          20      return $errors_fh if $errors_fh;
1499                                                  
1500                                                     # Errors file isn't open yet; try to open it.
1501           4                                 15      my $o = $self->{o};
1502  ***      4     50     33                   29      if ( $o && $o->has('tcpdump-errors') && $o->got('tcpdump-errors') ) {
      ***                   33                        
1503  ***      0                                  0         my $errors_file = $o->get('tcpdump-errors');
1504  ***      0                                  0         MKDEBUG && _d('tcpdump-errors file:', $errors_file);
1505  ***      0      0                           0         open $errors_fh, '>>', $errors_file
1506                                                           or die "Cannot open tcpdump-errors file $errors_file: $OS_ERROR";
1507                                                     }
1508                                                  
1509           4                                 16      $self->{errors_fh} = $errors_fh;
1510           4                                 16      return $errors_fh;
1511                                                  }
1512                                                  
1513                                                  sub fail_session {
1514  ***      4                    4      0     25      my ( $self, $session, $reason ) = @_;
1515           4                                 12      MKDEBUG && _d('Client', $session->{client}, 'failed because', $reason);
1516           4                                 19      my $errors_fh = $self->_get_errors_fh();
1517  ***      4     50                          25      if ( $errors_fh ) {
1518  ***      0                                  0         my $raw_packets = $session->{raw_packets};
1519  ***      0                                  0         delete $session->{raw_packets};  # Don't dump, it's printed below.
1520  ***      0                                  0         $session->{reason_for_failure} = $reason;
1521  ***      0                                  0         my $session_dump = '# ' . Dumper($session);
1522  ***      0                                  0         chomp $session_dump;
1523  ***      0                                  0         $session_dump =~ s/\n/\n# /g;
1524  ***      0                                  0         print $errors_fh "$session_dump\n";
1525                                                        {
1526  ***      0                                  0            local $LIST_SEPARATOR = "\n";
      ***      0                                  0   
1527  ***      0                                  0            print $errors_fh "@$raw_packets";
1528  ***      0                                  0            print $errors_fh "\n";
1529                                                        }
1530                                                     }
1531           4                                 22      delete $self->{sessions}->{$session->{client}};
1532           4                                 14      return;
1533                                                  }
1534                                                  
1535                                                  # Delete anything we added to the session related to
1536                                                  # buffering a large query received in multiple packets.
1537                                                  sub _delete_buff {
1538          66                   66           286      my ( $self, $session ) = @_;
1539          66                                253      map { delete $session->{$_} } qw(buff buff_left mysql_data_len);
             198                                775   
1540          66                                209      return;
1541                                                  }
1542                                                  
1543                                                  sub _d {
1544  ***      0                    0                    my ($package, undef, $line) = caller 0;
1545  ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
1546  ***      0                                              map { defined $_ ? $_ : 'undef' }
1547                                                          @_;
1548  ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
1549                                                  }
1550                                                  
1551                                                  1;
1552                                                  
1553                                                  # ###########################################################################
1554                                                  # End MySQLProtocolParser package
1555                                                  # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
250   ***     50      0    239   unless $args{$arg}
257          100    132    107   if (my $server = $$self{'server'})
259          100      3    129   if ($src_host ne $server and $dst_host ne $server)
269          100    105    131   if ($src_host =~ /:$$self{'port'}$/) { }
      ***     50    131      0   elsif ($dst_host =~ /:$$self{'port'}$/) { }
286          100    136    100   if ($$packet{'data_len'} >= 5)
294          100     65    171   if (not exists $$self{'sessions'}{$client})
295          100      7     58   if ($$packet{'syn'}) { }
             100     32     26   elsif ($packetno == 0) { }
327          100      1    209   if ($$packet{'syn'} and $$session{'n_queries'} > 0 || $$session{'state'})
339          100     69    140   if ($$packet{'data_len'} == 0)
347          100      5    135   if ($$session{'compress'})
348   ***     50      0      5   unless $self->uncompress_packet($packet, $session)
351          100      7    133   if ($$session{'buff'} and $packet_from eq 'client') { }
377   ***     50      0    133   if ($EVAL_ERROR)
388          100     63     77   if ($packet_from eq 'server') { }
      ***     50     77      0   elsif ($packet_from eq 'client') { }
392          100      7     70   if ($$session{'buff'}) { }
             100      6     64   elsif ($$packet{'mysql_data_len'} > $$packet{'data_len'} - 4) { }
393          100      4      3   if ($$session{'buff_left'} <= 0) { }
404          100      1      5   if ($$session{'cmd'} and ($$session{'state'} || '') eq 'awaiting_reply')
429          100      1     67   if ($$session{'cmd'} and ($$session{'state'} || '') eq 'awaiting_reply')
451          100      9    121   if ($$session{'closed'})
468   ***     50      0     63   unless $packet
469   ***     50      0     63   unless $session
473   ***     50      0     63   if (($$session{'server_seq'} || '') eq $$packet{'seq'})
490   ***     50      0     63   if (not $first_byte)
498          100     10     53   if (not $$session{'state'}) { }
499          100      9      1   if ($first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/) { }
      ***     50      1      0   elsif ($$session{'buff'}) { }
507   ***     50      0      9   if (not $handshake)
515   ***     50      0      9   unless $$session{'ts'}
528          100     26     27   if ($first_byte eq '00') { }
             100      2     25   elsif ($first_byte eq 'ff') { }
             100      1     24   elsif ($first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9) { }
529          100      8     18   if (($$session{'state'} || '') eq 'client_auth') { }
      ***     50     18      0   elsif ($$session{'cmd'}) { }
550          100      9      9   if ($com eq '16') { }
553   ***     50      0      9   if (not $ok)
568   ***     50      0      9   if (not $ok)
575          100      9      9   if ($com eq '03' or $com eq '17' or $com eq '1a') { }
      ***     50      9      0   elsif ($com eq '16') { }
607   ***     50      0      2   if (not $error)
613          100      1      1   if ($$session{'state'} eq 'client_auth') { }
      ***     50      1      0   elsif ($$session{'cmd'}) { }
630   ***     50      1      0   if ($com eq '03' or $com eq '17') { }
640   ***     50      1      0   $$error{'errno'} ? :
655   ***     50      1      0   if ($$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2) { }
678   ***     50     24      0   if ($$session{'cmd'}) { }
683   ***     50     24      0   if ($com eq '03' or $com eq '17') { }
694   ***     50     24      0   if ($$packet{'complete'})
699          100     23      1   if ($warning_count)
702   ***     50      0     23   $flags & 16 ? :
704          100      7     16   $flags & 32 ? :
729   ***     50      0     67   unless $packet
730   ***     50      0     67   unless $session
734          100      1     66   if (($$session{'client_seq'} || '') eq $$packet{'seq'})
744          100      9     57   if (($$session{'state'} || '') eq 'server_handshake') { }
             100      1     56   elsif (($$session{'state'} || '') eq 'client_auth_resend') { }
      ***     50      0     56   elsif (($$session{'state'} || '') eq 'awaiting_reply') { }
754   ***     50      0      9   if (not $handshake)
775   ***      0      0      0   $$session{'cmd'}{'arg'} ? :
784   ***     50      0     56   if ($$packet{'number'} != 0)
792          100     29     27   if (not defined $$session{'compress'})
793   ***     50      0     29   unless $self->detect_compression($packet, $session)
798   ***     50      0     56   if (not $com)
803          100     11     45   if ($$com{'code'} eq '17') { }
             100      1     44   elsif ($$com{'code'} eq '1a') { }
806   ***     50      0     11   if (not $exec)
818   ***     50      0      1   if (not $sth_id)
835          100      8     48   if ($$com{'code'} eq '01') { }
             100      2     46   elsif ($$com{'code'} eq '19') { }
852   ***     50      0      2   if (not $sth_id)
880          100     27     35   if (not $$session{'thread_id'})
888   ***     50      0     62   $$event{'No_good_index_used'} ? :
             100      7     55   $$event{'No_index_used'} ? :
944   ***     50     62      0   if ($sd eq $ed) { }
963   ***     50     13      0   $len ? :
970   ***     50      0     13   unless $data
982   ***     50     13      0   if ($first_byte <= 251) { }
      ***      0      0      0   elsif ($first_byte == 252) { }
      ***      0      0      0   elsif ($first_byte == 253) { }
      ***      0      0      0   elsif ($first_byte == 254) { }
1013         100      4    625   if ($len)
1035  ***     50     20      0   if ($first_byte < 251) { }
      ***      0      0      0   elsif ($first_byte == 252) { }
      ***      0      0      0   elsif ($first_byte == 253) { }
      ***      0      0      0   elsif ($first_byte == 254) { }
1061  ***     50      0      3   unless $data
1063  ***     50      0      3   if (length $data < 16)
1069  ***     50      0      3   unless $marker eq '#'
1093  ***     50      0     10   unless $data
1095  ***     50      0     10   if (length $data < 12)
1126  ***     50      0      9   unless $data
1128  ***     50      0      9   if (length $data < 8)
1147  ***     50      0     10   unless $data
1175  ***     50      0     10   unless $data
1189  ***     50      0     10   if (not $buff_len)
1202         100      7      3   $db ? :
1215  ***     50      0     86   unless $data and $len
1221  ***     50      0     86   if (not $com)
1225         100     70     16   if ($code ne '17' and $code ne '19' and $code ne '1a')
1255  ***     50      0     11   unless $data and $sths
1258  ***     50      0     11   unless defined $sth_id
1261  ***     50      0     11   if (not $sth)
1274         100      8      3   if ($new_params) { }
1289         100      1      2   if $data
1299         100      8     21   if ($null_bitmap & 2 ** $i) { }
1305  ***     50     21      0   if ($unpack_type{$types[$i]}) { }
1321         100     21      8   if $len
1334  ***     50      0      3   unless $data
1341  ***     50      0     20   unless $flags
1347         100    154    206   $flags_dec & $flagno ? :
1357  ***     50      0      1   unless $data
1358  ***     50      0      1   unless $len
1359  ***     50      0      1   unless ref $data eq 'SCALAR'
1368  ***     50      0      1   unless my $z = 'IO::Uncompress::Inflate'->new(\$comp_bin_data)
1371  ***     50      0      1   unless my $status = $z->read(\$uncomp_bin_data, $len)
1396         100      1     28   if ($com and $$com{'code'} eq '00') { }
1405  ***     50      0      1   unless $self->uncompress_packet($packet, $session)
1419  ***     50      0      6   unless $packet
1420  ***     50      0      6   unless $session
1446  ***     50      0      6   if ($EVAL_ERROR)
1452         100      1      5   if ($uncomp_data_len) { }
1457  ***     50      0      1   if ($EVAL_ERROR)
1476  ***     50      0    134   unless $packet
1498  ***     50      0      4   if $errors_fh
1502  ***     50      0      4   if ($o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors'))
1505  ***      0      0      0   unless open $errors_fh, '>>', $errors_file
1517  ***     50      0      4   if ($errors_fh)
1545  ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
259          100     57     72      3   $src_host ne $server and $dst_host ne $server
327          100    195     14      1   $$packet{'syn'} and $$session{'n_queries'} > 0 || $$session{'state'}
351          100    132      1      7   $$session{'buff'} and $packet_from eq 'client'
404   ***     66      5      0      1   $$session{'cmd'} and ($$session{'state'} || '') eq 'awaiting_reply'
429   ***     66     67      0      1   $$session{'cmd'} and ($$session{'state'} || '') eq 'awaiting_reply'
499   ***     66      1      0      9   $first_byte eq '0a' and length $data >= 33
      ***     66      1      0      9   $first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/
528   ***     66     24      0      1   $first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9
655   ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth'
      ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2
1215  ***     33      0      0     86   $data and $len
1225         100     11      3     72   $code ne '17' and $code ne '19'
             100     14      2     70   $code ne '17' and $code ne '19' and $code ne '1a'
1255  ***     33      0      0     11   $data and $sths
1396  ***     66      0     28      1   $com and $$com{'code'} eq '00'
1502  ***     33      4      0      0   $o and $o->has('tcpdump-errors')
      ***     33      4      0      0   $o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors')

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
66    ***     50      0      1   $ENV{'MKDEBUG'} || 0
232          100     18     14   $args{'port'} || '3306'
404   ***     50      1      0   $$session{'state'} || ''
421   ***     50      0      5   $$session{'buff_left'} ||= $$packet{'mysql_data_len'} - ($$packet{'data_len'} - 4)
429   ***     50      1      0   $$session{'state'} || ''
473          100     28     35   $$session{'server_seq'} || ''
529   ***     50     26      0   $$session{'state'} || ''
734          100     29     38   $$session{'client_seq'} || ''
744          100     10     56   $$session{'state'} || ''
             100      1     56   $$session{'state'} || ''
      ***     50      0     56   $$session{'state'} || ''
888          100      2     60   $$event{'Error_no'} || 'none'
             100      7     55   $$event{'Rows_affected'} || 0
             100      3     59   $$event{'Warning_count'} || 0
1265         100      9      2   int(($$sth{'num_params'} + 7) / 8) || 1

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
327   ***     66      1      0     14   $$session{'n_queries'} > 0 || $$session{'state'}
575          100      7      1     10   $com eq '03' or $com eq '17'
             100      8      1      9   $com eq '03' or $com eq '17' or $com eq '1a'
630   ***     33      1      0      0   $com eq '03' or $com eq '17'
683   ***     66     14     10      0   $com eq '03' or $com eq '17'


Covered Subroutines
-------------------

Subroutine                         Count Pod Location                                                   
---------------------------------- ----- --- -----------------------------------------------------------
BEGIN                                  1     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:182 
BEGIN                                  1     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:38  
BEGIN                                  1     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:39  
BEGIN                                  1     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:40  
BEGIN                                  1     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:47  
BEGIN                                  1     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:66  
BEGIN                                  1     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:99  
_delete_buff                          66     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1538
_get_errors_fh                         4     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1496
_make_event                           62     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:873 
_packet_from_client                   67     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:728 
_packet_from_server                   63     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:467 
decode_len                            13   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:969 
detect_compression                    29   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1385
fail_session                           4   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1514
get_lcb                               20   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1033
get_sth_id                             3   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1333
new                                   32   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:230 
parse_client_handshake_packet         10   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1174
parse_com_packet                      86   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1214
parse_error_packet                     3   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1060
parse_event                          239   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:247 
parse_execute_packet                  11   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1254
parse_flags                           20   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1340
parse_ok_packet                       10   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1092
parse_ok_prepared_statement_packet     9   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1125
parse_server_handshake_packet         10   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1146
remove_mysql_header                  134   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1475
tcp_timestamp                         62   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:930 
timestamp_diff                        62   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:937 
to_double                              4   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1025
to_num                               629   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1012
to_string                            116   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:954 
uncompress_data                        1   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1356
uncompress_packet                      6   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1418
unpack_string                         13   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:959 

Uncovered Subroutines
---------------------

Subroutine                         Count Pod Location                                                   
---------------------------------- ----- --- -----------------------------------------------------------
_d                                     0     /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1544


MySQLProtocolParser.t

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
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More tests => 70;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use MySQLProtocolParser;
               1                                  3   
               1                                 10   
15             1                    1            11   use TcpdumpParser;
               1                                  2   
               1                                 11   
16             1                    1            10   use MaatkitTest;
               1                                  4   
               1                                 40   
17                                                    
18             1                                  5   my $sample  = "common/t/samples/tcpdump/";
19             1                                  7   my $tcpdump = new TcpdumpParser();
20             1                                 26   my $protocol; # Create a new MySQLProtocolParser for each test.
21                                                    
22                                                    # Check that I can parse a really simple session.
23             1                                 10   $protocol = new MySQLProtocolParser();
24             1                                 57   test_protocol_parser(
25                                                       parser   => $tcpdump,
26                                                       protocol => $protocol,
27                                                       file     => "$sample/tcpdump001.txt",
28                                                       result   => [
29                                                          {  ts            => '090412 09:50:16.805123',
30                                                             db            => undef,
31                                                             user          => undef,
32                                                             Thread_id     => 4294967296,
33                                                             host          => '127.0.0.1',
34                                                             ip            => '127.0.0.1',
35                                                             port          => '42167',
36                                                             arg           => 'select "hello world" as greeting',
37                                                             Query_time    => sprintf('%.6f', .805123 - .804849),
38                                                             pos_in_log    => 0,
39                                                             bytes         => length('select "hello world" as greeting'),
40                                                             cmd           => 'Query',
41                                                             Error_no      => 'none',
42                                                             Rows_affected => 0,
43                                                             Warning_count      => 0,
44                                                             No_good_index_used => 'No',
45                                                             No_index_used      => 'No',
46                                                          },
47                                                       ],
48                                                    );
49                                                    
50                                                    # A more complex session with a complete login/logout cycle.
51             1                                 36   $protocol = new MySQLProtocolParser();
52             1                                 61   test_protocol_parser(
53                                                       parser   => $tcpdump,
54                                                       protocol => $protocol,
55                                                       file     => "$sample/tcpdump002.txt",
56                                                       result   => [
57                                                          {  ts         => "090412 11:00:13.118191",
58                                                             db         => 'mysql',
59                                                             user       => 'msandbox',
60                                                             host       => '127.0.0.1',
61                                                             ip         => '127.0.0.1',
62                                                             port       => '57890',
63                                                             arg        => 'administrator command: Connect',
64                                                             Query_time => '0.011152',
65                                                             Thread_id  => 8,
66                                                             pos_in_log => 1470,
67                                                             bytes      => length('administrator command: Connect'),
68                                                             cmd        => 'Admin',
69                                                             Error_no   => 'none',
70                                                             Rows_affected => 0,
71                                                             Warning_count      => 0,
72                                                             No_good_index_used => 'No',
73                                                             No_index_used      => 'No',
74                                                          },
75                                                          {  Query_time => '0.000265',
76                                                             Thread_id  => 8,
77                                                             arg        => 'select @@version_comment limit 1',
78                                                             bytes      => length('select @@version_comment limit 1'),
79                                                             cmd        => 'Query',
80                                                             db         => 'mysql',
81                                                             host       => '127.0.0.1',
82                                                             ip         => '127.0.0.1',
83                                                             port       => '57890',
84                                                             pos_in_log => 2449,
85                                                             ts         => '090412 11:00:13.118643',
86                                                             user       => 'msandbox',
87                                                             Error_no   => 'none',
88                                                             Rows_affected => 0,
89                                                             Warning_count      => 0,
90                                                             No_good_index_used => 'No',
91                                                             No_index_used      => 'No',
92                                                          },
93                                                          {  Query_time => '0.000167',
94                                                             Thread_id  => 8,
95                                                             arg        => 'select "paris in the the spring" as trick',
96                                                             bytes      => length('select "paris in the the spring" as trick'),
97                                                             cmd        => 'Query',
98                                                             db         => 'mysql',
99                                                             host       => '127.0.0.1',
100                                                            ip         => '127.0.0.1',
101                                                            port       => '57890',
102                                                            pos_in_log => 3298,
103                                                            ts         => '090412 11:00:13.119079',
104                                                            user       => 'msandbox',
105                                                            Error_no   => 'none',
106                                                            Rows_affected => 0,
107                                                            Warning_count      => 0,
108                                                            No_good_index_used => 'No',
109                                                            No_index_used      => 'No',
110                                                         },
111                                                         {  Query_time => '0.000000',
112                                                            Thread_id  => 8,
113                                                            arg        => 'administrator command: Quit',
114                                                            bytes      => 27,
115                                                            cmd        => 'Admin',
116                                                            db         => 'mysql',
117                                                            host       => '127.0.0.1',
118                                                            ip         => '127.0.0.1',
119                                                            port       => '57890',
120                                                            pos_in_log => '4186',
121                                                            ts         => '090412 11:00:13.119487',
122                                                            user       => 'msandbox',
123                                                            Error_no   => 'none',
124                                                            Rows_affected => 0,
125                                                            Warning_count      => 0,
126                                                            No_good_index_used => 'No',
127                                                            No_index_used      => 'No',
128                                                         },
129                                                      ],
130                                                   );
131                                                   
132                                                   # A session that has an error during login.
133            1                                 70   $protocol = new MySQLProtocolParser();
134            1                                 25   test_protocol_parser(
135                                                      parser   => $tcpdump,
136                                                      protocol => $protocol,
137                                                      file     => "$sample/tcpdump003.txt",
138                                                      result   => [
139                                                         {  ts         => "090412 12:41:46.357853",
140                                                            db         => '',
141                                                            user       => 'msandbox',
142                                                            host       => '127.0.0.1',
143                                                            ip         => '127.0.0.1',
144                                                            port       => '44488',
145                                                            arg        => 'administrator command: Connect',
146                                                            Query_time => '0.010753',
147                                                            Thread_id  => 9,
148                                                            pos_in_log => 1455,
149                                                            bytes      => length('administrator command: Connect'),
150                                                            cmd        => 'Admin',
151                                                            Error_no   => 1045,
152                                                            Rows_affected => 0,
153                                                            Warning_count      => 0,
154                                                            No_good_index_used => 'No',
155                                                            No_index_used      => 'No',
156                                                         },
157                                                      ],
158                                                   );
159                                                   
160                                                   # A session that has an error executing a query
161            1                                 34   $protocol = new MySQLProtocolParser();
162            1                                 23   test_protocol_parser(
163                                                      parser   => $tcpdump,
164                                                      protocol => $protocol,
165                                                      file     => "$sample/tcpdump004.txt",
166                                                      result   => [
167                                                         {  ts         => "090412 12:58:02.036002",
168                                                            db         => undef,
169                                                            user       => undef,
170                                                            host       => '127.0.0.1',
171                                                            ip         => '127.0.0.1',
172                                                            port       => '60439',
173                                                            arg        => 'select 5 from foo',
174                                                            Query_time => '0.000251',
175                                                            Thread_id  => 4294967296,
176                                                            pos_in_log => 0,
177                                                            bytes      => length('select 5 from foo'),
178                                                            cmd        => 'Query',
179                                                            Error_no   => "#1046",
180                                                            Rows_affected => 0,
181                                                            Warning_count      => 0,
182                                                            No_good_index_used => 'No',
183                                                            No_index_used      => 'No',
184                                                         },
185                                                      ],
186                                                   );
187                                                   
188                                                   # A session that has a single-row insert and a multi-row insert
189            1                                 34   $protocol = new MySQLProtocolParser();
190            1                                 40   test_protocol_parser(
191                                                      parser   => $tcpdump,
192                                                      protocol => $protocol,
193                                                      file     => "$sample/tcpdump005.txt",
194                                                      result   => [
195                                                         {  Error_no   => 'none',
196                                                            Rows_affected => 1,
197                                                            Query_time => '0.000435',
198                                                            Thread_id  => 4294967296,
199                                                            arg        => 'insert into test.t values(1)',
200                                                            bytes      => 28,
201                                                            cmd        => 'Query',
202                                                            db         => undef,
203                                                            host       => '127.0.0.1',
204                                                            ip         => '127.0.0.1',
205                                                            port       => '55300',
206                                                            pos_in_log => '0',
207                                                            ts         => '090412 16:46:02.978340',
208                                                            user       => undef,
209                                                            Warning_count      => 0,
210                                                            No_good_index_used => 'No',
211                                                            No_index_used      => 'No',
212                                                         },
213                                                         {  Error_no   => 'none',
214                                                            Rows_affected => 2,
215                                                            Query_time => '0.000565',
216                                                            Thread_id  => 4294967296,
217                                                            arg        => 'insert into test.t values(1),(2)',
218                                                            bytes      => 32,
219                                                            cmd        => 'Query',
220                                                            db         => undef,
221                                                            host       => '127.0.0.1',
222                                                            ip         => '127.0.0.1',
223                                                            port       => '55300',
224                                                            pos_in_log => '1033',
225                                                            ts         => '090412 16:46:20.245088',
226                                                            user       => undef,
227                                                            Warning_count      => 0,
228                                                            No_good_index_used => 'No',
229                                                            No_index_used      => 'No',
230                                                         },
231                                                      ],
232                                                   );
233                                                   
234                                                   # A session that causes a slow query because it doesn't use an index.
235            1                                 41   $protocol = new MySQLProtocolParser();
236            1                                 28   test_protocol_parser(
237                                                      parser   => $tcpdump,
238                                                      protocol => $protocol,
239                                                      file     => "$sample/tcpdump006.txt",
240                                                      result   => [
241                                                         {  ts         => '100412 20:46:10.776899',
242                                                            db         => undef,
243                                                            user       => undef,
244                                                            host       => '127.0.0.1',
245                                                            ip         => '127.0.0.1',
246                                                            port       => '48259',
247                                                            arg        => 'select * from t',
248                                                            Query_time => '0.000205',
249                                                            Thread_id  => 4294967296,
250                                                            pos_in_log => 0,
251                                                            bytes      => length('select * from t'),
252                                                            cmd        => 'Query',
253                                                            Error_no   => 'none',
254                                                            Rows_affected      => 0,
255                                                            Warning_count      => 0,
256                                                            No_good_index_used => 'No',
257                                                            No_index_used      => 'Yes',
258                                                         },
259                                                      ],
260                                                   );
261                                                   
262                                                   # A session that truncates an insert.
263            1                                 58   $protocol = new MySQLProtocolParser();
264            1                                 50   test_protocol_parser(
265                                                      parser   => $tcpdump,
266                                                      protocol => $protocol,
267                                                      file     => "$sample/tcpdump007.txt",
268                                                      result   => [
269                                                         {  ts         => '090412 20:57:22.798296',
270                                                            db         => undef,
271                                                            user       => undef,
272                                                            host       => '127.0.0.1',
273                                                            ip         => '127.0.0.1',
274                                                            port       => '38381',
275                                                            arg        => 'insert into t values(current_date)',
276                                                            Query_time => '0.000020',
277                                                            Thread_id  => 4294967296,
278                                                            pos_in_log => 0,
279                                                            bytes      => length('insert into t values(current_date)'),
280                                                            cmd        => 'Query',
281                                                            Error_no   => 'none',
282                                                            Rows_affected      => 1,
283                                                            Warning_count      => 1,
284                                                            No_good_index_used => 'No',
285                                                            No_index_used      => 'No',
286                                                         },
287                                                      ],
288                                                   );
289                                                   
290                                                   # #############################################################################
291                                                   # Check the individual packet parsing subs.
292                                                   # #############################################################################
293            1                                 68   MySQLProtocolParser->import(qw(
294                                                      parse_error_packet
295                                                      parse_ok_packet
296                                                      parse_server_handshake_packet
297                                                      parse_client_handshake_packet
298                                                      parse_com_packet
299                                                   ));
300                                                    
301            1                                419   is_deeply(
302                                                      parse_error_packet(load_data("common/t/samples/mysql_proto_001.txt")),
303                                                      {
304                                                         errno    => '1046',
305                                                         sqlstate => '#3D000',
306                                                         message  => 'No database selected',
307                                                      },
308                                                      'Parse error packet'
309                                                   );
310                                                   
311            1                                 22   is_deeply(
312                                                      parse_ok_packet('010002000100'),
313                                                      {
314                                                         affected_rows => 1,
315                                                         insert_id     => 0,
316                                                         status        => 2,
317                                                         warnings      => 1,
318                                                         message       => '',
319                                                      },
320                                                      'Parse ok packet'
321                                                   );
322                                                   
323            1                                 21   is_deeply(
324                                                      parse_server_handshake_packet(load_data("common/t/samples/mysql_proto_002.txt")),
325                                                      {
326                                                         thread_id      => '9',
327                                                         server_version => '5.0.67-0ubuntu6-log',
328                                                         flags          => {
329                                                            CLIENT_COMPRESS          => 1,
330                                                            CLIENT_CONNECT_WITH_DB   => 1,
331                                                            CLIENT_FOUND_ROWS        => 0,
332                                                            CLIENT_IGNORE_SIGPIPE    => 0,
333                                                            CLIENT_IGNORE_SPACE      => 0,
334                                                            CLIENT_INTERACTIVE       => 0,
335                                                            CLIENT_LOCAL_FILES       => 0,
336                                                            CLIENT_LONG_FLAG         => 1,
337                                                            CLIENT_LONG_PASSWORD     => 0,
338                                                            CLIENT_MULTI_RESULTS     => 0,
339                                                            CLIENT_MULTI_STATEMENTS  => 0,
340                                                            CLIENT_NO_SCHEMA         => 0,
341                                                            CLIENT_ODBC              => 0,
342                                                            CLIENT_PROTOCOL_41       => 1,
343                                                            CLIENT_RESERVED          => 0,
344                                                            CLIENT_SECURE_CONNECTION => 1,
345                                                            CLIENT_SSL               => 0,
346                                                            CLIENT_TRANSACTIONS      => 1,
347                                                         }
348                                                      },
349                                                      'Parse server handshake packet'
350                                                   );
351                                                   
352            1                                 28   is_deeply(
353                                                      parse_client_handshake_packet(load_data("common/t/samples/mysql_proto_003.txt")),
354                                                      {
355                                                         db    => 'mysql',
356                                                         user  => 'msandbox',
357                                                         flags => {
358                                                            CLIENT_COMPRESS          => 0,
359                                                            CLIENT_CONNECT_WITH_DB   => 1,
360                                                            CLIENT_FOUND_ROWS        => 0,
361                                                            CLIENT_IGNORE_SIGPIPE    => 0,
362                                                            CLIENT_IGNORE_SPACE      => 0,
363                                                            CLIENT_INTERACTIVE       => 0,
364                                                            CLIENT_LOCAL_FILES       => 1,
365                                                            CLIENT_LONG_FLAG         => 1,
366                                                            CLIENT_LONG_PASSWORD     => 1,
367                                                            CLIENT_MULTI_RESULTS     => 1,
368                                                            CLIENT_MULTI_STATEMENTS  => 1,
369                                                            CLIENT_NO_SCHEMA         => 0,
370                                                            CLIENT_ODBC              => 0,
371                                                            CLIENT_PROTOCOL_41       => 1,
372                                                            CLIENT_RESERVED          => 0,
373                                                            CLIENT_SECURE_CONNECTION => 1,
374                                                            CLIENT_SSL               => 0,
375                                                            CLIENT_TRANSACTIONS      => 1,
376                                                         },
377                                                      },
378                                                      'Parse client handshake packet'
379                                                   );
380                                                   
381            1                                 27   is_deeply(
382                                                      parse_com_packet('0373686f77207761726e696e67738d2dacbc', 14),
383                                                      {
384                                                         code => '03',
385                                                         com  => 'COM_QUERY',
386                                                         data => 'show warnings',
387                                                      },
388                                                      'Parse COM_QUERY packet'
389                                                   );
390                                                   
391                                                   # Test that we can parse with a non-standard port etc.
392            1                                 29   $protocol = new MySQLProtocolParser(
393                                                      server => '192.168.1.1',
394                                                      port   => '3307',
395                                                   );
396            1                                 76   test_protocol_parser(
397                                                      parser   => $tcpdump,
398                                                      protocol => $protocol,
399                                                      file     => "$sample/tcpdump012.txt",
400                                                      result   => [
401                                                         {  ts            => '090412 09:50:16.805123',
402                                                            db            => undef,
403                                                            user          => undef,
404                                                            Thread_id     => 4294967296,
405                                                            host          => '127.0.0.1',
406                                                            ip            => '127.0.0.1',
407                                                            port          => '42167',
408                                                            arg           => 'select "hello world" as greeting',
409                                                            Query_time    => sprintf('%.6f', .805123 - .804849),
410                                                            pos_in_log    => 0,
411                                                            bytes         => length('select "hello world" as greeting'),
412                                                            cmd           => 'Query',
413                                                            Error_no      => 'none',
414                                                            Rows_affected => 0,
415                                                            Warning_count      => 0,
416                                                            No_good_index_used => 'No',
417                                                            No_index_used      => 'No',
418                                                         },
419                                                      ],
420                                                   );
421                                                   
422                                                   # #############################################################################
423                                                   # Issue 447: MySQLProtocolParser does not handle old password algo or
424                                                   # compressed packets  
425                                                   # #############################################################################
426            1                                 60   $protocol = new MySQLProtocolParser(
427                                                      server => '10.55.200.15',
428                                                   );
429            1                                 49   test_protocol_parser(
430                                                      parser   => $tcpdump,
431                                                      protocol => $protocol,
432                                                      file     => "$sample/tcpdump013.txt",
433                                                      desc     => 'old password and compression',
434                                                      result   => [
435                                                         {  Error_no => 'none',
436                                                            No_good_index_used => 'No',
437                                                            No_index_used => 'No',
438                                                            Query_time => '0.034355',
439                                                            Rows_affected => 0,
440                                                            Thread_id => 36947020,
441                                                            Warning_count => 0,
442                                                            arg => 'administrator command: Connect',
443                                                            bytes => 30,
444                                                            cmd => 'Admin',
445                                                            db => '',
446                                                            host => '10.54.212.171',
447                                                            ip => '10.54.212.171',
448                                                            port => '49663',
449                                                            pos_in_log => 1834,
450                                                            ts => '090603 10:52:24.578817',
451                                                            user => 'luck'
452                                                         },
453                                                      ],
454                                                   );
455                                                   
456                                                   # Check in-stream compression detection.
457            1                                 75   $protocol = new MySQLProtocolParser(
458                                                      server => '10.55.200.15',
459                                                   );
460            1                                 56   test_protocol_parser(
461                                                      parser   => $tcpdump,
462                                                      protocol => $protocol,
463                                                      file     => "$sample/tcpdump014.txt",
464                                                      desc     => 'in-stream compression detection',
465                                                      result   => [
466                                                         {
467                                                            Error_no           => 'none',
468                                                            No_good_index_used => 'No',
469                                                            No_index_used      => 'No',
470                                                            Query_time         => '0.001375',
471                                                            Rows_affected      => 0,
472                                                            Thread_id          => 4294967296,
473                                                            Warning_count      => 0,
474                                                            arg                => 'show databases',
475                                                            bytes              => 14,
476                                                            cmd                => 'Query',
477                                                            db                 => undef,
478                                                            host               => '10.54.212.171',
479                                                            ip                 => '10.54.212.171',
480                                                            port               => '49663',
481                                                            pos_in_log         => 0,
482                                                            ts                 => '090603 10:52:24.587685',
483                                                            user               => undef,
484                                                         },
485                                                      ],
486                                                   );
487                                                   
488                                                   # Check data decompression.
489            1                                 66   $protocol = new MySQLProtocolParser(
490                                                      server => '127.0.0.1',
491                                                      port   => '12345',
492                                                   );
493            1                                 90   test_protocol_parser(
494                                                      parser   => $tcpdump,
495                                                      protocol => $protocol,
496                                                      file     => "$sample/tcpdump015.txt",
497                                                      desc     => 'compressed data',
498                                                      result   => [
499                                                         {
500                                                            Error_no => 'none',
501                                                            No_good_index_used => 'No',
502                                                            No_index_used => 'No',
503                                                            Query_time => '0.006415',
504                                                            Rows_affected => 0,
505                                                            Thread_id => 20,
506                                                            Warning_count => 0,
507                                                            arg => 'administrator command: Connect',
508                                                            bytes => 30,
509                                                            cmd => 'Admin',
510                                                            db => 'mysql',
511                                                            host => '127.0.0.1',
512                                                            ip => '127.0.0.1',
513                                                            port => '44489',
514                                                            pos_in_log => 664,
515                                                            ts => '090612 08:39:05.316805',
516                                                            user => 'msandbox',
517                                                         },
518                                                         {
519                                                            Error_no => 'none',
520                                                            No_good_index_used => 'No',
521                                                            No_index_used => 'Yes',
522                                                            Query_time => '0.002884',
523                                                            Rows_affected => 0,
524                                                            Thread_id => 20,
525                                                            Warning_count => 0,
526                                                            arg => 'select * from help_relation',
527                                                            bytes => 27,
528                                                            cmd => 'Query',
529                                                            db => 'mysql',
530                                                            host => '127.0.0.1',
531                                                            ip => '127.0.0.1',
532                                                            port => '44489',
533                                                            pos_in_log => 1637,
534                                                            ts => '090612 08:39:08.428913',
535                                                            user => 'msandbox',
536                                                         },
537                                                         {
538                                                            Error_no => 'none',
539                                                            No_good_index_used => 'No',
540                                                            No_index_used => 'No',
541                                                            Query_time => '0.000000',
542                                                            Rows_affected => 0,
543                                                            Thread_id => 20,
544                                                            Warning_count => 0,
545                                                            arg => 'administrator command: Quit',
546                                                            bytes => 27,
547                                                            cmd => 'Admin',
548                                                            db => 'mysql',
549                                                            host => '127.0.0.1',
550                                                            ip => '127.0.0.1',
551                                                            port => '44489',
552                                                            pos_in_log => 15782,
553                                                            ts => '090612 08:39:09.145334',
554                                                            user => 'msandbox',
555                                                         },
556                                                      ],
557                                                   );
558                                                   
559                                                   # TCP retransmission.
560                                                   # Check data decompression.
561            1                                 79   $protocol = new MySQLProtocolParser(
562                                                      server => '10.55.200.15',
563                                                   );
564            1                                 41   test_protocol_parser(
565                                                      parser   => $tcpdump,
566                                                      protocol => $protocol,
567                                                      file     => "$sample/tcpdump016.txt",
568                                                      desc     => 'TCP retransmission',
569                                                      result   => [
570                                                         {
571                                                            Error_no => 'none',
572                                                            No_good_index_used => 'No',
573                                                            No_index_used => 'No',
574                                                            Query_time => '0.001000',
575                                                            Rows_affected => 0,
576                                                            Thread_id => 38559282,
577                                                            Warning_count => 0,
578                                                            arg => 'administrator command: Connect',
579                                                            bytes => 30,
580                                                            cmd => 'Admin',
581                                                            db => '',
582                                                            host => '10.55.200.31',
583                                                            ip => '10.55.200.31',
584                                                            port => '64987',
585                                                            pos_in_log => 468,
586                                                            ts => '090609 16:53:17.112346',
587                                                            user => 'ppppadri',
588                                                         },
589                                                      ],
590                                                   );
591                                                   
592                                                   # #############################################################################
593                                                   # Issue 537: MySQLProtocolParser and MemcachedProtocolParser do not handle
594                                                   # multiple servers.
595                                                   # #############################################################################
596            1                                 33   $protocol = new MySQLProtocolParser();
597            1                                 37   test_protocol_parser(
598                                                      parser   => $tcpdump,
599                                                      protocol => $protocol,
600                                                      file     => "$sample/tcpdump018.txt",
601                                                      desc     => 'Multiple servers',
602                                                      result   => [
603                                                         {
604                                                            Error_no => 'none',
605                                                            No_good_index_used => 'No',
606                                                            No_index_used => 'No',
607                                                            Query_time => '0.000206',
608                                                            Rows_affected => 0,
609                                                            Thread_id => '4294967296',
610                                                            Warning_count => 0,
611                                                            arg => 'select * from foo',
612                                                            bytes => 17,
613                                                            cmd => 'Query',
614                                                            db => undef,
615                                                            host => '127.0.0.1',
616                                                            ip => '127.0.0.1',
617                                                            port => '42275',
618                                                            pos_in_log => 0,
619                                                            ts => '090727 08:28:41.723651',
620                                                            user => undef,
621                                                         },
622                                                         {
623                                                            Error_no => 'none',
624                                                            No_good_index_used => 'No',
625                                                            No_index_used => 'No',
626                                                            Query_time => '0.000203',
627                                                            Rows_affected => 0,
628                                                            Thread_id => '4294967297',
629                                                            Warning_count => 0,
630                                                            arg => 'select * from bar',
631                                                            bytes => 17,
632                                                            cmd => 'Query',
633                                                            db => undef,
634                                                            host => '127.0.0.1',
635                                                            ip => '127.0.0.1',
636                                                            port => '34233',
637                                                            pos_in_log => 987,
638                                                            ts => '090727 08:29:34.232748',
639                                                            user => undef,
640                                                         },
641                                                      ],
642                                                   );
643                                                   
644                                                   # Test that --watch-server causes just the given server to be watched.
645            1                                 39   $protocol = new MySQLProtocolParser(server=>'10.0.0.1',port=>'3306');
646            1                                 28   test_protocol_parser(
647                                                      parser   => $tcpdump,
648                                                      protocol => $protocol,
649                                                      file     => "$sample/tcpdump018.txt",
650                                                      desc     => 'Multiple servers but watch only one',
651                                                      result   => [
652                                                         {
653                                                            Error_no => 'none',
654                                                            No_good_index_used => 'No',
655                                                            No_index_used => 'No',
656                                                            Query_time => '0.000206',
657                                                            Rows_affected => 0,
658                                                            Thread_id => '4294967296',
659                                                            Warning_count => 0,
660                                                            arg => 'select * from foo',
661                                                            bytes => 17,
662                                                            cmd => 'Query',
663                                                            db => undef,
664                                                            host => '127.0.0.1',
665                                                            ip => '127.0.0.1',
666                                                            port => '42275',
667                                                            pos_in_log => 0,
668                                                            ts => '090727 08:28:41.723651',
669                                                            user => undef,
670                                                         },
671                                                      ]
672                                                   );
673                                                   
674                                                   
675                                                   # #############################################################################
676                                                   # Issue 558: Make mk-query-digest handle big/fragmented packets
677                                                   # #############################################################################
678            1                                 35   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'12345');
679            1                                 16   my $e = test_protocol_parser(
680                                                      parser   => $tcpdump,
681                                                      protocol => $protocol,
682                                                      file     => "$sample/tcpdump019.txt",
683                                                   );
684                                                   
685            1                                 27   like(
686                                                      $e->[0]->{arg},
687                                                      qr/--THE END--'\)$/,
688                                                      'Handles big, fragmented MySQL packets (issue 558)'
689                                                   );
690                                                   
691            1                                 10   my $arg = load_file("$sample/tcpdump019-arg.txt");
692            1                                 20   chomp $arg;
693            1                                 16   is(
694                                                      $e->[0]->{arg},
695                                                      $arg,
696                                                      'Re-assembled data is correct (issue 558)'
697                                                   );
698                                                   
699                                                   # #############################################################################
700                                                   # Issue 740: Handle prepared statements
701                                                   # #############################################################################
702            1                                 11   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'12345');
703            1                                 54   test_protocol_parser(
704                                                      parser   => $tcpdump,
705                                                      protocol => $protocol,
706                                                      file     => "$sample/tcpdump021.txt",
707                                                      desc     => 'prepared statements, simple, no NULL',
708                                                      result   => [
709                                                         {
710                                                            Error_no => 'none',
711                                                            No_good_index_used => 'No',
712                                                            No_index_used => 'No',
713                                                            Query_time => '0.000286',
714                                                            Rows_affected => 0,
715                                                            Thread_id => '4294967296',
716                                                            Warning_count => 0,
717                                                            arg => 'PREPARE SELECT i FROM d.t WHERE i=?',
718                                                            bytes => 35,
719                                                            cmd => 'Query',
720                                                            db => undef,
721                                                            host => '127.0.0.1',
722                                                            ip => '127.0.0.1',
723                                                            port => '58619',
724                                                            pos_in_log => 0,
725                                                            ts => '091208 09:23:49.637394',
726                                                            user => undef,
727                                                            Statement_id => 2,
728                                                         },
729                                                         {
730                                                            Error_no => 'none',
731                                                            No_good_index_used => 'No',
732                                                            No_index_used => 'Yes',
733                                                            Query_time => '0.000281',
734                                                            Rows_affected => 0,
735                                                            Thread_id => '4294967296',
736                                                            Warning_count => 0,
737                                                            arg => 'EXECUTE SELECT i FROM d.t WHERE i="3"',
738                                                            bytes => 37,
739                                                            cmd => 'Query',
740                                                            db => undef,
741                                                            host => '127.0.0.1',
742                                                            ip => '127.0.0.1',
743                                                            port => '58619',
744                                                            pos_in_log => 1106,
745                                                            ts => '091208 09:23:49.637892',
746                                                            user => undef,
747                                                            Statement_id => 2,
748                                                         },
749                                                         {
750                                                            Error_no => 'none',
751                                                             No_good_index_used => 'No',
752                                                             No_index_used => 'No',
753                                                             Query_time => '0.000000',
754                                                             Rows_affected => 0,
755                                                             Thread_id => '4294967296',
756                                                             Warning_count => 0,
757                                                             arg => 'administrator command: Quit',
758                                                             bytes => 27,
759                                                             cmd => 'Admin',
760                                                             db => undef,
761                                                             host => '127.0.0.1',
762                                                             ip => '127.0.0.1',
763                                                             port => '58619',
764                                                             pos_in_log => 1850,
765                                                             ts => '091208 09:23:49.638381',
766                                                             user => undef
767                                                         },
768                                                      ],
769                                                   );
770                                                   
771            1                                 49   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'12345');
772            1                                 37   test_protocol_parser(
773                                                      parser   => $tcpdump,
774                                                      protocol => $protocol,
775                                                      file     => "$sample/tcpdump022.txt",
776                                                      desc     => 'prepared statements, NULL value',
777                                                      result   => [
778                                                         {
779                                                            Error_no => 'none',
780                                                            No_good_index_used => 'No',
781                                                            No_index_used => 'No',
782                                                            Query_time => '0.000303',
783                                                            Rows_affected => 0,
784                                                            Thread_id => '4294967296',
785                                                            Warning_count => 0,
786                                                            arg => 'PREPARE SELECT i,j FROM d.t2 WHERE i=? AND j=?',
787                                                            bytes => 46,
788                                                            cmd => 'Query',
789                                                            db => undef,
790                                                            host => '127.0.0.1',
791                                                            ip => '127.0.0.1',
792                                                            port => '44545',
793                                                            pos_in_log => 0,
794                                                            ts => '091208 13:41:12.811188',
795                                                            user => undef,
796                                                            Statement_id => 2,
797                                                         },
798                                                         {
799                                                            Error_no => 'none',
800                                                            No_good_index_used => 'No',
801                                                            No_index_used => 'No',
802                                                            Query_time => '0.000186',
803                                                            Rows_affected => 0,
804                                                            Thread_id => '4294967296',
805                                                            Warning_count => 0,
806                                                            arg => 'EXECUTE SELECT i,j FROM d.t2 WHERE i=NULL AND j="5"',
807                                                            bytes => 51,
808                                                            cmd => 'Query',
809                                                            db => undef,
810                                                            host => '127.0.0.1',
811                                                            ip => '127.0.0.1',
812                                                            port => '44545',
813                                                            pos_in_log => 1330,
814                                                            ts => '091208 13:41:12.811591',
815                                                            user => undef,
816                                                            Statement_id => 2,
817                                                         }
818                                                      ],
819                                                   );
820                                                   
821            1                                 44   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'12345');
822            1                                 46   test_protocol_parser(
823                                                      parser   => $tcpdump,
824                                                      protocol => $protocol,
825                                                      file     => "$sample/tcpdump023.txt",
826                                                      desc     => 'prepared statements, string, char and float',
827                                                      result   => [
828                                                         {
829                                                            Error_no => 'none',
830                                                            No_good_index_used => 'No',
831                                                            No_index_used => 'No',
832                                                            Query_time => '0.000315',
833                                                            Rows_affected => 0,
834                                                            Thread_id => '4294967296',
835                                                            Warning_count => 0,
836                                                            arg => 'PREPARE SELECT * FROM d.t3 WHERE v=? OR c=? OR f=?',
837                                                            bytes => 50,
838                                                            cmd => 'Query',
839                                                            db => undef,
840                                                            host => '127.0.0.1',
841                                                            ip => '127.0.0.1',
842                                                            port => '49806',
843                                                            pos_in_log => 0,
844                                                            ts => '091208 14:14:55.951863',
845                                                            user => undef,
846                                                            Statement_id => 2,
847                                                         },
848                                                         {
849                                                            Error_no => 'none',
850                                                            No_good_index_used => 'No',
851                                                            No_index_used => 'No',
852                                                            Query_time => '0.000249',
853                                                            Rows_affected => 0,
854                                                            Thread_id => '4294967296',
855                                                            Warning_count => 0,
856                                                            arg => 'EXECUTE SELECT * FROM d.t3 WHERE v="hello world" OR c="a" OR f="1.23"',
857                                                            bytes => 69,
858                                                            cmd => 'Query',
859                                                            db => undef,
860                                                            host => '127.0.0.1',
861                                                            ip => '127.0.0.1',
862                                                            port => '49806',
863                                                            pos_in_log => 1540,
864                                                            ts => '091208 14:14:55.952344',
865                                                            user => undef,
866                                                            Statement_id => 2,
867                                                         }
868                                                      ],
869                                                   );
870                                                   
871            1                                 41   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'12345');
872            1                                 45   test_protocol_parser(
873                                                      parser   => $tcpdump,
874                                                      protocol => $protocol,
875                                                      file     => "$sample/tcpdump024.txt",
876                                                      desc     => 'prepared statements, all NULL',
877                                                      result   => [
878                                                         {
879                                                            Error_no => 'none',
880                                                            No_good_index_used => 'No',
881                                                            No_index_used => 'No',
882                                                            Query_time => '0.000278',
883                                                            Rows_affected => 0,
884                                                            Thread_id => '4294967296',
885                                                            Warning_count => 0,
886                                                            arg => 'PREPARE SELECT * FROM d.t3 WHERE v=? OR c=? OR f=?',
887                                                            bytes => 50,
888                                                            cmd => 'Query',
889                                                            db => undef,
890                                                            host => '127.0.0.1',
891                                                            ip => '127.0.0.1',
892                                                            port => '32810',
893                                                            pos_in_log => 0,
894                                                            ts => '091208 14:33:13.711351',
895                                                            user => undef,
896                                                            Statement_id => 2,
897                                                         },
898                                                         {
899                                                            Error_no => 'none',
900                                                            No_good_index_used => 'No',
901                                                            No_index_used => 'No',
902                                                            Query_time => '0.000159',
903                                                            Rows_affected => 0,
904                                                            Thread_id => '4294967296',
905                                                            Warning_count => 0,
906                                                            arg => 'EXECUTE SELECT * FROM d.t3 WHERE v=NULL OR c=NULL OR f=NULL',
907                                                            bytes => 59,
908                                                            cmd => 'Query',
909                                                            db => undef,
910                                                            host => '127.0.0.1',
911                                                            ip => '127.0.0.1',
912                                                            port => '32810',
913                                                            pos_in_log => 1540,
914                                                            ts => '091208 14:33:13.711642',
915                                                            user => undef,
916                                                            Statement_id => 2,
917                                                         },
918                                                      ],
919                                                   );
920                                                   
921            1                                 36   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'12345');
922            1                                 39   test_protocol_parser(
923                                                      parser   => $tcpdump,
924                                                      protocol => $protocol,
925                                                      file     => "$sample/tcpdump025.txt",
926                                                      desc     => 'prepared statements, no params',
927                                                      result   => [
928                                                         {
929                                                            Error_no => 'none',
930                                                            No_good_index_used => 'No',
931                                                            No_index_used => 'No',
932                                                            Query_time => '0.000268',
933                                                            Rows_affected => 0,
934                                                            Thread_id => '4294967296',
935                                                            Warning_count => 0,
936                                                            arg => 'PREPARE SELECT * FROM d.t WHERE 1 LIMIT 1;',
937                                                            bytes => 42,
938                                                            cmd => 'Query',
939                                                            db => undef,
940                                                            host => '127.0.0.1',
941                                                            ip => '127.0.0.1',
942                                                            port => '48585',
943                                                            pos_in_log => 0,
944                                                            ts => '091208 14:44:52.709181',
945                                                            user => undef,
946                                                            Statement_id => 2,
947                                                         },
948                                                         {
949                                                            Error_no => 'none',
950                                                            No_good_index_used => 'No',
951                                                            No_index_used => 'Yes',
952                                                            Query_time => '0.000234',
953                                                            Rows_affected => 0,
954                                                            Thread_id => '4294967296',
955                                                            Warning_count => 0,
956                                                            arg => 'EXECUTE SELECT * FROM d.t WHERE 1 LIMIT 1;',
957                                                            bytes => 42,
958                                                            cmd => 'Query',
959                                                            db => undef,
960                                                            host => '127.0.0.1',
961                                                            ip => '127.0.0.1',
962                                                            port => '48585',
963                                                            pos_in_log => 1014,
964                                                            ts => '091208 14:44:52.709597',
965                                                            user => undef,
966                                                            Statement_id => 2,
967                                                         }
968                                                      ],
969                                                   );
970                                                   
971            1                                 39   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'3306');
972            1                                 30   test_protocol_parser(
973                                                      parser   => $tcpdump,
974                                                      protocol => $protocol,
975                                                      file     => "$sample/tcpdump026.txt",
976                                                      desc     => 'prepared statements, close statement',
977                                                      result   => [
978                                                         {
979                                                            Error_no => 'none',
980                                                            No_good_index_used => 'No',
981                                                            No_index_used => 'No',
982                                                            Query_time => '0.000000',
983                                                            Rows_affected => 0,
984                                                            Thread_id => '4294967296',
985                                                            Warning_count => 0,
986                                                            arg => 'DEALLOCATE PREPARE 50',
987                                                            bytes => 21,
988                                                            cmd => 'Query',
989                                                            db => undef,
990                                                            host => '1.2.3.4',
991                                                            ip => '1.2.3.4',
992                                                            port => '34162',
993                                                            pos_in_log => 0,
994                                                            ts => '091208 17:42:12.696547',
995                                                            user => undef
996                                                         }
997                                                      ],
998                                                   );
999                                                   
1000           1                                 32   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'3306');
1001           1                                 26   test_protocol_parser(
1002                                                     parser   => $tcpdump,
1003                                                     protocol => $protocol,
1004                                                     file     => "$sample/tcpdump027.txt",
1005                                                     desc     => 'prepared statements, reset statement',
1006                                                     result   => [
1007                                                        {
1008                                                           Error_no => 'none',
1009                                                           No_good_index_used => 'No',
1010                                                           No_index_used => 'No',
1011                                                           Query_time => '0.000023',
1012                                                           Rows_affected => 0,
1013                                                           Statement_id => 51,
1014                                                           Thread_id => '4294967296',
1015                                                           Warning_count => 0,
1016                                                           arg => 'RESET 51',
1017                                                           bytes => 8,
1018                                                           cmd => 'Query',
1019                                                           db => undef,
1020                                                           host => '1.2.3.4',
1021                                                           ip => '1.2.3.4',
1022                                                           port => '34162',
1023                                                           pos_in_log => 0,
1024                                                           ts => '091208 17:42:12.698093',
1025                                                           user => undef
1026                                                        }
1027                                                     ],
1028                                                  );
1029                                                  
1030           1                                 34   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'12345');
1031           1                                 56   test_protocol_parser(
1032                                                     parser   => $tcpdump,
1033                                                     protocol => $protocol,
1034                                                     file     => "$sample/tcpdump028.txt",
1035                                                     desc     => 'prepared statements, multiple exec, new param',
1036                                                     result => [
1037                                                        {
1038                                                           Error_no => 'none',
1039                                                           No_good_index_used => 'No',
1040                                                           No_index_used => 'No',
1041                                                           Query_time => '0.000292',
1042                                                           Rows_affected => 0,
1043                                                           Statement_id => 2,
1044                                                           Thread_id => '4294967296',
1045                                                           Warning_count => 0,
1046                                                           arg => 'PREPARE SELECT * FROM d.t WHERE i=?',
1047                                                           bytes => 35,
1048                                                           cmd => 'Query',
1049                                                           db => undef,
1050                                                           host => '127.0.0.1',
1051                                                           ip => '127.0.0.1',
1052                                                           port => '38682',
1053                                                           pos_in_log => 0,
1054                                                           ts => '091208 17:35:37.433248',
1055                                                           user => undef
1056                                                        },
1057                                                        {
1058                                                           Error_no => 'none',
1059                                                           No_good_index_used => 'No',
1060                                                           No_index_used => 'Yes',
1061                                                           Query_time => '0.000254',
1062                                                           Rows_affected => 0,
1063                                                           Statement_id => 2,
1064                                                           Thread_id => '4294967296',
1065                                                           Warning_count => 0,
1066                                                           arg => 'EXECUTE SELECT * FROM d.t WHERE i="1"',
1067                                                           bytes => 37,
1068                                                           cmd => 'Query',
1069                                                           db => undef,
1070                                                           host => '127.0.0.1',
1071                                                           ip => '127.0.0.1',
1072                                                           port => '38682',
1073                                                           pos_in_log => 1106,
1074                                                           ts => '091208 17:35:37.433700',
1075                                                           user => undef
1076                                                        },
1077                                                        {
1078                                                           Error_no => 'none',
1079                                                           No_good_index_used => 'No',
1080                                                           No_index_used => 'Yes',
1081                                                           Query_time => '0.000190',
1082                                                           Rows_affected => 0,
1083                                                           Statement_id => 2,
1084                                                           Thread_id => '4294967296',
1085                                                           Warning_count => 0,
1086                                                           arg => 'EXECUTE SELECT * FROM d.t WHERE i="3"',
1087                                                           bytes => 37,
1088                                                           cmd => 'Query',
1089                                                           db => undef,
1090                                                           host => '127.0.0.1',
1091                                                           ip => '127.0.0.1',
1092                                                           port => '38682',
1093                                                           pos_in_log => 1850,
1094                                                           ts => '091208 17:35:37.434303',
1095                                                           user => undef
1096                                                        },
1097                                                        {
1098                                                           Error_no => 'none',
1099                                                           No_good_index_used => 'No',
1100                                                           No_index_used => 'Yes',
1101                                                           Query_time => '0.000166',
1102                                                           Rows_affected => 0,
1103                                                           Statement_id => 2,
1104                                                           Thread_id => '4294967296',
1105                                                           Warning_count => 0,
1106                                                           arg => 'EXECUTE SELECT * FROM d.t WHERE i=NULL',
1107                                                           bytes => 38,
1108                                                           cmd => 'Query',
1109                                                           db => undef,
1110                                                           host => '127.0.0.1',
1111                                                           ip => '127.0.0.1',
1112                                                           port => '38682',
1113                                                           pos_in_log => 2589,
1114                                                           ts => '091208 17:35:37.434708',
1115                                                           user => undef
1116                                                        }
1117                                                     ],
1118                                                  );
1119                                                  
1120           1                                 55   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'12345');
1121           1                                 59   test_protocol_parser(
1122                                                     parser   => $tcpdump,
1123                                                     protocol => $protocol,
1124                                                     file     => "$sample/tcpdump029.txt",
1125                                                     desc     => 'prepared statements, real param types',
1126                                                     result => [
1127                                                        {
1128                                                           Error_no => 'none',
1129                                                           No_good_index_used => 'No',
1130                                                           No_index_used => 'No',
1131                                                           Query_time => '0.000221',
1132                                                           Rows_affected => 0,
1133                                                           Statement_id => 1,
1134                                                           Thread_id => '4294967296',
1135                                                           Warning_count => 0,
1136                                                           arg => 'PREPARE SELECT * FROM d.t WHERE i=? OR u=? OR v=? OR d=? OR f=? OR t > ? OR dt > ?',
1137                                                           bytes => 82,
1138                                                           cmd => 'Query',
1139                                                           db => undef,
1140                                                           host => '127.0.0.1',
1141                                                           ip => '127.0.0.1',
1142                                                           port => '36496',
1143                                                           pos_in_log => 0,
1144                                                           ts => '091209 09:20:59.293775',
1145                                                           user => undef
1146                                                        },
1147                                                        {
1148                                                           Error_no => 'none',
1149                                                           No_good_index_used => 'No',
1150                                                           No_index_used => 'No',
1151                                                           Query_time => '0.000203',
1152                                                           Rows_affected => 0,
1153                                                           Statement_id => 1,
1154                                                           Thread_id => '4294967296',
1155                                                           Warning_count => 0,
1156                                                           arg => 'EXECUTE SELECT * FROM d.t WHERE i=42 OR u=2009 OR v="hello world" OR d=1.23 OR f=4.56 OR t > "2009-12-01" OR dt > "2009-12-01"',
1157                                                           bytes => 126,
1158                                                           cmd => 'Query',
1159                                                           db => undef,
1160                                                           host => '127.0.0.1',
1161                                                           ip => '127.0.0.1',
1162                                                           port => '36496',
1163                                                           pos_in_log => 2109,
1164                                                           ts => '091209 09:20:59.294409',
1165                                                           user => undef
1166                                                        },
1167                                                        {
1168                                                           Error_no => 'none',
1169                                                           No_good_index_used => 'No',
1170                                                           No_index_used => 'No',
1171                                                           Query_time => '0.000000',
1172                                                           Rows_affected => 0,
1173                                                           Thread_id => '4294967296',
1174                                                           Warning_count => 0,
1175                                                           arg => 'DEALLOCATE PREPARE 1',
1176                                                           bytes => 20,
1177                                                           cmd => 'Query',
1178                                                           db => undef,
1179                                                           host => '127.0.0.1',
1180                                                           ip => '127.0.0.1',
1181                                                           port => '36496',
1182                                                           pos_in_log => 3787,
1183                                                           ts => '091209 09:20:59.294926',
1184                                                           user => undef
1185                                                        },
1186                                                        {
1187                                                           Error_no => 'none',
1188                                                           No_good_index_used => 'No',
1189                                                           No_index_used => 'No',
1190                                                           Query_time => '0.000000',
1191                                                           Rows_affected => 0,
1192                                                           Thread_id => '4294967296',
1193                                                           Warning_count => 0,
1194                                                           arg => 'administrator command: Quit',
1195                                                           bytes => 27,
1196                                                           cmd => 'Admin',
1197                                                           db => undef,
1198                                                           host => '127.0.0.1',
1199                                                           ip => '127.0.0.1',
1200                                                           port => '36496',
1201                                                           pos_in_log => 4051,
1202                                                           ts => '091209 09:20:59.295064',
1203                                                           user => undef
1204                                                        },
1205                                                     ]
1206                                                  );
1207                                                  
1208           1                                 66   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'3306');
1209           1                                 33   test_protocol_parser(
1210                                                     parser   => $tcpdump,
1211                                                     protocol => $protocol,
1212                                                     file     => "$sample/tcpdump030.txt",
1213                                                     desc     => 'prepared statements, ok response to execute',
1214                                                     result => [
1215                                                        {
1216                                                           Error_no => 'none',
1217                                                           No_good_index_used => 'No',
1218                                                           No_index_used => 'No',
1219                                                           Query_time => '0.000046',
1220                                                           Rows_affected => 0,
1221                                                           Statement_id => 1,
1222                                                           Thread_id => '4294967296',
1223                                                           Warning_count => 0,
1224                                                           arg => 'PREPARE SET SESSION sql_mode="STRICT_ALL_TABLES"',
1225                                                           bytes => 48,
1226                                                           cmd => 'Query',
1227                                                           db => undef,
1228                                                           host => '1.2.3.24',
1229                                                           ip => '1.2.3.24',
1230                                                           port => '60696',
1231                                                           pos_in_log => 0,
1232                                                           ts => '091210 14:21:16.956302',
1233                                                           user => undef
1234                                                        },
1235                                                        {
1236                                                           Error_no => 'none',
1237                                                           No_good_index_used => 'No',
1238                                                           No_index_used => 'No',
1239                                                           Query_time => '0.000024',
1240                                                           Rows_affected => 0,
1241                                                           Statement_id => 1,
1242                                                           Thread_id => '4294967296',
1243                                                           Warning_count => 0,
1244                                                           arg => 'EXECUTE SET SESSION sql_mode="STRICT_ALL_TABLES"',
1245                                                           bytes => 48,
1246                                                           cmd => 'Query',
1247                                                           db => undef,
1248                                                           host => '1.2.3.24',
1249                                                           ip => '1.2.3.24',
1250                                                           port => '60696',
1251                                                           pos_in_log => 700,
1252                                                           ts => '091210 14:21:16.956446',
1253                                                           user => undef
1254                                                        }
1255                                                     ],
1256                                                  );
1257                                                  
1258           1                                 41   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'3306');
1259           1                                247   test_protocol_parser(
1260                                                     parser   => $tcpdump,
1261                                                     protocol => $protocol,
1262                                                     file     => "$sample/tcpdump034.txt",
1263                                                     desc     => 'prepared statements, NULL bitmap',
1264                                                     result => [
1265                                                        {
1266                                                           Error_no => 'none',
1267                                                           No_good_index_used => 'No',
1268                                                           No_index_used => 'No',
1269                                                           Query_time => '0.000288',
1270                                                           Rows_affected => 0,
1271                                                           Statement_id => 1,
1272                                                           Thread_id => '4294967296',
1273                                                           Warning_count => 0,
1274                                                           arg => 'PREPARE SELECT * FROM d.t WHERE i=? OR u=? OR v=? OR d=? OR f=? OR t > ? OR dt > ? OR i2=? OR i3=? OR i4=?',
1275                                                           bytes => 106,
1276                                                           cmd => 'Query',
1277                                                           db => undef,
1278                                                           host => '127.0.0.1',
1279                                                           ip => '127.0.0.1',
1280                                                           port => '43607',
1281                                                           pos_in_log => 0,
1282                                                           ts => '091224 16:47:24.204501',
1283                                                           user => undef
1284                                                        },
1285                                                        {
1286                                                           Error_no => 'none',
1287                                                           No_good_index_used => 'No',
1288                                                           No_index_used => 'No',
1289                                                           Query_time => '0.000322',
1290                                                           Rows_affected => 0,
1291                                                           Statement_id => 1,
1292                                                           Thread_id => '4294967296',
1293                                                           Warning_count => 0,
1294                                                           arg => 'EXECUTE SELECT * FROM d.t WHERE i=42 OR u=2009 OR v="hello world" OR d=1.23 OR f=4.56 OR t > "2009-12-01" OR dt > "2009-12-01" OR i2=NULL OR i3=NULL OR i4=NULL',
1295                                                           bytes => 159,
1296                                                           cmd => 'Query',
1297                                                           db => undef,
1298                                                           host => '127.0.0.1',
1299                                                           ip => '127.0.0.1',
1300                                                           port => '43607',
1301                                                           pos_in_log => 2748,
1302                                                           ts => '091224 16:47:24.204965',
1303                                                           user => undef
1304                                                        }
1305                                                     ],
1306                                                  );
1307                                                  
1308                                                  # #############################################################################
1309                                                  # Issue 761: mk-query-digest --tcpdump does not handle incomplete packets
1310                                                  # #############################################################################
1311           1                                 52   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'3306');
1312           1                                 36   test_protocol_parser(
1313                                                     parser   => $tcpdump,
1314                                                     protocol => $protocol,
1315                                                     file     => "$sample/tcpdump032.txt",
1316                                                     desc     => 'issue 761',
1317                                                     result => [
1318                                                        {
1319                                                           Error_no => 'none',
1320                                                           No_good_index_used => 'No',
1321                                                           No_index_used => 'No',
1322                                                           Query_time => '0.000431',
1323                                                           Rows_affected => 1,
1324                                                           Thread_id => '4294967296',
1325                                                           Warning_count => 21032,
1326                                                           arg => 'UPDATEDDDDNNNN',
1327                                                           bytes => 14,
1328                                                           cmd => 'Query',
1329                                                           db => undef,
1330                                                           host => '1.2.3.4',
1331                                                           ip => '1.2.3.4',
1332                                                           port => '35957',
1333                                                           pos_in_log => 1768,
1334                                                           ts => '091208 20:54:54.795250',
1335                                                           user => undef
1336                                                        }
1337                                                     ],
1338                                                  );
1339                                                  
1340                                                  # #############################################################################
1341                                                  # Issue 760: mk-query-digest --tcpdump might not get the whole query
1342                                                  # #############################################################################
1343           1                                 38   $protocol = new MySQLProtocolParser(server=>'127.0.0.1',port=>'3306');
1344           1                                 32   test_protocol_parser(
1345                                                     parser   => $tcpdump,
1346                                                     protocol => $protocol,
1347                                                     file     => "$sample/tcpdump031.txt",
1348                                                     desc     => 'issue 760',
1349                                                     result   => [
1350                                                        {
1351                                                           Error_no => 'none',
1352                                                           No_good_index_used => 'No',
1353                                                           No_index_used => 'No',
1354                                                           Query_time => '0.000430',
1355                                                           Rows_affected => 1,
1356                                                           Thread_id => '4294967296',
1357                                                           Warning_count => 21032,
1358                                                           arg => 'UPDATEDDDDNNNN',
1359                                                           bytes => 14,
1360                                                           cmd => 'Query',
1361                                                           db => undef,
1362                                                           host => '1.2.3.4',
1363                                                           ip => '1.2.3.4',
1364                                                           port => '35957',
1365                                                           pos_in_log => 534,
1366                                                           ts => '091207 20:54:54.795250',
1367                                                           user => undef
1368                                                        }
1369                                                     ],
1370                                                  );
1371                                                  
1372                                                  # #############################################################################
1373                                                  # Issue 794: MySQLProtocolParser does not handle client port reuse
1374                                                  # #############################################################################
1375           1                                 39   $protocol = new MySQLProtocolParser();
1376           1                                103   test_protocol_parser(
1377                                                     parser   => $tcpdump,
1378                                                     protocol => $protocol,
1379                                                     file     => "$sample/tcpdump035.txt",
1380                                                     desc     => 'client port reuse (issue 794)',
1381                                                     result   => [
1382                                                        {  ts         => "090412 11:00:13.118191",
1383                                                           db         => 'mysql',
1384                                                           user       => 'msandbox',
1385                                                           host       => '127.0.0.1',
1386                                                           ip         => '127.0.0.1',
1387                                                           port       => '57890',
1388                                                           arg        => 'administrator command: Connect',
1389                                                           Query_time => '0.011152',
1390                                                           Thread_id  => 8,
1391                                                           pos_in_log => 1470,
1392                                                           bytes      => length('administrator command: Connect'),
1393                                                           cmd        => 'Admin',
1394                                                           Error_no   => 'none',
1395                                                           Rows_affected => 0,
1396                                                           Warning_count      => 0,
1397                                                           No_good_index_used => 'No',
1398                                                           No_index_used      => 'No',
1399                                                        },
1400                                                        {  Query_time => '0.000167',
1401                                                           Thread_id  => 8,
1402                                                           arg        => 'select "paris in the the spring" as trick',
1403                                                           bytes      => length('select "paris in the the spring" as trick'),
1404                                                           cmd        => 'Query',
1405                                                           db         => 'mysql',
1406                                                           host       => '127.0.0.1',
1407                                                           ip         => '127.0.0.1',
1408                                                           port       => '57890',
1409                                                           pos_in_log => 2449,
1410                                                           ts         => '090412 11:00:13.119079',
1411                                                           user       => 'msandbox',
1412                                                           Error_no   => 'none',
1413                                                           Rows_affected => 0,
1414                                                           Warning_count      => 0,
1415                                                           No_good_index_used => 'No',
1416                                                           No_index_used      => 'No',
1417                                                        },
1418                                                        {  Query_time => '0.000000',
1419                                                           Thread_id  => 8,
1420                                                           arg        => 'administrator command: Quit',
1421                                                           bytes      => 27,
1422                                                           cmd        => 'Admin',
1423                                                           db         => 'mysql',
1424                                                           host       => '127.0.0.1',
1425                                                           ip         => '127.0.0.1',
1426                                                           port       => '57890',
1427                                                           pos_in_log => 3337,
1428                                                           ts         => '090412 11:00:13.119487',
1429                                                           user       => 'msandbox',
1430                                                           Error_no   => 'none',
1431                                                           Rows_affected => 0,
1432                                                           Warning_count      => 0,
1433                                                           No_good_index_used => 'No',
1434                                                           No_index_used      => 'No',
1435                                                        },
1436                                                        # port reused...      
1437                                                        {  ts => '090412 12:00:00.800000',
1438                                                           Error_no => 'none',
1439                                                           No_good_index_used => 'No',
1440                                                           No_index_used => 'No',
1441                                                           Query_time => '0.700000',
1442                                                           Rows_affected => 0,
1443                                                           Thread_id => 8,
1444                                                           Warning_count => 0,
1445                                                           arg => 'administrator command: Connect',
1446                                                           bytes => 30,
1447                                                           cmd => 'Admin',
1448                                                           db => 'mysql',
1449                                                           host => '127.0.0.1',
1450                                                           ip => '127.0.0.1',
1451                                                           port => '57890',
1452                                                           pos_in_log => 5791,
1453                                                           user => 'msandbox',
1454                                                        },
1455                                                        {  ts => '090412 12:00:01.000000',
1456                                                           Error_no => 'none',
1457                                                           No_good_index_used => 'No',
1458                                                           No_index_used => 'No',
1459                                                           Query_time => '0.100000',
1460                                                           Rows_affected => 0,
1461                                                           Thread_id => 8,
1462                                                           Warning_count => 0,
1463                                                           arg => 'select "paris in the the spring" as trick',
1464                                                           bytes => 41,
1465                                                           cmd => 'Query',
1466                                                           db => 'mysql',
1467                                                           host => '127.0.0.1',
1468                                                           ip => '127.0.0.1',
1469                                                           port => '57890',
1470                                                           pos_in_log => 6770, 
1471                                                           user => 'msandbox',
1472                                                        },
1473                                                        {  ts => '090412 12:00:01.100000',
1474                                                           Error_no => 'none',
1475                                                           No_good_index_used => 'No',
1476                                                           No_index_used => 'No',
1477                                                           Query_time => '0.000000',
1478                                                           Rows_affected => 0,
1479                                                           Thread_id => 8,
1480                                                           Warning_count => 0,
1481                                                           arg => 'administrator command: Quit',
1482                                                           bytes => 27,
1483                                                           cmd => 'Admin',
1484                                                           db => 'mysql',
1485                                                           host => '127.0.0.1',
1486                                                           ip => '127.0.0.1',
1487                                                           port => '57890',
1488                                                           pos_in_log => 7658,
1489                                                           user => 'msandbox',
1490                                                        }
1491                                                     ],
1492                                                  );
1493                                                  
1494           1                                 72   $protocol = new MySQLProtocolParser();
1495           1                                 58   test_protocol_parser(
1496                                                     parser   => $tcpdump,
1497                                                     protocol => $protocol,
1498                                                     file     => "$sample/tcpdump036.txt",
1499                                                     desc     => 'Houdini data (issue 794)',
1500                                                     result   => [
1501                                                        {  ts         => "090412 11:00:13.118191",
1502                                                           db         => 'mysql',
1503                                                           user       => 'msandbox',
1504                                                           host       => '127.0.0.1',
1505                                                           ip         => '127.0.0.1',
1506                                                           port       => '57890',
1507                                                           arg        => 'administrator command: Connect',
1508                                                           Query_time => '0.011152',
1509                                                           Thread_id  => 8,
1510                                                           pos_in_log => 1470,
1511                                                           bytes      => length('administrator command: Connect'),
1512                                                           cmd        => 'Admin',
1513                                                           Error_no   => 'none',
1514                                                           Rows_affected => 0,
1515                                                           Warning_count      => 0,
1516                                                           No_good_index_used => 'No',
1517                                                           No_index_used      => 'No',
1518                                                        },
1519                                                        # port reused...      
1520                                                        {  ts => '090412 12:00:00.800000',
1521                                                           Error_no => 'none',
1522                                                           No_good_index_used => 'No',
1523                                                           No_index_used => 'No',
1524                                                           Query_time => '0.700000',
1525                                                           Rows_affected => 0,
1526                                                           Thread_id => 8,
1527                                                           Warning_count => 0,
1528                                                           arg => 'administrator command: Connect',
1529                                                           bytes => 30,
1530                                                           cmd => 'Admin',
1531                                                           db => 'mysql',
1532                                                           host => '127.0.0.1',
1533                                                           ip => '127.0.0.1',
1534                                                           port => '57890',
1535                                                           pos_in_log => 4161,
1536                                                           user => 'msandbox',
1537                                                        },
1538                                                        {  ts => '090412 12:00:01.000000',
1539                                                           Error_no => 'none',
1540                                                           No_good_index_used => 'No',
1541                                                           No_index_used => 'No',
1542                                                           Query_time => '0.100000',
1543                                                           Rows_affected => 0,
1544                                                           Thread_id => 8,
1545                                                           Warning_count => 0,
1546                                                           arg => 'select "paris in the the spring" as trick',
1547                                                           bytes => 41,
1548                                                           cmd => 'Query',
1549                                                           db => 'mysql',
1550                                                           host => '127.0.0.1',
1551                                                           ip => '127.0.0.1',
1552                                                           port => '57890',
1553                                                           pos_in_log => 5140,
1554                                                           user => 'msandbox',
1555                                                        },
1556                                                        {  ts => '090412 12:00:01.100000',
1557                                                           Error_no => 'none',
1558                                                           No_good_index_used => 'No',
1559                                                           No_index_used => 'No',
1560                                                           Query_time => '0.000000',
1561                                                           Rows_affected => 0,
1562                                                           Thread_id => 8,
1563                                                           Warning_count => 0,
1564                                                           arg => 'administrator command: Quit',
1565                                                           bytes => 27,
1566                                                           cmd => 'Admin',
1567                                                           db => 'mysql',
1568                                                           host => '127.0.0.1',
1569                                                           ip => '127.0.0.1',
1570                                                           port => '57890',
1571                                                           pos_in_log => 6028,
1572                                                           user => 'msandbox',
1573                                                        }
1574                                                     ],
1575                                                  );
1576                                                  
1577           1                                 52   $protocol = new MySQLProtocolParser();
1578           1                                 36   test_protocol_parser(
1579                                                     parser   => $tcpdump,
1580                                                     protocol => $protocol,
1581                                                     file     => "$sample/tcpdump037.txt",
1582                                                     desc     => 'no server ok (issue 794)',
1583                                                     result   => [
1584                                                        {  ts => '090412 12:00:01.000000',
1585                                                           Error_no => 'none',
1586                                                           No_good_index_used => 'No',
1587                                                           No_index_used => 'No',
1588                                                           Query_time => '0.000000',
1589                                                           Rows_affected => 0,
1590                                                           Thread_id => '4294967296',
1591                                                           Warning_count => 0,
1592                                                           arg => 'administrator command: Quit',
1593                                                           bytes => 27,
1594                                                           cmd => 'Admin',
1595                                                           db => undef,
1596                                                           host => '127.0.0.1',
1597                                                           ip => '127.0.0.1',
1598                                                           port => '57890',
1599                                                           pos_in_log => 390,
1600                                                           user => undef
1601                                                        },
1602                                                        {  ts => '090412 12:00:03.000000',
1603                                                           Error_no => 'none',
1604                                                           No_good_index_used => 'No',
1605                                                           No_index_used => 'No',
1606                                                           Query_time => '1.000000',
1607                                                           Rows_affected => 0,
1608                                                           Thread_id => 4294967297,
1609                                                           Warning_count => 0,
1610                                                           arg => 'select "paris in the the spring" as trick',
1611                                                           bytes => 41,
1612                                                           cmd => 'Query',
1613                                                           db => undef,
1614                                                           host => '127.0.0.1',
1615                                                           ip => '127.0.0.1',
1616                                                           port => '57890',
1617                                                           pos_in_log => 646,
1618                                                           user => undef,
1619                                                        },
1620                                                     ],
1621                                                  );
1622                                                  
1623                                                  # #############################################################################
1624                                                  # Issue 832: mk-query-digest tcpdump crashes on successive, fragmented
1625                                                  # client query
1626                                                  # #############################################################################
1627           1                                 40   $protocol = new MySQLProtocolParser(server => '127.0.0.1',port=>'12345');
1628           1                                 16   $e = test_protocol_parser(
1629                                                     parser   => $tcpdump,
1630                                                     protocol => $protocol,
1631                                                     file     => "$sample/tcpdump038.txt",
1632                                                  );
1633                                                  
1634           1                                 37   like(
1635                                                     $e->[0]->{arg},
1636                                                     qr/--THE END--'\)$/,
1637                                                     '2nd, fragmented client query (issue 832)',
1638                                                  );
1639                                                  
1640                                                  # #############################################################################
1641                                                  # Done.
1642                                                  # #############################################################################
1643           1                                  3   exit;


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
---------- ----- ------------------------
BEGIN          1 MySQLProtocolParser.t:10
BEGIN          1 MySQLProtocolParser.t:11
BEGIN          1 MySQLProtocolParser.t:12
BEGIN          1 MySQLProtocolParser.t:14
BEGIN          1 MySQLProtocolParser.t:15
BEGIN          1 MySQLProtocolParser.t:16
BEGIN          1 MySQLProtocolParser.t:4 
BEGIN          1 MySQLProtocolParser.t:9 


