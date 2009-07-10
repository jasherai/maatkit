---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...n/QueryReportFormatter.pm   96.9   80.2   66.7  100.0    n/a  100.0   90.0
Total                          96.9   80.2   66.7  100.0    n/a  100.0   90.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryReportFormatter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 10 21:13:47 2009
Finish:       Fri Jul 10 21:13:48 2009

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
19                                                    # QueryReportFormatter package $Revision: 4143 $
20                                                    # ###########################################################################
21                                                    
22                                                    package QueryReportFormatter;
23                                                    
24             1                    1             6   use strict;
               1                                  3   
               1                                  7   
25             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
26             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
27                                                    Transformers->import(
28                                                       qw(shorten micro_t parse_timestamp unix_timestamp
29                                                          make_checksum percentage_of));
30                                                    
31             1                    1             8   use constant MKDEBUG           => $ENV{MKDEBUG};
               1                                  3   
               1                                  9   
32             1                    1             6   use constant LINE_LENGTH       => 74;
               1                                  2   
               1                                  5   
33             1                    1             5   use constant MAX_STRING_LENGTH => 10;
               1                                  3   
               1                                  5   
34                                                    
35                                                    # Special formatting functions
36                                                    my %formatting_function = (
37                                                       ts => sub {
38                                                          my ( $stats ) = @_;
39                                                          my $min = parse_timestamp($stats->{min} || '');
40                                                          my $max = parse_timestamp($stats->{max} || '');
41                                                          return $min && $max ? "$min to $max" : '';
42                                                       },
43                                                    );
44                                                    
45                                                    my $bool_format = '# %3s%% %s';
46                                                    
47                                                    sub new {
48             1                    1            12      my ( $class, %args ) = @_;
49             1                                 12      return bless { }, $class;
50                                                    }
51                                                    
52                                                    sub header {
53             1                    1            12      my ($self) = @_;
54                                                    
55             1                                  5      my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
56             1                                  4      eval {
57             1                              10984         my $mem = `ps -o rss,vsz $PID`;
58             1                                 42         ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
59                                                       };
60             1                                 15      ( $user, $system ) = times();
61                                                    
62             1                                 24      sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
63                                                          micro_t( $user,   p_s => 1, p_ms => 1 ),
64                                                          micro_t( $system, p_s => 1, p_ms => 1 ),
65                                                          shorten( $rss * 1_024 ),
66                                                          shorten( $vsz * 1_024 );
67                                                    }
68                                                    
69                                                    # Print a report about the global statistics in the EventAggregator.  %opts is a
70                                                    # hash that has the following keys:
71                                                    #  * select       An arrayref of attributes to print statistics lines for.
72                                                    #  * worst        The --orderby attribute.
73                                                    sub global_report {
74             3                    3            65      my ( $self, $ea, %opts ) = @_;
75             3                                 20      my $stats = $ea->results;
76             3                                  8      my @result;
77                                                    
78                                                       # Get global count
79             3                                 17      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
80                                                    
81                                                       # Calculate QPS (queries per second) by looking at the min/max timestamp.
82             3                                 11      my ($qps, $conc) = (0, 0);
83    ***      3    100     33                   90      if ( $global_cnt && $stats->{globals}->{ts}
      ***                   50                        
      ***                   50                        
      ***                   66                        
84                                                          && ($stats->{globals}->{ts}->{max} || '')
85                                                             gt ($stats->{globals}->{ts}->{min} || '')
86                                                       ) {
87             2                                  8         eval {
88             2                                 16            my $min  = parse_timestamp($stats->{globals}->{ts}->{min});
89             2                                 14            my $max  = parse_timestamp($stats->{globals}->{ts}->{max});
90             2                                 17            my $diff = unix_timestamp($max) - unix_timestamp($min);
91             2                                 12            $qps     = $global_cnt / $diff;
92             2                                 14            $conc    = $stats->{globals}->{$opts{worst}}->{sum} / $diff;
93                                                          };
94                                                       }
95                                                    
96                                                       # First line
97             3                                 18      my $line = sprintf(
98                                                          '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
99                                                          shorten($global_cnt),
100            3                                 19         shorten(scalar keys %{$stats->{classes}}),
101                                                         shorten($qps),
102                                                         shorten($conc));
103            3                                 18      $line .= ('_' x (LINE_LENGTH - length($line)));
104            3                                 11      push @result, $line;
105                                                   
106                                                      # Column header line
107            3                                 23      my ($format, @headers) = make_header('global');
108            3                                 19      push @result, sprintf($format, '', @headers);
109                                                   
110                                                      # Each additional line
111            3                                 11      foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
               3                                 22   
112           17                                 93         my $attrib_type = $ea->type_for($attrib);
113           17    100                          68         next unless $attrib_type; 
114   ***     14     50                          75         next unless exists $stats->{globals}->{$attrib};
115           14    100                          58         if ( $formatting_function{$attrib} ) { # Handle special cases
116           30                                 97            push @result, sprintf $format, make_label($attrib),
117                                                               $formatting_function{$attrib}->($stats->{globals}->{$attrib}),
118            3                                 15               (map { '' } 0..9); # just for good measure
119                                                         }
120                                                         else {
121           11                                 46            my $store = $stats->{globals}->{$attrib};
122           11                                 30            my @values;
123           11    100                          48            if ( $attrib_type eq 'num' ) {
      ***            50                               
      ***            50                               
124            9    100                         325               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
125            9                                 28               MKDEBUG && _d('Calculating global statistical_metrics for', $attrib);
126            9                                 68               my $metrics = $ea->calculate_statistical_metrics($store->{all}, $store);
127            9                                 82               @values = (
128            9                                 61                  @{$store}{qw(sum min max)},
129                                                                  $store->{sum} / $store->{cnt},
130            9                                 36                  @{$metrics}{qw(pct_95 stddev median)},
131                                                               );
132   ***      9     50                          38               @values = map { defined $_ ? $func->($_) : '' } @values;
              63                                303   
133                                                            }
134                                                            elsif ( $attrib_type eq 'string' ) {
135   ***      0                                  0               push @values,
136                                                                  format_string_list($store),
137   ***      0                                  0                  (map { '' } 0..9); # just for good measure
138                                                            }
139                                                            elsif ( $attrib_type eq 'bool' ) {
140            2                                 26               push @result,
141                                                                  sprintf $bool_format, format_bool_attrib($store), $attrib;
142                                                            }
143                                                            else {
144   ***      0                                  0               @values = ('', $store->{min}, $store->{max}, '', '', '', '');
145                                                            }
146                                                   
147           11    100                          96            push @result, sprintf $format, make_label($attrib), @values
148                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
149                                                         }
150                                                      }
151                                                   
152            3                                 14      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              20                                108   
              20                                115   
