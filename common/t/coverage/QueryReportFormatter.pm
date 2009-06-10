---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...n/QueryReportFormatter.pm   94.3   76.9   58.1   92.3    n/a  100.0   86.2
Total                          94.3   76.9   58.1   92.3    n/a  100.0   86.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryReportFormatter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:47 2009
Finish:       Wed Jun 10 17:20:47 2009

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
19                                                    # QueryReportFormatter package $Revision: 3408 $
20                                                    # ###########################################################################
21                                                    
22                                                    package QueryReportFormatter;
23                                                    
24             1                    1             5   use strict;
               1                                  2   
               1                                  6   
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
31             1                    1             6   use constant MKDEBUG     => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
32             1                    1             6   use constant LINE_LENGTH => 74;
               1                                  2   
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
84                                                    );
85                                                    
86                                                    sub new {
87             1                    1             5      my ( $class, %args ) = @_;
88             1                                 12      return bless { }, $class;
89                                                    }
90                                                    
91                                                    sub header {
92             1                    1             4      my ($self) = @_;
93                                                    
94             1                                  6      my ( $rss, $vsz, $user, $system ) = ( 0, 0, 0, 0 );
95             1                                  3      eval {
96             1                              12644         my $mem = `ps -o rss,vsz $PID`;
97             1                                 44         ( $rss, $vsz ) = $mem =~ m/(\d+)/g;
98                                                       };
99             1                                 17      ( $user, $system ) = times();
100                                                   
101            1                                 26      sprintf "# %s user time, %s system time, %s rss, %s vsz\n",
102                                                         micro_t( $user,   p_s => 1, p_ms => 1 ),
103                                                         micro_t( $system, p_s => 1, p_ms => 1 ),
104                                                         shorten( $rss * 1_024 ),
105                                                         shorten( $vsz * 1_024 );
106                                                   }
107                                                   
108                                                   # Print a report about the global statistics in the EventAggregator.  %opts is a
109                                                   # hash that has the following keys:
110                                                   #  * select       An arrayref of attributes to print statistics lines for.
111                                                   #  * worst        The --orderby attribute.
112                                                   sub global_report {
113            2                    2            18      my ( $self, $ea, %opts ) = @_;
114            2                                 12      my $stats = $ea->results;
115            2                                  8      my @result;
116                                                   
117                                                      # Get global count
118            2                                 10      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
119                                                   
120                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
121            2                                  8      my ($qps, $conc) = (0, 0);
122   ***      2    100     33                   51      if ( $global_cnt && $stats->{globals}->{ts}
      ***                   50                        
      ***                   50                        
      ***                   66                        
123                                                         && ($stats->{globals}->{ts}->{max} || '')
124                                                            gt ($stats->{globals}->{ts}->{min} || '')
125                                                      ) {
126            1                                  4         eval {
127            1                                  9            my $min  = parse_timestamp($stats->{globals}->{ts}->{min});
128            1                                 10            my $max  = parse_timestamp($stats->{globals}->{ts}->{max});
129            1                                  8            my $diff = unix_timestamp($max) - unix_timestamp($min);
130            1                                  5            $qps     = $global_cnt / $diff;
131            1                                  6            $conc    = $stats->{globals}->{$opts{worst}}->{sum} / $diff;
132                                                         };
133                                                      }
134                                                   
135                                                      # First line
136            2                                 13      my $line = sprintf(
137                                                         '# Overall: %s total, %s unique, %s QPS, %sx concurrency ',
138                                                         shorten($global_cnt),
139            2                                 12         shorten(scalar keys %{$stats->{classes}}),
140                                                         shorten($qps),
141                                                         shorten($conc));
142            2                                 13      $line .= ('_' x (LINE_LENGTH - length($line)));
143            2                                  8      push @result, $line;
144                                                   
145                                                      # Column header line
146            2                                 14      my ($format, @headers) = make_header('global');
147            2                                 16      push @result, sprintf($format, '', @headers);
148                                                   
149                                                      # Each additional line
150            2                                  6      foreach my $attrib ( @{$opts{select}} ) {
               2                                 11   
151           10    100                          52         next unless $ea->type_for($attrib);
152            7    100                          37         if ( $formatting_function{$attrib} ) { # Handle special cases
153           20                                 73            push @result, sprintf $format, make_label($attrib),
154                                                               $formatting_function{$attrib}->($stats->{globals}->{$attrib}),
155            2                                 11               (map { '' } 0..9);# just for good measure
156                                                         }
157                                                         else {
158            5                                 24            my $store = $stats->{globals}->{$attrib};
159            5                                 12            my @values;
160   ***      5     50                          20            if ( $ea->type_for($attrib) eq 'num' ) {
161            5    100                          37               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
162            5                                 13               MKDEBUG && _d('Calculating global statistical_metrics for', $attrib);
163            5                                 32               my $metrics = $ea->calculate_statistical_metrics($store->{all}, $store);
164            5                                 38               @values = (
165            5                                 36                  @{$store}{qw(sum min max)},
166                                                                  $store->{sum} / $store->{cnt},
167            5                                 21                  @{$metrics}{qw(pct_95 stddev median)},
168                                                               );
169   ***      5     50                          20               @values = map { defined $_ ? $func->($_) : '' } @values;
              35                                172   
170                                                            }
171                                                            else {
172   ***      0                                  0               @values = ('', $store->{min}, $store->{max}, '', '', '', '');
173                                                            }
174            5                                 34            push @result, sprintf $format, make_label($attrib), @values;
175                                                         }
176                                                      }
177                                                   
178            2                                  8      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              11                                 61   
              11                                 52   
179                                                   }
180                                                   
181                                                   # Print a report about the statistics in the EventAggregator.  %opts is a
182                                                   # hash that has the following keys:
183                                                   #  * select       An arrayref of attributes to print statistics lines for.
184                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
185                                                   #  * rank         The (optional) rank of the query, for the header
186                                                   #  * worst        The --orderby attribute
187                                                   #  * reason       Why this one is being reported on: top|outlier
188                                                   # TODO: it would be good to start using $ea->metrics() here for simplicity and
189                                                   # uniform code.
190                                                   sub event_report {
191            2                    2            24      my ( $self, $ea, %opts ) = @_;
192            2                                 14      my $stats = $ea->results;
193            2                                  6      my @result;
194                                                   
195                                                      # Does the data exist?  Is there a sample event?
196            2                                 10      my $store = $stats->{classes}->{$opts{where}};
197   ***      2     50                          11      return "# No such event $opts{where}\n" unless $store;
198            2                                 11      my $sample = $stats->{samples}->{$opts{where}};
199                                                   
200                                                      # Pick the first attribute to get counts
201            2                                 12      my $global_cnt = $stats->{globals}->{$opts{worst}}->{cnt};
202            2                                 11      my $class_cnt  = $store->{$opts{worst}}->{cnt};
203                                                   
204                                                      # Calculate QPS (queries per second) by looking at the min/max timestamp.
205            2                                 10      my ($qps, $conc) = (0, 0);
206   ***      2    100     33                   49      if ( $global_cnt && $store->{ts}
      ***                   50                        
      ***                   50                        
      ***                   66                        
207                                                         && ($store->{ts}->{max} || '')
208                                                            gt ($store->{ts}->{min} || '')
209                                                      ) {
210            1                                  3         eval {
211            1                                  6            my $min  = parse_timestamp($store->{ts}->{min});
212            1                                  6            my $max  = parse_timestamp($store->{ts}->{max});
213            1                                  6            my $diff = unix_timestamp($max) - unix_timestamp($min);
214            1                                  6            $qps     = $class_cnt / $diff;
215            1                                  6            $conc    = $store->{$opts{worst}}->{sum} / $diff;
216                                                         };
217                                                      }
218                                                   
219                                                      # First line
220   ***      2     50     50                   26      my $line = sprintf(
                           100                        
221                                                         '# %s %d: %s QPS, %sx concurrency, ID 0x%s at byte %d ',
222                                                         ($ea->{groupby} eq 'fingerprint' ? 'Query' : 'Item'),
223                                                         $opts{rank} || 0,
224                                                         shorten($qps),
225                                                         shorten($conc),
226                                                         make_checksum($opts{where}),
227                                                         $sample->{pos_in_log} || 0);
228            2                                 11      $line .= ('_' x (LINE_LENGTH - length($line)));
229            2                                  6      push @result, $line;
230                                                   
231   ***      2     50                          10      if ( $opts{reason} ) {
232   ***      2     50                          11         push @result, "# This item is included in the report because it matches "
233                                                            . ($opts{reason} eq 'top' ? '--limit.' : '--outliers.');
234                                                      }
235                                                   
236                                                      # Column header line
237            2                                 10      my ($format, @headers) = make_header();
238            2                                 15      push @result, sprintf($format, '', @headers);
239                                                   
240                                                      # Count line
241           18                                 56      push @result, sprintf
242                                                         $format, 'Count', percentage_of($class_cnt, $global_cnt), $class_cnt,
243            2                                 10            map { '' } (1 ..9);
244                                                   
245                                                      # Each additional line
246            2                                  7      foreach my $attrib ( @{$opts{select}} ) {
               2                                 12   
247           16    100                          67         next unless $ea->type_for($attrib);
248           11                                 40         my $vals = $store->{$attrib};
249           11    100                          41         if ( $formatting_function{$attrib} ) { # Handle special cases
250           60                                194            push @result, sprintf $format, make_label($attrib),
251                                                               $formatting_function{$attrib}->($vals),
252            6                                 25               (map { '' } 0..9);# just for good measure
253                                                         }
254                                                         else {
255            5                                 11            my @values;
256            5                                 11            my $pct;
257   ***      5     50                          21            if ( $ea->type_for($attrib) eq 'num' ) {
258            5    100                          29               my $func = $attrib =~ m/time$/ ? \&micro_t : \&shorten;
259            5                                 27               my $metrics = $ea->calculate_statistical_metrics($vals->{all}, $vals);
260            5                                 30               @values = (
261            5                                 28                  @{$vals}{qw(sum min max)},
262                                                                  $vals->{sum} / $vals->{cnt},
263            5                                 20                  @{$metrics}{qw(pct_95 stddev median)},
264                                                               );
265   ***      5     50                          18               @values = map { defined $_ ? $func->($_) : '' } @values;
              35                                154   
266            5                                 39               $pct = percentage_of($vals->{sum},
267                                                                  $stats->{globals}->{$attrib}->{sum});
268                                                            }
269                                                            else {
270   ***      0                                  0               @values = ('', $vals->{min}, $vals->{max}, '', '', '', '');
271   ***      0                                  0               $pct = 0;
272                                                            }
273            5                                 22            push @result, sprintf $format, make_label($attrib), $pct, @values;
274                                                         }
275                                                      }
276                                                   
277            2                                 12      return join("\n", map { s/\s+$//; $_ } @result) . "\n";
              19                                 93   
              19                                 74   
278                                                   }
279                                                   
280                                                   # Creates a chart of value distributions in buckets.  Right now it bucketizes
281                                                   # into 8 buckets, powers of ten starting with .000001. %opts has:
282                                                   #  * where        The value of the group-by attribute, such as the fingerprint.
283                                                   #  * attribute    An attribute to chart.
284                                                   sub chart_distro {
285            2                    2            15      my ( $self, $ea, %opts ) = @_;
286            2                                 12      my $stats = $ea->results;
287            2                                 15      my $store = $stats->{classes}->{$opts{where}}->{$opts{attribute}};
288            2                                  8      my $vals  = $store->{all};
289   ***      2     50     50                   25      return "" unless defined $vals && scalar @$vals;
290                                                      # TODO: this is broken.
291            2                                 12      my @buck_tens = $ea->buckets_of(10);
292            2                                 95      my @distro = map { 0 } (0 .. 7);
              16                                 48   
293            2                                 88      map { $distro[$buck_tens[$_]] += $vals->[$_] } (1 .. @$vals - 1);
            1998                               7432   
294                                                   
295            2                                 90      my $max_val = 0;
296            2                                  5      my $vals_per_mark; # number of vals represented by 1 #-mark
297            2                                  7      my $max_disp_width = 64;
298            2                                  7      my $bar_fmt = "# %5s%s";
299            2                                 14      my @distro_labels = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
300            2                                 14      my @results = "# $opts{attribute} distribution";
301                                                   
302                                                      # Find the distro with the most values. This will set
303                                                      # vals_per_mark and become the bar at max_disp_width.
304            2                                 13      foreach my $n_vals ( @distro ) {
305           16    100                          67         $max_val = $n_vals if $n_vals > $max_val;
306                                                      }
307            2                                  9      $vals_per_mark = $max_val / $max_disp_width;
308                                                   
309            2                                 17      foreach my $i ( 0 .. $#distro ) {
310           16                                 44         my $n_vals = $distro[$i];
311           16           100                   98         my $n_marks = $n_vals / ($vals_per_mark || 1);
312                                                         # Always print at least 1 mark for any bucket that has at least
313                                                         # 1 value. This skews the graph a tiny bit, but it allows us to
314                                                         # see all buckets that have values.
315   ***     16     50     66                  118         $n_marks = 1 if $n_marks < 1 && $n_vals > 0;
316           16    100                          69         my $bar = ($n_marks ? '  ' : '') . '#' x $n_marks;
317           16                                 81         push @results, sprintf $bar_fmt, $distro_labels[$i], $bar;
318                                                      }
319                                                   
320            2                                 61      return join("\n", @results) . "\n";
321                                                   }
322                                                   
323                                                   # Makes a header format and returns the format and the column header names.  The
324                                                   # argument is either 'global' or anything else.
325                                                   sub make_header {
326            4                    4            23      my ( $global ) = @_;
327            4                                 13      my $format = "# %-9s %6s %7s %7s %7s %7s %7s %7s %7s";
328            4                                 23      my @headers = qw(pct total min max avg 95% stddev median);
329            4    100                          16      if ( $global ) {
330            2                                 22         $format =~ s/%(\d+)s/' ' x $1/e;
               2                                 20   
331            2                                  7         shift @headers;
332                                                      }
333            4                                 36      return $format, @headers;
334                                                   }
335                                                   
336                                                   # Convert attribute names into labels
337                                                   sub make_label {
338           18                   18            62      my ( $val ) = @_;
339                                                      return $val eq 'ts'          ? 'Time range'
340                                                            : $val eq 'user'       ? 'Users'
341                                                            : $val eq 'db'         ? 'Databases'
342                                                            : $val eq 'Query_time' ? 'Exec time'
343           18    100                         156            : do { $val =~ s/_/ /g; $val = substr($val, 0, 9); $val };
               6    100                          36   
               6    100                          31   
               6    100                          50   
344                                                   }
345                                                   
346                                                   sub _d {
347   ***      0                    0                    my ($package, undef, $line) = caller 0;
348   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
349   ***      0                                              map { defined $_ ? $_ : 'undef' }
350                                                           @_;
351   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
352                                                   }
353                                                   
354                                                   1;
355                                                   
356                                                   # ###########################################################################
357                                                   # End QueryReportFormatter package
358                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
122          100      1      1   if ($global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || ''))
151          100      3      7   unless $ea->type_for($attrib)
152          100      2      5   if ($formatting_function{$attrib}) { }
160   ***     50      5      0   if ($ea->type_for($attrib) eq 'num') { }
161          100      3      2   $attrib =~ /time$/ ? :
169   ***     50     35      0   defined $_ ? :
197   ***     50      0      2   unless $store
206          100      1      1   if ($global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || ''))
220   ***     50      2      0   $$ea{'groupby'} eq 'fingerprint' ? :
231   ***     50      2      0   if ($opts{'reason'})
232   ***     50      2      0   $opts{'reason'} eq 'top' ? :
247          100      5     11   unless $ea->type_for($attrib)
249          100      6      5   if ($formatting_function{$attrib}) { }
257   ***     50      5      0   if ($ea->type_for($attrib) eq 'num') { }
258          100      3      2   $attrib =~ /time$/ ? :
265   ***     50     35      0   defined $_ ? :
289   ***     50      0      2   unless defined $vals and scalar @$vals
305          100      1     15   if $n_vals > $max_val
315   ***     50      0     16   if $n_marks < 1 and $n_vals > 0
316          100      1     15   $n_marks ? :
329          100      2      2   if ($global)
343          100      4      6   $val eq 'Query_time' ? :
             100      2     10   $val eq 'db' ? :
             100      2     12   $val eq 'user' ? :
             100      4     14   $val eq 'ts' ? :
