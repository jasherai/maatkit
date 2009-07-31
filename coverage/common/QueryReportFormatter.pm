---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...n/QueryReportFormatter.pm   96.5   79.0   61.5  100.0    n/a  100.0   88.5
Total                          96.5   79.0   61.5  100.0    n/a  100.0   88.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryReportFormatter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:13 2009
Finish:       Fri Jul 31 18:53:13 2009

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
19                                                    # QueryReportFormatter package $Revision: 4205 $
20                                                    # ###########################################################################
21                                                    
22                                                    package QueryReportFormatter;
23                                                    
24             1                    1             6   use strict;
               1                                  3   
               1                                  5   
25             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
26             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  5   
27                                                    Transformers->import(
28                                                       qw(shorten micro_t parse_timestamp unix_timestamp
29                                                          make_checksum percentage_of));
30                                                    
31             1                    1             7   use constant MKDEBUG           => $ENV{MKDEBUG};
               1                                  6   
               1                                  6   
32             1                    1             6   use constant LINE_LENGTH       => 74;
               1                                  2   
               1                                  5   
33             1                    1             6   use constant MAX_STRING_LENGTH => 10;
               1                                  6   
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
48             1                    1            12      my ( $class, %args ) = @_;
49             1                                 11      return bless { }, $class;
50                                                    }
51                                                    
52                                                    sub header {
53             1                    1            10      my ($self) = @_;
54                                                    
55             1                                 12      my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
56             1                                  3      eval {
57             1                              10018         my $mem = `ps -o rss,vsz $PID`;
58             1                                 39         ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
59                                                       };
60             1                                 13      ( $user, $system ) = times();
61                                                    
62             1                                 41      sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
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
74             4                    4            67      my ( $self, $ea, %opts ) = @_;
75             4                                 23      my $stats = $ea->results;
76             4                                 12      my @result;
77                                                    
78                                                       # Get global count
79             4                                 18      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
80                                                    
81                                                       # Calculate QPS (queries per second) by looking at the min/max timestamp.
82             4                                 15      my ($qps, $conc) = (0, 0);
83    ***      4    100     33                   99      if ( $global_cnt && $stats->{globals}->{ts}
      ***                   50                        
      ***                   50                        
      ***                   66                        
84                                                          && ($stats->{globals}->{ts}->{max} || '')
85                                                             gt ($stats->{globals}->{ts}->{min} || '')
86                                                       ) {
87             3                                  9         eval {
88             3                                 24            my $min  = parse_timestamp($stats->{globals}->{ts}->{min});
89             3                                 21            my $max  = parse_timestamp($stats->{globals}->{ts}->{max});
90             3                                 20            my $diff = unix_timestamp($max) - unix_timestamp($min);
91             3                                 15            $qps     = $global_cnt / $diff;
92             3                                 21            $conc    = $stats->{globals}->{$opts{worst}}->{sum} / $diff;
93                                                          };
94                                                       }
95                                                    
96                                                       # First line
97                                                       MKDEBUG && _d('global_cnt:', $global_cnt, 'unique:',
98             4                                 10         scalar keys %{$stats->{classes}}, 'qps:', $qps, 'conc:', $conc);
99             4                                 23      my $line = sprintf(
100                                                         '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
101                                                         shorten($global_cnt, d=>1_000),
102            4                                 25         shorten(scalar keys %{$stats->{classes}}, d=>1_000),
103                                                         shorten($qps, d=>1_000),
104                                                         shorten($conc, d=>1_000));
105            4                                 23      $line .= ('_' x (LINE_LENGTH - length($line)));
106            4                                 15      push @result, $line;
107                                                   
108                                                      # Column header line
109            4                                 25      my ($format, @headers) = make_header('global');
110            4                                 28      push @result, sprintf($format, '', @headers);
111                                                   
112                                                      # Each additional line
113            4                                 12      foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
               4                                 29   
114           22                                 93         my $attrib_type = $ea->type_for($attrib);
115           22    100                          82         next unless $attrib_type; 
116   ***     19     50                          88         next unless exists $stats->{globals}->{$attrib};
117           19    100                         296         if ( $formatting_function{$attrib} ) { # Handle special cases
118           40                                129            push @result, sprintf $format, make_label($attrib),
119                                                               $formatting_function{$attrib}->($stats->{globals}->{$attrib}),
120            4                                 20               (map { '' } 0..9); # just for good measure
121                                                         }
122                                                         else {
123           15                                 60            my $store = $stats->{globals}->{$attrib};
124           15                                 35            my @values;
125           15    100                          64            if ( $attrib_type eq 'num' ) {
      ***            50                               
      ***            50                               
126           11    100                          59               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
127           11                                 24               MKDEBUG && _d('Calculating global statistical_metrics for', $attrib);
128           11                                 62               my $metrics = $ea->calculate_statistical_metrics($store->{all}, $store);
129           11                                 69               @values = (
130           11                                 68                  @{$store}{qw(sum min max)},
131                                                                  $store->{sum} / $store->{cnt},
132           11                                 36                  @{$metrics}{qw(pct_95 stddev median)},
133                                                               );
134   ***     11     50                          44               @values = map { defined $_ ? $func->($_) : '' } @values;
              77                                344   
135                                                            }
136                                                            elsif ( $attrib_type eq 'string' ) {
137   ***      0                                  0               push @values,
138                                                                  format_string_list($store),
139   ***      0                                  0                  (map { '' } 0..9); # just for good measure
140                                                            }
141                                                            elsif ( $attrib_type eq 'bool' ) {
142   ***      4    100     66                   35               if ( $store->{sum} > 0 || !$opts{no_zero_bool} ) {
143            3                                 14                  push @result,
144                                                                     sprintf $bool_format, format_bool_attrib($store), $attrib;
145                                                               }
146                                                            }
147                                                            else {
148   ***      0                                  0               @values = ('', $store->{min}, $store->{max}, '', '', '', '');
149                                                            }
150                                                   
151           15    100                         102            push @result, sprintf $format, make_label($attrib), @values
152                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
153                                                         }
154                                                      }
155                                                   
156            4                                 16      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              26                                126   
              26                                113   