153                                                   }
154                                                   
155                                                   # Print a report about the statistics in the EventAggregator.  %opts is a
156                                                   # hash that has the following keys:
157                                                   #  * select       An arrayref of attributes to print statistics lines for.
158                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
159                                                   #  * rank         The (optional) rank of the query, for the header
160                                                   #  * worst        The --orderby attribute
161                                                   #  * reason       Why this one is being reported on: top|outlier
162                                                   # TODO: it would be good to start using $ea->metrics() here for simplicity and
163                                                   # uniform code.
164                                                   sub event_report {
165            8                    8           161      my ( $self, $ea, %opts ) = @_;
166            8                                 49      my $stats = $ea->results;
167            8                                 24      my @result;
168                                                   
169                                                      # Does the data exist?  Is there a sample event?
170            8                                 41      my $store = $stats->{classes}->{$opts{where}};
171   ***      8     50                          35      return "# No such event $opts{where}\n" unless $store;
172            8                                 39      my $sample = $stats->{samples}->{$opts{where}};
173                                                   
174                                                      # Pick the first attribute to get counts
175            8                                 41      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
176            8                                 42      my $class_cnt  = $store->{$opts{worst}}->{cnt};
177                                                   
178                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
179            8                                 29      my ($qps, $conc) = (0, 0);
180   ***      8    100     66                  168      if ( $global_cnt && $store->{ts}
      ***                   50                        
      ***                   50                        
                           100                        
181                                                         && ($store->{ts}->{max} || '')
182                                                            gt ($store->{ts}->{min} || '')
183                                                      ) {
184            3                                 10         eval {
185            3                                 19            my $min  = parse_timestamp($store->{ts}->{min});
186            3                                 20            my $max  = parse_timestamp($store->{ts}->{max});
187            3                                 16            my $diff = unix_timestamp($max) - unix_timestamp($min);
188            3                                 16            $qps     = $class_cnt / $diff;
189            3                                 18            $conc    = $store->{$opts{worst}}->{sum} / $diff;
190                                                         };
191                                                      }
192                                                   
193                                                      # First line
194   ***      8     50     50                   81      my $line = sprintf(
                           100                        
195                                                         '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
196                                                         ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
197                                                         $opts{rank} || 0,
198                                                         shorten($qps),
199                                                         shorten($conc),
200                                                         make_checksum($opts{where}),
201                                                         $sample->{pos_in_log} || 0);
202            8                                 44      $line .= ('_' x (LINE_LENGTH - length($line)));
203            8                                 33      push @result, $line;
204                                                   
205            8    100                          37      if ( $opts{reason} ) {
206   ***      5     50                          28         push @result, "# This item is included in the report because it matches "
207                                                            . ($opts{reason} eq 'top' ? '--limit.' : '--outliers.');
208                                                      }
209                                                   
210                                                      # Column header line
211            8                                 38      my ($format, @headers) = make_header();
212            8                                 54      push @result, sprintf($format, '', @headers);
213                                                   
214                                                      # Count line
215           72                                216      push @result, sprintf
216                                                         $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
217            8                                 45            map { '' } (1 ..9);
218                                                   
219                                                      # Each additional line
220            8                                 29      foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
               8                                 49   
221           67                                283         my $attrib_type = $ea->type_for($attrib);
222           67    100                         244         next unless $attrib_type; 
223           62    100                         275         next unless exists $store->{$attrib};
224           57                                174         my $vals = $store->{$attrib};
225   ***     57     50                         255         next unless scalar %$vals;
226           57    100                         234         if ( $formatting_function{$attrib} ) { # Handle special cases
227           30                                 93            push @result, sprintf $format, make_label($attrib),
228                                                               $formatting_function{$attrib}->($vals),
229            3                                 15               (map { '' } 0..9); # just for good measure
230                                                         }
231                                                         else {
232           54                                119            my @values;
233           54                                119            my $pct;
234           54    100                         215            if ( $attrib_type eq 'num' ) {
      ***            50                               
      ***             0                               
235           27    100                         136               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
236           27                                144               my $metrics = $ea->calculate_statistical_metrics($vals->{all}, $vals);
237           27                                162               @values = (
238           27                                163                  @{$vals}{qw(sum min max)},
239                                                                  $vals->{sum} / $vals->{cnt},
240           27                                 94                  @{$metrics}{qw(pct_95 stddev median)},
241                                                               );
242   ***     27     50                          99               @values = map { defined $_ ? $func->($_) : '' } @values;
             189                                890   
243           27                                207               $pct = percentage_of($vals->{sum},
244                                                                  $stats->{globals}->{$attrib}->{sum});
245                                                            }
246                                                            elsif ( $attrib_type eq 'string' ) {
247          270                                778               push @values,
248                                                                  format_string_list($vals),
249           27                                105                  (map { '' } 0..9); # just for good measure
250           27                                 89               $pct = '';
251                                                            }
252                                                            elsif ( $attrib_type eq 'bool' ) {
253   ***      0                                  0               push @result,
254                                                                  sprintf $bool_format, format_bool_attrib($vals), $attrib;
255                                                            }
256                                                            else {
257   ***      0                                  0               @values = ('', $vals->{min}, $vals->{max}, '', '', '', '');
258   ***      0                                  0               $pct = 0;
259                                                            }
260                                                   
261   ***     54     50                         318            push @result, sprintf $format, make_label($attrib), $pct, @values
262                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
263                                                         }
264                                                      }
265                                                   
266            8                                 38      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              86                                399   
              86                                372   
