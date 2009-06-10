---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...on/MySQLProtocolParser.pm   87.0   59.3   75.0   92.6    n/a  100.0   78.8
Total                          87.0   59.3   75.0   92.6    n/a  100.0   78.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MySQLProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:39 2009
Finish:       Wed Jun 10 17:20:39 2009

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
18                                                    # MySQLProtocolParser package $Revision: 3885 $
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
               1                                  3   
               1                                  7   
39             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                 10   
40             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
41                                                    
42                                                    eval {
43                                                       require IO::Uncompress::Inflate;
44                                                       IO::Uncompress::Inflate->import('inflate');
45                                                    };
46                                                    
47             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  7   
48                                                    $Data::Dumper::Indent = 1;
49                                                    
50                                                    require Exporter;
51                                                    our @ISA         = qw(Exporter);
52                                                    our %EXPORT_TAGS = ();
53                                                    our @EXPORT      = ();
54                                                    our @EXPORT_OK   = qw(
55                                                       parse_error_packet
56                                                       parse_ok_packet
57                                                       parse_server_handshake_packet
58                                                       parse_client_handshake_packet
59                                                       parse_com_packet
60                                                       parse_flags
61                                                    );
62                                                    
63             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
64                                                    use constant {
65             1                                 28      COM_SLEEP               => '00',
66                                                       COM_QUIT                => '01',
67                                                       COM_INIT_DB             => '02',
68                                                       COM_QUERY               => '03',
69                                                       COM_FIELD_LIST          => '04',
70                                                       COM_CREATE_DB           => '05',
71                                                       COM_DROP_DB             => '06',
72                                                       COM_REFRESH             => '07',
73                                                       COM_SHUTDOWN            => '08',
74                                                       COM_STATISTICS          => '09',
75                                                       COM_PROCESS_INFO        => '0a',
76                                                       COM_CONNECT             => '0b',
77                                                       COM_PROCESS_KILL        => '0c',
78                                                       COM_DEBUG               => '0d',
79                                                       COM_PING                => '0e',
80                                                       COM_TIME                => '0f',
81                                                       COM_DELAYED_INSERT      => '10',
82                                                       COM_CHANGE_USER         => '11',
83                                                       COM_BINLOG_DUMP         => '12',
84                                                       COM_TABLE_DUMP          => '13',
85                                                       COM_CONNECT_OUT         => '14',
86                                                       COM_REGISTER_SLAVE      => '15',
87                                                       COM_STMT_PREPARE        => '16',
88                                                       COM_STMT_EXECUTE        => '17',
89                                                       COM_STMT_SEND_LONG_DATA => '18',
90                                                       COM_STMT_CLOSE          => '19',
91                                                       COM_STMT_RESET          => '1a',
92                                                       COM_SET_OPTION          => '1b',
93                                                       COM_STMT_FETCH          => '1c',
94                                                       SERVER_QUERY_NO_GOOD_INDEX_USED => 16,
95                                                       SERVER_QUERY_NO_INDEX_USED      => 32,
96             1                    1             6   };
               1                                  2   
