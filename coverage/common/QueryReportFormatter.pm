---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...n/QueryReportFormatter.pm   97.3   80.0   66.7  100.0    n/a  100.0   89.8
Total                          97.3   80.0   66.7  100.0    n/a  100.0   89.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryReportFormatter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:36 2009
Finish:       Sat Aug 29 15:03:36 2009

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
19                                                    # QueryReportFormatter package $Revision: 4384 $
20                                                    # ###########################################################################
21                                                    
22                                                    package QueryReportFormatter;
23                                                    
24             1                    1             7   use strict;
               1                                  3   
               1                                  7   
25             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
26             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
27                                                    Transformers->import(
28                                                       qw(shorten micro_t parse_timestamp unix_timestamp
29                                                          make_checksum percentage_of));
30                                                    
31             1                    1             6   use constant MKDEBUG           => $ENV{MKDEBUG};
               1                                  3   
               1                                  7   
32             1                    1             6   use constant LINE_LENGTH       => 74;
               1                                  2   
               1                                  4   
33             1                    1             5   use constant MAX_STRING_LENGTH => 10;
               1                                  2   
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
45                                                    my $bool_format = '# %3s%% %-6s %s';
46                                                    
47                                                    sub new {
48             1                    1            14      my ( $class, %args ) = @_;
49             1                                 10      return bless { }, $class;
50                                                    }
51                                                    
52                                                    sub header {
53             1                    1            17      my ($self) = @_;
54                                                    
55             1                                  5      my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
56             1                                  4      eval {
57             1                              14016         my $mem = `ps -o rss,vsz $PID`;
58             1                                 40         ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
59                                                       };
60             1                                 14      ( $user, $system ) = times();
61                                                    
62             1                                 25      sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
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
74             5                    5            80      my ( $self, $ea, %opts ) = @_;
75             5                                 32      my $stats = $ea->results;
76             5                                 14      my @result;
77                                                    
78                                                       # Get global count
79             5                                 29      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
80                                                    
81                                                       # Calculate QPS (queries per second) by looking at the min/max timestamp.
82             5                                 19      my ($qps, $conc) = (0, 0);
83    ***      5    100     66                  116      if ( $global_cnt && $stats->{globals}->{ts}
      ***                   50                        
      ***                   50                        
                           100                        
84                                                          && ($stats->{globals}->{ts}->{max} || '')
85                                                             gt ($stats->{globals}->{ts}->{min} || '')
86                                                       ) {
87             3                                 10         eval {
88             3                                 22            my $min  = parse_timestamp($stats->{globals}->{ts}->{min});
89             3                                 23            my $max  = parse_timestamp($stats->{globals}->{ts}->{max});
90             3                                 21            my $diff = unix_timestamp($max) - unix_timestamp($min);
91             3                                 15            $qps     = $global_cnt / $diff;
92             3                                 22            $conc    = $stats->{globals}->{$opts{worst}}->{sum} / $diff;
93                                                          };
94                                                       }
95                                                    
96                                                       # First line
97                                                       MKDEBUG && _d('global_cnt:', $global_cnt, 'unique:',
98             5                                 13         scalar keys %{$stats->{classes}}, 'qps:', $qps, 'conc:', $conc);
99             5                                 33      my $line = sprintf(
100                                                         '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
101                                                         shorten($global_cnt, d=>1_000),
102            5                                 37         shorten(scalar keys %{$stats->{classes}}, d=>1_000),
103                                                         shorten($qps, d=>1_000),
104                                                         shorten($conc, d=>1_000));
105            5                                 32      $line .= ('_' x (LINE_LENGTH - length($line)));
106            5                                 21      push @result, $line;
107                                                   
108                                                      # Column header line
109            5                                 30      my ($format, @headers) = make_header('global');
110            5                                 33      push @result, sprintf($format, '', @headers);
111                                                   
112                                                      # Each additional line
113            5                                 20      foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
               5                                 35   
114           24                                136         my $attrib_type = $ea->type_for($attrib);
115           24    100                          95         next unless $attrib_type; 
116   ***     21     50                         107         next unless exists $stats->{globals}->{$attrib};
117           21    100                          90         if ( $formatting_function{$attrib} ) { # Handle special cases
118           40                                128            push @result, sprintf $format, make_label($attrib),
119                                                               $formatting_function{$attrib}->($stats->{globals}->{$attrib}),
120            4                                 20               (map { '' } 0..9); # just for good measure
121                                                         }
122                                                         else {
123           17                                 75            my $store = $stats->{globals}->{$attrib};
124           17                                 41            my @values;
125           17    100                          77            if ( $attrib_type eq 'num' ) {
                    100                               
      ***            50                               
126           12    100                          80               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
127           12                                 32               MKDEBUG && _d('Calculating global statistical_metrics for', $attrib);
128           12                                 75               my $metrics = $ea->calculate_statistical_metrics($store->{all}, $store);
129           12                                 89               @values = (
130           12                                 87                  @{$store}{qw(sum min max)},
131                                                                  $store->{sum} / $store->{cnt},
132           12                                 54                  @{$metrics}{qw(pct_95 stddev median)},
133                                                               );
134   ***     12     50                          54               @values = map { defined $_ ? $func->($_) : '' } @values;
              84                                403   
135                                                            }
136                                                            elsif ( $attrib_type eq 'string' ) {
137            1                                  2               MKDEBUG && _d('Ignoring string attrib', $attrib);
138            1                                  6               next;
139                                                            }
140                                                            elsif ( $attrib_type eq 'bool' ) {
141   ***      4    100     66                   42               if ( $store->{sum} > 0 || !$opts{no_zero_bool} ) {
142            3                                 13                  push @result,
143                                                                     sprintf $bool_format, format_bool_attrib($store), $attrib;
144                                                               }
145                                                            }
146                                                            else {
147   ***      0                                  0               @values = ('', $store->{min}, $store->{max}, '', '', '', '');
148                                                            }
149                                                   
150           16    100                         133            push @result, sprintf $format, make_label($attrib), @values
151                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
152                                                         }
153                                                      }
154                                                   
155            5                                 26      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              29                                149   
              29                                159   
