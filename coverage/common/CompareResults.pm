---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/CompareResults.pm   98.0   73.1   78.0  100.0    0.0   58.0   90.3
CompareResults.t               98.4   37.5   56.2  100.0    n/a   42.0   93.2
Total                          98.1   69.3   72.7  100.0    0.0  100.0   91.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:16 2010
Finish:       Thu Jun 24 19:32:16 2010

Run:          CompareResults.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:18 2010
Finish:       Thu Jun 24 19:32:21 2010

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
18                                                    # CompareResults package $Revision: 5976 $
19                                                    # ###########################################################################
20                                                    package CompareResults;
21                                                    
22             1                    1             4   use strict;
               1                                  3   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25             1                    1             9   use Time::HiRes qw(time);
               1                                  3   
               1                                  4   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 13   
28                                                    
29             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  7   
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
41    ***      4                    4      0    133      my ( $class, %args ) = @_;
42             4                                 57      my @required_args = qw(method base-dir plugins get_id
43                                                                              QueryParser MySQLDump TableParser TableSyncer Quoter);
44             4                                 38      foreach my $arg ( @required_args ) {
45    ***     36     50                         268         die "I need a $arg argument" unless $args{$arg};
46                                                       }
47             4                                 99      my $self = {
48                                                          %args,
49                                                          diffs   => {},
50                                                          samples => {},
51                                                       };
52             4                                121      return bless $self, $class;
53                                                    }
54                                                    
55                                                    # Required args:
56                                                    #   * event  hashref: an event
57                                                    #   * dbh    scalar: active dbh
58                                                    # Optional args:
59                                                    #   * db             scalar: database name to create temp table in unless...
60                                                    #   * temp-database  scalar: ...temp db name is given
61                                                    #   * temp-table     scalar: temp table name
62                                                    # Returns: hashref
63                                                    # Can die: yes
64                                                    # before_execute() drops the temp table if the method is checksum.
65                                                    # db and temp-table are required for the checksum method, but optional
66                                                    # for the rows method.
67                                                    sub before_execute {
68    ***     20                   20      0    230      my ( $self, %args ) = @_;
69            20                                154      my @required_args = qw(event dbh);
70            20                                133      foreach my $arg ( @required_args ) {
71    ***     40     50                         342         die "I need a $arg argument" unless $args{$arg};
72                                                       }
73            20                                145      my ($event, $dbh) = @args{@required_args};
74            20                                 90      my $sql;
75                                                    
76            20    100                         177      if ( $self->{method} eq 'checksum' ) {
77             6                                 49         my ($db, $tmp_tbl) = @args{qw(db temp-table)};
78    ***      6     50                          44         $db = $args{'temp-database'} if $args{'temp-database'};
79    ***      6     50                          36         die "Cannot checksum results without a database"
80                                                             unless $db;
81                                                    
82             6                                 74         $tmp_tbl = $self->{Quoter}->quote($db, $tmp_tbl);
83             6                                434         eval {
84             6                                 31            $sql = "DROP TABLE IF EXISTS $tmp_tbl";
85             6                                 21            MKDEBUG && _d($sql);
86             6                               2050            $dbh->do($sql);
87                                                    
88             6                                 44            $sql = "SET storage_engine=MyISAM";
89             6                                 21            MKDEBUG && _d($sql);
90             6                               1122            $dbh->do($sql);
91                                                          };
92    ***      6     50                          56         die "Failed to drop temporary table $tmp_tbl: $EVAL_ERROR"
93                                                             if $EVAL_ERROR;
94                                                    
95                                                          # Save the tmp tbl; it's used later in _compare_checksums().
96             6                                 48         $event->{tmp_tbl} = $tmp_tbl; 
97                                                    
98                                                          # Wrap the original query so when it's executed its results get
99                                                          # put in tmp table.
100            6                                 73         $event->{wrapped_query}
101                                                            = "CREATE TEMPORARY TABLE $tmp_tbl AS $event->{arg}";
102            6                                 29         MKDEBUG && _d('Wrapped query:', $event->{wrapped_query});
103                                                      }
104                                                   
105           20                                265      return $event;
106                                                   }
107                                                   
108                                                   # Required args:
109                                                   #   * event  hashref: an event
110                                                   #   * dbh    scalar: active dbh
111                                                   # Returns: hashref
112                                                   # Can die: yes
113                                                   # execute() executes the event's query.  Any prep work should have
114                                                   # been done in before_execute().  For the checksum method, this simply
115                                                   # executes the wrapped query.  For the rows method, this gets/saves
116                                                   # a statement handle for the results in the event which is processed
117                                                   # later in compare().  Both methods add the Query_time attrib to the
118                                                   # event.
119                                                   sub execute {
120   ***     20                   20      0    226      my ( $self, %args ) = @_;
121           20                                155      my @required_args = qw(event dbh);
122           20                                133      foreach my $arg ( @required_args ) {
123   ***     40     50                         334         die "I need a $arg argument" unless $args{$arg};
124                                                      }
125           20                                146      my ($event, $dbh) = @args{@required_args};
126           20                                 97      my ( $start, $end, $query_time );
127                                                   
128                                                      # Other modules should only execute the query if Query_time does not
129                                                      # already exist.  This module requires special execution so we always
130                                                      # execute.
131                                                   
132           20                                 67      MKDEBUG && _d('Executing query');
133           20                                126      $event->{Query_time} = 0;
134           20    100                         162      if ( $self->{method} eq 'rows' ) {
135           14                                 80         my $query = $event->{arg};
136           14                                 55         my $sth;
137           14                                 62         eval {
138           14                                 49            $sth = $dbh->prepare($query);
139                                                         };
140   ***     14     50                         169         die "Failed to prepare query: $EVAL_ERROR" if $EVAL_ERROR;
141                                                   
142           14                                 61         eval {
143           14                                119            $start = time();
144           14                              81170            $sth->execute();
145           14                                145            $end   = time();
146           14                                332            $query_time = sprintf '%.6f', $end - $start;
147                                                         };
148   ***     14     50                         102         die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
149                                                   
150           14                                133         $event->{results_sth} = $sth;
151                                                      }
152                                                      else {
153   ***      6     50                          51         die "No wrapped query" unless $event->{wrapped_query};
154            6                                 36         my $query = $event->{wrapped_query};
155            6                                 24         eval {
156            6                                 70            $start = time();
157            6                              64454            $dbh->do($query);
158            6                                 76            $end   = time();
159            6                               1572            $query_time = sprintf '%.6f', $end - $start;
160                                                         };
161   ***      6     50                          59         if ( $EVAL_ERROR ) {
162   ***      0                                  0            delete $event->{wrapped_query};
163   ***      0                                  0            delete $event->{tmp_tbl};
164   ***      0                                  0            die "Failed to execute query: $EVAL_ERROR";
165                                                         }
166                                                      }
167                                                   
168           20                                139      $event->{Query_time} = $query_time;
169                                                   
170           20                                345      return $event;
171                                                   }
172                                                   
173                                                   # Required args:
174                                                   #   * event  hashref: an event
175                                                   # Optional args:
176                                                   #   * dbh    scalar: active dbh
177                                                   # Returns: hashref
178                                                   # Can die: yes
179                                                   # after_execute() does any post-execution cleanup.  The results should
180                                                   # not be compared here; no anaylytics here, save that for compare().
181                                                   sub after_execute {
182   ***      7                    7      0     68      my ( $self, %args ) = @_;
183            7                                 47      my @required_args = qw(event);
184            7                                 47      foreach my $arg ( @required_args ) {
185   ***      7     50                          82         die "I need a $arg argument" unless $args{$arg};
186                                                      }
187            7                                 83      return $args{event};
188                                                   }
189                                                   
190                                                   # Required args:
191                                                   #   * events  arrayref: events
192                                                   #   * hosts   arrayref: hosts hashrefs with at least a dbh key
193                                                   # Optional args:
194                                                   #   * temp-database  scalar: temp db name
195                                                   # Returns: array
196                                                   # Can die: yes
197                                                   # compare() compares events that have been run through before_execute(),
198                                                   # execute() and after_execute().  The checksum method primarily compares
199                                                   # the checksum attribs saved in the events.  The rows method uses the
200                                                   # result statement handles saved in the events to compare rows and column
201                                                   # values.  Each method returns an array of key => value pairs which the
202                                                   # caller should aggregate into a meta-event that represents differences
203                                                   # compare() has found in these events.  Only a "summary" of differences is
204                                                   # returned.  Specific differences are saved internally and are reported
205                                                   # by calling report() later.
206                                                   sub compare {
207   ***     12                   12      0    197      my ( $self, %args ) = @_;
208           12                                 95      my @required_args = qw(events hosts);
209           12                                 95      foreach my $arg ( @required_args ) {
210   ***     24     50                         209         die "I need a $arg argument" unless $args{$arg};
211                                                      }
212           12                                 93      my ($events, $hosts) = @args{@required_args};
213           12    100                         254      return $self->{method} eq 'rows' ? $self->_compare_rows(%args)
214                                                                                       : $self->_compare_checksums(%args);
215                                                   }
216                                                   
217                                                   sub _compare_checksums {
218            4                    4            34      my ( $self, %args ) = @_;
219            4                                 35      my @required_args = qw(events hosts);
220            4                                 27      foreach my $arg ( @required_args ) {
221   ***      8     50                          64         die "I need a $arg argument" unless $args{$arg};
222                                                      }
223            4                                 29      my ($events, $hosts) = @args{@required_args};
224                                                   
225            4                                 17      my $different_row_counts    = 0;
226            4                                 18      my $different_column_counts = 0; # TODO
227            4                                 16      my $different_column_types  = 0; # TODO
228            4                                 28      my $different_checksums     = 0;
229                                                   
230            4                                 20      my $n_events = scalar @$events;
231            4                                 29      foreach my $i ( 0..($n_events-1) ) {
232            8                                671         $events->[$i] = $self->_checksum_results(
233                                                            event => $events->[$i],
234                                                            dbh   => $hosts->[$i]->{dbh},
235                                                         );
236            8    100                         334         if ( $i ) {
237            4    100    100                  102            if ( ($events->[0]->{checksum} || 0)
                           100                        
238                                                                 != ($events->[$i]->{checksum}||0) ) {
239            2                                 11               $different_checksums++;
240                                                            }
241            4    100    100                   81            if ( ($events->[0]->{row_count} || 0)
                           100                        
242                                                                 != ($events->[$i]->{row_count} || 0) ) {
243            1                                856               $different_row_counts++
244                                                            }
245                                                   
246            4                                 46            delete $events->[$i]->{wrapped_query};
247                                                         }
248                                                      }
249            4                                 30      delete $events->[0]->{wrapped_query};
250                                                   
251                                                      # Save differences.
252   ***      4            66                   53      my $item     = $events->[0]->{fingerprint} || $events->[0]->{arg};
253            4           100                   44      my $sampleno = $events->[0]->{sampleno} || 0;
254            4    100                          27      if ( $different_checksums ) {
255            4                                 67         $self->{diffs}->{checksums}->{$item}->{$sampleno}
256            2                                 17            = [ map { $_->{checksum} } @$events ];
257            2                                 37         $self->{samples}->{$item}->{$sampleno} = $events->[0]->{arg};
258                                                      }
259            4    100                          30      if ( $different_row_counts ) {
260            2                                 22         $self->{diffs}->{row_counts}->{$item}->{$sampleno}
261            1                                  7            = [ map { $_->{row_count} } @$events ];
262            1                                 11         $self->{samples}->{$item}->{$sampleno} = $events->[0]->{arg};
263                                                      }
264                                                   
265                                                      return (
266            4                                109         different_row_counts    => $different_row_counts,
267                                                         different_checksums     => $different_checksums,
268                                                         different_column_counts => $different_column_counts,
269                                                         different_column_types  => $different_column_types,
270                                                      );
271                                                   }
272                                                   
273                                                   sub _checksum_results {
274            8                    8            86      my ( $self, %args ) = @_;
275            8                                 60      my @required_args = qw(event dbh);
276            8                                 52      foreach my $arg ( @required_args ) {
277   ***     16     50                         133         die "I need a $arg argument" unless $args{$arg};
278                                                      }
279            8                                 58      my ($event, $dbh) = @args{@required_args};
280                                                   
281            8                                 28      my $sql;
282            8                                 33      my $n_rows       = 0;
283            8                                 32      my $tbl_checksum = 0;
284   ***      8    100     66                  152      if ( $event->{wrapped_query} && $event->{tmp_tbl} ) {
285            6                                 33         my $tmp_tbl = $event->{tmp_tbl};
286            6                                 30         eval {
287            6                                 36            $sql = "SELECT COUNT(*) FROM $tmp_tbl";
288            6                                 19            MKDEBUG && _d($sql);
289            6                                 24            ($n_rows) = @{ $dbh->selectcol_arrayref($sql) };
               6                                 26   
290                                                   
291            6                               2286            $sql = "CHECKSUM TABLE $tmp_tbl";
292            6                                 23            MKDEBUG && _d($sql);
293            6                                 20            $tbl_checksum = $dbh->selectrow_arrayref($sql)->[1];
294                                                         };
295   ***      6     50                        1290         die "Failed to checksum table: $EVAL_ERROR"
296                                                            if $EVAL_ERROR;
297                                                      
298            6                                 34         $sql = "DROP TABLE IF EXISTS $tmp_tbl";
299            6                                 19         MKDEBUG && _d($sql);
300            6                                 25        eval {
301            6                               1994            $dbh->do($sql);
302                                                         };
303                                                         # This isn't critical; we don't need to die.
304            6                                 36         MKDEBUG && $EVAL_ERROR && _d('Error:', $EVAL_ERROR);
305                                                      }
306                                                      else {
307            2                                 15         MKDEBUG && _d("Event doesn't have wrapped query or tmp tbl");
308                                                      }
309                                                   
310            8                                 56      $event->{row_count} = $n_rows;
311            8                                 60      $event->{checksum}  = $tbl_checksum;
312            8                                 29      MKDEBUG && _d('row count:', $n_rows, 'checksum:', $tbl_checksum);
313                                                   
314            8                                 86      return $event;
315                                                   }
316                                                   
317                                                   sub _compare_rows {
318            8                    8            83      my ( $self, %args ) = @_;
319            8                                 65      my @required_args = qw(events hosts);
320            8                                 78      foreach my $arg ( @required_args ) {
321   ***     16     50                         133         die "I need a $arg argument" unless $args{$arg};
322                                                      }
323            8                                 57      my ($events, $hosts) = @args{@required_args};
324                                                   
325            8                                 32      my $different_row_counts    = 0;
326            8                                 33      my $different_column_counts = 0; # TODO
327            8                                 32      my $different_column_types  = 0; # TODO
328            8                                 37      my $different_column_values = 0;
329                                                   
330            8                                 37      my $n_events = scalar @$events;
331            8                                 49      my $event0   = $events->[0]; 
332   ***      8            66                  139      my $item     = $event0->{fingerprint} || $event0->{arg};
333            8           100                   96      my $sampleno = $event0->{sampleno} || 0;
334            8                                 56      my $dbh      = $hosts->[0]->{dbh};  # doesn't matter which one
335                                                   
336            8    100                          73      if ( !$event0->{results_sth} ) {
337                                                         # This will happen if execute() or something fails.
338            1                                  3         MKDEBUG && _d("Event 0 doesn't have a results sth");
339                                                         return (
340            1                                 23            different_row_counts    => $different_row_counts,
341                                                            different_column_values => $different_column_values,
342                                                            different_column_counts => $different_column_counts,
343                                                            different_column_types  => $different_column_types,
344                                                         );
345                                                      }
346                                                   
347            7                                141      my $res_struct = MockSyncStream::get_result_set_struct($dbh,
348                                                         $event0->{results_sth});
349            7                                 29      MKDEBUG && _d('Result set struct:', Dumper($res_struct));
350                                                   
351                                                      # Use a mock sth so we don't have to re-execute event0 sth to compare
352                                                      # it to the 3rd and subsequent events.
353            7                                 32      my @event0_rows      = @{ $event0->{results_sth}->fetchall_arrayref({}) };
               7                                191   
354            7                                117      $event0->{row_count} = scalar @event0_rows;
355            7                                179      my $left = new MockSth(@event0_rows);
356            7                                421      $left->{NAME} = [ @{$event0->{results_sth}->{NAME}} ];
               7                                 77   
357                                                   
358                                                      EVENT:
359            7                                111      foreach my $i ( 1..($n_events-1) ) {
360            7                                 43         my $event = $events->[$i];
361            7                                 39         my $right = $event->{results_sth};
362                                                   
363            7                                 40         $event->{row_count} = 0;
364                                                   
365                                                         # Identical rows are ignored.  Once a difference on either side is found,
366                                                         # we gobble the remaining rows in that sth and print them to an outfile.
367                                                         # This short circuits RowDiff::compare_sets() which is what we want to do.
368            7                                 30         my $no_diff      = 1;  # results are identical; this catches 0 row results
369            7                                154         my $outfile      = new Outfile();
370            7                                256         my ($left_outfile, $right_outfile, $n_rows);
371                                                         my $same_row     = sub {
372            9                    9           311               $event->{row_count}++;  # Keep track of this event's row_count.
373            9                                 67               return;
374            7                                 87         };
375                                                         my $not_in_left  = sub {
376            5                    5           523            my ( $rr ) = @_;
377            5                                 22            $no_diff = 0;
378                                                            # $n_rows will be added later to this event's row_count.
379            5                                 84            ($right_outfile, $n_rows) = $self->write_to_outfile(
380                                                               side    => 'right',
381                                                               sth     => $right,
382                                                               row     => $rr,
383                                                               Outfile => $outfile,
384                                                            );
385            5                                131            return;
386            7                                 87         };
387                                                         my $not_in_right = sub {
388            5                    5           175            my ( $lr ) = @_;
389            5                                 23            $no_diff = 0;
390                                                            # left is event0 so we don't need $n_rows back.
391            5                                 58            ($left_outfile, undef) = $self->write_to_outfile(
392                                                               side    => 'left',
393                                                               sth     => $left,
394                                                               row     => $lr,
395                                                               Outfile => $outfile,
396                                                            ); 
397            5                                138            return;
398            7                                 93         };
399                                                   
400            7                                 90         my $rd       = new RowDiff(dbh => $dbh);
401            7                                523         my $mocksync = new MockSyncStream(
402                                                            query        => $event0->{arg},
403                                                            cols         => $res_struct->{cols},
404                                                            same_row     => $same_row,
405                                                            not_in_left  => $not_in_left,
406                                                            not_in_right => $not_in_right,
407                                                         );
408                                                   
409            7                                725         MKDEBUG && _d('Comparing result sets with MockSyncStream');
410            7                                 76         $rd->compare_sets(
411                                                            left_sth   => $left,
412                                                            right_sth  => $right,
413                                                            syncer     => $mocksync,
414                                                            tbl_struct => $res_struct,
415                                                         );
416                                                   
417                                                         # Add number of rows written to outfile to this event's row_count.
418                                                         # $n_rows will be undef if there were no differences; row_count will
419                                                         # still be correct in this case because we kept track of it in $same_row.
420            7           100                  259         $event->{row_count} += $n_rows || 0;
421                                                   
422            7                                 24         MKDEBUG && _d('Left has', $event0->{row_count}, 'rows, right has',
423                                                            $event->{row_count});
424                                                   
425                                                         # Save differences.
426            7    100                          68         $different_row_counts++ if $event0->{row_count} != $event->{row_count};
427            7    100                          44         if ( $different_row_counts ) {
428            2                                 36            $self->{diffs}->{row_counts}->{$item}->{$sampleno}
429                                                               = [ $event0->{row_count}, $event->{row_count} ];
430            2                                 22            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
431                                                         }
432                                                   
433            7                                 59         $left->reset();
434            7    100                         241         if ( $no_diff ) {
435            1                                  6            delete $event->{results_sth};
436            1                                 56            next EVENT;
437                                                         }
438                                                   
439                                                         # The result sets differ, so now we must begin the difficult
440                                                         # work: finding and determining the nature of those differences.
441            6                                 23         MKDEBUG && _d('Result sets are different');
442                                                   
443                                                   
444                                                         # Make sure both outfiles are created, else diff_rows() will die.
445            6    100                          42         if ( !$left_outfile ) {
446            1                                  3            MKDEBUG && _d('Right has extra rows not in left');
447            1                                  9            (undef, $left_outfile) = $self->open_outfile(side => 'left');
448                                                         }
449            6    100                          38         if ( !$right_outfile ) {
450            1                                 11            MKDEBUG && _d('Left has extra rows not in right');
451            1                                  9            (undef, $right_outfile) = $self->open_outfile(side => 'right');
452                                                         }
453                                                   
454   ***      6            33                  216         my @diff_rows = $self->diff_rows(
455                                                            %args,             # for options like max-different-rows
456                                                            left_dbh        => $hosts->[0]->{dbh},
457                                                            left_outfile    => $left_outfile,
458                                                            right_dbh       => $hosts->[$i]->{dbh},
459                                                            right_outfile   => $right_outfile,
460                                                            res_struct      => $res_struct,
461                                                            query           => $event0->{arg},
462                                                            db              => $args{'temp-database'} || $event0->{db},
463                                                         );
464                                                   
465                                                         # Save differences.
466            6    100                          57         if ( scalar @diff_rows ) { 
467            3                                 23            $different_column_values++; 
468            3                                 68            $self->{diffs}->{col_vals}->{$item}->{$sampleno} = \@diff_rows;
469            3                                 46            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
470                                                         }
471                                                   
472            6                                609         delete $event->{results_sth};
473                                                      }
474            7                                325      delete $event0->{results_sth};
475                                                   
476                                                      return (
477            7                                613         different_row_counts    => $different_row_counts,
478                                                         different_column_values => $different_column_values,
479                                                         different_column_counts => $different_column_counts,
480                                                         different_column_types  => $different_column_types,
481                                                      );
482                                                   }
483                                                   
484                                                   # Required args:
485                                                   #   * left_dbh       scalar: active dbh for left
486                                                   #   * left_outfile   scalar: outfile name for left
487                                                   #   * right_dbh      scalar: active dbh for right
488                                                   #   * right_outfile  scalar: outfile name for right
489                                                   #   * res_struct     hashref: result set structure
490                                                   #   * db             scalar: database to use for creating temp tables
491                                                   #   * query          scalar: query, parsed for indexes
492                                                   # Optional args:
493                                                   #   * add-indexes         scalar: add indexes from source tables to tmp tbl
494                                                   #   * max-different-rows  scalar: stop after this many differences are found
495                                                   #   * float-precision     scalar: round float, double, decimal types to N places
496                                                   # Returns: scalar
497                                                   # Can die: no
498                                                   # diff_rows() loads and compares two result sets and returns the number of
499                                                   # differences between them.  This includes missing rows and row data
500                                                   # differences.
501                                                   sub diff_rows {
502   ***      6                    6      0    190      my ( $self, %args ) = @_;
503            6                                 75      my @required_args = qw(left_dbh left_outfile right_dbh right_outfile
504                                                                             res_struct db query);
505            6                                 53      foreach my $arg ( @required_args ) {
506   ***     42     50                         307         die "I need a $arg argument" unless $args{$arg};
507                                                      }
508            6                                141      my ($left_dbh, $left_outfile, $right_dbh, $right_outfile, $res_struct,
509                                                          $db, $query)
510                                                         = @args{@required_args};
511                                                   
512                                                      # Switch to the given db.  This may be different from the event's
513                                                      # db if, for example, --temp-database was specified.
514            6                                 62      my $orig_left_db  = $self->_use_db($left_dbh, $db);
515            6                                 50      my $orig_right_db = $self->_use_db($right_dbh, $db);
516                                                   
517                                                      # First thing, make two temps tables into which the outfiles can
518                                                      # be loaded.  This requires that we make a CREATE TABLE statement
519                                                      # for the result sets' columns.
520            6                                 46      my $left_tbl  = "`$db`.`mk_upgrade_left`";
521            6                                 59      my $right_tbl = "`$db`.`mk_upgrade_right`";
522            6                                 72      my $table_ddl = $self->make_table_ddl($res_struct);
523                                                   
524            6                               2628      $left_dbh->do("DROP TABLE IF EXISTS $left_tbl");
525            6                             399793      $left_dbh->do("CREATE TABLE $left_tbl $table_ddl");
526            6                               6160      $left_dbh->do("LOAD DATA LOCAL INFILE '$left_outfile' "
527                                                         . "INTO TABLE $left_tbl");
528                                                   
529            6                             426343      $right_dbh->do("DROP TABLE IF EXISTS $right_tbl");
530            6                             370453      $right_dbh->do("CREATE TABLE $right_tbl $table_ddl");
531            6                               5135      $right_dbh->do("LOAD DATA LOCAL INFILE '$right_outfile' "
532                                                         . "INTO TABLE $right_tbl");
533                                                   
534            6                                 40      MKDEBUG && _d('Loaded', $left_outfile, 'into table', $left_tbl, 'and',
535                                                         $right_outfile, 'into table', $right_tbl);
536                                                   
537                                                      # Now we need to get all indexes from all tables used by the query
538                                                      # and add them to the temp tbl.  Some indexes may be invalid, dupes,
539                                                      # or generally useless, but we'll let the sync algo decide that later.
540            6    100                          79      if ( $args{'add-indexes'} ) {
541            1                                 51         $self->add_indexes(
542                                                            %args,
543                                                            dsts      => [
544                                                               { dbh => $left_dbh,  tbl => $left_tbl  },
545                                                               { dbh => $right_dbh, tbl => $right_tbl },
546                                                            ],
547                                                         );
548                                                      }
549                                                   
550                                                      # Create a RowDiff with callbacks that will do what we want when rows and
551                                                      # columns differ.  This RowDiff is passed to TableSyncer which calls it.
552                                                      # TODO: explain how these callbacks work together.
553            6           100                  151      my $max_diff = $args{'max-different-rows'} || 1_000;  # 1k=sanity/safety
554            6                                 42      my $n_diff   = 0;
555            6                                 24      my @missing_rows;  # not currently saved; row counts show missing rows
556            6                                 24      my @different_rows;
557            1                    1             8      use constant LEFT  => 0;
               1                                  3   
               1                                 10   
558            1                    1             6      use constant RIGHT => 1;
               1                                  3   
               1                                  4   
559            6                                 52      my @l_r = (undef, undef);
560            6                                 24      my @last_diff_col;
561            6                                 28      my $last_diff = 0;
562                                                      my $key_cmp      = sub {
563            4                    4            60         push @last_diff_col, [@_];
564            4                                 32         $last_diff--;
565            4                                 23         return;
566            6                                123      };
567                                                      my $same_row = sub {
568            7                    7            66         my ( %args ) = @_;
569            7                                 56         my ($lr, $rr) = @args{qw(lr rr)};
570            7    100    100                  123         if ( $l_r[LEFT] && $l_r[RIGHT] ) {
                    100                               
                    100                               
571            3                                 11            MKDEBUG && _d('Saving different row');
572            3                                 19            push @different_rows, $last_diff_col[$last_diff];
573            3                                 15            $n_diff++;
574                                                         }
575                                                         elsif ( $l_r[LEFT] ) {
576            2                                 15            MKDEBUG && _d('Saving not in right row');
577                                                            # push @missing_rows, [$l_r[LEFT], undef];
578            2                                 20            $n_diff++;
579                                                         }
580                                                         elsif ( $l_r[RIGHT] ) {
581            1                                  4            MKDEBUG && _d('Saving not in left row');
582                                                            # push @missing_rows, [undef, $l_r[RIGHT]];
583            1                                  8            $n_diff++;
584                                                         }
585                                                         else {
586            1                                  9            MKDEBUG && _d('No missing or different rows in queue');
587                                                         }
588            7                                 64         @l_r           = (undef, undef);
589            7                                 33         @last_diff_col = ();
590            7                                 34         $last_diff     = 0;
591            7                                 41         return;
592            6                                 92      };
593                                                      my $not_in_left  = sub {
594            4                    4            61         my ( %args ) = @_;
595            4                                 41         my ($lr, $rr) = @args{qw(lr rr)};
596   ***      4     50                          32         $same_row->() if $l_r[RIGHT];  # last missing row
597            4                                 21         $l_r[RIGHT] = $rr;
598   ***      4    100     66                   84         $same_row->(@l_r) if $l_r[LEFT] && $l_r[RIGHT];
599            4                                 38         return;
600            6                                 67      };
601                                                      my $not_in_right = sub {
602            5                    5            80         my ( %args ) = @_;
603            5                                 51         my ($lr, $rr) = @args{qw(lr rr)};
604            5    100                          46         $same_row->() if $l_r[LEFT];  # last missing row
605            5                                 24         $l_r[LEFT] = $lr;
606   ***      5     50     33                  104         $same_row->(@l_r) if $l_r[LEFT] && $l_r[RIGHT];
607            5                                 40         return;
608            6                                 66      };
609                                                      my $done = sub {
610           15                   15           154         my ( %args ) = @_;
611           15                                141         my ($left, $right) = @args{qw(left_sth right_sth)};
612           15                                 50         MKDEBUG && _d('Found', $n_diff, 'of', $max_diff, 'max differences');
613           15    100                         110         if ( $n_diff >= $max_diff ) {
614            1                                 11            MKDEBUG && _d('Done comparing rows, got --max-differences', $max_diff);
615            1                                 20            $left->finish();
616            1                                 16            $right->finish();
617            1                                 42            return 1;
618                                                         }
619           14                                340         return 0;
620            6                                 83      };
621            6                                 23      my $trf;
622            6    100                          58      if ( my $n = $args{'float-precision'} ) {
623                                                         $trf = sub {
624            1                    1            19            my ( $l, $r, $tbl, $col ) = @_;
625   ***      1     50                          45            return $l, $r
626                                                               unless $tbl->{type_for}->{$col} =~ m/(?:float|double|decimal)/;
627            1                                 36            my $l_rounded = sprintf "%.${n}f", $l;
628            1                                 20            my $r_rounded = sprintf "%.${n}f", $r;
629            1                                 10            MKDEBUG && _d('Rounded', $l, 'to', $l_rounded,
630                                                               'and', $r, 'to', $r_rounded);
631            1                                 16            return $l_rounded, $r_rounded;
632            2                                 42         };
633                                                      };
634                                                   
635            6                                172      my $rd = new RowDiff(
636                                                         dbh          => $left_dbh,
637                                                         key_cmp      => $key_cmp,
638                                                         same_row     => $same_row,
639                                                         not_in_left  => $not_in_left,
640                                                         not_in_right => $not_in_right,
641                                                         done         => $done,
642                                                         trf          => $trf,
643                                                      );
644            6                                579      my $ch = new ChangeHandler(
645                                                         left_db    => $db,
646                                                         left_tbl   => 'mk_upgrade_left',
647                                                         right_db   => $db,
648                                                         right_tbl  => 'mk_upgrade_right',
649                                                         tbl_struct => $res_struct,
650                                                         queue      => 0,
651                                                         replace    => 0,
652                                                         actions    => [],
653                                                         Quoter     => $self->{Quoter},
654                                                      );
655                                                   
656                                                      # With whatever index we may have, let TableSyncer choose an
657                                                      # algorithm and find were rows differ.  We don't actually sync
658                                                      # the tables (execute=>0).  Instead, the callbacks above will
659                                                      # save rows in @missing_rows and @different_rows.
660            6                               2898      $self->{TableSyncer}->sync_table(
661                                                         plugins       => $self->{plugins},
662                                                         src           => {
663                                                            dbh => $left_dbh,
664                                                            db  => $db,
665                                                            tbl => 'mk_upgrade_left',
666                                                         },
667                                                         dst           => {
668                                                            dbh => $right_dbh,
669                                                            db  => $db,
670                                                            tbl => 'mk_upgrade_right',
671                                                         },
672                                                         tbl_struct    => $res_struct,
673                                                         cols          => $res_struct->{cols},
674                                                         chunk_size    => 1_000,
675                                                         RowDiff       => $rd,
676                                                         ChangeHandler => $ch,
677                                                      );
678                                                   
679            6    100                        3884      if ( $n_diff < $max_diff ) {
680            5    100    100                  107         $same_row->() if $l_r[LEFT] || $l_r[RIGHT];  # save remaining rows
681                                                      }
682                                                   
683                                                      # Switch back to the original dbs.
684            6                                154      $self->_use_db($left_dbh,  $orig_left_db);
685            6                                 47      $self->_use_db($right_dbh, $orig_right_db);
686                                                   
687            6                                667      return @different_rows;
688                                                   }
689                                                   
690                                                   # Writes the current row and all remaining rows to an outfile.
691                                                   # Returns the outfile's name.
692                                                   sub write_to_outfile {
693   ***     10                   10      0    130      my ( $self, %args ) = @_;
694           10                                 87      my @required_args = qw(side row sth Outfile);
695           10                                 81      foreach my $arg ( @required_args ) {
696   ***     40     50                         300         die "I need a $arg argument" unless $args{$arg};
697                                                      }
698           10                                 82      my ( $side, $row, $sth, $outfile ) = @args{@required_args};
699           10                                 96      my ( $fh, $file ) = $self->open_outfile(%args);
700                                                   
701                                                      # Write this one row.
702           10                                126      $outfile->write($fh, [ MockSyncStream::as_arrayref($sth, $row) ]);
703                                                   
704                                                      # Get and write all remaining rows.
705           10                               1309      my $remaining_rows = $sth->fetchall_arrayref();
706           10                                522      $outfile->write($fh, $remaining_rows);
707                                                   
708           10                                525      my $n_rows = 1 + @$remaining_rows;
709           10                                 52      MKDEBUG && _d('Wrote', $n_rows, 'rows');
710                                                   
711   ***     10     50                         868      close $fh or warn "Cannot close $file: $OS_ERROR";
712           10                                 45      return $file, $n_rows;
713                                                   }
714                                                   
715                                                   sub open_outfile {
716   ***     12                   12      0    128      my ( $self, %args ) = @_;
717           12                                144      my $outfile = $self->{'base-dir'} . "/$args{side}-outfile.txt";
718   ***     12     50                        1574      open my $fh, '>', $outfile or die "Cannot open $outfile: $OS_ERROR";
719           12                                 73      MKDEBUG && _d('Opened outfile', $outfile);
720           12                                171      return $fh, $outfile;
721                                                   }
722                                                   
723                                                   # Returns just the column definitions for the given struct.
724                                                   # Example:
725                                                   #   (
726                                                   #     `i` integer,
727                                                   #     `f` float(10,8)
728                                                   #   )
729                                                   sub make_table_ddl {
730   ***      6                    6      0     42      my ( $self, $struct ) = @_;
731            8                                 38      my $sql = "(\n"
732                                                              . (join("\n",
733                                                                    map {
734            6                                 54                       my $name = $_;
735            8                                 56                       my $type = $struct->{type_for}->{$_};
736            8           100                  103                       my $size = $struct->{size}->{$_} || '';
737            8                                 93                       "  `$name` $type$size,";
738            6                                 35                    } @{$struct->{cols}}))
739                                                              . ')';
740                                                      # The last column will be like "`i` integer,)" which is invalid.
741            6                                122      $sql =~ s/,\)$/\n)/;
742            6                                 18      MKDEBUG && _d('Table ddl:', $sql);
743            6                                 47      return $sql;
744                                                   }
745                                                   
746                                                   # Adds every index from every table used by the query to all the
747                                                   # dest tables.  dest is an arrayref of hashes, one for each destination.
748                                                   # Each hash needs a dbh and tbl key; e.g.:
749                                                   #   [
750                                                   #     {
751                                                   #       dbh => $dbh,
752                                                   #       tbl => 'db.tbl',
753                                                   #     },
754                                                   #   ],
755                                                   # For the moment, the sub returns nothing.  In the future, it should
756                                                   # add to $args{struct}->{keys} the keys that it was able to add.
757                                                   sub add_indexes {
758   ***      1                    1      0     28      my ( $self, %args ) = @_;
759            1                                 16      my @required_args = qw(query dsts db);
760            1                                 13      foreach my $arg ( @required_args ) {
761   ***      3     50                          27         die "I need a $arg argument" unless $args{$arg};
762                                                      }
763            1                                 10      my ($query, $dsts) = @args{@required_args};
764                                                   
765            1                                  7      my $qp = $self->{QueryParser};
766            1                                  5      my $tp = $self->{TableParser};
767            1                                  6      my $q  = $self->{Quoter};
768            1                                  5      my $du = $self->{MySQLDump};
769                                                   
770            1                                 25      my @src_tbls = $qp->get_tables($query);
771            1                                353      my @keys;
772            1                                  6      foreach my $db_tbl ( @src_tbls ) {
773            1                                 17         my ($db, $tbl) = $q->split_unquote($db_tbl, $args{db});
774   ***      1     50                          60         if ( $db ) {
775            1                                  4            my $tbl_struct;
776            1                                  6            eval {
777            1                                 26               $tbl_struct = $tp->parse(
778                                                                  $du->get_create_table($dsts->[0]->{dbh}, $q, $db, $tbl)
779                                                               );
780                                                            };
781   ***      1     50                        1290            if ( $EVAL_ERROR ) {
782   ***      0                                  0               MKDEBUG && _d('Error parsing', $db, '.', $tbl, ':', $EVAL_ERROR);
783   ***      0                                  0               next;
784                                                            }
785   ***      1     50                          14            push @keys, map {
786            1                                 10               my $def = ($_->{is_unique} ? 'UNIQUE ' : '')
787                                                                       . "KEY ($_->{colnames})";
788            1                                 24               [$def, $_];
789            1                                  6            } grep { $_->{type} eq 'BTREE' } values %{$tbl_struct->{keys}};
               1                                  8   
790                                                         }
791                                                         else {
792   ***      0                                  0            MKDEBUG && _d('Cannot get indexes from', $db_tbl, 'because its '
793                                                               . 'database is unknown');
794                                                         }
795                                                      }
796            1                                  3      MKDEBUG && _d('Source keys:', Dumper(\@keys));
797   ***      1     50                           9      return unless @keys;
798                                                   
799            1                                  7      for my $dst ( @$dsts ) {
800            2                                 15         foreach my $key ( @keys ) {
801            2                                 16            my $def = $key->[0];
802            2                                 25            my $sql = "ALTER TABLE $dst->{tbl} ADD $key->[0]";
803            2                                  7            MKDEBUG && _d($sql);
804            2                                 10            eval {
805            2                             177038               $dst->{dbh}->do($sql);
806                                                            };
807   ***      2     50                          66            if ( $EVAL_ERROR ) {
808   ***      0                                  0               MKDEBUG && _d($EVAL_ERROR);
809                                                            }
810                                                            else {
811                                                               # TODO: $args{res_struct}->{keys}->{$key->[1]->{name}} = $key->[1];
812                                                            }
813                                                         }
814                                                      }
815                                                   
816                                                      # If the query uses only 1 table then return its struct.
817                                                      # TODO: $args{struct} = $struct if @src_tbls == 1;
818            1                                 35      return;
819                                                   }
820                                                   
821                                                   sub report {
822   ***      4                    4      0     64      my ( $self, %args ) = @_;
823            4                                 46      my @required_args = qw(hosts);
824            4                                 36      foreach my $arg ( @required_args ) {
825   ***      4     50                          42         die "I need a $arg argument" unless $args{$arg};
826                                                      }
827            4                                 31      my ($hosts) = @args{@required_args};
828                                                   
829   ***      4     50                          18      return unless keys %{$self->{diffs}};
               4                                 43   
830                                                   
831                                                      # These columns are common to all the reports; make them just once.
832            4                                 28      my $query_id_col = {
833                                                         name        => 'Query ID',
834                                                      };
835            8                                 60      my @host_cols = map {
836            4                                 37         my $col = { name => $_->{name} };
837            8                                 55         $col;
838                                                      } @$hosts;
839                                                   
840            4                                 18      my @reports;
841            4                                 25      foreach my $diff ( qw(checksums col_vals row_counts) ) {
842           12                              17029         my $report = "_report_diff_$diff";
843           12                                184         push @reports, $self->$report(
844                                                            query_id_col => $query_id_col,
845                                                            host_cols    => \@host_cols,
846                                                            %args
847                                                         );
848                                                      }
849                                                   
850            4                              16004      return join("\n", @reports);
851                                                   }
852                                                   
853                                                   sub _report_diff_checksums {
854            4                    4            54      my ( $self, %args ) = @_;
855            4                                 50      my @required_args = qw(query_id_col host_cols);
856            4                                 36      foreach my $arg ( @required_args ) {
857   ***      8     50                          68         die "I need a $arg argument" unless $args{$arg};
858                                                      }
859                                                   
860            4                                 36      my $get_id = $self->{get_id};
861                                                   
862            4    100                          16      return unless keys %{$self->{diffs}->{checksums}};
               4                                 65   
863                                                   
864            1                                 17      my $report = new ReportFormatter();
865            1                                131      $report->set_title('Checksum differences');
866            1                                 14      $report->set_columns(
867                                                         $args{query_id_col},
868            1                                 32         @{$args{host_cols}},
869                                                      );
870                                                   
871            1                                559      my $diff_checksums = $self->{diffs}->{checksums};
872            1                                 12      foreach my $item ( sort keys %$diff_checksums ) {
873            1                                 76         map {
874   ***      0                                  0            $report->add_line(
875                                                               $get_id->($item) . '-' . $_,
876            1                                  8               @{$diff_checksums->{$item}->{$_}},
877                                                            );
878            1                                  5         } sort { $a <=> $b } keys %{$diff_checksums->{$item}};
               1                                  9   
879                                                      }
880                                                   
881            1                                240      return $report->get_report();
882                                                   }
883                                                   
884                                                   sub _report_diff_col_vals {
885            4                    4            54      my ( $self, %args ) = @_;
886            4                                 42      my @required_args = qw(query_id_col host_cols);
887            4                                 36      foreach my $arg ( @required_args ) {
888   ***      8     50                          78         die "I need a $arg argument" unless $args{$arg};
889                                                      }
890                                                   
891            4                                 26      my $get_id = $self->{get_id};
892                                                   
893            4    100                          17      return unless keys %{$self->{diffs}->{col_vals}};
               4                                 74   
894                                                   
895            2                                 65      my $report = new ReportFormatter();
896            2                                216      $report->set_title('Column value differences');
897            2                                 29      $report->set_columns(
898                                                         $args{query_id_col},
899                                                         {
900                                                            name => 'Column'
901                                                         },
902            2                                 71         @{$args{host_cols}},
903                                                      );
904            2                               1375      my $diff_col_vals = $self->{diffs}->{col_vals};
905            2                                 30      foreach my $item ( sort keys %$diff_col_vals ) {
906            2                                 15         foreach my $sampleno (sort {$a <=> $b} keys %{$diff_col_vals->{$item}}) {
      ***      0                                  0   
               2                                 22   
907            2                                 33            map {
908            2                                 15               $report->add_line(
909                                                                  $get_id->($item) . '-' . $sampleno,
910                                                                  @$_,
911                                                               );
912            2                                 10            } @{$diff_col_vals->{$item}->{$sampleno}};
913                                                         }
914                                                      }
915                                                   
916            2                                677      return $report->get_report();
917                                                   }
918                                                   
919                                                   sub _report_diff_row_counts {
920            4                    4            41      my ( $self, %args ) = @_;
921            4                                 44      my @required_args = qw(query_id_col hosts);
922            4                                 36      foreach my $arg ( @required_args ) {
923   ***      8     50                          73         die "I need a $arg argument" unless $args{$arg};
924                                                      }
925                                                   
926            4                                 24      my $get_id = $self->{get_id};
927                                                   
928            4    100                          18      return unless keys %{$self->{diffs}->{row_counts}};
               4                                 53   
929                                                   
930            3                                 51      my $report = new ReportFormatter();
931            3                                276      $report->set_title('Row count differences');
932            6                                 53      $report->set_columns(
933                                                         $args{query_id_col},
934                                                         map {
935            3                                 21            my $col = { name => $_->{name}, right_justify => 1  };
936            6                                 46            $col;
937            3                                 85         } @{$args{hosts}},
938                                                      );
939                                                   
940            3                               1523      my $diff_row_counts = $self->{diffs}->{row_counts};
941            3                                 31      foreach my $item ( sort keys %$diff_row_counts ) {
942            3                                136         map {
943   ***      0                                  0            $report->add_line(
944                                                               $get_id->($item) . '-' . $_,
945            3                                 34               @{$diff_row_counts->{$item}->{$_}},
946                                                            );
947            3                                 14         } sort { $a <=> $b } keys %{$diff_row_counts->{$item}};
               3                                 39   
948                                                      }
949                                                   
950            3                                675      return $report->get_report();
951                                                   }
952                                                   
953                                                   sub samples {
954   ***      2                    2      0     14      my ( $self, $item ) = @_;
955   ***      2     50                          14      return unless $item;
956            2                                  7      my @samples;
957            2                                  6      foreach my $sampleno ( keys %{$self->{samples}->{$item}} ) {
               2                                 21   
958            2                                 19         push @samples, $sampleno, $self->{samples}->{$item}->{$sampleno};
959                                                      }
960            2                                 35      return @samples;
961                                                   }
962                                                   
963                                                   sub reset {
964   ***      3                    3      0     30      my ( $self ) = @_;
965            3                                 32      $self->{diffs}   = {};
966            3                                 67      $self->{samples} = {};
967            3                                 37      return;
968                                                   }
969                                                   
970                                                   # USE $new_db, return current db before the switch.
971                                                   sub _use_db {
972           24                   24           201      my ( $self, $dbh, $new_db ) = @_;
973           24    100                         162      return unless $new_db;
974           22                                105      my $sql = 'SELECT DATABASE()';
975           22                                 75      MKDEBUG && _d($sql);
976           22                                 74      my $curr = $dbh->selectrow_array($sql);
977   ***     22    100     66                 5465      if ( $curr && $new_db && $curr eq $new_db ) {
      ***                   66                        
978           20                                 70         MKDEBUG && _d('Current and new DB are the same');
979           20                                146         return $curr;
980                                                      }
981            2                                 14      $sql = "USE `$new_db`";
982            2                                  8      MKDEBUG && _d($sql);
983            2                                258      $dbh->do($sql);
984            2                                 17      return $curr;
985                                                   }
986                                                   
987                                                   sub _d {
988            1                    1            14      my ($package, undef, $line) = caller 0;
989   ***      2     50                          27      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 15   
               2                                 18   
990            1                                  8           map { defined $_ ? $_ : 'undef' }
991                                                           @_;
992            1                                  6      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
993                                                   }
994                                                   
995                                                   1;
996                                                   
997                                                   # ###########################################################################
998                                                   # End CompareResults package
999                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***     50      0     36   unless $args{$arg}
71    ***     50      0     40   unless $args{$arg}
76           100      6     14   if ($$self{'method'} eq 'checksum')
78    ***     50      0      6   if $args{'temp-database'}
79    ***     50      0      6   unless $db
92    ***     50      0      6   if $EVAL_ERROR
123   ***     50      0     40   unless $args{$arg}
134          100     14      6   if ($$self{'method'} eq 'rows') { }
140   ***     50      0     14   if $EVAL_ERROR
148   ***     50      0     14   if $EVAL_ERROR
153   ***     50      0      6   unless $$event{'wrapped_query'}
161   ***     50      0      6   if ($EVAL_ERROR)
185   ***     50      0      7   unless $args{$arg}
210   ***     50      0     24   unless $args{$arg}
213          100      8      4   $$self{'method'} eq 'rows' ? :
221   ***     50      0      8   unless $args{$arg}
236          100      4      4   if ($i)
237          100      2      2   if (($$events[0]{'checksum'} || 0) != ($$events[$i]{'checksum'} || 0))
241          100      1      3   if (($$events[0]{'row_count'} || 0) != ($$events[$i]{'row_count'} || 0))
254          100      2      2   if ($different_checksums)
259          100      1      3   if ($different_row_counts)
277   ***     50      0     16   unless $args{$arg}
284          100      6      2   if ($$event{'wrapped_query'} and $$event{'tmp_tbl'}) { }
295   ***     50      0      6   if $EVAL_ERROR
321   ***     50      0     16   unless $args{$arg}
336          100      1      7   if (not $$event0{'results_sth'})
426          100      2      5   if $$event0{'row_count'} != $$event{'row_count'}
427          100      2      5   if ($different_row_counts)
434          100      1      6   if ($no_diff)
445          100      1      5   if (not $left_outfile)
449          100      1      5   if (not $right_outfile)
466          100      3      3   if (scalar @diff_rows)
506   ***     50      0     42   unless $args{$arg}
540          100      1      5   if ($args{'add-indexes'})
570          100      3      4   if ($l_r[0] and $l_r[1]) { }
             100      2      2   elsif ($l_r[0]) { }
             100      1      1   elsif ($l_r[1]) { }
