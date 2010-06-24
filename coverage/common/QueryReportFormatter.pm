---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...n/QueryReportFormatter.pm   94.2   69.0   59.1  100.0    0.0   19.9   81.0
QueryReportFormatter.t         98.1   50.0   40.0  100.0    n/a   80.1   95.5
Total                          95.7   68.0   58.3  100.0    0.0  100.0   85.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:01 2010
Finish:       Thu Jun 24 19:36:01 2010

Run:          QueryReportFormatter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:03 2010
Finish:       Thu Jun 24 19:36:05 2010

/home/daniel/dev/maatkit/common/QueryReportFormatter.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2010 Percona Inc.
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
17                                                    
18                                                    # ###########################################################################
19                                                    # QueryReportFormatter package $Revision: 6361 $
20                                                    # ###########################################################################
21                                                    package QueryReportFormatter;
22                                                    
23                                                    # This package is used primarily by mk-query-digest to print its reports.
24                                                    # The main sub is print_reports() which prints the various reports fo
25                                                    # mk-query-digest --report-format.  Each report is produced in a sub of
26                                                    # the same name; e.g. --report-format=query_report == sub query_report().
27                                                    # The given ea (EventAggregator object) is expected to be "complete"; i.e.
28                                                    # fully aggregated and $ea->calculate_statistical_metrics() already called.
29                                                    # Subreports "profile" and "prepared" require the ReportFormatter module,
30                                                    # which is also in mk-query-digest.
31                                                    
32             1                    1             5   use strict;
               1                                  2   
               1                                  5   
33             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
34             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
35                                                    
36                                                    Transformers->import(qw(
37                                                       shorten micro_t parse_timestamp unix_timestamp make_checksum percentage_of
38                                                    ));
39                                                    
40    ***      1            50      1             6   use constant MKDEBUG           => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 19   
41             1                    1             6   use constant LINE_LENGTH       => 74;
               1                                  2   
               1                                  4   
42             1                    1             5   use constant MAX_STRING_LENGTH => 10;
               1                                  2   
               1                                  4   
