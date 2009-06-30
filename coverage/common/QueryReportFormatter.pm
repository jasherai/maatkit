---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...n/QueryReportFormatter.pm   95.7   80.3   66.7   93.3    n/a  100.0   89.0
Total                          95.7   80.3   66.7   93.3    n/a  100.0   89.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryReportFormatter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Jun 30 16:30:09 2009
Finish:       Tue Jun 30 16:30:09 2009

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
19                                                    # QueryReportFormatter package $Revision: 4025 $
20                                                    # ###########################################################################
21                                                    
22                                                    package QueryReportFormatter;
23                                                    
24             1                    1             6   use strict;
               1                                  2   
               1                                  6   
25             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                 10   
26             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  5   
27                                                    Transformers->import(
28                                                       qw(shorten micro_t parse_timestamp unix_timestamp
29                                                          make_checksum percentage_of));
30                                                    
31             1                    1             7   use constant MKDEBUG     => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
32             1                    1             6   use constant LINE_LENGTH => 74;
               1                                  3   
               1                                  4   
33                                                    
34                                                    # Special formatting functions
35                                                    my %formatting_function = (
36                                                       db => sub {
37                                                          my ( $stats ) = @_;
38                                                          my $cnt_for = $stats->{unq};
39                                                          if ( 1 == keys %$cnt_for ) {
40                                                             return 1, keys %$cnt_for;
41                                                          }
42                                                          my $line = '';
43                                                          my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
44                                                                         keys %$cnt_for;
45                                                          my $i = 0;
46                                                          foreach my $db ( @top ) {
47                                                             last if length($line) > LINE_LENGTH - 27;
48                                                             $line .= "$db ($cnt_for->{$db}), ";
49                                                             $i++;
50                                                          }
51                                                          $line =~ s/, $//;
52                                                          if ( $i < $#top ) {
53                                                             $line .= "... " . ($#top - $i) . " more";
54                                                          }
55                                                          return (scalar keys %$cnt_for, $line);
56                                                       },
57                                                       ts => sub {
58                                                          my ( $stats ) = @_;
59                                                          my $min = parse_timestamp($stats->{min} || '');
60                                                          my $max = parse_timestamp($stats->{max} || '');
61                                                          return $min && $max ? "$min to $max" : '';
62                                                       },
63                                                       user => sub {
64                                                          my ( $stats ) = @_;
65                                                          my $cnt_for = $stats->{unq};
66                                                          if ( 1 == keys %$cnt_for ) {
67                                                             return 1, keys %$cnt_for;
68                                                          }
69                                                          my $line = '';
70                                                          my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
71                                                                         keys %$cnt_for;
72                                                          my $i = 0;
73                                                          foreach my $user ( @top ) {
74                                                             last if length($line) > LINE_LENGTH - 27;
75                                                             $line .= "$user ($cnt_for->{$user}), ";
76                                                             $i++;
77                                                          }
78                                                          $line =~ s/, $//;
79                                                          if ( $i < $#top ) {
80                                                             $line .= "... " . ($#top - $i) . " more";
81                                                          }
82                                                          return (scalar keys %$cnt_for, $line);
83                                                       },
84                                                       QC_Hit         => \&format_bool_attrib,
85                                                       Full_scan      => \&format_bool_attrib,
86                                                       Full_join      => \&format_bool_attrib,
87                                                       Tmp_table      => \&format_bool_attrib,
88                                                       Disk_tmp_table => \&format_bool_attrib,
89                                                       Filesort       => \&format_bool_attrib,
90                                                       Disk_filesort  => \&format_bool_attrib,
91                                                    );
92                                                    
93                                                    my $bool_format = '#  %3s%%  %s';
94                                                    
95                                                    sub new {
96             1                    1            12      my ( $class, %args ) = @_;
97             1                                 11      return bless { }, $class;
98                                                    }
99                                                    
100                                                   sub header {
101            1                    1            12      my ($self) = @_;
102                                                   
103            1                                  6      my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
104            1                                  3      eval {
105            1                               9568         my $mem = `ps -o rss,vsz $PID`;
106            1                                 48         ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
107                                                      };
108            1                                 16      ( $user, $system ) = times();
109                                                   
110            1                                 31      sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
111                                                         micro_t( $user,   p_s => 1, p_ms => 1 ),
112                                                         micro_t( $system, p_s => 1, p_ms => 1 ),
113                                                         shorten( $rss * 1_024 ),
114                                                         shorten( $vsz * 1_024 );
115                                                   }
116                                                   
117                                                   # Print a report about the global statistics in the EventAggregator.  %opts is a
118                                                   # hash that has the following keys:
119                                                   #  * select       An arrayref of attributes to print statistics lines for.
120                                                   #  * worst        The --orderby attribute.
121                                                   sub global_report {
122            3                    3            68      my ( $self, $ea, %opts ) = @_;
123            3                                 20      my $stats = $ea->results;
124            3                                  9      my @result;
125                                                   
126                                                      # Get global count
127            3                                 17      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
128                                                   
129                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
130            3                                 11      my ($qps, $conc) = (0, 0);
131   ***      3    100     33                   82      if ( $global_cnt && $stats->{globals}->{ts}
      ***                   50                        
      ***                   50                        
      ***                   66                        
132                                                         && ($stats->{globals}->{ts}->{max} || '')
133                                                            gt ($stats->{globals}->{ts}->{min} || '')
134                                                      ) {
135            2                                  7         eval {
136            2                                 19            my $min  = parse_timestamp($stats->{globals}->{ts}->{min});
137            2                                 14            my $max  = parse_timestamp($stats->{globals}->{ts}->{max});
138            2                                 14            my $diff = unix_timestamp($max) - unix_timestamp($min);
139            2                                 10            $qps     = $global_cnt / $diff;
140            2                                 13            $conc    = $stats->{globals}->{$opts{worst}}->{sum} / $diff;
141                                                         };
142                                                      }
143                                                   
144                                                      # First line
145            3                                 18      my $line = sprintf(
146                                                         '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
147                                                         shorten($global_cnt),
148            3                                 19         shorten(scalar keys %{$stats->{classes}}),
149                                                         shorten($qps),
150                                                         shorten($conc));
151            3                                 18      $line .= ('_' x (LINE_LENGTH - length($line)));
152            3                                 13      push @result, $line;
153                                                   
154                                                      # Column header line
155            3                                 35      my ($format, @headers) = make_header('global');
156            3                                 22      push @result, sprintf($format, '', @headers);
157                                                   
158                                                      # Each additional line
159            3                                  9      foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
               3                                 22   
160           17                                 86         my $attrib_type = $ea->type_for($attrib);
161           17    100                          69         next unless $attrib_type; 
162   ***     14     50                          67         next unless exists $stats->{globals}->{$attrib};
163           14    100                          59         if ( $formatting_function{$attrib} ) { # Handle special cases
164            5    100                          23            if ( $attrib_type ne 'bool') {
165           30                                112               push @result, sprintf $format, make_label($attrib),
166                                                                     $formatting_function{$attrib}->($stats->{globals}->{$attrib}),
167            3                                 14                     (map { '' } 0..9); # just for good measure
168                                                            }
169                                                            else {
170                                                               # Bools have their own special line format.
171            2                                 12               push @result, sprintf $bool_format,
172                                                                     $formatting_function{$attrib}->($stats->{globals}->{$attrib}),
173                                                                     $attrib;
174                                                            }
175                                                         }
176                                                         else {
177            9                                 35            my $store = $stats->{globals}->{$attrib};
178            9                                 21            my @values;
179   ***      9     50                          34            if ( $attrib_type eq 'num' ) {
180            9    100                          60               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
181            9                                 21               MKDEBUG && _d('Calculating global statistical_metrics for', $attrib);
182            9                                 53               my $metrics = $ea->calculate_statistical_metrics($store->{all}, $store);
183            9                                 64               @values = (
184            9                                 55                  @{$store}{qw(sum min max)},
185                                                                  $store->{sum} / $store->{cnt},
186            9                                 33                  @{$metrics}{qw(pct_95 stddev median)},
187                                                               );
188   ***      9     50                          37               @values = map { defined $_ ? $func->($_) : '' } @values;
              63                                286   
189                                                            }
190                                                            else {
191   ***      0                                  0               @values = ('', $store->{min}, $store->{max}, '', '', '', '');
192                                                            }
193            9                                 54            push @result, sprintf $format, make_label($attrib), @values;
194                                                         }
195                                                      }
196                                                   
197            3                                 14      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              20                                105   
              20                                103   
198                                                   }
199                                                   
200                                                   # Print a report about the statistics in the EventAggregator.  %opts is a
201                                                   # hash that has the following keys:
202                                                   #  * select       An arrayref of attributes to print statistics lines for.
203                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
204                                                   #  * rank         The (optional) rank of the query, for the header
205                                                   #  * worst        The --orderby attribute
206                                                   #  * reason       Why this one is being reported on: top|outlier
207                                                   # TODO: it would be good to start using $ea->metrics() here for simplicity and
208                                                   # uniform code.
209                                                   sub event_report {
210            5                    5            92      my ( $self, $ea, %opts ) = @_;
211            5                                 29      my $stats = $ea->results;
212            5                                 15      my @result;
213                                                   
214                                                      # Does the data exist?  Is there a sample event?
215            5                                 23      my $store = $stats->{classes}->{$opts{where}};
216   ***      5     50                          20      return "# No such event $opts{where}\n" unless $store;
217            5                                 22      my $sample = $stats->{samples}->{$opts{where}};
218                                                   
219                                                      # Pick the first attribute to get counts
220            5                                 27      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
221            5                                 22      my $class_cnt  = $store->{$opts{worst}}->{cnt};
222                                                   
223                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
224            5                                 19      my ($qps, $conc) = (0, 0);
225   ***      5    100     66                   85      if ( $global_cnt && $store->{ts}
      ***                   50                        
      ***                   50                        
                           100                        
226                                                         && ($store->{ts}->{max} || '')
227                                                            gt ($store->{ts}->{min} || '')
228                                                      ) {
229            1                                  4         eval {
230            1                                  6            my $min  = parse_timestamp($store->{ts}->{min});
231            1                                  7            my $max  = parse_timestamp($store->{ts}->{max});
232            1                                  5            my $diff = unix_timestamp($max) - unix_timestamp($min);
233            1                                  6            $qps     = $class_cnt / $diff;
234            1                                  8            $conc    = $store->{$opts{worst}}->{sum} / $diff;
235                                                         };
236                                                      }
237                                                   
238                                                      # First line
239   ***      5     50     50                   44      my $line = sprintf(
                           100                        
240                                                         '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
241                                                         ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
242                                                         $opts{rank} || 0,
243                                                         shorten($qps),
244                                                         shorten($conc),
245                                                         make_checksum($opts{where}),
246                                                         $sample->{pos_in_log} || 0);
247            5                                 27      $line .= ('_' x (LINE_LENGTH - length($line)));
248            5                                 16      push @result, $line;
249                                                   
250            5    100                          24      if ( $opts{reason} ) {
251   ***      2     50                          13         push @result, "# This item is included in the report because it matches "
252                                                            . ($opts{reason} eq 'top' ? '--limit.' : '--outliers.');
253                                                      }
254                                                   
255                                                      # Column header line
256            5                                 20      my ($format, @headers) = make_header();
257            5                                 34      push @result, sprintf($format, '', @headers);
258                                                   
259                                                      # Count line
260           45                                137      push @result, sprintf
261                                                         $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
262            5                                 27            map { '' } (1 ..9);
263                                                   
264                                                      # Each additional line
265            5                                 18      foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
               5                                 26   
266           64                                290         my $attrib_type = $ea->type_for($attrib);
267           64    100                         248         next unless $attrib_type; 
268           59    100                         248         next unless exists $store->{$attrib};
269           54                                172         my $vals = $store->{$attrib};
270   ***     54     50                         247         next unless scalar %$vals;
271           54    100                         199         if ( $formatting_function{$attrib} ) { # Handle special cases
272   ***     12     50                          41            if ( $attrib_type ne 'bool' ) {
273          120                                387               push @result, sprintf $format, make_label($attrib),
274                                                                     $formatting_function{$attrib}->($vals),
275           12                                 49                     (map { '' } 0..9); # just for good measure
276                                                            }
277                                                            else {
278                                                               # Bools have their own special line format.
279   ***      0                                  0               push @result, sprintf $bool_format, 
280                                                                     $formatting_function{$attrib}->($vals),
281                                                                     $attrib;
282                                                            }
283                                                         }
284                                                         else {
285           42                                 99            my @values;
286           42                                 93            my $pct;
287           42    100                         148            if ( $attrib_type eq 'num' ) {
288           27    100                         128               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
289           27                                135               my $metrics = $ea->calculate_statistical_metrics($vals->{all}, $vals);
290           27                                159               @values = (
291           27                                146                  @{$vals}{qw(sum min max)},
292                                                                  $vals->{sum} / $vals->{cnt},
293           27                                 91                  @{$metrics}{qw(pct_95 stddev median)},
294                                                               );
295   ***     27     50                          93               @values = map { defined $_ ? $func->($_) : '' } @values;
             189                                861   
296           27                                189               $pct = percentage_of($vals->{sum},
297                                                                  $stats->{globals}->{$attrib}->{sum});
298                                                            }
299                                                            else {
300           15                                100               @values = ('', $vals->{min}, $vals->{max}, '', '', '', '');
301           15                                 49               $pct = 0;
302                                                            }
303           42                                163            push @result, sprintf $format, make_label($attrib), $pct, @values;
304                                                         }
305                                                      }
306                                                   
307            5                                 25      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              71                                331   
              71                                298   
308                                                   }
309                                                   
310                                                   # Creates a chart of value distributions in buckets.  Right now it bucketizes
311                                                   # into 8 buckets, powers of ten starting with .000001. %opts has:
312                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
313                                                   #  * attribute    An attribute to chart.
314                                                   sub chart_distro {
315            2                    2            50      my ( $self, $ea, %opts ) = @_;
316            2                                 12      my $stats = $ea->results;
317            2                                 15      my $store = $stats->{classes}->{$opts{where}}->{$opts{attribute}};
318            2                                  8      my $vals  = $store->{all};
319   ***      2     50     50                   23      return "" unless defined $vals && scalar @$vals;
320                                                      # TODO: this is broken.
321            2                                 14      my @buck_tens = $ea->buckets_of(10);
322            2                                 91      my @distro = map { 0 } (0 .. 7);
              16                                 46   
323            2                                 90      map { $distro[$buck_tens[$_]] += $vals->[$_] } (1 .. @$vals - 1);
            1998                               7353   
324                                                   
325            2                                 87      my $max_val = 0;
326            2                                  6      my $vals_per_mark; # number of vals represented by 1 #-mark
327            2                                  6      my $max_disp_width = 64;
328            2                                  5      my $bar_fmt = "# %5s%s";
329            2                                 12      my @distro_labels = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
330            2                                 11      my @results = "# $opts{attribute} distribution";
331                                                   
332                                                      # Find the distro with the most values. This will set
333                                                      # vals_per_mark and become the bar at max_disp_width.
334            2                                  8      foreach my $n_vals ( @distro ) {
335           16    100                          63         $max_val = $n_vals if $n_vals > $max_val;
336                                                      }
337            2                                  8      $vals_per_mark = $max_val / $max_disp_width;
338                                                   
339            2                                 12      foreach my $i ( 0 .. $#distro ) {
340           16                                 48         my $n_vals = $distro[$i];
341           16           100                   86         my $n_marks = $n_vals / ($vals_per_mark || 1);
342                                                         # Always print at least 1 mark for any bucket that has at least
343                                                         # 1 value. This skews the graph a tiny bit, but it allows us to
344                                                         # see all buckets that have values.
345   ***     16     50     66                  125         $n_marks = 1 if $n_marks < 1 && $n_vals > 0;
346           16    100                          68         my $bar = ($n_marks ? '  ' : '') . '#' x $n_marks;
347           16                                 78         push @results, sprintf $bar_fmt, $distro_labels[$i], $bar;
348                                                      }
349                                                   
350            2                                 60      return join("\n", @results) . "\n";
351                                                   }
352                                                   
353                                                   # Makes a header format and returns the format and the column header names.  The
354                                                   # argument is either 'global' or anything else.
355                                                   sub make_header {
356            8                    8            34      my ( $global ) = @_;
357            8                                 29      my $format = "# %-9s %6s %7s %7s %7s %7s %7s %7s %7s";
358            8                                 43      my @headers = qw(pct total min max avg 95% stddev median);
359            8    100                          33      if ( $global ) {
360            3                                 34         $format =~ s/%(\d+)s/' ' x $1/e;
               3                                 29   
361            3                                 10         shift @headers;
362                                                      }
363            8                                 82      return $format, @headers;
364                                                   }
365                                                   
366                                                   # Convert attribute names into labels
367                                                   sub make_label {
368           66                   66           228      my ( $val ) = @_;
369                                                      return  $val eq 'ts'         ? 'Time range'
370                                                            : $val eq 'user'       ? 'Users'
371                                                            : $val eq 'db'         ? 'Databases'
372                                                            : $val eq 'Query_time' ? 'Exec time'
373           66    100                         506            : do { $val =~ s/_/ /g; $val = substr($val, 0, 9); $val };
              43    100                         175   
              43    100                         140   
              43    100                         321   
374                                                   }
375                                                   
376                                                   # Does pretty-printing for bool (Yes/No) attributes like QC_Hit.
377                                                   sub format_bool_attrib {
378            2                    2             7      my ( $stats ) = @_;
379                                                      # Since the value is either 1 or 0, the sum is the number of
380                                                      # all true events and the number of false events is the total
381                                                      # number of events minus those that were true.
382            2                                 13      my $p_true  = percentage_of($stats->{sum},  $stats->{cnt});
383            2                                 10      my $p_false = percentage_of($stats->{cnt} - $stats->{sum}, $stats->{cnt});
384            2                                 14      return $p_true;
385                                                   }
386                                                   
387                                                   # Attribs are sorted into three groups: basic attributes (Query_time, etc.),
388                                                   # other non-bool attributes sorted by name, and bool attributes sorted by name.
389                                                   sub sort_attribs {
390            9                    9            71      my ( $ea, @attribs ) = @_;
391            9                                 65      my %basic_attrib = (
392                                                         Query_time    => 0,
393                                                         Lock_time     => 1,
394                                                         Rows_sent     => 2,
395                                                         Rows_examined => 3,
396                                                         ts            => 4,
397                                                      );
398            9                                 24      my @basic_attribs;
399            9                                 19      my @non_bool_attribs;
400            9                                 21      my @bool_attribs;
401                                                   
402            9                                 34      foreach my $attrib ( @attribs ) {
403           88    100                         298         if ( exists $basic_attrib{$attrib} ) {
404           41                                176            push @basic_attribs, $attrib;
405                                                         }
406                                                         else {
407           47    100    100                  182            if ( ($ea->type_for($attrib) || '') ne 'bool' ) {
408           43                                168               push @non_bool_attribs, $attrib;
409                                                            }
410                                                            else {
411            4                                 15               push @bool_attribs, $attrib;
412                                                            }
413                                                         }
414                                                      }
415                                                   
416            9                                 70      @non_bool_attribs = sort @non_bool_attribs;
417            9                                 32      @bool_attribs     = sort @bool_attribs;
418           65                                209      @basic_attribs    = sort {
419            9                                 17            $basic_attrib{$a} <=> $basic_attrib{$b} } @basic_attribs;
420                                                   
421            9                                106      return @basic_attribs, @non_bool_attribs, @bool_attribs;
422                                                   }
423                                                   
424                                                   sub _d {
425   ***      0                    0                    my ($package, undef, $line) = caller 0;
426   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
427   ***      0                                              map { defined $_ ? $_ : 'undef' }
428                                                           @_;
429   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
430                                                   }
431                                                   
432                                                   1;
433                                                   
434                                                   # ###########################################################################
435                                                   # End QueryReportFormatter package
436                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
131          100      2      1   if ($global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || ''))
161          100      3     14   unless $attrib_type
162   ***     50      0     14   unless exists $$stats{'globals'}{$attrib}
163          100      5      9   if ($formatting_function{$attrib}) { }
164          100      3      2   if ($attrib_type ne 'bool') { }
179   ***     50      9      0   if ($attrib_type eq 'num') { }
180          100      5      4   $attrib =~ /time$/ ? :
188   ***     50     63      0   defined $_ ? :
216   ***     50      0      5   unless $store
225          100      1      4   if ($global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || ''))
239   ***     50      5      0   $$ea{'groupby'} eq 'fingerprint' ? :
250          100      2      3   if ($opts{'reason'})
251   ***     50      2      0   $opts{'reason'} eq 'top' ? :
267          100      5     59   unless $attrib_type
268          100      5     54   unless exists $$store{$attrib}
270   ***     50      0     54   unless scalar %$vals
271          100     12     42   if ($formatting_function{$attrib}) { }
272   ***     50     12      0   if ($attrib_type ne 'bool') { }
287          100     27     15   if ($attrib_type eq 'num') { }
288          100      9     18   $attrib =~ /time$/ ? :
295   ***     50    189      0   defined $_ ? :
319   ***     50      0      2   unless defined $vals and scalar @$vals
335          100      1     15   if $n_vals > $max_val
345   ***     50      0     16   if $n_marks < 1 and $n_vals > 0
346          100      1     15   $n_marks ? :
359          100      3      5   if ($global)
373          100      8     43   $val eq 'Query_time' ? :
             100      4     51   $val eq 'db' ? :
             100      5     55   $val eq 'user' ? :
             100      6     60   $val eq 'ts' ? :
