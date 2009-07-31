---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableSyncer.pm   78.6   48.8   50.0   85.7    n/a  100.0   67.7
Total                          78.6   48.8   50.0   85.7    n/a  100.0   67.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:42 2009
Finish:       Fri Jul 31 18:53:57 2009

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
18                                                    # TableSyncer package $Revision: 4170 $
19                                                    # ###########################################################################
20                                                    package TableSyncer;
21                                                    
22             1                    1             7   use strict;
               1                                  3   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  4   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
28                                                    
29                                                    our %ALGOS = map { lc $_ => $_ } qw(Stream Chunk Nibble GroupBy);
30                                                    
31                                                    sub new {
32             1                    1        670620      bless {}, shift;
33                                                    }
34                                                    
35                                                    # Choose the best algorithm for syncing a given table.
36                                                    sub best_algorithm {
37             3                    3            43      my ( $self, %args ) = @_;
38             3                                 14      foreach my $arg ( qw(tbl_struct parser nibbler chunker) ) {
39    ***     12     50                          53         die "I need a $arg argument" unless $args{$arg};
40                                                       }
41             3                                 11      my $result;
42                                                    
43                                                       # See if Chunker says it can handle the table
44             3                                 31      my ($exact, $cols) = $args{chunker}
45                                                          ->find_chunk_columns($args{tbl_struct}, { exact => 1 });
46    ***      3     50                          14      if ( $exact ) {
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
57             3                                 24         my ($idx) = $args{parser}->find_best_index($args{tbl_struct});
58             3    100                          13         if ( $idx ) {
59             2                                  5            MKDEBUG && _d('Parser found best index', $idx, 'so Nibbler will work');
60             2                                  6            $result = 'Nibble';
61                                                          }
62                                                          else {
63                                                             # If not, GroupBy is the only choice.  We don't automatically choose
64                                                             # Stream, it must be specified by the user.
65             1                                  3            MKDEBUG && _d('No primary or unique non-null key in table');
66             1                                  3            $result = 'GroupBy';
67                                                          }
68                                                       }
69             3                                  7      MKDEBUG && _d('Algorithm:', $result);
70             3                                 22      return $result;
71                                                    }
72                                                    
73                                                    sub sync_table {
74            14                   14        6223291      my ( $self, %args ) = @_;
75            14                                200      foreach my $arg ( qw(
76                                                          buffer checksum chunker chunksize dst_db dst_dbh dst_tbl execute lock
77                                                          misc_dbh quoter replace replicate src_db src_dbh src_tbl test tbl_struct
78                                                          timeoutok transaction versionparser wait where possible_keys cols
79                                                          nibbler parser master_slave func dumper trim skipslavecheck bufferinmysql) )
80                                                       {
81    ***    462     50                        1970         die "I need a $arg argument" unless defined $args{$arg};
82                                                       }
83                                                       MKDEBUG && _d('Syncing table with args',
84                                                          join(', ',
85            14                                 40            map { "$_=" . (defined $args{$_} ? $args{$_} : 'undef') }
86                                                             sort keys %args));
87                                                    
88    ***     14            50                  177      my $sleep = $args{sleep} || 0;
89                                                    
90            13                                 57      my $can_replace
91            14                                 41         = grep { $_->{is_unique} } values %{$args{tbl_struct}->{keys}};
              14                                113   
92            14                                 37      MKDEBUG && _d('This table\'s replace-ability:', $can_replace);
93    ***     14            33                  118      my $use_replace = $args{replace} || $args{replicate};
94                                                    
95                                                       # TODO: for two-way sync, the change handler needs both DBHs.
96                                                       # Check permissions on writable tables (TODO: 2-way needs to check both)
97            14                                 34      my $update_func;
98            14                                 56      my $change_dbh;
99    ***     14     50                          62      if ( $args{execute} ) {
100   ***     14     50                          59         if ( $args{replicate} ) {
101   ***      0                                  0            $change_dbh = $args{src_dbh};
102   ***      0                                  0            $self->check_permissions(@args{qw(src_dbh src_db src_tbl quoter)});
103                                                            # Is it possible to make changes on the master?  Only if REPLACE will
104                                                            # work OK.
105   ***      0      0                           0            if ( !$can_replace ) {
106   ***      0                                  0               die "Can't make changes on the master: no unique index exists";
107                                                            }
108                                                         }
109                                                         else {
110           14                                 53            $change_dbh = $args{dst_dbh};
111           14                                150            $self->check_permissions(@args{qw(dst_dbh dst_db dst_tbl quoter)});
112                                                            # Is it safe to change data on $change_dbh?  It's only safe if it's not
113                                                            # a slave.  We don't change tables on slaves directly.  If we are
114                                                            # forced to change data on a slave, we require either that a) binary
115                                                            # logging is disabled, or b) the check is bypassed.  By the way, just
116                                                            # because the server is a slave doesn't mean it's not also the master
117                                                            # of the master (master-master replication).
118           14                                186            my $slave_status = $args{master_slave}->get_slave_status($change_dbh);
119           14                                 33            my (undef, $log_bin) = $change_dbh->selectrow_array(
120                                                               'SHOW VARIABLES LIKE "log_bin"');
121           14                                 32            my ($sql_log_bin) = $change_dbh->selectrow_array(
122                                                               'SELECT @@SQL_LOG_BIN');
123           14                               1808            MKDEBUG && _d('Variables: log_bin=',
124                                                               (defined $log_bin ? $log_bin : 'NULL'),
125                                                               ' @@SQL_LOG_BIN=',
126                                                               (defined $sql_log_bin ? $sql_log_bin : 'NULL'));
127   ***     14     50     33                  226            if ( !$args{skipslavecheck} && $slave_status && $sql_log_bin
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
135           14                                 40         MKDEBUG && _d('Will make changes via', $change_dbh);
136                                                         $update_func = sub {
137           36                                 74            map {
138           36                   36           129               MKDEBUG && _d('About to execute:', $_);
139           36                             5534395               $change_dbh->do($_);
140                                                            } @_;
141           14                                173         };
142                                                      }
143                                                   
144                                                      my $ch = new ChangeHandler(
145                                                         queue     => $args{buffer} ? 0 : 1,
146                                                         quoter    => $args{quoter},
147                                                         database  => $args{dst_db},
148                                                         table     => $args{dst_tbl},
149                                                         sdatabase => $args{src_db},
150                                                         stable    => $args{src_tbl},
151                                                         replace   => $use_replace,
152                                                         actions   => [
153                                                            ( $update_func ? $update_func            : () ),
154                                                            # Print AFTER executing, so the print isn't misleading in case of an
155                                                            # index violation etc that doesn't actually get executed.
156                                                            ( $args{print}
157   ***      0      0             0             0               ? sub { print(@_, ";\n") or die "Cannot print: $OS_ERROR" }
158   ***     14     50                         315               : () ),
      ***            50                               
      ***            50                               
159                                                         ],
160                                                      );
161           14                                137      my $rd = new RowDiff( dbh => $args{misc_dbh} );
162                                                   
163            4                                 19      $args{algorithm} ||= $self->best_algorithm(
164           14           100                   71         map { $_ => $args{$_} } qw(tbl_struct parser nibbler chunker));
165                                                   
166           14    100                         100      if ( !$ALGOS{ lc $args{algorithm} } ) {
167            1                                  2         die "No such algorithm $args{algorithm}; try one of "
168                                                            . join(', ', values %ALGOS) . "\n";
169                                                      }
170           13                                 67      $args{algorithm} = $ALGOS{ lc $args{algorithm} };
171                                                   
172           13    100                          71      if ( $args{test} ) {
173            2                                 14         return ($ch->get_changes(), ALGORITHM => $args{algorithm});
174                                                      }
175                                                   
176                                                      # The sync algorithms must be sheltered from size-to-rows conversions.
177           11                                166      my $chunksize = $args{chunker}->size_to_rows(
178                                                            @args{qw(src_dbh src_db src_tbl chunksize dumper)}),
179                                                   
180                                                      my $class  = "TableSync$args{algorithm}";
181           11                                305      my $plugin = $class->new(
182                                                         handler   => $ch,
183                                                         cols      => $args{cols},
184                                                         dbh       => $args{src_dbh},
185                                                         database  => $args{src_db},
186                                                         dumper    => $args{dumper},
187                                                         table     => $args{src_tbl},
188                                                         chunker   => $args{chunker},
189                                                         nibbler   => $args{nibbler},
190                                                         parser    => $args{parser},
191                                                         struct    => $args{tbl_struct},
192                                                         checksum  => $args{checksum},
193                                                         vp        => $args{versionparser},
194                                                         quoter    => $args{quoter},
195                                                         chunksize => $chunksize,
196                                                         where     => $args{where},
197                                                         possible_keys => [],
198                                                         versionparser => $args{versionparser},
199                                                         func          => $args{func},
200                                                         trim          => $args{trim},
201                                                         bufferinmysql => $args{bufferinmysql},
202                                                      );
203                                                   
204           11                                170      $self->lock_and_wait(%args, lock_level => 2);
205                                                   
206           11                                 56      my $cycle = 0;
207           11                                 96      while ( !$plugin->done ) {
208                                                   
209                                                         # Do as much of the work as possible before opening a transaction or
210                                                         # locking the tables.
211           25                                 70         MKDEBUG && _d('Beginning sync cycle', $cycle);
212   ***     25     50                         273         my $src_sql = $plugin->get_sql(
213                                                            quoter     => $args{quoter},
214                                                            database   => $args{src_db},
215                                                            table      => $args{src_tbl},
216                                                            where      => $args{where},
217                                                            index_hint => $args{index_hint} ? $plugin->{index} : undef,
218                                                         );
219   ***     25     50                         240         my $dst_sql = $plugin->get_sql(
220                                                            quoter     => $args{quoter},
221                                                            database   => $args{dst_db},
222                                                            table      => $args{dst_tbl},
223                                                            where      => $args{where},
224                                                            index_hint => $args{index_hint} ? $plugin->{index} : undef,
225                                                         );
226   ***     25     50                         132         if ( $args{transaction} ) {
227                                                            # TODO: update this for 2-way sync.
228   ***      0      0      0                    0            if ( $change_dbh && $change_dbh eq $args{src_dbh} ) {
      ***             0                               
229   ***      0                                  0               $src_sql .= ' FOR UPDATE';
230   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
231                                                            }
232                                                            elsif ( $change_dbh ) {
233   ***      0                                  0               $src_sql .= ' LOCK IN SHARE MODE';
234   ***      0                                  0               $dst_sql .= ' FOR UPDATE';
235                                                            }
236                                                            else {
237   ***      0                                  0               $src_sql .= ' LOCK IN SHARE MODE';
238   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
239                                                            }
240                                                         }
241           25                                168         $plugin->prepare($args{src_dbh});
242           25                                146         $plugin->prepare($args{dst_dbh});
243           25                                 79         MKDEBUG && _d('src:', $src_sql);
244           25                                 59         MKDEBUG && _d('dst:', $dst_sql);
245           25                                 63         my $src_sth = $args{src_dbh}
246                                                            ->prepare( $src_sql, { mysql_use_result => !$args{buffer} } );
247           25                                 55         my $dst_sth = $args{dst_dbh}
248                                                            ->prepare( $dst_sql, { mysql_use_result => !$args{buffer} } );
249                                                   
250                                                         # The first cycle should lock to begin work; after that, unlock only if
251                                                         # the plugin says it's OK (it may want to dig deeper on the rows it
252                                                         # currently has locked).
253           25                                161         my $executed_src = 0;
254           25    100    100                  195         if ( !$cycle || !$plugin->pending_changes() ) {
255           16                                192            $executed_src
256                                                               = $self->lock_and_wait(%args, src_sth => $src_sth, lock_level => 1);
257                                                         }
258                                                   
259                                                         # The source sth might have already been executed by lock_and_wait().
260   ***     25     50                        6983         $src_sth->execute() unless $executed_src;
261           25                               5706         $dst_sth->execute();
262                                                   
263           25                                310         $rd->compare_sets(
264                                                            left   => $src_sth,
265                                                            right  => $dst_sth,
266                                                            syncer => $plugin,
267                                                            tbl    => $args{tbl_struct},
268                                                         );
269           25                                 54         MKDEBUG && _d('Finished sync cycle', $cycle);
270           25                                168         $ch->process_rows(1);
271                                                   
272           25                                 75         $cycle++;
273                                                   
274           25                               1070         sleep $sleep;
275                                                      }
276                                                   
277           11                                 62      $ch->process_rows();
278                                                   
279           11                                201      $self->unlock(%args, lock_level => 2);
280                                                   
281           11                                 98      return ($ch->get_changes(), ALGORITHM => $args{algorithm});
282                                                   }
283                                                   
284                                                   # This query will check all needed privileges on the table without actually
285                                                   # changing anything in it.  We can't use REPLACE..SELECT because that doesn't
286                                                   # work inside of LOCK TABLES.
287                                                   sub check_permissions {
288           14                   14            89      my ( $self, $dbh, $db, $tbl, $quoter ) = @_;
289           14                                137      my $db_tbl = $quoter->quote($db, $tbl);
290           14                                 88      my $sql = "SHOW FULL COLUMNS FROM $db_tbl";
291           14                                 32      MKDEBUG && _d('Permissions check:', $sql);
292           14                                213      my $cols = $dbh->selectall_arrayref($sql, {Slice => {}});
293           14                                127      my ($hdr_name) = grep { m/privileges/i } keys %{$cols->[0]};
             126                                458   
              14                                108   
294           14                                 80      my $privs = $cols->[0]->{$hdr_name};
295   ***     14     50     33                  264      die "$privs does not include all needed privileges for $db_tbl"
      ***                   33                        
296                                                         unless $privs =~ m/select/ && $privs =~ m/insert/ && $privs =~ m/update/;
297           14                                 68      $sql = "DELETE FROM $db_tbl LIMIT 0"; # FULL COLUMNS doesn't show all privs
298           14                                 44      MKDEBUG && _d('Permissions check:', $sql);
299           14                               2684      $dbh->do($sql);
300                                                   }
301                                                   
302                                                   sub lock_table {
303            4                    4            23      my ( $self, $dbh, $where, $db_tbl, $mode ) = @_;
304            4                                 19      my $query = "LOCK TABLES $db_tbl $mode";
305            4                                  9      MKDEBUG && _d($query);
306            4                                411      $dbh->do($query);
307            4                                 20      MKDEBUG && _d('Acquired table lock on', $where, 'in', $mode, 'mode');
308                                                   }
309                                                   
310                                                   # Doesn't work quite the same way as lock_and_wait. It will unlock any LOWER
311                                                   # priority lock level, not just the exact same one.
312                                                   sub unlock {
313           11                   11           278      my ( $self, %args ) = @_;
314                                                   
315           11                                116      foreach my $arg ( qw(
316                                                         dst_db dst_dbh dst_tbl lock quoter replicate src_db src_dbh src_tbl
317                                                         timeoutok transaction wait lock_level) )
318                                                      {
319   ***    143     50                         602         die "I need a $arg argument" unless defined $args{$arg};
320                                                      }
321                                                   
322           11    100    100                  121      return unless $args{lock} && $args{lock} <= $args{lock_level};
323                                                   
324                                                      # First, unlock/commit.
325            2                                 13      foreach my $dbh( @args{qw(src_dbh dst_dbh)} ) {
326   ***      4     50                          18         if ( $args{transaction} ) {
327   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
328   ***      0                                  0            $dbh->commit;
329                                                         }
330                                                         else {
331            4                                 12            my $sql = 'UNLOCK TABLES';
332            4                                  9            MKDEBUG && _d($dbh, $sql);
333            4                                458            $dbh->do($sql);
334                                                         }
335                                                      }
336                                                   }
337                                                   
338                                                   # Lock levels:
339                                                   # 0 => none
340                                                   # 1 => per sync cycle
341                                                   # 2 => per table
342                                                   # 3 => global
343                                                   # This function might actually execute the $src_sth.  If we're using
344                                                   # transactions instead of table locks, the $src_sth has to be executed before
345                                                   # the MASTER_POS_WAIT() on the slave.  The return value is whether the
346                                                   # $src_sth was executed.
347                                                   sub lock_and_wait {
348           28                   28           650      my ( $self, %args ) = @_;
349           28                                730      my $result = 0;
350                                                   
351           28                                181      foreach my $arg ( qw(
352                                                         dst_db dst_dbh dst_tbl lock quoter replicate src_db src_dbh src_tbl
353                                                         timeoutok transaction wait lock_level misc_dbh master_slave) )
354                                                      {
355   ***    420     50                        1749         die "I need a $arg argument" unless defined $args{$arg};
356                                                      }
357                                                   
358           28    100    100                  319      return unless $args{lock} && $args{lock} == $args{lock_level};
359                                                   
360                                                      # First, unlock/commit.
361            3                                 19      foreach my $dbh( @args{qw(src_dbh dst_dbh)} ) {
362   ***      6     50                          28         if ( $args{transaction} ) {
363   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
364   ***      0                                  0            $dbh->commit;
365                                                         }
366                                                         else {
367            6                                 20            my $sql = 'UNLOCK TABLES';
368            6                                 16            MKDEBUG && _d($dbh, $sql);
369            6                                592            $dbh->do($sql);
370                                                         }
371                                                      }
372                                                   
373                                                      # User wants us to lock for consistency.  But lock only on source initially;
374                                                      # might have to wait for the slave to catch up before locking on the dest.
375            3    100                          18      if ( $args{lock} == 3 ) {
376            1                                  3         my $sql = 'FLUSH TABLES WITH READ LOCK';
377            1                                  2         MKDEBUG && _d($args{src_dbh}, ',', $sql);
378            1                                540         $args{src_dbh}->do($sql);
379                                                      }
380                                                      else {
381   ***      2     50                           8         if ( $args{transaction} ) {
382   ***      0      0                           0            if ( $args{src_sth} ) {
383                                                               # Execute the $src_sth on the source, so LOCK IN SHARE MODE/FOR
384                                                               # UPDATE will lock the rows examined.
385   ***      0                                  0               MKDEBUG && _d('Executing statement on source to lock rows');
386   ***      0                                  0               $args{src_sth}->execute();
387   ***      0                                  0               $result = 1;
388                                                            }
389                                                         }
390                                                         else {
391   ***      2     50                          19            $self->lock_table($args{src_dbh}, 'source',
392                                                               $args{quoter}->quote($args{src_db}, $args{src_tbl}),
393                                                               $args{replicate} ? 'WRITE' : 'READ');
394                                                         }
395                                                      }
396                                                   
397                                                      # If there is any error beyond this point, we need to unlock/commit.
398            3                                 12      eval {
399   ***      3     50                          15         if ( $args{wait} ) {
400                                                            # Always use the $misc_dbh dbh to check the master's position, because
401                                                            # the $src_dbh might be in use due to executing $src_sth.
402   ***      0                                  0            $args{master_slave}->wait_for_master(
403                                                               $args{misc_dbh}, $args{dst_dbh}, $args{wait}, $args{timeoutok});
404                                                         }
405                                                   
406                                                         # Don't lock on destination if it's a replication slave, or the
407                                                         # replication thread will not be able to make changes.
408   ***      3     50                          13         if ( $args{replicate} ) {
409   ***      0                                  0            MKDEBUG
410                                                               && _d('Not locking destination because syncing via replication');
411                                                         }
412                                                         else {
413            3    100                          20            if ( $args{lock} == 3 ) {
      ***            50                               
414            1                                  5               my $sql = 'FLUSH TABLES WITH READ LOCK';
415            1                                  2               MKDEBUG && _d($args{dst_dbh}, ',', $sql);
416            1                                107               $args{dst_dbh}->do($sql);
417                                                            }
418                                                            elsif ( !$args{transaction} ) {
419   ***      2     50                          15               $self->lock_table($args{dst_dbh}, 'dest',
420                                                                  $args{quoter}->quote($args{dst_db}, $args{dst_tbl}),
421                                                                  $args{execute} ? 'WRITE' : 'READ');
422                                                            }
423                                                         }
424                                                      };
425                                                   
426   ***      3     50                          14      if ( $EVAL_ERROR ) {
427                                                         # Must abort/unlock/commit so that we don't interfere with any further
428                                                         # tables we try to do.
429   ***      0      0                           0         if ( $args{src_sth}->{Active} ) {
430   ***      0                                  0            $args{src_sth}->finish();
431                                                         }
432   ***      0                                  0         foreach my $dbh ( @args{qw(src_dbh dst_dbh misc_dbh)} ) {
433   ***      0      0                           0            next unless $dbh;
434   ***      0                                  0            MKDEBUG && _d('Caught error, unlocking/committing on', $dbh);
435   ***      0                                  0            $dbh->do('UNLOCK TABLES');
436   ***      0      0                           0            $dbh->commit() unless $dbh->{AutoCommit};
437                                                         }
438                                                         # ... and then re-throw the error.
439   ***      0                                  0         die $EVAL_ERROR;
440                                                      }
441                                                   
442            3                                 27      return $result;
443                                                   }
444                                                   
445                                                   sub _d {
446   ***      0                    0                    my ($package, undef, $line) = caller 0;
447   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
448   ***      0                                              map { defined $_ ? $_ : 'undef' }
449                                                           @_;
450   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
451                                                   }
452                                                   
453                                                   1;
454                                                   
455                                                   # ###########################################################################
456                                                   # End TableSyncer package
457                                                   # ###########################################################################


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
157   ***      0      0      0   unless print @_, ";\n"
158   ***     50      0     14   $args{'buffer'} ? :
      ***     50     14      0   $update_func ? :
      ***     50      0     14   $args{'print'} ? :
166          100      1     13   if (not $ALGOS{lc $args{'algorithm'}})
172          100      2     11   if ($args{'test'})
212   ***     50      0     25   $args{'index_hint'} ? :
219   ***     50      0     25   $args{'index_hint'} ? :
226   ***     50      0     25   if ($args{'transaction'})
228   ***      0      0      0   if ($change_dbh and $change_dbh eq $args{'src_dbh'}) { }
      ***      0      0      0   elsif ($change_dbh) { }
254          100     16      9   if (not $cycle or not $plugin->pending_changes)
260   ***     50     25      0   unless $executed_src
295   ***     50      0     14   unless $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
319   ***     50      0    143   unless defined $args{$arg}
322          100      9      2   unless $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
326   ***     50      0      4   if ($args{'transaction'}) { }
355   ***     50      0    420   unless defined $args{$arg}
358          100     25      3   unless $args{'lock'} and $args{'lock'} == $args{'lock_level'}
362   ***     50      0      6   if ($args{'transaction'}) { }
375          100      1      2   if ($args{'lock'} == 3) { }
381   ***     50      0      2   if ($args{'transaction'}) { }
382   ***      0      0      0   if ($args{'src_sth'})
391   ***     50      0      2   $args{'replicate'} ? :
399   ***     50      0      3   if ($args{'wait'})
408   ***     50      0      3   if ($args{'replicate'}) { }
413          100      1      2   if ($args{'lock'} == 3) { }
      ***     50      2      0   elsif (not $args{'transaction'}) { }
419   ***     50      2      0   $args{'execute'} ? :
426   ***     50      0      3   if ($EVAL_ERROR)
429   ***      0      0      0   if ($args{'src_sth'}{'Active'})
433   ***      0      0      0   unless $dbh
436   ***      0      0      0   unless $$dbh{'AutoCommit'}
447   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
127   ***     33      0     14      0   not $args{'skipslavecheck'} and $slave_status
      ***     33     14      0      0   not $args{'skipslavecheck'} and $slave_status and $sql_log_bin
      ***     33     14      0      0   not $args{'skipslavecheck'} and $slave_status and $sql_log_bin and ($log_bin || 'OFF') eq 'ON'
228   ***      0      0      0      0   $change_dbh and $change_dbh eq $args{'src_dbh'}
295   ***     33      0      0     14   $privs =~ /select/ and $privs =~ /insert/
      ***     33      0      0     14   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
322          100      8      1      2   $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
358          100     21      4      3   $args{'lock'} and $args{'lock'} == $args{'lock_level'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
88    ***     50      0     14   $args{'sleep'} || 0
127   ***      0      0      0   $log_bin || 'OFF'
164          100     13      1   $args{'algorithm'} ||= $self->best_algorithm(map({$_, $args{$_};} 'tbl_struct', 'parser', 'nibbler', 'chunker'))

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
93    ***     33      0      0     14   $args{'replace'} || $args{'replicate'}
254          100     11      5      9   not $cycle or not $plugin->pending_changes


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
check_permissions    14 /home/daniel/dev/maatkit/common/TableSyncer.pm:288
lock_and_wait        28 /home/daniel/dev/maatkit/common/TableSyncer.pm:348
lock_table            4 /home/daniel/dev/maatkit/common/TableSyncer.pm:303
new                   1 /home/daniel/dev/maatkit/common/TableSyncer.pm:32 
sync_table           14 /home/daniel/dev/maatkit/common/TableSyncer.pm:74 
unlock               11 /home/daniel/dev/maatkit/common/TableSyncer.pm:313

Uncovered Subroutines
---------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
__ANON__              0 /home/daniel/dev/maatkit/common/TableSyncer.pm:157
_d                    0 /home/daniel/dev/maatkit/common/TableSyncer.pm:446


