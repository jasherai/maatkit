---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/MySQLProtocolParser.pm   81.2   59.7   64.3   89.7    n/a  100.0   74.7
Total                          81.2   59.7   64.3   89.7    n/a  100.0   74.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jun 12 14:54:32 2009
Finish:       Fri Jun 12 14:54:32 2009

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
18                                                    # MySQLProtocolParser package $Revision: 3928 $
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
38             1                    1             9   use strict;
               1                                  2   
               1                                  6   
39             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
40             1                    1             9   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
41                                                    
42                                                    eval {
43                                                       require IO::Uncompress::Inflate;
44                                                       IO::Uncompress::Inflate->import(qw(inflate $InflateError));
45                                                    };
46                                                    
47             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  8   
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
67             1                                 32      COM_SLEEP               => '00',
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
157           11                   11           472      my ( $class, %args ) = @_;
158           11                                104      my $self = {
159                                                         server      => $args{server},
160                                                         version     => '41',
161                                                         sessions    => {},
162                                                         o           => $args{o},
163                                                         raw_packets => [],  # Raw tcpdump packets before event.
164                                                      };
165           11                                 82      return bless $self, $class;
166                                                   }
167                                                   
168                                                   # The packet arg should be a hashref from TcpdumpParser::parse_event().
169                                                   # misc is a placeholder for future features.
170                                                   sub parse_packet {
171           78                   78           912      my ( $self, $packet, $misc ) = @_;
172                                                   
173                                                      # Auto-detect the server by looking for port 3306 or port "mysql" (sometimes
174                                                      # tcpdump will substitute the port by a lookup in /etc/protocols or
175                                                      # something).
176           78                                360      my $from  = "$packet->{src_host}:$packet->{src_port}";
177           78                                326      my $to    = "$packet->{dst_host}:$packet->{dst_port}";
178   ***     78     50    100                  386      $self->{server} ||= $from =~ m/:(?:3306|mysql)$/ ? $from
      ***            50                               
179                                                                        : $to   =~ m/:(?:3306|mysql)$/ ? $to
180                                                                        :                                undef;
181           78    100                         369      my $client = $from eq $self->{server} ? $to : $from;
182           78                                172      MKDEBUG && _d('Client:', $client);
183                                                   
184                                                      # Get the client's session info or create a new session if the
185                                                      # client hasn't been seen before.
186           78    100                         381      if ( !exists $self->{sessions}->{$client} ) {
187           14                                 31         MKDEBUG && _d('New session');
188           14                                124         $self->{sessions}->{$client} = {
189                                                            client      => $client,
190                                                            ts          => $packet->{ts},
191                                                            state       => undef,
192                                                            compress    => undef,
193                                                         };
194                                                      };
195           78                                279      my $session = $self->{sessions}->{$client};
196           78                                308      $packet->{session_state} = $session->{state};
197                                                   
198                                                      # Return early if there's TCP/MySQL data.  These are usually ACK
199                                                      # packets, but they could also be FINs in which case, we should close
200                                                      # and delete the client's session.
201           78    100                         332      if ( $packet->{data_len} == 0 ) {
202           39                                 88         MKDEBUG && _d('No TCP/MySQL data');
203                                                         # Is the session ready to close?
204           39    100    100                  263         if ( ($session->{state} || '') eq 'closing' ) {
205            3                                 17            delete $self->{sessions}->{$session->{client}};
206            3                                  6            MKDEBUG && _d('Session deleted'); 
207                                                         }
208           39                                226         return;
209                                                      }
210                                                   
211                                                      # Return unless the compressed packet can be uncompressed.
212                                                      # If it cannot, then we're helpless and must return.
213           39    100                         158      if ( $session->{compress} ) {
214   ***      5     50                          21         return unless uncompress_packet($packet);
215                                                      }
216                                                   
217                                                      # Remove the first MySQL header.  A single TCP packet can contain many
218                                                      # MySQL packets, but we only look at the first.  The 2nd and subsequent
219                                                      # packets are usually parts of a resultset returned by the server, but
220                                                      # we're not interested in resultsets.
221           39                                141      remove_mysql_header($packet);
222                                                   
223                                                      # Finally, parse the packet and maybe create an event.
224                                                      # The returned event may be empty if no event was ready to be created.
225           39                                 92      my $event;
226           39    100                         191      if ( $from eq $self->{server} ) {
      ***            50                               
227           20                                 87         $event = $self->_packet_from_server($packet, $session, $misc);
228                                                      }
229                                                      elsif ( $from eq $client ) {
230           19                                 87         $event = $self->_packet_from_client($packet, $session, $misc);
231                                                      }
232                                                      else {
233   ***      0                                  0         MKDEBUG && _d('Packet origin unknown');
234                                                      }
235                                                   
236           39                                 96      MKDEBUG && _d('Done parsing packet; client state:', $session->{state});
237           39                                295      return $event;
238                                                   }
239                                                   
240                                                   # Handles a packet from the server given the state of the session.
241                                                   # The server can send back a lot of different stuff, but luckily
242                                                   # we're only interested in
243                                                   #    * Connection handshake packets for the thread_id
244                                                   #    * OK and Error packets for errors, warnings, etc.
245                                                   # Anything else is ignored.  Returns an event if one was ready to be
246                                                   # created, otherwise returns nothing.
247                                                   sub _packet_from_server {
248           20                   20            91      my ( $self, $packet, $session, $misc ) = @_;
249   ***     20     50                          82      die "I need a packet"  unless $packet;
250   ***     20     50                          67      die "I need a session" unless $session;
251                                                   
252           20                                 50      MKDEBUG && _d('Packet is from server; client state:', $session->{state});
253           20                                 48      push @{$self->{raw_packets}}, $packet->{raw_packet};
              20                                120   
254                                                   
255           20                                 79      my $data = $packet->{data};
256                                                   
257                                                      # The first byte in the packet indicates whether it's an OK,
258                                                      # ERROR, EOF packet.  If it's not one of those, we test
259                                                      # whether it's an initialization packet (the first thing the
260                                                      # server ever sends the client).  If it's not that, it could
261                                                      # be a result set header, field, row data, etc.
262                                                   
263           20                                 88      my ( $first_byte ) = substr($data, 0, 2, '');
264           20                                 45      MKDEBUG && _d("First byte of packet:", $first_byte);
265                                                   
266   ***     20    100     66                  264      if ( $first_byte eq '00' ) { 
      ***           100     66                        
      ***           100     66                        
      ***           100     66                        
267   ***      6    100     50                   45         if ( ($session->{state} || '') eq 'client_auth' ) {
      ***            50                               
268                                                            # We logged in OK!  Trigger an admin Connect command.
269            3                                 10            $session->{state} = 'ready';
270                                                   
271            3                                 12            $session->{compress} = $session->{will_compress};
272            3                                 10            delete $session->{will_compress};
273            3                                  8            MKDEBUG && $session->{compress} && _d('Packets will be compressed');
274                                                   
275            3                                  7            MKDEBUG && _d('Admin command: Connect');
276            3                                 30            return $self->_make_event(
277                                                               {  cmd => 'Admin',
278                                                                  arg => 'administrator command: Connect',
279                                                                  ts  => $packet->{ts}, # Events are timestamped when they end
280                                                               },
281                                                               $packet, $session
282                                                            );
283                                                         }
284                                                         elsif ( $session->{cmd} ) {
285                                                            # This OK should be ack'ing a query or something sent earlier
286                                                            # by the client.
287            3                                 12            my $ok  = parse_ok_packet($data);
288   ***      3     50                          12            if ( !$ok ) {
289   ***      0                                  0               $self->fail_session($session, 'failed to parse OK packet');
290   ***      0                                  0               return;
291                                                            }
292            3                                 13            my $com = $session->{cmd}->{cmd};
293            3                                  7            my $arg;
294                                                   
295   ***      3     50                          12            if ( $com eq COM_QUERY ) {
296            3                                  9               $com = 'Query';
297            3                                 12               $arg = $session->{cmd}->{arg};
298                                                            }
299                                                            else {
300   ***      0                                  0               $arg = 'administrator command: '
301                                                                    . ucfirst(lc(substr($com_for{$com}, 4)));
302   ***      0                                  0               $com = 'Admin';
303                                                            }
304                                                   
305            3                                 10            $session->{state} = 'ready';
306            3                                 32            return $self->_make_event(
307                                                               {  cmd           => $com,
308                                                                  arg           => $arg,
309                                                                  ts            => $packet->{ts},
310                                                                  Insert_id     => $ok->{insert_id},
311                                                                  Warning_count => $ok->{warnings},
312                                                                  Rows_affected => $ok->{affected_rows},
313                                                               },
314                                                               $packet, $session
315                                                            );
316                                                         } 
317                                                      }
318                                                      elsif ( $first_byte eq 'ff' ) {
319            2                                 10         my $error = parse_error_packet($data);
320   ***      2     50                          17         if ( !$error ) {
321   ***      0                                  0            $self->fail_session($session, 'failed to parse error packet');
322   ***      0                                  0            return;
323                                                         }
324            2                                  5         my $event;
325                                                   
326            2    100                          14         if ( $session->{state} eq 'client_auth' ) {
      ***            50                               
327            1                                  3            MKDEBUG && _d('Connection failed');
328            1                                  8            $event = {
329                                                               cmd       => 'Admin',
330                                                               arg       => 'administrator command: Connect',
331                                                               ts        => $packet->{ts},
332                                                               Error_no  => $error->{errno},
333                                                            };
334            1                                  4            $session->{state} = 'closing';
335                                                         }
336                                                         elsif ( $session->{cmd} ) {
337                                                            # This error should be in response to a query or something
338                                                            # sent earlier by the client.
339            1                                  5            my $com = $session->{cmd}->{cmd};
340            1                                  2            my $arg;
341                                                   
342   ***      1     50                           5            if ( $com eq COM_QUERY ) {
343            1                                  3               $com = 'Query';
344            1                                  5               $arg = $session->{cmd}->{arg};
345                                                            }
346                                                            else {
347   ***      0                                  0               $arg = 'administrator command: '
348                                                                    . ucfirst(lc(substr($com_for{$com}, 4)));
349   ***      0                                  0               $com = 'Admin';
350                                                            }
351            1                                  7            $event = {
352                                                               cmd       => $com,
353                                                               arg       => $arg,
354                                                               ts        => $packet->{ts},
355                                                               Error_no  => $error->{errno},
356                                                            };
357            1                                  4            $session->{state} = 'ready';
358                                                         }
359                                                   
360            2                                 10         return $self->_make_event($event, $packet, $session);
361                                                      }
362                                                      elsif ( $first_byte eq 'fe' && $packet->{mysql_data_len} < 9 ) {
363   ***      1     50     33                   18         if ( $packet->{mysql_data_len} == 1
      ***                   33                        
364                                                              && $session->{state} eq 'client_auth'
365                                                              && $packet->{number} == 2 )
366                                                         {
367            1                                  3            MKDEBUG && _d('Server has old password table;',
368                                                               'client will resend password using old algorithm');
369            1                                  4            $session->{state} = 'client_auth_resend';
370                                                         }
371                                                         else {
372   ***      0                                  0            MKDEBUG && _d('Got an EOF packet');
373   ***      0                                  0            die "You should not have gotten here";
374                                                            # ^^^ We shouldn't reach this because EOF should come after a
375                                                            # header, field, or row data packet; and we should be firing the
376                                                            # event and returning when we see that.  See SVN history for some
377                                                            # good stuff we could do if we wanted to handle EOF packets.
378                                                         }
379                                                      }
380                                                      elsif ( !$session->{state}
381                                                              && $first_byte eq '0a'
382                                                              && length $data >= 33
383                                                              && $data =~ m/00{13}/ )
384                                                      {
385                                                         # It's the handshake packet from the server to the client.
386                                                         # 0a is protocol v10 which is essentially the only version used
387                                                         # today.  33 is the minimum possible length for a valid server
388                                                         # handshake packet.  It's probably a lot longer.  Other packets
389                                                         # may start with 0a, but none that can would be >= 33.  The 13-byte
390                                                         # 00 scramble buffer is another indicator.
391            4                                 23         my $handshake = parse_server_handshake_packet($data);
392   ***      4     50                          18         if ( !$handshake ) {
393   ***      0                                  0            $self->fail_session($session, 'failed to parse server handshake');
394   ***      0                                  0            return;
395                                                         }
396            4                                 18         $session->{state}     = 'server_handshake';
397            4                                 26         $session->{thread_id} = $handshake->{thread_id};
398                                                      }
399                                                      else {
400                                                         # Since we do NOT always have all the data the server sent to the
401                                                         # client, we can't always do any processing of results.  So when
402                                                         # we get one of these, we just fire the event even if the query
403                                                         # is not done.  This means we will NOT process EOF packets
404                                                         # themselves (see above).
405   ***      7     50                          29         if ( $session->{cmd} ) {
406            7                                 20            MKDEBUG && _d('Got a row/field/result packet');
407            7                                 28            my $com = $session->{cmd}->{cmd};
408            7                                 16            MKDEBUG && _d('Responding to client', $com_for{$com});
409            7                                 36            my $event = { ts  => $packet->{ts} };
410   ***      7     50                          30            if ( $com eq COM_QUERY ) {
411            7                                 23               $event->{cmd} = 'Query';
412            7                                 37               $event->{arg} = $session->{cmd}->{arg};
413                                                            }
414                                                            else {
415   ***      0                                  0               $event->{arg} = 'administrator command: '
416                                                                    . ucfirst(lc(substr($com_for{$com}, 4)));
417   ***      0                                  0               $event->{cmd} = 'Admin';
418                                                            }
419                                                   
420                                                            # We DID get all the data in the packet.
421   ***      7     50                          29            if ( $packet->{complete} ) {
422                                                               # Look to see if the end of the data appears to be an EOF
423                                                               # packet.
424            7                                 93               my ( $warning_count, $status_flags )
425                                                                  = $data =~ m/fe(.{4})(.{4})\Z/;
426            7    100                          31               if ( $warning_count ) { 
427            6                                 21                  $event->{Warnings} = to_num($warning_count);
428            6                                 22                  my $flags = to_num($status_flags); # TODO set all flags?
429   ***      6     50                          33                  $event->{No_good_index_used}
430                                                                     = $flags & SERVER_QUERY_NO_GOOD_INDEX_USED ? 1 : 0;
431            6    100                          38                  $event->{No_index_used}
432                                                                     = $flags & SERVER_QUERY_NO_INDEX_USED ? 1 : 0;
433                                                               }
434                                                            }
435                                                   
436            7                                 23            $session->{state} = 'ready';
437            7                                 32            return $self->_make_event($event, $packet, $session);
438                                                         }
439                                                         else {
440   ***      0                                  0            MKDEBUG && _d('Unknown in-stream server response');
441                                                         }
442                                                      }
443                                                   
444            5                                 20      return;
445                                                   }
446                                                   
447                                                   # Handles a packet from the client given the state of the session.
448                                                   # The client doesn't send a wide and exotic array of packets like
449                                                   # the server.  Even so, we're only interested in:
450                                                   #    * Users and dbs from connection handshake packets
451                                                   #    * SQL statements from COM_QUERY commands
452                                                   # Anything else is ignored.  Returns an event if one was ready to be
453                                                   # created, otherwise returns nothing.
454                                                   sub _packet_from_client {
455           19                   19            85      my ( $self, $packet, $session, $misc ) = @_;
456   ***     19     50                         103      die "I need a packet"  unless $packet;
457   ***     19     50                          65      die "I need a session" unless $session;
458                                                   
459           19                                 43      MKDEBUG && _d('Packet is from client; state:', $session->{state});
460           19                                 46      push @{$self->{raw_packets}}, $packet->{raw_packet};
              19                                115   
461                                                   
462           19                                 70      my $data  = $packet->{data};
463           19                                 58      my $ts    = $packet->{ts};
464                                                   
465           19    100    100                  275      if ( ($session->{state} || '') eq 'server_handshake' ) {
                    100    100                        
      ***            50    100                        
466            4                                 10         MKDEBUG && _d('Expecting client authentication packet');
467                                                         # The connection is a 3-way handshake:
468                                                         #    server > client  (protocol version, thread id, etc.)
469                                                         #    client > server  (user, pass, default db, etc.)
470                                                         #    server > client  OK if login succeeds
471                                                         # pos_in_log refers to 2nd handshake from the client.
472                                                         # A connection is logged even if the client fails to
473                                                         # login (bad password, etc.).
474            4                                 17         my $handshake = parse_client_handshake_packet($data);
475   ***      4     50                          18         if ( !$handshake ) {
476   ***      0                                  0            $self->fail_session($session, 'failed to parse client handshake');
477   ***      0                                  0            return;
478                                                         }
479            4                                 15         $session->{state}         = 'client_auth';
480            4                                 17         $session->{pos_in_log}    = $packet->{pos_in_log};
481            4                                 22         $session->{user}          = $handshake->{user};
482            4                                 16         $session->{db}            = $handshake->{db};
483                                                   
484                                                         # $session->{will_compress} will become $session->{compress} when
485                                                         # the server's final handshake packet is received.  This prevents
486                                                         # parse_packet() from trying to decompress that final packet.
487                                                         # Compressed packets can only begin after the full handshake is done.
488            4                                 34         $session->{will_compress} = $handshake->{flags}->{CLIENT_COMPRESS};
489                                                      }
490                                                      elsif ( ($session->{state} || '') eq 'client_auth_resend' ) {
491                                                         # Don't know how to parse this packet.
492            1                                  2         MKDEBUG && _d('Client resending password using old algorithm');
493            1                                  4         $session->{state} = 'client_auth';
494                                                      }
495                                                      elsif ( ($session->{state} || '') eq 'awaiting_reply' ) {
496   ***      0      0                           0         my $arg = $session->{cmd}->{arg} ? substr($session->{cmd}->{arg}, 0, 50)
497                                                                 : 'unknown';
498   ***      0                                  0         MKDEBUG && _d('More data for previous command:', $arg, '...'); 
499   ***      0                                  0         return;
500                                                      }
501                                                      else {
502                                                         # Otherwise, it should be a query.  We ignore the commands
503                                                         # that take arguments (COM_CHANGE_USER, COM_PROCESS_KILL).
504                                                   
505                                                         # Detect compression in-stream only if $session->{compress} is
506                                                         # not defined.  This means we didn't see the client handshake.
507                                                         # If we had seen it, $session->{compress} would be defined as 0 or 1.
508           14    100                          74         if ( !defined $session->{compress} ) {
509   ***      7     50                          38            return unless $self->detect_compression($packet, $session);
510            7                                 24            $data = $packet->{data};
511                                                         }
512                                                   
513           14                                 63         my $com = parse_com_packet($data, $packet->{mysql_data_len});
514   ***     14     50                          57         if ( !$com ) {
515   ***      0                                  0            $self->fail_session($session, 'failed to parse COM packet');
516   ***      0                                  0            return;
517                                                         }
518           14                                 53         $session->{state}      = 'awaiting_reply';
519           14                                 57         $session->{pos_in_log} = $packet->{pos_in_log};
520           14                                 46         $session->{ts}         = $ts;
521           14                                 84         $session->{cmd}        = {
522                                                            cmd => $com->{code},
523                                                            arg => $com->{data},
524                                                         };
525                                                   
526           14    100                          96         if ( $com->{code} eq COM_QUIT ) { # Fire right away; will cleanup later.
527            2                                  5            MKDEBUG && _d('Got a COM_QUIT');
528            2                                  7            $session->{state} = 'closing';
529            2                                 13            return $self->_make_event(
530                                                               {  cmd       => 'Admin',
531                                                                  arg       => 'administrator command: Quit',
532                                                                  ts        => $ts,
533                                                               },
534                                                               $packet, $session
535                                                            );
536                                                         }
537                                                      }
538                                                   
539           17                                 58      return;
540                                                   }
541                                                   
542                                                   # Make and return an event from the given packet and session.
543                                                   sub _make_event {
544           17                   17            80      my ( $self, $event, $packet, $session ) = @_;
545           17                                 40      MKDEBUG && _d('Making event');
546                                                   
547                                                      # Clear packets that preceded this event.
548           17                                 67      $self->{raw_packets} = [];
549                                                   
550           17                                157      my ($host, $port) = $session->{client} =~ m/((?:\d+\.){3}\d+)\:(\w+)/;
551   ***     17     50    100                  129      return $event = {
                    100    100                        
                           100                        
552                                                         cmd        => $event->{cmd},
553                                                         arg        => $event->{arg},
554                                                         bytes      => length( $event->{arg} ),
555                                                         ts         => tcp_timestamp( $event->{ts} ),
556                                                         host       => $host,
557                                                         ip         => $host,
558                                                         port       => $port,
559                                                         db         => $session->{db},
560                                                         user       => $session->{user},
561                                                         Thread_id  => $session->{thread_id},
562                                                         pos_in_log => $session->{pos_in_log},
563                                                         Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
564                                                         Error_no   => ($event->{Error_no} || 0),
565                                                         Rows_affected      => ($event->{Rows_affected} || 0),
566                                                         Warning_count      => ($event->{Warning_count} || 0),
567                                                         No_good_index_used => ($event->{No_good_index_used} ? 'Yes' : 'No'),
568                                                         No_index_used      => ($event->{No_index_used}      ? 'Yes' : 'No'),
569                                                      };
570                                                   }
571                                                   
572                                                   # Extracts a slow-log-formatted timestamp from the tcpdump timestamp format.
573                                                   sub tcp_timestamp {
574           17                   17            74      my ( $ts ) = @_;
575           17                                203      $ts =~ s/^\d\d(\d\d)-(\d\d)-(\d\d)/$1$2$3/;
576           17                                177      return $ts;
577                                                   }
578                                                   
579                                                   # Returns the difference between two tcpdump timestamps.
580                                                   sub timestamp_diff {
581           17                   17            74      my ( $start, $end ) = @_;
582           17                                 68      my $sd = substr($start, 0, 11, '');
583           17                                 57      my $ed = substr($end,   0, 11, '');
584           17                                108      my ( $sh, $sm, $ss ) = split(/:/, $start);
585           17                                 77      my ( $eh, $em, $es ) = split(/:/, $end);
586           17                                110      my $esecs = ($eh * 3600 + $em * 60 + $es);
587           17                                 77      my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
588   ***     17     50                          64      if ( $sd eq $ed ) {
589           17                                783         return sprintf '%.6f', $esecs - $ssecs;
590                                                      }
591                                                      else { # Assume only one day boundary has been crossed, no DST, etc
592   ***      0                                  0         return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
593                                                      }
594                                                   }
595                                                   
596                                                   # Converts hexadecimal to string.
597                                                   sub to_string {
598           48                   48           187      my ( $data ) = @_;
599                                                      # $data =~ s/(..)/chr(hex $1)/eg;
600           48                                232      $data = pack('H*', $data);
601           48                                186      return $data;
602                                                   }
603                                                   
604                                                   # All numbers are stored with the least significant byte first in the MySQL
605                                                   # protocol.
606                                                   sub to_num {
607          136                  136           509      my ( $str ) = @_;
608          136                                792      my @bytes = $str =~ m/(..)/g;
609          136                                393      my $result = 0;
610          136                                645      foreach my $i ( 0 .. $#bytes ) {
611          298                               1461         $result += hex($bytes[$i]) * (16 ** ($i * 2));
612                                                      }
613          136                                538      return $result;
614                                                   }
615                                                   
616                                                   # Accepts a reference to a string, which it will modify.  Extracts a
617                                                   # length-coded binary off the front of the string and returns that value as an
618                                                   # integer.
619                                                   sub get_lcb {
620            8                    8            27      my ( $string ) = @_;
621            8                                 31      my $first_byte = hex(substr($$string, 0, 2, ''));
622   ***      8     50                          26      if ( $first_byte < 251 ) {
      ***             0                               
      ***             0                               
      ***             0                               
623            8                                 25         return $first_byte;
624                                                      }
625                                                      elsif ( $first_byte == 252 ) {
626   ***      0                                  0         return to_num(substr($$string, 0, 4, ''));
627                                                      }
628                                                      elsif ( $first_byte == 253 ) {
629   ***      0                                  0         return to_num(substr($$string, 0, 6, ''));
630                                                      }
631                                                      elsif ( $first_byte == 254 ) {
632   ***      0                                  0         return to_num(substr($$string, 0, 16, ''));
633                                                      }
634                                                   }
635                                                   
636                                                   # Error packet structure:
637                                                   # Offset  Bytes               Field
638                                                   # ======  =================   ====================================
639                                                   #         00 00 00 01         MySQL proto header (already removed)
640                                                   #         ff                  Error  (already removed)
641                                                   # 0       00 00               Error number
642                                                   # 4       00                  SQL state marker, always '#'
643                                                   # 6       00 00 00 00 00      SQL state
644                                                   # 16      00 ...              Error message
645                                                   # The sqlstate marker and actual sqlstate are combined into one value. 
646                                                   sub parse_error_packet {
647            3                    3            19      my ( $data ) = @_;
648   ***      3     50                          15      die "I need data" unless $data;
649            3                                  8      MKDEBUG && _d('ERROR data:', $data);
650   ***      3     50                          15      if ( length $data < 16 ) {
651   ***      0                                  0         MKDEBUG && _d('Error packet is too short:', $data);
652   ***      0                                  0         return;
653                                                      }
654            3                                 15      my $errno    = to_num(substr($data, 0, 4));
655            3                                 14      my $marker   = to_string(substr($data, 4, 2));
656   ***      3     50                          14      return unless $marker eq '#';
657            3                                 14      my $sqlstate = to_string(substr($data, 6, 10));
658            3                                 13      my $message  = to_string(substr($data, 16));
659            3                                 22      my $pkt = {
660                                                         errno    => $errno,
661                                                         sqlstate => $marker . $sqlstate,
662                                                         message  => $message,
663                                                      };
664            3                                  7      MKDEBUG && _d('Error packet:', Dumper($pkt));
665            3                                 15      return $pkt;
666                                                   }
667                                                   
668                                                   # OK packet structure:
669                                                   # Offset  Bytes               Field
670                                                   # ======  =================   ====================================
671                                                   #         00 00 00 01         MySQL proto header (already removed)
672                                                   #         00                  OK  (already removed)
673                                                   #         1-9                 Affected rows (LCB)
674                                                   #         1-9                 Insert ID (LCB)
675                                                   #         00 00               Server status
676                                                   #         00 00               Warning count
677                                                   #         00 ...              Message (optional)
678                                                   sub parse_ok_packet {
679            4                    4            17      my ( $data ) = @_;
680   ***      4     50                          16      die "I need data" unless $data;
681            4                                 11      MKDEBUG && _d('OK data:', $data);
682   ***      4     50                          18      if ( length $data < 12 ) {
683   ***      0                                  0         MKDEBUG && _d('OK packet is too short:', $data);
684   ***      0                                  0         return;
685                                                      }
686            4                                 17      my $affected_rows = get_lcb(\$data);
687            4                                 17      my $insert_id     = get_lcb(\$data);
688            4                                 17      my $status        = to_num(substr($data, 0, 4, ''));
689            4                                 19      my $warnings      = to_num(substr($data, 0, 4, ''));
690            4                                 14      my $message       = to_string($data);
691                                                      # Note: $message is discarded.  It might be something like
692                                                      # Records: 2  Duplicates: 0  Warnings: 0
693            4                                 32      my $pkt = {
694                                                         affected_rows => $affected_rows,
695                                                         insert_id     => $insert_id,
696                                                         status        => $status,
697                                                         warnings      => $warnings,
698                                                         message       => $message,
699                                                      };
700            4                                 16      MKDEBUG && _d('OK packet:', Dumper($pkt));
701            4                                 20      return $pkt;
702                                                   }
703                                                   
704                                                   # Currently we only capture and return the thread id.
705                                                   sub parse_server_handshake_packet {
706            5                    5            27      my ( $data ) = @_;
707   ***      5     50                          22      die "I need data" unless $data;
708            5                                 13      MKDEBUG && _d('Server handshake data:', $data);
709            5                                 46      my $handshake_pattern = qr{
710                                                                           # Bytes                Name
711                                                         ^                 # -----                ----
712                                                         (.+?)00           # n Null-Term String   server_version
713                                                         (.{8})            # 4                    thread_id
714                                                         .{16}             # 8                    scramble_buff
715                                                         .{2}              # 1                    filler: always 0x00
716                                                         (.{4})            # 2                    server_capabilities
717                                                         .{2}              # 1                    server_language
718                                                         .{4}              # 2                    server_status
719                                                         .{26}             # 13                   filler: always 0x00
720                                                                           # 13                   rest of scramble_buff
721                                                      }x;
722            5                                 65      my ( $server_version, $thread_id, $flags ) = $data =~ m/$handshake_pattern/;
723            5                                 25      my $pkt = {
724                                                         server_version => to_string($server_version),
725                                                         thread_id      => to_num($thread_id),
726                                                         flags          => parse_flags($flags),
727                                                      };
728            5                                 17      MKDEBUG && _d('Server handshake packet:', Dumper($pkt));
729            5                                 57      return $pkt;
730                                                   }
731                                                   
732                                                   # Currently we only capture and return the user and default database.
733                                                   sub parse_client_handshake_packet {
734            5                    5            28      my ( $data ) = @_;
735   ***      5     50                          22      die "I need data" unless $data;
736            5                                 12      MKDEBUG && _d('Client handshake data:', $data);
737            5                                 60      my ( $flags, $user, $buff_len ) = $data =~ m{
738                                                         ^
739                                                         (.{8})         # Client flags
740                                                         .{10}          # Max packet size, charset
741                                                         (?:00){23}     # Filler
742                                                         ((?:..)+?)00   # Null-terminated user name
743                                                         (..)           # Length-coding byte for scramble buff
744                                                      }x;
745                                                   
746                                                      # This packet is easy to detect because it's the only case where
747                                                      # the server sends the client a packet first (its handshake) and
748                                                      # then the client only and ever sends back its handshake.
749   ***      5     50                          30      if ( !$buff_len ) {
750   ***      0                                  0         MKDEBUG && _d('Did not match client handshake packet');
751   ***      0                                  0         return;
752                                                      }
753                                                   
754                                                      # This length-coded binary doesn't seem to be a normal one, it
755                                                      # seems more like a length-coded string actually.
756            5                                 17      my $code_len = hex($buff_len);
757            5                                163      my ( $db ) = $data =~ m!
758                                                         ^.{64}${user}00..   # Everything matched before
759                                                         (?:..){$code_len}   # The scramble buffer
760                                                         (.*)00\Z            # The database name
761                                                      !x;
762            5    100                          24      my $pkt = {
763                                                         user  => to_string($user),
764                                                         db    => $db ? to_string($db) : '',
765                                                         flags => parse_flags($flags),
766                                                      };
767            5                                 15      MKDEBUG && _d('Client handshake packet:', Dumper($pkt));
768            5                                 33      return $pkt;
769                                                   }
770                                                   
771                                                   # COM data is not 00-terminated, but the the MySQL client appends \0,
772                                                   # so we have to use the packet length to know where the data ends.
773                                                   sub parse_com_packet {
774           22                   22            91      my ( $data, $len ) = @_;
775   ***     22     50                          82      die "I need data"  unless $data;
776   ***     22     50                          76      die "I need a len" unless $len;
777           22                                 48      MKDEBUG && _d('COM data:', $data, 'len:', $len);
778           22                                 71      my $code = substr($data, 0, 2);
779           22                                 78      my $com  = $com_for{$code};
780   ***     22     50                          81      if ( !$com ) {
781   ***      0                                  0         MKDEBUG && _d('Did not match COM packet');
782   ***      0                                  0         return;
783                                                      }
784           22                                117      $data    = to_string(substr($data, 2, ($len - 1) * 2));
785           22                                128      my $pkt = {
786                                                         code => $code,
787                                                         com  => $com,
788                                                         data => $data,
789                                                      };
790           22                                 48      MKDEBUG && _d('COM packet:', Dumper($pkt));
791           22                                 78      return $pkt;
792                                                   }
793                                                   
794                                                   sub parse_flags {
795           10                   10            40      my ( $flags ) = @_;
796   ***     10     50                          41      die "I need flags" unless $flags;
797           10                                 23      MKDEBUG && _d('Flag data:', $flags);
798           10                                137      my %flags     = %flag_for;
799           10                                 47      my $flags_dec = to_num($flags);
800           10                                 53      foreach my $flag ( keys %flag_for ) {
801          180                                482         my $flagno    = $flag_for{$flag};
802          180    100                         760         $flags{$flag} = ($flags_dec & $flagno ? 1 : 0);
803                                                      }
804           10                                 75      return \%flags;
805                                                   }
806                                                   
807                                                   # Takes a scalarref to a hex string of compressed data.
808                                                   # Returns a scalarref to a hex string of the uncompressed data.
809                                                   # The given hex string of compressed data is not modified.
810                                                   sub uncompress_data {
811            1                    1             4      my ( $data ) = @_;
812   ***      1     50                           5      die "I need data" unless $data;
813   ***      1     50                           5      die "I need a scalar reference" unless ref $data eq 'SCALAR';
814            1                                  3      MKDEBUG && _d('Uncompressing packet');
815            1                                  2      our $InflateError;
816                                                   
817                                                      # Pack hex string into compressed binary data.
818            1                                100      my $comp_bin_data = pack('H*', $$data);
819                                                   
820                                                      # Uncompress the compressed binary data.
821            1                                  4      my $uncomp_bin_data = '';
822   ***      1     50                           5      my $status          = inflate(
823                                                         \$comp_bin_data => \$uncomp_bin_data,
824                                                      ) or die "IO::Uncompress::Inflate failed: $InflateError";
825                                                   
826                                                      # Unpack the uncompressed binary data back into a hex string.
827                                                      # This is the original MySQL packet(s).
828            1                                 80      my $uncomp_data = unpack('H*', $uncomp_bin_data);
829                                                   
830            1                                  5      return \$uncomp_data;
831                                                   }
832                                                   
833                                                   # Returns 1 on success or 0 on failure.  Failure is probably
834                                                   # detecting compression but not being able to uncompress
835                                                   # (uncompress_packet() returns 0).
836                                                   sub detect_compression {
837            7                    7            30      my ( $self, $packet, $session ) = @_;
838            7                                 20      MKDEBUG && _d('Checking for client compression');
839                                                      # This is a necessary hack for detecting compression in-stream without
840                                                      # having seen the client handshake and CLIENT_COMPRESS flag.  If the
841                                                      # client is compressing packets, there will be an extra 7 bytes before
842                                                      # the regular MySQL header.  For short COM_QUERY commands, these 7 bytes
843                                                      # are usually zero where we'd expect to see 03 for COM_QUERY.  So if we
844                                                      # parse this packet and it looks like a COM_SLEEP (00) which is not a
845                                                      # command that the client can send, then chances are the client is using
846                                                      # compression.
847            7                                 40      my $com = parse_com_packet($packet->{data}, $packet->{data_len});
848            7    100                          36      if ( $com->{code} eq COM_SLEEP ) {
849            1                                  3         MKDEBUG && _d('Client is using compression');
850            1                                  5         $session->{compress} = 1;
851                                                   
852                                                         # Since parse_packet() didn't know the packet was compressed, it
853                                                         # called remove_mysql_header() which removed the first 4 of 7 bytes
854                                                         # of the compression header.  We must restore these 4 bytes, then
855                                                         # uncompress and remove the MySQL header.  We only do this once.
856            1                                  6         $packet->{data} = $packet->{mysql_hdr} . $packet->{data};
857   ***      1     50                           4         return 0 unless uncompress_packet($packet);
858            1                                  5         remove_mysql_header($packet);
859                                                      }
860                                                      else {
861            6                                 14         MKDEBUG && _d('Client is NOT using compression');
862            6                                 21         $session->{compress} = 0;
863                                                      }
864            7                                 43      return 1;
865                                                   }
866                                                   
867                                                   # Returns 1 if the packet was uncompressed or 0 if we can't uncompress.
868                                                   # Failure is usually due to IO::Uncompress not being available.
869                                                   sub uncompress_packet {
870            6                    6            21      my ( $packet ) = @_;
871   ***      6     50                          27      die "I need a packet" unless $packet;
872                                                   
873                                                      # From the doc: "A compressed packet header is:
874                                                      #    packet length (3 bytes),
875                                                      #    packet number (1 byte),
876                                                      #    and Uncompressed Packet Length (3 bytes).
877                                                      # The Uncompressed Packet Length is the number of bytes
878                                                      # in the original, uncompressed packet. If this is zero
879                                                      # then the data is not compressed."
880                                                   
881            6                                 21      my $data            = \$packet->{data};
882            6                                 25      my $comp_hdr        = substr($$data, 0, 14, '');
883            6                                 26      my $comp_data_len   = to_num(substr($comp_hdr, 0, 6));
884            6                                 27      my $pkt_num         = to_num(substr($comp_hdr, 6, 2));
885            6                                 25      my $uncomp_data_len = to_num(substr($comp_hdr, 8, 6));
886            6                                 14      MKDEBUG && _d('Compression header data:', $comp_hdr,
887                                                         'compressed data len (bytes)', $comp_data_len,
888                                                         'number', $pkt_num,
889                                                         'uncompressed data len (bytes)', $uncomp_data_len);
890                                                   
891            6    100                          19      if ( $uncomp_data_len ) {
892            1                                  3         eval {
893            1                                  5            $data = uncompress_data($data);
894            1                                 29            $packet->{data} = $$data;
895                                                         };
896   ***      1     50                           6         if ( $EVAL_ERROR ) {
897   ***      0                                  0            die "Cannot uncompress packet.  Check that IO::Uncompress::Inflate "
898                                                               . "is installed.\nnError: $EVAL_ERROR";
899                                                         }
900                                                      }
901                                                      else {
902            5                                 13         MKDEBUG && _d('Packet is not really compressed');
903            5                                 22         $packet->{data} = $$data;
904                                                      }
905                                                   
906            6                                 34      return 1;
907                                                   }
908                                                   
909                                                   # Removes the first 4 bytes of the packet data which should be
910                                                   # a MySQL header: 3 bytes packet length, 1 byte packet number.
911                                                   sub remove_mysql_header {
912           40                   40           138      my ( $packet ) = @_;
913   ***     40     50                         149      die "I need a packet" unless $packet;
914                                                   
915                                                      # NOTE: the data is modified by the inmost substr call here!  If we
916                                                      # had all the data in the TCP packets, we could change this to a while
917                                                      # loop; while get-a-packet-from-$data, do stuff, etc.  But we don't,
918                                                      # and we don't want to either.
919           40                                209      my $mysql_hdr      = substr($packet->{data}, 0, 8, '');
920           40                                168      my $mysql_data_len = to_num(substr($mysql_hdr, 0, 6));
921           40                                163      my $pkt_num        = to_num(substr($mysql_hdr, 6, 2));
922           40                                 85      MKDEBUG && _d('MySQL packet: header data', $mysql_hdr,
923                                                         'data len (bytes)', $mysql_data_len, 'number', $pkt_num);
924                                                   
925           40                                157      $packet->{mysql_hdr}      = $mysql_hdr;
926           40                                173      $packet->{mysql_data_len} = $mysql_data_len;
927           40                                128      $packet->{number}         = $pkt_num;
928                                                   
929           40                                109      return;
930                                                   }
931                                                   
932                                                   sub _get_errors_fh {
933   ***      0                    0                    my ( $self ) = @_;
934   ***      0                                         my $errors_fh = $self->{errors_fh};
935   ***      0      0                                  return $errors_fh if $errors_fh;
936                                                   
937                                                      # Errors file isn't open yet; try to open it.
938   ***      0                                         my $o = $self->{o};
939   ***      0      0      0                           if ( $o && $o->has('tcpdump-errors') && $o->got('tcpdump-errors') ) {
      ***                    0                        
940   ***      0                                            my $errors_file = $o->get('tcpdump-errors');
941   ***      0                                            MKDEBUG && _d('tcpdump-errors file:', $errors_file);
942   ***      0      0                                     open $errors_fh, '>>', $errors_file
943                                                            or die "Cannot open tcpdump-errors file $errors_file: $OS_ERROR";
944                                                      }
945                                                   
946   ***      0                                         $self->{errors_fh} = $errors_fh;
947   ***      0                                         return $errors_fh;
948                                                   }
949                                                   
950                                                   sub fail_session {
951   ***      0                    0                    my ( $self, $session, $reason ) = @_;
952   ***      0                                         my $errors_fh = $self->_get_errors_fh();
953   ***      0                                         my $session_dump = '# ' . Dumper($session);
954   ***      0                                         chomp $session_dump;
955   ***      0                                         $session_dump =~ s/\n/\n# /g;
956   ***      0                                         print $errors_fh "$session_dump\n";
957                                                      {
958   ***      0                                            local $LIST_SEPARATOR = "\n";
      ***      0                                      
959   ***      0                                            print $errors_fh "@{$self->{raw_packets}}";
      ***      0                                      
960   ***      0                                            print $errors_fh "\n";
961                                                      }
962   ***      0                                         MKDEBUG && _d('Failed session', $session->{client}, 'because', $reason);
963   ***      0                                         delete $self->{sessions}->{$session->{client}};
964   ***      0                                         return;
965                                                   }
966                                                   
967                                                   sub _d {
968   ***      0                    0                    my ($package, undef, $line) = caller 0;
969   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
970   ***      0                                              map { defined $_ ? $_ : 'undef' }
971                                                           @_;
972   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
973                                                   }
974                                                   
975                                                   1;
976                                                   
977                                                   # ###########################################################################
978                                                   # End MySQLProtocolParser package
979                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
178   ***     50      7      0   $to =~ /:(?:3306|mysql)$/ ? :
      ***     50      0      7   $from =~ /:(?:3306|mysql)$/ ? :
