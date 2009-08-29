---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryRanker.pm   90.5   75.0   63.2  100.0    n/a  100.0   85.5
Total                          90.5   75.0   63.2  100.0    n/a  100.0   85.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryRanker.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:34 2009
Finish:       Sat Aug 29 15:03:34 2009

/home/daniel/dev/maatkit/common/QueryRanker.pm

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
18                                                    # QueryRanker package $Revision: 4535 $
19                                                    # ###########################################################################
20                                                    package QueryRanker;
21                                                    
22                                                    # Read http://code.google.com/p/maatkit/wiki/QueryRankerInternals for
23                                                    # details about this module.  In brief, it ranks QueryExecutor results.
24                                                    
25             1                    1             9   use strict;
               1                                  2   
               1                                  7   
26             1                    1             6   use warnings FATAL => 'all';
               1                                103   
               1                                 10   
27                                                    
28             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
29             1                    1            11   use POSIX qw(floor);
               1                                  3   
               1                                  8   
30                                                    
31             1                    1            11   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 14   
32                                                    
33                                                    # Significant percentage increase for each bucket.  For example,
34                                                    # 1us to 4us is a 300% increase, but in reality that is not significant.
35                                                    # But a 500% increase to 6us may be significant.  In the 1s+ range (last
36                                                    # bucket), since the time is already so bad, even a 20% increase (e.g. 1s
37                                                    # to 1.2s) is significant.
38                                                    # If you change these values, you'll need to update the threshold tests
39                                                    # in QueryRanker.t.
40                                                    my @bucket_threshold = qw(500 100  100   500 50   50    20 1   );
41                                                    my @bucket_labels    = qw(1us 10us 100us 1ms 10ms 100ms 1s 10s+);
42                                                    
43                                                    # Built-in ranker subs for various results from QueryExecutor.
44                                                    my %ranker_for = (
45                                                       Query_time       => \&rank_query_times,
46                                                       warnings         => \&rank_warnings,
47                                                       checksum_results => \&rank_result_sets,
48                                                    );
49                                                    
50                                                    # Optional arguments:
51                                                    #   * ranker_for   Hashref of result=>callback subs for ranking results.
52                                                    #                  These are preferred to the built-in ranker subs in this
53                                                    #                  package in case you need to override a built-in.
54                                                    #
55                                                    sub new {
56             2                    2            23      my ( $class, %args ) = @_;
57             2                                 13      foreach my $arg ( qw() ) {
58    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
59                                                       }
60             2                                 10      my $self = {
61                                                          %args,
62                                                       };
63             2                                 25      return bless $self, $class;
64                                                    }
65                                                    
66                                                    # Ranks operation result differences.  @results is an array of operation
67                                                    # results for mulitple hosts returned from QueryExecutor::exec().  We only
68                                                    # compare the first host's results to all other hosts.  Usually, the first
69                                                    # host is a production server and subsequent hosts are test servers.  The
70                                                    # code, however, doesn't really care about the nature of the hosts--it's
71                                                    # host agnostic.
72                                                    #
73                                                    # Returns a total rank value and a list of reasons for that total rank.
74                                                    #
75                                                    # Ranker subs are either built-in (i.e. provided in this package) or given
76                                                    # with the optional ranker_for arg to new().  Given rankers are preferred.
77                                                    # A ranker sub is expected to return a list: a rank value and any reasons
78                                                    # for that rank value.
79                                                    sub rank_results {
80            16                   16           141      my ( $self, $results, %args ) = @_;
81    ***     16     50                          76      return unless @$results > 1;
82                                                    
83            16                                 40      my $rank      = 0;
84            16                                 46      my @reasons   = ();
85            16                                 51      my $host1     = $results->[0];
86                                                    
87                                                       RESULTS:
88            16                                 83      foreach my $op ( keys %$host1 ) {  # Each key the name of some operation
89    ***     24            66                  214         my $compare = $self->{ranker_for}->{$op} || $ranker_for{$op};
90    ***     24     50                          89         if ( !$compare ) {
91    ***      0                                  0            MKDEBUG && _d('No ranker for', $op);
92    ***      0                                  0            next RESULTS;
93                                                          }
94            24                                 49         MKDEBUG && _d('Ranking', $op, 'results');
95                                                    
96            24                                 72         my $host1_results = $host1->{$op};
97                                                    
98                                                          HOST:
99            24                                112         for my $i ( 1..(@$results-1) ) {
100           24                                 72            my $hostN = $results->[$i];
101   ***     24     50                         118            if ( !exists $hostN->{$op} ) {
102   ***      0                                  0               warn "Host", $i+1, " doesn't have $op results";
103   ***      0                                  0               next HOST;
104                                                            }
105                                                   
106           24                                125            my @res = $compare->($host1_results, $hostN->{$op}, %args);
107           24                                 90            $rank += shift @res;
108           24                                124            push @reasons, @res;
109                                                         } 
110                                                      }
111                                                   
112           16                                140      return $rank, @reasons;
113                                                   }
114                                                   
115                                                   sub rank_query_times {
116            9                    9            37      my ( $host1, $host2 ) = @_;
117            9                                 25      my $rank    = 0;   # total rank
118            9                                 27      my @reasons = ();  # all reasons
119            9                                 22      my @res     = ();  # ($rank, @reasons) for each comparison
120                                                   
121                                                      # QueryExecutor always does the Query_time operation.  If it worked,
122                                                      # then Query_time will be >= 0, else it will be = -1 and error will
123                                                      # be set.
124            9    100                          45      if ( $host1->{Query_time} == -1 ) {
125            1                                  3         $rank += 100;
126   ***      1            50                    8         push @reasons, 'Query failed to execute on host1: '
127                                                               . ($host1->{error} || 'unknown error')
128                                                               . " (rank+100)";
129                                                      }
130            9    100                          41      if ( $host2->{Query_time} == -1 ) {
131            1                                  3         $rank += 100;
132   ***      1            50                    7         push @reasons, 'Query failed to execute on host2: '
133                                                               . ($host2->{error} || 'unknown error')
134                                                               . " (rank+100)";
135                                                      }
136                                                   
137   ***      9    100     66                   79      if ( $host1->{Query_time} >= 0 && $host2->{Query_time} >= 0 ) {
138            8                                 39         @res = compare_query_times(
139                                                            $host1->{Query_time}, $host2->{Query_time});
140            8                                 24         $rank += shift @res;
141            8                                 26         push @reasons, @res;
142                                                      }
143                                                   
144            9                                 38      return $rank, @reasons;
145                                                   }
146                                                   
147                                                   sub rank_warnings {
148            8                    8            33      my ( $host1, $host2 ) = @_;
149            8                                 24      my $rank    = 0;   # total rank
150            8                                 23      my @reasons = ();  # all reasons
151            8                                 18      my @res     = ();  # ($rank, @reasons) for each comparison
152                                                   
153                                                      # Always rank queries with warnings above queries without warnings
154                                                      # or queries with identical warnings and no significant time difference.
155                                                      # So any query with a warning will have a minimum rank of 1.
156            8    100    100                   66      if ( $host1->{count} > 0 || $host2->{count} > 0 ) {
157            6                                 17         $rank += 1;
158            6                                 23         push @reasons, "Query has warnings (rank+1)";
159                                                      }
160                                                   
161            8    100                          46      if ( my $diff = abs($host1->{count} - $host2->{count}) ) {
162            3                                  8         $rank += $diff;
163            3                                 17         push @reasons, "Warning counts differ by $diff (rank+$diff)";
164                                                      }
165                                                   
166            8                                 38      @res = compare_warnings($host1->{codes}, $host2->{codes});
167            8                                 25      $rank += shift @res;
168            8                                 34      push @reasons, @res;
169                                                   
170            8                                 41      return $rank, @reasons;
171                                                   }
172                                                   
173                                                   # Compares query times and returns a rank increase value if the
174                                                   # times differ significantly or 0 if they don't.
175                                                   sub compare_query_times {
176           23                   23           309      my ( $t1, $t2 ) = @_;
177   ***     23     50                          92      die "I need a t1 argument" unless defined $t1;
178   ***     23     50                          80      die "I need a t2 argument" unless defined $t2;
179                                                   
180           23                                 50      MKDEBUG && _d('host1 query time:', $t1, 'host2 query time:', $t2);
181                                                   
182           23                                 83      my $t1_bucket = bucket_for($t1);
183           23                                 78      my $t2_bucket = bucket_for($t2);
184                                                   
185                                                      # Times are in different buckets so they differ significantly.
186           23    100                          95      if ( $t1_bucket != $t2_bucket ) {
187            5                                 18         my $rank_inc = 2 * abs($t1_bucket - $t2_bucket);
188            5                                 53         return $rank_inc, "Query times differ significantly: "
189                                                            . "host1 in ".$bucket_labels[$t1_bucket]." range, "
190                                                            . "host2 in ".$bucket_labels[$t2_bucket]." range (rank+2)";
191                                                      }
192                                                   
193                                                      # Times are in same bucket; check if they differ by that bucket's threshold.
194           18                                 62      my $inc = percentage_increase($t1, $t2);
195           18    100                        2149      if ( $inc >= $bucket_threshold[$t1_bucket] ) {
196            9                                110         return 1, "Query time increase $inc\% exceeds "
197                                                            . $bucket_threshold[$t1_bucket] . "\% increase threshold for "
198                                                            . $bucket_labels[$t1_bucket] . " range (rank+1)";
199                                                      }
200                                                   
201            9                                 32      return (0);  # No significant difference.
202                                                   }
203                                                   
204                                                   # Compares warnings and returns a rank increase value for two times the
205                                                   # number of warnings with the same code but different level and 3 times
206                                                   # the number of new warnings.
207                                                   sub compare_warnings {
208            8                    8            30      my ( $warnings1, $warnings2 ) = @_;
209   ***      8     50                          29      die "I need a warnings1 argument" unless defined $warnings1;
210   ***      8     50                          29      die "I need a warnings2 argument" unless defined $warnings2;
211                                                   
212            8                                 18      my %new_warnings;
213            8                                 19      my $rank_inc = 0;
214            8                                 22      my @reasons;
215                                                   
216            8                                 34      foreach my $code ( keys %$warnings1 ) {
217            6    100                          23         if ( exists $warnings2->{$code} ) {
218            3    100                          22            if ( $warnings2->{$code}->{Level} ne $warnings1->{$code}->{Level} ) {
219            1                                  3               $rank_inc += 2;
220            1                                 11               push @reasons, "Error $code changes level: "
221                                                                  . $warnings1->{$code}->{Level} . " on host1, "
222                                                                  . $warnings2->{$code}->{Level} . " on host2 (rank+2)";
223                                                            }
224                                                         }
225                                                         else {
226            3                                  7            MKDEBUG && _d('New warning on host1:', $code);
227            3                                 13            push @reasons, "Error $code on host1 is new (rank+3)";
228            3                                 16            %{ $new_warnings{$code} } = %{ $warnings1->{$code} };
               3                                 24   
               3                                 13   
229                                                         }
230                                                      }
231                                                   
232            8                                 36      foreach my $code ( keys %$warnings2 ) {
233   ***      5    100     66                   38         if ( !exists $warnings1->{$code} && !exists $new_warnings{$code} ) {
234            2                                  4            MKDEBUG && _d('New warning on host2:', $code);
235            2                                  9            push @reasons, "Error $code on host2 is new (rank+3)";
236            2                                  6            %{ $new_warnings{$code} } = %{ $warnings2->{$code} };
               2                                 13   
               2                                  9   
237                                                         }
238                                                      }
239                                                   
240            8                                 32      $rank_inc += 3 * scalar keys %new_warnings;
241                                                   
242                                                      # TODO: if we ever want to see the new warnings, we'll just have to
243                                                      #       modify this sub a litte.  %new_warnings is a placeholder for now.
244                                                   
245            8                                 44      return $rank_inc, @reasons;
246                                                   }
247                                                   
248                                                   sub rank_result_sets {
249            6                    6            26      my ( $host1, $host2 ) = @_;
250            6                                 25      my $rank    = 0;   # total rank
251            6                                 18      my @reasons = ();  # all reasons
252            6                                 17      my @res     = ();  # ($rank, @reasons) for each comparison
253                                                   
254            6    100                          32      if ( $host1->{checksum} ne $host2->{checksum} ) {
255            2                                  6         $rank += 50;
256            2                                  8         push @reasons, "Table checksums do not match (rank+50)";
257                                                      }
258                                                   
259            6    100                          31      if ( $host1->{n_rows} != $host2->{n_rows} ) {
260            1                                  3         $rank += 50;
261            1                                  5         push @reasons, "Number of rows do not match (rank+50)";
262                                                      }
263                                                   
264   ***      6     50     33                   54      if ( $host1->{table_struct} && $host2->{table_struct} ) {
265            6                                 33         @res = compare_table_structs(
266                                                            $host1->{table_struct},
267                                                            $host2->{table_struct}
268                                                         );
269            6                                 20         $rank += shift @res;
270            6                                 18         push @reasons, @res;
271                                                      }
272                                                      else {
273   ***      0                                  0         $rank += 10;
274   ***      0                                  0         push @reasons, 'The temporary tables could not be parsed (rank+10)';
275                                                      }
276                                                   
277            6                                 25      return $rank, @reasons;
278                                                   }
279                                                   
280                                                   sub compare_table_structs {
281            6                    6            24      my ( $s1, $s2 ) = @_;
282   ***      6     50                          25      die "I need a s1 argument" unless defined $s1;
283   ***      6     50                          24      die "I need a s2 argument" unless defined $s2;
284                                                   
285            6                                 22      my $rank_inc = 0;
286            6                                 17      my @reasons  = ();
287                                                   
288                                                      # Compare number of columns.
289   ***      6     50                          15      if ( scalar @{$s1->{cols}} != scalar @{$s2->{cols}} ) {
               6                                 22   
               6                                 28   
290   ***      0                                  0         my $inc = 2 * abs( scalar @{$s1->{cols}} - scalar @{$s2->{cols}} );
      ***      0                                  0   
      ***      0                                  0   
291   ***      0                                  0         $rank_inc += $inc;
292   ***      0                                  0         push @reasons, 'Tables have different columns counts: '
293   ***      0                                  0            . scalar @{$s1->{cols}} . ' columns on host1, '
294   ***      0                                  0            . scalar @{$s2->{cols}} . " columns on host2 (rank+$inc)";
295                                                      }
296                                                   
297                                                      # Compare column types.
298            6                                 18      my %host1_missing_cols = %{$s2->{type_for}};  # Make a copy to modify.
               6                                 38   
299            6                                 24      my @host2_missing_cols;
300            6                                 64      foreach my $col ( keys %{$s1->{type_for}} ) {
               6                                 34   
301           11    100                          48         if ( exists $s2->{type_for}->{$col} ) {
302           10    100                          56            if ( $s1->{type_for}->{$col} ne $s2->{type_for}->{$col} ) {
303            1                                  3               $rank_inc += 3;
304            1                                 12               push @reasons, "Types for $col column differ: "
305                                                                  . "'$s1->{type_for}->{$col}' on host1, "
306                                                                  . "'$s2->{type_for}->{$col}' on host2 (rank+3)";
307                                                            }
308           10                                 41            delete $host1_missing_cols{$col};
309                                                         }
310                                                         else {
311            1                                  4            push @host2_missing_cols, $col;
312                                                         }
313                                                      }
314                                                   
315            6                                 24      foreach my $col ( @host2_missing_cols ) {
316            1                                  4         $rank_inc += 5;
317            1                                  6         push @reasons, "Column $col exists on host1 but not on host2 (rank+5)";
318                                                      }
319            6                                 22      foreach my $col ( keys %host1_missing_cols ) {
320            1                                  4         $rank_inc += 5;
321            1                                  5         push @reasons, "Column $col exists on host2 but not on host1 (rank+5)";
322                                                      }
323                                                   
324            6                                 32      return $rank_inc, @reasons;
325                                                   }
326                                                   
327                                                   sub bucket_for {
328           46                   46           139      my ( $val ) = @_;
329   ***     46     50                         166      die "I need a val" unless defined $val;
330           46    100                         173      return 0 if $val == 0;
331                                                      # The buckets are powers of ten.  Bucket 0 represents (0 <= val < 10us) 
332                                                      # and 7 represents 10s and greater.  The powers are thus constrained to
333                                                      # between -6 and 1.  Because these are used as array indexes, we shift
334                                                      # up so it's non-negative, to get 0 - 7.
335           43                                266      my $bucket = floor(log($val) / log(10)) + 6;
336   ***     43     50                         187      $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
                    100                               
337           43                                129      return $bucket;
338                                                   }
339                                                   
340                                                   # Returns the percentage increase between two values.
341                                                   sub percentage_increase {
342           18                   18            63      my ( $x, $y ) = @_;
343           18    100                          76      return 0 if $x == $y;
344                                                   
345                                                      # Swap values if x > y to keep things simple.
346   ***     11     50                          40      if ( $x > $y ) {
347   ***      0                                  0         my $z = $y;
348   ***      0                                  0            $y = $x;
349   ***      0                                  0            $x = $z;
350                                                      }
351                                                   
352           11    100                          40      if ( $x == 0 ) {
353                                                         # TODO: increase from 0 to some value.  Is this defined mathematically?
354            1                                  3         return 1000;  # This should trigger all buckets' thresholds.
355                                                      }
356                                                   
357           10                                138      return sprintf '%.2f', (($y - $x) / $x) * 100;
358                                                   }
359                                                   
360                                                   sub _d {
361            1                    1            25      my ($package, undef, $line) = caller 0;
362   ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 10   
363            1                                  6           map { defined $_ ? $_ : 'undef' }
364                                                           @_;
365            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
366                                                   }
367                                                   
368                                                   1;
369                                                   
370                                                   # ###########################################################################
371                                                   # End QueryRanker package
372                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
58    ***      0      0      0   unless $args{$arg}
81    ***     50      0     16   unless @$results > 1
90    ***     50      0     24   if (not $compare)
101   ***     50      0     24   if (not exists $$hostN{$op})
124          100      1      8   if ($$host1{'Query_time'} == -1)
130          100      1      8   if ($$host2{'Query_time'} == -1)
137          100      8      1   if ($$host1{'Query_time'} >= 0 and $$host2{'Query_time'} >= 0)
156          100      6      2   if ($$host1{'count'} > 0 or $$host2{'count'} > 0)
161          100      3      5   if (my $diff = abs $$host1{'count'} - $$host2{'count'})
177   ***     50      0     23   unless defined $t1
178   ***     50      0     23   unless defined $t2
186          100      5     18   if ($t1_bucket != $t2_bucket)
195          100      9      9   if ($inc >= $bucket_threshold[$t1_bucket])
209   ***     50      0      8   unless defined $warnings1
210   ***     50      0      8   unless defined $warnings2
217          100      3      3   if (exists $$warnings2{$code}) { }
218          100      1      2   if ($$warnings2{$code}{'Level'} ne $$warnings1{$code}{'Level'})
233          100      2      3   if (not exists $$warnings1{$code} and not exists $new_warnings{$code})
254          100      2      4   if ($$host1{'checksum'} ne $$host2{'checksum'})
259          100      1      5   if ($$host1{'n_rows'} != $$host2{'n_rows'})
264   ***     50      6      0   if ($$host1{'table_struct'} and $$host2{'table_struct'}) { }
282   ***     50      0      6   unless defined $s1
283   ***     50      0      6   unless defined $s2
289   ***     50      0      6   if (scalar @{$$s1{'cols'};} != scalar @{$$s2{'cols'};})
301          100     10      1   if (exists $$s2{'type_for'}{$col}) { }
302          100      1      9   if ($$s1{'type_for'}{$col} ne $$s2{'type_for'}{$col})
329   ***     50      0     46   unless defined $val
330          100      3     43   if $val == 0
336   ***     50      0     42   $bucket < 0 ? :
             100      1     42   $bucket > 7 ? :
