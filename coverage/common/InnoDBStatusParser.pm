---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mon/InnoDBStatusParser.pm   67.3   37.5   40.0   81.8    0.0   91.5   58.7
InnoDBStatusParser.t          100.0   50.0   33.3  100.0    n/a    8.5   93.0
Total                          74.8   38.2   37.5   89.5    0.0  100.0   66.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:35 2010
Finish:       Thu Jun 24 19:33:35 2010

Run:          InnoDBStatusParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:37 2010
Finish:       Thu Jun 24 19:33:37 2010

/home/daniel/dev/maatkit/common/InnoDBStatusParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009-@CURRENTYEAR@ Baron Schwartz.
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
18                                                    # InnoDBStatusParser package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    package InnoDBStatusParser;
21                                                    
22                                                    # This package was taken from innotop.
23                                                    
24             1                    1             5   use strict;
               1                                  2   
               1                                  7   
25             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
26                                                    
27             1                    1             5   use English qw(-no_match_vars);
               1                                  6   
               1                                  7   
28                                                    
29    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 16   
30                                                    
31                                                    # TODO see 3 tablespace extents now reserved for B-tree split operations
32                                                    # example in note on case 1028
33                                                    
34                                                    # Some common patterns
35                                                    my $d  = qr/(\d+)/;                    # Digit
36                                                    my $f  = qr/(\d+\.\d+)/;               # Float
37                                                    my $t  = qr/(\d+ \d+)/;                # Transaction ID
38                                                    my $i  = qr/((?:\d{1,3}\.){3}\d+)/;    # IP address
39                                                    my $n  = qr/([^`\s]+)/;                # MySQL object name
40                                                    my $w  = qr/(\w+)/;                    # Words
41                                                    my $fl = qr/([\w\.\/]+) line $d/;      # Filename and line number
42                                                    my $h  = qr/((?:0x)?[0-9a-f]*)/;       # Hex
43                                                    my $s  = qr/(\d{6} .\d:\d\d:\d\d)/;    # InnoDB timestamp
44                                                    
45                                                    sub ts_to_time {
46    ***      1                    1      0      4      my ( $ts ) = @_;
47             1                                 19      sprintf('200%d-%02d-%02d %02d:%02d:%02d',
48                                                          $ts =~ m/(\d\d)(\d\d)(\d\d) +(\d+):(\d+):(\d+)/);
49                                                    }
50                                                    
51                                                    # A thread's proc_info can be at least 98 different things I've found in the
52                                                    # source.  Fortunately, most of them begin with a gerunded verb.  These are
53                                                    # the ones that don't.
54                                                    my %is_proc_info = (
55                                                       'After create'                 => 1,
56                                                       'Execution of init_command'    => 1,
57                                                       'FULLTEXT initialization'      => 1,
58                                                       'Reopen tables'                => 1,
59                                                       'Repair done'                  => 1,
60                                                       'Repair with keycache'         => 1,
61                                                       'System lock'                  => 1,
62                                                       'Table lock'                   => 1,
63                                                       'Thread initialized'           => 1,
64                                                       'User lock'                    => 1,
65                                                       'copy to tmp table'            => 1,
66                                                       'discard_or_import_tablespace' => 1,
67                                                       'end'                          => 1,
68                                                       'got handler lock'             => 1,
69                                                       'got old table'                => 1,
70                                                       'init'                         => 1,
71                                                       'key cache'                    => 1,
72                                                       'locks'                        => 1,
73                                                       'malloc'                       => 1,
74                                                       'query end'                    => 1,
75                                                       'rename result table'          => 1,
76                                                       'rename'                       => 1,
77                                                       'setup'                        => 1,
78                                                       'statistics'                   => 1,
79                                                       'status'                       => 1,
80                                                       'table cache'                  => 1,
81                                                       'update'                       => 1,
82                                                    );
83                                                    
84                                                    # Each parse rule is a set of rules and some custom code.  Each rule is an
85                                                    # arrayref of arrayrefs of columns and a regular expression pattern, to be
86                                                    # matched with the 'm' flag.
87                                                    # A lot of variables are also exported to SHOW STATUS.  I have named them the
88                                                    # same where possible, by comparing the sources in srv_export_innodb_status()
89                                                    # and looking at where the InnoDB status is printed from.
90                                                    my ( $COLS, $PATTERN ) = (0, 1);
91                                                    my %parse_rules_for = (
92                                                    
93                                                       # Google patches
94                                                       "BACKGROUND THREAD" => {
95                                                          rules => [
96                                                             [
97                                                                [qw(
98                                                                   Innodb_srv_main_1_second_loops
99                                                                   Innodb_srv_main_sleeps
100                                                                  Innodb_srv_main_10_second_loops
101                                                                  Innodb_srv_main_background_loops
102                                                                  Innodb_srv_main_flush_loops
103                                                               )],
104                                                               qr/^srv_master_thread loops: $d 1_second, $d sleeps, $d 10_second, $d background, $d flush$/m,
105                                                            ],
106                                                            [
107                                                               [qw(
108                                                                  Innodb_srv_sync_flush
109                                                                  Innodb_srv_async_flush
110                                                               )],
111                                                               qr/^srv_master_thread log flush: $d sync, $d async$/m,
112                                                            ],
113                                                            [
114                                                               [qw(
115                                                                  Innodb_flush_from_dirty_buffer
116                                                                  Innodb_flush_from_other
117                                                                  Innodb_flush_from_checkpoint
118                                                                  Innodb_flush_from_log_io_complete
119                                                                  Innodb_flush_from_log_write_up_to
120                                                                  Innodb_flush_from_archive
121                                                               )],
122                                                               qr/^fsync callers: $d buffer pool, $d other, $d checkpoint, $d log aio, $d log sync, $d archive$/m,
123                                                            ],
124                                                         ],
125                                                         customcode => sub{},
126                                                      },
127                                                   
128                                                      "SEMAPHORES" => {
129                                                         rules => [
130                                                            # Google patches
131                                                            [
132                                                               [qw(
133                                                                  Innodb_lock_wait_timeouts
134                                                               )],
135                                                               qr/^Lock wait timeouts $d$/m,
136                                                            ],
137                                                            [
138                                                               [qw(
139                                                                  Innodb_wait_array_reservation_count
140                                                                  Innodb_wait_array_signal_count
141                                                               )],
142                                                               qr/^OS WAIT ARRAY INFO: reservation count $d, signal count $d$/m,
143                                                            ],
144                                                            [
145                                                               [qw(
146                                                                  Innodb_mutex_spin_waits
147                                                                  Innodb_mutex_spin_rounds
148                                                                  Innodb_mutex_os_waits
149                                                               )],
150                                                               qr/^Mutex spin waits $d, rounds $d, OS waits $d$/m,
151                                                            ],
152                                                            [
153                                                               [qw(
154                                                                  Innodb_mutex_rw_shared_spins
155                                                                  Innodb_mutex_rw_shared_os_waits
156                                                                  Innodb_mutex_rw_excl_spins
157                                                                  Innodb_mutex_rw_excl_os_waits
158                                                               )],
159                                                               qr/^RW-shared spins $d, OS waits $d; RW-excl spins $d, OS waits $d$/m,
160                                                            ],
161                                                         ],
162                                                         customcode => sub {},
163                                                      },
164                                                   
165                                                      'LATEST FOREIGN KEY ERROR' => {
166                                                         rules => [
167                                                            [
168                                                               [qw(
169                                                                  Innodb_fk_time
170                                                               )],
171                                                               qr/^$s/m,
172                                                            ],
173                                                            [
174                                                               [qw(
175                                                                  Innodb_fk_child_db
176                                                                  Innodb_fk_child_table
177                                                               )],
178                                                               qr{oreign key constraint (?:fails for|of) table `?(.*?)`?/`?(.*?)`?:$}m,
179                                                            ],
180                                                            [
181                                                               [qw(
182                                                                  Innodb_fk_name
183                                                                  Innodb_fk_child_cols
184                                                                  Innodb_fk_parent_db
185                                                                  Innodb_fk_parent_table
186                                                                  Innodb_fk_parent_cols
187                                                               )],
188                                                               qr/CONSTRAINT `?$n`? FOREIGN KEY \((.+?)\) REFERENCES (?:`?$n`?\.)?`?$n`? \((.+?)\)/m,
189                                                            ],
190                                                            [
191                                                               [qw(
192                                                                  Innodb_fk_child_index
193                                                               )],
194                                                               qr/(?:in child table, in index|foreign key in table is) `?$n`?/m,
195                                                            ],
196                                                            [
197                                                               [qw(
198                                                                  Innodb_fk_parent_index
199                                                               )],
200                                                               qr/in parent table \S+ in index `$n`/m,
201                                                            ],
202                                                         ],
203                                                         customcode => sub {
204                                                            my ( $status, $text ) = @_;
205                                                            if ( $status->{Innodb_fk_time} ) {
206                                                               $status->{Innodb_fk_time} = ts_to_time($status->{Innodb_fk_time});
207                                                            }
208                                                            $status->{Innodb_fk_parent_db} ||= $status->{Innodb_fk_child_db};
209                                                            if ( $text =~ m/^there is no index/m ) {
210                                                               $status->{Innodb_fk_reason} = 'No index or type mismatch';
211                                                            }
212                                                            elsif ( $text =~ m/closest match we can find/ ) {
213                                                               $status->{Innodb_fk_reason} = 'No matching row';
214                                                            }
215                                                            elsif ( $text =~ m/, there is a record/ ) {
216                                                               $status->{Innodb_fk_reason} = 'Orphan row';
217                                                            }
218                                                            elsif ( $text =~ m/Cannot resolve table name|nor its .ibd file/ ) {
219                                                               $status->{Innodb_fk_reason} = 'No such parent table';
220                                                            }
221                                                            elsif ( $text =~ m/Cannot (?:DISCARD|drop)/ ) {
222                                                               $status->{Innodb_fk_reason} = 'Table is referenced';
223                                                               @{$status}{qw(
224                                                                  Innodb_fk_parent_db Innodb_fk_parent_table
225                                                                  Innodb_fk_child_db Innodb_fk_child_table
226                                                               )}
227                                                               = $text =~ m{table `$n/$n`\nbecause it is referenced by `$n/$n`};
228                                                            }
229                                                         },
230                                                      },
231                                                   
232                                                      'LATEST DETECTED DEADLOCK' => {
233                                                         rules => [
234                                                            [
235                                                               [qw(
236                                                                  Innodb_deadlock_time
237                                                               )],
238                                                               qr/^$s$/m,
239                                                            ],
240                                                         ],
241                                                         customcode => sub {
242                                                            my ( $status, $text ) = @_;
243                                                            if ( $status->{Innodb_deadlock_time} ) {
244                                                               $status->{Innodb_deadlock_time}
245                                                                  = ts_to_time($status->{Innodb_deadlock_time});
246                                                            }
247                                                         },
248                                                      },
249                                                   
250                                                      'TRANSACTIONS' => {
251                                                         rules => [
252                                                            [
253                                                               [qw(Innodb_transaction_counter)],
254                                                               qr/^Trx id counter $t$/m,
255                                                            ],
256                                                            [
257                                                               [qw(
258                                                                  Innodb_purged_to
259                                                                  Innodb_undo_log_record
260                                                               )],
261                                                               qr/^Purge done for trx's n:o < $t undo n:o < $t$/m,
262                                                            ],
263                                                            [
264                                                               [qw(Innodb_history_list_length)],
265                                                               qr/^History list length $d$/m,
266                                                            ],
267                                                            [
268                                                               [qw(Innodb_lock_struct_count)],
269                                                               qr/^Total number of lock structs in row lock hash table $d$/m,
270                                                            ],
271                                                         ],
272                                                         customcode => sub {
273                                                            my ( $status, $text ) = @_;
274                                                            $status->{Innodb_transactions_truncated}
275                                                               = $text =~ m/^\.\.\. truncated\.\.\.$/m ? 1 : 0;
276                                                            my @txns = $text =~ m/(^---TRANSACTION)/mg;
277                                                            $status->{Innodb_transactions} = scalar(@txns);
278                                                         },
279                                                      },
280                                                   
281                                                      # See os_aio_print() in os0file.c
282                                                      'FILE I/O' => {
283                                                         rules => [
284                                                            [
285                                                               [qw(
286                                                                  Innodb_pending_aio_reads
287                                                                  Innodb_pending_aio_writes
288                                                               )],
289                                                               qr/^Pending normal aio reads: $d, aio writes: $d,$/m,
290                                                            ],
291                                                            [
292                                                               [qw(
293                                                                  Innodb_insert_buffer_pending_reads
294                                                                  Innodb_log_pending_io
295                                                                  Innodb_pending_sync_io
296                                                               )],
297                                                               qr{^ ibuf aio reads: $d, log i/o's: $d, sync i/o's: $d$}m,
298                                                            ],
299                                                            [
300                                                               [qw(
301                                                                  Innodb_os_log_pending_fsyncs
302                                                                  Innodb_buffer_pool_pending_fsyncs
303                                                               )],
304                                                               qr/^Pending flushes \(fsync\) log: $d; buffer pool: $d$/m,
305                                                            ],
306                                                            [
307                                                               [qw(
308                                                                  Innodb_data_reads
309                                                                  Innodb_data_writes
310                                                                  Innodb_data_fsyncs
311                                                               )],
312                                                               qr/^$d OS file reads, $d OS file writes, $d OS fsyncs$/m,
313                                                            ],
314                                                            [
315                                                               [qw(
316                                                                  Innodb_data_reads_sec
317                                                                  Innodb_data_bytes_per_read
318                                                                  Innodb_data_writes_sec
319                                                                  Innodb_data_fsyncs_sec
320                                                               )],
321                                                               qr{^$f reads/s, $d avg bytes/read, $f writes/s, $f fsyncs/s$}m,
322                                                            ],
323                                                            [
324                                                               [qw(
325                                                                  Innodb_data_pending_preads
326                                                                  Innodb_data_pending_pwrites
327                                                               )],
328                                                               qr/$d pending preads, $d pending pwrites$/m,
329                                                            ],
330                                                         ],
331                                                         customcode => sub {
332                                                            my ( $status, $text ) = @_;
333                                                            my @thds = $text =~ m/^I.O thread $d state:/gm;
334                                                            $status->{Innodb_num_io_threads} = scalar(@thds);
335                                                            # To match the output of SHOW STATUS:
336                                                            $status->{Innodb_data_pending_fsyncs}
337                                                               = $status->{Innodb_os_log_pending_fsyncs}
338                                                               + $status->{Innodb_buffer_pool_pending_fsyncs};
339                                                         },
340                                                      },
341                                                   
342                                                      # See srv_printf_innodb_monitor() in storage/innobase/srv/srv0srv.c and
343                                                      # ibuf_print() in storage/innobase/ibuf/ibuf0ibuf.c
344                                                      'INSERT BUFFER AND ADAPTIVE HASH INDEX' => {
345                                                         rules => [
346                                                            [
347                                                               [qw(
348                                                                  Innodb_insert_buffer_size
349                                                                  Innodb_insert_buffer_free_list_length
350                                                                  Innodb_insert_buffer_segment_size
351                                                               )],
352                                                               qr/^Ibuf(?: for space 0)?: size $d, free list len $d, seg size $d,$/m,
353                                                            ],
354                                                            [
355                                                               [qw(
356                                                                  Innodb_insert_buffer_inserts
357                                                                  Innodb_insert_buffer_merged_records
358                                                                  Innodb_insert_buffer_merges
359                                                               )],
360                                                               qr/^$d inserts, $d merged recs, $d merges$/m,
361                                                            ],
362                                                            [
363                                                               [qw(
364                                                                  Innodb_hash_table_size
365                                                                  Innodb_hash_table_used_cells
366                                                                  Innodb_hash_table_buf_frames_reserved
367                                                               )],
368                                                               qr/^Hash table size $d, used cells $d, node heap has $d buffer\(s\)$/m,
369                                                            ],
370                                                            [
371                                                               [qw(
372                                                                  Innodb_hash_searches_sec
373                                                                  Innodb_nonhash_searches_sec
374                                                               )],
375                                                               qr{^$f hash searches/s, $f non-hash searches/s$}m,
376                                                            ],
377                                                         ],
378                                                         customcode => sub {},
379                                                      },
380                                                   
381                                                      # See log_print() in storage/innobase/log/log0log.c
382                                                      'LOG' => {
383                                                         rules => [
384                                                            [
385                                                               [qw(
386                                                                  Innodb_log_sequence_no
387                                                               )],
388                                                               qr/Log sequence number \s*(\d.*)$/m,
389                                                            ],
390                                                            [
391                                                               [qw(
392                                                                  Innodb_log_flushed_to
393                                                               )],
394                                                               qr/Log flushed up to \s*(\d.*)$/m,
395                                                            ],
396                                                            [
397                                                               [qw(
398                                                                  Innodb_log_last_checkpoint
399                                                               )],
400                                                               qr/Last checkpoint at \s*(\d.*)$/m,
401                                                            ],
402                                                            [
403                                                               [qw(
404                                                                  Innodb_log_pending_writes
405                                                                  Innodb_log_pending_chkp_writes
406                                                               )],
407                                                               qr/$d pending log writes, $d pending chkp writes/m,
408                                                            ],
409                                                            [
410                                                               [qw(
411                                                                  Innodb_log_ios
412                                                                  Innodb_log_ios_sec
413                                                               )],
414                                                               qr{$d log i/o's done, $f log i/o's/second}m,
415                                                            ],
416                                                            # Google patches
417                                                            [
418                                                               [qw(
419                                                                  Innodb_log_caller_write_buffer_pool
420                                                                  Innodb_log_caller_write_background_sync
421                                                                  Innodb_log_caller_write_background_async
422                                                                  Innodb_log_caller_write_internal
423                                                                  Innodb_log_caller_write_checkpoint_sync
424                                                                  Innodb_log_caller_write_checkpoint_async
425                                                                  Innodb_log_caller_write_log_archive
426                                                                  Innodb_log_caller_write_commit_sync
427                                                                  Innodb_log_caller_write_commit_async
428                                                               )],
429                                                               qr/^log sync callers: $d buffer pool, background $d sync and $d async, $d internal, checkpoint $d sync and $d async, $d archive, commit $d sync and $d async$/m,
430                                                            ],
431                                                            [
432                                                               [qw(
433                                                                  Innodb_log_syncer_write_buffer_pool
434                                                                  Innodb_log_syncer_write_background_sync
435                                                                  Innodb_log_syncer_write_background_async
436                                                                  Innodb_log_syncer_write_internal
437                                                                  Innodb_log_syncer_write_checkpoint_sync
438                                                                  Innodb_log_syncer_write_checkpoint_async
439                                                                  Innodb_log_syncer_write_log_archive
440                                                                  Innodb_log_syncer_write_commit_sync
441                                                                  Innodb_log_syncer_write_commit_async
442                                                               )],
443                                                               qr/^log sync syncers: $d buffer pool, background $d sync and $d async, $d internal, checkpoint $d sync and $d async, $d archive, commit $d sync and $d async$/m,
444                                                            ],
445                                                         ],
446                                                         customcode => sub {},
447                                                      },
448                                                   
449                                                      # See srv_printf_innodb_monitor().
450                                                      'BUFFER POOL AND MEMORY' => {
451                                                         rules => [
452                                                            [
453                                                               [qw(
454                                                                  Innodb_total_memory_allocated
455                                                                  Innodb_common_memory_allocated
456                                                               )],
457                                                               qr/^Total memory allocated $d; in additional pool allocated $d$/m,
458                                                            ],
459                                                            [
460                                                               [qw(
461                                                                  Innodb_dictionary_memory_allocated
462                                                               )],
463                                                               qr/Dictionary memory allocated $d/m,
464                                                            ],
465                                                            [
466                                                               [qw(
467                                                                  Innodb_awe_memory_allocated
468                                                               )],
469                                                               qr/$d MB of AWE memory/m,
470                                                            ],
471                                                            [
472                                                               [qw(
473                                                                  Innodb_buffer_pool_awe_memory_frames
474                                                               )],
475                                                               qr/AWE: Buffer pool memory frames\s+$d/m,
476                                                            ],
477                                                            [
478                                                               [qw(
479                                                                  Innodb_buffer_pool_awe_mapped
480                                                               )],
481                                                               qr/AWE: Database pages and free buffers mapped in frames\s+$d/m,
482                                                            ],
483                                                            [
484                                                               [qw(
485                                                                  Innodb_buffer_pool_pages_total
486                                                               )],
487                                                               qr/^Buffer pool size\s*$d$/m,
488                                                            ],
489                                                            [
490                                                               [qw(
491                                                                  Innodb_buffer_pool_pages_free
492                                                               )],
493                                                               qr/^Free buffers\s*$d$/m,
494                                                            ],
495                                                            [
496                                                               [qw(
497                                                                  Innodb_buffer_pool_pages_data
498                                                               )],
499                                                               qr/^Database pages\s*$d$/m,
500                                                            ],
501                                                            [
502                                                               [qw(
503                                                                  Innodb_buffer_pool_pages_dirty
504                                                               )],
505                                                               qr/^Modified db pages\s*$d$/m,
506                                                            ],
507                                                            [
508                                                               [qw(
509                                                                  Innodb_buffer_pool_pending_reads
510                                                               )],
511                                                               qr/^Pending reads $d$/m,
512                                                            ],
513                                                            [
514                                                               [qw(
515                                                                  Innodb_buffer_pool_pending_data_writes
516                                                                  Innodb_buffer_pool_pending_dirty_writes
517                                                                  Innodb_buffer_pool_pending_single_writes
518                                                               )],
519                                                               qr/Pending writes: LRU $d, flush list $d, single page $d/m,
520                                                            ],
521                                                            [
522                                                               [qw(
523                                                                  Innodb_buffer_pool_pages_read
524                                                                  Innodb_buffer_pool_pages_created
525                                                                  Innodb_buffer_pool_pages_written
526                                                               )],
527                                                               qr/^Pages read $d, created $d, written $d$/m,
528                                                            ],
529                                                            [
530                                                               [qw(
531                                                                  Innodb_buffer_pool_pages_read_sec
532                                                                  Innodb_buffer_pool_pages_created_sec
533                                                                  Innodb_buffer_pool_pages_written_sec
534                                                               )],
535                                                               qr{^$f reads/s, $f creates/s, $f writes/s$}m,
536                                                            ],
537                                                            [
538                                                               [qw(
539                                                                  Innodb_buffer_pool_awe_pages_remapped_sec
540                                                               )],
541                                                               qr{^AWE: $f page remaps/s$}m,
542                                                            ],
543                                                            [
544                                                               [qw(
545                                                                  Innodb_buffer_pool_hit_rate
546                                                               )],
547                                                               qr/^Buffer pool hit rate $d/m,
548                                                            ],
549                                                         ],
550                                                         customcode => sub {
551                                                            my ( $status, $text ) = @_;
552                                                            if ( defined $status->{Innodb_buffer_pool_hit_rate} ) {
553                                                               $status->{Innodb_buffer_pool_hit_rate} /= 1000;
554                                                            }
555                                                            else {
556                                                               $status->{Innodb_buffer_pool_hit_rate} = 1;
557                                                            }
558                                                         },
559                                                      },
560                                                   
561                                                      'ROW OPERATIONS' => {
562                                                         rules => [
563                                                            [
564                                                               [qw(
565                                                                  Innodb_threads_inside_kernel
566                                                                  Innodb_threads_queued
567                                                               )],
568                                                               qr/^$d queries inside InnoDB, $d queries in queue$/m,
569                                                            ],
570                                                            [
571                                                               [qw(
572                                                                  Innodb_read_views_open
573                                                               )],
574                                                               qr/^$d read views open inside InnoDB$/m,
575                                                            ],
576                                                            [
577                                                               [qw(
578                                                                  Innodb_reserved_extent_count
579                                                               )],
580                                                               qr/^$d tablespace extents now reserved for B-tree/m,
581                                                            ],
582                                                            [
583                                                               [qw(
584                                                                  Innodb_main_thread_proc_no
585                                                                  Innodb_main_thread_id
586                                                                  Innodb_main_thread_state
587                                                               )],
588                                                               qr/^Main thread (?:process no. $d, )?id $d, state: (.*)$/m,
589                                                            ],
590                                                            [
591                                                               [qw(
592                                                                  Innodb_rows_inserted
593                                                                  Innodb_rows_updated
594                                                                  Innodb_rows_deleted
595                                                                  Innodb_rows_read
596                                                               )],
597                                                               qr/^Number of rows inserted $d, updated $d, deleted $d, read $d$/m,
598                                                            ],
599                                                            [
600                                                               [qw(
601                                                                  Innodb_rows_inserted_sec
602                                                                  Innodb_rows_updated_sec
603                                                                  Innodb_rows_deleted_sec
604                                                                  Innodb_rows_read_sec
605                                                               )],
606                                                               qr{^$f inserts/s, $f updates/s, $f deletes/s, $f reads/s$}m,
607                                                            ],
608                                                         ],
609                                                         customcode => sub {},
610                                                      },
611                                                   
612                                                      top_level => {
613                                                         rules => [
614                                                            [
615                                                               [qw(
616                                                                  Innodb_status_time
617                                                               )],
618                                                               qr/^$s INNODB MONITOR OUTPUT$/m,
619                                                            ],
620                                                            [
621                                                               [qw(
622                                                                  Innodb_status_interval
623                                                               )],
624                                                               qr/Per second averages calculated from the last $d seconds/m,
625                                                            ],
626                                                         ],
627                                                         customcode => sub {
628                                                            my ( $status, $text ) = @_;
629                                                            $status->{Innodb_status_time}
630                                                               = ts_to_time($status->{Innodb_status_time});
631                                                            $status->{Innodb_status_truncated}
632                                                               = $text =~ m/END OF INNODB MONITOR OUTPUT/ ? 0 : 1;
633                                                         },
634                                                      },
635                                                   
636                                                      transaction => {
637                                                         rules => [
638                                                            [
639                                                               [qw(
640                                                                  txn_id
641                                                                  txn_status
642                                                                  active_secs
643                                                                  proc_no
644                                                                  os_thread_id
645                                                               )],
646                                                               qr/^(?:---)?TRANSACTION $t, (\D*?)(?: $d sec)?, (?:process no $d, )?OS thread id $d/m,
647                                                            ],
648                                                            [
649                                                               [qw(
650                                                                  thread_status
651                                                                  tickets
652                                                               )],
653                                                               qr/OS thread id \d+(?: ([^,]+?))?(?:, thread declared inside InnoDB $d)?$/m,
654                                                            ],
655                                                            [
656                                                               [qw(
657                                                                  txn_query_status
658                                                                  lock_structs
659                                                                  heap_size
660                                                                  row_locks
661                                                                  undo_log_entries
662                                                               )],
663                                                               qr/^(?:(\D*) )?$d lock struct\(s\), heap size $d(?:, $d row lock\(s\))?(?:, undo log entries $d)?$/m,
664                                                            ],
665                                                            [
666                                                               [qw(
667                                                                  lock_wait_time
668                                                               )],
669                                                               qr/^------- TRX HAS BEEN WAITING $d SEC/m,
670                                                            ],
671                                                            [
672                                                               [qw(
673                                                                  mysql_tables_used
674                                                                  mysql_tables_locked
675                                                               )],
676                                                               qr/^mysql tables in use $d, locked $d$/m,
677                                                            ],
678                                                            [
679                                                               [qw(
680                                                                  read_view_lower_limit
681                                                                  read_view_upper_limit
682                                                               )],
683                                                               qr/^Trx read view will not see trx with id >= $t, sees < $t$/m,
684                                                            ],
685                                                            # Only a certain number of bytes of the query text are included, at least
686                                                            # under some circumstances.  Some versions include 300, some 600, some
687                                                            # 3100.
688                                                            [
689                                                               [qw(
690                                                                  query_text
691                                                               )],
692                                                               qr{
693                                                                  ^MySQL\sthread\sid\s[^\n]+\n           # This comes before the query text
694                                                                  (.*?)                                  # The query text
695                                                                  (?=                                    # Followed by any of...
696                                                                     ^Trx\sread\sview
697                                                                     |^-------\sTRX\sHAS\sBEEN\sWAITING
698                                                                     |^TABLE\sLOCK
699                                                                     |^RECORD\sLOCKS\sspace\sid
700                                                                     |^(?:---)?TRANSACTION
701                                                                     |^\*\*\*\s\(\d\)
702                                                                     |\Z
703                                                                  )
704                                                               }xms,
705                                                            ],
706                                                         ],
707                                                         customcode => sub {
708                                                            my ( $status, $text ) = @_;
709                                                            if ( $status->{query_text} ) {
710                                                               $status->{query_text} =~ s/\n*$//;
711                                                            }
712                                                         },
713                                                      },
714                                                   
715                                                      lock => {
716                                                         rules => [
717                                                            [
718                                                               [qw(
719                                                                  type space_id page_no num_bits index database table txn_id mode
720                                                               )],
721                                                               qr{^(RECORD|TABLE) LOCKS? (?:space id $d page no $d n bits $d index `?$n`? of )?table `$n(?:/|`\.`)$n` trx id $t lock.mode (\S+)}m,
722                                                            ],
723                                                            [
724                                                               [qw(
725                                                                  gap
726                                                               )],
727                                                               qr/^(?:RECORD|TABLE) .*? locks (rec but not gap|gap before rec)/m,
728                                                            ],
729                                                            [
730                                                               [qw(
731                                                                  insert_intent
732                                                               )],
733                                                               qr/^(?:RECORD|TABLE) .*? (insert intention)/m,
734                                                            ],
735                                                            [
736                                                               [qw(
737                                                                  waiting
738                                                               )],
739                                                               qr/^(?:RECORD|TABLE) .*? (waiting)/m,
740                                                            ],
741                                                         ],
742                                                         customcode => sub {
743                                                            my ( $status, $text ) = @_;
744                                                         },
745                                                      },
746                                                   
747                                                      io_thread => {
748                                                         rules => [
749                                                            [
750                                                               [qw(
751                                                                  id
752                                                                  state
753                                                                  purpose
754                                                   
755                                                                  event_set
756                                                               )],
757                                                               qr{^I/O thread $d state: (.+?) \((.*)\)}m,
758                                                            ],
759                                                            # Support for Google patches
760                                                            [
761                                                               [qw(
762                                                                  io_reads
763                                                                  io_writes
764                                                                  io_requests
765                                                                  io_wait
766                                                                  io_avg_wait
767                                                                  max_io_wait
768                                                               )],
769                                                               qr{reads $d writes $d requests $d io secs $f io msecs/request $f max_io_wait $f}m,
770                                                            ],
771                                                            [
772                                                               [qw(
773                                                                  event_set
774                                                               )],
775                                                               qr/ ev (set)/m,
776                                                            ],
777                                                         ],
778                                                         customcode => sub {
779                                                            my ( $status, $text ) = @_;
780                                                         },
781                                                      },
782                                                   
783                                                      # Depending on whether it's a SYNC_MUTEX,RW_LOCK_EX,RW_LOCK_SHARED,
784                                                      # there will be different text output
785                                                      # See sync_array_cell_print() in innobase/sync/sync0arr.c
786                                                      mutex_wait => {
787                                                         rules => [
788                                                            [
789                                                               [qw(
790                                                                  thread_id
791                                                                  mutex_file
792                                                                  mutex_line
793                                                                  wait_secs
794                                                               )],
795                                                               qr/^--Thread $d has waited at $fl for $f seconds/m,
796                                                            ],
797                                                            [
798                                                               [qw(
799                                                                  wait_has_ended
800                                                               )],
801                                                               qr/^wait has ended$/m,
802                                                            ],
803                                                            [
804                                                               [qw(
805                                                                  cell_event_set
806                                                               )],
807                                                               qr/^wait is ending$/m,
808                                                            ],
809                                                         ],
810                                                         customcode => sub {
811                                                            my ( $status, $text ) = @_;
812                                                            if ( $text =~ m/^Mutex at/m ) {
813                                                               InnoDBParser::apply_rules(undef, $status, $text, 'sync_mutex');
814                                                            }
815                                                            else {
816                                                               InnoDBParser::apply_rules(undef, $status, $text, 'rw_lock');
817                                                            }
818                                                         },
819                                                      },
820                                                   
821                                                      sync_mutex => {
822                                                         rules => [
823                                                            [
824                                                               [qw(
825                                                                  type 
826                                                                  lock_mem_addr
827                                                                  lock_cfile_name
828                                                                  lock_cline
829                                                                  lock_word
830                                                               )],
831                                                               qr/^(M)utex at $h created file $fl, lock var $d$/m,
832                                                            ],
833                                                            [
834                                                               [qw(
835                                                                  lock_file_name
836                                                                  lock_file_line
837                                                                  num_waiters
838                                                               )],
839                                                               qr/^(?:Last time reserved in file $fl, )?waiters flag $d$/m,
840                                                            ],
841                                                         ],
842                                                         customcode => sub {
843                                                            my ( $status, $text ) = @_;
844                                                         },
845                                                      },
846                                                   
847                                                      rw_lock => {
848                                                         rules => [
849                                                            [
850                                                               [qw(
851                                                                  type 
852                                                                  lock_cfile_name
853                                                                  lock_cline
854                                                               )],
855                                                               qr/^(.)-lock on RW-latch at $h created in file $fl$/m,
856                                                            ],
857                                                            [
858                                                               [qw(
859                                                                  writer_thread
860                                                                  writer_lock_mode
861                                                               )],
862                                                               qr/^a writer \(thread id $d\) has reserved it in mode  (.*)$/m,
863                                                            ],
864                                                            [
865                                                               [qw(
866                                                                  num_readers
867                                                                  num_waiters
868                                                               )],
869                                                               qr/^number of readers $d, waiters flag $d$/m,
870                                                            ],
871                                                            [
872                                                               [qw(
873                                                                  last_s_file_name
874                                                                  last_s_line
875                                                               )],
876                                                               qr/^Last time read locked in file $fl$/m,
877                                                            ],
878                                                            [
879                                                               [qw(
880                                                                  last_x_file_name
881                                                                  last_x_line
882                                                               )],
883                                                               qr/^Last time write locked in file $fl$/m,
884                                                            ],
885                                                         ],
886                                                         customcode => sub {
887                                                            my ( $status, $text ) = @_;
888                                                         },
889                                                      },
890                                                   
891                                                   );
892                                                   
893                                                   sub new {
894   ***      1                    1      0      4      my ( $class, %args ) = @_;
895            1                                 23      return bless {}, $class;
896                                                   }
897                                                   
898                                                   sub parse {
899   ***      1                    1      0     50      my ( $self, $text ) = @_;
900                                                   
901                                                      # This will end up holding a series of "tables."
902            1                                 27      my %result = (
903                                                         status                => [{}], # Non-repeating data
904                                                         deadlock_transactions => [],   # The transactions only
905                                                         deadlock_locks        => [],   # Both held and waited-for
906                                                         transactions          => [],
907                                                         transaction_locks     => [],   # Both held and waited-for
908                                                         io_threads            => [],
909                                                         mutex_waits           => [],
910                                                         insert_buffer_pages   => [],   # Only if InnoDB built with UNIV_IBUF_DEBUG
911                                                      );
912            1                                  5      my $status = $result{status}[0];
913                                                   
914                                                      # Split it into sections and stash for parsing.
915            1                                  3      my %innodb_sections;
916            1                                351      my @matches = $text
917                                                         =~ m#\n(---+)\n([A-Z /]+)\n\1\n(.*?)(?=\n(---+)\n[A-Z /]+\n\4\n|$)#gs;
918            1                                 16      while ( my ($start, $name, $section_text, $end) = splice(@matches, 0, 4) ) {
919            7                                 54         $innodb_sections{$name} = $section_text;
920                                                      }
921                                                   
922                                                      # Get top-level info about the status which isn't included in any subsection.
923            1                                  8      $self->apply_rules($status, $text, 'top_level');
924                                                   
925                                                      # Parse non-nested data in each subsection.
926            1                                  6      foreach my $section ( keys %innodb_sections ) {
927            7                                 23         my $section_text = $innodb_sections{$section};
928   ***      7     50                          29         next unless defined $section_text; # No point in trying to parse further.
929            7                                 23         $self->apply_rules($status, $section_text, $section);
930                                                      }
931                                                   
932                                                      # Now get every other table.
933   ***      1     50                           6      if ( $innodb_sections{'LATEST DETECTED DEADLOCK'} ) {
934   ***      0                                  0         @result{qw(deadlock_transactions deadlock_locks)}
935                                                            = $self->parse_deadlocks($innodb_sections{'LATEST DETECTED DEADLOCK'});
936                                                      }
937   ***      1     50                           5      if ( $innodb_sections{'INSERT BUFFER AND ADAPTIVE HASH INDEX'} ) {
938   ***      0                                  0         $result{insert_buffer_pages} = [
939                                                            map {
940            1                                  9               my %page;
941   ***      0                                  0               @page{qw(page buffer_count)}
942                                                                  = $_ =~ m/Ibuf count for page $d is $d$/;
943   ***      0                                  0               \%page;
944                                                            } $innodb_sections{'INSERT BUFFER AND ADAPTIVE HASH INDEX'}
945                                                               =~ m/(^Ibuf count for page.*$)/gs
946                                                         ];
947                                                      }
948   ***      1     50                           5      if ( $innodb_sections{'TRANSACTIONS'} ) {
949            1                                  6         $result{transactions} = [
950            1                                 28            map { $self->parse_txn($_) }
951                                                               $innodb_sections{'TRANSACTIONS'}
952                                                               =~ m/(---TRANSACTION \d.*?)(?=\n---TRANSACTION|$)/gs
953                                                         ];
954   ***      0                                  0         $result{transaction_locks} = [
955                                                            map {
956            1                                  9               my $lock = {};
957   ***      0                                  0               $self->apply_rules($lock, $_, 'lock');
958   ***      0                                  0               $lock;
959                                                            }
960                                                            $innodb_sections{'TRANSACTIONS'} =~ m/(^(?:RECORD|TABLE) LOCKS?.*$)/gm
961                                                         ];
962                                                      }
963   ***      1     50                           5      if ( $innodb_sections{'FILE I/O'} ) {
964            4                                 12         $result{io_threads} = [
965                                                            map {
966            1                                245               my $thread = {};
967            4                                 16               $self->apply_rules($thread, $_, 'io_thread');
968            4                                 15               $thread;
969                                                            }
970                                                            $innodb_sections{'FILE I/O'} =~ m{^(I/O thread \d+ .*)$}gm
971                                                         ];
972                                                      }
973   ***      1     50                           5      if ( $innodb_sections{SEMAPHORES} ) {
974   ***      0                                  0         $result{mutex_waits} = [
975                                                            map {
976            1                                  8               my $cell = {};
977   ***      0                                  0               $self->apply_rules($cell, $_, 'mutex_wait');
978   ***      0                                  0               $cell;
979                                                            }
980                                                            $innodb_sections{SEMAPHORES} =~ m/^(--Thread.*?)^(?=Mutex spin|--Thread)/gms
981                                                         ];
982                                                      }
983                                                   
984            1                                140      return \%result;
985                                                   }
986                                                   
987                                                   sub apply_rules {
988   ***     13                   13      0     63      my ($self, $hashref, $text, $rulename) = @_;
989   ***     13     50                          70      my $rules = $parse_rules_for{$rulename}
990                                                         or die "There are no parse rules for '$rulename'";
991           13                                 32      foreach my $rule ( @{$rules->{rules}} ) {
              13                                 60   
992           67                                513         @{$hashref}{ @{$rule->[$COLS]} } = $text =~ m/$rule->[$PATTERN]/m;
              67                                417   
              67                                219   
993                                                         # MKDEBUG && _d(@{$rule->[$COLS]}, $rule->[$PATTERN]);
994                                                         # MKDEBUG && _d(@{$hashref}{ @{$rule->[$COLS]} });
995                                                      }
996                                                      # Apply section-specific rules
997           13                                 64      $rules->{customcode}->($hashref, $text);
998                                                   }
999                                                   
1000                                                  sub parse_deadlocks {
1001  ***      0                    0      0      0      my ($self, $text) = @_;
1002  ***      0                                  0      my (@txns, @locks);
1003                                                  
1004  ***      0                                  0      my @sections = $text
1005                                                        =~ m{
1006                                                           ^\*{3}\s([^\n]*)  # *** (1) WAITING FOR THIS...
1007                                                           (.*?)             # Followed by anything, non-greedy
1008                                                           (?=(?:^\*{3})|\z) # Followed by another three stars or EOF
1009                                                        }gmsx;
1010                                                  
1011  ***      0                                  0      while ( my ($header, $body) = splice(@sections, 0, 2) ) {
1012  ***      0      0                           0         my ( $num, $what ) = $header =~ m/^\($d\) (.*):$/
1013                                                           or next; # For the WE ROLL BACK case
1014                                                  
1015  ***      0      0                           0         if ( $what eq 'TRANSACTION' ) {
1016  ***      0                                  0            push @txns, $self->parse_txn($body);
1017                                                        }
1018                                                        else {
1019  ***      0                                  0            my $lock = {};
1020  ***      0                                  0            $self->apply_rules($lock, $body, 'lock');
1021  ***      0                                  0            push @locks, $lock;
1022                                                        }
1023                                                     }
1024                                                  
1025  ***      0                                  0      my ( $rolled_back ) = $text =~ m/^\*\*\* WE ROLL BACK TRANSACTION \($d\)$/m;
1026  ***      0      0                           0      if ( $rolled_back ) {
1027  ***      0                                  0         $txns[ $rolled_back - 1 ]->{victim} = 1;
1028                                                     }
1029                                                  
1030  ***      0                                  0      return (\@txns, \@locks);
1031                                                  }
1032                                                  
1033                                                  sub parse_txn {
1034  ***      1                    1      0      7      my ($self, $text) = @_;
1035                                                  
1036           1                                  4      my $txn = {};
1037           1                                  8      $self->apply_rules($txn, $text, 'transaction');
1038                                                  
1039                                                     # Parsing the line that begins 'MySQL thread id' is complicated.  The only
1040                                                     # thing always in the line is the thread and query id.  See function
1041                                                     # innobase_mysql_print_thd() in InnoDB source file sql/ha_innodb.cc.
1042           1                                  9      my ( $thread_line ) = $text =~ m/^(MySQL thread id .*)$/m;
1043           1                                  5      my ( $mysql_thread_id, $query_id, $hostname, $ip, $user, $query_status );
1044                                                  
1045  ***      1     50                           5      if ( $thread_line ) {
1046                                                        # These parts can always be gotten.
1047           1                                 26         ( $mysql_thread_id, $query_id )
1048                                                           = $thread_line =~ m/^MySQL thread id $d, query id $d/m;
1049                                                  
1050                                                        # If it's a master/slave thread, "Has (read|sent) all" may be the thread's
1051                                                        # proc_info.  In these cases, there won't be any host/ip/user info
1052           1                                  4         ( $query_status ) = $thread_line =~ m/(Has (?:read|sent) all .*$)/m;
1053  ***      1     50                          11         if ( defined($query_status) ) {
      ***            50                               
1054  ***      0                                  0            $user = 'system user';
1055                                                        }
1056                                                  
1057                                                        # It may be the case that the query id is the last thing in the line.
1058                                                        elsif ( $thread_line =~ m/query id \d+ / ) {
1059                                                           # The IP address is the only non-word thing left, so it's the most
1060                                                           # useful marker for where I have to start guessing.
1061           1                                 49            ( $hostname, $ip ) = $thread_line =~ m/query id \d+(?: ([A-Za-z]\S+))? $i/m;
1062  ***      1     50                           5            if ( defined $ip ) {
1063  ***      0                                  0               ( $user, $query_status ) = $thread_line =~ m/$ip $w(?: (.*))?$/;
1064                                                           }
1065                                                           else { # OK, there wasn't an IP address.
1066                                                              # There might not be ANYTHING except the query status.
1067           1                                  8               ( $query_status ) = $thread_line =~ m/query id \d+ (.*)$/;
1068  ***      1     50     33                   20               if ( $query_status !~ m/^\w+ing/ && !exists($is_proc_info{$query_status}) ) {
1069                                                                 # The remaining tokens are, in order: hostname, user, query_status.
1070                                                                 # It's basically impossible to know which is which.
1071           1                                 33                  ( $hostname, $user, $query_status ) = $thread_line
1072                                                                    =~ m/query id \d+(?: ([A-Za-z]\S+))?(?: $w(?: (.*))?)?$/m;
1073                                                              }
1074                                                              else {
1075  ***      0                                  0                  $user = 'system user';
1076                                                              }
1077                                                           }
1078                                                        }
1079                                                     }
1080                                                  
1081           1                                  6      @{$txn}{qw(mysql_thread_id query_id hostname ip user query_status)}
               1                                  8   
1082                                                        = ( $mysql_thread_id, $query_id, $hostname, $ip, $user, $query_status);
1083                                                  
1084           1                                  7      return $txn;
1085                                                  }
1086                                                  
1087                                                  sub _d {
1088  ***      0                    0                    my ($package, undef, $line) = caller 0;
1089  ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
1090  ***      0                                              map { defined $_ ? $_ : 'undef' }
1091                                                          @_;
1092  ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
1093                                                  }
1094                                                  
1095                                                  1;
1096                                                  
1097                                                  # ###########################################################################
1098                                                  # End InnoDBStatusParser package
1099                                                  # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
928   ***     50      0      7   unless defined $section_text
933   ***     50      0      1   if ($innodb_sections{'LATEST DETECTED DEADLOCK'})
937   ***     50      1      0   if ($innodb_sections{'INSERT BUFFER AND ADAPTIVE HASH INDEX'})
948   ***     50      1      0   if ($innodb_sections{'TRANSACTIONS'})
963   ***     50      1      0   if ($innodb_sections{'FILE I/O'})
973   ***     50      1      0   if ($innodb_sections{'SEMAPHORES'})
989   ***     50      0     13   unless my $rules = $parse_rules_for{$rulename}
1012  ***      0      0      0   unless my($num, $what) = $header =~ /^\($d\) (.*):$/
1015  ***      0      0      0   if ($what eq 'TRANSACTION') { }
1026  ***      0      0      0   if ($rolled_back)
1045  ***     50      1      0   if ($thread_line)
1053  ***     50      0      1   if (defined $query_status) { }
      ***     50      1      0   elsif ($thread_line =~ /query id \d+ /) { }
1062  ***     50      0      1   if (defined $ip) { }
1068  ***     50      1      0   if (not $query_status =~ /^\w+ing/ and not exists $is_proc_info{$query_status}) { }
1089  ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
1068  ***     33      0      0      1   not $query_status =~ /^\w+ing/ and not exists $is_proc_info{$query_status}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
29    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine      Count Pod Location                                                  
--------------- ----- --- ----------------------------------------------------------
BEGIN               1     /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:24  
BEGIN               1     /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:25  
BEGIN               1     /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:27  
BEGIN               1     /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:29  
apply_rules        13   0 /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:988 
new                 1   0 /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:894 
parse               1   0 /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:899 
parse_txn           1   0 /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:1034
ts_to_time          1   0 /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:46  

Uncovered Subroutines
---------------------

Subroutine      Count Pod Location                                                  
--------------- ----- --- ----------------------------------------------------------
_d                  0     /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:1088
parse_deadlocks     0   0 /home/daniel/dev/maatkit/common/InnoDBStatusParser.pm:1001


InnoDBStatusParser.t

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
               1                                  2   
               1                                  5   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 2;
               1                                  2   
               1                                  9   
13                                                    
14             1                    1            12   use InnoDBStatusParser;
               1                                  3   
               1                                 18   
15             1                    1            14   use MaatkitTest;
               1                                  6   
               1                                 40   
16                                                    
17             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  7   
18             1                                  5   $Data::Dumper::Indent    = 1;
19             1                                  4   $Data::Dumper::Sortkeys  = 1;
20             1                                  3   $Data::Dumper::Quotekeys = 0;
21                                                    
22             1                                  8   my $is = new InnoDBStatusParser();
23             1                                 10   isa_ok($is, 'InnoDBStatusParser');
24                                                    
25                                                    # Very basic status on quiet sandbox server.
26             1                                 10   is_deeply(
27                                                       $is->parse(load_file('common/t/samples/is001.txt')),
28                                                          {
29                                                            deadlock_locks => [],
30                                                            deadlock_transactions => [],
31                                                            insert_buffer_pages => [],
32                                                            io_threads => [
33                                                              {
34                                                                event_set => undef,
35                                                                id => '0',
36                                                                io_avg_wait => undef,
37                                                                io_reads => undef,
38                                                                io_requests => undef,
39                                                                io_wait => undef,
40                                                                io_writes => undef,
41                                                                max_io_wait => undef,
42                                                                purpose => 'insert buffer thread',
43                                                                state => 'waiting for i/o request'
44                                                              },
45                                                              {
46                                                                event_set => undef,
47                                                                id => '1',
48                                                                io_avg_wait => undef,
49                                                                io_reads => undef,
50                                                                io_requests => undef,
51                                                                io_wait => undef,
52                                                                io_writes => undef,
53                                                                max_io_wait => undef,
54                                                                purpose => 'log thread',
55                                                                state => 'waiting for i/o request'
56                                                              },
57                                                              {
58                                                                event_set => undef,
59                                                                id => '2',
60                                                                io_avg_wait => undef,
61                                                                io_reads => undef,
62                                                                io_requests => undef,
63                                                                io_wait => undef,
64                                                                io_writes => undef,
65                                                                max_io_wait => undef,
66                                                                purpose => 'read thread',
67                                                                state => 'waiting for i/o request'
68                                                              },
69                                                              {
70                                                                event_set => undef,
71                                                                id => '3',
72                                                                io_avg_wait => undef,
73                                                                io_reads => undef,
74                                                                io_requests => undef,
75                                                                io_wait => undef,
76                                                                io_writes => undef,
77                                                                max_io_wait => undef,
78                                                                purpose => 'write thread',
79                                                                state => 'waiting for i/o request'
80                                                              }
81                                                            ],
82                                                            mutex_waits => [],
83                                                            status => [
84                                                              {
85                                                                Innodb_awe_memory_allocated => undef,
86                                                                Innodb_buffer_pool_awe_mapped => undef,
87                                                                Innodb_buffer_pool_awe_memory_frames => undef,
88                                                                Innodb_buffer_pool_awe_pages_remapped_sec => undef,
89                                                                Innodb_buffer_pool_hit_rate => '1',
90                                                                Innodb_buffer_pool_pages_created => '178',
91                                                                Innodb_buffer_pool_pages_created_sec => '0.00',
92                                                                Innodb_buffer_pool_pages_data => '178',
93                                                                Innodb_buffer_pool_pages_dirty => '0',
94                                                                Innodb_buffer_pool_pages_free => '333',
95                                                                Innodb_buffer_pool_pages_read => '0',
96                                                                Innodb_buffer_pool_pages_read_sec => '0.00',
97                                                                Innodb_buffer_pool_pages_total => '512',
98                                                                Innodb_buffer_pool_pages_written => '189',
99                                                                Innodb_buffer_pool_pages_written_sec => '0.43',
100                                                               Innodb_buffer_pool_pending_data_writes => '0',
101                                                               Innodb_buffer_pool_pending_dirty_writes => '0',
102                                                               Innodb_buffer_pool_pending_fsyncs => 0,
103                                                               Innodb_buffer_pool_pending_reads => '0',
104                                                               Innodb_buffer_pool_pending_single_writes => '0',
105                                                               Innodb_common_memory_allocated => '675584',
106                                                               Innodb_data_bytes_per_read => '0',
107                                                               Innodb_data_fsyncs => '16',
108                                                               Innodb_data_fsyncs_sec => '0.08',
109                                                               Innodb_data_pending_fsyncs => 0,
110                                                               Innodb_data_pending_preads => undef,
111                                                               Innodb_data_pending_pwrites => undef,
112                                                               Innodb_data_reads => '0',
113                                                               Innodb_data_reads_sec => '0.00',
114                                                               Innodb_data_writes => '38',
115                                                               Innodb_data_writes_sec => '0.14',
116                                                               Innodb_dictionary_memory_allocated => undef,
117                                                               Innodb_hash_searches_sec => '0.00',
118                                                               Innodb_hash_table_buf_frames_reserved => '1',
119                                                               Innodb_hash_table_size => '17393',
120                                                               Innodb_hash_table_used_cells => '0',
121                                                               Innodb_history_list_length => '0',
122                                                               Innodb_insert_buffer_free_list_length => '0',
123                                                               Innodb_insert_buffer_inserts => '0',
124                                                               Innodb_insert_buffer_merged_records => '0',
125                                                               Innodb_insert_buffer_merges => '0',
126                                                               Innodb_insert_buffer_pending_reads => '0',
127                                                               Innodb_insert_buffer_segment_size => '2',
128                                                               Innodb_insert_buffer_size => '1',
129                                                               Innodb_lock_struct_count => '0',
130                                                               Innodb_lock_wait_timeouts => undef,
131                                                               Innodb_log_caller_write_background_async => undef,
132                                                               Innodb_log_caller_write_background_sync => undef,
133                                                               Innodb_log_caller_write_buffer_pool => undef,
134                                                               Innodb_log_caller_write_checkpoint_async => undef,
135                                                               Innodb_log_caller_write_checkpoint_sync => undef,
136                                                               Innodb_log_caller_write_commit_async => undef,
137                                                               Innodb_log_caller_write_commit_sync => undef,
138                                                               Innodb_log_caller_write_internal => undef,
139                                                               Innodb_log_caller_write_log_archive => undef,
140                                                               Innodb_log_flushed_to => '0 43655',
141                                                               Innodb_log_ios => '11',
142                                                               Innodb_log_ios_sec => '0.03',
143                                                               Innodb_log_last_checkpoint => '0 43655',
144                                                               Innodb_log_pending_chkp_writes => '0',
145                                                               Innodb_log_pending_io => '0',
146                                                               Innodb_log_pending_writes => '0',
147                                                               Innodb_log_sequence_no => '0 43655',
148                                                               Innodb_log_syncer_write_background_async => undef,
149                                                               Innodb_log_syncer_write_background_sync => undef,
150                                                               Innodb_log_syncer_write_buffer_pool => undef,
151                                                               Innodb_log_syncer_write_checkpoint_async => undef,
152                                                               Innodb_log_syncer_write_checkpoint_sync => undef,
153                                                               Innodb_log_syncer_write_commit_async => undef,
154                                                               Innodb_log_syncer_write_commit_sync => undef,
155                                                               Innodb_log_syncer_write_internal => undef,
156                                                               Innodb_log_syncer_write_log_archive => undef,
157                                                               Innodb_main_thread_id => '140284306659664',
158                                                               Innodb_main_thread_proc_no => '4257',
159                                                               Innodb_main_thread_state => 'waiting for server activity',
160                                                               Innodb_mutex_os_waits => '0',
161                                                               Innodb_mutex_rw_excl_os_waits => '0',
162                                                               Innodb_mutex_rw_excl_spins => '0',
163                                                               Innodb_mutex_rw_shared_os_waits => '7',
164                                                               Innodb_mutex_rw_shared_spins => '14',
165                                                               Innodb_mutex_spin_rounds => '2',
166                                                               Innodb_mutex_spin_waits => '0',
167                                                               Innodb_nonhash_searches_sec => '0.00',
168                                                               Innodb_num_io_threads => 4,
169                                                               Innodb_os_log_pending_fsyncs => 0,
170                                                               Innodb_pending_aio_reads => '0',
171                                                               Innodb_pending_aio_writes => '0',
172                                                               Innodb_pending_sync_io => '0',
173                                                               Innodb_purged_to => '0 0',
174                                                               Innodb_read_views_open => '1',
175                                                               Innodb_reserved_extent_count => undef,
176                                                               Innodb_rows_deleted => '0',
177                                                               Innodb_rows_deleted_sec => '0.00',
178                                                               Innodb_rows_inserted => '0',
179                                                               Innodb_rows_inserted_sec => '0.00',
180                                                               Innodb_rows_read => '0',
181                                                               Innodb_rows_read_sec => '0.00',
182                                                               Innodb_rows_updated => '0',
183                                                               Innodb_rows_updated_sec => '0.00',
184                                                               Innodb_status_interval => '37',
185                                                               Innodb_status_time => '2009-07-07 13:18:38',
186                                                               Innodb_status_truncated => 0,
187                                                               Innodb_threads_inside_kernel => '0',
188                                                               Innodb_threads_queued => '0',
189                                                               Innodb_total_memory_allocated => '20634452',
190                                                               Innodb_transaction_counter => '0 769',
191                                                               Innodb_transactions => 1,
192                                                               Innodb_transactions_truncated => 0,
193                                                               Innodb_undo_log_record => '0 0',
194                                                               Innodb_wait_array_reservation_count => '7',
195                                                               Innodb_wait_array_signal_count => '7'
196                                                             }
197                                                           ],
198                                                           transaction_locks => [],
199                                                           transactions => [
200                                                             {
201                                                               active_secs => undef,
202                                                               heap_size => undef,
203                                                               hostname => 'localhost',
204                                                               ip => undef,
205                                                               lock_structs => undef,
206                                                               lock_wait_time => undef,
207                                                               mysql_tables_locked => undef,
208                                                               mysql_tables_used => undef,
209                                                               mysql_thread_id => '3',
210                                                               os_thread_id => '140284242860368',
211                                                               proc_no => '4257',
212                                                               query_id => '11',
213                                                               query_status => undef,
214                                                               query_text => 'show innodb status',
215                                                               read_view_lower_limit => undef,
216                                                               read_view_upper_limit => undef,
217                                                               row_locks => undef,
218                                                               thread_status => undef,
219                                                               tickets => undef,
220                                                               txn_id => '0 0',
221                                                               txn_query_status => undef,
222                                                               txn_status => 'not started',
223                                                               undo_log_entries => undef,
224                                                               user => 'msandbox'
225                                                             }
226                                                           ]
227                                                         },
228                                                      'Basic InnoDB status'
229                                                   );
230                                                   
231                                                   # #############################################################################
232                                                   # Done.
233                                                   # #############################################################################
234            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location               
---------- ----- -----------------------
BEGIN          1 InnoDBStatusParser.t:10
BEGIN          1 InnoDBStatusParser.t:11
BEGIN          1 InnoDBStatusParser.t:12
BEGIN          1 InnoDBStatusParser.t:14
BEGIN          1 InnoDBStatusParser.t:15
BEGIN          1 InnoDBStatusParser.t:17
BEGIN          1 InnoDBStatusParser.t:4 
BEGIN          1 InnoDBStatusParser.t:9 