181          100     36     42   $from eq $$self{'server'} ? :
186          100     14     64   if (not exists $$self{'sessions'}{$client})
201          100     39     39   if ($$packet{'data_len'} == 0)
204          100      3     36   if (($$session{'state'} || '') eq 'closing')
213          100      5     34   if ($$session{'compress'})
214   ***     50      0      5   unless uncompress_packet($packet)
226          100     20     19   if ($from eq $$self{'server'}) { }
      ***     50     19      0   elsif ($from eq $client) { }
249   ***     50      0     20   unless $packet
250   ***     50      0     20   unless $session
266          100      6     14   if ($first_byte eq '00') { }
             100      2     12   elsif ($first_byte eq 'ff') { }
             100      1     11   elsif ($first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9) { }
             100      4      7   elsif (not $$session{'state'} and $first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/) { }
267          100      3      3   if (($$session{'state'} || '') eq 'client_auth') { }
      ***     50      3      0   elsif ($$session{'cmd'}) { }
288   ***     50      0      3   if (not $ok)
295   ***     50      3      0   if ($com eq '03') { }
320   ***     50      0      2   if (not $error)
326          100      1      1   if ($$session{'state'} eq 'client_auth') { }
      ***     50      1      0   elsif ($$session{'cmd'}) { }
342   ***     50      1      0   if ($com eq '03') { }
363   ***     50      1      0   if ($$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2) { }
392   ***     50      0      4   if (not $handshake)
405   ***     50      7      0   if ($$session{'cmd'}) { }
410   ***     50      7      0   if ($com eq '03') { }
421   ***     50      7      0   if ($$packet{'complete'})
426          100      6      1   if ($warning_count)
429   ***     50      0      6   $flags & 16 ? :
431          100      2      4   $flags & 32 ? :
456   ***     50      0     19   unless $packet
457   ***     50      0     19   unless $session
465          100      4     15   if (($$session{'state'} || '') eq 'server_handshake') { }
             100      1     14   elsif (($$session{'state'} || '') eq 'client_auth_resend') { }
      ***     50      0     14   elsif (($$session{'state'} || '') eq 'awaiting_reply') { }
