---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...aatkit/common/Progress.pm   89.6   76.7   75.0   92.3    0.0   40.9   81.0
Progress.t                    100.0   50.0   40.0  100.0    n/a   59.1   96.4
Total                          96.1   72.2   70.3   97.4    0.0  100.0   88.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 15:33:44 2010
Finish:       Thu Jun 24 15:33:44 2010

Run:          Progress.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 15:33:45 2010
Finish:       Thu Jun 24 15:33:45 2010

/home/daniel/dev/maatkit/common/Progress.pm

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
18                                                    # Progress package $Revision: 6326 $
19                                                    # ###########################################################################
20                                                    package Progress;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
26             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  6   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 12   
32                                                    
33                                                    # This module encapsulates a progress report.  To create a new object, pass in
34                                                    # the following:
35                                                    #  jobsize  Must be a number; defines the job's completion condition
36                                                    #  report   How and when to report progress.  Possible values:
37                                                    #              percentage: based on the percentage complete.
38                                                    #              time:       based on how much time elapsed.
39                                                    #              iterations: based on how many progress updates have happened.
40                                                    #  interval How many of whatever's specified in 'report' to wait before
41                                                    #           reporting progress: report each X%, each X seconds, or each X
42                                                    #           iterations.
43                                                    #
44                                                    # The 'report' and 'interval' can also be omitted, as long the following option
45                                                    # is passed:
46                                                    #  spec     An arrayref of [report,interval].  This is convenient to use from a
47                                                    #           --progress command-line option that is an array.
48                                                    #
49                                                    # Optional arguments:
50                                                    #  start    The start time of the job; can also be set by calling start()
51                                                    #  fraction How complete the job is, as a number between 0 and 1.  Updated by
52                                                    #           calling update().  Normally don't specify this.
53                                                    #  name     If you want to use the default progress indicator, by default it
54                                                    #           just prints out "Progress: ..." but you can replace "Progress" with
55                                                    #           whatever you specify here.
56                                                    sub new {
57    ***      6                    6      0     53      my ( $class, %args ) = @_;
58             6                                 30      foreach my $arg (qw(jobsize)) {
59    ***      6     50                          43         die "I need a $arg argument" unless defined $args{$arg};
60                                                       }
61    ***      6    100     66                   70      if ( (!$args{report} || !$args{interval}) ) {
62    ***      1     50     33                    7         if ( $args{spec} && @{$args{spec}} == 2 ) {
               1                                  8   
63             1                                  3            @args{qw(report interval)} = @{$args{spec}};
               1                                  7   
64                                                          }
65                                                          else {
66    ***      0                                  0            die "I need either report and interval arguments, or a spec";
67                                                          }
68                                                       }
69                                                    
70             6           100                   49      my $name  = $args{name} || "Progress";
71             6           100                   36      $args{start} ||= time();
72             6                                 14      my $self;
73                                                       $self = {
74                                                          last_reported => $args{start},
75                                                          fraction      => 0,       # How complete the job is
76                                                          callback      => sub {
77             2                    2            11            my ($fraction, $elapsed, $remaining, $eta) = @_;
78             2                                 26            printf STDERR "$name: %3d%% %s remain\n",
79                                                                $fraction * 100,
80                                                                Transformers::secs_to_time($remaining),
81                                                                Transformers::ts($eta);
82                                                          },
83             6                                110         %args,
84                                                       };
85             6                                 58      return bless $self, $class;
86                                                    }
87                                                    
88                                                    # Validates the 'spec' argument passed in from --progress command-line option.
89                                                    # It calls die with a trailing newline to avoid auto-adding the file/line.
90                                                    sub validate_spec {
91    ***      3    100             3      0     18      shift @_ if $_[0] eq 'Progress'; # Permit calling as Progress-> or Progress::
92             3                                 12      my ( $spec ) = @_;
93             3    100                          14      if ( @$spec != 2 ) {
94             1                                  3         die "spec array requires a two-part argument\n";
95                                                       }
96             2    100                          17      if ( $spec->[0] !~ m/^(?:percentage|time|iterations)$/ ) {
97             1                                  3         die "spec array's first element must be one of "
98                                                            . "percentage,time,iterations\n";
99                                                       }
100   ***      1     50                           7      if ( $spec->[1] !~ m/^\d+$/ ) {
101            1                                  3         die "spec array's second element must be an integer\n";
102                                                      }
103                                                   }
104                                                   
105                                                   # Specify your own custom way to report the progress.  The default is to print
106                                                   # the percentage to STDERR.  This is created in the call to new().  The
107                                                   # callback is a subroutine that will receive the fraction complete from 0 to
108                                                   # 1, seconds elapsed, seconds remaining, and the Unix timestamp of when we
109                                                   # expect to be complete.
110                                                   sub set_callback {
111   ***      3                    3      0     12      my ( $self, $callback ) = @_;
112            3                                 13      $self->{callback} = $callback;
113                                                   }
114                                                   
115                                                   # Set the start timer of when work began.  You can either set it to time() which
116                                                   # is the default, or pass in a value.
117                                                   sub start {
118   ***      2                    2      0      9      my ( $self, $start ) = @_;
119   ***      2            33                   15      $self->{start} = $self->{last_reported} = $start || time();
120                                                   }
121                                                   
122                                                   # Provide a progress update.  Pass in a callback subroutine which this code can
123                                                   # use to ask how complete the job is.  This callback will be called as
124                                                   # appropriate.  For example, in time-lapse updating, it won't be called unless
125                                                   # it's time to report the progress.  The callback has to return a number that's
126                                                   # of the same dimensions as the jobsize.  For example, if a text file has 800
127                                                   # lines to process, that's a jobsize of 800; the callback should return how
128                                                   # many lines we're done processing -- a number between 0 and 800.  You can also
129                                                   # optionally pass in the current time, but this is only for testing.
130                                                   sub update {
131   ***    156                  156      0    560      my ( $self, $callback, $now ) = @_;
132          156                                516      my $jobsize   = $self->{jobsize};
133          156           100                  742      $now        ||= time();
134          156                                584      $self->{iterations}++; # How many updates have happened;
135                                                   
136                                                      # Determine whether to just quit and return...
137   ***    156     50     66                 1474      if ( $self->{report} eq 'time'
                    100    100                        
138                                                            && $self->{interval} > $now - $self->{last_reported}
139                                                      ) {
140   ***      0                                  0         return;
141                                                      }
142                                                      elsif ( $self->{report} eq 'iterations'
143                                                            && ($self->{iterations} - 1) % $self->{interval} > 0
144                                                      ) {
145           25                                 78         return;
146                                                      }
147          131                                386      $self->{last_reported} = $now;
148                                                   
149                                                      # Get the updated status of the job
150          131                                432      my $completed = $callback->();
151          131                                393      $self->{updates}++; # How many times we have run the update callback
152                                                   
153                                                      # Sanity check: can't go beyond 100%
154          131    100                         454      return if $completed > $jobsize;
155                                                   
156                                                      # Compute the fraction complete, between 0 and 1.
157          130    100                         531      my $fraction = $completed > 0 ? $completed / $jobsize : 0;
158                                                   
159                                                      # Now that we know the fraction completed, we can decide whether to continue
160                                                      # on and report, for percentage-based reporting.  Have we crossed an
161                                                      # interval-percent boundary since the last update?
162          130    100    100                  820      if ( $self->{report} eq 'percentage'
163                                                            && $self->fraction_modulo($self->{fraction})
164                                                               >= $self->fraction_modulo($fraction)
165                                                      ) {
166                                                         # We're done; we haven't advanced progress enough to report.
167           81                                246         $self->{fraction} = $fraction;
168           81                                239         return;
169                                                      }
170           49                                158      $self->{fraction} = $fraction;
171                                                   
172                                                      # Continue computing the metrics, and call the callback with them.
173           49                                161      my $elapsed   = $now - $self->{start};
174           49                                129      my $remaining = 0;
175           49                                118      my $eta       = $now;
176   ***     49    100     66                  546      if ( $completed > 0 && $completed <= $jobsize && $elapsed > 0 ) {
                           100                        
177            3                                 11         my $rate = $completed / $elapsed;
178   ***      3     50                          16         if ( $rate > 0 ) {
179            3                                 11            $remaining = ($jobsize - $completed) / $rate;
180            3                                 14            $eta       = $now + int($remaining);
181                                                         }
182                                                      }
183           49                                218      $self->{callback}->($fraction, $elapsed, $remaining, $eta);
184                                                   }
185                                                   
186                                                   # Returns the number rounded to the nearest lower $self->{interval}, for use
187                                                   # with interval-based reporting.  For example, when you want to report every 5%,
188                                                   # then 0% through 4% all return 0%; 5% through 9% return 5%; and so on.  The
189                                                   # number needs to be passed as a fraction from 0 to 1.
190                                                   sub fraction_modulo {
191   ***    206                  206      0    837      my ( $self, $num ) = @_;
192          206                                564      $num *= 100; # Convert from fraction to percentage
193          206                               1822      return sprintf('%d',
194                                                         sprintf('%d', $num / $self->{interval}) * $self->{interval});
195                                                   }
196                                                   
197                                                   sub _d {
198   ***      0                    0                    my ($package, undef, $line) = caller 0;
199   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
200   ***      0                                              map { defined $_ ? $_ : 'undef' }
201                                                           @_;
202   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
203                                                   }
204                                                   
205                                                   1;
206                                                   
207                                                   # ###########################################################################
208                                                   # End Progress package
209                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
59    ***     50      0      6   unless defined $args{$arg}
61           100      1      5   if (not $args{'report'} or not $args{'interval'})
62    ***     50      1      0   if ($args{'spec'} and @{$args{'spec'};} == 2) { }
91           100      2      1   if $_[0] eq 'Progress'
93           100      1      2   if (@$spec != 2)
96           100      1      1   if (not $$spec[0] =~ /^(?:percentage|time|iterations)$/)
100   ***     50      1      0   if (not $$spec[1] =~ /^\d+$/)
137   ***     50      0    156   if ($$self{'report'} eq 'time' and $$self{'interval'} > $now - $$self{'last_reported'}) { }
             100     25    131   elsif ($$self{'report'} eq 'iterations' and ($$self{'iterations'} - 1) % $$self{'interval'} > 0) { }
