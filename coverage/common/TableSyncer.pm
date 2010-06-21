---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableSyncer.pm   89.5   68.8   75.0  100.0    0.0    1.5   81.6
TableSyncer.t                  99.2   65.0   41.7  100.0    n/a   98.5   96.1
Total                          95.4   68.1   67.3  100.0    0.0  100.0   89.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Mon Jun 21 20:55:36 2010
Finish:       Mon Jun 21 20:55:36 2010

Run:          TableSyncer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Mon Jun 21 20:55:38 2010
Finish:       Mon Jun 21 20:55:56 2010

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
18                                                    # TableSyncer package $Revision: 6503 $
19                                                    # ###########################################################################
20                                                    package TableSyncer;
21                                                    
22             1                    1             6   use strict;
               1                                  2   
               1                                  7   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  6   
26             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  8   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
32                                                    
33                                                    # Arguments:
34                                                    #   * MasterSlave    A MasterSlave module
35                                                    #   * Quoter         A Quoter module
36                                                    #   * VersionParser  A VersionParser module
37                                                    #   * TableChecksum  A TableChecksum module
38                                                    sub new {
39    ***      5                    5      0     58      my ( $class, %args ) = @_;
40             5                                 46      my @required_args = qw(MasterSlave Quoter VersionParser TableChecksum);
41             5                                 31      foreach my $arg ( @required_args ) {
42            14    100                          91         die "I need a $arg argument" unless defined $args{$arg};
43                                                       }
44             1                                 10      my $self = { %args };
45             1                                 35      return bless $self, $class;
46                                                    }
47                                                    
48                                                    # Return the first plugin from the arrayref of TableSync* plugins
49                                                    # that can sync the given table struct.  plugin->can_sync() usually
50                                                    # returns a hashref that it wants back when plugin->prepare_to_sync()
51                                                    # is called.  Or, it may return nothing (false) to say that it can't
52                                                    # sync the table.
53                                                    sub get_best_plugin {
54    ***     21                   21      0    391      my ( $self, %args ) = @_;
55            21                                189      foreach my $arg ( qw(plugins tbl_struct) ) {
56    ***     42     50                         346         die "I need a $arg argument" unless $args{$arg};
57                                                       }
58            21                                 93      MKDEBUG && _d('Getting best plugin');
59            21                                 91      foreach my $plugin ( @{$args{plugins}} ) {
              21                                164   
60            26                                 89         MKDEBUG && _d('Trying plugin', $plugin->name);
61            26                                416         my ($can_sync, %plugin_args) = $plugin->can_sync(%args);
62            26    100                        7926         if ( $can_sync ) {
63            21                                 74           MKDEBUG && _d('Can sync with', $plugin->name, Dumper(\%plugin_args));
64            21                                376           return $plugin, %plugin_args;
65                                                          }
66                                                       }
67    ***      0                                  0      MKDEBUG && _d('No plugin can sync the table');
68    ***      0                                  0      return;
69                                                    }
70                                                    
71                                                    # Required arguments:
72                                                    #   * plugins         Arrayref of TableSync* modules, in order of preference
73                                                    #   * src             Hashref with source (aka left) dbh, db, tbl
74                                                    #   * dst             Hashref with destination (aka right) dbh, db, tbl
75                                                    #   * tbl_struct      Return val from TableParser::parser() for src and dst tbl
76                                                    #   * cols            Arrayref of column names to checksum/compare
77                                                    #   * chunk_size      Size/number of rows to select in each chunk
78                                                    #   * RowDiff         A RowDiff module
79                                                    #   * ChangeHandler   A ChangeHandler module
80                                                    # Optional arguments:
81                                                    #   * where           WHERE clause to restrict synced rows (default none)
82                                                    #   * bidirectional   If doing bidirectional sync (default no)
83                                                    #   * changing_src    If making changes on src (default no)
84                                                    #   * replicate       Checksum table if syncing via replication (default no)
85                                                    #   * function        Crypto hash func for checksumming chunks (default CRC32)
86                                                    #   * dry_run         Prepare to sync but don't actually sync (default no)
87                                                    #   * chunk_col       Column name to chunk table on (default auto-choose)
88                                                    #   * chunk_index     Index name to use for chunking table (default auto-choose)
89                                                    #   * index_hint      Use FORCE/USE INDEX (chunk_index) (default yes)
90                                                    #   * buffer_in_mysql  Use SQL_BUFFER_RESULT (default no)
91                                                    #   * buffer_to_client Use mysql_use_result (default no)
92                                                    #   * callback        Sub called before executing the sql (default none)
93                                                    #   * transaction     locking
94                                                    #   * change_dbh      locking
95                                                    #   * lock            locking
96                                                    #   * wait            locking
97                                                    #   * timeout_ok      locking
98                                                    sub sync_table {
99    ***     19                   19      0    370      my ( $self, %args ) = @_;
100           19                                256      my @required_args = qw(plugins src dst tbl_struct cols chunk_size
101                                                                             RowDiff ChangeHandler);
102           19                                145      foreach my $arg ( @required_args ) {
103   ***    152     50                        1099         die "I need a $arg argument" unless $args{$arg};
104                                                      }
105                                                      MKDEBUG && _d('Syncing table with args:',
106           19                                 72         map { "$_: " . Dumper($args{$_}) }
107                                                         qw(plugins src dst tbl_struct cols chunk_size));
108                                                   
109           19                                208      my ($plugins, $src, $dst, $tbl_struct, $cols, $chunk_size, $rd, $ch)
110                                                         = @args{@required_args};
111                                                   
112   ***     19    100     66                  182      if ( $args{bidirectional} && $args{ChangeHandler}->{queue} ) {
113                                                         # This should be checked by the caller but just in case...
114            1                                  3         die "Queueing does not work with bidirectional syncing";
115                                                      }
116                                                   
117   ***     18     50                         181      $args{index_hint}    = 1 unless defined $args{index_hint};
118           18           100                  167      $args{lock}        ||= 0;
119   ***     18            50                  162      $args{wait}        ||= 0;
120           18           100                  160      $args{transaction} ||= 0;
121   ***     18            50                  164      $args{timeout_ok}  ||= 0;
122                                                   
123           18                                106      my $q  = $self->{Quoter};
124           18                                103      my $vp = $self->{VersionParser};
125                                                   
126                                                      # ########################################################################
127                                                      # Get and prepare the first plugin that can sync this table.
128                                                      # ########################################################################
129           18                                284      my ($plugin, %plugin_args) = $self->get_best_plugin(%args);
130   ***     18     50                         168      die "No plugin can sync $src->{db}.$src->{tbl}" unless $plugin;
131                                                   
132                                                      # The row-level (state 2) checksums use __crc, so the table can't use that.
133           18                                 89      my $crc_col = '__crc';
134           18                                186      while ( $tbl_struct->{is_col}->{$crc_col} ) {
135   ***      0                                  0         $crc_col = "_$crc_col"; # Prepend more _ until not a column.
136                                                      }
137           18                                 67      MKDEBUG && _d('CRC column:', $crc_col);
138                                                   
139                                                      # Make an index hint for either the explicitly given chunk_index
140                                                      # or the chunk_index chosen by the plugin if index_hint is true.
141           18                                 72      my $index_hint;
142   ***     18     50     33                  290      my $hint = ($vp->version_ge($src->{dbh}, '4.0.9')
143                                                                  && $vp->version_ge($dst->{dbh}, '4.0.9') ? 'FORCE' : 'USE')
144                                                               . ' INDEX';
145   ***     18     50     66                  384      if ( $args{chunk_index} ) {
                    100                               
146   ***      0                                  0         MKDEBUG && _d('Using given chunk index for index hint');
147   ***      0                                  0         $index_hint = "$hint (" . $q->quote($args{chunk_index}) . ")";
148                                                      }
149                                                      elsif ( $plugin_args{chunk_index} && $args{index_hint} ) {
150           13                                 51         MKDEBUG && _d('Using chunk index chosen by plugin for index hint');
151           13                                139         $index_hint = "$hint (" . $q->quote($plugin_args{chunk_index}) . ")";
152                                                      }
153           18                                751      MKDEBUG && _d('Index hint:', $index_hint);
154                                                   
155           18                                 84      eval {
156           18                                411         $plugin->prepare_to_sync(
157                                                            %args,
158                                                            %plugin_args,
159                                                            dbh        => $src->{dbh},
160                                                            db         => $src->{db},
161                                                            tbl        => $src->{tbl},
162                                                            crc_col    => $crc_col,
163                                                            index_hint => $index_hint,
164                                                         );
165                                                      };
166   ***     18     50                       24239      if ( $EVAL_ERROR ) {
167                                                         # At present, no plugin should fail to prepare, but just in case...
168   ***      0                                  0         die 'Failed to prepare TableSync', $plugin->name, ' plugin: ',
169                                                            $EVAL_ERROR;
170                                                      }
171                                                   
172                                                      # Some plugins like TableSyncChunk use checksum queries, others like
173                                                      # TableSyncGroupBy do not.  For those that do, make chunk (state 0)
174                                                      # and row (state 2) checksum queries.
175           18    100                         183      if ( $plugin->uses_checksum() ) {
176           13                                173         eval {
177           13                                208            my ($chunk_sql, $row_sql) = $self->make_checksum_queries(%args);
178           13                                179            $plugin->set_checksum_queries($chunk_sql, $row_sql);
179                                                         };
180   ***     13     50                         598         if ( $EVAL_ERROR ) {
181                                                            # This happens if src and dst are really different and the same
182                                                            # checksum algo and hash func can't be used on both.
183   ***      0                                  0            die "Failed to make checksum queries: $EVAL_ERROR";
184                                                         }
185                                                      } 
186                                                   
187                                                      # ########################################################################
188                                                      # Plugin is ready, return now if this is a dry run.
189                                                      # ########################################################################
190           18    100                         199      if ( $args{dry_run} ) {
191            1                                 17         return $ch->get_changes(), ALGORITHM => $plugin->name;
192                                                      }
193                                                   
194                                                      # ########################################################################
195                                                      # Start syncing the table.
196                                                      # ########################################################################
197                                                   
198                                                      # USE db on src and dst for cases like when replicate-do-db is being used.
199           17                                 78      eval {
200           17                               2975         $src->{dbh}->do("USE `$src->{db}`");
201           17                               2712         $dst->{dbh}->do("USE `$dst->{db}`");
202                                                      };
203   ***     17     50                         146      if ( $EVAL_ERROR ) {
204                                                         # This shouldn't happen, but just in case.  (The db and tbl on src
205                                                         # and dst should be checked before calling this sub.)
206   ***      0                                  0         die "Failed to USE database on source or destination: $EVAL_ERROR";
207                                                      }
208                                                   
209                                                      # For bidirectional syncing it's important to know on which dbh
210                                                      # changes are made or rows are fetched.  This identifies the dbhs,
211                                                      # then you can search for each one by its address like
212                                                      # "dbh DBI::db=HASH(0x1028b38)".
213           17                                 60      MKDEBUG && _d('left dbh', $src->{dbh});
214           17                                 93      MKDEBUG && _d('right dbh', $dst->{dbh});
215                                                   
216           17                                315      $self->lock_and_wait(%args, lock_level => 2);  # per-table lock
217                                                      
218           17                                120      my $callback = $args{callback};
219           17                                 80      my $cycle    = 0;
220           17                                304      while ( !$plugin->done() ) {
221                                                   
222                                                         # Do as much of the work as possible before opening a transaction or
223                                                         # locking the tables.
224           50                               2000         MKDEBUG && _d('Beginning sync cycle', $cycle);
225           50                                849         my $src_sql = $plugin->get_sql(
226                                                            database => $src->{db},
227                                                            table    => $src->{tbl},
228                                                            where    => $args{where},
229                                                         );
230           50                              22093         my $dst_sql = $plugin->get_sql(
231                                                            database => $dst->{db},
232                                                            table    => $dst->{tbl},
233                                                            where    => $args{where},
234                                                         );
235                                                   
236           50    100                       16345         if ( $args{transaction} ) {
237   ***      1     50                          13            if ( $args{bidirectional} ) {
      ***            50                               
238                                                               # Making changes on src and dst.
239   ***      0                                  0               $src_sql .= ' FOR UPDATE';
240   ***      0                                  0               $dst_sql .= ' FOR UPDATE';
241                                                            }
242                                                            elsif ( $args{changing_src} ) {
243                                                               # Making changes on master (src) which replicate to slave (dst).
244   ***      0                                  0               $src_sql .= ' FOR UPDATE';
245   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
246                                                            }
247                                                            else {
248                                                               # Making changes on slave (dst).
249            1                                  7               $src_sql .= ' LOCK IN SHARE MODE';
250            1                                  7               $dst_sql .= ' FOR UPDATE';
251                                                            }
252                                                         }
253           50                                172         MKDEBUG && _d('src:', $src_sql);
254           50                                188         MKDEBUG && _d('dst:', $dst_sql);
255                                                   
256                                                         # Give callback a chance to do something with the SQL statements.
257           50    100                         317         $callback->($src_sql, $dst_sql) if $callback;
258                                                   
259                                                         # Prepare each host for next sync cycle. This does stuff
260                                                         # like reset/init MySQL accumulator vars, etc.
261           50                                446         $plugin->prepare_sync_cycle($src);
262           50                               9969         $plugin->prepare_sync_cycle($dst);
263                                                   
264                                                         # Prepare SQL statements on host.  These aren't real prepared
265                                                         # statements (i.e. no ? placeholders); we just need sths to
266                                                         # pass to compare_sets().  Also, we can control buffering
267                                                         # (mysql_use_result) on the sths.
268           50                                181         my $src_sth = $src->{dbh}->prepare($src_sql);
269           50                                159         my $dst_sth = $dst->{dbh}->prepare($dst_sql);
270   ***     50     50                         637         if ( $args{buffer_to_client} ) {
271   ***      0                                  0            $src_sth->{mysql_use_result} = 1;
272   ***      0                                  0            $dst_sth->{mysql_use_result} = 1;
273                                                         }
274                                                   
275                                                         # The first cycle should lock to begin work; after that, unlock only if
276                                                         # the plugin says it's OK (it may want to dig deeper on the rows it
277                                                         # currently has locked).
278           50                                224         my $executed_src = 0;
279           50    100    100                  736         if ( !$cycle || !$plugin->pending_changes() ) {
280                                                            # per-sync cycle lock
281           34                               1034            $executed_src
282                                                               = $self->lock_and_wait(%args, src_sth => $src_sth, lock_level => 1);
283                                                         }
284                                                   
285                                                         # The source sth might have already been executed by lock_and_wait().
286           50    100                       30566         $src_sth->execute() unless $executed_src;
287           50                              27655         $dst_sth->execute();
288                                                   
289                                                         # Compare rows in the two sths.  If any differences are found
290                                                         # (same_row, not_in_left, not_in_right), the appropriate $syncer
291                                                         # methods are called to handle them.  Changes may be immediate, or...
292           50                               1083         $rd->compare_sets(
293                                                            left_sth   => $src_sth,
294                                                            right_sth  => $dst_sth,
295                                                            left_dbh   => $src->{dbh},
296                                                            right_dbh  => $dst->{dbh},
297                                                            syncer     => $plugin,
298                                                            tbl_struct => $tbl_struct,
299                                                         );
300                                                         # ...changes may be queued and executed now.
301           50                               2851         $ch->process_rows(1);
302                                                   
303           50                               7773         MKDEBUG && _d('Finished sync cycle', $cycle);
304           50                               3050         $cycle++;
305                                                      }
306                                                   
307           17                                834      $ch->process_rows();
308                                                   
309           17                               2884      $self->unlock(%args, lock_level => 2);
310                                                   
311           17                                244      return $ch->get_changes(), ALGORITHM => $plugin->name;
312                                                   }
313                                                   
314                                                   sub make_checksum_queries {
315   ***     14                   14      0    265      my ( $self, %args ) = @_;
316           14                                181      my @required_args = qw(src dst tbl_struct);
317           14                                113      foreach my $arg ( @required_args ) {
318   ***     42     50                         334         die "I need a $arg argument" unless $args{$arg};
319                                                      }
320           14                                110      my ($src, $dst, $tbl_struct) = @args{@required_args};
321           14                                 82      my $checksum = $self->{TableChecksum};
322                                                   
323                                                      # Decide on checksumming strategy and store checksum query prototypes for
324                                                      # later.
325           14                                232      my $src_algo = $checksum->best_algorithm(
326                                                         algorithm => 'BIT_XOR',
327                                                         dbh       => $src->{dbh},
328                                                         where     => 1,
329                                                         chunk     => 1,
330                                                         count     => 1,
331                                                      );
332           14                                628      my $dst_algo = $checksum->best_algorithm(
333                                                         algorithm => 'BIT_XOR',
334                                                         dbh       => $dst->{dbh},
335                                                         where     => 1,
336                                                         chunk     => 1,
337                                                         count     => 1,
338                                                      );
339   ***     14     50                         533      if ( $src_algo ne $dst_algo ) {
340   ***      0                                  0         die "Source and destination checksum algorithms are different: ",
341                                                            "$src_algo on source, $dst_algo on destination"
342                                                      }
343           14                                 46      MKDEBUG && _d('Chosen algo:', $src_algo);
344                                                   
345           14                                210      my $src_func = $checksum->choose_hash_func(dbh => $src->{dbh}, %args);
346           14                               5229      my $dst_func = $checksum->choose_hash_func(dbh => $dst->{dbh}, %args);
347   ***     14     50                        4552      if ( $src_func ne $dst_func ) {
348   ***      0                                  0         die "Source and destination hash functions are different: ",
349                                                         "$src_func on source, $dst_func on destination";
350                                                      }
351           14                                 48      MKDEBUG && _d('Chosen hash func:', $src_func);
352                                                   
353                                                      # Since the checksum algo and hash func are the same on src and dst
354                                                      # it doesn't matter if we use src_algo/func or dst_algo/func.
355                                                   
356           14                                181      my $crc_wid    = $checksum->get_crc_wid($src->{dbh}, $src_func);
357           14                               3411      my ($crc_type) = $checksum->get_crc_type($src->{dbh}, $src_func);
358           14                                 72      my $opt_slice;
359   ***     14     50     33                  341      if ( $src_algo eq 'BIT_XOR' && $crc_type !~ m/int$/ ) {
360           14                                191         $opt_slice = $checksum->optimize_xor(
361                                                            dbh      => $src->{dbh},
362                                                            function => $src_func
363                                                         );
364                                                      }
365                                                   
366           14                               6647      my $chunk_sql = $checksum->make_checksum_query(
367                                                         %args,
368                                                         db        => $src->{db},
369                                                         tbl       => $src->{tbl},
370                                                         algorithm => $src_algo,
371                                                         function  => $src_func,
372                                                         crc_wid   => $crc_wid,
373                                                         crc_type  => $crc_type,
374                                                         opt_slice => $opt_slice,
375                                                         replicate => undef, # replicate means something different to this sub
376                                                      );                     # than what we use it for; do not pass it!
377           14                              14271      MKDEBUG && _d('Chunk sql:', $chunk_sql);
378           14                                164      my $row_sql = $checksum->make_row_checksum(
379                                                         %args,
380                                                         function => $src_func,
381                                                      );
382           14                               7333      MKDEBUG && _d('Row sql:', $row_sql);
383           14                                206      return $chunk_sql, $row_sql;
384                                                   }
385                                                   
386                                                   sub lock_table {
387   ***      4                    4      0    322      my ( $self, $dbh, $where, $db_tbl, $mode ) = @_;
388            4                                 32      my $query = "LOCK TABLES $db_tbl $mode";
389            4                                 12      MKDEBUG && _d($query);
390            4                                592      $dbh->do($query);
391            4                                 35      MKDEBUG && _d('Acquired table lock on', $where, 'in', $mode, 'mode');
392                                                   }
393                                                   
394                                                   # Doesn't work quite the same way as lock_and_wait. It will unlock any LOWER
395                                                   # priority lock level, not just the exact same one.
396                                                   sub unlock {
397   ***     17                   17      0    394      my ( $self, %args ) = @_;
398                                                   
399           17                                243      foreach my $arg ( qw(src dst lock transaction lock_level) ) {
400   ***     85     50                         700         die "I need a $arg argument" unless defined $args{$arg};
401                                                      }
402           17                                101      my $src = $args{src};
403           17                                 88      my $dst = $args{dst};
404                                                   
405           17    100    100                  286      return unless $args{lock} && $args{lock} <= $args{lock_level};
406                                                   
407                                                      # First, unlock/commit.
408            3                                 27      foreach my $dbh ( $src->{dbh}, $dst->{dbh} ) {
409            6    100                          47         if ( $args{transaction} ) {
410            2                                  8            MKDEBUG && _d('Committing', $dbh);
411            2                                743            $dbh->commit();
412                                                         }
413                                                         else {
414            4                                 20            my $sql = 'UNLOCK TABLES';
415            4                                 12            MKDEBUG && _d($dbh, $sql);
416            4                                590            $dbh->do($sql);
417                                                         }
418                                                      }
419                                                   
420            3                                 37      return;
421                                                   }
422                                                   
423                                                   # Arguments:
424                                                   #    lock         scalar: lock level requested by user
425                                                   #    local_level  scalar: lock level code is calling from
426                                                   #    src          dbh
427                                                   #    dst          dbh
428                                                   # Lock levels:
429                                                   #   0 => none
430                                                   #   1 => per sync cycle
431                                                   #   2 => per table
432                                                   #   3 => global
433                                                   # This function might actually execute the $src_sth.  If we're using
434                                                   # transactions instead of table locks, the $src_sth has to be executed before
435                                                   # the MASTER_POS_WAIT() on the slave.  The return value is whether the
436                                                   # $src_sth was executed.
437                                                   sub lock_and_wait {
438   ***     52                   52      0   1172      my ( $self, %args ) = @_;
439           52                                430      my $result = 0;
440                                                   
441           52                                365      foreach my $arg ( qw(src dst lock lock_level) ) {
442   ***    208     50                        1631         die "I need a $arg argument" unless defined $args{$arg};
443                                                      }
444           52                                282      my $src = $args{src};
445           52                                275      my $dst = $args{dst};
446                                                   
447           52    100    100                  876      return unless $args{lock} && $args{lock} == $args{lock_level};
448            4                                 15      MKDEBUG && _d('lock and wait, lock level', $args{lock});
449                                                   
450                                                      # First, commit/unlock the previous transaction/lock.
451            4                                 34      foreach my $dbh ( $src->{dbh}, $dst->{dbh} ) {
452            8    100                          60         if ( $args{transaction} ) {
453            2                                  8            MKDEBUG && _d('Committing', $dbh);
454            2                                266            $dbh->commit();
455                                                         }
456                                                         else {
457            6                                 32            my $sql = 'UNLOCK TABLES';
458            6                                 21            MKDEBUG && _d($dbh, $sql);
459            6                               1680            $dbh->do($sql);
460                                                         }
461                                                      }
462                                                   
463                                                      # User wants us to lock for consistency.  But lock only on source initially;
464                                                      # might have to wait for the slave to catch up before locking on the dest.
465            4    100                          43      if ( $args{lock} == 3 ) {
466            1                                  6         my $sql = 'FLUSH TABLES WITH READ LOCK';
467            1                                  4         MKDEBUG && _d($src->{dbh}, $sql);
468            1                                510         $src->{dbh}->do($sql);
469                                                      }
470                                                      else {
471                                                         # Lock level 2 (per-table) or 1 (per-sync cycle)
472            3    100                          23         if ( $args{transaction} ) {
473   ***      1     50                          11            if ( $args{src_sth} ) {
474                                                               # Execute the $src_sth on the source, so LOCK IN SHARE MODE/FOR
475                                                               # UPDATE will lock the rows examined.
476            1                                  5               MKDEBUG && _d('Executing statement on source to lock rows');
477                                                   
478            1                                 10               my $sql = "START TRANSACTION WITH CONSISTENT SNAPSHOT";
479            1                                  4               MKDEBUG && _d($src->{dbh}, $sql);
480            1                                130               $src->{dbh}->do($sql);
481                                                   
482            1                                550               $args{src_sth}->execute();
483            1                                 10               $result = 1;
484                                                            }
485                                                         }
486                                                         else {
487   ***      2     50                          31            $self->lock_table($src->{dbh}, 'source',
488                                                               $self->{Quoter}->quote($src->{db}, $src->{tbl}),
489                                                               $args{changing_src} ? 'WRITE' : 'READ');
490                                                         }
491                                                      }
492                                                   
493                                                      # If there is any error beyond this point, we need to unlock/commit.
494            4                                 24      eval {
495            4    100                          39         if ( $args{wait} ) {
496                                                            # Always use the misc_dbh dbh to check the master's position, because
497                                                            # the main dbh might be in use due to executing $src_sth.
498            1                                 30            $self->{MasterSlave}->wait_for_master(
499                                                               $src->{misc_dbh}, $dst->{dbh}, $args{wait}, $args{timeout_ok});
500                                                         }
501                                                   
502                                                         # Don't lock the destination if we're making changes on the source
503                                                         # (for sync-to-master and sync via replicate) else the destination
504                                                         # won't be apply to make the changes.
505   ***      4     50                         298         if ( $args{changing_src} ) {
506   ***      0                                  0            MKDEBUG && _d('Not locking destination because changing source ',
507                                                               '(syncing via replication or sync-to-master)');
508                                                         }
509                                                         else {
510            4    100                          54            if ( $args{lock} == 3 ) {
                    100                               
511            1                                  5               my $sql = 'FLUSH TABLES WITH READ LOCK';
512            1                                  4               MKDEBUG && _d($dst->{dbh}, ',', $sql);
513            1                                427               $dst->{dbh}->do($sql);
514                                                            }
515                                                            elsif ( !$args{transaction} ) {
516   ***      2     50                          29               $self->lock_table($dst->{dbh}, 'dest',
517                                                                  $self->{Quoter}->quote($dst->{db}, $dst->{tbl}),
518                                                                  $args{execute} ? 'WRITE' : 'READ');
519                                                            }
520                                                         }
521                                                      };
522                                                   
523   ***      4     50                          33      if ( $EVAL_ERROR ) {
524                                                         # Must abort/unlock/commit so that we don't interfere with any further
525                                                         # tables we try to do.
526   ***      0      0                           0         if ( $args{src_sth}->{Active} ) {
527   ***      0                                  0            $args{src_sth}->finish();
528                                                         }
529   ***      0                                  0         foreach my $dbh ( $src->{dbh}, $dst->{dbh}, $src->{misc_dbh} ) {
530   ***      0      0                           0            next unless $dbh;
531   ***      0                                  0            MKDEBUG && _d('Caught error, unlocking/committing on', $dbh);
532   ***      0                                  0            $dbh->do('UNLOCK TABLES');
533   ***      0      0                           0            $dbh->commit() unless $dbh->{AutoCommit};
534                                                         }
535                                                         # ... and then re-throw the error.
536   ***      0                                  0         die $EVAL_ERROR;
537                                                      }
538                                                   
539            4                                 57      return $result;
540                                                   }
541                                                   
542                                                   # This query will check all needed privileges on the table without actually
543                                                   # changing anything in it.  We can't use REPLACE..SELECT because that doesn't
544                                                   # work inside of LOCK TABLES.  Returns 1 if user has all needed privs to
545                                                   # sync table, else returns 0.
546                                                   sub have_all_privs {
547   ***      5                    5      0     90      my ( $self, $dbh, $db, $tbl ) = @_;
548            5                                139      my $db_tbl = $self->{Quoter}->quote($db, $tbl);
549            5                                505      my $sql    = "SHOW FULL COLUMNS FROM $db_tbl";
550            5                                 25      MKDEBUG && _d('Permissions check:', $sql);
551            5                                107      my $cols       = $dbh->selectall_arrayref($sql, {Slice => {}});
552            5                                 75      my ($hdr_name) = grep { m/privileges/i } keys %{$cols->[0]};
              45                                281   
               5                                 72   
553            5                                 69      my $privs      = $cols->[0]->{$hdr_name};
554            5                                 48      $sql = "DELETE FROM $db_tbl LIMIT 0"; # FULL COLUMNS doesn't show all privs
555            5                                 19      MKDEBUG && _d('Permissions check:', $sql);
556            5                                 43      eval { $dbh->do($sql); };
               5                                436   
557            5    100                          49      my $can_delete = $EVAL_ERROR ? 0 : 1;
558                                                   
559            5                                 27      MKDEBUG && _d('User privs on', $db_tbl, ':', $privs,
560                                                         ($can_delete ? 'delete' : ''));
561   ***      5    100     66                  257      if ( $privs =~ m/select/ && $privs =~ m/insert/ && $privs =~ m/update/ 
                           100                        
                           100                        
562                                                           && $can_delete ) {
563            2                                  7         MKDEBUG && _d('User has all privs');
564            2                                 55         return 1;
565                                                      }
566            3                                 13      MKDEBUG && _d('User does not have all privs');
567            3                                 95      return 0;
568                                                   }
569                                                   
570                                                   sub _d {
571            1                    1            14      my ($package, undef, $line) = caller 0;
572   ***      2     50                          22      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 13   
               2                                 18   
573            1                                  9           map { defined $_ ? $_ : 'undef' }
574                                                           @_;
575            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
576                                                   }
577                                                   
578                                                   1;
579                                                   
580                                                   # ###########################################################################
581                                                   # End TableSyncer package
582                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
42           100      4     10   unless defined $args{$arg}
56    ***     50      0     42   unless $args{$arg}
62           100     21      5   if ($can_sync)
103   ***     50      0    152   unless $args{$arg}
112          100      1     18   if ($args{'bidirectional'} and $args{'ChangeHandler'}{'queue'})
117   ***     50     18      0   unless defined $args{'index_hint'}
130   ***     50      0     18   unless $plugin
142   ***     50     18      0   $vp->version_ge($$src{'dbh'}, '4.0.9') && $vp->version_ge($$dst{'dbh'}, '4.0.9') ? :
145   ***     50      0     18   if ($args{'chunk_index'}) { }
             100     13      5   elsif ($plugin_args{'chunk_index'} and $args{'index_hint'}) { }