348   ***      0      0      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
289   ***     50      0      2   defined $vals and scalar @$vals

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
122   ***     33      0      0      2   $global_cnt and $$stats{'globals'}{'ts'}
      ***     66      0      1      1   $global_cnt and $$stats{'globals'}{'ts'} and ($$stats{'globals'}{'ts'}{'max'} || '') gt ($$stats{'globals'}{'ts'}{'min'} || '')
206   ***     33      0      0      2   $global_cnt and $$store{'ts'}
      ***     66      0      1      1   $global_cnt and $$store{'ts'} and ($$store{'ts'}{'max'} || '') gt ($$store{'ts'}{'min'} || '')
315   ***     66      1     15      0   $n_marks < 1 and $n_vals > 0

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
122   ***     50      2      0   $$stats{'globals'}{'ts'}{'max'} || ''
      ***     50      2      0   $$stats{'globals'}{'ts'}{'min'} || ''
206   ***     50      2      0   $$store{'ts'}{'max'} || ''
      ***     50      2      0   $$store{'ts'}{'min'} || ''
220   ***     50      2      0   $opts{'rank'} || 0
             100      1      1   $$sample{'pos_in_log'} || 0
311          100      8      8   $vals_per_mark || 1


Covered Subroutines
-------------------

Subroutine    Count Location                                                   
------------- ----- -----------------------------------------------------------
BEGIN             1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:24 
BEGIN             1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:25 
BEGIN             1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:26 
BEGIN             1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:31 
BEGIN             1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:32 
chart_distro      2 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:285
event_report      2 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:191
global_report     2 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:113
header            1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:92 
make_header       4 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:326
make_label       18 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:338
new               1 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:87 

Uncovered Subroutines
---------------------

Subroutine    Count Location                                                   
------------- ----- -----------------------------------------------------------
_d                0 /home/daniel/dev/maatkit/common/QueryReportFormatter.pm:347


