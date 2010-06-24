---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/WatchServer.pm   97.8   63.2   71.4   88.9    0.0   96.1   82.1
WatchServer.t                 100.0   50.0   33.3  100.0    n/a    3.9   95.8
Total                          98.6   62.5   66.7   92.9    0.0  100.0   86.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:55 2010
Finish:       Thu Jun 24 19:38:55 2010

Run:          WatchServer.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:57 2010
Finish:       Thu Jun 24 19:38:57 2010

/home/daniel/dev/maatkit/common/WatchServer.pm

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
18                                                    # WatchServer package $Revision: 5266 $ 
19                                                    # ###########################################################################
20                                                    package WatchServer;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  7   
               1                                  7   
26                                                    
27    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 20   
28                                                    
29                                                    sub new {
30    ***      7                    7      0     48      my ( $class, %args ) = @_;
31             7                                 27      foreach my $arg ( qw(params) ) {
32    ***      7     50                          43         die "I need a $arg argument" unless $args{$arg};
33                                                       }
34                                                    
35             7                                 20      my $check_sub;
36             7                                 16      my %extra_args;
37             7                                 24      eval {
38             7                                 32         ($check_sub, %extra_args) = parse_params($args{params});
39                                                       };
40    ***      7     50                          30      die "Error parsing parameters $args{params}: $EVAL_ERROR" if $EVAL_ERROR;
41                                                    
42             7                                 63      my $self = {
43                                                          %extra_args,
44                                                          %args,
45                                                          check_sub => $check_sub,
46                                                          callbacks => {
47                                                             uptime => \&_uptime,
48                                                             vmstat => \&_vmstat,
49                                                          },
50                                                       };
51             7                                 57      return bless $self, $class;
52                                                    }
53                                                    
54                                                    sub parse_params {
55    ***      7                    7      0     29      my ( $params ) = @_;
56             7                                 42      my ( $cmd, $cmd_arg, $cmp, $thresh ) = split(':', $params);
57             7                                 20      MKDEBUG && _d('Parsed', $params, 'as', $cmd, $cmd_arg, $cmp, $thresh);
58    ***      7     50                          28      die "No command parameter" unless $cmd;
59    ***      7     50     66                   49      die "Invalid command: $cmd; expected loadavg or uptime"
60                                                          unless $cmd eq 'loadavg' || $cmd eq 'vmstat';
61             7    100                          34      if ( $cmd eq 'loadavg' ) {
      ***            50                               
62    ***      4     50    100                   56         die "Invalid $cmd argument: $cmd_arg; expected 1, 5 or 15"
      ***                   66                        
63                                                             unless $cmd_arg eq '1' || $cmd_arg eq '5' || $cmd_arg eq '15';
64                                                       }
65                                                       elsif ( $cmd eq 'vmstat' ) {
66             3                                 28         my @vmstat_args = qw(r b swpd free buff cache si so bi bo in cs us sy id wa);
67            48                                153         die "Invalid $cmd argument: $cmd_arg; expected one of "
68                                                             . join(',', @vmstat_args)
69    ***      3     50                          11            unless grep { $cmd_arg eq $_ } @vmstat_args;
70                                                       }
71    ***      7     50                          26      die "No comparison parameter; expected >, < or =" unless $cmp;
72    ***      7     50     66                   83      die "Invalid comparison parameter: $cmp; expected >, < or ="
      ***                   66                        
73                                                          unless $cmp eq '<' || $cmp eq '>' || $cmp eq '=';
74    ***      7     50                          24      die "No threshold value (N)" unless defined $thresh;
75                                                    
76                                                       # User probably doesn't care that = and == mean different things
77                                                       # in a programming language; just do what they expect.
78             7    100                          30      $cmp = '==' if $cmp eq '=';
79                                                    
80             7                                 95      my @lines = (
81                                                          'sub {',
82                                                          '   my ( $self, %args ) = @_;',
83                                                          "   my \$val = \$self->_get_val_from_$cmd('$cmd_arg', %args);",
84                                                          "   MKDEBUG && _d('Current $cmd $cmd_arg =', \$val);",
85                                                          "   \$self->_save_last_check(\$val, '$cmp', '$thresh');",
86                                                          "   return \$val $cmp $thresh ? 1 : 0;",
87                                                          '}',
88                                                       );
89                                                    
90                                                       # Make the subroutine.
91             7                                 38      my $code = join("\n", @lines);
92             7                                 14      MKDEBUG && _d('OK sub:', @lines);
93    ***      7     50                         742      my $check_sub = eval $code
94                                                          or die "Error compiling subroutine code:\n$code\n$EVAL_ERROR";
95                                                    
96             7                                 40      return $check_sub;
97                                                    }
98                                                    
99                                                    sub uses_dbh {
100   ***      0                    0      0      0      return 0;
101                                                   }
102                                                   
103                                                   sub set_dbh {
104   ***      0                    0      0      0      return;
105                                                   }
106                                                   
107                                                   sub set_callbacks {
108   ***      5                    5      0     25      my ( $self, %callbacks ) = @_;
109            5                                 23      foreach my $func ( keys %callbacks ) {
110   ***      5     50                          26         die "Callback $func does not exist"
111                                                            unless exists $self->{callbacks}->{$func};
112            5                                 21         $self->{callbacks}->{$func} = $callbacks{$func};
113            5                                 16         MKDEBUG && _d('Set new callback for', $func);
114                                                      }
115            5                                 18      return;
116                                                   }
117                                                   
118                                                   sub check {
119   ***      7                    7      0     30      my ( $self, %args ) = @_;
120            7                                 37      return $self->{check_sub}->(@_);
121                                                   }
122                                                   
123                                                   sub _uptime {
124            1                    1          2925      return `uptime`;
125                                                   }
126                                                   
127                                                   sub _get_val_from_loadavg {
128            4                    4            23      my ( $self, $cmd_arg, %args ) = @_;
129            4                                 21      my $uptime = $self->{callbacks}->{uptime}->();
130            4                                 20      chomp $uptime;
131   ***      4     50                          15      return 0 unless $uptime;
132            4                                 66      my @loadavgs = $uptime =~ m/load average:\s+(\S+),\s+(\S+),\s+(\S+)/;
133            4                                 11      MKDEBUG && _d('Load averages:', @loadavgs);
134            4    100                          31      my $i = $cmd_arg == 1 ? 0
                    100                               
135                                                            : $cmd_arg == 5 ? 1
136                                                            :                 2;
137   ***      4            50                   33      return $loadavgs[$i] || 0;
138                                                   }
139                                                   
140                                                   sub _vmstat {
141            1                    1         23464      return `vmstat`;
142                                                   }
143                                                   
144                                                   # Parses vmstat output like:
145                                                   # procs -----------memory---------- ---swap-- -----io---- -system-- ----cpu----
146                                                   # r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa
147                                                   # 0  0      0 664668 130452 566588    0    0     8    11  237  351  5  1 93  1
148                                                   # and returns a hashref with the values like:
149                                                   #   r    => 0,
150                                                   #   free => 664668,
151                                                   #   etc.
152                                                   sub _parse_vmstat {
153            5                    5            27      my ( $vmstat_output ) = @_;
154            5                                 16      MKDEBUG && _d('vmstat output:', $vmstat_output);
155           18                                 54      my @lines =
156                                                         map {
157            5                                 39            my $line = $_;
158           18                                174            my @vals = split(/\s+/, $line);
159           18                                 88            \@vals;
160                                                         } split(/\n/, $vmstat_output);
161            5                                 21      my %vmstat;
162            5                                 15      my $n_vals = scalar @{$lines[1]};
               5                                 22   
163            5                                 32      for my $i ( 0..$n_vals-1 ) {
164           85    100                         338         next unless $lines[1]->[$i];
165           80                                415         $vmstat{$lines[1]->[$i]} = $lines[-1]->[$i];
166                                                      }
167            5                                104      return \%vmstat;
168                                                   }
169                                                   
170                                                   sub _get_val_from_vmstat {
171            3                    3            14      my ( $self, $cmd_arg, %args ) = @_;
172            3                                 19      my $vmstat_output = $self->{callbacks}->{vmstat}->();
173            3           100                   25      return _parse_vmstat($vmstat_output)->{$cmd_arg} || 0;
174                                                   }
175                                                   
176                                                   sub _save_last_check {
177            7                    7            53      my ( $self, @args ) = @_;
178            7                                 42      $self->{last_check} = [ @args ];
179            7                                 23      return;
180                                                   }
181                                                   
182                                                   sub get_last_check {
183   ***      1                    1      0      4      my ( $self ) = @_;
184            1                                  4      return @{ $self->{last_check} };
               1                                  9   
185                                                   }
186                                                   
187                                                   sub _d {
188            1                    1             8      my ($package, undef, $line) = caller 0;
189   ***      2     50                          12      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 10   
190            1                                  5           map { defined $_ ? $_ : 'undef' }
191                                                           @_;
192            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
193                                                   }
194                                                   
195                                                   1;
196                                                   
197                                                   # ###########################################################################
198                                                   # End WatchServer package
199                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
32    ***     50      0      7   unless $args{$arg}
40    ***     50      0      7   if $EVAL_ERROR
58    ***     50      0      7   unless $cmd
59    ***     50      0      7   unless $cmd eq 'loadavg' or $cmd eq 'vmstat'
61           100      4      3   if ($cmd eq 'loadavg') { }
      ***     50      3      0   elsif ($cmd eq 'vmstat') { }
