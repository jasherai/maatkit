---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableSyncer.pm   89.8   68.5   68.8  100.0    0.0    2.5   80.6
TableSyncer.t                  99.2   62.5   50.0  100.0    n/a   97.5   94.9
Total                          95.4   67.1   64.1  100.0    0.0  100.0   87.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:54 2010
Finish:       Thu Jun 24 19:37:54 2010

Run:          TableSyncer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:56 2010
Finish:       Thu Jun 24 19:38:15 2010

/home/daniel/dev/maatkit/common/TableSyncer.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2010 Baron Schwartz.
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
18                                                    # TableSyncer package $Revision: 6523 $
19                                                    # ###########################################################################
20                                                    package TableSyncer;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  8   
23             1                    1             9   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
32                                                    
33                                                    # Arguments:
34                                                    #   * MasterSlave    A MasterSlave module
35                                                    #   * Quoter         A Quoter module
36                                                    #   * VersionParser  A VersionParser module
37                                                    #   * TableChecksum  A TableChecksum module
38                                                    #   * DSNParser      (optional)
39                                                    sub new {
40    ***      5                    5      0     64      my ( $class, %args ) = @_;
41             5                                 54      my @required_args = qw(MasterSlave Quoter VersionParser TableChecksum);
42             5                                 30      foreach my $arg ( @required_args ) {
43            14    100                          95         die "I need a $arg argument" unless defined $args{$arg};
44                                                       }
45             1                                 10      my $self = { %args };
46             1                                 36      return bless $self, $class;
47                                                    }
48                                                    
49                                                    # Return the first plugin from the arrayref of TableSync* plugins
50                                                    # that can sync the given table struct.  plugin->can_sync() usually
51                                                    # returns a hashref that it wants back when plugin->prepare_to_sync()
52                                                    # is called.  Or, it may return nothing (false) to say that it can't
53                                                    # sync the table.
54                                                    sub get_best_plugin {
55    ***     24                   24      0    475      my ( $self, %args ) = @_;
56            24                                294      foreach my $arg ( qw(plugins tbl_struct) ) {
57    ***     48     50                         440         die "I need a $arg argument" unless $args{$arg};
58                                                       }
59            24                                 98      MKDEBUG && _d('Getting best plugin');
60            24                                100      foreach my $plugin ( @{$args{plugins}} ) {
              24                                173   
61            29                                111         MKDEBUG && _d('Trying plugin', $plugin->name);
62            29                                538         my ($can_sync, %plugin_args) = $plugin->can_sync(%args);
63            29    100                        8360         if ( $can_sync ) {
64            24                                 81           MKDEBUG && _d('Can sync with', $plugin->name, Dumper(\%plugin_args));
65            24                                411           return $plugin, %plugin_args;
66                                                          }
67                                                       }
68    ***      0                                  0      MKDEBUG && _d('No plugin can sync the table');
69    ***      0                                  0      return;
70                                                    }
71                                                    
72                                                    # Required arguments:
73                                                    #   * plugins         Arrayref of TableSync* modules, in order of preference
74                                                    #   * src             Hashref with source (aka left) dbh, db, tbl
75                                                    #   * dst             Hashref with destination (aka right) dbh, db, tbl
76                                                    #   * tbl_struct      Return val from TableParser::parser() for src and dst tbl
77                                                    #   * cols            Arrayref of column names to checksum/compare
78                                                    #   * chunk_size      Size/number of rows to select in each chunk
79                                                    #   * RowDiff         A RowDiff module
80                                                    #   * ChangeHandler   A ChangeHandler module
81                                                    # Optional arguments:
82                                                    #   * where           WHERE clause to restrict synced rows (default none)
83                                                    #   * bidirectional   If doing bidirectional sync (default no)
84                                                    #   * changing_src    If making changes on src (default no)
85                                                    #   * replicate       Checksum table if syncing via replication (default no)
86                                                    #   * function        Crypto hash func for checksumming chunks (default CRC32)
87                                                    #   * dry_run         Prepare to sync but don't actually sync (default no)
88                                                    #   * chunk_col       Column name to chunk table on (default auto-choose)
89                                                    #   * chunk_index     Index name to use for chunking table (default auto-choose)
90                                                    #   * index_hint      Use FORCE/USE INDEX (chunk_index) (default yes)
91                                                    #   * buffer_in_mysql  Use SQL_BUFFER_RESULT (default no)
92                                                    #   * buffer_to_client Use mysql_use_result (default no)
93                                                    #   * callback        Sub called before executing the sql (default none)
94                                                    #   * trace           Append trace message to change statements (default yes)
95                                                    #   * transaction     locking
96                                                    #   * change_dbh      locking
97                                                    #   * lock            locking
98                                                    #   * wait            locking
99                                                    #   * timeout_ok      locking
100                                                   sub sync_table {
101   ***     22                   22      0   7792      my ( $self, %args ) = @_;
102           22                                315      my @required_args = qw(plugins src dst tbl_struct cols chunk_size
103                                                                             RowDiff ChangeHandler);
104           22                                203      foreach my $arg ( @required_args ) {
105   ***    176     50                        1332         die "I need a $arg argument" unless $args{$arg};
106                                                      }
107                                                      MKDEBUG && _d('Syncing table with args:',
108           22                                 84         map { "$_: " . Dumper($args{$_}) }
109                                                         qw(plugins src dst tbl_struct cols chunk_size));
110                                                   
111           22                                277      my ($plugins, $src, $dst, $tbl_struct, $cols, $chunk_size, $rd, $ch)
112                                                         = @args{@required_args};
113           22                                165      my $dp = $self->{DSNParser};
114           22    100                         180      $args{trace} = 1 unless defined $args{trace};
115                                                   
116   ***     22    100     66                  233      if ( $args{bidirectional} && $args{ChangeHandler}->{queue} ) {
117                                                         # This should be checked by the caller but just in case...
118            1                                  5         die "Queueing does not work with bidirectional syncing";
119                                                      }
120                                                   
121   ***     21     50                         205      $args{index_hint}    = 1 unless defined $args{index_hint};
122           21           100                  166      $args{lock}        ||= 0;
123   ***     21            50                  194      $args{wait}        ||= 0;
124           21           100                  178      $args{transaction} ||= 0;
125   ***     21            50                  190      $args{timeout_ok}  ||= 0;
126                                                   
127           21                                126      my $q  = $self->{Quoter};
128           21                                140      my $vp = $self->{VersionParser};
129                                                   
130                                                      # ########################################################################
131                                                      # Get and prepare the first plugin that can sync this table.
132                                                      # ########################################################################
133           21                                305      my ($plugin, %plugin_args) = $self->get_best_plugin(%args);
134   ***     21     50                         199      die "No plugin can sync $src->{db}.$src->{tbl}" unless $plugin;
135                                                   
136                                                      # The row-level (state 2) checksums use __crc, so the table can't use that.
137           21                                127      my $crc_col = '__crc';
138           21                                206      while ( $tbl_struct->{is_col}->{$crc_col} ) {
139   ***      0                                  0         $crc_col = "_$crc_col"; # Prepend more _ until not a column.
140                                                      }
141           21                                 71      MKDEBUG && _d('CRC column:', $crc_col);
142                                                   
143                                                      # Make an index hint for either the explicitly given chunk_index
144                                                      # or the chunk_index chosen by the plugin if index_hint is true.
145           21                                 84      my $index_hint;
146   ***     21     50     33                  441      my $hint = ($vp->version_ge($src->{dbh}, '4.0.9')
147                                                                  && $vp->version_ge($dst->{dbh}, '4.0.9') ? 'FORCE' : 'USE')
148                                                               . ' INDEX';
149   ***     21     50     66                  442      if ( $args{chunk_index} ) {
                    100                               
150   ***      0                                  0         MKDEBUG && _d('Using given chunk index for index hint');
151   ***      0                                  0         $index_hint = "$hint (" . $q->quote($args{chunk_index}) . ")";
152                                                      }
153                                                      elsif ( $plugin_args{chunk_index} && $args{index_hint} ) {
154           15                                 54         MKDEBUG && _d('Using chunk index chosen by plugin for index hint');
155           15                                166         $index_hint = "$hint (" . $q->quote($plugin_args{chunk_index}) . ")";
156                                                      }
157           21                                871      MKDEBUG && _d('Index hint:', $index_hint);
158                                                   
159           21                                 95      eval {
160           21                                542         $plugin->prepare_to_sync(
161                                                            %args,
162                                                            %plugin_args,
163                                                            dbh        => $src->{dbh},
164                                                            db         => $src->{db},
165                                                            tbl        => $src->{tbl},
166                                                            crc_col    => $crc_col,
167                                                            index_hint => $index_hint,
168                                                         );
169                                                      };
170   ***     21     50                       27808      if ( $EVAL_ERROR ) {
171                                                         # At present, no plugin should fail to prepare, but just in case...
172   ***      0                                  0         die 'Failed to prepare TableSync', $plugin->name, ' plugin: ',
173                                                            $EVAL_ERROR;
174                                                      }
175                                                   
176                                                      # Some plugins like TableSyncChunk use checksum queries, others like
177                                                      # TableSyncGroupBy do not.  For those that do, make chunk (state 0)
178                                                      # and row (state 2) checksum queries.
179           21    100                         287      if ( $plugin->uses_checksum() ) {
180           15                                213         eval {
181           15                                292            my ($chunk_sql, $row_sql) = $self->make_checksum_queries(%args);
182           15                                204            $plugin->set_checksum_queries($chunk_sql, $row_sql);
183                                                         };
184   ***     15     50                         740         if ( $EVAL_ERROR ) {
185                                                            # This happens if src and dst are really different and the same
186                                                            # checksum algo and hash func can't be used on both.
187   ***      0                                  0            die "Failed to make checksum queries: $EVAL_ERROR";
188                                                         }
189                                                      } 
190                                                   
191                                                      # ########################################################################
192                                                      # Plugin is ready, return now if this is a dry run.
193                                                      # ########################################################################
194           21    100                         235      if ( $args{dry_run} ) {
195            1                                 19         return $ch->get_changes(), ALGORITHM => $plugin->name;
196                                                      }
197                                                   
198                                                      # ########################################################################
199                                                      # Start syncing the table.
200                                                      # ########################################################################
201                                                   
202                                                      # USE db on src and dst for cases like when replicate-do-db is being used.
203           20                                 93      eval {
204           20                               3928         $src->{dbh}->do("USE `$src->{db}`");
205           20                               3469         $dst->{dbh}->do("USE `$dst->{db}`");
206                                                      };
207   ***     20     50                         200      if ( $EVAL_ERROR ) {
208                                                         # This shouldn't happen, but just in case.  (The db and tbl on src
209                                                         # and dst should be checked before calling this sub.)
210   ***      0                                  0         die "Failed to USE database on source or destination: $EVAL_ERROR";
211                                                      }
212                                                   
213                                                      # For bidirectional syncing it's important to know on which dbh
214                                                      # changes are made or rows are fetched.  This identifies the dbhs,
215                                                      # then you can search for each one by its address like
216                                                      # "dbh DBI::db=HASH(0x1028b38)".
217           20                                 70      MKDEBUG && _d('left dbh', $src->{dbh});
218           20                                104      MKDEBUG && _d('right dbh', $dst->{dbh});
219                                                   
220           20                              94671      chomp(my $hostname = `hostname`);
221   ***     15            50                  319      my $trace_msg
222                                                         = $args{trace} ? "src_db:$src->{db} src_tbl:$src->{tbl} "
223                                                            . ($dp && $src->{dsn} ? "src_dsn:".$dp->as_string($src->{dsn}) : "")
224                                                            . " dst_db:$dst->{db} dst_tbl:$dst->{tbl} "
225                                                            . ($dp && $dst->{dsn} ? "dst_dsn:".$dp->as_string($dst->{dsn}) : "")
226   ***     20     50     33                  871            . " " . join(" ", map { "$_:" . ($args{$_} || 0) }
      ***            50     33                        
      ***            50                               
      ***            50                               
                    100                               
227                                                                        qw(lock transaction changing_src replicate bidirectional))
228                                                            . " pid:$PID "
229                                                            . ($ENV{USER} ? "user:$ENV{USER} " : "")
230                                                            . ($hostname  ? "host:$hostname"   : "")
231                                                         :                "";
232           20                                101      MKDEBUG && _d("Binlog trace message:", $trace_msg);
233                                                   
234           20                               2072      $self->lock_and_wait(%args, lock_level => 2);  # per-table lock
235                                                   
236           20                                158      my $callback = $args{callback};
237           20                                147      my $cycle    = 0;
238           20                                642      while ( !$plugin->done() ) {
239                                                   
240                                                         # Do as much of the work as possible before opening a transaction or
241                                                         # locking the tables.
242           46                               1982         MKDEBUG && _d('Beginning sync cycle', $cycle);
243           46                               1026         my $src_sql = $plugin->get_sql(
244                                                            database => $src->{db},
245                                                            table    => $src->{tbl},
246                                                            where    => $args{where},
247                                                         );
248           46                              19549         my $dst_sql = $plugin->get_sql(
249                                                            database => $dst->{db},
250                                                            table    => $dst->{tbl},
251                                                            where    => $args{where},
252                                                         );
253                                                   
254           46    100                       14034         if ( $args{transaction} ) {
255   ***      1     50                          21            if ( $args{bidirectional} ) {
      ***            50                               
256                                                               # Making changes on src and dst.
257   ***      0                                  0               $src_sql .= ' FOR UPDATE';
258   ***      0                                  0               $dst_sql .= ' FOR UPDATE';
259                                                            }
260                                                            elsif ( $args{changing_src} ) {
261                                                               # Making changes on master (src) which replicate to slave (dst).
262   ***      0                                  0               $src_sql .= ' FOR UPDATE';
263   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
264                                                            }
265                                                            else {
266                                                               # Making changes on slave (dst).
267            1                                 13               $src_sql .= ' LOCK IN SHARE MODE';
268            1                                  9               $dst_sql .= ' FOR UPDATE';
269                                                            }
270                                                         }
271           46                                240         MKDEBUG && _d('src:', $src_sql);
272           46                                188         MKDEBUG && _d('dst:', $dst_sql);
273                                                   
274                                                         # Give callback a chance to do something with the SQL statements.
275           46    100                         336         $callback->($src_sql, $dst_sql) if $callback;
276                                                   
277                                                         # Prepare each host for next sync cycle. This does stuff
278                                                         # like reset/init MySQL accumulator vars, etc.
279           46                                554         $plugin->prepare_sync_cycle($src);
280           46                              11199         $plugin->prepare_sync_cycle($dst);
281                                                   
282                                                         # Prepare SQL statements on host.  These aren't real prepared
283                                                         # statements (i.e. no ? placeholders); we just need sths to
284                                                         # pass to compare_sets().  Also, we can control buffering
285                                                         # (mysql_use_result) on the sths.
286           46                                171         my $src_sth = $src->{dbh}->prepare($src_sql);
287           46                                143         my $dst_sth = $dst->{dbh}->prepare($dst_sql);
288   ***     46     50                         553         if ( $args{buffer_to_client} ) {
289   ***      0                                  0            $src_sth->{mysql_use_result} = 1;
290   ***      0                                  0            $dst_sth->{mysql_use_result} = 1;
291                                                         }
292                                                   
293                                                         # The first cycle should lock to begin work; after that, unlock only if
294                                                         # the plugin says it's OK (it may want to dig deeper on the rows it
295                                                         # currently has locked).
296           46                                206         my $executed_src = 0;
297           46    100    100                  652         if ( !$cycle || !$plugin->pending_changes() ) {
298                                                            # per-sync cycle lock
299           31                                917            $executed_src
300                                                               = $self->lock_and_wait(%args, src_sth => $src_sth, lock_level => 1);
301                                                         }
302                                                   
303                                                         # The source sth might have already been executed by lock_and_wait().
304           46    100                       30538         $src_sth->execute() unless $executed_src;
305           46                              77927         $dst_sth->execute();
306                                                   
307                                                         # Compare rows in the two sths.  If any differences are found
308                                                         # (same_row, not_in_left, not_in_right), the appropriate $syncer
309                                                         # methods are called to handle them.  Changes may be immediate, or...
310           46                               1288         $rd->compare_sets(
311                                                            left_sth   => $src_sth,
312                                                            right_sth  => $dst_sth,
313                                                            left_dbh   => $src->{dbh},
314                                                            right_dbh  => $dst->{dbh},
315                                                            syncer     => $plugin,
316                                                            tbl_struct => $tbl_struct,
317                                                         );
318                                                         # ...changes may be queued and executed now.
319           46                               2735         $ch->process_rows(1, $trace_msg);
320                                                   
321           46                               7713         MKDEBUG && _d('Finished sync cycle', $cycle);
322           46                               2847         $cycle++;
323                                                      }
324                                                   
325           20                                984      $ch->process_rows(0, $trace_msg);
326                                                   
327           20                               3424      $self->unlock(%args, lock_level => 2);
328                                                   
329           20                                363      return $ch->get_changes(), ALGORITHM => $plugin->name;
330                                                   }
331                                                   
332                                                   sub make_checksum_queries {
333   ***     16                   16      0    364      my ( $self, %args ) = @_;
334           16                                250      my @required_args = qw(src dst tbl_struct);
335           16                                144      foreach my $arg ( @required_args ) {
336   ***     48     50                         390         die "I need a $arg argument" unless $args{$arg};
337                                                      }
338           16                                131      my ($src, $dst, $tbl_struct) = @args{@required_args};
339           16                                101      my $checksum = $self->{TableChecksum};
340                                                   
341                                                      # Decide on checksumming strategy and store checksum query prototypes for
342                                                      # later.
343           16                                359      my $src_algo = $checksum->best_algorithm(
344                                                         algorithm => 'BIT_XOR',
345                                                         dbh       => $src->{dbh},
346                                                         where     => 1,
347                                                         chunk     => 1,
348                                                         count     => 1,
349                                                      );
350           16                                726      my $dst_algo = $checksum->best_algorithm(
351                                                         algorithm => 'BIT_XOR',
352                                                         dbh       => $dst->{dbh},
353                                                         where     => 1,
354                                                         chunk     => 1,
355                                                         count     => 1,
356                                                      );
357   ***     16     50                         612      if ( $src_algo ne $dst_algo ) {
358   ***      0                                  0         die "Source and destination checksum algorithms are different: ",
359                                                            "$src_algo on source, $dst_algo on destination"
360                                                      }
361           16                                 62      MKDEBUG && _d('Chosen algo:', $src_algo);
362                                                   
363           16                                309      my $src_func = $checksum->choose_hash_func(dbh => $src->{dbh}, %args);
364           16                               6606      my $dst_func = $checksum->choose_hash_func(dbh => $dst->{dbh}, %args);
365   ***     16     50                        6318      if ( $src_func ne $dst_func ) {
366   ***      0                                  0         die "Source and destination hash functions are different: ",
367                                                         "$src_func on source, $dst_func on destination";
368                                                      }
369           16                                 56      MKDEBUG && _d('Chosen hash func:', $src_func);
370                                                   
371                                                      # Since the checksum algo and hash func are the same on src and dst
372                                                      # it doesn't matter if we use src_algo/func or dst_algo/func.
373                                                   
374           16                                263      my $crc_wid    = $checksum->get_crc_wid($src->{dbh}, $src_func);
375           16                               4098      my ($crc_type) = $checksum->get_crc_type($src->{dbh}, $src_func);
376           16                                 75      my $opt_slice;
377   ***     16     50     33                  450      if ( $src_algo eq 'BIT_XOR' && $crc_type !~ m/int$/ ) {
378           16                                276         $opt_slice = $checksum->optimize_xor(
379                                                            dbh      => $src->{dbh},
380                                                            function => $src_func
381                                                         );
382                                                      }
383                                                   
384           16                               7999      my $chunk_sql = $checksum->make_checksum_query(
385                                                         %args,
386                                                         db        => $src->{db},
387                                                         tbl       => $src->{tbl},
388                                                         algorithm => $src_algo,
389                                                         function  => $src_func,
390                                                         crc_wid   => $crc_wid,
391                                                         crc_type  => $crc_type,
392                                                         opt_slice => $opt_slice,
393                                                         replicate => undef, # replicate means something different to this sub
394                                                      );                     # than what we use it for; do not pass it!
395           16                              16364      MKDEBUG && _d('Chunk sql:', $chunk_sql);
396           16                                204      my $row_sql = $checksum->make_row_checksum(
397                                                         %args,
398                                                         function => $src_func,
399                                                      );
400           16                               7954      MKDEBUG && _d('Row sql:', $row_sql);
401           16                                256      return $chunk_sql, $row_sql;
402                                                   }
403                                                   
404                                                   sub lock_table {
405   ***      4                    4      0    404      my ( $self, $dbh, $where, $db_tbl, $mode ) = @_;
406            4                                 37      my $query = "LOCK TABLES $db_tbl $mode";
407            4                                 12      MKDEBUG && _d($query);
408            4                                625      $dbh->do($query);
409            4                                 34      MKDEBUG && _d('Acquired table lock on', $where, 'in', $mode, 'mode');
410                                                   }
411                                                   
412                                                   # Doesn't work quite the same way as lock_and_wait. It will unlock any LOWER
413                                                   # priority lock level, not just the exact same one.
414                                                   sub unlock {
415   ***     20                   20      0    502      my ( $self, %args ) = @_;
416                                                   
417           20                                313      foreach my $arg ( qw(src dst lock transaction lock_level) ) {
418   ***    100     50                         810         die "I need a $arg argument" unless defined $args{$arg};
419                                                      }
420           20                                113      my $src = $args{src};
421           20                                124      my $dst = $args{dst};
422                                                   
423           20    100    100                  351      return unless $args{lock} && $args{lock} <= $args{lock_level};
424                                                   
425                                                      # First, unlock/commit.
426            3                                 26      foreach my $dbh ( $src->{dbh}, $dst->{dbh} ) {
427            6    100                          52         if ( $args{transaction} ) {
428            2                                  7            MKDEBUG && _d('Committing', $dbh);
429            2                               5931            $dbh->commit();
430                                                         }
431                                                         else {
432            4                                 19            my $sql = 'UNLOCK TABLES';
433            4                                 13            MKDEBUG && _d($dbh, $sql);
434            4                                580            $dbh->do($sql);
435                                                         }
436                                                      }
437                                                   
438            3                                 46      return;
439                                                   }
440                                                   
441                                                   # Arguments:
442                                                   #    lock         scalar: lock level requested by user
443                                                   #    local_level  scalar: lock level code is calling from
444                                                   #    src          hashref
445                                                   #    dst          hashref
446                                                   # Lock levels:
447                                                   #   0 => none
448                                                   #   1 => per sync cycle
449                                                   #   2 => per table
450                                                   #   3 => global
451                                                   # This function might actually execute the $src_sth.  If we're using
452                                                   # transactions instead of table locks, the $src_sth has to be executed before
453                                                   # the MASTER_POS_WAIT() on the slave.  The return value is whether the
454                                                   # $src_sth was executed.
455                                                   sub lock_and_wait {
456   ***     52                   52      0   2343      my ( $self, %args ) = @_;
457           52                                526      my $result = 0;
458                                                   
459           52                                469      foreach my $arg ( qw(src dst lock lock_level) ) {
460   ***    208     50                        1720         die "I need a $arg argument" unless defined $args{$arg};
461                                                      }
462           52                                285      my $src = $args{src};
463           52                                272      my $dst = $args{dst};
464                                                   
465           52    100    100                  986      return unless $args{lock} && $args{lock} == $args{lock_level};
466            4                                 27      MKDEBUG && _d('lock and wait, lock level', $args{lock});
467                                                   
468                                                      # First, commit/unlock the previous transaction/lock.
469            4                               1094      foreach my $dbh ( $src->{dbh}, $dst->{dbh} ) {
470            8    100                          72         if ( $args{transaction} ) {
471            2                                  9            MKDEBUG && _d('Committing', $dbh);
472            2                               4864            $dbh->commit();
473                                                         }
474                                                         else {
475            6                                 32            my $sql = 'UNLOCK TABLES';
476            6                                 20            MKDEBUG && _d($dbh, $sql);
477            6                                978            $dbh->do($sql);
478                                                         }
479                                                      }
480                                                   
481                                                      # User wants us to lock for consistency.  But lock only on source initially;
482                                                      # might have to wait for the slave to catch up before locking on the dest.
483            4    100                          43      if ( $args{lock} == 3 ) {
484            1                                 14         my $sql = 'FLUSH TABLES WITH READ LOCK';
485            1                                  9         MKDEBUG && _d($src->{dbh}, $sql);
486            1                               2055         $src->{dbh}->do($sql);
487                                                      }
488                                                      else {
489                                                         # Lock level 2 (per-table) or 1 (per-sync cycle)
490            3    100                          24         if ( $args{transaction} ) {
491   ***      1     50                          18            if ( $args{src_sth} ) {
492                                                               # Execute the $src_sth on the source, so LOCK IN SHARE MODE/FOR
493                                                               # UPDATE will lock the rows examined.
494            1                                  7               MKDEBUG && _d('Executing statement on source to lock rows');
495                                                   
496            1                                  8               my $sql = "START TRANSACTION /*!40108 WITH CONSISTENT SNAPSHOT */";
497            1                                  3               MKDEBUG && _d($src->{dbh}, $sql);
498            1                                160               $src->{dbh}->do($sql);
499                                                   
500            1                                409               $args{src_sth}->execute();
501            1                                  6               $result = 1;
502                                                            }
503                                                         }
504                                                         else {
505   ***      2     50                          59            $self->lock_table($src->{dbh}, 'source',
506                                                               $self->{Quoter}->quote($src->{db}, $src->{tbl}),
507                                                               $args{changing_src} ? 'WRITE' : 'READ');
508                                                         }
509                                                      }
510                                                   
511                                                      # If there is any error beyond this point, we need to unlock/commit.
512            4                                 58      eval {
513            4    100                          49         if ( $args{wait} ) {
514                                                            # Always use the misc_dbh dbh to check the master's position, because
515                                                            # the main dbh might be in use due to executing $src_sth.
516            1                                 45            $self->{MasterSlave}->wait_for_master(
517                                                               $src->{misc_dbh}, $dst->{dbh}, $args{wait}, $args{timeout_ok});
518                                                         }
519                                                   
520                                                         # Don't lock the destination if we're making changes on the source
521                                                         # (for sync-to-master and sync via replicate) else the destination
522                                                         # won't be apply to make the changes.
523   ***      4     50                         337         if ( $args{changing_src} ) {
524   ***      0                                  0            MKDEBUG && _d('Not locking destination because changing source ',
525                                                               '(syncing via replication or sync-to-master)');
526                                                         }
527                                                         else {
528            4    100                          55            if ( $args{lock} == 3 ) {
                    100                               
529            1                                 14               my $sql = 'FLUSH TABLES WITH READ LOCK';
530            1                                  4               MKDEBUG && _d($dst->{dbh}, ',', $sql);
531            1                                468               $dst->{dbh}->do($sql);
532                                                            }
533                                                            elsif ( !$args{transaction} ) {
534   ***      2     50                          28               $self->lock_table($dst->{dbh}, 'dest',
535                                                                  $self->{Quoter}->quote($dst->{db}, $dst->{tbl}),
536                                                                  $args{execute} ? 'WRITE' : 'READ');
537                                                            }
538                                                         }
539                                                      };
540                                                   
541   ***      4     50                          33      if ( $EVAL_ERROR ) {
542                                                         # Must abort/unlock/commit so that we don't interfere with any further
543                                                         # tables we try to do.
544   ***      0      0                           0         if ( $args{src_sth}->{Active} ) {
545   ***      0                                  0            $args{src_sth}->finish();
546                                                         }
547   ***      0                                  0         foreach my $dbh ( $src->{dbh}, $dst->{dbh}, $src->{misc_dbh} ) {
548   ***      0      0                           0            next unless $dbh;
549   ***      0                                  0            MKDEBUG && _d('Caught error, unlocking/committing on', $dbh);
550   ***      0                                  0            $dbh->do('UNLOCK TABLES');
551   ***      0      0                           0            $dbh->commit() unless $dbh->{AutoCommit};
552                                                         }
553                                                         # ... and then re-throw the error.
554   ***      0                                  0         die $EVAL_ERROR;
555                                                      }
556                                                   
557            4                                 55      return $result;
558                                                   }
559                                                   
560                                                   # This query will check all needed privileges on the table without actually
561                                                   # changing anything in it.  We can't use REPLACE..SELECT because that doesn't
562                                                   # work inside of LOCK TABLES.  Returns 1 if user has all needed privs to
563                                                   # sync table, else returns 0.
564                                                   sub have_all_privs {
565   ***      5                    5      0     94      my ( $self, $dbh, $db, $tbl ) = @_;
566            5                                124      my $db_tbl = $self->{Quoter}->quote($db, $tbl);
567            5                                519      my $sql    = "SHOW FULL COLUMNS FROM $db_tbl";
568            5                                 25      MKDEBUG && _d('Permissions check:', $sql);
569            5                                133      my $cols       = $dbh->selectall_arrayref($sql, {Slice => {}});
570            5                                108      my ($hdr_name) = grep { m/privileges/i } keys %{$cols->[0]};
              45                                297   
               5                                 69   
571            5                                 50      my $privs      = $cols->[0]->{$hdr_name};
572            5                                 52      $sql = "DELETE FROM $db_tbl LIMIT 0"; # FULL COLUMNS doesn't show all privs
573            5                                 20      MKDEBUG && _d('Permissions check:', $sql);
574            5                                 39      eval { $dbh->do($sql); };
               5                                403   
575            5    100                          53      my $can_delete = $EVAL_ERROR ? 0 : 1;
576                                                   
577            5                                 19      MKDEBUG && _d('User privs on', $db_tbl, ':', $privs,
578                                                         ($can_delete ? 'delete' : ''));
579   ***      5    100     66                  250      if ( $privs =~ m/select/ && $privs =~ m/insert/ && $privs =~ m/update/ 
                           100                        
                           100                        
580                                                           && $can_delete ) {
581            2                                 11         MKDEBUG && _d('User has all privs');
582            2                                 64         return 1;
583                                                      }
584            3                                 22      MKDEBUG && _d('User does not have all privs');
585            3                                122      return 0;
586                                                   }
587                                                   
588                                                   sub _d {
589            1                    1            19      my ($package, undef, $line) = caller 0;
590   ***      2     50                          20      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 19   
               2                                 19   
591            1                                  8           map { defined $_ ? $_ : 'undef' }
592                                                           @_;
593            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
594                                                   }
595                                                   
596                                                   1;
597                                                   
598                                                   # ###########################################################################
599                                                   # End TableSyncer package
600                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
43           100      4     10   unless defined $args{$arg}
57    ***     50      0     48   unless $args{$arg}
63           100     24      5   if ($can_sync)
105   ***     50      0    176   unless $args{$arg}
114          100      4     18   unless defined $args{'trace'}
116          100      1     21   if ($args{'bidirectional'} and $args{'ChangeHandler'}{'queue'})
121   ***     50     21      0   unless defined $args{'index_hint'}
134   ***     50      0     21   unless $plugin
146   ***     50     21      0   $vp->version_ge($$src{'dbh'}, '4.0.9') && $vp->version_ge($$dst{'dbh'}, '4.0.9') ? :
149   ***     50      0     21   if ($args{'chunk_index'}) { }
             100     15      6   elsif ($plugin_args{'chunk_index'} and $args{'index_hint'}) { }
