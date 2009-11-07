---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/CompareResults.pm   98.5   72.3   81.0  100.0    n/a  100.0   92.4
Total                          98.5   72.3   81.0  100.0    n/a  100.0   92.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          CompareResults.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Nov  7 17:23:14 2009
Finish:       Sat Nov  7 17:23:18 2009

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
18                                                    # CompareResults package $Revision: 5066 $
19                                                    # ###########################################################################
20                                                    package CompareResults;
21                                                    
22             1                    1             7   use strict;
               1                                  6   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  4   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25             1                    1             6   use Time::HiRes qw(time);
               1                                  2   
               1                                  5   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  6   
28                                                    
29             1                    1             6   use Data::Dumper;
               1                                  6   
               1                                  5   
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
41             4                    4        874879      my ( $class, %args ) = @_;
42             4                                 70      my @required_args = qw(method base-dir plugins get_id
43                                                                              QueryParser MySQLDump TableParser TableSyncer Quoter);
44             4                                 35      foreach my $arg ( @required_args ) {
45    ***     36     50                         277         die "I need a $arg argument" unless $args{$arg};
46                                                       }
47             4                                101      my $self = {
48                                                          %args,
49                                                          diffs   => {},
50                                                          samples => {},
51                                                       };
52             4                                112      return bless $self, $class;
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
68            20                   20          1238      my ( $self, %args ) = @_;
69            20                                171      my @required_args = qw(event dbh);
70            20                                114      foreach my $arg ( @required_args ) {
71    ***     40     50                         335         die "I need a $arg argument" unless $args{$arg};
72                                                       }
73            20                                144      my ($event, $dbh) = @args{@required_args};
74            20                                 69      my $sql;
75                                                    
76            20    100                         159      if ( $self->{method} eq 'checksum' ) {
77             6                                 45         my ($db, $tmp_tbl) = @args{qw(db temp-table)};
78    ***      6     50                          43         $db = $args{'temp-database'} if $args{'temp-database'};
79    ***      6     50                          35         die "Cannot checksum results without a database"
80                                                             unless $db;
81                                                    
82             6                                 69         $tmp_tbl = $self->{Quoter}->quote($db, $tmp_tbl);
83             6                                 27         eval {
84             6                                 32            $sql = "DROP TABLE IF EXISTS $tmp_tbl";
85             6                                 19            MKDEBUG && _d($sql);
86             6                               1638            $dbh->do($sql);
87                                                    
88             6                                 59            $sql = "SET storage_engine=MyISAM";
89             6                                 18            MKDEBUG && _d($sql);
90             6                                948            $dbh->do($sql);
91                                                          };
92    ***      6     50                          53         die "Failed to drop temporary table $tmp_tbl: $EVAL_ERROR"
93                                                             if $EVAL_ERROR;
94                                                    
95                                                          # Save the tmp tbl; it's used later in _compare_checksums().
96             6                                 45         $event->{tmp_tbl} = $tmp_tbl; 
97                                                    
98                                                          # Wrap the original query so when it's executed its results get
99                                                          # put in tmp table.
100            6                                 72         $event->{wrapped_query}
101                                                            = "CREATE TEMPORARY TABLE $tmp_tbl AS $event->{arg}";
102            6                                 22         MKDEBUG && _d('Wrapped query:', $event->{wrapped_query});
103                                                      }
104                                                   
105           20                                272      return $event;
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
120           20                   20           524      my ( $self, %args ) = @_;
121           20                                152      my @required_args = qw(event dbh);
122           20                                118      foreach my $arg ( @required_args ) {
123   ***     40     50                         337         die "I need a $arg argument" unless $args{$arg};
124                                                      }
125           20                                145      my ($event, $dbh) = @args{@required_args};
126           20                                 91      my ( $start, $end, $query_time );
127                                                   
128                                                      # Other modules should only execute the query if Query_time does not
129                                                      # already exist.  This module requires special execution so we always
130                                                      # execute.
131                                                   
132           20                                 67      MKDEBUG && _d('Executing query');
133           20                                122      $event->{Query_time} = 0;
134           20    100                         170      if ( $self->{method} eq 'rows' ) {
135           14                                 83         my $query = $event->{arg};
136           14                                 61         my $sth;
137           14                                 64         eval {
138           14                                 48            $sth = $dbh->prepare($query);
139                                                         };
140   ***     14     50                         164         die "Failed to prepare query: $EVAL_ERROR" if $EVAL_ERROR;
141                                                   
142           14                                 58         eval {
143           14                                116            $start = time();
144           14                               4561            $sth->execute();
145           14                                140            $end   = time();
146           14                                293            $query_time = sprintf '%.6f', $end - $start;
147                                                         };
148   ***     14     50                          96         die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
149                                                   
150           14                                119         $event->{results_sth} = $sth;
151                                                      }
152                                                      else {
153   ***      6     50                          48         die "No wrapped query" unless $event->{wrapped_query};
154            6                                 38         my $query = $event->{wrapped_query};
155            6                                 27         eval {
156            6                                 51            $start = time();
157            6                               6072            $dbh->do($query);
158            6                                 78            $end   = time();
159            6                                164            $query_time = sprintf '%.6f', $end - $start;
160                                                         };
161   ***      6     50                          54         die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
162                                                      }
163                                                   
164           20                                399      $event->{Query_time} = $query_time;
165                                                   
166           20                                337      return $event;
167                                                   }
168                                                   
169                                                   # Required args:
170                                                   #   * event  hashref: an event
171                                                   # Optional args:
172                                                   #   * dbh    scalar: active dbh
173                                                   # Returns: hashref
174                                                   # Can die: yes
175                                                   # after_execute() does any post-execution cleanup.  The results should
176                                                   # not be compared here; no anaylytics here, save that for compare().
177                                                   sub after_execute {
178            7                    7           129      my ( $self, %args ) = @_;
179            7                                 50      my @required_args = qw(event);
180            7                                 38      foreach my $arg ( @required_args ) {
181   ***      7     50                          69         die "I need a $arg argument" unless $args{$arg};
182                                                      }
183            7                                 82      return $args{event};
184                                                   }
185                                                   
186                                                   # Required args:
187                                                   #   * events  arrayref: events
188                                                   #   * hosts   arrayref: hosts hashrefs with at least a dbh key
189                                                   # Returns: array
190                                                   # Can die: yes
191                                                   # compare() compares events that have been run through before_execute(),
192                                                   # execute() and after_execute().  The checksum method primarily compares
193                                                   # the checksum attribs saved in the events.  The rows method uses the
194                                                   # result statement handles saved in the events to compare rows and column
195                                                   # values.  Each method returns an array of key => value pairs which the
196                                                   # caller should aggregate into a meta-event that represents differences
197                                                   # compare() has found in these events.  Only a "summary" of differences is
198                                                   # returned.  Specific differences are saved internally and are reported
199                                                   # by calling report() later.
200                                                   sub compare {
201           12                   12           259      my ( $self, %args ) = @_;
202           12                                 91      my @required_args = qw(events hosts);
203           12                                 79      foreach my $arg ( @required_args ) {
204   ***     24     50                         213         die "I need a $arg argument" unless $args{$arg};
205                                                      }
206           12                                 92      my ($events, $hosts) = @args{@required_args};
207           12    100                         220      return $self->{method} eq 'rows' ? $self->_compare_rows(%args)
208                                                                                       : $self->_compare_checksums(%args);
209                                                   }
210                                                   
211                                                   sub _compare_checksums {
212            4                    4            34      my ( $self, %args ) = @_;
213            4                                 30      my @required_args = qw(events hosts);
214            4                                 24      foreach my $arg ( @required_args ) {
215   ***      8     50                          64         die "I need a $arg argument" unless $args{$arg};
216                                                      }
217            4                                 29      my ($events, $hosts) = @args{@required_args};
218                                                   
219            4                                 18      my $different_row_counts    = 0;
220            4                                 16      my $different_column_counts = 0; # TODO
221            4                                 16      my $different_column_types  = 0; # TODO
222            4                                 16      my $different_checksums     = 0;
223                                                   
224            4                                 19      my $n_events = scalar @$events;
225            4                                 30      foreach my $i ( 0..($n_events-1) ) {
226            8                                105         $events->[$i] = $self->_checksum_results(
227                                                            event => $events->[$i],
228                                                            dbh   => $hosts->[$i]->{dbh},
229                                                         );
230            8    100                          68         if ( $i ) {
231            4    100    100                  105            if ( ($events->[0]->{checksum} || 0)
                           100                        
232                                                                 != ($events->[$i]->{checksum}||0) ) {
233            2                                 12               $different_checksums++;
234                                                            }
235            4    100    100                   87            if ( ($events->[0]->{row_count} || 0)
                           100                        
236                                                                 != ($events->[$i]->{row_count} || 0) ) {
237            1                                  6               $different_row_counts++
238                                                            }
239                                                   
240            4                                 46            delete $events->[$i]->{wrapped_query};
241                                                         }
242                                                      }
243            4                                 29      delete $events->[0]->{wrapped_query};
244                                                   
245                                                      # Save differences.
246   ***      4            66                   54      my $item     = $events->[0]->{fingerprint} || $events->[0]->{arg};
247            4           100                   43      my $sampleno = $events->[0]->{sampleno} || 0;
248            4    100                          26      if ( $different_checksums ) {
249            4                                 56         $self->{diffs}->{checksums}->{$item}->{$sampleno}
250            2                                 15            = [ map { $_->{checksum} } @$events ];
251            2                                 24         $self->{samples}->{$item}->{$sampleno} = $events->[0]->{arg};
252                                                      }
253            4    100                          28      if ( $different_row_counts ) {
254            2                                 22         $self->{diffs}->{row_counts}->{$item}->{$sampleno}
255            1                                  7            = [ map { $_->{row_count} } @$events ];
256            1                                 12         $self->{samples}->{$item}->{$sampleno} = $events->[0]->{arg};
257                                                      }
258                                                   
259                                                      return (
260            4                                117         different_row_counts    => $different_row_counts,
261                                                         different_checksums     => $different_checksums,
262                                                         different_column_counts => $different_column_counts,
263                                                         different_column_types  => $different_column_types,
264                                                      );
265                                                   }
266                                                   
267                                                   sub _checksum_results {
268            8                    8            77      my ( $self, %args ) = @_;
269            8                                 60      my @required_args = qw(event dbh);
270            8                                 50      foreach my $arg ( @required_args ) {
271   ***     16     50                         133         die "I need a $arg argument" unless $args{$arg};
272                                                      }
273            8                                 64      my ($event, $dbh) = @args{@required_args};
274                                                   
275            8                                 29      my $sql;
276            8                                 35      my $n_rows       = 0;
277            8                                 46      my $tbl_checksum = 0;
278   ***      8    100     66                  149      if ( $event->{wrapped_query} && $event->{tmp_tbl} ) {
279            6                                 35         my $tmp_tbl = $event->{tmp_tbl};
280            6                                 26         eval {
281            6                                 39            $sql = "SELECT COUNT(*) FROM $tmp_tbl";
282            6                                 19            MKDEBUG && _d($sql);
283            6                                 25            ($n_rows) = @{ $dbh->selectcol_arrayref($sql) };
               6                                 23   
284                                                   
285            6                                 90            $sql = "CHECKSUM TABLE $tmp_tbl";
286            6                                 20            MKDEBUG && _d($sql);
287            6                                 19            $tbl_checksum = $dbh->selectrow_arrayref($sql)->[1];
288                                                         };
289   ***      6     50                        1459         die "Failed to checksum table: $EVAL_ERROR"
290                                                            if $EVAL_ERROR;
291                                                      
292            6                                 38         $sql = "DROP TABLE IF EXISTS $tmp_tbl";
293            6                                 18         MKDEBUG && _d($sql);
294            6                                 24        eval {
295            6                               2162            $dbh->do($sql);
296                                                         };
297                                                         # This isn't critical; we don't need to die.
298            6                                 40         MKDEBUG && $EVAL_ERROR && _d('Error:', $EVAL_ERROR);
299                                                      }
300                                                      else {
301            2                                  8         MKDEBUG && _d("Event doesn't have wrapped query or tmp tbl");
302                                                      }
303                                                   
304            8                                 61      $event->{row_count} = $n_rows;
305            8                                 64      $event->{checksum}  = $tbl_checksum;
306            8                                 27      MKDEBUG && _d('row count:', $n_rows, 'checksum:', $tbl_checksum);
307                                                   
308            8                                112      return $event;
309                                                   }
310                                                   
311                                                   sub _compare_rows {
312            8                    8            77      my ( $self, %args ) = @_;
313            8                                 70      my @required_args = qw(events hosts);
314            8                                 52      foreach my $arg ( @required_args ) {
315   ***     16     50                         138         die "I need a $arg argument" unless $args{$arg};
316                                                      }
317            8                                 59      my ($events, $hosts) = @args{@required_args};
318                                                   
319            8                                 48      my $different_row_counts    = 0;
320            8                                 33      my $different_column_counts = 0; # TODO
321            8                                 34      my $different_column_types  = 0; # TODO
322            8                                 33      my $different_column_values = 0;
323                                                   
324            8                                 44      my $n_events = scalar @$events;
325            8                                 49      my $event0   = $events->[0]; 
326   ***      8            66                  117      my $item     = $event0->{fingerprint} || $event0->{arg};
327            8           100                   85      my $sampleno = $event0->{sampleno} || 0;
328            8                                 57      my $dbh      = $hosts->[0]->{dbh};  # doesn't matter which one
329                                                   
330            8    100                          67      if ( !$event0->{results_sth} ) {
331                                                         # This will happen if execute() or something fails.
332            1                                  4         MKDEBUG && _d("Event 0 doesn't have a results sth");
333                                                         return (
334            1                                 23            different_row_counts    => $different_row_counts,
335                                                            different_column_values => $different_column_values,
336                                                            different_column_counts => $different_column_counts,
337                                                            different_column_types  => $different_column_types,
338                                                         );
339                                                      }
340                                                   
341            7                                 91      my $res_struct = MockSyncStream::get_result_set_struct($dbh,
342                                                         $event0->{results_sth});
343            7                                 27      MKDEBUG && _d('Result set struct:', Dumper($res_struct));
344                                                   
345                                                      # Use a mock sth so we don't have to re-execute event0 sth to compare
346                                                      # it to the 3rd and subsequent events.
347            7                                 30      my @event0_rows      = @{ $event0->{results_sth}->fetchall_arrayref({}) };
               7                                129   
348            7                                111      $event0->{row_count} = scalar @event0_rows;
349            7                                128      my $left = new MockSth(@event0_rows);
350            7                                 31      $left->{NAME} = [ @{$event0->{results_sth}->{NAME}} ];
               7                                 78   
351                                                   
352                                                      EVENT:
353            7                                121      foreach my $i ( 1..($n_events-1) ) {
354            7                                 45         my $event = $events->[$i];
355            7                                 42         my $right = $event->{results_sth};
356                                                   
357            7                                 39         $event->{row_count} = 0;
358                                                   
359                                                         # Identical rows are ignored.  Once a difference on either side is found,
360                                                         # we gobble the remaining rows in that sth and print them to an outfile.
361                                                         # This short circuits RowDiff::compare_sets() which is what we want to do.
362            7                                 34         my $no_diff      = 1;  # results are identical; this catches 0 row results
363            7                                109         my $outfile      = new Outfile();
364            7                                 35         my ($left_outfile, $right_outfile, $n_rows);
365                                                         my $same_row     = sub {
366            9                    9            47               $event->{row_count}++;  # Keep track of this event's row_count.
367            9                                 45               return;
368            7                                 90         };
369                                                         my $not_in_left  = sub {
370            5                    5            26            my ( $rr ) = @_;
371            5                                 23            $no_diff = 0;
372                                                            # $n_rows will be added later to this event's row_count.
373            5                                 68            ($right_outfile, $n_rows) = $self->write_to_outfile(
374                                                               side    => 'right',
375                                                               sth     => $right,
376                                                               row     => $rr,
377                                                               Outfile => $outfile,
378                                                            );
379            5                                102            return;
380            7                                 86         };
381                                                         my $not_in_right = sub {
382            5                    5            26            my ( $lr ) = @_;
383            5                                 21            $no_diff = 0;
384                                                            # left is event0 so we don't need $n_rows back.
385            5                                 64            ($left_outfile, undef) = $self->write_to_outfile(
386                                                               side    => 'left',
387                                                               sth     => $left,
388                                                               row     => $lr,
389                                                               Outfile => $outfile,
390                                                            ); 
391            5                                104            return;
392            7                                 75         };
393                                                   
394            7                                 93         my $rd       = new RowDiff(dbh => $dbh);
395            7                                149         my $mocksync = new MockSyncStream(
396                                                            query        => $event0->{arg},
397                                                            cols         => $res_struct->{cols},
398                                                            same_row     => $same_row,
399                                                            not_in_left  => $not_in_left,
400                                                            not_in_right => $not_in_right,
401                                                         );
402                                                   
403            7                                 32         MKDEBUG && _d('Comparing result sets with MockSyncStream');
404            7                                 73         $rd->compare_sets(
405                                                            left   => $left,
406                                                            right  => $right,
407                                                            syncer => $mocksync,
408                                                            tbl    => $res_struct,
409                                                         );
410                                                   
411                                                         # Add number of rows written to outfile to this event's row_count.
412                                                         # $n_rows will be undef if there were no differences; row_count will
413                                                         # still be correct in this case because we kept track of it in $same_row.
414            7           100                   87         $event->{row_count} += $n_rows || 0;
415                                                   
416            7                                 24         MKDEBUG && _d('Left has', $event0->{row_count}, 'rows, right has',
417                                                            $event->{row_count});
418                                                   
419                                                         # Save differences.
420            7    100                          67         $different_row_counts++ if $event0->{row_count} != $event->{row_count};
421            7    100                          44         if ( $different_row_counts ) {
422            2                                 36            $self->{diffs}->{row_counts}->{$item}->{$sampleno}
423                                                               = [ $event0->{row_count}, $event->{row_count} ];
424            2                                 24            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
425                                                         }
426                                                   
427            7                                 57         $left->reset();
428            7    100                          69         next EVENT if $no_diff;
429                                                   
430                                                         # The result sets differ, so now we must begin the difficult
431                                                         # work: finding and determining the nature of those differences.
432            6                                 23         MKDEBUG && _d('Result sets are different');
433                                                   
434                                                   
435                                                         # Make sure both outfiles are created, else diff_rows() will die.
436            6    100                          41         if ( !$left_outfile ) {
437            1                                  4            MKDEBUG && _d('Right has extra rows not in left');
438            1                                  7            (undef, $left_outfile) = $self->open_outfile(side => 'left');
439                                                         }
440            6    100                          39         if ( !$right_outfile ) {
441            1                                  5            MKDEBUG && _d('Left has extra rows not in right');
442            1                                  7            (undef, $right_outfile) = $self->open_outfile(side => 'right');
443                                                         }
444                                                   
445   ***      6            33                  205         my @diff_rows = $self->diff_rows(
446                                                            %args,             # for options like max-different-rows
447                                                            left_dbh        => $hosts->[0]->{dbh},
448                                                            left_outfile    => $left_outfile,
449                                                            right_dbh       => $hosts->[$i]->{dbh},
450                                                            right_outfile   => $right_outfile,
451                                                            res_struct      => $res_struct,
452                                                            query           => $event0->{arg},
453                                                            db              => $args{tmp_db} || $event0->{db},
454                                                         );
455                                                   
456                                                         # Save differences.
457            6    100                         125         if ( scalar @diff_rows ) { 
458            3                                 14            $different_column_values++; 
459            3                                 51            $self->{diffs}->{col_vals}->{$item}->{$sampleno} = \@diff_rows;
460            3                                119            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
461                                                         }
462                                                      }
463                                                   
464                                                      return (
465            7                                272         different_row_counts    => $different_row_counts,
466                                                         different_column_values => $different_column_values,
467                                                         different_column_counts => $different_column_counts,
468                                                         different_column_types  => $different_column_types,
469                                                      );
470                                                   }
471                                                   
472                                                   # Required args:
473                                                   #   * left_dbh       scalar: active dbh for left
474                                                   #   * left_outfile   scalar: outfile name for left
475                                                   #   * right_dbh      scalar: active dbh for right
476                                                   #   * right_outfile  scalar: outfile name for right
477                                                   #   * res_struct     hashref: result set structure
478                                                   #   * db             scalar: database to use for creating temp tables
479                                                   #   * query          scalar: query, parsed for indexes
480                                                   # Optional args:
481                                                   #   * add-indexes         scalar: add indexes from source tables to tmp tbl
482                                                   #   * max-different-rows  scalar: stop after this many differences are found
483                                                   #   * float-precision     scalar: round float, double, decimal types to N places
484                                                   # Returns: scalar
485                                                   # Can die: no
486                                                   # diff_rows() loads and compares two result sets and returns the number of
487                                                   # differences between them.  This includes missing rows and row data
488                                                   # differences.
489                                                   sub diff_rows {
490            6                    6          3159      my ( $self, %args ) = @_;
491            6                                 83      my @required_args = qw(left_dbh left_outfile right_dbh right_outfile
492                                                                             res_struct db query);
493            6                                 46      foreach my $arg ( @required_args ) {
494   ***     42     50                         306         die "I need a $arg argument" unless $args{$arg};
495                                                      }
496            6                                 72      my ($left_dbh, $left_outfile, $right_dbh, $right_outfile, $res_struct,
497                                                          $db, $query)
498                                                         = @args{@required_args};
499                                                   
500                                                      # First thing, make two temps tables into which the outfiles can
501                                                      # be loaded.  This requires that we make a CREATE TABLE statement
502                                                      # for the result sets' columns.
503            6                                 42      my $left_tbl  = "`$db`.`mk_upgrade_left`";
504            6                                 33      my $right_tbl = "`$db`.`mk_upgrade_right`";
505            6                                 70      my $table_ddl = $self->make_table_ddl($res_struct);
506                                                   
507            6                               4958      $left_dbh->do("DROP TABLE IF EXISTS $left_tbl");
508            6                             379683      $left_dbh->do("CREATE TABLE $left_tbl $table_ddl");
509            6                               5560      $left_dbh->do("LOAD DATA LOCAL INFILE '$left_outfile' "
510                                                         . "INTO TABLE $left_tbl");
511                                                   
512            6                             393047      $right_dbh->do("DROP TABLE IF EXISTS $right_tbl");
513            6                             307999      $right_dbh->do("CREATE TABLE $right_tbl $table_ddl");
514            6                               4587      $right_dbh->do("LOAD DATA LOCAL INFILE '$right_outfile' "
515                                                         . "INTO TABLE $right_tbl");
516                                                   
517            6                                 39      MKDEBUG && _d('Loaded', $left_outfile, 'into table', $left_tbl, 'and',
518                                                         $right_outfile, 'into table', $right_tbl);
519                                                   
520                                                      # Now we need to get all indexes from all tables used by the query
521                                                      # and add them to the temp tbl.  Some indexes may be invalid, dupes,
522                                                      # or generally useless, but we'll let the sync algo decide that later.
523            6    100                          83      if ( $args{'add-indexes'} ) {
524            1                                 46         $self->add_indexes(
525                                                            %args,
526                                                            dsts      => [
527                                                               { dbh => $left_dbh,  tbl => $left_tbl  },
528                                                               { dbh => $right_dbh, tbl => $right_tbl },
529                                                            ],
530                                                         );
531                                                      }
532                                                   
533                                                      # Create a RowDiff with callbacks that will do what we want when rows and
534                                                      # columns differ.  This RowDiff is passed to TableSyncer which calls it.
535                                                      # TODO: explain how these callbacks work together.
536            6           100                  125      my $max_diff = $args{'max-different-rows'} || 1_000;  # 1k=sanity/safety
537            6                                 27      my $n_diff   = 0;
538            6                                 25      my @missing_rows;  # not currently saved; row counts show missing rows
539            6                                 22      my @different_rows;
540            1                    1            11      use constant LEFT  => 0;
               1                                  2   
               1                                  5   
541            1                    1             6      use constant RIGHT => 1;
               1                                  3   
               1                                  4   
542            6                                 52      my @l_r = (undef, undef);
543            6                                 23      my @last_diff_col;
544            6                                 26      my $last_diff = 0;
545                                                      my $key_cmp      = sub {
546            4                    4            38         push @last_diff_col, [@_];
547            4                                 17         $last_diff--;
548            4                                 20         return;
549            6                                129      };
550                                                      my $same_row = sub {
551            7                    7            48         my ( $lr, $rr ) = @_;
552            7    100    100                  106         if ( $l_r[LEFT] && $l_r[RIGHT] ) {
                    100                               
                    100                               
553            3                                 11            MKDEBUG && _d('Saving different row');
554            3                                 18            push @different_rows, $last_diff_col[$last_diff];
555            3                                 13            $n_diff++;
556                                                         }
557                                                         elsif ( $l_r[LEFT] ) {
558            2                                  7            MKDEBUG && _d('Saving not in right row');
559                                                            # push @missing_rows, [$l_r[LEFT], undef];
560            2                                 10            $n_diff++;
561                                                         }
562                                                         elsif ( $l_r[RIGHT] ) {
563            1                                  3            MKDEBUG && _d('Saving not in left row');
564                                                            # push @missing_rows, [undef, $l_r[RIGHT]];
565            1                                  4            $n_diff++;
566                                                         }
567                                                         else {
568            1                                  4            MKDEBUG && _d('No missing or different rows in queue');
569                                                         }
570            7                                 49         @l_r           = (undef, undef);
571            7                                 31         @last_diff_col = ();
572            7                                 28         $last_diff     = 0;
573            7                                 36         return;
574            6                                 86      };
575                                                      my $not_in_left  = sub {
576            4                    4            27         my ( $rr ) = @_;
577   ***      4     50                          26         $same_row->() if $l_r[RIGHT];  # last missing row
578            4                                 17         $l_r[RIGHT] = $rr;
579   ***      4    100     66                   67         $same_row->(@l_r) if $l_r[LEFT] && $l_r[RIGHT];
580            4                                 20         return;
581            6                                 63      };
582                                                      my $not_in_right = sub {
583            5                    5            30         my ( $lr ) = @_;
584            5    100                          41         $same_row->() if $l_r[LEFT];  # last missing row
585            5                                 22         $l_r[LEFT] = $lr;
586   ***      5     50     33                   76         $same_row->(@l_r) if $l_r[LEFT] && $l_r[RIGHT];
587            5                                 23         return;
588            6                                 82      };
589                                                      my $done = sub {
590           15                   15            94         my ( $left, $right ) = @_;
591           15                                 52         MKDEBUG && _d('Found', $n_diff, 'of', $max_diff, 'max differences');
592           15    100                         100         if ( $n_diff >= $max_diff ) {
593            1                                  5            MKDEBUG && _d('Done comparing rows, got --max-differences', $max_diff);
594            1                                 21            $left->finish();
595            1                                 12            $right->finish();
596            1                                 28            return 1;
597                                                         }
598           14                                297         return 0;
599            6                                 74      };
600            6                                 24      my $trf;
601            6    100                          55      if ( my $n = $args{'float-precision'} ) {
602                                                         $trf = sub {
603            1                    1            17            my ( $l, $r, $tbl, $col ) = @_;
604   ***      1     50                          27            return $l, $r
605                                                               unless $tbl->{type_for}->{$col} =~ m/(?:float|double|decimal)/;
606            1                                 23            my $l_rounded = sprintf "%.${n}f", $l;
607            1                                 12            my $r_rounded = sprintf "%.${n}f", $r;
608            1                                  4            MKDEBUG && _d('Rounded', $l, 'to', $l_rounded,
609                                                               'and', $r, 'to', $r_rounded);
610            1                                  9            return $l_rounded, $r_rounded;
611            2                                 40         };
612                                                      };
613                                                   
614            6                                168      my $rd = new RowDiff(
615                                                         dbh          => $left_dbh,
616                                                         key_cmp      => $key_cmp,
617                                                         same_row     => $same_row,
618                                                         not_in_left  => $not_in_left,
619                                                         not_in_right => $not_in_right,
620                                                         done         => $done,
621                                                         trf          => $trf,
622                                                      );
623            6                                150      my $ch = new ChangeHandler(
624                                                         src_db     => $db,
625                                                         src_tbl    => 'mk_upgrade_left',
626                                                         dst_db     => $db,
627                                                         dst_tbl    => 'mk_upgrade_right',
628                                                         tbl_struct => $res_struct,
629                                                         queue      => 0,
630                                                         replace    => 0,
631                                                         actions    => [],
632                                                         Quoter     => $self->{Quoter},
633                                                      );
634                                                   
635                                                      # With whatever index we may have, let TableSyncer choose an
636                                                      # algorithm and find were rows differ.  We don't actually sync
637                                                      # the tables (execute=>0).  Instead, the callbacks above will
638                                                      # save rows in @missing_rows and @different_rows.
639            6                                211      $self->{TableSyncer}->sync_table(
640                                                         plugins       => $self->{plugins},
641                                                         src           => {
642                                                            dbh => $left_dbh,
643                                                            db  => $db,
644                                                            tbl => 'mk_upgrade_left',
645                                                         },
646                                                         dst           => {
647                                                            dbh => $right_dbh,
648                                                            db  => $db,
649                                                            tbl => 'mk_upgrade_right',
650                                                         },
651                                                         tbl_struct    => $res_struct,
652                                                         cols          => $res_struct->{cols},
653                                                         chunk_size    => 1_000,
654                                                         RowDiff       => $rd,
655                                                         ChangeHandler => $ch,
656                                                      );
657                                                   
658            6    100                          64      if ( $n_diff < $max_diff ) {
659            5    100    100                   90         $same_row->() if $l_r[LEFT] || $l_r[RIGHT];  # save remaining rows
660                                                      }
661                                                   
662            6                                304      return @different_rows;
663                                                   }
664                                                   
665                                                   # Writes the current row and all remaining rows to an outfile.
666                                                   # Returns the outfile's name.
667                                                   sub write_to_outfile {
668           10                   10           133      my ( $self, %args ) = @_;
669           10                                 95      my @required_args = qw(side row sth Outfile);
670           10                                 64      foreach my $arg ( @required_args ) {
671   ***     40     50                         314         die "I need a $arg argument" unless $args{$arg};
672                                                      }
673           10                                115      my ( $side, $row, $sth, $outfile ) = @args{@required_args};
674           10                                103      my ( $fh, $file ) = $self->open_outfile(%args);
675                                                   
676                                                      # Write this one row.
677           10                                108      $outfile->write($fh, [ MockSyncStream::as_arrayref($sth, $row) ]);
678                                                   
679                                                      # Get and write all remaining rows.
680           10                                187      my $remaining_rows = $sth->fetchall_arrayref();
681           10                                 82      $outfile->write($fh, $remaining_rows);
682                                                   
683           10                                 58      my $n_rows = 1 + @$remaining_rows;
684           10                                 34      MKDEBUG && _d('Wrote', $n_rows, 'rows');
685                                                   
686   ***     10     50                         890      close $fh or warn "Cannot close $file: $OS_ERROR";
687           10                                 44      return $file, $n_rows;
688                                                   }
689                                                   
690                                                   sub open_outfile {
691           12                   12           115      my ( $self, %args ) = @_;
692           12                                144      my $outfile = $self->{'base-dir'} . "/$args{side}-outfile.txt";
693   ***     12     50                        1514      open my $fh, '>', $outfile or die "Cannot open $outfile: $OS_ERROR";
694           12                                 51      MKDEBUG && _d('Opened outfile', $outfile);
695           12                                154      return $fh, $outfile;
696                                                   }
697                                                   
698                                                   # Returns just the column definitions for the given struct.
699                                                   # Example:
700                                                   #   (
701                                                   #     `i` integer,
702                                                   #     `f` float(10,8)
703                                                   #   )
704                                                   sub make_table_ddl {
705            6                    6            39      my ( $self, $struct ) = @_;
706            8                                 35      my $sql = "(\n"
707                                                              . (join("\n",
708                                                                    map {
709            6                                 56                       my $name = $_;
710            8                                 57                       my $type = $struct->{type_for}->{$_};
711            8           100                   92                       my $size = $struct->{size}->{$_} || '';
712            8                                 92                       "  `$name` $type$size,";
713            6                                 35                    } @{$struct->{cols}}))
714                                                              . ')';
715                                                      # The last column will be like "`i` integer,)" which is invalid.
716            6                                 86      $sql =~ s/,\)$/\n)/;
717            6                                 18      MKDEBUG && _d('Table ddl:', $sql);
718            6                                 47      return $sql;
719                                                   }
720                                                   
721                                                   # Adds every index from every table used by the query to all the
722                                                   # dest tables.  dest is an arrayref of hashes, one for each destination.
723                                                   # Each hash needs a dbh and tbl key; e.g.:
724                                                   #   [
725                                                   #     {
726                                                   #       dbh => $dbh,
727                                                   #       tbl => 'db.tbl',
728                                                   #     },
729                                                   #   ],
730                                                   # For the moment, the sub returns nothing.  In the future, it should
731                                                   # add to $args{struct}->{keys} the keys that it was able to add.
732                                                   sub add_indexes {
733            1                    1            27      my ( $self, %args ) = @_;
734            1                                 13      my @required_args = qw(query dsts db);
735            1                                 19      foreach my $arg ( @required_args ) {
736   ***      3     50                          27         die "I need a $arg argument" unless $args{$arg};
737                                                      }
738            1                                  9      my ($query, $dsts) = @args{@required_args};
739                                                   
740            1                                  9      my $qp = $self->{QueryParser};
741            1                                  8      my $tp = $self->{TableParser};
742            1                                  7      my $q  = $self->{Quoter};
743            1                                  6      my $du = $self->{MySQLDump};
744                                                   
745            1                                 20      my @src_tbls = $qp->get_tables($query);
746            1                                  5      my @keys;
747            1                                  6      foreach my $db_tbl ( @src_tbls ) {
748            1                                 15         my ($db, $tbl) = $q->split_unquote($db_tbl, $args{db});
749   ***      1     50                           7         if ( $db ) {
750            1                                  5            my $tbl_struct;
751            1                                  6            eval {
752            1                                 26               $tbl_struct = $tp->parse(
753                                                                  $du->get_create_table($dsts->[0]->{dbh}, $q, $db, $tbl)
754                                                               );
755                                                            };
756   ***      1     50                          11            if ( $EVAL_ERROR ) {
757   ***      0                                  0               MKDEBUG && _d('Error parsing', $db, '.', $tbl, ':', $EVAL_ERROR);
758   ***      0                                  0               next;
759                                                            }
760   ***      1     50                          16            push @keys, map {
761            1                                 10               my $def = ($_->{is_unique} ? 'UNIQUE ' : '')
762                                                                       . "KEY ($_->{colnames})";
763            1                                 26               [$def, $_];
764            1                                  6            } grep { $_->{type} eq 'BTREE' } values %{$tbl_struct->{keys}};
               1                                 10   
765                                                         }
766                                                         else {
767   ***      0                                  0            MKDEBUG && _d('Cannot get indexes from', $db_tbl, 'because its '
768                                                               . 'database is unknown');
769                                                         }
770                                                      }
771            1                                  4      MKDEBUG && _d('Source keys:', Dumper(\@keys));
772   ***      1     50                           8      return unless @keys;
773                                                   
774            1                                  7      for my $dst ( @$dsts ) {
775            2                                 15         foreach my $key ( @keys ) {
776            2                                 17            my $def = $key->[0];
777            2                                 24            my $sql = "ALTER TABLE $dst->{tbl} ADD $key->[0]";
778            2                                  8            MKDEBUG && _d($sql);
779            2                                  9            eval {
780            2                             171476               $dst->{dbh}->do($sql);
781                                                            };
782   ***      2     50                          64            if ( $EVAL_ERROR ) {
783   ***      0                                  0               MKDEBUG && _d($EVAL_ERROR);
784                                                            }
785                                                            else {
786                                                               # TODO: $args{res_struct}->{keys}->{$key->[1]->{name}} = $key->[1];
787                                                            }
788                                                         }
789                                                      }
790                                                   
791                                                      # If the query uses only 1 table then return its struct.
792                                                      # TODO: $args{struct} = $struct if @src_tbls == 1;
793            1                                 34      return;
794                                                   }
795                                                   
796                                                   sub report {
797            4                    4            44      my ( $self, %args ) = @_;
798            4                                 30      my @required_args = qw(hosts);
799            4                                 32      foreach my $arg ( @required_args ) {
800   ***      4     50                          45         die "I need a $arg argument" unless $args{$arg};
801                                                      }
802            4                                 29      my ($hosts) = @args{@required_args};
803                                                   
804   ***      4     50                          16      return unless keys %{$self->{diffs}};
               4                                 46   
805                                                   
806                                                      # These columns are common to all the reports; make them just once.
807            4                                 36      my $query_id_col = {
808                                                         name        => 'Query ID',
809                                                         fixed_width => 18,
810                                                      };
811            8                                 61      my @host_cols = map {
812            4                                 25         my $col = { name => $_->{name} };
813            8                                 51         $col;
814                                                      } @$hosts;
815                                                   
816            4                                 20      my @reports;
817            4                                 25      foreach my $diff ( qw(checksums col_vals row_counts) ) {
818           12                                 75         my $report = "_report_diff_$diff";
819           12                                175         push @reports, $self->$report(
820                                                            query_id_col => $query_id_col,
821                                                            host_cols    => \@host_cols,
822                                                            %args
823                                                         );
824                                                      }
825                                                   
826            4                                 89      return join("\n", @reports);
827                                                   }
828                                                   
829                                                   sub _report_diff_checksums {
830            4                    4            48      my ( $self, %args ) = @_;
831            4                                 38      my @required_args = qw(query_id_col host_cols);
832            4                                 31      foreach my $arg ( @required_args ) {
833   ***      8     50                          74         die "I need a $arg argument" unless $args{$arg};
834                                                      }
835                                                   
836            4                                 26      my $get_id = $self->{get_id};
837                                                   
838            4    100                          16      return unless keys %{$self->{diffs}->{checksums}};
               4                                 65   
839                                                   
840            1                                 54      my $report = new ReportFormatter();
841            1                                 12      $report->set_title('Checksum differences');
842            1                                 14      $report->set_columns(
843                                                         $args{query_id_col},
844            1                                  6         @{$args{host_cols}},
845                                                      );
846                                                   
847            1                                 19      my $diff_checksums = $self->{diffs}->{checksums};
848            1                                 12      foreach my $item ( sort keys %$diff_checksums ) {
849            1                                 15         map {
850   ***      0                                  0            $report->add_line(
851                                                               $get_id->($item) . '-' . $_,
852            1                                  8               @{$diff_checksums->{$item}->{$_}},
853                                                            );
854            1                                  5         } sort { $a <=> $b } keys %{$diff_checksums->{$item}};
               1                                 11   
855                                                      }
856                                                   
857            1                                 16      return $report->get_report();
858                                                   }
859                                                   
860                                                   sub _report_diff_col_vals {
861            4                    4            44      my ( $self, %args ) = @_;
862            4                                 41      my @required_args = qw(query_id_col host_cols);
863            4                                 41      foreach my $arg ( @required_args ) {
864   ***      8     50                          71         die "I need a $arg argument" unless $args{$arg};
865                                                      }
866                                                   
867            4                                 26      my $get_id = $self->{get_id};
868                                                   
869            4    100                          17      return unless keys %{$self->{diffs}->{col_vals}};
               4                                 56   
870                                                   
871            2                                 55      my $report = new ReportFormatter();
872            2                                 19      $report->set_title('Column value differences');
873            2                                 25      $report->set_columns(
874                                                         $args{query_id_col},
875                                                         {
876                                                            name => 'Column'
877                                                         },
878            2                                 18         @{$args{host_cols}},
879                                                      );
880            2                                 16      my $diff_col_vals = $self->{diffs}->{col_vals};
881            2                                 20      foreach my $item ( sort keys %$diff_col_vals ) {
882            2                                  9         foreach my $sampleno (sort {$a <=> $b} keys %{$diff_col_vals->{$item}}) {
      ***      0                                  0   
               2                                 21   
883            2                                 18            map {
884            2                                 16               $report->add_line(
885                                                                  $get_id->($item) . '-' . $sampleno,
886                                                                  @$_,
887                                                               );
888            2                                  9            } @{$diff_col_vals->{$item}->{$sampleno}};
889                                                         }
890                                                      }
891                                                   
892            2                               2009      return $report->get_report();
893                                                   }
894                                                   
895                                                   sub _report_diff_row_counts {
896            4                    4            40      my ( $self, %args ) = @_;
897            4                                 40      my @required_args = qw(query_id_col hosts);
898            4                                 31      foreach my $arg ( @required_args ) {
899   ***      8     50                          67         die "I need a $arg argument" unless $args{$arg};
900                                                      }
901                                                   
902            4                                 24      my $get_id = $self->{get_id};
903                                                   
904            4    100                          14      return unless keys %{$self->{diffs}->{row_counts}};
               4                                 61   
905                                                   
906            3                                 42      my $report = new ReportFormatter();
907            3                                 26      $report->set_title('Row count differences');
908            6                                 51      $report->set_columns(
909                                                         $args{query_id_col},
910                                                         map {
911            3                                 20            my $col = { name => $_->{name}, right_justify => 1  };
912            6                                 43            $col;
913            3                                 18         } @{$args{hosts}},
914                                                      );
915                                                   
916            3                                 24      my $diff_row_counts = $self->{diffs}->{row_counts};
917            3                                 29      foreach my $item ( sort keys %$diff_row_counts ) {
918            3                                 33         map {
919   ***      0                                  0            $report->add_line(
920                                                               $get_id->($item) . '-' . $_,
921            3                                 24               @{$diff_row_counts->{$item}->{$_}},
922                                                            );
923            3                                 14         } sort { $a <=> $b } keys %{$diff_row_counts->{$item}};
               3                                 30   
924                                                      }
925                                                   
926            3                                 29      return $report->get_report();
927                                                   }
928                                                   
929                                                   sub samples {
930            2                    2            17      my ( $self, $item ) = @_;
931   ***      2     50                          16      return unless $item;
932            2                                  9      my @samples;
933            2                                  9      foreach my $sampleno ( keys %{$self->{samples}->{$item}} ) {
               2                                 26   
934            2                                 23         push @samples, $sampleno, $self->{samples}->{$item}->{$sampleno};
935                                                      }
936            2                                 26      return @samples;
937                                                   }
938                                                   
939                                                   sub reset {
940            3                    3            43      my ( $self ) = @_;
941            3                                 29      $self->{diffs}   = {};
942            3                                 62      $self->{samples} = {};
943            3                                 29      return;
944                                                   }
945                                                   
946                                                   sub _d {
947            1                    1            48      my ($package, undef, $line) = caller 0;
948   ***      2     50                          17      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 19   
949            1                                  9           map { defined $_ ? $_ : 'undef' }
950                                                           @_;
951            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
952                                                   }
953                                                   
954                                                   1;
955                                                   
956                                                   # ###########################################################################
957                                                   # End CompareResults package
958                                                   # ###########################################################################


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
161   ***     50      0      6   if $EVAL_ERROR
181   ***     50      0      7   unless $args{$arg}
204   ***     50      0     24   unless $args{$arg}
207          100      8      4   $$self{'method'} eq 'rows' ? :
215   ***     50      0      8   unless $args{$arg}
230          100      4      4   if ($i)
231          100      2      2   if (($$events[0]{'checksum'} || 0) != ($$events[$i]{'checksum'} || 0))
235          100      1      3   if (($$events[0]{'row_count'} || 0) != ($$events[$i]{'row_count'} || 0))
248          100      2      2   if ($different_checksums)
253          100      1      3   if ($different_row_counts)
271   ***     50      0     16   unless $args{$arg}
278          100      6      2   if ($$event{'wrapped_query'} and $$event{'tmp_tbl'}) { }
289   ***     50      0      6   if $EVAL_ERROR
315   ***     50      0     16   unless $args{$arg}
330          100      1      7   if (not $$event0{'results_sth'})
420          100      2      5   if $$event0{'row_count'} != $$event{'row_count'}
421          100      2      5   if ($different_row_counts)
428          100      1      6   if $no_diff
436          100      1      5   if (not $left_outfile)
440          100      1      5   if (not $right_outfile)
457          100      3      3   if (scalar @diff_rows)
494   ***     50      0     42   unless $args{$arg}
523          100      1      5   if ($args{'add-indexes'})
552          100      3      4   if ($l_r[0] and $l_r[1]) { }
             100      2      2   elsif ($l_r[0]) { }
             100      1      1   elsif ($l_r[1]) { }
