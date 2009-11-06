---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/CompareResults.pm   95.0   66.9   61.5   97.3    n/a  100.0   87.8
Total                          95.0   66.9   61.5   97.3    n/a  100.0   87.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          CompareResults.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Nov  6 15:57:39 2009
Finish:       Fri Nov  6 15:57:41 2009

/home/daniel/dev/maatkit/common/CompareResults.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009-@CURRENTYEAR@ Percona Inc.
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
18                                                    # CompareResults package $Revision: 5057 $
19                                                    # ###########################################################################
20                                                    package CompareResults;
21                                                    
22             1                    1             7   use strict;
               1                                  7   
               1                                  5   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25             1                    1             6   use Time::HiRes qw(time);
               1                                  2   
               1                                  6   
26                                                    
27             1                    1             5   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                  7   
28                                                    
29             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  6   
30                                                    $Data::Dumper::Indent    = 1;
31                                                    $Data::Dumper::Sortkeys  = 1;
32                                                    $Data::Dumper::Quotekeys = 0;
33                                                    
34                                                    # Required args:
35                                                    #   * method     scalar: "checksum" or "rows"
36                                                    #   * base-dir   scalar: dir used by rows method to write outfiles
37                                                    #   * plugins    arrayref: TableSync* plugins used by rows method
38                                                    #   * get_id     coderef: used by report() to trf query to its ID
39                                                    #   * common modules
40                                                    sub new {
41             2                    2        638710      my ( $class, %args ) = @_;
42             2                                 45      my @required_args = qw(method base-dir plugins get_id
43                                                                              QueryParser MySQLDump TableParser TableSyncer Quoter);
44             2                                 29      foreach my $arg ( @required_args ) {
45    ***     18     50                         146         die "I need a $arg argument" unless $args{$arg};
46                                                       }
47             2                                 68      my $self = {
48                                                          %args,
49                                                          tmp_tbl => '',  # for checksum method
50                                                          diffs   => {},
51                                                          samples => {},
52                                                       };
53             2                                 96      return bless $self, $class;
54                                                    }
55                                                    
56                                                    # Required args:
57                                                    #   * event  hashref: an event
58                                                    #   * dbh    scalar: active dbh
59                                                    # Optional args:
60                                                    #   * db             scalar: database name to create temp table in unless...
61                                                    #   * temp-database  scalar: ...temp db name is given
62                                                    #   * temp-table     scalar: temp table name
63                                                    # Returns: hashref
64                                                    # Can die: yes
65                                                    # before_execute() drops the temp table if the method is checksum.
66                                                    # db and temp-table are required for the checksum method, but optional
67                                                    # for the rows method.
68                                                    sub before_execute {
69            14                   14          1132      my ( $self, %args ) = @_;
70            14                                116      my @required_args = qw(event dbh);
71            14                                 89      foreach my $arg ( @required_args ) {
72    ***     28     50                         232         die "I need a $arg argument" unless $args{$arg};
73                                                       }
74            14                                101      my ($event, $dbh) = @args{@required_args};
75            14                                 62      my $sql;
76                                                    
77                                                       # Clear previous tmp tbl.
78            14                                 78      $self->{tmp_tbl} = '';
79                                                    
80            14    100                         114      if ( $self->{method} eq 'checksum' ) {
81             6                                 44         my ($db, $tmp_tbl) = @args{qw(db temp-table)};
82    ***      6     50                          44         $db = $args{'temp-database'} if $args{'temp-database'};
83    ***      6     50                          37         die "Cannot checksum results without a database"
84                                                             unless $db;
85                                                    
86             6                                 70         $tmp_tbl = $self->{Quoter}->quote($db, $tmp_tbl);
87             6                                 28         eval {
88             6                                 33            $sql = "DROP TABLE IF EXISTS $tmp_tbl";
89             6                                 18            MKDEBUG && _d($sql);
90             6                               2147            $dbh->do($sql);
91                                                    
92             6                                 46            $sql = "SET storage_engine=MyISAM";
93             6                                 20            MKDEBUG && _d($sql);
94             6                                933            $dbh->do($sql);
95                                                          };
96    ***      6     50                          64         die "Failed to drop temporary table $tmp_tbl: $EVAL_ERROR"
97                                                             if $EVAL_ERROR;
98                                                    
99                                                          # Save the tmp tbl; it's used later in _compare_checksums().
100            6                                 44         $self->{tmp_tbl} = $tmp_tbl; 
101                                                   
102                                                         # Wrap the original query so when it's executed its results get
103                                                         # put in tmp table.
104            6                                 52         $event->{original_arg} = $event->{arg};
105            6                                 58         $event->{arg} = "CREATE TEMPORARY TABLE $tmp_tbl AS $event->{arg}";
106            6                                 25         MKDEBUG && _d('Wrapped query:', $event->{arg});
107                                                      }
108                                                   
109           14                                211      return $event;
110                                                   }
111                                                   
112                                                   # Required args:
113                                                   #   * event  hashref: an event
114                                                   #   * dbh    scalar: active dbh
115                                                   # Returns: hashref
116                                                   # Can die: yes
117                                                   # execute() executes the event's query.  Any prep work should have
118                                                   # been done in before_execute().  For the checksum method, this simply
119                                                   # executes the wrapped query.  For the rows method, this gets/saves
120                                                   # a statement handle for the results in the event which is processed
121                                                   # later in compare().  Both methods add the Query_time attrib to the
122                                                   # event.
123                                                   sub execute {
124           14                   14           372      my ( $self, %args ) = @_;
125           14                                107      my @required_args = qw(event dbh);
126           14                                 87      foreach my $arg ( @required_args ) {
127   ***     28     50                         235         die "I need a $arg argument" unless $args{$arg};
128                                                      }
129           14                                102      my ($event, $dbh) = @args{@required_args};
130           14                                 87      my $query         = $event->{arg};
131           14                                 65      my ( $start, $end, $query_time );
132                                                   
133           14                                 50      MKDEBUG && _d('Executing query');
134           14                                 84      $event->{Query_time} = 0;
135           14    100                         129      if ( $self->{method} eq 'rows' ) {
136            8                                 38         my $sth;
137            8                                 36         eval {
138            8                                 28            $sth = $dbh->prepare($query);
139                                                         };
140   ***      8     50                          92         die "Failed to prepare query: $EVAL_ERROR" if $EVAL_ERROR;
141                                                   
142            8                                 30         eval {
143            8                                 89            $start = time();
144            8                               2680            $sth->execute();
145            8                                 80            $end   = time();
146            8                                188            $query_time = sprintf '%.6f', $end - $start;
147                                                         };
148   ***      8     50                          60         die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
149                                                   
150            8                                 71         $event->{results_sth} = $sth;
151                                                      }
152                                                      else {
153            6                                 29         eval {
154            6                                 55            $start = time();
155            6                               8532            $dbh->do($query);
156            6                                 85            $end   = time();
157            6                                185            $query_time = sprintf '%.6f', $end - $start;
158                                                         };
159   ***      6     50                          56         die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
160                                                      }
161                                                   
162           14                                241      $event->{Query_time} = $query_time;
163                                                   
164           14                                289      return $event;
165                                                   }
166                                                   
167                                                   # Required args:
168                                                   #   * event  hashref: an event
169                                                   # Optional args:
170                                                   #   * dbh    scalar: active dbh
171                                                   # Returns: hashref
172                                                   # Can die: yes
173                                                   # after_execute() does any post-execution cleanup.  The results should
174                                                   # not be compared here; no anaylytics here, save that for compare().
175                                                   sub after_execute {
176            7                    7           129      my ( $self, %args ) = @_;
177            7                                 49      my @required_args = qw(event);
178            7                                 50      foreach my $arg ( @required_args ) {
179   ***      7     50                          67         die "I need a $arg argument" unless $args{$arg};
180                                                      }
181            7                                 45      my ($event) = @args{@required_args};
182                                                   
183            7    100                          66      if ( $self->{method} eq 'checksum' ) {
184                                                         # This shouldn't happen, unless before_execute() isn't called.
185   ***      6     50                          58         die "Failed to restore original query" unless $event->{original_arg};
186                                                   
187            6                                 39         $event->{arg} = $event->{original_arg};
188            6                                 35         delete $event->{original_arg};
189            6                                 22         MKDEBUG && _d('Unwrapped query');
190                                                      }
191                                                   
192            7                                 81      return $event;
193                                                   }
194                                                   
195                                                   # Required args:
196                                                   #   * events  arrayref: events
197                                                   #   * hosts   arrayref: hosts hashrefs with at least a dbh key
198                                                   # Returns: array
199                                                   # Can die: yes
200                                                   # compare() compares events that have been run through before_execute(),
201                                                   # execute() and after_execute().  The checksum method primarily compares
202                                                   # the checksum attribs saved in the events.  The rows method uses the
203                                                   # result statement handles saved in the events to compare rows and column
204                                                   # values.  Each method returns an array of key => value pairs which the
205                                                   # caller should aggregate into a meta-event that represents differences
206                                                   # compare() has found in these events.  Only a "summary" of differences is
207                                                   # returned.  Specific differences are saved internally and are reported
208                                                   # by calling report() later.
209                                                   sub compare {
210            7                    7           119      my ( $self, %args ) = @_;
211            7                                 65      my @required_args = qw(events hosts);
212            7                                 51      foreach my $arg ( @required_args ) {
213   ***     14     50                         130         die "I need a $arg argument" unless $args{$arg};
214                                                      }
215            7                                 53      my ($events, $hosts) = @args{@required_args};
216            7    100                         139      return $self->{method} eq 'rows' ? $self->_compare_rows(%args)
217                                                                                       : $self->_compare_checksums(%args);
218                                                   }
219                                                   
220                                                   sub _compare_checksums {
221            3                    3            25      my ( $self, %args ) = @_;
222            3                                 24      my @required_args = qw(events hosts);
223            3                                 20      foreach my $arg ( @required_args ) {
224   ***      6     50                          50         die "I need a $arg argument" unless $args{$arg};
225                                                      }
226            3                                 21      my ($events, $hosts) = @args{@required_args};
227                                                   
228            3                                 13      my $different_row_counts    = 0;
229            3                                 14      my $different_column_counts = 0; # TODO
230            3                                 11      my $different_column_types  = 0; # TODO
231            3                                 12      my $different_checksums     = 0;
232                                                   
233            3                                 16      my $n_events = scalar @$events;
234            3                                 22      foreach my $i ( 0..($n_events-1) ) {
235            6                                 87         $events->[$i] = $self->_checksum_results(
236                                                            event => $events->[$i],
237                                                            dbh   => $hosts->[$i]->{dbh},
238                                                         );
239                                                         
240            6    100                          49         if ( $i ) {
241   ***      3    100     50                   70            $different_checksums++
      ***                   50                        
242                                                               if ($events->[0]->{checksum} || 0) != ($events->[$i]->{checksum} || 0);
243   ***      3    100     50                   62            $different_row_counts++
      ***                   50                        
244                                                               if ($events->[0]->{row_count} || 0) != ($events->[$i]->{row_count} || 0);
245                                                         }
246                                                      }
247                                                   
248                                                      # Save differences.
249   ***      3            33                   34      my $item     = $events->[0]->{fingerprint} || $events->[0]->{arg};
250   ***      3            50                   31      my $sampleno = $events->[0]->{sampleno} || 0;
251            3    100                          20      if ( $different_checksums ) {
252            4                                 66         $self->{diffs}->{checksums}->{$item}->{$sampleno}
253            2                                 15            = [ map { $_->{checksum} } @$events ];
254            2                                 26         $self->{samples}->{$item}->{$sampleno} = $events->[0]->{arg};
255                                                      }
256            3    100                          21      if ( $different_row_counts ) {
257            2                                 21         $self->{diffs}->{row_counts}->{$item}->{$sampleno}
258            1                                  8            = [ map { $_->{row_count} } @$events ];
259            1                                 10         $self->{samples}->{$item}->{$sampleno} = $events->[0]->{arg};
260                                                      }
261                                                   
262                                                      return (
263            3                                 92         different_row_counts    => $different_row_counts,
264                                                         different_checksums     => $different_checksums,
265                                                         different_column_counts => $different_column_counts,
266                                                         different_column_types  => $different_column_types,
267                                                      );
268                                                   }
269                                                   
270                                                   sub _checksum_results {
271            6                    6            60      my ( $self, %args ) = @_;
272            6                                 59      my @required_args = qw(event dbh);
273            6                                 36      foreach my $arg ( @required_args ) {
274   ***     12     50                         100         die "I need a $arg argument" unless $args{$arg};
275                                                      }
276            6                                 45      my ($event, $dbh) = @args{@required_args};
277            6                                 37      my $tmp_tbl       = $self->{tmp_tbl};
278            6                                 21      my $sql;
279                                                   
280            6                                 25      my $n_rows       = 0;
281            6                                 25      my $tbl_checksum = 0;
282            6                                 29      eval {
283            6                                 65         $sql = "SELECT COUNT(*) FROM $tmp_tbl";
284            6                                 20         MKDEBUG && _d($sql);
285            6                                 31         ($n_rows) = @{ $dbh->selectcol_arrayref($sql) };
               6                                 23   
286                                                   
287            6                                 86         $sql = "CHECKSUM TABLE $tmp_tbl";
288            6                                 19         MKDEBUG && _d($sql);
289            6                                 20         $tbl_checksum = $dbh->selectrow_arrayref($sql)->[1];
290                                                      };
291   ***      6     50                        1733      if ( $EVAL_ERROR ) {
292   ***      0                                  0         MKDEBUG && _d('Error counting rows or checksumming', $tmp_tbl, ':',
293                                                            $EVAL_ERROR);
294   ***      0                                  0         return;
295                                                      }
296            6                                 45      $event->{row_count} = $n_rows;
297            6                                 37      $event->{checksum}  = $tbl_checksum;
298            6                                 19      MKDEBUG && _d('n rows:', $n_rows, 'tbl checksum:', $tbl_checksum);
299                                                   
300            6                                 31      $sql = "DROP TABLE IF EXISTS $tmp_tbl";
301            6                                 20      MKDEBUG && _d($sql);
302            6                                 25      eval { $dbh->do($sql); };
               6                               3022   
303   ***      6     50                          61      if ( $EVAL_ERROR ) {
304   ***      0                                  0         MKDEBUG && _d('Error dropping tmp table:', $EVAL_ERROR);
305   ***      0                                  0         return;
306                                                      }
307                                                   
308            6                                 97      return $event;
309                                                   }
310                                                   
311                                                   sub _compare_rows {
312            4                    4            47      my ( $self, %args ) = @_;
313            4                                 33      my @required_args = qw(events hosts);
314            4                                 26      foreach my $arg ( @required_args ) {
315   ***      8     50                          65         die "I need a $arg argument" unless $args{$arg};
316                                                      }
317            4                                 30      my ($events, $hosts) = @args{@required_args};
318                                                   
319            4                                 17      my $different_row_counts    = 0;
320            4                                 17      my $different_column_counts = 0; # TODO
321            4                                 16      my $different_column_types  = 0; # TODO
322            4                                 19      my $different_column_values = 0;
323                                                   
324            4                                 30      my $n_events = scalar @$events;
325            4                                 23      my $event0   = $events->[0]; 
326   ***      4            66                   68      my $item     = $event0->{fingerprint} || $event0->{arg};
327            4           100                   48      my $sampleno = $event0->{sampleno} || 0;
328            4                                 27      my $dbh      = $hosts->[0]->{dbh};  # doesn't matter which one
329                                                   
330            4                                 53      my $res_struct = MockSyncStream::get_result_set_struct($dbh,
331                                                         $event0->{results_sth});
332            4                                 16      MKDEBUG && _d('Result set struct:', Dumper($res_struct));
333                                                   
334                                                      # Use a mock sth so we don't have to re-execute event0 sth to compare
335                                                      # it to the 3rd and subsequent events.
336            4                                 18      my @event0_rows      = @{ $event0->{results_sth}->fetchall_arrayref({}) };
               4                                128   
337            4                                 73      $event0->{row_count} = scalar @event0_rows;
338            4                                 83      my $left = new MockSth(@event0_rows);
339            4                                 16      $left->{NAME} = [ @{$event0->{results_sth}->{NAME}} ];
               4                                 65   
340                                                   
341                                                      EVENT:
342            4                                 77      foreach my $i ( 1..($n_events-1) ) {
343            4                                 27         my $event = $events->[$i];
344            4                                 24         my $right = $event->{results_sth};
345                                                   
346            4                                 24         $event->{row_count} = 0;
347                                                   
348                                                         # Identical rows are ignored.  Once a difference on either side is found,
349                                                         # we gobble the remaining rows in that sth and print them to an outfile.
350                                                         # This short circuits RowDiff::compare_sets() which is what we want to do.
351            4                                 17         my $no_diff      = 1;  # results are identical; this catches 0 row results
352            4                                 61         my $outfile      = new Outfile();
353            4                                 20         my ($left_outfile, $right_outfile, $n_rows);
354                                                         my $same_row     = sub {
355            8                    8            37               $event->{row_count}++;  # Keep track of this event's row_count.
356            8                                 43               return;
357            4                                 58         };
358                                                         my $not_in_left  = sub {
359            3                    3            17            my ( $rr ) = @_;
360            3                                 13            $no_diff = 0;
361                                                            # $n_rows will be added later to this event's row_count.
362            3                                 41            ($right_outfile, $n_rows) = $self->write_to_outfile(
363                                                               side    => 'right',
364                                                               sth     => $right,
365                                                               row     => $rr,
366                                                               Outfile => $outfile,
367                                                            );
368            3                                 61            return;
369            4                                 49         };
370                                                         my $not_in_right = sub {
371            2                    2            12            my ( $lr ) = @_;
372            2                                  9            $no_diff = 0;
373                                                            # left is event0 so we don't need $n_rows back.
374            2                                 20            ($left_outfile, undef) = $self->write_to_outfile(
375                                                               side    => 'left',
376                                                               sth     => $left,
377                                                               row     => $lr,
378                                                               Outfile => $outfile,
379                                                            ); 
380            2                                 43            return;
381            4                                 44         };
382                                                   
383            4                                 57         my $rd       = new RowDiff(dbh => $dbh);
384            4                                 86         my $mocksync = new MockSyncStream(
385                                                            query        => $event0->{arg},
386                                                            cols         => $res_struct->{cols},
387                                                            same_row     => $same_row,
388                                                            not_in_left  => $not_in_left,
389                                                            not_in_right => $not_in_right,
390                                                         );
391                                                   
392            4                                 17         MKDEBUG && _d('Comparing result sets with MockSyncStream');
393            4                                 46         $rd->compare_sets(
394                                                            left   => $left,
395                                                            right  => $right,
396                                                            syncer => $mocksync,
397                                                            tbl    => $res_struct,
398                                                         );
399                                                   
400                                                         # Add number of rows written to outfile to this event's row_count.
401                                                         # $n_rows will be undef if there were no differences; row_count will
402                                                         # still be correct in this case because we kept track of it in $same_row.
403            4           100                   63         $event->{row_count} += $n_rows || 0;
404                                                   
405            4                                 13         MKDEBUG && _d('Left has', $event0->{row_count}, 'rows, right has',
406                                                            $event->{row_count});
407                                                   
408                                                         # Save differences.
409            4    100                          42         $different_row_counts++ if $event0->{row_count} != $event->{row_count};
410            4    100                          28         if ( $different_row_counts ) {
411            1                                 18            $self->{diffs}->{row_counts}->{$item}->{$sampleno}
412                                                               = [ $event0->{row_count}, $event->{row_count} ];
413            1                                 12            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
414                                                         }
415                                                   
416            4                                 34         $left->reset();
417            4    100                          54         next EVENT if $no_diff;
418                                                   
419                                                         # The result sets differ, so now we must begin the difficult
420                                                         # work: finding and determining the nature of those differences.
421            3                                 11         MKDEBUG && _d('Result sets are different');
422                                                   
423                                                   
424                                                         # Make sure both outfiles are created, else diff_rows() will die.
425            3    100                          23         if ( !$left_outfile ) {
426            1                                  4            MKDEBUG && _d('Right has extra rows not in left');
427            1                                  8            (undef, $left_outfile) = $self->open_outfile(side => 'left');
428                                                         }
429   ***      3     50                          18         if ( !$right_outfile ) {
430   ***      0                                  0            MKDEBUG && _d('Left has extra rows not in right');
431   ***      0                                  0            (undef, $right_outfile) = $self->open_outfile(side => 'right');
432                                                         }
433                                                   
434   ***      3            33                  135         my @diff_rows = $self->diff_rows(
435                                                            %args,             # for options like max-different-rows
436                                                            left_dbh        => $hosts->[0]->{dbh},
437                                                            left_outfile    => $left_outfile,
438                                                            right_dbh       => $hosts->[$i]->{dbh},
439                                                            right_outfile   => $right_outfile,
440                                                            res_struct      => $res_struct,
441                                                            query           => $event0->{arg},
442                                                            db              => $args{tmp_db} || $event0->{db},
443                                                         );
444                                                   
445                                                         # Save differences.
446            3    100                          50         if ( scalar @diff_rows ) { 
447            2                                  9            $different_column_values++; 
448            2                                 36            $self->{diffs}->{col_vals}->{$item}->{$sampleno} = \@diff_rows;
449            2                                 84            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
450                                                         }
451                                                      }
452                                                   
453                                                      return (
454            4                                165         different_row_counts    => $different_row_counts,
455                                                         different_column_values => $different_column_values,
456                                                         different_column_counts => $different_column_counts,
457                                                         different_column_types  => $different_column_types,
458                                                      );
459                                                   }
460                                                   
461                                                   # Required args:
462                                                   #   * left_dbh       scalar: active dbh for left
463                                                   #   * left_outfile   scalar: outfile name for left
464                                                   #   * right_dbh      scalar: active dbh for right
465                                                   #   * right_outfile  scalar: outfile name for right
466                                                   #   * res_struct     hashref: result set structure
467                                                   #   * db             scalar: database to use for creating temp tables
468                                                   #   * query          scalar: query, parsed for indexes
469                                                   # Optional args:
470                                                   #   * add-indexes         scalar: add indexes from source tables to tmp tbl
471                                                   #   * max-different-rows  scalar: stop after this many differences are found
472                                                   #   * float-precision     scalar: round float, double, decimal types to N places
473                                                   # Returns: scalar
474                                                   # Can die: no
475                                                   # diff_rows() loads and compares two result sets and returns the number of
476                                                   # differences between them.  This includes missing rows and row data
477                                                   # differences.
478                                                   sub diff_rows {
479            3                    3            67      my ( $self, %args ) = @_;
480            3                                 38      my @required_args = qw(left_dbh left_outfile right_dbh right_outfile
481                                                                             res_struct db query);
482            3                                 22      foreach my $arg ( @required_args ) {
483   ***     21     50                         156         die "I need a $arg argument" unless $args{$arg};
484                                                      }
485            3                                 35      my ($left_dbh, $left_outfile, $right_dbh, $right_outfile, $res_struct,
486                                                          $db, $query)
487                                                         = @args{@required_args};
488                                                   
489                                                      # First thing, make two temps tables into which the outfiles can
490                                                      # be loaded.  This requires that we make a CREATE TABLE statement
491                                                      # for the result sets' columns.
492            3                                 22      my $left_tbl  = "`$db`.`mk_upgrade_left`";
493            3                                 16      my $right_tbl = "`$db`.`mk_upgrade_right`";
494            3                                 29      my $table_ddl = $self->make_table_ddl($res_struct);
495                                                   
496            3                               1399      $left_dbh->do("DROP TABLE IF EXISTS $left_tbl");
497            3                             202141      $left_dbh->do("CREATE TABLE $left_tbl $table_ddl");
498            3                               3054      $left_dbh->do("LOAD DATA LOCAL INFILE '$left_outfile' "
499                                                         . "INTO TABLE $left_tbl");
500                                                   
501            3                             158892      $right_dbh->do("DROP TABLE IF EXISTS $right_tbl");
502            3                             145557      $right_dbh->do("CREATE TABLE $right_tbl $table_ddl");
503            3                               2163      $right_dbh->do("LOAD DATA LOCAL INFILE '$right_outfile' "
504                                                         . "INTO TABLE $right_tbl");
505                                                   
506            3                                 17      MKDEBUG && _d('Loaded', $left_outfile, 'into table', $left_tbl, 'and',
507                                                         $right_outfile, 'into table', $right_tbl);
508                                                   
509                                                      # Now we need to get all indexes from all tables used by the query
510                                                      # and add them to the temp tbl.  Some indexes may be invalid, dupes,
511                                                      # or generally useless, but we'll let the sync algo decide that later.
512            3    100                          40      if ( $args{'add-indexes'} ) {
513            1                                 41         $self->add_indexes(
514                                                            %args,
515                                                            dsts      => [
516                                                               { dbh => $left_dbh,  tbl => $left_tbl  },
517                                                               { dbh => $right_dbh, tbl => $right_tbl },
518                                                            ],
519                                                         );
520                                                      }
521                                                   
522                                                      # Create a RowDiff with callbacks that will do what we want when rows and
523                                                      # columns differ.  This RowDiff is passed to TableSyncer which calls it.
524                                                      # TODO: explain how these callbacks work together.
525            3           100                   64      my $max_diff = $args{'max-different-rows'} || 1_000;  # 1k=sanity/safety
526            3                                 12      my $n_diff   = 0;
527            3                                 13      my @missing_rows;  # not currently saved; row counts show missing rows
528            3                                 12      my @different_rows;
529            1                    1             8      use constant LEFT  => 0;
               1                                  3   
               1                                  5   
530            1                    1             6      use constant RIGHT => 1;
               1                                  3   
               1                                  4   
531            3                                 23      my @l_r = (undef, undef);
532            3                                 14      my @last_diff_col;
533            3                                 15      my $last_diff = 0;
534                                                      my $key_cmp      = sub {
535            3                    3            27         push @last_diff_col, [@_];
536            3                                 14         $last_diff--;
537            3                                 14         return;
538            3                                 57      };
539                                                      my $same_row = sub {
540            3                    3            21         my ( $lr, $rr ) = @_;
541   ***      3    100     66                   45         if ( $l_r[LEFT] && $l_r[RIGHT] ) {
      ***            50                               
      ***            50                               
542            2                                 15            MKDEBUG && _d('Saving different row');
543            2                                 12            push @different_rows, $last_diff_col[$last_diff];
544            2                                  8            $n_diff++;
545                                                         }
546                                                         elsif ( $l_r[LEFT] ) {
547   ***      0                                  0            MKDEBUG && _d('Saving not in right row');
548                                                            # push @missing_rows, [$l_r[LEFT], undef];
549   ***      0                                  0            $n_diff++;
550                                                         }
551                                                         elsif ( $l_r[RIGHT] ) {
552            1                                  3            MKDEBUG && _d('Saving not in left row');
553                                                            # push @missing_rows, [undef, $l_r[RIGHT]];
554            1                                  5            $n_diff++;
555                                                         }
556                                                         else {
557   ***      0                                  0            MKDEBUG && _d('No missing or different rows in queue');
558                                                         }
559            3                                 23         @l_r           = (undef, undef);
560            3                                 13         @last_diff_col = ();
561            3                                 22         $last_diff     = 0;
562            3                                 17         return;
563            3                                 56      };
564                                                      my $not_in_left  = sub {
565            3                    3            18         my ( $rr ) = @_;
566   ***      3     50                          21         $same_row->() if $l_r[RIGHT];  # last missing row
567            3                                 16         $l_r[RIGHT] = $rr;
568   ***      3    100     66                   49         $same_row->(@l_r) if $l_r[LEFT] && $l_r[RIGHT];
569            3                                 15         return;
570            3                                 34      };
571                                                      my $not_in_right = sub {
572            2                    2            14         my ( $lr ) = @_;
573   ***      2     50                          15         $same_row->() if $l_r[LEFT];  # last missing row
574            2                                 10         $l_r[LEFT] = $lr;
575   ***      2     50     33                   33         $same_row->(@l_r) if $l_r[LEFT] && $l_r[RIGHT];
576            2                                 10         return;
577            3                                 30      };
578                                                      my $done = sub {
579            7                    7            43         my ( $left, $right ) = @_;
580            7                                 23         MKDEBUG && _d('Found', $n_diff, 'of', $max_diff, 'max differences');
581            7    100                          47         if ( $n_diff >= $max_diff ) {
582            1                                  4            MKDEBUG && _d('Done comparing rows, got --max-differences', $max_diff);
583            1                                 21            $left->finish();
584            1                                 14            $right->finish();
585            1                                 27            return 1;
586                                                         }
587            6                                129         return 0;
588            3                                 34      };
589            3                                  9      my $trf;
590   ***      3     50                          29      if ( my $n = $args{'float-precision'} ) {
591                                                         $trf = sub {
592   ***      0                    0             0            my ( $l, $r, $tbl, $col ) = @_;
593   ***      0      0                           0            return $l, $r
594                                                               unless $tbl->{type_for}->{$col} =~ m/(?:float|double|decimal)/;
595   ***      0                                  0            my $l_rounded = sprintf "%.${n}f", $l;
596   ***      0                                  0            my $r_rounded = sprintf "%.${n}f", $r;
597   ***      0                                  0            MKDEBUG && _d('Rounded', $l, 'to', $l_rounded,
598                                                               'and', $r, 'to', $r_rounded);
599   ***      0                                  0            return $l_rounded, $r_rounded;
600   ***      0                                  0         };
601                                                      };
602                                                   
603            3                                 89      my $rd = new RowDiff(
604                                                         dbh          => $left_dbh,
605                                                         key_cmp      => $key_cmp,
606                                                         same_row     => $same_row,
607                                                         not_in_left  => $not_in_left,
608                                                         not_in_right => $not_in_right,
609                                                         done         => $done,
610                                                         trf          => $trf,
611                                                      );
612            3                                 80      my $ch = new ChangeHandler(
613                                                         src_db     => $db,
614                                                         src_tbl    => 'mk_upgrade_left',
615                                                         dst_db     => $db,
616                                                         dst_tbl    => 'mk_upgrade_right',
617                                                         tbl_struct => $res_struct,
618                                                         queue      => 0,
619                                                         replace    => 0,
620                                                         actions    => [],
621                                                         Quoter     => $self->{Quoter},
622                                                      );
623                                                   
624                                                      # With whatever index we may have, let TableSyncer choose an
625                                                      # algorithm and find were rows differ.  We don't actually sync
626                                                      # the tables (execute=>0).  Instead, the callbacks above will
627                                                      # save rows in @missing_rows and @different_rows.
628            3                                100      $self->{TableSyncer}->sync_table(
629                                                         plugins       => $self->{plugins},
630                                                         src           => {
631                                                            dbh => $left_dbh,
632                                                            db  => $db,
633                                                            tbl => 'mk_upgrade_left',
634                                                         },
635                                                         dst           => {
636                                                            dbh => $right_dbh,
637                                                            db  => $db,
638                                                            tbl => 'mk_upgrade_right',
639                                                         },
640                                                         tbl_struct    => $res_struct,
641                                                         cols          => $res_struct->{cols},
642                                                         chunk_size    => 1_000,
643                                                         RowDiff       => $rd,
644                                                         ChangeHandler => $ch,
645                                                      );
646                                                   
647            3    100                          35      if ( $n_diff < $max_diff ) {
648   ***      2    100     66                   37         $same_row->() if $l_r[LEFT] || $l_r[RIGHT];  # save remaining rows
649                                                      }
650                                                   
651            3                                138      return @different_rows;
652                                                   }
653                                                   
654                                                   # Writes the current row and all remaining rows to an outfile.
655                                                   # Returns the outfile's name.
656                                                   sub write_to_outfile {
657            5                    5            64      my ( $self, %args ) = @_;
658            5                                 56      my @required_args = qw(side row sth Outfile);
659            5                                 32      foreach my $arg ( @required_args ) {
660   ***     20     50                         153         die "I need a $arg argument" unless $args{$arg};
661                                                      }
662            5                                 43      my ( $side, $row, $sth, $outfile ) = @args{@required_args};
663            5                                 55      my ( $fh, $file ) = $self->open_outfile(%args);
664                                                   
665                                                      # Write this one row.
666            5                                 56      $outfile->write($fh, [ MockSyncStream::as_arrayref($sth, $row) ]);
667                                                   
668                                                      # Get and write all remaining rows.
669            5                                112      my $remaining_rows = $sth->fetchall_arrayref();
670            5                                 38      $outfile->write($fh, $remaining_rows);
671                                                   
672            5                                 29      my $n_rows = 1 + @$remaining_rows;
673            5                                 19      MKDEBUG && _d('Wrote', $n_rows, 'rows');
674                                                   
675   ***      5     50                         424      close $fh or warn "Cannot close $file: $OS_ERROR";
676            5                                 21      return $file, $n_rows;
677                                                   }
678                                                   
679                                                   sub open_outfile {
680            6                    6            58      my ( $self, %args ) = @_;
681            6                                 69      my $outfile = $self->{'base-dir'} . "/$args{side}-outfile.txt";
682   ***      6     50                         741      open my $fh, '>', $outfile or die "Cannot open $outfile: $OS_ERROR";
683            6                                 23      MKDEBUG && _d('Opened outfile', $outfile);
684            6                                 74      return $fh, $outfile;
685                                                   }
686                                                   
687                                                   # Returns just the column definitions for the given struct.
688                                                   # Example:
689                                                   #   (
690                                                   #     `i` integer,
691                                                   #     `f` float(10,8)
692                                                   #   )
693                                                   sub make_table_ddl {
694            3                    3            20      my ( $self, $struct ) = @_;
695            5                                 23      my $sql = "(\n"
696                                                              . (join("\n",
697                                                                    map {
698            3                                 38                       my $name = $_;
699            5                                 38                       my $type = $struct->{type_for}->{$_};
700            5           100                   65                       my $size = $struct->{size}->{$_} || '';
701            5                                 56                       "  `$name` $type$size,";
702            3                                 18                    } @{$struct->{cols}}))
703                                                              . ')';
704                                                      # The last column will be like "`i` integer,)" which is invalid.
705            3                                 40      $sql =~ s/,\)$/\n)/;
706            3                                 11      MKDEBUG && _d('Table ddl:', $sql);
707            3                                 21      return $sql;
708                                                   }
709                                                   
710                                                   # Adds every index from every table used by the query to all the
711                                                   # dest tables.  dest is an arrayref of hashes, one for each destination.
712                                                   # Each hash needs a dbh and tbl key; e.g.:
713                                                   #   [
714                                                   #     {
715                                                   #       dbh => $dbh,
716                                                   #       tbl => 'db.tbl',
717                                                   #     },
718                                                   #   ],
719                                                   # For the moment, the sub returns nothing.  In the future, it should
720                                                   # add to $args{struct}->{keys} the keys that it was able to add.
721                                                   sub add_indexes {
722            1                    1            25      my ( $self, %args ) = @_;
723            1                                 12      my @required_args = qw(query dsts db);
724            1                                 16      foreach my $arg ( @required_args ) {
725   ***      3     50                          28         die "I need a $arg argument" unless $args{$arg};
726                                                      }
727            1                                  9      my ($query, $dsts) = @args{@required_args};
728                                                   
729            1                                  6      my $qp = $self->{QueryParser};
730            1                                  7      my $tp = $self->{TableParser};
731            1                                  5      my $q  = $self->{Quoter};
732            1                                  5      my $du = $self->{MySQLDump};
733                                                   
734            1                                 25      my @src_tbls = $qp->get_tables($query);
735            1                                  4      my @keys;
736            1                                  7      foreach my $db_tbl ( @src_tbls ) {
737            1                                 15         my ($db, $tbl) = $q->split_unquote($db_tbl, $args{db});
738   ***      1     50                           7         if ( $db ) {
739            1                                  5            my $tbl_struct;
740            1                                  5            eval {
741            1                                 24               $tbl_struct = $tp->parse(
742                                                                  $du->get_create_table($dsts->[0]->{dbh}, $q, $db, $tbl)
743                                                               );
744                                                            };
745   ***      1     50                          10            if ( $EVAL_ERROR ) {
746   ***      0                                  0               MKDEBUG && _d('Error parsing', $db, '.', $tbl, ':', $EVAL_ERROR);
747   ***      0                                  0               next;
748                                                            }
749   ***      1     50                          14            push @keys, map {
750            1                                  9               my $def = ($_->{is_unique} ? 'UNIQUE ' : '')
751                                                                       . "KEY ($_->{colnames})";
752            1                                 22               [$def, $_];
753            1                                  6            } grep { $_->{type} eq 'BTREE' } values %{$tbl_struct->{keys}};
               1                                  8   
754                                                         }
755                                                         else {
756   ***      0                                  0            MKDEBUG && _d('Cannot get indexes from', $db_tbl, 'because its '
757                                                               . 'database is unknown');
758                                                         }
759                                                      }
760            1                                  4      MKDEBUG && _d('Source keys:', Dumper(\@keys));
761   ***      1     50                           8      return unless @keys;
762                                                   
763            1                                  7      for my $dst ( @$dsts ) {
764            2                                 14         foreach my $key ( @keys ) {
765            2                                 16            my $def = $key->[0];
766            2                                440            my $sql = "ALTER TABLE $dst->{tbl} ADD $key->[0]";
767            2                                  8            MKDEBUG && _d($sql);
768            2                                 10            eval {
769            2                             145239               $dst->{dbh}->do($sql);
770                                                            };
771   ***      2     50                          62            if ( $EVAL_ERROR ) {
772   ***      0                                  0               MKDEBUG && _d($EVAL_ERROR);
773                                                            }
774                                                            else {
775                                                               # TODO: $args{res_struct}->{keys}->{$key->[1]->{name}} = $key->[1];
776                                                            }
777                                                         }
778                                                      }
779                                                   
780                                                      # If the query uses only 1 table then return its struct.
781                                                      # TODO: $args{struct} = $struct if @src_tbls == 1;
782            1                                 35      return;
783                                                   }
784                                                   
785                                                   sub report {
786            3                    3            33      my ( $self, %args ) = @_;
787            3                                 23      my @required_args = qw(hosts);
788            3                                 18      foreach my $arg ( @required_args ) {
789   ***      3     50                          34         die "I need a $arg argument" unless $args{$arg};
790                                                      }
791            3                                 22      my ($hosts) = @args{@required_args};
792                                                   
793   ***      3     50                          12      return unless keys %{$self->{diffs}};
               3                                 44   
794                                                   
795                                                      # These columns are common to all the reports; make them just once.
796            3                                 25      my $query_id_col = {
797                                                         name        => 'Query ID',
798                                                         fixed_width => 18,
799                                                      };
800            6                                 46      my @host_cols = map {
801            3                                 20         my $col = { name => $_->{name} };
802            6                                 37         $col;
803                                                      } @$hosts;
804                                                   
805            3                                 12      my @reports;
806            3                                 19      foreach my $diff ( qw(checksums col_vals row_counts) ) {
807            9                                 51         my $report = "_report_diff_$diff";
808            9                                139         push @reports, $self->$report(
809                                                            query_id_col => $query_id_col,
810                                                            host_cols    => \@host_cols,
811                                                            %args
812                                                         );
813                                                      }
814                                                   
815            3                                 59      return join("\n", @reports);
816                                                   }
817                                                   
818                                                   sub _report_diff_checksums {
819            3                    3            41      my ( $self, %args ) = @_;
820            3                                 29      my @required_args = qw(query_id_col host_cols);
821            3                                 25      foreach my $arg ( @required_args ) {
822   ***      6     50                          54         die "I need a $arg argument" unless $args{$arg};
823                                                      }
824                                                   
825            3                                 20      my $get_id = $self->{get_id};
826                                                   
827            3    100                          15      return unless keys %{$self->{diffs}->{checksums}};
               3                                 51   
828                                                   
829            1                                 59      my $report = new ReportFormatter();
830            1                                 12      $report->set_title('Checksum differences');
831            1                                 14      $report->set_columns(
832                                                         $args{query_id_col},
833            1                                  6         @{$args{host_cols}},
834                                                      );
835                                                   
836            1                                  7      my $diff_checksums = $self->{diffs}->{checksums};
837            1                                 12      foreach my $item ( sort keys %$diff_checksums ) {
838            1                                 17         map {
839   ***      0                                  0            $report->add_line(
840                                                               $get_id->($item) . '-' . $_,
841            1                                 10               @{$diff_checksums->{$item}->{$_}}[0,1],
842                                                            );
843            1                                  5         } sort { $a <=> $b } keys %{$diff_checksums->{$item}};
               1                                 19   
844                                                      }
845                                                   
846            1                                 11      return $report->get_report();
847                                                   }
848                                                   
849                                                   sub _report_diff_col_vals {
850            3                    3            35      my ( $self, %args ) = @_;
851            3                                 27      my @required_args = qw(query_id_col host_cols);
852            3                                 24      foreach my $arg ( @required_args ) {
853   ***      6     50                          53         die "I need a $arg argument" unless $args{$arg};
854                                                      }
855                                                   
856            3                                 18      my $get_id = $self->{get_id};
857                                                   
858            3    100                          31      return unless keys %{$self->{diffs}->{col_vals}};
               3                                 40   
859                                                   
860            2                                 40      my $report = new ReportFormatter();
861            2                                 21      $report->set_title('Column value differences');
862            2                                 24      $report->set_columns(
863                                                         $args{query_id_col},
864                                                         {
865                                                            name => 'Column'
866                                                         },
867            2                                 19         @{$args{host_cols}},
868                                                      );
869            2                                 19      my $diff_col_vals = $self->{diffs}->{col_vals};
870            2                                 20      foreach my $item ( sort keys %$diff_col_vals ) {
871            2                                 10         foreach my $sampleno (sort {$a <=> $b} keys %{$diff_col_vals->{$item}}) {
      ***      0                                  0   
               2                                 22   
872            2                                 16            map {
873            2                                 14               $report->add_line(
874                                                                  $get_id->($item) . '-' . $sampleno,
875                                                                  @$_,
876                                                               );
877            2                                  8            } @{$diff_col_vals->{$item}->{$sampleno}};
878                                                         }
879                                                      }
880                                                   
881            2                                 21      return $report->get_report();
882                                                   }
883                                                   
884                                                   sub _report_diff_row_counts {
885            3                    3            30      my ( $self, %args ) = @_;
886            3                                 29      my @required_args = qw(query_id_col hosts);
887            3                                 25      foreach my $arg ( @required_args ) {
888   ***      6     50                          50         die "I need a $arg argument" unless $args{$arg};
889                                                      }
890                                                   
891            3                                 25      my $get_id = $self->{get_id};
892                                                   
893            3    100                          12      return unless keys %{$self->{diffs}->{row_counts}};
               3                                 41   
894                                                   
895            2                                 16      my $report = new ReportFormatter();
896            2                                 17      $report->set_title('Row count differences');
897            4                                 35      $report->set_columns(
898                                                         $args{query_id_col},
899                                                         map {
900            2                                 15            my $col = { name => $_->{name}, right_justify => 1  };
901            4                                 25            $col;
902            2                                 18         } @{$args{hosts}},
903                                                      );
904                                                   
905            2                                 14      my $diff_row_counts = $self->{diffs}->{row_counts};
906            2                                 19      foreach my $item ( sort keys %$diff_row_counts ) {
907            2                                 21         map {
908   ***      0                                  0            $report->add_line(
909                                                               $get_id->($item) . '-' . $_,
910            2                                 16               @{$diff_row_counts->{$item}->{$_}}[0,1],
911                                                            );
912            2                                 11         } sort { $a <=> $b } keys %{$diff_row_counts->{$item}};
               2                                 19   
913                                                      }
914                                                   
915            2                                 14      return $report->get_report();
916                                                   }
917                                                   
918                                                   sub samples {
919            2                    2            21      my ( $self, $item ) = @_;
920   ***      2     50                          17      return unless $item;
921            2                                 11      my @samples;
922            2                                  9      foreach my $sampleno ( keys %{$self->{samples}->{$item}} ) {
               2                                 33   
923            2                                 25         push @samples, $sampleno, $self->{samples}->{$item}->{$sampleno};
924                                                      }
925            2                                 27      return @samples;
926                                                   }
927                                                   
928                                                   sub reset {
929            1                    1            22      my ( $self ) = @_;
930            1                                  7      $self->{tmp_tbl} = '';
931            1                                  7      $self->{diffs}   = {};
932            1                                 14      $self->{samples} = {};
933            1                                  9      return;
934                                                   }
935                                                   
936                                                   sub _d {
937            1                    1            67      my ($package, undef, $line) = caller 0;
938   ***      2     50                          22      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 22   
939            1                                  9           map { defined $_ ? $_ : 'undef' }
940                                                           @_;
941            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
942                                                   }
943                                                   
944                                                   1;
945                                                   
946                                                   # ###########################################################################
947                                                   # End CompareResults package
948                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***     50      0     18   unless $args{$arg}
72    ***     50      0     28   unless $args{$arg}
80           100      6      8   if ($$self{'method'} eq 'checksum')
82    ***     50      0      6   if $args{'temp-database'}
83    ***     50      0      6   unless $db
96    ***     50      0      6   if $EVAL_ERROR
127   ***     50      0     28   unless $args{$arg}
135          100      8      6   if ($$self{'method'} eq 'rows') { }
140   ***     50      0      8   if $EVAL_ERROR
148   ***     50      0      8   if $EVAL_ERROR
159   ***     50      0      6   if $EVAL_ERROR
179   ***     50      0      7   unless $args{$arg}
183          100      6      1   if ($$self{'method'} eq 'checksum')
185   ***     50      0      6   unless $$event{'original_arg'}
213   ***     50      0     14   unless $args{$arg}
216          100      4      3   $$self{'method'} eq 'rows' ? :
224   ***     50      0      6   unless $args{$arg}
240          100      3      3   if ($i)
241          100      2      1   if ($$events[0]{'checksum'} || 0) != ($$events[$i]{'checksum'} || 0)
243          100      1      2   if ($$events[0]{'row_count'} || 0) != ($$events[$i]{'row_count'} || 0)
251          100      2      1   if ($different_checksums)
256          100      1      2   if ($different_row_counts)
274   ***     50      0     12   unless $args{$arg}
291   ***     50      0      6   if ($EVAL_ERROR)
303   ***     50      0      6   if ($EVAL_ERROR)
315   ***     50      0      8   unless $args{$arg}
409          100      1      3   if $$event0{'row_count'} != $$event{'row_count'}
410          100      1      3   if ($different_row_counts)
417          100      1      3   if $no_diff
425          100      1      2   if (not $left_outfile)
429   ***     50      0      3   if (not $right_outfile)
446          100      2      1   if (scalar @diff_rows)
483   ***     50      0     21   unless $args{$arg}
512          100      1      2   if ($args{'add-indexes'})
541          100      2      1   if ($l_r[0] and $l_r[1]) { }
      ***     50      0      1   elsif ($l_r[0]) { }
      ***     50      1      0   elsif ($l_r[1]) { }
