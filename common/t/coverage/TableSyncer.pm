---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/TableSyncer.pm   78.3   48.8   50.0   85.7    n/a  100.0   67.6
Total                          78.3   48.8   50.0   85.7    n/a  100.0   67.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          TableSyncer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:19 2009
Finish:       Wed Jun 10 17:21:33 2009

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
18                                                    # TableSyncer package $Revision: 3495 $
19                                                    # ###########################################################################
20                                                    package TableSyncer;
21                                                    
22             1                    1            13   use strict;
               1                                  4   
               1                                 10   
23             1                    1            11   use warnings FATAL => 'all';
               1                                  3   
               1                                 10   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  8   
28                                                    
29                                                    our %ALGOS = map { lc $_ => $_ } qw(Stream Chunk Nibble GroupBy);
30                                                    
31                                                    sub new {
32             1                    1        419346      bless {}, shift;
33                                                    }
34                                                    
35                                                    # Choose the best algorithm for syncing a given table.
36                                                    sub best_algorithm {
37             3                    3            65      my ( $self, %args ) = @_;
38             3                                 29      foreach my $arg ( qw(tbl_struct parser nibbler chunker) ) {
39    ***     12     50                          93         die "I need a $arg argument" unless $args{$arg};
40                                                       }
41             3                                 14      my $result;
42                                                    
43                                                       # See if Chunker says it can handle the table
44             3                                 48      my ($exact, $cols) = $args{chunker}
45                                                          ->find_chunk_columns($args{tbl_struct}, { exact => 1 });
46    ***      3     50                          24      if ( $exact ) {
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
57             3                                 38         my ($idx) = $args{parser}->find_best_index($args{tbl_struct});
58             3    100                          20         if ( $idx ) {
59             2                                  7            MKDEBUG && _d('Parser found best index', $idx, 'so Nibbler will work');
60             2                                 12            $result = 'Nibble';
61                                                          }
62                                                          else {
63                                                             # If not, GroupBy is the only choice.  We don't automatically choose
64                                                             # Stream, it must be specified by the user.
65             1                                  4            MKDEBUG && _d('No primary or unique non-null key in table');
66             1                                  6            $result = 'GroupBy';
67                                                          }
68                                                       }
69             3                                 11      MKDEBUG && _d('Algorithm:', $result);
70             3                                 30      return $result;
71                                                    }
72                                                    
73                                                    sub sync_table {
74            14                   14        5746167      my ( $self, %args ) = @_;
75            14                                358      foreach my $arg ( qw(
76                                                          buffer checksum chunker chunksize dst_db dst_dbh dst_tbl execute lock
77                                                          misc_dbh quoter replace replicate src_db src_dbh src_tbl test tbl_struct
78                                                          timeoutok transaction versionparser wait where possible_keys cols
79                                                          nibbler parser master_slave func dumper trim skipslavecheck bufferinmysql) )
80                                                       {
81    ***    462     50                        3331         die "I need a $arg argument" unless defined $args{$arg};
82                                                       }
83                                                       MKDEBUG && _d('Syncing table with args',
84                                                          join(', ',
85            14                                 60            map { "$_=" . (defined $args{$_} ? $args{$_} : 'undef') }
86                                                             sort keys %args));
87                                                    
88            13                                103      my $can_replace
89            14                                 60         = grep { $_->{is_unique} } values %{$args{tbl_struct}->{keys}};
              14                                181   
90            14                                 53      MKDEBUG && _d('This table\'s replace-ability:', $can_replace);
91    ***     14            33                  326      my $use_replace = $args{replace} || $args{replicate};
92                                                    
93                                                       # TODO: for two-way sync, the change handler needs both DBHs.
94                                                       # Check permissions on writable tables (TODO: 2-way needs to check both)
95            14                                 51      my $update_func;
96            14                                 57      my $change_dbh;
97    ***     14     50                         100      if ( $args{execute} ) {
98    ***     14     50                          96         if ( $args{replicate} ) {
99    ***      0                                  0            $change_dbh = $args{src_dbh};
100   ***      0                                  0            $self->check_permissions(@args{qw(src_dbh src_db src_tbl quoter)});
101                                                            # Is it possible to make changes on the master?  Only if REPLACE will
102                                                            # work OK.
103   ***      0      0                           0            if ( !$can_replace ) {
104   ***      0                                  0               die "Can't make changes on the master: no unique index exists";
105                                                            }
106                                                         }
107                                                         else {
108           14                                 72            $change_dbh = $args{dst_dbh};
109           14                                193            $self->check_permissions(@args{qw(dst_dbh dst_db dst_tbl quoter)});
110                                                            # Is it safe to change data on $change_dbh?  It's only safe if it's not
111                                                            # a slave.  We don't change tables on slaves directly.  If we are
112                                                            # forced to change data on a slave, we require either that a) binary
113                                                            # logging is disabled, or b) the check is bypassed.  By the way, just
114                                                            # because the server is a slave doesn't mean it's not also the master
115                                                            # of the master (master-master replication).
116           14                                305            my $slave_status = $args{master_slave}->get_slave_status($change_dbh);
117           14                                 58            my (undef, $log_bin) = $change_dbh->selectrow_array(
118                                                               'SHOW VARIABLES LIKE "log_bin"');
119           14                                 52            my ($sql_log_bin) = $change_dbh->selectrow_array(
120                                                               'SELECT @@SQL_LOG_BIN');
121           14                               3335            MKDEBUG && _d('Variables: log_bin=',
122                                                               (defined $log_bin ? $log_bin : 'NULL'),
123                                                               ' @@SQL_LOG_BIN=',
124                                                               (defined $sql_log_bin ? $sql_log_bin : 'NULL'));
125   ***     14     50     33                  431            if ( !$args{skipslavecheck} && $slave_status && $sql_log_bin
      ***                   33                        
      ***                    0                        
      ***                   33                        
126                                                               && ($log_bin || 'OFF') eq 'ON' )
127                                                            {
128   ***      0                                  0               die "Can't make changes on $change_dbh because it's a slave: see "
129                                                                  . "the documentation section 'REPLICATION SAFETY' for solutions "
130                                                                  . "to this problem.";
131                                                            }
132                                                         }
133           14                                 62         MKDEBUG && _d('Will make changes via', $change_dbh);
134                                                         $update_func = sub {
135           36                                121            map {
136           36                   36           197               MKDEBUG && _d('About to execute:', $_);
137           36                             4907748               $change_dbh->do($_);
138                                                            } @_;
139           14                                283         };
140                                                      }
141                                                   
142                                                      my $ch = new ChangeHandler(
143                                                         queue     => $args{buffer} ? 0 : 1,
144                                                         quoter    => $args{quoter},
145                                                         database  => $args{dst_db},
146                                                         table     => $args{dst_tbl},
147                                                         sdatabase => $args{src_db},
148                                                         stable    => $args{src_tbl},
149                                                         replace   => $use_replace,
150                                                         actions   => [
151                                                            ( $update_func ? $update_func            : () ),
152                                                            # Print AFTER executing, so the print isn't misleading in case of an
153                                                            # index violation etc that doesn't actually get executed.
154                                                            ( $args{print}
155   ***      0      0             0             0               ? sub { print(@_, ";\n") or die "Cannot print: $OS_ERROR" }
156   ***     14     50                         572               : () ),
      ***            50                               
      ***            50                               
157                                                         ],
158                                                      );
159           14                                222      my $rd = new RowDiff( dbh => $args{misc_dbh} );
160                                                   
161            4                                 35      $args{algorithm} ||= $self->best_algorithm(
162           14           100                  117         map { $_ => $args{$_} } qw(tbl_struct parser nibbler chunker));
163                                                   
164           14    100                         150      if ( !$ALGOS{ lc $args{algorithm} } ) {
165            1                                  4         die "No such algorithm $args{algorithm}; try one of "
166                                                            . join(', ', values %ALGOS) . "\n";
167                                                      }
168           13                                105      $args{algorithm} = $ALGOS{ lc $args{algorithm} };
169                                                   
170           13    100                         106      if ( $args{test} ) {
171            2                                 26         return ($ch->get_changes(), ALGORITHM => $args{algorithm});
172                                                      }
173                                                   
174                                                      # The sync algorithms must be sheltered from size-to-rows conversions.
175           11                                236      my $chunksize = $args{chunker}->size_to_rows(
176                                                            @args{qw(src_dbh src_db src_tbl chunksize dumper)}),
177                                                   
178                                                      my $class  = "TableSync$args{algorithm}";
179           11                                551      my $plugin = $class->new(
180                                                         handler   => $ch,
181                                                         cols      => $args{cols},
182                                                         dbh       => $args{src_dbh},
183                                                         database  => $args{src_db},
184                                                         dumper    => $args{dumper},
185                                                         table     => $args{src_tbl},
186                                                         chunker   => $args{chunker},
187                                                         nibbler   => $args{nibbler},
188                                                         parser    => $args{parser},
189                                                         struct    => $args{tbl_struct},
190                                                         checksum  => $args{checksum},
191                                                         vp        => $args{versionparser},
192                                                         quoter    => $args{quoter},
193                                                         chunksize => $chunksize,
194                                                         where     => $args{where},
195                                                         possible_keys => [],
196                                                         versionparser => $args{versionparser},
197                                                         func          => $args{func},
198                                                         trim          => $args{trim},
199                                                         bufferinmysql => $args{bufferinmysql},
200                                                      );
201                                                   
202           11                                300      $self->lock_and_wait(%args, lock_level => 2);
203                                                   
204           11                                919      my $cycle = 0;
205           11                                189      while ( !$plugin->done ) {
206                                                   
207                                                         # Do as much of the work as possible before opening a transaction or
208                                                         # locking the tables.
209           25                                106         MKDEBUG && _d('Beginning sync cycle', $cycle);
210   ***     25     50                         495         my $src_sql = $plugin->get_sql(
211                                                            quoter     => $args{quoter},
212                                                            database   => $args{src_db},
213                                                            table      => $args{src_tbl},
214                                                            where      => $args{where},
215                                                            index_hint => $args{index_hint} ? $plugin->{index} : undef,
216                                                         );
217   ***     25     50                         427         my $dst_sql = $plugin->get_sql(
218                                                            quoter     => $args{quoter},
219                                                            database   => $args{dst_db},
220                                                            table      => $args{dst_tbl},
221                                                            where      => $args{where},
222                                                            index_hint => $args{index_hint} ? $plugin->{index} : undef,
223                                                         );
224   ***     25     50                         222         if ( $args{transaction} ) {
225                                                            # TODO: update this for 2-way sync.
226   ***      0      0      0                    0            if ( $change_dbh && $change_dbh eq $args{src_dbh} ) {
      ***             0                               
227   ***      0                                  0               $src_sql .= ' FOR UPDATE';
228   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
229                                                            }
230                                                            elsif ( $change_dbh ) {
231   ***      0                                  0               $src_sql .= ' LOCK IN SHARE MODE';
232   ***      0                                  0               $dst_sql .= ' FOR UPDATE';
233                                                            }
234                                                            else {
235   ***      0                                  0               $src_sql .= ' LOCK IN SHARE MODE';
236   ***      0                                  0               $dst_sql .= ' LOCK IN SHARE MODE';
237                                                            }
238                                                         }
239           25                                249         $plugin->prepare($args{src_dbh});
240           25                                257         $plugin->prepare($args{dst_dbh});
241           25                                114         MKDEBUG && _d('src:', $src_sql);
242           25                                 85         MKDEBUG && _d('dst:', $dst_sql);
243           25                                 90         my $src_sth = $args{src_dbh}
244                                                            ->prepare( $src_sql, { mysql_use_result => !$args{buffer} } );
245           25                                 79         my $dst_sth = $args{dst_dbh}
246                                                            ->prepare( $dst_sql, { mysql_use_result => !$args{buffer} } );
247                                                   
248                                                         # The first cycle should lock to begin work; after that, unlock only if
249                                                         # the plugin says it's OK (it may want to dig deeper on the rows it
250                                                         # currently has locked).
251           25                                238         my $executed_src = 0;
252           25    100    100                  334         if ( !$cycle || !$plugin->pending_changes() ) {
253           16                                327            $executed_src
254                                                               = $self->lock_and_wait(%args, src_sth => $src_sth, lock_level => 1);
255                                                         }
256                                                   
257                                                         # The source sth might have already been executed by lock_and_wait().
258   ***     25     50                       12865         $src_sth->execute() unless $executed_src;
259           25                               9369         $dst_sth->execute();
260                                                   
261           25                                413         $rd->compare_sets(
262                                                            left   => $src_sth,
263                                                            right  => $dst_sth,
264                                                            syncer => $plugin,
265                                                            tbl    => $args{tbl_struct},
266                                                         );
267           25                                104         MKDEBUG && _d('Finished sync cycle', $cycle);
268           25                                269         $ch->process_rows(1);
269                                                   
270           25                               1684         $cycle++;
271                                                      }
272                                                   
273           11                                105      $ch->process_rows();
274                                                   
275           11                                288      $self->unlock(%args, lock_level => 2);
276                                                   
277           11                                177      return ($ch->get_changes(), ALGORITHM => $args{algorithm});
278                                                   }
279                                                   
280                                                   # This query will check all needed privileges on the table without actually
281                                                   # changing anything in it.  We can't use REPLACE..SELECT because that doesn't
282                                                   # work inside of LOCK TABLES.
283                                                   sub check_permissions {
284           14                   14           149      my ( $self, $dbh, $db, $tbl, $quoter ) = @_;
285           14                                242      my $db_tbl = $quoter->quote($db, $tbl);
286           14                                100      my $sql = "SHOW FULL COLUMNS FROM $db_tbl";
287           14                                 56      MKDEBUG && _d('Permissions check:', $sql);
288           14                               1034      my $cols = $dbh->selectall_arrayref($sql, {Slice => {}});
289           14                                180      my ($hdr_name) = grep { m/privileges/i } keys %{$cols->[0]};
             126                                821   
              14                                191   
290           14                                140      my $privs = $cols->[0]->{$hdr_name};
291   ***     14     50     33                  498      die "$privs does not include all needed privileges for $db_tbl"
      ***                   33                        
292                                                         unless $privs =~ m/select/ && $privs =~ m/insert/ && $privs =~ m/update/;
293           14                                 97      $sql = "DELETE FROM $db_tbl LIMIT 0"; # FULL COLUMNS doesn't show all privs
294           14                                 44      MKDEBUG && _d('Permissions check:', $sql);
295           14                               8525      $dbh->do($sql);
296                                                   }
297                                                   
298                                                   sub lock_table {
299            4                    4            41      my ( $self, $dbh, $where, $db_tbl, $mode ) = @_;
300            4                                 32      my $query = "LOCK TABLES $db_tbl $mode";
301            4                                 26      MKDEBUG && _d($query);
302            4                               1901      $dbh->do($query);
303            4                                 44      MKDEBUG && _d('Acquired table lock on', $where, 'in', $mode, 'mode');
304                                                   }
305                                                   
306                                                   # Doesn't work quite the same way as lock_and_wait. It will unlock any LOWER
307                                                   # priority lock level, not just the exact same one.
308                                                   sub unlock {
309           11                   11           477      my ( $self, %args ) = @_;
310                                                   
311           11                                212      foreach my $arg ( qw(
312                                                         dst_db dst_dbh dst_tbl lock quoter replicate src_db src_dbh src_tbl
313                                                         timeoutok transaction wait lock_level) )
314                                                      {
315   ***    143     50                        1040         die "I need a $arg argument" unless defined $args{$arg};
316                                                      }
317                                                   
318           11    100    100                  216      return unless $args{lock} && $args{lock} <= $args{lock_level};
319                                                   
320                                                      # First, unlock/commit.
321            2                                 17      foreach my $dbh( @args{qw(src_dbh dst_dbh)} ) {
322   ***      4     50                          47         if ( $args{transaction} ) {
323   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
324   ***      0                                  0            $dbh->commit;
325                                                         }
326                                                         else {
327            4                                 22            my $sql = 'UNLOCK TABLES';
328            4                                 13            MKDEBUG && _d($dbh, $sql);
329            4                                871            $dbh->do($sql);
330                                                         }
331                                                      }
332                                                   }
333                                                   
334                                                   # Lock levels:
335                                                   # 0 => none
336                                                   # 1 => per sync cycle
337                                                   # 2 => per table
338                                                   # 3 => global
339                                                   # This function might actually execute the $src_sth.  If we're using
340                                                   # transactions instead of table locks, the $src_sth has to be executed before
341                                                   # the MASTER_POS_WAIT() on the slave.  The return value is whether the
342                                                   # $src_sth was executed.
343                                                   sub lock_and_wait {
344           28                   28          1133      my ( $self, %args ) = @_;
345           28                                327      my $result = 0;
346                                                   
347           28                                310      foreach my $arg ( qw(
348                                                         dst_db dst_dbh dst_tbl lock quoter replicate src_db src_dbh src_tbl
349                                                         timeoutok transaction wait lock_level misc_dbh master_slave) )
350                                                      {
351   ***    420     50                        3006         die "I need a $arg argument" unless defined $args{$arg};
352                                                      }
353                                                   
354           28    100    100                  593      return unless $args{lock} && $args{lock} == $args{lock_level};
355                                                   
356                                                      # First, unlock/commit.
357            3                                 30      foreach my $dbh( @args{qw(src_dbh dst_dbh)} ) {
358   ***      6     50                          53         if ( $args{transaction} ) {
359   ***      0                                  0            MKDEBUG && _d('Committing', $dbh);
360   ***      0                                  0            $dbh->commit;
361                                                         }
362                                                         else {
363            6                                 34            my $sql = 'UNLOCK TABLES';
364            6                                 18            MKDEBUG && _d($dbh, $sql);
365            6                               2067            $dbh->do($sql);
366                                                         }
367                                                      }
368                                                   
369                                                      # User wants us to lock for consistency.  But lock only on source initially;
370                                                      # might have to wait for the slave to catch up before locking on the dest.
371            3    100                          33      if ( $args{lock} == 3 ) {
372            1                                  7         my $sql = 'FLUSH TABLES WITH READ LOCK';
373            1                                  5         MKDEBUG && _d($args{src_dbh}, ',', $sql);
374            1                               1065         $args{src_dbh}->do($sql);
375                                                      }
376                                                      else {
377   ***      2     50                          20         if ( $args{transaction} ) {
378   ***      0      0                           0            if ( $args{src_sth} ) {
379                                                               # Execute the $src_sth on the source, so LOCK IN SHARE MODE/FOR
380                                                               # UPDATE will lock the rows examined.
381   ***      0                                  0               MKDEBUG && _d('Executing statement on source to lock rows');
382   ***      0                                  0               $args{src_sth}->execute();
383   ***      0                                  0               $result = 1;
384                                                            }
385                                                         }
386                                                         else {
387   ***      2     50                          38            $self->lock_table($args{src_dbh}, 'source',
388                                                               $args{quoter}->quote($args{src_db}, $args{src_tbl}),
389                                                               $args{replicate} ? 'WRITE' : 'READ');
390                                                         }
391                                                      }
392                                                   
393                                                      # If there is any error beyond this point, we need to unlock/commit.
394            3                                 20      eval {
395   ***      3     50                          32         if ( $args{wait} ) {
396                                                            # Always use the $misc_dbh dbh to check the master's position, because
397                                                            # the $src_dbh might be in use due to executing $src_sth.
398   ***      0                                  0            $args{master_slave}->wait_for_master(
399                                                               $args{misc_dbh}, $args{dst_dbh}, $args{wait}, $args{timeoutok});
400                                                         }
401                                                   
402                                                         # Don't lock on destination if it's a replication slave, or the
403                                                         # replication thread will not be able to make changes.
404   ***      3     50                          23         if ( $args{replicate} ) {
405   ***      0                                  0            MKDEBUG
406                                                               && _d('Not locking destination because syncing via replication');
407                                                         }
408                                                         else {
409            3    100                          33            if ( $args{lock} == 3 ) {
      ***            50                               
410            1                                  7               my $sql = 'FLUSH TABLES WITH READ LOCK';
411            1                                  4               MKDEBUG && _d($args{dst_dbh}, ',', $sql);
412            1                                288               $args{dst_dbh}->do($sql);
413                                                            }
414                                                            elsif ( !$args{transaction} ) {
415   ***      2     50                          26               $self->lock_table($args{dst_dbh}, 'dest',
416                                                                  $args{quoter}->quote($args{dst_db}, $args{dst_tbl}),
417                                                                  $args{execute} ? 'WRITE' : 'READ');
418                                                            }
419                                                         }
420                                                      };
421                                                   
422   ***      3     50                          25      if ( $EVAL_ERROR ) {
423                                                         # Must abort/unlock/commit so that we don't interfere with any further
424                                                         # tables we try to do.
425   ***      0      0                           0         if ( $args{src_sth}->{Active} ) {
426   ***      0                                  0            $args{src_sth}->finish();
427                                                         }
428   ***      0                                  0         foreach my $dbh ( @args{qw(src_dbh dst_dbh misc_dbh)} ) {
429   ***      0      0                           0            next unless $dbh;
430   ***      0                                  0            MKDEBUG && _d('Caught error, unlocking/committing on', $dbh);
431   ***      0                                  0            $dbh->do('UNLOCK TABLES');
432   ***      0      0                           0            $dbh->commit() unless $dbh->{AutoCommit};
433                                                         }
434                                                         # ... and then re-throw the error.
435   ***      0                                  0         die $EVAL_ERROR;
436                                                      }
437                                                   
438            3                                 64      return $result;
439                                                   }
440                                                   
441                                                   sub _d {
442   ***      0                    0                    my ($package, undef, $line) = caller 0;
443   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
444   ***      0                                              map { defined $_ ? $_ : 'undef' }
445                                                           @_;
446   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
447                                                   }
448                                                   
449                                                   1;
450                                                   
451                                                   # ###########################################################################
452                                                   # End TableSyncer package
453                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
39    ***     50      0     12   unless $args{$arg}
46    ***     50      0      3   if ($exact) { }
58           100      2      1   if ($idx) { }
81    ***     50      0    462   unless defined $args{$arg}
97    ***     50     14      0   if ($args{'execute'})
98    ***     50      0     14   if ($args{'replicate'}) { }
103   ***      0      0      0   if (not $can_replace)
125   ***     50      0     14   if (not $args{'skipslavecheck'} and $slave_status and $sql_log_bin and ($log_bin || 'OFF') eq 'ON')
155   ***      0      0      0   unless print @_, ";\n"
156   ***     50      0     14   $args{'buffer'} ? :
      ***     50     14      0   $update_func ? :
      ***     50      0     14   $args{'print'} ? :