166   ***     50      0     18   if ($EVAL_ERROR)
175          100     13      5   if ($plugin->uses_checksum)
180   ***     50      0     13   if ($EVAL_ERROR)
190          100      1     17   if ($args{'dry_run'})
203   ***     50      0     17   if ($EVAL_ERROR)
236          100      1     49   if ($args{'transaction'})
237   ***     50      0      1   if ($args{'bidirectional'}) { }
      ***     50      0      1   elsif ($args{'changing_src'}) { }
257          100      1     49   if $callback
270   ***     50      0     50   if ($args{'buffer_to_client'})
279          100     34     16   if (not $cycle or not $plugin->pending_changes)
286          100     49      1   unless $executed_src
318   ***     50      0     42   unless $args{$arg}
339   ***     50      0     14   if ($src_algo ne $dst_algo)
347   ***     50      0     14   if ($src_func ne $dst_func)
359   ***     50     14      0   if ($src_algo eq 'BIT_XOR' and not $crc_type =~ /int$/)
400   ***     50      0     85   unless defined $args{$arg}
405          100     14      3   unless $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
409          100      2      4   if ($args{'transaction'}) { }
442   ***     50      0    208   unless defined $args{$arg}
447          100     48      4   unless $args{'lock'} and $args{'lock'} == $args{'lock_level'}
452          100      2      6   if ($args{'transaction'}) { }
465          100      1      3   if ($args{'lock'} == 3) { }
472          100      1      2   if ($args{'transaction'}) { }
473   ***     50      1      0   if ($args{'src_sth'})
487   ***     50      0      2   $args{'changing_src'} ? :
495          100      1      3   if ($args{'wait'})
505   ***     50      0      4   if ($args{'changing_src'}) { }
510          100      1      3   if ($args{'lock'} == 3) { }
             100      2      1   elsif (not $args{'transaction'}) { }