62    ***     50      0      4   unless $cmd_arg eq '1' or $cmd_arg eq '5' or $cmd_arg eq '15'
69    ***     50      0      3   unless grep {$cmd_arg eq $_;} @vmstat_args
71    ***     50      0      7   unless $cmp
72    ***     50      0      7   unless $cmp eq '<' or $cmp eq '>' or $cmp eq '='
74    ***     50      0      7   unless defined $thresh
78           100      4      3   if $cmp eq '='
93    ***     50      0      7   unless my $check_sub = eval $code
110   ***     50      0      5   unless exists $$self{'callbacks'}{$func}
131   ***     50      0      4   unless $uptime
134          100      1      2   $cmd_arg == 5 ? :
             100      1      3   $cmd_arg == 1 ? :
164          100      5     80   unless $lines[1][$i]
189   ***     50      2      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0
137   ***     50      4      0   $loadavgs[$i] || 0
173          100      2      1   _parse_vmstat($vmstat_output)->{$cmd_arg} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
59    ***     66      4      3      0   $cmd eq 'loadavg' or $cmd eq 'vmstat'
62           100      1      1      2   $cmd_arg eq '1' or $cmd_arg eq '5'
      ***     66      2      2      0   $cmd_arg eq '1' or $cmd_arg eq '5' or $cmd_arg eq '15'
