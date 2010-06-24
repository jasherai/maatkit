---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mmon/TimeSeriesTrender.pm   88.7   62.5   50.0   90.0    0.0   69.4   78.8
TimeSeriesTrender.t           100.0   50.0   33.3  100.0    n/a   30.6   92.7
Total                          92.6   61.1   40.0   94.4    0.0  100.0   83.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:39 2010
Finish:       Thu Jun 24 19:38:39 2010

Run:          TimeSeriesTrender.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:40 2010
Finish:       Thu Jun 24 19:38:40 2010

/home/daniel/dev/maatkit/common/TimeSeriesTrender.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010-@CURRENTYEAR@ Percona Inc.
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
18                                                    # TimeSeriesTrender package $Revision: 6494 $
19                                                    # ###########################################################################
20                                                    package TimeSeriesTrender;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  8   
23             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
32                                                    
33                                                    # Arguments:
34                                                    #  *  callback    Subroutine to call when the time is set to the next larger
35                                                    #                 increment.  Receives a hashref of the current timestamp's
36                                                    #                 stats (see compute_stats()).
37                                                    sub new {
38    ***      1                    1      0      6      my ( $class, %args ) = @_;
39             1                                  4      foreach my $arg ( qw(callback) ) {
40    ***      1     50                           6         die "I need a $arg argument" unless defined $args{$arg};
41                                                       }
42             1                                  8      my $self = {
43                                                          %args,
44                                                          ts      => '',
45                                                          numbers => [],
46                                                       };
47             1                                 13      return bless $self, $class;
48                                                    }
49                                                    
50                                                    # Set the current timestamp to be applied to all subsequent values received
51                                                    # through add_number().  If the timestamp changes to the "next larger
52                                                    # increment," then fire the callback.  It *is* possible for a timestamp to be
53                                                    # less than one previously seen.  In such cases, we simply lump those
54                                                    # time-series data points into the current timestamp's bucket.
55                                                    sub set_time {
56    ***      2                    2      0      8      my ( $self, $ts ) = @_;
57             2                                  8      my $cur_ts = $self->{ts};
58             2    100                          12      if ( !$cur_ts ) {
      ***            50                               
59             1                                  4         $self->{ts} = $ts;
60                                                       }
61                                                       elsif ( $ts gt $cur_ts ) {
62             1                                  7         my $statistics = $self->compute_stats($cur_ts, $self->{numbers});
63             1                                  5         $self->{callback}->($statistics);
64             1                                  4         $self->{numbers} = [];
65             1                                  6         $self->{ts}      = $ts;
66                                                       }
67                                                       # If $cur_ts > $ts, then we do nothing -- we do not want $self->{ts} to ever
68                                                       # decrease!
69                                                    }
70                                                    
71                                                    # Add a number to the current batch defined by the current timestamp, which is
72                                                    # set by set_time().
73                                                    sub add_number {
74    ***     33                   33      0    116      my ( $self, $number ) = @_;
75            33                                 84      push @{$self->{numbers}}, $number;
              33                                155   
76                                                    }
77                                                    
78                                                    # Compute the desired statistics over the set of numbers, which is passed in as
79                                                    # an arrayref.  Returns a hashref.
80                                                    sub compute_stats {
81    ***      1                    1      0      6      my ( $self, $ts, $numbers ) = @_;
82             1                                  3      my $cnt = scalar @$numbers;
83             1                                  7      my $result = {
84                                                          ts    => $ts,
85                                                          cnt   => 0,
86                                                          sum   => 0,
87                                                          min   => 0,
88                                                          max   => 0,
89                                                          avg   => 0,
90                                                          stdev => 0,
91                                                       };
92    ***      1     50                           5      return $result unless $cnt;
93             1                                  5      my ( $sum, $min, $max, $sumsq ) = (0, 2 ** 32, 0, 0);
94             1                                  3      foreach my $num ( @$numbers ) {
95            33                                 85         $sum   += $num;
96            33    100                         103         $min    = $num < $min ? $num : $min;
97            33    100                         114         $max    = $num > $max ? $num : $max;
98            33                                101         $sumsq += $num * $num;
99                                                       }
100            1                                  5      my $avg   = $sum / $cnt;
101            1                                  5      my $var   = $sumsq / $cnt - ( $avg * $avg );
102   ***      1     50                          11      my $stdev = $var > 0 ? sqrt($var) : 0;
103                                                      # TODO: must compute the significant digits of the input, and use that to
104                                                      # round the output appropriately.
105            1                                  5      @{$result}{qw(cnt sum min max avg stdev)}
               1                                 10   
106                                                         = ($cnt, $sum, $min, $max, $avg, $stdev);
107            1                                  5      return $result;
108                                                   }
109                                                   
110                                                   sub _d {
111   ***      0                    0                    my ($package, undef, $line) = caller 0;
112   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
113   ***      0                                              map { defined $_ ? $_ : 'undef' }
114                                                           @_;
115   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
116                                                   }
117                                                   
118                                                   1;
119                                                   
120                                                   # ###########################################################################
121                                                   # End TimeSeriesTrender package
122                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
40    ***     50      0      1   unless defined $args{$arg}
58           100      1      1   if (not $cur_ts) { }
      ***     50      1      0   elsif ($ts gt $cur_ts) { }