156                                                   }
157                                                   
158                                                   # Print a report about the statistics in the EventAggregator.  %opts is a
159                                                   # hash that has the following keys:
160                                                   #  * select       An arrayref of attributes to print statistics lines for.
161                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
162                                                   #  * rank         The (optional) rank of the query, for the header
163                                                   #  * worst        The --orderby attribute
164                                                   #  * reason       Why this one is being reported on: top|outlier
165                                                   # TODO: it would be good to start using $ea->metrics() here for simplicity and
166                                                   # uniform code.
167                                                   sub event_report {
168            8                    8           162      my ( $self, $ea, %opts ) = @_;
169            8                                 47      my $stats = $ea->results;
170            8                                 24      my @result;
171                                                   
172                                                      # Does the data exist?  Is there a sample event?
173            8                                 40      my $store = $stats->{classes}->{$opts{where}};
174   ***      8     50                          36      return "# No such event $opts{where}\n" unless $store;
175            8                                 39      my $sample = $stats->{samples}->{$opts{where}};
176                                                   
177                                                      # Pick the first attribute to get counts
178            8                                 41      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
179            8                                 38      my $class_cnt  = $store->{$opts{worst}}->{cnt};
180                                                   
181                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
182            8                                 30      my ($qps, $conc) = (0, 0);
183   ***      8    100     66                  157      if ( $global_cnt && $store->{ts}
      ***                   50                        
      ***                   50                        
                           100                        
184                                                         && ($store->{ts}->{max} || '')
185                                                            gt ($store->{ts}->{min} || '')
186                                                      ) {
187            3                                 11         eval {
188            3                                 19            my $min  = parse_timestamp($store->{ts}->{min});
189            3                                 18            my $max  = parse_timestamp($store->{ts}->{max});
190            3                                 16            my $diff = unix_timestamp($max) - unix_timestamp($min);
191            3                                 16            $qps     = $class_cnt / $diff;
192            3                                 18            $conc    = $store->{$opts{worst}}->{sum} / $diff;
193                                                         };
194                                                      }
195                                                   
196                                                      # First line
197   ***      8     50     50                   81      my $line = sprintf(
                           100                        
198                                                         '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
199                                                         ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
200                                                         $opts{rank} || 0,
201                                                         shorten($qps, d=>1_000),
202                                                         shorten($conc, d=>1_000),
203                                                         make_checksum($opts{where}),
204                                                         $sample->{pos_in_log} || 0);
205            8                                 45      $line .= ('_' x (LINE_LENGTH - length($line)));
206            8                                 27      push @result, $line;
207                                                   
208            8    100                          41      if ( $opts{reason} ) {
209   ***      5     50                          34         push @result, "# This item is included in the report because it matches "
210                                                            . ($opts{reason} eq 'top' ? '--limit.' : '--outliers.');
211                                                      }
212                                                   
213                                                      # Column header line
214            8                                 57      my ($format, @headers) = make_header();
215            8                                 60      push @result, sprintf($format, '', @headers);
216                                                   
217                                                      # Count line
218           72                                259      push @result, sprintf
219                                                         $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
220            8                                 49            map { '' } (1 ..9);
221                                                   
222                                                      # Each additional line
223            8                                 33      foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
               8                                 46   
224           67                                289         my $attrib_type = $ea->type_for($attrib);
225           67    100                         246         next unless $attrib_type; 
226           62    100                         253         next unless exists $store->{$attrib};
227           57                                186         my $vals = $store->{$attrib};
228   ***     57     50                         281         next unless scalar %$vals;
229           57    100                         219         if ( $formatting_function{$attrib} ) { # Handle special cases
230           30                                 96            push @result, sprintf $format, make_label($attrib),
231                                                               $formatting_function{$attrib}->($vals),
232            3                                 14               (map { '' } 0..9); # just for good measure
233                                                         }
234                                                         else {
235           54                                123            my @values;
236           54                                123            my $pct;
237           54    100                         216            if ( $attrib_type eq 'num' ) {
      ***            50                               
      ***             0                               
238           27    100                         143               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
239           27                                143               my $metrics = $ea->calculate_statistical_metrics($vals->{all}, $vals);
240           27                                169               @values = (
241           27                                181                  @{$vals}{qw(sum min max)},
242                                                                  $vals->{sum} / $vals->{cnt},
243           27                                 96                  @{$metrics}{qw(pct_95 stddev median)},
244                                                               );
245   ***     27     50                         101               @values = map { defined $_ ? $func->($_) : '' } @values;
             189                                881   
246           27                                213               $pct = percentage_of($vals->{sum},
247                                                                  $stats->{globals}->{$attrib}->{sum});
248                                                            }
249                                                            elsif ( $attrib_type eq 'string' ) {
250          270                               1742               push @values,
251                                                                  format_string_list($vals),
252           27                                109                  (map { '' } 0..9); # just for good measure
253           27                                 89               $pct = '';
254                                                            }
255                                                            elsif ( $attrib_type eq 'bool' ) {
256   ***      0      0      0                    0               if ( $vals->{sum} > 0 || !$opts{no_zero_bool} ) {
257   ***      0                                  0                  push @result,
258                                                                     sprintf $bool_format, format_bool_attrib($vals), $attrib;
259                                                               }
260                                                            }
261                                                            else {
262   ***      0                                  0               @values = ('', $vals->{min}, $vals->{max}, '', '', '', '');
263   ***      0                                  0               $pct = 0;
264                                                            }
265                                                   
266   ***     54     50                         306            push @result, sprintf $format, make_label($attrib), $pct, @values
267                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
268                                                         }
269                                                      }
270                                                   
271            8                                 40      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              86                                424   
              86                                413   