403          100     41     47   if (exists $basic_attrib{$attrib}) { }
407          100     43      4   if (($ea->type_for($attrib) || '') ne 'bool') { }
426   ***      0      0      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
319   ***     50      0      2   defined $vals and scalar @$vals

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
131   ***     33      0      0      3   $global_cnt and $$stats{'globals'}{'ts'}
      ***     66      0      1      2   $global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || '')
225   ***     66      0      2      3   $global_cnt and $$store{'ts'}
             100      2      2      1   $global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || '')
345   ***     66      1     15      0   $n_marks < 1 and $n_vals > 0

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
131   ***     50      3      0   $$stats{'globals'}{'ts'}{'max'} || ''
      ***     50      3      0   $$stats{'globals'}{'ts'}{'min'} || ''
225   ***     50      3      0   $$store{'ts'}{'max'} || ''
      ***     50      3      0   $$store{'ts'}{'min'} || ''
239   ***     50      5      0   $opts{'rank'} || 0
             100      3      2   $$sample{'pos_in_log'} || 0
341          100      8      8   $vals_per_mark || 1
407          100     45      2   $ea->type_for($attrib) || ''


Covered Subroutines
-------------------

Subroutine         Count Location                                                   
------------------ ----- -----------------------------------------------------------
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:24 
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:25 
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:26 
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:31 
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:32 
chart_distro           2 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:315
event_report           5 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:210
format_bool_attrib     2 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:378
global_report          3 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:122
header                 1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:101
make_header            8 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:356
make_label            66 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:368
new                    1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:96 
sort_attribs           9 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:390

Uncovered Subroutines
---------------------

Subroutine         Count Location                                                   
------------------ ----- -----------------------------------------------------------
_d                     0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:425