516   ***     50      0      2   $args{'execute'} ? :
523   ***     50      0      4   if ($EVAL_ERROR)
526   ***      0      0      0   if ($args{'src_sth'}{'Active'})
530   ***      0      0      0   unless $dbh
533   ***      0      0      0   unless $$dbh{'AutoCommit'}
557          100      3      2   $EVAL_ERROR ? :
561          100      2      3   if ($privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/ and $can_delete)
572   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
112   ***     66     18      0      1   $args{'bidirectional'} and $args{'ChangeHandler'}{'queue'}
142   ***     33      0      0     18   $vp->version_ge($$src{'dbh'}, '4.0.9') && $vp->version_ge($$dst{'dbh'}, '4.0.9')
145   ***     66      5      0     13   $plugin_args{'chunk_index'} and $args{'index_hint'}
359   ***     33      0      0     14   $src_algo eq 'BIT_XOR' and not $crc_type =~ /int$/
405          100     13      1      3   $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
447          100     43      5      4   $args{'lock'} and $args{'lock'} == $args{'lock_level'}
561   ***     66      0      1      4   $privs =~ /select/ and $privs =~ /insert/
             100      1      1      3   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
             100      2      1      2   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/ and $can_delete

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
118          100      4     14   $args{'lock'} ||= 0
119   ***     50      0     18   $args{'wait'} ||= 0
120          100      1     17   $args{'transaction'} ||= 0
121   ***     50      0     18   $args{'timeout_ok'} ||= 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
279          100     17     17     16   not $cycle or not $plugin->pending_changes


