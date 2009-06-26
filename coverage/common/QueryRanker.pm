---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryRanker.pm   95.1   72.5   83.3  100.0    n/a  100.0   88.6
Total                          95.1   72.5   83.3  100.0    n/a  100.0   88.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryRanker.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jun 26 21:26:58 2009
Finish:       Fri Jun 26 21:26:58 2009

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
18                                                    # QueryRanker package $Revision: 3994 $
19                                                    # ###########################################################################
20                                                    package QueryRanker;
21                                                    
22                                                    # Read http://code.google.com/p/maatkit/wiki/QueryRankerInternals for
23                                                    # details about this module.
24                                                    
25             1                    1             9   use strict;
               1                                  2   
               1                                  7   
26             1                    1           107   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
27                                                    
28             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
29             1                    1            11   use POSIX qw(floor);
               1                                  3   
               1                                  7   
30                                                    
31             1                    1            14   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  4   
               1                                 15   
32                                                    
33                                                    # Significant percentage increase for each bucket.  For example,
34                                                    # 1us to 4us is a 300% increase, but in reality that is not significant.
35                                                    # But a 500% increase to 6us may be significant.  In the 1s+ range (last
36                                                    # bucket), since the time is already so bad, even a 20% increase (e.g. 1s
37                                                    # to 1.2s) is significant.
38                                                    # If you change these values, you'll need to update the threshold tests
39                                                    # in QueryRanker.t.
40                                                    my @bucket_threshold = qw(500 100 100 500 50 50 20 1);
41                                                    
42                                                    sub new {
43             1                    1            14      my ( $class, %args ) = @_;
44             1                                  5      foreach my $arg ( qw() ) {
45    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
46                                                       }
47             1                                  3      my $self = {
48                                                       };
49             1                                 20      return bless $self, $class;
50                                                    }
51                                                    
52                                                    sub rank {
53             8                    8            58      my ( $self, $results ) = @_;
54    ***      8     50                          28      die "I need a results argument" unless $results;
55                                                       
56             8                                 24      my $rank  = 0;
57             8                                 26      my $host1 = $results->{host1};
58             8                                 22      my $host2 = $results->{host2};
59                                                    
60             8                                 41      $rank += $self->compare_query_times(
61                                                          $host1->{Query_time}, $host2->{Query_time});
62                                                    
63                                                       # Always rank queries with warnings above queries without warnings
64                                                       # or queries with identical warnings and no significant time difference.
65                                                       # So any query with a warning will have a minimum rank of 1.
66             8    100    100                   62      if ( $host1->{warning_count} > 0 || $host2->{warning_count} > 0 ) {
67             6                                 19         $rank += 1;
68                                                       }
69                                                    
70             8                                 34      $rank += abs($host1->{warning_count} - $host2->{warning_count});
71             8                                 42      $rank += $self->compare_warnings($host1->{warnings}, $host2->{warnings});
72                                                    
73             8                                 40      return $rank;
74                                                    }
75                                                    
76                                                    # Compares query times and returns a rank increase value if the
77                                                    # times differ significantly or 0 if they don't.
78                                                    sub compare_query_times {
79            23                   23           293      my ( $self, $t1, $t2 ) = @_;
80    ***     23     50                          92      die "I need a t1 argument" unless defined $t1;
81    ***     23     50                          78      die "I need a t2 argument" unless defined $t2;
82                                                    
83            23                                 80      my $t1_bucket = bucket_for($t1);
84            23                                 72      my $t2_bucket = bucket_for($t2);
85                                                    
86                                                       # Times are in different buckets so they differ significantly.
87            23    100                          87      if ( $t1_bucket != $t2_bucket ) {
88             5                                 59         return 2 * abs($t1_bucket - $t2_bucket);
89                                                       }
90                                                    
91                                                       # Times are in same bucket; check if they differ by that bucket's threshold.
92            18                                 64      my $inc = percentage_increase($t1, $t2);
93            18    100                         189      return 1 if $inc >= $bucket_threshold[$t1_bucket];
94                                                    
95             9                                 46      return 0;  # No significant difference.
96                                                    }
97                                                    
98                                                    # Compares warnings and returns a rank increase value for two times the
99                                                    # number of warnings with the same code but different level and 3 times
100                                                   # the number of new warnings.
101                                                   sub compare_warnings {
102            8                    8            30      my ( $self, $warnings1, $warnings2 ) = @_;
103   ***      8     50                          29      die "I need a warnings1 argument" unless defined $warnings1;
104   ***      8     50                          26      die "I need a warnings2 argument" unless defined $warnings2;
105                                                   
106            8                                 21      my %new_warnings;
107            8                                 19      my $rank_inc = 0;
108                                                   
109            8                                 41      foreach my $code ( keys %$warnings1 ) {
110            6    100                          29         if ( exists $warnings2->{$code} ) {
111            3    100                          23            $rank_inc += 2
112                                                               if $warnings2->{$code}->{Level} ne $warnings1->{$code}->{Level};
113                                                         }
114                                                         else {
115            3                                  6            MKDEBUG && _d('New warning in warnings1:', $code);
116            3                                  7            %{ $new_warnings{$code} } = %{ $warnings1->{$code} };
               3                                 23   
               3                                 16   
117                                                         }
118                                                      }
119                                                   
120            8                                 34      foreach my $code ( keys %$warnings2 ) {
121   ***      5    100     66                   40         if ( !exists $warnings1->{$code} && !exists $new_warnings{$code} ) {
122            2                                  5            MKDEBUG && _d('New warning in warnings2:', $code);
123            2                                  4            %{ $new_warnings{$code} } = %{ $warnings2->{$code} };
               2                                 15   
               2                                  9   
124                                                         }
125                                                      }
126                                                   
127            8                                 31      $rank_inc += 3 * scalar keys %new_warnings;
128                                                   
129            8                                 31      return $rank_inc;
130                                                   }
131                                                   
132                                                   sub bucket_for {
133           46                   46           142      my ( $val ) = @_;
134   ***     46     50                         162      die "I need a val" unless defined $val;
135           46    100                         177      return 0 if $val == 0;
136                                                      # The buckets are powers of ten.  Bucket 0 represents (0 <= val < 10us) 
137                                                      # and 7 represents 10s and greater.  The powers are thus constrained to
138                                                      # between -6 and 1.  Because these are used as array indexes, we shift
139                                                      # up so it's non-negative, to get 0 - 7.
140           43                                263      my $bucket = floor(log($val) / log(10)) + 6;
141   ***     43     50                         187      $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
                    100                               
142           43                                132      return $bucket;
143                                                   }
144                                                   
145                                                   # Returns the percentage increase between two values.
146                                                   sub percentage_increase {
147           18                   18            61      my ( $x, $y ) = @_;
148           18    100                          71      return 0 if $x == $y;
149                                                   
150                                                      # Swap values if x > y to keep things simple.
151   ***     11     50                          45      if ( $x > $y ) {
152   ***      0                                  0         my $z = $y;
153   ***      0                                  0            $y = $x;
154   ***      0                                  0            $x = $z;
155                                                      }
156                                                   
157           11    100                          40      if ( $x == 0 ) {
158                                                         # TODO: increase from 0 to some value.  Is this defined mathematically?
159            1                                  4         return 1000;  # This should trigger all buckets' thresholds.
160                                                      }
161                                                   
162           10                                125      return sprintf '%.2f', (($y - $x) / $x) * 100;
163                                                   }
164                                                   
165                                                   sub _d {
166            1                    1            21      my ($package, undef, $line) = caller 0;
167   ***      2     50                          12      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  9   
               2                                 11   
168            1                                  6           map { defined $_ ? $_ : 'undef' }
169                                                           @_;
170            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
171                                                   }
172                                                   
173                                                   1;
174                                                   
175                                                   # ###########################################################################
176                                                   # End QueryRanker package
177                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***      0      0      0   unless $args{$arg}
54    ***     50      0      8   unless $results
66           100      6      2   if ($$host1{'warning_count'} > 0 or $$host2{'warning_count'} > 0)
80    ***     50      0     23   unless defined $t1
81    ***     50      0     23   unless defined $t2
87           100      5     18   if ($t1_bucket != $t2_bucket)
93           100      9      9   if $inc >= $bucket_threshold[$t1_bucket]
103   ***     50      0      8   unless defined $warnings1
104   ***     50      0      8   unless defined $warnings2
110          100      3      3   if (exists $$warnings2{$code}) { }
111          100      1      2   if $$warnings2{$code}{'Level'} ne $$warnings1{$code}{'Level'}
121          100      2      3   if (not exists $$warnings1{$code} and not exists $new_warnings{$code})
134   ***     50      0     46   unless defined $val
135          100      3     43   if $val == 0
141   ***     50      0     42   $bucket < 0 ? :
             100      1     42   $bucket > 7 ? :
148          100      7     11   if $x == $y
151   ***     50      0     11   if ($x > $y)
157          100      1     10   if ($x == 0)
167   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
121   ***     66      3      0      2   not exists $$warnings1{$code} and not exists $new_warnings{$code}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
66           100      5      1      2   $$host1{'warning_count'} > 0 or $$host2{'warning_count'} > 0


Covered Subroutines
-------------------

Subroutine          Count Location                                          
------------------- ----- --------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:25 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:26 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:28 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:29 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:31 
_d                      1 /home/daniel/dev/maatkit/common/QueryRanker.pm:166
bucket_for             46 /home/daniel/dev/maatkit/common/QueryRanker.pm:133
compare_query_times    23 /home/daniel/dev/maatkit/common/QueryRanker.pm:79 
compare_warnings        8 /home/daniel/dev/maatkit/common/QueryRanker.pm:102
new                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:43 
percentage_increase    18 /home/daniel/dev/maatkit/common/QueryRanker.pm:147
rank                    8 /home/daniel/dev/maatkit/common/QueryRanker.pm:53 


