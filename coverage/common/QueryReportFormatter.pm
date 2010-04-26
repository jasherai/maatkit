---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...n/QueryReportFormatter.pm   94.1   68.8   57.0  100.0    0.0   14.9   80.6
QueryReportFormatter.t         98.1   50.0   33.3  100.0    n/a   85.1   96.0
Total                          95.5   67.9   56.4  100.0    0.0  100.0   84.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Mon Apr 26 16:21:44 2010
Finish:       Mon Apr 26 16:21:44 2010

Run:          QueryReportFormatter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Mon Apr 26 16:21:46 2010
Finish:       Mon Apr 26 16:21:47 2010

/home/daniel/dev/maatkit/common/QueryReportFormatter.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2009 Percona Inc.
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
19                                                    # QueryReportFormatter package $Revision: 6138 $
20                                                    # ###########################################################################
21                                                    package QueryReportFormatter;
22                                                    
23             1                    1             5   use strict;
               1                                  2   
               1                                  7   
24             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26                                                    
27                                                    Transformers->import(qw(
28                                                       shorten micro_t parse_timestamp unix_timestamp make_checksum percentage_of
29                                                    ));
30                                                    
31    ***      1            50      1             8   use constant MKDEBUG           => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 19   
32             1                    1             6   use constant LINE_LENGTH       => 74;
               1                                  2   
               1                                  5   
33             1                    1             5   use constant MAX_STRING_LENGTH => 10;
               1                                  3   
               1                                 11   