272                                                   }
273                                                   
274                                                   # Creates a chart of value distributions in buckets.  Right now it bucketizes
275                                                   # into 8 buckets, powers of ten starting with .000001. %opts has:
276                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
277                                                   #  * attribute    An attribute to chart.
278                                                   sub chart_distro {
279            2                    2            47      my ( $self, $ea, %opts ) = @_;
280            2                                 13      my $stats = $ea->results;
281            2                                 16      my $store = $stats->{classes}->{$opts{where}}->{$opts{attribute}};
282            2                                  7      my $vals  = $store->{all};
283   ***      2     50     50                   27      return "" unless defined $vals && scalar @$vals;
284                                                      # TODO: this is broken.
285            2                                 14      my @buck_tens = $ea->buckets_of(10);
286            2                                 93      my @distro = map { 0 } (0 .. 7);
              16                                 46   
287            2                                 89      map { $distro[$buck_tens[$_]] += $vals->[$_] } (1 .. @$vals - 1);
            1998                               7452   
288                                                   
289            2                                 93      my $max_val = 0;
290            2                                  4      my $vals_per_mark; # number of vals represented by 1 #-mark
291            2                                  6      my $max_disp_width = 64;
292            2                                  7      my $bar_fmt = "# %5s%s";
293            2                                 14      my @distro_labels = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
294            2                                 21      my @results = "# $opts{attribute} distribution";
295                                                   
296                                                      # Find the distro with the most values. This will set
297                                                      # vals_per_mark and become the bar at max_disp_width.
298            2                                 14      foreach my $n_vals ( @distro ) {
299           16    100                          70         $max_val = $n_vals if $n_vals > $max_val;
300                                                      }
301            2                                  9      $vals_per_mark = $max_val / $max_disp_width;
302                                                   
303            2                                 14      foreach my $i ( 0 .. $#distro ) {
304           16                                 47         my $n_vals = $distro[$i];
305           16           100                   90         my $n_marks = $n_vals / ($vals_per_mark || 1);
306                                                         # Always print at least 1 mark for any bucket that has at least
307                                                         # 1 value. This skews the graph a tiny bit, but it allows us to
308                                                         # see all buckets that have values.
309   ***     16     50     66                  119         $n_marks = 1 if $n_marks < 1 && $n_vals > 0;
310           16    100                          70         my $bar = ($n_marks ? '  ' : '') . '#' x $n_marks;
311           16                                110         push @results, sprintf $bar_fmt, $distro_labels[$i], $bar;
312                                                      }
313                                                   
314            2                                 68      return join("\n", @results) . "\n";
315                                                   }
316                                                   
317                                                   # Makes a header format and returns the format and the column header names.  The
318                                                   # argument is either 'global' or anything else.
319                                                   sub make_header {
320           13                   13            58      my ( $global ) = @_;
321           13                                 46      my $format = "# %-9s %6s %7s %7s %7s %7s %7s %7s %7s";
322           13                                 83      my @headers = qw(pct total min max avg 95% stddev median);
323           13    100                          83      if ( $global ) {
324            5                                 50         $format =~ s/%(\d+)s/' ' x $1/e;
               5                                 43   
325            5                                 16         shift @headers;
326                                                      }
327           13                                138      return $format, @headers;
328                                                   }
329                                                   
330                                                   # Convert attribute names into labels
331                                                   sub make_label {
332           73                   73           276      my ( $val ) = @_;
333                                                   
334           73    100                         320      if ( $val =~ m/^InnoDB/ ) {
335                                                         # Shorten InnoDB attributes otherwise their short labels
336                                                         # are indistinguishable.
337            2                                 22         $val =~ s/^InnoDB_(\w+)/IDB_$1/;
338            2                                 11         $val =~ s/r_(\w+)/r$1/;
339                                                      }
340                                                   
341                                                      return  $val eq 'ts'         ? 'Time range'
342                                                            : $val eq 'user'       ? 'Users'
343                                                            : $val eq 'db'         ? 'Databases'
344                                                            : $val eq 'Query_time' ? 'Exec time'
345                                                            : $val eq 'host'       ? 'Hosts'
346                                                            : $val eq 'Error_no'   ? 'Errors'
347   ***     73     50                         702            : do { $val =~ s/_/ /g; $val = substr($val, 0, 9); $val };
              41    100                         174   
              41    100                         146   
              41    100                         351   
                    100                               
                    100                               
348                                                   }
349                                                   
350                                                   # Does pretty-printing for bool (Yes/No) attributes like QC_Hit.
351                                                   sub format_bool_attrib {
352            3                    3            11      my ( $stats ) = @_;
353                                                      # Since the value is either 1 or 0, the sum is the number of
354                                                      # all true events and the number of false events is the total
355                                                      # number of events minus those that were true.
356            3                                 18      my $p_true  = percentage_of($stats->{sum},  $stats->{cnt});
357                                                      # my $p_false = percentage_of($stats->{cnt} - $stats->{sum}, $stats->{cnt});
358            3                                 18      my $n_true = '(' . shorten($stats->{sum}, d=>1_000, p=>0) . ')';
359            3                                 19      return $p_true, $n_true;
360                                                   }
361                                                   
362                                                   # Does pretty-printing for lists of strings like users, hosts, db.
363                                                   sub format_string_list {
364           27                   27            91      my ( $stats ) = @_;
365   ***     27     50                         109      if ( exists $stats->{unq} ) {
366                                                         # Only class stats have unq.
367           27                                 82         my $cnt_for = $stats->{unq};
368           27    100                         144         if ( 1 == keys %$cnt_for ) {
369           23                                 94            my ($str) = keys %$cnt_for;
370                                                            # - 30 for label, spacing etc.
371           23    100                         101            $str = substr($str, 0, LINE_LENGTH - 30) . '...'
372                                                               if length $str > LINE_LENGTH - 30;
373           23                                107            return (1, $str);
374                                                         }
375            4                                 13         my $line = '';
376   ***      4     50                           7         my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
               6                                 58   
377                                                                        keys %$cnt_for;
378            4                                 27         my $i = 0;
379            4                                 15         foreach my $str ( @top ) {
380            9                                 22            my $print_str;
381            9    100                          35            if ( length $str > MAX_STRING_LENGTH ) {
382            5                                 20               $print_str = substr($str, 0, MAX_STRING_LENGTH) . '...';
383                                                            }
384                                                            else {
385            4                                 12               $print_str = $str;
386                                                            }
387            9    100                          54            last if (length $line) + (length $print_str)  > LINE_LENGTH - 27;
388            8                                 45            $line .= "$print_str ($cnt_for->{$str}), ";
389            8                                 26            $i++;
390                                                         }
391            4                                 24         $line =~ s/, $//;
392            4    100                          19         if ( $i < @top ) {
393            1                                  6            $line .= "... " . (@top - $i) . " more";
394                                                         }
395            4                                 32         return (scalar keys %$cnt_for, $line);
396                                                      }
397                                                      else {
398                                                         # Global stats don't have unq.
399   ***      0                                  0         return ($stats->{cnt});
400                                                      }
401                                                   }
402                                                   
403                                                   # Attribs are sorted into three groups: basic attributes (Query_time, etc.),
404                                                   # other non-bool attributes sorted by name, and bool attributes sorted by name.
405                                                   sub sort_attribs {
406           14                   14            93      my ( $ea, @attribs ) = @_;
407           14                                136      my %basic_attrib = (
408                                                         Query_time    => 0,
409                                                         Lock_time     => 1,
410                                                         Rows_sent     => 2,
411                                                         Rows_examined => 3,
412                                                         user          => 4,
413                                                         host          => 5,
414                                                         db            => 6,
415                                                         ts            => 7,
416                                                      );
417           14                                 39      my @basic_attribs;
418           14                                 29      my @non_bool_attribs;
419           14                                 41      my @bool_attribs;
420                                                   
421                                                      ATTRIB:
422           14                                 60      foreach my $attrib ( @attribs ) {
423          101    100                         372         next ATTRIB if $attrib eq 'pos_in_log';  # See issue 471. 
424           98    100                         334         if ( exists $basic_attrib{$attrib} ) {
425           62                                237            push @basic_attribs, $attrib;
426                                                         }
427                                                         else {
428           36    100    100                  149            if ( ($ea->type_for($attrib) || '') ne 'bool' ) {
429           30                                115               push @non_bool_attribs, $attrib;
430                                                            }
431                                                            else {
432            6                                 25               push @bool_attribs, $attrib;
433                                                            }
434                                                         }
435                                                      }
436                                                   
437           14                                 71      @non_bool_attribs = sort { uc $a cmp uc $b } @non_bool_attribs;
              41                                116   
438           14                                 49      @bool_attribs     = sort { uc $a cmp uc $b } @bool_attribs;
               3                                 11   
439           94                                536      @basic_attribs    = sort {
440           14                                 28            $basic_attrib{$a} <=> $basic_attrib{$b} } @basic_attribs;
441                                                   
442           14                                145      return @basic_attribs, @non_bool_attribs, @bool_attribs;
443                                                   }
444                                                   
445                                                   sub _d {
446            1                    1            34      my ($package, undef, $line) = caller 0;
447   ***      2     50                          11      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 11   
448            1                                  6           map { defined $_ ? $_ : 'undef' }
449                                                           @_;
450            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
451                                                   }
452                                                   
453                                                   1;
454                                                   
455                                                   # ###########################################################################
456                                                   # End QueryReportFormatter package
457                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
83           100      3      2   if ($global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || ''))
115          100      3     21   unless $attrib_type
116   ***     50      0     21   unless exists $$stats{'globals'}{$attrib}
117          100      4     17   if ($formatting_function{$attrib}) { }
125          100     12      5   if ($attrib_type eq 'num') { }
             100      1      4   elsif ($attrib_type eq 'string') { }
      ***     50      4      0   elsif ($attrib_type eq 'bool') { }
