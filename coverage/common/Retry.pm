---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...king-copy/common/Retry.pm  100.0   71.4   50.0  100.0    0.0   35.0   89.5
Retry.t                       100.0   83.3   55.6  100.0    n/a   65.0   95.0
Total                         100.0   75.0   53.8  100.0    0.0  100.0   92.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Mon Jul 12 21:07:17 2010
Finish:       Mon Jul 12 21:07:17 2010

Run:          Retry.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Mon Jul 12 21:07:18 2010
Finish:       Mon Jul 12 21:07:18 2010

/home/daniel/dev/maatkit/working-copy/common/Retry.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010-@CURRENTYEAR@ Percona Inc.
2                                                     
3                                                     # Feedback and improvements are welcome.
4                                                     #
5                                                     # THIS PROGRAM IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
6                                                     # WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
7                                                     # MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
8                                                     #
9                                                     # This program is free software; you can redistribute it and/or modify it under
10                                                    # the terms of the GNU General Public License as published by the Free Software
11                                                    # Foundation, version 2; OR the Perl Artistic License.  On UNIX and similar
12                                                    # systems, you can issue `man perlgpl' or `man perlartistic' to read these
13                                                    # licenses.
14                                                    #
15                                                    # You should have received a copy of the GNU General Public License along with
16                                                    # this program; if not, write to the Free Software Foundation, Inc., 59 Temple
17                                                    # Place, Suite 330, Boston, MA  02111-1307  USA.
18                                                    # ###########################################################################
19                                                    # Retry package $Revision$
20                                                    # ###########################################################################
21                                                    package Retry;
22                                                    
23             1                    1             5   use strict;
               1                                  3   
               1                                  7   
24             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
25             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 14   
27                                                    
28                                                    sub new {
29    ***      1                    1      0      5      my ( $class, %args ) = @_;
30             1                                  5      my $self = {
31                                                          %args,
32                                                       };
33             1                                 12      return bless $self, $class;
34                                                    }
35                                                    
36                                                    # Required arguments:
37                                                    #   * try          coderef: code to try; return true on success
38                                                    #   * wait         coderef: code that waits in between tries
39                                                    # Optional arguments:
40                                                    #   * tries        scalar: number of retries to attempt (default 3)
41                                                    #   * retry_on_die bool: retry try code if it dies (default no)
42                                                    #   * on_success   coderef: code to call if try is successful
43                                                    #   * on_failure   coderef: code to call if try does not succeed
44                                                    # Retries the try code until either it returns true or we exhaust
45                                                    # the number of retry attempts.  The args are passed to the coderefs
46                                                    # (try, wait, on_success, on_failure).  If the try code dies, that's
47                                                    # a final failure (no more retries) unless retry_on_die is true.
48                                                    # Returns either whatever the try code returned or undef on failure.
49                                                    sub retry {
50    ***      4                    4      0     33      my ( $self, %args ) = @_;
51             4                                 19      my @required_args = qw(try wait);
52             4                                 15      foreach my $arg ( @required_args ) {
53    ***      8     50                          38         die "I need a $arg argument" unless $args{$arg};
54                                                       };
55             4                                 17      my ($try, $wait) = @args{@required_args};
56    ***      4            50                   29      my $tries = $args{tries} || 3;
57                                                    
58             4                                 12      my $tryno = 0;
59             4                                 18      while ( ++$tryno <= $tries ) {
60            10                                 21         MKDEBUG && _d("Retry", $tryno, "of", $tries);
61            10                                 24         my $result;
62            10                                 26         eval {
63            10                                 34            $result = $try->();
64                                                          };
65                                                    
66            10    100                          37         if ( $result ) {
67             2                                  5            MKDEBUG && _d("Try code succeeded");
68    ***      2     50                          14            if ( my $on_success = $args{on_success} ) {
69             2                                  4               MKDEBUG && _d("Calling on_success code");
70             2                                  8               $on_success->(result=>$result);
71                                                             }
72             2                                 13            return $result;
73                                                          }
74                                                    
75             8    100                          28         if ( $EVAL_ERROR ) {
76             2                                  5            MKDEBUG && _d("Try code died:", $EVAL_ERROR);
77             2    100                          18            return unless $args{retry_on_die};
78                                                          }
79                                                    
80             7                                 15         MKDEBUG && _d("Try code failed, calling wait code");
81             7                                 23         $wait->(try=>$tryno);
82                                                       }
83                                                    
84             1                                  3      MKDEBUG && _d("Try code did not succeed");
85    ***      1     50                           5      if ( my $on_failure = $args{on_failure} ) {
86             1                                  3         MKDEBUG && _d("Calling on_failure code");
87             1                                  3         $on_failure->();
88                                                       }
89                                                    
90             1                                  6      return;
91                                                    }
92                                                    
93                                                    sub _d {
94             1                    1             8      my ($package, undef, $line) = caller 0;
95    ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  7   
               2                                 11   
96             1                                  4           map { defined $_ ? $_ : 'undef' }
97                                                            @_;
98             1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
99                                                    }
100                                                   
101                                                   1;
102                                                   
103                                                   # ###########################################################################
104                                                   # End Retry package
105                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
53    ***     50      0      8   unless $args{$arg}
66           100      2      8   if ($result)
68    ***     50      2      0   if (my $on_success = $args{'on_success'})
75           100      2      6   if ($EVAL_ERROR)
77           100      1      1   unless $args{'retry_on_die'}
85    ***     50      1      0   if (my $on_failure = $args{'on_failure'})
95    ***     50      2      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0
56    ***     50      0      4   $args{'tries'} || 3