43                                                    
44                                                    # Special formatting functions
45                                                    my %formatting_function = (
46                                                       ts => sub {
47                                                          my ( $vals ) = @_;
48                                                          my $min = parse_timestamp($vals->{min} || '');
49                                                          my $max = parse_timestamp($vals->{max} || '');
50                                                          return $min && $max ? "$min to $max" : '';
51                                                       },
52                                                    );
53                                                    
54                                                    # Arguments:
55                                                    #   * OptionParser
56                                                    #   * QueryRewriter
57                                                    #   * Quoter
58                                                    # Optional arguments:
59                                                    #   * QueryReview    Used in query_report()
60                                                    #   * dbh            Used in explain_report()
61                                                    sub new {
62    ***      2                    2      0     40      my ( $class, %args ) = @_;
63             2                                 19      foreach my $arg ( qw(OptionParser QueryRewriter Quoter) ) {
64    ***      6     50                          44         die "I need a $arg argument" unless $args{$arg};
65                                                       }
66                                                    
67                                                       # If ever someone wishes for a wider label width.
68    ***      2            50                   31      my $label_width = $args{label_width} || 9;
69             2                                  7      MKDEBUG && _d('Label width:', $label_width);
70                                                    
71             2                                 48      my $self = {
72                                                          %args,
73                                                          bool_format => '# %3s%% %-6s %s',
74                                                          label_width => $label_width,
75                                                          dont_print  => {         # don't print these attribs in these reports
76                                                             header => {
77                                                                user        => 1,
78                                                                db          => 1,
79                                                                pos_in_log  => 1,
80                                                                fingerprint => 1,
81                                                             },
82                                                             query_report => {
83                                                                pos_in_log  => 1,
84                                                                fingerprint => 1,
85                                                             }
86                                                          },
87                                                       };
88             2                                 32      return bless $self, $class;
89                                                    }
90                                                    
91                                                    # Arguments:
92                                                    #   * reports       arrayref: reports to print
93                                                    #   * ea            obj: EventAggregator
94                                                    #   * worst         arrayref: worst items
95                                                    #   * orderby       scalar: attrib worst items ordered by
96                                                    #   * groupby       scalar: attrib worst items grouped by
97                                                    # Optional arguments:
98                                                    #   * files         arrayref: files read for input
99                                                    #   * group         hashref: don't add blank line between these reports
100                                                   #                            if they appear together
101                                                   # Prints the given reports (rusage, heade (global), query_report, etc.) in
102                                                   # the given order.  These usually come from mk-query-digest --report-format.
103                                                   # Most of the required args are for header() and query_report().
104                                                   sub print_reports {
105   ***      4                    4      0     67      my ( $self, %args ) = @_;
106            4                                 37      foreach my $arg ( qw(reports ea worst orderby groupby) ) {
107   ***     20     50                         108         die "I need a $arg argument" unless exists $args{$arg};
108                                                      }
109            4                                 18      my $reports = $args{reports};
110            4                                 14      my $group   = $args{group};
111            4                                 13      my $last_report;
112                                                   
113            4                                 18      foreach my $report ( @$reports ) {
114           14                                 40         MKDEBUG && _d('Printing', $report, 'report'); 
115           14                                193         my $report_output = $self->$report(%args);
116   ***     14     50                       14384         if ( $report_output ) {
117           14    100    100                  340            print "\n"
                           100                        
118                                                               if !$last_report || !($group->{$last_report} && $group->{$report});
119           14                                 91            print $report_output;
120                                                         }
121                                                         else {
122   ***      0                                  0            MKDEBUG && _d('No', $report, 'report');
123                                                         }
124           14                                 85         $last_report = $report;
125                                                      }
126                                                   
127            4                                 48      return;
128                                                   }
129                                                   
130                                                   sub rusage {
131   ***      2                    2      0     17      my ( $self ) = @_;
132            2                                 13      my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
133            2                                  9      my $rusage = '';
134            2                                  8      eval {
135            2                              29589         my $mem = `ps -o rss,vsz -p $PID 2>&1`;
136            2                                113         ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
137            2                                 41         ( $user, $system ) = times();
138   ***      2            50                   66         $rusage = sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
      ***                   50                        
139                                                            micro_t( $user,   p_s => 1, p_ms => 1 ),
140                                                            micro_t( $system, p_s => 1, p_ms => 1 ),
141                                                            shorten( ($rss || 0) * 1_024 ),
142                                                            shorten( ($vsz || 0) * 1_024 );
143                                                      };
144   ***      2     50                          14      if ( $EVAL_ERROR ) {
145   ***      0                                  0         MKDEBUG && _d($EVAL_ERROR);
146                                                      }
147   ***      2     50                          38      return $rusage ? $rusage : "# Could not get rusage\n";
148                                                   }
149                                                   
150                                                   sub date {
151   ***      2                    2      0     33      my ( $self ) = @_;
152            2                                147      return "# Current date: " . (scalar localtime) . "\n";
153                                                   }
154                                                   
155                                                   sub files {
156   ***      2                    2      0     40      my ( $self, %args ) = @_;
157   ***      2     50                          21      if ( $args{files} ) {
158            2                                 11         return "# Files: " . join(', ', @{$args{files}}) . "\n";
               2                                 37   
159                                                      }
160   ***      0                                  0      return;
161                                                   }
162                                                   
163                                                   # Arguments:
164                                                   #   * ea         obj: EventAggregator
165                                                   #   * orderby    scalar: attrib items ordered by
166                                                   # Optional arguments:
167                                                   #   * select     arrayref: attribs to print, mostly for testing; see dont_print
168                                                   #   * zero_bool  bool: print zero bool values (0%)
169                                                   # Print a report about the global statistics in the EventAggregator.
170                                                   # Formerly called "global_report()."
171                                                   sub header {
172   ***      8                    8      0     90      my ( $self, %args ) = @_;
173            8                                 72      foreach my $arg ( qw(ea orderby) ) {
174   ***     16     50                          97         die "I need a $arg argument" unless $args{$arg};
175                                                      }
176            8                                 36      my $ea      = $args{ea};
177            8                                642      my $orderby = $args{orderby};
178                                                   
179            8                                 43      my $dont_print = $self->{dont_print}->{header};
180            8                                 59      my $results    = $ea->results();
181            8                                216      my @result;
182                                                   
183                                                      # Get global count
184   ***      8            50                   66      my $global_cnt = $results->{globals}->{$orderby}->{cnt} || 0;
185                                                   
186                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
187            8                                 31      my ($qps, $conc) = (0, 0);
188   ***      8    100     66                  207      if ( $global_cnt && $results->{globals}->{ts}
      ***                   50                        
      ***                   50                        
                           100                        
189                                                         && ($results->{globals}->{ts}->{max} || '')
190                                                            gt ($results->{globals}->{ts}->{min} || '')
191                                                      ) {
192            3                                 11         eval {
193            3                                 26            my $min  = parse_timestamp($results->{globals}->{ts}->{min});
194            3                                215            my $max  = parse_timestamp($results->{globals}->{ts}->{max});
195            3                                111            my $diff = unix_timestamp($max) - unix_timestamp($min);
196   ***      3            50                  556            $qps     = $global_cnt / ($diff || 1);
197            3                                 19            $conc    = $results->{globals}->{$args{orderby}}->{sum} / $diff;
198                                                         };
199                                                      }
200                                                   
201                                                      # First line
202                                                      MKDEBUG && _d('global_cnt:', $global_cnt, 'unique:',
203            8                                 23         scalar keys %{$results->{classes}}, 'qps:', $qps, 'conc:', $conc);
204            8                                459      my $line = sprintf(
205                                                         '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
206                                                         shorten($global_cnt, d=>1_000),
207            8           100                   58         shorten(scalar keys %{$results->{classes}}, d=>1_000),
                           100                        
208                                                         shorten($qps  || 0, d=>1_000),
209                                                         shorten($conc || 0, d=>1_000));
210            8                                 65      $line .= ('_' x (LINE_LENGTH - length($line) + $self->{label_width} - 9));
211            8                                 37      push @result, $line;
212                                                   
213                                                      # Column header line
214            8                                 60      my ($format, @headers) = $self->make_header('global');
215            8                                 66      push @result, sprintf($format, '', @headers);
216                                                   
217                                                      # Each additional line
218            8    100                          77      my $attribs = $args{select} ? $args{select} : $ea->get_attributes();
219            8                                123      foreach my $attrib ( $self->sorted_attribs($attribs, $ea) ) {
220           45    100                         223         next if $dont_print->{$attrib};
221           38                                182         my $attrib_type = $ea->type_for($attrib);
222           38    100                         626         next unless $attrib_type; 
223   ***     35     50                         171         next unless exists $results->{globals}->{$attrib};
224           35    100                         139         if ( $formatting_function{$attrib} ) { # Handle special cases
225           70                                249            push @result, sprintf $format, $self->make_label($attrib),
226                                                               $formatting_function{$attrib}->($results->{globals}->{$attrib}),
227            7                                 37               (map { '' } 0..9); # just for good measure
228                                                         }
229                                                         else {
230           28                                141            my $store = $results->{globals}->{$attrib};
231           28                                 71            my @values;
232           28    100                         141            if ( $attrib_type eq 'num' ) {
                    100                               
      ***            50                               
233           18    100                         172               my $func    = $attrib =~ m/time|wait$/ ? \&micro_t : \&shorten;
234           18                                 92               my $metrics = $ea->stats()->{globals}->{$attrib};
235           18                                147               @values = (
236           18                                133                  @{$store}{qw(sum min max)},
237                                                                  $store->{sum} / $store->{cnt},
238           18                                378                  @{$metrics}{qw(pct_95 stddev median)},
239                                                               );
240   ***     18     50                          80               @values = map { defined $_ ? $func->($_) : '' } @values;
             126                               5855   
241                                                            }
242                                                            elsif ( $attrib_type eq 'string' ) {
243            6                                 15               MKDEBUG && _d('Ignoring string attrib', $attrib);
244            6                                 24               next;
245                                                            }
246                                                            elsif ( $attrib_type eq 'bool' ) {
247   ***      4    100     66                   33               if ( $store->{sum} > 0 || $args{zero_bool} ) {
248            3                                 18                  push @result,
249                                                                     sprintf $self->{bool_format},
250                                                                        $self->format_bool_attrib($store), $attrib;
251                                                               }
252                                                            }
253                                                            else {
254   ***      0                                  0               @values = ('', $store->{min}, $store->{max}, '', '', '', '');
255                                                            }
256                                                   
257           22    100                        1133            push @result, sprintf $format, $self->make_label($attrib), @values
258                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
259                                                         }
260                                                      }
261                                                   
262            8                                 43      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              44                                256   
              44                                216   
263                                                   }
264                                                   
265                                                   # Arguments:
266                                                   #   * ea       obj: EventAggregator
267                                                   #   * worst    arrayref: worst items
268                                                   #   * orderby  scalar: attrib worst items ordered by
269                                                   #   * groupby  scalar: attrib worst items grouped by
270                                                   # Optional arguments:
271                                                   #   * select       arrayref: attribs to print, mostly for test; see dont_print
272                                                   #   * explain_why  bool: print reason why item is reported
273                                                   #   * print_header  bool: "Report grouped by" header
274                                                   sub query_report {
275   ***      4                    4      0     42      my ( $self, %args ) = @_;
276            4                                 34      foreach my $arg ( qw(ea worst orderby groupby) ) {
277   ***     16     50                          80         die "I need a $arg argument" unless defined $arg;
278                                                      }
279            4                                 18      my $ea      = $args{ea};
280            4                                 19      my $groupby = $args{groupby};
281            4                                 16      my $worst   = $args{worst};
282            4                                 23      my $n_worst = scalar @$worst;
283                                                   
284            4                                 24      my $o   = $self->{OptionParser};
285            4                                 27      my $q   = $self->{Quoter};
286            4                                 17      my $qv  = $self->{QueryReview};
287            4                                 33      my $qr  = $self->{QueryRewriter};
288                                                   
289            4                                 20      my $report = '';
290                                                   
291   ***      4     50                          26      if ( $args{print_header} ) {
292   ***      0                                  0         $report .= "# " . ( '#' x 72 ) . "\n"
293                                                                  . "# Report grouped by $groupby\n"
294                                                                  . '# ' . ( '#' x 72 ) . "\n\n";
295                                                      }
296                                                   
297                                                      # Print each worst item: its stats/metrics (sum/min/max/95%/etc.),
298                                                      # Query_time distro chart, tables, EXPLAIN, fingerprint, etc.
299                                                      # Items are usually unique queries/fingerprints--depends on how
300                                                      # the events were grouped.
301                                                      ITEM:
302            4                                 20      foreach my $rank ( 1..$n_worst ) {
303            5                                 42         my $item       = $worst->[$rank - 1]->[0];
304            5                                 33         my $stats      = $ea->results->{classes}->{$item};
305            5                                147         my $sample     = $ea->results->{samples}->{$item};
306   ***      5            50                  138         my $samp_query = $sample->{arg} || '';
307   ***      5     50                          33         my $reason     = $args{explain_why} ? $worst->[$rank - 1]->[1] : '';
308                                                   
309                                                         # ###############################################################
310                                                         # Possibly skip item for --review.
311                                                         # ###############################################################
312            5                                 22         my $review_vals;
313   ***      5     50                          30         if ( $qv ) {
314   ***      0                                  0            $review_vals = $qv->get_review_info($item);
315   ***      0      0      0                    0            next ITEM if $review_vals->{reviewed_by} && !$o->get('report-all');
316                                                         }
317                                                   
318                                                         # ###############################################################
319                                                         # Get tables for --for-explain.
320                                                         # ###############################################################
321   ***      0                                  0         my ($default_db) = $sample->{db}       ? $sample->{db}
322   ***      5     50                          48                          : $stats->{db}->{unq} ? keys %{$stats->{db}->{unq}}
                    100                               
323                                                                          :                       undef;
324            5                                 16         my @tables;
325   ***      5     50                          68         if ( $o->get('for-explain') ) {
326            5                                261            @tables = $self->{QueryParser}->extract_tables(
327                                                               query      => $samp_query,
328                                                               default_db => $default_db,
329                                                               Quoter     => $self->{Quoter},
330                                                            );
331                                                         }
332                                                   
333                                                         # ###############################################################
334                                                         # Print the standard query analysis report.
335                                                         # ###############################################################
336            5    100                        1295         $report .= "\n" if $rank > 1;  # space between each event report
337            5                                 50         $report .= $self->event_report(
338                                                            %args,
339                                                            item  => $item,
340                                                            rank   => $rank,
341                                                            reason => $reason,
342                                                         );
343                                                   
344   ***      5     50                          45         if ( $o->get('report-histogram') ) {
345            5                                197            $report .= $self->chart_distro(
346                                                               %args,
347                                                               attrib => $o->get('report-histogram'),
348                                                               item   => $item,
349                                                            );
350                                                         }
351                                                   
352   ***      5     50     33                   47         if ( $qv && $review_vals ) {
353                                                            # Print the review information that is already in the table
354                                                            # before putting anything new into the table.
355   ***      0                                  0            $report .= "# Review information\n";
356   ***      0                                  0            foreach my $col ( $qv->review_cols() ) {
357   ***      0                                  0               my $val = $review_vals->{$col};
358   ***      0      0      0                    0               if ( !$val || $val ne '0000-00-00 00:00:00' ) { # issue 202
359   ***      0      0                           0                  $report .= sprintf "# %13s: %-s\n", $col, ($val ? $val : '');
360                                                               }
361                                                            }
362                                                         }
363                                                   
364   ***      5     50                          28         if ( $groupby eq 'fingerprint' ) {
365                                                            # Shorten it if necessary (issue 216 and 292).           
366   ***      5     50                          39            $samp_query = $qr->shorten($samp_query, $o->get('shorten'))
367                                                               if $o->get('shorten');
368                                                   
369                                                            # Print query fingerprint.
370   ***      5     50                         159            $report .= "# Fingerprint\n#    $item\n"
371                                                               if $o->get('fingerprints');
372                                                   
373                                                            # Print tables used by query.
374   ***      5     50                         163            $report .= $self->tables_report(@tables)
375                                                               if $o->get('for-explain');
376                                                   
377            5    100                          60            if ( $item =~ m/^(?:[\(\s]*select|insert|replace)/ ) {
378   ***      3     50                          19               if ( $item =~ m/^(?:insert|replace)/ ) { # No EXPLAIN
379   ***      0                                  0                  $report .= "$samp_query\\G\n";
380                                                               }
381                                                               else {
382            3                                 15                  $report .= "# EXPLAIN\n$samp_query\\G\n"; 
383            3                                 25                  $report .= $self->explain_report($samp_query, $default_db);
384                                                               }
385                                                            }
386                                                            else {
387            2                                 10               $report .= "$samp_query\\G\n"; 
388            2                                 16               my $converted = $qr->convert_to_select($samp_query);
389   ***      2     50     33                  107               if ( $o->get('for-explain')
      ***                   33                        
390                                                                    && $converted
391                                                                    && $converted =~ m/^[\(\s]*select/i ) {
392                                                                  # It converted OK to a SELECT
393            2                                 86                  $report .= "# Converted for EXPLAIN\n# EXPLAIN\n$converted\\G\n";
394                                                               }
395                                                            }
396                                                         }
397                                                         else {
398   ***      0      0                           0            if ( $groupby eq 'tables' ) {
399   ***      0                                  0               my ( $db, $tbl ) = $q->split_unquote($item);
400   ***      0                                  0               $report .= $self->tables_report([$db, $tbl]);
401                                                            }
402   ***      0                                  0            $report .= "$item\n";
403                                                         }
404                                                      }
405                                                   
406            4                                 41      return $report;
407                                                   }
408                                                   
409                                                   # Arguments:
410                                                   #   * ea          obj: EventAggregator
411                                                   #   * item        scalar: Item in ea results
412                                                   #   * orderby     scalar: attribute that events are ordered by
413                                                   # Optional arguments:
414                                                   #   * select      arrayref: attribs to print, mostly for testing; see dont_print
415                                                   #   * reason      scalar: why this item is being reported (top|outlier)
416                                                   #   * rank        scalar: item rank among the worst
417                                                   #   * zero_bool   bool: print zero bool values (0%)
418                                                   # Print a report about the statistics in the EventAggregator.
419                                                   # Called by query_report().
420                                                   sub event_report {
421   ***     17                   17      0    185      my ( $self, %args ) = @_;
422           17                                113      foreach my $arg ( qw(ea item orderby) ) {
423   ***     51     50                         244         die "I need a $arg argument" unless $args{$arg};
424                                                      }
425           17                                 64      my $ea      = $args{ea};
426           17                                 64      my $item    = $args{item};
427           17                                 61      my $orderby = $args{orderby};
428                                                   
429           17                                 80      my $dont_print = $self->{dont_print}->{query_report};
430           17                                 86      my $results    = $ea->results();
431           17                                356      my @result;
432                                                   
433                                                      # Return unless the item exists in the results (it should).
434           17                                 79      my $store = $results->{classes}->{$item};
435   ***     17     50                          75      return "# No such event $item\n" unless $store;
436                                                   
437                                                      # Pick the first attribute to get counts
438           17                                 86      my $global_cnt = $results->{globals}->{$orderby}->{cnt};
439           17                                 74      my $class_cnt  = $store->{$orderby}->{cnt};
440                                                   
441                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
442           17                                 58      my ($qps, $conc) = (0, 0);
443   ***     17    100     66                  345      if ( $global_cnt && $store->{ts}
                           100                        
                           100                        
                           100                        
444                                                         && ($store->{ts}->{max} || '')
445                                                            gt ($store->{ts}->{min} || '')
446                                                      ) {
447            3                                 10         eval {
448            3                                 18            my $min  = parse_timestamp($store->{ts}->{min});
449            3                                138            my $max  = parse_timestamp($store->{ts}->{max});
450            3                                108            my $diff = unix_timestamp($max) - unix_timestamp($min);
451            3                                546            $qps     = $class_cnt / $diff;
452            3                                 15            $conc    = $store->{$orderby}->{sum} / $diff;
453                                                         };
454                                                      }
455                                                   
456                                                      # First line like:
457                                                      # Query 1: 9 QPS, 0x concurrency, ID 0x7F7D57ACDD8A346E at byte 5 ________
458   ***     17    100     50                  282      my $line = sprintf(
                           100                        
                           100                        
                           100                        
459                                                         '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
460                                                         ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
461                                                         $args{rank} || 0,
462                                                         shorten($qps  || 0, d=>1_000),
463                                                         shorten($conc || 0, d=>1_000),
464                                                         make_checksum($item),
465                                                         $results->{samples}->{$item}->{pos_in_log} || 0,
466                                                      );
467           17                                114      $line .= ('_' x (LINE_LENGTH - length($line) + $self->{label_width} - 9));
468           17                                 68      push @result, $line;
469                                                   
470           17    100                          83      if ( $args{reason} ) {
471   ***      5     50                          29         push @result,
472                                                            "# This item is included in the report because it matches "
473                                                               . ($args{reason} eq 'top' ? '--limit.' : '--outliers.');
474                                                      }
475                                                   
476                                                      # Column header line
477           17                                 93      my ($format, @headers) = $self->make_header();
478           17                                129      push @result, sprintf($format, '', @headers);
479                                                   
480                                                      # Count line
481          153                                938      push @result, sprintf
482                                                         $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
483           17                                110            map { '' } (1 ..9);
484                                                   
485                                                      # Each additional line
486           17    100                         119      my $attribs = $args{select} ? $args{select} : $ea->get_attributes();
487           17                                179      foreach my $attrib ( $self->sorted_attribs($attribs, $ea) ) {
488          119    100                         539         next if $dont_print->{$attrib};
489          111                                484         my $attrib_type = $ea->type_for($attrib);
490          111    100                        1684         next unless $attrib_type; 
491   ***    104     50                         447         next unless exists $store->{$attrib};
492          104                                349         my $vals = $store->{$attrib};
493          104    100                         498         next unless scalar %$vals;
494           99    100                         388         if ( $formatting_function{$attrib} ) { # Handle special cases
495           80                                295            push @result, sprintf $format, $self->make_label($attrib),
496                                                               $formatting_function{$attrib}->($vals),
497            8                                 40               (map { '' } 0..9); # just for good measure
498                                                         }
499                                                         else {
500           91                                230            my @values;
501           91                                213            my $pct;
502           91    100                         368            if ( $attrib_type eq 'num' ) {
      ***            50                               
      ***             0                               
503           48    100                         352               my $func    = $attrib =~ m/time|wait$/ ? \&micro_t : \&shorten;
504           48                                223               my $metrics = $ea->stats()->{classes}->{$item}->{$attrib};
505           48                                324               @values = (
506           48                                331                  @{$vals}{qw(sum min max)},
507                                                                  $vals->{sum} / $vals->{cnt},
508           48                               1135                  @{$metrics}{qw(pct_95 stddev median)},
509                                                               );
510   ***     48     50                         183               @values = map { defined $_ ? $func->($_) : '' } @values;
             336                              14022   
511           48                               2570               $pct = percentage_of($vals->{sum},
512                                                                  $results->{globals}->{$attrib}->{sum});
513                                                            }
514                                                            elsif ( $attrib_type eq 'string' ) {
515          430                               1325               push @values,
516                                                                  $self->format_string_list($attrib, $vals, $class_cnt),
517           43                                212                  (map { '' } 0..9); # just for good measure
518           43                                147               $pct = '';
519                                                            }
520                                                            elsif ( $attrib_type eq 'bool' ) {
521   ***      0      0      0                    0               if ( $vals->{sum} > 0 || $args{zero_bool} ) {
522   ***      0                                  0                  push @result,
523                                                                     sprintf $self->{bool_format},
524                                                                        $self->format_bool_attrib($vals), $attrib;
525                                                               }
526                                                            }
527                                                            else {
528   ***      0                                  0               @values = ('', $vals->{min}, $vals->{max}, '', '', '', '');
529   ***      0                                  0               $pct = 0;
530                                                            }
531                                                   
532   ***     91     50                        1579            push @result, sprintf $format, $self->make_label($attrib), $pct, @values
533                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
534                                                         }
535                                                      }
536                                                   
537           17                                 83      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
             155                                757   
             155                                673   
538                                                   }
539                                                   
540                                                   # Arguments:
541                                                   #  * ea      obj: EventAggregator
542                                                   #  * item    scalar: item in ea results
543                                                   #  * attrib  scalar: item's attribute to chart
544                                                   # Creates a chart of value distributions in buckets.  Right now it bucketizes
545                                                   # into 8 buckets, powers of ten starting with .000001.
546                                                   sub chart_distro {
547   ***      7                    7      0    211      my ( $self, %args ) = @_;
548            7                                 52      foreach my $arg ( qw(ea item attrib) ) {
549   ***     21     50                         107         die "I need a $arg argument" unless $args{$arg};
550                                                      }
551            7                                 25      my $ea     = $args{ea};
552            7                                 31      my $item   = $args{item};
553            7                                 26      my $attrib = $args{attrib};
554                                                   
555            7                                 36      my $results = $ea->results();
556            7                                180      my $store   = $results->{classes}->{$item}->{$attrib};
557            7                                 30      my $vals    = $store->{all};
558   ***      7     50     50                   99      return "" unless defined $vals && scalar %$vals;
559                                                   
560                                                      # TODO: this is broken.
561            7                                 63      my @buck_tens = $ea->buckets_of(10);
562            7                               5785      my @distro = map { 0 } (0 .. 7);
              56                                188   
563                                                   
564                                                      # See similar code in EventAggregator::_calc_metrics() or
565                                                      # http://code.google.com/p/maatkit/issues/detail?id=866
566            7                                 65      my @buckets = map { 0 } (0..999);
            7000                              21790   
567            7                                381      map { $buckets[$_] = $vals->{$_} } keys %$vals;
               8                                 60   
568            7                                 30      $vals = \@buckets;  # repoint vals from given hashref to our array
569                                                   
570            7                                483      map { $distro[$buck_tens[$_]] += $vals->[$_] } (1 .. @$vals - 1);
            6993                              30484   
571                                                   
572            7                                363      my $vals_per_mark; # number of vals represented by 1 #-mark
573            7                                 26      my $max_val        = 0;
574            7                                 21      my $max_disp_width = 64;
575            7                                 25      my $bar_fmt        = "# %5s%s";
576            7                                 61      my @distro_labels  = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
577            7                                 43      my @results        = "# $attrib distribution";
578                                                   
579                                                      # Find the distro with the most values. This will set
580                                                      # vals_per_mark and become the bar at max_disp_width.
581            7                                 32      foreach my $n_vals ( @distro ) {
582           56    100                         256         $max_val = $n_vals if $n_vals > $max_val;
583                                                      }
584            7                                 35      $vals_per_mark = $max_val / $max_disp_width;
585                                                   
586            7                                 59      foreach my $i ( 0 .. $#distro ) {
587           56                                175         my $n_vals  = $distro[$i];
588           56           100                  279         my $n_marks = $n_vals / ($vals_per_mark || 1);
589                                                   
590                                                         # Always print at least 1 mark for any bucket that has at least
591                                                         # 1 value. This skews the graph a tiny bit, but it allows us to
592                                                         # see all buckets that have values.
593   ***     56     50     66                  477         $n_marks = 1 if $n_marks < 1 && $n_vals > 0;
594                                                   
595           56    100                         262         my $bar = ($n_marks ? '  ' : '') . '#' x $n_marks;
596           56                                321         push @results, sprintf $bar_fmt, $distro_labels[$i], $bar;
597                                                      }
598                                                   
599            7                                394      return join("\n", @results) . "\n";
600                                                   }
601                                                   
602                                                   # Profile subreport (issue 381).
603                                                   # Arguments:
604                                                   #   * ea            obj: EventAggregator
605                                                   #   * worst         arrayref: worst items
606                                                   #   * groupby       scalar: attrib worst items grouped by
607                                                   # Optional arguments:
608                                                   #   * distill_args     hashref: extra args for distill()
609                                                   #   * ReportFormatter  obj: passed-in ReportFormatter for testing
610                                                   sub profile {
611   ***      3                    3      0     32      my ( $self, %args ) = @_;
612            3                                 28      foreach my $arg ( qw(ea worst groupby) ) {
613   ***      9     50                          51         die "I need a $arg argument" unless defined $arg;
614                                                      }
615            3                                 18      my $ea      = $args{ea};
616            3                                 12      my $worst   = $args{worst};
617            3                                 13      my $groupby = $args{groupby};
618            3                                 13      my $n_worst = scalar @$worst;
619                                                   
620            3                                 14      my $qr  = $self->{QueryRewriter};
621                                                   
622            3                                 10      my @profiles;
623            3                                 10      my $total_r = 0;
624                                                   
625            3                                 15      foreach my $rank ( 1..$n_worst ) {
626            3                                 22         my $item       = $worst->[$rank - 1]->[0];
627            3                                 24         my $stats      = $ea->results->{classes}->{$item};
628            3                                106         my $sample     = $ea->results->{samples}->{$item};
629   ***      3            50                   94         my $samp_query = $sample->{arg} || '';
630            3                                 50         my %profile    = (
631                                                            rank   => $rank,
632                                                            r      => $stats->{Query_time}->{sum},
633                                                            cnt    => $stats->{Query_time}->{cnt},
634                                                            sample => $groupby eq 'fingerprint' ?
635   ***      3     50                          34                       $qr->distill($samp_query, %{$args{distill_args}}) : $item,
      ***            50                               
636                                                            id     => $groupby eq 'fingerprint' ? make_checksum($item)   : '',
637                                                         );
638            3                                 18         $total_r += $profile{r};
639            3                                 22         push @profiles, \%profile;
640                                                      }
641                                                   
642   ***      3            33                   20      my $report = $args{ReportFormatter} || new ReportFormatter(
643                                                         line_width       => LINE_LENGTH,
644                                                         long_last_column => 1,
645                                                         extend_right     => 1,
646                                                      );
647            3                                 37      $report->set_title('Profile');
648            3                                128      $report->set_columns(
649                                                         { name => 'Rank',          right_justify => 1, },
650                                                         { name => 'Query ID',                          },
651                                                         { name => 'Response time', right_justify => 1, },
652                                                         { name => 'Calls',         right_justify => 1, },
653                                                         { name => 'R/Call',        right_justify => 1, },
654                                                         { name => 'Item',                              },
655                                                      );
656                                                   
657            3                               2099      foreach my $item ( sort { $a->{rank} <=> $b->{rank} } @profiles ) {
      ***      0                                  0   
658            3                                 52         my $rt  = sprintf('%10.4f', $item->{r});
659   ***      3            50                   44         my $rtp = sprintf('%4.1f%%', $item->{r} / ($total_r || 1) * 100);
660            3                                 26         my $rc  = sprintf('%8.4f', $item->{r} / $item->{cnt});
661            3                                 49         $report->add_line(
662                                                            $item->{rank},
663                                                            "0x$item->{id}",
664                                                            "$rt $rtp",
665                                                            $item->{cnt},
666                                                            $rc,
667                                                            $item->{sample},
668                                                         );
669                                                      }
670            3                                847      return $report->get_report();
671                                                   }
672                                                   
673                                                   # Prepared statements subreport (issue 740).
674                                                   # Arguments:
675                                                   #   * ea            obj: EventAggregator
676                                                   #   * worst         arrayref: worst items
677                                                   #   * groupby       scalar: attrib worst items grouped by
678                                                   # Optional arguments:
679                                                   #   * distill_args  hashref: extra args for distill()
680                                                   #   * ReportFormatter  obj: passed-in ReportFormatter for testing
681                                                   sub prepared {
682   ***      1                    1      0     12      my ( $self, %args ) = @_;
683            1                                  7      foreach my $arg ( qw(ea worst groupby) ) {
684   ***      3     50                          14         die "I need a $arg argument" unless defined $arg;
685                                                      }
686            1                                  5      my $ea      = $args{ea};
687            1                                  3      my $worst   = $args{worst};
688            1                                  4      my $groupby = $args{groupby};
689            1                                  5      my $n_worst = scalar @$worst;
690                                                   
691            1                                  4      my $qr = $self->{QueryRewriter};
692                                                   
693            1                                  2      my @prepared;       # prepared statements
694            1                                  3      my %seen_prepared;  # report each PREP-EXEC pair once
695            1                                  4      my $total_r = 0;
696                                                   
697            1                                  4      foreach my $rank ( 1..$n_worst ) {
698            2                                 11         my $item       = $worst->[$rank - 1]->[0];
699            2                                 13         my $stats      = $ea->results->{classes}->{$item};
700            2                                 53         my $sample     = $ea->results->{samples}->{$item};
701   ***      2            50                   44         my $samp_query = $sample->{arg} || '';
702                                                   
703            2                                 10         $total_r += $stats->{Query_time}->{sum};
704   ***      2     50     33                   96         next unless $stats->{Statement_id} && $item =~ m/^(?:prepare|execute) /;
705                                                   
706                                                         # Each PREPARE (probably) has some EXECUTE and each EXECUTE (should)
707                                                         # have some PREPARE.  But these are only the top N events so we can get
708                                                         # here a PREPARE but not its EXECUTE or vice-versa.  The prepared
709                                                         # statements report requires both so this code gets the missing pair
710                                                         # from the ea stats.
711            2                                  8         my ($prep_stmt, $prep, $prep_r, $prep_cnt);
712            2                                  5         my ($exec_stmt, $exec, $exec_r, $exec_cnt);
713                                                   
714            2    100                          10         if ( $item =~ m/^prepare / ) {
715            1                                  4            $prep_stmt           = $item;
716            1                                  5            ($exec_stmt = $item) =~ s/^prepare /execute /;
717                                                         }
718                                                         else {
719            1                                  8            ($prep_stmt = $item) =~ s/^execute /prepare /;
720            1                                  3            $exec_stmt           = $item;
721                                                         }
722                                                   
723                                                         # Report each PREPARE/EXECUTE pair once.
724            2    100                          13         if ( !$seen_prepared{$prep_stmt}++ ) {
725            1                                  5            $exec     = $ea->results->{classes}->{$exec_stmt};
726            1                                 23            $exec_r   = $exec->{Query_time}->{sum};
727            1                                  4            $exec_cnt = $exec->{Query_time}->{cnt};
728            1                                  4            $prep     = $ea->results->{classes}->{$prep_stmt};
729            1                                 23            $prep_r   = $prep->{Query_time}->{sum};
730            1                                 14            $prep_cnt = scalar keys %{$prep->{Statement_id}->{unq}},
               1                                  8   
731                                                            push @prepared, {
732                                                               prep_r   => $prep_r, 
733                                                               prep_cnt => $prep_cnt,
734                                                               exec_r   => $exec_r,
735                                                               exec_cnt => $exec_cnt,
736                                                               rank     => $rank,
737                                                               sample   => $groupby eq 'fingerprint'
738   ***      1     50                           2                             ? $qr->distill($samp_query, %{$args{distill_args}})
      ***            50                               
739                                                                             : $item,
740                                                               id       => $groupby eq 'fingerprint' ? make_checksum($item)
741                                                                                                     : '',
742                                                            };
743                                                         }
744                                                      }
745                                                   
746                                                      # Return unless there are prepared statements to report.
747   ***      1     50                           5      return unless scalar @prepared;
748                                                   
749   ***      1            33                    6      my $report = $args{ReportFormatter} || new ReportFormatter(
750                                                         line_width       => LINE_LENGTH,
751                                                         long_last_column => 1,
752                                                         extend_right     => 1,     
753                                                      );
754            1                                  7      $report->set_title('Prepared statements');
755            1                                 32      $report->set_columns(
756                                                         { name => 'Rank',          right_justify => 1, },
757                                                         { name => 'Query ID',                          },
758                                                         { name => 'PREP',          right_justify => 1, },
759                                                         { name => 'PREP Response', right_justify => 1, },
760                                                         { name => 'EXEC',          right_justify => 1, },
761                                                         { name => 'EXEC Response', right_justify => 1, },
762                                                         { name => 'Item',                              },
763                                                      );
764                                                   
765            1                                590      foreach my $item ( sort { $a->{rank} <=> $b->{rank} } @prepared ) {
      ***      0                                  0   
766            1                                 20         my $exec_rt  = sprintf('%10.4f', $item->{exec_r});
767   ***      1            50                   12         my $exec_rtp = sprintf('%4.1f%%',$item->{exec_r}/($total_r || 1) * 100);
768            1                                  7         my $prep_rt  = sprintf('%10.4f', $item->{prep_r});
769   ***      1            50                   19         my $prep_rtp = sprintf('%4.1f%%',$item->{prep_r}/($total_r || 1) * 100);
770   ***      1            50                   26         $report->add_line(
      ***                   50                        
771                                                            $item->{rank},
772                                                            "0x$item->{id}",
773                                                            $item->{prep_cnt} || 0,
774                                                            "$prep_rt $prep_rtp",
775                                                            $item->{exec_cnt} || 0,
776                                                            "$exec_rt $exec_rtp",
777                                                            $item->{sample},
778                                                         );
779                                                      }
780            1                                240      return $report->get_report();
781                                                   }
782                                                   
783                                                   # Makes a header format and returns the format and the column header names
784                                                   # The argument is either 'global' or anything else.
785                                                   sub make_header {
786   ***     25                   25      0    111      my ( $self, $global ) = @_;
787           25                                161      my $format  = "# %-$self->{label_width}s %6s %7s %7s %7s %7s %7s %7s %7s";
788           25                                148      my @headers = qw(pct total min max avg 95% stddev median);
789           25    100                          99      if ( $global ) {
790            8                                 95         $format =~ s/%(\d+)s/' ' x $1/e;
               8                                 74   
791            8                                 26         shift @headers;
792                                                      }
793           25                                285      return $format, @headers;
794                                                   }
795                                                   
796                                                   # Convert attribute names into labels
797                                                   sub make_label {
798   ***    124                  124      0   1480      my ( $self, $val ) = @_;
799                                                   
800          124    100                         523      if ( $val =~ m/^InnoDB/ ) {
801                                                         # Shorten InnoDB attributes otherwise their short labels
802                                                         # are indistinguishable.
803            5                                 41         $val =~ s/^InnoDB_(\w+)/IDB_$1/;
804            5                                 23         $val =~ s/r_(\w+)/r$1/;
805                                                      }
806                                                   
807                                                      return  $val eq 'ts'         ? 'Time range'
808                                                            : $val eq 'user'       ? 'Users'
809                                                            : $val eq 'db'         ? 'Databases'
810                                                            : $val eq 'Query_time' ? 'Exec time'
811                                                            : $val eq 'host'       ? 'Hosts'
812                                                            : $val eq 'Error_no'   ? 'Errors'
813   ***    124     50                        1294            : do { $val =~ s/_/ /g; $val = substr($val, 0, $self->{label_width}); $val };
              66    100                         297   
              66    100                         320   
              66    100                         738   
                    100                               
                    100                               
814                                                   }
815                                                   
816                                                   # Does pretty-printing for bool (Yes/No) attributes like QC_Hit.
817                                                   sub format_bool_attrib {
818   ***      3                    3      0     12      my ( $self, $vals ) = @_;
819                                                      # Since the value is either 1 or 0, the sum is the number of
820                                                      # all true events and the number of false events is the total
821                                                      # number of events minus those that were true.
822            3                                 19      my $p_true = percentage_of($vals->{sum},  $vals->{cnt});
823   ***      3            50                   85      my $n_true = '(' . shorten($vals->{sum} || 0, d=>1_000, p=>0) . ')';
824            3                                182      return $p_true, $n_true;
825                                                   }
826                                                   
827                                                   # Does pretty-printing for lists of strings like users, hosts, db.
828                                                   sub format_string_list {
829   ***     43                   43      0    213      my ( $self, $attrib, $vals, $class_cnt ) = @_;
830           43                                176      my $o        = $self->{OptionParser};
831           43                                206      my $show_all = $o->get('show-all');
832                                                   
833                                                      # Only class result values have unq.  So if unq doesn't exist,
834                                                      # then we've been given global values.
835   ***     43     50                        1435      if ( !exists $vals->{unq} ) {
836   ***      0                                  0         return ($vals->{cnt});
837                                                      }
838                                                   
839           43                                147      my $cnt_for = $vals->{unq};
840           43    100                         242      if ( 1 == keys %$cnt_for ) {
841           36                                161         my ($str) = keys %$cnt_for;
842                                                         # - 30 for label, spacing etc.
843           36    100                         178         $str = substr($str, 0, LINE_LENGTH - 30) . '...'
844                                                            if length $str > LINE_LENGTH - 30;
845           36                                188         return (1, $str);
846                                                      }
847            7                                 22      my $line = '';
848   ***      7     50                          11      my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
              13                                104   
849                                                                     keys %$cnt_for;
850            7                                 43      my $i = 0;
851            7                                 25      foreach my $str ( @top ) {
852           16                                 39         my $print_str;
853           16    100                          88         if ( $str =~ m/(?:\d+\.){3}\d+/ ) {
                    100                               
854            7                                 23            $print_str = $str;  # Do not shorten IP addresses.
855                                                         }
856                                                         elsif ( length $str > MAX_STRING_LENGTH ) {
857            5                                 19            $print_str = substr($str, 0, MAX_STRING_LENGTH) . '...';
858                                                         }
859                                                         else {
860            4                                 12            $print_str = $str;
861                                                         }
862           16                                 81         my $p = percentage_of($cnt_for->{$str}, $class_cnt);
863           16                                385         $print_str .= " ($cnt_for->{$str}/$p%)";
864           16    100                          71         if ( !$show_all->{$attrib} ) {
865           13    100                          64            last if (length $line) + (length $print_str)  > LINE_LENGTH - 27;
866                                                         }
867           13                                 43         $line .= "$print_str, ";
868           13                                 42         $i++;
869                                                      }
870                                                   
871            7                                 33      $line =~ s/, $//;
872                                                   
873            7    100                          30      if ( $i < @top ) {
874            3                                 15         $line .= "... " . (@top - $i) . " more";
875                                                      }
876                                                   
877            7                                 42      return (scalar keys %$cnt_for, $line);
878                                                   }
879                                                   
880                                                   # Attribs are sorted into three groups: basic attributes (Query_time, etc.),
881                                                   # other non-bool attributes sorted by name, and bool attributes sorted by name.
882                                                   sub sorted_attribs {
883   ***     26                   26      0    134      my ( $self, $attribs, $ea ) = @_;
884           26                                248      my %basic_attrib = (
885                                                         Query_time    => 0,
886                                                         Lock_time     => 1,
887                                                         Rows_sent     => 2,
888                                                         Rows_examined => 3,
889                                                         user          => 4,
890                                                         host          => 5,
891                                                         db            => 6,
892                                                         ts            => 7,
893                                                      );
894           26                                 71      my @basic_attribs;
895           26                                 66      my @non_bool_attribs;
896           26                                 62      my @bool_attribs;
897                                                   
898                                                      ATTRIB:
899           26                                120      foreach my $attrib ( @$attribs ) {
900          171    100                         623         if ( exists $basic_attrib{$attrib} ) {
901           99                                372            push @basic_attribs, $attrib;
902                                                         }
903                                                         else {
904           72    100    100                  331            if ( ($ea->type_for($attrib) || '') ne 'bool' ) {
905           66                               1209               push @non_bool_attribs, $attrib;
906                                                            }
907                                                            else {
908            6                                100               push @bool_attribs, $attrib;
909                                                            }
910                                                         }
911                                                      }
912                                                   
913           26                                107      @non_bool_attribs = sort { uc $a cmp uc $b } @non_bool_attribs;
              91                                279   
914           26                                102      @bool_attribs     = sort { uc $a cmp uc $b } @bool_attribs;
               3                                 11   
915          125                                398      @basic_attribs    = sort {
916           26                                 51            $basic_attrib{$a} <=> $basic_attrib{$b} } @basic_attribs;
917                                                   
918           26                                243      return @basic_attribs, @non_bool_attribs, @bool_attribs;
919                                                   }
920                                                   
921                                                   # Gets a default database and a list of arrayrefs of [db, tbl] to print out
922                                                   sub tables_report {
923   ***      5                    5      0    184      my ( $self, @tables ) = @_;
924   ***      5     50                          23      return '' unless @tables;
925            5                                 24      my $q      = $self->{Quoter};
926            5                                 18      my $tables = "";
927            5                                 31      foreach my $db_tbl ( @tables ) {
928            5                                 26         my ( $db, $tbl ) = @$db_tbl;
929   ***      5     50                          46         $tables .= '#    SHOW TABLE STATUS'
930                                                                  . ($db ? " FROM `$db`" : '')
931                                                                  . " LIKE '$tbl'\\G\n";
932           10                                 71         $tables .= "#    SHOW CREATE TABLE "
933            5                                 24                  . $q->quote(grep { $_ } @$db_tbl)
934                                                                  . "\\G\n";
935                                                      }
936   ***      5     50                         271      return $tables ? "# Tables\n$tables" : "# No tables\n";
937                                                   }
938                                                   
939                                                   sub explain_report {
940   ***      4                    4      0     50      my ( $self, $query, $db ) = @_;
941            4                                 28      my $dbh = $self->{dbh};
942            4                                 22      my $q   = $self->{Quoter};
943            4                                 23      my $qp  = $self->{QueryParser};
944   ***      4    100     66                   83      return '' unless $dbh && $query;
945            1                                 16      my $explain = '';
946            1                                  5      eval {
947   ***      1     50                          27         if ( !$qp->has_derived_table($query) ) {
948   ***      1     50                          85            if ( $db ) {
949            1                                 29               $dbh->do("USE " . $q->quote($db));
950                                                            }
951            1                                  5            my $sth = $dbh->prepare("EXPLAIN /*!50100 PARTITIONS */ $query");
952            1                                512            $sth->execute();
953            1                                 12            my $i = 1;
954            1                                 53            while ( my @row = $sth->fetchrow_array() ) {
955            1                                 12               $explain .= "# *************************** $i. "
956                                                                         . "row ***************************\n";
957            1                                 20               foreach my $j ( 0 .. $#row ) {
958           11    100                         196                  $explain .= sprintf "# %13s: %s\n", $sth->{NAME}->[$j],
959                                                                     defined $row[$j] ? $row[$j] : 'NULL';
960                                                               }
961            1                                 81               $i++;  # next row number
962                                                            }
963                                                         }
964                                                      };
965   ***      1     50                          10      if ( $EVAL_ERROR ) {
966   ***      0                                  0         MKDEBUG && _d("EXPLAIN failed:", $query, $EVAL_ERROR);
967                                                      }
968   ***      1     50                          30      return $explain ? $explain : "# EXPLAIN failed: $EVAL_ERROR";
969                                                   }
970                                                   
971                                                   sub _d {
972            1                    1            14      my ($package, undef, $line) = caller 0;
973   ***      2     50                         158      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 23   
               2                                 23   
974            1                                  9           map { defined $_ ? $_ : 'undef' }
975                                                           @_;
976            1                                  8      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
977                                                   }
978                                                   
979                                                   1;
980                                                   
981                                                   # ###########################################################################
982                                                   # End QueryReportFormatter package
983                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
64    ***     50      0      6   unless $args{$arg}
107   ***     50      0     20   unless exists $args{$arg}
116   ***     50     14      0   if ($report_output) { }
117          100     11      3   if not $last_report or not $$group{$last_report} && $$group{$report}
144   ***     50      0      2   if ($EVAL_ERROR)
147   ***     50      2      0   $rusage ? :
157   ***     50      2      0   if ($args{'files'})
174   ***     50      0     16   unless $args{$arg}
188          100      3      5   if ($global_cnt and $$results{'globals'}{'ts'} and ($$results{'globals'}{'ts'}{'max'} || '') gt ($$results{'globals'}{'ts'}{'min'} || ''))
218          100      3      5   $args{'select'} ? :
220          100      7     38   if $$dont_print{$attrib}
222          100      3     35   unless $attrib_type
223   ***     50      0     35   unless exists $$results{'globals'}{$attrib}
224          100      7     28   if ($formatting_function{$attrib}) { }
232          100     18     10   if ($attrib_type eq 'num') { }
             100      6      4   elsif ($attrib_type eq 'string') { }
      ***     50      4      0   elsif ($attrib_type eq 'bool') { }
233          100     14      4   $attrib =~ /time|wait$/ ? :
240   ***     50    126      0   defined $_ ? :
247          100      3      1   if ($$store{'sum'} > 0 or $args{'zero_bool'})
257          100     18      4   unless $attrib_type eq 'bool'
277   ***     50      0     16   unless defined $arg
291   ***     50      0      4   if ($args{'print_header'})
307   ***     50      0      5   $args{'explain_why'} ? :
313   ***     50      0      5   if ($qv)
315   ***      0      0      0   if $$review_vals{'reviewed_by'} and not $o->get('report-all')
322   ***     50      0      2   $$stats{'db'}{'unq'} ? :
             100      3      2   $$sample{'db'} ? :
325   ***     50      5      0   if ($o->get('for-explain'))
336          100      1      4   if $rank > 1
344   ***     50      5      0   if ($o->get('report-histogram'))
352   ***     50      0      5   if ($qv and $review_vals)
358   ***      0      0      0   if (not $val or $val ne '0000-00-00 00:00:00')
359   ***      0      0      0   $val ? :
364   ***     50      5      0   if ($groupby eq 'fingerprint') { }
366   ***     50      5      0   if $o->get('shorten')
370   ***     50      0      5   if $o->get('fingerprints')
374   ***     50      5      0   if $o->get('for-explain')
377          100      3      2   if ($item =~ /^(?:[\(\s]*select|insert|replace)/) { }
378   ***     50      0      3   if ($item =~ /^(?:insert|replace)/) { }
389   ***     50      2      0   if ($o->get('for-explain') and $converted and $converted =~ /^[\(\s]*select/i)
398   ***      0      0      0   if ($groupby eq 'tables')
423   ***     50      0     51   unless $args{$arg}
435   ***     50      0     17   unless $store
443          100      3     14   if ($global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || ''))
458          100     13      4   $$ea{'groupby'} eq 'fingerprint' ? :
470          100      5     12   if ($args{'reason'})
471   ***     50      5      0   $args{'reason'} eq 'top' ? :
486          100      9      8   $args{'select'} ? :
488          100      8    111   if $$dont_print{$attrib}
490          100      7    104   unless $attrib_type
491   ***     50      0    104   unless exists $$store{$attrib}
493          100      5     99   unless scalar %$vals
494          100      8     91   if ($formatting_function{$attrib}) { }
502          100     48     43   if ($attrib_type eq 'num') { }
      ***     50     43      0   elsif ($attrib_type eq 'string') { }
      ***      0      0      0   elsif ($attrib_type eq 'bool') { }
503          100     28     20   $attrib =~ /time|wait$/ ? :
510   ***     50    336      0   defined $_ ? :
521   ***      0      0      0   if ($$vals{'sum'} > 0 or $args{'zero_bool'})
532   ***     50     91      0   unless $attrib_type eq 'bool'
549   ***     50      0     21   unless $args{$arg}
558   ***     50      0      7   unless defined $vals and scalar %$vals
582          100      6     50   if $n_vals > $max_val
593   ***     50      0     56   if $n_marks < 1 and $n_vals > 0
595          100      6     50   $n_marks ? :
613   ***     50      0      9   unless defined $arg
635   ***     50      3      0   $groupby eq 'fingerprint' ? :
      ***     50      3      0   $groupby eq 'fingerprint' ? :
684   ***     50      0      3   unless defined $arg
704   ***     50      0      2   unless $$stats{'Statement_id'} and $item =~ /^(?:prepare|execute) /
714          100      1      1   if ($item =~ /^prepare /) { }
724          100      1      1   if (not $seen_prepared{$prep_stmt}++)
738   ***     50      1      0   $groupby eq 'fingerprint' ? :
      ***     50      1      0   $groupby eq 'fingerprint' ? :
747   ***     50      0      1   unless scalar @prepared
789          100      8     17   if ($global)
800          100      5    119   if ($val =~ /^InnoDB/)
813   ***     50      0     66   $val eq 'Error_no' ? :
             100      6     66   $val eq 'host' ? :
             100     25     72   $val eq 'Query_time' ? :
             100      7     97   $val eq 'db' ? :
             100      5    104   $val eq 'user' ? :
             100     15    109   $val eq 'ts' ? :
835   ***     50      0     43   if (not exists $$vals{'unq'})
840          100     36      7   if (1 == keys %$cnt_for)
843          100      3     33   if length $str > 44
848   ***     50     13      0   unless $$cnt_for{$b} <=> $$cnt_for{$a}
853          100      7      9   if ($str =~ /(?:\d+\.){3}\d+/) { }
             100      5      4   elsif (length $str > 10) { }
864          100     13      3   if (not $$show_all{$attrib})
865          100      3     10   if length($line) + length($print_str) > 47
873          100      3      4   if ($i < @top)
900          100     99     72   if (exists $basic_attrib{$attrib}) { }
904          100     66      6   if (($ea->type_for($attrib) || '') ne 'bool') { }
924   ***     50      0      5   unless @tables
929   ***     50      5      0   $db ? :
936   ***     50      5      0   $tables ? :
944          100      3      1   unless $dbh and $query
947   ***     50      1      0   if (not $qp->has_derived_table($query))
948   ***     50      1      0   if ($db)
958          100     10      1   defined $row[$j] ? :
965   ***     50      0      1   if ($EVAL_ERROR)
968   ***     50      1      0   $explain ? :
973   ***     50      2      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
558   ***     50      0      7   defined $vals and scalar %$vals

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
117          100      6      1      3   $$group{$last_report} && $$group{$report}
188   ***     66      0      1      7   $global_cnt and $$results{'globals'}{'ts'}
             100      1      4      3   $global_cnt and $$results{'globals'}{'ts'} and ($$results{'globals'}{'ts'}{'max'} || '') gt ($$results{'globals'}{'ts'}{'min'} || '')
315   ***      0      0      0      0   $$review_vals{'reviewed_by'} and not $o->get('report-all')
352   ***     33      5      0      0   $qv and $review_vals
389   ***     33      0      0      2   $o->get('for-explain') and $converted
      ***     33      0      0      2   $o->get('for-explain') and $converted and $converted =~ /^[\(\s]*select/i
443   ***     66      0      4     13   $global_cnt and $$store{'ts'}
             100      4     10      3   $global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || '')
593   ***     66      6     50      0   $n_marks < 1 and $n_vals > 0
704   ***     33      0      0      2   $$stats{'Statement_id'} and $item =~ /^(?:prepare|execute) /
944   ***     66      3      0      1   $dbh and $query

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
40    ***     50      0      1   $ENV{'MKDEBUG'} || 0
68    ***     50      0      2   $args{'label_width'} || 9
138   ***     50      2      0   $rss || 0
      ***     50      2      0   $vsz || 0
184   ***     50      8      0   $$results{'globals'}{$orderby}{'cnt'} || 0
188   ***     50      7      0   $$results{'globals'}{'ts'}{'max'} || ''
      ***     50      7      0   $$results{'globals'}{'ts'}{'min'} || ''
196   ***     50      3      0   $diff || 1
207          100      3      5   $qps || 0
             100      3      5   $conc || 0
306   ***     50      5      0   $$sample{'arg'} || ''
443          100     11      2   $$store{'ts'}{'max'} || ''
             100     11      2   $$store{'ts'}{'min'} || ''
458   ***     50     17      0   $args{'rank'} || 0
             100      3     14   $qps || 0
             100      3     14   $conc || 0
             100      7     10   $$results{'samples'}{$item}{'pos_in_log'} || 0
588          100     48      8   $vals_per_mark || 1
629   ***     50      3      0   $$sample{'arg'} || ''
659   ***     50      3      0   $total_r || 1
701   ***     50      2      0   $$sample{'arg'} || ''
767   ***     50      1      0   $total_r || 1
769   ***     50      1      0   $total_r || 1
770   ***     50      0      1   $$item{'prep_cnt'} || 0
      ***     50      1      0   $$item{'exec_cnt'} || 0
823   ***     50      3      0   $$vals{'sum'} || 0
904          100     70      2   $ea->type_for($attrib) || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
117          100      4      7      3   not $last_report or not $$group{$last_report} && $$group{$report}
247   ***     66      3      0      1   $$store{'sum'} > 0 or $args{'zero_bool'}
358   ***      0      0      0      0   not $val or $val ne '0000-00-00 00:00:00'
521   ***      0      0      0      0   $$vals{'sum'} > 0 or $args{'zero_bool'}
642   ***     33      3      0      0   $args{'ReportFormatter'} || new(ReportFormatter('line_width', 74, 'long_last_column', 1, 'extend_right', 1))
749   ***     33      1      0      0   $args{'ReportFormatter'} || new(ReportFormatter('line_width', 74, 'long_last_column', 1, 'extend_right', 1))


Covered Subroutines
-------------------

Subroutine         Count Pod Location                                                   
------------------ ----- --- -----------------------------------------------------------
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:32 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:33 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:34 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:40 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:41 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:42 
_d                     1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:972
chart_distro           7   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:547
date                   2   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:151
event_report          17   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:421
explain_report         4   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:940
files                  2   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:156
format_bool_attrib     3   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:818
format_string_list    43   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:829
header                 8   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:172
make_header           25   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:786
make_label           124   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:798
new                    2   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:62 
prepared               1   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:682
print_reports          4   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:105
profile                3   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:611
query_report           4   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:275
rusage                 2   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:131
sorted_attribs        26   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:883
tables_report          5   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:923


QueryReportFormatter.t

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
               1                                  6   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1            10   use Test::More tests => 29;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use Transformers;
               1                                  2   
               1                                 10   
15             1                    1            10   use QueryReportFormatter;
               1                                  3   
               1                                 15   
16             1                    1            13   use EventAggregator;
               1                                  3   
               1                                 23   
17             1                    1            15   use QueryRewriter;
               1                                  4   
               1                                 10   
18             1                    1            11   use QueryParser;
               1                                  2   
               1                                 13   
19             1                    1            11   use Quoter;
               1                                  3   
               1                                  9   
20             1                    1            10   use ReportFormatter;
               1                                  3   
               1                                 12   
21             1                    1            11   use OptionParser;
               1                                  3   
               1                                 16   
22             1                    1            15   use DSNParser;
               1                                  3   
               1                                 13   
23             1                    1             9   use ReportFormatter;
               1                                  2   
               1                                  7   
24             1                    1            13   use Sandbox;
               1                                  2   
               1                                 11   
25             1                    1            15   use MaatkitTest;
               1                                  6   
               1                                 34   
26                                                    
27             1                                 10   my $dp  = new DSNParser(opts=>$dsn_opts);
28             1                                241   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
29             1                                 55   my $dbh = $sb->get_dbh_for('master');
30                                                    
31             1                                390   my ($result, $events, $expected);
32                                                    
33             1                                 14   my $q   = new Quoter();
34             1                                 35   my $qp  = new QueryParser();
35             1                                 28   my $qr  = new QueryRewriter(QueryParser=>$qp);
36             1                                 33   my $o   = new OptionParser(description=>'qrf');
37                                                    
38             1                                159   $o->get_specs("$trunk/mk-query-digest/mk-query-digest");
39                                                    
40             1                                 32   my $qrf = new QueryReportFormatter(
41                                                       OptionParser  => $o,
42                                                       QueryRewriter => $qr,
43                                                       QueryParser   => $qp,
44                                                       Quoter        => $q, 
45                                                    );
46                                                    
47             1                                 27   my $ea  = new EventAggregator(
48                                                       groupby => 'fingerprint',
49                                                       worst   => 'Query_time',
50                                                       attributes => {
51                                                          Query_time    => [qw(Query_time)],
52                                                          Lock_time     => [qw(Lock_time)],
53                                                          user          => [qw(user)],
54                                                          ts            => [qw(ts)],
55                                                          Rows_sent     => [qw(Rows_sent)],
56                                                          Rows_examined => [qw(Rows_examined)],
57                                                          db            => [qw(db)],
58                                                       },
59                                                    );
60                                                    
61             1                                352   isa_ok($qrf, 'QueryReportFormatter');
62                                                    
63             1                                  8   $result = $qrf->rusage();
64             1                                 49   like(
65                                                       $result,
66                                                       qr/^# \S+ user time, \S+ system time, \S+ rss, \S+ vsz/s,
67                                                       'rusage report',
68                                                    );
69                                                    
70             1                                 56   $events = [
71                                                       {  ts            => '071015 21:43:52',
72                                                          cmd           => 'Query',
73                                                          user          => 'root',
74                                                          host          => 'localhost',
75                                                          ip            => '',
76                                                          arg           => "SELECT id FROM users WHERE name='foo'",
77                                                          Query_time    => '8.000652',
78                                                          Lock_time     => '0.000109',
79                                                          Rows_sent     => 1,
80                                                          Rows_examined => 1,
81                                                          pos_in_log    => 1,
82                                                          db            => 'test3',
83                                                       },
84                                                       {  ts   => '071015 21:43:52',
85                                                          cmd  => 'Query',
86                                                          user => 'root',
87                                                          host => 'localhost',
88                                                          ip   => '',
89                                                          arg =>
90                                                             "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
91                                                          Query_time    => '1.001943',
92                                                          Lock_time     => '0.000145',
93                                                          Rows_sent     => 0,
94                                                          Rows_examined => 0,
95                                                          pos_in_log    => 2,
96                                                          db            => 'test1',
97                                                       },
98                                                       {  ts            => '071015 21:43:53',
99                                                          cmd           => 'Query',
100                                                         user          => 'bob',
101                                                         host          => 'localhost',
102                                                         ip            => '',
103                                                         arg           => "SELECT id FROM users WHERE name='bar'",
104                                                         Query_time    => '1.000682',
105                                                         Lock_time     => '0.000201',
106                                                         Rows_sent     => 1,
107                                                         Rows_examined => 2,
108                                                         pos_in_log    => 5,
109                                                         db            => 'test1',
110                                                      }
111                                                   ];
112                                                   
113                                                   # Here's the breakdown of values for those three events:
114                                                   # 
115                                                   # ATTRIBUTE     VALUE     BUCKET  VALUE        RANGE
116                                                   # Query_time => 8.000652  326     7.700558026  range [7.700558026, 8.085585927)
117                                                   # Query_time => 1.001943  284     0.992136979  range [0.992136979, 1.041743827)
118                                                   # Query_time => 1.000682  284     0.992136979  range [0.992136979, 1.041743827)
119                                                   #               --------          -----------
120                                                   #               10.003277         9.684831984
121                                                   #
122                                                   # Lock_time  => 0.000109  97      0.000108186  range [0.000108186, 0.000113596)
123                                                   # Lock_time  => 0.000145  103     0.000144980  range [0.000144980, 0.000152229)
124                                                   # Lock_time  => 0.000201  109     0.000194287  range [0.000194287, 0.000204002)
125                                                   #               --------          -----------
126                                                   #               0.000455          0.000447453
127                                                   #
128                                                   # Rows_sent  => 1         284     0.992136979  range [0.992136979, 1.041743827)
129                                                   # Rows_sent  => 0         0       0
130                                                   # Rows_sent  => 1         284     0.992136979  range [0.992136979, 1.041743827)
131                                                   #               --------          -----------
132                                                   #               2                 1.984273958
133                                                   #
134                                                   # Rows_exam  => 1         284     0.992136979  range [0.992136979, 1.041743827)
135                                                   # Rows_exam  => 0         0       0 
136                                                   # Rows_exam  => 2         298     1.964363355, range [1.964363355, 2.062581523) 
137                                                   #               --------          -----------
138                                                   #               3                 2.956500334
139                                                   
140                                                   # I hand-checked these values with my TI-83 calculator.
141                                                   # They are, without a doubt, correct.
142            1                                  4   $expected = <<EOF;
143                                                   # Overall: 3 total, 2 unique, 3 QPS, 10.00x concurrency __________________
144                                                   #                    total     min     max     avg     95%  stddev  median
145                                                   # Exec time            10s      1s      8s      3s      8s      3s   992ms
146                                                   # Lock time          455us   109us   201us   151us   194us    35us   144us
147                                                   # Rows sent              2       0       1    0.67    0.99    0.47    0.99
148                                                   # Rows exam              3       0       2       1    1.96    0.80    0.99
149                                                   # Time range        2007-10-15 21:43:52 to 2007-10-15 21:43:53
150                                                   EOF
151                                                   
152            1                                  7   foreach my $event (@$events) {
153            3                                 25      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
154            3                                303      $ea->aggregate($event);
155                                                   }
156            1                                  9   $ea->calculate_statistical_metrics();
157            1                              32232   $result = $qrf->header(
158                                                      ea      => $ea,
159                                                      select  => [ qw(Query_time Lock_time Rows_sent Rows_examined ts) ],
160                                                      orderby => 'Query_time',
161                                                   );
162                                                   
163            1                                  9   is($result, $expected, 'Global (header) report');
164                                                   
165            1                                  4   $expected = <<EOF;
166                                                   # Query 1: 2 QPS, 9.00x concurrency, ID 0x82860EDA9A88FCC5 at byte 1 _____
167                                                   # This item is included in the report because it matches --limit.
168                                                   #              pct   total     min     max     avg     95%  stddev  median
169                                                   # Count         66       2
170                                                   # Exec time     89      9s      1s      8s      5s      8s      5s      5s
171                                                   # Lock time     68   310us   109us   201us   155us   201us    65us   155us
172                                                   # Rows sent    100       2       1       1       1       1       0       1
173                                                   # Rows exam    100       3       1       2    1.50       2    0.71    1.50
174                                                   # Users                  2 bob (1/50%), root (1/50%)
175                                                   # Databases              2 test1 (1/50%), test3 (1/50%)
176                                                   # Time range 2007-10-15 21:43:52 to 2007-10-15 21:43:53
177                                                   EOF
178                                                   
179            1                                 17   $result = $qrf->event_report(
180                                                      ea => $ea,
181                                                      # "users" is here to try to cause a failure
182                                                      select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
183                                                      item    => 'select id from users where name=?',
184                                                      rank    => 1,
185                                                      orderby => 'Query_time',
186                                                      reason  => 'top',
187                                                   );
188                                                   
189            1                                  9   is($result, $expected, 'Event report');
190                                                   
191            1                                  3   $expected = <<EOF;
192                                                   # Query_time distribution
193                                                   #   1us
194                                                   #  10us
195                                                   # 100us
196                                                   #   1ms
197                                                   #  10ms
198                                                   # 100ms
199                                                   #    1s  ################################################################
200                                                   #  10s+
201                                                   EOF
202                                                   
203            1                                 13   $result = $qrf->chart_distro(
204                                                      ea     => $ea,
205                                                      attrib => 'Query_time',
206                                                      item   => 'select id from users where name=?',
207                                                   );
208                                                   
209            1                                  8   is($result, $expected, 'Query_time distro');
210                                                   
211            1                                 15   SKIP: {
212            1                                  3      skip 'Wider labels not used, not tested', 1;
213   ***      0                                  0   $qrf = new QueryReportFormatter(label_width => 15);
214   ***      0                                  0   $expected = <<EOF;
215                                                   # Query 1: 2 QPS, 9.00x concurrency, ID 0x82860EDA9A88FCC5 at byte 1 ___________
216                                                   # This item is included in the report because it matches --limit.
217                                                   #                    pct   total     min     max     avg     95%  stddev  median
218                                                   # Count               66       2
219                                                   # Exec time           89      9s      1s      8s      5s      8s      5s      5s
220                                                   # Lock time           68   310us   109us   201us   155us   201us    65us   155us
221                                                   # Rows sent          100       2       1       1       1       1       0       1
222                                                   # Rows examined      100       3       1       2    1.50       2    0.71    1.50
223                                                   # Users                        2 bob (1), root (1)
224                                                   # Databases                    2 test1 (1), test3 (1)
225                                                   # Time range      2007-10-15 21:43:52 to 2007-10-15 21:43:53
226                                                   EOF
227                                                   
228   ***      0                                  0   $result = $qrf->event_report(
229                                                      $ea,
230                                                      # "users" is here to try to cause a failure
231                                                      select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
232                                                      where   => 'select id from users where name=?',
233                                                      rank    => 1,
234                                                      worst   => 'Query_time',
235                                                      reason  => 'top',
236                                                   );
237                                                   
238   ***      0                                  0   is($result, $expected, 'Event report with wider label');
239                                                   
240   ***      0                                  0   $qrf = new QueryReportFormatter;
241                                                   };
242                                                   
243                                                   # ########################################################################
244                                                   # This one is all about an event that's all zeroes.
245                                                   # ########################################################################
246            1                                 24   $ea  = new EventAggregator(
247                                                      groupby => 'fingerprint',
248                                                      worst   => 'Query_time',
249                                                      attributes => {
250                                                         Query_time    => [qw(Query_time)],
251                                                         Lock_time     => [qw(Lock_time)],
252                                                         user          => [qw(user)],
253                                                         ts            => [qw(ts)],
254                                                         Rows_sent     => [qw(Rows_sent)],
255                                                         Rows_examined => [qw(Rows_examined)],
256                                                         db            => [qw(db)],
257                                                      },
258                                                   );
259                                                   
260            1                                683   $events = [
261                                                      {  bytes              => 30,
262                                                         db                 => 'mysql',
263                                                         ip                 => '127.0.0.1',
264                                                         arg                => 'administrator command: Connect',
265                                                         fingerprint        => 'administrator command: Connect',
266                                                         Rows_affected      => 0,
267                                                         user               => 'msandbox',
268                                                         Warning_count      => 0,
269                                                         cmd                => 'Admin',
270                                                         No_good_index_used => 'No',
271                                                         ts                 => '090412 11:00:13.118191',
272                                                         No_index_used      => 'No',
273                                                         port               => '57890',
274                                                         host               => '127.0.0.1',
275                                                         Thread_id          => 8,
276                                                         pos_in_log         => '0',
277                                                         Query_time         => '0',
278                                                         Error_no           => 0
279                                                      },
280                                                   ];
281                                                   
282            1                                 13   foreach my $event (@$events) {
283            1                                  8      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
284            1                                 25      $ea->aggregate($event);
285                                                   }
286            1                                 42   $ea->calculate_statistical_metrics();
287            1                                223   $expected = <<EOF;
288                                                   # Overall: 1 total, 1 unique, 0 QPS, 0x concurrency ______________________
289                                                   #                    total     min     max     avg     95%  stddev  median
290                                                   # Exec time              0       0       0       0       0       0       0
291                                                   # Time range        2009-04-12 11:00:13.118191 to 2009-04-12 11:00:13.118191
292                                                   EOF
293                                                   
294            1                                 10   $result = $qrf->header(
295                                                      ea      => $ea,
296                                                      select  => [ qw(Query_time Lock_time Rows_sent Rows_examined ts) ],
297                                                      orderby => 'Query_time',
298                                                   );
299                                                   
300            1                                  6   is($result, $expected, 'Global report with all zeroes');
301                                                   
302            1                                  3   $expected = <<EOF;
303                                                   # Query 1: 0 QPS, 0x concurrency, ID 0x5D51E5F01B88B79E at byte 0 ________
304                                                   # This item is included in the report because it matches --limit.
305                                                   #              pct   total     min     max     avg     95%  stddev  median
306                                                   # Count        100       1
307                                                   # Exec time      0       0       0       0       0       0       0       0
308                                                   # Users                  1 msandbox
309                                                   # Databases              1   mysql
310                                                   # Time range 2009-04-12 11:00:13.118191 to 2009-04-12 11:00:13.118191
311                                                   EOF
312                                                   
313            1                                 14   $result = $qrf->event_report(
314                                                      ea     => $ea,
315                                                      select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
316                                                      item    => 'administrator command: Connect',
317                                                      rank    => 1,
318                                                      orderby => 'Query_time',
319                                                      reason  => 'top',
320                                                   );
321                                                   
322            1                                  8   is($result, $expected, 'Event report with all zeroes');
323                                                   
324            1                                  4   $expected = <<EOF;
325                                                   # Query_time distribution
326                                                   #   1us
327                                                   #  10us
328                                                   # 100us
329                                                   #   1ms
330                                                   #  10ms
331                                                   # 100ms
332                                                   #    1s
333                                                   #  10s+
334                                                   EOF
335                                                   
336                                                   # This used to cause illegal division by zero in some cases.
337            1                                  8   $result = $qrf->chart_distro(
338                                                      ea     => $ea,
339                                                      attrib => 'Query_time',
340                                                      item   => 'administrator command: Connect',
341                                                   );
342                                                   
343            1                                 12   is($result, $expected, 'Chart distro with all zeroes');
344                                                   
345                                                   # #############################################################################
346                                                   # Test bool (Yes/No) pretty printing.
347                                                   # #############################################################################
348            1                                 24   $events = [
349                                                      {  ts            => '071015 21:43:52',
350                                                         cmd           => 'Query',
351                                                         arg           => "SELECT id FROM users WHERE name='foo'",
352                                                         Query_time    => '8.000652',
353                                                         Lock_time     => '0.002300',
354                                                         QC_Hit        => 'No',
355                                                         Filesort      => 'Yes',
356                                                         InnoDB_IO_r_bytes     => 2,
357                                                         InnoDB_pages_distinct => 20,
358                                                      },
359                                                      {  ts            => '071015 21:43:52',
360                                                         cmd           => 'Query',
361                                                         arg           => "SELECT id FROM users WHERE name='foo'",
362                                                         Query_time    => '1.001943',
363                                                         Lock_time     => '0.002320',
364                                                         QC_Hit        => 'Yes',
365                                                         Filesort      => 'Yes',
366                                                         InnoDB_IO_r_bytes     => 2,
367                                                         InnoDB_pages_distinct => 18,
368                                                      },
369                                                      {  ts            => '071015 21:43:53',
370                                                         cmd           => 'Query',
371                                                         arg           => "SELECT id FROM users WHERE name='bar'",
372                                                         Query_time    => '1.000682',
373                                                         Lock_time     => '0.003301',
374                                                         QC_Hit        => 'Yes',
375                                                         Filesort      => 'Yes',
376                                                         InnoDB_IO_r_bytes     => 3,
377                                                         InnoDB_pages_distinct => 11,
378                                                      }
379                                                   ];
380            1                                  5   $expected = <<EOF;
381                                                   # Overall: 3 total, 1 unique, 3 QPS, 10.00x concurrency __________________
382                                                   #                    total     min     max     avg     95%  stddev  median
383                                                   # Exec time            10s      1s      8s      3s      8s      3s   992ms
384                                                   # Lock time            8ms     2ms     3ms     3ms     3ms   500us     2ms
385                                                   # Time range        2007-10-15 21:43:52 to 2007-10-15 21:43:53
386                                                   # IDB IO rb              7       2       3    2.33    2.90    0.44    1.96
387                                                   # IDB pages             49      11      20   16.33   19.46    3.71   17.65
388                                                   # 100% (3)    Filesort
389                                                   #  66% (2)    QC_Hit
390                                                   EOF
391                                                   
392            1                                  8   $ea  = new EventAggregator(
393                                                      groupby => 'fingerprint',
394                                                      worst   => 'Query_time',
395                                                      ignore_attributes => [qw(arg cmd)],
396                                                   );
397            1                                295   foreach my $event (@$events) {
398            3                                 21      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
399            3                                234      $ea->aggregate($event);
400                                                   }
401            1                                  6   $ea->calculate_statistical_metrics();
402            1                              67034   $result = $qrf->header(
403                                                      ea      => $ea,
404                                                      # select  => [ $ea->get_attributes() ],
405                                                      orderby => 'Query_time',
406                                                   );
407                                                   
408            1                                  8   is($result, $expected, 'Bool (Yes/No) pretty printer');
409                                                   
410                                                   # #############################################################################
411                                                   # Test attrib sorting.
412                                                   # #############################################################################
413                                                   
414                                                   # This test uses the $ea from the Bool pretty printer test above.
415            1                                  7   is_deeply(
416                                                      [ $qrf->sorted_attribs($ea->get_attributes(), $ea) ],
417                                                      [qw(
418                                                         Query_time
419                                                         Lock_time
420                                                         ts
421                                                         InnoDB_IO_r_bytes
422                                                         InnoDB_pages_distinct
423                                                         Filesort
424                                                         QC_Hit
425                                                         )
426                                                      ],
427                                                      'sorted_attribs()'
428                                                   );
429                                                   
430                                                   # ############################################################################
431                                                   # Test that --[no]zero-bool removes 0% vals.
432                                                   # ############################################################################
433            1                                 25   $events = [
434                                                      {  ts            => '071015 21:43:52',
435                                                         cmd           => 'Query',
436                                                         arg           => "SELECT id FROM users WHERE name='foo'",
437                                                         Query_time    => '8.000652',
438                                                         Lock_time     => '0.002300',
439                                                         QC_Hit        => 'No',
440                                                         Filesort      => 'No',
441                                                      },
442                                                      {  ts            => '071015 21:43:52',
443                                                         cmd           => 'Query',
444                                                         arg           => "SELECT id FROM users WHERE name='foo'",
445                                                         Query_time    => '1.001943',
446                                                         Lock_time     => '0.002320',
447                                                         QC_Hit        => 'Yes',
448                                                         Filesort      => 'No',
449                                                      },
450                                                      {  ts            => '071015 21:43:53',
451                                                         cmd           => 'Query',
452                                                         arg           => "SELECT id FROM users WHERE name='bar'",
453                                                         Query_time    => '1.000682',
454                                                         Lock_time     => '0.003301',
455                                                         QC_Hit        => 'Yes',
456                                                         Filesort      => 'No',
457                                                      }
458                                                   ];
459            1                                 10   $expected = <<EOF;
460                                                   # Overall: 3 total, 1 unique, 3 QPS, 10.00x concurrency __________________
461                                                   #                    total     min     max     avg     95%  stddev  median
462                                                   # Exec time            10s      1s      8s      3s      8s      3s   992ms
463                                                   # Lock time            8ms     2ms     3ms     3ms     3ms   500us     2ms
464                                                   # Time range        2007-10-15 21:43:52 to 2007-10-15 21:43:53
465                                                   #  66% (2)    QC_Hit
466                                                   EOF
467                                                   
468            1                                  9   $ea  = new EventAggregator(
469                                                      groupby => 'fingerprint',
470                                                      worst   => 'Query_time',
471                                                      ignore_attributes => [qw(arg cmd)],
472                                                   );
473            1                                460   foreach my $event (@$events) {
474            3                                 19      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
475            3                                232      $ea->aggregate($event);
476                                                   }
477            1                                  6   $ea->calculate_statistical_metrics();
478            1                              31903   $result = $qrf->header(
479                                                      ea        => $ea,
480                                                      # select    => [ $ea->get_attributes() ],
481                                                      orderby   => 'Query_time',
482                                                      zero_bool => 0,
483                                                   );
484                                                   
485            1                                  8   is($result, $expected, 'No zero bool vals');
486                                                   
487                                                   # #############################################################################
488                                                   # Issue 458: mk-query-digest Use of uninitialized value in division (/) at
489                                                   # line 3805
490                                                   # #############################################################################
491                                                   use SlowLogParser;
492                                                   my $p = new SlowLogParser();
493                                                   
494                                                   sub report_from_file {
495                                                      my $ea2 = new EventAggregator(
496                                                         groupby => 'fingerprint',
497                                                         worst   => 'Query_time',
498                                                      );
499                                                      my ( $file ) = @_;
500                                                      $file = "$trunk/$file";
501                                                      my @e;
502                                                      my @callbacks;
503                                                      push @callbacks, sub {
504                                                         my ( $event ) = @_;
505                                                         my $group_by_val = $event->{arg};
506                                                         return 0 unless defined $group_by_val;
507                                                         $event->{fingerprint} = $qr->fingerprint($group_by_val);
508                                                         return $event;
509                                                      };
510                                                      push @callbacks, sub {
511                                                         $ea2->aggregate(@_);
512                                                      };
513                                                      eval {
514                                                         open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
515                                                         my %args = (
516                                                            next_event => sub { return <$fh>;      },
517                                                            tell       => sub { return tell($fh);  },
518                                                         );
519                                                         while ( my $e = $p->parse_event(%args) ) {
520                                                            $_->($e) for @callbacks;
521                                                         }
522                                                         close $fh;
523                                                      };
524                                                      die $EVAL_ERROR if $EVAL_ERROR;
525                                                      $ea2->calculate_statistical_metrics();
526                                                      my %top_spec = (
527                                                         attrib  => 'Query_time',
528                                                         orderby => 'sum',
529                                                         total   => 100,
530                                                         count   => 100,
531                                                      );
532                                                      my @worst  = $ea2->top_events(%top_spec);
533                                                      my $report = '';
534                                                      foreach my $rank ( 1 .. @worst ) {
535                                                         $report .= $qrf->event_report(
536                                                            ea      => $ea2,
537                                                            # select  => [ $ea2->get_attributes() ],
538                                                            item    => $worst[$rank - 1]->[0],
539                                                            rank    => $rank,
540                                                            orderby => 'Query_time',
541                                                            reason  => '',
542                                                         );
543                                                      }
544                                                      return $report;
545                                                   }
546                                                   
547                                                   # The real bug is in QueryReportFormatter, and there's nothing particularly
548                                                   # interesting about this sample, but we just want to make sure that the
549                                                   # timestamp prop shows up only in the one event.  The bug is that it appears
550                                                   eval {
551                                                      report_from_file('common/t/samples/slow029.txt');
552                                                   };
553                                                   is(
554                                                      $EVAL_ERROR,
555                                                      '',
556                                                      'event_report() does not die on empty attributes (issue 458)'
557                                                   );
558                                                   
559                                                   # #############################################################################
560                                                   # Test that format_string_list() truncates long strings.
561                                                   # #############################################################################
562                                                   
563                                                   $events = [
564                                                      {  ts   => '071015 21:43:52',
565                                                         cmd  => 'Query',
566                                                         arg  => "SELECT id FROM users WHERE name='foo'",
567                                                         Query_time => 1,
568                                                         foo  => "Hi.  I'm a very long string.  I'm way over the 78 column width that we try to keep lines limited to so text wrapping doesn't make things look all funky and stuff.",
569                                                      },
570                                                   ];
571                                                   
572                                                   $expected = <<EOF;
573                                                   # Query 1: 0 QPS, 0x concurrency, ID 0x82860EDA9A88FCC5 at byte 0 ________
574                                                   # This item is included in the report because it matches --limit.
575                                                   #              pct   total     min     max     avg     95%  stddev  median
576                                                   # Count        100       1
577                                                   # Exec time    100      1s      1s      1s      1s      1s       0      1s
578                                                   # foo                    1 Hi.  I'm a very long string.  I'm way over t...
579                                                   EOF
580                                                   
581                                                   $ea  = new EventAggregator(
582                                                      groupby => 'fingerprint',
583                                                      worst   => 'Query_time',
584                                                      ignore_attributes => [qw(arg cmd)],
585                                                   );
586                                                   foreach my $event (@$events) {
587                                                      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
588                                                      $ea->aggregate($event);
589                                                   }
590                                                   $ea->calculate_statistical_metrics();
591                                                   $result = $qrf->event_report(
592                                                      ea      => $ea,
593                                                      select  => [ qw(Query_time foo) ],
594                                                      item    => 'select id from users where name=?',
595                                                      rank    => 1,
596                                                      orderby => 'Query_time',
597                                                      reason  => 'top',
598                                                   );
599                                                   
600                                                   is(
601                                                      $result,
602                                                      $expected,
603                                                      'Truncate one long string'
604                                                   );
605                                                   
606                                                   $ea->reset_aggregated_data();
607                                                   push @$events,
608                                                      {  ts   => '071015 21:43:55',
609                                                         cmd  => 'Query',
610                                                         arg  => "SELECT id FROM users WHERE name='foo'",
611                                                         Query_time => 2,
612                                                         foo  => "Me too! I'm a very long string yay!  I'm also over the 78 column width that we try to keep lines limited to."
613                                                      };
614                                                   
615                                                   $expected = <<EOF;
616                                                   # Query 1: 0.67 QPS, 1x concurrency, ID 0x82860EDA9A88FCC5 at byte 0 _____
617                                                   # This item is included in the report because it matches --limit.
618                                                   #              pct   total     min     max     avg     95%  stddev  median
619                                                   # Count        100       2
620                                                   # Exec time    100      3s      1s      2s      2s      2s   707ms      2s
621                                                   # foo                    2 Hi.  I'm a... (1/50%), Me too! I'... (1/50%)
622                                                   EOF
623                                                   
624                                                   foreach my $event (@$events) {
625                                                      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
626                                                      $ea->aggregate($event);
627                                                   }
628                                                   $ea->calculate_statistical_metrics();
629                                                   $result = $qrf->event_report(
630                                                      ea      => $ea,
631                                                      select  => [ qw(Query_time foo) ],
632                                                      item    => 'select id from users where name=?',
633                                                      rank    => 1,
634                                                      orderby => 'Query_time',
635                                                      reason  => 'top',
636                                                   );
637                                                   
638                                                   is(
639                                                      $result,
640                                                      $expected, 'Truncate multiple long strings'
641                                                   );
642                                                   
643                                                   $ea->reset_aggregated_data();
644                                                   push @$events,
645                                                      {  ts   => '071015 21:43:55',
646                                                         cmd  => 'Query',
647                                                         arg  => "SELECT id FROM users WHERE name='foo'",
648                                                         Query_time => 3,
649                                                         foo  => 'Number 3 long string, but I\'ll exceed the line length so I\'ll only show up as "more" :-('
650                                                      };
651                                                   
652                                                   $expected = <<EOF;
653                                                   # Query 1: 1 QPS, 2x concurrency, ID 0x82860EDA9A88FCC5 at byte 0 ________
654                                                   # This item is included in the report because it matches --limit.
655                                                   #              pct   total     min     max     avg     95%  stddev  median
656                                                   # Count        100       3
657                                                   # Exec time    100      6s      1s      3s      2s      3s   780ms      2s
658                                                   # foo                    3 Hi.  I'm a... (1/33%), Me too! I'... (1/33%)... 1 more
659                                                   EOF
660                                                   
661                                                   foreach my $event (@$events) {
662                                                      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
663                                                      $ea->aggregate($event);
664                                                   }
665                                                   $ea->calculate_statistical_metrics();
666                                                   $result = $qrf->event_report(
667                                                      ea      => $ea,
668                                                      select  => [ qw(Query_time foo) ],
669                                                      item    => 'select id from users where name=?',
670                                                      rank    => 1,
671                                                      orderby => 'Query_time',
672                                                      reason  => 'top',
673                                                   );
674                                                   
675                                                   is(
676                                                      $result,
677                                                      $expected, 'Truncate multiple strings longer than whole line'
678                                                   );
679                                                   
680                                                   # #############################################################################
681                                                   # Issue 478: mk-query-digest doesn't count errors and hosts right
682                                                   # #############################################################################
683                                                   
684                                                   # We decided that string attribs shouldn't be listed in the global header.
685                                                   $events = [
686                                                      {
687                                                         cmd           => 'Query',
688                                                         arg           => "SELECT id FROM users WHERE name='foo'",
689                                                         Query_time    => '8.000652',
690                                                         user          => 'bob',
691                                                      },
692                                                      {
693                                                         cmd           => 'Query',
694                                                         arg           => "SELECT id FROM users WHERE name='foo'",
695                                                         Query_time    => '1.001943',
696                                                         user          => 'bob',
697                                                      },
698                                                      {
699                                                         cmd           => 'Query',
700                                                         arg           => "SELECT id FROM users WHERE name='bar'",
701                                                         Query_time    => '1.000682',
702                                                         user          => 'bob',
703                                                      }
704                                                   ];
705                                                   $expected = <<EOF;
706                                                   # Overall: 3 total, 1 unique, 0 QPS, 0x concurrency ______________________
707                                                   #                    total     min     max     avg     95%  stddev  median
708                                                   # Exec time            10s      1s      8s      3s      8s      3s   992ms
709                                                   EOF
710                                                   
711                                                   $ea  = new EventAggregator(
712                                                      groupby => 'fingerprint',
713                                                      worst   => 'Query_time',
714                                                      ignore_attributes => [qw(arg cmd)],
715                                                   );
716                                                   foreach my $event (@$events) {
717                                                      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
718                                                      $ea->aggregate($event);
719                                                   }
720                                                   $ea->calculate_statistical_metrics();
721                                                   $result = $qrf->header(
722                                                      ea      => $ea,
723                                                      select  => $ea->get_attributes(),
724                                                      orderby => 'Query_time',
725                                                   );
726                                                   
727                                                   is($result, $expected, 'No string attribs in global report (issue 478)');
728                                                   
729                                                   # #############################################################################
730                                                   # Issue 744: Option to show all Hosts
731                                                   # #############################################################################
732                                                   
733                                                   # Don't shorten IP addresses.
734                                                   $events = [
735                                                      {
736                                                         cmd        => 'Query',
737                                                         arg        => "foo",
738                                                         Query_time => '8.000652',
739                                                         host       => '123.123.123.456',
740                                                      },
741                                                      {
742                                                         cmd        => 'Query',
743                                                         arg        => "foo",
744                                                         Query_time => '8.000652',
745                                                         host       => '123.123.123.789',
746                                                      },
747                                                   ];
748                                                   $expected = <<EOF;
749                                                   # Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
750                                                   #              pct   total     min     max     avg     95%  stddev  median
751                                                   # Count        100       2
752                                                   # Exec time    100     16s      8s      8s      8s      8s       0      8s
753                                                   # Hosts                  2 123.123.123.456 (1/50%)... 1 more
754                                                   EOF
755                                                   
756                                                   $ea  = new EventAggregator(
757                                                      groupby => 'arg',
758                                                      worst   => 'Query_time',
759                                                      ignore_attributes => [qw(arg cmd)],
760                                                   );
761                                                   foreach my $event (@$events) {
762                                                      $ea->aggregate($event);
763                                                   }
764                                                   $ea->calculate_statistical_metrics();
765                                                   $result = $qrf->event_report(
766                                                      ea      => $ea,
767                                                      select  => [ qw(Query_time host) ],
768                                                      item    => 'foo',
769                                                      rank    => 1,
770                                                      orderby => 'Query_time',
771                                                   );
772                                                   
773                                                   is($result, $expected, "IPs not shortened");
774                                                   
775                                                   # Add another event so we get "... N more" to make sure that IPs
776                                                   # are still not shortened.
777                                                   push @$events, 
778                                                      {
779                                                         cmd        => 'Query',
780                                                         arg        => "foo",
781                                                         Query_time => '8.000652',
782                                                         host       => '123.123.123.999',
783                                                      };
784                                                   $ea->aggregate($events->[-1]);
785                                                   $ea->calculate_statistical_metrics();
786                                                   $result = $qrf->event_report(
787                                                      ea      => $ea,
788                                                      select  => [ qw(Query_time host) ],
789                                                      item    => 'foo',
790                                                      rank    => 1,
791                                                      orderby => 'Query_time',
792                                                   );
793                                                   
794                                                   $expected = <<EOF;
795                                                   # Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
796                                                   #              pct   total     min     max     avg     95%  stddev  median
797                                                   # Count        100       3
798                                                   # Exec time    100     24s      8s      8s      8s      8s       0      8s
799                                                   # Hosts                  3 123.123.123.456 (1/33%)... 2 more
800                                                   EOF
801                                                   is($result, $expected, "IPs not shortened with more");
802                                                   
803                                                   # Test show_all.
804                                                   @ARGV = qw(--show-all host);
805                                                   $o->get_opts();
806                                                   $result = $qrf->event_report(
807                                                      ea       => $ea,
808                                                      select   => [ qw(Query_time host) ],
809                                                      item     => 'foo',
810                                                      rank     => 1,
811                                                      orderby  => 'Query_time',
812                                                   );
813                                                   
814                                                   $expected = <<EOF;
815                                                   # Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
816                                                   #              pct   total     min     max     avg     95%  stddev  median
817                                                   # Count        100       3
818                                                   # Exec time    100     24s      8s      8s      8s      8s       0      8s
819                                                   # Hosts                  3 123.123.123.456 (1/33%), 123.123.123.789 (1/33%), 123.123.123.999 (1/33%)
820                                                   EOF
821                                                   is($result, $expected, "Show all hosts");
822                                                   
823                                                   # #############################################################################
824                                                   # Issue 948: mk-query-digest treats InnoDB_rec_lock_wait value as number
825                                                   # instead of time
826                                                   # #############################################################################
827                                                   
828                                                   $events = [
829                                                      {
830                                                         cmd        => 'Query',
831                                                         arg        => "foo",
832                                                         Query_time => '8.000652',
833                                                         InnoDB_rec_lock_wait => 0.001,
834                                                         InnoDB_IO_r_wait     => 0.002,
835                                                         InnoDB_queue_wait    => 0.003,
836                                                      },
837                                                   ];
838                                                   $expected = <<EOF;
839                                                   # Item 1: 0 QPS, 0x concurrency, ID 0xEDEF654FCCC4A4D8 at byte 0 _________
840                                                   #              pct   total     min     max     avg     95%  stddev  median
841                                                   # Count        100       1
842                                                   # Exec time    100      8s      8s      8s      8s      8s       0      8s
843                                                   # IDB IO rw    100     2ms     2ms     2ms     2ms     2ms       0     2ms
844                                                   # IDB queue    100     3ms     3ms     3ms     3ms     3ms       0     3ms
845                                                   # IDB rec l    100     1ms     1ms     1ms     1ms     1ms       0     1ms
846                                                   EOF
847                                                   
848                                                   $ea  = new EventAggregator(
849                                                      groupby => 'arg',
850                                                      worst   => 'Query_time',
851                                                      ignore_attributes => [qw(arg cmd)],
852                                                   );
853                                                   foreach my $event (@$events) {
854                                                      $ea->aggregate($event);
855                                                   }
856                                                   $ea->calculate_statistical_metrics();
857                                                   $result = $qrf->event_report(
858                                                      ea      => $ea,
859                                                      select  => [ qw(Query_time InnoDB_rec_lock_wait InnoDB_IO_r_wait InnoDB_queue_wait) ],
860                                                      item    => 'foo',
861                                                      rank    => 1,
862                                                      orderby => 'Query_time',
863                                                   );
864                                                   
865                                                   is($result, $expected, "_wait attribs treated as times (issue 948)");
866                                                   
867                                                   
868                                                   # #############################################################################
869                                                   # print_reports()
870                                                   # #############################################################################
871                                                   $events = [
872                                                      {
873                                                         cmd         => 'Query',
874                                                         arg         => "select col from tbl where id=42",
875                                                         fingerprint => "select col from tbl where id=?",
876                                                         Query_time  => '1.000652',
877                                                         Lock_time   => '0.001292',
878                                                         ts          => '071015 21:43:52',
879                                                         pos_in_log  => 123,
880                                                         db          => 'foodb',
881                                                      },
882                                                   ];
883                                                   $ea = new EventAggregator(
884                                                      groupby => 'fingerprint',
885                                                      worst   => 'Query_time',
886                                                   );
887                                                   foreach my $event ( @$events ) {
888                                                      $ea->aggregate($event);
889                                                   }
890                                                   $ea->calculate_statistical_metrics();
891                                                   
892                                                   # Reset opts in case anything above left something set.
893                                                   @ARGV = qw();
894                                                   $o->get_opts();
895                                                   
896                                                   # Normally, the report subs will make their own ReportFormatter but
897                                                   # that package isn't visible to QueryReportFormatter right now so we
898                                                   # make ReportFormatters and pass them in.  Since ReporFormatters can't
899                                                   # be shared, we can only test one subreport at a time, else the
900                                                   # prepared statements subreport will reuse/reprint stuff from the
901                                                   # profile subreport.
902                                                   my $report = new ReportFormatter(line_width=>74, long_last_column=>1);
903                                                   
904                                                   ok(
905                                                      no_diff(
906                                                         sub { $qrf->print_reports(
907                                                            reports => [qw(header query_report profile)],
908                                                            ea      => $ea,
909                                                            worst   => [['select col from tbl where id=?','top']],
910                                                            orderby => 'Query_time',
911                                                            groupby => 'fingerprint',
912                                                            ReportFormatter => $report,
913                                                         ); },
914                                                         "common/t/samples/QueryReportFormatter/reports001.txt",
915                                                      ),
916                                                      "print_reports(header, query_report, profile)"
917                                                   );
918                                                   
919                                                   $report = new ReportFormatter(line_width=>74, long_last_column=>1);
920                                                   
921                                                   ok(
922                                                      no_diff(
923                                                         sub { $qrf->print_reports(
924                                                            reports => [qw(profile query_report header)],
925                                                            ea      => $ea,
926                                                            worst   => [['select col from tbl where id=?','top']],
927                                                            orderby => 'Query_time',
928                                                            groupby => 'fingerprint',
929                                                            ReportFormatter => $report,
930                                                         ); },
931                                                         "common/t/samples/QueryReportFormatter/reports003.txt",
932                                                      ),
933                                                      "print_reports(profile, query_report, header)",
934                                                   );
935                                                   
936                                                   $events = [
937                                                      {
938                                                         Query_time    => '0.000286',
939                                                         Warning_count => 0,
940                                                         arg           => 'PREPARE SELECT i FROM d.t WHERE i=?',
941                                                         fingerprint   => 'prepare select i from d.t where i=?',
942                                                         bytes         => 35,
943                                                         cmd           => 'Query',
944                                                         db            => undef,
945                                                         pos_in_log    => 0,
946                                                         ts            => '091208 09:23:49.637394',
947                                                         Statement_id  => 2,
948                                                      },
949                                                      {
950                                                         Query_time    => '0.030281',
951                                                         Warning_count => 0,
952                                                         arg           => 'EXECUTE SELECT i FROM d.t WHERE i="3"',
953                                                         fingerprint   => 'execute select i from d.t where i=?',
954                                                         bytes         => 37,
955                                                         cmd           => 'Query',
956                                                         db            => undef,
957                                                         pos_in_log    => 1106,
958                                                         ts            => '091208 09:23:49.637892',
959                                                         Statement_id  => 2,
960                                                      },
961                                                   ];
962                                                   $ea = new EventAggregator(
963                                                      groupby => 'fingerprint',
964                                                      worst   => 'Query_time',
965                                                   );
966                                                   foreach my $event ( @$events ) {
967                                                      $ea->aggregate($event);
968                                                   }
969                                                   $ea->calculate_statistical_metrics();
970                                                   $report = new ReportFormatter(
971                                                      line_width       => 74,
972                                                      long_last_column => 1, 
973                                                      extend_right     => 1
974                                                   );
975                                                   ok(
976                                                      no_diff(
977                                                         sub {
978                                                            $qrf->print_reports(
979                                                               reports => ['query_report','prepared'],
980                                                               ea      => $ea,
981                                                               worst   => [
982                                                                  ['execute select i from d.t where i=?', 'top'],
983                                                                  ['prepare select i from d.t where i=?', 'top'],
984                                                               ],
985                                                               orderby => 'Query_time',
986                                                               groupby => 'fingerprint',
987                                                               ReportFormatter => $report,
988                                                            );
989                                                         },
990                                                         "common/t/samples/QueryReportFormatter/reports002.txt",
991                                                      ),
992                                                      "print_reports(query_report, prepared)"
993                                                   );
994                                                   
995                                                   
996                                                   # #############################################################################
997                                                   # EXPLAIN report
998                                                   # #############################################################################
999                                                   SKIP: {
1000                                                     skip 'Cannot connect to sandbox master', 1 unless $dbh;
1001                                                     $sb->load_file('master', "common/t/samples/QueryReportFormatter/table.sql");
1002                                                  
1003                                                     # Normally dbh would be passed to QueryReportFormatter::new().  If it's
1004                                                     # set earlier then previous tests cause EXPLAIN failures due to their
1005                                                     # fake dbs.
1006                                                     $qrf->{dbh} = $dbh;
1007                                                  
1008                                                     my $explain =
1009                                                  "# *************************** 1. row ***************************
1010                                                  #            id: 1
1011                                                  #   select_type: SIMPLE
1012                                                  #         table: t
1013                                                  "
1014                                                  . (($sandbox_version || '') ge '5.1' ? "#    partitions: NULL\n" : '') .
1015                                                  "#          type: const
1016                                                  # possible_keys: PRIMARY
1017                                                  #           key: PRIMARY
1018                                                  #       key_len: 4
1019                                                  #           ref: const
1020                                                  #          rows: 1
1021                                                  #         Extra: 
1022                                                  ";
1023                                                  
1024                                                     is(
1025                                                        $qrf->explain_report("select * from qrf.t where i=2", 'qrf'),
1026                                                        $explain,
1027                                                        "explain_report()"
1028                                                     );
1029                                                  
1030                                                     $sb->wipe_clean($dbh);
1031                                                     $dbh->disconnect();
1032                                                  }
1033                                                  
1034                                                  
1035                                                  # #############################################################################
1036                                                  # files and date reports.
1037                                                  # #############################################################################
1038                                                  like(
1039                                                     $qrf->date(),
1040                                                     qr/# Current date: .+?\d+:\d+:\d+/,
1041                                                     "date report"
1042                                                  );
1043                                                  
1044                                                  is(
1045                                                     $qrf->files(files=>[qw(foo bar)]),
1046                                                     "# Files: foo, bar\n",
1047                                                     "files report"
1048                                                  );
1049                                                  
1050                                                  # #############################################################################
1051                                                  # Test report grouping.
1052                                                  # #############################################################################
1053                                                  $events = [
1054                                                     {
1055                                                        cmd         => 'Query',
1056                                                        arg         => "select col from tbl where id=42",
1057                                                        fingerprint => "select col from tbl where id=?",
1058                                                        Query_time  => '1.000652',
1059                                                        Lock_time   => '0.001292',
1060                                                        ts          => '071015 21:43:52',
1061                                                        pos_in_log  => 123,
1062                                                        db          => 'foodb',
1063                                                     },
1064                                                  ];
1065                                                  $ea = new EventAggregator(
1066                                                     groupby => 'fingerprint',
1067                                                     worst   => 'Query_time',
1068                                                  );
1069                                                  foreach my $event ( @$events ) {
1070                                                     $ea->aggregate($event);
1071                                                  }
1072                                                  $ea->calculate_statistical_metrics();
1073                                                  @ARGV = qw();
1074                                                  $o->get_opts();
1075                                                  $report = new ReportFormatter(line_width=>74, long_last_column=>1);
1076                                                  $qrf    = new QueryReportFormatter(
1077                                                     OptionParser  => $o,
1078                                                     QueryRewriter => $qr,
1079                                                     QueryParser   => $qp,
1080                                                     Quoter        => $q, 
1081                                                  );
1082                                                  my $output = output(
1083                                                     sub { $qrf->print_reports(
1084                                                        reports => [qw(rusage date files header query_report profile)],
1085                                                        ea      => $ea,
1086                                                        worst   => [['select col from tbl where id=?','top']],
1087                                                        orderby => 'Query_time',
1088                                                        groupby => 'fingerprint',
1089                                                        files   => [qw(foo bar)],
1090                                                        group   => {map {$_=>1} qw(rusage date files header)},
1091                                                        ReportFormatter => $report,
1092                                                     ); }
1093                                                  );
1094                                                  like(
1095                                                     $output,
1096                                                     qr/
1097                                                  ^#\s.+?\suser time.+?vsz$
1098                                                  ^#\sCurrent date:.+?$
1099                                                  ^#\sFiles:\sfoo,\sbar$
1100                                                     /mx,
1101                                                     "grouped reports"
1102                                                  );
1103                                                  
1104                                                  # #############################################################################
1105                                                  # Done.
1106                                                  # #############################################################################
1107                                                  $output = '';
1108                                                  {
1109                                                     local *STDERR;
1110                                                     open STDERR, '>', \$output;
1111                                                     $qrf->_d('Complete test coverage');
1112                                                  }
1113                                                  like(
1114                                                     $output,
1115                                                     qr/Complete test coverage/,
1116                                                     '_d() works'
1117                                                  );
1118                                                  exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
3821  ***     50      0      3   unless defined $group_by_val
3829  ***     50      0      1   unless open my $fh, '<', $file
3839  ***     50      0      1   if $EVAL_ERROR
4314  ***     50      0      1   unless $dbh
4323  ***     50      1      0   ($sandbox_version || '') ge '5.1' ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
4323  ***     50      1      0   $sandbox_version || ''


Covered Subroutines
-------------------

Subroutine       Count Location                   
---------------- ----- ---------------------------
BEGIN                1 QueryReportFormatter.t:10  
BEGIN                1 QueryReportFormatter.t:11  
BEGIN                1 QueryReportFormatter.t:12  
BEGIN                1 QueryReportFormatter.t:14  
BEGIN                1 QueryReportFormatter.t:15  
BEGIN                1 QueryReportFormatter.t:16  
BEGIN                1 QueryReportFormatter.t:17  
BEGIN                1 QueryReportFormatter.t:18  
BEGIN                1 QueryReportFormatter.t:19  
BEGIN                1 QueryReportFormatter.t:20  
BEGIN                1 QueryReportFormatter.t:21  
BEGIN                1 QueryReportFormatter.t:22  
BEGIN                1 QueryReportFormatter.t:23  
BEGIN                1 QueryReportFormatter.t:24  
BEGIN                1 QueryReportFormatter.t:25  
BEGIN                1 QueryReportFormatter.t:3806
BEGIN                1 QueryReportFormatter.t:4   
BEGIN                1 QueryReportFormatter.t:9   
__ANON__             3 QueryReportFormatter.t:3819
__ANON__             3 QueryReportFormatter.t:3826
__ANON__             4 QueryReportFormatter.t:3831
__ANON__             7 QueryReportFormatter.t:3832
__ANON__             1 QueryReportFormatter.t:4221
__ANON__             1 QueryReportFormatter.t:4238
__ANON__             1 QueryReportFormatter.t:4293
__ANON__             1 QueryReportFormatter.t:4405
report_from_file     1 QueryReportFormatter.t:3810


