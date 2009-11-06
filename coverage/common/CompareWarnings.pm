---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/CompareWarnings.pm   98.6   65.0   77.8  100.0    n/a  100.0   91.1
Total                          98.6   65.0   77.8  100.0    n/a  100.0   91.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          CompareWarnings.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Nov  6 21:05:55 2009
Finish:       Fri Nov  6 21:05:55 2009

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
18                                                    # CompareWarnings package $Revision$
19                                                    # ###########################################################################
20                                                    package CompareWarnings;
21                                                    
22             1                    1             6   use strict;
               1                                  2   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                  7   
27                                                    
28             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  6   
29                                                    $Data::Dumper::Indent    = 1;
30                                                    $Data::Dumper::Sortkeys  = 1;
31                                                    $Data::Dumper::Quotekeys = 0;
32                                                    
33                                                    # Required args:
34                                                    #   * clear   bool: clear warnings before each run
35                                                    #   * get_id  coderef: used by report() to trf query to its ID
36                                                    #   * common modules
37                                                    sub new {
38             1                    1         80972      my ( $class, %args ) = @_;
39             1                                 11      my @required_args = qw(clear get_id Quoter VersionParser);
40             1                                 11      foreach my $arg ( @required_args ) {
41    ***      4     50                          34         die "I need a $arg argument" unless $args{$arg};
42                                                       }
43             1                                 21      my $self = {
44                                                          %args,
45                                                          tmp_tbl => undef,  # tmp tbl used to clear warnings reliably
46                                                          diffs   => {},
47                                                          samples => {},
48                                                       };
49             1                                 37      return bless $self, $class;
50                                                    }
51                                                    
52                                                    # Required args:
53                                                    #   * event  hashref: an event
54                                                    #   * dbh    scalar: active dbh
55                                                    # Optional args:
56                                                    #   * db             scalar: database name to create temp table in unless...
57                                                    #   * temp-database  scalar: ...temp db name is given
58                                                    # Returns: hashref
59                                                    # Can die: yes
60                                                    # before_execute() selects from its special temp table to clear the warnings
61                                                    # if the module was created with the clear arg specified.  The temp table is
62                                                    # created if there's a db or temp db and the table doesn't exist yet.
63                                                    sub before_execute {
64             7                    7           261      my ( $self, %args ) = @_;
65             7                                 48      my @required_args = qw(event dbh);
66             7                                 37      foreach my $arg ( @required_args ) {
67    ***     14     50                         105         die "I need a $arg argument" unless $args{$arg};
68                                                       }
69             7                                 50      my ($event, $dbh) = @args{@required_args};
70             7                                 23      my $sql;
71                                                    
72    ***      7     50                          63      return $event unless $self->{clear};
73                                                    
74             7    100                          48      if ( !$self->{tmp_tbl} ) {
75             2                                  5         MKDEBUG && _d('Creating temporary table');
76                                                    
77             2                                 15         my ($db, $tmp_tbl) = @args{qw(db temp-table)};
78    ***      2     50                           9         $db = $args{'temp-database'} if $args{'temp-database'};
79             2    100                           8         die "Cannot clear warnings without a database"
80                                                             unless $db;
81                                                    
82             1                                  5         my $q  = $self->{Quoter};
83             1                                  4         my $vp = $self->{VersionParser};
84                                                    
85             1                                 15         $self->{tmp_tbl} = $q->quote($db, 'mk_upgrade_clear_warnings');
86    ***      1     50                          14         my $engine       = $vp->version_ge($dbh, '5.0.0') ? 'ENGINE' : 'TYPE';
87                                                    
88             1                                  4         eval {
89             1                                  7            $sql = "CREATE TABLE $self->{tmp_tbl} (i int) $engine=MEMORY";
90             1                                  3            MKDEBUG && _d($sql);
91             1                              52648            $dbh->do($sql);
92                                                    
93             1                                 23            $sql = "INSERT INTO $self->{tmp_tbl} VALUES (42)";
94             1                                  3            MKDEBUG && _d($sql);
95             1                                357            $dbh->do($sql);
96                                                          };
97    ***      1     50                          18         die "Failed to create temporary table $self->{tmp_tbl}: $EVAL_ERROR"
98                                                             if $EVAL_ERROR;
99                                                       }
100                                                   
101   ***      6     50                          47      if ( $self->{tmp_tbl} ) {
102            6                                 43         $sql = "SELECT * FROM $self->{tmp_tbl}";
103            6                                 18         MKDEBUG && _d($sql);
104            6                                 26         eval {
105            6                               1610            $dbh->do($sql);
106                                                         };
107   ***      6     50                         100         die "Failed to select from temporary table $self->{tmp_tbl}: $EVAL_ERROR"
108                                                            if $EVAL_ERROR;
109                                                      }
110                                                   
111            6                                124      return $event;
112                                                   }
113                                                   
114                                                   # Required args:
115                                                   #   * event  hashref: an event
116                                                   #   * dbh    scalar: active dbh
117                                                   # Returns: hashref
118                                                   # Can die: yes
119                                                   # execute() executes the event's query if is hasn't already been executed. 
120                                                   # Any prep work should have been done in before_execute().  Adds Query_time
121                                                   # attrib to the event.
122                                                   sub execute {
123            4                    4            89      my ( $self, %args ) = @_;
124            4                                 31      my @required_args = qw(event dbh);
125            4                                 24      foreach my $arg ( @required_args ) {
126   ***      8     50                          66         die "I need a $arg argument" unless $args{$arg};
127                                                      }
128            4                                 31      my ($event, $dbh) = @args{@required_args};
129                                                   
130            4    100                          31      if ( exists $event->{Query_time} ) {
131            1                                  4         MKDEBUG && _d('Query already executed');
132            1                                 12         return $event;
133                                                      }
134                                                   
135            3                                 11      MKDEBUG && _d('Executing query');
136            3                                 17      my $query = $event->{arg};
137            3                                 14      my ( $start, $end, $query_time );
138                                                   
139            3                                 19      $event->{Query_time} = 0;
140            3                                 11      eval {
141            3                                 15         $start = time();
142            3                                808         $dbh->do($query);
143            3                                 20         $end   = time();
144            3                                 82         $query_time = sprintf '%.6f', $end - $start;
145                                                      };
146   ***      3     50                          25      die "Failed to execute query: $EVAL_ERROR" if $EVAL_ERROR;
147                                                   
148            3                                 21      $event->{Query_time} = $query_time;
149                                                   
150            3                                 48      return $event;
151                                                   }
152                                                   
153                                                   # Required args:
154                                                   #   * event  hashref: an event
155                                                   #   * dbh    scalar: active dbh
156                                                   # Returns: hashref
157                                                   # Can die: yes
158                                                   # after_execute() gets any warnings from SHOW WARNINGS.
159                                                   sub after_execute {
160            4                    4            94      my ( $self, %args ) = @_;
161            4                                 30      my @required_args = qw(event dbh);
162            4                                 25      foreach my $arg ( @required_args ) {
163   ***      8     50                          69         die "I need a $arg argument" unless $args{$arg};
164                                                      }
165            4                                 30      my ($event, $dbh) = @args{@required_args};
166                                                   
167            4                                 13      my $warnings;
168            4                                 16      my $warning_count;
169            4                                 17      eval {
170            4                                 16         $warnings      = $dbh->selectall_hashref('SHOW WARNINGS', 'Code');
171            4                                 12         $warning_count = $dbh->selectcol_arrayref('SELECT @@warning_count')->[0];
172                                                      };
173   ***      4     50                          75      die "Failed to SHOW WARNINGS: $EVAL_ERROR"
174                                                         if $EVAL_ERROR;
175                                                   
176            4           100                   63      $event->{warning_count} = $warning_count || 0;
177            4                                 27      $event->{warnings}      = $warnings;
178                                                   
179            4                                 57      return $event;
180                                                   }
181                                                   
182                                                   # Required args:
183                                                   #   * events  arrayref: events
184                                                   # Returns: array
185                                                   # Can die: yes
186                                                   # compare() compares events that have been run through before_execute(),
187                                                   # execute() and after_execute().  Only a "summary" of differences is
188                                                   # returned.  Specific differences are saved internally and are reported
189                                                   # by calling report() later.
190                                                   sub compare {
191            4                    4            47      my ( $self, %args ) = @_;
192            4                                 28      my @required_args = qw(events);
193            4                                 26      foreach my $arg ( @required_args ) {
194   ***      4     50                          41         die "I need a $arg argument" unless $args{$arg};
195                                                      }
196            4                                 26      my ($events) = @args{@required_args};
197                                                   
198            4                                 19      my $different_warning_counts = 0;
199            4                                 16      my $different_warnings       = 0;
200            4                                 16      my $different_warning_levels = 0;
201                                                   
202            4                                 23      my $event0   = $events->[0];
203   ***      4            33                   36      my $item     = $event0->{fingerprint} || $event0->{arg};
204   ***      4            50                   33      my $sampleno = $event0->{sampleno} || 0;
205            4                                 21      my $w0       = $event0->{warnings};
206                                                   
207            4                                 21      my $n_events = scalar @$events;
208            4                                 31      foreach my $i ( 1..($n_events-1) ) {
209            4                                 23         my $event = $events->[$i];
210                                                   
211            4    100    100                   84         if ( ($event0->{warning_count} || 0) != ($event->{warning_count} || 0) ) {
                           100                        
212            2                                  8            $different_warning_counts++;
213            2           100                   57            $self->{diffs}->{warning_counts}->{$item}->{$sampleno}
                           100                        
214                                                               = [ $event0->{warning_count} || 0, $event->{warning_count} || 0 ];
215            2                                 23            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
216                                                         }
217                                                   
218                                                         # Check the warnings on event0 against this event.
219            4                                 24         my $w = $event->{warnings};
220                                                   
221                                                         # Neither event had warnings.
222   ***      4     50     66                   55         next if !$w0 && !$w;
223                                                   
224            4                                 16         my %new_warnings;
225            4                                 32         foreach my $code ( keys %$w0 ) {
226            3    100                          23            if ( exists $w->{$code} ) {
227            2    100                          27               if ( $w->{$code}->{Level} ne $w0->{$code}->{Level} ) {
228                                                                  # Save differences.
229            1                                  4                  $different_warning_levels++;
230            1                                 29                  $self->{diffs}->{levels}->{$item}->{$sampleno}
231                                                                     = [ $code, $w0->{$code}->{Level}, $w->{$code}->{Level},
232                                                                         $w->{$code}->{Message} ];
233            1                                 28                  $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
234                                                               }
235            2                                 20               delete $w->{$code};
236                                                            }
237                                                            else {
238                                                               # This warning code is on event0 but not on this event.
239                                                   
240                                                               # Save differences.
241            1                                  5               $different_warnings++;
242            1                                 16               $self->{diffs}->{warnings}->{$item}->{$sampleno}
243                                                                  = [ 0, $code, $w0->{$code}->{Message} ];
244            1                                 13               $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
245                                                            }
246                                                         }
247                                                   
248                                                         # Any warning codes on this event not deleted above are new;
249                                                         # i.e. they weren't on event0.
250            4                                 39         foreach my $code ( keys %$w ) {
251                                                            # Save differences.
252            1                                  4            $different_warnings++;
253            1                                 15            $self->{diffs}->{warnings}->{$item}->{$sampleno}
254                                                               = [ $i, $code, $w->{$code}->{Message} ];
255            1                                 13            $self->{samples}->{$item}->{$sampleno} = $event0->{arg};
256                                                         }
257                                                   
258                                                         # EventAggregator won't know what do with this hashref so delete it.
259            4                                 42         delete $event->{warnings};
260                                                      }
261            4                                 22      delete $event0->{warnings};
262                                                   
263                                                      return (
264            4                                117         different_warning_counts => $different_warning_counts,
265                                                         different_warnings       => $different_warnings,
266                                                         different_warning_levels => $different_warning_levels,
267                                                      );
268                                                   }
269                                                   
270                                                   sub report {
271            3                    3            31      my ( $self, %args ) = @_;
272            3                                 22      my @required_args = qw(hosts);
273            3                                 21      foreach my $arg ( @required_args ) {
274   ***      3     50                          30         die "I need a $arg argument" unless $args{$arg};
275                                                      }
276            3                                 21      my ($hosts) = @args{@required_args};
277                                                   
278   ***      3     50                          12      return unless keys %{$self->{diffs}};
               3                                 55   
279                                                   
280                                                      # These columns are common to all the reports; make them just once.
281            3                                 29      my $query_id_col = {
282                                                         name        => 'Query ID',
283                                                         fixed_width => 18,
284                                                      };
285            6                                 57      my @host_cols = map {
286            3                                 19         my $col = { name => $_->{name} };
287            6                                 37         $col;
288                                                      } @$hosts;
289                                                   
290            3                                 13      my @reports;
291            3                                 19      foreach my $diff ( qw(warnings levels warning_counts) ) {
292            9                                 63         my $report = "_report_diff_$diff";
293            9                                128         push @reports, $self->$report(
294                                                            query_id_col => $query_id_col,
295                                                            host_cols    => \@host_cols,
296                                                            %args
297                                                         );
298                                                      }
299                                                   
300            3                                 75      return join("\n", @reports);
301                                                   }
302                                                   
303                                                   sub _report_diff_warnings {
304            3                    3            41      my ( $self, %args ) = @_;
305            3                                 25      my @required_args = qw(query_id_col hosts);
306            3                                 20      foreach my $arg ( @required_args ) {
307   ***      6     50                          52         die "I need a $arg argument" unless $args{$arg};
308                                                      }
309                                                   
310            3                                 20      my $get_id = $self->{get_id};
311                                                   
312            3    100                          10      return unless keys %{$self->{diffs}->{warnings}};
               3                                 41   
313                                                   
314            2                                 22      my $report = new ReportFormatter(long_last_column => 1);
315            2                                 16      $report->set_title('New warnings');
316            2                                 48      $report->set_columns(
317                                                         $args{query_id_col},
318                                                         { name => 'Host', },
319                                                         { name => 'Code', right_justify => 1 },
320                                                         { name => 'Message' },
321                                                      );
322                                                   
323            2                                 14      my $diff_warnings = $self->{diffs}->{warnings};
324            2                                 22      foreach my $item ( sort keys %$diff_warnings ) {
325            2                                 21         map {
326            2                                  8            my ($hostno, $code, $message) = @{$diff_warnings->{$item}->{$_}};
      ***      0                                  0   
327            2                                 17            $report->add_line(
328                                                               $get_id->($item) . '-' . $_,
329                                                               $args{hosts}->[$hostno]->{name}, $code, $message,
330                                                            );
331            2                                  8         } sort { $a <=> $b } keys %{$diff_warnings->{$item}};
               2                                 20   
332                                                      }
333                                                   
334            2                                 17      return $report->get_report();
335                                                   }
336                                                   
337                                                   sub _report_diff_levels {
338            3                    3            33      my ( $self, %args ) = @_;
339            3                                 24      my @required_args = qw(query_id_col hosts);
340            3                                 19      foreach my $arg ( @required_args ) {
341   ***      6     50                          51         die "I need a $arg argument" unless $args{$arg};
342                                                      }
343                                                   
344            3                                 19      my $get_id = $self->{get_id};
345                                                   
346            3    100                          12      return unless keys %{$self->{diffs}->{levels}};
               3                                 43   
347                                                   
348            1                                 26      my $report = new ReportFormatter(long_last_column => 1);
349            1                                  8      $report->set_title('Warning level differences');
350            3                                 27      $report->set_columns(
351                                                         $args{query_id_col},
352                                                         { name => 'Code', right_justify => 1 },
353                                                         map {
354            1                                 18            my $col = { name => $_->{name}, right_justify => 1  };
355            3                                 27            $col;
356            1                                 10         } @{$args{hosts}},
357                                                         { name => 'Message' },
358                                                      );
359                                                   
360            1                                  9      my $diff_levels = $self->{diffs}->{levels};
361            1                                 11      foreach my $item ( sort keys %$diff_levels ) {
362            1                                 16         map {
363   ***      0                                  0            $report->add_line(
364                                                               $get_id->($item) . '-' . $_,
365            1                                  7               @{$diff_levels->{$item}->{$_}},
366                                                            );
367            1                                  4         } sort { $a <=> $b } keys %{$diff_levels->{$item}};
               1                                 10   
368                                                      }
369                                                   
370            1                                 28      return $report->get_report();
371                                                   }
372                                                   
373                                                   sub _report_diff_warning_counts {
374            3                    3            30      my ( $self, %args ) = @_;
375            3                                 24      my @required_args = qw(query_id_col hosts);
376            3                                 20      foreach my $arg ( @required_args ) {
377   ***      6     50                          51         die "I need a $arg argument" unless $args{$arg};
378                                                      }
379                                                   
380            3                                 19      my $get_id = $self->{get_id};
381                                                   
382            3    100                          12      return unless keys %{$self->{diffs}->{warning_counts}};
               3                                 41   
383                                                   
384            2                                 16      my $report = new ReportFormatter();
385            2                                 16      $report->set_title('Warning count differences');
386            4                                 36      $report->set_columns(
387                                                         $args{query_id_col},
388                                                         map {
389            2                                 13            my $col = { name => $_->{name}, right_justify => 1  };
390            4                                 24            $col;
391            2                                 20         } @{$args{hosts}},
392                                                      );
393                                                   
394            2                                 15      my $diff_warning_counts = $self->{diffs}->{warning_counts};
395            2                                 20      foreach my $item ( sort keys %$diff_warning_counts ) {
396            2                                 20         map {
397   ***      0                                  0            $report->add_line(
398                                                               $get_id->($item) . '-' . $_,
399            2                                 15               @{$diff_warning_counts->{$item}->{$_}},
400                                                            );
401            2                                  8         } sort { $a <=> $b } keys %{$diff_warning_counts->{$item}};
               2                                 19   
402                                                      }
403                                                   
404            2                                 14      return $report->get_report();
405                                                   }
406                                                   
407                                                   sub samples {
408            1                    1             8      my ( $self, $item ) = @_;
409   ***      1     50                           9      return unless $item;
410            1                                  4      my @samples;
411            1                                  5      foreach my $sampleno ( keys %{$self->{samples}->{$item}} ) {
               1                                 14   
412            1                                 13         push @samples, $sampleno, $self->{samples}->{$item}->{$sampleno};
413                                                      }
414            1                                 17      return @samples;
415                                                   }
416                                                   
417                                                   sub reset {
418            1                    1             8      my ( $self ) = @_;
419            1                                  9      $self->{diffs}   = {};
420            1                                 15      $self->{samples} = {};
421            1                                  7      return;
422                                                   }
423                                                   
424                                                   sub _d {
425            1                    1            51      my ($package, undef, $line) = caller 0;
426   ***      2     50                          29      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 15   
               2                                 18   
427            1                                  9           map { defined $_ ? $_ : 'undef' }
428                                                           @_;
429            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
430                                                   }
431                                                   
432                                                   1;
433                                                   
434                                                   # ###########################################################################
435                                                   # End CompareWarnings package
436                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
41    ***     50      0      4   unless $args{$arg}
67    ***     50      0     14   unless $args{$arg}
72    ***     50      0      7   unless $$self{'clear'}
74           100      2      5   if (not $$self{'tmp_tbl'})
78    ***     50      0      2   if $args{'temp-database'}
79           100      1      1   unless $db
86    ***     50      1      0   $vp->version_ge($dbh, '5.0.0') ? :
97    ***     50      0      1   if $EVAL_ERROR
101   ***     50      6      0   if ($$self{'tmp_tbl'})
107   ***     50      0      6   if $EVAL_ERROR
126   ***     50      0      8   unless $args{$arg}
130          100      1      3   if (exists $$event{'Query_time'})
146   ***     50      0      3   if $EVAL_ERROR
163   ***     50      0      8   unless $args{$arg}
173   ***     50      0      4   if $EVAL_ERROR
194   ***     50      0      4   unless $args{$arg}
211          100      2      2   if (($$event0{'warning_count'} || 0) != ($$event{'warning_count'} || 0))
222   ***     50      0      4   if not $w0 and not $w
226          100      2      1   if (exists $$w{$code}) { }
227          100      1      1   if ($$w{$code}{'Level'} ne $$w0{$code}{'Level'})
274   ***     50      0      3   unless $args{$arg}
278   ***     50      0      3   unless keys %{$$self{'diffs'};}
307   ***     50      0      6   unless $args{$arg}
312          100      1      2   unless keys %{$$self{'diffs'}{'warnings'};}
341   ***     50      0      6   unless $args{$arg}
346          100      2      1   unless keys %{$$self{'diffs'}{'levels'};}
377   ***     50      0      6   unless $args{$arg}
382          100      1      2   unless keys %{$$self{'diffs'}{'warning_counts'};}
409   ***     50      0      1   unless $item
426   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
222   ***     66      3      1      0   not $w0 and not $w

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
176          100      2      2   $warning_count || 0
204   ***     50      4      0   $$event0{'sampleno'} || 0
211          100      3      1   $$event0{'warning_count'} || 0
             100      3      1   $$event{'warning_count'} || 0