154          100      1    130   if $completed > $jobsize
157          100    128      2   $completed > 0 ? :
162          100     81     49   if ($$self{'report'} eq 'percentage' and $self->fraction_modulo($$self{'fraction'}) >= $self->fraction_modulo($fraction))
176          100      3     46   if ($completed > 0 and $completed <= $jobsize and $elapsed > 0)
178   ***     50      3      0   if ($rate > 0)
199   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
62    ***     33      0      0      1   $args{'spec'} and @{$args{'spec'};} == 2
137   ***     66    153      3      0   $$self{'report'} eq 'time' and $$self{'interval'} > $now - $$self{'last_reported'}
             100    105     26     25   $$self{'report'} eq 'iterations' and ($$self{'iterations'} - 1) % $$self{'interval'} > 0
162          100     29     20     81   $$self{'report'} eq 'percentage' and $self->fraction_modulo($$self{'fraction'}) >= $self->fraction_modulo($fraction)
176   ***     66      1      0     48   $completed > 0 and $completed <= $jobsize
             100      1     45      3   $completed > 0 and $completed <= $jobsize and $elapsed > 0

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
70           100      1      5   $args{'name'} || 'Progress'
71           100      1      5   $args{'start'} ||= time
133          100      3    153   $now ||= time

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
61    ***     66      1      0      5   not $args{'report'} or not $args{'interval'}
119   ***     33      2      0      0   $start || time