97                                                    
98                                                    my %com_for = (
99                                                       '00' => 'COM_SLEEP',
100                                                      '01' => 'COM_QUIT',
101                                                      '02' => 'COM_INIT_DB',
102                                                      '03' => 'COM_QUERY',
103                                                      '04' => 'COM_FIELD_LIST',
104                                                      '05' => 'COM_CREATE_DB',
105                                                      '06' => 'COM_DROP_DB',
106                                                      '07' => 'COM_REFRESH',
107                                                      '08' => 'COM_SHUTDOWN',
108                                                      '09' => 'COM_STATISTICS',
109                                                      '0a' => 'COM_PROCESS_INFO',
110                                                      '0b' => 'COM_CONNECT',
111                                                      '0c' => 'COM_PROCESS_KILL',
112                                                      '0d' => 'COM_DEBUG',
113                                                      '0e' => 'COM_PING',
114                                                      '0f' => 'COM_TIME',
115                                                      '10' => 'COM_DELAYED_INSERT',
116                                                      '11' => 'COM_CHANGE_USER',
117                                                      '12' => 'COM_BINLOG_DUMP',
118                                                      '13' => 'COM_TABLE_DUMP',
119                                                      '14' => 'COM_CONNECT_OUT',
120                                                      '15' => 'COM_REGISTER_SLAVE',
121                                                      '16' => 'COM_STMT_PREPARE',
122                                                      '17' => 'COM_STMT_EXECUTE',
123                                                      '18' => 'COM_STMT_SEND_LONG_DATA',
124                                                      '19' => 'COM_STMT_CLOSE',
125                                                      '1a' => 'COM_STMT_RESET',
126                                                      '1b' => 'COM_SET_OPTION',
127                                                      '1c' => 'COM_STMT_FETCH',
128                                                   );
129                                                   
130                                                   my %flag_for = (
131                                                      'CLIENT_LONG_PASSWORD'     => 1,       # new more secure passwords 
132                                                      'CLIENT_FOUND_ROWS'        => 2,       # Found instead of affected rows 
133                                                      'CLIENT_LONG_FLAG'         => 4,       # Get all column flags 
134                                                      'CLIENT_CONNECT_WITH_DB'   => 8,       # One can specify db on connect 
135                                                      'CLIENT_NO_SCHEMA'         => 16,      # Don't allow database.table.column 
136                                                      'CLIENT_COMPRESS'          => 32,      # Can use compression protocol 
137                                                      'CLIENT_ODBC'              => 64,      # Odbc client 
138                                                      'CLIENT_LOCAL_FILES'       => 128,     # Can use LOAD DATA LOCAL 
139                                                      'CLIENT_IGNORE_SPACE'      => 256,     # Ignore spaces before '(' 
140                                                      'CLIENT_PROTOCOL_41'       => 512,     # New 4.1 protocol 
141                                                      'CLIENT_INTERACTIVE'       => 1024,    # This is an interactive client 
142                                                      'CLIENT_SSL'               => 2048,    # Switch to SSL after handshake 
143                                                      'CLIENT_IGNORE_SIGPIPE'    => 4096,    # IGNORE sigpipes 
144                                                      'CLIENT_TRANSACTIONS'      => 8192,    # Client knows about transactions 
145                                                      'CLIENT_RESERVED'          => 16384,   # Old flag for 4.1 protocol  
146                                                      'CLIENT_SECURE_CONNECTION' => 32768,   # New 4.1 authentication 
147                                                      'CLIENT_MULTI_STATEMENTS'  => 65536,   # Enable/disable multi-stmt support 
148                                                      'CLIENT_MULTI_RESULTS'     => 131072,  # Enable/disable multi-results 
149                                                   );
150                                                   
151                                                   # server is the "host:port" of the sever being watched.  It's auto-guessed if
152                                                   # not specified.  version is a placeholder for handling differences between
153                                                   # MySQL v4.0 and older and v4.1 and newer.  Currently, we only handle v4.1.
154                                                   sub new {
155           10                   10           422      my ( $class, %args ) = @_;
156           10                                 76      my $self = {
157                                                         server    => $args{server},
158                                                         version   => '41',
159                                                         sessions  => {},
160                                                      };
161           10                                 73      return bless $self, $class;
162                                                   }
163                                                   
164                                                   # The packet arg should be a hashref from TcpdumpParser::parse_event().
165                                                   # misc is a placeholder for future features.
166                                                   sub parse_packet {
167           66                   66           766      my ( $self, $packet, $misc ) = @_;
168                                                   
169                                                      # Auto-detect the server by looking for port 3306 or port "mysql" (sometimes
170                                                      # tcpdump will substitute the port by a lookup in /etc/protocols or
171                                                      # something).
172           66                                305      my $from  = "$packet->{src_host}:$packet->{src_port}";
173           66                                276      my $to    = "$packet->{dst_host}:$packet->{dst_port}";
174   ***     66     50    100                  324      $self->{server} ||= $from =~ m/:(?:3306|mysql)$/ ? $from
      ***            50                               
175                                                                        : $to   =~ m/:(?:3306|mysql)$/ ? $to
176                                                                        :                                undef;
177           66    100                         280      my $client = $from eq $self->{server} ? $to : $from;
178           66                                138      MKDEBUG && _d('Client:', $client);
179                                                   
180                                                      # Get the client's session info or create a new session if the
181                                                      # client hasn't been seen before.
182           66    100                         322      if ( !exists $self->{sessions}->{$client} ) {
183           12                                 24         MKDEBUG && _d('New session');
184           12                                110         $self->{sessions}->{$client} = {
185                                                            client   => $client,
186                                                            ts       => $packet->{ts},
187                                                            state    => undef,
188                                                            compress => undef,
189                                                         };
190                                                      };
191           66                                237      my $session = $self->{sessions}->{$client};
192                                                   
193                                                      # Return early if there's TCP/MySQL data.  These are usually ACK
194                                                      # packets, but they could also be FINs in which case, we should close
195                                                      # and delete the client's session.
196           66    100                         287      if ( $packet->{data_len} == 0 ) {
197           33                                 74         MKDEBUG && _d('No TCP/MySQL data');
198                                                         # Is the session ready to close?
199           33    100    100                 1142         if ( ($session->{state} || '') eq 'closing' ) {
200            2                                 10            delete $self->{sessions}->{$session->{client}};
201            2                                  7            MKDEBUG && _d('Session deleted'); 
202                                                         }
203           33                                194         return;
204                                                      }
205                                                   
206                                                      # Return unless the compressed packet can be uncompressed.
207                                                      # If it cannot, then we're helpless and must return.
208           33    100                         137      if ( $session->{compress} ) {
209   ***      2     50                           8         return unless uncompress_packet($packet);
210                                                      }
211                                                   
212                                                      # Remove the first MySQL header.  A single TCP packet can contain many
213                                                      # MySQL packets, but we only look at the first.  The 2nd and subsequent
214                                                      # packets are usually parts of a resultset returned by the server, but
215                                                      # we're not interested in resultsets.
216           33                                119      remove_mysql_header($packet);
217                                                   
218                                                      # Finally, parse the packet and maybe create an event.
219                                                      # The returned event may be empty if no event was ready to be created.
220           33                                 74      my $event;
221           33    100                         160      if ( $from eq $self->{server} ) {
      ***            50                               
222           17                                 80         $event = _packet_from_server($packet, $session, $misc);
223                                                      }
224                                                      elsif ( $from eq $client ) {
225           16                                 67         $event = _packet_from_client($packet, $session, $misc);
226                                                      }
227                                                      else {
228   ***      0                                  0         MKDEBUG && _d('Packet origin unknown');
229                                                      }
230                                                   
231           33                                153      MKDEBUG && _d('Done parsing packet; client state:', $session->{state});
232           33                                276      return $event;
233                                                   }
234                                                   
235                                                   # Handles a packet from the server given the state of the session.
236                                                   # The server can send back a lot of different stuff, but luckily
237                                                   # we're only interested in
238                                                   #    * Connection handshake packets for the thread_id
239                                                   #    * OK and Error packets for errors, warnings, etc.
240                                                   # Anything else is ignored.  Returns an event if one was ready to be
241                                                   # created, otherwise returns nothing.
242                                                   sub _packet_from_server {
243           17                   17            73      my ( $packet, $session, $misc ) = @_;
244   ***     17     50                          77      die "I need a packet"  unless $packet;
245   ***     17     50                          65      die "I need a session" unless $session;
246                                                   
247           17                                 36      MKDEBUG && _d('Packet is from server; client state:', $session->{state});
248                                                   
249           17                                 62      my $data = $packet->{data};
250                                                   
251                                                      # The first byte in the packet indicates whether it's an OK,
252                                                      # ERROR, EOF packet.  If it's not one of those, we test
253                                                      # whether it's an initialization packet (the first thing the
254                                                      # server ever sends the client).  If it's not that, it could
255                                                      # be a result set header, field, row data, etc.
256                                                   
257           17                                 74      my ( $first_byte ) = substr($data, 0, 2, '');
258           17                                 38      MKDEBUG && _d("First byte of packet:", $first_byte);
259                                                   
260   ***     17    100     66                  260      if ( $first_byte eq '00' ) { 
      ***           100     66                        
      ***           100     66                        
      ***           100     66                        
261   ***      5    100     50                   40         if ( ($session->{state} || '') eq 'client_auth' ) {
      ***            50                               
262                                                            # We logged in OK!  Trigger an admin Connect command.
263            2                                  8            $session->{state} = 'ready';
264                                                   
265            2                                  9            $session->{compress} = $session->{will_compress};
266            2                                  8            delete $session->{will_compress};
267            2                                  5            MKDEBUG && $session->{compress} && _d('Packets will be compressed');
268                                                   
269            2                                  4            MKDEBUG && _d('Admin command: Connect');
270            2                                 16            return _make_event(
271                                                               {  cmd => 'Admin',
272                                                                  arg => 'administrator command: Connect',
273                                                                  ts  => $packet->{ts}, # Events are timestamped when they end
274                                                               },
275                                                               $packet, $session
276                                                            );
277                                                         }
278                                                         elsif ( $session->{cmd} ) {
279                                                            # This OK should be ack'ing a query or something sent earlier
280                                                            # by the client.
281            3                                 13            my $ok  = parse_ok_packet($data);
282            3                                 11            my $com = $session->{cmd}->{cmd};
283            3                                  9            my $arg;
284                                                   
285   ***      3     50                          10            if ( $com eq COM_QUERY ) {
286            3                                  8               $com = 'Query';
287            3                                 14               $arg = $session->{cmd}->{arg};
288                                                            }
289                                                            else {
290   ***      0                                  0               $arg = 'administrator command: '
291                                                                    . ucfirst(lc(substr($com_for{$com}, 4)));
292   ***      0                                  0               $com = 'Admin';
293                                                            }
294                                                   
295            3                                 10            $session->{state} = 'ready';
296            3                                 32            return _make_event(
297                                                               {  cmd           => $com,
298                                                                  arg           => $arg,
299                                                                  ts            => $packet->{ts},
300                                                                  Insert_id     => $ok->{insert_id},
301                                                                  Warning_count => $ok->{warnings},
302                                                                  Rows_affected => $ok->{affected_rows},
303                                                               },
304                                                               $packet, $session
305                                                            );
306                                                         } 
307                                                      }
308                                                      elsif ( $first_byte eq 'ff' ) {
309            2                                 10         my $error = parse_error_packet($data);
310   ***      2     50                           9         if ( !$error ) {
311   ***      0                                  0            MKDEBUG && _d('Not an error packet');
312   ***      0                                  0            return;
313                                                         }
314            2                                  4         my $event;
315                                                   
316            2    100                          14         if ( $session->{state} eq 'client_auth' ) {
      ***            50                               
317            1                                  2            MKDEBUG && _d('Connection failed');
318            1                                  8            $event = {
319                                                               cmd       => 'Admin',
320                                                               arg       => 'administrator command: Connect',
321                                                               ts        => $packet->{ts},
322                                                               Error_no  => $error->{errno},
323                                                            };
324            1                                  4            $session->{state} = 'closing';
325                                                         }
326                                                         elsif ( $session->{cmd} ) {
327                                                            # This error should be in response to a query or something
328                                                            # sent earlier by the client.
329            1                                  4            my $com = $session->{cmd}->{cmd};
330            1                                  3            my $arg;
331                                                   
332   ***      1     50                           4            if ( $com eq COM_QUERY ) {
333            1                                  3               $com = 'Query';
334            1                                  5               $arg = $session->{cmd}->{arg};
335                                                            }
336                                                            else {
337   ***      0                                  0               $arg = 'administrator command: '
338                                                                    . ucfirst(lc(substr($com_for{$com}, 4)));
339   ***      0                                  0               $com = 'Admin';
340                                                            }
341            1                                  7            $event = {
342                                                               cmd       => $com,
343                                                               arg       => $arg,
344                                                               ts        => $packet->{ts},
345                                                               Error_no  => $error->{errno},
346                                                            };
347            1                                  4            $session->{state} = 'ready';
348                                                         }
349                                                   
350            2                                 10         return _make_event($event, $packet, $session);
351                                                      }
352                                                      elsif ( $first_byte eq 'fe' && $packet->{mysql_data_len} < 9 ) {
353   ***      1     50     33                   17         if ( $packet->{mysql_data_len} == 1
      ***                   33                        
354                                                              && $session->{state} eq 'client_auth'
355                                                              && $packet->{number} == 2 )
356                                                         {
357            1                                  3            MKDEBUG && _d('Server has old password table;',
358                                                               'client will resend password using old algorithm');
359            1                                  3            $session->{state} = 'client_auth_resend';
360                                                         }
361                                                         else {
362   ***      0                                  0            MKDEBUG && _d('Got an EOF packet');
363   ***      0                                  0            die "You should not have gotten here";
364                                                            # ^^^ We shouldn't reach this because EOF should come after a
365                                                            # header, field, or row data packet; and we should be firing the
366                                                            # event and returning when we see that.  See SVN history for some
367                                                            # good stuff we could do if we wanted to handle EOF packets.
368                                                         }
369                                                      }
370                                                      elsif ( !$session->{state}
371                                                              && $first_byte eq '0a'
372                                                              && length $data >= 33
373                                                              && $data =~ m/00{13}/ )
374                                                      {
375                                                         # It's the handshake packet from the server to the client.
376                                                         # 0a is protocol v10 which is essentially the only version used
377                                                         # today.  33 is the minimum possible length for a valid server
378                                                         # handshake packet.  It's probably a lot longer.  Other packets
379                                                         # may start with 0a, but none that can would be >= 33.  The 13-byte
380                                                         # 00 scramble buffer is another indicator.
381            3                                 16         my $handshake = parse_server_handshake_packet($data);
382            3                                 14         $session->{state}     = 'server_handshake';
383            3                                 21         $session->{thread_id} = $handshake->{thread_id};
384                                                      }
385                                                      else {
386                                                         # Since we do NOT always have all the data the server sent to the
387                                                         # client, we can't always do any processing of results.  So when
388                                                         # we get one of these, we just fire the event even if the query
389                                                         # is not done.  This means we will NOT process EOF packets
390                                                         # themselves (see above).
391   ***      6     50                          25         if ( $session->{cmd} ) {
392            6                                 15            MKDEBUG && _d('Got a row/field/result packet');
393            6                                 24            my $com = $session->{cmd}->{cmd};
394            6                                 12            MKDEBUG && _d('Responding to client', $com_for{$com});
395            6                                 29            my $event = { ts  => $packet->{ts} };
396   ***      6     50                          24            if ( $com eq COM_QUERY ) {
397            6                                 19               $event->{cmd} = 'Query';
398            6                                 30               $event->{arg} = $session->{cmd}->{arg};
399                                                            }
400                                                            else {
401   ***      0                                  0               $event->{arg} = 'administrator command: '
402                                                                    . ucfirst(lc(substr($com_for{$com}, 4)));
403   ***      0                                  0               $event->{cmd} = 'Admin';
404                                                            }
405                                                   
406                                                            # We DID get all the data in the packet.
407   ***      6     50                          27            if ( $packet->{complete} ) {
408                                                               # Look to see if the end of the data appears to be an EOF
409                                                               # packet.
410            6                                 49               my ( $warning_count, $status_flags )
411                                                                  = $data =~ m/fe(.{4})(.{4})\Z/;
412            6    100                          27               if ( $warning_count ) { 
413            5                                 17                  $event->{Warnings} = to_num($warning_count);
414            5                                 17                  my $flags = to_num($status_flags); # TODO set all flags?
415   ***      5     50                          26                  $event->{No_good_index_used}
416                                                                     = $flags & SERVER_QUERY_NO_GOOD_INDEX_USED ? 1 : 0;
417            5    100                          26                  $event->{No_index_used}
418                                                                     = $flags & SERVER_QUERY_NO_INDEX_USED ? 1 : 0;
419                                                               }
420                                                            }
421                                                   
422            6                                 19            $session->{state} = 'ready';
423            6                                 26            return _make_event($event, $packet, $session);
424                                                         }
425                                                         else {
426   ***      0                                  0            MKDEBUG && _d('Unknown in-stream server response');
427                                                         }
428                                                      }
429                                                   
430            4                                 17      return;
431                                                   }
432                                                   
433                                                   # Handles a packet from the client given the state of the session.
434                                                   # The client doesn't send a wide and exotic array of packets like
435                                                   # the server.  Even so, we're only interested in:
436                                                   #    * Users and dbs from connection handshake packets
437                                                   #    * SQL statements from COM_QUERY commands
438                                                   # Anything else is ignored.  Returns an event if one was ready to be
439                                                   # created, otherwise returns nothing.
440                                                   sub _packet_from_client {
441           16                   16            67      my ( $packet, $session, $misc ) = @_;
442   ***     16     50                          63      die "I need a packet"  unless $packet;
443   ***     16     50                          60      die "I need a session" unless $session;
444                                                   
445           16                                 41      MKDEBUG && _d('Packet is from client; state:', $session->{state});
446                                                   
447           16                                 57      my $data  = $packet->{data};
448           16                                 53      my $ts    = $packet->{ts};
449                                                   
450           16    100    100                  236      if ( ($session->{state} || '') eq 'server_handshake' ) {
                    100    100                        
      ***            50    100                        
451            3                                  9         MKDEBUG && _d('Expecting client authentication packet');
452                                                         # The connection is a 3-way handshake:
453                                                         #    server > client  (protocol version, thread id, etc.)
454                                                         #    client > server  (user, pass, default db, etc.)
455                                                         #    server > client  OK if login succeeds
456                                                         # pos_in_log refers to 2nd handshake from the client.
457                                                         # A connection is logged even if the client fails to
458                                                         # login (bad password, etc.).
459            3                                 13         my $handshake = parse_client_handshake_packet($data);
460            3                                 12         $session->{state}         = 'client_auth';
461            3                                 13         $session->{pos_in_log}    = $packet->{pos_in_log};
462            3                                 13         $session->{user}          = $handshake->{user};
463            3                                 13         $session->{db}            = $handshake->{db};
464                                                   
465                                                         # $session->{will_compress} will become $session->{compress} when
466                                                         # the server's final handshake packet is received.  This prevents
467                                                         # parse_packet() from trying to decompress that final packet.
468                                                         # Compressed packets can only begin after the full handshake is done.
469            3                                 26         $session->{will_compress} = $handshake->{flags}->{CLIENT_COMPRESS};
470                                                      }
471                                                      elsif ( ($session->{state} || '') eq 'client_auth_resend' ) {
472                                                         # Don't know how to parse this packet.
473            1                                  2         MKDEBUG && _d('Client resending password using old algorithm');
474            1                                  4         $session->{state} = 'client_auth';
475                                                      }
476                                                      elsif ( ($session->{state} || '') eq 'awaiting_reply' ) {
477   ***      0      0                           0         my $arg = $session->{cmd}->{arg} ? substr($session->{cmd}->{arg}, 0, 50)
478                                                                 : 'unknown';
479   ***      0                                  0         MKDEBUG && _d('More data for previous command:', $arg, '...'); 
480   ***      0                                  0         return;
481                                                      }
482                                                      else {
483                                                         # Otherwise, it should be a query.  We ignore the commands
484                                                         # that take arguments (COM_CHANGE_USER, COM_PROCESS_KILL).
485                                                   
486                                                         # Detect compression in-stream only if $session->{compress} is
487                                                         # not defined.  This means we didn't see the client handshake.
488                                                         # If we had seen it, $session->{compress} would be defined as 0 or 1.
489           12    100                          59         if ( !defined $session->{compress} ) {
490   ***      7     50                          32            return unless detect_compression($packet, $session);
491            7                                 27            $data = $packet->{data};
492                                                         }
493                                                   
494           12                                 54         my $com = parse_com_packet($data, $packet->{mysql_data_len});
495           12                                 45         $session->{state}      = 'awaiting_reply';
496           12                                 59         $session->{pos_in_log} = $packet->{pos_in_log};
497           12                                 41         $session->{ts}         = $ts;
498           12                                 75         $session->{cmd}        = {
499                                                            cmd => $com->{code},
500                                                            arg => $com->{data},
501                                                         };
502                                                   
503           12    100                          70         if ( $com->{code} eq COM_QUIT ) { # Fire right away; will cleanup later.
504            1                                  3            MKDEBUG && _d('Got a COM_QUIT');
505            1                                  3            $session->{state} = 'closing';
506            1                                  7            return _make_event(
507                                                               {  cmd       => 'Admin',
508                                                                  arg       => 'administrator command: Quit',
509                                                                  ts        => $ts,
510                                                               },
511                                                               $packet, $session
512                                                            );
513                                                         }
514                                                      }
515                                                   
516           15                                 50      return;
517                                                   }
518                                                   
519                                                   # Make and return an event from the given packet and session.
520                                                   sub _make_event {
521           14                   14            65      my ( $event, $packet, $session ) = @_;
522           14                                 34      MKDEBUG && _d('Making event');
523           14                                114      my ($host, $port) = $session->{client} =~ m/((?:\d+\.){3}\d+)\:(\w+)/;
524   ***     14     50    100                  105      return $event = {
                    100    100                        
                           100                        
525                                                         cmd        => $event->{cmd},
526                                                         arg        => $event->{arg},
527                                                         bytes      => length( $event->{arg} ),
528                                                         ts         => tcp_timestamp( $event->{ts} ),
529                                                         host       => $host,
530                                                         ip         => $host,
531                                                         port       => $port,
532                                                         db         => $session->{db},
533                                                         user       => $session->{user},
534                                                         Thread_id  => $session->{thread_id},
535                                                         pos_in_log => $session->{pos_in_log},
536                                                         Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
537                                                         Error_no   => ($event->{Error_no} || 0),
538                                                         Rows_affected      => ($event->{Rows_affected} || 0),
539                                                         Warning_count      => ($event->{Warning_count} || 0),
540                                                         No_good_index_used => ($event->{No_good_index_used} ? 'Yes' : 'No'),
541                                                         No_index_used      => ($event->{No_index_used}      ? 'Yes' : 'No'),
542                                                      };
543                                                   }
544                                                   
545                                                   # Extracts a slow-log-formatted timestamp from the tcpdump timestamp format.
546                                                   sub tcp_timestamp {
547           14                   14            62      my ( $ts ) = @_;
548           14                                169      $ts =~ s/^\d\d(\d\d)-(\d\d)-(\d\d)/$1$2$3/;
549           14                                150      return $ts;
550                                                   }
551                                                   
552                                                   # Returns the difference between two tcpdump timestamps.
553                                                   sub timestamp_diff {
554           14                   14            62      my ( $start, $end ) = @_;
555           14                                 77      my $sd = substr($start, 0, 11, '');
556           14                                 46      my $ed = substr($end,   0, 11, '');
557           14                                 88      my ( $sh, $sm, $ss ) = split(/:/, $start);
558           14                                 65      my ( $eh, $em, $es ) = split(/:/, $end);
559           14                                 92      my $esecs = ($eh * 3600 + $em * 60 + $es);
560           14                                 55      my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
561   ***     14     50                          53      if ( $sd eq $ed ) {
562           14                                667         return sprintf '%.6f', $esecs - $ssecs;
563                                                      }
564                                                      else { # Assume only one day boundary has been crossed, no DST, etc
565   ***      0                                  0         return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
566                                                      }
567                                                   }
568                                                   
569                                                   # Converts hexadecimal to string.
570                                                   sub to_string {
571           43                   43           168      my ( $data ) = @_;
572                                                      # $data =~ s/(..)/chr(hex $1)/eg;
573           43                                216      $data = pack('H*', $data);
574           43                                166      return $data;
575                                                   }
576                                                   
577                                                   # All numbers are stored with the least significant byte first in the MySQL
578                                                   # protocol.
579                                                   sub to_num {
580          110                  110           402      my ( $str ) = @_;
581          110                                642      my @bytes = $str =~ m/(..)/g;
582          110                                313      my $result = 0;
583          110                                527      foreach my $i ( 0 .. $#bytes ) {
584          239                               1166         $result += hex($bytes[$i]) * (16 ** ($i * 2));
585                                                      }
586          110                                436      return $result;
587                                                   }
588                                                   
589                                                   # Accepts a reference to a string, which it will modify.  Extracts a
590                                                   # length-coded binary off the front of the string and returns that value as an
591                                                   # integer.
592                                                   sub get_lcb {
593            8                    8            35      my ( $string ) = @_;
594            8                                 32      my $first_byte = hex(substr($$string, 0, 2, ''));
595   ***      8     50                          29      if ( $first_byte < 251 ) {
      ***             0                               
      ***             0                               
      ***             0                               
596            8                                 25         return $first_byte;
597                                                      }
598                                                      elsif ( $first_byte == 252 ) {
599   ***      0                                  0         return to_num(substr($$string, 0, 4, ''));
600                                                      }
601                                                      elsif ( $first_byte == 253 ) {
602   ***      0                                  0         return to_num(substr($$string, 0, 6, ''));
603                                                      }
604                                                      elsif ( $first_byte == 254 ) {
605   ***      0                                  0         return to_num(substr($$string, 0, 16, ''));
606                                                      }
607                                                   }
608                                                   
609                                                   # Error packet structure:
610                                                   # Offset  Bytes               Field
611                                                   # ======  =================   ====================================
612                                                   #         00 00 00 01         MySQL proto header (already removed)
613                                                   #         ff                  Error  (already removed)
614                                                   # 0       00 00               Error number
615                                                   # 4       00                  SQL state marker, always '#'
616                                                   # 6       00 00 00 00 00      SQL state
617                                                   # 16      00 ...              Error message
618                                                   # The sqlstate marker and actual sqlstate are combined into one value. 
619                                                   sub parse_error_packet {
620            3                    3            21      my ( $data ) = @_;
621   ***      3     50                          14      die "I need data" unless $data;
622            3                                  7      MKDEBUG && _d('ERROR data:', $data);
623   ***      3     50                          17      die "Error packet is too short: $data" if length $data < 16;
624            3                                 15      my $errno    = to_num(substr($data, 0, 4));
625            3                                 14      my $marker   = to_string(substr($data, 4, 2));
626   ***      3     50                          13      return unless $marker eq '#';
627            3                                 13      my $sqlstate = to_string(substr($data, 6, 10));
628            3                                 14      my $message  = to_string(substr($data, 16));
629            3                                 22      my $pkt = {
630                                                         errno    => $errno,
631                                                         sqlstate => $marker . $sqlstate,
632                                                         message  => $message,
633                                                      };
634            3                                  7      MKDEBUG && _d('Error packet:', Dumper($pkt));
635            3                                 16      return $pkt;
636                                                   }
637                                                   
638                                                   # OK packet structure:
639                                                   # Offset  Bytes               Field
640                                                   # ======  =================   ====================================
641                                                   #         00 00 00 01         MySQL proto header (already removed)
642                                                   #         00                  OK  (already removed)
643                                                   #         1-9                 Affected rows (LCB)
644                                                   #         1-9                 Insert ID (LCB)
645                                                   #         00 00               Server status
646                                                   #         00 00               Warning count
647                                                   #         00 ...              Message (optional)
648                                                   sub parse_ok_packet {
649            4                    4            17      my ( $data ) = @_;
650   ***      4     50                          18      die "I need data" unless $data;
651            4                                  9      MKDEBUG && _d('OK data:', $data);
652   ***      4     50                          18      die "OK packet is too short: $data" if length $data < 12;
653            4                                 16      my $affected_rows = get_lcb(\$data);
654            4                                 15      my $insert_id     = get_lcb(\$data);
655            4                                 19      my $status        = to_num(substr($data, 0, 4, ''));
656            4                                 23      my $warnings      = to_num(substr($data, 0, 4, ''));
657            4                                 15      my $message       = to_string($data);
658                                                      # Note: $message is discarded.  It might be something like
659                                                      # Records: 2  Duplicates: 0  Warnings: 0
660            4                                 32      my $pkt = {
661                                                         affected_rows => $affected_rows,
662                                                         insert_id     => $insert_id,
663                                                         status        => $status,
664                                                         warnings      => $warnings,
665                                                         message       => $message,
666                                                      };
667            4                                  8      MKDEBUG && _d('OK packet:', Dumper($pkt));
668            4                                 19      return $pkt;
669                                                   }
670                                                   
671                                                   # Currently we only capture and return the thread id.
672                                                   sub parse_server_handshake_packet {
673            4                    4            30      my ( $data ) = @_;
674   ***      4     50                          18      die "I need data" unless $data;
675            4                                 11      MKDEBUG && _d('Server handshake data:', $data);
676            4                                 41      my $handshake_pattern = qr{
677                                                                           # Bytes                Name
678                                                         ^                 # -----                ----
679                                                         (.+?)00           # n Null-Term String   server_version
680                                                         (.{8})            # 4                    thread_id
681                                                         .{16}             # 8                    scramble_buff
682                                                         .{2}              # 1                    filler: always 0x00
683                                                         (.{4})            # 2                    server_capabilities
684                                                         .{2}              # 1                    server_language
685                                                         .{4}              # 2                    server_status
686                                                         .{26}             # 13                   filler: always 0x00
687                                                                           # 13                   rest of scramble_buff
688                                                      }x;
689            4                                 52      my ( $server_version, $thread_id, $flags ) = $data =~ m/$handshake_pattern/;
690            4                                 22      my $pkt = {
691                                                         server_version => to_string($server_version),
692                                                         thread_id      => to_num($thread_id),
693                                                         flags          => parse_flags($flags),
694                                                      };
695            4                                 11      MKDEBUG && _d('Server handshake packet:', Dumper($pkt));
696            4                                 48      return $pkt;
697                                                   }
698                                                   
699                                                   # Currently we only capture and return the user and default database.
700                                                   sub parse_client_handshake_packet {
701            4                    4            23      my ( $data ) = @_;
702   ***      4     50                          18      die "I need data" unless $data;
703            4                                  9      MKDEBUG && _d('Client handshake data:', $data);
704            4                                 50      my ( $flags, $user, $buff_len ) = $data =~ m{
705                                                         ^
706                                                         (.{8})         # Client flags
707                                                         .{10}          # Max packet size, charset
708                                                         (?:00){23}     # Filler
709                                                         ((?:..)+?)00   # Null-terminated user name
710                                                         (..)           # Length-coding byte for scramble buff
711                                                      }x;
712                                                   
713                                                      # This packet is easy to detect because it's the only case where
714                                                      # the server sends the client a packet first (its handshake) and
715                                                      # then the client only and ever sends back its handshake.
716   ***      4     50                          18      die "Did not match client handshake packet" unless $buff_len;
717                                                   
718                                                      # This length-coded binary doesn't seem to be a normal one, it
719                                                      # seems more like a length-coded string actually.
720            4                                 14      my $code_len = hex($buff_len);
721            4                                108      my ( $db ) = $data =~ m!
722                                                         ^.{64}${user}00..   # Everything matched before
723                                                         (?:..){$code_len}   # The scramble buffer
724                                                         (.*)00\Z            # The database name
725                                                      !x;
726            4    100                          16      my $pkt = {
727                                                         user  => to_string($user),
728                                                         db    => $db ? to_string($db) : '',
729                                                         flags => parse_flags($flags),
730                                                      };
731            4                                 11      MKDEBUG && _d('Client handshake packet:', Dumper($pkt));
732            4                                 29      return $pkt;
733                                                   }
734                                                   
735                                                   # COM data is not 00-terminated, but the the MySQL client appends \0,
736                                                   # so we have to use the packet length to know where the data ends.
737                                                   sub parse_com_packet {
738           20                   20            89      my ( $data, $len ) = @_;
739   ***     20     50                          75      die "I need data"  unless $data;
740   ***     20     50                          69      die "I need a len" unless $len;
741           20                                 45      MKDEBUG && _d('COM data:', $data, 'len:', $len);
742           20                                 66      my $code = substr($data, 0, 2);
743           20                                 76      my $com  = $com_for{$code};
744   ***     20     50                          83      die "Did not match COM packet" unless $com;
745           20                                108      $data    = to_string(substr($data, 2, ($len - 1) * 2));
746           20                                118      my $pkt = {
747                                                         code => $code,
748                                                         com  => $com,
749                                                         data => $data,
750                                                      };
751           20                                 48      MKDEBUG && _d('COM packet:', Dumper($pkt));
752           20                                 71      return $pkt;
753                                                   }
754                                                   
755                                                   sub parse_flags {
756            8                    8            31      my ( $flags ) = @_;
757   ***      8     50                          35      die "I need flags" unless $flags;
758            8                                 18      MKDEBUG && _d('Flag data:', $flags);
759            8                                104      my %flags     = %flag_for;
760            8                                 34      my $flags_dec = to_num($flags);
761            8                                 42      foreach my $flag ( keys %flag_for ) {
762          144                                388         my $flagno    = $flag_for{$flag};
763          144    100                         585         $flags{$flag} = ($flags_dec & $flagno ? 1 : 0);
764                                                      }
765            8                                 70      return \%flags;
766                                                   }
767                                                   
768                                                   # Takes a scalarref to a hex string of compressed data.
769                                                   # Returns a scalarref to a hex string of the uncompressed data.
770                                                   # The given hex string of compressed data is not modified.
771                                                   sub uncompress_data {
772   ***      0                    0             0      my ( $data ) = @_;
773   ***      0      0                           0      die "I need data" unless $data;
774   ***      0      0                           0      die "I need a scalar reference" unless ref $data eq 'SCALAR';
775   ***      0                                  0      MKDEBUG && _d('Uncompressing packet');
776                                                   
777                                                      # Pack hex string into compressed binary data.
778   ***      0                                  0      my $comp_bin_data = pack('H*', $$data);
779                                                   
780                                                      # Uncompress the compressed binary data.
781   ***      0                                  0      my $uncomp_bin_data = '';
782   ***      0      0                           0      my $status          = inflate(
783                                                         \$comp_bin_data => \$uncomp_bin_data,
784                                                      ) or die "inflate failed";
785                                                   
786                                                      # Unpack the uncompressed binary data back into a hex string.
787                                                      # This is the original MySQL packet(s).
788   ***      0                                  0      my $uncomp_data = unpack('H*', $uncomp_bin_data);
789                                                   
790   ***      0                                  0      return \$uncomp_data;
791                                                   }
792                                                   
793                                                   # Returns 1 on success or 0 on failure.  Failure is probably
794                                                   # detecting compression but not being able to uncompress
795                                                   # (uncompress_packet() returns 0).
796                                                   sub detect_compression {
797            7                    7            29      my ( $packet, $session ) = @_;
798            7                                 21      MKDEBUG && _d('Checking for client compression');
799                                                      # This is a necessary hack for detecting compression in-stream without
800                                                      # having seen the client handshake and CLIENT_COMPRESS flag.  If the
801                                                      # client is compressing packets, there will be an extra 7 bytes before
802                                                      # the regular MySQL header.  For short COM_QUERY commands, these 7 bytes
803                                                      # are usually zero where we'd expect to see 03 for COM_QUERY.  So if we
804                                                      # parse this packet and it looks like a COM_SLEEP (00) which is not a
805                                                      # command that the client can send, then chances are the client is using
806                                                      # compression.
807            7                                 40      my $com = parse_com_packet($packet->{data}, $packet->{data_len});
808            7    100                          36      if ( $com->{code} eq COM_SLEEP ) {
809            1                                  2         MKDEBUG && _d('Client is using compression');
810            1                                  4         $session->{compress} = 1;
811                                                   
812                                                         # Since parse_packet() didn't know the packet was compressed, it
813                                                         # called remove_mysql_header() which removed the first 4 of 7 bytes
814                                                         # of the compression header.  We must restore these 4 bytes, then
815                                                         # uncompress and remove the MySQL header.  We only do this once.
816            1                                  6         $packet->{data} = $packet->{mysql_hdr} . $packet->{data};
817   ***      1     50                           6         return 0 unless uncompress_packet($packet);
818            1                                  3         remove_mysql_header($packet);
819                                                      }
820                                                      else {
821            6                                 17         MKDEBUG && _d('Client is NOT using compression');
822            6                                 20         $session->{compress} = 0;
823                                                      }
824            7                                 39      return 1;
825                                                   }
826                                                   
827                                                   # Returns 1 if the packet was uncompressed or 0 if we can't uncompress.
828                                                   # Failure is usually due to IO::Uncompress not being available.
829                                                   sub uncompress_packet {
830            3                    3            18      my ( $packet ) = @_;
831   ***      3     50                          13      die "I need a packet" unless $packet;
832                                                   
833                                                      # From the doc: "A compressed packet header is:
834                                                      #    packet length (3 bytes),
835                                                      #    packet number (1 byte),
836                                                      #    and Uncompressed Packet Length (3 bytes).
837                                                      # The Uncompressed Packet Length is the number of bytes
838                                                      # in the original, uncompressed packet. If this is zero
839                                                      # then the data is not compressed."
840                                                   
841            3                                 12      my $data            = \$packet->{data};
842            3                                 22      my $comp_hdr        = substr($$data, 0, 14, '');
843            3                                 14      my $comp_data_len   = to_num(substr($comp_hdr, 0, 6));
844            3                                 15      my $pkt_num         = to_num(substr($comp_hdr, 6, 2));
845            3                                 17      my $uncomp_data_len = to_num(substr($comp_hdr, 8, 6));
846            3                                  6      MKDEBUG && _d('Compression header data:', $comp_hdr,
847                                                         'compressed data len (bytes)', $comp_data_len,
848                                                         'number', $pkt_num,
849                                                         'uncompressed data len (bytes)', $uncomp_data_len);
850                                                   
851   ***      3     50                          11      if ( $uncomp_data_len ) {
852   ***      0                                  0         eval {
853   ***      0                                  0            $data = uncompress_data($data);
854   ***      0                                  0            $packet->{data} = $$data;
855                                                         };
856   ***      0      0                           0         if ( $EVAL_ERROR ) {
857   ***      0                                  0            die "Cannot uncompress packet.  Check that IO::Uncompress::Inflate "
858                                                               . "is installed.\n\nError: $EVAL_ERROR";
859                                                         }
860                                                      }
861                                                      else {
862            3                                  7         MKDEBUG && _d('Packet is not really compressed');
863            3                                 13         $packet->{data} = $$data;
864                                                      }
865                                                   
866            3                                 16      return 1;
867                                                   }
868                                                   
869                                                   # Removes the first 4 bytes of the packet data which should be
870                                                   # a MySQL header: 3 bytes packet length, 1 byte packet number.
871                                                   sub remove_mysql_header {
872           34                   34           118      my ( $packet ) = @_;
873   ***     34     50                         127      die "I need a packet" unless $packet;
874                                                   
875                                                      # NOTE: the data is modified by the inmost substr call here!  If we
876                                                      # had all the data in the TCP packets, we could change this to a while
877                                                      # loop; while get-a-packet-from-$data, do stuff, etc.  But we don't,
878                                                      # and we don't want to either.
879           34                                159      my $mysql_hdr      = substr($packet->{data}, 0, 8, '');
880           34                                151      my $mysql_data_len = to_num(substr($mysql_hdr, 0, 6));
881           34                                143      my $pkt_num        = to_num(substr($mysql_hdr, 6, 2));
882           34                                 90      MKDEBUG && _d('MySQL packet: header data', $mysql_hdr,
883                                                         'data len (bytes)', $mysql_data_len, 'number', $pkt_num);
884                                                   
885           34                                132      $packet->{mysql_hdr}      = $mysql_hdr;
886           34                                116      $packet->{mysql_data_len} = $mysql_data_len;
887           34                                105      $packet->{number}         = $pkt_num;
888                                                   
889           34                                 95      return;
890                                                   }
891                                                   
892                                                   sub _d {
893   ***      0                    0                    my ($package, undef, $line) = caller 0;
894   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
895   ***      0                                              map { defined $_ ? $_ : 'undef' }
896                                                           @_;
897   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
898                                                   }
899                                                   
900                                                   1;
901                                                   
902                                                   # ###########################################################################
903                                                   # End MySQLProtocolParser package
904                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
174   ***     50      7      0   $to =~ /:(?:3306|mysql)$/ ? :
      ***     50      0      7   $from =~ /:(?:3306|mysql)$/ ? :
