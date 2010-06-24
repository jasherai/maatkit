---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mon/ExecutionThrottler.pm  100.0   70.0   52.6  100.0    0.0   57.1   85.1
ExecutionThrottler.t           98.4   50.0   33.3   90.9    n/a   42.9   93.5
Total                          99.3   68.8   50.0   96.0    0.0  100.0   88.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:10 2010
Finish:       Thu Jun 24 19:33:10 2010

Run:          ExecutionThrottler.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:12 2010
Finish:       Thu Jun 24 19:33:12 2010

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
18                                                    # ExecutionThrottler package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    package ExecutionThrottler;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
25                                                    
26             1                    1             7   use List::Util qw(sum min max);
               1                                  2   
               1                                 11   
27             1                    1             9   use Time::HiRes qw(time);
               1                                  3   
               1                                  4   
28             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
29                                                    $Data::Dumper::Indent    = 1;
30                                                    $Data::Dumper::Sortkeys  = 1;
31                                                    $Data::Dumper::Quotekeys = 0;
32                                                    
33    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
34                                                    
35                                                    # Arguments:
36                                                    #   * rate_max   scalar: maximum allowable execution rate
37                                                    #   * get_rate   subref: callback to get the current execution rate
38                                                    #   * check_int  scalar: check interval in seconds for calling get_rate()
39                                                    #   * step       scalar: incr/decr skip_prob in step increments
40                                                    sub new {
41    ***      1                    1      0      8      my ( $class, %args ) = @_;
42             1                                  6      my @required_args = qw(rate_max get_rate check_int step);
43             1                                  3      foreach my $arg ( @required_args ) {
44    ***      4     50                          19         die "I need a $arg argument" unless defined $args{$arg};
45                                                       }
46             1                                 17      my $self = {
47                                                          step       => 0.05,  # default
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
59             1                                 22      return bless $self, $class;
60                                                    }
61                                                    
62                                                    sub throttle {
63    ***      6                    6      0     35      my ( $self, %args ) = @_;
64    ***      6            33                   37      my $time = $args{misc}->{time} || time;
65             6    100                          20      if ( $self->_time_to_check($time) ) {
66             3                                 29         my $rate_avg = (sum(@{$self->{int_rates}})   || 0)
               3                                 17   
67    ***      3            50                    6                      / (scalar @{$self->{int_rates}} || 1);
      ***                   50                        
68             3                                 12         my $running_avg = $self->_save_rate_avg($rate_avg);
69             3                                  6         MKDEBUG && _d('Average rate for last interval:', $rate_avg);
70                                                    
71    ***      3     50                          13         if ( $args{stats} ) {
72             3                                 10            $args{stats}->{throttle_checked_rate}++;
73             3                                 43            $args{stats}->{throttle_rate_avg} = sprintf '%.2f', $running_avg;
74                                                          }
75                                                    
76             3                                  7         @{$self->{int_rates}} = ();
               3                                 12   
77                                                    
78             3    100                          14         if ( $rate_avg > $self->{rate_max} ) {
79                                                             # Rates is too high; increase the probability that the event
80                                                             # will be skipped.
81             1                                  4            $self->{skip_prob} += $self->{step};
82    ***      1     50                           5            $self->{skip_prob}  = 1.0 if $self->{skip_prob} > 1.0;
83             1                                  2            MKDEBUG && _d('Rate max exceeded');
84    ***      1     50                           6            $args{stats}->{throttle_rate_max_exceeded}++ if $args{stats};
85                                                          }
86                                                          else {
87                                                             # The rate is ok; decrease the probability that the event
88                                                             # will be skipped.
89             2                                  8            $self->{skip_prob} -= $self->{step};
90             2    100                          11            $self->{skip_prob} = 0.0 if $self->{skip_prob} < 0.0;
91    ***      2     50                          13            $args{stats}->{throttle_rate_ok}++ if $args{stats};
92                                                          }
93                                                    
94             3                                  6         MKDEBUG && _d('Skip probability:', $self->{skip_prob});
95             3                                 16         $self->{last_check} = $time;
96                                                       }
97                                                       else {
98             3                                 15         my $current_rate = $self->{get_rate}->();
99             3                                  9         push @{$self->{int_rates}}, $current_rate;
               3                                 13   
100   ***      3     50                          13         if ( $args{stats} ) {
101   ***      3            66                   37            $args{stats}->{throttle_rate_min} = min(
102                                                               ($args{stats}->{throttle_rate_min} || ()), $current_rate);
103   ***      3            66                   26            $args{stats}->{throttle_rate_max} = max(
104                                                               ($args{stats}->{throttle_rate_max} || ()), $current_rate);
105                                                         }
106            3                                  7         MKDEBUG && _d('Current rate:', $current_rate);
107                                                      } 
108                                                   
109                                                      # rand() returns a fractional value between [0,1).  If skip_prob is
110                                                      # 0 then, then no queries will be skipped.  If its 1.0, then all queries
111                                                      # will be skipped.  skip_prop is adjusted above; it depends on the
112                                                      # average rate.
113   ***      6     50                          27      if ( $args{event} ) {
114            6    100                          62         $args{event}->{Skip_exec} = $self->{skip_prob} <= rand() ? 'No' : 'Yes';
115                                                      }
116                                                   
117            6                                 40      return $args{event};
118                                                   }
119                                                   
120                                                   sub _time_to_check {
121            6                    6            26      my ( $self, $time ) = @_;
122            6    100                          27      if ( !$self->{last_check} ) {
123            1                                  3         $self->{last_check} = $time;
124            1                                  6         return 0;
125                                                      }
126            5    100                          36      return $time - $self->{last_check} >= $self->{check_int} ? 1 : 0;
127                                                   }
128                                                   
129                                                   sub rate_avg {
130   ***      1                    1      0      4      my ( $self ) = @_;
131   ***      1            50                    9      return $self->{stats}->{rate_avg} || 0;
132                                                   }
133                                                   
134                                                   sub skip_probability {
135   ***      3                    3      0     11      my ( $self ) = @_;
136            3                                 30      return $self->{skip_prob};
137                                                   }
138                                                   
139                                                   sub _save_rate_avg {
140            3                    3            12      my ( $self, $rate ) = @_;
141            3                                 13      my $samples  = $self->{stats}->{rate_samples};
142            3                                  9      push @$samples, $rate;
143   ***      3     50                          13      shift @$samples if @$samples > 1_000;
144            3                                 16      $self->{stats}->{rate_avg} = sum(@$samples) / (scalar @$samples);
145   ***      3            50                   19      return $self->{stats}->{rate_avg} || 0;
146                                                   }
147                                                   
148                                                   sub _d {
149            1                    1             7      my ($package, undef, $line) = caller 0;
150   ***      2     50                          11      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 11   
151            1                                  5           map { defined $_ ? $_ : 'undef' }
152                                                           @_;
153            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
154                                                   }
155                                                   
156                                                   1;
157                                                   
158                                                   # ###########################################################################
159                                                   # End ExecutionThrottler package
160                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
44    ***     50      0      4   unless defined $args{$arg}
65           100      3      3   if ($self->_time_to_check($time)) { }
71    ***     50      3      0   if ($args{'stats'})
78           100      1      2   if ($rate_avg > $$self{'rate_max'}) { }
82    ***     50      0      1   if $$self{'skip_prob'} > 1
84    ***     50      1      0   if $args{'stats'}
90           100      1      1   if $$self{'skip_prob'} < 0
91    ***     50      2      0   if $args{'stats'}
100   ***     50      3      0   if ($args{'stats'})
113   ***     50      6      0   if ($args{'event'})
114          100      4      2   $$self{'skip_prob'} <= rand() ? :
122          100      1      5   if (not $$self{'last_check'})
126          100      3      2   $time - $$self{'last_check'} >= $$self{'check_int'} ? :
143   ***     50      0      3   if @$samples > 1000
150   ***     50      2      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
33    ***     50      0      1   $ENV{'MKDEBUG'} || 0
67    ***     50      3      0   sum(@{$$self{'int_rates'};}) || 0
      ***     50      3      0   scalar @{$$self{'int_rates'};} || 1
131   ***     50      1      0   $$self{'stats'}{'rate_avg'} || 0
145   ***     50      3      0   $$self{'stats'}{'rate_avg'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
64    ***     33      6      0      0   $args{'misc'}{'time'} || time
101   ***     66      2      0      1   $args{'stats'}{'throttle_rate_min'} || ()
103   ***     66      2      0      1   $args{'stats'}{'throttle_rate_max'} || ()


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                                 
---------------- ----- --- ---------------------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:22 
BEGIN                1     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:23 
BEGIN                1     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:24 
BEGIN                1     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:26 
BEGIN                1     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:27 
BEGIN                1     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:28 
BEGIN                1     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:33 
_d                   1     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:149
_save_rate_avg       3     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:140
_time_to_check       6     /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:121
new                  1   0 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:41 
rate_avg             1   0 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:130
skip_probability     3   0 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:135
throttle             6   0 /home/daniel/dev/maatkit/common/ExecutionThrottler.pm:63 


ExecutionThrottler.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 12;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            12   use ExecutionThrottler;
               1                                  3   
               1                                 11   
15             1                    1            13   use MaatkitTest;
               1                                  5   
               1                                 35   
16                                                    
17             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 19   
18                                                    
19             1                                  5   my $rate    = 100;
20             1                                  4   my $oktorun = 1;
21             1                                  3   my $time    = 1.000001;
22             1                                  4   my $stats   = {};
23                                                    my %args = (
24                                                       event   => { arg => 'query', },
25    ***      0                    0             0      oktorun => sub { return $oktorun; },
26             1                                 13      misc    => { time => $time },
27                                                       stats   => $stats,
28                                                    );
29             1                    3             5   my $get_rate = sub { return $rate; };
               3                                 11   
30                                                    
31             1                                 11   my $et = new ExecutionThrottler(
32                                                       rate_max  => 90,
33                                                       get_rate  => $get_rate,
34                                                       check_int => 0.4,
35                                                       step      => 0.8,
36                                                    );
37                                                    
38             1                                  9   isa_ok($et, 'ExecutionThrottler');
39                                                    
40                                                    # This event won't be checked because 0.4 seconds haven't passed
41                                                    # so Skip_exec should still be 0 even though the rate is past max.
42             1                                 14   is_deeply(
43                                                       $et->throttle(%args),
44                                                       $args{event},
45                                                       'Event before first check'
46                                                    );
47                                                    
48                                                    # Since the event above wasn't checked, the skip prop should still be zero.
49             1                                 10   is(
50                                                       $et->skip_probability,
51                                                       0.0,
52                                                       'Zero skip prob'
53                                                    );
54                                                    
55                                                    # Let a time interval pass, 0.4s.
56             1                                  5   $args{misc}->{time} += 0.4;
57                                                    
58                                                    # This event will be checked because a time interval has passed.
59                                                    # The avg int rate will be 100, so skip prop should be stepped up
60                                                    # by 0.8 and Skip_exec will have an 80% chance of being set true.
61             1                                  7   my $event = $et->throttle(%args);
62             1                                  6   ok(
63                                                       exists $event->{Skip_exec},
64                                                       'Event after check, exceeds rate max, got Skip_exec attrib'
65                                                    );
66                                                    
67             1                                  6   is(
68                                                       $et->skip_probability,
69                                                       0.8,
70                                                       'Skip prob stepped by 0.8'
71                                                    );
72                                                    
73                                                    # Inject another rate sample and then sleep until the next check.
74             1                                  3   $rate = 50;
75             1                                  6   $et->throttle(%args);
76             1                                  5   $args{misc}->{time} += 0.45;
77                                                    
78                                                    # This event should be ok because the avg rate dropped below max.
79                                                    # skip prob should be stepped down by 0.8, to zero.
80             1                                  5   is_deeply(
81                                                       $et->throttle(%args),
82                                                       $args{event},
83                                                       'Event ok at min rate'
84                                                    );
85                                                    
86             1                                  9   is(
87                                                       $et->skip_probability,
88                                                       0,
89                                                       'Skip prob stepped down'
90                                                    );
91                                                    
92                                                    # Increase the rate to max and check that it's still ok.
93             1                                  3   $rate = 90;
94             1                                  8   $et->throttle(%args);
95             1                                  4   $args{misc}->{time} += 0.45;
96                                                    
97             1                                  6   is_deeply(
98                                                       $et->throttle(%args),
99                                                       $args{event},
100                                                      'Event ok at max rate'
101                                                   );
102                                                   
103                                                   # The avg int rates were 100, 50, 90 = avg 80.
104            1                                 12   is(
105                                                      $et->rate_avg,
106                                                      80,
107                                                      'Calcs average rate'
108                                                   );
109                                                   
110            1                                  7   is(
111                                                      $stats->{throttle_rate_min},
112                                                      50,
113                                                      'Stats min rate'
114                                                   );
115                                                   
116            1                                  7   is(
117                                                      $stats->{throttle_rate_max},
118                                                      100,
119                                                      'Stats max rate'
120                                                   );
121                                                   
122                                                   # #############################################################################
123                                                   # Done.
124                                                   # #############################################################################
125            1                                  3   my $output = '';
126                                                   {
127            1                                  3      local *STDERR;
               1                                  8   
128            1                    1             2      open STDERR, '>', \$output;
               1                                308   
               1                                  3   
               1                                  6   
129            1                                 17      $et->_d('Complete test coverage');
130                                                   }
131                                                   like(
132            1                                 23      $output,
133                                                      qr/Complete test coverage/,
134                                                      '_d() works'
135                                                   );
136            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location                
---------- ----- ------------------------
BEGIN          1 ExecutionThrottler.t:10 
BEGIN          1 ExecutionThrottler.t:11 
BEGIN          1 ExecutionThrottler.t:12 
BEGIN          1 ExecutionThrottler.t:128
BEGIN          1 ExecutionThrottler.t:14 
BEGIN          1 ExecutionThrottler.t:15 
BEGIN          1 ExecutionThrottler.t:17 
BEGIN          1 ExecutionThrottler.t:4  
BEGIN          1 ExecutionThrottler.t:9  
__ANON__       3 ExecutionThrottler.t:29 

Uncovered Subroutines
---------------------

Subroutine Count Location                
---------- ----- ------------------------
__ANON__       0 ExecutionThrottler.t:25 


