---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/MySQLProtocolParser.pm   78.0   59.9   61.2   89.7    n/a  100.0   72.3
Total                          78.0   59.9   61.2   89.7    n/a  100.0   72.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:00 2009
Finish:       Fri Jul 31 18:53:00 2009

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
18                                                    # MySQLProtocolParser package $Revision: 4283 $
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
               1                                  3   
               1                                  6   
40             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
41                                                    
42                                                    eval {
43                                                       require IO::Uncompress::Inflate;
44                                                       IO::Uncompress::Inflate->import(qw(inflate $InflateError));
45                                                    };
46                                                    
47             1                    1             7   use Data::Dumper;
               1                                  3   
               1                                  7   
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
67             1                                 28      COM_SLEEP               => '00',
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
157           14                   14           471      my ( $class, %args ) = @_;
158                                                   
159           14    100                         100      my ( $server_port )
160                                                         = $args{server} ? $args{server} =~ m/:(\w+)/ : ('3306|mysql');
161   ***     14            50                   54      $server_port ||= '3306|mysql';  # In case $args{server} doesn't have a port.
162                                                   
163           14                                123      my $self = {
164                                                         server         => $args{server},
165                                                         server_port    => $server_port,
166                                                         version        => '41',    # MySQL proto version; not used yet
167                                                         sessions       => {},
168                                                         o              => $args{o},
169                                                         fake_thread_id => 2**32,   # see _make_event()
170                                                      };
171           14                                 31      MKDEBUG && $self->{server} && _d('Watching only server', $self->{server});
172           14                                 91      return bless $self, $class;
173                                                   }
174                                                   
175                                                   # The packet arg should be a hashref from TcpdumpParser::parse_event().
176                                                   # misc is a placeholder for future features.
177                                                   sub parse_packet {
178           94                   94          1041      my ( $self, $packet, $misc ) = @_;
179                                                   
180           94                                437      my $src_host = "$packet->{src_host}:$packet->{src_port}";
181           94                                383      my $dst_host = "$packet->{dst_host}:$packet->{dst_port}";
182                                                   
183           94    100                         406      if ( my $server = $self->{server} ) {  # Watch only the given server.
184           44    100    100                  298         if ( $src_host ne $server && $dst_host ne $server ) {
185            3                                  7            MKDEBUG && _d('Packet is not to or from', $server);
186            3                                 17            return;
187                                                         }
188                                                      }
189                                                   
190                                                      # Auto-detect the server by looking for port 3306 or port "mysql" (sometimes
191                                                      # tcpdump will substitute the port by a lookup in /etc/protocols).
192           91                                209      my $packet_from;
193           91                                200      my $client;
194           91    100                         947      if ( $src_host =~ m/:$self->{server_port}$/ ) {
      ***            50                               
195           41                                108         $packet_from = 'server';
196           41                                111         $client      = $dst_host;
197                                                      }
198                                                      elsif ( $dst_host =~ m/:$self->{server_port}$/ ) {
199           50                                131         $packet_from = 'client';
200           50                                133         $client      = $src_host;
201                                                      }
202                                                      else {
203   ***      0                                  0         warn 'Packet is not to or from MySQL server: ', Dumper($packet);
204   ***      0                                  0         return;
205                                                      }
206           91                                190      MKDEBUG && _d('Client:', $client);
207                                                   
208                                                      # Get the client's session info or create a new session if the
209                                                      # client hasn't been seen before.
210           91    100                         444      if ( !exists $self->{sessions}->{$client} ) {
211           15                                 39         MKDEBUG && _d('New session');
212           15                                141         $self->{sessions}->{$client} = {
213                                                            client      => $client,
214                                                            ts          => $packet->{ts},
215                                                            state       => undef,
216                                                            compress    => undef,
217                                                            raw_packets => [],
218                                                         };
219                                                      };
220           91                                334      my $session = $self->{sessions}->{$client};
221                                                   
222                                                      # Return early if there's TCP/MySQL data.  These are usually ACK
223                                                      # packets, but they could also be FINs in which case, we should close
224                                                      # and delete the client's session.
225           91    100                         381      if ( $packet->{data_len} == 0 ) {
226           42                                 86         MKDEBUG && _d('No TCP/MySQL data');
227                                                         # Is the session ready to close?
228   ***     42     50    100                  320         if ( ($session->{state} || '') eq 'closing' ) {
229   ***      0                                  0            delete $self->{sessions}->{$session->{client}};
230   ***      0                                  0            MKDEBUG && _d('Session deleted'); 
231                                                         }
232           42                                238         return;
233                                                      }
234                                                   
235                                                      # Save raw packets to dump later in case something fails.
236           49                                115      push @{$session->{raw_packets}}, $packet->{raw_packet};
              49                                251   
237                                                   
238                                                      # Return unless the compressed packet can be uncompressed.
239                                                      # If it cannot, then we're helpless and must return.
240           49    100                         202      if ( $session->{compress} ) {
241   ***      5     50                          20         return unless $self->uncompress_packet($packet, $session);
242                                                      }
243                                                   
244                                                      # Remove the first MySQL header.  A single TCP packet can contain many
245                                                      # MySQL packets, but we only look at the first.  The 2nd and subsequent
246                                                      # packets are usually parts of a resultset returned by the server, but
247                                                      # we're not interested in resultsets.
248           49                                163      remove_mysql_header($packet);
249                                                   
250                                                      # Finally, parse the packet and maybe create an event.
251                                                      # The returned event may be empty if no event was ready to be created.
252           49                                113      my $event;
253           49    100                         206      if ( $packet_from eq 'server' ) {
      ***            50                               
254           25                                101         $event = $self->_packet_from_server($packet, $session, $misc);
255                                                      }
256                                                      elsif ( $packet_from eq 'client' ) {
257           24                                 99         $event = $self->_packet_from_client($packet, $session, $misc);
258                                                      }
259                                                      else {
260                                                         # Should not get here.
261   ***      0                                  0         die 'Packet origin unknown';
262                                                      }
263                                                   
264           49                                117      MKDEBUG && _d('Done parsing packet; client state:', $session->{state});
265           49                                400      return $event;
266                                                   }
267                                                   
268                                                   # Handles a packet from the server given the state of the session.
269                                                   # The server can send back a lot of different stuff, but luckily
270                                                   # we're only interested in
271                                                   #    * Connection handshake packets for the thread_id
272                                                   #    * OK and Error packets for errors, warnings, etc.
273                                                   # Anything else is ignored.  Returns an event if one was ready to be
274                                                   # created, otherwise returns nothing.
275                                                   sub _packet_from_server {
276           25                   25           104      my ( $self, $packet, $session, $misc ) = @_;
277   ***     25     50                         101      die "I need a packet"  unless $packet;
278   ***     25     50                          86      die "I need a session" unless $session;
279                                                   
280           25                                 49      MKDEBUG && _d('Packet is from server; client state:', $session->{state}); 
281                                                   
282   ***     25     50    100                  218      if ( ($session->{server_seq} || '') eq $packet->{seq} ) {
283   ***      0                                  0         push @{ $session->{server_retransmissions} }, $packet->{seq};
      ***      0                                  0   
284   ***      0                                  0         MKDEBUG && _d('TCP retransmission');
285   ***      0                                  0         return;
286                                                      }
287           25                                114      $session->{server_seq} = $packet->{seq};
288                                                   
289           25                                 89      my $data = $packet->{data};
290                                                   
291                                                      # The first byte in the packet indicates whether it's an OK,
292                                                      # ERROR, EOF packet.  If it's not one of those, we test
293                                                      # whether it's an initialization packet (the first thing the
294                                                      # server ever sends the client).  If it's not that, it could
295                                                      # be a result set header, field, row data, etc.
296                                                   
297           25                                 97      my ( $first_byte ) = substr($data, 0, 2, '');
298           25                                 51      MKDEBUG && _d('First byte of packet:', $first_byte);
299   ***     25     50                          99      if ( !$first_byte ) {
300   ***      0                                  0         $self->fail_session($session, 'no first byte');
301   ***      0                                  0         return;
302                                                      }
303                                                   
304                                                      # If there's no session state, then we're catching a server response
305                                                      # mid-stream.  It's only safe to wait until the client sends a command
306                                                      # or to look for the server handshake.
307           25    100                          96      if ( !$session->{state} ) {
308   ***      5     50     33                   73         if ( $first_byte eq '0a' && length $data >= 33 && $data =~ m/00{13}/ ) {
      ***                   33                        
309                                                            # It's the handshake packet from the server to the client.
310                                                            # 0a is protocol v10 which is essentially the only version used
311                                                            # today.  33 is the minimum possible length for a valid server
312                                                            # handshake packet.  It's probably a lot longer.  Other packets
313                                                            # may start with 0a, but none that can would be >= 33.  The 13-byte
314                                                            # 00 scramble buffer is another indicator.
315            5                                 22            my $handshake = parse_server_handshake_packet($data);
316   ***      5     50                          22            if ( !$handshake ) {
317   ***      0                                  0               $self->fail_session($session, 'failed to parse server handshake');
318   ***      0                                  0               return;
319                                                            }
320            5                                 20            $session->{state}     = 'server_handshake';
321            5                                 34            $session->{thread_id} = $handshake->{thread_id};
322                                                         }
323                                                         else {
324   ***      0                                  0            MKDEBUG && _d('Ignoring mid-stream server response');
325   ***      0                                  0            return;
326                                                         }
327                                                      }
328                                                      else {
329   ***     20    100     66                  121         if ( $first_byte eq '00' ) { 
                    100                               
                    100                               
330   ***      7    100     50                   45            if ( ($session->{state} || '') eq 'client_auth' ) {
      ***            50                               
331                                                               # We logged in OK!  Trigger an admin Connect command.
332                                                   
333            4                                 16               $session->{compress} = $session->{will_compress};
334            4                                 15               delete $session->{will_compress};
335            4                                  8               MKDEBUG && $session->{compress} && _d('Packets will be compressed');
336                                                   
337            4                                 10               MKDEBUG && _d('Admin command: Connect');
338            4                                 30               return $self->_make_event(
339                                                                  {  cmd => 'Admin',
340                                                                     arg => 'administrator command: Connect',
341                                                                     ts  => $packet->{ts}, # Events are timestamped when they end
342                                                                  },
343                                                                  $packet, $session
344                                                               );
345                                                            }
346                                                            elsif ( $session->{cmd} ) {
347                                                               # This OK should be ack'ing a query or something sent earlier
348                                                               # by the client.
349            3                                 12               my $ok  = parse_ok_packet($data);
350   ***      3     50                          13               if ( !$ok ) {
351   ***      0                                  0                  $self->fail_session($session, 'failed to parse OK packet');
352   ***      0                                  0                  return;
353                                                               }
354            3                                 11               my $com = $session->{cmd}->{cmd};
355            3                                  8               my $arg;
356                                                   
357   ***      3     50                          11               if ( $com eq COM_QUERY ) {
358            3                                  8                  $com = 'Query';
359            3                                 11                  $arg = $session->{cmd}->{arg};
360                                                               }
361                                                               else {
362   ***      0                                  0                  $arg = 'administrator command: '
363                                                                       . ucfirst(lc(substr($com_for{$com}, 4)));
364   ***      0                                  0                  $com = 'Admin';
365                                                               }
366                                                   
367            3                                 32               return $self->_make_event(
368                                                                  {  cmd           => $com,
369                                                                     arg           => $arg,
370                                                                     ts            => $packet->{ts},
371                                                                     Insert_id     => $ok->{insert_id},
372                                                                     Warning_count => $ok->{warnings},
373                                                                     Rows_affected => $ok->{affected_rows},
374                                                                  },
375                                                                  $packet, $session
376                                                               );
377                                                            } 
378                                                            else {
379   ***      0                                  0               MKDEBUG && _d('Looks like an OK packet but session has no cmd');
380                                                            }
381                                                         }
382                                                         elsif ( $first_byte eq 'ff' ) {
383            2                                  9            my $error = parse_error_packet($data);
384   ***      2     50                           7            if ( !$error ) {
385   ***      0                                  0               $self->fail_session($session, 'failed to parse error packet');
386   ***      0                                  0               return;
387                                                            }
388            2                                  6            my $event;
389                                                   
390            2    100                          12            if ( $session->{state} eq 'client_auth' ) {
      ***            50                               
391            1                                  6               MKDEBUG && _d('Connection failed');
392   ***      1     50                          10               $event = {
393                                                                  cmd       => 'Admin',
394                                                                  arg       => 'administrator command: Connect',
395                                                                  ts        => $packet->{ts},
396                                                                  Error_no  => $error->{errno} ? "#$error->{errno}" : 'none',
397                                                               };
398            1                                  5               return $self->_make_event($event, $packet, $session);
399   ***      0                                  0               $session->{state} = 'closing';
400                                                            }
401                                                            elsif ( $session->{cmd} ) {
402                                                               # This error should be in response to a query or something
403                                                               # sent earlier by the client.
404            1                                  4               my $com = $session->{cmd}->{cmd};
405            1                                  3               my $arg;
406                                                   
407   ***      1     50                           4               if ( $com eq COM_QUERY ) {
408            1                                  3                  $com = 'Query';
409            1                                  4                  $arg = $session->{cmd}->{arg};
410                                                               }
411                                                               else {
412   ***      0                                  0                  $arg = 'administrator command: '
413                                                                       . ucfirst(lc(substr($com_for{$com}, 4)));
414   ***      0                                  0                  $com = 'Admin';
415                                                               }
416                                                   
417   ***      1     50                           9               $event = {
418                                                                  cmd       => $com,
419                                                                  arg       => $arg,
420                                                                  ts        => $packet->{ts},
421                                                                  Error_no  => $error->{errno} ? "#$error->{errno}" : 'none',
422                                                               };
423            1                                  5               return $self->_make_event($event, $packet, $session);
424                                                            }
425                                                            else {
426   ***      0                                  0               MKDEBUG && _d('Looks like an error packet but client is not '
427                                                                  . 'authenticating and session has no cmd');
428                                                            }
429                                                         }
430                                                         elsif ( $first_byte eq 'fe' && $packet->{mysql_data_len} < 9 ) {
431                                                            # EOF packet
432   ***      1     50     33                   17            if ( $packet->{mysql_data_len} == 1
      ***                   33                        
433                                                                 && $session->{state} eq 'client_auth'
434                                                                 && $packet->{number} == 2 )
435                                                            {
436            1                                  2               MKDEBUG && _d('Server has old password table;',
437                                                                  'client will resend password using old algorithm');
438            1                                  4               $session->{state} = 'client_auth_resend';
439                                                            }
440                                                            else {
441   ***      0                                  0               MKDEBUG && _d('Got an EOF packet');
442   ***      0                                  0               die "Got an unexpected EOF packet";
443                                                               # ^^^ We shouldn't reach this because EOF should come after a
444                                                               # header, field, or row data packet; and we should be firing the
445                                                               # event and returning when we see that.  See SVN history for some
446                                                               # good stuff we could do if we wanted to handle EOF packets.
447                                                            }
448                                                         }
449                                                         else {
450                                                            # Since we do NOT always have all the data the server sent to the
451                                                            # client, we can't always do any processing of results.  So when
452                                                            # we get one of these, we just fire the event even if the query
453                                                            # is not done.  This means we will NOT process EOF packets
454                                                            # themselves (see above).
455   ***     10     50                          39            if ( $session->{cmd} ) {
456           10                                 21               MKDEBUG && _d('Got a row/field/result packet');
457           10                                 39               my $com = $session->{cmd}->{cmd};
458           10                                 22               MKDEBUG && _d('Responding to client', $com_for{$com});
459           10                                 42               my $event = { ts  => $packet->{ts} };
460   ***     10     50                          35               if ( $com eq COM_QUERY ) {
461           10                                 35                  $event->{cmd} = 'Query';
462           10                                 45                  $event->{arg} = $session->{cmd}->{arg};
463                                                               }
464                                                               else {
465   ***      0                                  0                  $event->{arg} = 'administrator command: '
466                                                                       . ucfirst(lc(substr($com_for{$com}, 4)));
467   ***      0                                  0                  $event->{cmd} = 'Admin';
468                                                               }
469                                                   
470                                                               # We DID get all the data in the packet.
471   ***     10     50                          44               if ( $packet->{complete} ) {
472                                                                  # Look to see if the end of the data appears to be an EOF
473                                                                  # packet.
474           10                                112                  my ( $warning_count, $status_flags )
475                                                                     = $data =~ m/fe(.{4})(.{4})\Z/;
476           10    100                          41                  if ( $warning_count ) { 
477            9                                 48                     $event->{Warnings} = to_num($warning_count);
478            9                                 30                     my $flags = to_num($status_flags); # TODO set all flags?
479   ***      9     50                          49                     $event->{No_good_index_used}
480                                                                        = $flags & SERVER_QUERY_NO_GOOD_INDEX_USED ? 1 : 0;
481            9    100                          47                     $event->{No_index_used}
482                                                                        = $flags & SERVER_QUERY_NO_INDEX_USED ? 1 : 0;
483                                                                  }
484                                                               }
485                                                   
486           10                                 44               return $self->_make_event($event, $packet, $session);
487                                                            }
488                                                            else {
489   ***      0                                  0               MKDEBUG && _d('Unknown in-stream server response');
490                                                            }
491                                                         }
492                                                      }
493                                                   
494            6                                 22      return;
495                                                   }
496                                                   
497                                                   # Handles a packet from the client given the state of the session.
498                                                   # The client doesn't send a wide and exotic array of packets like
499                                                   # the server.  Even so, we're only interested in:
500                                                   #    * Users and dbs from connection handshake packets
501                                                   #    * SQL statements from COM_QUERY commands
502                                                   # Anything else is ignored.  Returns an event if one was ready to be
503                                                   # created, otherwise returns nothing.
504                                                   sub _packet_from_client {
505           24                   24            95      my ( $self, $packet, $session, $misc ) = @_;
506   ***     24     50                          97      die "I need a packet"  unless $packet;
507   ***     24     50                          87      die "I need a session" unless $session;
508                                                   
509           24                                 50      MKDEBUG && _d('Packet is from client; state:', $session->{state}); 
510                                                   
511           24    100    100                  205      if ( ($session->{client_seq} || '') eq $packet->{seq} ) {
512            1                                  2         push @{ $session->{client_retransmissions} }, $packet->{seq};
               1                                  6   
513            1                                  2         MKDEBUG && _d('TCP retransmission');
514            1                                  4         return;
515                                                      }
516           23                                 95      $session->{client_seq} = $packet->{seq};
517                                                   
518           23                                 76      my $data  = $packet->{data};
519           23                                 69      my $ts    = $packet->{ts};
520                                                   
521           23    100    100                  365      if ( ($session->{state} || '') eq 'server_handshake' ) {
                    100    100                        
      ***            50     50                        
522            5                                 11         MKDEBUG && _d('Expecting client authentication packet');
523                                                         # The connection is a 3-way handshake:
524                                                         #    server > client  (protocol version, thread id, etc.)
525                                                         #    client > server  (user, pass, default db, etc.)
526                                                         #    server > client  OK if login succeeds
527                                                         # pos_in_log refers to 2nd handshake from the client.
528                                                         # A connection is logged even if the client fails to
529                                                         # login (bad password, etc.).
530            5                                 20         my $handshake = parse_client_handshake_packet($data);
531   ***      5     50                          22         if ( !$handshake ) {
532   ***      0                                  0            $self->fail_session($session, 'failed to parse client handshake');
533   ***      0                                  0            return;
534                                                         }
535            5                                 19         $session->{state}         = 'client_auth';
536            5                                 21         $session->{pos_in_log}    = $packet->{pos_in_log};
537            5                                 22         $session->{user}          = $handshake->{user};
538            5                                 21         $session->{db}            = $handshake->{db};
539                                                   
540                                                         # $session->{will_compress} will become $session->{compress} when
541                                                         # the server's final handshake packet is received.  This prevents
542                                                         # parse_packet() from trying to decompress that final packet.
543                                                         # Compressed packets can only begin after the full handshake is done.
544            5                                 37         $session->{will_compress} = $handshake->{flags}->{CLIENT_COMPRESS};
545                                                      }
546                                                      elsif ( ($session->{state} || '') eq 'client_auth_resend' ) {
547                                                         # Don't know how to parse this packet.
548            1                                  3         MKDEBUG && _d('Client resending password using old algorithm');
549            1                                  3         $session->{state} = 'client_auth';
550                                                      }
551                                                      elsif ( ($session->{state} || '') eq 'awaiting_reply' ) {
552   ***      0      0                           0         my $arg = $session->{cmd}->{arg} ? substr($session->{cmd}->{arg}, 0, 50)
553                                                                 : 'unknown';
554   ***      0                                  0         MKDEBUG && _d('More data for previous command:', $arg, '...'); 
555   ***      0                                  0         return;
556                                                      }
557                                                      else {
558                                                         # Otherwise, it should be a query.  We ignore the commands
559                                                         # that take arguments (COM_CHANGE_USER, COM_PROCESS_KILL).
560                                                   
561                                                         # Detect compression in-stream only if $session->{compress} is
562                                                         # not defined.  This means we didn't see the client handshake.
563                                                         # If we had seen it, $session->{compress} would be defined as 0 or 1.
564           17    100                          81         if ( !defined $session->{compress} ) {
565   ***     10     50                          43            return unless $self->detect_compression($packet, $session);
566           10                                 34            $data = $packet->{data};
567                                                         }
568                                                   
569           17                                 80         my $com = parse_com_packet($data, $packet->{mysql_data_len});
570   ***     17     50                          67         if ( !$com ) {
571   ***      0                                  0            $self->fail_session($session, 'failed to parse COM packet');
572   ***      0                                  0            return;
573                                                         }
574           17                                 59         $session->{state}      = 'awaiting_reply';
575           17                                 67         $session->{pos_in_log} = $packet->{pos_in_log};
576           17                                 56         $session->{ts}         = $ts;
577           17                                 96         $session->{cmd}        = {
578                                                            cmd => $com->{code},
579                                                            arg => $com->{data},
580                                                         };
581                                                   
582           17    100                          93         if ( $com->{code} eq COM_QUIT ) { # Fire right away; will cleanup later.
583            2                                  5            MKDEBUG && _d('Got a COM_QUIT');
584            2                                 14            return $self->_make_event(
585                                                               {  cmd       => 'Admin',
586                                                                  arg       => 'administrator command: Quit',
587                                                                  ts        => $ts,
588                                                               },
589                                                               $packet, $session
590                                                            );
591   ***      0                                  0            $session->{state} = 'closing';
592                                                         }
593                                                      }
594                                                   
595           21                                 69      return;
596                                                   }
597                                                   
598                                                   # Make and return an event from the given packet and session.
599                                                   sub _make_event {
600           21                   21            93      my ( $self, $event, $packet, $session ) = @_;
601           21                                 45      MKDEBUG && _d('Making event');
602                                                   
603                                                      # Clear packets that preceded this event.
604           21                                 78      $session->{raw_packets} = [];
605                                                   
606           21    100                         108      if ( !$session->{thread_id} ) {
607                                                         # Only the server handshake packet gives the thread id, so for
608                                                         # sessions caught mid-stream we assign a fake thread id.
609           10                                 20         MKDEBUG && _d('Giving session fake thread id', $self->{fake_thread_id});
610           10                                 52         $session->{thread_id} = $self->{fake_thread_id}++;
611                                                      }
612                                                   
613           21                                171      my ($host, $port) = $session->{client} =~ m/((?:\d+\.){3}\d+)\:(\w+)/;
614   ***     21     50    100                  146      my $new_event = {
                    100    100                        
                           100                        
615                                                         cmd        => $event->{cmd},
616                                                         arg        => $event->{arg},
617                                                         bytes      => length( $event->{arg} ),
618                                                         ts         => tcp_timestamp( $event->{ts} ),
619                                                         host       => $host,
620                                                         ip         => $host,
621                                                         port       => $port,
622                                                         db         => $session->{db},
623                                                         user       => $session->{user},
624                                                         Thread_id  => $session->{thread_id},
625                                                         pos_in_log => $session->{pos_in_log},
626                                                         Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
627                                                         Error_no   => $event->{Error_no} || 'none',
628                                                         Rows_affected      => ($event->{Rows_affected} || 0),
629                                                         Warning_count      => ($event->{Warning_count} || 0),
630                                                         No_good_index_used => ($event->{No_good_index_used} ? 'Yes' : 'No'),
631                                                         No_index_used      => ($event->{No_index_used}      ? 'Yes' : 'No'),
632                                                      };
633           21                                 60      MKDEBUG && _d('Properties of event:', Dumper($new_event));
634                                                   
635                                                      # Delete cmd to prevent re-making the same event if the
636                                                      # server sends extra stuff that looks like a result set, etc.
637           21                                 81      delete $session->{cmd};
638                                                   
639                                                      # Undef the session state so that we ignore everything from
640                                                      # the server and wait until the client says something again.
641           21                                 62      $session->{state} = undef;
642                                                   
643           21                                123      return $new_event;
644                                                   }
645                                                   
646                                                   # Extracts a slow-log-formatted timestamp from the tcpdump timestamp format.
647                                                   sub tcp_timestamp {
648           21                   21            84      my ( $ts ) = @_;
649           21                                226      $ts =~ s/^\d\d(\d\d)-(\d\d)-(\d\d)/$1$2$3/;
650           21                                206      return $ts;
651                                                   }
652                                                   
653                                                   # Returns the difference between two tcpdump timestamps.
654                                                   sub timestamp_diff {
655           21                   21            80      my ( $start, $end ) = @_;
656           21                                 82      my $sd = substr($start, 0, 11, '');
657           21                                 63      my $ed = substr($end,   0, 11, '');
658           21                                130      my ( $sh, $sm, $ss ) = split(/:/, $start);
659           21                                 90      my ( $eh, $em, $es ) = split(/:/, $end);
660           21                                119      my $esecs = ($eh * 3600 + $em * 60 + $es);
661           21                                 84      my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
662   ***     21     50                          77      if ( $sd eq $ed ) {
663           21                                817         return sprintf '%.6f', $esecs - $ssecs;
664                                                      }
665                                                      else { # Assume only one day boundary has been crossed, no DST, etc
666   ***      0                                  0         return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
667                                                      }
668                                                   }
669                                                   
670                                                   # Converts hexadecimal to string.
671                                                   sub to_string {
672           56                   56           203      my ( $data ) = @_;
673                                                      # $data =~ s/(..)/chr(hex $1)/eg;
674           56                                241      $data = pack('H*', $data);
675           56                                218      return $data;
676                                                   }
677                                                   
678                                                   # All numbers are stored with the least significant byte first in the MySQL
679                                                   # protocol.
680                                                   sub to_num {
681          165                  165           606      my ( $str ) = @_;
682          165                                956      my @bytes = $str =~ m/(..)/g;
683          165                                474      my $result = 0;
684          165                                781      foreach my $i ( 0 .. $#bytes ) {
685          360                               1735         $result += hex($bytes[$i]) * (16 ** ($i * 2));
686                                                      }
687          165                                660      return $result;
688                                                   }
689                                                   
690                                                   # Accepts a reference to a string, which it will modify.  Extracts a
691                                                   # length-coded binary off the front of the string and returns that value as an
692                                                   # integer.
693                                                   sub get_lcb {
694            8                    8            26      my ( $string ) = @_;
695            8                                 31      my $first_byte = hex(substr($$string, 0, 2, ''));
696   ***      8     50                          26      if ( $first_byte < 251 ) {
      ***             0                               
      ***             0                               
      ***             0                               
697            8                                 26         return $first_byte;
698                                                      }
699                                                      elsif ( $first_byte == 252 ) {
700   ***      0                                  0         return to_num(substr($$string, 0, 4, ''));
701                                                      }
702                                                      elsif ( $first_byte == 253 ) {
703   ***      0                                  0         return to_num(substr($$string, 0, 6, ''));
704                                                      }
705                                                      elsif ( $first_byte == 254 ) {
706   ***      0                                  0         return to_num(substr($$string, 0, 16, ''));
707                                                      }
708                                                   }
709                                                   
710                                                   # Error packet structure:
711                                                   # Offset  Bytes               Field
712                                                   # ======  =================   ====================================
713                                                   #         00 00 00 01         MySQL proto header (already removed)
714                                                   #         ff                  Error  (already removed)
715                                                   # 0       00 00               Error number
716                                                   # 4       23                  SQL state marker, always '#'
717                                                   # 6       00 00 00 00 00      SQL state
718                                                   # 16      00 ...              Error message
719                                                   # The sqlstate marker and actual sqlstate are combined into one value. 
720                                                   sub parse_error_packet {
721            3                    3            19      my ( $data ) = @_;
722   ***      3     50                          14      die "I need data" unless $data;
723            3                                  6      MKDEBUG && _d('ERROR data:', $data);
724   ***      3     50                          14      if ( length $data < 16 ) {
725   ***      0                                  0         MKDEBUG && _d('Error packet is too short:', $data);
726   ***      0                                  0         return;
727                                                      }
728            3                                 13      my $errno    = to_num(substr($data, 0, 4));
729            3                                 14      my $marker   = to_string(substr($data, 4, 2));
730   ***      3     50                          14      return unless $marker eq '#';
731            3                                 11      my $sqlstate = to_string(substr($data, 6, 10));
732            3                                 12      my $message  = to_string(substr($data, 16));
733            3                                 21      my $pkt = {
734                                                         errno    => $errno,
735                                                         sqlstate => $marker . $sqlstate,
736                                                         message  => $message,
737                                                      };
738            3                                  7      MKDEBUG && _d('Error packet:', Dumper($pkt));
739            3                                 15      return $pkt;
740                                                   }
741                                                   
742                                                   # OK packet structure:
743                                                   # Offset  Bytes               Field
744                                                   # ======  =================   ====================================
745                                                   #         00 00 00 01         MySQL proto header (already removed)
746                                                   #         00                  OK  (already removed)
747                                                   #         1-9                 Affected rows (LCB)
748                                                   #         1-9                 Insert ID (LCB)
749                                                   #         00 00               Server status
750                                                   #         00 00               Warning count
751                                                   #         00 ...              Message (optional)
752                                                   sub parse_ok_packet {
753            4                    4            16      my ( $data ) = @_;
754   ***      4     50                          17      die "I need data" unless $data;
755            4                                  8      MKDEBUG && _d('OK data:', $data);
756   ***      4     50                          16      if ( length $data < 12 ) {
757   ***      0                                  0         MKDEBUG && _d('OK packet is too short:', $data);
758   ***      0                                  0         return;
759                                                      }
760            4                                 15      my $affected_rows = get_lcb(\$data);
761            4                                 14      my $insert_id     = get_lcb(\$data);
762            4                                 18      my $status        = to_num(substr($data, 0, 4, ''));
763            4                                 20      my $warnings      = to_num(substr($data, 0, 4, ''));
764            4                                 13      my $message       = to_string($data);
765                                                      # Note: $message is discarded.  It might be something like
766                                                      # Records: 2  Duplicates: 0  Warnings: 0
767            4                                 29      my $pkt = {
768                                                         affected_rows => $affected_rows,
769                                                         insert_id     => $insert_id,
770                                                         status        => $status,
771                                                         warnings      => $warnings,
772                                                         message       => $message,
773                                                      };
774            4                                  9      MKDEBUG && _d('OK packet:', Dumper($pkt));
775            4                                 29      return $pkt;
776                                                   }
777                                                   
778                                                   # Currently we only capture and return the thread id.
779                                                   sub parse_server_handshake_packet {
780            6                    6            30      my ( $data ) = @_;
781   ***      6     50                          25      die "I need data" unless $data;
782            6                                 12      MKDEBUG && _d('Server handshake data:', $data);
783            6                                 44      my $handshake_pattern = qr{
784                                                                           # Bytes                Name
785                                                         ^                 # -----                ----
786                                                         (.+?)00           # n Null-Term String   server_version
787                                                         (.{8})            # 4                    thread_id
788                                                         .{16}             # 8                    scramble_buff
789                                                         .{2}              # 1                    filler: always 0x00
790                                                         (.{4})            # 2                    server_capabilities
791                                                         .{2}              # 1                    server_language
792                                                         .{4}              # 2                    server_status
793                                                         .{26}             # 13                   filler: always 0x00
794                                                                           # 13                   rest of scramble_buff
795                                                      }x;
796            6                                 73      my ( $server_version, $thread_id, $flags ) = $data =~ m/$handshake_pattern/;
797            6                                 29      my $pkt = {
798                                                         server_version => to_string($server_version),
799                                                         thread_id      => to_num($thread_id),
800                                                         flags          => parse_flags($flags),
801                                                      };
802            6                                 15      MKDEBUG && _d('Server handshake packet:', Dumper($pkt));
803            6                                 54      return $pkt;
804                                                   }
805                                                   
806                                                   # Currently we only capture and return the user and default database.
807                                                   sub parse_client_handshake_packet {
808            6                    6            27      my ( $data ) = @_;
809   ***      6     50                          26      die "I need data" unless $data;
810            6                                 15      MKDEBUG && _d('Client handshake data:', $data);
811            6                                 66      my ( $flags, $user, $buff_len ) = $data =~ m{
812                                                         ^
813                                                         (.{8})         # Client flags
814                                                         .{10}          # Max packet size, charset
815                                                         (?:00){23}     # Filler
816                                                         ((?:..)+?)00   # Null-terminated user name
817                                                         (..)           # Length-coding byte for scramble buff
818                                                      }x;
819                                                   
820                                                      # This packet is easy to detect because it's the only case where
821                                                      # the server sends the client a packet first (its handshake) and
822                                                      # then the client only and ever sends back its handshake.
823   ***      6     50                          29      if ( !$buff_len ) {
824   ***      0                                  0         MKDEBUG && _d('Did not match client handshake packet');
825   ***      0                                  0         return;
826                                                      }
827                                                   
828                                                      # This length-coded binary doesn't seem to be a normal one, it
829                                                      # seems more like a length-coded string actually.
830            6                                 16      my $code_len = hex($buff_len);
831            6                                153      my ( $db ) = $data =~ m!
832                                                         ^.{64}${user}00..   # Everything matched before
833                                                         (?:..){$code_len}   # The scramble buffer
834                                                         (.*)00\Z            # The database name
835                                                      !x;
836            6    100                          24      my $pkt = {
837                                                         user  => to_string($user),
838                                                         db    => $db ? to_string($db) : '',
839                                                         flags => parse_flags($flags),
840                                                      };
841            6                                 15      MKDEBUG && _d('Client handshake packet:', Dumper($pkt));
842            6                                 35      return $pkt;
843                                                   }
844                                                   
845                                                   # COM data is not 00-terminated, but the the MySQL client appends \0,
846                                                   # so we have to use the packet length to know where the data ends.
847                                                   sub parse_com_packet {
848           28                   28           116      my ( $data, $len ) = @_;
849   ***     28     50                         113      die "I need data"  unless $data;
850   ***     28     50                          90      die "I need a len" unless $len;
851           28                                 58      MKDEBUG && _d('COM data:', $data, 'len:', $len);
852           28                                 95      my $code = substr($data, 0, 2);
853           28                                 85      my $com  = $com_for{$code};
854   ***     28     50                          98      if ( !$com ) {
855   ***      0                                  0         MKDEBUG && _d('Did not match COM packet');
856   ***      0                                  0         return;
857                                                      }
858           28                                134      $data    = to_string(substr($data, 2, ($len - 1) * 2));
859           28                                150      my $pkt = {
860                                                         code => $code,
861                                                         com  => $com,
862                                                         data => $data,
863                                                      };
864           28                                 60      MKDEBUG && _d('COM packet:', Dumper($pkt));
865           28                                 97      return $pkt;
866                                                   }
867                                                   
868                                                   sub parse_flags {
869           12                   12            44      my ( $flags ) = @_;
870   ***     12     50                          44      die "I need flags" unless $flags;
871           12                                 26      MKDEBUG && _d('Flag data:', $flags);
872           12                                149      my %flags     = %flag_for;
873           12                                 52      my $flags_dec = to_num($flags);
874           12                                 67      foreach my $flag ( keys %flag_for ) {
875          216                                585         my $flagno    = $flag_for{$flag};
876          216    100                         876         $flags{$flag} = ($flags_dec & $flagno ? 1 : 0);
877                                                      }
878           12                                 85      return \%flags;
879                                                   }
880                                                   
881                                                   # Takes a scalarref to a hex string of compressed data.
882                                                   # Returns a scalarref to a hex string of the uncompressed data.
883                                                   # The given hex string of compressed data is not modified.
884                                                   sub uncompress_data {
885            1                    1             4      my ( $data, $len ) = @_;
886   ***      1     50                           5      die "I need data" unless $data;
887   ***      1     50                           4      die "I need a len argument" unless $len;
888   ***      1     50                           5      die "I need a scalar reference to data" unless ref $data eq 'SCALAR';
889            1                                  2      MKDEBUG && _d('Uncompressing data');
890            1                                  3      our $InflateError;
891                                                   
892                                                      # Pack hex string into compressed binary data.
893            1                                 88      my $comp_bin_data = pack('H*', $$data);
894                                                   
895                                                      # Uncompress the compressed binary data.
896            1                                  4      my $uncomp_bin_data = '';
897   ***      1     50                          13      my $z = new IO::Uncompress::Inflate(
898                                                         \$comp_bin_data
899                                                      ) or die "IO::Uncompress::Inflate failed: $InflateError";
900   ***      1     50                          12      my $status = $z->read(\$uncomp_bin_data, $len)
901                                                         or die "IO::Uncompress::Inflate failed: $InflateError";
902                                                   
903                                                      # Unpack the uncompressed binary data back into a hex string.
904                                                      # This is the original MySQL packet(s).
905            1                                 75      my $uncomp_data = unpack('H*', $uncomp_bin_data);
906                                                   
907            1                                  2      return \$uncomp_data;
908                                                   }
909                                                   
910                                                   # Returns 1 on success or 0 on failure.  Failure is probably
911                                                   # detecting compression but not being able to uncompress
912                                                   # (uncompress_packet() returns 0).
913                                                   sub detect_compression {
914           10                   10            42      my ( $self, $packet, $session ) = @_;
915           10                                 22      MKDEBUG && _d('Checking for client compression');
916                                                      # This is a necessary hack for detecting compression in-stream without
917                                                      # having seen the client handshake and CLIENT_COMPRESS flag.  If the
918                                                      # client is compressing packets, there will be an extra 7 bytes before
919                                                      # the regular MySQL header.  For short COM_QUERY commands, these 7 bytes
920                                                      # are usually zero where we'd expect to see 03 for COM_QUERY.  So if we
921                                                      # parse this packet and it looks like a COM_SLEEP (00) which is not a
922                                                      # command that the client can send, then chances are the client is using
923                                                      # compression.
924           10                                 49      my $com = parse_com_packet($packet->{data}, $packet->{data_len});
925   ***     10    100     66                   90      if ( $com && $com->{code} eq COM_SLEEP ) {
926            1                                  3         MKDEBUG && _d('Client is using compression');
927            1                                  3         $session->{compress} = 1;
928                                                   
929                                                         # Since parse_packet() didn't know the packet was compressed, it
930                                                         # called remove_mysql_header() which removed the first 4 of 7 bytes
931                                                         # of the compression header.  We must restore these 4 bytes, then
932                                                         # uncompress and remove the MySQL header.  We only do this once.
933            1                                  6         $packet->{data} = $packet->{mysql_hdr} . $packet->{data};
934   ***      1     50                           4         return 0 unless $self->uncompress_packet($packet, $session);
935            1                                  3         remove_mysql_header($packet);
936                                                      }
937                                                      else {
938            9                                 21         MKDEBUG && _d('Client is NOT using compression');
939            9                                 30         $session->{compress} = 0;
940                                                      }
941           10                                 54      return 1;
942                                                   }
943                                                   
944                                                   # Returns 1 if the packet was uncompressed or 0 if we can't uncompress.
945                                                   # Failure is usually due to IO::Uncompress not being available.
946                                                   sub uncompress_packet {
947            6                    6            39      my ( $self, $packet, $session ) = @_;
948   ***      6     50                          26      die "I need a packet"  unless $packet;
949   ***      6     50                          18      die "I need a session" unless $session;
950                                                   
951                                                      # From the doc: "A compressed packet header is:
952                                                      #    packet length (3 bytes),
953                                                      #    packet number (1 byte),
954                                                      #    and Uncompressed Packet Length (3 bytes).
955                                                      # The Uncompressed Packet Length is the number of bytes
956                                                      # in the original, uncompressed packet. If this is zero
957                                                      # then the data is not compressed."
958                                                   
959            6                                 16      my $data;
960            6                                 13      my $comp_hdr;
961            6                                 13      my $comp_data_len;
962            6                                 12      my $pkt_num;
963            6                                 15      my $uncomp_data_len;
964            6                                 15      eval {
965            6                                 23         $data            = \$packet->{data};
966            6                                 26         $comp_hdr        = substr($$data, 0, 14, '');
967            6                                 24         $comp_data_len   = to_num(substr($comp_hdr, 0, 6));
968            6                                 24         $pkt_num         = to_num(substr($comp_hdr, 6, 2));
969            6                                 25         $uncomp_data_len = to_num(substr($comp_hdr, 8, 6));
970            6                                 16         MKDEBUG && _d('Compression header data:', $comp_hdr,
971                                                            'compressed data len (bytes)', $comp_data_len,
972                                                            'number', $pkt_num,
973                                                            'uncompressed data len (bytes)', $uncomp_data_len);
974                                                      };
975   ***      6     50                          20      if ( $EVAL_ERROR ) {
976   ***      0                                  0         $session->{EVAL_ERROR} = $EVAL_ERROR;
977   ***      0                                  0         $self->fail_session($session, 'failed to parse compression header');
978   ***      0                                  0         return 0;
979                                                      }
980                                                   
981            6    100                          23      if ( $uncomp_data_len ) {
982            1                                  3         eval {
983            1                                  4            $data = uncompress_data($data, $uncomp_data_len);
984            1                                 41            $packet->{data} = $$data;
985                                                         };
986   ***      1     50                           6         if ( $EVAL_ERROR ) {
987   ***      0                                  0            $session->{EVAL_ERROR} = $EVAL_ERROR;
988   ***      0                                  0            $self->fail_session($session, 'failed to uncompress data');
989   ***      0                                  0            die "Cannot uncompress packet.  Check that IO::Uncompress::Inflate "
990                                                               . "is installed.\nError: $EVAL_ERROR";
991                                                         }
992                                                      }
993                                                      else {
994            5                                 11         MKDEBUG && _d('Packet is not really compressed');
995            5                                 16         $packet->{data} = $$data;
996                                                      }
997                                                   
998            6                                 32      return 1;
999                                                   }
1000                                                  
1001                                                  # Removes the first 4 bytes of the packet data which should be
1002                                                  # a MySQL header: 3 bytes packet length, 1 byte packet number.
1003                                                  sub remove_mysql_header {
1004          50                   50           169      my ( $packet ) = @_;
1005  ***     50     50                         187      die "I need a packet" unless $packet;
1006                                                  
1007                                                     # NOTE: the data is modified by the inmost substr call here!  If we
1008                                                     # had all the data in the TCP packets, we could change this to a while
1009                                                     # loop; while get-a-packet-from-$data, do stuff, etc.  But we don't,
1010                                                     # and we don't want to either.
1011          50                                225      my $mysql_hdr      = substr($packet->{data}, 0, 8, '');
1012          50                                202      my $mysql_data_len = to_num(substr($mysql_hdr, 0, 6));
1013          50                                202      my $pkt_num        = to_num(substr($mysql_hdr, 6, 2));
1014          50                                110      MKDEBUG && _d('MySQL packet: header data', $mysql_hdr,
1015                                                        'data len (bytes)', $mysql_data_len, 'number', $pkt_num);
1016                                                  
1017          50                                251      $packet->{mysql_hdr}      = $mysql_hdr;
1018          50                                165      $packet->{mysql_data_len} = $mysql_data_len;
1019          50                                154      $packet->{number}         = $pkt_num;
1020                                                  
1021          50                                142      return;
1022                                                  }
1023                                                  
1024                                                  sub _get_errors_fh {
1025  ***      0                    0                    my ( $self ) = @_;
1026  ***      0                                         my $errors_fh = $self->{errors_fh};
1027  ***      0      0                                  return $errors_fh if $errors_fh;
1028                                                  
1029                                                     # Errors file isn't open yet; try to open it.
1030  ***      0                                         my $o = $self->{o};
1031  ***      0      0      0                           if ( $o && $o->has('tcpdump-errors') && $o->got('tcpdump-errors') ) {
      ***                    0                        
1032  ***      0                                            my $errors_file = $o->get('tcpdump-errors');
1033  ***      0                                            MKDEBUG && _d('tcpdump-errors file:', $errors_file);
1034  ***      0      0                                     open $errors_fh, '>>', $errors_file
1035                                                           or die "Cannot open tcpdump-errors file $errors_file: $OS_ERROR";
1036                                                     }
1037                                                  
1038  ***      0                                         $self->{errors_fh} = $errors_fh;
1039  ***      0                                         return $errors_fh;
1040                                                  }
1041                                                  
1042                                                  sub fail_session {
1043  ***      0                    0                    my ( $self, $session, $reason ) = @_;
1044  ***      0                                         my $errors_fh = $self->_get_errors_fh();
1045  ***      0      0                                  if ( $errors_fh ) {
1046  ***      0                                            $session->{reason_for_failure} = $reason;
1047  ***      0                                            my $session_dump = '# ' . Dumper($session);
1048  ***      0                                            chomp $session_dump;
1049  ***      0                                            $session_dump =~ s/\n/\n# /g;
1050  ***      0                                            print $errors_fh "$session_dump\n";
1051                                                        {
1052  ***      0                                               local $LIST_SEPARATOR = "\n";
      ***      0                                      
1053  ***      0                                               print $errors_fh "@{$session->{raw_packets}}";
      ***      0                                      
1054  ***      0                                               print $errors_fh "\n";
1055                                                        }
1056                                                     }
1057  ***      0                                         MKDEBUG && _d('Failed session', $session->{client}, 'because', $reason);
1058  ***      0                                         delete $self->{sessions}->{$session->{client}};
1059  ***      0                                         return;
1060                                                  }
1061                                                  
1062                                                  sub _d {
1063  ***      0                    0                    my ($package, undef, $line) = caller 0;
1064  ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
1065  ***      0                                              map { defined $_ ? $_ : 'undef' }
1066                                                          @_;
1067  ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
1068                                                  }
1069                                                  
1070                                                  1;
1071                                                  
1072                                                  # ###########################################################################
1073                                                  # End MySQLProtocolParser package
1074                                                  # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
159          100      6      8   $args{'server'} ? :
183          100     44     50   if (my $server = $$self{'server'})
184          100      3     41   if ($src_host ne $server and $dst_host ne $server)
194          100     41     50   if ($src_host =~ /:$$self{'server_port'}$/) { }
      ***     50     50      0   elsif ($dst_host =~ /:$$self{'server_port'}$/) { }