157                                                   }
158                                                   
159                                                   # Print a report about the statistics in the EventAggregator.  %opts is a
160                                                   # hash that has the following keys:
161                                                   #  * select       An arrayref of attributes to print statistics lines for.
162                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
163                                                   #  * rank         The (optional) rank of the query, for the header
164                                                   #  * worst        The --orderby attribute
165                                                   #  * reason       Why this one is being reported on: top|outlier
166                                                   # TODO: it would be good to start using $ea->metrics() here for simplicity and
167                                                   # uniform code.
168                                                   sub event_report {
169            8                    8           150      my ( $self, $ea, %opts ) = @_;
170            8                                 47      my $stats = $ea->results;
171            8                                 21      my @result;
172                                                   
173                                                      # Does the data exist?  Is there a sample event?
174            8                                 38      my $store = $stats->{classes}->{$opts{where}};
175   ***      8     50                          36      return "# No such event $opts{where}\n" unless $store;
176            8                                 37      my $sample = $stats->{samples}->{$opts{where}};
177                                                   
178                                                      # Pick the first attribute to get counts
179            8                                 36      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
180            8                                 33      my $class_cnt  = $store->{$opts{worst}}->{cnt};
181                                                   
182                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
183            8                                 27      my ($qps, $conc) = (0, 0);
184   ***      8    100     66                  138      if ( $global_cnt && $store->{ts}
      ***                   50                        
      ***                   50                        
                           100                        
185                                                         && ($store->{ts}->{max} || '')
186                                                            gt ($store->{ts}->{min} || '')
187                                                      ) {
188            3                                  9         eval {
189            3                                 16            my $min  = parse_timestamp($store->{ts}->{min});
190            3                                 19            my $max  = parse_timestamp($store->{ts}->{max});
191            3                                 16            my $diff = unix_timestamp($max) - unix_timestamp($min);
192            3                                 15            $qps     = $class_cnt / $diff;
193            3                                 16            $conc    = $store->{$opts{worst}}->{sum} / $diff;
194                                                         };
195                                                      }
196                                                   
197                                                      # First line
198   ***      8     50     50                   78      my $line = sprintf(
                           100                        
199                                                         '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
200                                                         ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
201                                                         $opts{rank} || 0,
202                                                         shorten($qps, d=>1_000),
203                                                         shorten($conc, d=>1_000),
204                                                         make_checksum($opts{where}),
205                                                         $sample->{pos_in_log} || 0);
206            8                                 40      $line .= ('_' x (LINE_LENGTH - length($line)));
207            8                                 28      push @result, $line;
208                                                   
209            8    100                          39      if ( $opts{reason} ) {
210   ***      5     50                          30         push @result, "# This item is included in the report because it matches "
211                                                            . ($opts{reason} eq 'top' ? '--limit.' : '--outliers.');
212                                                      }
213                                                   
214                                                      # Column header line
215            8                                 33      my ($format, @headers) = make_header();
216            8                                 56      push @result, sprintf($format, '', @headers);
217                                                   
218                                                      # Count line
219           72                                217      push @result, sprintf
220                                                         $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
221            8                                 40            map { '' } (1 ..9);
222                                                   
223                                                      # Each additional line
224            8                                 30      foreach my $attrib ( sort_attribs($ea, @{$opts{select}}) ) {
               8                                 43   
225           67                                278         my $attrib_type = $ea->type_for($attrib);
226           67    100                         242         next unless $attrib_type; 
227           62    100                         260         next unless exists $store->{$attrib};
228           57                                177         my $vals = $store->{$attrib};
229   ***     57     50                         257         next unless scalar %$vals;
230           57    100                         216         if ( $formatting_function{$attrib} ) { # Handle special cases
231           30                                 94            push @result, sprintf $format, make_label($attrib),
232                                                               $formatting_function{$attrib}->($vals),
233            3                                 13               (map { '' } 0..9); # just for good measure
234                                                         }
235                                                         else {
236           54                                117            my @values;
237           54                                124            my $pct;
238           54    100                         210            if ( $attrib_type eq 'num' ) {
      ***            50                               
      ***             0                               
239           27    100                         136               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
240           27                                134               my $metrics = $ea->calculate_statistical_metrics($vals->{all}, $vals);
241           27                                163               @values = (
242           27                                153                  @{$vals}{qw(sum min max)},
243                                                                  $vals->{sum} / $vals->{cnt},
244           27                                 89                  @{$metrics}{qw(pct_95 stddev median)},
245                                                               );
246   ***     27     50                         103               @values = map { defined $_ ? $func->($_) : '' } @values;
             189                                870   
247           27                                192               $pct = percentage_of($vals->{sum},
248                                                                  $stats->{globals}->{$attrib}->{sum});
249                                                            }
250                                                            elsif ( $attrib_type eq 'string' ) {
251          270                                780               push @values,
252                                                                  format_string_list($vals),
253           27                                123                  (map { '' } 0..9); # just for good measure
254           27                                 85               $pct = '';
255                                                            }
256                                                            elsif ( $attrib_type eq 'bool' ) {
257   ***      0      0      0                    0               if ( $vals->{sum} > 0 || !$opts{no_zero_bool} ) {
258   ***      0                                  0                  push @result,
259                                                                     sprintf $bool_format, format_bool_attrib($vals), $attrib;
260                                                               }
261                                                            }
262                                                            else {
263   ***      0                                  0               @values = ('', $vals->{min}, $vals->{max}, '', '', '', '');
264   ***      0                                  0               $pct = 0;
265                                                            }
266                                                   
267   ***     54     50                         307            push @result, sprintf $format, make_label($attrib), $pct, @values
268                                                               unless $attrib_type eq 'bool';  # bool does its own thing.
269                                                         }
270                                                      }
271                                                   
272            8                                 37      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              86                                398   
              86                                372   
273                                                   }
274                                                   
275                                                   # Creates a chart of value distributions in buckets.  Right now it bucketizes
276                                                   # into 8 buckets, powers of ten starting with .000001. %opts has:
277                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
278                                                   #  * attribute    An attribute to chart.
279                                                   sub chart_distro {
280            2                    2            34      my ( $self, $ea, %opts ) = @_;
281            2                                  9      my $stats = $ea->results;
282            2                                 12      my $store = $stats->{classes}->{$opts{where}}->{$opts{attribute}};
283            2                                  6      my $vals  = $store->{all};
284   ***      2     50     50                   22      return "" unless defined $vals && scalar @$vals;
285                                                      # TODO: this is broken.
286            2                                 12      my @buck_tens = $ea->buckets_of(10);
287            2                                 92      my @distro = map { 0 } (0 .. 7);
              16                                 57   
288            2                                 88      map { $distro[$buck_tens[$_]] += $vals->[$_] } (1 .. @$vals - 1);
            1998                               7523   
289                                                   
290            2                                 87      my $max_val = 0;
291            2                                  5      my $vals_per_mark; # number of vals represented by 1 #-mark
292            2                                  6      my $max_disp_width = 64;
293            2                                  6      my $bar_fmt = "# %5s%s";
294            2                                 15      my @distro_labels = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
295            2                                 12      my @results = "# $opts{attribute} distribution";
296                                                   
297                                                      # Find the distro with the most values. This will set
298                                                      # vals_per_mark and become the bar at max_disp_width.
299            2                                 11      foreach my $n_vals ( @distro ) {
300           16    100                          72         $max_val = $n_vals if $n_vals > $max_val;
301                                                      }
302            2                                  9      $vals_per_mark = $max_val / $max_disp_width;
303                                                   
304            2                                 14      foreach my $i ( 0 .. $#distro ) {
305           16                                 44         my $n_vals = $distro[$i];
306           16           100                   91         my $n_marks = $n_vals / ($vals_per_mark || 1);
307                                                         # Always print at least 1 mark for any bucket that has at least
308                                                         # 1 value. This skews the graph a tiny bit, but it allows us to
309                                                         # see all buckets that have values.
310   ***     16     50     66                  122         $n_marks = 1 if $n_marks < 1 && $n_vals > 0;
311           16    100                          66         my $bar = ($n_marks ? '  ' : '') . '#' x $n_marks;
312           16                                 82         push @results, sprintf $bar_fmt, $distro_labels[$i], $bar;
313                                                      }
314                                                   
315            2                                 61      return join("\n", @results) . "\n";
316                                                   }
317                                                   
318                                                   # Makes a header format and returns the format and the column header names.  The
319                                                   # argument is either 'global' or anything else.
320                                                   sub make_header {
321           12                   12            48      my ( $global ) = @_;
322           12                                 40      my $format = "# %-9s %6s %7s %7s %7s %7s %7s %7s %7s";
323           12                                 63      my @headers = qw(pct total min max avg 95% stddev median);
324           12    100                          50      if ( $global ) {
325            4                                 34         $format =~ s/%(\d+)s/' ' x $1/e;
               4                                 34   
326            4                                 13         shift @headers;
327                                                      }
328           12                                106      return $format, @headers;
329                                                   }
330                                                   
331                                                   # Convert attribute names into labels
332                                                   sub make_label {
333           72                   72           251      my ( $val ) = @_;
334                                                   
335           72    100                         378      if ( $val =~ m/^InnoDB/ ) {
336                                                         # Shorten InnoDB attributes otherwise their short labels
337                                                         # are indistinguishable.
338            2                                 23         $val =~ s/^InnoDB_(\w+)/IDB_$1/;
339            2                                 12         $val =~ s/r_(\w+)/r$1/;
340                                                      }
341                                                   
342                                                      return  $val eq 'ts'         ? 'Time range'
343                                                            : $val eq 'user'       ? 'Users'
344                                                            : $val eq 'db'         ? 'Databases'
345                                                            : $val eq 'Query_time' ? 'Exec time'
346                                                            : $val eq 'host'       ? 'Hosts'
347                                                            : $val eq 'Error_no'   ? 'Errors'
348   ***     72     50                         657            : do { $val =~ s/_/ /g; $val = substr($val, 0, 9); $val };
              41    100                         164   
              41    100                         135   
              41    100                         314   
                    100                               
                    100                               
349                                                   }
350                                                   
351                                                   # Does pretty-printing for bool (Yes/No) attributes like QC_Hit.
352                                                   sub format_bool_attrib {
353            3                    3            12      my ( $stats ) = @_;
354                                                      # Since the value is either 1 or 0, the sum is the number of
355                                                      # all true events and the number of false events is the total
356                                                      # number of events minus those that were true.
357            3                                 16      my $p_true  = percentage_of($stats->{sum},  $stats->{cnt});
358                                                      # my $p_false = percentage_of($stats->{cnt} - $stats->{sum}, $stats->{cnt});
359            3                                 16      my $n_true = '(' . shorten($stats->{sum}, d=>1_000, p=>0) . ')';
360            3                                 18      return $p_true, $n_true;
361                                                   }
362                                                   
363                                                   # Does pretty-printing for lists of strings like users, hosts, db.
364                                                   sub format_string_list {
365           27                   27            88      my ( $stats ) = @_;
366   ***     27     50                         101      if ( exists $stats->{unq} ) {
367                                                         # Only class stats have unq.
368           27                                 86         my $cnt_for = $stats->{unq};
369           27    100                         132         if ( 1 == keys %$cnt_for ) {
370           23                                 87            my ($str) = keys %$cnt_for;
371                                                            # - 30 for label, spacing etc.
372           23    100                         104            $str = substr($str, 0, LINE_LENGTH - 30) . '...'
373                                                               if length $str > LINE_LENGTH - 30;
374           23                                106            return (1, $str);
375                                                         }
376            4                                 12         my $line = '';
377   ***      4     50                           9         my @top = sort { $cnt_for->{$b} <=> $cnt_for->{$a} || $a cmp $b }
               6                                 50   
378                                                                        keys %$cnt_for;
379            4                                 24         my $i = 0;
380            4                                 16         foreach my $str ( @top ) {
381            9                                 21            my $print_str;
382            9    100                          32            if ( length $str > MAX_STRING_LENGTH ) {
383            5                                 17               $print_str = substr($str, 0, MAX_STRING_LENGTH) . '...';
384                                                            }
385                                                            else {
386            4                                 11               $print_str = $str;
387                                                            }
388            9    100                          42            last if (length $line) + (length $print_str)  > LINE_LENGTH - 27;
389            8                                 40            $line .= "$print_str ($cnt_for->{$str}), ";
390            8                                 29            $i++;
391                                                         }
392            4                                 20         $line =~ s/, $//;
393            4    100                          17         if ( $i < @top ) {
394            1                                  6            $line .= "... " . (@top - $i) . " more";
395                                                         }
396            4                                 24         return (scalar keys %$cnt_for, $line);
397                                                      }
398                                                      else {
399                                                         # Global stats don't have unq.
400   ***      0                                  0         return ($stats->{cnt});
401                                                      }
402                                                   }
403                                                   
404                                                   # Attribs are sorted into three groups: basic attributes (Query_time, etc.),
405                                                   # other non-bool attributes sorted by name, and bool attributes sorted by name.
406                                                   sub sort_attribs {
407           13                   13            77      my ( $ea, @attribs ) = @_;
408           13                                108      my %basic_attrib = (
409                                                         Query_time    => 0,
410                                                         Lock_time     => 1,
411                                                         Rows_sent     => 2,
412                                                         Rows_examined => 3,
413                                                         user          => 4,
414                                                         host          => 5,
415                                                         db            => 6,
416                                                         ts            => 7,
417                                                      );
418           13                                 34      my @basic_attribs;
419           13                                 30      my @non_bool_attribs;
420           13                                 32      my @bool_attribs;
421                                                   
422                                                      ATTRIB:
423           13                                 50      foreach my $attrib ( @attribs ) {
424           99    100                         352         next ATTRIB if $attrib eq 'pos_in_log';  # See issue 471. 
425           96    100                         320         if ( exists $basic_attrib{$attrib} ) {
426           60                                215            push @basic_attribs, $attrib;
427                                                         }
428                                                         else {
429           36    100    100                  146            if ( ($ea->type_for($attrib) || '') ne 'bool' ) {
430           30                                115               push @non_bool_attribs, $attrib;
431                                                            }
432                                                            else {
433            6                                 24               push @bool_attribs, $attrib;
434                                                            }
435                                                         }
436                                                      }
437                                                   
438           13                                 54      @non_bool_attribs = sort { uc $a cmp uc $b } @non_bool_attribs;
              41                                116   
439           13                                 45      @bool_attribs     = sort { uc $a cmp uc $b } @bool_attribs;
               3                                 11   
440           93                                297      @basic_attribs    = sort {
441           13                                 28            $basic_attrib{$a} <=> $basic_attrib{$b} } @basic_attribs;
442                                                   
443           13                                139      return @basic_attribs, @non_bool_attribs, @bool_attribs;
444                                                   }
445                                                   
446                                                   sub _d {
447            1                    1            26      my ($package, undef, $line) = caller 0;
448   ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  9   
               2                                 32   
449            1                                 11           map { defined $_ ? $_ : 'undef' }
450                                                           @_;
451            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
452                                                   }
453                                                   
454                                                   1;
455                                                   
456                                                   # ###########################################################################
457                                                   # End QueryReportFormatter package
458                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
83           100      3      1   if ($global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || ''))
115          100      3     19   unless $attrib_type
116   ***     50      0     19   unless exists $$stats{'globals'}{$attrib}
117          100      4     15   if ($formatting_function{$attrib}) { }
125          100     11      4   if ($attrib_type eq 'num') { }
      ***     50      0      4   elsif ($attrib_type eq 'string') { }
      ***     50      4      0   elsif ($attrib_type eq 'bool') { }
