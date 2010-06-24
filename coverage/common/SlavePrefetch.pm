---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlavePrefetch.pm   77.4   52.6   51.6   88.6    0.0   85.5   66.5
SlavePrefetch.t                98.6   61.1   35.7   92.6    n/a   14.5   93.7
Total                          86.6   53.5   49.5   90.1    0.0  100.0   75.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:34 2010
Finish:       Thu Jun 24 19:36:34 2010

Run:          SlavePrefetch.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:35 2010
Finish:       Thu Jun 24 19:36:37 2010

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
18                                                    # SlavePrefetch package $Revision: 6500 $
19                                                    # ###########################################################################
20                                                    package SlavePrefetch;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                  6   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  7   
               1                                  7   
25                                                    
26             1                    1             6   use List::Util qw(min max sum);
               1                                  2   
               1                                 11   
27             1                    1             9   use Time::HiRes qw(gettimeofday);
               1                                  3   
               1                                  5   
28             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  7   
29                                                    $Data::Dumper::Indent    = 1;
30                                                    $Data::Dumper::Sortkeys  = 1;
31                                                    $Data::Dumper::Quotekeys = 0;
32                                                    
33    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
34                                                    
35                                                    # Arguments:
36                                                    #   * dbh                dbh: slave
37                                                    #   * oktorun            coderef: callback to terminate when waiting for window
38                                                    #   * chk_int            scalar: check interval
39                                                    #   * chk_min            scalar: minimum check interval
40                                                    #   * chk_max            scalar: maximum check interval 
41                                                    #   * QueryRewriter      obj
42                                                    # Optional arguments:
43                                                    #   * TableParser        obj: allows rewrite_query() to rewrite more
44                                                    #   * QueryParser        obj: allows rewrite_query() to rewrite more
45                                                    #   * Quoter             obj: allows rewrite_query() to rewrite more
46                                                    #   * mysqlbinlog        scalar: mysqlbinlog command
47                                                    #   * stats              hashref: stats counter
48                                                    #   * stats_file         scalar filename with saved stats
49                                                    #   * have_subqueries    bool: yes if MySQL >= 4.1.0
50                                                    #   * offset             # The remaining args are equivalent mk-slave-prefetch
51                                                    #   * window             # options.  Defaults are provided to make testing
52                                                    #   * io-lag             # easier, so they are technically optional.
53                                                    #   * query-sample-size  #
54                                                    #   * max-query-time     #
55                                                    #   * errors             #
56                                                    #   * num-prefix         #
57                                                    #   * print-nonrewritten #
58                                                    #   * regject-regexp     #
59                                                    #   * permit-regexp      #
60                                                    #   * progress           #
61                                                    sub new {
62    ***      4                    4      0    153      my ( $class, %args ) = @_;
63             4                                 52      my @required_args = qw(dbh oktorun chk_int chk_min chk_max QueryRewriter);
64             4                                 35      foreach my $arg ( @required_args ) {
65    ***     24     50                         172         die "I need a $arg argument" unless $args{$arg};
66                                                       }
67                                                    
68                                                       my $self = {
69                                                          # Defaults
70                                                          offset              => 128,
71                                                          window              => 4_096,
72                                                          'io-lag'            => 1_024,
73                                                          'query-sample-size' => 4,
74                                                          'max-query-time'    => 1,
75                                                          mysqlbinlog         => 'mysqlbinlog',
76                                                    
77                                                          # Override defaults
78                                                          %args,
79                                                    
80                                                          # Private variables
81                                                          pos          => 0,
82                                                          next         => 0,
83                                                          last_ts      => 0,
84                                                          slave        => undef,
85                                                          last_chk     => 0,
86                                                          query_stats  => {},
87                                                          query_errors => {},
88                                                          tbl_cols     => {},
89                                                          callbacks    => {
90                                                             show_slave_status => sub {
91    ***      0                    0             0               my ( $dbh ) = @_;
92    ***      0                                  0               return $dbh->selectrow_hashref("SHOW SLAVE STATUS");
93                                                             }, 
94                                                             use_db            => sub {
95    ***      0                    0             0               my ( $dbh, $db ) = @_;
96    ***      0                                  0               eval {
97    ***      0                                  0                  MKDEBUG && _d('USE', $db);
98    ***      0                                  0                  $dbh->do("USE `$db`");
99                                                                };
100   ***      0                                  0               MKDEBUG && $EVAL_ERROR && _d($EVAL_ERROR);
101   ***      0                                  0               return;
102                                                            },
103            4                                270            wait_for_master   => \&_wait_for_master,
104                                                         },
105                                                      };
106                                                   
107                                                      # Pre-init saved stats from file.
108   ***      4     50                          51      init_stats($self->{stats}, $args{stats_file}, $args{'query-sample-size'})
109                                                         if $args{stats_file};
110                                                   
111            4                                 64      return bless $self, $class;
112                                                   }
113                                                   
114                                                   sub set_callbacks {
115   ***      4                    4      0     40      my ( $self, %callbacks ) = @_;
116            4                                 32      foreach my $func ( keys %callbacks ) {
117   ***      4     50                          34         die "Callback $func does not exist"
118                                                            unless exists $self->{callbacks}->{$func};
119            4                                 25         $self->{callbacks}->{$func} = $callbacks{$func};
120            4                                 50         MKDEBUG && _d('Set new callback for', $func);
121                                                      }
122            4                                 29      return;
123                                                   }
124                                                   
125                                                   sub init_stats {
126   ***      0                    0      0      0      my ( $stats, $file, $n_samples ) = @_;
127   ***      0      0                           0      open my $fh, "<", $file or die $OS_ERROR;
128   ***      0                                  0      MKDEBUG && _d('Reading saved stats from', $file);
129   ***      0                                  0      my ($type, $rest);
130   ***      0                                  0      while ( my $line = <$fh> ) {
131   ***      0                                  0         ($type, $rest) = $line =~ m/^# (query|stats): (.*)$/;
132   ***      0      0                           0         next unless $type;
133   ***      0      0                           0         if ( $type eq 'query' ) {
134   ***      0                                  0            $stats->{$rest} = { seen => 1, samples => [] };
135                                                         }
136                                                         else {
137   ***      0                                  0            my ( $seen, $exec, $sum, $avg )
138                                                               = $rest =~ m/seen=(\S+) exec=(\S+) sum=(\S+) avg=(\S+)/;
139   ***      0      0                           0            if ( $seen ) {
140   ***      0                                  0               $stats->{$rest}->{samples}
141   ***      0                                  0                  = [ map { $avg } (1..$n_samples) ];
142   ***      0                                  0               $stats->{$rest}->{avg} = $avg;
143                                                            }
144                                                         }
145                                                      }
146   ***      0      0                           0      close $fh or die $OS_ERROR;
147   ***      0                                  0      return;
148                                                   }
149                                                   
150                                                   sub get_stats {
151   ***      1                    1      0      5      my ( $self ) = @_;
152            1                                 11      return $self->{stats}, $self->{query_stats}, $self->{query_errors};
153                                                   }
154                                                   
155                                                   sub reset_stats {
156   ***      0                    0      0      0      my ( $self, %args ) = @_;
157   ***      0      0      0                    0      $self->{stats} = { events => 0, } if $args{all} || $args{stats};
158   ***      0      0      0                    0      $self->{query_stats}  = {}        if $args{all} || $args{query_stats};
159   ***      0      0      0                    0      $self->{query_errors} = {}        if $args{all} || $args{query_errors};
160   ***      0                                  0      return;
161                                                   }
162                                                   
163                                                   
164                                                   # Arguments:
165                                                   #   * relay_log      scalar: full /path/relay-log file name
166                                                   # Optional arguments:
167                                                   #   * tmpdir         (optional) dir for mysqlbinlog --local-load
168                                                   #   * start_pos      (optional) start pos for mysqlbinlog --start-pos
169                                                   sub open_relay_log {
170   ***      1                    1      0     15      my ( $self, %args ) = @_;
171            1                                  6      foreach my $arg ( qw(relay_log) ) {
172   ***      1     50                           9         die "I need a $arg argument" unless $args{$arg};
173                                                      }
174                                                   
175                                                      # Ensure file is readable
176   ***      1     50                          23      if ( !-r $args{relay_log} ) {
177   ***      0                                  0         die "Relay log $args{relay_log} does not exist or is not readable";
178                                                      }
179                                                   
180            1                                 11      my $cmd = $self->_mysqlbinlog_cmd(%args);
181                                                   
182   ***      1     50                        4301      open my $fh, "$cmd |" or die $OS_ERROR; # Succeeds even on error
183   ***      1     50                          24      if ( $CHILD_ERROR ) {
184   ***      0                                  0         die "$cmd returned exit code " . ($CHILD_ERROR >> 8)
185                                                            . '.  Try running the command manually or using MKDEBUG=1' ;
186                                                      }
187            1                                 20      $self->{cmd} = $cmd;
188            1                                  9      $self->{stats}->{mysqlbinlog}++;
189            1                                 48      return $fh;
190                                                   }
191                                                   
192                                                   sub _mysqlbinlog_cmd {
193            2                    2            16      my ( $self, %args ) = @_;
194            2    100                          31      my $cmd = $self->{mysqlbinlog}
      ***            50                               
195                                                              . ($args{tmpdir}    ? " --local-load=$args{tmpdir} "   : '')
196                                                              . ($args{start_pos} ? " --start-pos=$args{start_pos} " : '')
197                                                              . $args{relay_log}
198                                                              . (MKDEBUG ? ' 2>/dev/null' : '');
199            2                                  5      MKDEBUG && _d($cmd);
200            2                                 15      return $cmd;
201                                                   }
202                                                   
203                                                   sub close_relay_log {
204   ***      0                    0      0      0      my ( $self, $fh ) = @_;
205   ***      0                                  0      MKDEBUG && _d('Closing relay log');
206                                                      # Unfortunately, mysqlbinlog does NOT like me to close the pipe
207                                                      # before reading all data from it.  It hangs and prints angry
208                                                      # messages about a closed file.  So I'll find the mysqlbinlog
209                                                      # process created by the open() and kill it.
210   ***      0                                  0      my $procs = `ps -eaf | grep mysqlbinlog | grep -v grep`;
211   ***      0                                  0      my $cmd   = $self->{cmd};
212   ***      0                                  0      MKDEBUG && _d($procs);
213   ***      0      0                           0      if ( my ($line) = $procs =~ m/^(.*?\d\s+$cmd)$/m ) {
214   ***      0                                  0         chomp $line;
215   ***      0                                  0         MKDEBUG && _d($line);
216   ***      0      0                           0         if ( my ( $proc ) = $line =~ m/(\d+)/ ) {
217   ***      0                                  0            MKDEBUG && _d('Will kill process', $proc);
218   ***      0                                  0            kill(15, $proc);
219                                                         }
220                                                      }
221                                                      else {
222   ***      0                                  0         warn "Cannot find mysqlbinlog command in ps";
223                                                      }
224   ***      0      0                           0      if ( !close($fh) ) {
225   ***      0      0                           0         if ( $OS_ERROR ) {
226   ***      0                                  0            warn "Error closing mysqlbinlog pipe: $OS_ERROR\n";
227                                                         }
228                                                         else {
229   ***      0                                  0            MKDEBUG && _d('Exit status', $CHILD_ERROR,'from mysqlbinlog');
230                                                         }
231                                                      }
232   ***      0                                  0      return;
233                                                   }
234                                                   
235                                                   # Returns true if it's time to _get_slave_status() again.
236                                                   sub _check_slave_status {
237           11                   11            50      my ( $self ) = @_;
238   ***     11     50                          67      return 1 unless defined $self->{slave};
239                                                      return
240           11    100    100                  215         $self->{pos} > $self->{slave}->{pos}
241                                                         && ($self->{stats}->{events} - $self->{last_chk}) >= $self->{chk_int}
242                                                            ? 1 : 0;
243                                                   }
244                                                   
245                                                   # Returns the next check interval.
246                                                   sub _get_next_chk_int {
247            2                    2            10      my ( $self ) = @_;
248   ***      2     50                          15      if ( $self->{pos} <= $self->{slave}->{pos} ) {
249                                                         # The slave caught up to us so do another check sooner than usual.
250   ***      0                                  0         return max($self->{chk_min}, $self->{chk_int} / 2);
251                                                      }
252                                                      else {
253                                                         # We're ahead of the slave so wait a little longer until the next check.
254            2                                 19         return min($self->{chk_max}, $self->{chk_int} * 2);
255                                                      }
256                                                   }
257                                                   
258                                                   # This is the private interface, called internally to update
259                                                   # $self->{slave}.  The public interface to return $self->{slave}
260                                                   # is get_slave_status().
261                                                   sub _get_slave_status {
262           14                   14            58      my ( $self ) = @_;
263           14                                 72      $self->{stats}->{show_slave_status}++;
264                                                   
265                                                      # Remember to $dbh->{FetchHashKeyName} = 'NAME_lc'.
266                                                   
267           14                                 63      my $show_slave_status = $self->{callbacks}->{show_slave_status};
268           14                                 73      my $status            = $show_slave_status->($self->{dbh}); 
269   ***     14     50     33                  198      if ( !$status || !%$status ) {
270   ***      0                                  0         die "No output from SHOW SLAVE STATUS";
271                                                      }
272   ***     14     50     50                  347      my %status = (
      ***            50                               
273                                                         running => ($status->{slave_sql_running} || '') eq 'Yes' ? 1 : 0,
274                                                         file    => $status->{relay_log_file},
275                                                         pos     => $status->{relay_log_pos},
276                                                                    # If the slave SQL thread is executing from the same log the
277                                                                    # I/O thread is reading from, in general (except when the
278                                                                    # master or slave starts a new binlog or relay log) we can
279                                                                    # tell how many bytes the SQL thread lags the I/O thread.
280                                                         lag   => $status->{master_log_file} eq $status->{relay_master_log_file}
281                                                                ? $status->{read_master_log_pos} - $status->{exec_master_log_pos}
282                                                                : 0,
283                                                         mfile => $status->{relay_master_log_file},
284                                                         mpos  => $status->{exec_master_log_pos},
285                                                      );
286                                                   
287           14                                 69      $self->{slave}    = \%status;
288           14                                 90      $self->{last_chk} = $self->{stats}->{events};
289           14                                 32      MKDEBUG && _d('Slave status:', Dumper($self->{slave}));
290           14                                 57      return;
291                                                   }
292                                                   
293                                                   # Public interface for returning the current/last slave status.
294                                                   sub get_slave_status {
295   ***      1                    1      0      8      my ( $self ) = @_;
296            1                                  7      $self->_get_slave_status();
297            1                                 13      return $self->{slave};
298                                                   }
299                                                   
300                                                   sub slave_is_running {
301   ***      1                    1      0      5      my ( $self, $dbh ) = @_;
302   ***      1     50                           6      $self->_get_slave_status() unless defined $self->{slave};
303            1                                  6      return $self->{slave}->{running};
304                                                   }
305                                                   
306                                                   sub get_interval {
307   ***      1                    1      0      3      my ( $self ) = @_;
308            1                                  9      return $self->{stats}->{events}, $self->{last_chk};
309                                                   }
310                                                   
311                                                   sub get_pipeline_pos {
312   ***      3                    3      0     13      my ( $self ) = @_;
313            3                                 33      return $self->{pos}, $self->{next}, $self->{last_ts};
314                                                   }
315                                                   
316                                                   sub set_pipeline_pos {
317   ***     14                   14      0     70      my ( $self, $pos, $next, $ts ) = @_;
318   ***     14     50     33                  144      die "pos must be >= 0"  unless defined $pos && $pos >= 0;
319   ***     14     50     33                  120      die "next must be >= 0" unless defined $pos && $pos >= 0;
320           14                                 59      $self->{pos}     = $pos;
321           14                                 47      $self->{next}    = $next;
322           14           100                  103      $self->{last_ts} = $ts || 0;  # undef same as zero
323           14                                 31      MKDEBUG && _d('Set pipeline pos', @_);
324           14                                 47      return;
325                                                   }
326                                                   
327                                                   sub reset_pipeline_pos {
328   ***      3                    3      0     16      my ( $self ) = @_;
329            3                                 14      $self->{pos}     = 0; # Current position we're reading in relay log.
330            3                                 12      $self->{next}    = 0; # Start of next relay log event.
331            3                                 14      $self->{last_ts} = 0; # Last seen timestamp.
332            3                                  8      MKDEBUG && _d('Reset pipeline');
333            3                                 12      return;
334                                                   }
335                                                   
336                                                   # Check if we're in the "window".  If yes, returns the event; if no,
337                                                   # returns nothing.  This is the public interface; _in_window() should
338                                                   # not be called directly.
339                                                   sub in_window {
340   ***     11                   11      0     81      my ( $self, %args ) = @_;
341           11                                 78      my ($event, $oktorun) = @args{qw(event oktorun)};
342                                                   
343                                                      # The caller must incr stats->events!  We use this to determine
344                                                      # if it's time to check the slave's status again.
345                                                   
346   ***     11     50                          67      if ( !$event->{offset} ) {
347                                                         # This will happen for start/end of log stuff like:
348                                                         #   End of log file
349                                                         #   ROLLBACK /* added by mysqlbinlog */;
350                                                         #   /*!50003 SET COMPLETION_TYPE=@OLD_COMPLETION_TYPE*/;
351   ***      0                                  0         MKDEBUG && _d('Event has no offset, skipping');
352   ***      0                                  0         $self->{stats}->{no_offset}++;
353   ***      0                                  0         return;
354                                                      }
355                                                   
356                                                      # Update pos and next.
357   ***     11     50                          81      $self->{pos}  = $event->{offset} if $event->{offset};
358   ***     11            50                  140      $self->{next} = max($self->{next},$self->{pos}+($event->{end_log_pos} || 0));
359                                                   
360   ***     11     50     33                   74      if ( $self->{progress}
361                                                           && $self->{stats}->{events} % $self->{progress} == 0 ) {
362   ***      0                                  0         print("# $self->{slave}->{file} $self->{pos} ",
363   ***      0                                  0            join(' ', map { "$_:$self->{stats}->{$_}" } keys %{$self->{stats}}),
      ***      0                                  0   
364                                                            "\n");
365                                                      }
366                                                   
367                                                      # Time to check the slave's status again?
368           11    100                          65      if ( $self->_check_slave_status() ) { 
369            2                                 16         MKDEBUG && _d('Checking slave status at interval',
370                                                            $self->{stats}->{events});
371            2                                 14         my $current_relay_log = $self->{slave}->{file};
372            2                                 13         $self->_get_slave_status();
373   ***      2    100     66                   44         if (    $current_relay_log
374                                                              && $current_relay_log ne $self->{slave}->{file} ) {
375            1                                  3            MKDEBUG && _d('Relay log file has changed from',
376                                                               $current_relay_log, 'to', $self->{slave}->{file});
377            1                                  9            $self->reset_pipeline_pos();
378   ***      1     50                          17            $args{oktorun}->(0) if $args{oktorun};
379            1                                  8            return;
380                                                         }
381            1                                  7         $self->{chk_int} = $self->_get_next_chk_int();
382            1                                  3         MKDEBUG && _d('Next check interval:', $self->{chk_int});
383                                                      }
384                                                   
385                                                      # We're in the window if we're not behind the slave or too far
386                                                      # ahead of it.  We can only execute queries while in the window.
387           10    100                          54      return $event if $self->_in_window();
388                                                   }
389                                                   
390                                                   # Checks, prepares and rewrites the event's arg to a SELECT.
391                                                   # If successful, returns the event with the original arg replaced
392                                                   # with the SELECT query (and the original arg saved as "arg_original");
393                                                   # else returns nothing.
394                                                   sub rewrite_query { 
395   ***     10                   10      0     75      my ( $self, $event, %args ) = @_;
396                                                   
397   ***     10     50                          82      if ( !$event->{arg} ) {
398                                                         # The caller shouldn't give us an arg-less event, but just in case...
399   ***      0                                  0         $self->{stats}->{no_arg}++;
400   ***      0                                  0         return;
401                                                      }
402                                                   
403                                                      # If it's a LOAD DATA INFILE, rm the temp file.
404                                                      # TODO: maybe this should still be before _in_window()?
405   ***     10     50                          97      if ( my ($file) = $event->{arg} =~ m/INFILE ('[^']+')/i ) {
406   ***      0                                  0         $self->{stats}->{load_data_infile}++;
407   ***      0      0                           0         if ( !unlink($file) ) {
408   ***      0                                  0            MKDEBUG && _d('Could not unlink', $file);
409   ***      0                                  0            $self->{stats}->{could_not_unlink}++;
410                                                         }
411   ***      0                                  0         return;
412                                                      }
413                                                   
414           10                                 80      my ($query, $fingerprint) = $self->prepare_query($event->{arg});
415                                                   
416                                                      # Maybe rewrite failed INSERT|REPLACE by injecting missing columns list.
417                                                      # http://code.google.com/p/maatkit/issues/detail?id=1003
418   ***     10    100     66                  184      if ( !$query
      ***                   66                        
      ***                   66                        
419                                                           && $event->{arg} =~ m/^INSERT|REPLACE/i
420                                                           && $self->{TableParser}
421                                                           && $self->{QueryParser} )
422                                                      {
423            2                                 38         my $new_arg = $self->inject_columns_list($event->{arg}, %args);
424   ***      2     50                          13         return unless $new_arg;
425            2                                 12         $event->{arg} = $new_arg;
426            2                                 25         return $self->rewrite_query($event);
427                                                      }
428                                                   
429   ***      8     50                          43      if ( !$query ) {
430   ***      0                                  0         MKDEBUG && _d('Failed to prepare query, skipping');
431   ***      0                                  0         return;
432                                                      }
433            8                                 51      $event->{arg_original} = $event->{arg};
434            8                                 41      $event->{arg}          = $query;  # SELECT query
435            8                                 40      $event->{fingerprint}  = $fingerprint;
436                                                   
437            8                                 50      return $event;
438                                                   }
439                                                   
440                                                   sub inject_columns_list {
441   ***      2                    2      0     20      my ( $self, $query, %args ) = @_; 
442            2                                 13      my $tp   = $self->{TableParser};
443            2                                 10      my $qp   = $self->{QueryParser};
444            2                                 11      my $q    = $self->{Quoter};
445            2                                 17      my $dbh  = $self->{dbh};
446   ***      2     50     33                   39      return unless $tp && $qp;
447            2                                 10      MKDEBUG && _d('Attempting to inject columns list into query');
448                                                   
449            2                                 12      my $default_db = $args{default_db};
450                                                   
451            2                                 31      my @tbls = $qp->get_tables($query);
452   ***      2     50                         544      if ( !@tbls ) {
453   ***      0                                  0         MKDEBUG && _d("Can't get tables from query");
454   ***      0                                  0         return;
455                                                      }
456   ***      2     50                          15      if ( @tbls > 1 ) {
457   ***      0                                  0         MKDEBUG && _d("Query has more than one table");
458   ***      0                                  0         return;
459                                                      }
460                                                   
461   ***      2     50                          21      if ( $q ) {
462            2                                 33         my ($db, $tbl) = $q->split_unquote($tbls[0]);
463   ***      2    100     66                  138         if ( !$db && $default_db ) {
464            1                                  4            MKDEBUG && _d('Using default db:', $default_db);
465            1                                  8            $tbls[0] = "$default_db.$tbl";
466                                                         }
467                                                      }
468                                                   
469            2                                 16      my $tbl_cols = $self->{tbl_cols}->{$tbls[0]};
470            2    100                          17      if ( !$tbl_cols ) {
471            1                                  8         my $sql = "SHOW CREATE TABLE $tbls[0]";
472            1                                  7         MKDEBUG && _d($sql);
473            1                                  5         eval {
474            1                                  5            my $show_create = $dbh->selectrow_arrayref($sql)->[1];
475   ***      1     50                         387            if ( !$show_create ) {
476   ***      0                                  0               MKDEBUG && _d("Failed to", $sql);
477   ***      0                                  0               return;
478                                                            }
479            1                                 21            my $tbl_struct = $tp->parse($show_create);
480   ***      1     50                        1113            if ( !$tbl_struct ) {
481   ***      0                                  0               MKDEBUG && _d("Failed to parse table struct");
482   ***      0                                  0               return;
483                                                            }
484            1                                  6            $tbl_cols = join(',', map { "`$_`" } @{$tbl_struct->{cols}});
               3                                 23   
               1                                  8   
485            1                                 32            $self->{tbl_cols}->{$tbls[0]} = $tbl_cols;
486                                                         };
487   ***      1     50                           9         if ( $EVAL_ERROR ) {
488   ***      0                                  0            MKDEBUG && _d($EVAL_ERROR);
489   ***      0                                  0            return;
490                                                         }
491                                                      }
492                                                      else {
493            1                                  4         MKDEBUG && _d('Using cached columns for', $tbls[0]);
494                                                      }
495                                                   
496   ***      2     50                          32      if ( !($query =~ s/ VALUES?/ ($tbl_cols) VALUES/i) ) {
497   ***      0                                  0         MKDEBUG && _d("Failed to inject columns list");
498   ***      0                                  0         return;
499                                                      }
500                                                   
501            2                                  8      MKDEBUG && _d('Successfully inject columns list:',
502                                                         substr($query, 0, 100), '...');
503                                                   
504            2                                 17      return $query;
505                                                   }
506                                                   
507                                                   sub get_window {
508   ***      2                    2      0      9      my ( $self ) = @_;
509            2                                 16      return $self->{offset}, $self->{window};
510                                                   }
511                                                   
512                                                   sub set_window {
513   ***      5                    5      0     29      my ( $self, $offset, $window ) = @_;
514   ***      5     50                          31      die "offset must be > 0" unless $offset;
515   ***      5     50                          25      die "window must be > 0" unless $window;
516            5                                 18      $self->{offset} = $offset;
517            5                                 20      $self->{window} = $window;
518            5                                 13      MKDEBUG && _d('Set window', @_);
519            5                                 17      return;
520                                                   }
521                                                   
522                                                   # Returns false if the current pos is out of the window, else returns true.
523                                                   # The window is a throttle (if the caller chooses to use it).  This is a
524                                                   # private method called by in_window(); it should not be called directly.
525                                                   sub _in_window {
526           13                   13            57      my ( $self ) = @_;
527           13                                 46      MKDEBUG && _d('Checking window, pos:', $self->{pos},
528                                                         'next', $self->{next},
529                                                         'slave pos:', $self->{slave}->{pos},
530                                                         'master pos', $self->{slave}->{mpos});
531                                                   
532                                                      # We're behind the slave which is bad because we're no
533                                                      # longer prefetching.  We need to stop pipelining events
534                                                      # and start skipping them until we're back in the window
535                                                      # or ahead of the slave.
536           13    100                          60      return 0 unless $self->_far_enough_ahead();
537                                                   
538                                                      # We're ahead of the slave, but check that we're not too
539                                                      # far ahead, i.e. out of the window or too close to the end
540                                                      # of the binlog.  If we are, wait for the slave to catch up
541                                                      # then go back to pipelining events.
542            9                                 52      my $wait_for_master = $self->{callbacks}->{wait_for_master};
543            9                                 77      my %wait_args       = (
544                                                         dbh       => $self->{dbh},
545                                                         mfile     => $self->{slave}->{mfile},
546                                                         until_pos => $self->next_window(),
547                                                      );
548                                                   
549            9                                 43      my $oktorun = $self->{oktorun};
550   ***      9            66                   47      while ( $oktorun->()
      ***                   66                        
                           100                        
551                                                              && $self->{slave}->{running}
552                                                              && ($self->_too_far_ahead() || $self->_too_close_to_io()) ) {
553                                                         # Don't increment stats if the slave didn't catch up while we
554                                                         # slept.
555            2                                  8         $self->{stats}->{master_pos_wait}++;
556   ***      2     50                          11         if ( $wait_for_master->(%wait_args) > 0 ) {
557   ***      2     50                           7            if ( $self->_too_far_ahead() ) {
      ***             0                               
558            2                                  8               $self->{stats}->{too_far_ahead}++;
559                                                            }
560                                                            elsif ( $self->_too_close_to_io() ) {
561   ***      0                                  0               $self->{stats}->{too_close_to_io_thread}++;
562                                                            }
563                                                         }
564                                                         else {
565   ***      0                                  0            MKDEBUG && _d('SQL thread did not advance');
566                                                         }
567            2                                  8         $self->_get_slave_status();
568                                                      }
569                                                   
570   ***      9    100     33                   74      if (     $self->{slave}->{running}
      ***                   66                        
      ***                   66                        
571                                                           &&  $self->_far_enough_ahead()
572                                                           && !$self->_too_far_ahead()
573                                                           && !$self->_too_close_to_io() )
574                                                      {
575            7                                 21         MKDEBUG && _d('Event', $self->{stats}->{events}, 'is in the window');
576            7                                 65         return 1;
577                                                      }
578                                                   
579            2                                  5      MKDEBUG && _d('Event', $self->{stats}->{events}, 'is not in the window');
580            2                                 13      return 0;
581                                                   }
582                                                   
583                                                   # Whether we are slave pos+offset ahead of the slave.
584                                                   sub _far_enough_ahead {
585           26                   26            95      my ( $self ) = @_;
586           26    100                         201      if ( $self->{pos} < $self->{slave}->{pos} + $self->{offset} ) {
587            6                                 13         MKDEBUG && _d($self->{pos}, 'is not',
588                                                            $self->{offset}, 'ahead of', $self->{slave}->{pos});
589            6                                 23         $self->{stats}->{not_far_enough_ahead}++;
590            6                                 45         return 0;
591                                                      }
592           20                                155      return 1;
593                                                   }
594                                                   
595                                                   # Whether we are slave pos+offset+window ahead of the slave.
596                                                   sub _too_far_ahead {
597           24                   24            93      my ( $self ) = @_;
598           24    100                         203      my $too_far =
599                                                         $self->{pos}
600                                                            > $self->{slave}->{pos} + $self->{offset} + $self->{window} ? 1 : 0;
601           24                                 56      MKDEBUG && _d('pos', $self->{pos}, 'too far ahead of',
602                                                         'slave pos', $self->{slave}->{pos}, ':', $too_far ? 'yes' : 'no');
603           24                                201      return $too_far;
604                                                   }
605                                                   
606                                                   # Whether we are too close to where the I/O thread is writing.
607                                                   sub _too_close_to_io {
608           14                   14            57      my ( $self ) = @_;
609   ***     14            66                  188      my $too_close= $self->{slave}->{lag}
610                                                         && $self->{pos}
611                                                            >= $self->{slave}->{pos} + $self->{slave}->{lag} - $self->{'io-lag'};
612           14                                 34      MKDEBUG && _d('pos', $self->{pos},
613                                                         'too close to I/O thread pos', $self->{slave}->{pos}, '+',
614                                                         $self->{slave}->{lag}, ':', $too_close ? 'yes' : 'no');
615           14                                131      return $too_close;
616                                                   }
617                                                   
618                                                   sub _wait_for_master {
619            2                    2            23      my ( %args ) = @_;
620            2                                 17      my @required_args = qw(dbh mfile until_pos);
621            2                                 12      foreach my $arg ( @required_args ) {
622   ***      6     50                          42         die "I need a $arg argument" unless $args{$arg};
623                                                      }
624   ***      2            50                   30      my $timeout = $args{timeout} || 1;
625            2                                 15      my ($dbh, $mfile, $until_pos) = @args{@required_args};
626            2                                 16      my $sql = "SELECT COALESCE(MASTER_POS_WAIT('$mfile',$until_pos,$timeout),0)";
627            2                                  6      MKDEBUG && _d('Waiting for master:', $sql);
628            2                                 16      my $start = gettimeofday();
629            2                                  6      my ($events) = $dbh->selectrow_array($sql);
630            2                             1001019      MKDEBUG && _d('Waited', (gettimeofday - $start), 'and got', $events);
631            2                                 42      return $events;
632                                                   }
633                                                   
634                                                   # The next window is pos-offset, assuming that master/slave pos
635                                                   # are behind pos.  If we get too far ahead, we need to wait until
636                                                   # the slave is right behind us.  The closest it can get is offset
637                                                   # bytes behind us, thus pos-offset.  However, the return value is
638                                                   # in terms of master pos because this is what MASTER_POS_WAIT()
639                                                   # expects.
640                                                   sub next_window {
641   ***     10                   10      0     42      my ( $self ) = @_;
642           10                                 82      my $next_window = 
643                                                            $self->{slave}->{mpos}                    # master pos
644                                                            + ($self->{pos} - $self->{slave}->{pos})  # how far we're ahead
645                                                            - $self->{offset};                        # offset;
646           10                                 24      MKDEBUG && _d('Next window, master pos:', $self->{slave}->{mpos},
647                                                         'next window:', $next_window,
648                                                         'bytes left:', $next_window - $self->{offset} - $self->{slave}->{mpos});
649           10                                 71      return $next_window;
650                                                   }
651                                                   
652                                                   # Does everything necessary to make the given DMS query ready for
653                                                   # execution as a SELECT.  If successful, the prepared query and its
654                                                   # fingerprint are returned; else nothing is returned.
655                                                   sub prepare_query {
656   ***     20                   20      0    119      my ( $self, $query ) = @_;
657           20                                 98      my $qr = $self->{QueryRewriter};
658                                                   
659           20                                141      $query = $qr->strip_comments($query);
660                                                   
661   ***     20     50                         777      return unless $self->query_is_allowed($query);
662                                                   
663                                                      # If the event is SET TIMESTAMP and we've already set the
664                                                      # timestamp to that value, skip it.
665           20    100                         151      if ( (my ($new_ts) = $query =~ m/SET timestamp=(\d+)/) ) {
666            2                                  5         MKDEBUG && _d('timestamp query:', $query);
667            2    100                          10         if ( $new_ts == $self->{last_ts} ) {
668            1                                  6            MKDEBUG && _d('Already saw timestamp', $new_ts);
669            1                                  9            $self->{stats}->{same_timestamp}++;
670            1                                  6            return;
671                                                         }
672                                                         else {
673            1                                  4            $self->{last_ts} = $new_ts;
674                                                         }
675                                                      }
676                                                   
677           19                                136      my $select = $qr->convert_to_select($query);
678           19    100                        2237      if ( $select !~ m/\A\s*(?:set|select|use)/i ) {
679            2                                  9         MKDEBUG && _d('Cannot rewrite query as SELECT:',
680                                                            (length $query > 240 ? substr($query, 0, 237) . '...' : $query));
681   ***      2     50                          43         _d("Not rewritten: $query") if $self->{'print-nonrewritten'};
682            2                                 28         $self->{stats}->{query_not_rewritten}++;
683            2                                 19         return;
684                                                      }
685                                                   
686           17                                185      my $fingerprint = $qr->fingerprint(
687                                                         $select,
688                                                         { prefixes => $self->{'num-prefix'} }
689                                                      );
690                                                   
691                                                      # If the query's average execution time is longer than the specified
692                                                      # limit, we wait for the slave to execute it then skip it ourself.
693                                                      # We do *not* want to skip it and continue pipelining events because
694                                                      # the caches that we would warm while executing ahead of the slave
695                                                      # would become cold once the slave hits this slow query and stalls.
696                                                      # In general, we want to always be just a little ahead of the slave
697                                                      # so it executes in the warmth of our pipelining wake.
698           17    100                        1595      if ((my $avg = $self->get_avg($fingerprint)) >= $self->{'max-query-time'}) {
699            1                                  2         MKDEBUG && _d('Avg time', $avg, 'too long for', $fingerprint);
700            1                                  5         $self->{stats}->{query_too_long}++;
701            1                                  7         return $self->_wait_skip_query($avg);
702                                                      }
703                                                   
704                                                      # Safeguard as much as possible against enormous result sets.
705           16                                 91      $select = $qr->convert_select_list($select);
706                                                   
707                                                      # The following block is/was meant to prevent huge insert/select queries
708                                                      # from slowing us, and maybe the network, down by wrapping the query like
709                                                      # select 1 from (<query>) as x limit 1.  This way, the huge result set of
710                                                      # the query is not transmitted but the query itself is still executed.
711                                                      # If someone has a similar problem, we can re-enable (and fix) this block.
712                                                      # The bug here is that by this point the query is already seen so the if()
713                                                      # is always false.
714                                                      # if ( $self->{have_subqueries} && !$self->have_seen($fingerprint) ) {
715                                                      #    # Wrap in a "derived table," but only if it hasn't been
716                                                      #    # seen before.  This way, really short queries avoid the
717                                                      #    # overhead of creating the temp table.
718                                                      #    # $select = $qr->wrap_in_derived($select);
719                                                      # }
720                                                   
721                                                      # Success: the prepared and converted query ready to execute.
722           16                                580      return $select, $fingerprint;
723                                                   }
724                                                   
725                                                   # Waits for the slave to catch up, execute the query at our current
726                                                   # pos, and then move on.  This is usually used to wait-skip slow queries,
727                                                   # so the wait arg is important.  If a slow query takes 3 seconds, and
728                                                   # it takes the slave another 1 second to reach our pos, then we can
729                                                   # either wait_for_master 4 times (1s each) or just wait twice, 3s each
730                                                   # time but the 2nd time will return as soon as the slave has moved
731                                                   # past the slow query.
732                                                   sub _wait_skip_query {
733            1                    1             4      my ( $self, $wait ) = @_;
734            1                                  4      my $wait_for_master = $self->{callbacks}->{wait_for_master};
735            1                                 12      my $until_pos = 
736                                                            $self->{slave}->{mpos}                    # master pos
737                                                            + ($self->{pos} - $self->{slave}->{pos})  # how far we're ahead
738                                                            + 1;                                      # 1 past this query
739            1                                 10      my %wait_args       = (
740                                                         dbh       => $self->{dbh},
741                                                         mfile     => $self->{slave}->{mfile},
742                                                         until_pos => $until_pos,
743                                                         timeout   => $wait,
744                                                      );
745            1                                 27      my $start = gettimeofday();
746   ***      1            66                   15      while ( $self->{slave}->{running}
747                                                              && ($self->{slave}->{pos} <= $self->{pos}) ) {
748            3                                 10         $self->{stats}->{master_pos_wait}++;
749            3                                 16         $wait_for_master->(%wait_args);
750            3                                 12         $self->_get_slave_status();
751            3                                 31         MKDEBUG && _d('Bytes until slave reaches wait-skip query:',
752                                                            $self->{pos} - $self->{slave}->{pos});
753                                                      }
754            1                                  2      MKDEBUG && _d('Waited', (gettimeofday - $start), 'to skip query');
755            1                                  4      $self->_get_slave_status();
756            1                                  7      return;
757                                                   }
758                                                   
759                                                   sub query_is_allowed {
760   ***     32                   32      0    155      my ( $self, $query ) = @_;
761   ***     32     50                         138      return unless $query;
762           32    100                         253      if ( $query =~ m/\A\s*(?:set [t@]|use|insert|update|delete|replace)/i ) {
763           27                                116         my $reject_regexp = $self->{reject_regexp};
764           27                                135         my $permit_regexp = $self->{permit_regexp};
765   ***     27     50     33                  354         if ( ($reject_regexp && $query =~ m/$reject_regexp/o)
      ***                   33                        
      ***                   33                        
766                                                              || ($permit_regexp && $query !~ m/$permit_regexp/o) )
767                                                         {
768   ***      0                                  0            MKDEBUG && _d('Query is not allowed, fails permit/reject regexp');
769   ***      0                                  0            $self->{stats}->{event_filtered_out}++;
770   ***      0                                  0            return 0;
771                                                         }
772           27                                149         return 1;
773                                                      }
774            5                                 12      MKDEBUG && _d('Query is not allowed, wrong type');
775            5                                 18      $self->{stats}->{event_not_allowed}++;
776            5                                 25      return 0;
777                                                   }
778                                                   
779                                                   sub exec {
780   ***      2                    2      0     16      my ( $self, %args ) = @_;
781            2                                  9      my $query       = $args{query};
782            2                                  8      my $fingerprint = $args{fingerprint};
783            2                                  7      eval {
784            2                                 14         my $start = gettimeofday();
785            2                                 98         $self->{dbh}->do($query);
786            1                                 11         $self->__store_avg($fingerprint, gettimeofday() - $start);
787                                                      };
788            2    100                          13      if ( $EVAL_ERROR ) {
789            1                                  6         $self->{stats}->{query_error}++;
790            1                                  6         $self->{query_errors}->{$fingerprint}++;
791   ***      1     50     50                   26         if ( (($self->{errors} || 0) == 2) || MKDEBUG ) {
      ***                   50                        
792   ***      0                                  0            _d($EVAL_ERROR);
793   ***      0                                  0            _d('SQL was:', $query);
794                                                         }
795                                                      }
796            2                                 11      return;
797                                                   }
798                                                   
799                                                   # The average is weighted so we don't quit trying a statement when we have
800                                                   # only a few samples.  So if we want to collect 16 samples and the first one
801                                                   # is huge, it will be weighted as 1/16th of its size.
802                                                   sub __store_avg {
803            1                    1             6      my ( $self, $fingerprint, $time ) = @_;
804            1                                  3      MKDEBUG && _d('Execution time:', $fingerprint, $time);
805   ***      1            50                   23      my $query_stats = $self->{query_stats}->{$fingerprint} ||= {};
806   ***      1            50                   11      my $samples     = $query_stats->{samples} ||= [];
807            1                                  4      push @$samples, $time;
808   ***      1     50                           8      if ( @$samples > $self->{'query-sample-size'} ) {
809   ***      0                                  0         shift @$samples;
810                                                      }
811            1                                 19      $query_stats->{avg} = sum(@$samples) / $self->{'query-sample-size'};
812            1                                  7      $query_stats->{exec}++;
813            1                                  8      $query_stats->{sum} += $time;
814            1                                  3      MKDEBUG && _d('Average time:', $query_stats->{avg});
815            1                                  4      return;
816                                                   }
817                                                   
818                                                   sub get_avg {
819   ***     17                   17      0     85      my ( $self, $fingerprint ) = @_;
820           17                                128      $self->{query_stats}->{$fingerprint}->{seen}++;
821           17           100                  255      return $self->{query_stats}->{$fingerprint}->{avg} || 0;
822                                                   }
823                                                   
824                                                   sub _d {
825            1                    1            13      my ($package, undef, $line) = caller 0;
826   ***      2     50                          16      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 18   
827            1                                  8           map { defined $_ ? $_ : 'undef' }
828                                                           @_;
829            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
830                                                   }
831                                                   
832                                                   1;
833                                                   
834                                                   # ###########################################################################
835                                                   # End SlavePrefetch package
836                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
65    ***     50      0     24   unless $args{$arg}
108   ***     50      0      4   if $args{'stats_file'}
117   ***     50      0      4   unless exists $$self{'callbacks'}{$func}
127   ***      0      0      0   unless open my $fh, '<', $file
132   ***      0      0      0   unless $type
133   ***      0      0      0   if ($type eq 'query') { }
139   ***      0      0      0   if ($seen)
146   ***      0      0      0   unless close $fh
157   ***      0      0      0   if $args{'all'} or $args{'stats'}
158   ***      0      0      0   if $args{'all'} or $args{'query_stats'}
159   ***      0      0      0   if $args{'all'} or $args{'query_errors'}
172   ***     50      0      1   unless $args{$arg}
176   ***     50      0      1   if (not -r $args{'relay_log'})
182   ***     50      0      1   unless open my $fh, "$cmd |"
183   ***     50      0      1   if ($CHILD_ERROR)
194          100      1      1   $args{'tmpdir'} ? :
      ***     50      2      0   $args{'start_pos'} ? :