Covered Subroutines
-------------------

Subroutine Count Pod Location                                                
---------- ----- --- --------------------------------------------------------
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/Retry.pm:23
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/Retry.pm:24
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/Retry.pm:25
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/Retry.pm:26
_d             1     /home/daniel/dev/maatkit/working-copy/common/Retry.pm:94
new            1   0 /home/daniel/dev/maatkit/working-copy/common/Retry.pm:29
retry          4   0 /home/daniel/dev/maatkit/working-copy/common/Retry.pm:50


Retry.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            13   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 13;
               1                                  2   
               1                                 10   
13                                                    
14             1                    1            12   use Retry;
               1                                  3   
               1                                 10   
15             1                    1            10   use MaatkitTest;
               1                                  3   
               1                                 48   
16                                                    
17             1                                  5   my $success;
18             1                                  2   my $failure;
19             1                                  3   my $waitno;
20             1                                  2   my $tryno;
21             1                                  3   my $tries;
22             1                                  3   my $die;
23                                                    
24             1                                  6   my $rt = new Retry();
25                                                    
26                                                    my $try = sub {
27            10    100            10            34      if ( $die ) {
28             2                                  5         $die = 0;
29             2                                  5         die "Arrrgh!";
30                                                       }
31             8    100                          46      return $tryno++ == $tries ? "succeed" : 0;
32             1                                  8   };
33                                                    my $wait = sub {
34             7                    7            35      $waitno++;
35             1                                  5   };
36                                                    my $on_success = sub {
37             2                    2             9      $success = "succeed on $tryno";
38             1                                  6   };
39                                                    my $on_failure = sub {
40             1                    1             6      $failure = "failed on $tryno";
41             1                                 21   };
42                                                    sub try_it {
43             4                    4            19      my ( %args ) = @_;
44             4                                 13      $success = "";
45             4                                 11      $failure = "";
46    ***      4            50                   31      $waitno  = $args{wainot} || 0;
47    ***      4            50                   28      $tryno   = $args{tryno}  || 1;
48             4           100                   22      $tries   = $args{tries}  || 3;
49                                                    
50             4                                 32      return $rt->retry(
51                                                          try          => $try,
52                                                          wait         => $wait,
53                                                          on_success   => $on_success,
54                                                          on_failure   => $on_failure,
55                                                          retry_on_die => $args{retry_on_die},
56                                                       );
57                                                    }
58                                                    
59             1                                  5   my $retval = try_it();
60             1                                  9   is(
61                                                       $retval,
62                                                       "succeed",
63                                                       "Retry succeeded"
64                                                    );
65                                                    
66             1                                  5   is(
67                                                       $success,
68                                                       "succeed on 4",
69                                                       "Called on_success code"
70                                                    );
71                                                    
72             1                                  6   is(
73                                                       $waitno,
74                                                       2,
75                                                       "Called wait code"
76                                                    );
77                                                    
78                                                    # Default tries is 3 so allowing ourself 4 tries will cause the retry
79                                                    # to fail and the on_failure code should be called.
80             1                                  5   $retval = try_it(tries=>4);
81             1                                  6   ok(
82                                                       !defined $retval,
83                                                       "Returned undef on failure"
84                                                    );
85                                                    
86             1                                  5   is(
87                                                       $failure,
88                                                       "failed on 4",
89                                                       "Called on_failure code"
90                                                    );
91                                                    
92             1                                  5   is(
93                                                       $success,
94                                                       "",
95                                                       "Did not call on_success code"
96                                                    );
97                                                    
98                                                    # Test what happens if the try code dies.  try_it() will reset $die to 0.
99             1                                  4   $die = 1;
100            1                                  4   try_it();
101            1                                  6   ok(
102                                                      !defined $retval,
103                                                      "Returned undef on try die"
104                                                   );
105                                                   
106            1                                  5   is(
107                                                      $failure,
108                                                      "",
109                                                      "Did not call on_failure code on try die without retry_on_die"
110                                                   );
111                                                   
112            1                                  5   is(
113                                                      $success,
114                                                      "",
115                                                      "Did not call on_success code"
116                                                   );
117                                                   
118                                                   # Test retry_on_die.  This should work with tries=2 because the first
119                                                   # try will die leaving with only 2 more retries.
120            1                                  4   $die = 1;
121            1                                  4   $retval = try_it(retry_on_die=>1, tries=>2);
122            1                                  5   is(
123                                                      $retval,
124                                                      "succeed",
125                                                      "Retry succeeded with retry_on_die"
126                                                   );
127                                                   
128            1                                  5   is(
129                                                      $success,
130                                                      "succeed on 3",
131                                                      "Called on_success code with retry_on_die"
132                                                   );
133                                                   
134            1                                  8   is(
135                                                      $waitno,
136                                                      2,
137                                                      "Called wait code with retry_on_die"
138                                                   );
139                                                   
140                                                   # #############################################################################
141                                                   # Done.
142                                                   # #############################################################################
143            1                                  4   my $output = '';
144                                                   {
145            1                                  3      local *STDERR;
               1                                  7   
146            1                    1            95      open STDERR, '>', \$output;
               1                                304   
               1                                  3   
               1                                  7   
147            1                                 16      $rt->_d('Complete test coverage');
148                                                   }
149                                                   like(
150            1                                 23      $output,
151                                                      qr/Complete test coverage/,
152                                                      '_d() works'
153                                                   );
154            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}
27           100      2      8   if ($die)
31           100      2      6   $tryno++ == $tries ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
46    ***     50      0      4   $args{'wainot'} || 0
47    ***     50      0      4   $args{'tryno'} || 1
48           100      2      2   $args{'tries'} || 3


Covered Subroutines
-------------------

Subroutine Count Location   
---------- ----- -----------
BEGIN          1 Retry.t:10 
BEGIN          1 Retry.t:11 
BEGIN          1 Retry.t:12 
BEGIN          1 Retry.t:14 
BEGIN          1 Retry.t:146
BEGIN          1 Retry.t:15 
BEGIN          1 Retry.t:4  
BEGIN          1 Retry.t:9  
__ANON__      10 Retry.t:27 
__ANON__       7 Retry.t:34 
__ANON__       2 Retry.t:37 
__ANON__       1 Retry.t:40 
try_it         4 Retry.t:43 