475   ***     50      0      4   if (not $handshake)
496   ***      0      0      0   $$session{'cmd'}{'arg'} ? :
508          100      7      7   if (not defined $$session{'compress'})
509   ***     50      0      7   unless $self->detect_compression($packet, $session)
514   ***     50      0     14   if (not $com)
526          100      2     12   if ($$com{'code'} eq '01')
551   ***     50      0     17   $$event{'No_good_index_used'} ? :
             100      2     15   $$event{'No_index_used'} ? :
588   ***     50     17      0   if ($sd eq $ed) { }
622   ***     50      8      0   if ($first_byte < 251) { }
      ***      0      0      0   elsif ($first_byte == 252) { }
      ***      0      0      0   elsif ($first_byte == 253) { }
      ***      0      0      0   elsif ($first_byte == 254) { }
648   ***     50      0      3   unless $data
650   ***     50      0      3   if (length $data < 16)
656   ***     50      0      3   unless $marker eq '#'
680   ***     50      0      4   unless $data
682   ***     50      0      4   if (length $data < 12)
707   ***     50      0      5   unless $data
735   ***     50      0      5   unless $data
749   ***     50      0      5   if (not $buff_len)
762          100      3      2   $db ? :
775   ***     50      0     22   unless $data
776   ***     50      0     22   unless $len
780   ***     50      0     22   if (not $com)
796   ***     50      0     10   unless $flags
802          100     79    101   $flags_dec & $flagno ? :
812   ***     50      0      1   unless $data
813   ***     50      0      1   unless ref $data eq 'SCALAR'
822   ***     50      0      1   unless my $status = inflate(\$comp_bin_data, \$uncomp_bin_data)
848          100      1      6   if ($$com{'code'} eq '00') { }
857   ***     50      0      1   unless uncompress_packet($packet)
871   ***     50      0      6   unless $packet
891          100      1      5   if ($uncomp_data_len) { }
896   ***     50      0      1   if ($EVAL_ERROR)
913   ***     50      0     40   unless $packet
935   ***      0      0      0   if $errors_fh
939   ***      0      0      0   if ($o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors'))
942   ***      0      0      0   unless open $errors_fh, '>>', $errors_file
969   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
266   ***     66     11      0      1   $first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9
      ***     66      7      0      4   not $$session{'state'} and $first_byte eq '0a'
      ***     66      7      0      4   not $$session{'state'} and $first_byte eq '0a' and length $data >= 33
      ***     66      7      0      4   not $$session{'state'} and $first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/
363   ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth'
      ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2
939   ***      0      0      0      0   $o and $o->has('tcpdump-errors')
      ***      0      0      0      0   $o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors')

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
178          100     71      7   $$self{'server'} ||= $from =~ /:(?:3306|mysql)$/ ? $from : ($to =~ /:(?:3306|mysql)$/ ? $to : undef)
204          100     23     16   $$session{'state'} || ''
267   ***     50      6      0   $$session{'state'} || ''
465          100     12      7   $$session{'state'} || ''
             100      8      7   $$session{'state'} || ''
             100      7      7   $$session{'state'} || ''
551          100      2     15   $$event{'Error_no'} || 0
             100      3     14   $$event{'Rows_affected'} || 0
             100      1     16   $$event{'Warning_count'} || 0


Covered Subroutines
-------------------

Subroutine                    Count Location                                                  
----------------------------- ----- ----------------------------------------------------------
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:38 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:39 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:40 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:47 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:65 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:98 
_make_event                      17 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:544
_packet_from_client              19 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:455
_packet_from_server              20 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:248
detect_compression                7 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:837
get_lcb                           8 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:620
new                              11 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:157
parse_client_handshake_packet     5 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:734
parse_com_packet                 22 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:774
parse_error_packet                3 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:647
parse_flags                      10 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:795
parse_ok_packet                   4 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:679
parse_packet                     78 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:171
parse_server_handshake_packet     5 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:706
remove_mysql_header              40 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:912
tcp_timestamp                    17 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:574
timestamp_diff                   17 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:581
to_num                          136 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:607
to_string                        48 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:598
uncompress_data                   1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:811
uncompress_packet                 6 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:870

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                                  
----------------------------- ----- ----------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:968
_get_errors_fh                    0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:933
fail_session                      0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:951