210          100     15     76   if (not exists $$self{'sessions'}{$client})
225          100     42     49   if ($$packet{'data_len'} == 0)
228   ***     50      0     42   if (($$session{'state'} || '') eq 'closing')
240          100      5     44   if ($$session{'compress'})
241   ***     50      0      5   unless $self->uncompress_packet($packet, $session)
253          100     25     24   if ($packet_from eq 'server') { }
      ***     50     24      0   elsif ($packet_from eq 'client') { }
277   ***     50      0     25   unless $packet
278   ***     50      0     25   unless $session
282   ***     50      0     25   if (($$session{'server_seq'} || '') eq $$packet{'seq'})
299   ***     50      0     25   if (not $first_byte)
307          100      5     20   if (not $$session{'state'}) { }
308   ***     50      5      0   if ($first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/) { }
316   ***     50      0      5   if (not $handshake)
329          100      7     13   if ($first_byte eq '00') { }
             100      2     11   elsif ($first_byte eq 'ff') { }
             100      1     10   elsif ($first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9) { }
330          100      4      3   if (($$session{'state'} || '') eq 'client_auth') { }
      ***     50      3      0   elsif ($$session{'cmd'}) { }
350   ***     50      0      3   if (not $ok)
357   ***     50      3      0   if ($com eq '03') { }
384   ***     50      0      2   if (not $error)
390          100      1      1   if ($$session{'state'} eq 'client_auth') { }
      ***     50      1      0   elsif ($$session{'cmd'}) { }
