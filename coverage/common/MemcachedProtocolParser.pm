---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...emcachedProtocolParser.pm   80.6   68.4   59.3   73.3    n/a  100.0   75.5
Total                          80.6   68.4   59.3   73.3    n/a  100.0   75.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MemcachedProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sun Jul 12 15:07:11 2009
Finish:       Sun Jul 12 15:07:12 2009

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
18                                                    # MemcachedProtocolParser package $Revision: 4146 $
19                                                    # ###########################################################################
20                                                    package MemcachedProtocolParser;
21                                                    
22             1                    1            14   use strict;
               1                                  3   
               1                                  9   
23             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                 10   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
25                                                    
26             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  8   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  7   
               1                                 11   
32                                                    
33                                                    # server is the "host:port" of the sever being watched.  It's auto-guessed if
34                                                    # not specified.
35                                                    sub new {
36            10                   10           372      my ( $class, %args ) = @_;
37            10                                 75      my $self = {
38                                                          server      => $args{server},
39                                                          sessions    => {},
40                                                          o           => $args{o},
41                                                       };
42            10                                 68      return bless $self, $class;
43                                                    }
44                                                    
45                                                    # The packet arg should be a hashref from TcpdumpParser::parse_event().
46                                                    # misc is a placeholder for future features.
47                                                    sub parse_packet {
48            49                   49           650      my ( $self, $packet, $misc ) = @_;
49                                                    
50                                                       # Auto-detect the server by looking for port 11211
51            49                                247      my $from  = "$packet->{src_host}:$packet->{src_port}";
52            49                                222      my $to    = "$packet->{dst_host}:$packet->{dst_port}";
53    ***     49     50    100                  252      $self->{server} ||= $from =~ m/:(?:11211)$/ ? $from
      ***            50                               
54                                                                         : $to   =~ m/:(?:11211)$/ ? $to
55                                                                         :                           undef;
56            49    100                         224      my $client = $from eq $self->{server} ? $to : $from;
57            49                                106      MKDEBUG && _d('Client:', $client);
58                                                    
59                                                       # Get the client's session info or create a new session if the
60                                                       # client hasn't been seen before.
61            49    100                         249      if ( !exists $self->{sessions}->{$client} ) {
62            14                                 32         MKDEBUG && _d('New session');
63            14                                115         $self->{sessions}->{$client} = {
64                                                             client      => $client,
65                                                             state       => undef,
66                                                             raw_packets => [],
67                                                             # ts -- wait for ts later.
68                                                          };
69                                                       };
70            49                                184      my $session = $self->{sessions}->{$client};
71                                                    
72                                                       # Return early if there's no TCP data.  These are usually ACK packets, but
73                                                       # they could also be FINs in which case, we should close and delete the
74                                                       # client's session.
75            49    100                         221      if ( $packet->{data_len} == 0 ) {
76            20                                 43         MKDEBUG && _d('No TCP data');
77            20                                133         return;
78                                                       }
79                                                    
80                                                       # Save raw packets to dump later in case something fails.
81            29                                 71      push @{$session->{raw_packets}}, $packet->{raw_packet};
              29                                231   
82                                                    
83                                                       # Finally, parse the packet and maybe create an event.
84            29                                748      $packet->{data} = pack('H*', $packet->{data});
85            29                                 64      my $event;
86            29    100                         141      if ( $from eq $self->{server} ) {
      ***            50                               
87            15                                 70         $event = $self->_packet_from_server($packet, $session, $misc);
88                                                       }
89                                                       elsif ( $from eq $client ) {
90            14                                 78         $event = $self->_packet_from_client($packet, $session, $misc);
91                                                       }
92                                                       else {
93    ***      0                                  0         MKDEBUG && _d('Packet origin unknown');
94                                                       }
95                                                    
96            29                                 70      MKDEBUG && _d('Done with packet; event:', Dumper($event));
97            29                                247      return $event;
98                                                    }
99                                                    
100                                                   # Handles a packet from the server given the state of the session.  Returns an
101                                                   # event if one was ready to be created, otherwise returns nothing.
102                                                   sub _packet_from_server {
103           15                   15            62      my ( $self, $packet, $session, $misc ) = @_;
104   ***     15     50                          62      die "I need a packet"  unless $packet;
105   ***     15     50                          52      die "I need a session" unless $session;
106                                                   
107           15                                 36      MKDEBUG && _d('Packet is from server; client state:', $session->{state}); 
108                                                   
109           15                                 60      my $data = $packet->{data};
110                                                   
111                                                      # If there's no session state, then we're catching a server response
112                                                      # mid-stream.
113   ***     15     50                          67      if ( !$session->{state} ) {
114   ***      0                                  0         MKDEBUG && _d('Ignoring mid-stream server response');
115   ***      0                                  0         return;
116                                                      }
117                                                   
118                                                      # Assume that the server is returning only one value.  TODO: make it
119                                                      # handle multi-gets.
120           15    100                          65      if ( $session->{state} eq 'awaiting reply' ) {
121           13                                 28         MKDEBUG && _d('State is awaiting reply');
122           13                                115         my ($line1, $rest) = $packet->{data} =~ m/\A(.*?)\r\n(.*)?/s;
123                                                   
124                                                         # Split up the first line into its parts.
125           13                                 77         my @vals = $line1 =~ m/(\S+)/g;
126           13                                 53         $session->{res} = shift @vals;
127           13    100    100                  189         if ( $session->{cmd} eq 'incr' || $session->{cmd} eq 'decr' ) {
                    100                               
                    100                               
      ***            50                               
128            4                                 10            MKDEBUG && _d('It is an incr or decr');
129            4    100                          23            if ( $session->{res} !~ m/\D/ ) { # It's an integer, not an error
130            2                                  5               MKDEBUG && _d('Got a value for the incr/decr');
131            2                                 17               $session->{val} = $session->{res};
132            2                                  7               $session->{res} = '';
133                                                            }
134                                                         }
135                                                         elsif ( $session->{res} eq 'VALUE' ) {
136            4                                  9            MKDEBUG && _d('It is the result of a "get"');
137            4                                 17            my ($key, $flags, $bytes) = @vals;
138   ***      4     50                          22            defined $session->{flags} or $session->{flags} = $flags;
139   ***      4     50                          22            defined $session->{bytes} or $session->{bytes} = $bytes;
140                                                            # Get the value from the $rest. TODO: there might be multiple responses
141   ***      4     50     33                   37            if ( $rest && $bytes ) {
142            4                                  9               MKDEBUG && _d('There is a value');
143            4    100                          26               if ( length($rest) > $bytes ) {
144            2                                  4                  MKDEBUG && _d('Looks like we got the whole response');
145            2                                 12                  $session->{val} = substr($rest, 0, $bytes); # Got the whole response.
146                                                               }
147                                                               else {
148            2                                  6                  MKDEBUG && _d('Got partial response, saving for later');
149            2                                  5                  push @{$session->{partial}}, [ $packet->{seq}, $rest ];
               2                                 15   
150            2                                  8                  $session->{gathered} += length($rest);
151            2                                  8                  $session->{state} = 'partial recv';
152            2                                  8                  return; # Prevent firing an event.
153                                                               }
154                                                            }
155                                                         }
156                                                         elsif ( $session->{res} eq 'END' ) {
157                                                            # Technically NOT_FOUND is an error, and this isn't an error it's just
158                                                            # a NULL, but what it really means is the value isn't found.
159            1                                  3            MKDEBUG && _d('Got an END without any data, firing NOT_FOUND');
160            1                                 17            $session->{res} = 'NOT_FOUND';
161                                                         }
162                                                         elsif ( $session->{res} !~ m/STORED|DELETED|NOT_FOUND/ ) {
163                                                            # Not really sure what else would get us here... want to make a note
164                                                            # and not have an uncaught condition.
165   ***      0                                  0            MKDEBUG && _d("Session result:", $session->{res});
166                                                         }
167                                                      }
168                                                      else { # Should be 'partial recv'
169            2                                  6         MKDEBUG && _d('Session state: ', $session->{state});
170            2                                  5         push @{$session->{partial}}, [ $packet->{seq}, $data ];
               2                                 19   
171            2                                  9         $session->{gathered} += length($data);
172                                                         MKDEBUG && _d('Gathered', $session->{gathered}, 'bytes in',
173            2                                  5            scalar(@{$session->{partial}}), 'packets from server');
174            2    100                          15         if ( $session->{gathered} >= $session->{bytes} + 2 ) { # Done.
175            1                                  3            MKDEBUG && _d('End of partial response, preparing event');
176            3                                 36            my $val = join('',
177            3                                 14               map  { $_->[1] }
178                                                               # Sort in proper sequence because TCP might reorder them.
179            1                                  2               sort { $a->[0] <=> $b->[0] }
180            1                                  4                    @{$session->{partial}});
181            1                                 14            $session->{val} = substr($val, 0, $session->{bytes});
182                                                         }
183                                                         else {
184            1                                  3            MKDEBUG && _d('Partial response continues, no action');
185            1                                  6            return; # Prevent firing event.
186                                                         }
187                                                      }
188                                                   
189           12                                 55      my $event = make_event($session, $packet);
190           12                                 29      MKDEBUG && _d('Creating event, deleting session');
191           12                                 57      delete $self->{sessions}->{$session->{client}}; # memcached is stateless!
192           12                                 44      $session->{raw_packets} = []; # Avoid keeping forever
193           12                                 62      return $event;
194                                                   }
195                                                   
196                                                   # Handles a packet from the client given the state of the session.
197                                                   sub _packet_from_client {
198           14                   14            59      my ( $self, $packet, $session, $misc ) = @_;
199   ***     14     50                          57      die "I need a packet"  unless $packet;
200   ***     14     50                          48      die "I need a session" unless $session;
201                                                   
202           14                                 30      MKDEBUG && _d('Packet is from client; state:', $session->{state});
203                                                   
204           14                                 38      my $event;
205           14    100    100                  145      if ( ($session->{state} || '') =~m/awaiting reply|partial recv/ ) {
206                                                         # Whoa, we expected something from the server, not the client.  Fire an
207                                                         # INTERRUPTED with what we've got, and create a new session.
208            1                                  3         MKDEBUG && _d("Expected data from the client, looks like interrupted");
209            1                                  4         $session->{res} = 'INTERRUPTED';
210            1                                  4         $event = make_event($session, $packet);
211            1                                  4         my $client = $session->{client};
212            1                                  8         delete @{$session}{keys %$session};
               1                                  8   
213            1                                  6         $session->{client} = $client;
214                                                      }
215                                                   
216           14                                 40      my ($line1, $val);
217           14                                 42      my ($cmd, $key, $flags, $exptime, $bytes);
218                                                      
219           14    100                          63      if ( !$session->{state} ) {
220           13                                 26         MKDEBUG && _d('Session state: ', $session->{state});
221                                                         # Split up the first line into its parts.
222           13                                183         ($line1, $val) = $packet->{data} =~ m/\A(.*?)\r\n(.+)?/s;
223                                                         # TODO: handle <cas unique> and [noreply]
224           13                                103         my @vals = $line1 =~ m/(\S+)/g;
225           13                                 53         $cmd = lc shift @vals;
226           13                                 30         MKDEBUG && _d('$cmd is a ', $cmd);
227   ***     13    100     66                  108         if ( $cmd eq 'set' ) {
                    100                               
                    100                               
      ***            50                               
228            2                                  8            ($key, $flags, $exptime, $bytes) = @vals;
229            2                                  8            $session->{bytes} = $bytes;
230                                                         }
231                                                         elsif ( $cmd eq 'get' ) {
232            5                                 19            ($key) = @vals;
233                                                         }
234                                                         elsif ( $cmd eq 'delete' ) {
235            2                                  8            ($key) = @vals; # TODO: handle the <queue_time>
236                                                         }
237                                                         elsif ( $cmd eq 'incr' || $cmd eq 'decr' ) {
238            4                                 16            ($key) = @vals;
239                                                         }
240           13                                 54         @{$session}{qw(cmd key flags exptime)}
              13                                 75   
241                                                            = ($cmd, $key, $flags, $exptime);
242           13                                 63         $session->{host}       = $packet->{src_host};
243           13                                 51         $session->{pos_in_log} = $packet->{pos_in_log};
244           13                                 58         $session->{ts}         = $packet->{ts};
245                                                      }
246                                                      else {
247            1                                  2         MKDEBUG && _d('Session state: ', $session->{state});
248            1                                  5         $val = $packet->{data};
249                                                      }
250                                                   
251                                                      # Handle the rest of the packet.  It might not be the whole value that was
252                                                      # sent, for example for a big set().  We need to look at the number of bytes
253                                                      # and see if we got it all.
254           14                                 47      $session->{state} = 'awaiting reply'; # Assume we got the whole packet
255           14    100                          54      if ( $val ) {
256            3    100                          19         if ( $session->{bytes} + 2 == length($val) ) { # +2 for the \r\n
257            1                                  3            MKDEBUG && _d('Got the whole thing');
258            1                                  4            $val =~ s/\r\n\Z//; # We got the whole thing.
259            1                                  4            $session->{val} = $val;
260                                                         }
261                                                         else { # We apparently did NOT get the whole thing.
262            2                                  5            MKDEBUG && _d('Partial send, saving for later');
263            2                                  5            push @{$session->{partial}},
               2                                 17   
264                                                               [ $packet->{seq}, $val ];
265            2                                  8            $session->{gathered} += length($val);
266                                                            MKDEBUG && _d('Gathered', $session->{gathered}, 'bytes in',
267            2                                  4               scalar(@{$session->{partial}}), 'packets from client');
268            2    100                          13            if ( $session->{gathered} >= $session->{bytes} + 2 ) { # Done.
269            1                                  2               MKDEBUG && _d('Message looks complete now, saving value');
270            2                                 26               $val = join('',
271            1                                  5                  map  { $_->[1] }
272                                                                  # Sort in proper sequence because TCP might reorder them.
273            1                                  2                  sort { $a->[0] <=> $b->[0] }
274            1                                  4                       @{$session->{partial}});
275            1                                  6               $val =~ s/\r\n\Z//;
276            1                                  8               $session->{val} = $val;
277                                                            }
278                                                            else {
279            1                                  3               MKDEBUG && _d('Message not complete');
280            1                                  4               $val = '[INCOMPLETE]';
281            1                                  4               $session->{state} = 'partial send';
282                                                            }
283                                                         }
284                                                      }
285                                                   
286           14                                 58      return $event;
287                                                   }
288                                                   
289                                                   # The event is not yet suitable for mk-query-digest.  It lacks, for example,
290                                                   # an arg and fingerprint attribute.  The event should be passed to
291                                                   # MemcachedEvent::make_event() to transform it.
292                                                   sub make_event {
293           13                   13            51      my ( $session, $packet ) = @_;
294           13           100                  372      my $event = {
      ***                   50                        
      ***                   50                        
                           100                        
295                                                         cmd        => $session->{cmd},
296                                                         key        => $session->{key},
297                                                         val        => $session->{val} || '',
298                                                         res        => $session->{res},
299                                                         ts         => $session->{ts},
300                                                         host       => $session->{host},
301                                                         flags      => $session->{flags}   || 0,
302                                                         exptime    => $session->{exptime} || 0,
303                                                         bytes      => $session->{bytes}   || 0,
304                                                         Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
305                                                         pos_in_log => $session->{pos_in_log},
306                                                      };
307           13                                 53      return $event;
308                                                   }
309                                                   
310                                                   sub _get_errors_fh {
311   ***      0                    0             0      my ( $self ) = @_;
312   ***      0                                  0      my $errors_fh = $self->{errors_fh};
313   ***      0      0                           0      return $errors_fh if $errors_fh;
314                                                   
315                                                      # Errors file isn't open yet; try to open it.
316   ***      0                                  0      my $o = $self->{o};
317   ***      0      0      0                    0      if ( $o && $o->has('tcpdump-errors') && $o->got('tcpdump-errors') ) {
      ***                    0                        
318   ***      0                                  0         my $errors_file = $o->get('tcpdump-errors');
319   ***      0                                  0         MKDEBUG && _d('tcpdump-errors file:', $errors_file);
320   ***      0      0                           0         open $errors_fh, '>>', $errors_file
321                                                            or die "Cannot open tcpdump-errors file $errors_file: $OS_ERROR";
322                                                      }
323                                                   
324   ***      0                                  0      $self->{errors_fh} = $errors_fh;
325   ***      0                                  0      return $errors_fh;
326                                                   }
327                                                   
328                                                   sub fail_session {
329   ***      0                    0             0      my ( $self, $session, $reason ) = @_;
330   ***      0                                  0      my $errors_fh = $self->_get_errors_fh();
331   ***      0      0                           0      if ( $errors_fh ) {
332   ***      0                                  0         $session->{reason_for_failure} = $reason;
333   ***      0                                  0         my $session_dump = '# ' . Dumper($session);
334   ***      0                                  0         chomp $session_dump;
335   ***      0                                  0         $session_dump =~ s/\n/\n# /g;
336   ***      0                                  0         print $errors_fh "$session_dump\n";
337                                                         {
338   ***      0                                  0            local $LIST_SEPARATOR = "\n";
      ***      0                                  0   
339   ***      0                                  0            print $errors_fh "@{$session->{raw_packets}}";
      ***      0                                  0   
340   ***      0                                  0            print $errors_fh "\n";
341                                                         }
342                                                      }
343   ***      0                                  0      MKDEBUG && _d('Failed session', $session->{client}, 'because', $reason);
344   ***      0                                  0      delete $self->{sessions}->{$session->{client}};
345   ***      0                                  0      return;
346                                                   }
347                                                   
348                                                   sub _d {
349   ***      0                    0             0      my ($package, undef, $line) = caller 0;
350   ***      0      0                           0      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                  0   
      ***      0                                  0   
351   ***      0                                  0           map { defined $_ ? $_ : 'undef' }
352                                                           @_;
353   ***      0                                  0      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
354                                                   }
355                                                   
356                                                   # Returns the difference between two tcpdump timestamps.  TODO: this is in
357                                                   # MySQLProtocolParser too, best to factor it out somewhere common.
358                                                   sub timestamp_diff {
359           13                   13            62      my ( $start, $end ) = @_;
360           13                                 61      my $sd = substr($start, 0, 11, '');
361           13                                 39      my $ed = substr($end,   0, 11, '');
362           13                                 87      my ( $sh, $sm, $ss ) = split(/:/, $start);
363           13                                 67      my ( $eh, $em, $es ) = split(/:/, $end);
364           13                                 91      my $esecs = ($eh * 3600 + $em * 60 + $es);
365           13                                 55      my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
366   ***     13     50                          48      if ( $sd eq $ed ) {
367           13                                329         return sprintf '%.6f', $esecs - $ssecs;
368                                                      }
369                                                      else { # Assume only one day boundary has been crossed, no DST, etc
370   ***      0                                            return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
371                                                      }
372                                                   }
373                                                   
374                                                   # Replace things that look like placeholders with a ?
375                                                   sub fingerprint {
376   ***      0                    0                    my ( $val ) = @_;
377   ***      0                                         $val =~ s/[0-9A-Fa-f]{16,}|\d+/?/g;
378                                                   }
379                                                   
380                                                   1;
381                                                   
382                                                   # ###########################################################################
383                                                   # End MemcachedProtocolParser package
384                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
53    ***     50     10      0   $to =~ /:(?:11211)$/ ? :
      ***     50      0     10   $from =~ /:(?:11211)$/ ? :