596   ***     50      0      4   if $l_r[1]
598          100      3      1   if $l_r[0] and $l_r[1]
604          100      1      4   if $l_r[0]
606   ***     50      0      5   if $l_r[0] and $l_r[1]
613          100      1     14   if ($n_diff >= $max_diff)
622          100      2      4   if (my $n = $args{'float-precision'})
625   ***     50      0      1   unless $$tbl{'type_for'}{$col} =~ /(?:float|double|decimal)/
679          100      5      1   if ($n_diff < $max_diff)
680          100      2      3   if $l_r[0] or $l_r[1]
696   ***     50      0     40   unless $args{$arg}
711   ***     50      0     10   unless close $fh
718   ***     50      0     12   unless open my $fh, '>', $outfile
761   ***     50      0      3   unless $args{$arg}
774   ***     50      1      0   if ($db) { }
781   ***     50      0      1   if ($EVAL_ERROR)
785   ***     50      1      0   $$_{'is_unique'} ? :
797   ***     50      0      1   unless @keys
807   ***     50      0      2   if ($EVAL_ERROR) { }
825   ***     50      0      4   unless $args{$arg}
829   ***     50      0      4   unless keys %{$$self{'diffs'};}
857   ***     50      0      8   unless $args{$arg}
862          100      3      1   unless keys %{$$self{'diffs'}{'checksums'};}
888   ***     50      0      8   unless $args{$arg}
893          100      2      2   unless keys %{$$self{'diffs'}{'col_vals'};}
923   ***     50      0      8   unless $args{$arg}
928          100      1      3   unless keys %{$$self{'diffs'}{'row_counts'};}
955   ***     50      0      2   unless $item
973          100      2     22   unless $new_db
977          100     20      2   if ($curr and $new_db and $curr eq $new_db)
989   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
284   ***     66      2      0      6   $$event{'wrapped_query'} and $$event{'tmp_tbl'}
570          100      2      2      3   $l_r[0] and $l_r[1]
598   ***     66      1      0      3   $l_r[0] and $l_r[1]
606   ***     33      0      5      0   $l_r[0] and $l_r[1]
977   ***     66      2      0     20   $curr and $new_db
      ***     66      2      0     20   $curr and $new_db and $curr eq $new_db

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0
237          100      3      1   $$events[0]{'checksum'} || 0
             100      3      1   $$events[$i]{'checksum'} || 0