577   ***     50      0      4   if $l_r[1]
579          100      3      1   if $l_r[0] and $l_r[1]
584          100      1      4   if $l_r[0]
586   ***     50      0      5   if $l_r[0] and $l_r[1]
592          100      1     14   if ($n_diff >= $max_diff)
601          100      2      4   if (my $n = $args{'float-precision'})
604   ***     50      0      1   unless $$tbl{'type_for'}{$col} =~ /(?:float|double|decimal)/
658          100      5      1   if ($n_diff < $max_diff)
659          100      2      3   if $l_r[0] or $l_r[1]
671   ***     50      0     40   unless $args{$arg}
686   ***     50      0     10   unless close $fh
693   ***     50      0     12   unless open my $fh, '>', $outfile
736   ***     50      0      3   unless $args{$arg}
749   ***     50      1      0   if ($db) { }
756   ***     50      0      1   if ($EVAL_ERROR)
760   ***     50      1      0   $$_{'is_unique'} ? :
772   ***     50      0      1   unless @keys
782   ***     50      0      2   if ($EVAL_ERROR) { }
800   ***     50      0      4   unless $args{$arg}
804   ***     50      0      4   unless keys %{$$self{'diffs'};}
833   ***     50      0      8   unless $args{$arg}
838          100      3      1   unless keys %{$$self{'diffs'}{'checksums'};}
864   ***     50      0      8   unless $args{$arg}
869          100      2      2   unless keys %{$$self{'diffs'}{'col_vals'};}
899   ***     50      0      8   unless $args{$arg}
904          100      1      3   unless keys %{$$self{'diffs'}{'row_counts'};}
931   ***     50      0      2   unless $item
948   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
278   ***     66      2      0      6   $$event{'wrapped_query'} and $$event{'tmp_tbl'}
552          100      2      2      3   $l_r[0] and $l_r[1]
579   ***     66      1      0      3   $l_r[0] and $l_r[1]
586   ***     33      0      5      0   $l_r[0] and $l_r[1]

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
231          100      3      1   $$events[0]{'checksum'} || 0
             100      3      1   $$events[$i]{'checksum'} || 0