92    ***     50      0      1   unless $cnt
96           100      1     32   $num < $min ? :
97           100      4     29   $num > $max ? :
102   ***     50      1      0   $var > 0 ? :
112   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine    Count Pod Location                                                
------------- ----- --- --------------------------------------------------------
BEGIN             1     /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:22 
BEGIN             1     /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:23 
BEGIN             1     /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:25 
BEGIN             1     /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:26 
BEGIN             1     /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:31 
add_number       33   0 /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:74 
compute_stats     1   0 /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:81 
new               1   0 /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:38 
set_time          2   0 /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:56 

Uncovered Subroutines
---------------------

Subroutine    Count Pod Location                                                
------------- ----- --- --------------------------------------------------------
_d                0     /home/daniel/dev/maatkit/common/TimeSeriesTrender.pm:111


TimeSeriesTrender.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                 20   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1            11   use Test::More tests => 1;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use TimeSeriesTrender;
               1                                  3   
               1                                 10   
15             1                    1            48   use MaatkitTest;
               1                                  4   
               1                                 39   
16                                                    
17             1                                  8   my $result;
18                                                    my $tst = new TimeSeriesTrender(
19             1                    1             5      callback => sub { $result = $_[0]; },
20             1                                 12   );
21                                                    
22             1                                  5   $tst->set_time('5');
23             1                                  9   map { $tst->add_number($_) }
              33                                133   
24                                                       qw(1 2 1 2 12 23 2 2 3 3 21 3 3 1 1 2 3 1 2 12 2
25                                                          3 1 3 2 22 2 2 2 2 3 1 1); 
26             1                                  7   $tst->set_time('6');
27                                                    
28             1                                 14   is_deeply($result,
29                                                       {
30                                                          ts    => 5,
31                                                          stdev => 6.09038140334414,
32                                                          avg   => 4.42424242424242,
33                                                          min   => 1,
34                                                          max   => 23,
35                                                          cnt   => 33,
36                                                          sum   => 146,
37                                                       },
38                                                       'Simple stats test');
39                                                    
40                                                    # #############################################################################
41                                                    # Done.
42                                                    # #############################################################################


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
---------- ----- ----------------------
BEGIN          1 TimeSeriesTrender.t:10
BEGIN          1 TimeSeriesTrender.t:11
BEGIN          1 TimeSeriesTrender.t:12
BEGIN          1 TimeSeriesTrender.t:14
BEGIN          1 TimeSeriesTrender.t:15
BEGIN          1 TimeSeriesTrender.t:4 
BEGIN          1 TimeSeriesTrender.t:9 
__ANON__       1 TimeSeriesTrender.t:19