72    ***     66      0      3      4   $cmp eq '<' or $cmp eq '>'
      ***     66      3      4      0   $cmp eq '<' or $cmp eq '>' or $cmp eq '='


Covered Subroutines
-------------------

Subroutine            Count Pod Location                                          
--------------------- ----- --- --------------------------------------------------
BEGIN                     1     /home/daniel/dev/maatkit/common/WatchServer.pm:22 
BEGIN                     1     /home/daniel/dev/maatkit/common/WatchServer.pm:23 
BEGIN                     1     /home/daniel/dev/maatkit/common/WatchServer.pm:25 
BEGIN                     1     /home/daniel/dev/maatkit/common/WatchServer.pm:27 
_d                        1     /home/daniel/dev/maatkit/common/WatchServer.pm:188
_get_val_from_loadavg     4     /home/daniel/dev/maatkit/common/WatchServer.pm:128
_get_val_from_vmstat      3     /home/daniel/dev/maatkit/common/WatchServer.pm:171
_parse_vmstat             5     /home/daniel/dev/maatkit/common/WatchServer.pm:153
_save_last_check          7     /home/daniel/dev/maatkit/common/WatchServer.pm:177
_uptime                   1     /home/daniel/dev/maatkit/common/WatchServer.pm:124
_vmstat                   1     /home/daniel/dev/maatkit/common/WatchServer.pm:141
check                     7   0 /home/daniel/dev/maatkit/common/WatchServer.pm:119
get_last_check            1   0 /home/daniel/dev/maatkit/common/WatchServer.pm:183
new                       7   0 /home/daniel/dev/maatkit/common/WatchServer.pm:30 
parse_params              7   0 /home/daniel/dev/maatkit/common/WatchServer.pm:55 
set_callbacks             5   0 /home/daniel/dev/maatkit/common/WatchServer.pm:108