235          100      3      1   $$events[0]{'row_count'} || 0
             100      3      1   $$events[$i]{'row_count'} || 0
247          100      3      1   $$events[0]{'sampleno'} || 0
327          100      5      3   $$event0{'sampleno'} || 0
414          100      5      2   $n_rows || 0
536          100      1      5   $args{'max-different-rows'} || 1000
711          100      5      3   $$struct{'size'}{$_} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
246   ***     66      3      1      0   $$events[0]{'fingerprint'} || $$events[0]{'arg'}
326   ***     66      5      3      0   $$event0{'fingerprint'} || $$event0{'arg'}
445   ***     33      0      6      0   $args{'tmp_db'} || $$event0{'db'}
659          100      1      1      3   $l_r[0] or $l_r[1]


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
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:540
BEGIN                       1 /home/daniel/dev/maatkit/common/CompareResults.pm:541
__ANON__                    9 /home/daniel/dev/maatkit/common/CompareResults.pm:366
__ANON__                    5 /home/daniel/dev/maatkit/common/CompareResults.pm:370
__ANON__                    5 /home/daniel/dev/maatkit/common/CompareResults.pm:382
__ANON__                    4 /home/daniel/dev/maatkit/common/CompareResults.pm:546
__ANON__                    7 /home/daniel/dev/maatkit/common/CompareResults.pm:551
__ANON__                    4 /home/daniel/dev/maatkit/common/CompareResults.pm:576
__ANON__                    5 /home/daniel/dev/maatkit/common/CompareResults.pm:583
__ANON__                   15 /home/daniel/dev/maatkit/common/CompareResults.pm:590
__ANON__                    1 /home/daniel/dev/maatkit/common/CompareResults.pm:603
_checksum_results           8 /home/daniel/dev/maatkit/common/CompareResults.pm:268
_compare_checksums          4 /home/daniel/dev/maatkit/common/CompareResults.pm:212
_compare_rows               8 /home/daniel/dev/maatkit/common/CompareResults.pm:312
_d                          1 /home/daniel/dev/maatkit/common/CompareResults.pm:947
_report_diff_checksums      4 /home/daniel/dev/maatkit/common/CompareResults.pm:830
_report_diff_col_vals       4 /home/daniel/dev/maatkit/common/CompareResults.pm:861
_report_diff_row_counts     4 /home/daniel/dev/maatkit/common/CompareResults.pm:896
add_indexes                 1 /home/daniel/dev/maatkit/common/CompareResults.pm:733
after_execute               7 /home/daniel/dev/maatkit/common/CompareResults.pm:178
before_execute             20 /home/daniel/dev/maatkit/common/CompareResults.pm:68 
compare                    12 /home/daniel/dev/maatkit/common/CompareResults.pm:201
diff_rows                   6 /home/daniel/dev/maatkit/common/CompareResults.pm:490
execute                    20 /home/daniel/dev/maatkit/common/CompareResults.pm:120
make_table_ddl              6 /home/daniel/dev/maatkit/common/CompareResults.pm:705
new                         4 /home/daniel/dev/maatkit/common/CompareResults.pm:41 
open_outfile               12 /home/daniel/dev/maatkit/common/CompareResults.pm:691
report                      4 /home/daniel/dev/maatkit/common/CompareResults.pm:797
reset                       3 /home/daniel/dev/maatkit/common/CompareResults.pm:940
samples                     2 /home/daniel/dev/maatkit/common/CompareResults.pm:930
write_to_outfile           10 /home/daniel/dev/maatkit/common/CompareResults.pm:668