56           100     22     27   $from eq $$self{'server'} ? :
61           100     14     35   if (not exists $$self{'sessions'}{$client})
75           100     20     29   if ($$packet{'data_len'} == 0)
86           100     15     14   if ($from eq $$self{'server'}) { }
      ***     50     14      0   elsif ($from eq $client) { }
104   ***     50      0     15   unless $packet
105   ***     50      0     15   unless $session
113   ***     50      0     15   if (not $$session{'state'})
120          100     13      2   if ($$session{'state'} eq 'awaiting reply') { }
127          100      4      9   if ($$session{'cmd'} eq 'incr' or $$session{'cmd'} eq 'decr') { }
             100      4      5   elsif ($$session{'res'} eq 'VALUE') { }
             100      1      4   elsif ($$session{'res'} eq 'END') { }
      ***     50      0      4   elsif (not $$session{'res'} =~ /STORED|DELETED|NOT_FOUND/) { }
129          100      2      2   if (not $$session{'res'} =~ /\D/)
138   ***     50      4      0   unless defined $$session{'flags'}
139   ***     50      4      0   unless defined $$session{'bytes'}
141   ***     50      4      0   if ($rest and $bytes)
143          100      2      2   if (length $rest > $bytes) { }
174          100      1      1   if ($$session{'gathered'} >= $$session{'bytes'} + 2) { }
199   ***     50      0     14   unless $packet
200   ***     50      0     14   unless $session
205          100      1     13   if (($$session{'state'} || '') =~ /awaiting reply|partial recv/)
219          100     13      1   if (not $$session{'state'}) { }
227          100      2     11   if ($cmd eq 'set') { }
             100      5      6   elsif ($cmd eq 'get') { }
             100      2      4   elsif ($cmd eq 'delete') { }
      ***     50      4      0   elsif ($cmd eq 'incr' or $cmd eq 'decr') { }