177          100     31     35   $from eq $$self{'server'} ? :
182          100     12     54   if (not exists $$self{'sessions'}{$client})
196          100     33     33   if ($$packet{'data_len'} == 0)
199          100      2     31   if (($$session{'state'} || '') eq 'closing')
208          100      2     31   if ($$session{'compress'})
209   ***     50      0      2   unless uncompress_packet($packet)
221          100     17     16   if ($from eq $$self{'server'}) { }
      ***     50     16      0   elsif ($from eq $client) { }
244   ***     50      0     17   unless $packet
245   ***     50      0     17   unless $session
260          100      5     12   if ($first_byte eq '00') { }
             100      2     10   elsif ($first_byte eq 'ff') { }
             100      1      9   elsif ($first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9) { }
             100      3      6   elsif (not $$session{'state'} and $first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/) { }
261          100      2      3   if (($$session{'state'} || '') eq 'client_auth') { }
      ***     50      3      0   elsif ($$session{'cmd'}) { }
285   ***     50      3      0   if ($com eq '03') { }
310   ***     50      0      2   if (not $error)
316          100      1      1   if ($$session{'state'} eq 'client_auth') { }
      ***     50      1      0   elsif ($$session{'cmd'}) { }
332   ***     50      1      0   if ($com eq '03') { }
353   ***     50      1      0   if ($$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2) { }
391   ***     50      6      0   if ($$session{'cmd'}) { }
396   ***     50      6      0   if ($com eq '03') { }
407   ***     50      6      0   if ($$packet{'complete'})
412          100      5      1   if ($warning_count)
415   ***     50      0      5   $flags & 16 ? :
417          100      1      4   $flags & 32 ? :
442   ***     50      0     16   unless $packet
443   ***     50      0     16   unless $session
450          100      3     13   if (($$session{'state'} || '') eq 'server_handshake') { }
             100      1     12   elsif (($$session{'state'} || '') eq 'client_auth_resend') { }
      ***     50      0     12   elsif (($$session{'state'} || '') eq 'awaiting_reply') { }
