---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/MySQLProtocolParser.pm   78.2   61.1   61.4   89.7    n/a  100.0   72.6
Total                          78.2   61.1   61.4   89.7    n/a  100.0   72.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:19 2009
Finish:       Sat Aug 29 15:03:20 2009

/home/daniel/dev/maatkit/common/MySQLProtocolParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2009 Percona Inc.
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
18                                                    # MySQLProtocolParser package $Revision: 4523 $
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
38             1                    1             8   use strict;
               1                                  2   
               1                                  7   
39             1                    1             5   use warnings FATAL => 'all';
               1                                 14   
               1                                  6   
40             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  6   
41                                                    
42                                                    eval {
43                                                       require IO::Uncompress::Inflate;
44                                                       IO::Uncompress::Inflate->import(qw(inflate $InflateError));
45                                                    };
46                                                    
47             1                    1             7   use Data::Dumper;
               1                                  3   
               1                                  9   
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
59                                                       parse_server_handshake_packet
60                                                       parse_client_handshake_packet
61                                                       parse_com_packet
62                                                       parse_flags
63                                                    );
64                                                    
65             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
66                                                    use constant {
67             1                                 29      COM_SLEEP               => '00',
68                                                       COM_QUIT                => '01',
69                                                       COM_INIT_DB             => '02',
70                                                       COM_QUERY               => '03',
71                                                       COM_FIELD_LIST          => '04',
72                                                       COM_CREATE_DB           => '05',
73                                                       COM_DROP_DB             => '06',
74                                                       COM_REFRESH             => '07',
75                                                       COM_SHUTDOWN            => '08',
76                                                       COM_STATISTICS          => '09',
77                                                       COM_PROCESS_INFO        => '0a',
78                                                       COM_CONNECT             => '0b',
79                                                       COM_PROCESS_KILL        => '0c',
80                                                       COM_DEBUG               => '0d',
81                                                       COM_PING                => '0e',
82                                                       COM_TIME                => '0f',
83                                                       COM_DELAYED_INSERT      => '10',
84                                                       COM_CHANGE_USER         => '11',
85                                                       COM_BINLOG_DUMP         => '12',
86                                                       COM_TABLE_DUMP          => '13',
87                                                       COM_CONNECT_OUT         => '14',
88                                                       COM_REGISTER_SLAVE      => '15',
89                                                       COM_STMT_PREPARE        => '16',
90                                                       COM_STMT_EXECUTE        => '17',
91                                                       COM_STMT_SEND_LONG_DATA => '18',
92                                                       COM_STMT_CLOSE          => '19',
93                                                       COM_STMT_RESET          => '1a',
94                                                       COM_SET_OPTION          => '1b',
95                                                       COM_STMT_FETCH          => '1c',
96                                                       SERVER_QUERY_NO_GOOD_INDEX_USED => 16,
97                                                       SERVER_QUERY_NO_INDEX_USED      => 32,
98             1                    1             6   };
               1                                  2   