Covered Subroutines
-------------------

Subroutine            Count Pod Location                                          
--------------------- ----- --- --------------------------------------------------
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:22 
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:23 
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:25 
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:26 
BEGIN                     1     /home/daniel/dev/maatkit/common/TableSyncer.pm:31 
_d                        1     /home/daniel/dev/maatkit/common/TableSyncer.pm:571
get_best_plugin          21   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:54 
have_all_privs            5   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:547
lock_and_wait            52   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:438
lock_table                4   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:387
make_checksum_queries    14   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:315
new                       5   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:39 
sync_table               19   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:99 
unlock                   17   0 /home/daniel/dev/maatkit/common/TableSyncer.pm:397


TableSyncer.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More;
               1                                  3   
               1                                  9   
13                                                    
14                                                    # TableSyncer and its required modules:
15             1                    1            11   use TableSyncer;
               1                                  3   
               1                                 11   
16             1                    1            11   use MasterSlave;
               1                                  3   
               1                                 13   
17             1                    1            20   use Quoter;
               1                                  3   
               1                                 10   
18             1                    1            14   use TableChecksum;
               1                                  2   
               1                                 11   
19             1                    1            10   use VersionParser;
               1                                  3   
               1                                 10   
20                                                    # The sync plugins:
21             1                    1             9   use TableSyncChunk;
               1                                  3   
               1                                 10   
22             1                    1            10   use TableSyncNibble;
               1                                  3   
               1                                 11   
23             1                    1            11   use TableSyncGroupBy;
               1                                  3   
               1                                 10   
24             1                    1             9   use TableSyncStream;
               1                                  3   
               1                                 10   
25                                                    # Helper modules for the sync plugins:
26             1                    1            18   use TableChunker;
               1                                  4   
               1                                 19   
27             1                    1            19   use TableNibbler;
               1                                  6   
               1                                 21   
28                                                    # Modules for sync():
29             1                    1            19   use ChangeHandler;
               1                                  8   
               1                                 17   
30             1                    1            18   use RowDiff;
               1                                  4   
               1                                 19   
31                                                    # And other modules:
32             1                    1            18   use MySQLDump;
               1                                  3   
               1                                 23   
33             1                    1            18   use TableParser;
               1                                  5   
               1                                 19   
34             1                    1            22   use DSNParser;
               1                                  3   
               1                                 25   
35             1                    1            47   use Sandbox;
               1                                  3   
               1                                 10   
36             1                    1            10   use MaatkitTest;
               1                                  5   
               1                                 35   