392   ***     50      1      0   $$error{'errno'} ? :
407   ***     50      1      0   if ($com eq '03') { }
417   ***     50      1      0   $$error{'errno'} ? :
432   ***     50      1      0   if ($$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2) { }
455   ***     50     10      0   if ($$session{'cmd'}) { }
460   ***     50     10      0   if ($com eq '03') { }
471   ***     50     10      0   if ($$packet{'complete'})
476          100      9      1   if ($warning_count)
479   ***     50      0      9   $flags & 16 ? :
481          100      2      7   $flags & 32 ? :
506   ***     50      0     24   unless $packet
507   ***     50      0     24   unless $session
511          100      1     23   if (($$session{'client_seq'} || '') eq $$packet{'seq'})
521          100      5     18   if (($$session{'state'} || '') eq 'server_handshake') { }
             100      1     17   elsif (($$session{'state'} || '') eq 'client_auth_resend') { }
      ***     50      0     17   elsif (($$session{'state'} || '') eq 'awaiting_reply') { }
531   ***     50      0      5   if (not $handshake)
552   ***      0      0      0   $$session{'cmd'}{'arg'} ? :
564          100     10      7   if (not defined $$session{'compress'})
565   ***     50      0     10   unless $self->detect_compression($packet, $session)
570   ***     50      0     17   if (not $com)
582          100      2     15   if ($$com{'code'} eq '01')
606          100     10     11   if (not $$session{'thread_id'})
614   ***     50      0     21   $$event{'No_good_index_used'} ? :
             100      2     19   $$event{'No_index_used'} ? :
