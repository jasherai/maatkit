---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryRanker.pm   93.1   67.9    n/a  100.0    n/a  100.0   86.6
Total                          93.1   67.9    n/a  100.0    n/a  100.0   86.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryRanker.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jun 26 18:01:06 2009
Finish:       Fri Jun 26 18:01:06 2009

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
18                                                    # QueryRanker package $Revision: 3993 $
19                                                    # ###########################################################################
20                                                    package QueryRanker;
21                                                    
22                                                    # This module ranks query execution results from QueryExecutor.
23                                                    # (See comments on QueryExecutor::exec() for what an execution result looks
24                                                    # like.)  We want to know which queries have the greatest difference in
25                                                    # execution time, warnings, etc. when executed on different hosts.  The
26                                                    # greater a query's differences, the greater its rank.
27                                                    #
28                                                    # The order of hosts does not matter.  We speak of host1 and host2, but
29                                                    # neither is considered the benchmark.  We are agnostic about the hosts;
30                                                    # it could be an upgrade scenario where host2 is a newer version of host1,
31                                                    # or a downgrade scenario where host2 is older than host1, or a comparison
32                                                    # of the same version on different hardware or something.  So remember:
33                                                    # we're only interested in "absolute" differences and no host has preference.
34                                                    # 
35                                                    # A query's rank (or score) is a simple integer.  Every query starts with
36                                                    # a zero rank.  Then its rank is increased when a difference is found.  How
37                                                    # much it increases depends on the difference.  This is discussed next; it's
38                                                    # different for each comparison.
39                                                    #
40                                                    # There are several metrics by which we compare and rank differences.  The
41                                                    # most basic is time and warnings.  A query's rank increases proportionately
42                                                    # to the absolute difference in its warning counts.  So if a query produces
43                                                    # a warning on host1 but not on host2, or vice-versa, its rank increases
44                                                    # by 1.  Its rank is also increased by 1 for every warning that differs in
45                                                    # its severity; e.g. if it's an error on host1 but a warning on host2, this
46                                                    # may seem like a good thing (the error goes away) but it's not because it's
47                                                    # suspicious and suspicious leads to surprises and we don't like surprises.
48                                                    # Finally, a query's rank is increased by 1 for significant differences in
49                                                    # its execution times.  If its times are in the same bucket but differ by
50                                                    # a factor that is significant for that bucket, then its rank is only
51                                                    # increased by 1.  But if its time are in different buckets, then its rank
52                                                    # is increased by 2 times the difference of buckets; e.g. if one time is
53                                                    # 0.001 and the other time is 0.01, that's 1 bucket different so its rank
54                                                    # is increased by 2.
55                                                    #
56                                                    # Other rank metrics are planned: difference in result checksum, in EXPLAIN
57                                                    # plan, etc.
58                                                    
59             1                    1             9   use strict;
               1                                  2   
               1                                  7   
60             1                    1           102   use warnings FATAL => 'all';
               1                                  3   
               1                                  9   
61                                                    
62             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
63             1                    1            11   use POSIX qw(floor);
               1                                  3   
               1                                  7   