99                                                    
100                                                   my %com_for = (
101                                                      '00' => 'COM_SLEEP',
102                                                      '01' => 'COM_QUIT',
103                                                      '02' => 'COM_INIT_DB',
104                                                      '03' => 'COM_QUERY',
105                                                      '04' => 'COM_FIELD_LIST',
106                                                      '05' => 'COM_CREATE_DB',
107                                                      '06' => 'COM_DROP_DB',
108                                                      '07' => 'COM_REFRESH',
109                                                      '08' => 'COM_SHUTDOWN',
110                                                      '09' => 'COM_STATISTICS',
111                                                      '0a' => 'COM_PROCESS_INFO',
112                                                      '0b' => 'COM_CONNECT',
113                                                      '0c' => 'COM_PROCESS_KILL',
114                                                      '0d' => 'COM_DEBUG',
115                                                      '0e' => 'COM_PING',
116                                                      '0f' => 'COM_TIME',
117                                                      '10' => 'COM_DELAYED_INSERT',
118                                                      '11' => 'COM_CHANGE_USER',
119                                                      '12' => 'COM_BINLOG_DUMP',
120                                                      '13' => 'COM_TABLE_DUMP',
121                                                      '14' => 'COM_CONNECT_OUT',
122                                                      '15' => 'COM_REGISTER_SLAVE',
123                                                      '16' => 'COM_STMT_PREPARE',
124                                                      '17' => 'COM_STMT_EXECUTE',
125                                                      '18' => 'COM_STMT_SEND_LONG_DATA',
126                                                      '19' => 'COM_STMT_CLOSE',
127                                                      '1a' => 'COM_STMT_RESET',
128                                                      '1b' => 'COM_SET_OPTION',
129                                                      '1c' => 'COM_STMT_FETCH',
130                                                   );
131                                                   
132                                                   my %flag_for = (
133                                                      'CLIENT_LONG_PASSWORD'     => 1,       # new more secure passwords 
134                                                      'CLIENT_FOUND_ROWS'        => 2,       # Found instead of affected rows 
135                                                      'CLIENT_LONG_FLAG'         => 4,       # Get all column flags 
136                                                      'CLIENT_CONNECT_WITH_DB'   => 8,       # One can specify db on connect 
137                                                      'CLIENT_NO_SCHEMA'         => 16,      # Don't allow database.table.column 
138                                                      'CLIENT_COMPRESS'          => 32,      # Can use compression protocol 
139                                                      'CLIENT_ODBC'              => 64,      # Odbc client 
140                                                      'CLIENT_LOCAL_FILES'       => 128,     # Can use LOAD DATA LOCAL 
141                                                      'CLIENT_IGNORE_SPACE'      => 256,     # Ignore spaces before '(' 
142                                                      'CLIENT_PROTOCOL_41'       => 512,     # New 4.1 protocol 
143                                                      'CLIENT_INTERACTIVE'       => 1024,    # This is an interactive client 
144                                                      'CLIENT_SSL'               => 2048,    # Switch to SSL after handshake 
145                                                      'CLIENT_IGNORE_SIGPIPE'    => 4096,    # IGNORE sigpipes 
146                                                      'CLIENT_TRANSACTIONS'      => 8192,    # Client knows about transactions 
147                                                      'CLIENT_RESERVED'          => 16384,   # Old flag for 4.1 protocol  
148                                                      'CLIENT_SECURE_CONNECTION' => 32768,   # New 4.1 authentication 
149                                                      'CLIENT_MULTI_STATEMENTS'  => 65536,   # Enable/disable multi-stmt support 
150                                                      'CLIENT_MULTI_RESULTS'     => 131072,  # Enable/disable multi-results 
151                                                   );
152                                                   
153                                                   # server is the "host:port" of the sever being watched.  It's auto-guessed if
154                                                   # not specified.  version is a placeholder for handling differences between
155                                                   # MySQL v4.0 and older and v4.1 and newer.  Currently, we only handle v4.1.
156                                                   sub new {
157           15                   15           662      my ( $class, %args ) = @_;
158                                                   
159           15    100                         129      my ( $server_port )
160                                                         = $args{server} ? $args{server} =~ m/:(\w+)/ : ('3306|mysql');
161   ***     15            50                   65      $server_port ||= '3306|mysql';  # In case $args{server} doesn't have a port.
162                                                   
163           15                                146      my $self = {
164                                                         server         => $args{server},
165                                                         server_port    => $server_port,
166                                                         version        => '41',    # MySQL proto version; not used yet
167                                                         sessions       => {},
168                                                         o              => $args{o},
169                                                         fake_thread_id => 2**32,   # see _make_event()
170                                                      };
171           15                                 47      MKDEBUG && $self->{server} && _d('Watching only server', $self->{server});
172           15                                106      return bless $self, $class;
173                                                   }
174                                                   
175                                                   # The packet arg should be a hashref from TcpdumpParser::parse_event().
176                                                   # misc is a placeholder for future features.
177                                                   sub parse_packet {
178           99                   99          1229      my ( $self, $packet, $misc ) = @_;
179                                                   
180           99                                479      my $src_host = "$packet->{src_host}:$packet->{src_port}";
181           99                                438      my $dst_host = "$packet->{dst_host}:$packet->{dst_port}";
182                                                   
183           99    100                         459      if ( my $server = $self->{server} ) {  # Watch only the given server.
184           49    100    100                  370         if ( $src_host ne $server && $dst_host ne $server ) {
185            3                                  7            MKDEBUG && _d('Packet is not to or from', $server);
186            3                                 18            return;
187                                                         }
188                                                      }
189                                                   
190                                                      # Auto-detect the server by looking for port 3306 or port "mysql" (sometimes
191                                                      # tcpdump will substitute the port by a lookup in /etc/protocols).
192           96                                212      my $packet_from;
193           96                                218      my $client;
194           96    100                        1110      if ( $src_host =~ m/:$self->{server_port}$/ ) {
      ***            50                               
195           43                                117         $packet_from = 'server';
196           43                                113         $client      = $dst_host;
197                                                      }
198                                                      elsif ( $dst_host =~ m/:$self->{server_port}$/ ) {
199           53                                150         $packet_from = 'client';
200           53                                170         $client      = $src_host;
201                                                      }
202                                                      else {
203   ***      0                                  0         warn 'Packet is not to or from MySQL server: ', Dumper($packet);
204   ***      0                                  0         return;
205                                                      }
206           96                                205      MKDEBUG && _d('Client:', $client);
207                                                   
208                                                      # Get the client's session info or create a new session if the
209                                                      # client hasn't been seen before.
210           96    100                         473      if ( !exists $self->{sessions}->{$client} ) {
211           16                                 38         MKDEBUG && _d('New session');
212           16                                175         $self->{sessions}->{$client} = {
213                                                            client      => $client,
214                                                            ts          => $packet->{ts},
215                                                            state       => undef,
216                                                            compress    => undef,
217                                                            raw_packets => [],
218                                                            buff        => '',
219                                                         };
220                                                      };
221           96                                365      my $session = $self->{sessions}->{$client};
222                                                   
223                                                      # Return early if there's TCP/MySQL data.  These are usually ACK
224                                                      # packets, but they could also be FINs in which case, we should close
225                                                      # and delete the client's session.
226           96    100                         415      if ( $packet->{data_len} == 0 ) {
227           44                                102         MKDEBUG && _d('No TCP/MySQL data');
228                                                         # Is the session ready to close?
229   ***     44     50    100                  350         if ( ($session->{state} || '') eq 'closing' ) {
230   ***      0                                  0            delete $self->{sessions}->{$session->{client}};
231   ***      0                                  0            MKDEBUG && _d('Session deleted'); 
232                                                         }
233           44                                281         return;
234                                                      }
235                                                   
236                                                      # Save raw packets to dump later in case something fails.
237           52                                128      push @{$session->{raw_packets}}, $packet->{raw_packet};
              52                                363   
238                                                   
239                                                      # Return unless the compressed packet can be uncompressed.
240                                                      # If it cannot, then we're helpless and must return.
241           52    100                         218      if ( $session->{compress} ) {
242   ***      5     50                          23         return unless $self->uncompress_packet($packet, $session);
243                                                      }
244                                                   
245   ***     52    100     66                  269      if ( $session->{buff} && $packet_from eq 'client' ) {
246                                                         # Previous packets were not complete so append this data
247                                                         # to what we've been buffering.  Afterwards, do *not* attempt
248                                                         # to remove_mysql_header() because it was already done (for
249                                                         # the first packet).
250            1                                 29         $packet->{data}        = $session->{buff} . $packet->{data};
251            1                                  4         $session->{buff_left} -= $packet->{data_len};
252                                                   
253                                                         # We didn't remove_mysql_header(), so mysql_data_len isn't set.
254                                                         # So set it to the real, complete data len (from the first
255                                                         # packet's MySQL header).
256            1                                  6         $packet->{mysql_data_len} = $session->{mysql_data_len};
257                                                   
258            1                                  3         MKDEBUG && _d('Appending data to buff; expecting',
259                                                            $session->{buff_left}, 'more bytes');
260                                                      }
261                                                      else { 
262                                                         # Remove the first MySQL header.  A single TCP packet can contain many
263                                                         # MySQL packets, but we only look at the first.  The 2nd and subsequent
264                                                         # packets are usually parts of a resultset returned by the server, but
265                                                         # we're not interested in resultsets.
266           51                                142         eval {
267           51                                212            remove_mysql_header($packet);
268                                                         };
269   ***     51     50                         200         if ( $EVAL_ERROR ) {
270   ***      0                                  0            MKDEBUG && _d('remove_mysql_header() failed; failing session');
271   ***      0                                  0            $session->{EVAL_ERROR} = $EVAL_ERROR;
272   ***      0                                  0            $self->fail_session($session, 'remove_mysql_header() failed');
273   ***      0                                  0            return;
274                                                         }
275                                                      }
276                                                   
277                                                      # Finally, parse the packet and maybe create an event.
278                                                      # The returned event may be empty if no event was ready to be created.
279           52                                115      my $event;
280           52    100                         238      if ( $packet_from eq 'server' ) {
      ***            50                               
281           26                                128         $event = $self->_packet_from_server($packet, $session, $misc);
282                                                      }
283                                                      elsif ( $packet_from eq 'client' ) {
284   ***     26    100     66                  215         if ( $session->{buff} && $session->{buff_left} <= 0 ) {
                    100                               
285            1                                  3            MKDEBUG && _d('Data is complete');
286                                                         }
287                                                         elsif ( $packet->{mysql_data_len} > $packet->{data_len} ) {
288                                                            # There is more MySQL data than this packet contains.
289                                                            # Save the data and wait for more packets.
290            1                                  5            $session->{mysql_data_len} = $packet->{mysql_data_len};
291            1                                 49            $session->{buff}           = $packet->{data};
292                                                            
293                                                            # Do this just once here.  For the next packets, buff_left
294                                                            # will be decremented above.
295   ***      1            50                   10            $session->{buff_left}
296                                                               ||= $packet->{mysql_data_len} - $packet->{data_len};
297                                                   
298            1                                  2            MKDEBUG && _d('Data not complete; expecting',
299                                                               $session->{buff_left}, 'more bytes');
300            1                                 10            return;
301                                                         }
302           25                                112         $event = $self->_packet_from_client($packet, $session, $misc);
303                                                   
304           25                                 89         $session->{buff}           = '';
305           25                                 89         $session->{buff_left}      = 0;
306           25                                 84         $session->{mysql_data_len} = 0;
307                                                      }
308                                                      else {
309                                                         # Should not get here.
310   ***      0                                  0         die 'Packet origin unknown';
311                                                      }
312                                                   
313           51                                127      MKDEBUG && _d('Done parsing packet; client state:', $session->{state});
314           51                                433      return $event;
315                                                   }
316                                                   
317                                                   # Handles a packet from the server given the state of the session.
318                                                   # The server can send back a lot of different stuff, but luckily
319                                                   # we're only interested in
320                                                   #    * Connection handshake packets for the thread_id
321                                                   #    * OK and Error packets for errors, warnings, etc.
322                                                   # Anything else is ignored.  Returns an event if one was ready to be
323                                                   # created, otherwise returns nothing.
324                                                   sub _packet_from_server {
325           26                   26           124      my ( $self, $packet, $session, $misc ) = @_;
326   ***     26     50                         101      die "I need a packet"  unless $packet;
327   ***     26     50                          94      die "I need a session" unless $session;
328                                                   
329           26                                 60      MKDEBUG && _d('Packet is from server; client state:', $session->{state}); 
330                                                   
331   ***     26     50    100                  248      if ( ($session->{server_seq} || '') eq $packet->{seq} ) {
332   ***      0                                  0         push @{ $session->{server_retransmissions} }, $packet->{seq};
      ***      0                                  0   
333   ***      0                                  0         MKDEBUG && _d('TCP retransmission');
334   ***      0                                  0         return;
335                                                      }
336           26                                113      $session->{server_seq} = $packet->{seq};
337                                                   
338           26                                 96      my $data = $packet->{data};
339                                                   
340                                                      # The first byte in the packet indicates whether it's an OK,
341                                                      # ERROR, EOF packet.  If it's not one of those, we test
342                                                      # whether it's an initialization packet (the first thing the
343                                                      # server ever sends the client).  If it's not that, it could
344                                                      # be a result set header, field, row data, etc.
345                                                   
346           26                                110      my ( $first_byte ) = substr($data, 0, 2, '');
347           26                                 56      MKDEBUG && _d('First byte of packet:', $first_byte);
348   ***     26     50                          99      if ( !$first_byte ) {
349   ***      0                                  0         $self->fail_session($session, 'no first byte');
350   ***      0                                  0         return;
351                                                      }
352                                                   
353                                                      # If there's no session state, then we're catching a server response
354                                                      # mid-stream.  It's only safe to wait until the client sends a command
355                                                      # or to look for the server handshake.
356           26    100                         106      if ( !$session->{state} ) {
357   ***      5     50     33                   74         if ( $first_byte eq '0a' && length $data >= 33 && $data =~ m/00{13}/ ) {
      ***                   33                        
358                                                            # It's the handshake packet from the server to the client.
359                                                            # 0a is protocol v10 which is essentially the only version used
360                                                            # today.  33 is the minimum possible length for a valid server
361                                                            # handshake packet.  It's probably a lot longer.  Other packets
362                                                            # may start with 0a, but none that can would be >= 33.  The 13-byte
363                                                            # 00 scramble buffer is another indicator.
364            5                                 25            my $handshake = parse_server_handshake_packet($data);
365   ***      5     50                          25            if ( !$handshake ) {
366   ***      0                                  0               $self->fail_session($session, 'failed to parse server handshake');
367   ***      0                                  0               return;
368                                                            }
369            5                                 26            $session->{state}     = 'server_handshake';
370            5                                 40            $session->{thread_id} = $handshake->{thread_id};
371                                                         }
372                                                         else {
373   ***      0                                  0            MKDEBUG && _d('Ignoring mid-stream server response');
374   ***      0                                  0            return;
375                                                         }
376                                                      }
377                                                      else {
378   ***     21    100     66                  153         if ( $first_byte eq '00' ) { 
                    100                               
                    100                               
379   ***      8    100     50                   60            if ( ($session->{state} || '') eq 'client_auth' ) {
      ***            50                               
380                                                               # We logged in OK!  Trigger an admin Connect command.
381                                                   
382            4                                 17               $session->{compress} = $session->{will_compress};
383            4                                 18               delete $session->{will_compress};
384            4                                  9               MKDEBUG && $session->{compress} && _d('Packets will be compressed');
385                                                   
386            4                                 10               MKDEBUG && _d('Admin command: Connect');
387            4                                 34               return $self->_make_event(
388                                                                  {  cmd => 'Admin',
389                                                                     arg => 'administrator command: Connect',
390                                                                     ts  => $packet->{ts}, # Events are timestamped when they end
391                                                                  },
392                                                                  $packet, $session
393                                                               );
394                                                            }
395                                                            elsif ( $session->{cmd} ) {
396                                                               # This OK should be ack'ing a query or something sent earlier
397                                                               # by the client.
398            4                                 18               my $ok  = parse_ok_packet($data);
399   ***      4     50                          22               if ( !$ok ) {
400   ***      0                                  0                  $self->fail_session($session, 'failed to parse OK packet');
401   ***      0                                  0                  return;
402                                                               }
403            4                                 16               my $com = $session->{cmd}->{cmd};
404            4                                 12               my $arg;
405                                                   
406   ***      4     50                          16               if ( $com eq COM_QUERY ) {
407            4                                 10                  $com = 'Query';
408            4                                 22                  $arg = $session->{cmd}->{arg};
409                                                               }
410                                                               else {
411   ***      0                                  0                  $arg = 'administrator command: '
412                                                                       . ucfirst(lc(substr($com_for{$com}, 4)));
413   ***      0                                  0                  $com = 'Admin';
414                                                               }
415                                                   
416            4                                 53               return $self->_make_event(
417                                                                  {  cmd           => $com,
418                                                                     arg           => $arg,
419                                                                     ts            => $packet->{ts},
420                                                                     Insert_id     => $ok->{insert_id},
421                                                                     Warning_count => $ok->{warnings},
422                                                                     Rows_affected => $ok->{affected_rows},
423                                                                  },
424                                                                  $packet, $session
425                                                               );
426                                                            } 
427                                                            else {
428   ***      0                                  0               MKDEBUG && _d('Looks like an OK packet but session has no cmd');
429                                                            }
430                                                         }
431                                                         elsif ( $first_byte eq 'ff' ) {
432            2                                 10            my $error = parse_error_packet($data);
433   ***      2     50                           9            if ( !$error ) {
434   ***      0                                  0               $self->fail_session($session, 'failed to parse error packet');
435   ***      0                                  0               return;
436                                                            }
437            2                                  6            my $event;
438                                                   
439            2    100                          14            if ( $session->{state} eq 'client_auth' ) {
      ***            50                               
440            1                                  2               MKDEBUG && _d('Connection failed');
441   ***      1     50                          10               $event = {
442                                                                  cmd       => 'Admin',
443                                                                  arg       => 'administrator command: Connect',
444                                                                  ts        => $packet->{ts},
445                                                                  Error_no  => $error->{errno} ? "#$error->{errno}" : 'none',
446                                                               };
447            1                                  6               return $self->_make_event($event, $packet, $session);
448   ***      0                                  0               $session->{state} = 'closing';
449                                                            }
450                                                            elsif ( $session->{cmd} ) {
451                                                               # This error should be in response to a query or something
452                                                               # sent earlier by the client.
453            1                                  4               my $com = $session->{cmd}->{cmd};
454            1                                  3               my $arg;
455                                                   
456   ***      1     50                           4               if ( $com eq COM_QUERY ) {
457            1                                  3                  $com = 'Query';
458            1                                  4                  $arg = $session->{cmd}->{arg};
459                                                               }
460                                                               else {
461   ***      0                                  0                  $arg = 'administrator command: '
462                                                                       . ucfirst(lc(substr($com_for{$com}, 4)));
463   ***      0                                  0                  $com = 'Admin';
464                                                               }
465                                                   
466   ***      1     50                          10               $event = {
467                                                                  cmd       => $com,
468                                                                  arg       => $arg,
469                                                                  ts        => $packet->{ts},
470                                                                  Error_no  => $error->{errno} ? "#$error->{errno}" : 'none',
471                                                               };
472            1                                  5               return $self->_make_event($event, $packet, $session);
473                                                            }
474                                                            else {
475   ***      0                                  0               MKDEBUG && _d('Looks like an error packet but client is not '
476                                                                  . 'authenticating and session has no cmd');
477                                                            }
478                                                         }
479                                                         elsif ( $first_byte eq 'fe' && $packet->{mysql_data_len} < 9 ) {
480                                                            # EOF packet
481   ***      1     50     33                   17            if ( $packet->{mysql_data_len} == 1
      ***                   33                        
482                                                                 && $session->{state} eq 'client_auth'
483                                                                 && $packet->{number} == 2 )
484                                                            {
485            1                                  4               MKDEBUG && _d('Server has old password table;',
486                                                                  'client will resend password using old algorithm');
487            1                                  4               $session->{state} = 'client_auth_resend';
488                                                            }
489                                                            else {
490   ***      0                                  0               MKDEBUG && _d('Got an EOF packet');
491   ***      0                                  0               die "Got an unexpected EOF packet";
492                                                               # ^^^ We shouldn't reach this because EOF should come after a
493                                                               # header, field, or row data packet; and we should be firing the
494                                                               # event and returning when we see that.  See SVN history for some
495                                                               # good stuff we could do if we wanted to handle EOF packets.
496                                                            }
497                                                         }
498                                                         else {
499                                                            # Since we do NOT always have all the data the server sent to the
500                                                            # client, we can't always do any processing of results.  So when
501                                                            # we get one of these, we just fire the event even if the query
502                                                            # is not done.  This means we will NOT process EOF packets
503                                                            # themselves (see above).
504   ***     10     50                          50            if ( $session->{cmd} ) {
505           10                                 22               MKDEBUG && _d('Got a row/field/result packet');
506           10                                 42               my $com = $session->{cmd}->{cmd};
507           10                                 23               MKDEBUG && _d('Responding to client', $com_for{$com});
508           10                                 50               my $event = { ts  => $packet->{ts} };
509   ***     10     50                          44               if ( $com eq COM_QUERY ) {
510           10                                 40                  $event->{cmd} = 'Query';
511           10                                 49                  $event->{arg} = $session->{cmd}->{arg};
512                                                               }
513                                                               else {
514   ***      0                                  0                  $event->{arg} = 'administrator command: '
515                                                                       . ucfirst(lc(substr($com_for{$com}, 4)));
516   ***      0                                  0                  $event->{cmd} = 'Admin';
517                                                               }
518                                                   
519                                                               # We DID get all the data in the packet.
520   ***     10     50                          46               if ( $packet->{complete} ) {
521                                                                  # Look to see if the end of the data appears to be an EOF
522                                                                  # packet.
523           10                                123                  my ( $warning_count, $status_flags )
524                                                                     = $data =~ m/fe(.{4})(.{4})\Z/;
525           10    100                          46                  if ( $warning_count ) { 
526            9                                 31                     $event->{Warnings} = to_num($warning_count);
527            9                                 33                     my $flags = to_num($status_flags); # TODO set all flags?
528   ***      9     50                          51                     $event->{No_good_index_used}
529                                                                        = $flags & SERVER_QUERY_NO_GOOD_INDEX_USED ? 1 : 0;
530            9    100                          48                     $event->{No_index_used}
531                                                                        = $flags & SERVER_QUERY_NO_INDEX_USED ? 1 : 0;
532                                                                  }
533                                                               }
534                                                   
535           10                                 49               return $self->_make_event($event, $packet, $session);
536                                                            }
537                                                            else {
538   ***      0                                  0               MKDEBUG && _d('Unknown in-stream server response');
539                                                            }
540                                                         }
541                                                      }
542                                                   
543            6                                 25      return;
544                                                   }
545                                                   
546                                                   # Handles a packet from the client given the state of the session.
547                                                   # The client doesn't send a wide and exotic array of packets like
548                                                   # the server.  Even so, we're only interested in:
549                                                   #    * Users and dbs from connection handshake packets
550                                                   #    * SQL statements from COM_QUERY commands
551                                                   # Anything else is ignored.  Returns an event if one was ready to be
552                                                   # created, otherwise returns nothing.
553                                                   sub _packet_from_client {
554           25                   25           115      my ( $self, $packet, $session, $misc ) = @_;
555   ***     25     50                          98      die "I need a packet"  unless $packet;
556   ***     25     50                          90      die "I need a session" unless $session;
557                                                   
558           25                                 57      MKDEBUG && _d('Packet is from client; state:', $session->{state}); 
559                                                   
560           25    100    100                  232      if ( ($session->{client_seq} || '') eq $packet->{seq} ) {
561            1                                  3         push @{ $session->{client_retransmissions} }, $packet->{seq};
               1                                  7   
562            1                                  2         MKDEBUG && _d('TCP retransmission');
563            1                                  4         return;
564                                                      }
565           24                                 97      $session->{client_seq} = $packet->{seq};
566                                                   
567           24                                100      my $data  = $packet->{data};
568           24                                 81      my $ts    = $packet->{ts};
569                                                   
570           24    100    100                  432      if ( ($session->{state} || '') eq 'server_handshake' ) {
                    100    100                        
      ***            50     50                        
571            5                                 13         MKDEBUG && _d('Expecting client authentication packet');
572                                                         # The connection is a 3-way handshake:
573                                                         #    server > client  (protocol version, thread id, etc.)
574                                                         #    client > server  (user, pass, default db, etc.)
575                                                         #    server > client  OK if login succeeds
576                                                         # pos_in_log refers to 2nd handshake from the client.
577                                                         # A connection is logged even if the client fails to
578                                                         # login (bad password, etc.).
579            5                                 19         my $handshake = parse_client_handshake_packet($data);
580   ***      5     50                          21         if ( !$handshake ) {
581   ***      0                                  0            $self->fail_session($session, 'failed to parse client handshake');
582   ***      0                                  0            return;
583                                                         }
584            5                                 19         $session->{state}         = 'client_auth';
585            5                                 22         $session->{pos_in_log}    = $packet->{pos_in_log};
586            5                                 23         $session->{user}          = $handshake->{user};
587            5                                 21         $session->{db}            = $handshake->{db};
588                                                   
589                                                         # $session->{will_compress} will become $session->{compress} when
590                                                         # the server's final handshake packet is received.  This prevents
591                                                         # parse_packet() from trying to decompress that final packet.
592                                                         # Compressed packets can only begin after the full handshake is done.
593            5                                 37         $session->{will_compress} = $handshake->{flags}->{CLIENT_COMPRESS};
594                                                      }
595                                                      elsif ( ($session->{state} || '') eq 'client_auth_resend' ) {
596                                                         # Don't know how to parse this packet.
597            1                                  2         MKDEBUG && _d('Client resending password using old algorithm');
598            1                                  4         $session->{state} = 'client_auth';
599                                                      }
600                                                      elsif ( ($session->{state} || '') eq 'awaiting_reply' ) {
601   ***      0      0                           0         my $arg = $session->{cmd}->{arg} ? substr($session->{cmd}->{arg}, 0, 50)
602                                                                 : 'unknown';
603   ***      0                                  0         MKDEBUG && _d('More data for previous command:', $arg, '...'); 
604   ***      0                                  0         return;
605                                                      }
606                                                      else {
607                                                         # Otherwise, it should be a query.  We ignore the commands
608                                                         # that take arguments (COM_CHANGE_USER, COM_PROCESS_KILL).
609                                                   
610                                                         # Detect compression in-stream only if $session->{compress} is
611                                                         # not defined.  This means we didn't see the client handshake.
612                                                         # If we had seen it, $session->{compress} would be defined as 0 or 1.
613           18    100                          97         if ( !defined $session->{compress} ) {
614   ***     11     50                          57            return unless $self->detect_compression($packet, $session);
615           11                                 42            $data = $packet->{data};
616                                                         }
617                                                   
618           18                                 92         my $com = parse_com_packet($data, $packet->{mysql_data_len});
619   ***     18     50                          72         if ( !$com ) {
620   ***      0                                  0            $self->fail_session($session, 'failed to parse COM packet');
621   ***      0                                  0            return;
622                                                         }
623           18                                 72         $session->{state}      = 'awaiting_reply';
624           18                                 85         $session->{pos_in_log} = $packet->{pos_in_log};
625           18                                 56         $session->{ts}         = $ts;
626           18                                134         $session->{cmd}        = {
627                                                            cmd => $com->{code},
628                                                            arg => $com->{data},
629                                                         };
630                                                   
631           18    100                         117         if ( $com->{code} eq COM_QUIT ) { # Fire right away; will cleanup later.
632            2                                  6            MKDEBUG && _d('Got a COM_QUIT');
633            2                                 16            return $self->_make_event(
634                                                               {  cmd       => 'Admin',
635                                                                  arg       => 'administrator command: Quit',
636                                                                  ts        => $ts,
637                                                               },
638                                                               $packet, $session
639                                                            );
640   ***      0                                  0            $session->{state} = 'closing';
641                                                         }
642                                                      }
643                                                   
644           22                                 80      return;
645                                                   }
646                                                   
647                                                   # Make and return an event from the given packet and session.
648                                                   sub _make_event {
649           22                   22           107      my ( $self, $event, $packet, $session ) = @_;
650           22                                 59      MKDEBUG && _d('Making event');
651                                                   
652                                                      # Clear packets that preceded this event.
653           22                                 92      $session->{raw_packets} = [];
654                                                   
655           22    100                         123      if ( !$session->{thread_id} ) {
656                                                         # Only the server handshake packet gives the thread id, so for
657                                                         # sessions caught mid-stream we assign a fake thread id.
658           11                                 44         MKDEBUG && _d('Giving session fake thread id', $self->{fake_thread_id});
659           11                                 68         $session->{thread_id} = $self->{fake_thread_id}++;
660                                                      }
661                                                   
662           22                                210      my ($host, $port) = $session->{client} =~ m/((?:\d+\.){3}\d+)\:(\w+)/;
663   ***     22     50    100                  190      my $new_event = {
                    100    100                        
                           100                        
664                                                         cmd        => $event->{cmd},
665                                                         arg        => $event->{arg},
666                                                         bytes      => length( $event->{arg} ),
667                                                         ts         => tcp_timestamp( $event->{ts} ),
668                                                         host       => $host,
669                                                         ip         => $host,
670                                                         port       => $port,
671                                                         db         => $session->{db},
672                                                         user       => $session->{user},
673                                                         Thread_id  => $session->{thread_id},
674                                                         pos_in_log => $session->{pos_in_log},
675                                                         Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
676                                                         Error_no   => $event->{Error_no} || 'none',
677                                                         Rows_affected      => ($event->{Rows_affected} || 0),
678                                                         Warning_count      => ($event->{Warning_count} || 0),
679                                                         No_good_index_used => ($event->{No_good_index_used} ? 'Yes' : 'No'),
680                                                         No_index_used      => ($event->{No_index_used}      ? 'Yes' : 'No'),
681                                                      };
682           22                                 67      MKDEBUG && _d('Properties of event:', Dumper($new_event));
683                                                   
684                                                      # Delete cmd to prevent re-making the same event if the
685                                                      # server sends extra stuff that looks like a result set, etc.
686           22                                100      delete $session->{cmd};
687                                                   
688                                                      # Undef the session state so that we ignore everything from
689                                                      # the server and wait until the client says something again.
690           22                                 74      $session->{state} = undef;
691                                                   
692           22                                133      return $new_event;
693                                                   }
694                                                   
695                                                   # Extracts a slow-log-formatted timestamp from the tcpdump timestamp format.
696                                                   sub tcp_timestamp {
697           22                   22            96      my ( $ts ) = @_;
698           22                                290      $ts =~ s/^\d\d(\d\d)-(\d\d)-(\d\d)/$1$2$3/;
699           22                                228      return $ts;
700                                                   }
701                                                   
702                                                   # Returns the difference between two tcpdump timestamps.
703                                                   sub timestamp_diff {
704           22                   22            96      my ( $start, $end ) = @_;
705           22                                 91      my $sd = substr($start, 0, 11, '');
706           22                                 74      my $ed = substr($end,   0, 11, '');
707           22                                146      my ( $sh, $sm, $ss ) = split(/:/, $start);
708           22                                109      my ( $eh, $em, $es ) = split(/:/, $end);
709           22                                144      my $esecs = ($eh * 3600 + $em * 60 + $es);
710           22                                 94      my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
711   ***     22     50                          90      if ( $sd eq $ed ) {
712           22                               1002         return sprintf '%.6f', $esecs - $ssecs;
713                                                      }
714                                                      else { # Assume only one day boundary has been crossed, no DST, etc
715   ***      0                                  0         return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
716                                                      }
717                                                   }
718                                                   
719                                                   # Converts hexadecimal to string.
720                                                   sub to_string {
721           59                   59           321      my ( $data ) = @_;
722                                                      # $data =~ s/(..)/chr(hex $1)/eg;
723           59                                609      $data = pack('H*', $data);
724           59                                254      return $data;
725                                                   }
726                                                   
727                                                   # All numbers are stored with the least significant byte first in the MySQL
728                                                   # protocol.
729                                                   sub to_num {
730          171                  171           660      my ( $str ) = @_;
731          171                               1022      my @bytes = $str =~ m/(..)/g;
732          171                                513      my $result = 0;
733          171                                876      foreach my $i ( 0 .. $#bytes ) {
734          372                               1865         $result += hex($bytes[$i]) * (16 ** ($i * 2));
735                                                      }
736          171                                700      return $result;
737                                                   }
738                                                   
739                                                   # Accepts a reference to a string, which it will modify.  Extracts a
740                                                   # length-coded binary off the front of the string and returns that value as an
741                                                   # integer.
742                                                   sub get_lcb {
743           10                   10            33      my ( $string ) = @_;
744           10                                 40      my $first_byte = hex(substr($$string, 0, 2, ''));
745   ***     10     50                          35      if ( $first_byte < 251 ) {
      ***             0                               
      ***             0                               
      ***             0                               
746           10                                 32         return $first_byte;
747                                                      }
748                                                      elsif ( $first_byte == 252 ) {
749   ***      0                                  0         return to_num(substr($$string, 0, 4, ''));
750                                                      }
751                                                      elsif ( $first_byte == 253 ) {
752   ***      0                                  0         return to_num(substr($$string, 0, 6, ''));
753                                                      }
754                                                      elsif ( $first_byte == 254 ) {
755   ***      0                                  0         return to_num(substr($$string, 0, 16, ''));
756                                                      }
757                                                   }
758                                                   
759                                                   # Error packet structure:
760                                                   # Offset  Bytes               Field
761                                                   # ======  =================   ====================================
762                                                   #         00 00 00 01         MySQL proto header (already removed)
763                                                   #         ff                  Error  (already removed)
764                                                   # 0       00 00               Error number
765                                                   # 4       23                  SQL state marker, always '#'
766                                                   # 6       00 00 00 00 00      SQL state
767                                                   # 16      00 ...              Error message
768                                                   # The sqlstate marker and actual sqlstate are combined into one value. 
769                                                   sub parse_error_packet {
770            3                    3            23      my ( $data ) = @_;
771   ***      3     50                          14      die "I need data" unless $data;
772            3                                  8      MKDEBUG && _d('ERROR data:', $data);
773   ***      3     50                          15      if ( length $data < 16 ) {
774   ***      0                                  0         MKDEBUG && _d('Error packet is too short:', $data);
775   ***      0                                  0         return;
776                                                      }
777            3                                 16      my $errno    = to_num(substr($data, 0, 4));
778            3                                 14      my $marker   = to_string(substr($data, 4, 2));
779   ***      3     50                          14      return unless $marker eq '#';
780            3                                 13      my $sqlstate = to_string(substr($data, 6, 10));
781            3                                 13      my $message  = to_string(substr($data, 16));
782            3                                 24      my $pkt = {
783                                                         errno    => $errno,
784                                                         sqlstate => $marker . $sqlstate,
785                                                         message  => $message,
786                                                      };
787            3                                  7      MKDEBUG && _d('Error packet:', Dumper($pkt));
788            3                                 15      return $pkt;
789                                                   }
790                                                   
791                                                   # OK packet structure:
792                                                   # Offset  Bytes               Field
793                                                   # ======  =================   ====================================
794                                                   #         00 00 00 01         MySQL proto header (already removed)
795                                                   #         00                  OK  (already removed)
796                                                   #         1-9                 Affected rows (LCB)
797                                                   #         1-9                 Insert ID (LCB)
798                                                   #         00 00               Server status
799                                                   #         00 00               Warning count
800                                                   #         00 ...              Message (optional)
801                                                   sub parse_ok_packet {
802            5                    5            23      my ( $data ) = @_;
803   ***      5     50                          23      die "I need data" unless $data;
804            5                                 12      MKDEBUG && _d('OK data:', $data);
805   ***      5     50                          22      if ( length $data < 12 ) {
806   ***      0                                  0         MKDEBUG && _d('OK packet is too short:', $data);
807   ***      0                                  0         return;
808                                                      }
809            5                                 24      my $affected_rows = get_lcb(\$data);
810            5                                 21      my $insert_id     = get_lcb(\$data);
811            5                                 24      my $status        = to_num(substr($data, 0, 4, ''));
812            5                                 24      my $warnings      = to_num(substr($data, 0, 4, ''));
813            5                                 18      my $message       = to_string($data);
814                                                      # Note: $message is discarded.  It might be something like
815                                                      # Records: 2  Duplicates: 0  Warnings: 0
816            5                                 42      my $pkt = {
817                                                         affected_rows => $affected_rows,
818                                                         insert_id     => $insert_id,
819                                                         status        => $status,
820                                                         warnings      => $warnings,
821                                                         message       => $message,
822                                                      };
823            5                                 20      MKDEBUG && _d('OK packet:', Dumper($pkt));
824            5                                 25      return $pkt;
825                                                   }
826                                                   
827                                                   # Currently we only capture and return the thread id.
828                                                   sub parse_server_handshake_packet {
829            6                    6            32      my ( $data ) = @_;
830   ***      6     50                          25      die "I need data" unless $data;
831            6                                 15      MKDEBUG && _d('Server handshake data:', $data);
832            6                                 37      my $handshake_pattern = qr{
833                                                                           # Bytes                Name
834                                                         ^                 # -----                ----
835                                                         (.+?)00           # n Null-Term String   server_version
836                                                         (.{8})            # 4                    thread_id
837                                                         .{16}             # 8                    scramble_buff
838                                                         .{2}              # 1                    filler: always 0x00
839                                                         (.{4})            # 2                    server_capabilities
840                                                         .{2}              # 1                    server_language
841                                                         .{4}              # 2                    server_status
842                                                         .{26}             # 13                   filler: always 0x00
843                                                                           # 13                   rest of scramble_buff
844                                                      }x;
845            6                                 76      my ( $server_version, $thread_id, $flags ) = $data =~ m/$handshake_pattern/;
846            6                                 30      my $pkt = {
847                                                         server_version => to_string($server_version),
848                                                         thread_id      => to_num($thread_id),
849                                                         flags          => parse_flags($flags),
850                                                      };
851            6                                 15      MKDEBUG && _d('Server handshake packet:', Dumper($pkt));
852            6                                 48      return $pkt;
853                                                   }
854                                                   
855                                                   # Currently we only capture and return the user and default database.
856                                                   sub parse_client_handshake_packet {
857            6                    6            40      my ( $data ) = @_;
858   ***      6     50                          26      die "I need data" unless $data;
859            6                                 14      MKDEBUG && _d('Client handshake data:', $data);
860            6                                 72      my ( $flags, $user, $buff_len ) = $data =~ m{
861                                                         ^
862                                                         (.{8})         # Client flags
863                                                         .{10}          # Max packet size, charset
864                                                         (?:00){23}     # Filler
865                                                         ((?:..)+?)00   # Null-terminated user name
866                                                         (..)           # Length-coding byte for scramble buff
867                                                      }x;
868                                                   
869                                                      # This packet is easy to detect because it's the only case where
870                                                      # the server sends the client a packet first (its handshake) and
871                                                      # then the client only and ever sends back its handshake.
872   ***      6     50                          33      if ( !$buff_len ) {
873   ***      0                                  0         MKDEBUG && _d('Did not match client handshake packet');
874   ***      0                                  0         return;
875                                                      }
876                                                   
877                                                      # This length-coded binary doesn't seem to be a normal one, it
878                                                      # seems more like a length-coded string actually.
879            6                                 20      my $code_len = hex($buff_len);
880            6                                154      my ( $db ) = $data =~ m!
881                                                         ^.{64}${user}00..   # Everything matched before
882                                                         (?:..){$code_len}   # The scramble buffer
883                                                         (.*)00\Z            # The database name
884                                                      !x;
885            6    100                          28      my $pkt = {
886                                                         user  => to_string($user),
887                                                         db    => $db ? to_string($db) : '',
888                                                         flags => parse_flags($flags),
889                                                      };
890            6                                 16      MKDEBUG && _d('Client handshake packet:', Dumper($pkt));
891            6                                 36      return $pkt;
892                                                   }
893                                                   
894                                                   # COM data is not 00-terminated, but the the MySQL client appends \0,
895                                                   # so we have to use the packet length to know where the data ends.
896                                                   sub parse_com_packet {
897           30                   30           232      my ( $data, $len ) = @_;
898   ***     30     50                         111      die "I need data"  unless $data;
899   ***     30     50                         103      die "I need a len" unless $len;
900           30                                 69      MKDEBUG && _d('COM data:',
901                                                         (substr($data, 0, 100).(length $data > 100 ? '...' : '')),
902                                                         'len:', $len);
903           30                                104      my $code = substr($data, 0, 2);
904           30                                105      my $com  = $com_for{$code};
905   ***     30     50                         107      if ( !$com ) {
906   ***      0                                  0         MKDEBUG && _d('Did not match COM packet');
907   ***      0                                  0         return;
908                                                      }
909           30                                164      $data    = to_string(substr($data, 2, ($len - 1) * 2));
910           30                                185      my $pkt = {
911                                                         code => $code,
912                                                         com  => $com,
913                                                         data => $data,
914                                                      };
915           30                                 68      MKDEBUG && _d('COM packet:', Dumper($pkt));
916           30                                108      return $pkt;
917                                                   }
918                                                   
919                                                   sub parse_flags {
920           12                   12            43      my ( $flags ) = @_;
921   ***     12     50                          53      die "I need flags" unless $flags;
922           12                                 28      MKDEBUG && _d('Flag data:', $flags);
923           12                                176      my %flags     = %flag_for;
924           12                                 51      my $flags_dec = to_num($flags);
925           12                                 63      foreach my $flag ( keys %flag_for ) {
926          216                                995         my $flagno    = $flag_for{$flag};
927          216    100                         888         $flags{$flag} = ($flags_dec & $flagno ? 1 : 0);
928                                                      }
929           12                                 92      return \%flags;
930                                                   }
931                                                   
932                                                   # Takes a scalarref to a hex string of compressed data.
933                                                   # Returns a scalarref to a hex string of the uncompressed data.
934                                                   # The given hex string of compressed data is not modified.
935                                                   sub uncompress_data {
936            1                    1             5      my ( $data, $len ) = @_;
937   ***      1     50                           6      die "I need data" unless $data;
938   ***      1     50                           4      die "I need a len argument" unless $len;
939   ***      1     50                           7      die "I need a scalar reference to data" unless ref $data eq 'SCALAR';
940            1                                  2      MKDEBUG && _d('Uncompressing data');
941            1                                  3      our $InflateError;
942                                                   
943                                                      # Pack hex string into compressed binary data.
944            1                                 92      my $comp_bin_data = pack('H*', $$data);
945                                                   
946                                                      # Uncompress the compressed binary data.
947            1                                  4      my $uncomp_bin_data = '';
948   ***      1     50                          14      my $z = new IO::Uncompress::Inflate(
949                                                         \$comp_bin_data
950                                                      ) or die "IO::Uncompress::Inflate failed: $InflateError";
951   ***      1     50                          12      my $status = $z->read(\$uncomp_bin_data, $len)
952                                                         or die "IO::Uncompress::Inflate failed: $InflateError";
953                                                   
954                                                      # Unpack the uncompressed binary data back into a hex string.
955                                                      # This is the original MySQL packet(s).
956            1                                 77      my $uncomp_data = unpack('H*', $uncomp_bin_data);
957                                                   
958            1                                  2      return \$uncomp_data;
959                                                   }
960                                                   
961                                                   # Returns 1 on success or 0 on failure.  Failure is probably
962                                                   # detecting compression but not being able to uncompress
963                                                   # (uncompress_packet() returns 0).
964                                                   sub detect_compression {
965           11                   11            55      my ( $self, $packet, $session ) = @_;
966           11                                 26      MKDEBUG && _d('Checking for client compression');
967                                                      # This is a necessary hack for detecting compression in-stream without
968                                                      # having seen the client handshake and CLIENT_COMPRESS flag.  If the
969                                                      # client is compressing packets, there will be an extra 7 bytes before
970                                                      # the regular MySQL header.  For short COM_QUERY commands, these 7 bytes
971                                                      # are usually zero where we'd expect to see 03 for COM_QUERY.  So if we
972                                                      # parse this packet and it looks like a COM_SLEEP (00) which is not a
973                                                      # command that the client can send, then chances are the client is using
974                                                      # compression.
975           11                                 63      my $com = parse_com_packet($packet->{data}, $packet->{data_len});
976   ***     11    100     66                  115      if ( $com && $com->{code} eq COM_SLEEP ) {
977            1                                  3         MKDEBUG && _d('Client is using compression');
978            1                                  3         $session->{compress} = 1;
979                                                   
980                                                         # Since parse_packet() didn't know the packet was compressed, it
981                                                         # called remove_mysql_header() which removed the first 4 of 7 bytes
982                                                         # of the compression header.  We must restore these 4 bytes, then
983                                                         # uncompress and remove the MySQL header.  We only do this once.
984            1                                  7         $packet->{data} = $packet->{mysql_hdr} . $packet->{data};
985   ***      1     50                           5         return 0 unless $self->uncompress_packet($packet, $session);
986            1                                  4         remove_mysql_header($packet);
987                                                      }
988                                                      else {
989           10                                 23         MKDEBUG && _d('Client is NOT using compression');
990           10                                 34         $session->{compress} = 0;
991                                                      }
992           11                                 66      return 1;
993                                                   }
994                                                   
995                                                   # Returns 1 if the packet was uncompressed or 0 if we can't uncompress.
996                                                   # Failure is usually due to IO::Uncompress not being available.
997                                                   sub uncompress_packet {
998            6                    6            24      my ( $self, $packet, $session ) = @_;
999   ***      6     50                          25      die "I need a packet"  unless $packet;
1000  ***      6     50                          22      die "I need a session" unless $session;
1001                                                  
1002                                                     # From the doc: "A compressed packet header is:
1003                                                     #    packet length (3 bytes),
1004                                                     #    packet number (1 byte),
1005                                                     #    and Uncompressed Packet Length (3 bytes).
1006                                                     # The Uncompressed Packet Length is the number of bytes
1007                                                     # in the original, uncompressed packet. If this is zero
1008                                                     # then the data is not compressed."
1009                                                  
1010           6                                 13      my $data;
1011           6                                 13      my $comp_hdr;
1012           6                                 15      my $comp_data_len;
1013           6                                 14      my $pkt_num;
1014           6                                 15      my $uncomp_data_len;
1015           6                                 16      eval {
1016           6                                 23         $data            = \$packet->{data};
1017           6                                 27         $comp_hdr        = substr($$data, 0, 14, '');
1018           6                                 32         $comp_data_len   = to_num(substr($comp_hdr, 0, 6));
1019           6                                 27         $pkt_num         = to_num(substr($comp_hdr, 6, 2));
1020           6                                 24         $uncomp_data_len = to_num(substr($comp_hdr, 8, 6));
1021           6                                 16         MKDEBUG && _d('Compression header data:', $comp_hdr,
1022                                                           'compressed data len (bytes)', $comp_data_len,
1023                                                           'number', $pkt_num,
1024                                                           'uncompressed data len (bytes)', $uncomp_data_len);
1025                                                     };
1026  ***      6     50                          23      if ( $EVAL_ERROR ) {
1027  ***      0                                  0         $session->{EVAL_ERROR} = $EVAL_ERROR;
1028  ***      0                                  0         $self->fail_session($session, 'failed to parse compression header');
1029  ***      0                                  0         return 0;
1030                                                     }
1031                                                  
1032           6    100                          23      if ( $uncomp_data_len ) {
1033           1                                  3         eval {
1034           1                                  5            $data = uncompress_data($data, $uncomp_data_len);
1035           1                                 49            $packet->{data} = $$data;
1036                                                        };
1037  ***      1     50                           5         if ( $EVAL_ERROR ) {
1038  ***      0                                  0            $session->{EVAL_ERROR} = $EVAL_ERROR;
1039  ***      0                                  0            $self->fail_session($session, 'failed to uncompress data');
1040  ***      0                                  0            die "Cannot uncompress packet.  Check that IO::Uncompress::Inflate "
1041                                                              . "is installed.\nError: $EVAL_ERROR";
1042                                                        }
1043                                                     }
1044                                                     else {
1045           5                                 11         MKDEBUG && _d('Packet is not really compressed');
1046           5                                 18         $packet->{data} = $$data;
1047                                                     }
1048                                                  
1049           6                                 31      return 1;
1050                                                  }
1051                                                  
1052                                                  # Removes the first 4 bytes of the packet data which should be
1053                                                  # a MySQL header: 3 bytes packet length, 1 byte packet number.
1054                                                  sub remove_mysql_header {
1055          52                   52           236      my ( $packet ) = @_;
1056  ***     52     50                         198      die "I need a packet" unless $packet;
1057                                                  
1058                                                     # NOTE: the data is modified by the inmost substr call here!  If we
1059                                                     # had all the data in the TCP packets, we could change this to a while
1060                                                     # loop; while get-a-packet-from-$data, do stuff, etc.  But we don't,
1061                                                     # and we don't want to either.
1062          52                                260      my $mysql_hdr      = substr($packet->{data}, 0, 8, '');
1063          52                               1529      my $mysql_data_len = to_num(substr($mysql_hdr, 0, 6));
1064          52                                217      my $pkt_num        = to_num(substr($mysql_hdr, 6, 2));
1065          52                                119      MKDEBUG && _d('MySQL packet: header data', $mysql_hdr,
1066                                                        'data len (bytes)', $mysql_data_len, 'number', $pkt_num);
1067                                                  
1068          52                                284      $packet->{mysql_hdr}      = $mysql_hdr;
1069          52                                178      $packet->{mysql_data_len} = $mysql_data_len;
1070          52                                181      $packet->{number}         = $pkt_num;
1071                                                  
1072          52                                162      return;
1073                                                  }
1074                                                  
1075                                                  sub _get_errors_fh {
1076  ***      0                    0                    my ( $self ) = @_;
1077  ***      0                                         my $errors_fh = $self->{errors_fh};
1078  ***      0      0                                  return $errors_fh if $errors_fh;
1079                                                  
1080                                                     # Errors file isn't open yet; try to open it.
1081  ***      0                                         my $o = $self->{o};
1082  ***      0      0      0                           if ( $o && $o->has('tcpdump-errors') && $o->got('tcpdump-errors') ) {
      ***                    0                        
1083  ***      0                                            my $errors_file = $o->get('tcpdump-errors');
1084  ***      0                                            MKDEBUG && _d('tcpdump-errors file:', $errors_file);
1085  ***      0      0                                     open $errors_fh, '>>', $errors_file
1086                                                           or die "Cannot open tcpdump-errors file $errors_file: $OS_ERROR";
1087                                                     }
1088                                                  
1089  ***      0                                         $self->{errors_fh} = $errors_fh;
1090  ***      0                                         return $errors_fh;
1091                                                  }
1092                                                  
1093                                                  sub fail_session {
1094  ***      0                    0                    my ( $self, $session, $reason ) = @_;
1095  ***      0                                         my $errors_fh = $self->_get_errors_fh();
1096  ***      0      0                                  if ( $errors_fh ) {
1097  ***      0                                            $session->{reason_for_failure} = $reason;
1098  ***      0                                            my $session_dump = '# ' . Dumper($session);
1099  ***      0                                            chomp $session_dump;
1100  ***      0                                            $session_dump =~ s/\n/\n# /g;
1101  ***      0                                            print $errors_fh "$session_dump\n";
1102                                                        {
1103  ***      0                                               local $LIST_SEPARATOR = "\n";
      ***      0                                      
1104  ***      0                                               print $errors_fh "@{$session->{raw_packets}}";
      ***      0                                      
1105  ***      0                                               print $errors_fh "\n";
1106                                                        }
1107                                                     }
1108  ***      0                                         MKDEBUG && _d('Failed session', $session->{client}, 'because', $reason);
1109  ***      0                                         delete $self->{sessions}->{$session->{client}};
1110  ***      0                                         return;
1111                                                  }
1112                                                  
1113                                                  sub _d {
1114  ***      0                    0                    my ($package, undef, $line) = caller 0;
1115  ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
1116  ***      0                                              map { defined $_ ? $_ : 'undef' }
1117                                                          @_;
1118  ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
1119                                                  }
1120                                                  
1121                                                  1;
1122                                                  
1123                                                  # ###########################################################################
1124                                                  # End MySQLProtocolParser package
1125                                                  # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
159          100      7      8   $args{'server'} ? :
183          100     49     50   if (my $server = $$self{'server'})
184          100      3     46   if ($src_host ne $server and $dst_host ne $server)
194          100     43     53   if ($src_host =~ /:$$self{'server_port'}$/) { }
      ***     50     53      0   elsif ($dst_host =~ /:$$self{'server_port'}$/) { }
