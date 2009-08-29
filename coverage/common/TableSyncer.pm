---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableSyncer.pm   78.8   48.8   48.7   85.7    n/a  100.0   67.6
Total                          78.8   48.8   48.7   85.7    n/a  100.0   67.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:04:06 2009
Finish:       Sat Aug 29 15:04:20 2009

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
18                                                    # TableSyncer package $Revision: 4590 $
19                                                    # ###########################################################################
20                                                    package TableSyncer;
21                                                    
22             1                    1            11   use strict;
               1                                  2   
               1                                  8   
23             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24                                                    
25             1                    1             7   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
28                                                    
29                                                    our %ALGOS = map { lc $_ => $_ } qw(Stream Chunk Nibble GroupBy);
30                                                    
31                                                    sub new {
32             1                    1        522703      bless {}, shift;
33                                                    }
34                                                    
35                                                    # Choose the best algorithm for syncing a given table.
36                                                    sub best_algorithm {
37             3                    3            39      my ( $self, %args ) = @_;
38             3                                 16      foreach my $arg ( qw(tbl_struct parser nibbler chunker) ) {
39    ***     12     50                          52         die "I need a $arg argument" unless $args{$arg};
40                                                       }
41             3                                 13      my $result;
42                                                    
43                                                       # See if Chunker says it can handle the table
44             3                                 29      my ($exact, $cols) = $args{chunker}
45                                                          ->find_chunk_columns($args{tbl_struct}, { exact => 1 });
46    ***      3     50                          13      if ( $exact ) {
47    ***      0                                  0         MKDEBUG && _d('Chunker says', $cols->[0], 'supports chunking exactly');
48    ***      0                                  0         $result = 'Chunk';
49                                                          # If Chunker can handle it OK, but not with exact chunk sizes, it means
50                                                          # it's using only the first column of a multi-column index, which could
51                                                          # be really bad.  It's better to use Nibble for these, because at least
52                                                          # it can reliably select a chunk of rows of the desired size.
53                                                       }
54                                                       else {
55                                                          # If there's an index, $nibbler->generate_asc_stmt() will use it, so it
56                                                          # is an indication that the nibble algorithm will work.
57             3                                 21         my ($idx) = $args{parser}->find_best_index($args{tbl_struct});
58             3    100                          11         if ( $idx ) {
59             2                                  5            MKDEBUG && _d('Parser found best index', $idx, 'so Nibbler will work');
60             2                                  9            $result = 'Nibble';
61                                                          }
62                                                          else {
63                                                             # If not, GroupBy is the only choice.  We don't automatically choose
64                                                             # Stream, it must be specified by the user.
65             1                                  3            MKDEBUG && _d('No primary or unique non-null key in table');
66             1                                  5            $result = 'GroupBy';
67                                                          }
68                                                       }
69             3                                  6      MKDEBUG && _d('Algorithm:', $result);
70             3                                 18      return $result;
71                                                    }
72                                                    
73                                                    sub sync_table {
74            14                   14        5784427      my ( $self, %args ) = @_;
75            14                                198      foreach my $arg ( qw(
76                                                          buffer checksum chunker chunksize dst_db dst_dbh dst_tbl execute lock
77                                                          misc_dbh quoter replace replicate src_db src_dbh src_tbl test tbl_struct
78                                                          timeoutok transaction versionparser wait where possible_keys cols
79                                                          nibbler parser master_slave func dumper trim skipslavecheck bufferinmysql) )
80                                                       {
81    ***    462     50                        1902         die "I need a $arg argument" unless defined $args{$arg};
82                                                       }
83                                                       MKDEBUG && _d('Syncing table with args',
84                                                          join(', ',
85            14                                 52            map { "$_=" . (defined $args{$_} ? $args{$_} : 'undef') }
86                                                             sort keys %args));
87                                                    
88    ***     14            50                  170      my $sleep = $args{sleep} || 0;
89                                                    
90            13                                 59      my $can_replace
91            14                                 46         = grep { $_->{is_unique} } values %{$args{tbl_struct}->{keys}};
              14                                112   
92            14                                 42      MKDEBUG && _d('This table\'s replace-ability:', $can_replace);
93    ***     14            33                  129      my $use_replace = $args{replace} || $args{replicate};
94                                                    
95                                                       # TODO: for two-way sync, the change handler needs both DBHs.
96                                                       # Check permissions on writable tables (TODO: 2-way needs to check both)
97            14                                 32      my $update_func;
98            14                                 58      my $change_dbh;
99    ***     14     50                          59      if ( $args{execute} ) {
100   ***     14     50                          72         if ( $args{replicate} ) {
101   ***      0                                  0            $change_dbh = $args{src_dbh};
102   ***      0                                  0            $self->check_permissions(@args{qw(src_dbh src_db src_tbl quoter)});
103                                                            # Is it possible to make changes on the master?  Only if REPLACE will
104                                                            # work OK.
105   ***      0      0                           0            if ( !$can_replace ) {
106   ***      0                                  0               die "Can't make changes on the master: no unique index exists";
107                                                            }
108                                                         }
109                                                         else {
110           14                                 54            $change_dbh = $args{dst_dbh};
111           14                                142            $self->check_permissions(@args{qw(dst_dbh dst_db dst_tbl quoter)});
112                                                            # Is it safe to change data on $change_dbh?  It's only safe if it's not
113                                                            # a slave.  We don't change tables on slaves directly.  If we are
114                                                            # forced to change data on a slave, we require either that a) binary
115                                                            # logging is disabled, or b) the check is bypassed.  By the way, just
116                                                            # because the server is a slave doesn't mean it's not also the master
117                                                            # of the master (master-master replication).
118           14                                199            my $slave_status = $args{master_slave}->get_slave_status($change_dbh);
119           14                                 37            my (undef, $log_bin) = $change_dbh->selectrow_array(
120                                                               'SHOW VARIABLES LIKE "log_bin"');
121           14                                 32            my ($sql_log_bin) = $change_dbh->selectrow_array(
122                                                               'SELECT @@SQL_LOG_BIN');
123           14                               1684            MKDEBUG && _d('Variables: log_bin=',
124                                                               (defined $log_bin ? $log_bin : 'NULL'),
125                                                               ' @@SQL_LOG_BIN=',
126                                                               (defined $sql_log_bin ? $sql_log_bin : 'NULL'));
127   ***     14     50     33                  242            if ( !$args{skipslavecheck} && $slave_status && $sql_log_bin
      ***                   33                        
      ***                    0                        
      ***                   33                        
128                                                               && ($log_bin || 'OFF') eq 'ON' )
129                                                            {
130   ***      0                                  0               die "Can't make changes on $change_dbh because it's a slave: see "
131                                                                  . "the documentation section 'REPLICATION SAFETY' for solutions "
132                                                                  . "to this problem.";
133                                                            }
134                                                         }
135           14                                 37         MKDEBUG && _d('Will make changes via', $change_dbh);
136                                                         $update_func = sub {
137           36                                 76            map {
138           36                   36           127               MKDEBUG && _d('About to execute:', $_);
139           36                             4916176               $change_dbh->do($_);
140                                                            } @_;
141           14                                176         };
142                                                   
143                                                         # Set default database in case replicate-do-db is being used (issue 533).
144           14                               1516         $args{src_dbh}->do("USE `$args{src_db}`");
145           14                               1101         $args{dst_dbh}->do("USE `$args{dst_db}`");
146                                                      }
147                                                   
148                                                      my $ch = new ChangeHandler(
149                                                         queue     => $args{buffer} ? 0 : 1,
150                                                         quoter    => $args{quoter},
151                                                         database  => $args{dst_db},
152                                                         table     => $args{dst_tbl},
153                                                         sdatabase => $args{src_db},
154                                                         stable    => $args{src_tbl},
155                                                         replace   => $use_replace,
156                                                         actions   => [
157                                                            ( $update_func ? $update_func            : () ),
158                                                            # Print AFTER executing, so the print isn't misleading in case of an
159                                                            # index violation etc that doesn't actually get executed.
160                                                            ( $args{print}
161   ***      0      0             0             0               ? sub { print(@_, ";\n") or die "Cannot print: $OS_ERROR" }
162   ***     14     50                         344               : () ),
      ***            50                               
      ***            50                               
163                                                         ],
164                                                      );
165   ***     14            33                  242      my $rd = $args{RowDiff} || new RowDiff( dbh => $args{misc_dbh} );
166                                                   
167            4                                 18      $args{algorithm} ||= $self->best_algorithm(
168           14           100                  591         map { $_ => $args{$_} } qw(tbl_struct parser nibbler chunker));
169                                                   
170           14    100                          97      if ( !$ALGOS{ lc $args{algorithm} } ) {
171            1                                  4         die "No such algorithm $args{algorithm}; try one of "
172                                                            . join(', ', values %ALGOS) . "\n";
173                                                      }
174           13                                718      $args{algorithm} = $ALGOS{ lc $args{algorithm} };
175                                                   
176           13    100                          63      if ( $args{test} ) {
177            2                                 13         return ($ch->get_changes(), ALGORITHM => $args{algorithm});
178                                                      }
179                                                   
180                                                      # The sync algorithms must be sheltered from size-to-rows conversions.
181           11                                155      my $chunksize = $args{chunker}->size_to_rows(
182                                                            @args{qw(src_dbh src_db src_tbl chunksize dumper)}),
183                                                   
184                                                      my $class  = "TableSync$args{algorithm}";
185           11                                325      my $plugin = $class->new(
186                                                         handler   => $ch,
187                                                         cols      => $args{cols},
188                                                         dbh       => $args{src_dbh},
189                                                         database  => $args{src_db},
190                                                         dumper    => $args{dumper},
191                                                         table     => $args{src_tbl},
192                                                         chunker   => $args{chunker},
193                                                         nibbler   => $args{nibbler},
194                                                         parser    => $args{parser},
195                                                         struct    => $args{tbl_struct},
196                                                         checksum  => $args{checksum},
197                                                         vp        => $args{versionparser},
198                                                         quoter    => $args{quoter},
199                                                         chunksize => $chunksize,
200                                                         where     => $args{where},
201                                                         possible_keys => [],
202                                                         versionparser => $args{versionparser},
203                                                         func          => $args{func},
204                                                         trim          => $args{trim},
205                                                         bufferinmysql => $args{bufferinmysql},
206                                                      );
207                                                   
208           11                                209      $self->lock_and_wait(%args, lock_level => 2);
209                                                   
210           11                                 68      my $cycle = 0;
211           11                                102      while ( !$plugin->done ) {
212                                                   
213                                                         # Do as much of the work as possible before opening a transaction or
214                                                         # locking the tables.
215           25                                 72         MKDEBUG && _d('Beginning sync cycle', $cycle);
216   ***     25     50                         322         my $src_sql = $plugin->get_sql(
217                                                            quoter     => $args{quoter},
218                                                            database   => $args{src_db},
219                                                            table      => $args{src_tbl},
220                                                            where      => $args{where},
221                                                            index_hint => $args{index_hint} ? $plugin->{index} : undef,
222                                                         );
223   ***     25     50                         266         my $dst_sql = $plugin->get_sql(
224                                                            quoter     => $args{quoter},
225                                                            database   => $args{dst_db},
226                                                            table      => $args{dst_tbl},
227                                                            where      => $args{where},
228                                                            index_hint => $args{index_hint} ? $plugin->{index} : undef,
229                                                         );
230   ***     25     50                         134         if ( $args{transaction} ) {
231                                                            # TODO: update this for 2-way sync.
232   ***      0      0      0                    0            if ( $change_dbh && $change_dbh eq $args{src_dbh} ) {
      ***             0                               
233   ***      0                                  0               $src_sql .= ' FOR UPDATE';
234   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
235                                                            }
236                                                            elsif ( $change_dbh ) {
237   ***      0                                  0               $src_sql .= ' LOCK IN SHARE MODE';
238   ***      0                                  0               $dst_sql .= ' FOR UPDATE';
239                                                            }
240                                                            else {
241   ***      0                                  0               $src_sql .= ' LOCK IN SHARE MODE';
242   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
243                                                            }
244                                                         }
245           25                                161         $plugin->prepare($args{src_dbh});
246           25                                144         $plugin->prepare($args{dst_dbh});
247           25                                 56         MKDEBUG && _d('src:', $src_sql);
248           25                                 53         MKDEBUG && _d('dst:', $dst_sql);
249           25                                 68         my $src_sth = $args{src_dbh}
250                                                            ->prepare( $src_sql, { mysql_use_result => !$args{buffer} } );
251           25                                 55         my $dst_sth = $args{dst_dbh}
252                                                            ->prepare( $dst_sql, { mysql_use_result => !$args{buffer} } );
253                                                   
254                                                         # The first cycle should lock to begin work; after that, unlock only if
255                                                         # the plugin says it's OK (it may want to dig deeper on the rows it
256                                                         # currently has locked).
257           25                                137         my $executed_src = 0;
258           25    100    100                  204         if ( !$cycle || !$plugin->pending_changes() ) {
259           16                                186            $executed_src
260                                                               = $self->lock_and_wait(%args, src_sth => $src_sth, lock_level => 1);
261                                                         }
262                                                   
263                                                         # The source sth might have already been executed by lock_and_wait().
264   ***     25     50                        7274         $src_sth->execute() unless $executed_src;
265           25                               7743         $dst_sth->execute();
266                                                   
267           25                                596         $rd->compare_sets(
268                                                            left   => $src_sth,
269                                                            right  => $dst_sth,
270                                                            syncer => $plugin,
271                                                            tbl    => $args{tbl_struct},
272                                                         );
273           25                                 55         MKDEBUG && _d('Finished sync cycle', $cycle);
274           25                                171         $ch->process_rows(1);
275                                                   
276           25                                 76         $cycle++;
277                                                   
278           25                               1067         sleep $sleep;
279                                                      }
280                                                   
281           11                                 71      $ch->process_rows();
282                                                   
283           11                                216      $self->unlock(%args, lock_level => 2);
284                                                   
285           11                                 96      return ($ch->get_changes(), ALGORITHM => $args{algorithm});
286                                                   }
287                                                   
288                                                   # This query will check all needed privileges on the table without actually
289                                                   # changing anything in it.  We can't use REPLACE..SELECT because that doesn't
290                                                   # work inside of LOCK TABLES.
291                                                   sub check_permissions {
292           14                   14            80      my ( $self, $dbh, $db, $tbl, $quoter ) = @_;
293           14                                138      my $db_tbl = $quoter->quote($db, $tbl);
294           14                                 58      my $sql = "SHOW FULL COLUMNS FROM $db_tbl";
295           14                                 36      MKDEBUG && _d('Permissions check:', $sql);
296           14                                206      my $cols = $dbh->selectall_arrayref($sql, {Slice => {}});
297           14                                129      my ($hdr_name) = grep { m/privileges/i } keys %{$cols->[0]};
             126                                476   
              14                                113   
298           14                                 93      my $privs = $cols->[0]->{$hdr_name};
299   ***     14     50     33                  271      die "$privs does not include all needed privileges for $db_tbl"
      ***                   33                        
300                                                         unless $privs =~ m/select/ && $privs =~ m/insert/ && $privs =~ m/update/;
301           14                                 69      $sql = "DELETE FROM $db_tbl LIMIT 0"; # FULL COLUMNS doesn't show all privs
302           14                                 31      MKDEBUG && _d('Permissions check:', $sql);
303           14                               1980      $dbh->do($sql);
304                                                   }
305                                                   
306                                                   sub lock_table {
307            4                    4            24      my ( $self, $dbh, $where, $db_tbl, $mode ) = @_;
308            4                                 17      my $query = "LOCK TABLES $db_tbl $mode";
309            4                                  8      MKDEBUG && _d($query);
310            4                                312      $dbh->do($query);
311            4                                 18      MKDEBUG && _d('Acquired table lock on', $where, 'in', $mode, 'mode');
312                                                   }
313                                                   
314                                                   # Doesn't work quite the same way as lock_and_wait. It will unlock any LOWER
315                                                   # priority lock level, not just the exact same one.
316                                                   sub unlock {
317           11                   11           266      my ( $self, %args ) = @_;
318                                                   
319           11                                138      foreach my $arg ( qw(
320                                                         dst_db dst_dbh dst_tbl lock quoter replicate src_db src_dbh src_tbl
321                                                         timeoutok transaction wait lock_level) )
322                                                      {
323   ***    143     50                         601         die "I need a $arg argument" unless defined $args{$arg};
324                                                      }
325                                                   
326           11    100    100                  123      return unless $args{lock} && $args{lock} <= $args{lock_level};
327                                                   
328                                                      # First, unlock/commit.
329            2                                 12      foreach my $dbh( @args{qw(src_dbh dst_dbh)} ) {
330   ***      4     50                          20         if ( $args{transaction} ) {
331   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
332   ***      0                                  0            $dbh->commit;
333                                                         }
334                                                         else {
335            4                                 14            my $sql = 'UNLOCK TABLES';
336            4                                  9            MKDEBUG && _d($dbh, $sql);
337            4                                420            $dbh->do($sql);
338                                                         }
339                                                      }
340                                                   }
341                                                   
342                                                   # Lock levels:
343                                                   # 0 => none
344                                                   # 1 => per sync cycle
345                                                   # 2 => per table
346                                                   # 3 => global
347                                                   # This function might actually execute the $src_sth.  If we're using
348                                                   # transactions instead of table locks, the $src_sth has to be executed before
349                                                   # the MASTER_POS_WAIT() on the slave.  The return value is whether the
350                                                   # $src_sth was executed.
351                                                   sub lock_and_wait {
352           28                   28           628      my ( $self, %args ) = @_;
353           28                                259      my $result = 0;
354                                                   
355           28                                165      foreach my $arg ( qw(
356                                                         dst_db dst_dbh dst_tbl lock quoter replicate src_db src_dbh src_tbl
357                                                         timeoutok transaction wait lock_level misc_dbh master_slave) )
358                                                      {
359   ***    420     50                        1747         die "I need a $arg argument" unless defined $args{$arg};
360                                                      }
361                                                   
362           28    100    100                  326      return unless $args{lock} && $args{lock} == $args{lock_level};
363                                                   
364                                                      # First, unlock/commit.
365            3                                 21      foreach my $dbh( @args{qw(src_dbh dst_dbh)} ) {
366   ***      6     50                          31         if ( $args{transaction} ) {
367   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
368   ***      0                                  0            $dbh->commit;
369                                                         }
370                                                         else {
371            6                                 20            my $sql = 'UNLOCK TABLES';
372            6                                 16            MKDEBUG && _d($dbh, $sql);
373            6                                501            $dbh->do($sql);
374                                                         }
375                                                      }
376                                                   
377                                                      # User wants us to lock for consistency.  But lock only on source initially;
378                                                      # might have to wait for the slave to catch up before locking on the dest.
379            3    100                          23      if ( $args{lock} == 3 ) {
380            1                                  4         my $sql = 'FLUSH TABLES WITH READ LOCK';
381            1                                  2         MKDEBUG && _d($args{src_dbh}, ',', $sql);
382            1                                467         $args{src_dbh}->do($sql);
383                                                      }
384                                                      else {
385   ***      2     50                          12         if ( $args{transaction} ) {
386   ***      0      0                           0            if ( $args{src_sth} ) {
387                                                               # Execute the $src_sth on the source, so LOCK IN SHARE MODE/FOR
388                                                               # UPDATE will lock the rows examined.
389   ***      0                                  0               MKDEBUG && _d('Executing statement on source to lock rows');
390   ***      0                                  0               $args{src_sth}->execute();
391   ***      0                                  0               $result = 1;
392                                                            }
393                                                         }
394                                                         else {
395   ***      2     50                          18            $self->lock_table($args{src_dbh}, 'source',
396                                                               $args{quoter}->quote($args{src_db}, $args{src_tbl}),
397                                                               $args{replicate} ? 'WRITE' : 'READ');
398                                                         }
399                                                      }
400                                                   
401                                                      # If there is any error beyond this point, we need to unlock/commit.
402            3                                 17      eval {
403   ***      3     50                          18         if ( $args{wait} ) {
404                                                            # Always use the $misc_dbh dbh to check the master's position, because
405                                                            # the $src_dbh might be in use due to executing $src_sth.
406   ***      0                                  0            $args{master_slave}->wait_for_master(
407                                                               $args{misc_dbh}, $args{dst_dbh}, $args{wait}, $args{timeoutok});
408                                                         }
409                                                   
410                                                         # Don't lock on destination if it's a replication slave, or the
411                                                         # replication thread will not be able to make changes.
412   ***      3     50                          14         if ( $args{replicate} ) {
413   ***      0                                  0            MKDEBUG
414                                                               && _d('Not locking destination because syncing via replication');
415                                                         }
416                                                         else {
417            3    100                          31            if ( $args{lock} == 3 ) {
      ***            50                               
418            1                                  4               my $sql = 'FLUSH TABLES WITH READ LOCK';
419            1                                  3               MKDEBUG && _d($args{dst_dbh}, ',', $sql);
420            1                                 79               $args{dst_dbh}->do($sql);
421                                                            }
422                                                            elsif ( !$args{transaction} ) {
423   ***      2     50                          14               $self->lock_table($args{dst_dbh}, 'dest',
424                                                                  $args{quoter}->quote($args{dst_db}, $args{dst_tbl}),
425                                                                  $args{execute} ? 'WRITE' : 'READ');
426                                                            }
427                                                         }
428                                                      };
429                                                   
430   ***      3     50                          18      if ( $EVAL_ERROR ) {
431                                                         # Must abort/unlock/commit so that we don't interfere with any further
432                                                         # tables we try to do.
433   ***      0      0                           0         if ( $args{src_sth}->{Active} ) {
434   ***      0                                  0            $args{src_sth}->finish();
435                                                         }
436   ***      0                                  0         foreach my $dbh ( @args{qw(src_dbh dst_dbh misc_dbh)} ) {
437   ***      0      0                           0            next unless $dbh;
438   ***      0                                  0            MKDEBUG && _d('Caught error, unlocking/committing on', $dbh);
439   ***      0                                  0            $dbh->do('UNLOCK TABLES');
440   ***      0      0                           0            $dbh->commit() unless $dbh->{AutoCommit};
441                                                         }
442                                                         # ... and then re-throw the error.
443   ***      0                                  0         die $EVAL_ERROR;
444                                                      }
445                                                   
446            3                                 28      return $result;
447                                                   }
448                                                   
449                                                   sub _d {
450   ***      0                    0                    my ($package, undef, $line) = caller 0;
451   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
452   ***      0                                              map { defined $_ ? $_ : 'undef' }
453                                                           @_;
454   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
455                                                   }
456                                                   
457                                                   1;
458                                                   
459                                                   # ###########################################################################
460                                                   # End TableSyncer package
461                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39    ***     50      0     12   unless $args{$arg}
46    ***     50      0      3   if ($exact) { }
58           100      2      1   if ($idx) { }
81    ***     50      0    462   unless defined $args{$arg}
99    ***     50     14      0   if ($args{'execute'})
100   ***     50      0     14   if ($args{'replicate'}) { }
105   ***      0      0      0   if (not $can_replace)
127   ***     50      0     14   if (not $args{'skipslavecheck'} and $slave_status and $sql_log_bin and ($log_bin || 'OFF') eq 'ON')
161   ***      0      0      0   unless print @_, ";\n"
162   ***     50      0     14   $args{'buffer'} ? :
      ***     50     14      0   $update_func ? :
      ***     50      0     14   $args{'print'} ? :