566   ***     50      0      3   if $l_r[1]
568          100      2      1   if $l_r[0] and $l_r[1]
573   ***     50      0      2   if $l_r[0]
575   ***     50      0      2   if $l_r[0] and $l_r[1]
581          100      1      6   if ($n_diff >= $max_diff)
590   ***     50      0      3   if (my $n = $args{'float-precision'})
593   ***      0      0      0   unless $$tbl{'type_for'}{$col} =~ /(?:float|double|decimal)/
647          100      2      1   if ($n_diff < $max_diff)
648          100      1      1   if $l_r[0] or $l_r[1]
660   ***     50      0     20   unless $args{$arg}
675   ***     50      0      5   unless close $fh
682   ***     50      0      6   unless open my $fh, '>', $outfile
725   ***     50      0      3   unless $args{$arg}
738   ***     50      1      0   if ($db) { }
745   ***     50      0      1   if ($EVAL_ERROR)
749   ***     50      1      0   $$_{'is_unique'} ? :
761   ***     50      0      1   unless @keys
771   ***     50      0      2   if ($EVAL_ERROR) { }
789   ***     50      0      3   unless $args{$arg}
793   ***     50      0      3   unless keys %{$$self{'diffs'};}
822   ***     50      0      6   unless $args{$arg}
827          100      2      1   unless keys %{$$self{'diffs'}{'checksums'};}
853   ***     50      0      6   unless $args{$arg}
858          100      1      2   unless keys %{$$self{'diffs'}{'col_vals'};}
888   ***     50      0      6   unless $args{$arg}
893          100      1      2   unless keys %{$$self{'diffs'}{'row_counts'};}
920   ***     50      0      2   unless $item
938   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
541   ***     66      1      0      2   $l_r[0] and $l_r[1]
568   ***     66      1      0      2   $l_r[0] and $l_r[1]
575   ***     33      0      2      0   $l_r[0] and $l_r[1]

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
241   ***     50      3      0   $$events[0]{'checksum'} || 0
      ***     50      3      0   $$events[$i]{'checksum'} || 0
