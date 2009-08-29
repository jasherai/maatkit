---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...emcachedProtocolParser.pm   79.8   66.2   51.5   78.6    n/a  100.0   73.8
Total                          79.8   66.2   51.5   78.6    n/a  100.0   73.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          MemcachedProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:01 2009
Finish:       Sat Aug 29 15:03:02 2009

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
18                                                    # MemcachedProtocolParser package $Revision: 4308 $
19                                                    # ###########################################################################
20                                                    package MemcachedProtocolParser;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  8   
23             1                    1             6   use warnings FATAL => 'all';
               1                                 13   
               1                                 10   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
25                                                    
26             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  8   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 11   
32                                                    
33                                                    # server is the "host:port" of the sever being watched.  It's auto-guessed if
34                                                    # not specified.
35                                                    sub new {
36            11                   11           450      my ( $class, %args ) = @_;
37                                                    
38    ***     11     50                          68      my ( $server_port )
39                                                          = $args{server} ? $args{server} =~ m/:(\w+)/ : ('11211');
40    ***     11            50                   43      $server_port ||= '11211';  # In case $args{server} doesn't have a port.
41                                                    
42            11                                 95      my $self = {
43                                                          server      => $args{server},
44                                                          server_port => $server_port,
45                                                          sessions    => {},
46                                                          o           => $args{o},
47                                                       };
48            11                                 74      return bless $self, $class;
49                                                    }
50                                                    
51                                                    # The packet arg should be a hashref from TcpdumpParser::parse_event().
52                                                    # misc is a placeholder for future features.
53                                                    sub parse_packet {
54            53                   53           635      my ( $self, $packet, $misc ) = @_;
55                                                    
56            53                                249      my $src_host = "$packet->{src_host}:$packet->{src_port}";
57            53                                231      my $dst_host = "$packet->{dst_host}:$packet->{dst_port}";
58                                                    
59    ***     53     50                         236      if ( my $server = $self->{server} ) {  # Watch only the given server.
60    ***      0      0      0                    0         if ( $src_host ne $server && $dst_host ne $server ) {
61    ***      0                                  0            MKDEBUG && _d('Packet is not to or from', $server);
62    ***      0                                  0            return;
63                                                          }
64                                                       }
65                                                    
66                                                       # Auto-detect the server by looking for port 11211
67            53                                120      my $packet_from;
68            53                                124      my $client;
69            53    100                         401      if ( $src_host =~ m/:$self->{server_port}$/ ) {
      ***            50                               
70            24                                 60         $packet_from = 'server';
71            24                                 65         $client      = $dst_host;
72                                                       }
73                                                       elsif ( $dst_host =~ m/:$self->{server_port}$/ ) {
74            29                                 77         $packet_from = 'client';
75            29                                 81         $client      = $src_host;
76                                                       }
77                                                       else {
78    ***      0                                  0         warn 'Packet is not to or from memcached server: ', Dumper($packet);
79    ***      0                                  0         return;
80                                                       }
81            53                                109      MKDEBUG && _d('Client:', $client);
82                                                    
83                                                       # Get the client's session info or create a new session if the
84                                                       # client hasn't been seen before.
85            53    100                         258      if ( !exists $self->{sessions}->{$client} ) {
86            16                                 35         MKDEBUG && _d('New session');
87            16                                143         $self->{sessions}->{$client} = {
88                                                             client      => $client,
89                                                             state       => undef,
90                                                             raw_packets => [],
91                                                             # ts -- wait for ts later.
92                                                          };
93                                                       };
94            53                                198      my $session = $self->{sessions}->{$client};
95                                                    
96                                                       # Return early if there's no TCP data.  These are usually ACK packets, but
97                                                       # they could also be FINs in which case, we should close and delete the
98                                                       # client's session.
99            53    100                         228      if ( $packet->{data_len} == 0 ) {
100           20                                 45         MKDEBUG && _d('No TCP data');
101           20                                115         return;
102                                                      }
103                                                   
104                                                      # Save raw packets to dump later in case something fails.
105           33                                 79      push @{$session->{raw_packets}}, $packet->{raw_packet};
              33                                255   
106                                                   
107                                                      # Finally, parse the packet and maybe create an event.
108           33                                741      $packet->{data} = pack('H*', $packet->{data});
109           33                                 75      my $event;
110           33    100                         140      if ( $packet_from eq 'server' ) {
      ***            50                               
111           17                                 76         $event = $self->_packet_from_server($packet, $session, $misc);
112                                                      }
113                                                      elsif ( $packet_from eq 'client' ) {
114           16                                 82         $event = $self->_packet_from_client($packet, $session, $misc);
115                                                      }
116                                                      else {
117                                                         # Should not get here.
118   ***      0                                  0         die 'Packet origin unknown';
119                                                      }
120                                                   
121           33                                 83      MKDEBUG && _d('Done with packet; event:', Dumper($event));
122           33                               1057      return $event;
123                                                   }
124                                                   
125                                                   # Handles a packet from the server given the state of the session.  Returns an
126                                                   # event if one was ready to be created, otherwise returns nothing.
127                                                   sub _packet_from_server {
128           17                   17            69      my ( $self, $packet, $session, $misc ) = @_;
129   ***     17     50                          69      die "I need a packet"  unless $packet;
130   ***     17     50                          79      die "I need a session" unless $session;
131                                                   
132           17                                 36      MKDEBUG && _d('Packet is from server; client state:', $session->{state}); 
133                                                   
134           17                                 66      my $data = $packet->{data};
135                                                   
136                                                      # If there's no session state, then we're catching a server response
137                                                      # mid-stream.
138   ***     17     50                          92      if ( !$session->{state} ) {
139   ***      0                                  0         MKDEBUG && _d('Ignoring mid-stream server response');
140   ***      0                                  0         return;
141                                                      }
142                                                   
143                                                      # Assume that the server is returning only one value.  TODO: make it
144                                                      # handle multi-gets.
145           17    100                          79      if ( $session->{state} eq 'awaiting reply' ) {
146           15                                 33         MKDEBUG && _d('State is awaiting reply');
147           15                                133         my ($line1, $rest) = $packet->{data} =~ m/\A(.*?)\r\n(.*)?/s;
148                                                   
149                                                         # Split up the first line into its parts.
150           15                                 97         my @vals = $line1 =~ m/(\S+)/g;
151           15                                 65         $session->{res} = shift @vals;
152           15    100    100                  214         if ( $session->{cmd} eq 'incr' || $session->{cmd} eq 'decr' ) {
                    100                               
                    100                               
      ***            50                               
153            4                                  8            MKDEBUG && _d('It is an incr or decr');
154            4    100                          21            if ( $session->{res} !~ m/\D/ ) { # It's an integer, not an error
155            2                                  4               MKDEBUG && _d('Got a value for the incr/decr');
156            2                                  9               $session->{val} = $session->{res};
157            2                                  8               $session->{res} = '';
158                                                            }
159                                                         }
160                                                         elsif ( $session->{res} eq 'VALUE' ) {
161            5                                 11            MKDEBUG && _d('It is the result of a "get"');
162            5                                 19            my ($key, $flags, $bytes) = @vals;
163   ***      5     50                          28            defined $session->{flags} or $session->{flags} = $flags;
164   ***      5     50                          30            defined $session->{bytes} or $session->{bytes} = $bytes;
165                                                            # Get the value from the $rest. TODO: there might be multiple responses
166   ***      5     50     33                   37            if ( $rest && $bytes ) {
167            5                                 10               MKDEBUG && _d('There is a value');
168            5    100                          25               if ( length($rest) > $bytes ) {
169            3                                  9                  MKDEBUG && _d('Looks like we got the whole response');
170            3                                 15                  $session->{val} = substr($rest, 0, $bytes); # Got the whole response.
171                                                               }
172                                                               else {
173            2                                  5                  MKDEBUG && _d('Got partial response, saving for later');
174            2                                  6                  push @{$session->{partial}}, [ $packet->{seq}, $rest ];
               2                                 15   
175            2                                  8                  $session->{gathered} += length($rest);
176            2                                  6                  $session->{state} = 'partial recv';
177            2                                  9                  return; # Prevent firing an event.
178                                                               }
179                                                            }
180                                                         }
181                                                         elsif ( $session->{res} eq 'END' ) {
182                                                            # Technically NOT_FOUND is an error, and this isn't an error it's just
183                                                            # a NULL, but what it really means is the value isn't found.
184            1                                  3            MKDEBUG && _d('Got an END without any data, firing NOT_FOUND');
185            1                                  5            $session->{res} = 'NOT_FOUND';
186                                                         }
187                                                         elsif ( $session->{res} !~ m/STORED|DELETED|NOT_FOUND/ ) {
188                                                            # Not really sure what else would get us here... want to make a note
189                                                            # and not have an uncaught condition.
190   ***      0                                  0            MKDEBUG && _d("Session result:", $session->{res});
191                                                         }
192                                                      }
193                                                      else { # Should be 'partial recv'
194            2                                  5         MKDEBUG && _d('Session state: ', $session->{state});
195            2                                  5         push @{$session->{partial}}, [ $packet->{seq}, $data ];
               2                                 26   
196            2                                  7         $session->{gathered} += length($data);
197                                                         MKDEBUG && _d('Gathered', $session->{gathered}, 'bytes in',
198            2                                  5            scalar(@{$session->{partial}}), 'packets from server');
199            2    100                          14         if ( $session->{gathered} >= $session->{bytes} + 2 ) { # Done.
200            1                                  3            MKDEBUG && _d('End of partial response, preparing event');
201            3                                 29            my $val = join('',
202            3                                 13               map  { $_->[1] }
203                                                               # Sort in proper sequence because TCP might reorder them.
204            1                                  2               sort { $a->[0] <=> $b->[0] }
205            1                                  3                    @{$session->{partial}});
206            1                                 14            $session->{val} = substr($val, 0, $session->{bytes});
207                                                         }
208                                                         else {
209            1                                  2            MKDEBUG && _d('Partial response continues, no action');
210            1                                  4            return; # Prevent firing event.
211                                                         }
212                                                      }
213                                                   
214           14                                 59      my $event = make_event($session, $packet);
215           14                                 34      MKDEBUG && _d('Creating event, deleting session');
216           14                                 75      delete $self->{sessions}->{$session->{client}}; # memcached is stateless!
217           14                                 46      $session->{raw_packets} = []; # Avoid keeping forever
218           14                                 66      return $event;
219                                                   }
220                                                   
221                                                   # Handles a packet from the client given the state of the session.
222                                                   sub _packet_from_client {
223           16                   16            66      my ( $self, $packet, $session, $misc ) = @_;
224   ***     16     50                          65      die "I need a packet"  unless $packet;
225   ***     16     50                          58      die "I need a session" unless $session;
226                                                   
227           16                                 35      MKDEBUG && _d('Packet is from client; state:', $session->{state});
228                                                   
229           16                                 37      my $event;
230           16    100    100                  146      if ( ($session->{state} || '') =~m/awaiting reply|partial recv/ ) {
231                                                         # Whoa, we expected something from the server, not the client.  Fire an
232                                                         # INTERRUPTED with what we've got, and create a new session.
233            1                                  2         MKDEBUG && _d("Expected data from the client, looks like interrupted");
234            1                                  4         $session->{res} = 'INTERRUPTED';
235            1                                  4         $event = make_event($session, $packet);
236            1                                  3         my $client = $session->{client};
237            1                                  6         delete @{$session}{keys %$session};
               1                                  7   
238            1                                  5         $session->{client} = $client;
239                                                      }
240                                                   
241           16                                 49      my ($line1, $val);
242           16                                 54      my ($cmd, $key, $flags, $exptime, $bytes);
243                                                      
244           16    100                          62      if ( !$session->{state} ) {
245           15                                 37         MKDEBUG && _d('Session state: ', $session->{state});
246                                                         # Split up the first line into its parts.
247           15                                185         ($line1, $val) = $packet->{data} =~ m/\A(.*?)\r\n(.+)?/s;
248                                                         # TODO: handle <cas unique> and [noreply]
249           15                                119         my @vals = $line1 =~ m/(\S+)/g;
250           15                                 60         $cmd = lc shift @vals;
251           15                                 37         MKDEBUG && _d('$cmd is a ', $cmd);
252   ***     15    100     66                  181         if ( $cmd eq 'set' || $cmd eq 'add' ) {
      ***           100     66                        
                    100                               
      ***            50                               
253            3                                 11            ($key, $flags, $exptime, $bytes) = @vals;
254            3                                 13            $session->{bytes} = $bytes;
255                                                         }
256                                                         elsif ( $cmd eq 'get' ) {
257            6                                 20            ($key) = @vals;
258                                                         }
259                                                         elsif ( $cmd eq 'delete' ) {
260            2                                  8            ($key) = @vals; # TODO: handle the <queue_time>
261                                                         }
262                                                         elsif ( $cmd eq 'incr' || $cmd eq 'decr' ) {
263            4                                 15            ($key) = @vals;
264                                                         }
265                                                         else {
266   ***      0                                  0            MKDEBUG && _d("Don't know how to handle", $cmd, "command");
267                                                         }
268           15                                 61         @{$session}{qw(cmd key flags exptime)}
              15                                 92   
269                                                            = ($cmd, $key, $flags, $exptime);
270           15                                 95         $session->{host}       = $packet->{src_host};
271           15                                 64         $session->{pos_in_log} = $packet->{pos_in_log};
272           15                                 74         $session->{ts}         = $packet->{ts};
273                                                      }
274                                                      else {
275            1                                  2         MKDEBUG && _d('Session state: ', $session->{state});
276            1                                  5         $val = $packet->{data};
277                                                      }
278                                                   
279                                                      # Handle the rest of the packet.  It might not be the whole value that was
280                                                      # sent, for example for a big set().  We need to look at the number of bytes
281                                                      # and see if we got it all.
282           16                                 60      $session->{state} = 'awaiting reply'; # Assume we got the whole packet
283           16    100                          69      if ( $val ) {
284            4    100                          27         if ( $session->{bytes} + 2 == length($val) ) { # +2 for the \r\n
285            2                                  6            MKDEBUG && _d('Got the whole thing');
286            2                                  8            $val =~ s/\r\n\Z//; # We got the whole thing.
287            2                                  8            $session->{val} = $val;
288                                                         }
289                                                         else { # We apparently did NOT get the whole thing.
290            2                                  5            MKDEBUG && _d('Partial send, saving for later');
291            2                                  5            push @{$session->{partial}},
               2                                 17   
292                                                               [ $packet->{seq}, $val ];
293            2                                  7            $session->{gathered} += length($val);
294                                                            MKDEBUG && _d('Gathered', $session->{gathered}, 'bytes in',
295            2                                  5               scalar(@{$session->{partial}}), 'packets from client');
296            2    100                          12            if ( $session->{gathered} >= $session->{bytes} + 2 ) { # Done.
297            1                                  3               MKDEBUG && _d('Message looks complete now, saving value');
298            2                                 23               $val = join('',
299            1                                  4                  map  { $_->[1] }
300                                                                  # Sort in proper sequence because TCP might reorder them.
301            1                                  3                  sort { $a->[0] <=> $b->[0] }
302            1                                  3                       @{$session->{partial}});
303            1                                  6               $val =~ s/\r\n\Z//;
304            1                                 10               $session->{val} = $val;
305                                                            }
306                                                            else {
307            1                                  2               MKDEBUG && _d('Message not complete');
308            1                                  3               $val = '[INCOMPLETE]';
309            1                                  4               $session->{state} = 'partial send';
310                                                            }
311                                                         }
312                                                      }
313                                                   
314           16                                 62      return $event;
315                                                   }
316                                                   
317                                                   # The event is not yet suitable for mk-query-digest.  It lacks, for example,
318                                                   # an arg and fingerprint attribute.  The event should be passed to
319                                                   # MemcachedEvent::make_event() to transform it.
320                                                   sub make_event {
321           15                   15            56      my ( $session, $packet ) = @_;
322           15           100                 7933      my $event = {
      ***                   50                        
      ***                   50                        
                           100                        
323                                                         cmd        => $session->{cmd},
324                                                         key        => $session->{key},
325                                                         val        => $session->{val} || '',
326                                                         res        => $session->{res},
327                                                         ts         => $session->{ts},
328                                                         host       => $session->{host},
329                                                         flags      => $session->{flags}   || 0,
330                                                         exptime    => $session->{exptime} || 0,
331                                                         bytes      => $session->{bytes}   || 0,
332                                                         Query_time => timestamp_diff($session->{ts}, $packet->{ts}),
333                                                         pos_in_log => $session->{pos_in_log},
334                                                      };
335           15                                 73      return $event;
336                                                   }
337                                                   
338                                                   sub _get_errors_fh {
339   ***      0                    0             0      my ( $self ) = @_;
340   ***      0                                  0      my $errors_fh = $self->{errors_fh};
341   ***      0      0                           0      return $errors_fh if $errors_fh;
342                                                   
343                                                      # Errors file isn't open yet; try to open it.
344   ***      0                                  0      my $o = $self->{o};
345   ***      0      0      0                    0      if ( $o && $o->has('tcpdump-errors') && $o->got('tcpdump-errors') ) {
      ***                    0                        
346   ***      0                                  0         my $errors_file = $o->get('tcpdump-errors');
347   ***      0                                  0         MKDEBUG && _d('tcpdump-errors file:', $errors_file);
348   ***      0      0                           0         open $errors_fh, '>>', $errors_file
349                                                            or die "Cannot open tcpdump-errors file $errors_file: $OS_ERROR";
350                                                      }
351                                                   
352   ***      0                                  0      $self->{errors_fh} = $errors_fh;
353   ***      0                                  0      return $errors_fh;
354                                                   }
355                                                   
356                                                   sub fail_session {
357   ***      0                    0             0      my ( $self, $session, $reason ) = @_;
358   ***      0                                  0      my $errors_fh = $self->_get_errors_fh();
359   ***      0      0                           0      if ( $errors_fh ) {
360   ***      0                                  0         $session->{reason_for_failure} = $reason;
361   ***      0                                  0         my $session_dump = '# ' . Dumper($session);
362   ***      0                                  0         chomp $session_dump;
363   ***      0                                  0         $session_dump =~ s/\n/\n# /g;
364   ***      0                                  0         print $errors_fh "$session_dump\n";
365                                                         {
366   ***      0                                  0            local $LIST_SEPARATOR = "\n";
      ***      0                                  0   
367   ***      0                                  0            print $errors_fh "@{$session->{raw_packets}}";
      ***      0                                  0   
368   ***      0                                  0            print $errors_fh "\n";
369                                                         }
370                                                      }
371   ***      0                                  0      MKDEBUG && _d('Failed session', $session->{client}, 'because', $reason);
372   ***      0                                  0      delete $self->{sessions}->{$session->{client}};
373   ***      0                                  0      return;
374                                                   }
375                                                   
376                                                   sub _d {
377   ***      0                    0             0      my ($package, undef, $line) = caller 0;
378   ***      0      0                           0      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                  0   
      ***      0                                  0   
379   ***      0                                  0           map { defined $_ ? $_ : 'undef' }
380                                                           @_;
381   ***      0                                  0      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
382                                                   }
383                                                   
384                                                   # Returns the difference between two tcpdump timestamps.  TODO: this is in
385                                                   # MySQLProtocolParser too, best to factor it out somewhere common.
386                                                   sub timestamp_diff {
387           15                   15            75      my ( $start, $end ) = @_;
388           15                                 68      my $sd = substr($start, 0, 11, '');
389           15                                 50      my $ed = substr($end,   0, 11, '');
390           15                                 96      my ( $sh, $sm, $ss ) = split(/:/, $start);
391           15                                 72      my ( $eh, $em, $es ) = split(/:/, $end);
392           15                                103      my $esecs = ($eh * 3600 + $em * 60 + $es);
393           15                                 61      my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
394   ***     15     50                          57      if ( $sd eq $ed ) {
395           15                               7285         return sprintf '%.6f', $esecs - $ssecs;
396                                                      }
397                                                      else { # Assume only one day boundary has been crossed, no DST, etc
398   ***      0                                            return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
399                                                      }
400                                                   }
401                                                   
402                                                   1;
403                                                   
404                                                   # ###########################################################################
405                                                   # End MemcachedProtocolParser package
406                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
38    ***     50      0     11   $args{'server'} ? :
59    ***     50      0     53   if (my $server = $$self{'server'})
60    ***      0      0      0   if ($src_host ne $server and $dst_host ne $server)
69           100     24     29   if ($src_host =~ /:$$self{'server_port'}$/) { }
      ***     50     29      0   elsif ($dst_host =~ /:$$self{'server_port'}$/) { }