267                                                   }
268                                                   
269                                                   # Creates a chart of value distributions in buckets.  Right now it bucketizes
270                                                   # into 8 buckets, powers of ten starting with .000001. %opts has:
271                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
272                                                   #  * attribute    An attribute to chart.
273                                                   sub chart_distro {
274            2                    2            42      my ( $self, $ea, %opts ) = @_;
275            2                                 12      my $stats = $ea->results;
276            2                                 13      my $store = $stats->{classes}->{$opts{where}}->{$opts{attribute}};
277            2                                  8      my $vals  = $store->{all};
278   ***      2     50     50                   25      return "" unless defined $vals && scalar @$vals;
279                                                      # TODO: this is broken.
280            2                                 13      my @buck_tens = $ea->buckets_of(10);
281            2                                 96      my @distro = map { 0 } (0 .. 7);
              16                                 47   
282            2                                 94      map { $distro[$buck_tens[$_]] += $vals->[$_] } (1 .. @$vals - 1);
            1998                               7575   
283                                                   
284            2                                104      my $max_val = 0;
285            2                                  5      my $vals_per_mark; # number of vals represented by 1 #-mark
286            2                                  6      my $max_disp_width = 64;
287            2                                 10      my $bar_fmt = "# %5s%s";
288            2                                 22      my @distro_labels = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
289            2                                 35      my @results = "# $opts{attribute} distribution";
290                                                   
291                                                      # Find the distro with the most values. This will set
292                                                      # vals_per_mark and become the bar at max_disp_width.
293            2                                 16      foreach my $n_vals ( @distro ) {
294           16    100                          72         $max_val = $n_vals if $n_vals > $max_val;
295                                                      }
296            2                                 12      $vals_per_mark = $max_val / $max_disp_width;
297                                                   
298            2                                 21      foreach my $i ( 0 .. $#distro ) {
299           16                                 47         my $n_vals = $distro[$i];
300           16           100                   94         my $n_marks = $n_vals / ($vals_per_mark || 1);
301                                                         # Always print at least 1 mark for any bucket that has at least
302                                                         # 1 value. This skews the graph a tiny bit, but it allows us to
303                                                         # see all buckets that have values.
304   ***     16     50     66                  127         $n_marks = 1 if $n_marks < 1 && $n_vals > 0;
305           16    100                          71         my $bar = ($n_marks ? '  ' : '') . '#' x $n_marks;
306           16                                 87         push @results, sprintf $bar_fmt, $distro_labels[$i], $bar;
307                                                      }
308                                                   
309            2                                 85      return join("\n", @results) . "\n";
310                                                   }
311                                                   
312                                                   # Makes a header format and returns the format and the column header names.  The
313                                                   # argument is either 'global' or anything else.
314                                                   sub make_header {
315           11                   11            46      my ( $global ) = @_;
316           11                                 37      my $format = "# %-9s %6s %7s %7s %7s %7s %7s %7s %7s";
317           11                                 60      my @headers = qw(pct total min max avg 95% stddev median);
318           11    100                          43      if ( $global ) {
319            3                                 33         $format =~ s/%(\d+)s/' ' x $1/e;
               3                                 31   
320            3                                 10         shift @headers;
321                                                      }
322           11                                117      return $format, @headers;
323                                                   }
324                                                   
325                                                   # Convert attribute names into labels
326                                                   sub make_label {
327           69                   69           248      my ( $val ) = @_;
328                                                   
329           69    100                         285      if ( $val =~ m/^InnoDB/ ) {
330                                                         # Shorten InnoDB attributes otherwise their short labels
331                                                         # are indistinguishable.
332            2                                 29         $val =~ s/^InnoDB_(\w+)/IDB_$1/;
333            2                                 13         $val =~ s/r_(\w+)/r$1/;
334                                                      }
335                                                   
336                                                      return  $val eq 'ts'         ? 'Time range'
337                                                            : $val eq 'user'       ? 'Users'
338                                                            : $val eq 'db'         ? 'Databases'
339                                                            : $val eq 'Query_time' ? 'Exec time'
340                                                            : $val eq 'host'       ? 'Hosts'
341                                                            : $val eq 'Error_no'   ? 'Errors'
342   ***     69     50                         759            : do { $val =~ s/_/ /g; $val = substr($val, 0, 9); $val };
              40    100                         162   
              40    100                         136   
              40    100                         322   
                    100                               
                    100                               
343                                                   }
344                                                   
345                                                   # Does pretty-printing for bool (Yes/No) attributes like QC_Hit.
346                                                   sub format_bool_attrib {
347            2                    2             7      my ( $stats ) = @_;
348                                                      # Since the value is either 1 or 0, the sum is the number of
349                                                      # all true events and the number of false events is the total
350                                                      # number of events minus those that were true.
351            2                                 14      my $p_true  = percentage_of($stats->{sum},  $stats->{cnt});
352            2                                 14      my $p_false = percentage_of($stats->{cnt} - $stats->{sum}, $stats->{cnt});
353            2                                  9      return $p_true;
354                                                   }
355                                                   
356                                                   # Does pretty-printing for lists of strings like users, hosts, db.
357                                                   sub format_string_list {
358           27                   27            88      my ( $stats ) = @_;
359   ***     27     50                          99      if ( exists $stats->{unq} ) {
360                                                         # Only class stats have unq.
361           27                                 79         my $cnt_for = $stats->{unq};
362           27    100                         138         if ( 1 == keys %$cnt_for ) {
363           23                                 87            my ($str) = keys %$cnt_for;
364                                                            # - 30 for label, spacing etc.
365           23    100                         107            $str = substr($str, 0, LINE_LENGTH - 30) . '...'
366                                                               if length $str > LINE_LENGTH - 30;
367           23                                 99            return (1, $str);
368                                                         }
369            4                                 11         my $line = '';
370   ***      4     50                           8         my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
               6                                 51   
371                                                                        keys %$cnt_for;
372            4                                 26         my $i = 0;
373            4                                 15         foreach my $str ( @top ) {
374            9                                 20            my $print_str;
375            9    100                          43            if ( length $str > MAX_STRING_LENGTH ) {
376            5                                 19               $print_str = substr($str, 0, MAX_STRING_LENGTH) . '...';
377                                                            }
378                                                            else {
379            4                                 11               $print_str = $str;
380                                                            }
381            9    100                          41            last if (length $line) + (length $print_str)  > LINE_LENGTH - 27;
382            8                                 40            $line .= "$print_str ($cnt_for->{$str}), ";
383            8                                 24            $i++;
384                                                         }
385            4                                 25         $line =~ s/, $//;
386            4    100                          18         if ( $i < @top ) {
387            1                                  6            $line .= "... " . (@top - $i) . " more";
388                                                         }
389            4                                 26         return (scalar keys %$cnt_for, $line);
390                                                      }
391                                                      else {
392                                                         # Global stats don't have unq.
393   ***      0                                  0         return ($stats->{cnt});
394                                                      }
395                                                   }
396                                                   
397                                                   # Attribs are sorted into three groups: basic attributes (Query_time, etc.),
398                                                   # other non-bool attributes sorted by name, and bool attributes sorted by name.
399                                                   sub sort_attribs {
400           12                   12            81      my ( $ea, @attribs ) = @_;
401           12                                106      my %basic_attrib = (
402                                                         Query_time    => 0,
403                                                         Lock_time     => 1,
404                                                         Rows_sent     => 2,
405                                                         Rows_examined => 3,
406                                                         user          => 4,
407                                                         host          => 5,
408                                                         db            => 6,
409                                                         ts            => 7,
410                                                      );
411           12                                 34      my @basic_attribs;
412           12                                 45      my @non_bool_attribs;
413           12                                 31      my @bool_attribs;
414                                                   
415                                                      ATTRIB:
416           12                                 66      foreach my $attrib ( @attribs ) {
417           94    100                         353         next ATTRIB if $attrib eq 'pos_in_log';  # See issue 471. 
418           91    100                         361         if ( exists $basic_attrib{$attrib} ) {
419           57                                205            push @basic_attribs, $attrib;
420                                                         }
421                                                         else {
422           34    100    100                  137            if ( ($ea->type_for($attrib) || '') ne 'bool' ) {
423           30                                117               push @non_bool_attribs, $attrib;
424                                                            }
425                                                            else {
426            4                                 17               push @bool_attribs, $attrib;
427                                                            }
428                                                         }
429                                                      }
430                                                   
431           12                                 59      @non_bool_attribs = sort { uc $a cmp uc $b } @non_bool_attribs;
              41                                125   
432           12                                 41      @bool_attribs     = sort { uc $a cmp uc $b } @bool_attribs;
               2                                  7   
433           90                                292      @basic_attribs    = sort {
434           12                                 26            $basic_attrib{$a} <=> $basic_attrib{$b} } @basic_attribs;
435                                                   
436           12                                132      return @basic_attribs, @non_bool_attribs, @bool_attribs;
437                                                   }
438                                                   
439                                                   sub _d {
440            1                    1            28      my ($package, undef, $line) = caller 0;
441   ***      2     50                          11      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 30   
442            1                                  5           map { defined $_ ? $_ : 'undef' }
443                                                           @_;
444            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
445                                                   }
446                                                   
447                                                   1;
448                                                   
449                                                   # ###########################################################################
450                                                   # End QueryReportFormatter package
451                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
83           100      2      1   if ($global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || ''))
113          100      3     14   unless $attrib_type
114   ***     50      0     14   unless exists $$stats{'globals'}{$attrib}
115          100      3     11   if ($formatting_function{$attrib}) { }
123          100      9      2   if ($attrib_type eq 'num') { }
      ***     50      0      2   elsif ($attrib_type eq 'string') { }
      ***     50      2      0   elsif ($attrib_type eq 'bool') { }