170   ***     50      0     21   if ($EVAL_ERROR)
179          100     15      6   if ($plugin->uses_checksum)
184   ***     50      0     15   if ($EVAL_ERROR)
194          100      1     20   if ($args{'dry_run'})
207   ***     50      0     20   if ($EVAL_ERROR)
226   ***     50      3      0   $dp && $$src{'dsn'} ? :
      ***     50      3      0   $dp && $$dst{'dsn'} ? :
      ***     50      3      0   $ENV{'USER'} ? :
      ***     50      3      0   $hostname ? :
             100      3     17   $args{'trace'} ? :
254          100      1     45   if ($args{'transaction'})
255   ***     50      0      1   if ($args{'bidirectional'}) { }
      ***     50      0      1   elsif ($args{'changing_src'}) { }
275          100      1     45   if $callback
288   ***     50      0     46   if ($args{'buffer_to_client'})
297          100     31     15   if (not $cycle or not $plugin->pending_changes)
304          100     45      1   unless $executed_src
336   ***     50      0     48   unless $args{$arg}
357   ***     50      0     16   if ($src_algo ne $dst_algo)
365   ***     50      0     16   if ($src_func ne $dst_func)
377   ***     50     16      0   if ($src_algo eq 'BIT_XOR' and not $crc_type =~ /int$/)
418   ***     50      0    100   unless defined $args{$arg}
423          100     17      3   unless $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
427          100      2      4   if ($args{'transaction'}) { }
460   ***     50      0    208   unless defined $args{$arg}
465          100     48      4   unless $args{'lock'} and $args{'lock'} == $args{'lock_level'}
470          100      2      6   if ($args{'transaction'}) { }
483          100      1      3   if ($args{'lock'} == 3) { }
490          100      1      2   if ($args{'transaction'}) { }
491   ***     50      1      0   if ($args{'src_sth'})
505   ***     50      0      2   $args{'changing_src'} ? :
513          100      1      3   if ($args{'wait'})
523   ***     50      0      4   if ($args{'changing_src'}) { }
528          100      1      3   if ($args{'lock'} == 3) { }
             100      2      1   elsif (not $args{'transaction'}) { }
