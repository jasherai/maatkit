---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableSyncer.pm   75.8   53.4   51.4   85.7    n/a  100.0   68.2
Total                          75.8   53.4   51.4   85.7    n/a  100.0   68.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Sep 25 18:32:51 2009
Finish:       Fri Sep 25 18:33:00 2009

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
18                                                    # TableSyncer package $Revision: 4751 $
19                                                    # ###########################################################################
20                                                    package TableSyncer;
21                                                    
22             1                    1            10   use strict;
               1                                  3   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  4   
               1                                  7   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
26             1                    1            11   use Data::Dumper;
               1                                  4   
               1                                 12   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 12   
32                                                    
33                                                    # Arguments:
34                                                    #   * MasterSlave    A MasterSlave module
35                                                    #   * Quoter         A Quoter module
36                                                    #   * VersionParser  A VersionParser module
37                                                    #   * TableChecksum  A TableChecksum module
38                                                    sub new {
39             5                    5           197      my ( $class, %args ) = @_;
40             5                                 27      my @required_args = qw(MasterSlave Quoter VersionParser TableChecksum);
41             5                                 20      foreach my $arg ( @required_args ) {
42            14    100                          56         die "I need a $arg argument" unless defined $args{$arg};
43                                                       }
44             1                                  6      my $self = { %args };
45             1                                 25      return bless $self, $class;
46                                                    }
47                                                    
48                                                    # Return the first plugin from the arrayref of TableSync* plugins
49                                                    # that can sync the given table struct.  plugin->can_sync() usually
50                                                    # returns a hashref that it wants back when plugin->prepare_to_sync()
51                                                    # is called.  Or, it may return nothing (false) to say that it can't
52                                                    # sync the table.
53                                                    sub get_best_plugin {
54            16                   16           204      my ( $self, %args ) = @_;
55            16                                 92      foreach my $arg ( qw(plugins tbl_struct) ) {
56    ***     32     50                         174         die "I need a $arg argument" unless $args{$arg};
57                                                       }
58            16                                 43      MKDEBUG && _d('Getting best plugin');
59            16                                 62      foreach my $plugin ( @{$args{plugins}} ) {
              16                                 67   
60            19                                 50         MKDEBUG && _d('Trying plugin', $plugin->name());
61            19                                176         my ($can_sync, %plugin_args) = $plugin->can_sync(%args);
62            19    100                         101         if ( $can_sync ) {
63            16                                 40           MKDEBUG && _d('Can sync with', $plugin->name(), Dumper(\%plugin_args));
64            16                                143           return $plugin, %plugin_args;
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
95            13                   13           303      my ( $self, %args ) = @_;
96            13                                103      my @required_args = qw(plugins src dst tbl_struct cols chunk_size
97                                                                              RowDiff ChangeHandler);
98            13                                 60      foreach my $arg ( @required_args ) {
99    ***    104     50                         448         die "I need a $arg argument" unless $args{$arg};
100                                                      }
101           13                                 37      MKDEBUG && _d('Syncing table with args', Dumper(\%args));
102           13                                102      my ($plugins, $src, $dst, $tbl_struct, $cols, $chunk_size, $rd, $ch)
103                                                         = @args{@required_args};
104                                                   
105   ***     13     50                          72      $args{index_hint}    = 1 unless defined $args{index_hint};
106   ***     13            50                   72      $args{replicate}   ||= 0;
107           13           100                   89      $args{lock}        ||= 0;
108   ***     13            50                   75      $args{wait}        ||= 0;
109   ***     13            50                   67      $args{transaction} ||= 0;
110   ***     13            50                   72      $args{timeout_ok}  ||= 0;
111                                                   
112           13                                 51      my $q  = $self->{Quoter};
113           13                                 51      my $vp = $self->{VersionParser};
114                                                   
115                                                      # ########################################################################
116                                                      # Get and prepare the first plugin that can sync this table.
117                                                      # ########################################################################
118           13                                127      my ($plugin, %plugin_args) = $self->get_best_plugin(%args);
119   ***     13     50                          84      die "No plugin can sync $src->{db}.$src->{tbl}" unless $plugin;
120                                                   
121                                                      # The row-level (state 2) checksums use __crc, so the table can't use that.
122           13                                 44      my $crc_col = '__crc';
123           13                                 86      while ( $tbl_struct->{is_col}->{$crc_col} ) {
124   ***      0                                  0         $crc_col = "_$crc_col"; # Prepend more _ until not a column.
125                                                      }
126           13                                 34      MKDEBUG && _d('CRC column:', $crc_col);
127                                                   
128                                                      # Make an index hint for either the explicitly given chunk_index
129                                                      # or the chunk_index chosen by the plugin if index_hint is true.
130           13                                 36      my $index_hint;
131   ***     13     50     33                  104      my $hint = ($vp->version_ge($src->{dbh}, '4.0.9')
132                                                                  && $vp->version_ge($dst->{dbh}, '4.0.9') ? 'FORCE' : 'USE')
133                                                               . ' INDEX';
134   ***     13     50     66                  140      if ( $args{chunk_index} ) {
                    100                               
135   ***      0                                  0         MKDEBUG && _d('Using given chunk index for index hint');
136   ***      0                                  0         $index_hint = "$hint (" . $q->quote($args{chunk_index}) . ")";
137                                                      }
138                                                      elsif ( $plugin_args{chunk_index} && $args{index_hint} ) {
139            9                                 25         MKDEBUG && _d('Using chunk index chosen by plugin for index hint');
140            9                                 59         $index_hint = "$hint (" . $q->quote($plugin_args{chunk_index}) . ")";
141                                                      }
142           13                                 41      MKDEBUG && _d('Index hint:', $index_hint);
143                                                   
144           13                                 45      eval {
145           13                                183         $plugin->prepare_to_sync(
146                                                            %args,
147                                                            %plugin_args,
148                                                            dbh         => $src->{dbh},
149                                                            db          => $src->{db},
150                                                            tbl         => $src->{tbl},
151                                                            crc_col     => $crc_col,
152                                                            index_hint  => $index_hint,
153                                                         );
154                                                      };
155   ***     13     50                          86      if ( $EVAL_ERROR ) {
156                                                         # At present, no plugin should fail to prepare, but just in case...
157   ***      0                                  0         die 'Failed to prepare TableSync', $plugin->name(), ' plugin: ',
158                                                            $EVAL_ERROR;
159                                                      }
160                                                   
161                                                      # Some plugins like TableSyncChunk use checksum queries, others like
162                                                      # TableSyncGroupBy do not.  For those that do, make chunk (state 0)
163                                                      # and row (state 2) checksum queries.
164           13    100                          86      if ( $plugin->uses_checksum() ) {
165            9                                 35         eval {
166            9                                 90            my ($chunk_sql, $row_sql) = $self->make_checksum_queries(%args);
167            9                                 82            $plugin->set_checksum_queries($chunk_sql, $row_sql);
168                                                         };
169   ***      9     50                          43         if ( $EVAL_ERROR ) {
170                                                            # This happens if src and dst are really different and the same
171                                                            # checksum algo and hash func can't be used on both.
172   ***      0                                  0            die "Failed to make checksum queries: $EVAL_ERROR";
173                                                         }
174                                                      } 
175                                                   
176                                                      # ########################################################################
177                                                      # Plugin is ready, return now if this is a dry run.
178                                                      # ########################################################################
179           13    100                          73      if ( $args{dry_run} ) {
180            1                                  8         return $ch->get_changes(), ALGORITHM => $plugin->name();
181                                                      }
182                                                   
183                                                      # ########################################################################
184                                                      # Start syncing the table.
185                                                      # ########################################################################
186                                                   
187                                                      # USE db on src and dst for cases like when replicate-do-db is being used.
188           12                                 48      eval {
189           12                               1717         $src->{dbh}->do("USE `$src->{db}`");
190           12                               1508         $dst->{dbh}->do("USE `$dst->{db}`");
191                                                      };
192   ***     12     50                          66      if ( $EVAL_ERROR ) {
193                                                         # This shouldn't happen, but just in case.  (The db and tbl on src
194                                                         # and dst should be checked before calling this sub.)
195   ***      0                                  0         die "Failed to USE database on source or destination: $EVAL_ERROR";
196                                                      }
197                                                   
198           12                                144      $self->lock_and_wait(%args, lock_level => 2);  # per-table lock
199                                                   
200           12                                 44      my $cycle = 0;
201           12                                114      while ( !$plugin->done() ) {
202                                                   
203                                                         # Do as much of the work as possible before opening a transaction or
204                                                         # locking the tables.
205           29                                 78         MKDEBUG && _d('Beginning sync cycle', $cycle);
206           29                                330         my $src_sql = $plugin->get_sql(
207                                                            database   => $src->{db},
208                                                            table      => $src->{tbl},
209                                                            where      => $args{where},
210                                                         );
211           29                                291         my $dst_sql = $plugin->get_sql(
212                                                            database   => $dst->{db},
213                                                            table      => $dst->{tbl},
214                                                            where      => $args{where},
215                                                         );
216   ***     29     50                         168         if ( $args{transaction} ) {
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
234           29                                153         $plugin->prepare_sync_cycle($src);
235           29                                143         $plugin->prepare_sync_cycle($dst);
236           29                                 71         MKDEBUG && _d('src:', $src_sql);
237           29                                 68         MKDEBUG && _d('dst:', $dst_sql);
238           29                                 77         my $src_sth = $src->{dbh}->prepare($src_sql);
239           29                                 63         my $dst_sth = $dst->{dbh}->prepare($dst_sql);
240                                                   
241                                                         # The first cycle should lock to begin work; after that, unlock only if
242                                                         # the plugin says it's OK (it may want to dig deeper on the rows it
243                                                         # currently has locked).
244           29                                154         my $executed_src = 0;
245           29    100    100                  233         if ( !$cycle || !$plugin->pending_changes() ) {
246                                                            # per-sync cycle lock
247           22                                257            $executed_src
248                                                               = $self->lock_and_wait(%args, src_sth => $src_sth, lock_level => 1);
249                                                         }
250                                                   
251                                                         # The source sth might have already been executed by lock_and_wait().
252   ***     29     50                       10536         $src_sth->execute() unless $executed_src;
253           29                              10340         $dst_sth->execute();
254                                                   
255           29                                332         $rd->compare_sets(
256                                                            left   => $src_sth,
257                                                            right  => $dst_sth,
258                                                            syncer => $plugin,
259                                                            tbl    => $tbl_struct,
260                                                         );
261           29                                 72         MKDEBUG && _d('Finished sync cycle', $cycle);
262           29                                189         $ch->process_rows(1);
263                                                   
264           29                               1151         $cycle++;
265                                                      }
266                                                   
267           12                                 77      $ch->process_rows();
268                                                   
269           12                                163      $self->unlock(%args, lock_level => 2);
270                                                   
271           12                                 85      return $ch->get_changes(), ALGORITHM => $plugin->name();
272                                                   }
273                                                   
274                                                   sub make_checksum_queries {
275            9                    9            95      my ( $self, %args ) = @_;
276            9                                 63      my @required_args = qw(src dst tbl_struct);
277            9                                 42      foreach my $arg ( @required_args ) {
278   ***     27     50                         133         die "I need a $arg argument" unless $args{$arg};
279                                                      }
280            9                                 43      my ($src, $dst, $tbl_struct) = @args{@required_args};
281            9                                 38      my $checksum = $self->{TableChecksum};
282                                                   
283                                                      # Decide on checksumming strategy and store checksum query prototypes for
284                                                      # later.
285            9                                 77      my $src_algo = $checksum->best_algorithm(
286                                                         algorithm => 'BIT_XOR',
287                                                         dbh       => $src->{dbh},
288                                                         where     => 1,
289                                                         chunk     => 1,
290                                                         count     => 1,
291                                                      );
292            9                                 58      my $dst_algo = $checksum->best_algorithm(
293                                                         algorithm => 'BIT_XOR',
294                                                         dbh       => $dst->{dbh},
295                                                         where     => 1,
296                                                         chunk     => 1,
297                                                         count     => 1,
298                                                      );
299   ***      9     50                          44      if ( $src_algo ne $dst_algo ) {
300   ***      0                                  0         die "Source and destination checksum algorithms are different: ",
301                                                            "$src_algo on source, $dst_algo on destination"
302                                                      }
303            9                                 20      MKDEBUG && _d('Chosen algo:', $src_algo);
304                                                   
305            9                                 89      my $src_func = $checksum->choose_hash_func(dbh => $src->{dbh}, %args);
306            9                                 91      my $dst_func = $checksum->choose_hash_func(dbh => $dst->{dbh}, %args);
307   ***      9     50                          52      if ( $src_func ne $dst_func ) {
308   ***      0                                  0         die "Source and destination hash functions are different: ",
309                                                         "$src_func on source, $dst_func on destination";
310                                                      }
311            9                                 22      MKDEBUG && _d('Chosen hash func:', $src_func);
312                                                   
313                                                      # Since the checksum algo and hash func are the same on src and dst
314                                                      # it doesn't matter if we use src_algo/func or dst_algo/func.
315                                                   
316            9                                 69      my $crc_wid    = $checksum->get_crc_wid($src->{dbh}, $src_func);
317            9                                 65      my ($crc_type) = $checksum->get_crc_type($src->{dbh}, $src_func);
318            9                                 33      my $opt_slice;
319   ***      9     50     33                  115      if ( $src_algo eq 'BIT_XOR' && $crc_type !~ m/int$/ ) {
320            9                                 81         $opt_slice = $checksum->optimize_xor($src->{dbh}, $src_func);
321                                                      }
322                                                   
323            9                                172      my $chunk_sql = $checksum->make_checksum_query(
324                                                         db        => $src->{db},
325                                                         tbl       => $src->{tbl},
326                                                         algorithm => $src_algo,
327                                                         function  => $src_func,
328                                                         crc_wid   => $crc_wid,
329                                                         crc_type  => $crc_type,
330                                                         opt_slice => $opt_slice,
331                                                         %args,
332                                                      );
333            9                                 32      MKDEBUG && _d('Chunk sql:', $chunk_sql);
334            9                                 60      my $row_sql = $checksum->make_row_checksum(
335                                                         %args,
336                                                         function => $src_func,
337                                                      );
338            9                                 28      MKDEBUG && _d('Row sql:', $row_sql);
339            9                                 95      return $chunk_sql, $row_sql;
340                                                   }
341                                                   
342                                                   # This query will check all needed privileges on the table without actually
343                                                   # changing anything in it.  We can't use REPLACE..SELECT because that doesn't
344                                                   # work inside of LOCK TABLES.
345                                                   sub check_permissions {
346   ***      0                    0             0      my ( $self, $dbh, $db, $tbl, $quoter ) = @_;
347   ***      0                                  0      my $db_tbl = $quoter->quote($db, $tbl);
348   ***      0                                  0      my $sql = "SHOW FULL COLUMNS FROM $db_tbl";
349   ***      0                                  0      MKDEBUG && _d('Permissions check:', $sql);
350   ***      0                                  0      my $cols = $dbh->selectall_arrayref($sql, {Slice => {}});
351   ***      0                                  0      my ($hdr_name) = grep { m/privileges/i } keys %{$cols->[0]};
      ***      0                                  0   
      ***      0                                  0   
352   ***      0                                  0      my $privs = $cols->[0]->{$hdr_name};
353   ***      0      0      0                    0      die "$privs does not include all needed privileges for $db_tbl"
      ***                    0                        
354                                                         unless $privs =~ m/select/ && $privs =~ m/insert/ && $privs =~ m/update/;
355   ***      0                                  0      $sql = "DELETE FROM $db_tbl LIMIT 0"; # FULL COLUMNS doesn't show all privs
356   ***      0                                  0      MKDEBUG && _d('Permissions check:', $sql);
357   ***      0                                  0      $dbh->do($sql);
358                                                   }
359                                                   
360                                                   sub lock_table {
361            4                    4            23      my ( $self, $dbh, $where, $db_tbl, $mode ) = @_;
362            4                                 18      my $query = "LOCK TABLES $db_tbl $mode";
363            4                                 10      MKDEBUG && _d($query);
364            4                                448      $dbh->do($query);
365            4                                 25      MKDEBUG && _d('Acquired table lock on', $where, 'in', $mode, 'mode');
366                                                   }
367                                                   
368                                                   # Doesn't work quite the same way as lock_and_wait. It will unlock any LOWER
369                                                   # priority lock level, not just the exact same one.
370                                                   sub unlock {
371           12                   12           169      my ( $self, %args ) = @_;
372                                                   
373           12                                 89      foreach my $arg ( qw(src dst lock replicate timeout_ok transaction wait
374                                                                           lock_level) ) {
375   ***     96     50                         414         die "I need a $arg argument" unless defined $args{$arg};
376                                                      }
377           12                                 51      my $src = $args{src};
378           12                                 43      my $dst = $args{dst};
379                                                   
380           12    100    100                  111      return unless $args{lock} && $args{lock} <= $args{lock_level};
381                                                   
382                                                      # First, unlock/commit.
383            2                                 12      foreach my $dbh ( $src->{dbh}, $dst->{dbh} ) {
384   ***      4     50                          19         if ( $args{transaction} ) {
385   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
386   ***      0                                  0            $dbh->commit();
387                                                         }
388                                                         else {
389            4                                 14            my $sql = 'UNLOCK TABLES';
390            4                                  9            MKDEBUG && _d($dbh, $sql);
391            4                                426            $dbh->do($sql);
392                                                         }
393                                                      }
394                                                   
395            2                                 14      return;
396                                                   }
397                                                   
398                                                   # Lock levels:
399                                                   #   0 => none
400                                                   #   1 => per sync cycle
401                                                   #   2 => per table
402                                                   #   3 => global
403                                                   # This function might actually execute the $src_sth.  If we're using
404                                                   # transactions instead of table locks, the $src_sth has to be executed before
405                                                   # the MASTER_POS_WAIT() on the slave.  The return value is whether the
406                                                   # $src_sth was executed.
407                                                   sub lock_and_wait {
408           35                   35           489      my ( $self, %args ) = @_;
409           35                                187      my $result = 0;
410                                                   
411           35                                196      foreach my $arg ( qw(src dst lock replicate timeout_ok transaction wait
412                                                                           lock_level) ) {
413   ***    280     50                        1277         die "I need a $arg argument" unless defined $args{$arg};
414                                                      }
415           35                                120      my $src = $args{src};
416           35                                112      my $dst = $args{dst};
417                                                   
418           35    100    100                  340      return unless $args{lock} && $args{lock} == $args{lock_level};
419                                                   
420                                                      # First, commit/unlock the previous transaction/lock.
421            3                                 19      foreach my $dbh ( $src->{dbh}, $dst->{dbh} ) {
422   ***      6     50                          25         if ( $args{transaction} ) {
423   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
424   ***      0                                  0            $dbh->commit();
425                                                         }
426                                                         else {
427            6                                 19            my $sql = 'UNLOCK TABLES';
428            6                                 15            MKDEBUG && _d($dbh, $sql);
429            6                                606            $dbh->do($sql);
430                                                         }
431                                                      }
432                                                   
433                                                      # User wants us to lock for consistency.  But lock only on source initially;
434                                                      # might have to wait for the slave to catch up before locking on the dest.
435            3    100                          19      if ( $args{lock} == 3 ) {
436            1                                  5         my $sql = 'FLUSH TABLES WITH READ LOCK';
437            1                                  2         MKDEBUG && _d($src->{dbh}, ',', $sql);
438            1                                205         $src->{dbh}->do($sql);
439                                                      }
440                                                      else {
441                                                         # Lock level 2 (per-table) or 1 (per-sync cycle)
442   ***      2     50                          10         if ( $args{transaction} ) {
443   ***      0      0                           0            if ( $args{src_sth} ) {
444                                                               # Execute the $src_sth on the source, so LOCK IN SHARE MODE/FOR
445                                                               # UPDATE will lock the rows examined.
446   ***      0                                  0               MKDEBUG && _d('Executing statement on source to lock rows');
447   ***      0                                  0               $args{src_sth}->execute();
448   ***      0                                  0               $result = 1;
449                                                            }
450                                                         }
451                                                         else {
452   ***      2     50                          19            $self->lock_table($src->{dbh}, 'source',
453                                                               $self->{Quoter}->quote($src->{db}, $src->{tbl}),
454                                                               $args{replicate} ? 'WRITE' : 'READ');
455                                                         }
456                                                      }
457                                                   
458                                                      # If there is any error beyond this point, we need to unlock/commit.
459            3                                 14      eval {
460            3    100                          17         if ( $args{wait} ) {
461                                                            # Always use the misc_dbh dbh to check the master's position, because
462                                                            # the main dbh might be in use due to executing $src_sth.
463            1                                 22            $self->{MasterSlave}->wait_for_master(
464                                                               $src->{misc_dbh}, $dst->{dbh}, $args{wait}, $args{timeout_ok});
465                                                         }
466                                                   
467                                                         # Don't lock on destination if it's a replication slave, or the
468                                                         # replication thread will not be able to make changes.
469   ***      3     50                          19         if ( $args{replicate} ) {
470   ***      0                                  0            MKDEBUG
471                                                               && _d('Not locking destination because syncing via replication');
472                                                         }
473                                                         else {
474            3    100                          21            if ( $args{lock} == 3 ) {
      ***            50                               
475            1                                  4               my $sql = 'FLUSH TABLES WITH READ LOCK';
476            1                                 10               MKDEBUG && _d($dst->{dbh}, ',', $sql);
477            1                                191               $dst->{dbh}->do($sql);
478                                                            }
479                                                            elsif ( !$args{transaction} ) {
480   ***      2     50                          19               $self->lock_table($dst->{dbh}, 'dest',
481                                                                  $self->{Quoter}->quote($dst->{db}, $dst->{tbl}),
482                                                                  $args{execute} ? 'WRITE' : 'READ');
483                                                            }
484                                                         }
485                                                      };
486                                                   
487   ***      3     50                          18      if ( $EVAL_ERROR ) {
488                                                         # Must abort/unlock/commit so that we don't interfere with any further
489                                                         # tables we try to do.
490   ***      0      0                           0         if ( $args{src_sth}->{Active} ) {
491   ***      0                                  0            $args{src_sth}->finish();
492                                                         }
493   ***      0                                  0         foreach my $dbh ( @args{qw(src_dbh dst_dbh misc_dbh)} ) {
494   ***      0      0                           0            next unless $dbh;
495   ***      0                                  0            MKDEBUG && _d('Caught error, unlocking/committing on', $dbh);
496   ***      0                                  0            $dbh->do('UNLOCK TABLES');
497   ***      0      0                           0            $dbh->commit() unless $dbh->{AutoCommit};
498                                                         }
499                                                         # ... and then re-throw the error.
500   ***      0                                  0         die $EVAL_ERROR;
501                                                      }
502                                                   
503            3                                 25      return $result;
504                                                   }
505                                                   
506                                                   sub _d {
507   ***      0                    0                    my ($package, undef, $line) = caller 0;
508   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
509   ***      0                                              map { defined $_ ? $_ : 'undef' }
510                                                           @_;
511   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
512                                                   }
513                                                   
514                                                   1;
515                                                   
516                                                   # ###########################################################################
517                                                   # End TableSyncer package
518                                                   # ###########################################################################


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
353   ***      0      0      0   unless $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
375   ***     50      0     96   unless defined $args{$arg}
380          100     10      2   unless $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
384   ***     50      0      4   if ($args{'transaction'}) { }
413   ***     50      0    280   unless defined $args{$arg}
418          100     32      3   unless $args{'lock'} and $args{'lock'} == $args{'lock_level'}
422   ***     50      0      6   if ($args{'transaction'}) { }
435          100      1      2   if ($args{'lock'} == 3) { }
442   ***     50      0      2   if ($args{'transaction'}) { }
443   ***      0      0      0   if ($args{'src_sth'})
452   ***     50      0      2   $args{'replicate'} ? :
460          100      1      2   if ($args{'wait'})
469   ***     50      0      3   if ($args{'replicate'}) { }
474          100      1      2   if ($args{'lock'} == 3) { }
      ***     50      2      0   elsif (not $args{'transaction'}) { }
480   ***     50      0      2   $args{'execute'} ? :
487   ***     50      0      3   if ($EVAL_ERROR)
490   ***      0      0      0   if ($args{'src_sth'}{'Active'})
494   ***      0      0      0   unless $dbh
497   ***      0      0      0   unless $$dbh{'AutoCommit'}
508   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
131   ***     33      0      0     13   $vp->version_ge($$src{'dbh'}, '4.0.9') && $vp->version_ge($$dst{'dbh'}, '4.0.9')
134   ***     66      4      0      9   $plugin_args{'chunk_index'} and $args{'index_hint'}
218   ***      0      0      0      0   $args{'change_dbh'} and $args{'change_dbh'} eq $$src{'dbh'}
319   ***     33      0      0      9   $src_algo eq 'BIT_XOR' and not $crc_type =~ /int$/
353   ***      0      0      0      0   $privs =~ /select/ and $privs =~ /insert/
      ***      0      0      0      0   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
380          100      9      1      2   $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
418          100     28      4      3   $args{'lock'} and $args{'lock'} == $args{'lock_level'}

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
lock_and_wait            35 /home/daniel/dev/maatkit/common/TableSyncer.pm:408
lock_table                4 /home/daniel/dev/maatkit/common/TableSyncer.pm:361
make_checksum_queries     9 /home/daniel/dev/maatkit/common/TableSyncer.pm:275
new                       5 /home/daniel/dev/maatkit/common/TableSyncer.pm:39 
sync_table               13 /home/daniel/dev/maatkit/common/TableSyncer.pm:95 
unlock                   12 /home/daniel/dev/maatkit/common/TableSyncer.pm:371

Uncovered Subroutines
---------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
_d                        0 /home/daniel/dev/maatkit/common/TableSyncer.pm:507
check_permissions         0 /home/daniel/dev/maatkit/common/TableSyncer.pm:346