126          100      8      4   $attrib =~ /time$/ ? :
134   ***     50     84      0   defined $_ ? :
141          100      3      1   if ($$store{'sum'} > 0 or not $opts{'no_zero_bool'})
150          100     12      4   unless $attrib_type eq 'bool'
174   ***     50      0      8   unless $store
183          100      3      5   if ($global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || ''))
197   ***     50      8      0   $$ea{'groupby'} eq 'fingerprint' ? :
208          100      5      3   if ($opts{'reason'})
209   ***     50      5      0   $opts{'reason'} eq 'top' ? :
225          100      5     62   unless $attrib_type
226          100      5     57   unless exists $$store{$attrib}
228   ***     50      0     57   unless scalar %$vals
229          100      3     54   if ($formatting_function{$attrib}) { }
237          100     27     27   if ($attrib_type eq 'num') { }
      ***     50     27      0   elsif ($attrib_type eq 'string') { }
      ***      0      0      0   elsif ($attrib_type eq 'bool') { }
238          100     12     15   $attrib =~ /time$/ ? :
245   ***     50    189      0   defined $_ ? :
256   ***      0      0      0   if ($$vals{'sum'} > 0 or not $opts{'no_zero_bool'})
266   ***     50     54      0   unless $attrib_type eq 'bool'
283   ***     50      0      2   unless defined $vals and scalar @$vals
299          100      1     15   if $n_vals > $max_val
309   ***     50      0     16   if $n_marks < 1 and $n_vals > 0
310          100      1     15   $n_marks ? :
323          100      5      8   if ($global)
334          100      2     71   if ($val =~ /^InnoDB/)
347   ***     50      0     41   $val eq 'Error_no' ? :
             100      3     41   $val eq 'host' ? :
             100     13     44   $val eq 'Query_time' ? :
             100      4     57   $val eq 'db' ? :
             100      5     61   $val eq 'user' ? :
             100      7     66   $val eq 'ts' ? :
