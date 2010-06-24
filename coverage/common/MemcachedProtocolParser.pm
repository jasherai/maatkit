---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...emcachedProtocolParser.pm   81.2   69.0   60.5   78.6    0.0   98.4   75.0
MemcachedProtocolParser.t     100.0   50.0   33.3  100.0    n/a    1.6   95.5
Total                          84.8   68.6   58.5   86.4    0.0  100.0   78.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:02 2010
Finish:       Thu Jun 24 19:35:02 2010

Run:          MemcachedProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:03 2010
Finish:       Thu Jun 24 19:35:04 2010

/home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm

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
18                                                    # MemcachedProtocolParser package $Revision: 5810 $
19                                                    # ###########################################################################
20                                                    package MemcachedProtocolParser;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                 18   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25                                                    
26             1                    1             5   use Data::Dumper;
               1                                  3   
               1                                  7   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 14   
32                                                    
33                                                    sub new {
34    ***     14                   14      0     85      my ( $class, %args ) = @_;
35                                                    
36    ***     14            50                  246      my $self = {
37                                                          server      => $args{server},
38                                                          port        => $args{port} || '11211',
39                                                          sessions    => {},
40                                                          o           => $args{o},
41                                                       };
42            14                                104      return bless $self, $class;
43                                                    }
44                                                    
45                                                    # The packet arg should be a hashref from TcpdumpParser::parse_event().
46                                                    # misc is a placeholder for future features.
47                                                    sub parse_event {
48    ***     64                   64      0  75910      my ( $self, %args ) = @_;
49            64                                320      my @required_args = qw(event);
50            64                                238      foreach my $arg ( @required_args ) {
51    ***     64     50                         381         die "I need a $arg argument" unless $args{$arg};
52                                                       }
53            64                                247      my $packet = @args{@required_args};
54                                                    
55            64                                653      my $src_host = "$packet->{src_host}:$packet->{src_port}";
56            64                                295      my $dst_host = "$packet->{dst_host}:$packet->{dst_port}";
57                                                    
58    ***     64     50                         298      if ( my $server = $self->{server} ) {  # Watch only the given server.
59    ***      0                                  0         $server .= ":$self->{port}";
60    ***      0      0      0                    0         if ( $src_host ne $server && $dst_host ne $server ) {
61    ***      0                                  0            MKDEBUG && _d('Packet is not to or from', $server);
62    ***      0                                  0            return;
63                                                          }
64                                                       }
65                                                    
66                                                       # Auto-detect the server by looking for port 11211
67            64                                157      my $packet_from;
68            64                                155      my $client;
69            64    100                         613      if ( $src_host =~ m/:$self->{port}$/ ) {
      ***            50                               
70            31                                 96         $packet_from = 'server';
71            31                                105         $client      = $dst_host;
72                                                       }
73                                                       elsif ( $dst_host =~ m/:$self->{port}$/ ) {
74            33                                102         $packet_from = 'client';
75            33                                124         $client      = $src_host;
76                                                       }
77                                                       else {
78    ***      0                                  0         warn 'Packet is not to or from memcached server: ', Dumper($packet);
79    ***      0                                  0         return;
80                                                       }
81            64                                155      MKDEBUG && _d('Client:', $client);
82                                                    
83                                                       # Get the client's session info or create a new session if the
84                                                       # client hasn't been seen before.
85            64    100                         376      if ( !exists $self->{sessions}->{$client} ) {
86            22                                 61         MKDEBUG && _d('New session');
87            22                                196         $self->{sessions}->{$client} = {
88                                                             client      => $client,
89                                                             state       => undef,
90                                                             raw_packets => [],
91                                                             # ts -- wait for ts later.
92                                                          };
93                                                       };
94            64                                252      my $session = $self->{sessions}->{$client};
95                                                    
96                                                       # Return early if there's no TCP data.  These are usually ACK packets, but
97                                                       # they could also be FINs in which case, we should close and delete the
98                                                       # client's session.
99            64    100                         309      if ( $packet->{data_len} == 0 ) {
100           20                                 45         MKDEBUG && _d('No TCP data');
101           20                                108         return;
102                                                      }
103                                                   
104                                                      # Save raw packets to dump later in case something fails.
105           44                                110      push @{$session->{raw_packets}}, $packet->{raw_packet};
              44                                345   
106                                                   
107                                                      # Finally, parse the packet and maybe create an event.
108           44                                863      $packet->{data} = pack('H*', $packet->{data});
109           44                                121      my $event;
110           44    100                         211      if ( $packet_from eq 'server' ) {
      ***            50                               
111           24                                131         $event = $self->_packet_from_server($packet, $session, $args{misc});
112                                                      }
113                                                      elsif ( $packet_from eq 'client' ) {
114           20                                138         $event = $self->_packet_from_client($packet, $session, $args{misc});
115                                                      }
116                                                      else {
117                                                         # Should not get here.
118   ***      0                                  0         die 'Packet origin unknown';
119                                                      }
120                                                   
121           44                                104      MKDEBUG && _d('Done with packet; event:', Dumper($event));
122           44                                302      return $event;
123                                                   }
124                                                   
125                                                   # Handles a packet from the server given the state of the session.  Returns an
126                                                   # event if one was ready to be created, otherwise returns nothing.
127                                                   sub _packet_from_server {
128           24                   24           104      my ( $self, $packet, $session, $misc ) = @_;
129   ***     24     50                         106      die "I need a packet"  unless $packet;
130   ***     24     50                          88      die "I need a session" unless $session;
131                                                   
132           24                                 58      MKDEBUG && _d('Packet is from server; client state:', $session->{state}); 
133                                                   
134           24                                105      my $data = $packet->{data};
135                                                   
136                                                      # If there's no session state, then we're catching a server response
137                                                      # mid-stream.
138           24    100                         107      if ( !$session->{state} ) {
139            3                                  7         MKDEBUG && _d('Ignoring mid-stream server response');
140            3                                 11         return;
141                                                      }
142                                                   
143                                                      # Assume that the server is returning only one value.  TODO: make it
144                                                      # handle multi-gets.
145           21    100                         100      if ( $session->{state} eq 'awaiting reply' ) {
146           19                                 47         MKDEBUG && _d('State is awaiting reply');
147                                                         # \r\n == 0d0a
148           19                                175         my ($line1, $rest) = $packet->{data} =~ m/\A(.*?)\r\n(.*)?/s;
149                                                   
150                                                         # Split up the first line into its parts.
151           19                                433         my @vals = $line1 =~ m/(\S+)/g;
152           19                                 92         $session->{res} = shift @vals;
153           19                                 50         MKDEBUG && _d('Result of last', $session->{cmd}, 'cmd:', $session->{res});
154                                                   
155           19    100    100                  319         if ( $session->{cmd} eq 'incr' || $session->{cmd} eq 'decr' ) {
                    100                               
                    100                               
      ***            50                               
156            4                                 10            MKDEBUG && _d('It is an incr or decr');
157            4    100                          30            if ( $session->{res} !~ m/\D/ ) { # It's an integer, not an error
158            2                                 11               MKDEBUG && _d('Got a value for the incr/decr');
159            2                                  9               $session->{val} = $session->{res};
160            2                                  8               $session->{res} = '';
161                                                            }
162                                                         }
163                                                         elsif ( $session->{res} eq 'VALUE' ) {
164            6                                 17            MKDEBUG && _d('It is the result of a "get"');
165            6                                 27            my ($key, $flags, $bytes) = @vals;
166   ***      6     50                          34            defined $session->{flags} or $session->{flags} = $flags;
167   ***      6     50                          44            defined $session->{bytes} or $session->{bytes} = $bytes;
168                                                            # Get the value from the $rest. TODO: there might be multiple responses
169   ***      6     50     33                   47            if ( $rest && $bytes ) {
170            6                                 14               MKDEBUG && _d('There is a value');
171            6    100                          35               if ( length($rest) > $bytes ) {
172            4                                  8                  MKDEBUG && _d('Looks like we got the whole response');
173            4                                 24                  $session->{val} = substr($rest, 0, $bytes); # Got the whole response.
174                                                               }
175                                                               else {
176            2                                  5                  MKDEBUG && _d('Got partial response, saving for later');
177            2                                  6                  push @{$session->{partial}}, [ $packet->{seq}, $rest ];
               2                                 15   
178            2                                  9                  $session->{gathered} += length($rest);
179            2                                  7                  $session->{state} = 'partial recv';
180            2                                 10                  return; # Prevent firing an event.
181                                                               }
182                                                            }
183                                                         }
184                                                         elsif ( $session->{res} eq 'END' ) {
185                                                            # Technically NOT_FOUND is an error, and this isn't an error it's just
186                                                            # a NULL, but what it really means is the value isn't found.
187            2                                  5            MKDEBUG && _d('Got an END without any data, firing NOT_FOUND');
188            2                                  9            $session->{res} = 'NOT_FOUND';
189                                                         }
190                                                         elsif ( $session->{res} !~ m/STORED|DELETED|NOT_FOUND/ ) {
191                                                            # Not really sure what else would get us here... want to make a note
192                                                            # and not have an uncaught condition.
193   ***      0                                  0            MKDEBUG && _d('Unknown result');
194                                                         }
195                                                      }
196                                                      else { # Should be 'partial recv'
197            2                                  8         MKDEBUG && _d('Session state: ', $session->{state});
198            2                                  7         push @{$session->{partial}}, [ $packet->{seq}, $data ];
               2                                 38   
199            2                                 10         $session->{gathered} += length($data);
200                                                         MKDEBUG && _d('Gathered', $session->{gathered}, 'bytes in',
201            2                                  5            scalar(@{$session->{partial}}), 'packets from server');
202            2    100                          17         if ( $session->{gathered} >= $session->{bytes} + 2 ) { # Done.
203            1                                  4            MKDEBUG && _d('End of partial response, preparing event');
204            3                                 40            my $val = join('',
205            3                                 14               map  { $_->[1] }
206                                                               # Sort in proper sequence because TCP might reorder them.
207            1                                  2               sort { $a->[0] <=> $b->[0] }
208            1                                  4                    @{$session->{partial}});
209            1                                 18            $session->{val} = substr($val, 0, $session->{bytes});
210                                                         }
211                                                         else {
212            1                                  3            MKDEBUG && _d('Partial response continues, no action');
213            1                                  5            return; # Prevent firing event.
214                                                         }
215                                                      }
216                                                   
217           18                                 46      MKDEBUG && _d('Creating event, deleting session');
218           18                                 80      my $event = make_event($session, $packet);
219           18                                 98      delete $self->{sessions}->{$session->{client}}; # memcached is stateless!
220           18                                 65      $session->{raw_packets} = []; # Avoid keeping forever
221           18                                 99      return $event;
222                                                   }
223                                                   
224                                                   # Handles a packet from the client given the state of the session.
225                                                   sub _packet_from_client {
226           20                   20            97      my ( $self, $packet, $session, $misc ) = @_;
227   ***     20     50                          84      die "I need a packet"  unless $packet;
228   ***     20     50                          78      die "I need a session" unless $session;
229                                                   
230           20                                 48      MKDEBUG && _d('Packet is from client; state:', $session->{state});
231                                                   
232           20                                 54      my $event;
233           20    100    100                  229      if ( ($session->{state} || '') =~m/awaiting reply|partial recv/ ) {
234                                                         # Whoa, we expected something from the server, not the client.  Fire an
235                                                         # INTERRUPTED with what we've got, and create a new session.
236            1                                  4         MKDEBUG && _d("Expected data from the client, looks like interrupted");
237            1                                  4         $session->{res} = 'INTERRUPTED';
238            1                                  5         $event = make_event($session, $packet);
239            1                                  5         my $client = $session->{client};
240            1                                  5         delete @{$session}{keys %$session};
               1                                  9   
241            1                                  6         $session->{client} = $client;
242                                                      }
243                                                   
244           20                                 69      my ($line1, $val);
245           20                                 77      my ($cmd, $key, $flags, $exptime, $bytes);
246                                                      
247           20    100                          92      if ( !$session->{state} ) {
248           19                                 47         MKDEBUG && _d('Session state: ', $session->{state});
249                                                         # Split up the first line into its parts.
250           19                                245         ($line1, $val) = $packet->{data} =~ m/\A(.*?)\r\n(.+)?/s;
251                                                         # TODO: handle <cas unique> and [noreply]
252           19                                165         my @vals = $line1 =~ m/(\S+)/g;
253           19                                 91         $cmd = lc shift @vals;
254           19                                 46         MKDEBUG && _d('$cmd is a ', $cmd);
255   ***     19    100     66                  330         if ( $cmd eq 'set' || $cmd eq 'add' || $cmd eq 'replace' ) {
                    100    100                        
      ***           100     66                        
      ***            50                               
256            4                                 17            ($key, $flags, $exptime, $bytes) = @vals;
257            4                                 22            $session->{bytes} = $bytes;
258                                                         }
259                                                         elsif ( $cmd eq 'get' ) {
260            8                                 29            ($key) = @vals;
261            8    100                          35            if ( $val ) {
262            1                                  3               MKDEBUG && _d('Multiple cmds:', $val);
263            1                                  4               $val = undef;
264                                                            }
265                                                         }
266                                                         elsif ( $cmd eq 'delete' ) {
267            3                                 11            ($key) = @vals; # TODO: handle the <queue_time>
268            3    100                          15            if ( $val ) {
269            1                                  3               MKDEBUG && _d('Multiple cmds:', $val);
270            1                                  4               $val = undef;
271                                                            }
272                                                         }
273                                                         elsif ( $cmd eq 'incr' || $cmd eq 'decr' ) {
274            4                                 17            ($key) = @vals;
275                                                         }
276                                                         else {
277   ***      0                                  0            MKDEBUG && _d("Don't know how to handle", $cmd, "command");
278                                                         }
279           19                                 94         @{$session}{qw(cmd key flags exptime)}
              19                                126   
280                                                            = ($cmd, $key, $flags, $exptime);
281           19                                101         $session->{host}       = $packet->{src_host};
282           19                                 89         $session->{pos_in_log} = $packet->{pos_in_log};
283           19                                115         $session->{ts}         = $packet->{ts};
284                                                      }
285                                                      else {
286            1                                  2         MKDEBUG && _d('Session state: ', $session->{state});
287            1                                  5         $val = $packet->{data};
288                                                      }
289                                                   
290                                                      # Handle the rest of the packet.  It might not be the whole value that was
291                                                      # sent, for example for a big set().  We need to look at the number of bytes
292                                                      # and see if we got it all.
293           20                                 71      $session->{state} = 'awaiting reply'; # Assume we got the whole packet
294           20    100                          76      if ( $val ) {
295            5    100                          33         if ( $session->{bytes} + 2 == length($val) ) { # +2 for the \r\n
296            3                                  8            MKDEBUG && _d('Got the whole thing');
297            3                                 16            $val =~ s/\r\n\Z//; # We got the whole thing.
298            3                                 12            $session->{val} = $val;
299                                                         }
300                                                         else { # We apparently did NOT get the whole thing.
301            2                                  6            MKDEBUG && _d('Partial send, saving for later');
302            2                                  6            push @{$session->{partial}},
               2                                 17   
303                                                               [ $packet->{seq}, $val ];
304            2                                  7            $session->{gathered} += length($val);
305                                                            MKDEBUG && _d('Gathered', $session->{gathered}, 'bytes in',
306            2                                  6               scalar(@{$session->{partial}}), 'packets from client');
307            2    100                          14            if ( $session->{gathered} >= $session->{bytes} + 2 ) { # Done.
308            1                                  3               MKDEBUG && _d('Message looks complete now, saving value');
309            2                                 39               $val = join('',
310            1                                  7                  map  { $_->[1] }
311                                                                  # Sort in proper sequence because TCP might reorder them.
312            1                                  2                  sort { $a->[0] <=> $b->[0] }
313            1                                  4                       @{$session->{partial}});
314            1                                 17               $val =~ s/\r\n\Z//;
315            1                                 13               $session->{val} = $val;
316                                                            }
317                                                            else {
318            1                                  2               MKDEBUG && _d('Message not complete');
319            1                                  5               $val = '[INCOMPLETE]';
320            1                                  4               $session->{state} = 'partial send';
321                                                            }
322                                                         }
323                                                      }
324                                                   
325           20                                 83      return $event;
326                                                   }
327                                                   
328                                                   # The event is not yet suitable for mk-query-digest.  It lacks, for example,
329                                                   # an arg and fingerprint attribute.  The event should be passed to
330                                                   # MemcachedEvent::make_event() to transform it.
331                                                   sub make_event {
332   ***     19                   19      0     82      my ( $session, $packet ) = @_;
333           19           100                  529      my $event = {
                           100                        
                           100                        
                           100                        
334                                                         cmd        => $session->{cmd},
335                                                         key        => $session->{key},
336                                                         val        => $session->{val} || '',
337                                                         res        => $session->{res},
338                                                         ts         => $session->{ts},
339                                                         host       => $session->{host},
340                                                         flags      => $session->{flags}   || 0,
341                                                         exptime    => $session->{exptime} || 0,
342                                                         bytes      => $session->{bytes}   || 0,
343                                                         Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
344                                                         pos_in_log => $session->{pos_in_log},
345                                                      };
346           19                                 85      return $event;
347                                                   }
348                                                   
349                                                   sub _get_errors_fh {
350   ***      0                    0             0      my ( $self ) = @_;
351   ***      0                                  0      my $errors_fh = $self->{errors_fh};
352   ***      0      0                           0      return $errors_fh if $errors_fh;
353                                                   
354                                                      # Errors file isn't open yet; try to open it.
355   ***      0                                  0      my $o = $self->{o};
356   ***      0      0      0                    0      if ( $o && $o->has('tcpdump-errors') && $o->got('tcpdump-errors') ) {
      ***                    0                        
357   ***      0                                  0         my $errors_file = $o->get('tcpdump-errors');
358   ***      0                                  0         MKDEBUG && _d('tcpdump-errors file:', $errors_file);
359   ***      0      0                           0         open $errors_fh, '>>', $errors_file
360                                                            or die "Cannot open tcpdump-errors file $errors_file: $OS_ERROR";
361                                                      }
362                                                   
363   ***      0                                  0      $self->{errors_fh} = $errors_fh;
364   ***      0                                  0      return $errors_fh;
365                                                   }
366                                                   
367                                                   sub fail_session {
368   ***      0                    0      0      0      my ( $self, $session, $reason ) = @_;
369   ***      0                                  0      my $errors_fh = $self->_get_errors_fh();
370   ***      0      0                           0      if ( $errors_fh ) {
371   ***      0                                  0         $session->{reason_for_failure} = $reason;
372   ***      0                                  0         my $session_dump = '# ' . Dumper($session);
373   ***      0                                  0         chomp $session_dump;
374   ***      0                                  0         $session_dump =~ s/\n/\n# /g;
375   ***      0                                  0         print $errors_fh "$session_dump\n";
376                                                         {
377   ***      0                                  0            local $LIST_SEPARATOR = "\n";
      ***      0                                  0   
378   ***      0                                  0            print $errors_fh "@{$session->{raw_packets}}";
      ***      0                                  0   
379   ***      0                                  0            print $errors_fh "\n";
380                                                         }
381                                                      }
382   ***      0                                  0      MKDEBUG && _d('Failed session', $session->{client}, 'because', $reason);
383   ***      0                                  0      delete $self->{sessions}->{$session->{client}};
384   ***      0                                  0      return;
385                                                   }
386                                                   
387                                                   sub _d {
388   ***      0                    0             0      my ($package, undef, $line) = caller 0;
389   ***      0      0                           0      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                  0   
      ***      0                                  0   
390   ***      0                                  0           map { defined $_ ? $_ : 'undef' }
391                                                           @_;
392   ***      0                                  0      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
393                                                   }
394                                                   
395                                                   # Returns the difference between two tcpdump timestamps.  TODO: this is in
396                                                   # MySQLProtocolParser too, best to factor it out somewhere common.
397                                                   sub timestamp_diff {
398   ***     19                   19      0     85      my ( $start, $end ) = @_;
399           19                                 94      my $sd = substr($start, 0, 11, '');
400           19                                 79      my $ed = substr($end,   0, 11, '');
401           19                                136      my ( $sh, $sm, $ss ) = split(/:/, $start);
402           19                                100      my ( $eh, $em, $es ) = split(/:/, $end);
403           19                                162      my $esecs = ($eh * 3600 + $em * 60 + $es);
404           19                                 81      my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
405   ***     19     50                          80      if ( $sd eq $ed ) {
406           19                                520         return sprintf '%.6f', $esecs - $ssecs;
407                                                      }
408                                                      else { # Assume only one day boundary has been crossed, no DST, etc
409   ***      0                                            return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
410                                                      }
411                                                   }
412                                                   
413                                                   1;
414                                                   
415                                                   # ###########################################################################
416                                                   # End MemcachedProtocolParser package
417                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
51    ***     50      0     64   unless $args{$arg}
58    ***     50      0     64   if (my $server = $$self{'server'})
60    ***      0      0      0   if ($src_host ne $server and $dst_host ne $server)
69           100     31     33   if ($src_host =~ /:$$self{'port'}$/) { }
      ***     50     33      0   elsif ($dst_host =~ /:$$self{'port'}$/) { }