534   ***     50      0      2   $args{'execute'} ? :
541   ***     50      0      4   if ($EVAL_ERROR)
544   ***      0      0      0   if ($args{'src_sth'}{'Active'})
548   ***      0      0      0   unless $dbh
551   ***      0      0      0   unless $$dbh{'AutoCommit'}
575          100      3      2   $EVAL_ERROR ? :
579          100      2      3   if ($privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/ and $can_delete)
590   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
116   ***     66     21      0      1   $args{'bidirectional'} and $args{'ChangeHandler'}{'queue'}
146   ***     33      0      0     21   $vp->version_ge($$src{'dbh'}, '4.0.9') && $vp->version_ge($$dst{'dbh'}, '4.0.9')
149   ***     66      6      0     15   $plugin_args{'chunk_index'} and $args{'index_hint'}
226   ***     33      0      0      3   $dp && $$src{'dsn'}
      ***     33      0      0      3   $dp && $$dst{'dsn'}
377   ***     33      0      0     16   $src_algo eq 'BIT_XOR' and not $crc_type =~ /int$/
423          100     16      1      3   $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
465          100     43      5      4   $args{'lock'} and $args{'lock'} == $args{'lock_level'}
579   ***     66      0      1      4   $privs =~ /select/ and $privs =~ /insert/
             100      1      1      3   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
             100      2      1      2   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/ and $can_delete

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
122          100      4     17   $args{'lock'} ||= 0
123   ***     50      0     21   $args{'wait'} ||= 0
124          100      1     20   $args{'transaction'} ||= 0
125   ***     50      0     21   $args{'timeout_ok'} ||= 0
221   ***     50      0     15   $args{$_} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
297          100     20     11     15   not $cycle or not $plugin->pending_changes