170          100      1     13   if (not $ALGOS{lc $args{'algorithm'}})
176          100      2     11   if ($args{'test'})
216   ***     50      0     25   $args{'index_hint'} ? :
223   ***     50      0     25   $args{'index_hint'} ? :
230   ***     50      0     25   if ($args{'transaction'})
232   ***      0      0      0   if ($change_dbh and $change_dbh eq $args{'src_dbh'}) { }
      ***      0      0      0   elsif ($change_dbh) { }
258          100     16      9   if (not $cycle or not $plugin->pending_changes)
264   ***     50     25      0   unless $executed_src
299   ***     50      0     14   unless $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
323   ***     50      0    143   unless defined $args{$arg}
326          100      9      2   unless $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
330   ***     50      0      4   if ($args{'transaction'}) { }
359   ***     50      0    420   unless defined $args{$arg}
362          100     25      3   unless $args{'lock'} and $args{'lock'} == $args{'lock_level'}
366   ***     50      0      6   if ($args{'transaction'}) { }
379          100      1      2   if ($args{'lock'} == 3) { }
385   ***     50      0      2   if ($args{'transaction'}) { }
386   ***      0      0      0   if ($args{'src_sth'})
395   ***     50      0      2   $args{'replicate'} ? :
403   ***     50      0      3   if ($args{'wait'})
412   ***     50      0      3   if ($args{'replicate'}) { }
417          100      1      2   if ($args{'lock'} == 3) { }
      ***     50      2      0   elsif (not $args{'transaction'}) { }
