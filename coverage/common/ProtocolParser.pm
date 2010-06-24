---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/ProtocolParser.pm   10.0    0.0    3.3   35.3    0.0   31.8    8.3
ProtocolParser.t              100.0   50.0   33.3  100.0    n/a   68.2   91.4
Total                          20.2    1.4    6.1   54.2    0.0  100.0   16.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 20:08:55 2010
Finish:       Thu Jun 24 20:08:55 2010

Run:          ProtocolParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 20:08:57 2010
Finish:       Thu Jun 24 20:08:57 2010

/home/daniel/dev/maatkit/common/ProtocolParser.pm

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
18                                                    # ProtocolParser package $Revision: 5811 $
19                                                    # ###########################################################################
20                                                    package ProtocolParser;
21                                                    
22             1                    1             4   use strict;
               1                                  3   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  1   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
25                                                    
26                                                    eval {
27                                                       require IO::Uncompress::Inflate;
28                                                       IO::Uncompress::Inflate->import(qw(inflate $InflateError));
29                                                    };
30                                                    
31             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  7   
32                                                    $Data::Dumper::Indent    = 1;
33                                                    $Data::Dumper::Sortkeys  = 1;
34                                                    $Data::Dumper::Quotekeys = 0;
35                                                    
36    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
37                                                    
38                                                    sub new {
39    ***      1                    1      0      5      my ( $class, %args ) = @_;
40                                                    
41             1                                  8      my $self = {
42                                                          server      => $args{server},
43                                                          port        => $args{port},
44                                                          sessions    => {},
45                                                          o           => $args{o},
46                                                       };
47                                                    
48             1                                 14      return bless $self, $class;
49                                                    }
50                                                    
51                                                    sub parse_event {
52    ***      0                    0      0             my ( $self, %args ) = @_;
53    ***      0                                         my @required_args = qw(event);
54    ***      0                                         foreach my $arg ( @required_args ) {
55    ***      0      0                                     die "I need a $arg argument" unless $args{$arg};
56                                                       }
57    ***      0                                         my $packet = @args{@required_args};
58                                                    
59                                                       # Save each session's packets until its closed by the client.
60                                                       # This allows us to ensure that packets are processed in order.
61    ***      0      0                                  if ( $self->{buffer} ) {
62    ***      0                                            my ($packet_from, $session) = $self->_get_session($packet);
63    ***      0      0                                     if ( $packet->{data_len} ) {
64    ***      0      0                                        if ( $packet_from eq 'client' ) {
65    ***      0                                                  push @{$session->{client_packets}}, $packet;
      ***      0                                      
66    ***      0                                                  MKDEBUG && _d('Saved client packet');
67                                                             }
68                                                             else {
69    ***      0                                                  push @{$session->{server_packets}}, $packet;
      ***      0                                      
70    ***      0                                                  MKDEBUG && _d('Saved server packet');
71                                                             }
72                                                          }
73                                                    
74                                                          # Process the session's packets when the client closes the connection.
75    ***      0      0      0                              return unless ($packet_from eq 'client')
      ***                    0                        
76                                                                        && ($packet->{fin} || $packet->{rst});
77                                                    
78    ***      0                                            my $event;
79    ***      0                                            map {
80    ***      0                                               $event = $self->_parse_packet($_, $args{misc});
81    ***      0                                            } sort { $a->{seq} <=> $b->{seq} }
82    ***      0                                            @{$session->{client_packets}};
83                                                          
84    ***      0                                            map {
85    ***      0                                               $event = $self->_parse_packet($_, $args{misc});
86    ***      0                                            } sort { $a->{seq} <=> $b->{seq} }
87    ***      0                                            @{$session->{server_packets}};
88                                                    
89    ***      0                                            return $event;
90                                                       }
91                                                    
92    ***      0      0                                  if ( $packet->{data_len} == 0 ) {
93                                                          # Return early if there's no TCP data.  These are usually ACK packets, but
94                                                          # they could also be FINs in which case, we should close and delete the
95                                                          # client's session.
96    ***      0                                            MKDEBUG && _d('No TCP data');
97    ***      0                                            return;
98                                                       }
99                                                    
100   ***      0                                         return $self->_parse_packet($packet, $args{misc});
101                                                   }
102                                                   
103                                                   # The packet arg should be a hashref from TcpdumpParser::parse_event().
104                                                   # misc is a placeholder for future features.
105                                                   sub _parse_packet {
106   ***      0                    0                    my ( $self, $packet, $misc ) = @_;
107                                                   
108   ***      0                                         my ($packet_from, $session) = $self->_get_session($packet);
109   ***      0                                         MKDEBUG && _d('State:', $session->{state});
110                                                   
111                                                      # Save raw packets to dump later in case something fails.
112   ***      0      0                                  push @{$session->{raw_packets}}, $packet->{raw_packet}
      ***      0                                      
113                                                         unless $misc->{recurse};
114                                                   
115   ***      0      0                                  if ( $session->{buff} ) {
116                                                         # Previous packets were not complete so append this data
117                                                         # to what we've been buffering.
118   ***      0                                            $session->{buff_left} -= $packet->{data_len};
119   ***      0      0                                     if ( $session->{buff_left} > 0 ) {
120   ***      0                                               MKDEBUG && _d('Added data to buff; expecting', $session->{buff_left},
121                                                               'more bytes');
122   ***      0                                               return;
123                                                         }
124                                                   
125   ***      0                                            MKDEBUG && _d('Got all data; buff left:', $session->{buff_left});
126   ***      0                                            $packet->{data}       = $session->{buff} . $packet->{data};
127   ***      0                                            $packet->{data_len}  += length $session->{buff};
128   ***      0                                            $session->{buff}      = '';
129   ***      0                                            $session->{buff_left} = 0;
130                                                      }
131                                                   
132                                                      # Finally, parse the packet and maybe create an event.
133   ***      0      0                                  $packet->{data} = pack('H*', $packet->{data}) unless $misc->{recurse};
134   ***      0                                         my $event;
135   ***      0      0                                  if ( $packet_from eq 'server' ) {
      ***             0                               
136   ***      0                                            $event = $self->_packet_from_server($packet, $session, $misc);
137                                                      }
138                                                      elsif ( $packet_from eq 'client' ) {
139   ***      0                                            $event = $self->_packet_from_client($packet, $session, $misc);
140                                                      }
141                                                      else {
142                                                         # Should not get here.
143   ***      0                                            die 'Packet origin unknown';
144                                                      }
145   ***      0                                         MKDEBUG && _d('State:', $session->{state});
146                                                   
147   ***      0      0                                  if ( $session->{out_of_order} ) {
148   ***      0                                            MKDEBUG && _d('Session packets are out of order');
149   ***      0                                            push @{$session->{packets}}, $packet;
      ***      0                                      
150   ***      0      0      0                              $session->{ts_min}
151                                                            = $packet->{ts} if $packet->{ts} lt ($session->{ts_min} || '');
152   ***      0      0      0                              $session->{ts_max}
153                                                            = $packet->{ts} if $packet->{ts} gt ($session->{ts_max} || '');
154   ***      0      0                                     if ( $session->{have_all_packets} ) {
155   ***      0                                               MKDEBUG && _d('Have all packets; ordering and processing');
156   ***      0                                               delete $session->{out_of_order};
157   ***      0                                               delete $session->{have_all_packets};
158   ***      0                                               map {
159   ***      0                                                  $event = $self->_parse_packet($_, { recurse => 1 });
160   ***      0                                               } sort { $a->{seq} <=> $b->{seq} } @{$session->{packets}};
      ***      0                                      
161                                                         }
162                                                      }
163                                                   
164   ***      0                                         MKDEBUG && _d('Done with packet; event:', Dumper($event));
165   ***      0                                         return $event;
166                                                   }
167                                                   
168                                                   sub _get_session {
169   ***      0                    0                    my ( $self, $packet ) = @_;
170                                                   
171   ***      0                                         my $src_host = "$packet->{src_host}:$packet->{src_port}";
172   ***      0                                         my $dst_host = "$packet->{dst_host}:$packet->{dst_port}";
173                                                   
174   ***      0      0                                  if ( my $server = $self->{server} ) {  # Watch only the given server.
175   ***      0                                            $server .= ":$self->{port}";
176   ***      0      0      0                              if ( $src_host ne $server && $dst_host ne $server ) {
177   ***      0                                               MKDEBUG && _d('Packet is not to or from', $server);
178   ***      0                                               return;
179                                                         }
180                                                      }
181                                                   
182                                                      # Auto-detect the server by looking for its port.
183   ***      0                                         my $packet_from;
184   ***      0                                         my $client;
185   ***      0      0                                  if ( $src_host =~ m/:$self->{port}$/ ) {
      ***             0                               
186   ***      0                                            $packet_from = 'server';
187   ***      0                                            $client      = $dst_host;
188                                                      }
189                                                      elsif ( $dst_host =~ m/:$self->{port}$/ ) {
190   ***      0                                            $packet_from = 'client';
191   ***      0                                            $client      = $src_host;
192                                                      }
193                                                      else {
194   ***      0                                            warn 'Packet is not to or from server: ', Dumper($packet);
195   ***      0                                            return;
196                                                      }
197   ***      0                                         MKDEBUG && _d('Client:', $client);
198                                                   
199                                                      # Get the client's session info or create a new session if the
200                                                      # client hasn't been seen before.
201   ***      0      0                                  if ( !exists $self->{sessions}->{$client} ) {
202   ***      0                                            MKDEBUG && _d('New session');
203   ***      0                                            $self->{sessions}->{$client} = {
204                                                            client      => $client,
205                                                            state       => undef,
206                                                            raw_packets => [],
207                                                            # ts -- wait for ts later.
208                                                         };
209                                                      };
210   ***      0                                         my $session = $self->{sessions}->{$client};
211                                                   
212   ***      0                                         return $packet_from, $session;
213                                                   }
214                                                   
215                                                   sub _packet_from_server {
216   ***      0                    0                    die "Don't call parent class _packet_from_server()";
217                                                   }
218                                                   
219                                                   sub _packet_from_client {
220   ***      0                    0                    die "Don't call parent class _packet_from_client()";
221                                                   }
222                                                   
223                                                   sub make_event {
224   ***      0                    0      0             my ( $self, $session, $packet ) = @_;
225   ***      0      0                                  die "Event has no attributes" unless scalar keys %{$session->{attribs}};
      ***      0                                      
226   ***      0      0                                  die "Query has no arg attribute" unless $session->{attribs}->{arg};
227   ***      0             0                           my $start_request = $session->{start_request} || 0;
228   ***      0             0                           my $start_reply   = $session->{start_reply}   || 0;
229   ***      0             0                           my $end_reply     = $session->{end_reply}     || 0;
230   ***      0                                         MKDEBUG && _d('Request start:', $start_request,
231                                                         'reply start:', $start_reply, 'reply end:', $end_reply);
232   ***      0                                         my $event = {
233                                                         Query_time    => $self->timestamp_diff($start_request, $start_reply),
234                                                         Transmit_time => $self->timestamp_diff($start_reply, $end_reply),
235                                                      };
236   ***      0                                         @{$event}{keys %{$session->{attribs}}} = values %{$session->{attribs}};
      ***      0                                      
      ***      0                                      
      ***      0                                      
237   ***      0                                         return $event;
238                                                   }
239                                                   
240                                                   sub _get_errors_fh {
241   ***      0                    0                    my ( $self ) = @_;
242   ***      0                                         my $errors_fh = $self->{errors_fh};
243   ***      0      0                                  return $errors_fh if $errors_fh;
244                                                   
245                                                      # Errors file isn't open yet; try to open it.
246   ***      0                                         my $o = $self->{o};
247   ***      0      0      0                           if ( $o && $o->has('tcpdump-errors') && $o->got('tcpdump-errors') ) {
      ***                    0                        
248   ***      0                                            my $errors_file = $o->get('tcpdump-errors');
249   ***      0                                            MKDEBUG && _d('tcpdump-errors file:', $errors_file);
250   ***      0      0                                     open $errors_fh, '>>', $errors_file
251                                                            or die "Cannot open tcpdump-errors file $errors_file: $OS_ERROR";
252                                                      }
253                                                   
254   ***      0                                         $self->{errors_fh} = $errors_fh;
255   ***      0                                         return $errors_fh;
256                                                   }
257                                                   
258                                                   sub fail_session {
259   ***      0                    0      0             my ( $self, $session, $reason ) = @_;
260   ***      0                                         my $errors_fh = $self->_get_errors_fh();
261   ***      0      0                                  if ( $errors_fh ) {
262   ***      0                                            $session->{reason_for_failure} = $reason;
263   ***      0                                            my $session_dump = '# ' . Dumper($session);
264   ***      0                                            chomp $session_dump;
265   ***      0                                            $session_dump =~ s/\n/\n# /g;
266   ***      0                                            print $errors_fh "$session_dump\n";
267                                                         {
268   ***      0                                               local $LIST_SEPARATOR = "\n";
      ***      0                                      
269   ***      0                                               print $errors_fh "@{$session->{raw_packets}}";
      ***      0                                      
270   ***      0                                               print $errors_fh "\n";
271                                                         }
272                                                      }
273   ***      0                                         MKDEBUG && _d('Failed session', $session->{client}, 'because', $reason);
274   ***      0                                         delete $self->{sessions}->{$session->{client}};
275   ***      0                                         return;
276                                                   }
277                                                   
278                                                   # Returns the difference between two tcpdump timestamps.
279                                                   sub timestamp_diff {
280   ***      0                    0      0             my ( $self, $start, $end ) = @_;
281   ***      0      0      0                           return 0 unless $start && $end;
282   ***      0                                         my $sd = substr($start, 0, 11, '');
283   ***      0                                         my $ed = substr($end,   0, 11, '');
284   ***      0                                         my ( $sh, $sm, $ss ) = split(/:/, $start);
285   ***      0                                         my ( $eh, $em, $es ) = split(/:/, $end);
286   ***      0                                         my $esecs = ($eh * 3600 + $em * 60 + $es);
287   ***      0                                         my $ssecs = ($sh * 3600 + $sm * 60 + $ss);
288   ***      0      0                                  if ( $sd eq $ed ) {
289   ***      0                                            return sprintf '%.6f', $esecs - $ssecs;
290                                                      }
291                                                      else { # Assume only one day boundary has been crossed, no DST, etc
292   ***      0                                            return sprintf '%.6f', ( 86_400 - $ssecs ) + $esecs;
293                                                      }
294                                                   }
295                                                   
296                                                   # Takes a scalarref to a hex string of compressed data.
297                                                   # Returns a scalarref to a hex string of the uncompressed data.
298                                                   # The given hex string of compressed data is not modified.
299                                                   sub uncompress_data {
300   ***      0                    0      0             my ( $self, $data, $len ) = @_;
301   ***      0      0                                  die "I need data" unless $data;
302   ***      0      0                                  die "I need a len argument" unless $len;
303   ***      0      0                                  die "I need a scalar reference to data" unless ref $data eq 'SCALAR';
304   ***      0                                         MKDEBUG && _d('Uncompressing data');
305   ***      0                                         our $InflateError;
306                                                   
307                                                      # Pack hex string into compressed binary data.
308   ***      0                                         my $comp_bin_data = pack('H*', $$data);
309                                                   
310                                                      # Uncompress the compressed binary data.
311   ***      0                                         my $uncomp_bin_data = '';
312   ***      0      0                                  my $z = new IO::Uncompress::Inflate(
313                                                         \$comp_bin_data
314                                                      ) or die "IO::Uncompress::Inflate failed: $InflateError";
315   ***      0      0                                  my $status = $z->read(\$uncomp_bin_data, $len)
316                                                         or die "IO::Uncompress::Inflate failed: $InflateError";
317                                                   
318                                                      # Unpack the uncompressed binary data back into a hex string.
319                                                      # This is the original MySQL packet(s).
320   ***      0                                         my $uncomp_data = unpack('H*', $uncomp_bin_data);
321                                                   
322   ***      0                                         return \$uncomp_data;
323                                                   }
324                                                   
325                                                   sub _d {
326   ***      0                    0                    my ($package, undef, $line) = caller 0;
327   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
328   ***      0                                              map { defined $_ ? $_ : 'undef' }
329                                                           @_;
330   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
331                                                   }
332                                                   
333                                                   1;
334                                                   
335                                                   # ###########################################################################
336                                                   # End ProtocolParser package
337                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
55    ***      0      0      0   unless $args{$arg}
61    ***      0      0      0   if ($$self{'buffer'})
63    ***      0      0      0   if ($$packet{'data_len'})
64    ***      0      0      0   if ($packet_from eq 'client') { }
75    ***      0      0      0   unless $packet_from eq 'client' and $$packet{'fin'} || $$packet{'rst'}
92    ***      0      0      0   if ($$packet{'data_len'} == 0)
112   ***      0      0      0   unless $$misc{'recurse'}
115   ***      0      0      0   if ($$session{'buff'})
119   ***      0      0      0   if ($$session{'buff_left'} > 0)
133   ***      0      0      0   unless $$misc{'recurse'}
135   ***      0      0      0   if ($packet_from eq 'server') { }
      ***      0      0      0   elsif ($packet_from eq 'client') { }