85           100     16     37   if (not exists $$self{'sessions'}{$client})
99           100     20     33   if ($$packet{'data_len'} == 0)
110          100     17     16   if ($packet_from eq 'server') { }
      ***     50     16      0   elsif ($packet_from eq 'client') { }
129   ***     50      0     17   unless $packet
130   ***     50      0     17   unless $session
138   ***     50      0     17   if (not $$session{'state'})
145          100     15      2   if ($$session{'state'} eq 'awaiting reply') { }
152          100      4     11   if ($$session{'cmd'} eq 'incr' or $$session{'cmd'} eq 'decr') { }
             100      5      6   elsif ($$session{'res'} eq 'VALUE') { }
             100      1      5   elsif ($$session{'res'} eq 'END') { }
      ***     50      0      5   elsif (not $$session{'res'} =~ /STORED|DELETED|NOT_FOUND/) { }
154          100      2      2   if (not $$session{'res'} =~ /\D/)
163   ***     50      5      0   unless defined $$session{'flags'}
164   ***     50      5      0   unless defined $$session{'bytes'}
166   ***     50      5      0   if ($rest and $bytes)
168          100      3      2   if (length $rest > $bytes) { }
199          100      1      1   if ($$session{'gathered'} >= $$session{'bytes'} + 2) { }
224   ***     50      0     16   unless $packet
225   ***     50      0     16   unless $session
230          100      1     15   if (($$session{'state'} || '') =~ /awaiting reply|partial recv/)
244          100     15      1   if (not $$session{'state'}) { }
252          100      3     12   if ($cmd eq 'set' or $cmd eq 'add') { }
             100      6      6   elsif ($cmd eq 'get') { }
             100      2      4   elsif ($cmd eq 'delete') { }
      ***     50      4      0   elsif ($cmd eq 'incr' or $cmd eq 'decr') { }