34                                                    
35                                                    # Special formatting functions
36                                                    my %formatting_function = (
37                                                       ts => sub {
38                                                          my ( $vals ) = @_;
39                                                          my $min = parse_timestamp($vals->{min} || '');
40                                                          my $max = parse_timestamp($vals->{max} || '');
41                                                          return $min && $max ? "$min to $max" : '';
42                                                       },
43                                                    );
44                                                    
45                                                    # Arguments:
46                                                    #   * OptionParser
47                                                    #   * QueryRewriter
48                                                    #   * Quoter
49                                                    # Optional arguments:
50                                                    #   * QueryReview    Used in query_report()
51                                                    #   * dbh            Used in explain_report()
52                                                    sub new {
53    ***      1                    1      0     12      my ( $class, %args ) = @_;
54             1                                  5      foreach my $arg ( qw(OptionParser QueryRewriter Quoter) ) {
55    ***      3     50                          17         die "I need a $arg argument" unless $args{$arg};
56                                                       }
57                                                    
58                                                       # If ever someone wishes for a wider label width.
59    ***      1            50                   10      my $label_width = $args{label_width} || 9;
60             1                                  2      MKDEBUG && _d('Label width:', $label_width);
61                                                    
62             1                                 15      my $self = {
63                                                          %args,
64                                                          bool_format => '# %3s%% %-6s %s',
65                                                          label_width => $label_width,
66                                                          dont_print  => {
67                                                             header => {
68                                                                user       => 1,
69                                                                db         => 1,
70                                                                pos_in_log => 1,
71                                                             },
72                                                             query_report => {
73                                                                pos_in_log => 1,
74                                                             }
75                                                          },
76                                                       };
77             1                                 17      return bless $self, $class;
78                                                    }
79                                                    
80                                                    # Arguments:
81                                                    #   * reports       arrayref: reports to print
82                                                    #   * ea            obj: EventAggregator
83                                                    #   * worst         arrayref: worst items
84                                                    #   * orderby       scalar: attrib worst items ordered by
85                                                    #   * groupby       scalar: attrib worst items grouped by
86                                                    # Optional args:
87                                                    #   * print_header  bool: "Report grouped by" header
88                                                    # Prints the given reports (rusage, heade (global), query_report, etc.) in
89                                                    # the given order.  These usually come from mk-query-digest --report-format.
90                                                    # Most of the required args are for header() and query_report().
91                                                    sub print_reports {
92    ***      3                    3      0     45      my ( $self, %args ) = @_;
93             3                                 23      foreach my $arg ( qw(reports ea worst orderby groupby) ) {
94    ***     15     50                          67         die "I need a $arg argument" unless exists $args{$arg};
95                                                       }
96             3                                 12      my $reports = $args{reports};
97                                                    
98    ***      3     50                          13      if ( $args{print_header} ) {
99    ***      0                                  0         print "\n# ", ( '#' x 72 ), "\n";
100   ***      0                                  0         print "# Report grouped by $args{groupby}\n";
101   ***      0                                  0         print '# ', ( '#' x 72 ), "\n";
102                                                      }
103                                                   
104            3                                 12      foreach my $report ( @$reports ) {
105            8                               2683         MKDEBUG && _d('Printing', $report, 'report'); 
106            8                                 87         print "\n", $self->$report(%args);
107                                                      }
108                                                   
109            3                               6006      return;
110                                                   }
111                                                   
112                                                   sub rusage {
113   ***      1                    1      0      4      my ( $self ) = @_;
114            1                                  8      my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
115            1                                  4      my $rusage = '';
116            1                                  3      eval {
117            1                              10204         my $mem = `ps -o rss,vsz -p $PID 2>&1`;
118            1                                 42         ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
119            1                                 15         ( $user, $system ) = times();
120   ***      1            50                   27         $rusage = sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
      ***                   50                        
121                                                            micro_t( $user,   p_s => 1, p_ms => 1 ),
122                                                            micro_t( $system, p_s => 1, p_ms => 1 ),
123                                                            shorten( ($rss || 0) * 1_024 ),
124                                                            shorten( ($vsz || 0) * 1_024 );
125                                                      };
126   ***      1     50                           5      if ( $EVAL_ERROR ) {
127   ***      0                                  0         MKDEBUG && _d($EVAL_ERROR);
128                                                      }
129   ***      1     50                          12      return $rusage ? $rusage : "# Could not get rusage\n";
130                                                   }
131                                                   
132                                                   # Arguments:
133                                                   #   * ea         obj: EventAggregator
134                                                   #   * orderby    scalar: attrib items ordered by
135                                                   # Optional arguments:
136                                                   #   * select     arrayref: attribs to print
137                                                   #   * zero_bool  bool: print zero bool values (0%)
138                                                   # Print a report about the global statistics in the EventAggregator.
139                                                   # Formerly called "global_report()."
140                                                   sub header {
141   ***      7                    7      0     79      my ( $self, %args ) = @_;
142            7                                 54      foreach my $arg ( qw(ea orderby) ) {
143   ***     14     50                          81         die "I need a $arg argument" unless $args{$arg};
144                                                      }
145            7                                 24      my $ea      = $args{ea};
146            7                                 23      my $orderby = $args{orderby};
147                                                   
148            7                                 35      my $dont_print = $self->{dont_print}->{header};
149            7                                 41      my $results    = $ea->results();
150            7                                157      my @result;
151                                                   
152                                                      # Get global count
153   ***      7            50                   48      my $global_cnt = $results->{globals}->{$orderby}->{cnt} || 0;
154                                                   
155                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
156            7                                 31      my ($qps, $conc) = (0, 0);
157   ***      7    100     66                  151      if ( $global_cnt && $results->{globals}->{ts}
      ***                   50                        
      ***                   50                        
                           100                        
158                                                         && ($results->{globals}->{ts}->{max} || '')
159                                                            gt ($results->{globals}->{ts}->{min} || '')
160                                                      ) {
161            3                                 11         eval {
162            3                                 29            my $min  = parse_timestamp($results->{globals}->{ts}->{min});
163            3                                214            my $max  = parse_timestamp($results->{globals}->{ts}->{max});
164            3                                113            my $diff = unix_timestamp($max) - unix_timestamp($min);
165   ***      3            50                  550            $qps     = $global_cnt / ($diff || 1);
166            3                                672            $conc    = $results->{globals}->{$args{orderby}}->{sum} / $diff;
167                                                         };
168                                                      }
169                                                   
170                                                      # First line
171                                                      MKDEBUG && _d('global_cnt:', $global_cnt, 'unique:',
172            7                                 20         scalar keys %{$results->{classes}}, 'qps:', $qps, 'conc:', $conc);
173            7                                381      my $line = sprintf(
174                                                         '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
175                                                         shorten($global_cnt, d=>1_000),
176            7           100                   47         shorten(scalar keys %{$results->{classes}}, d=>1_000),
                           100                        
177                                                         shorten($qps  || 0, d=>1_000),
178                                                         shorten($conc || 0, d=>1_000));
179            7                                 51      $line .= ('_' x (LINE_LENGTH - length($line) + $self->{label_width} - 9));
180            7                                 27      push @result, $line;
181                                                   
182                                                      # Column header line
183            7                                 46      my ($format, @headers) = $self->make_header('global');
184            7                                 48      push @result, sprintf($format, '', @headers);
185                                                   
186                                                      # Each additional line
187            7    100                          51      my $attribs = $args{select} ? $args{select} : $ea->get_attributes();
188            7                                 81      foreach my $attrib ( $self->sorted_attribs($attribs, $ea) ) {
189           38    100                         172         next if $dont_print->{$attrib};
190           33                                140         my $attrib_type = $ea->type_for($attrib);
191           33    100                         490         next unless $attrib_type; 
192   ***     30     50                         184         next unless exists $results->{globals}->{$attrib};
193           30    100                         189         if ( $formatting_function{$attrib} ) { # Handle special cases
194           60                                192            push @result, sprintf $format, $self->make_label($attrib),
195                                                               $formatting_function{$attrib}->($results->{globals}->{$attrib}),
196            6                                 26               (map { '' } 0..9); # just for good measure
197                                                         }
198                                                         else {
199           24                                 95            my $store = $results->{globals}->{$attrib};
200           24                                 56            my @values;
201           24    100                         128            if ( $attrib_type eq 'num' ) {
                    100                               
      ***            50                               
202           16    100                         132               my $func    = $attrib =~ m/time|wait$/ ? \&micro_t : \&shorten;
203           16                                 76               my $metrics = $ea->stats()->{globals}->{$attrib};
204           16                                105               @values = (
205           16                                106                  @{$store}{qw(sum min max)},
206                                                                  $store->{sum} / $store->{cnt},
207           16                                298                  @{$metrics}{qw(pct_95 stddev median)},
208                                                               );
209   ***     16     50                          64               @values = map { defined $_ ? $func->($_) : '' } @values;
             112                               5377   
210                                                            }
211                                                            elsif ( $attrib_type eq 'string' ) {
212            4                                 10               MKDEBUG && _d('Ignoring string attrib', $attrib);
213            4                                 14               next;
214                                                            }
215                                                            elsif ( $attrib_type eq 'bool' ) {
216   ***      4    100     66                   42               if ( $store->{sum} > 0 || $args{zero_bool} ) {
217            3                                 17                  push @result,
218                                                                     sprintf $self->{bool_format},
219                                                                        $self->format_bool_attrib($store), $attrib;
220                                                               }
221                                                            }
222                                                            else {
223   ***      0                                  0               @values = ('', $store->{min}, $store->{max}, '', '', '', '');
224                                                            }
225                                                   
226           20    100                         909            push @result, sprintf $format, $self->make_label($attrib), @values
227                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
228                                                         }
229                                                      }
230                                                   
231            7                                 31      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              39                                204   
              39                                203   
232                                                   }
233                                                   
234                                                   # Arguments:
235                                                   #   * ea       obj: EventAggregator
236                                                   #   * worst    arrayref: worst items
237                                                   #   * orderby  scalar: attrib worst items ordered by
238                                                   #   * groupby  scalar: attrib worst items grouped by
239                                                   # Optional arguments:
240                                                   #   * select   arrayref: attribs to print
241                                                   sub query_report {
242   ***      3                    3      0     30      my ( $self, %args ) = @_;
243            3                                 25      foreach my $arg ( qw(ea worst orderby groupby) ) {
244   ***     12     50                          55         die "I need a $arg argument" unless defined $arg;
245                                                      }
246            3                                 12      my $ea      = $args{ea};
247            3                                 10      my $groupby = $args{groupby};
248            3                                 10      my $worst   = $args{worst};
249            3                                 14      my $n_worst = scalar @$worst;
250                                                   
251            3                                 16      my $o   = $self->{OptionParser};
252            3                                 18      my $q   = $self->{Quoter};
253            3                                 11      my $qv  = $self->{QueryReview};
254            3                                 11      my $qr  = $self->{QueryRewriter};
255                                                   
256            3                                 11      my $report = '';
257                                                   
258                                                      # Print each worst item: its stats/metrics (sum/min/max/95%/etc.),
259                                                      # Query_time distro chart, tables, EXPLAIN, fingerprint, etc.
260                                                      # Items are usually unique queries/fingerprints--depends on how
261                                                      # the events were grouped.
262                                                      ITEM:
263            3                                 16      foreach my $rank ( 1..$n_worst ) {
264            4                                 27         my $item       = $worst->[$rank - 1]->[0];
265            4                                 24         my $stats      = $ea->results->{classes}->{$item};
266            4                                104         my $sample     = $ea->results->{samples}->{$item};
267   ***      4            50                  124         my $samp_query = $sample->{arg} || '';
268   ***      4     50                          20         my $reason     = $args{explain_why} ? $worst->[$rank - 1]->[1] : '';
269                                                   
270                                                         # ###############################################################
271                                                         # Possibly skip item for --review.
272                                                         # ###############################################################
273            4                                 14         my $review_vals;
274   ***      4     50                          16         if ( $qv ) {
275   ***      0                                  0            $review_vals = $qv->get_review_info($item);
276   ***      0      0      0                    0            next ITEM if $review_vals->{reviewed_by} && !$o->get('report-all');
277                                                         }
278                                                   
279                                                         # ###############################################################
280                                                         # Get tables for --for-explain.
281                                                         # ###############################################################
282   ***      0                                  0         my ($default_db) = $sample->{db}       ? $sample->{db}
283   ***      4     50                          29                          : $stats->{db}->{unq} ? keys %{$stats->{db}->{unq}}
                    100                               
284                                                                          :                       undef;
285            4                                 12         my @tables;
286   ***      4     50                          40         if ( $o->get('for-explain') ) {
287            4                                143            @tables = $self->extract_tables($samp_query, $default_db);
288                                                         }
289                                                   
290                                                         # ###############################################################
291                                                         # Print the standard query analysis report.
292                                                         # ###############################################################
293            4    100                          19         $report .= "\n" if $rank > 1;  # space between each event report
294            4                                 32         $report .= $self->event_report(
295                                                            %args,
296                                                            item  => $item,
297                                                            rank   => $rank,
298                                                            reason => $reason,
299                                                         );
300                                                   
301   ***      4     50                          30         if ( $o->get('report-histogram') ) {
302            4                                119            $report .= $self->chart_distro(
303                                                               %args,
304                                                               attrib => $o->get('report-histogram'),
305                                                               item   => $item,
306                                                            );
307                                                         }
308                                                   
309   ***      4     50     33                   26         if ( $qv && $review_vals ) {
310                                                            # Print the review information that is already in the table
311                                                            # before putting anything new into the table.
312   ***      0                                  0            $report .= "# Review information\n";
313   ***      0                                  0            foreach my $col ( $qv->review_cols() ) {
314   ***      0                                  0               my $val = $review_vals->{$col};
315   ***      0      0      0                    0               if ( !$val || $val ne '0000-00-00 00:00:00' ) { # issue 202
316   ***      0      0                           0                  $report .= sprintf "# %13s: %-s\n", $col, ($val ? $val : '');
317                                                               }
318                                                            }
319                                                         }
320                                                   
321   ***      4     50                          18         if ( $groupby eq 'fingerprint' ) {
322                                                            # Shorten it if necessary (issue 216 and 292).           
323   ***      4     50                          23            $samp_query = $qr->shorten($samp_query, $o->get('shorten'))
324                                                               if $o->get('shorten');
325                                                   
326                                                            # Print query fingerprint.
327   ***      4     50                          87            $report .= "# Fingerprint\n#    $item\n"
328                                                               if $o->get('fingerprints');
329                                                   
330                                                            # Print tables used by query.
331   ***      4     50                         104            $report .= $self->tables_report(@tables)
332                                                               if $o->get('for-explain');
333                                                   
334            4    100                          35            if ( $item =~ m/^(?:[\(\s]*select|insert|replace)/ ) {
335   ***      2     50                          13               if ( $item =~ m/^(?:insert|replace)/ ) { # No EXPLAIN
336   ***      0                                  0                  $report .= "$samp_query\\G\n";
337                                                               }
338                                                               else {
339            2                                  8                  $report .= "# EXPLAIN\n$samp_query\\G\n"; 
340            2                                 12                  $report .= $self->explain_report($samp_query, $default_db);
341                                                               }
342                                                            }
343                                                            else {
344            2                                  9               $report .= "$samp_query\\G\n"; 
345            2                                 15               my $converted = $qr->convert_to_select($samp_query);
346   ***      2     50     33                   94               if ( $o->get('for-explain')
      ***                   33                        
347                                                                    && $converted
348                                                                    && $converted =~ m/^[\(\s]*select/i ) {
349                                                                  # It converted OK to a SELECT
350            2                                 84                  $report .= "# Converted for EXPLAIN\n# EXPLAIN\n$converted\\G\n";
351                                                               }
352                                                            }
353                                                         }
354                                                         else {
355   ***      0      0                           0            if ( $groupby eq 'tables' ) {
356   ***      0                                  0               my ( $db, $tbl ) = $q->split_unquote($item);
357   ***      0                                  0               $report .= $self->tables_report([$db, $tbl]);
358                                                            }
359   ***      0                                  0            $report .= "$item\n";
360                                                         }
361                                                      }
362                                                   
363            3                                 39      return $report;
364                                                   }
365                                                   
366                                                   # Arguments:
367                                                   #   * ea          obj: EventAggregator
368                                                   #   * item        scalar: Item in ea results
369                                                   #   * orderby     scalar: attribute that events are ordered by
370                                                   # Optional arguments:
371                                                   #   * select     arrayref: attribs to print
372                                                   #   * reason      scalar: why this item is being reported (top|outlier)
373                                                   #   * rank        scalar: item rank among the worst
374                                                   #   * zero_bool   bool: print zero bool values (0%)
375                                                   # Print a report about the statistics in the EventAggregator.
376                                                   # Called by query_report().
377                                                   sub event_report {
378   ***     16                   16      0    173      my ( $self, %args ) = @_;
379           16                                 85      foreach my $arg ( qw(ea item orderby) ) {
380   ***     48     50                         226         die "I need a $arg argument" unless $args{$arg};
381                                                      }
382           16                                 49      my $ea      = $args{ea};
383           16                                 59      my $item    = $args{item};
384           16                                 54      my $orderby = $args{orderby};
385                                                   
386           16                                 71      my $dont_print = $self->{dont_print}->{query_report};
387           16                                 82      my $results    = $ea->results();
388           16                                316      my @result;
389                                                   
390                                                      # Return unless the item exists in the results (it should).
391           16                                 69      my $store = $results->{classes}->{$item};
392   ***     16     50                          62      return "# No such event $item\n" unless $store;
393                                                   
394                                                      # Pick the first attribute to get counts
395           16                                 72      my $global_cnt = $results->{globals}->{$orderby}->{cnt};
396           16                                 61      my $class_cnt  = $store->{$orderby}->{cnt};
397                                                   
398                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
399           16                                 56      my ($qps, $conc) = (0, 0);
400   ***     16    100     66                  306      if ( $global_cnt && $store->{ts}
                           100                        
                           100                        
                           100                        
401                                                         && ($store->{ts}->{max} || '')
402                                                            gt ($store->{ts}->{min} || '')
403                                                      ) {
404            3                                 10         eval {
405            3                                 19            my $min  = parse_timestamp($store->{ts}->{min});
406            3                                145            my $max  = parse_timestamp($store->{ts}->{max});
407            3                                108            my $diff = unix_timestamp($max) - unix_timestamp($min);
408            3                                534            $qps     = $class_cnt / $diff;
409            3                                 17            $conc    = $store->{$orderby}->{sum} / $diff;
410                                                         };
411                                                      }
412                                                   
413                                                      # First line like:
414                                                      # Query 1: 9 QPS, 0x concurrency, ID 0x7F7D57ACDD8A346E at byte 5 ________
415   ***     16    100     50                  259      my $line = sprintf(
                           100                        
                           100                        
                           100                        
416                                                         '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
417                                                         ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
418                                                         $args{rank} || 0,
419                                                         shorten($qps  || 0, d=>1_000),
420                                                         shorten($conc || 0, d=>1_000),
421                                                         make_checksum($item),
422                                                         $results->{samples}->{$item}->{pos_in_log} || 0,
423                                                      );
424           16                                109      $line .= ('_' x (LINE_LENGTH - length($line) + $self->{label_width} - 9));
425           16                                 58      push @result, $line;
426                                                   
427           16    100                          76      if ( $args{reason} ) {
428   ***      5     50                          28         push @result,
429                                                            "# This item is included in the report because it matches "
430                                                               . ($args{reason} eq 'top' ? '--limit.' : '--outliers.');
431                                                      }
432                                                   
433                                                      # Column header line
434           16                                116      my ($format, @headers) = $self->make_header();
435           16                                117      push @result, sprintf($format, '', @headers);
436                                                   
437                                                      # Count line
438          144                                804      push @result, sprintf
439                                                         $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
440           16                                 98            map { '' } (1 ..9);
441                                                   
442                                                      # Each additional line
443           16    100                         108      my $attribs = $args{select} ? $args{select} : $ea->get_attributes();
444           16                                153      foreach my $attrib ( $self->sorted_attribs($attribs, $ea) ) {
445          112    100                         479         next if $dont_print->{$attrib};
446          105                                449         my $attrib_type = $ea->type_for($attrib);
447          105    100                        1528         next unless $attrib_type; 
448   ***     98     50                         401         next unless exists $store->{$attrib};
449           98                                306         my $vals = $store->{$attrib};
450           98    100                         467         next unless scalar %$vals;
451           93    100                         347         if ( $formatting_function{$attrib} ) { # Handle special cases
452           70                                241            push @result, sprintf $format, $self->make_label($attrib),
453                                                               $formatting_function{$attrib}->($vals),
454            7                                 31               (map { '' } 0..9); # just for good measure
455                                                         }
456                                                         else {
457           86                                196            my @values;
458           86                                201            my $pct;
459           86    100                         335            if ( $attrib_type eq 'num' ) {
      ***            50                               
      ***             0                               
460           46    100                         322               my $func    = $attrib =~ m/time|wait$/ ? \&micro_t : \&shorten;
461           46                                205               my $metrics = $ea->stats()->{classes}->{$item}->{$attrib};
462           46                                301               @values = (
463           46                                296                  @{$vals}{qw(sum min max)},
464                                                                  $vals->{sum} / $vals->{cnt},
465           46                                861                  @{$metrics}{qw(pct_95 stddev median)},
466                                                               );
467   ***     46     50                         164               @values = map { defined $_ ? $func->($_) : '' } @values;
             322                              12721   
468           46                               2363               $pct = percentage_of($vals->{sum},
469                                                                  $results->{globals}->{$attrib}->{sum});
470                                                            }
471                                                            elsif ( $attrib_type eq 'string' ) {
472          400                               1160               push @values,
473                                                                  $self->format_string_list($attrib, $vals),
474           40                                181                  (map { '' } 0..9); # just for good measure
475           40                                132               $pct = '';
476                                                            }
477                                                            elsif ( $attrib_type eq 'bool' ) {
478   ***      0      0      0                    0               if ( $vals->{sum} > 0 || $args{zero_bool} ) {
479   ***      0                                  0                  push @result,
480                                                                     sprintf $self->{bool_format},
481                                                                        $self->format_bool_attrib($vals), $attrib;
482                                                               }
483                                                            }
484                                                            else {
485   ***      0                                  0               @values = ('', $vals->{min}, $vals->{max}, '', '', '', '');
486   ***      0                                  0               $pct = 0;
487                                                            }
488                                                   
489   ***     86     50                        1408            push @result, sprintf $format, $self->make_label($attrib), $pct, @values
490                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
491                                                         }
492                                                      }
493                                                   
494           16                                 71      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
             146                                677   
             146                                640   
495                                                   }
496                                                   
497                                                   # Arguments:
498                                                   #  * ea      obj: EventAggregator
499                                                   #  * item    scalar: item in ea results
500                                                   #  * attrib  scalar: item's attribute to chart
501                                                   # Creates a chart of value distributions in buckets.  Right now it bucketizes
502                                                   # into 8 buckets, powers of ten starting with .000001.
503                                                   sub chart_distro {
504   ***      6                    6      0    140      my ( $self, %args ) = @_;
505            6                                 36      foreach my $arg ( qw(ea item attrib) ) {
506   ***     18     50                          88         die "I need a $arg argument" unless $args{$arg};
507                                                      }
508            6                                 19      my $ea     = $args{ea};
509            6                                 22      my $item   = $args{item};
510            6                                 23      my $attrib = $args{attrib};
511                                                   
512            6                                 27      my $results = $ea->results();
513            6                                128      my $store   = $results->{classes}->{$item}->{$attrib};
514            6                                 19      my $vals    = $store->{all};
515   ***      6     50     50                   65      return "" unless defined $vals && scalar @$vals;
516                                                   
517                                                      # TODO: this is broken.
518            6                                 42      my @buck_tens = $ea->buckets_of(10);
519            6                               5220      my @distro = map { 0 } (0 .. 7);
              48                                146   
520            6                                263      map { $distro[$buck_tens[$_]] += $vals->[$_] } (1 .. @$vals - 1);
            5994                              23892   
521                                                   
522            6                                271      my $vals_per_mark; # number of vals represented by 1 #-mark
523            6                                 19      my $max_val        = 0;
524            6                                 14      my $max_disp_width = 64;
525            6                                 21      my $bar_fmt        = "# %5s%s";
526            6                                 42      my @distro_labels  = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
527            6                                 42      my @results        = "# $attrib distribution";
528                                                   
529                                                      # Find the distro with the most values. This will set
530                                                      # vals_per_mark and become the bar at max_disp_width.
531            6                                 32      foreach my $n_vals ( @distro ) {
532           48    100                         193         $max_val = $n_vals if $n_vals > $max_val;
533                                                      }
534            6                                 23      $vals_per_mark = $max_val / $max_disp_width;
535                                                   
536            6                                 44      foreach my $i ( 0 .. $#distro ) {
537           48                                132         my $n_vals  = $distro[$i];
538           48           100                  219         my $n_marks = $n_vals / ($vals_per_mark || 1);
539                                                   
540                                                         # Always print at least 1 mark for any bucket that has at least
541                                                         # 1 value. This skews the graph a tiny bit, but it allows us to
542                                                         # see all buckets that have values.
543   ***     48     50     66                  348         $n_marks = 1 if $n_marks < 1 && $n_vals > 0;
544                                                   
545           48    100                         203         my $bar = ($n_marks ? '  ' : '') . '#' x $n_marks;
546           48                                243         push @results, sprintf $bar_fmt, $distro_labels[$i], $bar;
547                                                      }
548                                                   
549            6                                191      return join("\n", @results) . "\n";
550                                                   }
551                                                   
552                                                   # Profile subreport (issue 381).
553                                                   # Arguments:
554                                                   #   * ea            obj: EventAggregator
555                                                   #   * worst         arrayref: worst items
556                                                   #   * groupby       scalar: attrib worst items grouped by
557                                                   # Optional arguments:
558                                                   #   * distill_args     hashref: extra args for distill()
559                                                   #   * ReportFormatter  obj: passed-in ReportFormatter for testing
560                                                   sub profile {
561   ***      2                    2      0     15      my ( $self, %args ) = @_;
562            2                                 11      foreach my $arg ( qw(ea worst groupby) ) {
563   ***      6     50                          29         die "I need a $arg argument" unless defined $arg;
564                                                      }
565            2                                  8      my $ea      = $args{ea};
566            2                                  6      my $worst   = $args{worst};
567            2                                  7      my $groupby = $args{groupby};
568            2                                  8      my $n_worst = scalar @$worst;
569                                                   
570            2                                 10      my $qr  = $self->{QueryRewriter};
571                                                   
572            2                                  5      my @profiles;
573            2                                  8      my $total_r = 0;
574                                                   
575            2                                  8      foreach my $rank ( 1..$n_worst ) {
576            2                                 11         my $item       = $worst->[$rank - 1]->[0];
577            2                                 18         my $stats      = $ea->results->{classes}->{$item};
578            2                                 56         my $sample     = $ea->results->{samples}->{$item};
579   ***      2            50                   48         my $samp_query = $sample->{arg} || '';
580            2                                 29         my %profile    = (
581                                                            rank   => $rank,
582                                                            r      => $stats->{Query_time}->{sum},
583                                                            cnt    => $stats->{Query_time}->{cnt},
584                                                            sample => $groupby eq 'fingerprint' ?
585   ***      2     50                          17                       $qr->distill($samp_query, %{$args{distill_args}}) : $item,
      ***            50                               
586                                                            id     => $groupby eq 'fingerprint' ? make_checksum($item)   : '',
587                                                         );
588            2                                  8         $total_r += $profile{r};
589            2                                 13         push @profiles, \%profile;
590                                                      }
591                                                   
592   ***      2            33                   11      my $report = $args{ReportFormatter} || new ReportFormatter(
593                                                         line_width       => LINE_LENGTH,
594                                                         long_last_column => 1,
595                                                      );
596            2                                 13      $report->set_title('Profile');
597            2                                 61      $report->set_columns(
598                                                         { name => 'Rank',          right_justify => 1, },
599                                                         { name => 'Query ID',                          },
600                                                         { name => 'Response time', right_justify => 1, },
601                                                         { name => 'Calls',         right_justify => 1, },
602                                                         { name => 'R/Call',        right_justify => 1, },
603                                                         { name => 'Item',                              },
604                                                      );
605                                                   
606            2                                969      foreach my $item ( sort { $a->{rank} <=> $b->{rank} } @profiles ) {
      ***      0                                  0   
607            2                                 31         my $rt  = sprintf('%10.4f', $item->{r});
608   ***      2            50                   22         my $rtp = sprintf('%4.1f%%', $item->{r} / ($total_r || 1) * 100);
609            2                                 12         my $rc  = sprintf('%8.4f', $item->{r} / $item->{cnt});
610            2                                 24         $report->add_line(
611                                                            $item->{rank},
612                                                            "0x$item->{id}",
613                                                            "$rt $rtp",
614                                                            $item->{cnt},
615                                                            $rc,
616                                                            $item->{sample},
617                                                         );
618                                                      }
619            2                                391      return $report->get_report();
620                                                   }
621                                                   
622                                                   # Prepared statements subreport (issue 740).
623                                                   # Arguments:
624                                                   #   * ea            obj: EventAggregator
625                                                   #   * worst         arrayref: worst items
626                                                   #   * groupby       scalar: attrib worst items grouped by
627                                                   # Optional arguments:
628                                                   #   * distill_args  hashref: extra args for distill()
629                                                   #   * ReportFormatter  obj: passed-in ReportFormatter for testing
630                                                   sub prepared {
631   ***      1                    1      0      8      my ( $self, %args ) = @_;
632            1                                  8      foreach my $arg ( qw(ea worst groupby) ) {
633   ***      3     50                          14         die "I need a $arg argument" unless defined $arg;
634                                                      }
635            1                                  4      my $ea      = $args{ea};
636            1                                  3      my $worst   = $args{worst};
637            1                                  4      my $groupby = $args{groupby};
638            1                                  3      my $n_worst = scalar @$worst;
639                                                   
640            1                                  4      my $qr = $self->{QueryRewriter};
641                                                   
642            1                                  3      my @prepared;       # prepared statements
643            1                                  2      my %seen_prepared;  # report each PREP-EXEC pair once
644            1                                  3      my $total_r = 0;
645                                                   
646            1                                  4      foreach my $rank ( 1..$n_worst ) {
647            2                                  9         my $item       = $worst->[$rank - 1]->[0];
648            2                                 11         my $stats      = $ea->results->{classes}->{$item};
649            2                                 43         my $sample     = $ea->results->{samples}->{$item};
650   ***      2            50                   43         my $samp_query = $sample->{arg} || '';
651                                                   
652            2                                  8         $total_r += $stats->{Query_time}->{sum};
653   ***      2     50     33                   77         next unless $stats->{Statement_id} && $item =~ m/^(?:prepare|execute) /;
654                                                   
655                                                         # Each PREPARE (probably) has some EXECUTE and each EXECUTE (should)
656                                                         # have some PREPARE.  But these are only the top N events so we can get
657                                                         # here a PREPARE but not its EXECUTE or vice-versa.  The prepared
658                                                         # statements report requires both so this code gets the missing pair
659                                                         # from the ea stats.
660            2                                  9         my ($prep_stmt, $prep, $prep_r, $prep_cnt);
661            2                                  5         my ($exec_stmt, $exec, $exec_r, $exec_cnt);
662                                                   
663            2    100                          14         if ( $item =~ m/^prepare / ) {
664            1                                  4            $prep_stmt           = $item;
665            1                                  4            ($exec_stmt = $item) =~ s/^prepare /execute /;
666                                                         }
667                                                         else {
668            1                                  5            ($prep_stmt = $item) =~ s/^execute /prepare /;
669            1                                  3            $exec_stmt           = $item;
670                                                         }
671                                                   
672                                                         # Report each PREPARE/EXECUTE pair once.
673            2    100                          15         if ( !$seen_prepared{$prep_stmt}++ ) {
674            1                                  5            $exec     = $ea->results->{classes}->{$exec_stmt};
675            1                                 21            $exec_r   = $exec->{Query_time}->{sum};
676            1                                  5            $exec_cnt = $exec->{Query_time}->{cnt};
677            1                                  4            $prep     = $ea->results->{classes}->{$prep_stmt};
678            1                                 20            $prep_r   = $prep->{Query_time}->{sum};
679            1                                 13            $prep_cnt = scalar keys %{$prep->{Statement_id}->{unq}},
               1                                  9   
680                                                            push @prepared, {
681                                                               prep_r   => $prep_r, 
682                                                               prep_cnt => $prep_cnt,
683                                                               exec_r   => $exec_r,
684                                                               exec_cnt => $exec_cnt,
685                                                               rank     => $rank,
686                                                               sample   => $groupby eq 'fingerprint'
687   ***      1     50                           3                             ? $qr->distill($samp_query, %{$args{distill_args}})
      ***            50                               
688                                                                             : $item,
689                                                               id       => $groupby eq 'fingerprint' ? make_checksum($item)
690                                                                                                     : '',
691                                                            };
692                                                         }
693                                                      }
694                                                   
695                                                      # Return unless there are prepared statements to report.
696   ***      1     50                           5      return unless scalar @prepared;
697                                                   
698   ***      1            33                    5      my $report = $args{ReportFormatter} || new ReportFormatter(
699                                                         line_width       => LINE_LENGTH,
700                                                         long_last_column => 1,
701                                                      );
702            1                                  7      $report->set_title('Prepared statements');
703            1                                 33      $report->set_columns(
704                                                         { name => 'Rank',          right_justify => 1, },
705                                                         { name => 'Query ID',                          },
706                                                         { name => 'PREP',          right_justify => 1, },
707                                                         { name => 'PREP Response', right_justify => 1, },
708                                                         { name => 'EXEC',          right_justify => 1, },
709                                                         { name => 'EXEC Response', right_justify => 1, },
710                                                         { name => 'Item',          extend_right  => 1, },
711                                                      );
712                                                   
713            1                                552      foreach my $item ( sort { $a->{rank} <=> $b->{rank} } @prepared ) {
      ***      0                                  0   
714            1                                 14         my $exec_rt  = sprintf('%10.4f', $item->{exec_r});
715   ***      1            50                   14         my $exec_rtp = sprintf('%4.1f%%',$item->{exec_r}/($total_r || 1) * 100);
716            1                                  6         my $prep_rt  = sprintf('%10.4f', $item->{prep_r});
717   ***      1            50                   22         my $prep_rtp = sprintf('%4.1f%%',$item->{prep_r}/($total_r || 1) * 100);
718   ***      1            50                   21         $report->add_line(
      ***                   50                        
719                                                            $item->{rank},
720                                                            "0x$item->{id}",
721                                                            $item->{prep_cnt} || 0,
722                                                            "$prep_rt $prep_rtp",
723                                                            $item->{exec_cnt} || 0,
724                                                            "$exec_rt $exec_rtp",
725                                                            $item->{sample},
726                                                         );
727                                                      }
728            1                                217      return $report->get_report();
729                                                   }
730                                                   
731                                                   # Makes a header format and returns the format and the column header names
732                                                   # The argument is either 'global' or anything else.
733                                                   sub make_header {
734   ***     23                   23      0     96      my ( $self, $global ) = @_;
735           23                                123      my $format  = "# %-$self->{label_width}s %6s %7s %7s %7s %7s %7s %7s %7s";
736           23                                123      my @headers = qw(pct total min max avg 95% stddev median);
737           23    100                          86      if ( $global ) {
738            7                                 67         $format =~ s/%(\d+)s/' ' x $1/e;
               7                                 58   
739            7                                 27         shift @headers;
740                                                      }
741           23                                234      return $format, @headers;
742                                                   }
743                                                   
744                                                   # Convert attribute names into labels
745                                                   sub make_label {
746   ***    115                  115      0    436      my ( $self, $val ) = @_;
747                                                   
748          115    100                         466      if ( $val =~ m/^InnoDB/ ) {
749                                                         # Shorten InnoDB attributes otherwise their short labels
750                                                         # are indistinguishable.
751            5                                 42         $val =~ s/^InnoDB_(\w+)/IDB_$1/;
752            5                                 27         $val =~ s/r_(\w+)/r$1/;
753                                                      }
754                                                   
755                                                      return  $val eq 'ts'         ? 'Time range'
756                                                            : $val eq 'user'       ? 'Users'
757                                                            : $val eq 'db'         ? 'Databases'
758                                                            : $val eq 'Query_time' ? 'Exec time'
759                                                            : $val eq 'host'       ? 'Hosts'
760                                                            : $val eq 'Error_no'   ? 'Errors'
761   ***    115     50                        1087            : do { $val =~ s/_/ /g; $val = substr($val, 0, $self->{label_width}); $val };
              62    100                         256   
              62    100                         251   
              62    100                         533   
                    100                               
                    100                               
762                                                   }
763                                                   
764                                                   # Does pretty-printing for bool (Yes/No) attributes like QC_Hit.
765                                                   sub format_bool_attrib {
766   ***      3                    3      0     13      my ( $self, $vals ) = @_;
767                                                      # Since the value is either 1 or 0, the sum is the number of
768                                                      # all true events and the number of false events is the total
769                                                      # number of events minus those that were true.
770            3                                 19      my $p_true = percentage_of($vals->{sum},  $vals->{cnt});
771   ***      3            50                   85      my $n_true = '(' . shorten($vals->{sum} || 0, d=>1_000, p=>0) . ')';
772            3                                136      return $p_true, $n_true;
773                                                   }
774                                                   
775                                                   # Does pretty-printing for lists of strings like users, hosts, db.
776                                                   sub format_string_list {
777   ***     40                   40      0    160      my ( $self, $attrib, $vals ) = @_;
778           40                                145      my $o        = $self->{OptionParser};
779           40                                189      my $show_all = $o->get('show-all');
780                                                   
781                                                      # Only class result values have unq.  So if unq doesn't exist,
782                                                      # then we've been given global values.
783   ***     40     50                        1003      if ( !exists $vals->{unq} ) {
784   ***      0                                  0         return ($vals->{cnt});
785                                                      }
786                                                   
787           40                                129      my $cnt_for = $vals->{unq};
788           40    100                         207      if ( 1 == keys %$cnt_for ) {
789           33                                140         my ($str) = keys %$cnt_for;
790                                                         # - 30 for label, spacing etc.
791           33    100                         143         $str = substr($str, 0, LINE_LENGTH - 30) . '...'
792                                                            if length $str > LINE_LENGTH - 30;
793           33                                150         return (1, $str);
794                                                      }
795            7                                 23      my $line = '';
796   ***      7     50                          17      my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
              13                                108   
797                                                                     keys %$cnt_for;
798            7                                 41      my $i = 0;
799            7                                 26      foreach my $str ( @top ) {
800           17                                 37         my $print_str;
801           17    100                          93         if ( $str =~ m/(?:\d+\.){3}\d+/ ) {
                    100                               
802            8                                 23            $print_str = $str;  # Do not shorten IP addresses.
803                                                         }
804                                                         elsif ( length $str > MAX_STRING_LENGTH ) {
805            5                                 19            $print_str = substr($str, 0, MAX_STRING_LENGTH) . '...';
806                                                         }
807                                                         else {
808            4                                 12            $print_str = $str;
809                                                         }
810           17    100                          75         if ( !$show_all->{$attrib} ) {
811           14    100                          65            last if (length $line) + (length $print_str)  > LINE_LENGTH - 27;
812                                                         }
813           15                                 75         $line .= "$print_str ($cnt_for->{$str}), ";
814           15                                 45         $i++;
815                                                      }
816                                                   
817            7                                 33      $line =~ s/, $//;
818                                                   
819            7    100                          30      if ( $i < @top ) {
820            2                                 11         $line .= "... " . (@top - $i) . " more";
821                                                      }
822                                                   
823            7                                 43      return (scalar keys %$cnt_for, $line);
824                                                   }
825                                                   
826                                                   # Attribs are sorted into three groups: basic attributes (Query_time, etc.),
827                                                   # other non-bool attributes sorted by name, and bool attributes sorted by name.
828                                                   sub sorted_attribs {
829   ***     24                   24      0    114      my ( $self, $attribs, $ea ) = @_;
830           24                                208      my %basic_attrib = (
831                                                         Query_time    => 0,
832                                                         Lock_time     => 1,
833                                                         Rows_sent     => 2,
834                                                         Rows_examined => 3,
835                                                         user          => 4,
836                                                         host          => 5,
837                                                         db            => 6,
838                                                         ts            => 7,
839                                                      );
840           24                                 61      my @basic_attribs;
841           24                                 63      my @non_bool_attribs;
842           24                                 63      my @bool_attribs;
843                                                   
844                                                      ATTRIB:
845           24                                115      foreach my $attrib ( @$attribs ) {
846          157    100                         538         if ( exists $basic_attrib{$attrib} ) {
847           91                                313            push @basic_attribs, $attrib;
848                                                         }
849                                                         else {
850           66    100    100                  285            if ( ($ea->type_for($attrib) || '') ne 'bool' ) {
851           60                               1023               push @non_bool_attribs, $attrib;
852                                                            }
853                                                            else {
854            6                                 99               push @bool_attribs, $attrib;
855                                                            }
856                                                         }
857                                                      }
858                                                   
859           24                                100      @non_bool_attribs = sort { uc $a cmp uc $b } @non_bool_attribs;
              85                                258   
860           24                                 83      @bool_attribs     = sort { uc $a cmp uc $b } @bool_attribs;
               3                                 10   
861          117                                354      @basic_attribs    = sort {
862           24                                 51            $basic_attrib{$a} <=> $basic_attrib{$b} } @basic_attribs;
863                                                   
864           24                                190      return @basic_attribs, @non_bool_attribs, @bool_attribs;
865                                                   }
866                                                   
867                                                   sub extract_tables {
868   ***      4                    4      0     21      my ( $self, $query, $default_db ) = @_;
869            4                                 11      MKDEBUG && _d('Extracting tables');
870            4                                 21      my $qp = $self->{QueryParser};
871            4                                 13      my $q  = $self->{Quoter};
872            4                                 11      my @tables;
873            4                                 11      my %seen;
874            4                                 38      foreach my $db_tbl ( $qp->get_tables($query) ) {
875   ***      4     50                         486         next unless $db_tbl;
876   ***      4     50                          26         next if $seen{$db_tbl}++; # Unique-ify for issue 337.
877            4                                 45         my ( $db, $tbl ) = $q->split_unquote($db_tbl);
878   ***      4            66                  149         push @tables, [ $db || $default_db, $tbl ];
879                                                      }
880            4                                 23      return @tables;
881                                                   }
882                                                   
883                                                   # Gets a default database and a list of arrayrefs of [db, tbl] to print out
884                                                   sub tables_report {
885   ***      4                    4      0    121      my ( $self, @tables ) = @_;
886   ***      4     50                          16      return '' unless @tables;
887            4                                 15      my $q      = $self->{Quoter};
888            4                                 14      my $tables = "";
889            4                                 20      foreach my $db_tbl ( @tables ) {
890            4                                 18         my ( $db, $tbl ) = @$db_tbl;
891   ***      4     50                          28         $tables .= '#    SHOW TABLE STATUS'
892                                                                  . ($db ? " FROM `$db`" : '')
893                                                                  . " LIKE '$tbl'\\G\n";
894            8                                 49         $tables .= "#    SHOW CREATE TABLE "
895            4                                 17                  . $q->quote(grep { $_ } @$db_tbl)
896                                                                  . "\\G\n";
897                                                      }
898   ***      4     50                         172      return $tables ? "# Tables\n$tables" : "# No tables\n";
899                                                   }
900                                                   
901                                                   sub explain_report {
902   ***      3                    3      0     52      my ( $self, $query, $db ) = @_;
903            3                                 21      my $dbh = $self->{dbh};
904            3                                 15      my $q   = $self->{Quoter};
905            3                                 16      my $qp  = $self->{QueryParser};
906   ***      3    100     66                   72      return '' unless $dbh && $query;
907            1                                 18      my $explain = '';
908            1                                  6      eval {
909   ***      1     50                          24         if ( !$qp->has_derived_table($query) ) {
910   ***      1     50                          98            if ( $db ) {
911            1                                 23               $dbh->do("USE " . $q->quote($db));
912                                                            }
913            1                                  7            my $sth = $dbh->prepare("EXPLAIN /*!50100 PARTITIONS */ $query");
914            1                                461            $sth->execute();
915            1                                  6            my $i = 1;
916            1                                 84            while ( my @row = $sth->fetchrow_array() ) {
917            1                                 12               $explain .= "# *************************** $i. "
918                                                                         . "row ***************************\n";
919            1                                 19               foreach my $j ( 0 .. $#row ) {
920           11    100                         252                  $explain .= sprintf "# %13s: %s\n", $sth->{NAME}->[$j],
921                                                                     defined $row[$j] ? $row[$j] : 'NULL';
922                                                               }
923            1                                 95               $i++;  # next row number
924                                                            }
925                                                         }
926                                                      };
927   ***      1     50                           9      if ( $EVAL_ERROR ) {
928   ***      0                                  0         MKDEBUG && _d("EXPLAIN failed:", $query, $EVAL_ERROR);
929                                                      }
930   ***      1     50                          40      return $explain ? $explain : "# EXPLAIN failed: $EVAL_ERROR";
931                                                   }
932                                                   
933                                                   sub _d {
934            1                    1            15      my ($package, undef, $line) = caller 0;
935   ***      2     50                          20      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 18   
936            1                                  8           map { defined $_ ? $_ : 'undef' }
937                                                           @_;
938            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
939                                                   }
940                                                   
941                                                   1;
942                                                   
943                                                   # ###########################################################################
944                                                   # End QueryReportFormatter package
945                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
55    ***     50      0      3   unless $args{$arg}
94    ***     50      0     15   unless exists $args{$arg}
98    ***     50      0      3   if ($args{'print_header'})
126   ***     50      0      1   if ($EVAL_ERROR)
129   ***     50      1      0   $rusage ? :
143   ***     50      0     14   unless $args{$arg}
157          100      3      4   if ($global_cnt and $$results{'globals'}{'ts'} and ($$results{'globals'}{'ts'}{'max'} || '') gt ($$results{'globals'}{'ts'}{'min'} || ''))
187          100      3      4   $args{'select'} ? :
189          100      5     33   if $$dont_print{$attrib}
191          100      3     30   unless $attrib_type
192   ***     50      0     30   unless exists $$results{'globals'}{$attrib}
193          100      6     24   if ($formatting_function{$attrib}) { }
201          100     16      8   if ($attrib_type eq 'num') { }
             100      4      4   elsif ($attrib_type eq 'string') { }
      ***     50      4      0   elsif ($attrib_type eq 'bool') { }
202          100     12      4   $attrib =~ /time|wait$/ ? :
209   ***     50    112      0   defined $_ ? :
216          100      3      1   if ($$store{'sum'} > 0 or $args{'zero_bool'})
226          100     16      4   unless $attrib_type eq 'bool'
244   ***     50      0     12   unless defined $arg
268   ***     50      0      4   $args{'explain_why'} ? :
274   ***     50      0      4   if ($qv)
276   ***      0      0      0   if $$review_vals{'reviewed_by'} and not $o->get('report-all')
283   ***     50      0      2   $$stats{'db'}{'unq'} ? :
             100      2      2   $$sample{'db'} ? :
286   ***     50      4      0   if ($o->get('for-explain'))
293          100      1      3   if $rank > 1
301   ***     50      4      0   if ($o->get('report-histogram'))
309   ***     50      0      4   if ($qv and $review_vals)
315   ***      0      0      0   if (not $val or $val ne '0000-00-00 00:00:00')
316   ***      0      0      0   $val ? :
321   ***     50      4      0   if ($groupby eq 'fingerprint') { }
323   ***     50      4      0   if $o->get('shorten')
327   ***     50      0      4   if $o->get('fingerprints')
331   ***     50      4      0   if $o->get('for-explain')
334          100      2      2   if ($item =~ /^(?:[\(\s]*select|insert|replace)/) { }
335   ***     50      0      2   if ($item =~ /^(?:insert|replace)/) { }
346   ***     50      2      0   if ($o->get('for-explain') and $converted and $converted =~ /^[\(\s]*select/i)
355   ***      0      0      0   if ($groupby eq 'tables')
380   ***     50      0     48   unless $args{$arg}
392   ***     50      0     16   unless $store
400          100      3     13   if ($global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || ''))
415          100     12      4   $$ea{'groupby'} eq 'fingerprint' ? :
427          100      5     11   if ($args{'reason'})
428   ***     50      5      0   $args{'reason'} eq 'top' ? :
443          100      9      7   $args{'select'} ? :
445          100      7    105   if $$dont_print{$attrib}
447          100      7     98   unless $attrib_type
448   ***     50      0     98   unless exists $$store{$attrib}
450          100      5     93   unless scalar %$vals
451          100      7     86   if ($formatting_function{$attrib}) { }
459          100     46     40   if ($attrib_type eq 'num') { }
      ***     50     40      0   elsif ($attrib_type eq 'string') { }
      ***      0      0      0   elsif ($attrib_type eq 'bool') { }
460          100     26     20   $attrib =~ /time|wait$/ ? :
467   ***     50    322      0   defined $_ ? :
478   ***      0      0      0   if ($$vals{'sum'} > 0 or $args{'zero_bool'})
489   ***     50     86      0   unless $attrib_type eq 'bool'
506   ***     50      0     18   unless $args{$arg}
515   ***     50      0      6   unless defined $vals and scalar @$vals
532          100      5     43   if $n_vals > $max_val
543   ***     50      0     48   if $n_marks < 1 and $n_vals > 0
545          100      5     43   $n_marks ? :
563   ***     50      0      6   unless defined $arg
585   ***     50      2      0   $groupby eq 'fingerprint' ? :
      ***     50      2      0   $groupby eq 'fingerprint' ? :
633   ***     50      0      3   unless defined $arg
653   ***     50      0      2   unless $$stats{'Statement_id'} and $item =~ /^(?:prepare|execute) /
663          100      1      1   if ($item =~ /^prepare /) { }
673          100      1      1   if (not $seen_prepared{$prep_stmt}++)
687   ***     50      1      0   $groupby eq 'fingerprint' ? :
      ***     50      1      0   $groupby eq 'fingerprint' ? :
696   ***     50      0      1   unless scalar @prepared
737          100      7     16   if ($global)
748          100      5    110   if ($val =~ /^InnoDB/)
761   ***     50      0     62   $val eq 'Error_no' ? :
             100      6     62   $val eq 'host' ? :
             100     23     68   $val eq 'Query_time' ? :
             100      6     91   $val eq 'db' ? :
             100      5     97   $val eq 'user' ? :
             100     13    102   $val eq 'ts' ? :
783   ***     50      0     40   if (not exists $$vals{'unq'})
788          100     33      7   if (1 == keys %$cnt_for)
791          100      3     30   if length $str > 44
796   ***     50     13      0   unless $$cnt_for{$b} <=> $$cnt_for{$a}
801          100      8      9   if ($str =~ /(?:\d+\.){3}\d+/) { }
             100      5      4   elsif (length $str > 10) { }
810          100     14      3   if (not $$show_all{$attrib})
811          100      2     12   if length($line) + length($print_str) > 47
819          100      2      5   if ($i < @top)
846          100     91     66   if (exists $basic_attrib{$attrib}) { }
850          100     60      6   if (($ea->type_for($attrib) || '') ne 'bool') { }
875   ***     50      0      4   unless $db_tbl
876   ***     50      0      4   if $seen{$db_tbl}++
886   ***     50      0      4   unless @tables
891   ***     50      4      0   $db ? :
898   ***     50      4      0   $tables ? :
906          100      2      1   unless $dbh and $query
909   ***     50      1      0   if (not $qp->has_derived_table($query))
910   ***     50      1      0   if ($db)
920          100     10      1   defined $row[$j] ? :
927   ***     50      0      1   if ($EVAL_ERROR)
930   ***     50      1      0   $explain ? :
935   ***     50      2      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
515   ***     50      0      6   defined $vals and scalar @$vals

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
157   ***     66      0      1      6   $global_cnt and $$results{'globals'}{'ts'}
             100      1      3      3   $global_cnt and $$results{'globals'}{'ts'} and ($$results{'globals'}{'ts'}{'max'} || '') gt ($$results{'globals'}{'ts'}{'min'} || '')
276   ***      0      0      0      0   $$review_vals{'reviewed_by'} and not $o->get('report-all')
309   ***     33      4      0      0   $qv and $review_vals
346   ***     33      0      0      2   $o->get('for-explain') and $converted
      ***     33      0      0      2   $o->get('for-explain') and $converted and $converted =~ /^[\(\s]*select/i
400   ***     66      0      4     12   $global_cnt and $$store{'ts'}
             100      4      9      3   $global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || '')
543   ***     66      5     43      0   $n_marks < 1 and $n_vals > 0
653   ***     33      0      0      2   $$stats{'Statement_id'} and $item =~ /^(?:prepare|execute) /
906   ***     66      2      0      1   $dbh and $query

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
59    ***     50      0      1   $args{'label_width'} || 9
120   ***     50      1      0   $rss || 0
      ***     50      1      0   $vsz || 0
153   ***     50      7      0   $$results{'globals'}{$orderby}{'cnt'} || 0
157   ***     50      6      0   $$results{'globals'}{'ts'}{'max'} || ''
      ***     50      6      0   $$results{'globals'}{'ts'}{'min'} || ''
165   ***     50      3      0   $diff || 1
176          100      3      4   $qps || 0
             100      3      4   $conc || 0
267   ***     50      4      0   $$sample{'arg'} || ''
400          100     10      2   $$store{'ts'}{'max'} || ''
             100     10      2   $$store{'ts'}{'min'} || ''
415   ***     50     16      0   $args{'rank'} || 0
             100      3     13   $qps || 0
             100      3     13   $conc || 0
             100      6     10   $$results{'samples'}{$item}{'pos_in_log'} || 0
538          100     40      8   $vals_per_mark || 1
579   ***     50      2      0   $$sample{'arg'} || ''
608   ***     50      2      0   $total_r || 1
650   ***     50      2      0   $$sample{'arg'} || ''
715   ***     50      1      0   $total_r || 1
717   ***     50      1      0   $total_r || 1
718   ***     50      0      1   $$item{'prep_cnt'} || 0
      ***     50      1      0   $$item{'exec_cnt'} || 0
771   ***     50      3      0   $$vals{'sum'} || 0
850          100     64      2   $ea->type_for($attrib) || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
216   ***     66      3      0      1   $$store{'sum'} > 0 or $args{'zero_bool'}
315   ***      0      0      0      0   not $val or $val ne '0000-00-00 00:00:00'
478   ***      0      0      0      0   $$vals{'sum'} > 0 or $args{'zero_bool'}
592   ***     33      2      0      0   $args{'ReportFormatter'} || new(ReportFormatter('line_width', 74, 'long_last_column', 1))
698   ***     33      1      0      0   $args{'ReportFormatter'} || new(ReportFormatter('line_width', 74, 'long_last_column', 1))
878   ***     66      2      2      0   $db || $default_db


Covered Subroutines
-------------------

Subroutine         Count Pod Location                                                   
------------------ ----- --- -----------------------------------------------------------
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:23 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:24 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:25 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:31 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:32 
BEGIN                  1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:33 
_d                     1     /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:934
chart_distro           6   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:504
event_report          16   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:378
explain_report         3   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:902
extract_tables         4   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:868
format_bool_attrib     3   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:766
format_string_list    40   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:777
header                 7   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:141
make_header           23   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:734
make_label           115   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:746
new                    1   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:53 
prepared               1   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:631
print_reports          3   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:92 
profile                2   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:561
query_report           3   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:242
rusage                 1   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:113
sorted_attribs        24   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:829
tables_report          4   0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:885


QueryReportFormatter.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            36      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            13   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
11             1                    1            14   use English qw(-no_match_vars);
               1                                  3   
               1                                  9   
12             1                    1            11   use Test::More tests => 26;
               1                                  3   
               1                                 12   
13                                                    
14             1                    1            13   use Transformers;
               1                                  3   
               1                                 11   
15             1                    1            13   use QueryReportFormatter;
               1                                  3   
               1                                 16   
16             1                    1            16   use EventAggregator;
               1                                  4   
               1                                 25   
17             1                    1            17   use QueryRewriter;
               1                                  3   
               1                                 15   
18             1                    1            15   use QueryParser;
               1                                  3   
               1                                 16   
19             1                    1            20   use Quoter;
               1                                  4   
               1                                 13   
20             1                    1            13   use ReportFormatter;
               1                                  3   
               1                                 12   
21             1                    1            11   use OptionParser;
               1                                  3   
               1                                 14   
22             1                    1            14   use DSNParser;
               1                                  4   
               1                                 11   
23             1                    1             8   use ReportFormatter;
               1                                  2   
               1                                  7   
24             1                    1            12   use Sandbox;
               1                                  3   
               1                                 10   
25             1                    1            11   use MaatkitTest;
               1                                  9   
               1                                  9   
26                                                    
27             1                                 10   my $dp  = new DSNParser(opts=>$dsn_opts);
28             1                                234   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
29             1                                 54   my $dbh = $sb->get_dbh_for('master');
30                                                    
31             1                                176   my ($result, $events, $expected);
32                                                    
33             1                                 11   my $q   = new Quoter();
34             1                                 30   my $qp  = new QueryParser();
35             1                                 24   my $qr  = new QueryRewriter(QueryParser=>$qp);
36             1                                 30   my $o   = new OptionParser(description=>'qrf');
37                                                    
38             1                                144   $o->get_specs("$trunk/mk-query-digest/mk-query-digest");
39                                                    
40             1                                 25   my $qrf = new QueryReportFormatter(
41                                                       OptionParser  => $o,
42                                                       QueryRewriter => $qr,
43                                                       QueryParser   => $qp,
44                                                       Quoter        => $q, 
45                                                    );
46                                                    
47             1                                 20   my $ea  = new EventAggregator(
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
61             1                                349   isa_ok($qrf, 'QueryReportFormatter');
62                                                    
63             1                                  9   $result = $qrf->rusage();
64             1                                 35   like(
65                                                       $result,
66                                                       qr/^# \S+ user time, \S+ system time, \S+ rss, \S+ vsz/s,
67                                                       'rusage report',
68                                                    );
69                                                    
70             1                                 59   $events = [
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
152            1                                  8   foreach my $event (@$events) {
153            3                                 28      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
154            3                                281      $ea->aggregate($event);
155                                                   }
156            1                                 11   $ea->calculate_statistical_metrics();
157            1                              22410   $result = $qrf->header(
158                                                      ea      => $ea,
159                                                      select  => [ qw(Query_time Lock_time Rows_sent Rows_examined ts) ],
160                                                      orderby => 'Query_time',
161                                                   );
162                                                   
163            1                                  8   is($result, $expected, 'Global (header) report');
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
174                                                   # Users                  2 bob (1), root (1)
175                                                   # Databases              2 test1 (1), test3 (1)
176                                                   # Time range 2007-10-15 21:43:52 to 2007-10-15 21:43:53
177                                                   EOF
178                                                   
179            1                                 18   $result = $qrf->event_report(
180                                                      ea => $ea,
181                                                      # "users" is here to try to cause a failure
182                                                      select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
183                                                      item    => 'select id from users where name=?',
184                                                      rank    => 1,
185                                                      orderby => 'Query_time',
186                                                      reason  => 'top',
187                                                   );
188                                                   
189            1                                  7   is($result, $expected, 'Event report');
190                                                   
191            1                                  4   $expected = <<EOF;
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
203            1                                 12   $result = $qrf->chart_distro(
204                                                      ea     => $ea,
205                                                      attrib => 'Query_time',
206                                                      item   => 'select id from users where name=?',
207                                                   );
208                                                   
209            1                                  6   is($result, $expected, 'Query_time distro');
210                                                   
211            1                                 13   SKIP: {
212            1                                  4      skip 'Wider labels not used, not tested', 1;
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
246            1                                 26   $ea  = new EventAggregator(
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
260            1                                930   $events = [
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
284            1                                 28      $ea->aggregate($event);
285                                                   }
286            1                                 42   $ea->calculate_statistical_metrics();
287            1                                222   $expected = <<EOF;
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
300            1                                  7   is($result, $expected, 'Global report with all zeroes');
301                                                   
302            1                                  5   $expected = <<EOF;
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
313            1                                 11   $result = $qrf->event_report(
314                                                      ea     => $ea,
315                                                      select => [ qw(Query_time Lock_time Rows_sent Rows_examined ts db user users) ],
316                                                      item    => 'administrator command: Connect',
317                                                      rank    => 1,
318                                                      orderby => 'Query_time',
319                                                      reason  => 'top',
320                                                   );
321                                                   
322            1                                  6   is($result, $expected, 'Event report with all zeroes');
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
337            1                                  9   $result = $qrf->chart_distro(
338                                                      ea     => $ea,
339                                                      attrib => 'Query_time',
340                                                      item   => 'administrator command: Connect',
341                                                   );
342                                                   
343            1                                  5   is($result, $expected, 'Chart distro with all zeroes');
344                                                   
345                                                   # #############################################################################
346                                                   # Test bool (Yes/No) pretty printing.
347                                                   # #############################################################################
348            1                                 26   $events = [
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
397            1                                395   foreach my $event (@$events) {
398            3                                 26      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
399            3                                229      $ea->aggregate($event);
400                                                   }
401            1                                  7   $ea->calculate_statistical_metrics();
402            1                              44183   $result = $qrf->header(
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
415            1                                  6   is_deeply(
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
433            1                                 27   $events = [
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
468            1                                 10   $ea  = new EventAggregator(
469                                                      groupby => 'fingerprint',
470                                                      worst   => 'Query_time',
471                                                      ignore_attributes => [qw(arg cmd)],
472                                                   );
473            1                                596   foreach my $event (@$events) {
474            3                                 21      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
475            3                                217      $ea->aggregate($event);
476                                                   }
477            1                                  6   $ea->calculate_statistical_metrics();
478            1                              22135   $result = $qrf->header(
479                                                      ea        => $ea,
480                                                      # select    => [ $ea->get_attributes() ],
481                                                      orderby   => 'Query_time',
482                                                      zero_bool => 0,
483                                                   );
484                                                   
485            1                                  7   is($result, $expected, 'No zero bool vals');
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
621                                                   # foo                    2 Hi.  I'm a... (1), Me too! I'... (1)
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
658                                                   # foo                    3 Hi.  I'm a... (1), Me too! I'... (1)... 1 more
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
753                                                   # Hosts                  2 123.123.123.456 (1), 123.123.123.789 (1)
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
799                                                   # Hosts                  3 123.123.123.456 (1), 123.123.123.789 (1)... 1 more
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
819                                                   # Hosts                  3 123.123.123.456 (1), 123.123.123.789 (1), 123.123.123.999 (1)
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
1008                                                     is(
1009                                                        $qrf->explain_report("select * from qrf.t where i=2", 'qrf'),
1010                                                  "# *************************** 1. row ***************************
1011                                                  #            id: 1
1012                                                  #   select_type: SIMPLE
1013                                                  #         table: t
1014                                                  #    partitions: NULL
1015                                                  #          type: const
1016                                                  # possible_keys: PRIMARY
1017                                                  #           key: PRIMARY
1018                                                  #       key_len: 4
1019                                                  #           ref: const
1020                                                  #          rows: 1
1021                                                  #         Extra: 
1022                                                  ",
1023                                                     "explain_report()"
1024                                                     );
1025                                                  
1026                                                     $sb->wipe_clean($dbh);
1027                                                     $dbh->disconnect();
1028                                                  }
1029                                                  
1030                                                  # #############################################################################
1031                                                  # Done.
1032                                                  # #############################################################################
1033                                                  my $output = '';
1034                                                  {
1035                                                     local *STDERR;
1036                                                     open STDERR, '>', \$output;
1037                                                     $qrf->_d('Complete test coverage');
1038                                                  }
1039                                                  like(
1040                                                     $output,
1041                                                     qr/Complete test coverage/,
1042                                                     '_d() works'
1043                                                  );
1044                                                  exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
3821  ***     50      0      3   unless defined $group_by_val
3829  ***     50      0      1   unless open my $fh, '<', $file
3839  ***     50      0      1   if $EVAL_ERROR
4314  ***     50      0      1   unless $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


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
BEGIN                1 QueryReportFormatter.t:4351
BEGIN                1 QueryReportFormatter.t:9   
__ANON__             3 QueryReportFormatter.t:3819
__ANON__             3 QueryReportFormatter.t:3826
__ANON__             4 QueryReportFormatter.t:3831
__ANON__             7 QueryReportFormatter.t:3832
__ANON__             1 QueryReportFormatter.t:4221
__ANON__             1 QueryReportFormatter.t:4238
__ANON__             1 QueryReportFormatter.t:4293
report_from_file     1 QueryReportFormatter.t:3810