210          100     16     80   if (not exists $$self{'sessions'}{$client})
226          100     44     52   if ($$packet{'data_len'} == 0)
229   ***     50      0     44   if (($$session{'state'} || '') eq 'closing')
241          100      5     47   if ($$session{'compress'})
242   ***     50      0      5   unless $self->uncompress_packet($packet, $session)
245          100      1     51   if ($$session{'buff'} and $packet_from eq 'client') { }
269   ***     50      0     51   if ($EVAL_ERROR)
280          100     26     26   if ($packet_from eq 'server') { }
      ***     50     26      0   elsif ($packet_from eq 'client') { }
284          100      1     25   if ($$session{'buff'} and $$session{'buff_left'} <= 0) { }
             100      1     24   elsif ($$packet{'mysql_data_len'} > $$packet{'data_len'}) { }
326   ***     50      0     26   unless $packet
327   ***     50      0     26   unless $session
331   ***     50      0     26   if (($$session{'server_seq'} || '') eq $$packet{'seq'})
348   ***     50      0     26   if (not $first_byte)
356          100      5     21   if (not $$session{'state'}) { }
357   ***     50      5      0   if ($first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/) { }
365   ***     50      0      5   if (not $handshake)
378          100      8     13   if ($first_byte eq '00') { }
             100      2     11   elsif ($first_byte eq 'ff') { }
             100      1     10   elsif ($first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9) { }