343          100      7     11   if $x == $y
346   ***     50      0     11   if ($x > $y)
352          100      1     10   if ($x == 0)
362   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
137   ***     66      1      0      8   $$host1{'Query_time'} >= 0 and $$host2{'Query_time'} >= 0
233   ***     66      3      0      2   not exists $$warnings1{$code} and not exists $new_warnings{$code}
264   ***     33      0      0      6   $$host1{'table_struct'} and $$host2{'table_struct'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
126   ***     50      1      0   $$host1{'error'} || 'unknown error'
132   ***     50      1      0   $$host2{'error'} || 'unknown error'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
89    ***     66      1     23      0   $$self{'ranker_for'}{$op} || $ranker_for{$op}
156          100      5      1      2   $$host1{'count'} > 0 or $$host2{'count'} > 0


Covered Subroutines
-------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:25 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:26 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:28 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:29 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:31 
_d                        1 /home/daniel/dev/maatkit/common/QueryRanker.pm:361
bucket_for               46 /home/daniel/dev/maatkit/common/QueryRanker.pm:328
compare_query_times      23 /home/daniel/dev/maatkit/common/QueryRanker.pm:176
compare_table_structs     6 /home/daniel/dev/maatkit/common/QueryRanker.pm:281
compare_warnings          8 /home/daniel/dev/maatkit/common/QueryRanker.pm:208
new                       2 /home/daniel/dev/maatkit/common/QueryRanker.pm:56 
percentage_increase      18 /home/daniel/dev/maatkit/common/QueryRanker.pm:342
rank_query_times          9 /home/daniel/dev/maatkit/common/QueryRanker.pm:116
rank_result_sets          6 /home/daniel/dev/maatkit/common/QueryRanker.pm:249
rank_results             16 /home/daniel/dev/maatkit/common/QueryRanker.pm:80 
rank_warnings             8 /home/daniel/dev/maatkit/common/QueryRanker.pm:148


