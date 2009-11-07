---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/CompareWarnings.pm   98.6   68.5   77.8  100.0    n/a  100.0   92.2
Total                          98.6   68.5   77.8  100.0    n/a  100.0   92.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          CompareWarnings.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Nov  7 17:23:24 2009
Finish:       Sat Nov  7 17:23:24 2009

/home/daniel/dev/maatkit/common/CompareWarnings.pm

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
18                                                    # CompareWarnings package $Revision: 5067 $
19                                                    # ###########################################################################
20                                                    package CompareWarnings;
21                                                    
22             1                    1             6   use strict;
               1                                  3   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             9   use English qw(-no_match_vars);
               1                                  3   
               1                                  4   
25                                                    
26             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                  6   
27                                                    
28             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  5   
29                                                    $Data::Dumper::Indent    = 1;
30                                                    $Data::Dumper::Sortkeys  = 1;
31                                                    $Data::Dumper::Quotekeys = 0;
32                                                    
33                                                    # Required args:
34                                                    #   * get_id  coderef: used by report() to trf query to its ID
35                                                    #   * common modules
36                                                    # Optional args:
37                                                    #   * clear-warnings        bool: clear warnings before each run
38                                                    #   * clear-warnings-table  scalar: table to select from to clear warnings
39                                                    sub new {
40             2                    2         59702      my ( $class, %args ) = @_;
41             2                                 20      my @required_args = qw(get_id Quoter QueryParser);
42             2                                 18      foreach my $arg ( @required_args ) {
43    ***      6     50                          48         die "I need a $arg argument" unless $args{$arg};
44                                                       }
45             2                                 27      my $self = {
46                                                          %args,
47                                                          diffs   => {},
48                                                          samples => {},
49                                                       };
50             2                                 45      return bless $self, $class;
51                                                    }
52                                                    
53                                                    # Required args:
54                                                    #   * event  hashref: an event
55                                                    #   * dbh    scalar: active dbh
56                                                    # Optional args:
57                                                    #   * db             scalar: database name to create temp table in unless...
58                                                    #   * temp-database  scalar: ...temp db name is given
59                                                    # Returns: hashref
60                                                    # Can die: yes
61                                                    # before_execute() selects from its special temp table to clear the warnings
62                                                    # if the module was created with the clear arg specified.  The temp table is
63                                                    # created if there's a db or temp db and the table doesn't exist yet.
64                                                    sub before_execute {
65             6                    6           360      my ( $self, %args ) = @_;
66             6                                 47      my @required_args = qw(event dbh);
67             6                                 36      foreach my $arg ( @required_args ) {
68    ***     12     50                          98         die "I need a $arg argument" unless $args{$arg};
69                                                       }
70             6                                 45      my ($event, $dbh) = @args{@required_args};
71             6                                 19      my $sql;
72                                                    
73    ***      6     50                          45      return $event unless $self->{'clear-warnings'};
74                                                    
75             6    100                          45      if ( my $tbl = $self->{'clear-warnings-table'} ) {
76             1                                  7         $sql = "SELECT * FROM $tbl LIMIT 1";
77             1                                  6         MKDEBUG && _d($sql);
78             1                                  4         eval {
79             1                                 19            $dbh->do($sql);
80                                                          };
81    ***      1     50                           4         die "Failed to SELECT from clear warnings table: $EVAL_ERROR"
82                                                             if $EVAL_ERROR;
83                                                       }
84                                                       else {
85             5                                 28         my $q    = $self->{Quoter};
86             5                                 27         my $qp   = $self->{QueryParser};
87             5                                 65         my @tbls = $qp->get_tables($event->{arg});
88             5                                 25         my $ok   = 0;
89                                                          TABLE:
90             5                                 27         foreach my $tbl ( @tbls ) {
91             5                                 31            $sql = "SELECT * FROM $tbl LIMIT 1";
92             5                                 16            MKDEBUG && _d($sql);
93             5                                 20            eval {
94             5                               1177               $dbh->do($sql);
95                                                             };
96             5    100                          52            if ( $EVAL_ERROR ) {
97             1                                  7               MKDEBUG && _d('Failed to clear warnings');
98                                                             }
99                                                             else {
100            4                                 13               MKDEBUG && _d('Cleared warnings');
101            4                                 18               $ok = 1;
102            4                                 22               last TABLE;
103                                                            }
104                                                         }
105            5    100                          37         die "Failed to clear warnings"
106                                                            unless $ok;
107                                                      }
108                                                   
109            4                                 63      return $event;
110                                                   }
111                                                   
112                                                   # Required args:
113                                                   #   * event  hashref: an event
114                                                   #   * dbh    scalar: active dbh
115                                                   # Returns: hashref
116                                                   # Can die: yes
117                                                   # execute() executes the event's query if is hasn't already been executed. 
118                                                   # Any prep work should have been done in before_execute().  Adds Query_time
119                                                   # attrib to the event.
120                                                   sub execute {
121            4                    4           210      my ( $self, %args ) = @_;
122            4                                 31      my @required_args = qw(event dbh);
123            4                                 23      foreach my $arg ( @required_args ) {
124   ***      8     50                          68         die "I need a $arg argument" unless $args{$arg};
125                                                      }
126            4                                 29      my ($event, $dbh) = @args{@required_args};
127                                                   
128            4    100                          34      if ( exists $event->{Query_time} ) {
129            1                                  4         MKDEBUG && _d('Query already executed');
130            1                                 11         return $event;
131                                                      }
132                                                   
133            3                                 10      MKDEBUG && _d('Executing query');
134            3                                 17      my $query = $event->{arg};
135            3                                 14      my ( $start, $end, $query_time );
136                                                   
137            3                                 17      $event->{Query_time} = 0;
138            3                                 12      eval {
139            3                                 15         $start = time();
140            3                                893         $dbh->do($query);
141            3                                 18         $end   = time();
142            3                                 70         $query_time = sprintf '%.6f', $end - $start;
143                                                      };
144   ***      3     50                          21      die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
145                                                   
146            3                                 22      $event->{Query_time} = $query_time;
147                                                   
148            3                                 45      return $event;
149                                                   }
150                                                   
151                                                   # Required args:
152                                                   #   * event  hashref: an event
153                                                   #   * dbh    scalar: active dbh
154                                                   # Returns: hashref
155                                                   # Can die: yes
156                                                   # after_execute() gets any warnings from SHOW WARNINGS.
157                                                   sub after_execute {
158            4                    4           214      my ( $self, %args ) = @_;
159            4                                 31      my @required_args = qw(event dbh);
160            4                                 26      foreach my $arg ( @required_args ) {
161   ***      8     50                          70         die "I need a $arg argument" unless $args{$arg};
162                                                      }
163            4                                 29      my ($event, $dbh) = @args{@required_args};
164                                                   
165            4                                 14      my $warnings;
166            4                                 13      my $warning_count;
167            4                                 16      eval {
168            4                                 18         $warnings      = $dbh->selectall_hashref('SHOW WARNINGS', 'Code');
169            4                                 14         $warning_count = $dbh->selectcol_arrayref('SELECT @@warning_count')->[0];
170                                                      };
171   ***      4     50                          55      die "Failed to SHOW WARNINGS: $EVAL_ERROR"
172                                                         if $EVAL_ERROR;
173                                                   
174            4           100                   60      $event->{warning_count} = $warning_count || 0;
175            4                                 23      $event->{warnings}      = $warnings;
176                                                   
177            4                                 53      return $event;
178                                                   }
179                                                   
180                                                   # Required args:
181                                                   #   * events  arrayref: events
182                                                   # Returns: array
183                                                   # Can die: yes
184                                                   # compare() compares events that have been run through before_execute(),
185                                                   # execute() and after_execute().  Only a "summary" of differences is
186                                                   # returned.  Specific differences are saved internally and are reported
187                                                   # by calling report() later.
188                                                   sub compare {
189            4                    4            78      my ( $self, %args ) = @_;
190            4                                 31      my @required_args = qw(events);
191            4                                 26      foreach my $arg ( @required_args ) {
192   ***      4     50                          41         die "I need a $arg argument" unless $args{$arg};
193                                                      }
194            4                                 27      my ($events) = @args{@required_args};
195                                                   
196            4                                 18      my $different_warning_counts = 0;
197            4                                 17      my $different_warnings       = 0;
198            4                                 17      my $different_warning_levels = 0;
199                                                   
200            4                                 24      my $event0   = $events->[0];
201   ***      4            33                   33      my $item     = $event0->{fingerprint} || $event0->{arg};
202   ***      4            50                   30      my $sampleno = $event0->{sampleno} || 0;
203            4                                 21      my $w0       = $event0->{warnings};
204                                                   
205            4                                 20      my $n_events = scalar @$events;
206            4                                 32      foreach my $i ( 1..($n_events-1) ) {
207            4                                 36         my $event = $events->[$i];
208                                                   
209            4    100    100                   82         if ( ($event0->{warning_count} || 0) != ($event->{warning_count} || 0) ) {
                           100                        
210            2                                  8            $different_warning_counts++;
211            2           100                   56            $self->{diffs}->{warning_counts}->{$item}->{$sampleno}
                           100                        
212                                                               = [ $event0->{warning_count} || 0, $event->{warning_count} || 0 ];
213            2                                 22            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
214                                                         }
215                                                   
216                                                         # Check the warnings on event0 against this event.
217            4                                 40         my $w = $event->{warnings};
218                                                   
219                                                         # Neither event had warnings.
220   ***      4     50     66                   48         next if !$w0 && !$w;
221                                                   
222            4                                 16         my %new_warnings;
223            4                                 33         foreach my $code ( keys %$w0 ) {
224            3    100                          22            if ( exists $w->{$code} ) {
225            2    100                          24               if ( $w->{$code}->{Level} ne $w0->{$code}->{Level} ) {
226                                                                  # Save differences.
227            1                                  5                  $different_warning_levels++;
228            1                                 29                  $self->{diffs}->{levels}->{$item}->{$sampleno}
229                                                                     = [ $code, $w0->{$code}->{Level}, $w->{$code}->{Level},
230                                                                         $w->{$code}->{Message} ];
231            1                                 18                  $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
232                                                               }
233            2                                 20               delete $w->{$code};
234                                                            }
235                                                            else {
236                                                               # This warning code is on event0 but not on this event.
237                                                   
238                                                               # Save differences.
239            1                                  5               $different_warnings++;
240            1                                 15               $self->{diffs}->{warnings}->{$item}->{$sampleno}
241                                                                  = [ 0, $code, $w0->{$code}->{Message} ];
242            1                                 12               $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
243                                                            }
244                                                         }
245                                                   
246                                                         # Any warning codes on this event not deleted above are new;
247                                                         # i.e. they weren't on event0.
248            4                                 36         foreach my $code ( keys %$w ) {
249                                                            # Save differences.
250            1                                  5            $different_warnings++;
251            1                                 15            $self->{diffs}->{warnings}->{$item}->{$sampleno}
252                                                               = [ $i, $code, $w->{$code}->{Message} ];
253            1                                 13            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
254                                                         }
255                                                   
256                                                         # EventAggregator won't know what do with this hashref so delete it.
257            4                                 40         delete $event->{warnings};
258                                                      }
259            4                                 21      delete $event0->{warnings};
260                                                   
261                                                      return (
262            4                                185         different_warning_counts => $different_warning_counts,
263                                                         different_warnings       => $different_warnings,
264                                                         different_warning_levels => $different_warning_levels,
265                                                      );
266                                                   }
267                                                   
268                                                   sub report {
269            3                    3            30      my ( $self, %args ) = @_;
270            3                                 23      my @required_args = qw(hosts);
271            3                                 20      foreach my $arg ( @required_args ) {
272   ***      3     50                          31         die "I need a $arg argument" unless $args{$arg};
273                                                      }
274            3                                 20      my ($hosts) = @args{@required_args};
275                                                   
276   ***      3     50                          13      return unless keys %{$self->{diffs}};
               3                                 42   
277                                                   
278                                                      # These columns are common to all the reports; make them just once.
279            3                                 30      my $query_id_col = {
280                                                         name        => 'Query ID',
281                                                         fixed_width => 18,
282                                                      };
283            6                                 43      my @host_cols = map {
284            3                                 20         my $col = { name => $_->{name} };
285            6                                 37         $col;
286                                                      } @$hosts;
287                                                   
288            3                                 13      my @reports;
289            3                                 24      foreach my $diff ( qw(warnings levels warning_counts) ) {
290            9                                 54         my $report = "_report_diff_$diff";
291            9                                129         push @reports, $self->$report(
292                                                            query_id_col => $query_id_col,
293                                                            host_cols    => \@host_cols,
294                                                            %args
295                                                         );
296                                                      }
297                                                   
298            3                                 64      return join("\n", @reports);
299                                                   }
300                                                   
301                                                   sub _report_diff_warnings {
302            3                    3            31      my ( $self, %args ) = @_;
303            3                                 25      my @required_args = qw(query_id_col hosts);
304            3                                 17      foreach my $arg ( @required_args ) {
305   ***      6     50                          51         die "I need a $arg argument" unless $args{$arg};
306                                                      }
307                                                   
308            3                                 20      my $get_id = $self->{get_id};
309                                                   
310            3    100                          13      return unless keys %{$self->{diffs}->{warnings}};
               3                                 36   
311                                                   
312            2                                 22      my $report = new ReportFormatter(long_last_column => 1);
313            2                                 16      $report->set_title('New warnings');
314            2                                 33      $report->set_columns(
315                                                         $args{query_id_col},
316                                                         { name => 'Host', },
317                                                         { name => 'Code', right_justify => 1 },
318                                                         { name => 'Message' },
319                                                      );
320                                                   
321            2                                 15      my $diff_warnings = $self->{diffs}->{warnings};
322            2                                 21      foreach my $item ( sort keys %$diff_warnings ) {
323            2                                 21         map {
324            2                                  8            my ($hostno, $code, $message) = @{$diff_warnings->{$item}->{$_}};
      ***      0                                  0   
325            2                                 24            $report->add_line(
326                                                               $get_id->($item) . '-' . $_,
327                                                               $args{hosts}->[$hostno]->{name}, $code, $message,
328                                                            );
329            2                                 10         } sort { $a <=> $b } keys %{$diff_warnings->{$item}};
               2                                 19   
330                                                      }
331                                                   
332            2                                 16      return $report->get_report();
333                                                   }
334                                                   
335                                                   sub _report_diff_levels {
336            3                    3            31      my ( $self, %args ) = @_;
337            3                                 24      my @required_args = qw(query_id_col hosts);
338            3                                 20      foreach my $arg ( @required_args ) {
339   ***      6     50                          52         die "I need a $arg argument" unless $args{$arg};
340                                                      }
341                                                   
342            3                                 39      my $get_id = $self->{get_id};
343                                                   
344            3    100                          11      return unless keys %{$self->{diffs}->{levels}};
               3                                 46   
345                                                   
346            1                                 24      my $report = new ReportFormatter(long_last_column => 1);
347            1                                  8      $report->set_title('Warning level differences');
348            3                                 33      $report->set_columns(
349                                                         $args{query_id_col},
350                                                         { name => 'Code', right_justify => 1 },
351                                                         map {
352            1                                  8            my $col = { name => $_->{name}, right_justify => 1  };
353            3                                 26            $col;
354            1                                 10         } @{$args{hosts}},
355                                                         { name => 'Message' },
356                                                      );
357                                                   
358            1                                  9      my $diff_levels = $self->{diffs}->{levels};
359            1                                 12      foreach my $item ( sort keys %$diff_levels ) {
360            1                                 16         map {
361   ***      0                                  0            $report->add_line(
362                                                               $get_id->($item) . '-' . $_,
363            1                                  8               @{$diff_levels->{$item}->{$_}},
364                                                            );
365            1                                  4         } sort { $a <=> $b } keys %{$diff_levels->{$item}};
               1                                 10   
366                                                      }
367                                                   
368            1                                 12      return $report->get_report();
369                                                   }
370                                                   
371                                                   sub _report_diff_warning_counts {
372            3                    3            30      my ( $self, %args ) = @_;
373            3                                 26      my @required_args = qw(query_id_col hosts);
374            3                                 20      foreach my $arg ( @required_args ) {
375   ***      6     50                          49         die "I need a $arg argument" unless $args{$arg};
376                                                      }
377                                                   
378            3                                 19      my $get_id = $self->{get_id};
379                                                   
380            3    100                          12      return unless keys %{$self->{diffs}->{warning_counts}};
               3                                 44   
381                                                   
382            2                                 16      my $report = new ReportFormatter();
383            2                                 15      $report->set_title('Warning count differences');
384            4                                 33      $report->set_columns(
385                                                         $args{query_id_col},
386                                                         map {
387            2                                 14            my $col = { name => $_->{name}, right_justify => 1  };
388            4                                 25            $col;
389            2                                 11         } @{$args{hosts}},
390                                                      );
391                                                   
392            2                                 14      my $diff_warning_counts = $self->{diffs}->{warning_counts};
393            2                                 18      foreach my $item ( sort keys %$diff_warning_counts ) {
394            2                                 19         map {
395   ***      0                                  0            $report->add_line(
396                                                               $get_id->($item) . '-' . $_,
397            2                                 14               @{$diff_warning_counts->{$item}->{$_}},
398                                                            );
399            2                                 10         } sort { $a <=> $b } keys %{$diff_warning_counts->{$item}};
               2                                 17   
400                                                      }
401                                                   
402            2                                 15      return $report->get_report();
403                                                   }
404                                                   
405                                                   sub samples {
406            1                    1             9      my ( $self, $item ) = @_;
407   ***      1     50                           9      return unless $item;
408            1                                  4      my @samples;
409            1                                  4      foreach my $sampleno ( keys %{$self->{samples}->{$item}} ) {
               1                                 13   
410            1                                 14         push @samples, $sampleno, $self->{samples}->{$item}->{$sampleno};
411                                                      }
412            1                                 16      return @samples;
413                                                   }
414                                                   
415                                                   sub reset {
416            1                    1             7      my ( $self ) = @_;
417            1                                  8      $self->{diffs}   = {};
418            1                                 14      $self->{samples} = {};
419            1                                  7      return;
420                                                   }
421                                                   
422                                                   sub _d {
423            1                    1            48      my ($package, undef, $line) = caller 0;
424   ***      2     50                          22      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 18   
425            1                                  9           map { defined $_ ? $_ : 'undef' }
426                                                           @_;
427            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
428                                                   }
429                                                   
430                                                   1;
431                                                   
432                                                   # ###########################################################################
433                                                   # End CompareWarnings package
434                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
43    ***     50      0      6   unless $args{$arg}
68    ***     50      0     12   unless $args{$arg}
73    ***     50      0      6   unless $$self{'clear-warnings'}
75           100      1      5   if (my $tbl = $$self{'clear-warnings-table'}) { }
81    ***     50      1      0   if $EVAL_ERROR
96           100      1      4   if ($EVAL_ERROR) { }
105          100      1      4   unless $ok
124   ***     50      0      8   unless $args{$arg}
128          100      1      3   if (exists $$event{'Query_time'})
144   ***     50      0      3   if $EVAL_ERROR
161   ***     50      0      8   unless $args{$arg}
171   ***     50      0      4   if $EVAL_ERROR
192   ***     50      0      4   unless $args{$arg}
209          100      2      2   if (($$event0{'warning_count'} || 0) != ($$event{'warning_count'} || 0))
220   ***     50      0      4   if not $w0 and not $w
224          100      2      1   if (exists $$w{$code}) { }
225          100      1      1   if ($$w{$code}{'Level'} ne $$w0{$code}{'Level'})
272   ***     50      0      3   unless $args{$arg}
276   ***     50      0      3   unless keys %{$$self{'diffs'};}
305   ***     50      0      6   unless $args{$arg}
310          100      1      2   unless keys %{$$self{'diffs'}{'warnings'};}
339   ***     50      0      6   unless $args{$arg}
344          100      2      1   unless keys %{$$self{'diffs'}{'levels'};}
375   ***     50      0      6   unless $args{$arg}
380          100      1      2   unless keys %{$$self{'diffs'}{'warning_counts'};}
407   ***     50      0      1   unless $item
424   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
220   ***     66      3      1      0   not $w0 and not $w

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
174          100      2      2   $warning_count || 0
202   ***     50      4      0   $$event0{'sampleno'} || 0
209          100      3      1   $$event0{'warning_count'} || 0
             100      3      1   $$event{'warning_count'} || 0