243   ***     50      3      0   $$events[0]{'row_count'} || 0
      ***     50      3      0   $$events[$i]{'row_count'} || 0
250   ***     50      3      0   $$events[0]{'sampleno'} || 0
327          100      2      2   $$event0{'sampleno'} || 0
403          100      3      1   $n_rows || 0
525          100      1      2   $args{'max-different-rows'} || 1000
700          100      2      3   $$struct{'size'}{$_} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
249   ***     33      3      0      0   $$events[0]{'fingerprint'} || $$events[0]{'arg'}
326   ***     66      2      2      0   $$event0{'fingerprint'} || $$event0{'arg'}
434   ***     33      0      3      0   $args{'tmp_db'} || $$event0{'db'}
648   ***     66      0      1      1   $l_r[0] or $l_r[1]


Covered Subroutines
-------------------

Subroutine              Count Location                                             
----------------------- ----- -----------------------------------------------------
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:22 
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:23 
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:24 
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:25 
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:27 
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:29 
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:529
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:530
__ANON__                    8 /home/daniel/dev/maatkit/common/CompareResults.pm:355
__ANON__                    3 /home/daniel/dev/maatkit/common/CompareResults.pm:359
__ANON__                    2 /home/daniel/dev/maatkit/common/CompareResults.pm:371
__ANON__                    3 /home/daniel/dev/maatkit/common/CompareResults.pm:535
__ANON__                    3 /home/daniel/dev/maatkit/common/CompareResults.pm:540
__ANON__                    3 /home/daniel/dev/maatkit/common/CompareResults.pm:565
__ANON__                    2 /home/daniel/dev/maatkit/common/CompareResults.pm:572
__ANON__                    7 /home/daniel/dev/maatkit/common/CompareResults.pm:579
_checksum_results           6 /home/daniel/dev/maatkit/common/CompareResults.pm:271
_compare_checksums          3 /home/daniel/dev/maatkit/common/CompareResults.pm:221
_compare_rows               4 /home/daniel/dev/maatkit/common/CompareResults.pm:312
_d                          1 /home/daniel/dev/maatkit/common/CompareResults.pm:937
_report_diff_checksums      3 /home/daniel/dev/maatkit/common/CompareResults.pm:819
_report_diff_col_vals       3 /home/daniel/dev/maatkit/common/CompareResults.pm:850
_report_diff_row_counts     3 /home/daniel/dev/maatkit/common/CompareResults.pm:885
add_indexes                 1 /home/daniel/dev/maatkit/common/CompareResults.pm:722
after_execute               7 /home/daniel/dev/maatkit/common/CompareResults.pm:176
before_execute             14 /home/daniel/dev/maatkit/common/CompareResults.pm:69 
compare                     7 /home/daniel/dev/maatkit/common/CompareResults.pm:210
diff_rows                   3 /home/daniel/dev/maatkit/common/CompareResults.pm:479
execute                    14 /home/daniel/dev/maatkit/common/CompareResults.pm:124
make_table_ddl              3 /home/daniel/dev/maatkit/common/CompareResults.pm:694
new                         2 /home/daniel/dev/maatkit/common/CompareResults.pm:41 
open_outfile                6 /home/daniel/dev/maatkit/common/CompareResults.pm:680
report                      3 /home/daniel/dev/maatkit/common/CompareResults.pm:786
reset                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:929
samples                     2 /home/daniel/dev/maatkit/common/CompareResults.pm:919
write_to_outfile            5 /home/daniel/dev/maatkit/common/CompareResults.pm:657

Uncovered Subroutines
---------------------

Subroutine              Count Location                                             
----------------------- ----- -----------------------------------------------------
__ANON__                    0 /home/daniel/dev/maatkit/common/CompareResults.pm:592