365   ***     50     27      0   if (exists $$stats{'unq'}) { }
368          100     23      4   if (1 == keys %$cnt_for)
371          100      3     20   if length $str > 44
376   ***     50      6      0   unless $$cnt_for{$b} <=> $$cnt_for{$a}
381          100      5      4   if (length $str > 10) { }
387          100      1      8   if length($line) + length($print_str) > 47
392          100      1      3   if ($i < @top)
423          100      3     98   if $attrib eq 'pos_in_log'
424          100     62     36   if (exists $basic_attrib{$attrib}) { }
428          100     30      6   if (($ea->type_for($attrib) || '') ne 'bool') { }
447   ***     50      2      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
283   ***     50      0      2   defined $vals and scalar @$vals

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
83    ***     66      0      1      4   $global_cnt and $$stats{'globals'}{'ts'}
             100      1      1      3   $global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || '')
183   ***     66      0      2      6   $global_cnt and $$store{'ts'}
             100      2      3      3   $global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || '')
309   ***     66      1     15      0   $n_marks < 1 and $n_vals > 0

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
83    ***     50      4      0   $$stats{'globals'}{'ts'}{'max'} || ''
      ***     50      4      0   $$stats{'globals'}{'ts'}{'min'} || ''
183   ***     50      6      0   $$store{'ts'}{'max'} || ''
      ***     50      6      0   $$store{'ts'}{'min'} || ''
197   ***     50      8      0   $opts{'rank'} || 0
             100      3      5   $$sample{'pos_in_log'} || 0
305          100      8      8   $vals_per_mark || 1
428          100     34      2   $ea->type_for($attrib) || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
141   ***     66      3      0      1   $$store{'sum'} > 0 or not $opts{'no_zero_bool'}
256   ***      0      0      0      0   $$vals{'sum'} > 0 or not $opts{'no_zero_bool'}


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
_d                     1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:446
chart_distro           2 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:279
event_report           8 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:168
format_bool_attrib     3 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:352
format_string_list    27 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:364
global_report          5 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:74 
header                 1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:53 
make_header           13 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:320
make_label            73 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:332
new                    1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:48 
sort_attribs          14 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:406