124          100      5      4   $attrib =~ /time$/ ? :
132   ***     50     63      0   defined $_ ? :
147          100      9      2   unless $attrib_type eq 'bool'
171   ***     50      0      8   unless $store
180          100      3      5   if ($global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || ''))
194   ***     50      8      0   $$ea{'groupby'} eq 'fingerprint' ? :
205          100      5      3   if ($opts{'reason'})
206   ***     50      5      0   $opts{'reason'} eq 'top' ? :
222          100      5     62   unless $attrib_type
223          100      5     57   unless exists $$store{$attrib}
225   ***     50      0     57   unless scalar %$vals
226          100      3     54   if ($formatting_function{$attrib}) { }
234          100     27     27   if ($attrib_type eq 'num') { }
      ***     50     27      0   elsif ($attrib_type eq 'string') { }
      ***      0      0      0   elsif ($attrib_type eq 'bool') { }
235          100     12     15   $attrib =~ /time$/ ? :
242   ***     50    189      0   defined $_ ? :
261   ***     50     54      0   unless $attrib_type eq 'bool'
278   ***     50      0      2   unless defined $vals and scalar @$vals
294          100      1     15   if $n_vals > $max_val
304   ***     50      0     16   if $n_marks < 1 and $n_vals > 0
305          100      1     15   $n_marks ? :
318          100      3      8   if ($global)
329          100      2     67   if ($val =~ /^InnoDB/)
342   ***     50      0     40   $val eq 'Error_no' ? :
             100      3     40   $val eq 'host' ? :
             100     11     43   $val eq 'Query_time' ? :
             100      4     54   $val eq 'db' ? :
             100      5     58   $val eq 'user' ? :
             100      6     63   $val eq 'ts' ? :