Covered Subroutines
-------------------

Subroutine      Count Pod Location                                       
--------------- ----- --- -----------------------------------------------
BEGIN               1     /home/daniel/dev/maatkit/common/Progress.pm:22 
BEGIN               1     /home/daniel/dev/maatkit/common/Progress.pm:23 
BEGIN               1     /home/daniel/dev/maatkit/common/Progress.pm:25 
BEGIN               1     /home/daniel/dev/maatkit/common/Progress.pm:26 
BEGIN               1     /home/daniel/dev/maatkit/common/Progress.pm:31 
__ANON__            2     /home/daniel/dev/maatkit/common/Progress.pm:77 
fraction_modulo   206   0 /home/daniel/dev/maatkit/common/Progress.pm:191
new                 6   0 /home/daniel/dev/maatkit/common/Progress.pm:57 
set_callback        3   0 /home/daniel/dev/maatkit/common/Progress.pm:111
start               2   0 /home/daniel/dev/maatkit/common/Progress.pm:118
update            156   0 /home/daniel/dev/maatkit/common/Progress.pm:131
validate_spec       3   0 /home/daniel/dev/maatkit/common/Progress.pm:91 

Uncovered Subroutines
---------------------

Subroutine      Count Pod Location                                       
--------------- ----- --- -----------------------------------------------
_d                  0     /home/daniel/dev/maatkit/common/Progress.pm:198