85           100     22     42   if (not exists $$self{'sessions'}{$client})
99           100     20     44   if ($$packet{'data_len'} == 0)
110          100     24     20   if ($packet_from eq 'server') { }
      ***     50     20      0   elsif ($packet_from eq 'client') { }
129   ***     50      0     24   unless $packet
130   ***     50      0     24   unless $session
138          100      3     21   if (not $$session{'state'})
145          100     19      2   if ($$session{'state'} eq 'awaiting reply') { }
155          100      4     15   if ($$session{'cmd'} eq 'incr' or $$session{'cmd'} eq 'decr') { }
             100      6      9   elsif ($$session{'res'} eq 'VALUE') { }
             100      2      7   elsif ($$session{'res'} eq 'END') { }
      ***     50      0      7   elsif (not $$session{'res'} =~ /STORED|DELETED|NOT_FOUND/) { }
157          100      2      2   if (not $$session{'res'} =~ /\D/)
166   ***     50      6      0   unless defined $$session{'flags'}
167   ***     50      6      0   unless defined $$session{'bytes'}
169   ***     50      6      0   if ($rest and $bytes)
171          100      4      2   if (length $rest > $bytes) { }
202          100      1      1   if ($$session{'gathered'} >= $$session{'bytes'} + 2) { }
227   ***     50      0     20   unless $packet
228   ***     50      0     20   unless $session
233          100      1     19   if (($$session{'state'} || '') =~ /awaiting reply|partial recv/)
247          100     19      1   if (not $$session{'state'}) { }
255          100      4     15   if ($cmd eq 'set' or $cmd eq 'add' or $cmd eq 'replace') { }
             100      8      7   elsif ($cmd eq 'get') { }
             100      3      4   elsif ($cmd eq 'delete') { }
      ***     50      4      0   elsif ($cmd eq 'incr' or $cmd eq 'decr') { }
