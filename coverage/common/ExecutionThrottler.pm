---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mon/ExecutionThrottler.pm  100.0   75.0   50.0  100.0    n/a  100.0   92.2
Total                         100.0   75.0   50.0  100.0    n/a  100.0   92.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          ExecutionThrottler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Nov 19 23:26:29 2009
Finish:       Thu Nov 19 23:26:31 2009

/home/daniel/dev/maatkit/common/ExecutionThrottler.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2009 Percona Inc.
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
18                                                    # ExecutionThrottler package $Revision$
19                                                    # ###########################################################################
20                                                    package ExecutionThrottler;
21                                                    
22             1                    1             9   use strict;
               1                                  5   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
25                                                    
26             1                    1             7   use List::Util qw(sum);
               1                                  3   
               1                                 23   
27             1                    1             6   use Time::HiRes qw(time);
               1                                  7   
               1                                  7   
28             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  8   
29                                                    $Data::Dumper::Indent    = 1;
30                                                    $Data::Dumper::Sortkeys  = 1;
31                                                    $Data::Dumper::Quotekeys = 0;
32                                                    
33             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  9   
34                                                    
35                                                    # Arguments:
36                                                    #   * rate_max          scalar: maximum allowable execution rate
37                                                    #   * get_rate          subref: callback to get the current execution rate
38                                                    #   * check_int         scalar: check interval in seconds for calling get_rate()
39                                                    #   * probability-step  scalar: incr/decr skip_prob in step increments
40                                                    sub new {
41             1                    1            49      my ( $class, %args ) = @_;
42             1                                  6      my @required_args = qw(rate_max get_rate check_int);
43             1                                  4      foreach my $arg ( @required_args ) {
44    ***      3     50                          15         die "I need a $arg argument" unless defined $args{$arg};
45                                                       }
46             1                                 12      my $self = {
47                                                          'probability-step' => 0.05,  # default
48                                                          %args, 
49                                                          rate_ok    => undef,
50                                                          last_check => undef,
51                                                          stats      => {
52                                                             rate_avg     => 0,
53                                                             rate_samples => [],
54                                                          },
55                                                          int_rates  => [],
56                                                          skip_prob  => 0.0,
57                                                       };
58                                                    
59             1                                 15      return bless $self, $class;
60                                                    }
61                                                    
62                                                    sub parse_event {
63             6                    6            75      my ( $self, %args ) = @_;
64             6    100                          43      if ( $self->_time_to_check() ) {
65             3                                 66         my $rate_avg = (sum(@{$self->{int_rates}})   || 0)
               3                                 49   
66    ***      3            50                   12                      / (scalar @{$self->{int_rates}} || 1);
      ***                   50                        
67             3                                 25         $self->_save_rate_avg($rate_avg);
68             3                                 11         @{$self->{int_rates}} = ();
               3                                 27   
69             3                                  8         MKDEBUG && _d('Average rate for last interval:', $rate_avg);
70                                                    
71             3    100                          21         if ( $rate_avg > $self->{rate_max} ) {
72                                                             # Rates is too high; increase the probability that the event
73                                                             # will be skipped.
74             1                                  5            $self->{skip_prob} += $self->{'probability-step'};
75    ***      1     50                           6            $self->{skip_prob}  = 1.0 if $self->{skip_prob} > 1.0;
76             1                                  2            MKDEBUG && _d('Rate max exceeded');
77    ***      1     50                           8            $args{stats}->{rate_max_exceeded}++ if $args{stats};
78                                                          }
79                                                          else {
80                                                             # The rate is ok; decrease the probability that the event
81                                                             # will be skipped.
82             2                                 10            $self->{skip_prob} -= $self->{'probability-step'};
83             2    100                          13            $self->{skip_prob} = 0.0 if $self->{skip_prob} < 0.0;
84                                                          }
85                                                    
86             3                                  7         MKDEBUG && _d('Skip probability:', $self->{skip_prob});
87                                                       }
88                                                       else {
89             3                                 16         my $current_rate = $self->{get_rate}->();
90             3                                 21         push @{$self->{int_rates}}, $current_rate;
               3                                 11   
91             3                                  8         MKDEBUG && _d('Current rate:', $current_rate);
92                                                       }
93             6                                 44      $self->{last_check} = time;
94                                                    
95                                                       # rand() returns a fractional value between [0,1).  If skip_prob is
96                                                       # 0 then, then no queries will be skipped.  If its 1.0, then all queries
97                                                       # will be skipped.  skip_prop is adjusted above; it depends on the
98                                                       # average rate.
99    ***      6     50                          28      if ( $args{event} ) {
100            6    100                          67         $args{event}->{Skip_exec} = $self->{skip_prob} <= rand() ? 0 : 1;
101                                                      }
102                                                   
103            6                                 44      return $args{event};
104                                                   }
105                                                   
106                                                   sub _time_to_check {
107            6                    6            27      my ( $self ) = @_;
108            6    100                          51      return 0 unless $self->{last_check};
109            5    100                          99      return time - $self->{last_check} >= $self->{check_int} ? 1 : 0;
110                                                   }
111                                                   
112                                                   sub rate_avg {
113            1                    1             5      my ( $self ) = @_;
114   ***      1            50                   11      return $self->{stats}->{rate_avg} || 0;
115                                                   }
116                                                   
117                                                   sub skip_probability {
118            3                    3            16      my ( $self ) = @_;
119            3                                 20      return $self->{skip_prob};
120                                                   }
121                                                   
122                                                   sub _save_rate_avg {
123            3                    3            27      my ( $self, $rate ) = @_;
124            3                                 20      my $samples  = $self->{stats}->{rate_samples};
125            3                                 15      push @$samples, $rate;
126   ***      3     50                          21      shift @$samples if @$samples > 100;
127            3                                 28      $self->{stats}->{rate_avg} = sum(@$samples) / (scalar @$samples);
128            3                                 13      return;
129                                                   }
130                                                   
131                                                   sub _d {
132            1                    1            23      my ($package, undef, $line) = caller 0;
133   ***      2     50                           9      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 12   
134            1                                  6           map { defined $_ ? $_ : 'undef' }
135                                                           @_;
136            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
137                                                   }
138                                                   
139                                                   1;
140                                                   
141                                                   # ###########################################################################
142                                                   # End ExecutionThrottler package
143                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
44    ***     50      0      3   unless defined $args{$arg}
64           100      3      3   if ($self->_time_to_check) { }
71           100      1      2   if ($rate_avg > $$self{'rate_max'}) { }
75    ***     50      0      1   if $$self{'skip_prob'} > 1
77    ***     50      0      1   if $args{'stats'}
83           100      1      1   if $$self{'skip_prob'} < 0
99    ***     50      6      0   if ($args{'event'})
100          100      4      2   $$self{'skip_prob'} <= rand() ? :
108          100      1      5   unless $$self{'last_check'}
109          100      3      2   time - $$self{'last_check'} >= $$self{'check_int'} ? :
126   ***     50      0      3   if @$samples > 100
133   ***     50      2      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
66    ***     50      3      0   sum(@{$$self{'int_rates'};}) || 0
      ***     50      3      0   scalar @{$$self{'int_rates'};} || 1
114   ***     50      1      0   $$self{'stats'}{'rate_avg'} || 0


Covered Subroutines
-------------------

Subroutine       Count Location                                                 
---------------- ----- ---------------------------------------------------------
BEGIN                1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:22 
BEGIN                1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:23 
BEGIN                1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:24 
BEGIN                1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:26 
BEGIN                1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:27 
BEGIN                1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:28 
BEGIN                1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:33 
_d                   1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:132
_save_rate_avg       3 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:123
_time_to_check       6 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:107
new                  1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:41 
parse_event          6 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:63 
rate_avg             1 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:113
skip_probability     3 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:118