Progress.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die
5                                                           "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
6                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
7              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
8                                                     }
9                                                     
10             1                    1            11   use strict;
               1                                  2   
               1                                  6   
11             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
12             1                    1            12   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
13             1                    1            10   use Test::More tests => 29;
               1                                  4   
               1                                  9   
14                                                    
15             1                    1            20   use Transformers;
               1                                  3   
               1                                 11   
16             1                    1            11   use Progress;
               1                                  3   
               1                                 14   
17             1                    1            14   use MaatkitTest;
               1                                  6   
               1                                 70   
18                                                    
19    ***      1            50      1            11   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  4   
               1                                 48   
20                                                    
21             1                    1            12   use Data::Dumper;
               1                                  4   
               1                                 10   
22             1                                  5   $Data::Dumper::Indent    = 1;
23             1                                  3   $Data::Dumper::Sortkeys  = 1;
24             1                                  4   $Data::Dumper::Quotekeys = 0;
25                                                    
26             1                                  8   my $pr;
27             1                                  3   my $how_much_done    = 0;
28             1                                  3   my $callbacks_called = 0;
29             1                                  3   my $completion_arr   = [];
30                                                    
31                                                    # #############################################################################
32                                                    # Checks that the command-line interface works OK
33                                                    # #############################################################################
34                                                    
35             1                                 16   foreach my $test ( (
36             1                    1           267         [  sub { Progress->validate_spec([qw()]) },
37                                                             'spec array requires a two-part argument', ],
38             1                    1            16         [  sub { Progress->validate_spec([qw(foo bar)]) },
39                                                             'spec array\'s first element must be one of percentage,time,iterations', ],
40             1                    1            15         [  sub { Progress::validate_spec([qw(time bar)]) },
41                                                             'spec array\'s second element must be an integer', ],
42                                                       )
43                                                    ) {
44             3                                 81      throws_ok($test->[0], qr/$test->[1]/, $test->[1]);
45                                                    }
46                                                    
47             1                                 16   $pr = new Progress (
48                                                       jobsize => 100,
49                                                       spec    => [qw(percentage 15)],
50                                                    );
51             1                                  7   is ($pr->{jobsize}, 100, 'jobsize is 100');
52             1                                  6   is ($pr->{report}, 'percentage', 'report is percentage');
53             1                                  6   is ($pr->{interval}, 15, 'interval is 15');
54                                                    
55                                                    # #############################################################################
56                                                    # Simple percentage-based completion.
57                                                    # #############################################################################
58                                                    
59             1                                  7   $pr = new Progress(
60                                                       jobsize  => 100,
61                                                       report   => 'percentage',
62                                                       interval => 5,
63                                                    );
64                                                    
65             1                                 16   is($pr->fraction_modulo(.01), 0, 'fraction_modulo .01');
66             1                                  8   is($pr->fraction_modulo(.04), 0, 'fraction_modulo .04');
67             1                                  6   is($pr->fraction_modulo(.05), 5, 'fraction_modulo .05');
68             1                                  5   is($pr->fraction_modulo(.09), 5, 'fraction_modulo .09');
69                                                    
70                                                    $pr->set_callback(
71                                                       sub{
72            20                   20            81         my ( $fraction, $elapsed, $remaining, $eta ) = @_;
73            20                                 59         $how_much_done = $fraction * 100;
74            20                                 63         $callbacks_called++;
75                                                       }
76             1                                 10   );
77                                                    
78                                                    # 0 through 4% shouldn't trigger the callback to be called, so $how_much_done
79                                                    # should stay at 0%.
80             1                                  7   my $i = 0;
81             1                                  5   for (0..4) {
82             5                    5            30      $pr->update(sub{return $i});
               5                                 16   
83             5                                 22      $i++;
84                                                    }
85             1                                  6   is($how_much_done, 0, 'Progress has not been updated yet');
86             1                                  5   is($callbacks_called, 0, 'Callback has not been called');
87                                                    
88                                                    # Now we cross the 5% threshold... this should call the callback.
89             1                    1             9   $pr->update(sub{return $i});
               1                                  4   
