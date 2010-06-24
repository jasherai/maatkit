---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../ProcesslistAggregator.pm   85.0   87.5   80.0   85.7    0.0   82.8   82.7
ProcesslistAggregator.t       100.0   50.0   33.3  100.0    n/a   17.2   95.7
Total                          93.5   83.3   69.2   95.0    0.0  100.0   89.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:40 2010
Finish:       Thu Jun 24 19:35:40 2010

Run:          ProcesslistAggregator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:42 2010
Finish:       Thu Jun 24 19:35:42 2010

/home/daniel/dev/maatkit/common/ProcesslistAggregator.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2010 Percona Inc.
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
18                                                    # ProcesslistAggregator package $Revision: 5669 $
19                                                    # ###########################################################################
20                                                    package ProcesslistAggregator;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                 11   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  1   
               1                                  8   
25                                                    
26    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 16   
27                                                    
28                                                    sub new {
29    ***      1                    1      0      4      my ( $class, %args ) = @_;
30    ***      1            50                   15      my $self = {
31                                                          undef_val => $args{undef_val} || 'NULL',
32                                                       };
33             1                                 11      return bless $self, $class;
34                                                    }
35                                                    
36                                                    # Given an arrayref of processes ($proclist), returns an hashref of
37                                                    # time and counts aggregates for User, Host, db, Command and State.
38                                                    # See t/ProcesslistAggregator.t for examples.
39                                                    # The $proclist arg is usually the return val of:
40                                                    #    $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} } );
41                                                    sub aggregate {
42    ***      4                    4      0   9472      my ( $self, $proclist ) = @_;
43             4                                 18      my $aggregate = {};
44             4                                 11      foreach my $proc ( @{$proclist} ) {
               4                                 20   
45           166                                437         foreach my $field ( keys %{ $proc } ) {
             166                                852   
46                                                             # Don't aggregate these fields.
47          1328    100                        5148            next if $field eq 'Id';
48          1162    100                        4635            next if $field eq 'Info';
49           996    100                        3770            next if $field eq 'Time';
50                                                    
51                                                             # Format the field's value a little.
52           830                               2696            my $val  = $proc->{ $field };
53           830    100                        3038               $val  = $self->{undef_val} if !defined $val;
54           830    100    100                 6373               $val  = lc $val if ( $field eq 'Command' || $field eq 'State' );
55           830    100                        3346               $val  =~ s/:.*// if $field eq 'Host';
56                                                    
57           830                               2683            my $time = $proc->{Time};
58           830    100    100                 5262               $time = 0 if !$time || $time eq 'NULL';
59                                                    
60                                                             # Do this last or else $proc->{$field} won't match.
61           830                               2516            $field = lc $field;
62                                                    
63           830                               3652            $aggregate->{ $field }->{ $val }->{time}  += $time;
64           830                               4246            $aggregate->{ $field }->{ $val }->{count} += 1;
65                                                          }
66                                                       }
67             4                                 54      return $aggregate;
68                                                    }
69                                                    
70                                                    sub _d {
71    ***      0                    0                    my ($package, undef, $line) = caller 0;
72    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
73    ***      0                                              map { defined $_ ? $_ : 'undef' }
74                                                            @_;
75    ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
76                                                    }
77                                                    
78                                                    1;
79                                                    
80                                                    # ###########################################################################
81                                                    # End ProcesslistAggregator package
82                                                    # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
47           100    166   1162   if $field eq 'Id'
48           100    166    996   if $field eq 'Info'
49           100    166    830   if $field eq 'Time'
53           100     28    802   if not defined $val
54           100    332    498   if $field eq 'Command' or $field eq 'State'
55           100    166    664   if $field eq 'Host'
58           100    495    335   if not $time or $time eq 'NULL'
72    ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0
30    ***     50      0      1   $args{'undef_val'} || 'NULL'

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
54           100    166    166    498   $field eq 'Command' or $field eq 'State'
58           100    490      5    335   not $time or $time eq 'NULL'


Covered Subroutines
-------------------

Subroutine Count Pod Location                                                   
---------- ----- --- -----------------------------------------------------------
BEGIN          1     /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:22
BEGIN          1     /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:23
BEGIN          1     /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:24
BEGIN          1     /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:26
aggregate      4   0 /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:42
new            1   0 /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:29

Uncovered Subroutines
---------------------

Subroutine Count Pod Location                                                   
---------- ----- --- -----------------------------------------------------------
_d             0     /home/daniel/dev/maatkit/common/ProcesslistAggregator.pm:71


ProcesslistAggregator.t

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
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            32   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 7;
               1                                  4   
               1                                 12   
13                                                    
14             1                    1            16   use ProcesslistAggregator;
               1                                  3   
               1                                 14   
15             1                    1            11   use TextResultSetParser;
               1                                  3   
               1                                 10   
16             1                    1            12   use DSNParser;
               1                                  3   
               1                                 14   
17             1                    1            15   use MySQLDump;
               1                                  3   
               1                                 14   
18             1                    1            11   use Quoter;
               1                                  3   
               1                                 10   
19             1                    1            10   use TableParser;
               1                                  3   
               1                                 16   
20             1                    1            28   use MaatkitTest;
               1                                  5   
               1                                 40   