164          100      1     13   if (not $ALGOS{lc $args{'algorithm'}})
170          100      2     11   if ($args{'test'})
210   ***     50      0     25   $args{'index_hint'} ? :
217   ***     50      0     25   $args{'index_hint'} ? :
224   ***     50      0     25   if ($args{'transaction'})
226   ***      0      0      0   if ($change_dbh and $change_dbh eq $args{'src_dbh'}) { }
      ***      0      0      0   elsif ($change_dbh) { }
252          100     16      9   if (not $cycle or not $plugin->pending_changes)
258   ***     50     25      0   unless $executed_src
291   ***     50      0     14   unless $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
315   ***     50      0    143   unless defined $args{$arg}
318          100      9      2   unless $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
322   ***     50      0      4   if ($args{'transaction'}) { }
351   ***     50      0    420   unless defined $args{$arg}
354          100     25      3   unless $args{'lock'} and $args{'lock'} == $args{'lock_level'}
358   ***     50      0      6   if ($args{'transaction'}) { }
371          100      1      2   if ($args{'lock'} == 3) { }
377   ***     50      0      2   if ($args{'transaction'}) { }
378   ***      0      0      0   if ($args{'src_sth'})
387   ***     50      0      2   $args{'replicate'} ? :
395   ***     50      0      3   if ($args{'wait'})
404   ***     50      0      3   if ($args{'replicate'}) { }
409          100      1      2   if ($args{'lock'} == 3) { }
      ***     50      2      0   elsif (not $args{'transaction'}) { }