90             1                                  4   $i++;
91             1                                  5   is($how_much_done, 5, 'Progress updated to 5%');
92             1                                  5   is($callbacks_called, 1, 'Callback has been called');
93                                                    
94             1                                  5   for (6..99) {
95            94                   94           546      $pr->update(sub{return $i});
              94                                308   
96            94                                373      $i++;
97                                                    }
98             1                                  4   is($how_much_done, 95, 'Progress updated to 95%'); # Not 99 because interval=5
99             1                                  6   is($callbacks_called, 19, 'Callback has been called 19 times');
100                                                   
101                                                   # Go to 100%
102            1                    1            11   $pr->update(sub{return $i});
               1                                  4   
103            1                                  6   is($how_much_done, 100, 'Progress updated to 100%');
104            1                                  6   is($callbacks_called, 20, 'Callback has been called 20 times');
105                                                   
106                                                   # Can't go beyond 100%, right?
107            1                    1             8   $pr->update(sub{return 200});
               1                                  5   
108            1                                  5   is($how_much_done, 100, 'Progress stops at 100%');
109            1                                  5   is($callbacks_called, 20, 'Callback not called any more times');
110                                                   
111                                                   # #############################################################################
112                                                   # Iteration-based completion.
113                                                   # #############################################################################
114                                                   
115            1                                  8   $pr = new Progress(
116                                                      jobsize  => 500,
117                                                      report   => 'iterations',
118                                                      interval => 2,
119                                                   );
120            1                                  8   $how_much_done    = 0;
121            1                                  3   $callbacks_called = 0;
122                                                   $pr->set_callback(
123                                                      sub{
124           26                   26            99         my ( $fraction, $elapsed, $remaining, $eta ) = @_;
125           26                                 74         $how_much_done = $fraction * 100;
126           26                                 81         $callbacks_called++;
127                                                      }
128            1                                  9   );
129                                                   
130            1                                  6   $i = 0;
131            1                                  5   for ( 0 .. 50 ) {
132           51                   26           284      $pr->update(sub{return $i});
              26                                 92   
133           51                                193      $i++;
134                                                   }
135            1                                  4   is($how_much_done, 10, 'Progress is 10% done');
136            1                                  4   is($callbacks_called, 26, 'Callback called every 2 iterations');
137                                                   
138                                                   # #############################################################################
139                                                   # Time-based completion.
140                                                   # #############################################################################
141                                                   
142            1                                  7   $pr = new Progress(
143                                                      jobsize  => 600,
144                                                      report   => 'time',
145                                                      interval => 10, # Every ten seconds
146                                                   );
147            1                                 10   $pr->start(10); # Current time is 10 seconds.
148            1                                  3   $completion_arr = [];
149            1                                  3   $callbacks_called  = 0;
150                                                   $pr->set_callback(
151                                                      sub{
152            1                    1             5         $completion_arr = [ @_ ];
153            1                                  3         $callbacks_called++;
154                                                      }
155            1                                  7   );
156            1                    1            10   $pr->update(sub{return 60}, 35);
               1                                  5   
