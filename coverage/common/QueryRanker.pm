---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryRanker.pm   91.2   73.3   83.3  100.0    n/a  100.0   87.3
Total                          91.2   73.3   83.3  100.0    n/a  100.0   87.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryRanker.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:11 2009
Finish:       Fri Jul 31 18:53:11 2009

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
18                                                    # QueryRanker package $Revision: 4220 $
19                                                    # ###########################################################################
20                                                    package QueryRanker;
21                                                    
22                                                    # Read http://code.google.com/p/maatkit/wiki/QueryRankerInternals for
23                                                    # details about this module.  In brief, it ranks QueryExecutor results.
24                                                    
25             1                    1             9   use strict;
               1                                  3   
               1                                  7   
26             1                    1           104   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
27                                                    
28             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
29             1                    1            11   use POSIX qw(floor);
               1                                  4   
               1                                  7   
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
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
43                                                    my %ranker_for = (
44                                                       Query_time => \&rank_query_times,
45                                                       warnings   => \&rank_warnings,
46                                                       results    => \&rank_result_sets,
47                                                    );
48                                                    
49                                                    sub new {
50             1                    1            13      my ( $class, %args ) = @_;
51             1                                  4      foreach my $arg ( qw() ) {
52    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
53                                                       }
54             1                                  4      my $self = {
55                                                       };
56             1                                 14      return bless $self, $class;
57                                                    }
58                                                    
59                                                    sub rank_results {
60            14                   14            77      my ( $self, @results ) = @_;
61    ***     14     50                          60      return unless @results > 1;
62                                                    
63            14                                 34      my $rank           = 0;
64            14                                 40      my @reasons        = ();
65            14                                 38      my $master_results = shift @results;
66                                                    
67                                                       RESULTS:
68            14                                 67      foreach my $results ( keys %$master_results ) {
69            22                                 65         my $compare = $ranker_for{$results};
70    ***     22     50                          83         if ( !$compare ) {
71    ***      0                                  0            warn "I don't know how to rank $results results";
72    ***      0                                  0            next RESULTS;
73                                                          }
74                                                    
75            22                                 64         my $master = $master_results->{$results};
76                                                    
77            22                                 55         HOST:
78                                                          my $i = 1;  # host1 is master...
79            22                                 65         foreach my $host_results ( @results ) {
80            22                                 55            $i++; # ...so we start with host2.
81    ***     22     50                          86            if ( !exists $host_results->{$results} ) {
82    ***      0                                  0               warn "Host$i doesn't have $results results";
83    ***      0                                  0               next HOST;
84                                                             }
85                                                    
86            22                                 64            my $host = $host_results->{$results};
87                                                    
88            22                                 77            my @res = $compare->($self, $master, $host);
89            22                                 61            $rank += shift @res;
90            22                                109            push @reasons, @res;
91                                                          } 
92                                                       }
93                                                    
94            14                                111      return $rank, @reasons;
95                                                    }
96                                                    
97                                                    sub rank_query_times {
98             8                    8            37      my ( $self, $host1, $host2 ) = @_;
99             8                                 21      my $rank    = 0;   # total rank
100            8                                 23      my @reasons = ();  # all reasons
101            8                                 26      my @res     = ();  # ($rank, @reasons) for each comparison
102                                                   
103            8                                 29      @res = $self->compare_query_times($host1, $host2);
104            8                                 25      $rank += shift @res;
105            8                                 19      push @reasons, @res;
106                                                   
107            8                                 31      return $rank, @reasons;
108                                                   }
109                                                   
110                                                   sub rank_warnings {
111            8                    8            30      my ( $self, $host1, $host2 ) = @_;
112            8                                 20      my $rank    = 0;   # total rank
113            8                                 22      my @reasons = ();  # all reasons
114            8                                 21      my @res     = ();  # ($rank, @reasons) for each comparison
115                                                   
116                                                      # Always rank queries with warnings above queries without warnings
117                                                      # or queries with identical warnings and no significant time difference.
118                                                      # So any query with a warning will have a minimum rank of 1.
119            8    100    100                   59      if ( $host1->{count} > 0 || $host2->{count} > 0 ) {
120            6                                 18         $rank += 1;
121            6                                 20         push @reasons, "Query has warnings (rank+1)";
122                                                      }
123                                                   
124            8    100                          45      if ( my $diff = abs($host1->{count} - $host2->{count}) ) {
125            3                                  9         $rank += $diff;
126            3                                 14         push @reasons, "Warning counts differ by $diff (rank+$diff)";
127                                                      }
128                                                   
129            8                                 41      @res = $self->compare_warnings($host1->{codes}, $host2->{codes});
130            8                                 26      $rank += shift @res;
131            8                                 22      push @reasons, @res;
132                                                   
133            8                                 41      return $rank, @reasons;
134                                                   }
135                                                   
136                                                   # Compares query times and returns a rank increase value if the
137                                                   # times differ significantly or 0 if they don't.
138                                                   sub compare_query_times {
139           23                   23           285      my ( $self, $t1, $t2 ) = @_;
140   ***     23     50                          82      die "I need a t1 argument" unless defined $t1;
141   ***     23     50                          81      die "I need a t2 argument" unless defined $t2;
142                                                   
143           23                                 47      MKDEBUG && _d('host1 query time:', $t1, 'host2 query time:', $t2);
144                                                   
145           23                                 77      my $t1_bucket = bucket_for($t1);
146           23                                 73      my $t2_bucket = bucket_for($t2);
147                                                   
148                                                      # Times are in different buckets so they differ significantly.
149           23    100                          84      if ( $t1_bucket != $t2_bucket ) {
150            5                                 20         my $rank_inc = 2 * abs($t1_bucket - $t2_bucket);
151            5                                 40         return $rank_inc, "Query times differ significantly: "
152                                                            . "host1 in ".$bucket_labels[$t1_bucket]." range, "
153                                                            . "host2 in ".$bucket_labels[$t2_bucket]." range (rank+2)";
154                                                      }
155                                                   
156                                                      # Times are in same bucket; check if they differ by that bucket's threshold.
157           18                                 63      my $inc = percentage_increase($t1, $t2);
158           18    100                          94      if ( $inc >= $bucket_threshold[$t1_bucket] ) {
159            9                                 74         return 1, "Query time increase $inc\% exceeds "
160                                                            . $bucket_threshold[$t1_bucket] . "\% increase threshold for "
161                                                            . $bucket_labels[$t1_bucket] . " range (rank+1)";
162                                                      }
163                                                   
164            9                                 35      return (0);  # No significant difference.
165                                                   }
166                                                   
167                                                   # Compares warnings and returns a rank increase value for two times the
168                                                   # number of warnings with the same code but different level and 3 times
169                                                   # the number of new warnings.
170                                                   sub compare_warnings {
171            8                    8            29      my ( $self, $warnings1, $warnings2 ) = @_;
172   ***      8     50                          30      die "I need a warnings1 argument" unless defined $warnings1;
173   ***      8     50                          27      die "I need a warnings2 argument" unless defined $warnings2;
174                                                   
175            8                                 18      my %new_warnings;
176            8                                 19      my $rank_inc = 0;
177            8                                 18      my @reasons;
178                                                   
179            8                                 33      foreach my $code ( keys %$warnings1 ) {
180            6    100                          24         if ( exists $warnings2->{$code} ) {
181            3    100                          23            if ( $warnings2->{$code}->{Level} ne $warnings1->{$code}->{Level} ) {
182            1                                  3               $rank_inc += 2;
183            1                                 12               push @reasons, "Error $code changes level: "
184                                                                  . $warnings1->{$code}->{Level} . " on host1, "
185                                                                  . $warnings2->{$code}->{Level} . " on host2 (rank+2)";
186                                                            }
187                                                         }
188                                                         else {
189            3                                  7            MKDEBUG && _d('New warning on host1:', $code);
190            3                                 13            push @reasons, "Error $code on host1 is new (rank+3)";
191            3                                  7            %{ $new_warnings{$code} } = %{ $warnings1->{$code} };
               3                                 23   
               3                                 12   
192                                                         }
193                                                      }
194                                                   
195            8                                 38      foreach my $code ( keys %$warnings2 ) {
196   ***      5    100     66                   39         if ( !exists $warnings1->{$code} && !exists $new_warnings{$code} ) {
197            2                                  5            MKDEBUG && _d('New warning on host2:', $code);
198            2                                  8            push @reasons, "Error $code on host2 is new (rank+3)";
199            2                                  5            %{ $new_warnings{$code} } = %{ $warnings2->{$code} };
               2                                 14   
               2                                  8   
200                                                         }
201                                                      }
202                                                   
203            8                                 31      $rank_inc += 3 * scalar keys %new_warnings;
204                                                   
205                                                      # TODO: if we ever want to see the new warnings, we'll just have to
206                                                      #       modify this sub a litte.  %new_warnings is a placeholder for now.
207                                                   
208            8                                 43      return $rank_inc, @reasons;
209                                                   }
210                                                   
211                                                   sub rank_result_sets {
212            6                    6            23      my ( $self, $host1, $host2 ) = @_;
213            6                                 19      my $rank    = 0;   # total rank
214            6                                 16      my @reasons = ();  # all reasons
215            6                                 16      my @res     = ();  # ($rank, @reasons) for each comparison
216                                                   
217            6    100                          31      if ( $host1->{checksum} ne $host2->{checksum} ) {
218            2                                  4         $rank += 50;
219            2                                  9         push @reasons, "Table checksums do not match (rank+50)";
220                                                      }
221                                                   
222            6    100                          27      if ( $host1->{n_rows} != $host2->{n_rows} ) {
223            1                                  3         $rank += 50;
224            1                                  3         push @reasons, "Number of rows do not match (rank+50)";
225                                                      }
226                                                   
227            6                                 30      @res = $self->compare_table_structs($host1->{table_struct},
228                                                                                          $host2->{table_struct});
229            6                                 18      $rank += shift @res;
230            6                                 17      push @reasons, @res;
231                                                   
232            6                                 24      return $rank, @reasons;
233                                                   }
234                                                   
235                                                   sub compare_table_structs {
236            6                    6            22      my ( $self, $s1, $s2 ) = @_;
237   ***      6     50                          22      die "I need a s1 argument" unless defined $s1;
238   ***      6     50                          20      die "I need a s2 argument" unless defined $s2;
239                                                   
240            6                                 15      my $rank_inc = 0;
241            6                                 18      my @reasons  = ();
242                                                   
243                                                      # Compare number of columns.
244   ***      6     50                          12      if ( scalar @{$s1->{cols}} != scalar @{$s2->{cols}} ) {
               6                                 21   
               6                                 27   
245   ***      0                                  0         my $inc = 2 * abs( scalar @{$s1->{cols}} - scalar @{$s2->{cols}} );
      ***      0                                  0   
      ***      0                                  0   
246   ***      0                                  0         $rank_inc += $inc;
247   ***      0                                  0         push @reasons, 'Tables have different columns counts: '
248   ***      0                                  0            . scalar @{$s1->{cols}} . ' columns on host1, '
249   ***      0                                  0            . scalar @{$s2->{cols}} . " columns on host2 (rank+$inc)";
250                                                      }
251                                                   
252                                                      # Compare column types.
253            6                                 15      my %host1_missing_cols = %{$s2->{type_for}};  # Make a copy to modify.
               6                                 51   
254            6                                 17      my @host2_missing_cols;
255            6                                 16      foreach my $col ( keys %{$s1->{type_for}} ) {
               6                                 26   
256           11    100                          48         if ( exists $s2->{type_for}->{$col} ) {
257           10    100                          53            if ( $s1->{type_for}->{$col} ne $s2->{type_for}->{$col} ) {
258            1                                  3               $rank_inc += 3;
259            1                                  9               push @reasons, "Types for $col column differ: "
260                                                                  . "'$s1->{type_for}->{$col}' on host1, "
261                                                                  . "'$s2->{type_for}->{$col}' on host2 (rank+3)";
262                                                            }
263           10                                 39            delete $host1_missing_cols{$col};
264                                                         }
265                                                         else {
266            1                                  4            push @host2_missing_cols, $col;
267                                                         }
268                                                      }
269                                                   
270            6                                 24      foreach my $col ( @host2_missing_cols ) {
271            1                                  3         $rank_inc += 5;
272            1                                  6         push @reasons, "Column $col exists on host1 but not on host2 (rank+5)";
273                                                      }
274            6                                 22      foreach my $col ( keys %host1_missing_cols ) {
275            1                                  3         $rank_inc += 5;
276            1                                  6         push @reasons, "Column $col exists on host2 but not on host1 (rank+5)";
277                                                      }
278                                                   
279            6                                 30      return $rank_inc, @reasons;
280                                                   }
281                                                   
282                                                   sub bucket_for {
283           46                   46           138      my ( $val ) = @_;
284   ***     46     50                         156      die "I need a val" unless defined $val;
285           46    100                         170      return 0 if $val == 0;
286                                                      # The buckets are powers of ten.  Bucket 0 represents (0 <= val < 10us) 
287                                                      # and 7 represents 10s and greater.  The powers are thus constrained to
288                                                      # between -6 and 1.  Because these are used as array indexes, we shift
289                                                      # up so it's non-negative, to get 0 - 7.
290           43                                249      my $bucket = floor(log($val) / log(10)) + 6;
291   ***     43     50                         185      $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
                    100                               
292           43                                128      return $bucket;
293                                                   }
294                                                   
295                                                   # Returns the percentage increase between two values.
296                                                   sub percentage_increase {
297           18                   18            57      my ( $x, $y ) = @_;
298           18    100                          75      return 0 if $x == $y;
299                                                   
300                                                      # Swap values if x > y to keep things simple.
301   ***     11     50                          37      if ( $x > $y ) {
302   ***      0                                  0         my $z = $y;
303   ***      0                                  0            $y = $x;
304   ***      0                                  0            $x = $z;
305                                                      }
306                                                   
307           11    100                          38      if ( $x == 0 ) {
308                                                         # TODO: increase from 0 to some value.  Is this defined mathematically?
309            1                                  3         return 1000;  # This should trigger all buckets' thresholds.
310                                                      }
311                                                   
312           10                                108      return sprintf '%.2f', (($y - $x) / $x) * 100;
313                                                   }
314                                                   
315                                                   sub _d {
316            1                    1            21      my ($package, undef, $line) = caller 0;
317   ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 10   
               2                                 10   
318            1                                  5           map { defined $_ ? $_ : 'undef' }
319                                                           @_;
320            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
321                                                   }
322                                                   
323                                                   1;
324                                                   
325                                                   # ###########################################################################
326                                                   # End QueryRanker package
327                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
52    ***      0      0      0   unless $args{$arg}
61    ***     50      0     14   unless @results > 1
70    ***     50      0     22   if (not $compare)
81    ***     50      0     22   if (not exists $$host_results{$results})
119          100      6      2   if ($$host1{'count'} > 0 or $$host2{'count'} > 0)
124          100      3      5   if (my $diff = abs $$host1{'count'} - $$host2{'count'})
140   ***     50      0     23   unless defined $t1
141   ***     50      0     23   unless defined $t2
149          100      5     18   if ($t1_bucket != $t2_bucket)
158          100      9      9   if ($inc >= $bucket_threshold[$t1_bucket])
172   ***     50      0      8   unless defined $warnings1
173   ***     50      0      8   unless defined $warnings2
180          100      3      3   if (exists $$warnings2{$code}) { }
181          100      1      2   if ($$warnings2{$code}{'Level'} ne $$warnings1{$code}{'Level'})
196          100      2      3   if (not exists $$warnings1{$code} and not exists $new_warnings{$code})
217          100      2      4   if ($$host1{'checksum'} ne $$host2{'checksum'})
222          100      1      5   if ($$host1{'n_rows'} != $$host2{'n_rows'})
237   ***     50      0      6   unless defined $s1
238   ***     50      0      6   unless defined $s2
244   ***     50      0      6   if (scalar @{$$s1{'cols'};} != scalar @{$$s2{'cols'};})
256          100     10      1   if (exists $$s2{'type_for'}{$col}) { }
257          100      1      9   if ($$s1{'type_for'}{$col} ne $$s2{'type_for'}{$col})
284   ***     50      0     46   unless defined $val
285          100      3     43   if $val == 0
291   ***     50      0     42   $bucket < 0 ? :
             100      1     42   $bucket > 7 ? :
