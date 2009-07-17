---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryRanker.pm   92.6   74.1   83.3  100.0    n/a  100.0   88.1
Total                          92.6   74.1   83.3  100.0    n/a  100.0   88.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryRanker.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 17 15:51:18 2009
Finish:       Fri Jul 17 15:51:18 2009

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
18                                                    # QueryRanker package $Revision: 4020 $
19                                                    # ###########################################################################
20                                                    package QueryRanker;
21                                                    
22                                                    # Read http://code.google.com/p/maatkit/wiki/QueryRankerInternals for
23                                                    # details about this module.
24                                                    
25             1                    1            15   use strict;
               1                                  3   
               1                                 10   
26             1                    1            10   use warnings FATAL => 'all';
               1                                174   
               1                                 15   
27                                                    
28             1                    1            10   use English qw(-no_match_vars);
               1                                  4   
               1                                 12   
29             1                    1            18   use POSIX qw(floor);
               1                                  5   
               1                                 14   
30                                                    
31             1                    1            15   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 20   
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
43                                                    sub new {
44             1                    1            27      my ( $class, %args ) = @_;
45             1                                 10      foreach my $arg ( qw() ) {
46    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
47                                                       }
48             1                                  6      my $self = {
49                                                       };
50             1                                 28      return bless $self, $class;
51                                                    }
52                                                    
53                                                    # Ranks execution results from QueryExecutor::exec().  Returns an array:
54                                                    #   (
55                                                    #      rank,         # Integer rank value
56                                                    #      ( reasons ),  # List of reasons for each rank increase
57                                                    #   )
58                                                    sub rank_execution {
59             8                    8            95      my ( $self, $results ) = @_;
60    ***      8     50                          55      die "I need a results argument" unless $results;
61                                                       
62             8                                 34      my $rank    = 0;   # total rank
63             8                                 40      my @reasons = ();  # all reasons
64             8                                 33      my @res     = ();  # ($rank, @reasons) for each comparison
65             8                                 43      my $host1   = $results->{host1};
66             8                                 42      my $host2   = $results->{host2};
67                                                    
68             8                                 76      @res = $self->compare_query_times($host1->{Query_time},$host2->{Query_time});
69             8                                 45      $rank += shift @res;
70             8                                 36      push @reasons, @res;
71                                                    
72                                                       # Always rank queries with warnings above queries without warnings
73                                                       # or queries with identical warnings and no significant time difference.
74                                                       # So any query with a warning will have a minimum rank of 1.
75             8    100    100                  119      if ( $host1->{warning_count} > 0 || $host2->{warning_count} > 0 ) {
76             6                                 30         $rank += 1;
77             6                                 35         push @reasons, "Query has warnings (rank+1)";
78                                                       }
79                                                    
80             8    100                          83      if ( my $diff = abs($host1->{warning_count} - $host2->{warning_count}) ) {
81             3                                 13         $rank += $diff;
82             3                                 27         push @reasons, "Warning counts differ by $diff (rank+$diff)";
83                                                       }
84                                                    
85             8                                 74      @res = $self->compare_warnings($host1->{warnings}, $host2->{warnings});
86             8                                 39      $rank += shift @res;
87             8                                 39      push @reasons, @res;
88                                                    
89             8                                118      return $rank, @reasons;
90                                                    }
91                                                    
92                                                    # Compares query times and returns a rank increase value if the
93                                                    # times differ significantly or 0 if they don't.
94                                                    sub compare_query_times {
95            23                   23           547      my ( $self, $t1, $t2 ) = @_;
96    ***     23     50                         150      die "I need a t1 argument" unless defined $t1;
97    ***     23     50                         133      die "I need a t2 argument" unless defined $t2;
98                                                    
99            23                                 80      MKDEBUG && _d('host1 query time:', $t1, 'host2 query time:', $t2);
100                                                   
101           23                                130      my $t1_bucket = bucket_for($t1);
102           23                                122      my $t2_bucket = bucket_for($t2);
103                                                   
104                                                      # Times are in different buckets so they differ significantly.
105           23    100                         152      if ( $t1_bucket != $t2_bucket ) {
106            5                                 35         my $rank_inc = 2 * abs($t1_bucket - $t2_bucket);
107            5                                 80         return $rank_inc, "Query times differ significantly: "
108                                                            . "host1 in ".$bucket_labels[$t1_bucket]." range, "
109                                                            . "host2 in ".$bucket_labels[$t2_bucket]." range (rank+2)";
110                                                      }
111                                                   
112                                                      # Times are in same bucket; check if they differ by that bucket's threshold.
113           18                                 99      my $inc = percentage_increase($t1, $t2);
114           18    100                         162      if ( $inc >= $bucket_threshold[$t1_bucket] ) {
115            9                                142         return 1, "Query time increase $inc\% exceeds "
116                                                            . $bucket_threshold[$t1_bucket] . "\% increase threshold for "
117                                                            . $bucket_labels[$t1_bucket] . " range (rank+1)";
118                                                      }
119                                                   
120            9                                 57      return (0);  # No significant difference.
121                                                   }
122                                                   
123                                                   # Compares warnings and returns a rank increase value for two times the
124                                                   # number of warnings with the same code but different level and 3 times
125                                                   # the number of new warnings.
126                                                   sub compare_warnings {
127            8                    8            50      my ( $self, $warnings1, $warnings2 ) = @_;
128   ***      8     50                          58      die "I need a warnings1 argument" unless defined $warnings1;
129   ***      8     50                          45      die "I need a warnings2 argument" unless defined $warnings2;
130                                                   
131            8                                 29      my %new_warnings;
132            8                                 33      my $rank_inc = 0;
133            8                                 28      my @reasons;
134                                                   
135            8                                 68      foreach my $code ( keys %$warnings1 ) {
136            6    100                          41         if ( exists $warnings2->{$code} ) {
137            3    100                          42            if ( $warnings2->{$code}->{Level} ne $warnings1->{$code}->{Level} ) {
138            1                                  5               $rank_inc += 2;
139            1                                 20               push @reasons, "Error $code changes level: "
140                                                                  . $warnings1->{$code}->{Level} . " on host1, "
141                                                                  . $warnings2->{$code}->{Level} . " on host2 (rank+2)";
142                                                            }
143                                                         }
144                                                         else {
145            3                                 10            MKDEBUG && _d('New warning on host1:', $code);
146            3                                 22            push @reasons, "Error $code on host1 is new (rank+3)";
147            3                                 12            %{ $new_warnings{$code} } = %{ $warnings1->{$code} };
               3                                 56   
               3                                 25   
148                                                         }
149                                                      }
150                                                   
151            8                                 62      foreach my $code ( keys %$warnings2 ) {
152   ***      5    100     66                  100         if ( !exists $warnings1->{$code} && !exists $new_warnings{$code} ) {
153            2                                  7            MKDEBUG && _d('New warning on host2:', $code);
154            2                                 16            push @reasons, "Error $code on host2 is new (rank+3)";
155            2                                  7            %{ $new_warnings{$code} } = %{ $warnings2->{$code} };
               2                                 44   
               2                                 16   
156                                                         }
157                                                      }
158                                                   
159            8                                 50      $rank_inc += 3 * scalar keys %new_warnings;
160                                                   
161                                                      # TODO: if we ever want to see the new warnings, we'll just have to
162                                                      #       modify this sub a litte.  %new_warnings is a placeholder for now.
163                                                   
164            8                                 81      return $rank_inc, @reasons;
165                                                   }
166                                                   
167                                                   # Ranks results from QueryExecutor::compare_results().  Returns an array:
168                                                   #   (
169                                                   #      rank,         # Integer rank value
170                                                   #      ( reasons ),  # List of reasons for each rank increase
171                                                   #   )
172                                                   sub rank_results {
173            6                    6            40      my ( $self, $results ) = @_;
174   ***      6     50                          42      die "I need a results argument" unless $results;
175                                                   
176            6                                 27      my $rank    = 0;   # total rank
177            6                                 29      my @reasons = ();  # all reasons
178            6                                 27      my @res     = ();  # ($rank, @reasons) for each comparison
179            6                                 34      my $host1   = $results->{host1};
180            6                                 33      my $host2   = $results->{host2};
181                                                   
182            6    100                          59      if ( $host1->{table_checksum} ne $host2->{table_checksum} ) {
183            2                                 11         $rank += 50;
184            2                                 13         push @reasons, "Table checksums do not match (rank+50)";
185                                                      }
186                                                   
187            6    100                          51      if ( $host1->{n_rows} != $host2->{n_rows} ) {
188            1                                  4         $rank += 50;
189            1                                  5         push @reasons, "Number of rows do not match (rank+50)";
190                                                      }
191                                                   
192            6                                 62      @res = $self->compare_table_structs($host1->{table_struct},
193                                                                                          $host2->{table_struct});
194            6                                 31      $rank += shift @res;
195            6                                 30      push @reasons, @res;
196                                                   
197            6                                 75      return $rank, @reasons;
198                                                   }
199                                                   
200                                                   sub compare_table_structs {
201            6                    6            46      my ( $self, $s1, $s2 ) = @_;
202   ***      6     50                          42      die "I need a s1 argument" unless defined $s1;
203   ***      6     50                          34      die "I need a s2 argument" unless defined $s2;
204                                                   
205            6                                 27      my $rank_inc = 0;
206            6                                 26      my @reasons  = ();
207                                                   
208                                                      # Compare number of columns.
209   ***      6     50                          23      if ( scalar @{$s1->{cols}} != scalar @{$s2->{cols}} ) {
               6                                 37   
               6                                 50   
210   ***      0                                  0         my $inc = 2 * abs( scalar @{$s1->{cols}} - scalar @{$s2->{cols}} );
      ***      0                                  0   
      ***      0                                  0   
211   ***      0                                  0         $rank_inc += $inc;
212   ***      0                                  0         push @reasons, 'Tables have different columns counts: '
213   ***      0                                  0            . scalar @{$s1->{cols}} . ' columns on host1, '
214   ***      0                                  0            . scalar @{$s2->{cols}} . " columns on host2 (rank+$inc)";
215                                                      }
216                                                   
217                                                      # Compare column types.
218            6                                 26      my %host1_missing_cols = %{$s2->{type_for}};  # Make a copy to modify.
               6                                 73   
219            6                                 28      my @host2_missing_cols;
220            6                                 24      foreach my $col ( keys %{$s1->{type_for}} ) {
               6                                 51   
221           11    100                          81         if ( exists $s2->{type_for}->{$col} ) {
222           10    100                         139            if ( $s1->{type_for}->{$col} ne $s2->{type_for}->{$col} ) {
223            1                                  5               $rank_inc += 3;
224            1                                 19               push @reasons, "Types for $col column differ: "
225                                                                  . "'$s1->{type_for}->{$col}' on host1, "
226                                                                  . "'$s2->{type_for}->{$col}' on host2 (rank+3)";
227                                                            }
228           10                                 75            delete $host1_missing_cols{$col};
229                                                         }
230                                                         else {
231            1                                 10            push @host2_missing_cols, $col;
232                                                         }
233                                                      }
234                                                   
235            6                                 41      foreach my $col ( @host2_missing_cols ) {
236            1                                  5         $rank_inc += 5;
237            1                                 11         push @reasons, "Column $col exists on host1 but not on host2 (rank+5)";
238                                                      }
239            6                                 41      foreach my $col ( keys %host1_missing_cols ) {
240            1                                  5         $rank_inc += 5;
241            1                                 11         push @reasons, "Column $col exists on host2 but not on host1 (rank+5)";
242                                                      }
243                                                   
244            6                                 57      return $rank_inc, @reasons;
245                                                   }
246                                                   
247                                                   sub bucket_for {
248           46                   46           229      my ( $val ) = @_;
249   ***     46     50                         270      die "I need a val" unless defined $val;
250           46    100                         296      return 0 if $val == 0;
251                                                      # The buckets are powers of ten.  Bucket 0 represents (0 <= val < 10us) 
252                                                      # and 7 represents 10s and greater.  The powers are thus constrained to
253                                                      # between -6 and 1.  Because these are used as array indexes, we shift
254                                                      # up so it's non-negative, to get 0 - 7.
255           43                                445      my $bucket = floor(log($val) / log(10)) + 6;
256   ***     43     50                         328      $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
                    100                               
257           43                                217      return $bucket;
258                                                   }
259                                                   
260                                                   # Returns the percentage increase between two values.
261                                                   sub percentage_increase {
262           18                   18           103      my ( $x, $y ) = @_;
263           18    100                         130      return 0 if $x == $y;
264                                                   
265                                                      # Swap values if x > y to keep things simple.
266   ***     11     50                          67      if ( $x > $y ) {
267   ***      0                                  0         my $z = $y;
268   ***      0                                  0            $y = $x;
269   ***      0                                  0            $x = $z;
270                                                      }
271                                                   
272           11    100                          68      if ( $x == 0 ) {
273                                                         # TODO: increase from 0 to some value.  Is this defined mathematically?
274            1                                  6         return 1000;  # This should trigger all buckets' thresholds.
275                                                      }
276                                                   
277           10                                201      return sprintf '%.2f', (($y - $x) / $x) * 100;
278                                                   }
279                                                   
280                                                   sub _d {
281            1                    1            41      my ($package, undef, $line) = caller 0;
282   ***      2     50                          15      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 13   
               2                                 17   
283            1                                  9           map { defined $_ ? $_ : 'undef' }
284                                                           @_;
285            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
286                                                   }
287                                                   
288                                                   1;
289                                                   
290                                                   # ###########################################################################
291                                                   # End QueryRanker package
292                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
46    ***      0      0      0   unless $args{$arg}
60    ***     50      0      8   unless $results
75           100      6      2   if ($$host1{'warning_count'} > 0 or $$host2{'warning_count'} > 0)
80           100      3      5   if (my $diff = abs $$host1{'warning_count'} - $$host2{'warning_count'})
96    ***     50      0     23   unless defined $t1
97    ***     50      0     23   unless defined $t2
105          100      5     18   if ($t1_bucket != $t2_bucket)
114          100      9      9   if ($inc >= $bucket_threshold[$t1_bucket])
128   ***     50      0      8   unless defined $warnings1
129   ***     50      0      8   unless defined $warnings2
136          100      3      3   if (exists $$warnings2{$code}) { }
137          100      1      2   if ($$warnings2{$code}{'Level'} ne $$warnings1{$code}{'Level'})
152          100      2      3   if (not exists $$warnings1{$code} and not exists $new_warnings{$code})
174   ***     50      0      6   unless $results
182          100      2      4   if ($$host1{'table_checksum'} ne $$host2{'table_checksum'})
187          100      1      5   if ($$host1{'n_rows'} != $$host2{'n_rows'})
202   ***     50      0      6   unless defined $s1
203   ***     50      0      6   unless defined $s2
209   ***     50      0      6   if (scalar @{$$s1{'cols'};} != scalar @{$$s2{'cols'};})
221          100     10      1   if (exists $$s2{'type_for'}{$col}) { }
222          100      1      9   if ($$s1{'type_for'}{$col} ne $$s2{'type_for'}{$col})
249   ***     50      0     46   unless defined $val
250          100      3     43   if $val == 0
256   ***     50      0     42   $bucket < 0 ? :
             100      1     42   $bucket > 7 ? :