213          100      1      1   $$event0{'warning_count'} || 0
             100      1      1   $$event{'warning_count'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
203   ***     33      4      0      0   $$event0{'fingerprint'} || $$event0{'arg'}


Covered Subroutines
-------------------

Subroutine                  Count Location                                              
--------------------------- ----- ------------------------------------------------------
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:22 
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:23 
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:24 
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:26 
BEGIN                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:28 
_d                              1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:425
_report_diff_levels             3 /home/daniel/dev/maatkit/common/CompareWarnings.pm:338
_report_diff_warning_counts     3 /home/daniel/dev/maatkit/common/CompareWarnings.pm:374
_report_diff_warnings           3 /home/daniel/dev/maatkit/common/CompareWarnings.pm:304
after_execute                   4 /home/daniel/dev/maatkit/common/CompareWarnings.pm:160
before_execute                  7 /home/daniel/dev/maatkit/common/CompareWarnings.pm:64 
compare                         4 /home/daniel/dev/maatkit/common/CompareWarnings.pm:191
execute                         4 /home/daniel/dev/maatkit/common/CompareWarnings.pm:123
new                             1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:38 
report                          3 /home/daniel/dev/maatkit/common/CompareWarnings.pm:271
reset                           1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:418
samples                         1 /home/daniel/dev/maatkit/common/CompareWarnings.pm:408