298          100      7     11   if $x == $y
301   ***     50      0     11   if ($x > $y)
307          100      1     10   if ($x == 0)
317   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
196   ***     66      3      0      2   not exists $$warnings1{$code} and not exists $new_warnings{$code}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
119          100      5      1      2   $$host1{'count'} > 0 or $$host2{'count'} > 0


Covered Subroutines
-------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:25 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:26 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:28 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:29 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:31 
_d                        1 /home/daniel/dev/maatkit/common/QueryRanker.pm:316
bucket_for               46 /home/daniel/dev/maatkit/common/QueryRanker.pm:283
compare_query_times      23 /home/daniel/dev/maatkit/common/QueryRanker.pm:139
compare_table_structs     6 /home/daniel/dev/maatkit/common/QueryRanker.pm:236
compare_warnings          8 /home/daniel/dev/maatkit/common/QueryRanker.pm:171
new                       1 /home/daniel/dev/maatkit/common/QueryRanker.pm:50 
percentage_increase      18 /home/daniel/dev/maatkit/common/QueryRanker.pm:297
rank_query_times          8 /home/daniel/dev/maatkit/common/QueryRanker.pm:98 
rank_result_sets          6 /home/daniel/dev/maatkit/common/QueryRanker.pm:212
rank_results             14 /home/daniel/dev/maatkit/common/QueryRanker.pm:60 
rank_warnings             8 /home/daniel/dev/maatkit/common/QueryRanker.pm:111