263          100      7     11   if $x == $y
266   ***     50      0     11   if ($x > $y)
272          100      1     10   if ($x == 0)
282   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
152   ***     66      3      0      2   not exists $$warnings1{$code} and not exists $new_warnings{$code}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
75           100      5      1      2   $$host1{'warning_count'} > 0 or $$host2{'warning_count'} > 0


Covered Subroutines
-------------------

Subroutine            Count Location                                          
--------------------- ----- --------------------------------------------------
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:25 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:26 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:28 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:29 
BEGIN                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:31 
_d                        1 /home/daniel/dev/maatkit/common/QueryRanker.pm:281
bucket_for               46 /home/daniel/dev/maatkit/common/QueryRanker.pm:248
compare_query_times      23 /home/daniel/dev/maatkit/common/QueryRanker.pm:95 
compare_table_structs     6 /home/daniel/dev/maatkit/common/QueryRanker.pm:201
compare_warnings          8 /home/daniel/dev/maatkit/common/QueryRanker.pm:127
new                       1 /home/daniel/dev/maatkit/common/QueryRanker.pm:44 
percentage_increase      18 /home/daniel/dev/maatkit/common/QueryRanker.pm:262
rank_execution            8 /home/daniel/dev/maatkit/common/QueryRanker.pm:59 
rank_results              6 /home/daniel/dev/maatkit/common/QueryRanker.pm:173