37                                                    
38    ***      1            50      1             9   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 24   
39                                                    
40             1                                 11   my $dp = new DSNParser(opts=>$dsn_opts);
41             1                                230   my $sb = new Sandbox(basedir => '/tmp', DSNParser => $dp);
42             1                                 56   my $dbh      = $sb->get_dbh_for('master');
43             1                                413   my $src_dbh  = $sb->get_dbh_for('master');
44             1                                255   my $dst_dbh  = $sb->get_dbh_for('slave1');
45                                                    
46    ***      1     50     33                  253   if ( !$src_dbh || !$dbh ) {
      ***            50                               
47    ***      0                                  0      plan skip_all => 'Cannot connect to sandbox master';
48                                                    }
49                                                    elsif ( !$dst_dbh ) {
50    ***      0                                  0      plan skip_all => 'Cannot connect to sandbox slave';
51                                                    }
52                                                    else {
53             1                                 10      plan tests => 52;
54                                                    }
55                                                    
56             1                                272   $sb->create_dbs($dbh, ['test']);
57             1                                732   my $mysql = $sb->_use_for('master');
58             1                                 25   $sb->load_file('master', 'common/t/samples/before-TableSyncChunk.sql');
59                                                    
60             1                             1029690   my $q  = new Quoter();
61             1                                123   my $tp = new TableParser(Quoter=>$q);
62             1                                133   my $du = new MySQLDump( cache => 0 );
63             1                                 59   my ($rows, $cnt);
64                                                    
65                                                    # ###########################################################################
66                                                    # Make a TableSyncer object.
67                                                    # ###########################################################################
68                                                    throws_ok(
69             1                    1            48      sub { new TableSyncer() },
70             1                                 74      qr/I need a MasterSlave/,
71                                                       'MasterSlave required'
72                                                    );
73                                                    throws_ok(
74             1                    1            26      sub { new TableSyncer(MasterSlave=>1) },
75             1                               2172      qr/I need a Quoter/,
76                                                       'Quoter required'
77                                                    );
78                                                    throws_ok(
79             1                    1            28      sub { new TableSyncer(MasterSlave=>1, Quoter=>1) },
80             1                               1584      qr/I need a VersionParser/,
81                                                       'VersionParser required'
82                                                    );
83                                                    throws_ok(
84             1                    1            27      sub { new TableSyncer(MasterSlave=>1, Quoter=>1, VersionParser=>1) },
85             1                               1591      qr/I need a TableChecksum/,
86                                                       'TableChecksum required'
87                                                    );
88                                                    
89             1                               1568   my $rd       = new RowDiff(dbh=>$src_dbh);
90             1                                 96   my $ms       = new MasterSlave();
91             1                                 74   my $vp       = new VersionParser();
92             1                                 54   my $checksum = new TableChecksum(
93                                                       Quoter         => $q,
94                                                       VersionParser => $vp,
95                                                    );
96             1                                 83   my $syncer = new TableSyncer(
97                                                       MasterSlave   => $ms,
98                                                       Quoter        => $q,
99                                                       TableChecksum => $checksum,
100                                                      VersionParser => $vp,
101                                                   );
102            1                                 14   isa_ok($syncer, 'TableSyncer');
103                                                   
104                                                   # ###########################################################################
105                                                   # Make TableSync* objects.
106                                                   # ###########################################################################
107            1                               1440   my $chunker = new TableChunker( Quoter => $q, MySQLDump => $du );
108            1                                133   my $nibbler = new TableNibbler( TableParser => $tp, Quoter => $q );
109                                                   
110            1                                101   my ($sync_chunk, $sync_nibble, $sync_groupby, $sync_stream);
111            1                                  5   my $plugins = [];
112                                                   
113                                                   # Call this func to re-make/reset the plugins.
114                                                   
115                                                   sub make_plugins {
116            7                    7           209      $sync_chunk = new TableSyncChunk(
117                                                         TableChunker => $chunker,
118                                                         Quoter       => $q,
119                                                      );
120            7                                928      $sync_nibble = new TableSyncNibble(
121                                                         TableNibbler  => $nibbler,
122                                                         TableChunker  => $chunker,
123                                                         TableParser   => $tp,
124                                                         Quoter        => $q,
125                                                      );
126            7                                845      $sync_groupby = new TableSyncGroupBy( Quoter => $q );
127            7                                558      $sync_stream  = new TableSyncStream( Quoter => $q );
128                                                   
129            7                                440      $plugins = [$sync_chunk, $sync_nibble, $sync_groupby, $sync_stream];
130                                                   
131            7                               1061      return;
132                                                   }
133                                                   
134            1                                 14   make_plugins();
135                                                   
136                                                   # ###########################################################################
137                                                   # Test get_best_plugin() (formerly best_algorithm()).
138                                                   # ###########################################################################
139            1                                 21   my $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test5'));
140            1                                926   is_deeply(
141                                                      [
142                                                         $syncer->get_best_plugin(
143                                                            plugins     => $plugins,
144                                                            tbl_struct  => $tbl_struct,
145                                                         )
146                                                      ],
147                                                      [ $sync_groupby ],
148                                                      'Best plugin GroupBy'
149                                                   );
150                                                   
151            1                                 25   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test3'));
152            1                               1346   my ($plugin, %plugin_args) = $syncer->get_best_plugin(
153                                                      plugins     => $plugins,
154                                                      tbl_struct  => $tbl_struct,
155                                                   );
156            1                                 21   is_deeply(
157                                                      [ $plugin, \%plugin_args, ],
158                                                      [ $sync_chunk, { chunk_index => 'PRIMARY', chunk_col => 'a', } ],
159                                                      'Best plugin Chunk'
160                                                   );
161                                                   
162            1                                 23   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test6'));
163            1                               1042   ($plugin, %plugin_args) = $syncer->get_best_plugin(
164                                                      plugins     => $plugins,
165                                                      tbl_struct  => $tbl_struct,
166                                                   );
167            1                                 20   is_deeply(
168                                                      [ $plugin, \%plugin_args, ],
169                                                      [ $sync_nibble,{ chunk_index => 'a', key_cols => [qw(a)], small_table=>0 } ],
170                                                      'Best plugin Nibble'
171                                                   );
172                                                   
173                                                   # ###########################################################################
174                                                   # Test sync_table() for each plugin with a basic, 4 row data set.
175                                                   # ###########################################################################
176                                                   
177                                                   # REMEMBER: call new_ch() before each sync to reset the number of actions.
178                                                   
179                                                   # Redo this in case any tests above change $tbl_struct.
180            1                                 31   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test1'));
181                                                   
182                                                   # test1 has 4 rows and test2, which is the same struct, is empty.
183                                                   # So after sync, test2 should have the same 4 rows as test1.
184            1                               1381   my $test1_rows = [
185                                                    [qw(1 en)],
186                                                    [qw(2 ca)],
187                                                    [qw(3 ab)],
188                                                    [qw(4 bz)],
189                                                   ];
190            1                                  9   my $inserts = [
191                                                      "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('1', 'en')",
192                                                      "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('2', 'ca')",
193                                                      "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('3', 'ab')",
194                                                      "INSERT INTO `test`.`test2`(`a`, `b`) VALUES ('4', 'bz')",
195                                                   ];
196            1                                 11   my $src = {
197                                                      dbh      => $src_dbh,
198                                                      misc_dbh => $dbh,
199                                                      db       => 'test',
200                                                      tbl      => 'test1',
201                                                   };
202            1                                  8   my $dst = {
203                                                      dbh => $dst_dbh,
204                                                      db  => 'test',
205                                                      tbl => 'test2',
206                                                   };
207            1                                 36   my %args = (
208                                                      plugins        => $plugins,
209                                                      src            => $src,
210                                                      dst            => $dst,
211                                                      tbl_struct     => $tbl_struct,
212                                                      cols           => $tbl_struct->{cols},
213                                                      chunk_size     => 2,
214                                                      RowDiff        => $rd,
215                                                      ChangeHandler  => undef,  # call new_ch()
216                                                      function       => 'SHA1',
217                                                   );
218                                                   
219            1                                  7   my @rows;
220                                                   sub new_ch {
221           15                   15           143      my ( $dbh, $queue ) = @_;
222                                                      return new ChangeHandler(
223                                                         Quoter    => $q,
224                                                         left_db   => $src->{db},
225                                                         left_tbl  => $src->{tbl},
226                                                         right_db  => $dst->{db},
227                                                         right_tbl => $dst->{tbl},
228                                                         actions => [
229                                                            sub {
230           52                   52         26487               my ( $sql, $change_dbh ) = @_;
231           52                                408               push @rows, $sql;
232           52    100                         405               if ( $change_dbh ) {
      ***            50                               
233                                                                  # dbh passed through change() or process_rows()
234           21                             3405244                  $change_dbh->do($sql);
235                                                               }
236                                                               elsif ( $dbh ) {
237                                                                  # dbh passed to this sub
238   ***      0                                  0                  $dbh->do($sql);
239                                                               }
240                                                               else {
241                                                                  # default dst dbh for this test script
242           31                             2566762                  $dst_dbh->do($sql);
243                                                               }
244                                                            }
245           15    100                         793         ],
246                                                         replace => 0,
247                                                         queue   => defined $queue ? $queue : 1,
248                                                      );
249                                                   }
250                                                   
251                                                   # First, do a dry run sync, so nothing should happen.
252            1                             129052   $dst_dbh->do('TRUNCATE TABLE test.test2');
253            1                                 14   @rows = ();
254            1                                 10   $args{ChangeHandler} = new_ch();
255                                                   
256            1                                489   is_deeply(
257                                                      { $syncer->sync_table(%args, dry_run => 1) },
258                                                      {
259                                                         DELETE    => 0,
260                                                         INSERT    => 0,
261                                                         REPLACE   => 0,
262                                                         UPDATE    => 0,
263                                                         ALGORITHM => 'Chunk',
264                                                      },
265                                                      'Dry run, no changes, Chunk plugin'
266                                                   );
267                                                   
268            1                                 24   is_deeply(
269                                                      \@rows,
270                                                      [],
271                                                      'Dry run, no SQL statements made'
272                                                   );
273                                                   
274            1                                  4   is_deeply(
275                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
276                                                      [],
277                                                      'Dry run, no rows changed'
278                                                   );
279                                                   
280                                                   # Now do the real syncs that should insert 4 rows into test2.
281                                                   
282                                                   # Sync with Chunk.
283            1                                 54   is_deeply(
284                                                      { $syncer->sync_table(%args) },
285                                                      {
286                                                         DELETE    => 0,
287                                                         INSERT    => 4,
288                                                         REPLACE   => 0,
289                                                         UPDATE    => 0,
290                                                         ALGORITHM => 'Chunk',
291                                                      },
292                                                      'Sync with Chunk, 4 INSERTs'
293                                                   );
294                                                   
295            1                                 27   is_deeply(
296                                                      \@rows,
297                                                      $inserts,
298                                                      'Sync with Chunk, ChangeHandler made INSERT statements'
299                                                   );
300                                                   
301            1                                  5   is_deeply(
302                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
303                                                      $test1_rows,
304                                                      'Sync with Chunk, dst rows match src rows'
305                                                   );
306                                                   
307                                                   # Sync with Chunk again, but use chunk_size = 1k which should be converted.
308            1                              56415   $dst_dbh->do('TRUNCATE TABLE test.test2');
309            1                                 21   @rows = ();
310            1                                 12   $args{ChangeHandler} = new_ch();
311                                                   
312            1                                457   is_deeply(
313                                                      { $syncer->sync_table(%args) },
314                                                      {
315                                                         DELETE    => 0,
316                                                         INSERT    => 4,
317                                                         REPLACE   => 0,
318                                                         UPDATE    => 0,
319                                                         ALGORITHM => 'Chunk',
320                                                      },
321                                                      'Sync with Chunk chunk size 1k, 4 INSERTs'
322                                                   );
323                                                   
324            1                                 25   is_deeply(
325                                                      \@rows,
326                                                      $inserts,
327                                                      'Sync with Chunk chunk size 1k, ChangeHandler made INSERT statements'
328                                                   );
329                                                   
330            1                                  5   is_deeply(
331                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
332                                                      $test1_rows,
333                                                      'Sync with Chunk chunk size 1k, dst rows match src rows'
334                                                   );
335                                                   
336                                                   # Sync with Nibble.
337            1                              56618   $dst_dbh->do('TRUNCATE TABLE test.test2');
338            1                                 20   @rows = ();
339            1                                  9   $args{ChangeHandler} = new_ch();
340                                                   
341            1                                447   is_deeply(
342                                                      { $syncer->sync_table(%args, plugins => [$sync_nibble]) },
343                                                      {
344                                                         DELETE    => 0,
345                                                         INSERT    => 4,
346                                                         REPLACE   => 0,
347                                                         UPDATE    => 0,
348                                                         ALGORITHM => 'Nibble',
349                                                      },
350                                                      'Sync with Nibble, 4 INSERTs'
351                                                   );
352                                                   
353            1                                 24   is_deeply(
354                                                      \@rows,
355                                                      $inserts,
356                                                      'Sync with Nibble, ChangeHandler made INSERT statements'
357                                                   );
358                                                   
359            1                                  5   is_deeply(
360                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
361                                                      $test1_rows,
362                                                      'Sync with Nibble, dst rows match src rows'
363                                                   );
364                                                   
365                                                   # Sync with GroupBy.
366            1                              39522   $dst_dbh->do('TRUNCATE TABLE test.test2');
367            1                                 22   @rows = ();
368            1                                 10   $args{ChangeHandler} = new_ch();
369                                                   
370            1                                460   is_deeply(
371                                                      { $syncer->sync_table(%args, plugins => [$sync_groupby]) },
372                                                      {
373                                                         DELETE    => 0,
374                                                         INSERT    => 4,
375                                                         REPLACE   => 0,
376                                                         UPDATE    => 0,
377                                                         ALGORITHM => 'GroupBy',
378                                                      },
379                                                      'Sync with GroupBy, 4 INSERTs'
380                                                   );
381                                                   
382            1                                 24   is_deeply(
383                                                      \@rows,
384                                                      $inserts,
385                                                      'Sync with GroupBy, ChangeHandler made INSERT statements'
386                                                   );
387                                                   
388            1                                  5   is_deeply(
389                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
390                                                      $test1_rows,
391                                                      'Sync with GroupBy, dst rows match src rows'
392                                                   );
393                                                   
394                                                   # Sync with Stream.
395            1                              45496   $dst_dbh->do('TRUNCATE TABLE test.test2');
396            1                                 20   @rows = ();
397            1                                 13   $args{ChangeHandler} = new_ch();
398                                                   
399            1                                445   is_deeply(
400                                                      { $syncer->sync_table(%args, plugins => [$sync_stream]) },
401                                                      {
402                                                         DELETE    => 0,
403                                                         INSERT    => 4,
404                                                         REPLACE   => 0,
405                                                         UPDATE    => 0,
406                                                         ALGORITHM => 'Stream',
407                                                      },
408                                                      'Sync with Stream, 4 INSERTs'
409                                                   );
410                                                   
411            1                                 26   is_deeply(
412                                                      \@rows,
413                                                      $inserts,
414                                                      'Sync with Stream, ChangeHandler made INSERT statements'
415                                                   );
416                                                   
417            1                                  4   is_deeply(
418                                                      $dst_dbh->selectall_arrayref('SELECT * FROM test.test2 ORDER BY a, b'),
419                                                      $test1_rows,
420                                                      'Sync with Stream, dst rows match src rows'
421                                                   );
422                                                   
423                                                   # #############################################################################
424                                                   # Check that the plugins can resolve unique key violations.
425                                                   # #############################################################################
426                                                   
427            1                                 54   make_plugins();
428                                                   
429            1                                 14   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test3'));
430                                                   
431            1                               1357   $args{tbl_struct} = $tbl_struct;
432            1                                  8   $args{cols}       = $tbl_struct->{cols};
433            1                                  7   $src->{tbl} = 'test3';
434            1                                  6   $dst->{tbl} = 'test4';
435                                                   
436            1                                  6   @rows = ();
437            1                                  7   $args{ChangeHandler} = new_ch();
438                                                   
439            1                                391   $syncer->sync_table(%args, plugins => [$sync_stream]);
440                                                   
441            1                                 66   is_deeply(
442                                                      $dst_dbh->selectall_arrayref('select * from test.test4 order by a', { Slice => {}} ),
443                                                      [ { a => 1, b => 2 }, { a => 2, b => 1 } ],
444                                                      'Resolves unique key violations with Stream'
445                                                   );
446                                                   
447                                                   
448            1                                 23   @rows = ();
449            1                                  8   $args{ChangeHandler} = new_ch();
450                                                   
451            1                                394   $syncer->sync_table(%args, plugins => [$sync_chunk]);
452                                                   
453            1                                 11   is_deeply(
454                                                      $dst_dbh->selectall_arrayref('select * from test.test4 order by a', { Slice => {}} ),
455                                                      [ { a => 1, b => 2 }, { a => 2, b => 1 } ],
456                                                      'Resolves unique key violations with Chunk' );
457                                                   
458                                                   # ###########################################################################
459                                                   # Test locking.
460                                                   # ###########################################################################
461                                                   
462            1                                 24   make_plugins();
463                                                   
464            1                                 17   $syncer->sync_table(%args, lock => 1);
465                                                   
466                                                   # The locks should be released.
467            1                                333   ok($src_dbh->do('select * from test.test4'), 'Cycle locks released');
468                                                   
469            1                                 18   $syncer->sync_table(%args, lock => 2);
470                                                   
471                                                   # The locks should be released.
472            1                                310   ok($src_dbh->do('select * from test.test4'), 'Table locks released');
473                                                   
474            1                                 19   $syncer->sync_table(%args, lock => 3);
475                                                   
476            1                                585   ok(
477                                                      $dbh->do('replace into test.test3 select * from test.test3 limit 0'),
478                                                      'Does not lock in level 3 locking'
479                                                   );
480                                                   
481            1                                  7   eval {
482            1                                 21      $syncer->lock_and_wait(
483                                                         %args,
484                                                         lock        => 3,
485                                                         lock_level  => 3,
486                                                         replicate   => 0,
487                                                         timeout_ok  => 1,
488                                                         transaction => 0,
489                                                         wait        => 60,
490                                                      );
491                                                   };
492            1                                 13   is($EVAL_ERROR, '', 'Locks in level 3');
493                                                   
494                                                   # See DBI man page.
495            1                    1             8   use POSIX ':signal_h';
               1                                  2   
               1                                 14   