241          100      3      1   $$events[0]{'row_count'} || 0
             100      3      1   $$events[$i]{'row_count'} || 0
253          100      3      1   $$events[0]{'sampleno'} || 0
333          100      5      3   $$event0{'sampleno'} || 0
420          100      5      2   $n_rows || 0
553          100      1      5   $args{'max-different-rows'} || 1000
736          100      5      3   $$struct{'size'}{$_} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
252   ***     66      3      1      0   $$events[0]{'fingerprint'} || $$events[0]{'arg'}
332   ***     66      5      3      0   $$event0{'fingerprint'} || $$event0{'arg'}
454   ***     33      0      6      0   $args{'temp-database'} || $$event0{'db'}
680          100      1      1      3   $l_r[0] or $l_r[1]


Covered Subroutines
-------------------

Subroutine              Count Pod Location                                             
----------------------- ----- --- -----------------------------------------------------
BEGIN                       1     /home/daniel/dev/maatkit/common/CompareResults.pm:22 
BEGIN                       1     /home/daniel/dev/maatkit/common/CompareResults.pm:23 
BEGIN                       1     /home/daniel/dev/maatkit/common/CompareResults.pm:24 
BEGIN                       1     /home/daniel/dev/maatkit/common/CompareResults.pm:25 
BEGIN                       1     /home/daniel/dev/maatkit/common/CompareResults.pm:27 
BEGIN                       1     /home/daniel/dev/maatkit/common/CompareResults.pm:29 
BEGIN                       1     /home/daniel/dev/maatkit/common/CompareResults.pm:557
BEGIN                       1     /home/daniel/dev/maatkit/common/CompareResults.pm:558
__ANON__                    9     /home/daniel/dev/maatkit/common/CompareResults.pm:372
__ANON__                    5     /home/daniel/dev/maatkit/common/CompareResults.pm:376
__ANON__                    5     /home/daniel/dev/maatkit/common/CompareResults.pm:388
__ANON__                    4     /home/daniel/dev/maatkit/common/CompareResults.pm:563
__ANON__                    7     /home/daniel/dev/maatkit/common/CompareResults.pm:568
__ANON__                    4     /home/daniel/dev/maatkit/common/CompareResults.pm:594
__ANON__                    5     /home/daniel/dev/maatkit/common/CompareResults.pm:602
__ANON__                   15     /home/daniel/dev/maatkit/common/CompareResults.pm:610
__ANON__                    1     /home/daniel/dev/maatkit/common/CompareResults.pm:624
_checksum_results           8     /home/daniel/dev/maatkit/common/CompareResults.pm:274
_compare_checksums          4     /home/daniel/dev/maatkit/common/CompareResults.pm:218
_compare_rows               8     /home/daniel/dev/maatkit/common/CompareResults.pm:318
_d                          1     /home/daniel/dev/maatkit/common/CompareResults.pm:988
_report_diff_checksums      4     /home/daniel/dev/maatkit/common/CompareResults.pm:854
_report_diff_col_vals       4     /home/daniel/dev/maatkit/common/CompareResults.pm:885
_report_diff_row_counts     4     /home/daniel/dev/maatkit/common/CompareResults.pm:920
_use_db                    24     /home/daniel/dev/maatkit/common/CompareResults.pm:972
add_indexes                 1   0 /home/daniel/dev/maatkit/common/CompareResults.pm:758
after_execute               7   0 /home/daniel/dev/maatkit/common/CompareResults.pm:182
before_execute             20   0 /home/daniel/dev/maatkit/common/CompareResults.pm:68 
compare                    12   0 /home/daniel/dev/maatkit/common/CompareResults.pm:207
diff_rows                   6   0 /home/daniel/dev/maatkit/common/CompareResults.pm:502
execute                    20   0 /home/daniel/dev/maatkit/common/CompareResults.pm:120
make_table_ddl              6   0 /home/daniel/dev/maatkit/common/CompareResults.pm:730
new                         4   0 /home/daniel/dev/maatkit/common/CompareResults.pm:41 
open_outfile               12   0 /home/daniel/dev/maatkit/common/CompareResults.pm:716
report                      4   0 /home/daniel/dev/maatkit/common/CompareResults.pm:822
reset                       3   0 /home/daniel/dev/maatkit/common/CompareResults.pm:964
samples                     2   0 /home/daniel/dev/maatkit/common/CompareResults.pm:954
write_to_outfile           10   0 /home/daniel/dev/maatkit/common/CompareResults.pm:693


