---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/CompareWarnings.pm   98.7   68.5   75.0  100.0    0.0   27.7   89.8
CompareWarnings.t             100.0   50.0   50.0  100.0    n/a   72.3   92.8
Total                          99.1   66.7   63.2  100.0    0.0  100.0   90.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:23 2010
Finish:       Thu Jun 24 19:32:23 2010

Run:          CompareWarnings.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:25 2010
Finish:       Thu Jun 24 19:32:25 2010

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
18                                                    # CompareWarnings package $Revision: 6190 $
19                                                    # ###########################################################################
20                                                    package CompareWarnings;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  4   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  4   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  4   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 11   
27                                                    
28             1                    1             5   use Data::Dumper;
               1                                  2   
               1                                  7   
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
40    ***      2                    2      0     23      my ( $class, %args ) = @_;
41             2                                 11      my @required_args = qw(get_id Quoter QueryParser);
42             2                                 11      foreach my $arg ( @required_args ) {
43    ***      6     50                          30         die "I need a $arg argument" unless $args{$arg};
44                                                       }
45             2                                 24      my $self = {
46                                                          %args,
47                                                          diffs   => {},
48                                                          samples => {},
49                                                       };
50             2                                 40      return bless $self, $class;
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
65    ***      6                    6      0     47      my ( $self, %args ) = @_;
66             6                                 29      my @required_args = qw(event dbh);
67             6                                 23      foreach my $arg ( @required_args ) {
68    ***     12     50                          59         die "I need a $arg argument" unless $args{$arg};
69                                                       }
70             6                                 27      my ($event, $dbh) = @args{@required_args};
71             6                                 14      my $sql;
72                                                    
73    ***      6     50                          27      return $event unless $self->{'clear-warnings'};
74                                                    
75             6    100                          31      if ( my $tbl = $self->{'clear-warnings-table'} ) {
76             1                                  4         $sql = "SELECT * FROM $tbl LIMIT 1";
77             1                                  3         MKDEBUG && _d($sql);
78             1                                  3         eval {
79             1                                 12            $dbh->do($sql);
80                                                          };
81    ***      1     50                           3         die "Failed to SELECT from clear warnings table: $EVAL_ERROR"
82                                                             if $EVAL_ERROR;
83                                                       }
84                                                       else {
85             5                                 19         my $q    = $self->{Quoter};
86             5                                 15         my $qp   = $self->{QueryParser};
87             5                                 43         my @tbls = $qp->get_tables($event->{arg});
88             5                                527         my $ok   = 0;
89                                                          TABLE:
90             5                                 17         foreach my $tbl ( @tbls ) {
91             5                                 18            $sql = "SELECT * FROM $tbl LIMIT 1";
92             5                                 11            MKDEBUG && _d($sql);
93             5                                 14            eval {
94             5                                665               $dbh->do($sql);
95                                                             };
96             5    100                          24            if ( $EVAL_ERROR ) {
97             1                                  4               MKDEBUG && _d('Failed to clear warnings');
98                                                             }
99                                                             else {
100            4                                 12               MKDEBUG && _d('Cleared warnings');
101            4                                 10               $ok = 1;
102            4                                 14               last TABLE;
103                                                            }
104                                                         }
105            5    100                          23         die "Failed to clear warnings"
106                                                            unless $ok;
107                                                      }
108                                                   
109            4                                 33      return $event;
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
121   ***      4                    4      0     22      my ( $self, %args ) = @_;
122            4                                 17      my @required_args = qw(event dbh);
123            4                                 15      foreach my $arg ( @required_args ) {
124   ***      8     50                          38         die "I need a $arg argument" unless $args{$arg};
125                                                      }
126            4                                 17      my ($event, $dbh) = @args{@required_args};
127                                                   
128            4    100                          20      if ( exists $event->{Query_time} ) {
129            1                                  2         MKDEBUG && _d('Query already executed');
130            1                                  6         return $event;
131                                                      }
132                                                   
133            3                                  6      MKDEBUG && _d('Executing query');
134            3                                 15      my $query = $event->{arg};
135            3                                 10      my ( $start, $end, $query_time );
136                                                   
137            3                                 12      $event->{Query_time} = 0;
138            3                                  6      eval {
139            3                                 12         $start = time();
140            3                                376         $dbh->do($query);
141            3                                 14         $end   = time();
142            3                                 54         $query_time = sprintf '%.6f', $end - $start;
143                                                      };
144   ***      3     50                          13      die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
145                                                   
146            3                                 13      $event->{Query_time} = $query_time;
147                                                   
148            3                                 26      return $event;
149                                                   }
150                                                   
151                                                   # Required args:
152                                                   #   * event  hashref: an event
153                                                   #   * dbh    scalar: active dbh
154                                                   # Returns: hashref
155                                                   # Can die: yes
156                                                   # after_execute() gets any warnings from SHOW WARNINGS.
157                                                   sub after_execute {
158   ***      4                    4      0     30      my ( $self, %args ) = @_;
159            4                                 19      my @required_args = qw(event dbh);
160            4                                 15      foreach my $arg ( @required_args ) {
161   ***      8     50                          38         die "I need a $arg argument" unless $args{$arg};
162                                                      }
163            4                                 16      my ($event, $dbh) = @args{@required_args};
164                                                   
165            4                                 11      my $warnings;
166            4                                 10      my $warning_count;
167            4                                  9      eval {
168            4                                 10         $warnings      = $dbh->selectall_hashref('SHOW WARNINGS', 'Code');
169            4                                  9         $warning_count = $dbh->selectcol_arrayref('SELECT @@warning_count')->[0];
170                                                      };
171   ***      4     50                         685      die "Failed to SHOW WARNINGS: $EVAL_ERROR"
172                                                         if $EVAL_ERROR;
173                                                   
174                                                      # We munge the warnings to be the same thing so testing is easier, otherwise
175                                                      # a ton of code has to be involved.  This seems to be the minimal necessary
176                                                      # code to handle changes in warning messages.
177            2                                 13      map {
178            4                                 18         $_->{Message} =~ s/Out of range value adjusted/Out of range value/;
179                                                      } values %$warnings;
180            4           100                   33      $event->{warning_count} = $warning_count || 0;
181            4                                 16      $event->{warnings}      = $warnings;
182                                                   
183            4                                 29      return $event;
184                                                   }
185                                                   
186                                                   # Required args:
187                                                   #   * events  arrayref: events
188                                                   # Returns: array
189                                                   # Can die: yes
190                                                   # compare() compares events that have been run through before_execute(),
191                                                   # execute() and after_execute().  Only a "summary" of differences is
192                                                   # returned.  Specific differences are saved internally and are reported
193                                                   # by calling report() later.
194                                                   sub compare {
195   ***      4                    4      0     44      my ( $self, %args ) = @_;
196            4                                 30      my @required_args = qw(events);
197            4                                 29      foreach my $arg ( @required_args ) {
198   ***      4     50                          41         die "I need a $arg argument" unless $args{$arg};
199                                                      }
200            4                                 27      my ($events) = @args{@required_args};
201                                                   
202            4                                 16      my $different_warning_counts = 0;
203            4                                 17      my $different_warnings       = 0;
204            4                                 16      my $different_warning_levels = 0;
205                                                   
206            4                                 23      my $event0   = $events->[0];
207   ***      4            33                   36      my $item     = $event0->{fingerprint} || $event0->{arg};
208   ***      4            50                   32      my $sampleno = $event0->{sampleno} || 0;
209            4                                 21      my $w0       = $event0->{warnings};
210                                                   
211            4                                 19      my $n_events = scalar @$events;
212            4                                 31      foreach my $i ( 1..($n_events-1) ) {
213            4                                 23         my $event = $events->[$i];
214                                                   
215            4    100    100                   80         if ( ($event0->{warning_count} || 0) != ($event->{warning_count} || 0) ) {
                           100                        
216            2                                  7            MKDEBUG && _d('Warning counts differ:',
217                                                               $event0->{warning_count}, $event->{warning_count});
218            2                                  9            $different_warning_counts++;
219            2           100                   58            $self->{diffs}->{warning_counts}->{$item}->{$sampleno}
                           100                        
220                                                               = [ $event0->{warning_count} || 0, $event->{warning_count} || 0 ];
221            2                                 22            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
222                                                         }
223                                                   
224                                                         # Check the warnings on event0 against this event.
225            4                                 22         my $w = $event->{warnings};
226                                                   
227                                                         # Neither event had warnings.
228   ***      4     50     66                   58         next if !$w0 && !$w;
229                                                   
230            4                                 16         my %new_warnings;
231            4                                 32         foreach my $code ( keys %$w0 ) {
232            3    100                          23            if ( exists $w->{$code} ) {
233            2    100                          24               if ( $w->{$code}->{Level} ne $w0->{$code}->{Level} ) {
234            1                                  5                  MKDEBUG && _d('Warning levels differ:',
235                                                                     $w0->{$code}->{Level}, $w->{$code}->{Level});
236                                                                  # Save differences.
237            1                                  4                  $different_warning_levels++;
238            1                                 25                  $self->{diffs}->{levels}->{$item}->{$sampleno}
239                                                                     = [ $code, $w0->{$code}->{Level}, $w->{$code}->{Level},
240                                                                         $w->{$code}->{Message} ];
241            1                                 12                  $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
242                                                               }
243            2                                 20               delete $w->{$code};
244                                                            }
245                                                            else {
246                                                               # This warning code is on event0 but not on this event.
247            1                                  4               MKDEBUG && _d('Warning gone:', $w0->{$code}->{Message});
248                                                               # Save differences.
249            1                                  4               $different_warnings++;
250            1                                 15               $self->{diffs}->{warnings}->{$item}->{$sampleno}
251                                                                  = [ 0, $code, $w0->{$code}->{Message} ];
252            1                                 12               $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
253                                                            }
254                                                         }
255                                                   
256                                                         # Any warning codes on this event not deleted above are new;
257                                                         # i.e. they weren't on event0.
258            4                                 36         foreach my $code ( keys %$w ) {
259            1                                  4            MKDEBUG && _d('Warning new:', $w->{$code}->{Message});
260                                                            # Save differences.
261            1                                  5            $different_warnings++;
262            1                                 13            $self->{diffs}->{warnings}->{$item}->{$sampleno}
263                                                               = [ $i, $code, $w->{$code}->{Message} ];
264            1                                 12            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
265                                                         }
266                                                   
267                                                         # EventAggregator won't know what do with this hashref so delete it.
268            4                                 40         delete $event->{warnings};
269                                                      }
270            4                                 22      delete $event0->{warnings};
271                                                   
272                                                      return (
273            4                                133         different_warning_counts => $different_warning_counts,
274                                                         different_warnings       => $different_warnings,
275                                                         different_warning_levels => $different_warning_levels,
276                                                      );
277                                                   }
278                                                   
279                                                   sub report {
280   ***      3                    3      0     29      my ( $self, %args ) = @_;
281            3                                 20      my @required_args = qw(hosts);
282            3                                 21      foreach my $arg ( @required_args ) {
283   ***      3     50                          32         die "I need a $arg argument" unless $args{$arg};
284                                                      }
285            3                                 21      my ($hosts) = @args{@required_args};
286                                                   
287   ***      3     50                          10      return unless keys %{$self->{diffs}};
               3                                 32   
288                                                   
289                                                      # These columns are common to all the reports; make them just once.
290            3                                 23      my $query_id_col = {
291                                                         name        => 'Query ID',
292                                                      };
293            6                                 44      my @host_cols = map {
294            3                                 20         my $col = { name => $_->{name} };
295            6                                 37         $col;
296                                                      } @$hosts;
297                                                   
298            3                                 13      my @reports;
299            3                                 19      foreach my $diff ( qw(warnings levels warning_counts) ) {
300            9                              13663         my $report = "_report_diff_$diff";
301            9                                128         push @reports, $self->$report(
302                                                            query_id_col => $query_id_col,
303                                                            host_cols    => \@host_cols,
304                                                            %args
305                                                         );
306                                                      }
307                                                   
308            3                              11228      return join("\n", @reports);
309                                                   }
310                                                   
311                                                   sub _report_diff_warnings {
312            3                    3            30      my ( $self, %args ) = @_;
313            3                                 22      my @required_args = qw(query_id_col hosts);
314            3                                 23      foreach my $arg ( @required_args ) {
315   ***      6     50                          51         die "I need a $arg argument" unless $args{$arg};
316                                                      }
317                                                   
318            3                                 20      my $get_id = $self->{get_id};
319                                                   
320            3    100                          20      return unless keys %{$self->{diffs}->{warnings}};
               3                                 40   
321                                                   
322            2                                 21      my $report = new ReportFormatter(extend_right => 1);
323            2                               1113      $report->set_title('New warnings');
324            2                                 98      $report->set_columns(
325                                                         $args{query_id_col},
326                                                         { name => 'Host', },
327                                                         { name => 'Code', right_justify => 1 },
328                                                         { name => 'Message' },
329                                                      );
330                                                   
331            2                               1320      my $diff_warnings = $self->{diffs}->{warnings};
332            2                                 24      foreach my $item ( sort keys %$diff_warnings ) {
333            2                                 21         map {
334            2                                 10            my ($hostno, $code, $message) = @{$diff_warnings->{$item}->{$_}};
      ***      0                                  0   
335            2                                 17            $report->add_line(
336                                                               $get_id->($item) . '-' . $_,
337                                                               $args{hosts}->[$hostno]->{name}, $code, $message,
338                                                            );
339            2                                  9         } sort { $a <=> $b } keys %{$diff_warnings->{$item}};
               2                                 19   
340                                                      }
341                                                   
342            2                                642      return $report->get_report();
343                                                   }
344                                                   
345                                                   sub _report_diff_levels {
346            3                    3            37      my ( $self, %args ) = @_;
347            3                                 23      my @required_args = qw(query_id_col hosts);
348            3                                 18      foreach my $arg ( @required_args ) {
349   ***      6     50                          53         die "I need a $arg argument" unless $args{$arg};
350                                                      }
351                                                   
352            3                                 19      my $get_id = $self->{get_id};
353                                                   
354            3    100                          10      return unless keys %{$self->{diffs}->{levels}};
               3                                 44   
355                                                   
356            1                                 41      my $report = new ReportFormatter(extend_right => 1);
357            1                                138      $report->set_title('Warning level differences');
358            3                                 25      $report->set_columns(
359                                                         $args{query_id_col},
360                                                         { name => 'Code', right_justify => 1 },
361                                                         map {
362            1                                 14            my $col = { name => $_->{name}, right_justify => 1  };
363            3                                 22            $col;
364            1                                 40         } @{$args{hosts}},
365                                                         { name => 'Message' },
366                                                      );
367                                                   
368            1                                922      my $diff_levels = $self->{diffs}->{levels};
369            1                                 12      foreach my $item ( sort keys %$diff_levels ) {
370            1                                 82         map {
371   ***      0                                  0            $report->add_line(
372                                                               $get_id->($item) . '-' . $_,
373            1                                 12               @{$diff_levels->{$item}->{$_}},
374                                                            );
375            1                                  6         } sort { $a <=> $b } keys %{$diff_levels->{$item}};
               1                                 10   
376                                                      }
377                                                   
378            1                                334      return $report->get_report();
379                                                   }
380                                                   
381                                                   sub _report_diff_warning_counts {
382            3                    3            31      my ( $self, %args ) = @_;
383            3                                 25      my @required_args = qw(query_id_col hosts);
384            3                                 19      foreach my $arg ( @required_args ) {
385   ***      6     50                          59         die "I need a $arg argument" unless $args{$arg};
386                                                      }
387                                                   
388            3                                 18      my $get_id = $self->{get_id};
389                                                   
390            3    100                          12      return unless keys %{$self->{diffs}->{warning_counts}};
               3                                 41   
391                                                   
392            2                                 18      my $report = new ReportFormatter();
393            2                                161      $report->set_title('Warning count differences');
394            4                                 36      $report->set_columns(
395                                                         $args{query_id_col},
396                                                         map {
397            2                                 14            my $col = { name => $_->{name}, right_justify => 1  };
398            4                                 26            $col;
399            2                                 52         } @{$args{hosts}},
400                                                      );
401                                                   
402            2                                920      my $diff_warning_counts = $self->{diffs}->{warning_counts};
403            2                                 20      foreach my $item ( sort keys %$diff_warning_counts ) {
404            2                                 81         map {
405   ***      0                                  0            $report->add_line(
406                                                               $get_id->($item) . '-' . $_,
407            2                                 14               @{$diff_warning_counts->{$item}->{$_}},
408                                                            );
409            2                                  9         } sort { $a <=> $b } keys %{$diff_warning_counts->{$item}};
               2                                 18   
410                                                      }
411                                                   
412            2                                431      return $report->get_report();
413                                                   }
414                                                   
415                                                   sub samples {
416   ***      1                    1      0      8      my ( $self, $item ) = @_;
417   ***      1     50                           9      return unless $item;
418            1                                  4      my @samples;
419            1                                  5      foreach my $sampleno ( keys %{$self->{samples}->{$item}} ) {
               1                                 14   
420            1                                 12         push @samples, $sampleno, $self->{samples}->{$item}->{$sampleno};
421                                                      }
422            1                                 16      return @samples;
423                                                   }
424                                                   
425                                                   sub reset {
426   ***      1                    1      0      6      my ( $self ) = @_;
427            1                                  8      $self->{diffs}   = {};
428            1                                 13      $self->{samples} = {};
429            1                                  7      return;
430                                                   }
431                                                   
432                                                   sub _d {
433            1                    1            13      my ($package, undef, $line) = caller 0;
434   ***      2     50                          17      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 16   
               2                                 20   
435            1                                 12           map { defined $_ ? $_ : 'undef' }
436                                                           @_;
437            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
438                                                   }
439                                                   
440                                                   1;
441                                                   
442                                                   # ###########################################################################
443                                                   # End CompareWarnings package
444                                                   # ###########################################################################


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
198   ***     50      0      4   unless $args{$arg}
215          100      2      2   if (($$event0{'warning_count'} || 0) != ($$event{'warning_count'} || 0))
228   ***     50      0      4   if not $w0 and not $w
232          100      2      1   if (exists $$w{$code}) { }
233          100      1      1   if ($$w{$code}{'Level'} ne $$w0{$code}{'Level'})
283   ***     50      0      3   unless $args{$arg}
287   ***     50      0      3   unless keys %{$$self{'diffs'};}
315   ***     50      0      6   unless $args{$arg}
320          100      1      2   unless keys %{$$self{'diffs'}{'warnings'};}
349   ***     50      0      6   unless $args{$arg}
354          100      2      1   unless keys %{$$self{'diffs'}{'levels'};}
385   ***     50      0      6   unless $args{$arg}
390          100      1      2   unless keys %{$$self{'diffs'}{'warning_counts'};}
417   ***     50      0      1   unless $item
434   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
228   ***     66      3      1      0   not $w0 and not $w

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0
180          100      2      2   $warning_count || 0
208   ***     50      4      0   $$event0{'sampleno'} || 0
215          100      3      1   $$event0{'warning_count'} || 0
             100      3      1   $$event{'warning_count'} || 0