496            1                                 58   my $mask = POSIX::SigSet->new(SIGALRM);    # signals to mask in the handler
497            1                    1            42   my $action = POSIX::SigAction->new( sub { die "maatkit timeout" }, $mask, );
               1                                  7   
498            1                                 96   my $oldaction = POSIX::SigAction->new();
499            1                                 88   sigaction( SIGALRM, $action, $oldaction );
500                                                   
501                                                   throws_ok (
502                                                      sub {
503            1                    1            39         alarm 1;
504            1                                 11         $dbh->do('replace into test.test3 select * from test.test3 limit 0');
505                                                      },
506            1                                 26      qr/maatkit timeout/,
507                                                      "Level 3 lock NOT released",
508                                                   );
509                                                   
510                                                   # Kill the DBHs it in the right order: there's a connection waiting on
511                                                   # a lock.
512            1                                153   $src_dbh->disconnect();
513            1                                263   $dst_dbh->disconnect();
514            1                                 19   $src_dbh = $sb->get_dbh_for('master');
515            1                                458   $dst_dbh = $sb->get_dbh_for('slave1');
516                                                   
517            1                                499   $src->{dbh} = $src_dbh;
518            1                                  7   $dst->{dbh} = $dst_dbh;
519                                                   
520                                                   # ###########################################################################
521                                                   # Test TableSyncGroupBy.
522                                                   # ###########################################################################
523                                                   
524            1                                112   $sb->load_file('master', 'common/t/samples/before-TableSyncGroupBy.sql');
525            1                             1808956   sleep 1;
526            1                                 63   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test1'));
527                                                   
528            1                               1257   $args{tbl_struct} = $tbl_struct;
529            1                                 93   $args{cols}       = $tbl_struct->{cols};
530            1                                 37   $src->{tbl} = 'test1';
531            1                                  7   $dst->{tbl} = 'test2';
532                                                   
533            1                                 12   @rows = ();
534            1                                 14   $args{ChangeHandler} = new_ch();
535                                                   
536            1                                440   $syncer->sync_table(%args, plugins => [$sync_groupby]);
537                                                   
538            1                                 18   is_deeply(
539                                                      $dst_dbh->selectall_arrayref('select * from test.test2 order by a, b, c', { Slice => {}} ),
540                                                      [
541                                                         { a => 1, b => 2, c => 3 },
542                                                         { a => 1, b => 2, c => 3 },
543                                                         { a => 1, b => 2, c => 3 },
544                                                         { a => 1, b => 2, c => 3 },
545                                                         { a => 2, b => 2, c => 3 },
546                                                         { a => 2, b => 2, c => 3 },
547                                                         { a => 2, b => 2, c => 3 },
548                                                         { a => 2, b => 2, c => 3 },
549                                                         { a => 3, b => 2, c => 3 },
550                                                         { a => 3, b => 2, c => 3 },
551                                                      ],
552                                                      'Table synced with GroupBy',
553                                                   );
554                                                   
555                                                   # #############################################################################
556                                                   # Issue 96: mk-table-sync: Nibbler infinite loop
557                                                   # #############################################################################
558                                                   
559            1                                 47   $sb->load_file('master', 'common/t/samples/issue_96.sql');
560            1                             1568035   sleep 1;
561            1                                 65   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'issue_96','t'));
562                                                   
563            1                               1603   $args{tbl_struct} = $tbl_struct;
564            1                                 56   $args{cols}       = $tbl_struct->{cols};
565            1                                 18   $src->{db} = $dst->{db} = 'issue_96';
566            1                                 13   $src->{tbl} = 't';
567            1                                  5   $dst->{tbl} = 't2';
568                                                   
569            1                                 18   @rows = ();
570            1                                 15   $args{ChangeHandler} = new_ch();
571                                                   
572                                                   # Make paranoid-sure that the tables differ.
573            1                                  7   my $r1 = $src_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t WHERE package_id=4');
574            1                                  5   my $r2 = $dst_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t2 WHERE package_id=4');
575            1                                437   is_deeply(
576                                                      [ $r1->[0]->[0], $r2->[0]->[0] ],
577                                                      [ 'ta',          'zz'          ],
578                                                      'Infinite loop table differs (issue 96)'
579                                                   );
580                                                   
581            1                                 53   $syncer->sync_table(%args, chunk_size => 2, plugins => [$sync_nibble]);
582                                                   
583            1                                  8   $r1 = $src_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t WHERE package_id=4');
584            1                                  4   $r2 = $dst_dbh->selectall_arrayref('SELECT from_city FROM issue_96.t2 WHERE package_id=4');
585            1                                376   is(
586                                                      $r1->[0]->[0],
587                                                      $r2->[0]->[0],
588                                                      'Sync infinite loop table (issue 96)'
589                                                   );
590                                                   
591                                                   # #############################################################################
592                                                   # Test check_permissions().
593                                                   # #############################################################################
594                                                   
595                                                   # Re-using issue_96.t from above.
596            1                                 22   is(
597                                                      $syncer->have_all_privs($src->{dbh}, 'issue_96', 't'),
598                                                      1,
599                                                      'Have all privs'
600                                                   );
601                                                   
602            1                              19786   diag(`/tmp/12345/use -u root -e "CREATE USER 'bob'\@'\%' IDENTIFIED BY 'bob'"`);
603            1                              18848   diag(`/tmp/12345/use -u root -e "GRANT select ON issue_96.t TO 'bob'\@'\%'"`);
604            1                                 59   my $bob_dbh = DBI->connect(
605                                                      "DBI:mysql:;host=127.0.0.1;port=12345", 'bob', 'bob',
606                                                         { PrintError => 0, RaiseError => 1 });
607                                                   
608            1                                 41   is(
609                                                      $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
610                                                      0,
611                                                      "Don't have all privs, just select"
612                                                   );
613                                                   
614            1                              19347   diag(`/tmp/12345/use -u root -e "GRANT insert ON issue_96.t TO 'bob'\@'\%'"`);
615            1                                 43   is(
616                                                      $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
617                                                      0,
618                                                      "Don't have all privs, just select and insert"
619                                                   );
620                                                   
621            1                              19656   diag(`/tmp/12345/use -u root -e "GRANT update ON issue_96.t TO 'bob'\@'\%'"`);
622            1                                 40   is(
623                                                      $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
624                                                      0,
625                                                      "Don't have all privs, just select, insert and update"
626                                                   );
627                                                   
628            1                              19121   diag(`/tmp/12345/use -u root -e "GRANT delete ON issue_96.t TO 'bob'\@'\%'"`);
629            1                                 50   is(
630                                                      $syncer->have_all_privs($bob_dbh, 'issue_96', 't'),
631                                                      1,
632                                                      "Bob got his privs"
633                                                   );
634                                                   
635            1                              19704   diag(`/tmp/12345/use -u root -e "DROP USER 'bob'"`);
636                                                   
637                                                   # ###########################################################################
638                                                   # Test that the calback gives us the src and dst sql.
639                                                   # ###########################################################################
640                                                   
641                                                   # Re-using issue_96.t from above.  The tables are already in sync so there
642                                                   # should only be 1 sync cycle.
643            1                                 35   @rows = ();
644            1                                 20   $args{ChangeHandler} = new_ch();
645            1                                509   my @sqls;
646                                                   $syncer->sync_table(%args, chunk_size => 1000, plugins => [$sync_nibble],
647            1                    1            71      callback => sub { push @sqls, @_; } );
               1                                 18   