126          100      7      4   $attrib =~ /time$/ ? :
134   ***     50     77      0   defined $_ ? :
142          100      3      1   if ($$store{'sum'} > 0 or not $opts{'no_zero_bool'})
151          100     11      4   unless $attrib_type eq 'bool'
175   ***     50      0      8   unless $store
184          100      3      5   if ($global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || ''))
198   ***     50      8      0   $$ea{'groupby'} eq 'fingerprint' ? :
209          100      5      3   if ($opts{'reason'})
210   ***     50      5      0   $opts{'reason'} eq 'top' ? :
226          100      5     62   unless $attrib_type
227          100      5     57   unless exists $$store{$attrib}
229   ***     50      0     57   unless scalar %$vals
230          100      3     54   if ($formatting_function{$attrib}) { }
238          100     27     27   if ($attrib_type eq 'num') { }
      ***     50     27      0   elsif ($attrib_type eq 'string') { }
      ***      0      0      0   elsif ($attrib_type eq 'bool') { }
239          100     12     15   $attrib =~ /time$/ ? :
246   ***     50    189      0   defined $_ ? :
257   ***      0      0      0   if ($$vals{'sum'} > 0 or not $opts{'no_zero_bool'})
267   ***     50     54      0   unless $attrib_type eq 'bool'
284   ***     50      0      2   unless defined $vals and scalar @$vals
300          100      1     15   if $n_vals > $max_val
310   ***     50      0     16   if $n_marks < 1 and $n_vals > 0
311          100      1     15   $n_marks ? :
324          100      4      8   if ($global)
335          100      2     70   if ($val =~ /^InnoDB/)
348   ***     50      0     41   $val eq 'Error_no' ? :
             100      3     41   $val eq 'host' ? :
             100     12     44   $val eq 'Query_time' ? :
             100      4     56   $val eq 'db' ? :
             100      5     60   $val eq 'user' ? :
             100      7     65   $val eq 'ts' ? :