Covered Subroutines
-------------------

Subroutine            Count Pod Location                                          
--------------------- ----- --- --------------------------------------------------
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:22 
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:23 
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:25 
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:26 
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:31 
_d                        1     /home/daniel/dev/maatkit/common/TableSyncer.pm:589
get_best_plugin          24   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:55 
have_all_privs            5   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:565
lock_and_wait            52   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:456
lock_table                4   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:405
make_checksum_queries    16   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:333
new                       5   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:40 
sync_table               22   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:101
unlock                   20   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:415


TableSyncer.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  3   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More;
               1                                  3   
               1                                 10   
13                                                    
14                                                    # TableSyncer and its required modules:
15             1                    1            21   use TableSyncer;
               1                                  3   
               1                                 14   
16             1                    1            13   use MasterSlave;
               1                                  4   
               1                                 13   
17             1                    1            11   use Quoter;
               1                                  3   
               1                                 10   
18             1                    1            10   use TableChecksum;
               1                                  2   
               1                                 11   
19             1                    1            11   use VersionParser;
               1                                  2   
               1                                  9   
20                                                    # The sync plugins:
21             1                    1            10   use TableSyncChunk;
               1                                  3   
               1                                 11   
22             1                    1            12   use TableSyncNibble;
               1                                  3   
               1                                 12   
23             1                    1            11   use TableSyncGroupBy;
               1                                  4   
               1                                 10   
24             1                    1            15   use TableSyncStream;
               1                                  4   
               1                                  9   
25                                                    # Helper modules for the sync plugins:
26             1                    1            13   use TableChunker;
               1                                  3   
               1                                 14   
27             1                    1            13   use TableNibbler;
               1                                  3   
               1                                 10   
28                                                    # Modules for sync():
29             1                    1            11   use ChangeHandler;
               1                                  5   
               1                                 10   
30             1                    1            11   use RowDiff;
               1                                  3   
               1                                 10   
31                                                    # And other modules:
32             1                    1            10   use MySQLDump;
               1                                  3   
               1                                 11   
33             1                    1            10   use TableParser;
               1                                  3   
               1                                 12   
34             1                    1            12   use DSNParser;
               1                                  3   
               1                                 11   
35             1                    1            13   use Sandbox;
               1                                  3   
               1                                 10   
36             1                    1            11   use MaatkitTest;
               1                                  5   
               1                                 39   