213   ***      0      0      0   if (my($line) = $procs =~ /^(.*?\d\s+$cmd)$/m) { }
216   ***      0      0      0   if (my($proc) = $line =~ /(\d+)/)
224   ***      0      0      0   if (not close $fh)
225   ***      0      0      0   if ($OS_ERROR) { }
238   ***     50      0     11   unless defined $$self{'slave'}
240          100      2      9   $$self{'pos'} > $$self{'slave'}{'pos'} && $$self{'stats'}{'events'} - $$self{'last_chk'} >= $$self{'chk_int'} ? :
248   ***     50      0      2   if ($$self{'pos'} <= $$self{'slave'}{'pos'}) { }
269   ***     50      0     14   if (not $status or not %$status)
272   ***     50     14      0   ($$status{'slave_sql_running'} || '') eq 'Yes' ? :
      ***     50     14      0   $$status{'master_log_file'} eq $$status{'relay_master_log_file'} ? :
302   ***     50      0      1   unless defined $$self{'slave'}
318   ***     50      0     14   unless defined $pos and $pos >= 0
319   ***     50      0     14   unless defined $pos and $pos >= 0
346   ***     50      0     11   if (not $$event{'offset'})
357   ***     50     11      0   if $$event{'offset'}
360   ***     50      0     11   if ($$self{'progress'} and $$self{'stats'}{'events'} % $$self{'progress'} == 0)
368          100      2      9   if ($self->_check_slave_status)
373          100      1      1   if ($current_relay_log and $current_relay_log ne $$self{'slave'}{'file'})
378   ***     50      1      0   if $args{'oktorun'}
387          100      6      4   if $self->_in_window
397   ***     50      0     10   if (not $$event{'arg'})
405   ***     50      0     10   if (my($file) = $$event{'arg'} =~ /INFILE ('[^']+')/i)
407   ***      0      0      0   if (not unlink $file)
418          100      2      8   if (not $query and $$event{'arg'} =~ /^INSERT|REPLACE/i and $$self{'TableParser'} and $$self{'QueryParser'})
424   ***     50      0      2   unless $new_arg
429   ***     50      0      8   if (not $query)
446   ***     50      0      2   unless $tp and $qp
452   ***     50      0      2   if (not @tbls)
456   ***     50      0      2   if (@tbls > 1)
461   ***     50      2      0   if ($q)
463          100      1      1   if (not $db and $default_db)
470          100      1      1   if (not $tbl_cols) { }
475   ***     50      0      1   if (not $show_create)
480   ***     50      0      1   if (not $tbl_struct)
487   ***     50      0      1   if ($EVAL_ERROR)
496   ***     50      0      2   if (not $query =~ s/ VALUES?/ ($tbl_cols) VALUES/i)
514   ***     50      0      5   unless $offset
515   ***     50      0      5   unless $window
536          100      4      9   unless $self->_far_enough_ahead
556   ***     50      2      0   if (&$wait_for_master(%wait_args) > 0) { }
557   ***     50      2      0   if ($self->_too_far_ahead) { }
      ***      0      0      0   elsif ($self->_too_close_to_io) { }
570          100      7      2   if ($$self{'slave'}{'running'} and $self->_far_enough_ahead and not $self->_too_far_ahead and not $self->_too_close_to_io)
586          100      6     20   if ($$self{'pos'} < $$self{'slave'}{'pos'} + $$self{'offset'})
598          100      7     17   $$self{'pos'} > $$self{'slave'}{'pos'} + $$self{'offset'} + $$self{'window'} ? :
622   ***     50      0      6   unless $args{$arg}
661   ***     50      0     20   unless $self->query_is_allowed($query)
665          100      2     18   if (my($new_ts) = $query =~ /SET timestamp=(\d+)/)
667          100      1      1   if ($new_ts == $$self{'last_ts'}) { }
678          100      2     17   if (not $select =~ /\A\s*(?:set|select|use)/i)
681   ***     50      0      2   if $$self{'print-nonrewritten'}
698          100      1     16   if ((my $avg = $self->get_avg($fingerprint)) >= $$self{'max-query-time'})
761   ***     50      0     32   unless $query
762          100     27      5   if ($query =~ /\A\s*(?:set [t\@]|use|insert|update|delete|replace)/i)
765   ***     50      0     27   if ($reject_regexp and $query =~ /$reject_regexp/o or $permit_regexp and not $query =~ /$permit_regexp/o)
788          100      1      1   if ($EVAL_ERROR)
791   ***     50      0      1   if (($$self{'errors'} || 0) == 2 or 0)
808   ***     50      0      1   if (@$samples > $$self{'query-sample-size'})
826   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
240          100      1      8      2   $$self{'pos'} > $$self{'slave'}{'pos'} && $$self{'stats'}{'events'} - $$self{'last_chk'} >= $$self{'chk_int'}
318   ***     33      0      0     14   defined $pos and $pos >= 0
319   ***     33      0      0     14   defined $pos and $pos >= 0
360   ***     33     11      0      0   $$self{'progress'} and $$self{'stats'}{'events'} % $$self{'progress'} == 0
373   ***     66      0      1      1   $current_relay_log and $current_relay_log ne $$self{'slave'}{'file'}
418   ***     66      8      0      2   not $query and $$event{'arg'} =~ /^INSERT|REPLACE/i
      ***     66      8      0      2   not $query and $$event{'arg'} =~ /^INSERT|REPLACE/i and $$self{'TableParser'}
      ***     66      8      0      2   not $query and $$event{'arg'} =~ /^INSERT|REPLACE/i and $$self{'TableParser'} and $$self{'QueryParser'}
446   ***     33      0      0      2   $tp and $qp
463   ***     66      1      0      1   not $db and $default_db
550   ***     66      2      0      9   &$oktorun() and $$self{'slave'}{'running'}
             100      2      7      2   &$oktorun() and $$self{'slave'}{'running'} and $self->_too_far_ahead || $self->_too_close_to_io
570   ***     33      0      0      9   $$self{'slave'}{'running'} and $self->_far_enough_ahead
      ***     66      0      2      7   $$self{'slave'}{'running'} and $self->_far_enough_ahead and not $self->_too_far_ahead
      ***     66      2      0      7   $$self{'slave'}{'running'} and $self->_far_enough_ahead and not $self->_too_far_ahead and not $self->_too_close_to_io
609   ***     66      4     10      0   $$self{'slave'}{'lag'} && $$self{'pos'} >= $$self{'slave'}{'pos'} + $$self{'slave'}{'lag'} - $$self{'io-lag'}
746   ***     66      0      1      3   $$self{'slave'}{'running'} and $$self{'slave'}{'pos'} <= $$self{'pos'}
765   ***     33     27      0      0   $reject_regexp and $query =~ /$reject_regexp/o
      ***     33     27      0      0   $permit_regexp and not $query =~ /$permit_regexp/o

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
33    ***     50      0      1   $ENV{'MKDEBUG'} || 0
272   ***     50     14      0   $$status{'slave_sql_running'} || ''
322          100      1     13   $ts || 0
358   ***     50     11      0   $$event{'end_log_pos'} || 0
624   ***     50      0      2   $args{'timeout'} || 1
791   ***     50      0      1   $$self{'errors'} || 0
      ***     50      0      1   ($$self{'errors'} || 0) == 2 or 0
805   ***     50      0      1   $$self{'query_stats'}{$fingerprint} ||= {}
806   ***     50      0      1   $$query_stats{'samples'} ||= []
821          100      1     16   $$self{'query_stats'}{$fingerprint}{'avg'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
157   ***      0      0      0      0   $args{'all'} or $args{'stats'}
158   ***      0      0      0      0   $args{'all'} or $args{'query_stats'}
159   ***      0      0      0      0   $args{'all'} or $args{'query_errors'}
269   ***     33      0      0     14   not $status or not %$status
550   ***     66      2      0      7   $self->_too_far_ahead || $self->_too_close_to_io
765   ***     33      0      0     27   $reject_regexp and $query =~ /$reject_regexp/o or $permit_regexp and not $query =~ /$permit_regexp/o


Covered Subroutines
-------------------

Subroutine          Count Pod Location                                            
------------------- ----- --- ----------------------------------------------------
BEGIN                   1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:22 
BEGIN                   1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:23 
BEGIN                   1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:24 
BEGIN                   1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:26 
BEGIN                   1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:27 
BEGIN                   1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:28 
BEGIN                   1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:33 
__store_avg             1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:803
_check_slave_status    11     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:237
_d                      1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:825
_far_enough_ahead      26     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:585
_get_next_chk_int       2     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:247
_get_slave_status      14     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:262
_in_window             13     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:526
_mysqlbinlog_cmd        2     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:193
_too_close_to_io       14     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:608
_too_far_ahead         24     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:597
_wait_for_master        2     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:619
_wait_skip_query        1     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:733
exec                    2   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:780
get_avg                17   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:819
get_interval            1   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:307
get_pipeline_pos        3   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:312
get_slave_status        1   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:295
get_stats               1   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:151
get_window              2   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:508
in_window              11   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:340
inject_columns_list     2   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:441
new                     4   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:62 
next_window            10   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:641
open_relay_log          1   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:170
prepare_query          20   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:656
query_is_allowed       32   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:760
reset_pipeline_pos      3   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:328
rewrite_query          10   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:395
set_callbacks           4   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:115
set_pipeline_pos       14   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:317
set_window              5   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:513
slave_is_running        1   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:301

Uncovered Subroutines
---------------------

Subroutine          Count Pod Location                                            
------------------- ----- --- ----------------------------------------------------
__ANON__                0     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:91 
__ANON__                0     /home/daniel/dev/maatkit/common/SlavePrefetch.pm:95 
close_relay_log         0   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:204
init_stats              0   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:126
reset_stats             0   0 /home/daniel/dev/maatkit/common/SlavePrefetch.pm:156


SlavePrefetch.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  5   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 71;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use SlavePrefetch;
               1                                  3   
               1                                 26   
15             1                    1            13   use QueryRewriter;
               1                                  5   
               1                                 11   
16             1                    1            15   use BinaryLogParser;
               1                                  3   
               1                                 10   
17             1                    1             9   use DSNParser;
               1                                  4   
               1                                 12   
18             1                    1            14   use Sandbox;
               1                                  3   
               1                                 10   
19             1                    1           206   use TableParser;
               1                                  3   
               1                                 13   
20             1                    1            11   use Quoter;
               1                                  4   
               1                                 12   
21             1                    1            12   use QueryParser;
               1                                  2   
               1                                 10   
22             1                    1            14   use MaatkitTest;
               1                                  7   
               1                                 38   
23                                                    
24             1                                 14   my $dp = new DSNParser(opts=>$dsn_opts);
25             1                                243   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
26                                                    
27    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 30   
28                                                    
29             1                                 57   my $qp          = new QueryParser();
30             1                                 24   my $qr          = new QueryRewriter(QueryParser=>$qp);
31             1                                 24   my $dbh         = 1;  # we don't need to connect yet
32             1                                  3   my $oktorun     = 1;
33             1                                  3   my $more_events = 1;
34                                                    
35                                                    sub oktorun {
36            11                   11           167      return $oktorun;
37                                                    }
38                                                    sub more_events { 
39             1                    1             6      $more_events = $_[0];
40                                                    }
41                                                    
42             1                                 17   my $spf = new SlavePrefetch(
43                                                       dbh             => $dbh,
44                                                       oktorun         => \&oktorun,
45                                                       chk_int         => 4,
46                                                       chk_min         => 1,
47                                                       chk_max         => 8,
48                                                       QueryRewriter   => $qr,
49                                                       have_subqueries => 1,
50                                                       stats           => { events => 0 },
51                                                    );
52             1                                  9   isa_ok($spf, 'SlavePrefetch');
53                                                    
54                                                    # ###########################################################################
55                                                    # Test the pipeline pos.
56                                                    # ###########################################################################
57             1                                  9   is_deeply(
58                                                       [ $spf->get_pipeline_pos() ],
59                                                       [ 0, 0, 0 ],
60                                                       'Initial pipeline pos'
61                                                    );
62                                                    
63             1                                 13   $spf->set_pipeline_pos(5, 3, 1);
64             1                                  5   is_deeply(
65                                                       [ $spf->get_pipeline_pos() ],
66                                                       [ 5, 3, 1 ],
67                                                       'Set pipeline pos'
68                                                    );
69                                                    
70             1                                 14   $spf->reset_pipeline_pos();
71             1                                 13   is_deeply(
72                                                       [ $spf->get_pipeline_pos() ],
73                                                       [ 0, 0, 0 ],
74                                                       'Reset pipeline pos'
75                                                    );
76                                                    
77                                                    # ###########################################################################
78                                                    # Test opening and closing a relay log.
79                                                    # ###########################################################################
80             1                                  9   my $tmp_file = '/tmp/SlavePrefetch.txt';
81             1                               6420   diag(`rm -rf $tmp_file 2>/dev/null`);
82             1                                185   open my $tmp_fh, '>', $tmp_file;
83                                                    
84             1                                  4   my $fh;
85             1                                  6   eval {
86             1                                 20      $fh = $spf->open_relay_log(
87                                                          relay_log => "$trunk/common/t/samples/relay-binlog001",
88                                                          start_pos => 1708,
89                                                       );
90                                                    };
91             1                                 22   is(
92                                                       $EVAL_ERROR,
93                                                       '',
94                                                       'No error opening relay binlog'
95                                                    );
96             1                                  8   ok(
97                                                       $fh,
98                                                       'Got a filehandle for the relay binglog'
99                                                    );
100                                                   
101            1                                 15   is(
102                                                      $spf->_mysqlbinlog_cmd(
103                                                         tmpdir    => '/dev/null',
104                                                         relay_log => "$trunk/common/t/samples/relay-binlog001",
105                                                         start_pos => 1708,
106                                                      ),
107                                                      "mysqlbinlog --local-load=/dev/null  --start-pos=1708 $trunk/common/t/samples/relay-binlog001",
108                                                      'mysqlbinlog cmd'
109                                                   );
110                                                   
111   ***      1     50                           5   SKIP: {
112            1                                  4      skip "Cannot open $tmp_file for writing", 1 unless $tmp_fh;
113            1                               6713      print $tmp_fh $_ while ( <$fh> );
114            1                                 51      close $tmp_fh;
115            1                               3136      my $output = `cat $tmp_file 2>&1`;
116            1                                 63      like(
117                                                         $output,
118                                                         qr/090910\s+\d+:26:23\s+server\s+id\s+12345\s+end_log_pos\s+1925/,
119                                                         'Opened relay binlog'
120                                                      );
121            1                               6268      diag(`rm -rf $tmp_file 2>/dev/null`);
122                                                   };
123                                                   
124                                                   # This doesn't work because mysqlbinlog is run in a shell so ps
125                                                   # show "[sh]" instead of "mysqlbinlog".
126                                                   #eval {
127                                                   #   $spf->close_relay_log($fh);
128                                                   #};
129                                                   #is(
130                                                   #   $EVAL_ERROR,
131                                                   #   '',
132                                                   #   'No error closing relay binlog'
133                                                   #);
134                                                   
135                                                   # ###########################################################################
136                                                   # Test that we can fake SHOW SLAVE STATUS with a callback.
137                                                   # ###########################################################################
138                                                   
139                                                   # Remember to lowercase all the keys!
140            1                                 60   my $slave_status = {
141                                                      slave_io_state        => 'Waiting for master to send event',
142                                                      master_host           => '127.0.0.1',
143                                                      master_user           => 'msandbox',
144                                                      master_port           => 12345,
145                                                      connect_retry         => 60,
146                                                      master_log_file       => 'mysql-bin.000001',
147                                                      read_master_log_pos   => 1925,
148                                                      relay_log_file        => 'mysql-relay-bin.000003',
149                                                      relay_log_pos         => 2062,
150                                                      relay_master_log_file => 'mysql-bin.000001',
151                                                      slave_io_running      => 'Yes',
152                                                      slave_sql_running     => 'Yes',
153                                                      replicate_do_db       => undef,
154                                                      replicate_ignore_db   => undef,
155                                                      replicate_do_table    => undef,
156                                                      last_errno            => 0,
157                                                      last_error            => undef,
158                                                      skip_counter          => 0,
159                                                      exec_master_log_pos   => 1925,
160                                                      relay_log_space       => 2062,
161                                                      until_condition       => 'None',
162                                                      until_log_file        => undef,
163                                                      until_log_pos         => 0,
164                                                      seconds_behind_master => 0,
165                                                   };
166                                                   sub show_slave_status {
167           14                   14            56      return $slave_status;
168                                                   }
169                                                   
170            1                                 11   eval {
171            1                                 19      $spf->set_callbacks( show_slave_status => \&show_slave_status );
172                                                   };
173            1                                 12   is(
174                                                      $EVAL_ERROR,
175                                                      '',
176                                                      'No error setting show_slave_status callback'
177                                                   );
178                                                   
179            1                                 13   is_deeply(
180                                                      $spf->get_slave_status(),
181                                                      {
182                                                         running  => 1,
183                                                         file     => 'mysql-relay-bin.000003',
184                                                         pos      => 2062,
185                                                         lag      => 0,
186                                                         mfile    => 'mysql-bin.000001',
187                                                         mpos     => 1925,
188                                                      },
189                                                      'Fake SHOW SLAVE STATUS with callback'
190                                                   );
191                                                   
192                                                   # Now that we have slave stats, this should be true.
193            1                                 11   is(
194                                                      $spf->slave_is_running(),
195                                                      1,
196                                                      'Slave is running'
197                                                   );
198                                                   
199                                                   # ###########################################################################
200                                                   # Quick test that we can get the current "interval" and last check.
201                                                   # ###########################################################################
202                                                   
203                                                   # We haven't pipelined any events yet so these should be zero.
204            1                                  9   is_deeply(
205                                                      [ $spf->get_interval() ],
206                                                      [ 0, 0 ],
207                                                      'Get interval and last check'
208                                                   );
209                                                   
210                                                   # ###########################################################################
211                                                   # Test window stuff.
212                                                   # ###########################################################################
213                                                   
214                                                   # We didn't pass and offset or window arg to new() so these are defaults.
215            1                                 17   is_deeply(
216                                                      [ $spf->get_window() ],
217                                                      [ 128, 4_096 ],
218                                                      'Get window (defaults)'
219                                                   );
220                                                   
221            1                                 19   $spf->set_window(25, 1_024);  # offset, window
222            1                                  5   is_deeply(
223                                                      [ $spf->get_window() ],
224                                                      [ 25, 1_024 ],
225                                                      'Set window'
226                                                   );
227                                                   
228                                                   # The following tests are sensitive to pos, slave stats and the window
229                                                   # which we vary to test the subs.  Before each test the curren vals are
230                                                   # restated so the scenario being tested is clear.
231                                                   
232            1                                 16   $spf->set_pipeline_pos(100, 150);
233            1                                  4   $slave_status->{relay_log_pos} = 700;
234            1                                  5   $spf->_get_slave_status();
235                                                   
236                                                   # pos:       100
237                                                   # slave pos: 700
238                                                   # offset:    25
239                                                   # window:    1024
240            1                                 14   is(
241                                                      $spf->_far_enough_ahead(),
242                                                      0,
243                                                      "Far enough ahead: way behind slave"
244                                                   );
245                                                   
246            1                                  6   $spf->set_pipeline_pos(700, 750);
247                                                   
248                                                   # pos:       700
249                                                   # slave pos: 700
250                                                   # offset:    25
251                                                   # window:    1024
252            1                                  5   is(
253                                                      $spf->_far_enough_ahead(),
254                                                      0,
255                                                      "Far enough ahead: same pos as slave"
256                                                   );
257                                                   
258            1                                  6   $spf->set_pipeline_pos(725, 750);
259                                                   
260                                                   # pos:       725
261                                                   # slave pos: 700
262                                                   # offset:    25
263                                                   # window:    1024
264            1                                  5   is(
265                                                      $spf->_far_enough_ahead(),
266                                                      1,
267                                                      "Far enough ahead: ahead of slave, right at offset"
268                                                   );
269                                                   
270            1                                  5   $spf->set_pipeline_pos(726, 750);
271                                                   
272                                                   # pos:       726
273                                                   # slave pos: 700
274                                                   # offset:    25
275                                                   # window:    1024
276            1                                  5   is(
277                                                      $spf->_far_enough_ahead(),
278                                                      1,
279                                                      "Far enough ahead: first byte ahead of slave"
280                                                   );
281                                                   
282            1                                  5   $spf->set_pipeline_pos(500, 550);
283                                                   
284                                                   # pos:       500
285                                                   # slave pos: 700
286                                                   # offset:    25
287                                                   # window:    1024
288            1                                  9   is(
289                                                      $spf->_too_far_ahead(),
290                                                      0,
291                                                      "Too far ahead: behind slave"
292                                                   );
293                                                   
294            1                                  5   $spf->set_pipeline_pos(1500, 1550);
295                                                   
296                                                   # pos:       1500
297                                                   # slave pos: 700
298                                                   # offset:    25
299                                                   # window:    1024
300            1                                  4   is(
301                                                      $spf->_too_far_ahead(),
302                                                      0,
303                                                      "Too far ahead: in window"
304                                                   );
305                                                   
306            1                                  6   $spf->set_pipeline_pos(1749, 1850);
307                                                   
308                                                   # pos:       1749
309                                                   # slave pos: 700
310                                                   # offset:    25
311                                                   # window:    1024
312            1                                  5   is(
313                                                      $spf->_too_far_ahead(),
314                                                      0,
315                                                      "Too far ahead: at last byte in window"
316                                                   );
317                                                   
318            1                                  8   $spf->set_pipeline_pos(1750, 1850);
319                                                   
320                                                   # pos:       1750
321                                                   # slave pos: 700
322                                                   # offset:    25
323                                                   # window:    1024
324            1                                  5   is(
325                                                      $spf->_too_far_ahead(),
326                                                      1,
327                                                      "Too far ahead: first byte past window"
328                                                   );
329                                                   
330                                                   # TODO: test _too_close_to_io().
331                                                   
332                                                   # To fully test _in_window() we'll need to set a wait_for_master callback.
333                                                   # For the offline tests, it will simulate MASTER_POS_WAIT() by setting
334                                                   # the slave stats given an array of stats.  Each call shifts and sets
335                                                   # global $slave_status to the next stats in the array.  Then when
336                                                   # _get_slave_status() is called after wait_for_master(), the faux stats
337                                                   # get set.
338            1                                  3   my @slave_stats;
339            1                                  3   my $n_events = 1;
340                                                   sub wait_for_master {
341   ***      5     50             5            19      if ( @slave_stats ) {
342            5                                 16         $slave_status = shift @slave_stats;
343                                                      }
344            5                                 30      return $n_events;
345                                                   }
346                                                   
347            1                                  3   eval {
348            1                                  8      $spf->set_callbacks( wait_for_master => \&wait_for_master );
349                                                   };
350            1                                  6   is(
351                                                      $EVAL_ERROR,
352                                                      '',
353                                                      'No error setting wait_for_master callback'
354                                                   );
355                                                   
356                                                   # _in_window() should return immediately if we're not far enough ahead.
357                                                   # So do like befor and make it seem like we're way behind the slave.
358            1                                  9   $spf->set_pipeline_pos(100, 150);
359                                                   
360                                                   # pos:       100
361                                                   # slave pos: 700
362                                                   # offset:    25
363                                                   # window:    1024
364            1                                  6   is(
365                                                      $spf->_in_window(),
366                                                      0,
367                                                      "In window: way behind slave"
368                                                   );
369                                                   
370                                                   # _in_window() will wait_for_master if we're too far ahead or too close
371                                                   # to io (and if it's oktorun).  It should let the slave catch up just
372                                                   # until we're back in the window, then return 1.
373                                                   
374                                                   # First let's test that oktorun will early-terminate the loop and cause
375                                                   # _in_window() to return 1 even though we're out of the window.
376            1                                  7   $oktorun = 0;
377                                                   
378            1                                  5   $spf->set_pipeline_pos(5000, 5050);
379                                                   
380                                                   # pos:       5000
381                                                   # slave pos: 700
382                                                   # offset:    25
383                                                   # window:    1024
384            1                                  6   is(
385                                                      $spf->_in_window(),
386                                                      0,
387                                                      "In window: past window but oktorun caused early return"
388                                                   );
389                                                   
390                                                   # Now we're oktorun but too far ahead, so wait_for_master() should
391                                                   # get called and it's going to wait until the next window.  So let's
392                                                   # test all this.
393            1                                  3   $oktorun = 1;
394                                                   
395            1                                  6   $spf->set_window(50, 100);
396            1                                  5   $spf->set_pipeline_pos(800, 900);
397            1                                  5   $slave_status->{exec_master_log_pos} = 100;
398            1                                  3   $slave_status->{relay_log_pos}       = 200;
399            1                                  6   $spf->_get_slave_status();
400                                                   
401                                                   # offset       50
402                                                   # window       100
403                                                   
404                                                   # pos   mysql  mk   
405                                                   # ----+------------
406                                                   # mst | 100    700
407                                                   # slv | 200    800
408                                                   
409                                                   # +100 difference between master and slave pos
410                                                   
411                                                   # in terms of master pos (for MASTER_POS_WAIT()):
412                                                   #   in window    150-250
413                                                   #   past window  450
414                                                   #   next window  650-750
415                                                   # in terms of slave pos (for _too_*()):
416                                                   #   next window  750-850
417                                                   
418                                                   # Window lower/upper, past and next are in terms of the master pos
419                                                   # because MASTER_POS_WAIT() uses this (exec_master_log_pos), not
420                                                   # the slave pos (relay_log_pos).
421            1                                  5   is(
422                                                      $spf->next_window(),
423                                                      650,  # in terms of master pos
424                                                      'Next window'
425                                                   );
426                                                   
427                                                   # Make some faux slave stats that simulate replication progress.
428            1                                  4   @slave_stats = ();
429            1                                 21   push @slave_stats,
430                                                      {
431                                                         # Read 400 bytes
432                                                         exec_master_log_pos   => 500,
433                                                         relay_log_pos         => 600,
434                                                         slave_sql_running     => 'Yes',
435                                                         master_log_file       => 'mysql-bin.000001',
436                                                         relay_master_log_file => 'mysql-bin.000001',
437                                                         relay_log_file        => 'mysql-relay-bin.000003',
438                                                         read_master_log_pos   => 1925,
439                                                      },
440                                                      {
441                                                         # Read 100 bytes--in window now
442                                                         exec_master_log_pos   => 600,
443                                                         relay_log_pos         => 700,
444                                                         slave_sql_running     => 'Yes',
445                                                         master_log_file       => 'mysql-bin.000001',
446                                                         relay_master_log_file => 'mysql-bin.000001',
447                                                         relay_log_file        => 'mysql-relay-bin.000003',
448                                                         read_master_log_pos   => 1925,
449                                                      },
450                                                      {
451                                                         # Read 50 bytes--shouldn't be used; see below
452                                                         exec_master_log_pos   => 650,
453                                                         relay_log_pos         => 750,
454                                                         slave_sql_running     => 'Yes',
455                                                         master_log_file       => 'mysql-bin.000001',
456                                                         relay_master_log_file => 'mysql-bin.000001',
457                                                         relay_log_file        => 'mysql-relay-bin.000003',
458                                                         read_master_log_pos   => 1925,
459                                                      };
460                                                   
461            1                                  5   is(
462                                                      $spf->_in_window(),
463                                                      1,
464                                                      "In window: slave caught up"
465                                                   );
466            1                                 12   is_deeply(
467                                                      \@slave_stats,
468                                                      [
469                                                         {
470                                                            # Read 50 bytes--shouldn't be used; that's why it's still here
471                                                            exec_master_log_pos   => 650,
472                                                            relay_log_pos         => 750,
473                                                            slave_sql_running     => 'Yes',
474                                                            master_log_file       => 'mysql-bin.000001',
475                                                            relay_master_log_file => 'mysql-bin.000001',
476                                                            relay_log_file        => 'mysql-relay-bin.000003',
477                                                            read_master_log_pos   => 1925,
478                                                         },
479                                                      ],
480                                                      'In window: stopped waiting once slave was in window'
481                                                   );
482                                                   
483                                                   # #############################################################################
484                                                   # Test query_is_allowed().
485                                                   # #############################################################################
486                                                   
487                                                   # query_is_allowed() expects that the query is already stripped of comments.
488                                                   
489                                                   # Remember to increase tests (line 6) if you add more types.
490            1                                 13   my @ok_types = qw(use insert update delete replace);
491            1                                  4   my @not_ok_types = qw(select create drop alter);
492                                                   
493            1                                  8   foreach my $ok_type ( @ok_types ) {
494            5                                 32      is(
495                                                         $spf->query_is_allowed("$ok_type from blah blah etc."),
496                                                         1,
497                                                         "$ok_type is allowed"
498                                                      );
499                                                   }
500                                                   
501            1                                  4   foreach my $not_ok_type ( @not_ok_types ) {
502            4                                 23      is(
503                                                         $spf->query_is_allowed("$not_ok_type from blah blah etc."),
504                                                         0,
505                                                         "$not_ok_type is NOT allowed"
506                                                      );
507                                                   }
508                                                   
509                                                   is(
510            1                                  5      $spf->query_is_allowed("SET timestamp=1197996507"),
511                                                      1,
512                                                      "SET timestamp is allowed"
513                                                   );
514            1                                  5   is(
515                                                      $spf->query_is_allowed('SET @var=1'),
516                                                      1,
517                                                      'SET @var is allowed'
518                                                   );
519            1                                  6   is(
520                                                      $spf->query_is_allowed("SET insert_id=34484549"),
521                                                      0,
522                                                      "SET insert_id is NOT allowed"
523                                                   );
524                                                   
525                                                   
526                                                   # #############################################################################
527                                                   # Test that we skip already-seen timestamps.
528                                                   # #############################################################################
529                                                   
530                                                   # No interface for this, so we hack it in.
531            1                                  6   $spf->{last_ts} = '12345';
532                                                   
533            1                                  8   is(
534                                                      $spf->prepare_query('SET timestamp=12345'),
535                                                      undef,
536                                                      'Skip already-seen timestamps'
537                                                   );
538            1                                  7   is(
539                                                      $spf->prepare_query('SET timestamp=44485'),
540                                                      'set timestamp=?',
541                                                      'Does not skip new timestamp'
542                                                   );
543                                                   
544                                                   # #############################################################################
545                                                   # Test general cases for prepare_query().
546                                                   # #############################################################################
547            1                                  6   is_deeply(
548                                                      [ $spf->prepare_query('INSERT INTO foo (a,b) VALUES (1,2)') ],
549                                                      [
550                                                         'select 1 from  foo  where a=1 and b=2',
551                                                         'select * from foo where a=? and b=?',
552                                                      ],
553                                                      'Prepare INSERT'
554                                                   );
555                                                   
556            1                                 12   is_deeply(
557                                                      [ $spf->prepare_query('UPDATE foo SET bar=1 WHERE id=9') ],
558                                                      [
559                                                         'select isnull(coalesce(  bar=1 )) from foo where  id=9',
560                                                         'select bar=? from foo where id=?'
561                                                      ],
562                                                      'Prepare UPDATE'
563                                                   );
564                                                   
565            1                                 11   is_deeply(
566                                                      [ $spf->prepare_query('DELETE FROM foo WHERE id=9') ],
567                                                      [
568                                                         'select 1 from  foo WHERE id=9',
569                                                         'select * from foo where id=?',
570                                                      ],
571                                                      'Prepare DELETE'
572                                                   );
573                                                   
574            1                                 27   is_deeply(
575                                                      [ $spf->prepare_query('/* comment */ DELETE FROM foo WHERE id=9; -- foo') ],
576                                                      [
577                                                         'select 1 from  foo WHERE id=9; ',
578                                                         'select * from foo where id=?; ',
579                                                      ],
580                                                      'Prepare DELETE with comments'
581                                                   );
582                                                   
583            1                                 14   is_deeply(
584                                                      [ $spf->prepare_query('USE db') ],
585                                                      [ 'USE db', 'use ?' ],
586                                                      'Prepare USE'
587                                                   );
588                                                   
589            1                                 11   is_deeply(
590                                                      [ $spf->prepare_query('replace into foo select * from bar') ],
591                                                      [ 'select 1 from bar', 'select * from bar' ],
592                                                      'Prepare REPLACE INTO'
593                                                   );
594                                                   
595                                                   # #############################################################################
596                                                   # Test that slow queries are skipped, wait_skip_query().
597                                                   # #############################################################################
598                                                   
599                                                   # Like the _in_window() test before, we need to simulate all the pos.
600                                                   # The slow query is at our pos, 100, so we'll need to wait until the
601                                                   # slave passes this pos.
602                                                   
603            1                                 12   $spf->set_window(50, 500);
604            1                                  7   $spf->set_pipeline_pos(100, 200);
605            1                                  5   $slave_status->{exec_master_log_pos} = 50;
606            1                                  4   $slave_status->{relay_log_pos}       = 50;
607            1                                  5   $spf->_get_slave_status();
608                                                   
609            1                                  6   @slave_stats = ();
610            1                                 23   push @slave_stats,
611                                                      {
612                                                         # 20 bytes before slow query...
613                                                         exec_master_log_pos   => 80,
614                                                         relay_log_pos         => 80,
615                                                         slave_sql_running     => 'Yes',
616                                                         master_log_file       => 'mysql-bin.000001',
617                                                         relay_master_log_file => 'mysql-bin.000001',
618                                                         relay_log_file        => 'mysql-relay-bin.000003',
619                                                         read_master_log_pos   => 1925,
620                                                      },
621                                                      {
622                                                         # At slow query...
623                                                         exec_master_log_pos   => 100,
624                                                         relay_log_pos         => 100,
625                                                         slave_sql_running     => 'Yes',
626                                                         master_log_file       => 'mysql-bin.000001',
627                                                         relay_master_log_file => 'mysql-bin.000001',
628                                                         relay_log_file        => 'mysql-relay-bin.000003',
629                                                         read_master_log_pos   => 1925,
630                                                      },
631                                                      {
632                                                         # Past slow query and done waiting.
633                                                         exec_master_log_pos   => 150,
634                                                         relay_log_pos         => 150,
635                                                         slave_sql_running     => 'Yes',
636                                                         master_log_file       => 'mysql-bin.000001',
637                                                         relay_master_log_file => 'mysql-bin.000001',
638                                                         relay_log_file        => 'mysql-relay-bin.000003',
639                                                         read_master_log_pos   => 1925,
640                                                      },
641                                                      {
642                                                         _wait_skip_query => "should stop before here",
643                                                      };
644                                                   
645                                                   # No interface for this either so hack it in.
646            1                                  6   my ($query, $fp) = $spf->prepare_query('INSERT INTO foo (a,b) VALUES (1,2)');
647            1                                  5   $spf->{query_stats}->{$fp}->{avg} = 3;
648                                                   
649            1                                  5   is(
650                                                      $spf->prepare_query('INSERT INTO foo (a,b) VALUES (1,2)'),
651                                                      undef,
652                                                      'Does not prepare slow query'
653                                                   );
654                                                   
655            1                                  9   is_deeply(
656                                                      \@slave_stats,
657                                                      [
658                                                         {
659                                                            _wait_skip_query => "should stop before here",
660                                                         },
661                                                      ],
662                                                      '_wait_skip_query() stopped waiting once query was skipped'
663                                                   );
664                                                   
665                                                   
666                                                   # #############################################################################
667                                                   # Test the big fish: pipeline_event().
668                                                   # #############################################################################
669            1                                 22   my $parser = new BinaryLogParser();
670            1                                 37   my @events;
671            1                                  2   my @queries;
672                                                   
673                                                   sub parse_binlog {
674            1                    1             4      my ( $file ) = @_;
675            1                                  4      @events = ();
676   ***      1     50                          53      open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
677            1                                  3      my $more_events = 1;
678            1                                  5      while ( $more_events ) {
679                                                         my $e = $parser->parse_event(
680           14                   14         16863            next_event => sub { return <$fh>;    },
681           26                   26           635            tell       => sub { return tell $fh; },
682            1                    1            10            oktorun    => sub { $more_events = $_[0]; },
683           13                                136         );
684           13    100                        2993         push @events, $e if $e;
685                                                      }
686            1                                 11      close $fh;
687            1                                  3      return;
688                                                   }
689                                                   
690            1                                  3   my $event;
691                                                   sub ple {
692           11                   11            75      $spf->{stats}->{events}++;
693           11                                 92      my $e = $spf->in_window(event=>$event, oktorun=>\&more_events);
694           11    100                          61      return unless $e;
695            6                                 41      $e = $spf->rewrite_query($e);
696   ***      6     50                          32      if ( $e ) {
697            6                                 51         push @queries, [ $e->{arg}, $e->{fingerprint} ];
698                                                      }
699                                                   }
700                                                   
701            1                                  8   parse_binlog("$trunk/common/t/samples/binlogs/binlog003.txt");
702                                                   # print Dumper(\@events);  # uncomment if you want to see what's going on
703                                                   
704            1                                 14   $spf->set_window(100, 300);
705            1                                  8   $spf->reset_pipeline_pos();
706            1                                  4   $slave_status->{exec_master_log_pos} = 263;
707            1                                  4   $slave_status->{relay_log_pos}       = 263;
708            1                                  5   $spf->_get_slave_status();
709                                                   
710                                                   # Slave is at event 1 (pos 263) and we "read" (shift) event 1,
711                                                   # so we are *not* in the window because we're not far enough ahead.
712                                                   # Given the 100 offset, we need to be at least pos 363, which is
713                                                   # event 3 at pos/offset 434.
714            1                                  3   $event = shift @events;
715            1                                  5   ple();
716            1                                  6   is_deeply(
717                                                      \@queries,
718                                                      [],
719                                                      "Query not pipelined because we're on top of the slave"
720                                                   );
721                                                      
722            1                                  8   $event = shift @events;
723            1                                  7   ple();
724            1                                  6   is_deeply(
725                                                      \@queries,
726                                                      [],
727                                                      "Query not pipelined because we're still not far enough ahead"
728                                                   );
729                                                   
730                                                   
731            1                                 14   $event = shift @events;  # event 3, first past offset
732            1                                  6   ple();
733            1                                  7   is_deeply(
734                                                      \@queries,
735                                                      [ [
736                                                         'select 1 from  t  where i=1',  # query
737                                                         'select * from t where i=?',    # fingerprint
738                                                      ] ],
739                                                      'Executes first query in the window'
740                                                   );
741                                                   
742                                                   # Events 4 and 5 are still in the window because
743                                                   #     slave pos    263
744                                                   #   + offset       100
745                                                   #   + window       300
746                                                   #   = outer limit  663
747                                                   # and event 6 begins at 721, past the outer limit.  But event 4
748                                                   # is going to trigger the interval which is 4,1,8 (args to new()).
749                                                   # So let's update the slave status as if the slave had caught up
750                                                   # to event 3.  But this make event 4 too close to the slave because
751                                                   # slave pos 434 + offset 100 = 535 as minimum pos ahead of slave.
752                                                   # So event 4 should be skipped and event 5 at pos 606 is next in window.
753            1                                 10   $slave_status->{exec_master_log_pos} = 434;
754            1                                  5   $slave_status->{relay_log_pos}       = 434;
755                                                   
756            1                                  4   @queries = ();  # clear event 3
757                                                   
758            1                                  4   $event = shift @events;  # event 4, triggers interval check
759            1                                  9   ple();
760            1                                  7   is_deeply(
761                                                      \@queries,
762                                                      [],
763                                                      'Query no longer in window after interval check'
764                                                   );
765                                                   
766            1                                 10   is(
767                                                      $spf->_get_next_chk_int(),
768                                                      8,
769                                                      'Next check interval longer'
770                                                   );
771                                                   
772            1                                  5   $event = shift @events;  # event 5
773            1                                  8   ple();
774            1                                  9   is_deeply(
775                                                      \@queries,
776                                                      [ [
777                                                         'select 1 from  t  limit 1',
778                                                         'select * from t limit ?',
779                                                      ] ],
780                                                      'Pipelines first query in updated window/interval'
781                                                   );
782                                                   
783                                                   # Now let's pretend like we've made it too far ahead of the slave,
784                                                   # past the window which ends at 835.  Event 8 at pos 911 is too far.
785                                                   
786            1                                 10   @queries = ();  # clear event 5
787                                                   
788            1                                  5   $event = shift @events;  # event 6
789            1                                  8   ple();
790            1                                  4   $event = shift @events;  # event 7
791            1                                  7   ple();
792            1                                 15   is_deeply(
793                                                      \@queries,
794                                                      [
795                                                         [
796                                                            'select 1 from  t where i = 3 or i = 5',
797                                                            'select * from t where i = ? or i = ?'
798                                                         ],
799                                                         [
800                                                            'select isnull(coalesce(  i = 11 )) from t where  i = 10',
801                                                            'select i = ? from t where i = ?'
802                                                         ]
803                                                      ],
804                                                      'Events 6 and 7'
805                                                   );
806                                                   
807            1                                 12   @queries = ();  # clear events 6 and 7
808                                                   
809                                                   # _in_window() is going to try to wait for the slave which will start
810                                                   # calling our callback, popping slave_stats, but we won't bother to
811                                                   # set this, we'll just terminate the loop early.
812            1                                  3   $oktorun = 0;
813            1                                  4   $event = shift @events;  # event 8
814            1                                  7   ple();
815            1                                 13   is_deeply(
816                                                      \@queries,
817                                                      [],
818                                                      'Event 8 too far ahead of slave'
819                                                   );
820                                                   
821                                                   # ###########################################################################
822                                                   # Online tests.
823                                                   # ###########################################################################
824            1                                 31   my $master_dbh = $sb->get_dbh_for('master');
825            1                                437   my $slave_dbh  = $sb->get_dbh_for('slave1');
826                                                   
827   ***      1     50     33                   18   SKIP: {
828            1                                312      skip 'Cannot connect to sandbox master or slave', 6
829                                                         unless $master_dbh && $slave_dbh;
830                                                   
831            1                                 22      my $spf = new SlavePrefetch(
832                                                         dbh             => $slave_dbh,
833                                                         oktorun         => \&oktorun,
834                                                         chk_int         => 4,
835                                                         chk_min         => 1,
836                                                         chk_max         => 8,
837                                                         QueryRewriter   => $qr,
838                                                         have_subqueries => 1,
839                                                         stats           => { events => 0 },
840                                                      );
841                                                   
842                                                      # Test that exec() actually executes the query.
843            1                                107      $slave_dbh->do('SET @a=1');
844            1                                 14      $spf->exec(query=>'SET @a=5', fingerprint=>'set @a=?');
845            1                                  3      is_deeply(
846                                                         $slave_dbh->selectrow_arrayref('SELECT @a'),
847                                                         ['5'],
848                                                         'exec() executes the query'
849                                                      );
850                                                   
851                                                      # This causes an error so that stats->{query_error} gets set
852                                                      # and we can check later that get_stats() returns the stats.
853            1                                 45      $spf->exec(query=>'foo', fingerprint=>'foo');
854                                                   
855                                                      # exec() should have stored the query time which we can
856                                                      # get from the stats.
857            1                                  9      my ($stats, $query_stats, $query_errors) = $spf->get_stats();
858            1                                  9      is_deeply(
859                                                         $stats,
860                                                         {
861                                                            events      => 0,
862                                                            query_error => 1,
863                                                         },
864                                                         'Get stats'
865                                                      );
866                                                   
867            1                                 12      is_deeply(
868                                                         $query_errors,
869                                                         {
870                                                            foo => 1,
871                                                         },
872                                                         'Get query errors'
873                                                      );
874                                                   
875   ***      1            33                   35      ok(
      ***                   33                        
876                                                         exists $query_stats->{'set @a=?'}
877                                                         && exists $query_stats->{'set @a=?'}->{avg}
878                                                         && exists $query_stats->{'set @a=?'}->{samples},
879                                                         'Get query stats'
880                                                      );
881                                                   
882                                                      # Test wait_for_master().
883            1                                  9      my $ms = $master_dbh->selectrow_hashref('SHOW MASTER STATUS');
884            1                                  3      my $ss = $slave_dbh->selectrow_hashref('SHOW SLAVE STATUS');
885            1                                779      my $master_pos = $ms->{Position};
886            1                                 20      my %wait_args = (
887                                                         dbh       => $slave_dbh,
888                                                         mfile     => $ss->{Relay_Master_Log_File},
889                                                         until_pos => $master_pos + 100,
890                                                      );
891            1                                 16      is(
892                                                         SlavePrefetch::_wait_for_master(%wait_args),
893                                                         -1,
894                                                         '_wait_for_master() timeout 1s after no events'
895                                                      );
896                                                   
897            1                                  9      $wait_args{until_pos} = $master_pos;
898            1                                 13      is(
899                                                         SlavePrefetch::_wait_for_master(%wait_args),
900                                                         0,
901                                                         '_wait_for_master() return immediately when already at pos'
902                                                      );
903                                                   };
904                                                   
905                                                   # #############################################################################
906                                                   # Test that we get a database.
907                                                   # #############################################################################
908            1                                  6   my @dbs;
909                                                   sub save_dbs {
910   ***      0                    0                    my ( %args ) = @_;
911   ***      0                                         push @dbs, $args{db};
912                                                   }
913                                                   sub use_db {
914   ***      0                    0                    my ( $dbh, $db ) = @_;
915   ***      0                                         push @dbs, "USE $db";
916                                                   };
917                                                   
918                                                   # Tests for carrying the db forward were removed because
919                                                   # this is now handled by an earlier processes in mk-slave-prefetch.
920                                                   
921                                                   # #############################################################################
922                                                   # Rewrite INSERT without columns list.
923                                                   # #############################################################################
924   ***      1     50                           7   SKIP: {
925            1                                  4      skip 'Cannot connect to sandbox slave', 2 unless $slave_dbh;
926                                                   
927            1                                 44      my $q  = new Quoter();
928            1                                 80      my $tp = new TableParser(Quoter => $q);
929                                                   
930                                                      # Load any 'ol table.  This one is like:
931                                                      # CREATE TABLE `issue_94` (
932                                                      #   a INT NOT NULL,
933                                                      #   b INT NOT NULL,
934                                                      #   c CHAR(16) NOT NULL,
935                                                      #   INDEX idx (a)
936                                                      # );
937            1                                 96      $sb->create_dbs($slave_dbh, [qw(test)]);
938            1                                837      $sb->load_file('slave1', 'common/t/samples/issue_94.sql');
939                                                   
940            1                             121053      my $spf = new SlavePrefetch(
941                                                         dbh             => $slave_dbh,
942                                                         oktorun         => \&oktorun,
943                                                         chk_int         => 4,
944                                                         chk_min         => 1,
945                                                         chk_max         => 8,
946                                                         QueryRewriter   => $qr,
947                                                         TableParser     => $tp,
948                                                         QueryParser     => $qp,
949                                                         Quoter          => $q,
950                                                      );
951            1                                 42      my $event = $spf->rewrite_query(
952                                                         {
953                                                            arg => "INSERT INTO test.issue_94 VALUES (1, 2, 'your ad here')",
954                                                         }
955                                                      );
956            1                                 24      is(
957                                                         $event->{arg},
958                                                         "select 1 from  test.issue_94  where `a`=1 and `b`= 2 and `c`= 'your ad here'",
959                                                         'Rewrote INSERT without columns list'
960                                                      );
961                                                   
962            1                                 13      $event = $spf->rewrite_query(
963                                                         {
964                                                            arg => "INSERT INTO issue_94 VALUES (1, 2, 'your ad here')",
965                                                         },
966                                                         default_db => 'test',
967                                                      );
968            1                                 12      is(
969                                                         $event->{arg},
970                                                         "select 1 from  issue_94  where `a`=1 and `b`= 2 and `c`= 'your ad here'",
971                                                         'Rewrote INSERT without columns list or db-qualified table'
972                                                      );
973                                                   
974            1                                 22      $sb->wipe_clean($slave_dbh);
975                                                   }
976                                                   
977                                                   
978                                                   # #############################################################################
979                                                   # Issue 1075: Check if relay log has changed at interval
980                                                   # #############################################################################
981            1                               1840   $oktorun     = 1;
982            1                                  5   $more_events = 1;
983            1                                 14   @queries = ();
984            1                                 42   @events  = (
985                                                      {
986                                                         arg         => 'update db.tbl set col=1 where id=1',
987                                                         offset      => 550,
988                                                         end_log_pos => 600,
989                                                      },
990                                                      {
991                                                         arg         => 'update db.tbl set col=1 where id=2',
992                                                         offset      => 600,
993                                                         end_log_pos => 700,
994                                                      },
995                                                      {
996                                                         arg         => 'update db.tbl set col=1 where id=3',
997                                                         offset      => 390,
998                                                         end_log_pos => 505,
999                                                      },
1000                                                  );
1001                                                  
1002           1                                 27   $spf = new SlavePrefetch(
1003                                                     dbh             => $dbh,
1004                                                     oktorun         => \&oktorun,
1005                                                     chk_int         => 2,
1006                                                     chk_min         => 1,
1007                                                     chk_max         => 3,
1008                                                     'io-lag'        => 0,
1009                                                     QueryRewriter   => $qr,
1010                                                     have_subqueries => 1,
1011                                                     stats           => { events => 0 },
1012                                                  );
1013           1                                205   $spf->set_callbacks( wait_for_master => \&wait_for_master );
1014           1                                  9   $spf->set_callbacks( show_slave_status => \&show_slave_status );
1015                                                  
1016           1                                 14   $spf->set_window(50, 500);
1017           1                                 18   $spf->set_pipeline_pos(500, 600);
1018                                                  
1019                                                  # Executing near end of bin01.
1020           1                                 26   $slave_status = {
1021                                                     master_log_file       => 'mysql-bin.000001',
1022                                                     read_master_log_pos   => 1_000,
1023                                                     exec_master_log_pos   => 1_000,
1024                                                     relay_master_log_file => 'mysql-bin.000001',
1025                                                     relay_log_file        => 'mysql-relay-bin.000001',
1026                                                     relay_log_pos         => 400,
1027                                                     slave_io_running      => 'Yes',
1028                                                     slave_sql_running     => 'Yes',
1029                                                  };
1030           1                                 15   $spf->_get_slave_status();
1031           1                                  5   @queries = ();
1032           1                                  6   $event   = shift @events;
1033           1                                 13   ple();
1034           1                                 31   is_deeply(
1035                                                     \@queries,
1036                                                     [[
1037                                                        'select isnull(coalesce(  col=1 )) from db.tbl where  id=1',
1038                                                        'select col=? from db.tbl where id=?',
1039                                                     ]],
1040                                                     "Exec near end of relay log 1 (issue 1075)"
1041                                                  );
1042                                                  
1043                                                  # Relay log changes to bin02.  Interval check will check slave status
1044                                                  # and see that relay log file has changed, resetting the pipeline pos
1045                                                  # to zero which will be behind so it will skip events until it's caught up.
1046           1                                 31   $slave_status = {
1047                                                     master_log_file       => 'mysql-bin.000002',
1048                                                     read_master_log_pos   => 300,
1049                                                     exec_master_log_pos   => 300,
1050                                                     relay_master_log_file => 'mysql-bin.000002',
1051                                                     relay_log_file        => 'mysql-relay-bin.000002',
1052                                                     relay_log_pos         => 200,
1053                                                     slave_io_running      => 'Yes',
1054                                                     slave_sql_running     => 'Yes',
1055                                                  };
1056           1                                 12   @queries = ();
1057           1                                  5   $event   = shift @events;
1058           1                                 10   ple();
1059           1                                235   is_deeply(
1060                                                     \@queries,
1061                                                     [],
1062                                                     "Drop query from old relay log, switch to new relay log (issue 1075)"
1063                                                  );
1064                                                  
1065           1                                 17   is(
1066                                                     $more_events,
1067                                                     0,
1068                                                     "No more events when relay log changes"
1069                                                  );
1070                                                  
1071                                                  # Should have switch to bin02 by now.
1072           1                                 19   $slave_status = {
1073                                                     master_log_file       => 'mysql-bin.000002',
1074                                                     read_master_log_pos   => 400,
1075                                                     exec_master_log_pos   => 303,
1076                                                     relay_master_log_file => 'mysql-bin.000002',
1077                                                     relay_log_file        => 'mysql-relay-bin.000002',
1078                                                     relay_log_pos         => 301,
1079                                                     slave_io_running      => 'Yes',
1080                                                     slave_sql_running     => 'Yes',
1081                                                  };
1082           1                                 11   @queries = ();
1083           1                                  5   $event   = shift @events;
1084           1                                  8   ple();
1085           1                                 14   is_deeply(
1086                                                     \@queries,
1087                                                     [[
1088                                                        'select isnull(coalesce(  col=1 )) from db.tbl where  id=3',
1089                                                        'select col=? from db.tbl where id=?',
1090                                                     ]],
1091                                                     "Excuting from new relay log (issue 1075)"
1092                                                  );
1093                                                  
1094                                                  # #############################################################################
1095                                                  # Done.
1096                                                  # #############################################################################
1097           1                                 15   my $output = '';
1098                                                  {
1099           1                                  5      local *STDERR;
               1                                 22   
1100           1                    1             4      open STDERR, '>', \$output;
               1                                582   
               1                                  4   
               1                                 12   
1101           1                                 31      $spf->_d('Complete test coverage');
1102                                                  }
1103                                                  like(
1104           1                                 30      $output,
1105                                                     qr/Complete test coverage/,
1106                                                     '_d() works'
1107                                                  );
1108           1                                  7   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
111   ***     50      0      1   unless $tmp_fh
341   ***     50      5      0   if (@slave_stats)
676   ***     50      0      1   unless open my $fh, '<', $file
684          100     12      1   if $e
694          100      5      6   unless $e
696   ***     50      6      0   if ($e)
827   ***     50      0      1   unless $master_dbh and $slave_dbh
924   ***     50      0      1   unless $slave_dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
827   ***     33      0      0      1   $master_dbh and $slave_dbh
875   ***     33      0      0      1   exists $$query_stats{'set @a=?'} && exists $$query_stats{'set @a=?'}{'avg'}
      ***     33      0      0      1   exists $$query_stats{'set @a=?'} && exists $$query_stats{'set @a=?'}{'avg'} && exists $$query_stats{'set @a=?'}{'samples'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine        Count Location            
----------------- ----- --------------------
BEGIN                 1 SlavePrefetch.t:10  
BEGIN                 1 SlavePrefetch.t:11  
BEGIN                 1 SlavePrefetch.t:1100
BEGIN                 1 SlavePrefetch.t:12  
BEGIN                 1 SlavePrefetch.t:14  
BEGIN                 1 SlavePrefetch.t:15  
BEGIN                 1 SlavePrefetch.t:16  
BEGIN                 1 SlavePrefetch.t:17  
BEGIN                 1 SlavePrefetch.t:18  
BEGIN                 1 SlavePrefetch.t:19  
BEGIN                 1 SlavePrefetch.t:20  
BEGIN                 1 SlavePrefetch.t:21  
BEGIN                 1 SlavePrefetch.t:22  
BEGIN                 1 SlavePrefetch.t:27  
BEGIN                 1 SlavePrefetch.t:4   
BEGIN                 1 SlavePrefetch.t:9   
__ANON__             14 SlavePrefetch.t:680 
__ANON__             26 SlavePrefetch.t:681 
__ANON__              1 SlavePrefetch.t:682 
more_events           1 SlavePrefetch.t:39  
oktorun              11 SlavePrefetch.t:36  
parse_binlog          1 SlavePrefetch.t:674 
ple                  11 SlavePrefetch.t:692 
show_slave_status    14 SlavePrefetch.t:167 
wait_for_master       5 SlavePrefetch.t:341 

Uncovered Subroutines
---------------------

Subroutine        Count Location            
----------------- ----- --------------------
save_dbs              0 SlavePrefetch.t:910 
use_db                0 SlavePrefetch.t:914 