64                                                    
65             1                    1            10   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 14   
66                                                    
67                                                    # Significant percentage increase for each bucket.  For example,
68                                                    # 1us to 4us is a 300% increase, but in reality that is not significant.
69                                                    # But a 500% increase to 6us may be significant.  In the 1s+ range (last
70                                                    # bucket), since the time is already so bad, even a 20% increase (e.g. 1s
71                                                    # to 1.2s) is significant.
72                                                    my @bucket_threshold = qw(500 100 100 500 50 50 20 1);
73                                                    
74                                                    sub new {
75             1                    1            14      my ( $class, %args ) = @_;
76             1                                  4      foreach my $arg ( qw() ) {
77    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
78                                                       }
79             1                                  4      my $self = {
80                                                       };
81             1                                 17      return bless $self, $class;
82                                                    }
83                                                    
84                                                    sub rank {
85             2                    2            31      my ( $self, $results ) = @_;
86    ***      2     50                           9      die "I need a results argument" unless $results;
87                                                       
88             2                                  6      my $rank  = 0;
89             2                                  7      my $host1 = $results->{host1};
90             2                                  7      my $host2 = $results->{host2};
91                                                    
92             2                                 11      $rank += $self->compare_query_times(
93                                                          $host1->{Query_time}, $host2->{Query_time});
94                                                    
95             2                                 12      return $rank;
96                                                    }
97                                                    
98                                                    # Compares two query times and returns a rank increase value if the
99                                                    # times differ significantly or 0 if they don't.
100                                                   sub compare_query_times {
101           17                   17           277      my ( $self, $t1, $t2 ) = @_;
102   ***     17     50                          68      die "I need a t1 argument" unless defined $t1;
103   ***     17     50                          58      die "I need a t2 argument" unless defined $t2;
104                                                   
105           17                                 56      my $t1_bucket = bucket_for($t1);
106           17                                 55      my $t2_bucket = bucket_for($t2);
107                                                   
108                                                      # Times are in different buckets so they differ significantly.
109           17    100                          69      if ( $t1_bucket != $t2_bucket ) {
110            5                                 58         return 2 * abs($t1_bucket - $t2_bucket);
111                                                      }
112                                                   
113                                                      # Times are in same bucket; check if they differ by that bucket's threshold.
114           12                                 39      my $inc = percentage_increase($t1, $t2);
115           12    100                         158      return 1 if $inc >= $bucket_threshold[$t1_bucket];
116                                                   
117            3                                 35      return 0;  # No significant difference.
118                                                   }
119                                                   
120                                                   sub bucket_for {
121           34                   34           116      my ( $val ) = @_;
122   ***     34     50                         133      die "I need a val" unless defined $val;
123           34    100                         130      return 0 if $val == 0;
124                                                      # The buckets are powers of ten.  Bucket 0 represents (0 <= val < 10us) 
125                                                      # and 7 represents 10s and greater.  The powers are thus constrained to
126                                                      # between -6 and 1.  Because these are used as array indexes, we shift
127                                                      # up so it's non-negative, to get 0 - 7.
128           31                                188      my $bucket = floor(log($val) / log(10)) + 6;
129   ***     31     50                         138      $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
                    100                               
130           31                                 94      return $bucket;
131                                                   }
132                                                   
133                                                   # Returns the percentage increase between two values.
134                                                   sub percentage_increase {
135           12                   12            42      my ( $x, $y ) = @_;
136           12    100                          47      return 0 if $x == $y;
137                                                   
138                                                      # Swap values if x > y to keep things simple.
139   ***     11     50                          37      if ( $x > $y ) {
140   ***      0                                  0         my $z = $y;
141   ***      0                                  0            $y = $x;
142   ***      0                                  0            $x = $z;
143                                                      }
144                                                   
145           11    100                          42      if ( $x == 0 ) {
146                                                         # TODO: increase from 0 to some value.  Is this defined mathematically?
147            1                                  4         return 1000;  # This should trigger all buckets' thresholds.
148                                                      }
149                                                   
150           10                                123      return sprintf '%.2f', (($y - $x) / $x) * 100;
151                                                   }
152                                                   
153                                                   sub _d {
154            1                    1            25      my ($package, undef, $line) = caller 0;
155   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  7   
               2                                 11   
156            1                                  5           map { defined $_ ? $_ : 'undef' }
157                                                           @_;
158            1                                  6      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
159                                                   }
160                                                   
161                                                   1;
162                                                   
163                                                   # ###########################################################################
164                                                   # End QueryRanker package
165                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
77    ***      0      0      0   unless $args{$arg}
86    ***     50      0      2   unless $results
102   ***     50      0     17   unless defined $t1
103   ***     50      0     17   unless defined $t2
109          100      5     12   if ($t1_bucket != $t2_bucket)
115          100      9      3   if $inc >= $bucket_threshold[$t1_bucket]
122   ***     50      0     34   unless defined $val
123          100      3     31   if $val == 0
129   ***     50      0     30   $bucket < 0 ? :
             100      1     30   $bucket > 7 ? :
136          100      1     11   if $x == $y
139   ***     50      0     11   if ($x > $y)
145          100      1     10   if ($x == 0)
155   ***     50      2      0   defined $_ ? :


Covered Subroutines
-------------------

Subroutine          Count Location                                          
------------------- ----- --------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:59 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:60 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:62 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:63 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRanker.pm:65 
_d                      1 /home/daniel/dev/maatkit/common/QueryRanker.pm:154
bucket_for             34 /home/daniel/dev/maatkit/common/QueryRanker.pm:121
compare_query_times    17 /home/daniel/dev/maatkit/common/QueryRanker.pm:101
new                     1 /home/daniel/dev/maatkit/common/QueryRanker.pm:75 
percentage_increase    12 /home/daniel/dev/maatkit/common/QueryRanker.pm:135
rank                    2 /home/daniel/dev/maatkit/common/QueryRanker.pm:85 