662   ***     50     21      0   if ($sd eq $ed) { }
696   ***     50      8      0   if ($first_byte < 251) { }
      ***      0      0      0   elsif ($first_byte == 252) { }
      ***      0      0      0   elsif ($first_byte == 253) { }
      ***      0      0      0   elsif ($first_byte == 254) { }
722   ***     50      0      3   unless $data
724   ***     50      0      3   if (length $data < 16)
730   ***     50      0      3   unless $marker eq '#'
754   ***     50      0      4   unless $data
756   ***     50      0      4   if (length $data < 12)
781   ***     50      0      6   unless $data
809   ***     50      0      6   unless $data
823   ***     50      0      6   if (not $buff_len)
836          100      3      3   $db ? :
849   ***     50      0     28   unless $data
850   ***     50      0     28   unless $len
854   ***     50      0     28   if (not $com)
870   ***     50      0     12   unless $flags
876          100     94    122   $flags_dec & $flagno ? :
886   ***     50      0      1   unless $data
887   ***     50      0      1   unless $len
888   ***     50      0      1   unless ref $data eq 'SCALAR'
897   ***     50      0      1   unless my $z = 'IO::Uncompress::Inflate'->new(\$comp_bin_data)
900   ***     50      0      1   unless my $status = $z->read(\$uncomp_bin_data, $len)
925          100      1      9   if ($com and $$com{'code'} eq '00') { }
934   ***     50      0      1   unless $self->uncompress_packet($packet, $session)
948   ***     50      0      6   unless $packet
949   ***     50      0      6   unless $session
975   ***     50      0      6   if ($EVAL_ERROR)
981          100      1      5   if ($uncomp_data_len) { }
986   ***     50      0      1   if ($EVAL_ERROR)
1005  ***     50      0     50   unless $packet
1027  ***      0      0      0   if $errors_fh
1031  ***      0      0      0   if ($o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors'))
1034  ***      0      0      0   unless open $errors_fh, '>>', $errors_file
1045  ***      0      0      0   if ($errors_fh)
1064  ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
184          100     19     22      3   $src_host ne $server and $dst_host ne $server
308   ***     33      0      0      5   $first_byte eq '0a' and length $data >= 33
      ***     33      0      0      5   $first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/
329   ***     66     10      0      1   $first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9
432   ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth'
      ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2
925   ***     66      0      9      1   $com and $$com{'code'} eq '00'
1031  ***      0      0      0      0   $o and $o->has('tcpdump-errors')
      ***      0      0      0      0   $o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors')

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
161   ***     50     14      0   $server_port ||= '3306|mysql'
228          100     12     30   $$session{'state'} || ''
282          100     10     15   $$session{'server_seq'} || ''
330   ***     50      7      0   $$session{'state'} || ''
511          100      9     15   $$session{'client_seq'} || ''
521          100      6     17   $$session{'state'} || ''
             100      1     17   $$session{'state'} || ''
      ***     50      0     17   $$session{'state'} || ''
614          100      2     19   $$event{'Error_no'} || 'none'
             100      3     18   $$event{'Rows_affected'} || 0
             100      1     20   $$event{'Warning_count'} || 0


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
_make_event                      21 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:600 
_packet_from_client              24 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:505 
_packet_from_server              25 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:276 
detect_compression               10 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:914 
get_lcb                           8 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:694 
new                              14 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:157 
parse_client_handshake_packet     6 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:808 
parse_com_packet                 28 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:848 
parse_error_packet                3 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:721 
parse_flags                      12 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:869 
parse_ok_packet                   4 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:753 
parse_packet                     94 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:178 
parse_server_handshake_packet     6 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:780 
remove_mysql_header              50 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1004
tcp_timestamp                    21 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:648 
timestamp_diff                   21 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:655 
to_num                          165 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:681 
to_string                        56 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:672 
uncompress_data                   1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:885 
uncompress_packet                 6 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:947 

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                                   
----------------------------- ----- -----------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1063
_get_errors_fh                    0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1025
fail_session                      0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:1043


