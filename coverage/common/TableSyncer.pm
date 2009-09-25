---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableSyncer.pm   82.3   56.7   67.5   92.9    n/a  100.0   74.9
Total                          82.3   56.7   67.5   92.9    n/a  100.0   74.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Sep 25 20:36:28 2009
Finish:       Fri Sep 25 20:36:37 2009

/home/daniel/dev/maatkit/common/TableSyncer.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2009 Baron Schwartz.
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
18                                                    # TableSyncer package $Revision: 4754 $
19                                                    # ###########################################################################
20                                                    package TableSyncer;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                 10   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
26             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  9   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 11   
32                                                    
33                                                    # Arguments:
34                                                    #   * MasterSlave    A MasterSlave module
35                                                    #   * Quoter         A Quoter module
36                                                    #   * VersionParser  A VersionParser module
37                                                    #   * TableChecksum  A TableChecksum module
38                                                    sub new {
39             5                    5           201      my ( $class, %args ) = @_;
40             5                                 30      my @required_args = qw(MasterSlave Quoter VersionParser TableChecksum);
41             5                                 19      foreach my $arg ( @required_args ) {
42            14    100                          52         die "I need a $arg argument" unless defined $args{$arg};
43                                                       }
44             1                                  6      my $self = { %args };
45             1                                 24      return bless $self, $class;
46                                                    }
47                                                    
48                                                    # Return the first plugin from the arrayref of TableSync* plugins
49                                                    # that can sync the given table struct.  plugin->can_sync() usually
50                                                    # returns a hashref that it wants back when plugin->prepare_to_sync()
51                                                    # is called.  Or, it may return nothing (false) to say that it can't
52                                                    # sync the table.
53                                                    sub get_best_plugin {
54            16                   16           237      my ( $self, %args ) = @_;
55            16                                 97      foreach my $arg ( qw(plugins tbl_struct) ) {
56    ***     32     50                         159         die "I need a $arg argument" unless $args{$arg};
57                                                       }
58            16                                 39      MKDEBUG && _d('Getting best plugin');
59            16                                 48      foreach my $plugin ( @{$args{plugins}} ) {
              16                                 77   
60            19                                 45         MKDEBUG && _d('Trying plugin', $plugin->name());
61            19                                181         my ($can_sync, %plugin_args) = $plugin->can_sync(%args);
62            19    100                         110         if ( $can_sync ) {
63            16                                 39           MKDEBUG && _d('Can sync with', $plugin->name(), Dumper(\%plugin_args));
64            16                                148           return $plugin, %plugin_args;
65                                                          }
66                                                       }
67    ***      0                                  0      MKDEBUG && _d('No plugin can sync the table');
68    ***      0                                  0      return;
69                                                    }
70                                                    
71                                                    # Required arguments:
72                                                    #   * plugins         Arrayref of TableSync* modules, in order of preference
73                                                    #   * src             Hashref with source dbh, db, tbl
74                                                    #   * dst             Hashref with destination dbh, db, tbl
75                                                    #   * tbl_struct      Return val from TableParser::parser() for src and dst tbl
76                                                    #   * cols            Arrayref of column names to checksum/compare
77                                                    #   * chunk_size      Size/number of rows to select in each chunk
78                                                    #   * RowDiff         A RowDiff module
79                                                    #   * ChangeHandler   A ChangeHandler module
80                                                    # Optional arguments:
81                                                    #   * where           WHERE clause to restrict synced rows (default none)
82                                                    #   * replicate       If syncing via replication (default no)
83                                                    #   * function        Crypto hash func for checksumming chunks (default CRC32)
84                                                    #   * dry_run         Prepare to sync but don't actually sync (default no)
85                                                    #   * chunk_col       Column name to chunk table on (default auto-choose)
86                                                    #   * chunk_index     Index name to use for chunking table (default auto-choose)
87                                                    #   * index_hint      Use FORCE/USE INDEX (chunk_index) (default yes)
88                                                    #   * buffer_in_mysql Use SQL_BUFFER_RESULT (default no)
89                                                    #   * transaction     locking
90                                                    #   * change_dbh      locking
91                                                    #   * lock            locking
92                                                    #   * wait            locking
93                                                    #   * timeout_ok      locking
94                                                    sub sync_table {
95            13                   13           295      my ( $self, %args ) = @_;
96            13                                103      my @required_args = qw(plugins src dst tbl_struct cols chunk_size
97                                                                              RowDiff ChangeHandler);
98            13                                 62      foreach my $arg ( @required_args ) {
99    ***    104     50                         497         die "I need a $arg argument" unless $args{$arg};
100                                                      }
101           13                                 35      MKDEBUG && _d('Syncing table with args', Dumper(\%args));
102           13                                 81      my ($plugins, $src, $dst, $tbl_struct, $cols, $chunk_size, $rd, $ch)
103                                                         = @args{@required_args};
104                                                   
105   ***     13     50                          80      $args{index_hint}    = 1 unless defined $args{index_hint};
106   ***     13            50                   73      $args{replicate}   ||= 0;
107           13           100                   69      $args{lock}        ||= 0;
108   ***     13            50                   71      $args{wait}        ||= 0;
109   ***     13            50                   79      $args{transaction} ||= 0;
110   ***     13            50                   67      $args{timeout_ok}  ||= 0;
111                                                   
112           13                                 48      my $q  = $self->{Quoter};
113           13                                 49      my $vp = $self->{VersionParser};
114                                                   
115                                                      # ########################################################################
116                                                      # Get and prepare the first plugin that can sync this table.
117                                                      # ########################################################################
118           13                                113      my ($plugin, %plugin_args) = $self->get_best_plugin(%args);
119   ***     13     50                          73      die "No plugin can sync $src->{db}.$src->{tbl}" unless $plugin;
120                                                   
121                                                      # The row-level (state 2) checksums use __crc, so the table can't use that.
122           13                                 43      my $crc_col = '__crc';
123           13                                 82      while ( $tbl_struct->{is_col}->{$crc_col} ) {
124   ***      0                                  0         $crc_col = "_$crc_col"; # Prepend more _ until not a column.
125                                                      }
126           13                                 46      MKDEBUG && _d('CRC column:', $crc_col);
127                                                   
128                                                      # Make an index hint for either the explicitly given chunk_index
129                                                      # or the chunk_index chosen by the plugin if index_hint is true.
130           13                                 33      my $index_hint;
131   ***     13     50     33                  111      my $hint = ($vp->version_ge($src->{dbh}, '4.0.9')
132                                                                  && $vp->version_ge($dst->{dbh}, '4.0.9') ? 'FORCE' : 'USE')
133                                                               . ' INDEX';
134   ***     13     50     66                  146      if ( $args{chunk_index} ) {
                    100                               
135   ***      0                                  0         MKDEBUG && _d('Using given chunk index for index hint');
136   ***      0                                  0         $index_hint = "$hint (" . $q->quote($args{chunk_index}) . ")";
137                                                      }
138                                                      elsif ( $plugin_args{chunk_index} && $args{index_hint} ) {
139            9                                 21         MKDEBUG && _d('Using chunk index chosen by plugin for index hint');
140            9                                 73         $index_hint = "$hint (" . $q->quote($plugin_args{chunk_index}) . ")";
141                                                      }
142           13                                 33      MKDEBUG && _d('Index hint:', $index_hint);
143                                                   
144           13                                 45      eval {
145           13                                174         $plugin->prepare_to_sync(
146                                                            %args,
147                                                            %plugin_args,
148                                                            dbh         => $src->{dbh},
149                                                            db          => $src->{db},
150                                                            tbl         => $src->{tbl},
151                                                            crc_col     => $crc_col,
152                                                            index_hint  => $index_hint,
153                                                         );
154                                                      };
155   ***     13     50                          77      if ( $EVAL_ERROR ) {
156                                                         # At present, no plugin should fail to prepare, but just in case...
157   ***      0                                  0         die 'Failed to prepare TableSync', $plugin->name(), ' plugin: ',
158                                                            $EVAL_ERROR;
159                                                      }
160                                                   
161                                                      # Some plugins like TableSyncChunk use checksum queries, others like
162                                                      # TableSyncGroupBy do not.  For those that do, make chunk (state 0)
163                                                      # and row (state 2) checksum queries.
164           13    100                          74      if ( $plugin->uses_checksum() ) {
165            9                                 26         eval {
166            9                                 87            my ($chunk_sql, $row_sql) = $self->make_checksum_queries(%args);
167            9                                 84            $plugin->set_checksum_queries($chunk_sql, $row_sql);
168                                                         };
169   ***      9     50                          44         if ( $EVAL_ERROR ) {
170                                                            # This happens if src and dst are really different and the same
171                                                            # checksum algo and hash func can't be used on both.
172   ***      0                                  0            die "Failed to make checksum queries: $EVAL_ERROR";
173                                                         }
174                                                      } 
175                                                   
176                                                      # ########################################################################
177                                                      # Plugin is ready, return now if this is a dry run.
178                                                      # ########################################################################
179           13    100                          71      if ( $args{dry_run} ) {
180            1                                  9         return $ch->get_changes(), ALGORITHM => $plugin->name();
181                                                      }
182                                                   
183                                                      # ########################################################################
184                                                      # Start syncing the table.
185                                                      # ########################################################################
186                                                   
187                                                      # USE db on src and dst for cases like when replicate-do-db is being used.
188           12                               1289      eval {
189           12                               1762         $src->{dbh}->do("USE `$src->{db}`");
190           12                               1282         $dst->{dbh}->do("USE `$dst->{db}`");
191                                                      };
192   ***     12     50                          70      if ( $EVAL_ERROR ) {
193                                                         # This shouldn't happen, but just in case.  (The db and tbl on src
194                                                         # and dst should be checked before calling this sub.)
195   ***      0                                  0         die "Failed to USE database on source or destination: $EVAL_ERROR";
196                                                      }
197                                                   
198           12                                149      $self->lock_and_wait(%args, lock_level => 2);  # per-table lock
199                                                   
200           12                                 43      my $cycle = 0;
201           12                                102      while ( !$plugin->done() ) {
202                                                   
203                                                         # Do as much of the work as possible before opening a transaction or
204                                                         # locking the tables.
205           29                                 84         MKDEBUG && _d('Beginning sync cycle', $cycle);
206           29                                318         my $src_sql = $plugin->get_sql(
207                                                            database   => $src->{db},
208                                                            table      => $src->{tbl},
209                                                            where      => $args{where},
210                                                         );
211           29                                300         my $dst_sql = $plugin->get_sql(
212                                                            database   => $dst->{db},
213                                                            table      => $dst->{tbl},
214                                                            where      => $args{where},
215                                                         );
216   ***     29     50                         173         if ( $args{transaction} ) {
217                                                            # TODO: update this for 2-way sync.
218   ***      0      0      0                    0            if ( $args{change_dbh} && $args{change_dbh} eq $src->{dbh} ) {
      ***             0                               
219                                                               # Making changes on master which will replicate to the slave.
220   ***      0                                  0               $src_sql .= ' FOR UPDATE';
221   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
222                                                            }
223                                                            elsif ( $args{change_dbh} ) {
224                                                               # Making changes on the slave.
225   ***      0                                  0               $src_sql .= ' LOCK IN SHARE MODE';
226   ***      0                                  0               $dst_sql .= ' FOR UPDATE';
227                                                            }
228                                                            else {
229                                                               # TODO: this doesn't really happen
230   ***      0                                  0               $src_sql .= ' LOCK IN SHARE MODE';
231   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
232                                                            }
233                                                         }
234           29                                163         $plugin->prepare_sync_cycle($src);
235           29                                142         $plugin->prepare_sync_cycle($dst);
236           29                                 70         MKDEBUG && _d('src:', $src_sql);
237           29                                 66         MKDEBUG && _d('dst:', $dst_sql);
238           29                                 68         my $src_sth = $src->{dbh}->prepare($src_sql);
239           29                                 62         my $dst_sth = $dst->{dbh}->prepare($dst_sql);
240                                                   
241                                                         # The first cycle should lock to begin work; after that, unlock only if
242                                                         # the plugin says it's OK (it may want to dig deeper on the rows it
243                                                         # currently has locked).
244           29                                187         my $executed_src = 0;
245           29    100    100                  227         if ( !$cycle || !$plugin->pending_changes() ) {
246                                                            # per-sync cycle lock
247           22                                229            $executed_src
248                                                               = $self->lock_and_wait(%args, src_sth => $src_sth, lock_level => 1);
249                                                         }
250                                                   
251                                                         # The source sth might have already been executed by lock_and_wait().
252   ***     29     50                       10117         $src_sth->execute() unless $executed_src;
253           29                               8379         $dst_sth->execute();
254                                                   
255           29                                306         $rd->compare_sets(
256                                                            left   => $src_sth,
257                                                            right  => $dst_sth,
258                                                            syncer => $plugin,
259                                                            tbl    => $tbl_struct,
260                                                         );
261           29                                 68         MKDEBUG && _d('Finished sync cycle', $cycle);
262           29                                192         $ch->process_rows(1);
263                                                   
264           29                               1097         $cycle++;
265                                                      }
266                                                   
267           12                                 73      $ch->process_rows();
268                                                   
269           12                                160      $self->unlock(%args, lock_level => 2);
270                                                   
271           12                                 83      return $ch->get_changes(), ALGORITHM => $plugin->name();
272                                                   }
273                                                   
274                                                   sub make_checksum_queries {
275            9                    9            95      my ( $self, %args ) = @_;
276            9                                 66      my @required_args = qw(src dst tbl_struct);
277            9                                 32      foreach my $arg ( @required_args ) {
278   ***     27     50                         122         die "I need a $arg argument" unless $args{$arg};
279                                                      }
280            9                                 44      my ($src, $dst, $tbl_struct) = @args{@required_args};
281            9                                 32      my $checksum = $self->{TableChecksum};
282                                                   
283                                                      # Decide on checksumming strategy and store checksum query prototypes for
284                                                      # later.
285            9                                 88      my $src_algo = $checksum->best_algorithm(
286                                                         algorithm => 'BIT_XOR',
287                                                         dbh       => $src->{dbh},
288                                                         where     => 1,
289                                                         chunk     => 1,
290                                                         count     => 1,
291                                                      );
292            9                                 59      my $dst_algo = $checksum->best_algorithm(
293                                                         algorithm => 'BIT_XOR',
294                                                         dbh       => $dst->{dbh},
295                                                         where     => 1,
296                                                         chunk     => 1,
297                                                         count     => 1,
298                                                      );
299   ***      9     50                          43      if ( $src_algo ne $dst_algo ) {
300   ***      0                                  0         die "Source and destination checksum algorithms are different: ",
301                                                            "$src_algo on source, $dst_algo on destination"
302                                                      }
303            9                                 19      MKDEBUG && _d('Chosen algo:', $src_algo);
304                                                   
305            9                                 91      my $src_func = $checksum->choose_hash_func(dbh => $src->{dbh}, %args);
306            9                                 90      my $dst_func = $checksum->choose_hash_func(dbh => $dst->{dbh}, %args);
307   ***      9     50                          52      if ( $src_func ne $dst_func ) {
308   ***      0                                  0         die "Source and destination hash functions are different: ",
309                                                         "$src_func on source, $dst_func on destination";
310                                                      }
311            9                                 24      MKDEBUG && _d('Chosen hash func:', $src_func);
312                                                   
313                                                      # Since the checksum algo and hash func are the same on src and dst
314                                                      # it doesn't matter if we use src_algo/func or dst_algo/func.
315                                                   
316            9                                 74      my $crc_wid    = $checksum->get_crc_wid($src->{dbh}, $src_func);
317            9                                 68      my ($crc_type) = $checksum->get_crc_type($src->{dbh}, $src_func);
318            9                                 29      my $opt_slice;
319   ***      9     50     33                  117      if ( $src_algo eq 'BIT_XOR' && $crc_type !~ m/int$/ ) {
320            9                                 71         $opt_slice = $checksum->optimize_xor($src->{dbh}, $src_func);
321                                                      }
322                                                   
323            9                                184      my $chunk_sql = $checksum->make_checksum_query(
324                                                         db        => $src->{db},
325                                                         tbl       => $src->{tbl},
326                                                         algorithm => $src_algo,
327                                                         function  => $src_func,
328                                                         crc_wid   => $crc_wid,
329                                                         crc_type  => $crc_type,
330                                                         opt_slice => $opt_slice,
331                                                         %args,
332                                                      );
333            9                                 30      MKDEBUG && _d('Chunk sql:', $chunk_sql);
334            9                                 64      my $row_sql = $checksum->make_row_checksum(
335                                                         %args,
336                                                         function => $src_func,
337                                                      );
338            9                                 30      MKDEBUG && _d('Row sql:', $row_sql);
339            9                                 94      return $chunk_sql, $row_sql;
340                                                   }
341                                                   
342                                                   sub lock_table {
343            4                    4            23      my ( $self, $dbh, $where, $db_tbl, $mode ) = @_;
344            4                                 19      my $query = "LOCK TABLES $db_tbl $mode";
345            4                                  8      MKDEBUG && _d($query);
346            4                                305      $dbh->do($query);
347            4                                 23      MKDEBUG && _d('Acquired table lock on', $where, 'in', $mode, 'mode');
348                                                   }
349                                                   
350                                                   # Doesn't work quite the same way as lock_and_wait. It will unlock any LOWER
351                                                   # priority lock level, not just the exact same one.
352                                                   sub unlock {
353           12                   12           175      my ( $self, %args ) = @_;
354                                                   
355           12                                 90      foreach my $arg ( qw(src dst lock replicate timeout_ok transaction wait
356                                                                           lock_level) ) {
357   ***     96     50                         413         die "I need a $arg argument" unless defined $args{$arg};
358                                                      }
359           12                                 46      my $src = $args{src};
360           12                                 40      my $dst = $args{dst};
361                                                   
362           12    100    100                  115      return unless $args{lock} && $args{lock} <= $args{lock_level};
363                                                   
364                                                      # First, unlock/commit.
365            2                                 10      foreach my $dbh ( $src->{dbh}, $dst->{dbh} ) {
366   ***      4     50                          19         if ( $args{transaction} ) {
367   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
368   ***      0                                  0            $dbh->commit();
369                                                         }
370                                                         else {
371            4                                 12            my $sql = 'UNLOCK TABLES';
372            4                                  9            MKDEBUG && _d($dbh, $sql);
373            4                                421            $dbh->do($sql);
374                                                         }
375                                                      }
376                                                   
377            2                                 14      return;
378                                                   }
379                                                   
380                                                   # Lock levels:
381                                                   #   0 => none
382                                                   #   1 => per sync cycle
383                                                   #   2 => per table
384                                                   #   3 => global
385                                                   # This function might actually execute the $src_sth.  If we're using
386                                                   # transactions instead of table locks, the $src_sth has to be executed before
387                                                   # the MASTER_POS_WAIT() on the slave.  The return value is whether the
388                                                   # $src_sth was executed.
389                                                   sub lock_and_wait {
390           35                   35           477      my ( $self, %args ) = @_;
391           35                                173      my $result = 0;
392                                                   
393           35                                180      foreach my $arg ( qw(src dst lock replicate timeout_ok transaction wait
394                                                                           lock_level) ) {
395   ***    280     50                        1195         die "I need a $arg argument" unless defined $args{$arg};
396                                                      }
397           35                                122      my $src = $args{src};
398           35                                116      my $dst = $args{dst};
399                                                   
400           35    100    100                  366      return unless $args{lock} && $args{lock} == $args{lock_level};
401                                                   
402                                                      # First, commit/unlock the previous transaction/lock.
403            3                                 16      foreach my $dbh ( $src->{dbh}, $dst->{dbh} ) {
404   ***      6     50                          26         if ( $args{transaction} ) {
405   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
406   ***      0                                  0            $dbh->commit();
407                                                         }
408                                                         else {
409            6                                 19            my $sql = 'UNLOCK TABLES';
410            6                                 14            MKDEBUG && _d($dbh, $sql);
411            6                                473            $dbh->do($sql);
412                                                         }
413                                                      }
414                                                   
415                                                      # User wants us to lock for consistency.  But lock only on source initially;
416                                                      # might have to wait for the slave to catch up before locking on the dest.
417            3    100                          18      if ( $args{lock} == 3 ) {
418            1                                  5         my $sql = 'FLUSH TABLES WITH READ LOCK';
419            1                                  2         MKDEBUG && _d($src->{dbh}, ',', $sql);
420            1                                415         $src->{dbh}->do($sql);
421                                                      }
422                                                      else {
423                                                         # Lock level 2 (per-table) or 1 (per-sync cycle)
424   ***      2     50                           9         if ( $args{transaction} ) {
425   ***      0      0                           0            if ( $args{src_sth} ) {
426                                                               # Execute the $src_sth on the source, so LOCK IN SHARE MODE/FOR
427                                                               # UPDATE will lock the rows examined.
428   ***      0                                  0               MKDEBUG && _d('Executing statement on source to lock rows');
429   ***      0                                  0               $args{src_sth}->execute();
430   ***      0                                  0               $result = 1;
431                                                            }
432                                                         }
433                                                         else {
434   ***      2     50                          18            $self->lock_table($src->{dbh}, 'source',
435                                                               $self->{Quoter}->quote($src->{db}, $src->{tbl}),
436                                                               $args{replicate} ? 'WRITE' : 'READ');
437                                                         }
438                                                      }
439                                                   
440                                                      # If there is any error beyond this point, we need to unlock/commit.
441            3                                 12      eval {
442            3    100                          18         if ( $args{wait} ) {
443                                                            # Always use the misc_dbh dbh to check the master's position, because
444                                                            # the main dbh might be in use due to executing $src_sth.
445            1                                 24            $self->{MasterSlave}->wait_for_master(
446                                                               $src->{misc_dbh}, $dst->{dbh}, $args{wait}, $args{timeout_ok});
447                                                         }
448                                                   
449                                                         # Don't lock on destination if it's a replication slave, or the
450                                                         # replication thread will not be able to make changes.
451   ***      3     50                          14         if ( $args{replicate} ) {
452   ***      0                                  0            MKDEBUG
453                                                               && _d('Not locking destination because syncing via replication');
454                                                         }
455                                                         else {
456            3    100                          21            if ( $args{lock} == 3 ) {
      ***            50                               
457            1                                  3               my $sql = 'FLUSH TABLES WITH READ LOCK';
458            1                                  3               MKDEBUG && _d($dst->{dbh}, ',', $sql);
459            1                                217               $dst->{dbh}->do($sql);
460                                                            }
461                                                            elsif ( !$args{transaction} ) {
462   ***      2     50                          15               $self->lock_table($dst->{dbh}, 'dest',
463                                                                  $self->{Quoter}->quote($dst->{db}, $dst->{tbl}),
464                                                                  $args{execute} ? 'WRITE' : 'READ');
465                                                            }
466                                                         }
467                                                      };
468                                                   
469   ***      3     50                          16      if ( $EVAL_ERROR ) {
470                                                         # Must abort/unlock/commit so that we don't interfere with any further
471                                                         # tables we try to do.
472   ***      0      0                           0         if ( $args{src_sth}->{Active} ) {
473   ***      0                                  0            $args{src_sth}->finish();
474                                                         }
475   ***      0                                  0         foreach my $dbh ( @args{qw(src_dbh dst_dbh misc_dbh)} ) {
476   ***      0      0                           0            next unless $dbh;
477   ***      0                                  0            MKDEBUG && _d('Caught error, unlocking/committing on', $dbh);
478   ***      0                                  0            $dbh->do('UNLOCK TABLES');
479   ***      0      0                           0            $dbh->commit() unless $dbh->{AutoCommit};
480                                                         }
481                                                         # ... and then re-throw the error.
482   ***      0                                  0         die $EVAL_ERROR;
483                                                      }
484                                                   
485            3                                 23      return $result;
486                                                   }
487                                                   
488                                                   # This query will check all needed privileges on the table without actually
489                                                   # changing anything in it.  We can't use REPLACE..SELECT because that doesn't
490                                                   # work inside of LOCK TABLES.  Returns 1 if user has all needed privs to
491                                                   # sync table, else returns 0.
492                                                   sub have_all_privs {
493            5                    5            98      my ( $self, $dbh, $db, $tbl ) = @_;
494            5                                 72      my $db_tbl = $self->{Quoter}->quote($db, $tbl);
495            5                                 44      my $sql    = "SHOW FULL COLUMNS FROM $db_tbl";
496            5                                 20      MKDEBUG && _d('Permissions check:', $sql);
497            5                                 93      my $cols       = $dbh->selectall_arrayref($sql, {Slice => {}});
498            5                                 45      my ($hdr_name) = grep { m/privileges/i } keys %{$cols->[0]};
              45                                179   
               5                                 41   
499            5                                 29      my $privs      = $cols->[0]->{$hdr_name};
500            5                                 25      $sql = "DELETE FROM $db_tbl LIMIT 0"; # FULL COLUMNS doesn't show all privs
501            5                                 20      MKDEBUG && _d('Permissions check:', $sql);
502            5                                 21      eval { $dbh->do($sql); };
               5                                251   
503            5    100                          40      my $can_delete = $EVAL_ERROR ? 0 : 1;
504                                                   
505            5                                 10      MKDEBUG && _d('User privs on', $db_tbl, ':', $privs,
506                                                         ($can_delete ? 'delete' : ''));
507   ***      5    100     66                  135      if ( $privs =~ m/select/ && $privs =~ m/insert/ && $privs =~ m/update/ 
                           100                        
                           100                        
508                                                           && $can_delete ) {
509            2                                  4         MKDEBUG && _d('User has all privs');
510            2                                 34         return 1;
511                                                      }
512            3                                 10      MKDEBUG && _d('User does not have all privs');
513            3                                 59      return 0;
514                                                   }
515                                                   
516                                                   sub _d {
517   ***      0                    0                    my ($package, undef, $line) = caller 0;
518   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
519   ***      0                                              map { defined $_ ? $_ : 'undef' }
520                                                           @_;
521   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
522                                                   }
523                                                   
524                                                   1;
525                                                   
526                                                   # ###########################################################################
527                                                   # End TableSyncer package
528                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
42           100      4     10   unless defined $args{$arg}
56    ***     50      0     32   unless $args{$arg}
62           100     16      3   if ($can_sync)
99    ***     50      0    104   unless $args{$arg}
105   ***     50     13      0   unless defined $args{'index_hint'}
119   ***     50      0     13   unless $plugin
131   ***     50     13      0   $vp->version_ge($$src{'dbh'}, '4.0.9') && $vp->version_ge($$dst{'dbh'}, '4.0.9') ? :
134   ***     50      0     13   if ($args{'chunk_index'}) { }
             100      9      4   elsif ($plugin_args{'chunk_index'} and $args{'index_hint'}) { }