37                                                    
38    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 24   
39                                                    
40             1                                 10   my $dp = new DSNParser(opts=>$dsn_opts);
41             1                                228   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
42             1                                 50   my $dbh      = $sb->get_dbh_for('master');
43             1                                387   my $src_dbh  = $sb->get_dbh_for('master');
44             1                                289   my $dst_dbh  = $sb->get_dbh_for('slave1');
45                                                    
46    ***      1     50     33                  278   if ( !$src_dbh || !$dbh ) {
      ***            50                               
47    ***      0                                  0      plan skip_all => 'Cannot connect to sandbox master';
48                                                    }
49                                                    elsif ( !$dst_dbh ) {
50    ***      0                                  0      plan skip_all => 'Cannot connect to sandbox slave';
51                                                    }
52                                                    else {
53             1                                 11      plan tests => 58;
54                                                    }
55                                                    
56             1                                508   $sb->create_dbs($dbh, ['test']);
57             1                                715   $sb->load_file('master', 'common/t/samples/before-TableSyncChunk.sql');
58                                                    
59             1                             938237   my $q  = new Quoter();
60             1                                117   my $tp = new TableParser(Quoter=>$q);
61             1                                135   my $du = new MySQLDump( cache => 0 );
62                                                    
63                                                    # ###########################################################################
64                                                    # Make a TableSyncer object.
65                                                    # ###########################################################################
66                                                    throws_ok(
67             1                    1            56      sub { new TableSyncer() },
68             1                                114      qr/I need a MasterSlave/,
69                                                       'MasterSlave required'
70                                                    );
71                                                    throws_ok(
72             1                    1            28      sub { new TableSyncer(MasterSlave=>1) },
73             1                               2218      qr/I need a Quoter/,
74                                                       'Quoter required'
75                                                    );
76                                                    throws_ok(
77             1                    1            29      sub { new TableSyncer(MasterSlave=>1, Quoter=>1) },
78             1                               1594      qr/I need a VersionParser/,
79                                                       'VersionParser required'
80                                                    );
81                                                    throws_ok(
82             1                    1            30      sub { new TableSyncer(MasterSlave=>1, Quoter=>1, VersionParser=>1) },
83             1                               1597      qr/I need a TableChecksum/,
84                                                       'TableChecksum required'
85                                                    );
86                                                    
87             1                               1579   my $rd       = new RowDiff(dbh=>$src_dbh);
88             1                                 98   my $ms       = new MasterSlave();
89             1                                 75   my $vp       = new VersionParser();
90             1                                 56   my $checksum = new TableChecksum(
91                                                       Quoter         => $q,
92                                                       VersionParser => $vp,
93                                                    );
94             1                                 97   my $syncer = new TableSyncer(
95                                                       MasterSlave   => $ms,
96                                                       Quoter        => $q,
97                                                       TableChecksum => $checksum,
98                                                       VersionParser => $vp,
99                                                       DSNParser     => $dp,
100                                                   );
101            1                                 18   isa_ok($syncer, 'TableSyncer');
102                                                   
103            1                               1489   my $chunker = new TableChunker( Quoter => $q, MySQLDump => $du );
104            1                                139   my $nibbler = new TableNibbler( TableParser => $tp, Quoter => $q );
105                                                   
106                                                   # Global vars used/set by the subs below and accessed throughout the tests.
107            1                                 89   my $src;
108            1                                  3   my $dst;
109            1                                  4   my $tbl_struct;
110            1                                 13   my %actions;
111            1                                  4   my @rows;
112            1                                  5   my ($sync_chunk, $sync_nibble, $sync_groupby, $sync_stream);
113            1                                  5   my $plugins = [];
114                                                   
115                                                   # Call this func to re-make/reset the plugins.
116                                                   sub make_plugins {
117           18                   18           400      $sync_chunk = new TableSyncChunk(
118                                                         TableChunker => $chunker,
119                                                         Quoter       => $q,
120                                                      );
121           18                               1974      $sync_nibble = new TableSyncNibble(
122                                                         TableNibbler  => $nibbler,
123                                                         TableChunker  => $chunker,
124                                                         TableParser   => $tp,
125                                                         Quoter        => $q,
126                                                      );
127           18                               2136      $sync_groupby = new TableSyncGroupBy( Quoter => $q );
128           18                               1379      $sync_stream  = new TableSyncStream( Quoter => $q );
129                                                   
130           18                               1205      $plugins = [$sync_chunk, $sync_nibble, $sync_groupby, $sync_stream];
131                                                   
132           18                               1411      return;
133                                                   }
134                                                   
135                                                   sub new_ch {
136           22                   22           151      my ( $dbh, $queue ) = @_;
137                                                      return new ChangeHandler(
138                                                         Quoter    => $q,
139                                                         left_db   => $src->{db},
140                                                         left_tbl  => $src->{tbl},
141                                                         right_db  => $dst->{db},
142                                                         right_tbl => $dst->{tbl},
143                                                         actions => [
144                                                            sub {
145           52                   52         26262               my ( $sql, $change_dbh ) = @_;
146           52                                445               push @rows, $sql;
147           52    100                         423               if ( $change_dbh ) {
      ***            50                               
148                                                                  # dbh passed through change() or process_rows()
149           21                             3393830                  $change_dbh->do($sql);
150                                                               }
151                                                               elsif ( $dbh ) {
152                                                                  # dbh passed to this sub
153   ***      0                                  0                  $dbh->do($sql);
154                                                               }
155                                                               else {
156                                                                  # default dst dbh for this test script
157           31                             2703140                  $dst_dbh->do($sql);
158                                                               }
159                                                            }
160           22    100                         932         ],
161                                                         replace => 0,
162                                                         queue   => defined $queue ? $queue : 1,
163                                                      );
164                                                   }
165                                                   
166                                                   # Shortens/automates a lot of the setup needed for calling
167                                                   # TableSyncer::sync_table.  At minimum, you can pass just
168                                                   # the src and dst args which are db.tbl args to sync. Various
169                                                   # global vars are set: @rows, %actions, etc.
170                                                   sub sync_table {
171           18                   18           389      my ( %args ) = @_;
172           18                                225      my ($src_db_tbl, $dst_db_tbl) = @args{qw(src dst)};
173           18                                403      my ($src_db, $src_tbl) = $q->split_unquote($src_db_tbl);
174           18                               1090      my ($dst_db, $dst_tbl) = $q->split_unquote($dst_db_tbl);
175           18    100                         787      if ( $args{plugins} ) {
176           11                                106         $plugins = $args{plugins};
177                                                      }
178                                                      else {
179            7                                 54         make_plugins();
180                                                      }
181           18                                488      $tbl_struct = $tp->parse(
182                                                         $du->get_create_table($src_dbh, $q, $src_db, $src_tbl));
183           18                              27454      $src = {
184                                                         dbh      => $src_dbh,
185                                                         dsn      => {h=>'127.1',P=>'12345',},
186                                                         misc_dbh => $dbh,
187                                                         db       => $src_db,
188                                                         tbl      => $src_tbl,
189                                                      };
190           18                                454      $dst = {
191                                                         dbh => $dst_dbh,
192                                                         dsn => {h=>'127.1',P=>'12346',},
193                                                         db  => $dst_db,
194                                                         tbl => $dst_tbl,
195                                                      };
196           18                                202      @rows = ();
197           18           100                  883      %actions = $syncer->sync_table(
      ***                   50                        
198                                                         plugins       => $plugins,
199                                                         src           => $src,
200                                                         dst           => $dst,
201                                                         tbl_struct    => $tbl_struct,
202                                                         cols          => $tbl_struct->{cols},
203                                                         chunk_size    => $args{chunk_size} || 5,
204                                                         dry_run       => $args{dry_run},
205                                                         function      => $args{function} || 'SHA1',
206                                                         lock          => $args{lock},
207                                                         transaction   => $args{transaction},
208                                                         callback      => $args{callback},
209                                                         RowDiff       => $rd,
210                                                         ChangeHandler => new_ch(),
211                                                         trace         => 0,
212                                                      );
213                                                   
214           18                               2584      return;
215                                                   }
216                                                   
217                                                   # ###########################################################################
218                                                   # Test get_best_plugin() (formerly best_algorithm()).
219                                                   # ###########################################################################
220            1                                 13   make_plugins();
221            1                                 29   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q, 'test', 'test5'));
222            1                               1029   is_deeply(
223                                                      [
224                                                         $syncer->get_best_plugin(
225                                                            plugins     => $plugins,
226                                                            tbl_struct  => $tbl_struct,
227                                                         )
228                                                      ],
229                                                      [ $sync_groupby ],
230                                                      'Best plugin GroupBy'
231                                                   );
232                                                   
233            1                                 21   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test3'));
234            1                               1393   my ($plugin, %plugin_args) = $syncer->get_best_plugin(
235                                                      plugins     => $plugins,
236                                                      tbl_struct  => $tbl_struct,
237                                                   );
238            1                                 19   is_deeply(
239                                                      [ $plugin, \%plugin_args, ],
240                                                      [ $sync_chunk, { chunk_index => 'PRIMARY', chunk_col => 'a', } ],
241                                                      'Best plugin Chunk'
242                                                   );
243                                                   
244            1                                 25   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test6'));
245            1                               1054   ($plugin, %plugin_args) = $syncer->get_best_plugin(
246                                                      plugins     => $plugins,
247                                                      tbl_struct  => $tbl_struct,
248                                                   );
249            1                                 25   is_deeply(
250                                                      [ $plugin, \%plugin_args, ],
251                                                      [ $sync_nibble,{ chunk_index => 'a', key_cols => [qw(a)], small_table=>0 } ],
252                                                      'Best plugin Nibble'
253                                                   );
254                                                   
255                                                   # ###########################################################################
256                                                   # Test sync_table() for each plugin with a basic, 4 row data set.
257                                                   # ###########################################################################
258                                                   
259                                                   # test1 has 4 rows and test2, which is the same struct, is empty.
260                                                   # So after sync, test2 should have the same 4 rows as test1.
261            1                                 34   my $test1_rows = [
262                                                    [qw(1 en)],
263                                                    [qw(2 ca)],
264                                                    [qw(3 ab)],
265                                                    [qw(4 bz)],
266                                                   ];
267            1                                 10   my $inserts = [
268                                                      "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('1', 'en')",
269                                                      "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('2', 'ca')",
270                                                      "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('3', 'ab')",
271                                                      "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('4', 'bz')",
272                                                   ];
273                                                   
274                                                   # First, do a dry run sync, so nothing should happen.
275            1                              85379   $dst_dbh->do('TRUNCATE TABLE test.test2');
276                                                   
277            1                                 33   sync_table(
278                                                      src     => "test.test1",
279                                                      dst     => "test.test2",
280                                                      dry_run => 1,
281                                                   );
282            1                                 17   is_deeply(
283                                                      \%actions,
284                                                      {
285                                                         DELETE    => 0,
286                                                         INSERT    => 0,
287                                                         REPLACE   => 0,
288                                                         UPDATE    => 0,
289                                                         ALGORITHM => 'Chunk',
290                                                      },
291                                                      'Dry run, no changes, Chunk plugin'
292                                                   );
293                                                   
294            1                                 20   is_deeply(
295                                                      \@rows,
296                                                      [],
297                                                      'Dry run, no SQL statements made'
298                                                   );
299                                                   
300            1                                  5   is_deeply(
301                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
302                                                      [],
303                                                      'Dry run, no rows changed'
304                                                   );
305                                                   
306                                                   # Now do the real syncs that should insert 4 rows into test2.
307                                                   
308                                                   # Sync with Chunk.
309            1                                 48   sync_table(
310                                                      src => "test.test1",
311                                                      dst => "test.test2",
312                                                   );
313            1                                 37   is_deeply(
314                                                      \%actions,
315                                                      {
316                                                         DELETE    => 0,
317                                                         INSERT    => 4,
318                                                         REPLACE   => 0,
319                                                         UPDATE    => 0,
320                                                         ALGORITHM => 'Chunk',
321                                                      },
322                                                      'Sync with Chunk, 4 INSERTs'
323                                                   );
324                                                   
325            1                                 42   is_deeply(
326                                                      \@rows,
327                                                      $inserts,
328                                                      'Sync with Chunk, ChangeHandler made INSERT statements'
329                                                   );
330                                                   
331            1                                  5   is_deeply(
332                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
333                                                      $test1_rows,
334                                                      'Sync with Chunk, dst rows match src rows'
335                                                   );
336                                                   
337                                                   # Sync with Chunk again, but use chunk_size = 1k which should be converted.
338            1                              43926   $dst_dbh->do('TRUNCATE TABLE test.test2');
339            1                                 21   sync_table(
340                                                      src        => "test.test1",
341                                                      dst        => "test.test2",
342                                                      chunk_size => '1k',
343                                                   );
344                                                   
345            1                                 54   is_deeply(
346                                                      \%actions,
347                                                      {
348                                                         DELETE    => 0,
349                                                         INSERT    => 4,
350                                                         REPLACE   => 0,
351                                                         UPDATE    => 0,
352                                                         ALGORITHM => 'Chunk',
353                                                      },
354                                                      'Sync with Chunk chunk size 1k, 4 INSERTs'
355                                                   );
356                                                   
357            1                                 31   is_deeply(
358                                                      \@rows,
359                                                      $inserts,
360                                                      'Sync with Chunk chunk size 1k, ChangeHandler made INSERT statements'
361                                                   );
362                                                   
363            1                                  4   is_deeply(
364                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
365                                                      $test1_rows,
366                                                      'Sync with Chunk chunk size 1k, dst rows match src rows'
367                                                   );
368                                                   
369                                                   # Sync with Nibble.
370            1                              56647   $dst_dbh->do('TRUNCATE TABLE test.test2');
371            1                                 26   sync_table(
372                                                      src     => "test.test1",
373                                                      dst     => "test.test2",
374                                                      plugins => [ $sync_nibble ],
375                                                   );
376                                                   
377            1                                 53   is_deeply(
378                                                      \%actions,
379                                                      {
380                                                         DELETE    => 0,
381                                                         INSERT    => 4,
382                                                         REPLACE   => 0,
383                                                         UPDATE    => 0,
384                                                         ALGORITHM => 'Nibble',
385                                                      },
386                                                      'Sync with Nibble, 4 INSERTs'
387                                                   );
388                                                   
389            1                                 29   is_deeply(
390                                                      \@rows,
391                                                      $inserts,
392                                                      'Sync with Nibble, ChangeHandler made INSERT statements'
393                                                   );
394                                                   
395            1                                  8   is_deeply(
396                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
397                                                      $test1_rows,
398                                                      'Sync with Nibble, dst rows match src rows'
399                                                   );
400                                                   
401                                                   # Sync with GroupBy.
402            1                              55700   $dst_dbh->do('TRUNCATE TABLE test.test2');
403            1                                 26   sync_table(
404                                                      src     => "test.test1",
405                                                      dst     => "test.test2",
406                                                      plugins => [ $sync_groupby ],
407                                                   );
408                                                   
409            1                                 52   is_deeply(
410                                                      \%actions,
411                                                      {
412                                                         DELETE    => 0,
413                                                         INSERT    => 4,
414                                                         REPLACE   => 0,
415                                                         UPDATE    => 0,
416                                                         ALGORITHM => 'GroupBy',
417                                                      },
418                                                      'Sync with GroupBy, 4 INSERTs'
419                                                   );
420                                                   
421            1                                 30   is_deeply(
422                                                      \@rows,
423                                                      $inserts,
424                                                      'Sync with GroupBy, ChangeHandler made INSERT statements'
425                                                   );
426                                                   
427            1                                  4   is_deeply(
428                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
429                                                      $test1_rows,
430                                                      'Sync with GroupBy, dst rows match src rows'
431                                                   );
432                                                   
433                                                   # Sync with Stream.
434            1                              45455   $dst_dbh->do('TRUNCATE TABLE test.test2');
435            1                                 30   sync_table(
436                                                      src     => "test.test1",
437                                                      dst     => "test.test2",
438                                                      plugins => [ $sync_stream ],
439                                                   );
440                                                   
441            1                                 50   is_deeply(
442                                                      \%actions,
443                                                      {
444                                                         DELETE    => 0,
445                                                         INSERT    => 4,
446                                                         REPLACE   => 0,
447                                                         UPDATE    => 0,
448                                                         ALGORITHM => 'Stream',
449                                                      },
450                                                      'Sync with Stream, 4 INSERTs'
451                                                   );
452                                                   
453            1                                 30   is_deeply(
454                                                      \@rows,
455                                                      $inserts,
456                                                      'Sync with Stream, ChangeHandler made INSERT statements'
457                                                   );
458                                                   
459            1                                  8   is_deeply(
460                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
461                                                      $test1_rows,
462                                                      'Sync with Stream, dst rows match src rows'
463                                                   );
464                                                   
465                                                   # #############################################################################
466                                                   # Check that the plugins can resolve unique key violations.
467                                                   # #############################################################################
468            1                                 70   make_plugins();
469                                                   
470            1                                 10   sync_table(
471                                                      src     => "test.test3",
472                                                      dst     => "test.test4",
473                                                      plugins => [ $sync_stream ],
474                                                   );
475                                                   
476            1                                 96   is_deeply(
477                                                      $dst_dbh->selectall_arrayref('select * from test.test4 order by a', { Slice => {}} ),
478                                                      [ { a => 1, b => 2 }, { a => 2, b => 1 } ],
479                                                      'Resolves unique key violations with Stream'
480                                                   );
481                                                   
482            1                                 29   sync_table(
483                                                      src     => "test.test3",
484                                                      dst     => "test.test4",
485                                                      plugins => [ $sync_chunk ],
486                                                   );
487                                                   
488            1                                 37   is_deeply(
489                                                      $dst_dbh->selectall_arrayref('select * from test.test4 order by a', { Slice => {}} ),
490                                                      [ { a => 1, b => 2 }, { a => 2, b => 1 } ],
491                                                      'Resolves unique key violations with Chunk'
492                                                   );
493                                                   
494                                                   # ###########################################################################
495                                                   # Test locking.
496                                                   # ###########################################################################
497            1                                 37   make_plugins();
498                                                   
499            1                                 16   sync_table(
500                                                      src  => "test.test1",
501                                                      dst  => "test.test2",
502                                                      lock => 1,
503                                                   );
504                                                   
505                                                   # The locks should be released.
506            1                                274   ok($src_dbh->do('select * from test.test4'), 'Cycle locks released');
507                                                   
508            1                                 10   sync_table(
509                                                      src  => "test.test1",
510                                                      dst  => "test.test2",
511                                                      lock => 2,
512                                                   );
513                                                   
514                                                   # The locks should be released.
515            1                                322   ok($src_dbh->do('select * from test.test4'), 'Table locks released');
516                                                   
517            1                                 20   sync_table(
518                                                      src  => "test.test1",
519                                                      dst  => "test.test2",
520                                                      lock => 3,
521                                                   );
522                                                   
523            1                                679   ok(
524                                                      $dbh->do('replace into test.test3 select * from test.test3 limit 0'),
525                                                      'Does not lock in level 3 locking'
526                                                   );
527                                                   
528            1                                 13   eval {
529            1                                 22      $syncer->lock_and_wait(
530                                                         src         => $src,
531                                                         dst         => $dst,
532                                                         lock        => 3,
533                                                         lock_level  => 3,
534                                                         replicate   => 0,
535                                                         timeout_ok  => 1,
536                                                         transaction => 0,
537                                                         wait        => 60,
538                                                      );
539                                                   };
540            1                                 17   is($EVAL_ERROR, '', 'Locks in level 3');
541                                                   
542                                                   # See DBI man page.
543            1                    1             8   use POSIX ':signal_h';
               1                                  2   
               1                                 15   
