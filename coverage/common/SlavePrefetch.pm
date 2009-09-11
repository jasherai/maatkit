---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlavePrefetch.pm   50.2   25.5   32.0   68.4    n/a  100.0   43.8
Total                          50.2   25.5   32.0   68.4    n/a  100.0   43.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SlavePrefetch.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Sep 11 00:29:43 2009
Finish:       Fri Sep 11 00:29:43 2009

/home/daniel/dev/maatkit/common/SlavePrefetch.pm

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
18                                                    # SlavePrefetch package $Revision: 4683 $
19                                                    # ###########################################################################
20                                                    package SlavePrefetch;
21                                                    
22             1                    1            14   use strict;
               1                                  8   
               1                                 11   
23             1                    1            10   use warnings FATAL => 'all';
               1                                  3   
               1                                 14   
24             1                    1            10   use English qw(-no_match_vars);
               1                                  3   
               1                                 12   
25                                                    
26             1                    1            12   use List::Util qw(min max sum);
               1                                  3   
               1                                 19   
27             1                    1            19   use Time::HiRes qw(gettimeofday);
               1                                  4   
               1                                  9   
28             1                    1            12   use Data::Dumper;
               1                                  4   
               1                                 13   
29                                                    $Data::Dumper::Indent    = 1;
30                                                    $Data::Dumper::Sortkeys  = 1;
31                                                    $Data::Dumper::Quotekeys = 0;
32                                                    
33             1                    1            11   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 14   
34                                                    
35                                                    # Arguments:
36                                                    #   * dbh                Slave dbh
37                                                    #   * oktorun            Callback for early termination
38                                                    #   * callbacks          Arrayref of callbacks to execute valid queries
39                                                    #   * chk_int            Check interval
40                                                    #   * chk_min            Minimum check interval
41                                                    #   * chk_max            Maximum check interval 
42                                                    #   * datadir            datadir system var
43                                                    #   * QueryRewriter      Common module
44                                                    #   * stats_file         (optional) Filename with saved stats
45                                                    #   * have_subqueries    (optional) bool: Yes if MySQL >= 4.1.0
46                                                    #   * offset             # The remaining args are equivalent mk-slave-prefetch
47                                                    #   * window             # options.  Defaults are provided to make testing
48                                                    #   * io-lag             # easier, so they are technically optional.
49                                                    #   * query-sample-size  #
50                                                    #   * max-query-time     #
51                                                    #   * errors             #
52                                                    #   * num-prefix         #
53                                                    #   * print-nonrewritten #
54                                                    #   * regject-regexp     #
55                                                    #   * permit-regexp      #
56                                                    #   * progress           #
57                                                    sub new {
58             1                    1            79      my ( $class, %args ) = @_;
59             1                                 13      my @required_args = qw(dbh oktorun callbacks chk_int chk_min chk_max
60                                                                              datadir QueryRewriter);
61             1                                  7      foreach my $arg ( @required_args ) {
62    ***      8     50                          61         die "I need a $arg argument" unless $args{$arg};
63                                                       }
64    ***      1            50                   10      $args{'offset'}            ||= 128;
65    ***      1            50                    8      $args{'window'}            ||= 4_096;
66    ***      1            50                    7      $args{'io-lag'}            ||= 1_024;
67    ***      1            50                   34      $args{'query-sample-size'} ||= 4;
68    ***      1            50                   10      $args{'max-query-time'}    ||= 1;
69                                                    
70                                                       my $self = {
71                                                          %args, 
72                                                          pos          => 0,
73                                                          next         => 0,
74                                                          last_ts      => 0,
75                                                          slave        => undef,
76                                                          n_events     => 0,
77                                                          last_chk     => 0,
78                                                          stats        => {},
79                                                          query_stats  => {},
80                                                          query_errors => {},
81                                                          callbacks    => {
82                                                             show_slave_status => sub {
83    ***      0                    0             0               my ( $dbh ) = @_;
84    ***      0                                  0               return $dbh->selectrow_hashref("SHOW SLAVE STATUS");
85                                                             }, 
86             1                                 64            wait_for_master   => \&_wait_for_master,
87                                                          },
88                                                       };
89                                                    
90                                                       # Pre-init saved stats from file.
91    ***      1     50                          10      init_stats($self->{stats}, $args{stats_file}, $args{'query-sample-size'})
92                                                          if $args{stats_file};
93                                                    
94             1                                 25      return bless $self, $class;
95                                                    }
96                                                    
97                                                    sub set_callbacks {
98             2                    2           173      my ( $self, %callbacks ) = @_;
99             2                                 24      foreach my $func ( keys %callbacks ) {
100   ***      2     50                          24         die "Callback $func does not exist"
101                                                            unless exists $self->{callbacks}->{$func};
102            2                                 16         $self->{callbacks}->{$func} = $callbacks{$func};
103            2                                 33         MKDEBUG && _d('Set new callback for', $func);
104                                                      }
105            2                                 17      return;
106                                                   }
107                                                   
108                                                   sub init_stats {
109   ***      0                    0             0      my ( $stats, $file, $n_samples ) = @_;
110   ***      0      0                           0      open my $fh, "<", $file or die $OS_ERROR;
111   ***      0                                  0      MKDEBUG && _d('Reading saved stats from', $file);
112   ***      0                                  0      my ($type, $rest);
113   ***      0                                  0      while ( my $line = <$fh> ) {
114   ***      0                                  0         ($type, $rest) = $line =~ m/^# (query|stats): (.*)$/;
115   ***      0      0                           0         next unless $type;
116   ***      0      0                           0         if ( $type eq 'query' ) {
117   ***      0                                  0            $stats->{$rest} = { seen => 1, samples => [] };
118                                                         }
119                                                         else {
120   ***      0                                  0            my ( $seen, $exec, $sum, $avg )
121                                                               = $rest =~ m/seen=(\S+) exec=(\S+) sum=(\S+) avg=(\S+)/;
122   ***      0      0                           0            if ( $seen ) {
123   ***      0                                  0               $stats->{$rest}->{samples}
124   ***      0                                  0                  = [ map { $avg } (1..$n_samples) ];
125   ***      0                                  0               $stats->{$rest}->{avg} = $avg;
126                                                            }
127                                                         }
128                                                      }
129   ***      0      0                           0      close $fh or die $OS_ERROR;
130   ***      0                                  0      return;
131                                                   }
132                                                   
133                                                   sub incr_stat {
134   ***      0                    0             0      my ( $self, $stat ) = @_;
135   ***      0                                  0      $self->{stats}->{$stat}++;
136   ***      0                                  0      return;
137                                                   }
138                                                   
139                                                   sub get_stats {
140   ***      0                    0             0      my ( $self ) = @_;
141   ***      0                                  0      return $self->{stats}, $self->{query_stats}, $self->{query_errors};
142                                                   }
143                                                   
144                                                   # Arguments:
145                                                   #   * tmpdir         Dir for mysqlbinlog --local-load
146                                                   #   * datadir        (optional) Datadir for file
147                                                   #   * start_pos      (optional) Start pos for mysqlbinlog --start-pos
148                                                   #   * file           (optional) Name of the relay log
149                                                   #   * mysqlbinlog    (optional) mysqlbinlog command (if not in PATH)
150                                                   sub open_relay_log {
151            1                    1            32      my ( $self, %args ) = @_;
152            1                                 10      my @required_args = qw(tmpdir);
153            1                                 11      foreach my $arg ( @required_args ) {
154   ***      1     50                          23         die "I need a $arg argument" unless $args{$arg};
155                                                      }
156            1                                  8      my ($tmpdir)    = @args{@required_args};
157   ***      1            33                   12      my $datadir     = $args{datadir}     || $self->{datadir};
158   ***      1            33                    9      my $start_pos   = $args{start_pos}   || $self->{slave}->{pos};
159   ***      1            33                    8      my $file        = $args{file}        || $self->{slave}->{file};
160   ***      1            50                   24      my $mysqlbinlog = $args{mysqlbinlog} || 'mysqlbinlog';
161                                                   
162                                                      # Ensure file is readable
163   ***      1     50                          32      if ( !-r "$datadir/$file" ) {
164   ***      0                                  0         die "Relay log $datadir/$file does not exist or is not readable";
165                                                      }
166                                                   
167            1                                 20      my $cmd = "$mysqlbinlog -l $tmpdir "
168                                                              . " --start-pos=$start_pos $datadir/$file"
169                                                              . (MKDEBUG ? ' 2>/dev/null' : '');
170            1                                  5      MKDEBUG && _d('Opening relay log:', $cmd);
171                                                   
172   ***      1     50                        2156      open my $fh, "$cmd |" or die $OS_ERROR; # Succeeds even on error
173   ***      1     50                          54      if ( $CHILD_ERROR ) {
174   ***      0                                  0         die "$cmd returned exit code " . ($CHILD_ERROR >> 8)
175                                                            . '.  Try running the command manually or using MKDEBUG=1' ;
176                                                      }
177            1                                 29      $self->{cmd} = $cmd;
178            1                                 15      $self->{stats}->{mysqlbinlog}++;
179            1                                 73      return $fh;
180                                                   }
181                                                   
182                                                   sub close_relay_log {
183            1                    1          6987      my ( $self, $fh ) = @_;
184            1                                 14      MKDEBUG && _d('Closing relay log');
185                                                      # Unfortunately, mysqlbinlog does NOT like me to close the pipe
186                                                      # before reading all data from it.  It hangs and prints angry
187                                                      # messages about a closed file.  So I'll find the mysqlbinlog
188                                                      # process created by the open() and kill it.
189            1                              34597      my $procs = `ps -eaf | grep mysqlbinlog | grep -v grep`;
190            1                                 25      my $cmd   = $self->{cmd};
191            1                                  7      MKDEBUG && _d($procs);
192   ***      1     50                         107      if ( my ($line) = $procs =~ m/^(.*?\d\s+$cmd)$/m ) {
193   ***      0                                  0         chomp $line;
194   ***      0                                  0         MKDEBUG && _d($line);
195   ***      0      0                           0         if ( my ( $proc ) = $line =~ m/(\d+)/ ) {
196   ***      0                                  0            MKDEBUG && _d('Will kill process', $proc);
197   ***      0                                  0            kill(15, $proc);
198                                                         }
199                                                      }
200                                                      else {
201            1                                 88         warn "Cannot find mysqlbinlog command in ps";
202                                                      }
203   ***      1     50                          69      if ( !close($fh) ) {
204   ***      0      0                           0         if ( $OS_ERROR ) {
205   ***      0                                  0            warn "Error closing mysqlbinlog pipe: $OS_ERROR\n";
206                                                         }
207                                                         else {
208   ***      0                                  0            MKDEBUG && _d('Exit status', $CHILD_ERROR,'from mysqlbinlog');
209                                                         }
210                                                      }
211            1                                 43      return;
212                                                   }
213                                                   
214                                                   # This is the private interface, called internally to update
215                                                   # $self->{slave}.  The public interface to return $self->{slave}
216                                                   # is get_slave_status().
217                                                   sub _get_slave_status {
218            5                    5            35      my ( $self, $callback ) = @_;
219            5                                 36      $self->{stats}->{show_slave_status}++;
220                                                   
221                                                      # Remember to $dbh->{FetchHashKeyName} = 'NAME_lc'.
222                                                   
223            5                                 34      my $show_slave_status = $self->{callbacks}->{show_slave_status};
224            5                                 46      my $status            = $show_slave_status->($self->{dbh}); 
225   ***      5     50     33                  134      if ( !$status || !%$status ) {
226   ***      0                                  0         die "No output from SHOW SLAVE STATUS";
227                                                      }
228   ***      5     50     50                  228      my %status = (
229                                                         running => ($status->{slave_sql_running} || '') eq 'Yes',
230                                                         file    => $status->{relay_log_file},
231                                                         pos     => $status->{relay_log_pos},
232                                                                    # If the slave SQL thread is executing from the same log the
233                                                                    # I/O thread is reading from, in general (except when the
234                                                                    # master or slave starts a new binlog or relay log) we can
235                                                                    # tell how many bytes the SQL thread lags the I/O thread.
236                                                         lag   => $status->{master_log_file} eq $status->{relay_master_log_file}
237                                                                ? $status->{read_master_log_pos} - $status->{exec_master_log_pos}
238                                                                : 0,
239                                                         mfile => $status->{relay_master_log_file},
240                                                         mpos  => $status->{exec_master_log_pos},
241                                                      );
242                                                   
243            5                                 42      $self->{slave}    = \%status;
244            5                                 42      $self->{last_chk} = $self->{n_events};
245            5                                 17      MKDEBUG && _d('Slave status:', Dumper($self->{slave}));
246            5                                 36      return;
247                                                   }
248                                                   
249                                                   # Public interface for returning the current/last slave status.
250                                                   sub get_slave_status {
251            1                    1             6      my ( $self ) = @_;
252            1                                 33      return $self->{slave};
253                                                   }
254                                                   
255                                                   sub slave_is_running {
256            6                    6            94      my ( $self ) = @_;
257            6                                 84      return $self->{slave}->{running};
258                                                   }
259                                                   
260                                                   sub get_interval {
261            1                    1             6      my ( $self ) = @_;
262            1                                 16      return $self->{n_events}, $self->{last_chk};
263                                                   }
264                                                   
265                                                   sub get_pipeline_pos {
266            3                    3            34      my ( $self ) = @_;
267            3                                 58      return $self->{pos}, $self->{next}, $self->{last_ts};
268                                                   }
269                                                   
270                                                   sub set_pipeline_pos {
271           12                   12           100      my ( $self, $pos, $next, $ts ) = @_;
272   ***     12     50     33                  206      die "pos must be >= 0"  unless defined $pos && $pos >= 0;
273   ***     12     50     33                  162      die "next must be >= 0" unless defined $pos && $pos >= 0;
274           12                                 67      $self->{pos}     = $pos;
275           12                                 60      $self->{next}    = $next;
276           12           100                  150      $self->{last_ts} = $ts || 0;  # undef same as zero
277           12                                 38      MKDEBUG && _d('Set pipeline pos', @_);
278           12                                 62      return;
279                                                   }
280                                                   
281                                                   sub reset_pipeline_pos {
282            1                    1             7      my ( $self ) = @_;
283            1                                  7      $self->{pos}     = 0; # Current position we're reading in relay log.
284            1                                  6      $self->{next}    = 0; # Start of next relay log event.
285            1                                  5      $self->{last_ts} = 0; # Last seen timestamp.
286            1                                  3      MKDEBUG && _d('Reset pipeline');
287            1                                  4      return;
288                                                   }
289                                                   
290                                                   sub pipeline_event {
291   ***      0                    0             0      my ( $self, $event ) = @_;
292                                                   
293                                                      # Update pos and next.
294   ***      0                                  0      $self->{stats}->{events}++;
295   ***      0      0                           0      $self->{pos}  = $event->{offset} if $event->{offset};
296   ***      0             0                    0      $self->{next} = max($self->{next}, $self->{pos} + ($event->{end} || 0));
297   ***      0                                  0      MKDEBUG && _d('pos:', $self->{pos}, 'next:', $self->{next},
298                                                         'slave pos:', $self->{slave}->{pos});
299                                                   
300   ***      0      0      0                    0      if ( $self->{progress}
301                                                           && $self->{stats}->{events} % $self->{progress} == 0 ) {
302   ***      0                                  0         print("# $self->{slave}->{file} $self->{pos} ",
303   ***      0                                  0            join(' ', map { "$_:$self->{stats}->{$_}" } keys %{$self->{stats}}),
      ***      0                                  0   
304                                                            "\n");
305                                                      }
306                                                   
307                                                      # Time to check the slave's status again?
308                                                      # TODO: factor this, too
309   ***      0      0      0                    0      if ( $self->{pos} > $self->{slave}->{pos}
310                                                           && ($self->{n_events} - $self->{last_chk}) >= $self->{chk_int} ) {
311   ***      0                                  0         $self->_get_slave_status();
312   ***      0      0                           0         $self->{chk_int} = $self->{pos} <= $self->{slave_pos}  
313                                                            ? max($self->{chk_min}, $self->{chk_int} / 2) # slave caught up to us
314                                                            : min($self->{chk_max}, $self->{chk_int} * 2);
315                                                      }
316                                                   
317                                                      # We're in the window if we're not behind the slave or too far
318                                                      # ahead of it.  We can only execute queries while in the window.
319   ***      0      0                           0      return unless $self->_in_window();
320                                                   
321   ***      0      0                           0      if ( $event->{arg} ) {
322                                                         # If it's a LOAD DATA INFILE, rm the temp file.
323                                                         # TODO: maybe this should still be before _in_window()?
324   ***      0      0                           0         if ( my ($file) = $event->{arg} =~ m/INFILE ('[^']+')/i ) {
325   ***      0                                  0            $self->{stats}->{load_data_infile}++;
326   ***      0      0                           0            if ( !unlink($file) ) {
327   ***      0                                  0               MKDEBUG && _d('Could not unlink', $file);
328   ***      0                                  0               $self->{stats}->{could_not_unlink}++;
329                                                            }
330   ***      0                                  0            return;
331                                                         }
332                                                   
333   ***      0                                  0         my ($query, $fingerprint) = prepare_query($event->{arg});
334   ***      0      0                           0         if ( !$query ) {
335   ***      0                                  0            MKDEBUG && _d('Failed to prepare query, skipping');
336   ***      0                                  0            return;
337                                                         }
338                                                   
339                                                         # Do it!
340   ***      0                                  0         $self->{stats}->{do_query}++;
341   ***      0                                  0         foreach my $callback ( @{$self->{callbacks}} ) {
      ***      0                                  0   
342   ***      0                                  0            $callback->($query, $fingerprint);
343                                                         }
344                                                      }
345                                                   
346   ***      0                                  0      return;
347                                                   }
348                                                   
349                                                   sub get_window {
350            2                    2            14      my ( $self ) = @_;
351            2                                 29      return $self->{offset}, $self->{window};
352                                                   }
353                                                   
354                                                   sub set_window {
355            2                    2            18      my ( $self, $offset, $window ) = @_;
356   ***      2     50                          15      die "offset must be > 0" unless $offset;
357   ***      2     50                          12      die "window must be > 0" unless $window;
358            2                                 13      $self->{offset} = $offset;
359            2                                 11      $self->{window} = $window;
360            2                                  7      MKDEBUG && _d('Set window', @_);
361            2                                 17      return;
362                                                   }
363                                                   
364                                                   # Returns false if the current pos is out of the window,
365                                                   # else returns true.  This "throttles" pipeline_event()
366                                                   # so that it only executes queries when we're in the window.
367                                                   sub _in_window {
368            3                    3            34      my ( $self ) = @_;
369            3                                 12      MKDEBUG && _d('pos:', $self->{pos},
370                                                         'slave pos:', $self->{slave}->{pos},
371                                                         'master pos', $self->{slave}->{mpos});
372                                                   
373                                                      # We're behind the slave which is bad because we're no
374                                                      # longer prefetching.  We need to stop pipelining events
375                                                      # and start skipping them until we're back in the window
376                                                      # or ahead of the slave.
377            3    100                          20      return 0 unless $self->_far_enough_ahead();
378                                                   
379                                                      # We're ahead of the slave, but check that we're not too
380                                                      # far ahead, i.e. out of the window or too close to the end
381                                                      # of the binlog.  If we are, wait for the slave to catch up
382                                                      # then go back to pipelining events.
383            2                                 16      my $wait_for_master = $self->{callbacks}->{wait_for_master};
384            2                                 38      my %wait_args       = (
385                                                         dbh       => $self->{dbh},
386                                                         mfile     => $self->{slave}->{mfile},
387                                                         until_pos => $self->next_window(),
388                                                      );
389   ***      2            66                   20      while ( $self->{oktorun}->(only_if_slave_is_running => 1,
                           100                        
390                                                                                 slave_is_running => $self->slave_is_running())
391                                                              && ($self->_too_far_ahead() || $self->_too_close_to_io()) )
392                                                      {
393                                                         # Don't increment stats if the slave didn't catch up while we
394                                                         # slept.
395            2                                 14         $self->{stats}->{master_pos_wait}++;
396   ***      2     50                          18         if ( $wait_for_master->(%wait_args) > 0 ) {
397   ***      2     50                          64            if ( $self->_too_far_ahead() ) {
      ***             0                               
398            2                                 13               $self->{stats}->{too_far_ahead}++;
399                                                            }
400                                                            elsif ( $self->_too_close_to_io() ) {
401   ***      0                                  0               $self->{stats}->{too_close_to_io_thread}++;
402                                                            }
403                                                         }
404                                                         else {
405   ***      0                                  0            MKDEBUG && _d('SQL thread did not advance');
406                                                         }
407            2                                 14         $self->_get_slave_status();
408                                                      }
409                                                   
410            2                                 22      MKDEBUG && _d('In window, pos', $self->{pos},
411                                                         'slave pos', $self->{slave}->{pos}, 'master pos', $self->{slave}->{mpos},
412                                                         'interation', $self->{n_events});
413            2                                 23      return 1;
414                                                   }
415                                                   
416                                                   # Whether we are slave pos+offset ahead of the slave.
417                                                   sub _far_enough_ahead {
418            7                    7            44      my ( $self ) = @_;
419            7    100                          97      if ( $self->{pos} < $self->{slave}->{pos} + $self->{offset} ) {
420            3                                 10         MKDEBUG && _d($self->{pos}, 'is not',
421                                                            $self->{offset}, 'ahead of', $self->{slave}->{pos});
422            3                                 20         $self->{stats}->{not_far_enough_ahead}++;
423            3                                 39         return 0;
424                                                      }
425            4                                 32      return 1;
426                                                   }
427                                                   
428                                                   # Whether we are slave pos+offset+window ahead of the slave.
429                                                   sub _too_far_ahead {
430            9                    9            94      my ( $self ) = @_;
431            9    100                         119      my $too_far =
432                                                         $self->{pos}
433                                                            > $self->{slave}->{pos} + $self->{offset} + $self->{window} ? 1 : 0;
434            9                                 30      MKDEBUG && _d('pos', $self->{pos}, 'too far ahead of',
435                                                         'slave pos', $self->{slave}->{pos}, ':', $too_far ? 'yes' : 'no');
436            9                                 95      return $too_far;
437                                                   }
438                                                   
439                                                   # Whether we are too close to where the I/O thread is writing.
440                                                   sub _too_close_to_io {
441            1                    1             7      my ( $self ) = @_;
442   ***      1            33                   26      my $too_close= $self->{slave}->{lag}
443                                                         && $self->{pos}
444                                                            >= $self->{slave}->{pos} + $self->{slave}->{lag} - $self->{'io-lag'};
445            1                                  3      MKDEBUG && _d('pos', $self->{pos},
446                                                         'too close to I/O thread pos', $self->{slave}->{pos}, '+',
447                                                         $self->{slave}->{lag}, ':', $too_close ? 'yes' : 'no');
448            1                                 15      return $too_close;
449                                                   }
450                                                   
451                                                   sub _wait_for_master {
452   ***      0                    0             0      my ( %args ) = @_;
453   ***      0                                  0      my @required_args = qw(dbh mfile until_pos wait timeout);
454   ***      0                                  0      foreach my $arg ( @required_args ) {
455   ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
456                                                      }
457   ***      0             0                    0      my $timeout = $args{timeout} || 1;
458   ***      0                                  0      my ($dbh, $mfile, $until_pos) = @args{@required_args};
459   ***      0                                  0      my $sql = "SELECT COALESCE(MASTER_POS_WAIT('$mfile',$until_pos,$timeout),0)";
460   ***      0                                  0      MKDEBUG && _d('Waiting for master:', $sql);
461   ***      0                                  0      my $start = gettimeofday();
462   ***      0                                  0      my ($events) = $dbh->selectrow_array($sql);
463   ***      0                                  0      MKDEBUG && _d('Waited', (gettimeofday - $start), 'and got', $events);
464   ***      0                                  0      return $events;
465                                                   }
466                                                   
467                                                   # The next window is pos-offset, assuming that master/slave pos
468                                                   # are behind pos.  If we get too far ahead, we need to wait until
469                                                   # the slave is right behind us.  The closest it can get is offset
470                                                   # bytes behind us, thus pos-offset.  However, the return value is
471                                                   # in terms of master pos because this is what MASTER_POS_WAIT()
472                                                   # expects.
473                                                   sub next_window {
474            3                    3            21      my ( $self ) = @_;
475            3                                 39      my $next_window = 
476                                                            $self->{slave}->{mpos}                    # master pos
477                                                            + ($self->{pos} - $self->{slave}->{pos})  # how far we're ahead
478                                                            - $self->{offset};                        # offset;
479            3                                  9      MKDEBUG && _d('master pos:', $self->{slave}->{mpos},
480                                                         'next window:', $next_window,
481                                                         'bytes left:', $next_window - $self->{offset} - $self->{slave}->{mpos});
482            3                                 59      return $next_window;
483                                                   }
484                                                   
485                                                   # Does everything necessary to make the given DMS query ready for
486                                                   # pipelined execution in pipeline_event() if the query can/should
487                                                   # be executed.  If yes, then the prepared query and its fingerprint
488                                                   # are returned; else nothing is returned.
489                                                   sub prepare_query {
490   ***      0                    0             0      my ( $self, $query ) = @_;
491   ***      0                                  0      my $qr = $self->{QueryRewriter};
492                                                   
493   ***      0                                  0      $query = $qr->strip_comments($query);
494                                                   
495   ***      0      0                           0      return unless $self->query_is_allowed($query);
496                                                   
497                                                      # If the event is SET TIMESTAMP and we've already set the
498                                                      # timestamp to that value, skip it.
499   ***      0      0                           0      if ( (my ($new_ts) = $query =~ m/SET TIMESTAMP=(\d+)/) ) {
500   ***      0      0                           0         if ( $new_ts == $self->{last_ts} ) {
501   ***      0                                  0            MKDEBUG && _d('Already saw timestamp', $new_ts);
502   ***      0                                  0            $self->{stats}->{same_timestamp}++;
503   ***      0                                  0            return;
504                                                         }
505                                                         else {
506   ***      0                                  0            $self->{last_ts} = $new_ts;
507                                                         }
508                                                      }
509                                                   
510   ***      0                                  0      my $select = $qr->convert_to_select($query);
511   ***      0      0                           0      if ( $select !~ m/\A\s*(?:set|select|use)/i ) {
512   ***      0                                  0         MKDEBUG && _d('Cannot rewrite query as SELECT');
513   ***      0      0                           0         _d($query) if $self->{'print-nonrewritten'};
514   ***      0                                  0         $self->{stats}->{query_not_rewritten}++;
515   ***      0                                  0         return;
516                                                      }
517                                                   
518   ***      0                                  0      my $fingerprint = $qr->fingerprint(
519                                                         $select,
520                                                         { prefixes => $self->{'num-prefix'} }
521                                                      );
522   ***      0      0                           0      if ((my $avg = $self->__get_avg($fingerprint))>=$self->{'max-query-time'}) {
523                                                         # The query's average execution time is longer than the specified
524                                                         # limit, so we skip it and wait for the slave to execute it.  We
525                                                         # do *not* want to skip it and continue pipelining events because
526                                                         # the caches that we would warm while executing ahead of the slave
527                                                         # would become cold once the slave hits this slow query and stalls.
528                                                         # In general, we want to always be just a little ahead of the slave
529                                                         # so it executes in the warmth of our pipelining wake.
530   ***      0                                  0         MKDEBUG && _d('Avg time', $avg, 'too long for', $fingerprint);
531   ***      0                                  0         $self->{stats}->{query_too_long}++;
532                                                   
533   ***      0                                  0         my $wait_for_master = $self->{callbacks}->{wait_for_master};
534   ***      0                                  0         my $until_pos = 
535                                                               $self->{slave}->{mpos}                    # master pos
536                                                               + ($self->{pos} - $self->{slave}->{pos})  # how far we're ahead
537                                                               + 1;                                      # 1 past this query
538   ***      0                                  0         my %wait_args       = (
539                                                            dbh       => $self->{dbh},
540                                                            mfile     => $self->{slave}->{mfile},
541                                                            until_pos => $until_pos,
542                                                         );
543   ***      0                                  0         $self->{stats}->{master_pos_wait}++;
544   ***      0                                  0         $wait_for_master->(%wait_args);
545                                                   
546   ***      0                                  0         $self->_get_slave_status();
547   ***      0                                  0         return;
548                                                      }
549                                                   
550                                                      # Safeguard as much as possible against enormous result sets.
551   ***      0                                  0      $select = $qr->convert_select_list($select);
552   ***      0      0      0                    0      if ( $self->{have_subqueries}
553                                                           && !$self->__have_seen_query($fingerprint) ) {
554                                                         # Wrap in a "derived table," but only if it hasn't been
555                                                         # seen before.  This way, really short queries avoid the
556                                                         # overhead of creating the temp table.
557   ***      0                                  0         $select = $qr->wrap_in_derived($select);
558                                                      }
559                                                   
560                                                      # Success: the prepared and converted query ready to execute.
561   ***      0                                  0      return $select, $fingerprint;
562                                                   }
563                                                   
564                                                   sub query_is_allowed {
565           12                   12           202      my ( $self, $query ) = @_;
566   ***     12     50                          79      return unless $query;
567           12    100                         147      if ( $query =~ m/\A\s*(?:set [t@]|use|insert|update|delete|replace)/i ) {
568            7                                 42         my $reject_regexp = $self->{reject_regexp};
569            7                                 35         my $permit_regexp = $self->{permit_regexp};
570   ***      7     50     33                  155         if ( ($reject_regexp && $query =~ m/$reject_regexp/o)
      ***                   33                        
      ***                   33                        
571                                                              || ($permit_regexp && $query !~ m/$permit_regexp/o) )
572                                                         {
573   ***      0                                  0            MKDEBUG && _d('Query is not allowed, fails permit/reject regexp');
574   ***      0                                  0            $self->{stats}->{event_filtered_out}++;
575   ***      0                                  0            return 0;
576                                                         }
577            7                                 75         return 1;
578                                                      }
579            5                                 19      MKDEBUG && _d('Query is not allowed, wrong type');
580            5                                 35      $self->{stats}->{event_not_allowed}++;
581            5                                 51      return 0;
582                                                   }
583                                                   
584                                                   sub exec {
585   ***      0                    0                    my ( $self, $query, $fingerprint ) = @_;
586   ***      0                                         eval {
587   ***      0                                            my $start = gettimeofday();
588   ***      0                                            $self->{dbh}->do($query);
589   ***      0                                            $self->__store_avg($fingerprint, gettimeofday() - $start);
590                                                      };
591   ***      0      0                                  if ( $EVAL_ERROR ) {
592   ***      0                                            $self->{stats}->{query_error}++;
593   ***      0      0      0                              if ( (($self->{errors} || 0) == 2) || MKDEBUG ) {
      ***             0      0                        
      ***                    0                        
594   ***      0                                               _d($EVAL_ERROR);
595   ***      0                                               _d('SQL was:', $query);
596                                                         }
597                                                         elsif ( ($self->{errors} || 0) == 1 ) {
598   ***      0                                               $self->{query_errors}->{$fingerprint}++;
599                                                         }
600                                                      }
601   ***      0                                         return;
602                                                   }
603                                                   
604                                                   # The average is weighted so we don't quit trying a statement when we have
605                                                   # only a few samples.  So if we want to collect 16 samples and the first one
606                                                   # is huge, it will be weighted as 1/16th of its size.
607                                                   sub __store_avg {
608   ***      0                    0                    my ( $self, $query, $time ) = @_;
609   ***      0                                         MKDEBUG && _d('Execution time:', $query, $time);
610   ***      0                                         my $query_stats = $self->{query_stats}->{$query};
611   ***      0             0                           my $samples     = $query_stats->{samples} ||= [];
612   ***      0                                         push @$samples, $time;
613   ***      0      0                                  if ( @$samples > $self->{'query-sample-size'} ) {
614   ***      0                                            shift @$samples;
615                                                      }
616   ***      0                                         $query_stats->{avg} = sum(@$samples) / $self->{'query-sample-size'};
617   ***      0                                         $query_stats->{exec}++;
618   ***      0                                         $query_stats->{sum} += $time;
619   ***      0                                         MKDEBUG && _d('Average time:', $query_stats->{avg});
620   ***      0                                         return;
621                                                   }
622                                                   
623                                                   sub __have_seen_query {
624   ***      0                    0                    my ( $self, $query ) = @_;
625   ***      0                                         return $self->{query_stats}->{$query}->{seen};
626                                                   }
627                                                   
628                                                   sub __get_avg {
629   ***      0                    0                    my ( $self, $query ) = @_;
630   ***      0                                         $self->{query_stats}->{$query}->{seen}++;
631   ***      0             0                           return $self->{query_stats}->{$query}->{avg} || 0;
632                                                   }
633                                                   
634                                                   sub _d {
635   ***      0                    0                    my ($package, undef, $line) = caller 0;
636   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
637   ***      0                                              map { defined $_ ? $_ : 'undef' }
638                                                           @_;
639   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
640                                                   }
641                                                   
642                                                   1;
643                                                   
644                                                   # ###########################################################################
645                                                   # End SlavePrefetch package
646                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
62    ***     50      0      8   unless $args{$arg}
91    ***     50      0      1   if $args{'stats_file'}
100   ***     50      0      2   unless exists $$self{'callbacks'}{$func}
110   ***      0      0      0   unless open my $fh, '<', $file
115   ***      0      0      0   unless $type
116   ***      0      0      0   if ($type eq 'query') { }
122   ***      0      0      0   if ($seen)
129   ***      0      0      0   unless close $fh
154   ***     50      0      1   unless $args{$arg}
163   ***     50      0      1   if (not -r "$datadir/$file")
172   ***     50      0      1   unless open my $fh, "$cmd |"
173   ***     50      0      1   if ($CHILD_ERROR)
192   ***     50      0      1   if (my($line) = $procs =~ /^(.*?\d\s+$cmd)$/m) { }
195   ***      0      0      0   if (my($proc) = $line =~ /(\d+)/)
203   ***     50      0      1   if (not close $fh)
204   ***      0      0      0   if ($OS_ERROR) { }
225   ***     50      0      5   if (not $status or not %$status)
228   ***     50      5      0   $$status{'master_log_file'} eq $$status{'relay_master_log_file'} ? :
272   ***     50      0     12   unless defined $pos and $pos >= 0
273   ***     50      0     12   unless defined $pos and $pos >= 0
295   ***      0      0      0   if $$event{'offset'}
300   ***      0      0      0   if ($$self{'progress'} and $$self{'stats'}{'events'} % $$self{'progress'} == 0)
309   ***      0      0      0   if ($$self{'pos'} > $$self{'slave'}{'pos'} and $$self{'n_events'} - $$self{'last_chk'} >= $$self{'chk_int'})
312   ***      0      0      0   $$self{'pos'} <= $$self{'slave_pos'} ? :
319   ***      0      0      0   unless $self->_in_window
321   ***      0      0      0   if ($$event{'arg'})
324   ***      0      0      0   if (my($file) = $$event{'arg'} =~ /INFILE ('[^']+')/i)
326   ***      0      0      0   if (not unlink $file)
334   ***      0      0      0   if (not $query)
356   ***     50      0      2   unless $offset
357   ***     50      0      2   unless $window
377          100      1      2   unless $self->_far_enough_ahead
396   ***     50      2      0   if (&$wait_for_master(%wait_args) > 0) { }
397   ***     50      2      0   if ($self->_too_far_ahead) { }
      ***      0      0      0   elsif ($self->_too_close_to_io) { }
419          100      3      4   if ($$self{'pos'} < $$self{'slave'}{'pos'} + $$self{'offset'})
431          100      5      4   $$self{'pos'} > $$self{'slave'}{'pos'} + $$self{'offset'} + $$self{'window'} ? :
455   ***      0      0      0   unless $args{$arg}
495   ***      0      0      0   unless $self->query_is_allowed($query)
499   ***      0      0      0   if (my($new_ts) = $query =~ /SET TIMESTAMP=(\d+)/)
500   ***      0      0      0   if ($new_ts == $$self{'last_ts'}) { }
511   ***      0      0      0   if (not $select =~ /\A\s*(?:set|select|use)/i)
513   ***      0      0      0   if $$self{'print-nonrewritten'}
522   ***      0      0      0   if ((my $avg = $self->__get_avg($fingerprint)) >= $$self{'max-query-time'})
552   ***      0      0      0   if ($$self{'have_subqueries'} and not $self->__have_seen_query($fingerprint))
566   ***     50      0     12   unless $query
567          100      7      5   if ($query =~ /\A\s*(?:set [t\@]|use|insert|update|delete|replace)/i)
570   ***     50      0      7   if ($reject_regexp and $query =~ /$reject_regexp/o or $permit_regexp and not $query =~ /$permit_regexp/o)
591   ***      0      0      0   if ($EVAL_ERROR)
593   ***      0      0      0   if (($$self{'errors'} || 0) == 2 or undef) { }
      ***      0      0      0   elsif (($$self{'errors'} || 0) == 1) { }
613   ***      0      0      0   if (@$samples > $$self{'query-sample-size'})
636   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
272   ***     33      0      0     12   defined $pos and $pos >= 0
273   ***     33      0      0     12   defined $pos and $pos >= 0
300   ***      0      0      0      0   $$self{'progress'} and $$self{'stats'}{'events'} % $$self{'progress'} == 0
309   ***      0      0      0      0   $$self{'pos'} > $$self{'slave'}{'pos'} and $$self{'n_events'} - $$self{'last_chk'} >= $$self{'chk_int'}
389          100      1      1      2   $$self{'oktorun'}('only_if_slave_is_running', 1, 'slave_is_running', $self->slave_is_running) and $self->_too_far_ahead || $self->_too_close_to_io
442   ***     33      0      1      0   $$self{'slave'}{'lag'} && $$self{'pos'} >= $$self{'slave'}{'pos'} + $$self{'slave'}{'lag'} - $$self{'io-lag'}
552   ***      0      0      0      0   $$self{'have_subqueries'} and not $self->__have_seen_query($fingerprint)
570   ***     33      7      0      0   $reject_regexp and $query =~ /$reject_regexp/o
      ***     33      7      0      0   $permit_regexp and not $query =~ /$permit_regexp/o

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
64    ***     50      0      1   $args{'offset'} ||= 128
65    ***     50      0      1   $args{'window'} ||= 4096
66    ***     50      0      1   $args{'io-lag'} ||= 1024
67    ***     50      0      1   $args{'query-sample-size'} ||= 4
68    ***     50      0      1   $args{'max-query-time'} ||= 1
160   ***     50      0      1   $args{'mysqlbinlog'} || 'mysqlbinlog'
228   ***     50      5      0   $$status{'slave_sql_running'} || ''
276          100      1     11   $ts || 0
296   ***      0      0      0   $$event{'end'} || 0
457   ***      0      0      0   $args{'timeout'} || 1
593   ***      0      0      0   $$self{'errors'} || 0
      ***      0      0      0   ($$self{'errors'} || 0) == 2 or undef
      ***      0      0      0   $$self{'errors'} || 0
611   ***      0      0      0   $$query_stats{'samples'} ||= []
631   ***      0      0      0   $$self{'query_stats'}{$query}{'avg'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
157   ***     33      1      0      0   $args{'datadir'} || $$self{'datadir'}
158   ***     33      1      0      0   $args{'start_pos'} || $$self{'slave'}{'pos'}
159   ***     33      1      0      0   $args{'file'} || $$self{'slave'}{'file'}
225   ***     33      0      0      5   not $status or not %$status
389   ***     66      2      0      1   $self->_too_far_ahead || $self->_too_close_to_io
570   ***     33      0      0      7   $reject_regexp and $query =~ /$reject_regexp/o or $permit_regexp and not $query =~ /$permit_regexp/o


Covered Subroutines
-------------------

Subroutine         Count Location                                            
------------------ ----- ----------------------------------------------------
BEGIN                  1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:22 
BEGIN                  1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:23 
BEGIN                  1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:24 
BEGIN                  1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:26 
BEGIN                  1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:27 
BEGIN                  1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:28 
BEGIN                  1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:33 
_far_enough_ahead      7 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:418
_get_slave_status      5 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:218
_in_window             3 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:368
_too_close_to_io       1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:441
_too_far_ahead         9 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:430
close_relay_log        1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:183
get_interval           1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:261
get_pipeline_pos       3 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:266
get_slave_status       1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:251
get_window             2 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:350
new                    1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:58 
next_window            3 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:474
open_relay_log         1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:151
query_is_allowed      12 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:565
reset_pipeline_pos     1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:282
set_callbacks          2 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:98 
set_pipeline_pos      12 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:271
set_window             2 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:355
slave_is_running       6 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:256

Uncovered Subroutines
---------------------

Subroutine         Count Location                                            
------------------ ----- ----------------------------------------------------
__ANON__               0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:83 
__get_avg              0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:629
__have_seen_query      0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:624
__store_avg            0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:608
_d                     0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:635
_wait_for_master       0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:452
exec                   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:585
get_stats              0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:140
incr_stat              0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:134
init_stats             0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:109
pipeline_event         0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:291
prepare_query          0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:490