219          100      1      1   $$event0{'warning_count'} || 0
             100      1      1   $$event{'warning_count'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
207   ***     33      4      0      0   $$event0{'fingerprint'} || $$event0{'arg'}


Covered Subroutines
-------------------

Subroutine                  Count Pod Location                                              
--------------------------- ----- --- ------------------------------------------------------
BEGIN                           1     /home/daniel/dev/maatkit/common/CompareWarnings.pm:22 
BEGIN                           1     /home/daniel/dev/maatkit/common/CompareWarnings.pm:23 
BEGIN                           1     /home/daniel/dev/maatkit/common/CompareWarnings.pm:24 
BEGIN                           1     /home/daniel/dev/maatkit/common/CompareWarnings.pm:26 
BEGIN                           1     /home/daniel/dev/maatkit/common/CompareWarnings.pm:28 
_d                              1     /home/daniel/dev/maatkit/common/CompareWarnings.pm:433
_report_diff_levels             3     /home/daniel/dev/maatkit/common/CompareWarnings.pm:346
_report_diff_warning_counts     3     /home/daniel/dev/maatkit/common/CompareWarnings.pm:382
_report_diff_warnings           3     /home/daniel/dev/maatkit/common/CompareWarnings.pm:312
after_execute                   4   0 /home/daniel/dev/maatkit/common/CompareWarnings.pm:158
before_execute                  6   0 /home/daniel/dev/maatkit/common/CompareWarnings.pm:65 
compare                         4   0 /home/daniel/dev/maatkit/common/CompareWarnings.pm:195
execute                         4   0 /home/daniel/dev/maatkit/common/CompareWarnings.pm:121
new                             2   0 /home/daniel/dev/maatkit/common/CompareWarnings.pm:40 
report                          3   0 /home/daniel/dev/maatkit/common/CompareWarnings.pm:280
reset                           1   0 /home/daniel/dev/maatkit/common/CompareWarnings.pm:426
samples                         1   0 /home/daniel/dev/maatkit/common/CompareWarnings.pm:416


CompareWarnings.t

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
10             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 20;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            13   use Quoter;
               1                                  3   
               1                                 11   
15             1                    1            11   use QueryParser;
               1                                  3   
               1                                 11   
16             1                    1            11   use ReportFormatter;
               1                                  3   
               1                                 11   
17             1                    1            12   use Transformers;
               1                                  3   
               1                                 10   
18             1                    1            10   use DSNParser;
               1                                  3   
               1                                 12   
19             1                    1            15   use Sandbox;
               1                                  3   
               1                                 11   
20             1                    1            11   use CompareWarnings;
               1                                  3   
               1                                 11   
21             1                    1            11   use MaatkitTest;
               1                                  6   
               1                                 35   
22                                                    
23             1                                 11   my $dp  = new DSNParser(opts=>$dsn_opts);
24             1                                241   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
25    ***      1     50                          97   my $dbh1 = $sb->get_dbh_for('master')
26                                                       or BAIL_OUT('Cannot connect to sandbox master');
27                                                    
28             1                                404   $sb->create_dbs($dbh1, ['test']);
29                                                    
30             1                                844   Transformers->import(qw(make_checksum));
31                                                    
32             1                                180   my $q  = new Quoter();
33             1                                 34   my $qp = new QueryParser();
34             1                                 20   my %modules = (
35                                                       Quoter      => $q,
36                                                       QueryParser => $qp,
37                                                    );
38                                                    
39             1                                  3   my $cw;
40             1                                  2   my $report;
41             1                                  4   my @events;
42             1                                  9   my $hosts = [
43                                                       { dbh => $dbh1, name => 'dbh-1' },
44                                                       { dbh => $dbh1, name => 'dbh-2'  },
45                                                    ];
46                                                    
47                                                    sub proc {
48             6                    6            33      my ( $when, %args ) = @_;
49    ***      6     50    100                   73      die "I don't know when $when is"
      ***                   66                        
50                                                          unless $when eq 'before_execute'
51                                                              || $when eq 'execute'
52                                                              || $when eq 'after_execute';
53             6                                 32      for my $i ( 0..$#events ) {
54            12                                118         $events[$i] = $cw->$when(
55                                                             event    => $events[$i],
56                                                             dbh      => $hosts->[$i]->{dbh},
57                                                             %args,
58                                                          );
59                                                       }
60                                                    };
61                                                    
62                                                    sub get_id {
63             5                    5            54      return make_checksum(@_);
64                                                    }
65                                                    
66                                                    # #############################################################################
67                                                    # Test it.
68                                                    # #############################################################################
69                                                    
70             1                              94184   diag(`/tmp/12345/use < $trunk/common/t/samples/compare-warnings.sql`);
71                                                    
72             1                                 22   @events = (
73                                                       {
74                                                          arg         => 'select * from test.t',
75                                                          fingerprint => 'select * from test.t',
76                                                          sampleno    => 1,
77                                                       },
78                                                       {
79                                                          arg         => 'select * from test.t',
80                                                          fingerprint => 'select * from test.t',
81                                                          sampleno    => 1,
82                                                       },
83                                                    );
84                                                    
85             1                                 40   $cw = new CompareWarnings(
86                                                       'clear-warnings'       => 1,
87                                                       'clear-warnings-table' => 'mysql.bad',
88                                                       get_id => \&get_id,
89                                                       %modules,
90                                                    );
91                                                    
92             1                                 12   isa_ok($cw, 'CompareWarnings');
93                                                    
94             1                                  9   eval {
95             1                                 12      $cw->before_execute(
96                                                          event => $events[0],
97                                                          dbh   => $dbh1,
98                                                       );
99                                                    };
100                                                   
101            1                                 23   like(
102                                                      $EVAL_ERROR,
103                                                      qr/^Failed/,
104                                                      "Can't clear warnings with bad table"
105                                                   );
106                                                   
107            1                                 22   $cw = new CompareWarnings(
108                                                      'clear-warnings' => 1,
109                                                      get_id => \&get_id,
110                                                      %modules,
111                                                   );
112                                                   
113            1                                  5   eval {
114            1                                  7      $cw->before_execute(
115                                                         event => { arg => 'select * from bad.db' },
116                                                         dbh   => $dbh1,
117                                                      );
118                                                   };
119                                                   
120            1                                 13   like(
121                                                      $EVAL_ERROR,
122                                                      qr/^Failed/,
123                                                      "Can't clear warnings with query with bad tables"
124                                                   );
125                                                   
126            1                                 14   proc('before_execute', db=>'test');
127                                                   
128            1                                  8   $events[0]->{Query_time} = 123;
129            1                                  5   proc('execute');
130                                                   
131            1                                  7   is(
132                                                      $events[0]->{Query_time},
133                                                      123,
134                                                      "execute() doesn't execute if Query_time already exists"
135                                                   );
136                                                   
137   ***      1            33                   25   ok(
138                                                      exists $events[1]->{Query_time}
139                                                      && $events[1]->{Query_time} >= 0,
140                                                      "execute() will execute if Query_time doesn't exist ($events[1]->{Query_time})"
141                                                   );
142                                                   
143            1                                  5   proc('after_execute');
144                                                   
145            1                                  8   is(
146                                                      $events[0]->{warning_count},
147                                                      0,
148                                                      'Zero warning count'
149                                                   );
150                                                   
151            1                                 13   is_deeply(
152                                                      $events[0]->{warnings},
153                                                      {},
154                                                      'No warnings'
155                                                   );
156                                                   
157                                                   
158                                                   # #############################################################################
159                                                   # Test with the same warning on both hosts.
160                                                   # #############################################################################
161            1                                 21   @events = (
162                                                      {
163                                                         arg         => 'insert into test.t values (-2,"hi2",2)',
164                                                         fingerprint => 'insert into test.t values (?,?,?)',
165                                                         sampleno    => 1,
166                                                      },
167                                                      {
168                                                         arg         => 'insert into test.t values (-2,"hi2",2)',
169                                                         fingerprint => 'insert into test.t values (?,?,?)',
170                                                         sampleno    => 1,
171                                                      },
172                                                   );
173                                                   
174            1                                  5   proc('before_execute');
175            1                                  6   proc('execute');
176            1                                  5   proc('after_execute');
177                                                   
178   ***      1            33                   22   ok(
179                                                      $events[0]->{warning_count} == 1 && $events[1]->{warning_count} == 1,
180                                                      'Both events had 1 warning'
181                                                   );
182                                                   
183            1                                 13   is_deeply(
184                                                      $events[0]->{warnings},
185                                                      {
186                                                         '1264' => {
187                                                            Code    => '1264',
188                                                            Level   => 'Warning',
189                                                            Message => 'Out of range value for column \'i\' at row 1'
190                                                         }
191                                                      },
192                                                      'Event 0 has 1264 warning'
193                                                   );
194                                                   
195            1                                 16   is_deeply(
196                                                      $events[1]->{warnings},
197                                                      {
198                                                         '1264' => {
199                                                            Code    => '1264',
200                                                            Level   => 'Warning',
201                                                            Message => 'Out of range value for column \'i\' at row 1'
202                                                         }
203                                                      },
204                                                      'Event 1 has same 1264 warning'
205                                                   );
206                                                   
207                                                   # Compare the warnings: there should be no diffs since they're the same.
208            1                                 31   is_deeply(
209                                                      [ $cw->compare(events => \@events, hosts => $hosts) ],
210                                                      [qw(
211                                                         different_warning_counts 0
212                                                         different_warnings       0
213                                                         different_warning_levels 0
214                                                      )],
215                                                      'compare(), no differences'
216                                                   );
217                                                   
218   ***      1            33                   51   ok(
219                                                      !exists $events[0]->{warnings}
220                                                      && !exists $events[1]->{warnings},
221                                                      'compare() deletes the warnings hashes from the events'
222                                                   );
223                                                   
224                                                   # Add the warnings back with an increased level on the second event.
225            1                                 15   my $w1 = {
226                                                      '1264' => {
227                                                         Code    => '1264',
228                                                         Level   => 'Warning',
229                                                         Message => 'Out of range value for column \'i\' at row 1'
230                                                      },
231                                                   };
232            1                                 12   my $w2 = {
233                                                      '1264' => {
234                                                         Code    => '1264',
235                                                         Level   => 'Error',  # diff
236                                                         Message => 'Out of range value for column \'i\' at row 1'
237                                                      },
238                                                   };
239            1                                  4   %{$events[0]->{warnings}} = %{$w1};
               1                                 10   
               1                                  8   
240            1                                  5   %{$events[1]->{warnings}} = %{$w2};
               1                                  8   
               1                                  6   
241                                                   
242            1                                 22   is_deeply(
243                                                      [ $cw->compare(events => \@events, hosts => $hosts) ],
244                                                      [qw(
245                                                         different_warning_counts 0
246                                                         different_warnings       0
247                                                         different_warning_levels 1
248                                                      )],
249                                                      'compare(), same warnings but different levels'
250                                                   );
251                                                   
252            1                                 17   $report = <<EOF;
253                                                   # Warning level differences
254                                                   # Query ID           Code dbh-1   dbh-2 Message
255                                                   # ================== ==== ======= ===== ======================================
256                                                   # 4336C4AAA4EEF76B-1 1264 Warning Error Out of range value for column 'i' at row 1
257                                                   EOF
258                                                   
259            1                                 17   is(
260                                                      $cw->report(hosts => $hosts),
261                                                      $report,
262                                                      'report warning level difference'
263                                                   );
264                                                   
265            1                                 11   $w2->{1264}->{Level} = 'Warning';
266            1                                 20   $cw->reset();
267                                                   
268                                                   # Make like the warning didn't happen on the 2nd event.
269            1                                  4   %{$events[0]->{warnings}} = %{$w1};
               1                                 10   
               1                                  7   
270            1                                  8   $events[0]->{warning_count} = 1;
271            1                                  6   delete $events[1]->{warnings};
272            1                                  7   $events[1]->{warning_count} = 0;
273                                                   
274            1                                 12   is_deeply(
275                                                      [ $cw->compare(events => \@events, hosts => $hosts) ],
276                                                      [qw(
277                                                         different_warning_counts 1
278                                                         different_warnings       1
279                                                         different_warning_levels 0
280                                                      )],
281                                                      'compare(), warning only on event 0'
282                                                   );
283                                                   
284            1                                 21   $report = <<EOF;
285                                                   # New warnings
286                                                   # Query ID           Host  Code Message
287                                                   # ================== ===== ==== ==========================================
288                                                   # 4336C4AAA4EEF76B-1 dbh-1 1264 Out of range value for column 'i' at row 1
289                                                   
290                                                   # Warning count differences
291                                                   # Query ID           dbh-1 dbh-2
292                                                   # ================== ===== =====
293                                                   # 4336C4AAA4EEF76B-1     1     0
294                                                   EOF
295                                                   
296            1                                 10   is(
297                                                      $cw->report(hosts => $hosts),
298                                                      $report,
299                                                      'report new warning on host 1'
300                                                   );
301                                                   
302                                                   # Make like the warning didn't happen on the first event;
303            1                                 10   delete $events[0]->{warnings};
304            1                                  7   $events[0]->{warning_count} = 0;
305            1                                  4   %{$events[1]->{warnings}} = %{$w2};
               1                                 10   
               1                                  9   
306            1                                  8   $events[1]->{warning_count} = 1;
307                                                   
308            1                                 18   is_deeply(
309                                                      [ $cw->compare(events => \@events, hosts => $hosts) ],
310                                                      [qw(
311                                                         different_warning_counts 1
312                                                         different_warnings       1
313                                                         different_warning_levels 0
314                                                      )],
315                                                      'compare(), warning only on event 1'
316                                                   );
317                                                   
318            1                                 16   $report = <<EOF;
319                                                   # New warnings
320                                                   # Query ID           Host  Code Message
321                                                   # ================== ===== ==== ==========================================
322                                                   # 4336C4AAA4EEF76B-1 dbh-2 1264 Out of range value for column 'i' at row 1
323                                                   
324                                                   # Warning count differences
325                                                   # Query ID           dbh-1 dbh-2
326                                                   # ================== ===== =====
327                                                   # 4336C4AAA4EEF76B-1     0     1
328                                                   EOF
329                                                   
330            1                                 10   is(
331                                                      $cw->report(hosts => $hosts),
332                                                      $report,
333                                                      'report new warning on host 2'
334                                                   );
335                                                   
336            1                                 17   is_deeply(
337                                                      [ $cw->samples('insert into test.t values (?,?,?)') ],
338                                                      [ '1', 'insert into test.t values (-2,"hi2",2)' ],
339                                                      'samples()'
340                                                   );
341                                                   
342                                                   # #############################################################################
343                                                   # Done.
344                                                   # #############################################################################
345            1                                 16   my $output = '';
346                                                   {
347            1                                  4      local *STDERR;
               1                                 18   
348            1                    1             3      open STDERR, '>', \$output;
               1                                591   
               1                                  6   
               1                                 11   
349            1                                 31      $cw->_d('Complete test coverage');
350                                                   }
351                                                   like(
352            1                                 32      $output,
353                                                      qr/Complete test coverage/,
354                                                      '_d() works'
355                                                   );
356            1                                 23   $sb->wipe_clean($dbh1);
357            1                                  6   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
25    ***     50      0      1   unless my $dbh1 = $sb->get_dbh_for('master')
49    ***     50      0      6   unless $when eq 'before_execute' or $when eq 'execute' or $when eq 'after_execute'


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
137   ***     33      0      0      1   exists $events[1]{'Query_time'} && $events[1]{'Query_time'} >= 0
178   ***     33      0      0      1   $events[0]{'warning_count'} == 1 && $events[1]{'warning_count'} == 1
218   ***     33      0      0      1   !exists($events[0]{'warnings'}) && !exists($events[1]{'warnings'})

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
49           100      2      2      2   $when eq 'before_execute' or $when eq 'execute'
      ***     66      4      2      0   $when eq 'before_execute' or $when eq 'execute' or $when eq 'after_execute'


Covered Subroutines
-------------------

Subroutine Count Location             
---------- ----- ---------------------
BEGIN          1 CompareWarnings.t:10 
BEGIN          1 CompareWarnings.t:11 
BEGIN          1 CompareWarnings.t:12 
BEGIN          1 CompareWarnings.t:14 
BEGIN          1 CompareWarnings.t:15 
BEGIN          1 CompareWarnings.t:16 
BEGIN          1 CompareWarnings.t:17 
BEGIN          1 CompareWarnings.t:18 
BEGIN          1 CompareWarnings.t:19 
BEGIN          1 CompareWarnings.t:20 
BEGIN          1 CompareWarnings.t:21 
BEGIN          1 CompareWarnings.t:348
BEGIN          1 CompareWarnings.t:4  
BEGIN          1 CompareWarnings.t:9  
get_id         5 CompareWarnings.t:63 
proc           6 CompareWarnings.t:48 