366   ***     50     27      0   if (exists $$stats{'unq'}) { }
369          100     23      4   if (1 == keys %$cnt_for)
372          100      3     20   if length $str > 44
377   ***     50      6      0   unless $$cnt_for{$b} <=> $$cnt_for{$a}
382          100      5      4   if (length $str > 10) { }
388          100      1      8   if length($line) + length($print_str) > 47
393          100      1      3   if ($i < @top)
424          100      3     96   if $attrib eq 'pos_in_log'
425          100     60     36   if (exists $basic_attrib{$attrib}) { }
429          100     30      6   if (($ea->type_for($attrib) || '') ne 'bool') { }
448   ***     50      2      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
284   ***     50      0      2   defined $vals and scalar @$vals

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
83    ***     33      0      0      4   $global_cnt and $$stats{'globals'}{'ts'}
      ***     66      0      1      3   $global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || '')
184   ***     66      0      2      6   $global_cnt and $$store{'ts'}
             100      2      3      3   $global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || '')
310   ***     66      1     15      0   $n_marks < 1 and $n_vals > 0

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
83    ***     50      4      0   $$stats{'globals'}{'ts'}{'max'} || ''
      ***     50      4      0   $$stats{'globals'}{'ts'}{'min'} || ''
184   ***     50      6      0   $$store{'ts'}{'max'} || ''
      ***     50      6      0   $$store{'ts'}{'min'} || ''
198   ***     50      8      0   $opts{'rank'} || 0
             100      3      5   $$sample{'pos_in_log'} || 0
306          100      8      8   $vals_per_mark || 1
429          100     34      2   $ea->type_for($attrib) || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
142   ***     66      3      0      1   $$store{'sum'} > 0 or not $opts{'no_zero_bool'}
257   ***      0      0      0      0   $$vals{'sum'} > 0 or not $opts{'no_zero_bool'}


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
_d                     1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:447
chart_distro           2 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:280
event_report           8 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:169
format_bool_attrib     3 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:353
format_string_list    27 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:365
global_report          4 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:74 
header                 1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:53 
make_header           12 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:321
make_label            72 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:333
new                    1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:48 
sort_attribs          13 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:407