211          100      1      1   $$event0{'warning_count'} || 0
             100      1      1   $$event{'warning_count'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
201   ***     33      4      0      0   $$event0{'fingerprint'} || $$event0{'arg'}


Covered Subroutines
-------------------

Subroutine                  Count Location                                              
--------------------------- ----- ------------------------------------------------------
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:22 
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:23 
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:24 
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:26 
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:28 
_d                              1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:423
_report_diff_levels             3 /home/daniel/dev/maatkit/common/CompareWarnings.pm:336
_report_diff_warning_counts     3 /home/daniel/dev/maatkit/common/CompareWarnings.pm:372
_report_diff_warnings           3 /home/daniel/dev/maatkit/common/CompareWarnings.pm:302
after_execute                   4 /home/daniel/dev/maatkit/common/CompareWarnings.pm:158
before_execute                  6 /home/daniel/dev/maatkit/common/CompareWarnings.pm:65 
compare                         4 /home/daniel/dev/maatkit/common/CompareWarnings.pm:189
execute                         4 /home/daniel/dev/maatkit/common/CompareWarnings.pm:121
new                             2 /home/daniel/dev/maatkit/common/CompareWarnings.pm:40 
report                          3 /home/daniel/dev/maatkit/common/CompareWarnings.pm:269
reset                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:416
samples                         1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:406