283          100      4     12   if ($val)
284          100      2      2   if ($$session{'bytes'} + 2 == length $val) { }
296          100      1      1   if ($$session{'gathered'} >= $$session{'bytes'} + 2) { }
341   ***      0      0      0   if $errors_fh
345   ***      0      0      0   if ($o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors'))
348   ***      0      0      0   unless open $errors_fh, '>>', $errors_file
359   ***      0      0      0   if ($errors_fh)
378   ***      0      0      0   defined $_ ? :
394   ***     50     15      0   if ($sd eq $ed) { }


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
60    ***      0      0      0      0   $src_host ne $server and $dst_host ne $server
166   ***     33      0      0      5   $rest and $bytes
345   ***      0      0      0      0   $o and $o->has('tcpdump-errors')
      ***      0      0      0      0   $o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors')

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
40    ***     50     11      0   $server_port ||= '11211'
230          100      2     14   $$session{'state'} || ''
322          100      9      6   $$session{'val'} || ''
      ***     50      0     15   $$session{'flags'} || 0
      ***     50      0     15   $$session{'exptime'} || 0
             100      8      7   $$session{'bytes'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
152          100      2      2     11   $$session{'cmd'} eq 'incr' or $$session{'cmd'} eq 'decr'
252   ***     66      3      0     12   $cmd eq 'set' or $cmd eq 'add'
      ***     66      2      2      0   $cmd eq 'incr' or $cmd eq 'decr'


Covered Subroutines
-------------------

Subroutine          Count Location                                                      
------------------- ----- --------------------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:22 
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:23 
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:24 
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:26 
BEGIN                   1 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:31 
_packet_from_client    16 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:223
_packet_from_server    17 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:128
make_event             15 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:321
new                    11 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:36 
parse_packet           53 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:54 
timestamp_diff         15 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:387

Uncovered Subroutines
---------------------

Subroutine          Count Location                                                      
------------------- ----- --------------------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:377
_get_errors_fh          0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:339
fail_session            0 /home/daniel/dev/maatkit/common/MemcachedProtocolParser.pm:357