415   ***     50      2      0   $args{'execute'} ? :
422   ***     50      0      3   if ($EVAL_ERROR)
425   ***      0      0      0   if ($args{'src_sth'}{'Active'})
429   ***      0      0      0   unless $dbh
432   ***      0      0      0   unless $$dbh{'AutoCommit'}
443   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
125   ***     33      0     14      0   not $args{'skipslavecheck'} and $slave_status
      ***     33     14      0      0   not $args{'skipslavecheck'} and $slave_status and $sql_log_bin
      ***     33     14      0      0   not $args{'skipslavecheck'} and $slave_status and $sql_log_bin and ($log_bin || 'OFF') eq 'ON'
226   ***      0      0      0      0   $change_dbh and $change_dbh eq $args{'src_dbh'}
291   ***     33      0      0     14   $privs =~ /select/ and $privs =~ /insert/
      ***     33      0      0     14   $privs =~ /select/ and $privs =~ /insert/ and $privs =~ /update/
318          100      8      1      2   $args{'lock'} and $args{'lock'} <= $args{'lock_level'}
354          100     21      4      3   $args{'lock'} and $args{'lock'} == $args{'lock_level'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
125   ***      0      0      0   $log_bin || 'OFF'
162          100     13      1   $args{'algorithm'} ||= $self->best_algorithm(map({$_, $args{$_};} 'tbl_struct', 'parser', 'nibbler', 'chunker'))

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
91    ***     33      0      0     14   $args{'replace'} || $args{'replicate'}
252          100     11      5      9   not $cycle or not $plugin->pending_changes


Covered Subroutines
-------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
BEGIN                 1 /home/daniel/dev/maatkit/common/TableSyncer.pm:22 
BEGIN                 1 /home/daniel/dev/maatkit/common/TableSyncer.pm:23 
BEGIN                 1 /home/daniel/dev/maatkit/common/TableSyncer.pm:25 
BEGIN                 1 /home/daniel/dev/maatkit/common/TableSyncer.pm:27 
__ANON__             36 /home/daniel/dev/maatkit/common/TableSyncer.pm:136
best_algorithm        3 /home/daniel/dev/maatkit/common/TableSyncer.pm:37 
check_permissions    14 /home/daniel/dev/maatkit/common/TableSyncer.pm:284
lock_and_wait        28 /home/daniel/dev/maatkit/common/TableSyncer.pm:344
lock_table            4 /home/daniel/dev/maatkit/common/TableSyncer.pm:299
new                   1 /home/daniel/dev/maatkit/common/TableSyncer.pm:32 
sync_table           14 /home/daniel/dev/maatkit/common/TableSyncer.pm:74 
unlock               11 /home/daniel/dev/maatkit/common/TableSyncer.pm:309

Uncovered Subroutines
---------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
__ANON__              0 /home/daniel/dev/maatkit/common/TableSyncer.pm:155
_d                    0 /home/daniel/dev/maatkit/common/TableSyncer.pm:442