255          100      3     11   if ($val)
256          100      1      2   if ($$session{'bytes'} + 2 == length $val) { }
268          100      1      1   if ($$session{'gathered'} >= $$session{'bytes'} + 2) { }
313   ***      0      0      0   if $errors_fh
317   ***      0      0      0   if ($o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors'))
320   ***      0      0      0   unless open $errors_fh, '>>', $errors_file
331   ***      0      0      0   if ($errors_fh)
350   ***      0      0      0   defined $_ ? :
366   ***     50     13      0   if ($sd eq $ed) { }


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
141   ***     33      0      0      4   $rest and $bytes
317   ***      0      0      0      0   $o and $o->has('tcpdump-errors')
      ***      0      0      0      0   $o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors')

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
53           100     39     10   $$self{'server'} ||= $from =~ /:(?:11211)$/ ? $from : ($to =~ /:(?:11211)$/ ? $to : undef)
205          100      2     12   $$session{'state'} || ''
294          100      7      6   $$session{'val'} || ''
      ***     50      0     13   $$session{'flags'} || 0
      ***     50      0     13   $$session{'exptime'} || 0
             100      6      7   $$session{'bytes'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
127          100      2      2      9   $$session{'cmd'} eq 'incr' or $$session{'cmd'} eq 'decr'
227   ***     66      2      2      0   $cmd eq 'incr' or $cmd eq 'decr'


Covered Subroutines
-------------------

Subroutine          Count Location                                                      
------------------- ----- --------------------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:22 
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:23 
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:24 
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:26 
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:31 
_packet_from_client    14 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:198
_packet_from_server    15 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:103
make_event             13 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:293
new                    10 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:36 
parse_packet           49 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:48 
timestamp_diff         13 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:359

Uncovered Subroutines
---------------------

Subroutine          Count Location                                                      
------------------- ----- --------------------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:349
_get_errors_fh          0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:311
fail_session            0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:329
fingerprint             0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:376