544            1                                 80   my $mask = POSIX::SigSet->new(SIGALRM);    # signals to mask in the handler
545            1                    1            58   my $action = POSIX::SigAction->new( sub { die "maatkit timeout" }, $mask, );
               1                                 19   
546            1                                  9   my $oldaction = POSIX::SigAction->new();
547            1                                 88   sigaction( SIGALRM, $action, $oldaction );
548                                                   
549                                                   throws_ok (
550                                                      sub {
551            1                    1            40         alarm 1;
552            1                                 11         $dbh->do('replace into test.test3 select * from test.test3 limit 0');
553                                                      },
554            1                                 39      qr/maatkit timeout/,
555                                                      "Level 3 lock NOT released",
556                                                   );
557                                                   
558                                                   # Kill the DBHs it in the right order: there's a connection waiting on
559                                                   # a lock.
560            1                                435   $src_dbh->disconnect();
561            1                                895   $dst_dbh->disconnect();
562            1                                 30   $src_dbh = $sb->get_dbh_for('master');
563            1                                508   $dst_dbh = $sb->get_dbh_for('slave1');
564                                                   
565            1                                545   $src->{dbh} = $src_dbh;
566            1                                  7   $dst->{dbh} = $dst_dbh;
567                                                   
568                                                   # ###########################################################################
569                                                   # Test TableSyncGroupBy.
570                                                   # ###########################################################################
571            1                                129   make_plugins();
572            1                                 15   $sb->load_file('master', 'common/t/samples/before-TableSyncGroupBy.sql');
573            1                             1903756   sleep 1;
574                                                   
575            1                                 80   sync_table(
576                                                      src     => "test.test1",
577                                                      dst     => "test.test2",
578                                                      plugins => [ $sync_groupby ],
579                                                   );
580                                                   
581            1                                 37   is_deeply(
582                                                      $dst_dbh->selectall_arrayref('select * from test.test2 order by a, b, c', { Slice => {}} ),
583                                                      [
584                                                         { a => 1, b => 2, c => 3 },
585                                                         { a => 1, b => 2, c => 3 },
586                                                         { a => 1, b => 2, c => 3 },
587                                                         { a => 1, b => 2, c => 3 },
588                                                         { a => 2, b => 2, c => 3 },
589                                                         { a => 2, b => 2, c => 3 },
590                                                         { a => 2, b => 2, c => 3 },
591                                                         { a => 2, b => 2, c => 3 },
592                                                         { a => 3, b => 2, c => 3 },
593                                                         { a => 3, b => 2, c => 3 },
594                                                      ],
595                                                      'Table synced with GroupBy',
596                                                   );
597                                                   
598                                                   # #############################################################################
599                                                   # Issue 96: mk-table-sync: Nibbler infinite loop
600                                                   # #############################################################################
601            1                                 54   make_plugins();
602            1                                 26   $sb->load_file('master', 'common/t/samples/issue_96.sql');
603            1                             1810920   sleep 1;
604                                                   
605                                                   # Make paranoid-sure that the tables differ.
606            1                                 13   my $r1 = $src_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t WHERE package_id=4');
607            1                                  8   my $r2 = $dst_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t2 WHERE package_id=4');
608            1                                456   is_deeply(
609                                                      [ $r1->[0]->[0], $r2->[0]->[0] ],
610                                                      [ 'ta',          'zz'          ],
611                                                      'Infinite loop table differs (issue 96)'
612                                                   );
613                                                   
614            1                                 47   sync_table(
615                                                      src     => "issue_96.t",
616                                                      dst     => "issue_96.t2",
617                                                      plugins => [ $sync_nibble ],
618                                                   );
619                                                   
620            1                                  6   $r1 = $src_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t WHERE package_id=4');
621            1                                  4   $r2 = $dst_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t2 WHERE package_id=4');
622                                                   
623                                                   # Other tests below rely on this table being synced, so die
624                                                   # if it fails to sync.
625   ***      1     50                         427   is(
626                                                      $r1->[0]->[0],
627                                                      $r2->[0]->[0],
628                                                      'Sync infinite loop table (issue 96)'
629                                                   ) or die "Failed to sync issue_96.t";
630                                                   
631                                                   # #############################################################################
632                                                   # Test check_permissions().
633                                                   # #############################################################################
634                                                   
635   ***      1     50                          16   SKIP: {
636            1                                 10      skip "Not tested on MySQL $sandbox_version", 5
637                                                         unless $sandbox_version gt '4.0';
638                                                   
639                                                   # Re-using issue_96.t from above.
640            1                                 25   is(
641                                                      $syncer->have_all_privs($src->{dbh}, 'issue_96', 't'),
642                                                      1,
643                                                      'Have all privs'
644                                                   );
645                                                   
646            1                              21499   diag(`/tmp/12345/use -u root -e "CREATE USER 'bob'\@'\%' IDENTIFIED BY 'bob'"`);
647            1                              19604   diag(`/tmp/12345/use -u root -e "GRANT select ON issue_96.t TO 'bob'\@'\%'"`);
648            1                                 49   my $bob_dbh = DBI->connect(
649                                                      "DBI:mysql:;host=127.0.0.1;port=12345", 'bob', 'bob',
650                                                         { PrintError => 0, RaiseError => 1 });
651                                                   
652            1                                 36   is(
653                                                      $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
654                                                      0,
655                                                      "Don't have all privs, just select"
656                                                   );
657                                                   
658            1                              19549   diag(`/tmp/12345/use -u root -e "GRANT insert ON issue_96.t TO 'bob'\@'\%'"`);
659            1                                 37   is(
660                                                      $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
661                                                      0,
662                                                      "Don't have all privs, just select and insert"
663                                                   );
664                                                   
665            1                              19617   diag(`/tmp/12345/use -u root -e "GRANT update ON issue_96.t TO 'bob'\@'\%'"`);
666            1                                 36   is(
667                                                      $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
668                                                      0,
669                                                      "Don't have all privs, just select, insert and update"
670                                                   );
671                                                   
672            1                              22811   diag(`/tmp/12345/use -u root -e "GRANT delete ON issue_96.t TO 'bob'\@'\%'"`);
673            1                                 44   is(
674                                                      $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
675                                                      1,
676                                                      "Bob got his privs"
677                                                   );
678                                                   
679            1                              19463   diag(`/tmp/12345/use -u root -e "DROP USER 'bob'"`);
680                                                   }
681                                                   
682                                                   # ###########################################################################
683                                                   # Test that the calback gives us the src and dst sql.
684                                                   # ###########################################################################
685            1                                 28   make_plugins;
686                                                   # Re-using issue_96.t from above.  The tables are already in sync so there
687                                                   # should only be 1 sync cycle.
688            1                                 15   my @sqls;
689                                                   sync_table(
690                                                      src        => "issue_96.t",
691                                                      dst        => "issue_96.t2",
692                                                      chunk_size => 1000,
693                                                      plugins    => [ $sync_nibble ],
694            1                    1            26      callback   => sub { push @sqls, @_; },
695            1                                 37   );
696                                                   
697   ***      1     50                          32   my $queries = ($sandbox_version gt '4.0' ?
698                                                      [
699                                                         'SELECT /*issue_96.t:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, \'0\'))), 0) AS crc FROM `issue_96`.`t` FORCE INDEX (`package_id`) WHERE (1=1)',
700                                                         'SELECT /*issue_96.t2:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, \'0\'))), 0) AS crc FROM `issue_96`.`t2` FORCE INDEX (`package_id`) WHERE (1=1)',
701                                                      ] :
702                                                      [
703                                                         "SELECT /*issue_96.t:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(RIGHT(MAX(\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), SHA1(CONCAT(\@crc, SHA1(CONCAT_WS('#', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))))))), 40), 0) AS crc FROM `issue_96`.`t` FORCE INDEX (`package_id`) WHERE (1=1)",
704                                                         "SELECT /*issue_96.t2:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, COALESCE(RIGHT(MAX(\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), SHA1(CONCAT(\@crc, SHA1(CONCAT_WS('#', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))))))), 40), 0) AS crc FROM `issue_96`.`t2` FORCE INDEX (`package_id`) WHERE (1=1)",
705                                                      ],
706                                                   );
707            1                                 23   is_deeply(
708                                                      \@sqls,
709                                                      $queries,
710                                                      'Callback gives src and dst sql'
711                                                   );
712                                                   
713                                                   # #############################################################################
714                                                   # Test that make_checksum_queries() doesn't pass replicate.
715                                                   # #############################################################################
716                                                   
717                                                   # Re-using issue_96.* tables from above.
718                                                   
719   ***      1     50                          27   $queries = ($sandbox_version gt '4.0' ?
720                                                      [
721                                                         'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, COALESCE(LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, \'0\'))), 0) AS crc FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/',
722                                                         "`package_id`, `location`, `from_city`, SHA1(CONCAT_WS('#', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`))))",
723                                                      ] :
724                                                      [
725                                                         "SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, COALESCE(RIGHT(MAX(\@crc := CONCAT(LPAD(\@cnt := \@cnt + 1, 16, '0'), SHA1(CONCAT(\@crc, SHA1(CONCAT_WS('#', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))))))), 40), 0) AS crc FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/",
726                                                         "`package_id`, `location`, `from_city`, SHA1(CONCAT_WS('#', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`))))",
727                                                      ],
728                                                   );
729                                                   
730            1                                 24   @sqls = $syncer->make_checksum_queries(
731                                                      replicate  => 'bad',
732                                                      src        => $src,
733                                                      dst        => $dst,
734                                                      tbl_struct => $tbl_struct,
735                                                      function   => 'SHA1',
736                                                   );
737            1                                 13   is_deeply(
738                                                      \@sqls,
739                                                      $queries,
740                                                      'make_checksum_queries() does not pass replicate arg'
741                                                   );
742                                                   
743                                                   # #############################################################################
744                                                   # Issue 464: Make mk-table-sync do two-way sync
745                                                   # #############################################################################
746   ***      1     50                          16   SKIP: {
747            1                                 20      skip "Not tested with MySQL $sandbox_version", 7
748                                                         unless $sandbox_version gt '4.0';
749                                                   
750            1                             2169166   diag(`$trunk/sandbox/start-sandbox master 12347 >/dev/null`);
751            1                                 39   my $dbh2 = $sb->get_dbh_for('slave2');
752   ***      1     50                          15   SKIP: {
753            1                                585      skip 'Cannot connect to sandbox master', 7 unless $dbh;
754   ***      1     50                          12      skip 'Cannot connect to second sandbox master', 7 unless $dbh2;
755                                                   
756                                                      sub set_bidi_callbacks {
757                                                         $sync_chunk->set_callback('same_row', sub {
758           12                   12          1158            my ( %args ) = @_;
759           12                                132            my ($lr, $rr, $syncer) = @args{qw(lr rr syncer)};
760           12                                 75            my $ch = $syncer->{ChangeHandler};
761           12                                 40            my $change_dbh;
762           12                                 45            my $auth_row;
763                                                   
764           12                                 63            my $left_ts  = $lr->{ts};
765           12                                 66            my $right_ts = $rr->{ts};
766           12                                 48            MKDEBUG && TableSyncer::_d("left ts: $left_ts");
767           12                                 38            MKDEBUG && TableSyncer::_d("right ts: $right_ts");
768                                                   
769   ***     12            50                  128            my $cmp = ($left_ts || '') cmp ($right_ts || '');
      ***                   50                        
770           12    100                          95            if ( $cmp == -1 ) {
      ***            50                               
771            9                                 31               MKDEBUG && TableSyncer::_d("right dbh $dbh2 is newer; update left dbh $src_dbh");
772            9                                122               $ch->set_src('right', $dbh2);
773            9                                843               $auth_row   = $args{rr};
774            9                                 42               $change_dbh = $src_dbh;
775                                                            }
776                                                            elsif ( $cmp == 1 ) {
777            3                                 10               MKDEBUG && TableSyncer::_d("left dbh $src_dbh is newer; update right dbh $dbh2");
778            3                                 62               $ch->set_src('left', $src_dbh);
779            3                                263               $auth_row  = $args{lr};
780            3                                 15               $change_dbh = $dbh2;
781                                                            }
782           12                                156            return ('UPDATE', $auth_row, $change_dbh);
783            3                    3           133         });
784                                                         $sync_chunk->set_callback('not_in_right', sub {
785            3                    3           276            my ( %args ) = @_;
786            3                                 50            $args{syncer}->{ChangeHandler}->set_src('left', $src_dbh);
787            3                                287            return 'INSERT', $args{lr}, $dbh2;
788            3                                167         });
789                                                         $sync_chunk->set_callback('not_in_left', sub {
790            6                    6           478            my ( %args ) = @_;
791            6                                 92            $args{syncer}->{ChangeHandler}->set_src('right', $dbh2);
792            6                                590            return 'INSERT', $args{rr}, $src_dbh;
793            3                                135         });
794                                                      };
795                                                   
796                                                      # Proper data on both tables after bidirectional sync.
797            1                                 62      my $bidi_data = 
798                                                         [
799                                                            [1,   'abc',   1,  '2010-02-01 05:45:30'],
800                                                            [2,   'def',   2,  '2010-01-31 06:11:11'],
801                                                            [3,   'ghi',   5,  '2010-02-01 09:17:52'],
802                                                            [4,   'jkl',   6,  '2010-02-01 10:11:33'],
803                                                            [5,   undef,   0,  '2010-02-02 05:10:00'],
804                                                            [6,   'p',     4,  '2010-01-31 10:17:00'],
805                                                            [7,   'qrs',   5,  '2010-02-01 10:11:11'],
806                                                            [8,   'tuv',   6,  '2010-01-31 10:17:20'],
807                                                            [9,   'wxy',   7,  '2010-02-01 10:17:00'],
808                                                            [10,  'z',     8,  '2010-01-31 10:17:08'],
809                                                            [11,  '?',     0,  '2010-01-29 11:17:12'],
810                                                            [12,  '',      0,  '2010-02-01 11:17:00'],
811                                                            [13,  'hmm',   1,  '2010-02-02 12:17:31'],
812                                                            [14,  undef,   0,  '2010-01-31 10:17:00'],
813                                                            [15,  'gtg',   7,  '2010-02-02 06:01:08'],
814                                                            [17,  'good',  1,  '2010-02-02 21:38:03'],
815                                                            [20,  'new', 100,  '2010-02-01 04:15:36'],
816                                                         ];
817                                                   
818                                                      # ########################################################################
819                                                      # First bidi test with chunk size=2, roughly 9 chunks.
820                                                      # ########################################################################
821                                                      # Load "master" data.
822            1                                 24      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
823            1                             160114      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
824                                                      # Load remote data.
825            1                             190125      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
826            1                             325791      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
827            1                             199958      make_plugins();
828            1                                 22      set_bidi_callbacks();
829            1                                 52      $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q, 'bidi','t'));
830                                                   
831            1                               1957      $src->{db}           = 'bidi';
832            1                                  9      $src->{tbl}          = 't';
833            1                                 11      $dst->{db}           = 'bidi';
834            1                                  5      $dst->{tbl}          = 't';
835            1                                  9      $dst->{dbh}          = $dbh2;            # Must set $dbh2 here and
836                                                   
837            1                                 13      my %args = (
838                                                         src           => $src,
839                                                         dst           => $dst,
840                                                         tbl_struct    => $tbl_struct,
841                                                         cols          => [qw(ts)],  # Compare only ts col when chunks differ.
842                                                         plugins       => $plugins,
843                                                         function      => 'SHA1',
844                                                         ChangeHandler => new_ch($dbh2, 0), # here to override $dst_dbh.
845                                                         RowDiff       => $rd,
846                                                         chunk_size    => 2,
847                                                      );
848            1                                432      @rows = ();
849                                                   
850            1                                 30      $syncer->sync_table(%args, plugins => [$sync_chunk]);
851                                                   
852            1                                  5      my $res = $src_dbh->selectall_arrayref('select * from bidi.t order by id');
853            1                                634      is_deeply(
854                                                         $res,
855                                                         $bidi_data,
856                                                         'Bidirectional sync "master" (chunk size 2)'
857                                                      );
858                                                   
859            1                                  6      $res = $dbh2->selectall_arrayref('select * from bidi.t order by id');
860            1                                679      is_deeply(
861                                                         $res,
862                                                         $bidi_data,
863                                                         'Bidirectional sync remote-1 (chunk size 2)'
864                                                      );
865                                                   
866                                                      # ########################################################################
867                                                      # Test it again with a larger chunk size, roughly half the table.
868                                                      # ########################################################################
869            1                                 32      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
870            1                             222525      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
871            1                             173449      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
872            1                             332245      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
873            1                             133877      make_plugins();
874            1                                 19      set_bidi_callbacks();
875            1                                 44      $args{ChangeHandler} = new_ch($dbh2, 0);
876            1                                576      @rows = ();
877                                                   
878            1                                 63      $syncer->sync_table(%args, plugins => [$sync_chunk], chunk_size => 10);
879                                                   
880            1                                 10      $res = $src_dbh->selectall_arrayref('select * from bidi.t order by id');
881            1                                736      is_deeply(
882                                                         $res,
883                                                         $bidi_data,
884                                                         'Bidirectional sync "master" (chunk size 10)'
885                                                      );
886                                                   
887            1                                  5      $res = $dbh2->selectall_arrayref('select * from bidi.t order by id');
888            1                                643      is_deeply(
889                                                         $res,
890                                                         $bidi_data,
891                                                         'Bidirectional sync remote-1 (chunk size 10)'
892                                                      );
893                                                   
894                                                      # ########################################################################
895                                                      # Chunk whole table.
896                                                      # ########################################################################
897            1                                 34      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
898            1                             602394      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
899            1                             265719      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
900            1                             265791      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
901            1                             151059      make_plugins();
902            1                                 18      set_bidi_callbacks();
903            1                                 44      $args{ChangeHandler} = new_ch($dbh2, 0);
904            1                                532      @rows = ();
905                                                   
906            1                                 58      $syncer->sync_table(%args, plugins => [$sync_chunk], chunk_size => 100000);
907                                                   
908            1                                 11      $res = $src_dbh->selectall_arrayref('select * from bidi.t order by id');
909            1                                695      is_deeply(
910                                                         $res,
911                                                         $bidi_data,
912                                                         'Bidirectional sync "master" (whole table chunk)'
913                                                      );
914                                                   
915            1                                  8      $res = $dbh2->selectall_arrayref('select * from bidi.t order by id');
916            1                                640      is_deeply(
917                                                         $res,
918                                                         $bidi_data,
919                                                         'Bidirectional sync remote-1 (whole table chunk)'
920                                                      );
921                                                   
922                                                      # ########################################################################
923                                                      # See TableSyncer.pm for why this is so.
924                                                      # ######################################################################## 
925            1                                 30      $args{ChangeHandler} = new_ch($dbh2, 1);
926                                                      throws_ok(
927            1                    1            40         sub { $syncer->sync_table(%args, bidirectional => 1, plugins => [$sync_chunk]) },
928            1                                497         qr/Queueing does not work with bidirectional syncing/,
929                                                         'Queueing does not work with bidirectional syncing'
930                                                      );
931                                                   
932            1                                 22      $sb->wipe_clean($dbh2);
933            1                              43149      diag(`$trunk/sandbox/stop-sandbox remove 12347 >/dev/null &`);
934                                                   }
935                                                   }
936                                                   
937                                                   
938                                                   # #############################################################################
939                                                   # Test with transactions.
940                                                   # #############################################################################
941            1                                 13   make_plugins();
942                                                   # Sandbox::get_dbh_for() defaults to AutoCommit=1.  Autocommit must
943                                                   # be off else commit() will cause an error.
944            1                                 21   $dbh      = $sb->get_dbh_for('master', {AutoCommit=>0});
945            1                                335   $src_dbh  = $sb->get_dbh_for('master', {AutoCommit=>0});
946            1                                301   $dst_dbh  = $sb->get_dbh_for('slave1', {AutoCommit=>0});
947                                                   
948            1                                393   sync_table(
949                                                      src         => "test.test1",
950                                                      dst         => "test.test1",
951                                                      transaction => 1,
952                                                      lock        => 1,
953                                                   );
954                                                   
955                                                   # There are no diffs.  This just tests that the code doesn't crash
956                                                   # when transaction is true.
957            1                                 32   is_deeply(
958                                                      \@rows,
959                                                      [],
960                                                      "Sync with transaction"
961                                                   );
962                                                   
963                                                   # #############################################################################
964                                                   # Issue 672: mk-table-sync should COALESCE to avoid undef
965                                                   # #############################################################################
966            1                                 21   make_plugins();
967            1                                 21   $sb->load_file('master', "common/t/samples/empty_tables.sql");
968                                                   
969            1                             103068   foreach my $sync( $sync_chunk, $sync_nibble, $sync_groupby ) {
970            3                                 94      sync_table(
971                                                         src     => 'et.et1',
972                                                         dst     => 'et.et1',
973                                                         plugins => [ $sync ],
974                                                      );
975            3                                 52      my $sync_name = ref $sync;
976            3                                 24      my $algo = $sync_name;
977            3                                 74      $algo =~ s/TableSync//;
978                                                   
979            3                                 88      is_deeply(
980                                                         \@rows,
981                                                         [],
982                                                         "Sync empty tables with " . ref $sync,
983                                                      );
984                                                   
985            3                                 89      is(
986                                                         $actions{ALGORITHM},
987                                                         $algo,
988                                                         "$algo algo used to sync empty table"
989                                                      );
990                                                   }
991                                                   
992                                                   # #############################################################################
993                                                   # Done.
994                                                   # #############################################################################
995            1                                 12   my $output = '';
996                                                   {
997            1                                  9      local *STDERR;
               1                                 26   
998            1                    1             4      open STDERR, '>', \$output;
               1                                577   
               1                                  5   
               1                                 15   
999            1                                 37      $syncer->_d('Complete test coverage');
1000                                                  }
1001                                                  like(
1002           1                                 35      $output,
1003                                                     qr/Complete test coverage/,
1004                                                     '_d() works'
1005                                                  );
1006           1                                 29   $sb->wipe_clean($src_dbh);
1007           1                             269183   $sb->wipe_clean($dst_dbh);
1008           1                                  7   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
46    ***     50      0      1   if (not $src_dbh or not $dbh) { }
      ***     50      0      1   elsif (not $dst_dbh) { }