423   ***     50      2      0   $args{'execute'} ? :
430   ***     50      0      3   if ($EVAL_ERROR)
433   ***      0      0      0   if ($args{'src_sth'}{'Active'})
437   ***      0      0      0   unless $dbh
440   ***      0      0      0   unless $$dbh{'AutoCommit'}
451   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
127   ***     33      0     14      0   not $args{'skipslavecheck'} and $slave_status
      ***     33     14      0      0   not $args{'skipslavecheck'} and $slave_status and $sql_log_bin
      ***     33     14      0      0   not $args{'skipslavecheck'} and $slave_status and $sql_log_bin and ($log_bin || 'OFF') eq 'ON'
232   ***      0      0      0      0   $change_dbh and $change_dbh eq $args{'src_dbh'}
299   ***     33      0      0     14   $privs =~ /select/ and $privs =~ /insert/
      ***     33      0      0     14   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
326          100      8      1      2   $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
362          100     21      4      3   $args{'lock'} and $args{'lock'} == $args{'lock_level'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
88    ***     50      0     14   $args{'sleep'} || 0
127   ***      0      0      0   $log_bin || 'OFF'
168          100     13      1   $args{'algorithm'} ||= $self->best_algorithm(map({$_, $args{$_};} 'tbl_struct', 'parser', 'nibbler', 'chunker'))

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
93    ***     33      0      0     14   $args{'replace'} || $args{'replicate'}
165   ***     33      0     14      0   $args{'RowDiff'} || 'RowDiff'->new('dbh', $args{'misc_dbh'})
258          100     11      5      9   not $cycle or not $plugin->pending_changes


Covered Subroutines
-------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
BEGIN                 1 /home/daniel/dev/maatkit/common/TableSyncer.pm:22 
BEGIN                 1 /home/daniel/dev/maatkit/common/TableSyncer.pm:23 
BEGIN                 1 /home/daniel/dev/maatkit/common/TableSyncer.pm:25 
BEGIN                 1 /home/daniel/dev/maatkit/common/TableSyncer.pm:27 
__ANON__             36 /home/daniel/dev/maatkit/common/TableSyncer.pm:138
best_algorithm        3 /home/daniel/dev/maatkit/common/TableSyncer.pm:37 
check_permissions    14 /home/daniel/dev/maatkit/common/TableSyncer.pm:292
lock_and_wait        28 /home/daniel/dev/maatkit/common/TableSyncer.pm:352
lock_table            4 /home/daniel/dev/maatkit/common/TableSyncer.pm:307
new                   1 /home/daniel/dev/maatkit/common/TableSyncer.pm:32 
sync_table           14 /home/daniel/dev/maatkit/common/TableSyncer.pm:74 
unlock               11 /home/daniel/dev/maatkit/common/TableSyncer.pm:317

Uncovered Subroutines
---------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
__ANON__              0 /home/daniel/dev/maatkit/common/TableSyncer.pm:161
_d                    0 /home/daniel/dev/maatkit/common/TableSyncer.pm:450