261          100      1      7   if ($val)
268          100      1      2   if ($val)
294          100      5     15   if ($val)
295          100      3      2   if ($$session{'bytes'} + 2 == length $val) { }
307          100      1      1   if ($$session{'gathered'} >= $$session{'bytes'} + 2) { }
352   ***      0      0      0   if $errors_fh
356   ***      0      0      0   if ($o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors'))
359   ***      0      0      0   unless open $errors_fh, '>>', $errors_file
370   ***      0      0      0   if ($errors_fh)
389   ***      0      0      0   defined $_ ? :
405   ***     50     19      0   if ($sd eq $ed) { }


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
60    ***      0      0      0      0   $src_host ne $server and $dst_host ne $server
169   ***     33      0      0      6   $rest and $bytes
356   ***      0      0      0      0   $o and $o->has('tcpdump-errors')
      ***      0      0      0      0   $o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors')

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
36    ***     50      0     14   $args{'port'} || '11211'
233          100      2     18   $$session{'state'} || ''
333          100     11      8   $$session{'val'} || ''
             100      2     17   $$session{'flags'} || 0
             100      1     18   $$session{'exptime'} || 0
             100     10      9   $$session{'bytes'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
155          100      2      2     15   $$session{'cmd'} eq 'incr' or $$session{'cmd'} eq 'decr'
255   ***     66      3      0     16   $cmd eq 'set' or $cmd eq 'add'
             100      3      1     15   $cmd eq 'set' or $cmd eq 'add' or $cmd eq 'replace'
      ***     66      2      2      0   $cmd eq 'incr' or $cmd eq 'decr'


Covered Subroutines
-------------------

Subroutine          Count Pod Location                                                      
------------------- ----- --- --------------------------------------------------------------
BEGIN                   1     /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:22 
BEGIN                   1     /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:23 
BEGIN                   1     /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:24 
BEGIN                   1     /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:26 
BEGIN                   1     /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:31 
_packet_from_client    20     /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:226
_packet_from_server    24     /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:128
make_event             19   0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:332
new                    14   0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:34 
parse_event            64   0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:48 
timestamp_diff         19   0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:398

Uncovered Subroutines
---------------------

Subroutine          Count Pod Location                                                      
------------------- ----- --- --------------------------------------------------------------
_d                      0     /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:388
_get_errors_fh          0     /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:350
fail_session            0   0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:368


MemcachedProtocolParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            37      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            13   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            14   use English qw(-no_match_vars);
               1                                  3   
               1                                  9   
12             1                    1            12   use Test::More tests => 28;
               1                                  4   
               1                                 11   
13                                                    
14             1                    1            13   use MemcachedProtocolParser;
               1                                  3   
               1                                 17   
15             1                    1            19   use TcpdumpParser;
               1                                  2   
               1                                 14   
16             1                    1            14   use MaatkitTest;
               1                                  5   
               1                                 38   
17                                                    
18             1                                 13   my $tcpdump  = new TcpdumpParser();
19             1                                 31   my $protocol; # Create a new MemcachedProtocolParser for each test.
20                                                    
21                                                    # A session with a simple set().
22             1                                 10   $protocol = new MemcachedProtocolParser();
23             1                                 55   test_protocol_parser(
24                                                       parser   => $tcpdump,
25                                                       protocol => $protocol,
26                                                       file     => 'common/t/samples/memc_tcpdump001.txt',
27                                                       result   => [
28                                                          {  ts            => '2009-07-04 21:33:39.229179',
29                                                             host          => '127.0.0.1',
30                                                             cmd           => 'set',
31                                                             key           => 'my_key',
32                                                             val           => 'Some value',
33                                                             flags         => '0',
34                                                             exptime       => '0',
35                                                             bytes         => '10',
36                                                             res           => 'STORED',
37                                                             Query_time    => sprintf('%.6f', .229299 - .229179),
38                                                             pos_in_log    => 0,
39                                                          },
40                                                       ],
41                                                    );
42                                                    
43                                                    # A session with a simple get().
44             1                                 45   $protocol = new MemcachedProtocolParser();
45             1                                 24   test_protocol_parser(
46                                                       parser   => $tcpdump,
47                                                       protocol => $protocol,
48                                                       file     => 'common/t/samples/memc_tcpdump002.txt',
49                                                       result   => [
50                                                          {  Query_time => '0.000067',
51                                                             cmd        => 'get',
52                                                             key        => 'my_key',
53                                                             val        => 'Some value',
54                                                             bytes      => 10,
55                                                             exptime    => 0,
56                                                             flags      => 0,
57                                                             host       => '127.0.0.1',
58                                                             pos_in_log => '0',
59                                                             res        => 'VALUE',
60                                                             ts         => '2009-07-04 22:12:06.174390'
61                                                          },
62                                                       ],
63                                                    );
64                                                    
65                                                    # A session with a simple incr() and decr().
66             1                                 48   $protocol = new MemcachedProtocolParser();
67             1                                 31   test_protocol_parser(
68                                                       parser   => $tcpdump,
69                                                       protocol => $protocol,
70                                                       file     => 'common/t/samples/memc_tcpdump003.txt',
71                                                       result   => [
72                                                          {  Query_time => '0.000073',
73                                                             cmd        => 'incr',
74                                                             key        => 'key',
75                                                             val        => '8',
76                                                             bytes      => 0,
77                                                             exptime    => 0,
78                                                             flags      => 0,
79                                                             host       => '127.0.0.1',
80                                                             pos_in_log => '0',
81                                                             res        => '',
82                                                             ts         => '2009-07-04 22:12:06.175734',
83                                                          },
84                                                          {  Query_time => '0.000068',
85                                                             cmd        => 'decr',
86                                                             bytes      => 0,
87                                                             exptime    => 0,
88                                                             flags      => 0,
89                                                             host       => '127.0.0.1',
90                                                             key        => 'key',
91                                                             pos_in_log => 522,
92                                                             res        => '',
93                                                             ts         => '2009-07-04 22:12:06.176181',
94                                                             val => '7',
95                                                          },
96                                                       ],
97                                                    );
98                                                    
99                                                    # A session with a simple incr() and decr(), but the value doesn't exist.
100            1                                 44   $protocol = new MemcachedProtocolParser();
101            1                                 26   test_protocol_parser(
102                                                      parser   => $tcpdump,
103                                                      protocol => $protocol,
104                                                      file     => 'common/t/samples/memc_tcpdump004.txt',
105                                                      result   => [
106                                                         {  Query_time => '0.000131',
107                                                            bytes      => 0,
108                                                            cmd        => 'incr',
109                                                            exptime    => 0,
110                                                            flags      => 0,
111                                                            host       => '127.0.0.1',
112                                                            key        => 'key',
113                                                            pos_in_log => 764,
114                                                            res        => 'NOT_FOUND',
115                                                            ts         => '2009-07-06 10:37:21.668469',
116                                                            val        => '',
117                                                         },
118                                                         {
119                                                            Query_time => '0.000055',
120                                                            bytes      => 0,
121                                                            cmd        => 'decr',
122                                                            exptime    => 0,
123                                                            flags      => 0,
124                                                            host       => '127.0.0.1',
125                                                            key        => 'key',
126                                                            pos_in_log => 1788,
127                                                            res        => 'NOT_FOUND',
128                                                            ts         => '2009-07-06 10:37:21.668851',
129                                                            val        => '',
130                                                         },
131                                                      ],
132                                                   );
133                                                   
134                                                   # A session with a huge set() that will not fit into a single TCP packet.
135            1                                 90   $protocol = new MemcachedProtocolParser();
136            1                                110   test_protocol_parser(
137                                                      parser   => $tcpdump,
138                                                      protocol => $protocol,
139                                                      file     => 'common/t/samples/memc_tcpdump005.txt',
140                                                      result   => [
141                                                         {  Query_time => '0.003928',
142                                                            bytes      => 17946,
143                                                            cmd        => 'set',
144                                                            exptime    => 0,
145                                                            flags      => 0,
146                                                            host       => '127.0.0.1',
147                                                            key        => 'my_key',
148                                                            pos_in_log => 764,
149                                                            res        => 'STORED',
150                                                            ts         => '2009-07-06 22:07:14.406827',
151                                                            val        => ('lorem ipsum dolor sit amet' x 690) . ' fini!',
152                                                         },
153                                                      ],
154                                                   );
155                                                   
156                                                   # A session with a huge get() that will not fit into a single TCP packet.
157            1                                 38   $protocol = new MemcachedProtocolParser();
158            1                                 50   test_protocol_parser(
159                                                      parser   => $tcpdump,
160                                                      protocol => $protocol,
161                                                      file     => 'common/t/samples/memc_tcpdump006.txt',
162                                                      result   => [
163                                                         {
164                                                            Query_time => '0.000196',
165                                                            bytes      => 17946,
166                                                            cmd        => 'get',
167                                                            exptime    => 0,
168                                                            flags      => 0,
169                                                            host       => '127.0.0.1',
170                                                            key        => 'my_key',
171                                                            pos_in_log => 0,
172                                                            res        => 'VALUE',
173                                                            ts         => '2009-07-06 22:07:14.411331',
174                                                            val        => ('lorem ipsum dolor sit amet' x 690) . ' fini!',
175                                                         },
176                                                      ],
177                                                   );
178                                                   
179                                                   # A session with a get() that doesn't exist.
180            1                                 72   $protocol = new MemcachedProtocolParser();
181            1                                 22   test_protocol_parser(
182                                                      parser   => $tcpdump,
183                                                      protocol => $protocol,
184                                                      file     => 'common/t/samples/memc_tcpdump007.txt',
185                                                      result   => [
186                                                         {
187                                                            Query_time => '0.000016',
188                                                            bytes      => 0,
189                                                            cmd        => 'get',
190                                                            exptime    => 0,
191                                                            flags      => 0,
192                                                            host       => '127.0.0.1',
193                                                            key        => 'comment_v3_482685',
194                                                            pos_in_log => 0,
195                                                            res        => 'NOT_FOUND',
196                                                            ts         => '2009-06-11 21:54:49.059144',
197                                                            val        => '',
198                                                         },
199                                                      ],
200                                                   );
201                                                   
202                                                   # A session with a huge get() that will not fit into a single TCP packet, but
203                                                   # the connection seems to be broken in the middle of the receive and then the
204                                                   # new client picks up and asks for something different.
205            1                                 47   $protocol = new MemcachedProtocolParser();
206            1                                 25   test_protocol_parser(
207                                                      parser   => $tcpdump,
208                                                      protocol => $protocol,
209                                                      file     => 'common/t/samples/memc_tcpdump008.txt',
210                                                      result   => [
211                                                         {
212                                                            Query_time => '0.000003',
213                                                            bytes      => 17946,
214                                                            cmd        => 'get',
215                                                            exptime    => 0,
216                                                            flags      => 0,
217                                                            host       => '127.0.0.1',
218                                                            key        => 'my_key',
219                                                            pos_in_log => 0,
220                                                            res        => 'INTERRUPTED',
221                                                            ts         => '2009-07-06 22:07:14.411331',
222                                                            val        => '',
223                                                         },
224                                                         {  Query_time => '0.000001',
225                                                            cmd        => 'get',
226                                                            key        => 'my_key',
227                                                            val        => 'Some value',
228                                                            bytes      => 10,
229                                                            exptime    => 0,
230                                                            flags      => 0,
231                                                            host       => '127.0.0.1',
232                                                            pos_in_log => 5382,
233                                                            res        => 'VALUE',
234                                                            ts         => '2009-07-06 22:07:14.411334',
235                                                         },
236                                                      ],
237                                                   );
238                                                   
239                                                   # A session with a delete() that doesn't exist. TODO: delete takes a queue_time.
240            1                                 65   $protocol = new MemcachedProtocolParser();
241            1                                 19   test_protocol_parser(
242                                                      parser   => $tcpdump,
243                                                      protocol => $protocol,
244                                                      file     => 'common/t/samples/memc_tcpdump009.txt',
245                                                      result   => [
246                                                         {
247                                                            Query_time => '0.000022',
248                                                            bytes      => 0,
249                                                            cmd        => 'delete',
250                                                            exptime    => 0,
251                                                            flags      => 0,
252                                                            host       => '127.0.0.1',
253                                                            key        => 'comment_1873527',
254                                                            pos_in_log => 0,
255                                                            res        => 'NOT_FOUND',
256                                                            ts         => '2009-06-11 21:54:52.244534',
257                                                            val        => '',
258                                                         },
259                                                      ],
260                                                   );
261                                                   
262                                                   # A session with a delete() that does exist.
263            1                                 45   $protocol = new MemcachedProtocolParser();
264            1                                 19   test_protocol_parser(
265                                                      parser   => $tcpdump,
266                                                      protocol => $protocol,
267                                                      file     => 'common/t/samples/memc_tcpdump010.txt',
268                                                      result   => [
269                                                         {
270                                                            Query_time => '0.000120',
271                                                            bytes      => 0,
272                                                            cmd        => 'delete',
273                                                            exptime    => 0,
274                                                            flags      => 0,
275                                                            host       => '127.0.0.1',
276                                                            key        => 'my_key',
277                                                            pos_in_log => 0,
278                                                            res        => 'DELETED',
279                                                            ts         => '2009-07-09 22:00:29.066476',
280                                                            val        => '',
281                                                         },
282                                                      ],
283                                                   );
284                                                   
285                                                   # #############################################################################
286                                                   # Issue 537: MySQLProtocolParser and MemcachedProtocolParser do not handle
287                                                   # multiple servers.
288                                                   # #############################################################################
289            1                                 47   $protocol = new MemcachedProtocolParser();
290            1                                 42   test_protocol_parser(
291                                                      parser   => $tcpdump,
292                                                      protocol => $protocol,
293                                                      file     => 'common/t/samples/memc_tcpdump011.txt',
294                                                      result   => [
295                                                         {  Query_time => '0.000067',
296                                                            cmd        => 'get',
297                                                            key        => 'my_key',
298                                                            val        => 'Some value',
299                                                            bytes      => 10,
300                                                            exptime    => 0,
301                                                            flags      => 0,
302                                                            host       => '127.0.0.8',
303                                                            pos_in_log => '0',
304                                                            res        => 'VALUE',
305                                                            ts         => '2009-07-04 22:12:06.174390'
306                                                         },
307                                                         {  ts            => '2009-07-04 21:33:39.229179',
308                                                            host          => '127.0.0.9',
309                                                            cmd           => 'set',
310                                                            key           => 'my_key',
311                                                            val           => 'Some value',
312                                                            flags         => '0',
313                                                            exptime       => '0',
314                                                            bytes         => '10',
315                                                            res           => 'STORED',
316                                                            Query_time    => sprintf('%.6f', .229299 - .229179),
317                                                            pos_in_log    => 638,
318                                                         },
319                                                      ],
320                                                   );
321                                                   
322                                                   # #############################################################################
323                                                   # Issue 544: memcached parse error
324                                                   # #############################################################################
325                                                   
326                                                   # Multiple delete in one packet.
327            1                                 56   $protocol = new MemcachedProtocolParser();
328            1                                 21   test_protocol_parser(
329                                                      parser   => $tcpdump,
330                                                      protocol => $protocol,
331                                                      file     => 'common/t/samples/memc_tcpdump014.txt',
332                                                      result   => [
333                                                         {  ts          => '2009-10-06 10:31:56.323538',
334                                                            Query_time  => '0.000024',
335                                                            bytes       => 0,
336                                                            cmd         => 'delete',
337                                                            exptime     => 0,
338                                                            flags       => 0,
339                                                            host        => '10.0.0.5',
340                                                            key         => 'ABBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBC',
341                                                            pos_in_log  => 0,
342                                                            res         => 'NOT_FOUND',
343                                                            val         => ''
344                                                         },
345                                                      ],
346                                                   );
347                                                   
348                                                   # Multiple mixed commands: get delete delete
349            1                                 38   $protocol = new MemcachedProtocolParser();
350            1                                 21   test_protocol_parser(
351                                                      parser   => $tcpdump,
352                                                      protocol => $protocol,
353                                                      file     => 'common/t/samples/memc_tcpdump015.txt',
354                                                      result   => [
355                                                         {  ts          => '2009-10-06 10:31:56.330709',
356                                                            Query_time  => '0.000013',
357                                                            bytes       => 0,
358                                                            cmd         => 'get',
359                                                            exptime     => 0,
360                                                            flags       => 0,
361                                                            host        => '10.0.0.5',
362                                                            key         => 'ABBBBBBBBBBBBBBBBBBBBBC',
363                                                            pos_in_log  => 0,
364                                                            res         => 'NOT_FOUND',
365                                                            
366                                                            val => ''
367                                                         },
368                                                      ],
369                                                   );
370                                                   
371                                                   
372                                                   # #############################################################################
373                                                   # Issue 818: mk-query-digest: error parsing memcached dump - use of
374                                                   # uninitialized value in addition
375                                                   # #############################################################################
376                                                   
377                                                   # A replace command.
378            1                                 30   $protocol = new MemcachedProtocolParser();
379            1                                 25   test_protocol_parser(
380                                                      parser   => $tcpdump,
381                                                      protocol => $protocol,
382                                                      file     => 'common/t/samples/memc_tcpdump016.txt',
383                                                      result   => [
384                                                         {  ts         => '2010-01-20 10:27:18.510727',
385                                                            Query_time => '0.000030',
386                                                            bytes      => 56,
387                                                            cmd        => 'replace',
388                                                            exptime    => '43200',
389                                                            flags      => '1',
390                                                            host       => '192.168.0.3',
391                                                            key        => 'BD_Uk_cms__20100120_095702tab_containerId_410',
392                                                            pos_in_log => 0,
393                                                            res        => 'STORED',
394                                                            val        => 'a:3:{i:0;s:6:"a:0:{}";i:1;i:1263983238;i:2;s:5:"43200";}'
395                                                         },
396                                                         {  ts         => '2010-01-20 10:27:18.510876',
397                                                            Query_time => '0.000066',
398                                                            bytes      => '56',
399                                                            cmd        => 'get',
400                                                            exptime    => 0,
401                                                            flags      => '1',
402                                                            host       => '192.168.0.3',
403                                                            key        => 'BD_Uk_cms__20100120_095702tab_containerId_410',
404                                                            pos_in_log => 893,
405                                                            res        => 'VALUE',
406                                                            val        => 'a:3:{i:0;s:6:"a:0:{}";i:1;i:1263983238;i:2;s:5:"43200";}'
407                                                         }
408                                                      ],
409                                                   );
410                                                   
411                                                   # #############################################################################
412                                                   # Done.
413                                                   # #############################################################################
414            1                                  4   exit;


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
---------- ----- ----------------------------
BEGIN          1 MemcachedProtocolParser.t:10
BEGIN          1 MemcachedProtocolParser.t:11
BEGIN          1 MemcachedProtocolParser.t:12
BEGIN          1 MemcachedProtocolParser.t:14
BEGIN          1 MemcachedProtocolParser.t:15
BEGIN          1 MemcachedProtocolParser.t:16
BEGIN          1 MemcachedProtocolParser.t:4 
BEGIN          1 MemcachedProtocolParser.t:9 