21                                                    
22             1                                 18   my $r   = new TextResultSetParser();
23             1                                 35   my $apl = new ProcesslistAggregator();
24                                                    
25             1                                 10   isa_ok($apl, 'ProcesslistAggregator');
26                                                    
27                                                    sub test_aggregate {
28             2                    2            11      my ($file, $expected, $msg) = @_;
29             2                                 17      my $proclist = $r->parse( load_file($file) );
30             2                              10869      is_deeply(
31                                                          $apl->aggregate($proclist),
32                                                          $expected,
33                                                          $msg
34                                                       );
35             2                                101      return;
36                                                    }
37                                                    
38             1                                 41   test_aggregate(
39                                                       'common/t/samples/pl/recset001.txt',
40                                                       {
41                                                          command => { query     => { time => 0, count => 1 } },
42                                                          db      => { ''        => { time => 0, count => 1 } },
43                                                          user    => { msandbox  => { time => 0, count => 1 } },
44                                                          state   => { ''        => { time => 0, count => 1 } },
45                                                          host    => { localhost => { time => 0, count => 1 } },
46                                                       },
47                                                       'Aggregate basic processlist'
48                                                    );
49                                                    
50             1                                 36   test_aggregate(
51                                                       'common/t/samples/pl/recset004.txt',
52                                                       {
53                                                          db => {
54                                                             NULL   => { count => 1,  time => 0 },
55                                                             forest => { count => 50, time => 533 }
56                                                          },
57                                                          user => {
58                                                             user1 => { count => 50, time => 533 },
59                                                             root  => { count => 1,  time => 0 }
60                                                          },
61                                                          host => {
62                                                             '0.1.2.11' => { count => 21, time => 187 },
63                                                             '0.1.2.12' => { count => 25, time => 331 },
64                                                             '0.1.2.21' => { count => 4,  time => 15 },
65                                                             localhost  => { count => 1,  time => 0 }
66                                                          },
67                                                          state => {
68                                                             locked    => { count => 24, time => 84 },
69                                                             preparing => { count => 26, time => 449 },
70                                                             null      => { count => 1,  time => 0 }
71                                                          },
72                                                          command => { query => { count => 51, time => 533 } }
73                                                       },
74                                                       'Sample with 51 processes',
75                                                    );
76                                                    
77             1                                 18   my $aggregate = $apl->aggregate($r->parse(load_file('common/t/samples/pl/recset003.txt')));
78             1                                 99   cmp_ok(
79                                                       $aggregate->{db}->{NULL}->{count},
80                                                       '==',
81                                                       3,
82                                                       '113 proc sample: 3 NULL db'
83                                                    );
84             1                                  9   cmp_ok(
85                                                       $aggregate->{db}->{happy}->{count},
86                                                       '==',
87                                                       110,
88                                                       '113 proc sample: 110 happy db'
89                                                    );
90                                                    
91                                                    # #############################################################################
92                                                    # Issue 777: ProcesslistAggregator undef bug
93                                                    # #############################################################################
94             1                                 12   $r = new TextResultSetParser(
95                                                       value_for => {
96                                                          '' => undef,
97                                                       }
98                                                    );
99                                                    
100            1                                 25   my $row = $r->parse(load_file('common/t/samples/pl/recset007.txt'));
101                                                   
102            1                                434   is_deeply(
103                                                      $row,
104                                                      [
105                                                         {
106                                                            Command => undef,
107                                                            Host => undef,
108                                                            Id => '9',
109                                                            Info => undef,
110                                                            State => undef,
111                                                            Time => undef,
112                                                            User => undef,
113                                                            db => undef
114                                                         }
115                                                      ],
116                                                      'Pathological undef row'
117                                                   );
118                                                   
119            1                                 25   is_deeply(
120                                                      $apl->aggregate($row),
121                                                      {
122                                                         command => {
123                                                          null => {
124                                                            count => 1,
125                                                            time => 0
126                                                          }
127                                                         },
128                                                         db => {
129                                                          NULL => {
130                                                            count => 1,
131                                                            time => 0
132                                                          }
133                                                         },
134                                                         host => {
135                                                          NULL => {
136                                                            count => 1,
137                                                            time => 0
138                                                          }
139                                                         },
140                                                         state => {
141                                                          null => {
142                                                            count => 1,
143                                                            time => 0
144                                                          }
145                                                         },
146                                                         user => {
147                                                          NULL => {
148                                                            count => 1,
149                                                            time => 0
150                                                          }
151                                                         },
152                                                      },
153                                                      'Pathological undef row aggregate'
154                                                   );
155                                                   
156            1                                  3   exit;


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

Subroutine     Count Location                  
-------------- ----- --------------------------
BEGIN              1 ProcesslistAggregator.t:10
BEGIN              1 ProcesslistAggregator.t:11
BEGIN              1 ProcesslistAggregator.t:12
BEGIN              1 ProcesslistAggregator.t:14
BEGIN              1 ProcesslistAggregator.t:15
BEGIN              1 ProcesslistAggregator.t:16
BEGIN              1 ProcesslistAggregator.t:17
BEGIN              1 ProcesslistAggregator.t:18
BEGIN              1 ProcesslistAggregator.t:19
BEGIN              1 ProcesslistAggregator.t:20
BEGIN              1 ProcesslistAggregator.t:4 
BEGIN              1 ProcesslistAggregator.t:9 
test_aggregate     2 ProcesslistAggregator.t:28