157            1                                 13   is_deeply(
158                                                      $completion_arr,
159                                                      [.1, 25, 225, 260 ],
160                                                      'Got completion info for time-based stuff'
161                                                   );
162            1                                 23   is($callbacks_called, 1, 'Callback called once');
163                                                   
164                                                   # #############################################################################
165                                                   # Test the default callback
166                                                   # #############################################################################
167                                                   
168            1                                  3   my $buffer;
169            1                                  3   eval {
170            1                                  7      local *STDERR;
171   ***      1     50             1             2      open STDERR, '>', \$buffer or die $OS_ERROR;
               1                              14756   
               1                                  3   
               1                                  7   
172            1                                 24      $pr = new Progress(
173                                                         jobsize  => 600,
174                                                         report   => 'time',
175                                                         interval => 10, # Every ten seconds
176                                                      );
177            1                                 13      $pr->start(10); # Current time is 10 seconds.
178            1                    1             8      $pr->update(sub{return 60}, 35);
               1                                  5   
179            1                                  7      is($buffer, "Progress:  10% 03:45 remain\n",
180                                                         'Tested the default callback');
181                                                   };
182            1                                 25   is ($EVAL_ERROR, '', "No error in default callback");
183                                                   
184            1                                  9   $buffer = '';
185            1                                  5   eval {
186            1                                  6      local *STDERR;
187   ***      1     50                          26      open STDERR, '>', \$buffer or die $OS_ERROR;
188            1                                 17      $pr = new Progress(
189                                                         jobsize  => 600,
190                                                         report   => 'time',
191                                                         interval => 10, # Every ten seconds
192                                                         name     => 'custom name',
193                                                         start    => 10, # Current time is 10 seconds, alternate interface
194                                                      );
195            1                                 21      is($pr->{start}, 10, 'Custom start time param works');
196            1                    1            14      $pr->update(sub{return 60}, 35);
               1                                  6   
197            1                                 11      is($buffer, "custom name:  10% 03:45 remain\n",
198                                                         'Tested the default callback with custom name');
199                                                   };
200            1                                 18   is ($EVAL_ERROR, '', "No error in default callback with custom name");
201                                                   
202                                                   # #############################################################################
203                                                   # Done.
204                                                   # #############################################################################
205            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
171   ***     50      0      1   unless open STDERR, '>', \$buffer
187   ***     50      0      1   unless open STDERR, '>', \$buffer


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
19    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine Count Location      
---------- ----- --------------
BEGIN          1 Progress.t:10 
BEGIN          1 Progress.t:11 
BEGIN          1 Progress.t:12 
BEGIN          1 Progress.t:13 
BEGIN          1 Progress.t:15 
BEGIN          1 Progress.t:16 
BEGIN          1 Progress.t:17 
BEGIN          1 Progress.t:171
BEGIN          1 Progress.t:19 
BEGIN          1 Progress.t:21 
BEGIN          1 Progress.t:4  
__ANON__       1 Progress.t:102
__ANON__       1 Progress.t:107
__ANON__      26 Progress.t:124
__ANON__      26 Progress.t:132
__ANON__       1 Progress.t:152
__ANON__       1 Progress.t:156
__ANON__       1 Progress.t:178
__ANON__       1 Progress.t:196
__ANON__       1 Progress.t:36 
__ANON__       1 Progress.t:38 
__ANON__       1 Progress.t:40 
__ANON__      20 Progress.t:72 
__ANON__       5 Progress.t:82 
__ANON__       1 Progress.t:89 
__ANON__      94 Progress.t:95 