CompareResults.t

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
10             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 56;
               1                                  3   
               1                                  8   
13                                                    
14             1                    1            11   use Quoter;
               1                                  3   
               1                                  9   
15             1                    1            10   use MySQLDump;
               1                                  3   
               1                                 11   
16             1                    1            17   use TableParser;
               1                                  2   
               1                                 12   
17             1                    1            10   use DSNParser;
               1                                  4   
               1                                 12   
18             1                    1            14   use QueryParser;
               1                                  3   
               1                                 11   
19             1                    1            10   use TableSyncer;
               1                                  3   
               1                                 32   
20             1                    1            11   use TableChecksum;
               1                                  3   
               1                                 12   
21             1                    1            11   use VersionParser;
               1                                  3   
               1                                 10   
22             1                    1            13   use TableSyncGroupBy;
               1                                  3   
               1                                 11   
23             1                    1            10   use MockSyncStream;
               1                                  3   
               1                                 10   
24             1                    1            10   use MockSth;
               1                                  2   
               1                                 10   
25             1                    1            10   use Outfile;
               1                                  3   
               1                                 10   
26             1                    1            11   use RowDiff;
               1                                  3   
               1                                 10   
27             1                    1            11   use ChangeHandler;
               1                                  3   
               1                                 11   
28             1                    1            10   use ReportFormatter;
               1                                  4   
               1                                 11   