Uncovered Subroutines
---------------------

Subroutine            Count Pod Location                                          
--------------------- ----- --- --------------------------------------------------
set_dbh                   0   0 /home/daniel/dev/maatkit/common/WatchServer.pm:104
uses_dbh                  0   0 /home/daniel/dev/maatkit/common/WatchServer.pm:100


WatchServer.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            55   use strict;
               1                                  2   
               1                                  5   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            11   use Test::More tests => 11;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use WatchServer;
               1                                  3   
               1                                 11   
15             1                    1            13   use MaatkitTest;
               1                                  4   
               1                                 39   
16                                                    
17                                                    # ###########################################################################
18                                                    # Test parsing vmstat output.
19                                                    # ###########################################################################
20                                                    
21             1                                  6   my $vmstat_output ="procs -----------memory---------- ---swap-- -----io---- -system-- ----cpu----
22                                                     r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa
23                                                      1  0      0 664668 130452 566588    0    0     8    11  237  351  5  1 93  1
24                                                    ";
25                                                    
26             1                                  8   is_deeply(
27                                                       WatchServer::_parse_vmstat($vmstat_output),
28                                                       {
29                                                          b     => '0',
30                                                          r     => '1',
31                                                          swpd  => '0',
32                                                          free  => '664668',
33                                                          buff  => '130452',
34                                                          cache => '566588',
35                                                          si    => '0',
36                                                          so    => '0',
37                                                          bi    => '8',
38                                                          bo    => '11',
39                                                          in    => '237',
40                                                          cs    => '351',
41                                                          us    => '5',
42                                                          sy    => '1',
43                                                          id    => '93',
44                                                          wa    => '1'
45                                                       },
46                                                       'Parse vmstat output, 1 line'
47                                                    );
48                                                    
49             1                                 17   $vmstat_output ="procs -----------memory---------- ---swap-- -----io---- -system-- ----cpu----
50                                                     r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa
51                                                      2  0      0 592164 143884 571712    0    0     6     9  228  340  4  1 94  1
52                                                       1  0      0 592144 143888 571712    0    0     0    76  682  725  2  1 94  2
53                                                    ";
54                                                    
55             1                                  6   is_deeply(
56                                                       WatchServer::_parse_vmstat($vmstat_output),
57                                                       {
58                                                          b     => '0',
59                                                          r     => '1',
60                                                          swpd  => '0',
61                                                          free  => '592144',
62                                                          buff  => '143888',
63                                                          cache => '571712',
64                                                          si    => '0',
65                                                          so    => '0',
66                                                          bi    => '0',
67                                                          bo    => '76',
68                                                          in    => '682',
69                                                          cs    => '725',
70                                                          us    => '2',
71                                                          sy    => '1',
72                                                          id    => '94',
73                                                          wa    => '2'
74                                                       },
75                                                       'Parse vmstat output, 2 lines'
76                                                    );
77                                                    
78                                                    # ###########################################################################
79                                                    # Test watching loadavg (uptime).
80                                                    # ###########################################################################
81                                                    
82             1                                 13   my $uptime = ' 14:14:53 up 23:59,  5 users,  load average: 0.08, 0.05, 0.04';
83             3                    3            20   sub get_uptime { return $uptime };
84                                                    
85             1                                244   my $w = new WatchServer(
86                                                       params => 'loadavg:1:=:0.08',
87                                                    );
88             1                                  6   $w->set_callbacks( uptime => \&get_uptime );
89                                                    
90             1                                  5   is(
91                                                       $w->check(),
92                                                       1,
93                                                       'Loadavg 1 min'
94                                                    );
95                                                    
96             1                                  6   $w = new WatchServer(
97                                                       params => 'loadavg:5:=:0.05',
98                                                    );
99             1                                 20   $w->set_callbacks( uptime => \&get_uptime );
100                                                   
101            1                                  5   is(
102                                                      $w->check(),
103                                                      1,
104                                                      'Loadavg 5 min'
105                                                   );
106                                                   
107            1                                  7   $w = new WatchServer(
108                                                      params => 'loadavg:15:=:0.04',
109                                                   );
110            1                                 18   $w->set_callbacks( uptime => \&get_uptime );
111                                                   
112            1                                  5   is(
113                                                      $w->check(),
114                                                      1,
115                                                      'Loadavg 15 min'
116                                                   );
117                                                   
118                                                   # ###########################################################################
119                                                   # Test watching vmstat.
120                                                   # ###########################################################################
121                                                   
122            2                    2             9   sub get_vmstat { return $vmstat_output};
123                                                   
124            1                                  6   $w = new WatchServer(
125                                                      params => 'vmstat:free:>:0',
126                                                   );
127            1                                 19   $w->set_callbacks( vmstat => \&get_vmstat );
128                                                   
129            1                                  5   is(
130                                                      $w->check(),
131                                                      1,
132                                                      'vmstat free'
133                                                   );
134                                                   
135            1                                  6   $w = new WatchServer(
136                                                      params => 'vmstat:swpd:=:0',
137                                                   );
138            1                                 18   $w->set_callbacks( vmstat => \&get_vmstat );
139                                                   
140            1                                  5   is(
141                                                      $w->check(),
142                                                      1,
143                                                      'vmstat swpd'
144                                                   );
145                                                   
146            1                                  6   is_deeply(
147                                                      [ $w->get_last_check() ],
148                                                      [ '0', '==', '0' ],
149                                                      'get_last_check()'
150                                                   );
151                                                   
152                                                   # ###########################################################################
153                                                   # Live tests.
154                                                   # ###########################################################################
155                                                   
156                                                   # This test may fail because who knows what the loadavg is like on
157                                                   # your box right now.
158                                                   
159            1                                 11   $w = new WatchServer(
160                                                      params => 'loadavg:15:>:0.00'
161                                                   );
162                                                   
163            1                                 19   is(
164                                                      $w->check(),
165                                                      1,
166                                                      'Loadavg 15 min > 0.00 (live)'
167                                                   );
168                                                   
169                                                   
170            1                                 11   $w = new WatchServer(
171                                                      params => 'vmstat:cache:>:1',
172                                                   );
173                                                   
174            1                                 25   is(
175                                                      $w->check(),
176                                                      1,
177                                                      'vmstat cache > 1 (live)'
178                                                   );
179                                                   
180                                                   # #############################################################################
181                                                   # Done.
182                                                   # #############################################################################
183            1                                  4   my $output = '';
184                                                   {
185            1                                  5      local *STDERR;
               1                                 16   
186            1                    1             2      open STDERR, '>', \$output;
               1                                319   
               1                                  3   
               1                                  7   
187            1                                 22      $w->_d('Complete test coverage');
188                                                   }
189                                                   like(
190            1                                 88      $output,
191                                                      qr/Complete test coverage/,
192                                                      '_d() works'
193                                                   );
194            1                                  3   exit;


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
---------- ----- -----------------
BEGIN          1 WatchServer.t:10 
BEGIN          1 WatchServer.t:11 
BEGIN          1 WatchServer.t:12 
BEGIN          1 WatchServer.t:14 
BEGIN          1 WatchServer.t:15 
BEGIN          1 WatchServer.t:186
BEGIN          1 WatchServer.t:4  
BEGIN          1 WatchServer.t:9  
get_uptime     3 WatchServer.t:83 
get_vmstat     2 WatchServer.t:122