147          100     21     31   if ($change_dbh) { }
      ***     50      0     31   elsif ($dbh) { }
160          100      4     18   defined $queue ? :
175          100     11      7   if ($args{'plugins'}) { }
625   ***     50      0      1   unless is $$r1[0][0], $$r2[0][0], 'Sync infinite loop table (issue 96)'
635   ***     50      0      1   unless $sandbox_version gt '4.0'
697   ***     50      1      0   $sandbox_version gt '4.0' ? :
719   ***     50      1      0   $sandbox_version gt '4.0' ? :
746   ***     50      0      1   unless $sandbox_version gt '4.0'
752   ***     50      0      1   unless $dbh
754   ***     50      0      1   unless $dbh2
770          100      9      3   if ($cmp == -1) { }
      ***     50      3      0   elsif ($cmp == 1) { }


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
38    ***     50      0      1   $ENV{'MKDEBUG'} || 0
197          100      2     16   $args{'chunk_size'} || 5
      ***     50      0     18   $args{'function'} || 'SHA1'
769   ***     50     12      0   $left_ts || ''
      ***     50     12      0   $right_ts || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
46    ***     33      0      0      1   not $src_dbh or not $dbh


Covered Subroutines
-------------------

Subroutine         Count Location         
------------------ ----- -----------------
BEGIN                  1 TableSyncer.t:10 
BEGIN                  1 TableSyncer.t:11 
BEGIN                  1 TableSyncer.t:12 
BEGIN                  1 TableSyncer.t:15 
BEGIN                  1 TableSyncer.t:16 
BEGIN                  1 TableSyncer.t:17 
BEGIN                  1 TableSyncer.t:18 
BEGIN                  1 TableSyncer.t:19 
BEGIN                  1 TableSyncer.t:21 
BEGIN                  1 TableSyncer.t:22 
BEGIN                  1 TableSyncer.t:23 
BEGIN                  1 TableSyncer.t:24 
BEGIN                  1 TableSyncer.t:26 
BEGIN                  1 TableSyncer.t:27 
BEGIN                  1 TableSyncer.t:29 
BEGIN                  1 TableSyncer.t:30 
BEGIN                  1 TableSyncer.t:32 
BEGIN                  1 TableSyncer.t:33 
BEGIN                  1 TableSyncer.t:34 
BEGIN                  1 TableSyncer.t:35 
BEGIN                  1 TableSyncer.t:36 
BEGIN                  1 TableSyncer.t:38 
BEGIN                  1 TableSyncer.t:4  
BEGIN                  1 TableSyncer.t:543
BEGIN                  1 TableSyncer.t:9  
BEGIN                  1 TableSyncer.t:998
__ANON__              52 TableSyncer.t:145
__ANON__               1 TableSyncer.t:545
__ANON__               1 TableSyncer.t:551
__ANON__               1 TableSyncer.t:67 
__ANON__               1 TableSyncer.t:694
__ANON__               1 TableSyncer.t:72 
__ANON__              12 TableSyncer.t:758
__ANON__               1 TableSyncer.t:77 
__ANON__               3 TableSyncer.t:785
__ANON__               6 TableSyncer.t:790
__ANON__               1 TableSyncer.t:82 
__ANON__               1 TableSyncer.t:927
make_plugins          18 TableSyncer.t:117
new_ch                22 TableSyncer.t:136
set_bidi_callbacks     3 TableSyncer.t:783
sync_table            18 TableSyncer.t:171