29             1                    1            12   use Transformers;
               1                                  3   
               1                                 14   
30             1                    1            11   use Sandbox;
               1                                  4   
               1                                 13   
31             1                    1            14   use CompareResults;
               1                                  3   
               1                                 12   
32             1                    1            20   use MaatkitTest;
               1                                  4   
               1                                 86   
33                                                    
34             1                                 12   my $dp  = new DSNParser(opts=>$dsn_opts);
35             1                                249   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
36    ***      1     50                          54   my $dbh1 = $sb->get_dbh_for('master')
37                                                       or BAIL_OUT('Cannot connect to sandbox master');
38    ***      1     50                         395   my $dbh2 = $sb->get_dbh_for('slave1')
39                                                       or BAIL_OUT('Cannot connect to sandbox slave1');
40                                                    
41             1                                253   $sb->create_dbs($dbh1, ['test']);
42                                                    
43             1                                710   Transformers->import(qw(make_checksum));
44                                                    
45             1                                184   my $vp = new VersionParser();
46             1                                 34   my $q  = new Quoter();
47             1                                 24   my $qp = new QueryParser();
48             1                                 25   my $du = new MySQLDump(cache => 0);
49             1                                 33   my $tp = new TableParser(Quoter => $q);
50             1                                 45   my $tc = new TableChecksum(Quoter => $q, VersionParser => $vp);
51             1                                 46   my $of = new Outfile();
52             1                                 30   my $ts = new TableSyncer(
53                                                       Quoter        => $q,
54                                                       VersionParser => $vp,
55                                                       TableChecksum => $tc,
56                                                       MasterSlave   => 1,
57                                                    );
58             1                                 59   my %modules = (
59                                                       VersionParser => $vp,
60                                                       Quoter        => $q,
61                                                       TableParser   => $tp,
62                                                       TableSyncer   => $ts,
63                                                       QueryParser   => $qp,
64                                                       MySQLDump     => $du,
65                                                       Outfile       => $of,
66                                                    );
67                                                    
68             1                                 10   my $plugin = new TableSyncGroupBy(Quoter => $q);
69                                                    
70             1                                 33   my $cr;
71             1                                  2   my $i;
72             1                                  2   my $report;
73             1                                  3   my @events;
74             1                                  7   my $hosts = [
75                                                       { dbh => $dbh1, name => 'master' },
76                                                       { dbh => $dbh2, name => 'slave'  },
77                                                    ];
78                                                    
79                                                    sub proc {
80            23                   23           245      my ( $when, %args ) = @_;
81    ***     23     50    100                  480      die "I don't know when $when is"
      ***                   66                        
82                                                          unless $when eq 'before_execute'
83                                                              || $when eq 'execute'
84                                                              || $when eq 'after_execute';
85            23                                269      for my $i ( 0..$#events ) {
86            46                                799         $events[$i] = $cr->$when(
87                                                             event    => $events[$i],
88                                                             dbh      => $hosts->[$i]->{dbh},
89                                                             %args,
90                                                          );
91                                                       }
92                                                    };
93                                                    
94                                                    sub get_id {
95             6                    6           100      return make_checksum(@_);
96                                                    }
97                                                    
98                                                    # #############################################################################
99                                                    # Test the checksum method.
100                                                   # #############################################################################
101                                                   
102            1                             456613   diag(`/tmp/12345/use < $trunk/common/t/samples/compare-results.sql`);
103                                                   
104            1                                 59   $cr = new CompareResults(
105                                                      method     => 'checksum',
106                                                      'base-dir' => '/dev/null',  # not used with checksum method
107                                                      plugins    => [$plugin],
108                                                      get_id     => \&get_id,
109                                                      %modules,
110                                                   );
111                                                   
112            1                                 21   isa_ok($cr, 'CompareResults');
113                                                   
114            1                                 31   @events = (
115                                                      {
116                                                         arg         => 'select * from test.t where i>0',
117                                                         fingerprint => 'select * from test.t where i>?',
118                                                         sampleno    => 1,
119                                                      },
120                                                      {
121                                                         arg         => 'select * from test.t where i>0',
122                                                         fingerprint => 'select * from test.t where i>?',
123                                                         sampleno    => 1,
124                                                      },
125                                                   );
126                                                   
127            1                                  5   $i = 0;
128                                                   MaatkitTest::wait_until(
129                                                      sub {
130            1                    1            49         my $r;
131            1                                  7         eval {
132            1                                  5            $r = $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"');
133                                                         };
134   ***      1     50     50                  647         return 1 if ($r->[0] || '') eq 'dropme';
135   ***      0      0                           0         diag('Waiting for CREATE TABLE...') unless $i++;
136   ***      0                                  0         return 0;
137                                                      },
138            1                                 37      0.5,
139                                                      30,
140                                                   );
141                                                   
142            1                                  4   is_deeply(
143                                                      $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
144                                                      ['dropme'],
145                                                      'checksum: temp table exists'
146                                                   );
147                                                   
148            1                                 53   proc('before_execute', db=>'test', 'temp-table'=>'dropme');
149                                                   
150            1                                 21   is(
151                                                      $events[0]->{wrapped_query},
152                                                      'CREATE TEMPORARY TABLE `test`.`dropme` AS select * from test.t where i>0',
153                                                      'checksum: before_execute() wraps query in CREATE TEMPORARY TABLE'
154                                                   );
155                                                   
156            1                                  5   is_deeply(
157                                                      $dbh1->selectall_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
158                                                      [],
159                                                      'checksum: before_execute() drops temp table'
160                                                   );
161                                                   
162            1                                 63   ok(
163                                                      !exists $events[0]->{Query_time},
164                                                      "checksum: Query_time doesn't exist before execute()"
165                                                   );
166                                                   
167            1                                 21   proc('execute');
168                                                   
169            1                                 17   ok(
170                                                      exists $events[0]->{Query_time},
171                                                      "checksum: Query_time exists after exectue()"
172                                                   );
173                                                   
174            1                                 53   like(
175                                                      $events[0]->{Query_time},
176                                                      qr/^[\d.]+$/,
177                                                      "checksum: Query_time is a number ($events[0]->{Query_time})"
178                                                   );
179                                                   
180            1                                 26   is(
181                                                      $events[0]->{wrapped_query},
182                                                      'CREATE TEMPORARY TABLE `test`.`dropme` AS select * from test.t where i>0',
183                                                      "checksum: execute() doesn't unwrap query"
184                                                   );
185                                                   
186            1                                  4   is_deeply(
187                                                      $dbh1->selectall_arrayref('select * from test.dropme'),
188                                                      [[1],[2],[3]],
189                                                      'checksum: Result set selected into the temp table'
190                                                   );
191                                                   
192            1                                 58   ok(
193                                                      !exists $events[0]->{row_count},
194                                                      "checksum: row_count doesn't exist before after_execute()"
195                                                   );
196                                                   
197            1                                 12   ok(
198                                                      !exists $events[0]->{checksum},
199                                                      "checksum: checksum doesn't exist before after_execute()"
200                                                   );
201                                                   
202            1                                  9   proc('after_execute');
203                                                   
204            1                                 12   is(
205                                                      $events[0]->{wrapped_query},
206                                                      'CREATE TEMPORARY TABLE `test`.`dropme` AS select * from test.t where i>0',
207                                                      'checksum: after_execute() left wrapped query'
208                                                   );
209                                                   
210            1                                  4   is_deeply(
211                                                      $dbh1->selectall_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
212                                                      [],
213                                                      'checksum: after_execute() drops temp table'
214                                                   );
215                                                   
216            1                                 58   is_deeply(
217                                                      [ $cr->compare(
218                                                         events => \@events,
219                                                         hosts  => $hosts,
220                                                      ) ],
221                                                      [
222                                                         different_row_counts    => 0,
223                                                         different_checksums     => 0,
224                                                         different_column_counts => 0,
225                                                         different_column_types  => 0,
226                                                      ],
227                                                      'checksum: compare, no differences'
228                                                   );
229                                                   
230            1                                 25   is(
231                                                      $events[0]->{row_count},
232                                                      3,
233                                                      "checksum: correct row_count after after_execute()"
234                                                   );
235                                                   
236            1                                 11   is(
237                                                      $events[0]->{checksum},
238                                                      '251493421',
239                                                      "checksum: correct checksum after after_execute()"
240                                                   );
241                                                   
242            1                                 11   ok(
243                                                      !exists $events[0]->{wrapped_query},
244                                                      'checksum: wrapped query removed after compare'
245                                                   );
246                                                   
247                                                   # Make checksums differ.
248            1                                360   $dbh2->do('update test.t set i = 99 where i=1');
249                                                   
250            1                                 10   proc('before_execute', db=>'test', 'temp-table'=>'dropme');
251            1                                  9   proc('execute');
252            1                                 10   proc('after_execute');
253                                                   
254            1                                 15   is_deeply(
255                                                      [ $cr->compare(
256                                                         events => \@events,
257                                                         hosts  => $hosts,
258                                                      ) ],
259                                                      [
260                                                         different_row_counts    => 0,
261                                                         different_checksums     => 1,
262                                                         different_column_counts => 0,
263                                                         different_column_types  => 0,
264                                                      ],
265                                                      'checksum: compare, different checksums' 
266                                                   );
267                                                   
268                                                   # Make row counts differ, too.
269            1                                353   $dbh2->do('insert into test.t values (4)');
270                                                   
271            1                                 11   proc('before_execute', db=>'test', 'temp-table'=>'dropme');
272            1                                  8   proc('execute');
273            1                                  9   proc('after_execute');
274                                                   
275            1                                 13   is_deeply(
276                                                      [ $cr->compare(
277                                                         events => \@events,
278                                                         hosts  => $hosts,
279                                                      ) ],
280                                                      [
281                                                         different_row_counts    => 1,
282                                                         different_checksums     => 1,
283                                                         different_column_counts => 0,
284                                                         different_column_types  => 0,
285                                                      ],
286                                                      'checksum: compare, different checksums and row counts'
287                                                   );
288                                                   
289            1                                 30   $report = <<EOF;
290                                                   # Checksum differences
291                                                   # Query ID           master    slave
292                                                   # ================== ========= ==========
293                                                   # D2D386B840D3BEEA-1 $events[0]->{checksum} $events[1]->{checksum}
294                                                   
295                                                   # Row count differences
296                                                   # Query ID           master slave
297                                                   # ================== ====== =====
298                                                   # D2D386B840D3BEEA-1      3     4
299                                                   EOF
300                                                   
301            1                                 28   is(
302                                                      $cr->report(hosts => $hosts),
303                                                      $report,
304                                                      'checksum: report'
305                                                   );
306                                                   
307            1                                 14   my %samples = $cr->samples($events[0]->{fingerprint});
308            1                                  8   is_deeply(
309                                                      \%samples,
310                                                      {
311                                                         1 => 'select * from test.t where i>0',
312                                                      },
313                                                      'checksum: samples'
314                                                   );
315                                                   
316                                                   # #############################################################################
317                                                   # Test the rows method.
318                                                   # #############################################################################
319                                                   
320            1                                  8   my $tmpdir = '/tmp/mk-upgrade-res';
321                                                   
322            1                             668472   diag(`/tmp/12345/use < $trunk/common/t/samples/compare-results.sql`);
323            1                              14917   diag(`rm -rf $tmpdir; mkdir $tmpdir`);
324                                                   
325            1                                 81   $cr = new CompareResults(
326                                                      method     => 'rows',
327                                                      'base-dir' => $tmpdir,
328                                                      plugins    => [$plugin],
329                                                      get_id     => \&get_id,
330                                                      %modules,
331                                                   );
332                                                   
333            1                                 96   isa_ok($cr, 'CompareResults');
334                                                   
335            1                                 85   @events = (
336                                                      {
337                                                         arg => 'select * from test.t',
338                                                         db  => 'test',
339                                                      },
340                                                      {
341                                                         arg => 'select * from test.t',
342                                                         db  => 'test',
343                                                      },
344                                                   );
345                                                   
346            1                                 11   $i = 0;
347                                                   MaatkitTest::wait_until(
348                                                      sub {
349            1                    1            52         my $r;
350            1                                  7         eval {
351            1                                  6            $r = $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"');
352                                                         };
353   ***      1     50     50                  756         return 1 if ($r->[0] || '') eq 'dropme';
354   ***      0      0                           0         diag('Waiting for CREATE TABLE...') unless $i++;
355   ***      0                                  0         return 0;
356                                                      },
357            1                                 40      0.5,
358                                                      30,
359                                                   );
360                                                   
361            1                                  6   is_deeply(
362                                                      $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
363                                                      ['dropme'],
364                                                      'rows: temp table exists'
365                                                   );
366                                                   
367            1                                 55   proc('before_execute');
368                                                   
369            1                                 19   is(
370                                                      $events[0]->{arg},
371                                                      'select * from test.t',
372                                                      "rows: before_execute() doesn't wrap query and doesn't require tmp table"
373                                                   );
374                                                   
375            1                                  4   is_deeply(
376                                                      $dbh1->selectrow_arrayref('SHOW TABLES FROM test LIKE "dropme"'),
377                                                      ['dropme'],
378                                                      "rows: before_execute() doesn't drop temp table"
379                                                   );
380                                                   
381            1                                 67   ok(
382                                                      !exists $events[0]->{Query_time},
383                                                      "rows: Query_time doesn't exist before execute()"
384                                                   );
385                                                   
386            1                                 12   ok(
387                                                      !exists $events[0]->{results_sth},
388                                                      "rows: results_sth doesn't exist before execute()"
389                                                   );
390                                                   
391            1                                  8   proc('execute');
392                                                   
393            1                                 17   ok(
394                                                      exists $events[0]->{Query_time},
395                                                      "rows: query_time exists after exectue()"
396                                                   );
397                                                   
398            1                                 15   ok(
399                                                      exists $events[0]->{results_sth},
400                                                      "rows: results_sth exists after exectue()"
401                                                   );
402                                                   
403            1                                 43   like(
404                                                      $events[0]->{Query_time},
405                                                      qr/^[\d.]+$/,
406                                                      "rows: Query_time is a number ($events[0]->{Query_time})"
407                                                   );
408                                                   
409            1                                 18   ok(
410                                                      !exists $events[0]->{row_count},
411                                                      "rows: row_count doesn't exist before after_execute()"
412                                                   );
413                                                   
414            1                                 15   is_deeply(
415                                                      $cr->after_execute(event=>$events[0]),
416                                                      $events[0],
417                                                      "rows: after_execute() doesn't modify the event"
418                                                   );
419                                                   
420            1                                 26   is_deeply(
421                                                      [ $cr->compare(
422                                                         events => \@events,
423                                                         hosts  => $hosts,
424                                                      ) ],
425                                                      [
426                                                         different_row_counts    => 0,
427                                                         different_column_values => 0,
428                                                         different_column_counts => 0,
429                                                         different_column_types  => 0,
430                                                      ],
431                                                      'rows: compare, no differences'
432                                                   );
433                                                   
434            1                                 28   is(
435                                                      $events[0]->{row_count},
436                                                      3,
437                                                      "rows: compare() sets row_count"
438                                                   );
439                                                   
440            1                                 12   is(
441                                                      $events[1]->{row_count},
442                                                      3,
443                                                      "rows: compare() sets row_count"
444                                                   );
445                                                   
446                                                   # Make the result set differ.
447            1                                361   $dbh2->do('insert into test.t values (5)');
448                                                   
449            1                                 11   proc('before_execute');
450            1                                  8   proc('execute');
451                                                   
452            1                                 15   is_deeply(
453                                                      [ $cr->compare(
454                                                         events => \@events,
455                                                         hosts  => $hosts,
456                                                      ) ],
457                                                      [
458                                                         different_row_counts    => 1,
459                                                         different_column_values => 0,
460                                                         different_column_counts => 0,
461                                                         different_column_types  => 0,
462                                                      ],
463                                                      'rows: compare, different row counts'
464                                                   );
465                                                   
466                                                   # Use test.t2 and make a column value differ.
467            1                                 49   @events = (
468                                                      {
469                                                         arg         => 'select * from test.t2',
470                                                         db          => 'test',
471                                                         fingerprint => 'select * from test.t2',
472                                                         sampleno    => 3,
473                                                      },
474                                                      {
475                                                         arg         => 'select * from test.t2',
476                                                         db          => 'test',
477                                                         fingerprint => 'select * from test.t2',
478                                                         sampleno    => 3,
479                                                      },
480                                                   );
481                                                   
482            1                                445   $dbh2->do('update test.t2 set c="should be c" where i=3');
483                                                   
484            1                                  4   is_deeply(
485                                                      $dbh2->selectrow_arrayref('select c from test.t2 where i=3'),
486                                                      ['should be c'],
487                                                      'rows: column value is different'
488                                                   );
489                                                   
490            1                                 62   proc('before_execute');
491            1                                  7   proc('execute');
492                                                   
493            1                                 19   is_deeply(
494                                                      [ $cr->compare(
495                                                         events => \@events,
496                                                         hosts  => $hosts,
497                                                      ) ],
498                                                      [
499                                                         different_row_counts    => 0,
500                                                         different_column_values => 1,
501                                                         different_column_counts => 0,
502                                                         different_column_types  => 0,
503                                                      ],
504                                                      'rows: compare, different column values'
505                                                   );
506                                                   
507            1                                  4   is_deeply(
508                                                      $dbh1->selectall_arrayref('show indexes from test.mk_upgrade_left'),
509                                                      [],
510                                                      'Did not add indexes'
511                                                   );
512                                                   
513            1                                 50   $report = <<EOF;
514                                                   # Column value differences
515                                                   # Query ID           Column master slave
516                                                   # ================== ====== ====== ===========
517                                                   # CFC309761E9131C5-3 c      c      should be c
518                                                   
519                                                   # Row count differences
520                                                   # Query ID           master slave
521                                                   # ================== ====== =====
522                                                   # B8B721D77EA1FD78-0      3     4
523                                                   EOF
524                                                   
525            1                                 23   is(
526                                                      $cr->report(hosts => $hosts),
527                                                      $report,
528                                                      'rows: report'
529                                                   );
530                                                   
531            1                                 23   %samples = $cr->samples($events[0]->{fingerprint});
532            1                                 15   is_deeply(
533                                                      \%samples,
534                                                      {
535                                                         3 => 'select * from test.t2'
536                                                      },
537                                                      'rows: samples'
538                                                   );
539                                                   
540                                                   # #############################################################################
541                                                   # Test max-different-rows.
542                                                   # #############################################################################
543            1                                 31   $cr->reset();
544            1                                514   $dbh2->do('update test.t2 set c="should be a" where i=1');
545            1                                268   $dbh2->do('update test.t2 set c="should be b" where i=2');
546            1                                  9   proc('before_execute');
547            1                                  7   proc('execute');
548                                                   
549            1                                 22   is_deeply(
550                                                      [ $cr->compare(
551                                                         events => \@events,
552                                                         hosts  => $hosts,
553                                                         'max-different-rows' => 1,
554                                                         'add-indexes'        => 1,
555                                                      ) ],
556                                                      [
557                                                         different_row_counts    => 0,
558                                                         different_column_values => 1,
559                                                         different_column_counts => 0,
560                                                         different_column_types  => 0,
561                                                      ],
562                                                      'rows: compare, stop at max-different-rows'
563                                                   );
564                                                   
565            1                                  7   is_deeply(
566                                                      $dbh1->selectall_arrayref('show indexes from test.mk_upgrade_left'),
567                                                      [['mk_upgrade_left','0','i','1','i','A',undef,undef, undef,'YES','BTREE','']],
568                                                      'Added indexes'
569                                                   );
570                                                   
571            1                                 56   $report = <<EOF;
572                                                   # Column value differences
573                                                   # Query ID           Column master slave
574                                                   # ================== ====== ====== ===========
575                                                   # CFC309761E9131C5-3 c      a      should be a
576                                                   EOF
577                                                   
578            1                                 22   is(
579                                                      $cr->report(hosts => $hosts),
580                                                      $report,
581                                                      'rows: report max-different-rows'
582                                                   );
583                                                   
584                                                   # #############################################################################
585                                                   # Double check that outfiles have correct contents.
586                                                   # #############################################################################
587                                                   
588                                                   # This test uses the results from the max-different-rows test above.
589                                                   
590            1                               5677   my @outfile = split(/[\t\n]+/, `cat /tmp/mk-upgrade-res/left-outfile.txt`);
591            1                                 81   is_deeply(
592                                                   	\@outfile,
593                                                   	[qw(1 a 2 b 3 c)],
594                                                      'Left outfile'
595                                                   );
596                                                   
597            1                               5694   @outfile = split(/[\t\n]+/, `cat /tmp/mk-upgrade-res/right-outfile.txt`);
598            1                                 71   is_deeply(
599                                                   	\@outfile,
600                                                   	['1', 'should be a', '2', 'should be b', '3', 'should be c'],
601                                                      'Right outfile'
602                                                   );
603                                                   
604                                                   # #############################################################################
605                                                   # Test float-precision.
606                                                   # #############################################################################
607            1                                 99   @events = (
608                                                      {
609                                                         arg         => 'select * from test.t3',
610                                                         db          => 'test',
611                                                         fingerprint => 'select * from test.t3',
612                                                         sampleno    => 3,
613                                                      },
614                                                      {
615                                                         arg         => 'select * from test.t3',
616                                                         db          => 'test',
617                                                         fingerprint => 'select * from test.t3',
618                                                         sampleno    => 3,
619                                                      },
620                                                   );
621                                                   
622            1                                 33   $cr->reset();
623            1                                455   $dbh2->do('update test.t3 set f=1.12346 where 1');
624            1                                 26   proc('before_execute');
625            1                                  8   proc('execute');
626                                                   
627            1                                 23   is_deeply(
628                                                      [ $cr->compare(
629                                                         events => \@events,
630                                                         hosts  => $hosts,
631                                                      ) ],
632                                                      [
633                                                         different_row_counts    => 0,
634                                                         different_column_values => 1,
635                                                         different_column_counts => 0,
636                                                         different_column_types  => 0,
637                                                      ],
638                                                      'rows: compare, different without float-precision'
639                                                   );
640                                                   
641            1                                 45   proc('before_execute');
642            1                                  8   proc('execute');
643                                                   
644            1                                 23   is_deeply(
645                                                      [ $cr->compare(
646                                                         events => \@events,
647                                                         hosts  => $hosts,
648                                                         'float-precision' => 3
649                                                      ) ],
650                                                      [
651                                                         different_row_counts    => 0,
652                                                         different_column_values => 0,
653                                                         different_column_counts => 0,
654                                                         different_column_types  => 0,
655                                                      ],
656                                                      'rows: compare, not different with float-precision'
657                                                   );
658                                                   
659                                                   # #############################################################################
660                                                   # Test when left has more rows than right.
661                                                   # #############################################################################
662            1                                 36   $cr->reset();
663            1                                394   $dbh1->do('update test.t3 set f=0 where 1');
664            1                                143   $dbh1->do('SET SQL_LOG_BIN=0');
665            1                                205   $dbh1->do('insert into test.t3 values (2.0),(3.0)');
666            1                                109   $dbh1->do('SET SQL_LOG_BIN=1');
667                                                   
668            1                                  5   my $left_n_rows = $dbh1->selectcol_arrayref('select count(*) from test.t3')->[0];
669            1                                  5   my $right_n_rows = $dbh2->selectcol_arrayref('select count(*) from test.t3')->[0];
670   ***      1            33                  353   ok(
671                                                      $left_n_rows == 3 && $right_n_rows == 1,
672                                                      'Left has extra rows'
673                                                   );
674                                                   
675            1                                 24   proc('before_execute');
676            1                                  8   proc('execute');
677                                                   
678            1                                 15   is_deeply(
679                                                      [ $cr->compare(
680                                                         events => \@events,
681                                                         hosts  => $hosts,
682                                                         'float-precision' => 3
683                                                      ) ],
684                                                      [
685                                                         different_row_counts    => 1,
686                                                         different_column_values => 0,
687                                                         different_column_counts => 0,
688                                                         different_column_types  => 0,
689                                                      ],
690                                                      'rows: compare, left with more rows'
691                                                   );
692                                                   
693            1                                 26   $report = <<EOF;
694                                                   # Row count differences
695                                                   # Query ID           master slave
696                                                   # ================== ====== =====
697                                                   # D56E6FABA26D1F1C-3      3     1
698                                                   EOF
699                                                   
700            1                                 22   is(
701                                                      $cr->report(hosts => $hosts),
702                                                      $report,
703                                                      'rows: report, left with more rows'
704                                                   );
705                                                   
706                                                   # #############################################################################
707                                                   # Try to compare without having done the actions.
708                                                   # #############################################################################
709            1                                 41   @events = (
710                                                      {
711                                                         arg => 'select * from test.t',
712                                                         db  => 'test',
713                                                      },
714                                                      {
715                                                         arg => 'select * from test.t',
716                                                         db  => 'test',
717                                                      },
718                                                   );
719                                                   
720            1                                 64   $cr = new CompareResults(
721                                                      method     => 'checksum',
722                                                      'base-dir' => '/dev/null',  # not used with checksum method
723                                                      plugins    => [$plugin],
724                                                      get_id     => \&get_id,
725                                                      %modules,
726                                                   );
727                                                   
728            1                                 29   my @diffs;
729            1                                  6   eval {
730            1                                 12      @diffs = $cr->compare(events => \@events, hosts => $hosts);
731                                                   };
732                                                   
733            1                                 10   is(
734                                                      $EVAL_ERROR,
735                                                      '',
736                                                      "compare() checksums without actions doesn't die"
737                                                   );
738                                                   
739            1                                 22   is_deeply(
740                                                      \@diffs,
741                                                      [
742                                                         different_row_counts    => 0,
743                                                         different_checksums     => 0,
744                                                         different_column_counts => 0,
745                                                         different_column_types  => 0,
746                                                      ],
747                                                      'No differences after bad compare()'
748                                                   );
749                                                   
750            1                                 34   $cr = new CompareResults(
751                                                      method     => 'rows',
752                                                      'base-dir' => $tmpdir,
753                                                      plugins    => [$plugin],
754                                                      get_id     => \&get_id,
755                                                      %modules,
756                                                   );
757                                                   
758            1                                 11   eval {
759            1                                 11      @diffs = $cr->compare(events => \@events, hosts => $hosts);
760                                                   };
761                                                   
762            1                                 11   is(
763                                                      $EVAL_ERROR,
764                                                      '',
765                                                      "compare() rows without actions doesn't die"
766                                                   );
767                                                   
768            1                                 16   is_deeply(
769                                                      \@diffs,
770                                                      [
771                                                         different_row_counts    => 0,
772                                                         different_column_values => 0,
773                                                         different_column_counts => 0,
774                                                         different_column_types  => 0,
775                                                      ],
776                                                      'No differences after bad compare()'
777                                                   );
778                                                   
779                                                   # #############################################################################
780                                                   # Done.
781                                                   # #############################################################################
782            1                                 15   my $output = '';
783                                                   {
784            1                                  5      local *STDERR;
               1                                 29   
785            1                    1             3      open STDERR, '>', \$output;
               1                                557   
               1                                  4   
               1                                 13   
786            1                                 35      $cr->_d('Complete test coverage');
787                                                   }
788                                                   like(
789            1                                 34      $output,
790                                                      qr/Complete test coverage/,
791                                                      '_d() works'
792                                                   );
793            1                               5895   diag(`rm -rf $tmpdir`);
794            1                              11809   diag(`rm -rf /tmp/*outfile.txt`);
795            1                                 42   $sb->wipe_clean($dbh1);
796            1                                  9   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
36    ***     50      0      1   unless my $dbh1 = $sb->get_dbh_for('master')
38    ***     50      0      1   unless my $dbh2 = $sb->get_dbh_for('slave1')
81    ***     50      0     23   unless $when eq 'before_execute' or $when eq 'execute' or $when eq 'after_execute'
134   ***     50      1      0   if ($$r[0] || '') eq 'dropme'
135   ***      0      0      0   unless $i++
353   ***     50      1      0   if ($$r[0] || '') eq 'dropme'
354   ***      0      0      0   unless $i++


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
670   ***     33      0      0      1   $left_n_rows == 3 && $right_n_rows == 1

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
134   ***     50      1      0   $$r[0] || ''
353   ***     50      1      0   $$r[0] || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
81           100     10     10      3   $when eq 'before_execute' or $when eq 'execute'
      ***     66     20      3      0   $when eq 'before_execute' or $when eq 'execute' or $when eq 'after_execute'