477   ***      0      0      0   $$session{'cmd'}{'arg'} ? :
489          100      7      5   if (not defined $$session{'compress'})
490   ***     50      0      7   unless detect_compression($packet, $session)
503          100      1     11   if ($$com{'code'} eq '01')
524   ***     50      0     14   $$event{'No_good_index_used'} ? :
             100      1     13   $$event{'No_index_used'} ? :
561   ***     50     14      0   if ($sd eq $ed) { }
595   ***     50      8      0   if ($first_byte < 251) { }
      ***      0      0      0   elsif ($first_byte == 252) { }
      ***      0      0      0   elsif ($first_byte == 253) { }
      ***      0      0      0   elsif ($first_byte == 254) { }
621   ***     50      0      3   unless $data
623   ***     50      0      3   if length $data < 16
626   ***     50      0      3   unless $marker eq '#'
650   ***     50      0      4   unless $data
652   ***     50      0      4   if length $data < 12
674   ***     50      0      4   unless $data
702   ***     50      0      4   unless $data
716   ***     50      0      4   unless $buff_len
726          100      2      2   $db ? :
739   ***     50      0     20   unless $data
740   ***     50      0     20   unless $len
744   ***     50      0     20   unless $com
757   ***     50      0      8   unless $flags
763          100     62     82   $flags_dec & $flagno ? :
773   ***      0      0      0   unless $data
774   ***      0      0      0   unless ref $data eq 'SCALAR'
782   ***      0      0      0   unless my $status = inflate(\$comp_bin_data, \$uncomp_bin_data)
808          100      1      6   if ($$com{'code'} eq '00') { }
817   ***     50      0      1   unless uncompress_packet($packet)
831   ***     50      0      3   unless $packet
851   ***     50      0      3   if ($uncomp_data_len) { }
856   ***      0      0      0   if ($EVAL_ERROR)
873   ***     50      0     34   unless $packet
894   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
260   ***     66      9      0      1   $first_byte eq 'fe' and $$packet{'mysql_data_len'} < 9
      ***     66      6      0      3   not $$session{'state'} and $first_byte eq '0a'
      ***     66      6      0      3   not $$session{'state'} and $first_byte eq '0a' and length $data >= 33
      ***     66      6      0      3   not $$session{'state'} and $first_byte eq '0a' and length $data >= 33 and $data =~ /00{13}/