648            1                                 74   is_deeply(
649                                                      \@sqls,
650                                                      [
651                                                         'SELECT /*issue_96.t:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, \'0\'))) AS crc FROM `issue_96`.`t` FORCE INDEX (`package_id`) WHERE (1=1)',
652                                                         'SELECT /*issue_96.t2:1/1*/ 0 AS chunk_num, COUNT(*) AS cnt, LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, \'0\'))) AS crc FROM `issue_96`.`t2` FORCE INDEX (`package_id`) WHERE (1=1)',
653                                                      ],
654                                                      'Callback gives src and dst sql'
655                                                   );
656                                                   
657                                                   
658                                                   # #############################################################################
659                                                   # Test that make_checksum_queries() doesn't pass replicate.
660                                                   # #############################################################################
661                                                   
662                                                   # Re-using table from above.
663                                                   
664            1                                 25   my @foo = $syncer->make_checksum_queries(%args, replicate => 'bad');
665            1                                 15   is_deeply(
666                                                      \@foo,
667                                                      [
668                                                         'SELECT /*PROGRESS_COMMENT*//*CHUNK_NUM*/ COUNT(*) AS cnt, LOWER(CONCAT(LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 1, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc, 17, 16), 16, 10) AS UNSIGNED)), 10, 16), 16, \'0\'), LPAD(CONV(BIT_XOR(CAST(CONV(SUBSTRING(@crc := SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`)))), 33, 8), 16, 10) AS UNSIGNED)), 10, 16), 8, \'0\'))) AS crc FROM /*DB_TBL*//*INDEX_HINT*//*WHERE*/',
669                                                         '`package_id`, `location`, `from_city`, SHA1(CONCAT_WS(\'#\', `package_id`, `location`, `from_city`, CONCAT(ISNULL(`package_id`), ISNULL(`location`), ISNULL(`from_city`))))',
670                                                      ],
671                                                      'make_checksum_queries() does not pass replicate arg'
672                                                   );
673                                                   
674                                                   # #############################################################################
675                                                   # Issue 464: Make mk-table-sync do two-way sync
676                                                   # #############################################################################
677            1                             2149520   diag(`$trunk/sandbox/start-sandbox master 12347 >/dev/null`);
678            1                                 42   my $dbh2 = $sb->get_dbh_for('slave2');
679   ***      1     50                          18   SKIP: {
680            1                                575      skip 'Cannot connect to sandbox master', 1 unless $dbh;
681   ***      1     50                          10      skip 'Cannot connect to second sandbox master', 1 unless $dbh2;
682                                                   
683                                                      sub set_bidi_callbacks {
684                                                         $sync_chunk->set_callback('same_row', sub {
685           12                   12          1182            my ( %args ) = @_;
686           12                                124            my ($lr, $rr, $syncer) = @args{qw(lr rr syncer)};
687           12                                 70            my $ch = $syncer->{ChangeHandler};
688           12                                 43            my $change_dbh;
689           12                                 41            my $auth_row;
690                                                   
691           12                                 69            my $left_ts  = $lr->{ts};
692           12                                 60            my $right_ts = $rr->{ts};
693           12                                 42            MKDEBUG && TableSyncer::_d("left ts: $left_ts");
694           12                                 40            MKDEBUG && TableSyncer::_d("right ts: $right_ts");
695                                                   
696   ***     12            50                  150            my $cmp = ($left_ts || '') cmp ($right_ts || '');
      ***                   50                        
697           12    100                          87            if ( $cmp == -1 ) {
      ***            50                               
698            9                                 39               MKDEBUG && TableSyncer::_d("right dbh $dbh2 is newer; update left dbh $src_dbh");
699            9                                100               $ch->set_src('right', $dbh2);
700            9                                798               $auth_row   = $args{rr};
701            9                                 43               $change_dbh = $src_dbh;
702                                                            }
703                                                            elsif ( $cmp == 1 ) {
704            3                                  9               MKDEBUG && TableSyncer::_d("left dbh $src_dbh is newer; update right dbh $dbh2");
705            3                                 31               $ch->set_src('left', $src_dbh);
706            3                                237               $auth_row  = $args{lr};
707            3                                 14               $change_dbh = $dbh2;
708                                                            }
709           12                                156            return ('UPDATE', $auth_row, $change_dbh);
710            3                    3            93         });
711                                                         $sync_chunk->set_callback('not_in_right', sub {
712            3                    3           241            my ( %args ) = @_;
713            3                                 48            $args{syncer}->{ChangeHandler}->set_src('left', $src_dbh);
714            3                                282            return 'INSERT', $args{lr}, $dbh2;
715            3                                139         });
716                                                         $sync_chunk->set_callback('not_in_left', sub {
717            6                    6           480            my ( %args ) = @_;
718            6                                 93            $args{syncer}->{ChangeHandler}->set_src('right', $dbh2);
719            6                                576            return 'INSERT', $args{rr}, $src_dbh;
720            3                                126         });
721                                                      };
722                                                   
723                                                      # Proper data on both tables after bidirectional sync.
724            1                                 74      my $bidi_data = 
725                                                         [
726                                                            [1,   'abc',   1,  '2010-02-01 05:45:30'],
727                                                            [2,   'def',   2,  '2010-01-31 06:11:11'],
728                                                            [3,   'ghi',   5,  '2010-02-01 09:17:52'],
729                                                            [4,   'jkl',   6,  '2010-02-01 10:11:33'],
730                                                            [5,   undef,   0,  '2010-02-02 05:10:00'],
731                                                            [6,   'p',     4,  '2010-01-31 10:17:00'],
732                                                            [7,   'qrs',   5,  '2010-02-01 10:11:11'],
733                                                            [8,   'tuv',   6,  '2010-01-31 10:17:20'],
734                                                            [9,   'wxy',   7,  '2010-02-01 10:17:00'],
735                                                            [10,  'z',     8,  '2010-01-31 10:17:08'],
736                                                            [11,  '?',     0,  '2010-01-29 11:17:12'],
737                                                            [12,  '',      0,  '2010-02-01 11:17:00'],
738                                                            [13,  'hmm',   1,  '2010-02-02 12:17:31'],
739                                                            [14,  undef,   0,  '2010-01-31 10:17:00'],
740                                                            [15,  'gtg',   7,  '2010-02-02 06:01:08'],
741                                                            [17,  'good',  1,  '2010-02-02 21:38:03'],
742                                                            [20,  'new', 100,  '2010-02-01 04:15:36'],
743                                                         ];
744                                                   
745                                                      # ########################################################################
746                                                      # First bidi test with chunk size=2, roughly 9 chunks.
747                                                      # ########################################################################
748                                                      # Load "master" data.
749            1                                 24      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
750            1                             130155      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
751                                                      # Load remote data.
752            1                             190102      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
753            1                             248382      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
754            1                             133688      make_plugins();
755            1                                 23      set_bidi_callbacks();
756            1                                 61      $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q, 'bidi','t'));
757            1                               1782      $args{tbl_struct}    = $tbl_struct;
758            1                                 69      $args{cols}          = [qw(ts)],  # Compare only ts col when chunks differ.
759                                                      $src->{db}           = 'bidi';
760            1                                 12      $src->{tbl}          = 't';
761            1                                 13      $dst->{db}           = 'bidi';
762            1                                  5      $dst->{tbl}          = 't';
763            1                                  6      $dst->{dbh}          = $dbh2;            # Must set $dbh2 here and
764            1                                  8      $args{ChangeHandler} = new_ch($dbh2, 0); # here to override $dst_dbh.
765            1                                431      @rows                = ();
766                                                   
767            1                                 37      $syncer->sync_table(%args, plugins => [$sync_chunk]);
768                                                   
769            1                                  7      my $res = $src_dbh->selectall_arrayref('select * from bidi.t order by id');
770            1                                707      is_deeply(
771                                                         $res,
772                                                         $bidi_data,
773                                                         'Bidirectional sync "master" (chunk size 2)'
774                                                      );
775                                                   
776            1                                  5      $res = $dbh2->selectall_arrayref('select * from bidi.t order by id');
777            1                                620      is_deeply(
778                                                         $res,
779                                                         $bidi_data,
780                                                         'Bidirectional sync remote-1 (chunk size 2)'
781                                                      );
782                                                   
783                                                      # ########################################################################
784                                                      # Test it again with a larger chunk size, roughly half the table.
785                                                      # ########################################################################
786            1                                 17      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
787            1                             204877      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
788            1                             167334      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
789            1                             236334      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
790            1                             144643      make_plugins();
791            1                                 15      set_bidi_callbacks();
792            1                                 42      $args{ChangeHandler} = new_ch($dbh2, 0);
793            1                                503      @rows = ();
794                                                   
795            1                                 53      $syncer->sync_table(%args, plugins => [$sync_chunk], chunk_size => 10);
796                                                   
797            1                                  6      $res = $src_dbh->selectall_arrayref('select * from bidi.t order by id');
798            1                                659      is_deeply(
799                                                         $res,
800                                                         $bidi_data,
801                                                         'Bidirectional sync "master" (chunk size 10)'
802                                                      );
803                                                   
804            1                                  3      $res = $dbh2->selectall_arrayref('select * from bidi.t order by id');
805            1                                387      is_deeply(
806                                                         $res,
807                                                         $bidi_data,
808                                                         'Bidirectional sync remote-1 (chunk size 10)'
809                                                      );
810                                                   
811                                                      # ########################################################################
812                                                      # Chunk whole table.
813                                                      # ########################################################################
814            1                                 20      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/table.sql');
815            1                             192255      $sb->load_file('master', 'mk-table-sync/t/samples/bidirectional/master-data.sql');
816            1                             180175      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/table.sql');
817            1                             268595      $sb->load_file('slave2', 'mk-table-sync/t/samples/bidirectional/remote-1.sql');
818            1                             111404      make_plugins();
819            1                                 13      set_bidi_callbacks();
820            1                                 39      $args{ChangeHandler} = new_ch($dbh2, 0);
821            1                                546      @rows = ();
822                                                   
823            1                                 45      $syncer->sync_table(%args, plugins => [$sync_chunk], chunk_size => 100000);
824                                                   
825            1                                  6      $res = $src_dbh->selectall_arrayref('select * from bidi.t order by id');
826            1                                659      is_deeply(
827                                                         $res,
828                                                         $bidi_data,
829                                                         'Bidirectional sync "master" (whole table chunk)'
830                                                      );
831                                                   
832            1                                  5      $res = $dbh2->selectall_arrayref('select * from bidi.t order by id');
833            1                                617      is_deeply(
834                                                         $res,
835                                                         $bidi_data,
836                                                         'Bidirectional sync remote-1 (whole table chunk)'
837                                                      );
838                                                   
839                                                      # ########################################################################
840                                                      # See TableSyncer.pm for why this is so.
841                                                      # ######################################################################## 
842            1                                 14      $args{ChangeHandler} = new_ch($dbh2, 1);
843                                                      throws_ok(
844            1                    1            22         sub { $syncer->sync_table(%args, bidirectional => 1, plugins => [$sync_chunk]) },
845            1                                227         qr/Queueing does not work with bidirectional syncing/,
846                                                         'Queueing does not work with bidirectional syncing'
847                                                      );
848                                                   
849            1                                 17      $sb->wipe_clean($dbh2);
850            1                              58859      diag(`$trunk/sandbox/stop-sandbox remove 12347 >/dev/null &`);
851                                                   }
852                                                   
853                                                   
854                                                   
855                                                   # #############################################################################
856                                                   # Test with transactions.
857                                                   # #############################################################################
858                                                   
859                                                   # Sandbox::get_dbh_for() defaults to AutoCommit=1.  Autocommit must
860                                                   # be off else commit() will cause an error.
861            1                                 33   $dbh      = $sb->get_dbh_for('master', {AutoCommit=>0});
862            1                                552   $src_dbh  = $sb->get_dbh_for('master', {AutoCommit=>0});
863            1                                523   $dst_dbh  = $sb->get_dbh_for('slave1', {AutoCommit=>0});
864                                                   
865            1                                710   make_plugins();
866            1                                 31   $tbl_struct = $tp->parse($du->get_create_table($src_dbh, $q,'test','test1'));
867            1                               1119   $src = {
868                                                      dbh      => $src_dbh,
869                                                      misc_dbh => $dbh,
870                                                      db       => 'test',
871                                                      tbl      => 'test1',
872                                                   };
873            1                                 15   $dst = {
874                                                      dbh => $dst_dbh,
875                                                      db  => 'test',
876                                                      tbl => 'test2',
877                                                   };
878            1                                516   %args = (
879                                                      plugins       => $plugins,
880                                                      src           => $src,
881                                                      dst           => $dst,
882                                                      tbl_struct    => $tbl_struct,
883                                                      cols          => $tbl_struct->{cols},
884                                                      chunk_size    => 5,
885                                                      RowDiff       => $rd,
886                                                      ChangeHandler => undef,  # call new_ch()
887                                                      function      => 'SHA1',
888                                                      transaction   => 1,
889                                                      lock          => 1,
890                                                   );
891            1                                 11   $args{ChangeHandler} = new_ch();
892            1                                408   @rows = ();
893                                                   
894                                                   # There are no diffs.  This just tests that the code doesn't crash
895                                                   # when transaction is true.
896            1                                 25   $syncer->sync_table(%args);
897            1                                 82   is_deeply(
898                                                      \@rows,
899                                                      [],
900                                                      "Sync with transaction"
901                                                   );
902                                                   
903                                                   # #############################################################################
904                                                   # Done.
905                                                   # #############################################################################
906            1                                 17   my $output = '';
907                                                   {
908            1                                  6      local *STDERR;
               1                                 82   
909            1                    1             4      open STDERR, '>', \$output;
               1                                551   
               1                                  5   
               1                                 14   
910            1                                 44      $syncer->_d('Complete test coverage');
911                                                   }
912                                                   like(
913            1                                 40      $output,
914                                                      qr/Complete test coverage/,
915                                                      '_d() works'
916                                                   );
917            1                                 24   $sb->wipe_clean($src_dbh);
918            1                             314664   $sb->wipe_clean($dst_dbh);
919            1                                  8   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
46    ***     50      0      1   if (not $src_dbh or not $dbh) { }
      ***     50      0      1   elsif (not $dst_dbh) { }
232          100     21     31   if ($change_dbh) { }
      ***     50      0     31   elsif ($dbh) { }
245          100      4     11   defined $queue ? :
679   ***     50      0      1   unless $dbh
681   ***     50      0      1   unless $dbh2
697          100      9      3   if ($cmp == -1) { }
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
696   ***     50     12      0   $left_ts || ''
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
BEGIN                  1 TableSyncer.t:495
BEGIN                  1 TableSyncer.t:9  
BEGIN                  1 TableSyncer.t:909
__ANON__              52 TableSyncer.t:230
__ANON__               1 TableSyncer.t:497
__ANON__               1 TableSyncer.t:503
__ANON__               1 TableSyncer.t:647
__ANON__              12 TableSyncer.t:685
__ANON__               1 TableSyncer.t:69 
__ANON__               3 TableSyncer.t:712
__ANON__               6 TableSyncer.t:717
__ANON__               1 TableSyncer.t:74 
__ANON__               1 TableSyncer.t:79 
__ANON__               1 TableSyncer.t:84 
__ANON__               1 TableSyncer.t:844
make_plugins           7 TableSyncer.t:116
new_ch                15 TableSyncer.t:221
set_bidi_callbacks     3 TableSyncer.t:710