Covered Subroutines
-------------------

Subroutine Count Location            
---------- ----- --------------------
BEGIN          1 CompareResults.t:10 
BEGIN          1 CompareResults.t:11 
BEGIN          1 CompareResults.t:12 
BEGIN          1 CompareResults.t:14 
BEGIN          1 CompareResults.t:15 
BEGIN          1 CompareResults.t:16 
BEGIN          1 CompareResults.t:17 
BEGIN          1 CompareResults.t:18 
BEGIN          1 CompareResults.t:19 
BEGIN          1 CompareResults.t:20 
BEGIN          1 CompareResults.t:21 
BEGIN          1 CompareResults.t:22 
BEGIN          1 CompareResults.t:23 
BEGIN          1 CompareResults.t:24 
BEGIN          1 CompareResults.t:25 
BEGIN          1 CompareResults.t:26 
BEGIN          1 CompareResults.t:27 
BEGIN          1 CompareResults.t:28 
BEGIN          1 CompareResults.t:29 
BEGIN          1 CompareResults.t:30 
BEGIN          1 CompareResults.t:31 
BEGIN          1 CompareResults.t:32 
BEGIN          1 CompareResults.t:4  
BEGIN          1 CompareResults.t:785
BEGIN          1 CompareResults.t:9  
__ANON__       1 CompareResults.t:130
__ANON__       1 CompareResults.t:349
get_id         6 CompareResults.t:95 
proc          23 CompareResults.t:80 