379          100      4      4   if (($$session{'state'} || '') eq 'client_auth') { }
      ***     50      4      0   elsif ($$session{'cmd'}) { }
399   ***     50      0      4   if (not $ok)
406   ***     50      4      0   if ($com eq '03') { }
433   ***     50      0      2   if (not $error)
439          100      1      1   if ($$session{'state'} eq 'client_auth') { }
      ***     50      1      0   elsif ($$session{'cmd'}) { }
441   ***     50      1      0   $$error{'errno'} ? :
456   ***     50      1      0   if ($com eq '03') { }
466   ***     50      1      0   $$error{'errno'} ? :
481   ***     50      1      0   if ($$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2) { }
504   ***     50     10      0   if ($$session{'cmd'}) { }
509   ***     50     10      0   if ($com eq '03') { }
520   ***     50     10      0   if ($$packet{'complete'})
525          100      9      1   if ($warning_count)
528   ***     50      0      9   $flags & 16 ? :
530          100      2      7   $flags & 32 ? :
555   ***     50      0     25   unless $packet
556   ***     50      0     25   unless $session
560          100      1     24   if (($$session{'client_seq'} || '') eq $$packet{'seq'})
570          100      5     19   if (($$session{'state'} || '') eq 'server_handshake') { }
             100      1     18   elsif (($$session{'state'} || '') eq 'client_auth_resend') { }
      ***     50      0     18   elsif (($$session{'state'} || '') eq 'awaiting_reply') { }
