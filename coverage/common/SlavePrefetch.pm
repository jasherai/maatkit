---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlavePrefetch.pm   68.7   45.4   44.0   80.0    n/a  100.0   61.3
Total                          68.7   45.4   44.0   80.0    n/a  100.0   61.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SlavePrefetch.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Sep 15 15:07:10 2009
Finish:       Tue Sep 15 15:07:10 2009

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
18                                                    # SlavePrefetch package $Revision: 4686 $
19                                                    # ###########################################################################
20                                                    package SlavePrefetch;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                 12   
25                                                    
26             1                    1             7   use List::Util qw(min max sum);
               1                                  2   
               1                                 11   
27             1                    1            11   use Time::HiRes qw(gettimeofday);
               1                                  3   
               1                                  5   
28             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  8   
29                                                    $Data::Dumper::Indent    = 1;
30                                                    $Data::Dumper::Sortkeys  = 1;
31                                                    $Data::Dumper::Quotekeys = 0;
32                                                    
33             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                  9   
34                                                    
35                                                    # Arguments:
36                                                    #   * dbh                Slave dbh
37                                                    #   * oktorun            Callback for early termination
38                                                    #   * chk_int            Check interval
39                                                    #   * chk_min            Minimum check interval
40                                                    #   * chk_max            Maximum check interval 
41                                                    #   * datadir            datadir system var
42                                                    #   * QueryRewriter      Common module
43                                                    #   * stats_file         (optional) Filename with saved stats
44                                                    #   * have_subqueries    (optional) bool: Yes if MySQL >= 4.1.0
45                                                    #   * offset             # The remaining args are equivalent mk-slave-prefetch
46                                                    #   * window             # options.  Defaults are provided to make testing
47                                                    #   * io-lag             # easier, so they are technically optional.
48                                                    #   * query-sample-size  #
49                                                    #   * max-query-time     #
50                                                    #   * errors             #
51                                                    #   * num-prefix         #
52                                                    #   * print-nonrewritten #
53                                                    #   * regject-regexp     #
54                                                    #   * permit-regexp      #
55                                                    #   * progress           #
56                                                    sub new {
57             1                    1            35      my ( $class, %args ) = @_;
58             1                                  7      my @required_args = qw(dbh oktorun chk_int chk_min chk_max
59                                                                              datadir QueryRewriter);
60             1                                  5      foreach my $arg ( @required_args ) {
61    ***      7     50                          31         die "I need a $arg argument" unless $args{$arg};
62                                                       }
63    ***      1            50                    6      $args{'offset'}            ||= 128;
64    ***      1            50                    5      $args{'window'}            ||= 4_096;
65    ***      1            50                    6      $args{'io-lag'}            ||= 1_024;
66    ***      1            50                   24      $args{'query-sample-size'} ||= 4;
67    ***      1            50                    5      $args{'max-query-time'}    ||= 1;
68                                                    
69                                                       my $self = {
70                                                          %args, 
71                                                          pos          => 0,
72                                                          next         => 0,
73                                                          last_ts      => 0,
74                                                          slave        => undef,
75                                                          n_events     => 0,
76                                                          last_chk     => 0,
77                                                          stats        => {},
78                                                          query_stats  => {},
79                                                          query_errors => {},
80                                                          callbacks    => {
81                                                             show_slave_status => sub {
82    ***      0                    0             0               my ( $dbh ) = @_;
83    ***      0                                  0               return $dbh->selectrow_hashref("SHOW SLAVE STATUS");
84                                                             }, 
85             1                                 31            wait_for_master   => \&_wait_for_master,
86                                                          },
87                                                       };
88                                                    
89                                                       # Pre-init saved stats from file.
90    ***      1     50                           7      init_stats($self->{stats}, $args{stats_file}, $args{'query-sample-size'})
91                                                          if $args{stats_file};
92                                                    
93             1                                 14      return bless $self, $class;
94                                                    }
95                                                    
96                                                    sub set_callbacks {
97             2                    2            94      my ( $self, %callbacks ) = @_;
98             2                                 12      foreach my $func ( keys %callbacks ) {
99    ***      2     50                          15         die "Callback $func does not exist"
100                                                            unless exists $self->{callbacks}->{$func};
101            2                                  8         $self->{callbacks}->{$func} = $callbacks{$func};
102            2                                 17         MKDEBUG && _d('Set new callback for', $func);
103                                                      }
104            2                                 11      return;
105                                                   }
106                                                   
107                                                   sub init_stats {
108   ***      0                    0             0      my ( $stats, $file, $n_samples ) = @_;
109   ***      0      0                           0      open my $fh, "<", $file or die $OS_ERROR;
110   ***      0                                  0      MKDEBUG && _d('Reading saved stats from', $file);
111   ***      0                                  0      my ($type, $rest);
112   ***      0                                  0      while ( my $line = <$fh> ) {
113   ***      0                                  0         ($type, $rest) = $line =~ m/^# (query|stats): (.*)$/;
114   ***      0      0                           0         next unless $type;
115   ***      0      0                           0         if ( $type eq 'query' ) {
116   ***      0                                  0            $stats->{$rest} = { seen => 1, samples => [] };
117                                                         }
118                                                         else {
119   ***      0                                  0            my ( $seen, $exec, $sum, $avg )
120                                                               = $rest =~ m/seen=(\S+) exec=(\S+) sum=(\S+) avg=(\S+)/;
121   ***      0      0                           0            if ( $seen ) {
122   ***      0                                  0               $stats->{$rest}->{samples}
123   ***      0                                  0                  = [ map { $avg } (1..$n_samples) ];
124   ***      0                                  0               $stats->{$rest}->{avg} = $avg;
125                                                            }
126                                                         }
127                                                      }
128   ***      0      0                           0      close $fh or die $OS_ERROR;
129   ***      0                                  0      return;
130                                                   }
131                                                   
132                                                   sub incr_stat {
133   ***      0                    0             0      my ( $self, $stat ) = @_;
134   ***      0                                  0      $self->{stats}->{$stat}++;
135   ***      0                                  0      return;
136                                                   }
137                                                   
138                                                   sub get_stats {
139   ***      0                    0             0      my ( $self ) = @_;
140   ***      0                                  0      return $self->{stats}, $self->{query_stats}, $self->{query_errors};
141                                                   }
142                                                   
143                                                   # Arguments:
144                                                   #   * tmpdir         Dir for mysqlbinlog --local-load
145                                                   #   * datadir        (optional) Datadir for file
146                                                   #   * start_pos      (optional) Start pos for mysqlbinlog --start-pos
147                                                   #   * file           (optional) Name of the relay log
148                                                   #   * mysqlbinlog    (optional) mysqlbinlog command (if not in PATH)
149                                                   sub open_relay_log {
150            1                    1            22      my ( $self, %args ) = @_;
151            1                                  7      my @required_args = qw(tmpdir);
152            1                                  8      foreach my $arg ( @required_args ) {
153   ***      1     50                          14         die "I need a $arg argument" unless $args{$arg};
154                                                      }
155            1                                  7      my ($tmpdir)    = @args{@required_args};
156   ***      1            33                    6      my $datadir     = $args{datadir}     || $self->{datadir};
157   ***      1            33                    5      my $start_pos   = $args{start_pos}   || $self->{slave}->{pos};
158   ***      1            33                    4      my $file        = $args{file}        || $self->{slave}->{file};
159   ***      1            50                   20      my $mysqlbinlog = $args{mysqlbinlog} || 'mysqlbinlog';
160                                                   
161                                                      # Ensure file is readable
162   ***      1     50                          22      if ( !-r "$datadir/$file" ) {
163   ***      0                                  0         die "Relay log $datadir/$file does not exist or is not readable";
164                                                      }
165                                                   
166            1                                 16      my $cmd = "$mysqlbinlog -l $tmpdir "
167                                                              . " --start-pos=$start_pos $datadir/$file"
168                                                              . (MKDEBUG ? ' 2>/dev/null' : '');
169            1                                  2      MKDEBUG && _d('Opening relay log:', $cmd);
170                                                   
171   ***      1     50                        4385      open my $fh, "$cmd |" or die $OS_ERROR; # Succeeds even on error
172   ***      1     50                          26      if ( $CHILD_ERROR ) {
173   ***      0                                  0         die "$cmd returned exit code " . ($CHILD_ERROR >> 8)
174                                                            . '.  Try running the command manually or using MKDEBUG=1' ;
175                                                      }
176            1                                 18      $self->{cmd} = $cmd;
177            1                                  9      $self->{stats}->{mysqlbinlog}++;
178            1                                 50      return $fh;
179                                                   }
180                                                   
181                                                   sub close_relay_log {
182            1                    1          3744      my ( $self, $fh ) = @_;
183            1                                  5      MKDEBUG && _d('Closing relay log');
184                                                      # Unfortunately, mysqlbinlog does NOT like me to close the pipe
185                                                      # before reading all data from it.  It hangs and prints angry
186                                                      # messages about a closed file.  So I'll find the mysqlbinlog
187                                                      # process created by the open() and kill it.
188            1                              15182      my $procs = `ps -eaf | grep mysqlbinlog | grep -v grep`;
189            1                                 15      my $cmd   = $self->{cmd};
190            1                                  5      MKDEBUG && _d($procs);
191   ***      1     50                          63      if ( my ($line) = $procs =~ m/^(.*?\d\s+$cmd)$/m ) {
192   ***      0                                  0         chomp $line;
193   ***      0                                  0         MKDEBUG && _d($line);
194   ***      0      0                           0         if ( my ( $proc ) = $line =~ m/(\d+)/ ) {
195   ***      0                                  0            MKDEBUG && _d('Will kill process', $proc);
196   ***      0                                  0            kill(15, $proc);
197                                                         }
198                                                      }
199                                                      else {
200            1                                 42         warn "Cannot find mysqlbinlog command in ps";
201                                                      }
202   ***      1     50                          38      if ( !close($fh) ) {
203   ***      0      0                           0         if ( $OS_ERROR ) {
204   ***      0                                  0            warn "Error closing mysqlbinlog pipe: $OS_ERROR\n";
205                                                         }
206                                                         else {
207   ***      0                                  0            MKDEBUG && _d('Exit status', $CHILD_ERROR,'from mysqlbinlog');
208                                                         }
209                                                      }
210            1                                 26      return;
211                                                   }
212                                                   
213                                                   # Returns true if it's time to _get_slave_status() again.
214                                                   sub _check_slave_status {
215            8                    8            29      my ( $self ) = @_;
216                                                      return
217            8    100    100                  119         $self->{pos} > $self->{slave}->{pos}
218                                                         && ($self->{n_events} - $self->{last_chk}) >= $self->{chk_int} ? 1 : 0;
219                                                   }
220                                                   
221                                                   # Returns the next check interval.
222                                                   sub _get_next_chk_int {
223            2                    2            18      my ( $self ) = @_;
224   ***      2     50                          13      if ( $self->{pos} <= $self->{slave}->{pos} ) {
225                                                         # The slave caught up to us so do another check sooner than usual.
226   ***      0                                  0         return max($self->{chk_min}, $self->{chk_int} / 2);
227                                                      }
228                                                      else {
229                                                         # We're ahead of the slave so wait a little longer until the next check.
230            2                                 18         return min($self->{chk_max}, $self->{chk_int} * 2);
231                                                      }
232                                                   }
233                                                   
234                                                   # This is the private interface, called internally to update
235                                                   # $self->{slave}.  The public interface to return $self->{slave}
236                                                   # is get_slave_status().
237                                                   sub _get_slave_status {
238           12                   12            59      my ( $self, $callback ) = @_;
239           12                                 47      $self->{stats}->{show_slave_status}++;
240                                                   
241                                                      # Remember to $dbh->{FetchHashKeyName} = 'NAME_lc'.
242                                                   
243           12                                 46      my $show_slave_status = $self->{callbacks}->{show_slave_status};
244           12                                 60      my $status            = $show_slave_status->($self->{dbh}); 
245   ***     12     50     33                  171      if ( !$status || !%$status ) {
246   ***      0                                  0         die "No output from SHOW SLAVE STATUS";
247                                                      }
248   ***     12     50     50                  229      my %status = (
249                                                         running => ($status->{slave_sql_running} || '') eq 'Yes',
250                                                         file    => $status->{relay_log_file},
251                                                         pos     => $status->{relay_log_pos},
252                                                                    # If the slave SQL thread is executing from the same log the
253                                                                    # I/O thread is reading from, in general (except when the
254                                                                    # master or slave starts a new binlog or relay log) we can
255                                                                    # tell how many bytes the SQL thread lags the I/O thread.
256                                                         lag   => $status->{master_log_file} eq $status->{relay_master_log_file}
257                                                                ? $status->{read_master_log_pos} - $status->{exec_master_log_pos}
258                                                                : 0,
259                                                         mfile => $status->{relay_master_log_file},
260                                                         mpos  => $status->{exec_master_log_pos},
261                                                      );
262                                                   
263           12                                 57      $self->{slave}    = \%status;
264           12                                 59      $self->{last_chk} = $self->{n_events};
265           12                                 25      MKDEBUG && _d('Slave status:', Dumper($self->{slave}));
266           12                                 45      return;
267                                                   }
268                                                   
269                                                   # Public interface for returning the current/last slave status.
270                                                   sub get_slave_status {
271            1                    1             4      my ( $self ) = @_;
272            1                                 25      return $self->{slave};
273                                                   }
274                                                   
275                                                   sub slave_is_running {
276           15                   15            70      my ( $self ) = @_;
277           15                                100      return $self->{slave}->{running};
278                                                   }
279                                                   
280                                                   sub get_interval {
281            1                    1             4      my ( $self ) = @_;
282            1                                 10      return $self->{n_events}, $self->{last_chk};
283                                                   }
284                                                   
285                                                   sub get_pipeline_pos {
286            3                    3            18      my ( $self ) = @_;
287            3                                 27      return $self->{pos}, $self->{next}, $self->{last_ts};
288                                                   }
289                                                   
290                                                   sub set_pipeline_pos {
291           13                   13            65      my ( $self, $pos, $next, $ts ) = @_;
292   ***     13     50     33                  113      die "pos must be >= 0"  unless defined $pos && $pos >= 0;
293   ***     13     50     33                   97      die "next must be >= 0" unless defined $pos && $pos >= 0;
294           13                                 44      $self->{pos}     = $pos;
295           13                                 41      $self->{next}    = $next;
296           13           100                   85      $self->{last_ts} = $ts || 0;  # undef same as zero
297           13                                 34      MKDEBUG && _d('Set pipeline pos', @_);
298           13                                 43      return;
299                                                   }
300                                                   
301                                                   sub reset_pipeline_pos {
302            2                    2            11      my ( $self ) = @_;
303            2                                  8      $self->{pos}     = 0; # Current position we're reading in relay log.
304            2                                  7      $self->{next}    = 0; # Start of next relay log event.
305            2                                  7      $self->{last_ts} = 0; # Last seen timestamp.
306            2                                  5      MKDEBUG && _d('Reset pipeline');
307            2                                  8      return;
308                                                   }
309                                                   
310                                                   sub pipeline_event {
311            8                    8           159      my ( $self, $event, @callbacks ) = @_;
312                                                   
313                                                      # Update pos and next.
314            8                                 31      $self->{n_events}++;
315   ***      8     50                          50      $self->{pos}  = $event->{offset} if $event->{offset};
316   ***      8            50                   83      $self->{next} = max($self->{next},$self->{pos}+($event->{end_log_pos} || 0));
317                                                   
318   ***      8     50     33                   45      if ( $self->{progress}
319                                                           && $self->{stats}->{events} % $self->{progress} == 0 ) {
320   ***      0                                  0         print("# $self->{slave}->{file} $self->{pos} ",
321   ***      0                                  0            join(' ', map { "$_:$self->{stats}->{$_}" } keys %{$self->{stats}}),
      ***      0                                  0   
322                                                            "\n");
323                                                      }
324                                                   
325                                                      # Time to check the slave's status again?
326            8    100                          34      if ( $self->_check_slave_status() ) { 
327            1                                  2         MKDEBUG && _d('Checking slave status at interval', $self->{n_events});
328            1                                  6         $self->_get_slave_status();
329            1                                  4         $self->{chk_int} = $self->_get_next_chk_int();
330            1                                  3         MKDEBUG && _d('Next check interval:', $self->{chk_int});
331                                                      }
332                                                   
333                                                      # We're in the window if we're not behind the slave or too far
334                                                      # ahead of it.  We can only execute queries while in the window.
335            8    100                          33      return unless $self->_in_window();
336                                                   
337   ***      4     50                          20      if ( $event->{arg} ) {
338                                                         # If it's a LOAD DATA INFILE, rm the temp file.
339                                                         # TODO: maybe this should still be before _in_window()?
340   ***      4     50                          29         if ( my ($file) = $event->{arg} =~ m/INFILE ('[^']+')/i ) {
341   ***      0                                  0            $self->{stats}->{load_data_infile}++;
342   ***      0      0                           0            if ( !unlink($file) ) {
343   ***      0                                  0               MKDEBUG && _d('Could not unlink', $file);
344   ***      0                                  0               $self->{stats}->{could_not_unlink}++;
345                                                            }
346   ***      0                                  0            return;
347                                                         }
348                                                   
349            4                                 19         my ($query, $fingerprint) = $self->prepare_query($event->{arg});
350   ***      4     50                          18         if ( !$query ) {
351   ***      0                                  0            MKDEBUG && _d('Failed to prepare query, skipping');
352   ***      0                                  0            return;
353                                                         }
354                                                   
355                                                         # Do it!
356            4                                 17         $self->{stats}->{do_query}++;
357            4                                 16         foreach my $callback ( @callbacks ) {
358            4                                 18            $callback->($query, $fingerprint);
359                                                         }
360                                                      }
361                                                   
362            4                                 61      return;
363                                                   }
364                                                   
365                                                   sub get_window {
366            2                    2             8      my ( $self ) = @_;
367            2                                 19      return $self->{offset}, $self->{window};
368                                                   }
369                                                   
370                                                   sub set_window {
371            4                    4            34      my ( $self, $offset, $window ) = @_;
372   ***      4     50                          17      die "offset must be > 0" unless $offset;
373   ***      4     50                          15      die "window must be > 0" unless $window;
374            4                                 16      $self->{offset} = $offset;
375            4                                 12      $self->{window} = $window;
376            4                                 10      MKDEBUG && _d('Set window', @_);
377            4                                 12      return;
378                                                   }
379                                                   
380                                                   # Returns false if the current pos is out of the window,
381                                                   # else returns true.  This "throttles" pipeline_event()
382                                                   # so that it only executes queries when we're in the window.
383                                                   sub _in_window {
384           11                   11            42      my ( $self ) = @_;
385           11                                 26      MKDEBUG && _d('Checking window, pos:', $self->{pos},
386                                                         'next', $self->{next},
387                                                         'slave pos:', $self->{slave}->{pos},
388                                                         'master pos', $self->{slave}->{mpos});
389                                                   
390                                                      # We're behind the slave which is bad because we're no
391                                                      # longer prefetching.  We need to stop pipelining events
392                                                      # and start skipping them until we're back in the window
393                                                      # or ahead of the slave.
394           11    100                          44      return 0 unless $self->_far_enough_ahead();
395                                                   
396                                                      # We're ahead of the slave, but check that we're not too
397                                                      # far ahead, i.e. out of the window or too close to the end
398                                                      # of the binlog.  If we are, wait for the slave to catch up
399                                                      # then go back to pipelining events.
400            7                                 28      my $wait_for_master = $self->{callbacks}->{wait_for_master};
401            7                                 48      my %wait_args       = (
402                                                         dbh       => $self->{dbh},
403                                                         mfile     => $self->{slave}->{mfile},
404                                                         until_pos => $self->next_window(),
405                                                      );
406            7                                 21      my $oktorun = 1;
407   ***      7            66                   34      while ( ($oktorun = $self->{oktorun}->(only_if_slave_is_running => 1,
                           100                        
408                                                                                 slave_is_running => $self->slave_is_running()))
409                                                              && ($self->_too_far_ahead() || $self->_too_close_to_io()) )
410                                                      {
411                                                         # Don't increment stats if the slave didn't catch up while we
412                                                         # slept.
413            2                                  9         $self->{stats}->{master_pos_wait}++;
414   ***      2     50                          11         if ( $wait_for_master->(%wait_args) > 0 ) {
415   ***      2     50                          38            if ( $self->_too_far_ahead() ) {
      ***             0                               
416            2                                  9               $self->{stats}->{too_far_ahead}++;
417                                                            }
418                                                            elsif ( $self->_too_close_to_io() ) {
419   ***      0                                  0               $self->{stats}->{too_close_to_io_thread}++;
420                                                            }
421                                                         }
422                                                         else {
423   ***      0                                  0            MKDEBUG && _d('SQL thread did not advance');
424                                                         }
425            2                                  8         $self->_get_slave_status();
426                                                      }
427                                                   
428            7    100                          46      if ( !$oktorun ) {
429            2                                  7         MKDEBUG && _d('Not oktorun while waiting for event', $self->{n_events});
430            2                                 15         return 0;
431                                                      }
432                                                   
433            5                                 12      MKDEBUG && _d('Event', $self->{n_events}, 'is in the window');
434            5                                 27      return 1;
435                                                   }
436                                                   
437                                                   # Whether we are slave pos+offset ahead of the slave.
438                                                   sub _far_enough_ahead {
439           15                   15            53      my ( $self ) = @_;
440           15    100                         105      if ( $self->{pos} < $self->{slave}->{pos} + $self->{offset} ) {
441            6                                 13         MKDEBUG && _d($self->{pos}, 'is not',
442                                                            $self->{offset}, 'ahead of', $self->{slave}->{pos});
443            6                                 25         $self->{stats}->{not_far_enough_ahead}++;
444            6                                 56         return 0;
445                                                      }
446            9                                 38      return 1;
447                                                   }
448                                                   
449                                                   # Whether we are slave pos+offset+window ahead of the slave.
450                                                   sub _too_far_ahead {
451           13                   13           101      my ( $self ) = @_;
452           13    100                          92      my $too_far =
453                                                         $self->{pos}
454                                                            > $self->{slave}->{pos} + $self->{offset} + $self->{window} ? 1 : 0;
455           13                                 28      MKDEBUG && _d('pos', $self->{pos}, 'too far ahead of',
456                                                         'slave pos', $self->{slave}->{pos}, ':', $too_far ? 'yes' : 'no');
457           13                                 75      return $too_far;
458                                                   }
459                                                   
460                                                   # Whether we are too close to where the I/O thread is writing.
461                                                   sub _too_close_to_io {
462            5                    5            21      my ( $self ) = @_;
463   ***      5            33                   64      my $too_close= $self->{slave}->{lag}
464                                                         && $self->{pos}
465                                                            >= $self->{slave}->{pos} + $self->{slave}->{lag} - $self->{'io-lag'};
466            5                                 12      MKDEBUG && _d('pos', $self->{pos},
467                                                         'too close to I/O thread pos', $self->{slave}->{pos}, '+',
468                                                         $self->{slave}->{lag}, ':', $too_close ? 'yes' : 'no');
469            5                                 37      return $too_close;
470                                                   }
471                                                   
472                                                   sub _wait_for_master {
473   ***      0                    0             0      my ( %args ) = @_;
474   ***      0                                  0      my @required_args = qw(dbh mfile until_pos wait timeout);
475   ***      0                                  0      foreach my $arg ( @required_args ) {
476   ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
477                                                      }
478   ***      0             0                    0      my $timeout = $args{timeout} || 1;
479   ***      0                                  0      my ($dbh, $mfile, $until_pos) = @args{@required_args};
480   ***      0                                  0      my $sql = "SELECT COALESCE(MASTER_POS_WAIT('$mfile',$until_pos,$timeout),0)";
481   ***      0                                  0      MKDEBUG && _d('Waiting for master:', $sql);
482   ***      0                                  0      my $start = gettimeofday();
483   ***      0                                  0      my ($events) = $dbh->selectrow_array($sql);
484   ***      0                                  0      MKDEBUG && _d('Waited', (gettimeofday - $start), 'and got', $events);
485   ***      0                                  0      return $events;
486                                                   }
487                                                   
488                                                   # The next window is pos-offset, assuming that master/slave pos
489                                                   # are behind pos.  If we get too far ahead, we need to wait until
490                                                   # the slave is right behind us.  The closest it can get is offset
491                                                   # bytes behind us, thus pos-offset.  However, the return value is
492                                                   # in terms of master pos because this is what MASTER_POS_WAIT()
493                                                   # expects.
494                                                   sub next_window {
495            8                    8            28      my ( $self ) = @_;
496            8                                 54      my $next_window = 
497                                                            $self->{slave}->{mpos}                    # master pos
498                                                            + ($self->{pos} - $self->{slave}->{pos})  # how far we're ahead
499                                                            - $self->{offset};                        # offset;
500            8                                 17      MKDEBUG && _d('Next window, master pos:', $self->{slave}->{mpos},
501                                                         'next window:', $next_window,
502                                                         'bytes left:', $next_window - $self->{offset} - $self->{slave}->{mpos});
503            8                                 49      return $next_window;
504                                                   }
505                                                   
506                                                   # Does everything necessary to make the given DMS query ready for
507                                                   # pipelined execution in pipeline_event() if the query can/should
508                                                   # be executed.  If yes, then the prepared query and its fingerprint
509                                                   # are returned; else nothing is returned.
510                                                   sub prepare_query {
511           14                   14            83      my ( $self, $query ) = @_;
512           14                                 55      my $qr = $self->{QueryRewriter};
513                                                   
514           14                                 61      $query = $qr->strip_comments($query);
515                                                   
516   ***     14     50                          55      return unless $self->query_is_allowed($query);
517                                                   
518                                                      # If the event is SET TIMESTAMP and we've already set the
519                                                      # timestamp to that value, skip it.
520           14    100                          99      if ( (my ($new_ts) = $query =~ m/SET timestamp=(\d+)/) ) {
521            2                                  4         MKDEBUG && _d('timestamp query:', $query);
522            2    100                          12         if ( $new_ts == $self->{last_ts} ) {
523            1                                  2            MKDEBUG && _d('Already saw timestamp', $new_ts);
524            1                                  5            $self->{stats}->{same_timestamp}++;
525            1                                  5            return;
526                                                         }
527                                                         else {
528            1                                  4            $self->{last_ts} = $new_ts;
529                                                         }
530                                                      }
531                                                   
532           13                                 63      my $select = $qr->convert_to_select($query);
533   ***     13     50                          78      if ( $select !~ m/\A\s*(?:set|select|use)/i ) {
534   ***      0                                  0         MKDEBUG && _d('Cannot rewrite query as SELECT:', $query);
535   ***      0      0                           0         _d($query) if $self->{'print-nonrewritten'};
536   ***      0                                  0         $self->{stats}->{query_not_rewritten}++;
537   ***      0                                  0         return;
538                                                      }
539                                                   
540           13                                 92      my $fingerprint = $qr->fingerprint(
541                                                         $select,
542                                                         { prefixes => $self->{'num-prefix'} }
543                                                      );
544                                                   
545                                                      # If the query's average execution time is longer than the specified
546                                                      # limit, we wait for the slave to execute it then skip it ourself.
547                                                      # We do *not* want to skip it and continue pipelining events because
548                                                      # the caches that we would warm while executing ahead of the slave
549                                                      # would become cold once the slave hits this slow query and stalls.
550                                                      # In general, we want to always be just a little ahead of the slave
551                                                      # so it executes in the warmth of our pipelining wake.
552           13    100                          73      if ((my $avg = $self->get_avg($fingerprint)) >= $self->{'max-query-time'}) {
553            1                                  3         MKDEBUG && _d('Avg time', $avg, 'too long for', $fingerprint);
554            1                                 13         $self->{stats}->{query_too_long}++;
555            1                                  6         return $self->_wait_skip_query($avg);
556                                                      }
557                                                   
558                                                      # Safeguard as much as possible against enormous result sets.
559           12                                 54      $select = $qr->convert_select_list($select);
560                                                   
561                                                      # The following block is/was meant to prevent huge insert/select queries
562                                                      # from slowing us, and maybe the network, down by wrapping the query like
563                                                      # select 1 from (<query>) as x limit 1.  This way, the huge result set of
564                                                      # the query is not transmitted but the query itself is still executed.
565                                                      # If someone has a similar problem, we can re-enable (and fix) this block.
566                                                      # The bug here is that by this point the query is already seen so the if()
567                                                      # is always false.
568                                                      # if ( $self->{have_subqueries} && !$self->have_seen($fingerprint) ) {
569                                                      #    # Wrap in a "derived table," but only if it hasn't been
570                                                      #    # seen before.  This way, really short queries avoid the
571                                                      #    # overhead of creating the temp table.
572                                                      #    # $select = $qr->wrap_in_derived($select);
573                                                      # }
574                                                   
575                                                      # Success: the prepared and converted query ready to execute.
576           12                                 80      return $select, $fingerprint;
577                                                   }
578                                                   
579                                                   # Waits for the slave to catch up, execute the query at our current
580                                                   # pos, and then move on.  This is usually used to wait-skip slow queries,
581                                                   # so the wait arg is important.  If a slow query takes 3 seconds, and
582                                                   # it takes the slave another 1 second to reach our pos, then we can
583                                                   # either wait_for_master 4 times (1s each) or just wait twice, 3s each
584                                                   # time but the 2nd time will return as soon as the slave has moved
585                                                   # past the slow query.
586                                                   sub _wait_skip_query {
587            1                    1             5      my ( $self, $wait ) = @_;
588            1                                  5      my $wait_for_master = $self->{callbacks}->{wait_for_master};
589            1                                  7      my $until_pos = 
590                                                            $self->{slave}->{mpos}                    # master pos
591                                                            + ($self->{pos} - $self->{slave}->{pos})  # how far we're ahead
592                                                            + 1;                                      # 1 past this query
593            1                                 10      my %wait_args       = (
594                                                         dbh       => $self->{dbh},
595                                                         mfile     => $self->{slave}->{mfile},
596                                                         until_pos => $until_pos,
597                                                         timeout   => $wait,
598                                                      );
599            1                                 28      my $start = gettimeofday();
600   ***      1            66                    5      while ( $self->{oktorun}->(only_if_slave_is_running => 1,
601                                                                                 slave_is_running => $self->slave_is_running())
602                                                              && ($self->{slave}->{pos} <= $self->{pos}) ) {
603            3                                 44         $self->{stats}->{master_pos_wait}++;
604            3                                 15         $wait_for_master->(%wait_args);
605            3                                 37         $self->_get_slave_status();
606            3                                 13         MKDEBUG && _d('Bytes until slave reaches wait-skip query:',
607                                                            $self->{pos} - $self->{slave}->{pos});
608                                                      }
609            1                                 12      MKDEBUG && _d('Waited', (gettimeofday - $start), 'to skip query');
610            1                                  5      $self->_get_slave_status();
611            1                                  9      return;
612                                                   }
613                                                   
614                                                   sub query_is_allowed {
615           26                   26           153      my ( $self, $query ) = @_;
616   ***     26     50                          96      return unless $query;
617           26    100                         162      if ( $query =~ m/\A\s*(?:set [t@]|use|insert|update|delete|replace)/i ) {
618           21                                 71         my $reject_regexp = $self->{reject_regexp};
619           21                                 66         my $permit_regexp = $self->{permit_regexp};
620   ***     21     50     33                  208         if ( ($reject_regexp && $query =~ m/$reject_regexp/o)
      ***                   33                        
      ***                   33                        
621                                                              || ($permit_regexp && $query !~ m/$permit_regexp/o) )
622                                                         {
623   ***      0                                  0            MKDEBUG && _d('Query is not allowed, fails permit/reject regexp');
624   ***      0                                  0            $self->{stats}->{event_filtered_out}++;
625   ***      0                                  0            return 0;
626                                                         }
627           21                                 97         return 1;
628                                                      }
629            5                                 12      MKDEBUG && _d('Query is not allowed, wrong type');
630            5                                 20      $self->{stats}->{event_not_allowed}++;
631            5                                 27      return 0;
632                                                   }
633                                                   
634                                                   sub exec {
635   ***      0                    0             0      my ( $self, $query, $fingerprint ) = @_;
636   ***      0                                  0      eval {
637   ***      0                                  0         my $start = gettimeofday();
638   ***      0                                  0         $self->{dbh}->do($query);
639   ***      0                                  0         $self->__store_avg($fingerprint, gettimeofday() - $start);
640                                                      };
641   ***      0      0                           0      if ( $EVAL_ERROR ) {
642   ***      0                                  0         $self->{stats}->{query_error}++;
643   ***      0      0      0                    0         if ( (($self->{errors} || 0) == 2) || MKDEBUG ) {
      ***             0      0                        
      ***                    0                        
644   ***      0                                  0            _d($EVAL_ERROR);
645   ***      0                                  0            _d('SQL was:', $query);
646                                                         }
647                                                         elsif ( ($self->{errors} || 0) == 1 ) {
648   ***      0                                  0            $self->{query_errors}->{$fingerprint}++;
649                                                         }
650                                                      }
651   ***      0                                  0      return;
652                                                   }
653                                                   
654                                                   # The average is weighted so we don't quit trying a statement when we have
655                                                   # only a few samples.  So if we want to collect 16 samples and the first one
656                                                   # is huge, it will be weighted as 1/16th of its size.
657                                                   sub __store_avg {
658   ***      0                    0             0      my ( $self, $query, $time ) = @_;
659   ***      0                                  0      MKDEBUG && _d('Execution time:', $query, $time);
660   ***      0                                  0      my $query_stats = $self->{query_stats}->{$query};
661   ***      0             0                    0      my $samples     = $query_stats->{samples} ||= [];
662   ***      0                                  0      push @$samples, $time;
663   ***      0      0                           0      if ( @$samples > $self->{'query-sample-size'} ) {
664   ***      0                                  0         shift @$samples;
665                                                      }
666   ***      0                                  0      $query_stats->{avg} = sum(@$samples) / $self->{'query-sample-size'};
667   ***      0                                  0      $query_stats->{exec}++;
668   ***      0                                  0      $query_stats->{sum} += $time;
669   ***      0                                  0      MKDEBUG && _d('Average time:', $query_stats->{avg});
670   ***      0                                  0      return;
671                                                   }
672                                                   
673                                                   sub get_avg {
674           13                   13            56      my ( $self, $fingerprint ) = @_;
675           13                                 80      $self->{query_stats}->{$fingerprint}->{seen}++;
676           13           100                  152      return $self->{query_stats}->{$fingerprint}->{avg} || 0;
677                                                   }
678                                                   
679                                                   sub _d {
680   ***      0                    0                    my ($package, undef, $line) = caller 0;
681   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
682   ***      0                                              map { defined $_ ? $_ : 'undef' }
683                                                           @_;
684   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
685                                                   }
686                                                   
687                                                   1;
688                                                   
689                                                   # ###########################################################################
690                                                   # End SlavePrefetch package
691                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
61    ***     50      0      7   unless $args{$arg}
90    ***     50      0      1   if $args{'stats_file'}
99    ***     50      0      2   unless exists $$self{'callbacks'}{$func}
109   ***      0      0      0   unless open my $fh, '<', $file
114   ***      0      0      0   unless $type
115   ***      0      0      0   if ($type eq 'query') { }
121   ***      0      0      0   if ($seen)
128   ***      0      0      0   unless close $fh
153   ***     50      0      1   unless $args{$arg}
162   ***     50      0      1   if (not -r "$datadir/$file")
171   ***     50      0      1   unless open my $fh, "$cmd |"
172   ***     50      0      1   if ($CHILD_ERROR)
191   ***     50      0      1   if (my($line) = $procs =~ /^(.*?\d\s+$cmd)$/m) { }
194   ***      0      0      0   if (my($proc) = $line =~ /(\d+)/)
202   ***     50      0      1   if (not close $fh)
203   ***      0      0      0   if ($OS_ERROR) { }
217          100      1      7   $$self{'pos'} > $$self{'slave'}{'pos'} && $$self{'n_events'} - $$self{'last_chk'} >= $$self{'chk_int'} ? :
224   ***     50      0      2   if ($$self{'pos'} <= $$self{'slave'}{'pos'}) { }
245   ***     50      0     12   if (not $status or not %$status)
248   ***     50     12      0   $$status{'master_log_file'} eq $$status{'relay_master_log_file'} ? :
292   ***     50      0     13   unless defined $pos and $pos >= 0
293   ***     50      0     13   unless defined $pos and $pos >= 0
315   ***     50      8      0   if $$event{'offset'}
318   ***     50      0      8   if ($$self{'progress'} and $$self{'stats'}{'events'} % $$self{'progress'} == 0)
326          100      1      7   if ($self->_check_slave_status)
335          100      4      4   unless $self->_in_window
337   ***     50      4      0   if ($$event{'arg'})
340   ***     50      0      4   if (my($file) = $$event{'arg'} =~ /INFILE ('[^']+')/i)
342   ***      0      0      0   if (not unlink $file)
350   ***     50      0      4   if (not $query)
372   ***     50      0      4   unless $offset
373   ***     50      0      4   unless $window
394          100      4      7   unless $self->_far_enough_ahead
414   ***     50      2      0   if (&$wait_for_master(%wait_args) > 0) { }
415   ***     50      2      0   if ($self->_too_far_ahead) { }
      ***      0      0      0   elsif ($self->_too_close_to_io) { }
428          100      2      5   if (not $oktorun)
440          100      6      9   if ($$self{'pos'} < $$self{'slave'}{'pos'} + $$self{'offset'})
452          100      5      8   $$self{'pos'} > $$self{'slave'}{'pos'} + $$self{'offset'} + $$self{'window'} ? :
476   ***      0      0      0   unless $args{$arg}
516   ***     50      0     14   unless $self->query_is_allowed($query)
520          100      2     12   if (my($new_ts) = $query =~ /SET timestamp=(\d+)/)
522          100      1      1   if ($new_ts == $$self{'last_ts'}) { }
533   ***     50      0     13   if (not $select =~ /\A\s*(?:set|select|use)/i)
535   ***      0      0      0   if $$self{'print-nonrewritten'}
552          100      1     12   if ((my $avg = $self->get_avg($fingerprint)) >= $$self{'max-query-time'})
616   ***     50      0     26   unless $query
617          100     21      5   if ($query =~ /\A\s*(?:set [t\@]|use|insert|update|delete|replace)/i)
620   ***     50      0     21   if ($reject_regexp and $query =~ /$reject_regexp/o or $permit_regexp and not $query =~ /$permit_regexp/o)
641   ***      0      0      0   if ($EVAL_ERROR)
643   ***      0      0      0   if (($$self{'errors'} || 0) == 2 or undef) { }
      ***      0      0      0   elsif (($$self{'errors'} || 0) == 1) { }
663   ***      0      0      0   if (@$samples > $$self{'query-sample-size'})
681   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
217          100      1      6      1   $$self{'pos'} > $$self{'slave'}{'pos'} && $$self{'n_events'} - $$self{'last_chk'} >= $$self{'chk_int'}
292   ***     33      0      0     13   defined $pos and $pos >= 0
293   ***     33      0      0     13   defined $pos and $pos >= 0
318   ***     33      8      0      0   $$self{'progress'} and $$self{'stats'}{'events'} % $$self{'progress'} == 0
407          100      2      5      2   $oktorun = $$self{'oktorun'}('only_if_slave_is_running', 1, 'slave_is_running', $self->slave_is_running) and $self->_too_far_ahead || $self->_too_close_to_io
463   ***     33      0      5      0   $$self{'slave'}{'lag'} && $$self{'pos'} >= $$self{'slave'}{'pos'} + $$self{'slave'}{'lag'} - $$self{'io-lag'}
600   ***     66      0      1      3   $$self{'oktorun'}('only_if_slave_is_running', 1, 'slave_is_running', $self->slave_is_running) and $$self{'slave'}{'pos'} <= $$self{'pos'}
620   ***     33     21      0      0   $reject_regexp and $query =~ /$reject_regexp/o
      ***     33     21      0      0   $permit_regexp and not $query =~ /$permit_regexp/o

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
63    ***     50      0      1   $args{'offset'} ||= 128
64    ***     50      0      1   $args{'window'} ||= 4096
65    ***     50      0      1   $args{'io-lag'} ||= 1024
66    ***     50      0      1   $args{'query-sample-size'} ||= 4
67    ***     50      0      1   $args{'max-query-time'} ||= 1
159   ***     50      0      1   $args{'mysqlbinlog'} || 'mysqlbinlog'
248   ***     50     12      0   $$status{'slave_sql_running'} || ''
296          100      1     12   $ts || 0
316   ***     50      8      0   $$event{'end_log_pos'} || 0
478   ***      0      0      0   $args{'timeout'} || 1
643   ***      0      0      0   $$self{'errors'} || 0
      ***      0      0      0   ($$self{'errors'} || 0) == 2 or undef
      ***      0      0      0   $$self{'errors'} || 0
661   ***      0      0      0   $$query_stats{'samples'} ||= []
676          100      1     12   $$self{'query_stats'}{$fingerprint}{'avg'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
156   ***     33      1      0      0   $args{'datadir'} || $$self{'datadir'}
157   ***     33      1      0      0   $args{'start_pos'} || $$self{'slave'}{'pos'}
158   ***     33      1      0      0   $args{'file'} || $$self{'slave'}{'file'}
245   ***     33      0      0     12   not $status or not %$status
407   ***     66      2      0      5   $self->_too_far_ahead || $self->_too_close_to_io
620   ***     33      0      0     21   $reject_regexp and $query =~ /$reject_regexp/o or $permit_regexp and not $query =~ /$permit_regexp/o


Covered Subroutines
-------------------

Subroutine          Count Location                                            
------------------- ----- ----------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:22 
BEGIN                   1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:23 
BEGIN                   1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:24 
BEGIN                   1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:26 
BEGIN                   1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:27 
BEGIN                   1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:28 
BEGIN                   1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:33 
_check_slave_status     8 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:215
_far_enough_ahead      15 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:439
_get_next_chk_int       2 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:223
_get_slave_status      12 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:238
_in_window             11 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:384
_too_close_to_io        5 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:462
_too_far_ahead         13 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:451
_wait_skip_query        1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:587
close_relay_log         1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:182
get_avg                13 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:674
get_interval            1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:281
get_pipeline_pos        3 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:286
get_slave_status        1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:271
get_window              2 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:366
new                     1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:57 
next_window             8 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:495
open_relay_log          1 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:150
pipeline_event          8 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:311
prepare_query          14 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:511
query_is_allowed       26 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:615
reset_pipeline_pos      2 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:302
set_callbacks           2 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:97 
set_pipeline_pos       13 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:291
set_window              4 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:371
slave_is_running       15 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:276

Uncovered Subroutines
---------------------

Subroutine          Count Location                                            
------------------- ----- ----------------------------------------------------
__ANON__                0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:82 
__store_avg             0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:658
_d                      0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:680
_wait_for_master        0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:473
exec                    0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:635
get_stats               0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:139
incr_stat               0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:133
init_stats              0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:108