155   ***     50      0     13   if ($EVAL_ERROR)
164          100      9      4   if ($plugin->uses_checksum)
169   ***     50      0      9   if ($EVAL_ERROR)
179          100      1     12   if ($args{'dry_run'})
192   ***     50      0     12   if ($EVAL_ERROR)
216   ***     50      0     29   if ($args{'transaction'})
218   ***      0      0      0   if ($args{'change_dbh'} and $args{'change_dbh'} eq $$src{'dbh'}) { }
      ***      0      0      0   elsif ($args{'change_dbh'}) { }
245          100     22      7   if (not $cycle or not $plugin->pending_changes)
252   ***     50     29      0   unless $executed_src
278   ***     50      0     27   unless $args{$arg}
299   ***     50      0      9   if ($src_algo ne $dst_algo)
307   ***     50      0      9   if ($src_func ne $dst_func)
319   ***     50      9      0   if ($src_algo eq 'BIT_XOR' and not $crc_type =~ /int$/)
357   ***     50      0     96   unless defined $args{$arg}
362          100     10      2   unless $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
366   ***     50      0      4   if ($args{'transaction'}) { }
395   ***     50      0    280   unless defined $args{$arg}
400          100     32      3   unless $args{'lock'} and $args{'lock'} == $args{'lock_level'}
404   ***     50      0      6   if ($args{'transaction'}) { }
417          100      1      2   if ($args{'lock'} == 3) { }
424   ***     50      0      2   if ($args{'transaction'}) { }
425   ***      0      0      0   if ($args{'src_sth'})
434   ***     50      0      2   $args{'replicate'} ? :
442          100      1      2   if ($args{'wait'})
451   ***     50      0      3   if ($args{'replicate'}) { }
456          100      1      2   if ($args{'lock'} == 3) { }
      ***     50      2      0   elsif (not $args{'transaction'}) { }