359   ***     50     27      0   if (exists $$stats{'unq'}) { }
362          100     23      4   if (1 == keys %$cnt_for)
365          100      3     20   if length $str > 44
370   ***     50      6      0   unless $$cnt_for{$b} <=> $$cnt_for{$a}
375          100      5      4   if (length $str > 10) { }
381          100      1      8   if length($line) + length($print_str) > 47
386          100      1      3   if ($i < @top)
417          100      3     91   if $attrib eq 'pos_in_log'
418          100     57     34   if (exists $basic_attrib{$attrib}) { }
422          100     30      4   if (($ea->type_for($attrib) || '') ne 'bool') { }
441   ***     50      2      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
278   ***     50      0      2   defined $vals and scalar @$vals

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
83    ***     33      0      0      3   $global_cnt and $$stats{'globals'}{'ts'}
      ***     66      0      1      2   $global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || '')
180   ***     66      0      2      6   $global_cnt and $$store{'ts'}
             100      2      3      3   $global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || '')
304   ***     66      1     15      0   $n_marks < 1 and $n_vals > 0

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
83    ***     50      3      0   $$stats{'globals'}{'ts'}{'max'} || ''
      ***     50      3      0   $$stats{'globals'}{'ts'}{'min'} || ''
180   ***     50      6      0   $$store{'ts'}{'max'} || ''
      ***     50      6      0   $$store{'ts'}{'min'} || ''
194   ***     50      8      0   $opts{'rank'} || 0
             100      3      5   $$sample{'pos_in_log'} || 0
300          100      8      8   $vals_per_mark || 1
422          100     32      2   $ea->type_for($attrib) || ''


Covered Subroutines
-------------------

Subroutine         Count Location                                                   
------------------ ----- -----------------------------------------------------------
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:24 
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:25 
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:26 
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:31 
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:32 
BEGIN                  1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:33 
_d                     1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:440
chart_distro           2 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:274
event_report           8 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:165
format_bool_attrib     2 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:347
format_string_list    27 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:358
global_report          3 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:74 
header                 1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:53 
make_header           11 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:315
make_label            69 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:327
new                    1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:48 
sort_attribs          12 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:400