580   ***     50      0      5   if (not $handshake)
601   ***      0      0      0   $$session{'cmd'}{'arg'} ? :
613          100     11      7   if (not defined $$session{'compress'})
614   ***     50      0     11   unless $self->detect_compression($packet, $session)
619   ***     50      0     18   if (not $com)
631          100      2     16   if ($$com{'code'} eq '01')
655          100     11     11   if (not $$session{'thread_id'})
663   ***     50      0     22   $$event{'No_good_index_used'} ? :
             100      2     20   $$event{'No_index_used'} ? :
711   ***     50     22      0   if ($sd eq $ed) { }
745   ***     50     10      0   if ($first_byte < 251) { }
      ***      0      0      0   elsif ($first_byte == 252) { }
      ***      0      0      0   elsif ($first_byte == 253) { }
      ***      0      0      0   elsif ($first_byte == 254) { }
771   ***     50      0      3   unless $data
773   ***     50      0      3   if (length $data < 16)
779   ***     50      0      3   unless $marker eq '#'
803   ***     50      0      5   unless $data
805   ***     50      0      5   if (length $data < 12)
830   ***     50      0      6   unless $data
858   ***     50      0      6   unless $data
872   ***     50      0      6   if (not $buff_len)
885          100      3      3   $db ? :
898   ***     50      0     30   unless $data
899   ***     50      0     30   unless $len
905   ***     50      0     30   if (not $com)
921   ***     50      0     12   unless $flags
927          100     94    122   $flags_dec & $flagno ? :
937   ***     50      0      1   unless $data
938   ***     50      0      1   unless $len
939   ***     50      0      1   unless ref $data eq 'SCALAR'
948   ***     50      0      1   unless my $z = 'IO::Uncompress::Inflate'->new(\$comp_bin_data)
951   ***     50      0      1   unless my $status = $z->read(\$uncomp_bin_data, $len)
976          100      1     10   if ($com and $$com{'code'} eq '00') { }
985   ***     50      0      1   unless $self->uncompress_packet($packet, $session)
999   ***     50      0      6   unless $packet
1000  ***     50      0      6   unless $session
1026  ***     50      0      6   if ($EVAL_ERROR)
1032         100      1      5   if ($uncomp_data_len) { }
1037  ***     50      0      1   if ($EVAL_ERROR)
1056  ***     50      0     52   unless $packet
1078  ***      0      0      0   if $errors_fh
1082  ***      0      0      0   if ($o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors'))
1085  ***      0      0      0   unless open $errors_fh, '>>', $errors_file
1096  ***      0      0      0   if ($errors_fh)
1115  ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
184          100     21     25      3   $src_host ne $server and $dst_host ne $server
245   ***     66     51      0      1   $$session{'buff'} and $packet_from eq 'client'
284   ***     66     25      0      1   $$session{'buff'} and $$session{'buff_left'} <= 0
357   ***     33      0      0      5   $first_byte eq '0a' and length $data >= 33
      ***     33      0      0      5   $first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/
378   ***     66     10      0      1   $first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9
481   ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth'
      ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2
976   ***     66      0     10      1   $com and $$com{'code'} eq '00'
1082  ***      0      0      0      0   $o and $o->has('tcpdump-errors')
      ***      0      0      0      0   $o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors')

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
161   ***     50     15      0   $server_port ||= '3306|mysql'
229          100     12     32   $$session{'state'} || ''
295   ***     50      0      1   $$session{'buff_left'} ||= $$packet{'mysql_data_len'} - $$packet{'data_len'}
331          100     10     16   $$session{'server_seq'} || ''
379   ***     50      8      0   $$session{'state'} || ''
560          100      9     16   $$session{'client_seq'} || ''
570          100      6     18   $$session{'state'} || ''
             100      1     18   $$session{'state'} || ''
      ***     50      0     18   $$session{'state'} || ''
663          100      2     20   $$event{'Error_no'} || 'none'
             100      4     18   $$event{'Rows_affected'} || 0
             100      1     21   $$event{'Warning_count'} || 0


Covered Subroutines
-------------------

Subroutine                    Count Location                                                   
----------------------------- ----- -----------------------------------------------------------
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:38  
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:39  
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:40  
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:47  
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:65  
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:98  
_make_event                      22 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:649 
_packet_from_client              25 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:554 
_packet_from_server              26 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:325 
detect_compression               11 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:965 
get_lcb                          10 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:743 
new                              15 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:157 
parse_client_handshake_packet     6 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:857 
parse_com_packet                 30 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:897 
parse_error_packet                3 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:770 
parse_flags                      12 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:920 
parse_ok_packet                   5 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:802 
parse_packet                     99 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:178 
parse_server_handshake_packet     6 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:829 
remove_mysql_header              52 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1055
tcp_timestamp                    22 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:697 
timestamp_diff                   22 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:704 
to_num                          171 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:730 
to_string                        59 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:721 
uncompress_data                   1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:936 
uncompress_packet                 6 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:998 

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                                   
----------------------------- ----- -----------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1114
_get_errors_fh                    0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1076
fail_session                      0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1094