462   ***     50      0      2   $args{'execute'} ? :
469   ***     50      0      3   if ($EVAL_ERROR)
472   ***      0      0      0   if ($args{'src_sth'}{'Active'})
476   ***      0      0      0   unless $dbh
479   ***      0      0      0   unless $$dbh{'AutoCommit'}
503          100      3      2   $EVAL_ERROR ? :
507          100      2      3   if ($privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/ and $can_delete)
518   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
131   ***     33      0      0     13   $vp->version_ge($$src{'dbh'}, '4.0.9') && $vp->version_ge($$dst{'dbh'}, '4.0.9')
134   ***     66      4      0      9   $plugin_args{'chunk_index'} and $args{'index_hint'}
218   ***      0      0      0      0   $args{'change_dbh'} and $args{'change_dbh'} eq $$src{'dbh'}
319   ***     33      0      0      9   $src_algo eq 'BIT_XOR' and not $crc_type =~ /int$/
362          100      9      1      2   $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
400          100     28      4      3   $args{'lock'} and $args{'lock'} == $args{'lock_level'}
507   ***     66      0      1      4   $privs =~ /select/ and $privs =~ /insert/
             100      1      1      3   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
             100      2      1      2   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/ and $can_delete

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
106   ***     50      0     13   $args{'replicate'} ||= 0
107          100      3     10   $args{'lock'} ||= 0
108   ***     50      0     13   $args{'wait'} ||= 0
109   ***     50      0     13   $args{'transaction'} ||= 0
110   ***     50      0     13   $args{'timeout_ok'} ||= 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
245          100     12     10      7   not $cycle or not $plugin->pending_changes


Covered Subroutines
-------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
BEGIN                     1 /home/daniel/dev/maatkit/common/TableSyncer.pm:22 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableSyncer.pm:23 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableSyncer.pm:25 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableSyncer.pm:26 
BEGIN                     1 /home/daniel/dev/maatkit/common/TableSyncer.pm:31 
get_best_plugin          16 /home/daniel/dev/maatkit/common/TableSyncer.pm:54 
have_all_privs            5 /home/daniel/dev/maatkit/common/TableSyncer.pm:493
lock_and_wait            35 /home/daniel/dev/maatkit/common/TableSyncer.pm:390
lock_table                4 /home/daniel/dev/maatkit/common/TableSyncer.pm:343
make_checksum_queries     9 /home/daniel/dev/maatkit/common/TableSyncer.pm:275
new                       5 /home/daniel/dev/maatkit/common/TableSyncer.pm:39 
sync_table               13 /home/daniel/dev/maatkit/common/TableSyncer.pm:95 
unlock                   12 /home/daniel/dev/maatkit/common/TableSyncer.pm:353

Uncovered Subroutines
---------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
_d                        0 /home/daniel/dev/maatkit/common/TableSyncer.pm:517