353   ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth'
      ***     33      0      0      1   $$packet{'mysql_data_len'} == 1 and $$session{'state'} eq 'client_auth' and $$packet{'number'} == 2

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
174          100     59      7   $$self{'server'} ||= $from =~ /:(?:3306|mysql)$/ ? $from : ($to =~ /:(?:3306|mysql)$/ ? $to : undef)
199          100     19     14   $$session{'state'} || ''
261   ***     50      5      0   $$session{'state'} || ''
450          100      9      7   $$session{'state'} || ''
             100      6      7   $$session{'state'} || ''
             100      5      7   $$session{'state'} || ''
524          100      2     12   $$event{'Error_no'} || 0
             100      3     11   $$event{'Rows_affected'} || 0
             100      1     13   $$event{'Warning_count'} || 0


Covered Subroutines
-------------------

Subroutine                    Count Location                                                  
----------------------------- ----- ----------------------------------------------------------
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:38 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:39 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:40 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:47 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:63 
BEGIN                             1 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:96 
_make_event                      14 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:521
_packet_from_client              16 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:441
_packet_from_server              17 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:243
detect_compression                7 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:797
get_lcb                           8 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:593
new                              10 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:155
parse_client_handshake_packet     4 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:701
parse_com_packet                 20 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:738
parse_error_packet                3 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:620
parse_flags                       8 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:756
parse_ok_packet                   4 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:649
parse_packet                     66 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:167
parse_server_handshake_packet     4 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:673
remove_mysql_header              34 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:872
tcp_timestamp                    14 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:547
timestamp_diff                   14 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:554
to_num                          110 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:580
to_string                        43 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:571
uncompress_packet                 3 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:830

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                                  
----------------------------- ----- ----------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:893
uncompress_data                   0 /home/daniel/dev/maatkit/common/MySQLProtocolParser.pm:772