147   ***      0      0      0   if ($$session{'out_of_order'})
150   ***      0      0      0   if $$packet{'ts'} lt ($$session{'ts_min'} || '')
152   ***      0      0      0   if $$packet{'ts'} gt ($$session{'ts_max'} || '')
154   ***      0      0      0   if ($$session{'have_all_packets'})
174   ***      0      0      0   if (my $server = $$self{'server'})
176   ***      0      0      0   if ($src_host ne $server and $dst_host ne $server)
185   ***      0      0      0   if ($src_host =~ /:$$self{'port'}$/) { }
      ***      0      0      0   elsif ($dst_host =~ /:$$self{'port'}$/) { }
201   ***      0      0      0   if (not exists $$self{'sessions'}{$client})
225   ***      0      0      0   unless scalar keys %{$$session{'attribs'};}
226   ***      0      0      0   unless $$session{'attribs'}{'arg'}
243   ***      0      0      0   if $errors_fh
247   ***      0      0      0   if ($o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors'))
250   ***      0      0      0   unless open $errors_fh, '>>', $errors_file
261   ***      0      0      0   if ($errors_fh)
281   ***      0      0      0   unless $start and $end
288   ***      0      0      0   if ($sd eq $ed) { }
301   ***      0      0      0   unless $data
302   ***      0      0      0   unless $len
303   ***      0      0      0   unless ref $data eq 'SCALAR'
312   ***      0      0      0   unless my $z = 'IO::Uncompress::Inflate'->new(\$comp_bin_data)
315   ***      0      0      0   unless my $status = $z->read(\$uncomp_bin_data, $len)
327   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
75    ***      0      0      0      0   $packet_from eq 'client' and $$packet{'fin'} || $$packet{'rst'}
176   ***      0      0      0      0   $src_host ne $server and $dst_host ne $server
247   ***      0      0      0      0   $o and $o->has('tcpdump-errors')
      ***      0      0      0      0   $o and $o->has('tcpdump-errors') and $o->got('tcpdump-errors')
281   ***      0      0      0      0   $start and $end

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
36    ***     50      0      1   $ENV{'MKDEBUG'} || 0
150   ***      0      0      0   $$session{'ts_min'} || ''
152   ***      0      0      0   $$session{'ts_max'} || ''
227   ***      0      0      0   $$session{'start_request'} || 0
228   ***      0      0      0   $$session{'start_reply'} || 0
229   ***      0      0      0   $$session{'end_reply'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
75    ***      0      0      0      0   $$packet{'fin'} || $$packet{'rst'}


Covered Subroutines
-------------------

Subroutine          Count Pod Location                                             
------------------- ----- --- -----------------------------------------------------
BEGIN                   1     /home/daniel/dev/maatkit/common/ProtocolParser.pm:22 
BEGIN                   1     /home/daniel/dev/maatkit/common/ProtocolParser.pm:23 
BEGIN                   1     /home/daniel/dev/maatkit/common/ProtocolParser.pm:24 
BEGIN                   1     /home/daniel/dev/maatkit/common/ProtocolParser.pm:31 
BEGIN                   1     /home/daniel/dev/maatkit/common/ProtocolParser.pm:36 
new                     1   0 /home/daniel/dev/maatkit/common/ProtocolParser.pm:39 

Uncovered Subroutines
---------------------

Subroutine          Count Pod Location                                             
------------------- ----- --- -----------------------------------------------------
_d                      0     /home/daniel/dev/maatkit/common/ProtocolParser.pm:326
_get_errors_fh          0     /home/daniel/dev/maatkit/common/ProtocolParser.pm:241
_get_session            0     /home/daniel/dev/maatkit/common/ProtocolParser.pm:169
_packet_from_client     0     /home/daniel/dev/maatkit/common/ProtocolParser.pm:220
_packet_from_server     0     /home/daniel/dev/maatkit/common/ProtocolParser.pm:216
_parse_packet           0     /home/daniel/dev/maatkit/common/ProtocolParser.pm:106
fail_session            0   0 /home/daniel/dev/maatkit/common/ProtocolParser.pm:259
make_event              0   0 /home/daniel/dev/maatkit/common/ProtocolParser.pm:224
parse_event             0   0 /home/daniel/dev/maatkit/common/ProtocolParser.pm:52 
timestamp_diff          0   0 /home/daniel/dev/maatkit/common/ProtocolParser.pm:280
uncompress_data         0   0 /home/daniel/dev/maatkit/common/ProtocolParser.pm:300


ProtocolParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  3   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 1;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use ProtocolParser;
               1                                  3   
               1                                 17   
15             1                    1            12   use MaatkitTest;
               1                                  5   
               1                                 40   
16                                                    
17             1                                  9   my $protocol = new ProtocolParser();
18             1                                  8   isa_ok($protocol, 'ProtocolParser');
19                                                    
20                                                    # #############################################################################
21                                                    # Done.
22                                                    # #############################################################################
23             1                                  3   exit;


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
BEGIN          1 ProtocolParser.t:10
BEGIN          1 ProtocolParser.t:11
BEGIN          1 ProtocolParser.t:12
BEGIN          1 ProtocolParser.t:14
BEGIN          1 ProtocolParser.t:15
BEGIN          1 ProtocolParser.t:4 
BEGIN          1 ProtocolParser.t:9 


