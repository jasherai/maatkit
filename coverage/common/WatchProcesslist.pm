---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...ommon/WatchProcesslist.pm   95.9   53.6   69.6   85.7    0.0   12.5   77.9
WatchProcesslist.t            100.0   50.0   33.3  100.0    n/a   87.5   94.3
Total                          97.8   52.9   65.4   92.6    0.0  100.0   84.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:52 2010
Finish:       Thu Jun 24 19:38:52 2010

Run:          WatchProcesslist.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:53 2010
Finish:       Thu Jun 24 19:38:54 2010

/home/daniel/dev/maatkit/common/WatchProcesslist.pm

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
18                                                    # WatchProcesslist package $Revision: 5266 $
19                                                    # ###########################################################################
20                                                    package WatchProcesslist;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1            15   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
28                                                    
29                                                    sub new {
30    ***      4                    4      0     32      my ( $class, %args ) = @_;
31             4                                 17      foreach my $arg ( qw(params) ) {
32    ***      4     50                          26         die "I need a $arg argument" unless $args{$arg};
33                                                       }
34                                                    
35             4                                  9      my $check_sub;
36             4                                 12      my %extra_args;
37             4                                 12      eval {
38             4                                 16         ($check_sub, %extra_args) = parse_params($args{params});
39                                                       };
40    ***      4     50                          20      die "Error parsing parameters $args{params}: $EVAL_ERROR" if $EVAL_ERROR;
41                                                    
42             4                                 36      my $self = {
43                                                          %extra_args,
44                                                          %args,
45                                                          check_sub => $check_sub,
46                                                          callbacks => {
47                                                             show_processlist => \&_show_processlist,
48                                                          },
49                                                       };
50             4                                 33      return bless $self, $class;
51                                                    }
52                                                    
53                                                    sub parse_params {
54    ***      4                    4      0     15      my ( $params ) = @_;
55             4                                 29      my ( $col, $val, $agg, $cmp, $thresh ) = split(':', $params);
56             4                                 14      $col = lc $col;
57             4                                 13      $val = lc $val;
58             4                                 12      $agg = lc $agg;
59             4                                  8      MKDEBUG && _d('Parsed', $params, 'as', $col, $val, $agg, $cmp, $thresh);
60    ***      4     50                          15      die "No column parameter; expected db, user, host, state or command"
61                                                          unless $col;
62    ***      4     50     66                   76      die "Invalid column: $col; expected db, user, host, state or command"
      ***                   66                        
                           100                        
      ***                   66                        
63                                                          unless $col eq 'db' || $col eq 'user' || $col eq 'host' 
64                                                              || $col eq 'state' || $col eq 'command';
65    ***      4     50                          13      die "No value parameter" unless $val;
66    ***      4     50                          16      die "No aggregate; expected count or time" unless $agg;
67    ***      4     50     66                   29      die "Invalid aggregate: $agg; expected count or time"
68                                                          unless $agg eq 'count' || $agg eq 'time';
69    ***      4     50                          16      die "No comparison parameter; expected >, < or =" unless $cmp;
70    ***      4     50     66                   46      die "Invalid comparison: $cmp; expected >, < or ="
      ***                   66                        
71                                                          unless $cmp eq '<' || $cmp eq '>' || $cmp eq '=';
72    ***      4     50                          16      die "No threshold value (N)" unless defined $thresh;
73                                                    
74                                                       # User probably doesn't care that = and == mean different things
75                                                       # in a programming language; just do what they expect.
76             4    100                          16      $cmp = '==' if $cmp eq '=';
77                                                    
78             4                                 72      my @lines = (
79                                                          'sub {',
80                                                          '   my ( $self, %args ) = @_;',
81                                                          '   my $proc = $self->{callbacks}->{show_processlist}->($self->{dbh});',
82                                                          '   if ( !$proc ) {',
83                                                          "      \$self->_save_last_check('processlist was empty');",
84                                                          '      return 0;',
85                                                          '   }',
86                                                          '   my $apl  = $self->{ProcesslistAggregator}->aggregate($proc);',
87                                                          "   my \$val = \$apl->{$col}->{'$val'}->{$agg} || 0;",
88                                                          "   MKDEBUG && _d('Current $col $val $agg =', \$val);",
89                                                          "   \$self->_save_last_check(\$val, '$cmp', '$thresh');",
90                                                          "   return \$val $cmp $thresh ? 1 : 0;",
91                                                          '}',
92                                                       );
93                                                    
94                                                       # Make the subroutine.
95             4                                 27      my $code = join("\n", @lines);
96             4                                 10      MKDEBUG && _d('OK sub:', @lines);
97    ***      4     50                         590      my $check_sub = eval $code
98                                                          or die "Error compiling subroutine code:\n$code\n$EVAL_ERROR";
99                                                    
100                                                      # We need a ProcesslistAggregator obj.  For this to work the
101                                                      # ProcesslistAggregator module needs to be in the same file as this
102                                                      # module.  Since this module is created generically, caller (mk-loadavg)
103                                                      # doesn't know what extra args/modules we need, so we create them ourself.
104            4                                 11      my %args;
105            4                                 13      my $pla;
106            4                                 10      eval {
107            4                                  8         $pla = new ProcesslistAggregator();
108                                                      };
109            4                                 12      MKDEBUG && $EVAL_ERROR && _d('Cannot create a ProcesslistAggregator object:',
110                                                         $EVAL_ERROR);
111            4                                 15      $args{ProcesslistAggregator} = $pla;
112                                                   
113            4                                 33      return $check_sub, %args;
114                                                   }
115                                                   
116                                                   sub uses_dbh {
117   ***      0                    0      0      0      return 1;
118                                                   }
119                                                   
120                                                   sub set_dbh {
121   ***      0                    0      0      0      my ( $self, $dbh ) = @_;
122   ***      0                                  0      $self->{dbh} = $dbh;
123                                                   }
124                                                   
125                                                   sub set_callbacks {
126   ***      3                    3      0     15      my ( $self, %callbacks ) = @_;
127            3                                 13      foreach my $func ( keys %callbacks ) {
128   ***      3     50                          20         die "Callback $func does not exist"
129                                                            unless exists $self->{callbacks}->{$func};
130            3                                 13         $self->{callbacks}->{$func} = $callbacks{$func};
131            3                                 10         MKDEBUG && _d('Set new callback for', $func);
132                                                      }
133            3                                 12      return;
134                                                   }
135                                                   
136                                                   sub check {
137   ***      4                    4      0     16      my ( $self, %args ) = @_;
138            4                                 22      return $self->{check_sub}->(@_);
139                                                   }
140                                                   
141                                                   sub _show_processlist {
142            1                    1             4      my ( $dbh, %args ) = @_;
143            1                                 27      return $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} } );
144                                                   }
145                                                   
146                                                   sub _save_last_check {
147            4                    4            21      my ( $self, @args ) = @_;
148            4                                 20      $self->{last_check} = [ @args ];
149            4                                 15      return;
150                                                   }
151                                                   
152                                                   sub get_last_check {
153   ***      1                    1      0      4      my ( $self ) = @_;
154            1                                  3      return @{ $self->{last_check} };
               1                                 15   
155                                                   }
156                                                   
157                                                   sub _d {
158            1                    1             7      my ($package, undef, $line) = caller 0;
159   ***      2     50                          11      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 10   
160            1                                  6           map { defined $_ ? $_ : 'undef' }
161                                                           @_;
162            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
163                                                   }
164                                                   
165                                                   1;
166                                                   
167                                                   # ###########################################################################
168                                                   # End WatchProcesslist package
169                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
32    ***     50      0      4   unless $args{$arg}
40    ***     50      0      4   if $EVAL_ERROR
60    ***     50      0      4   unless $col
62    ***     50      0      4   unless $col eq 'db' or $col eq 'user' or $col eq 'host' or $col eq 'state' or $col eq 'command'
65    ***     50      0      4   unless $val
66    ***     50      0      4   unless $agg
67    ***     50      0      4   unless $agg eq 'count' or $agg eq 'time'
69    ***     50      0      4   unless $cmp
70    ***     50      0      4   unless $cmp eq '<' or $cmp eq '>' or $cmp eq '='
72    ***     50      0      4   unless defined $thresh
76           100      2      2   if $cmp eq '='
97    ***     50      0      4   unless my $check_sub = eval $code
128   ***     50      0      3   unless exists $$self{'callbacks'}{$func}
159   ***     50      2      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
62    ***     66      1      0      3   $col eq 'db' or $col eq 'user'
      ***     66      1      0      3   $col eq 'db' or $col eq 'user' or $col eq 'host'
             100      1      2      1   $col eq 'db' or $col eq 'user' or $col eq 'host' or $col eq 'state'
      ***     66      3      1      0   $col eq 'db' or $col eq 'user' or $col eq 'host' or $col eq 'state' or $col eq 'command'
67    ***     66      3      1      0   $agg eq 'count' or $agg eq 'time'
70    ***     66      2      0      2   $cmp eq '<' or $cmp eq '>'
      ***     66      2      2      0   $cmp eq '<' or $cmp eq '>' or $cmp eq '='


Covered Subroutines
-------------------

Subroutine        Count Pod Location                                               
----------------- ----- --- -------------------------------------------------------
BEGIN                 1     /home/daniel/dev/maatkit/common/WatchProcesslist.pm:22 
BEGIN                 1     /home/daniel/dev/maatkit/common/WatchProcesslist.pm:23 
BEGIN                 1     /home/daniel/dev/maatkit/common/WatchProcesslist.pm:25 
BEGIN                 1     /home/daniel/dev/maatkit/common/WatchProcesslist.pm:27 
_d                    1     /home/daniel/dev/maatkit/common/WatchProcesslist.pm:158
_save_last_check      4     /home/daniel/dev/maatkit/common/WatchProcesslist.pm:147
_show_processlist     1     /home/daniel/dev/maatkit/common/WatchProcesslist.pm:142
check                 4   0 /home/daniel/dev/maatkit/common/WatchProcesslist.pm:137
get_last_check        1   0 /home/daniel/dev/maatkit/common/WatchProcesslist.pm:153
new                   4   0 /home/daniel/dev/maatkit/common/WatchProcesslist.pm:30 
parse_params          4   0 /home/daniel/dev/maatkit/common/WatchProcesslist.pm:54 
set_callbacks         3   0 /home/daniel/dev/maatkit/common/WatchProcesslist.pm:126

Uncovered Subroutines
---------------------

Subroutine        Count Pod Location                                               
----------------- ----- --- -------------------------------------------------------
set_dbh               0   0 /home/daniel/dev/maatkit/common/WatchProcesslist.pm:121
uses_dbh              0   0 /home/daniel/dev/maatkit/common/WatchProcesslist.pm:117


WatchProcesslist.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            11   use Test::More tests => 6;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use WatchProcesslist;
               1                                  3   
               1                                 10   
15             1                    1            11   use DSNParser;
               1                                  3   
               1                                 10   
16             1                    1            15   use Sandbox;
               1                                  3   
               1                                 10   
17             1                    1            11   use ProcesslistAggregator;
               1                                  3   
               1                                 10   
18             1                    1            10   use TextResultSetParser;
               1                                  3   
               1                                 10   
19             1                    1            10   use MaatkitTest;
               1                                  5   
               1                                 35   
20                                                    
21             1                                 12   my $pla = new ProcesslistAggregator();
22             1                                 33   my $r   = new TextResultSetParser();
23             1                                 31   my $dp  = new DSNParser(opts=>$dsn_opts);
24             1                                232   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
25             1                                 53   my $dbh = $sb->get_dbh_for('master');
26                                                    
27             1                                381   my $proc;
28             3                    3            11   sub show_processlist { return $proc };
29                                                    
30             1                                  8   $proc = $r->parse( load_file('common/t/samples/pl/recset004.txt') );
31                                                    
32             1                              10253   my $w = new WatchProcesslist(
33                                                       params => 'state:Locked:count:<:1000',
34                                                       dbh    => 1,
35                                                       ProcesslistAggregator => $pla,
36                                                    );
37             1                                  7   $w->set_callbacks( show_processlist => \&show_processlist );
38                                                    
39             1                                 38   is(
40                                                       $w->check(),
41                                                       1,
42                                                       'Processlist locked count ok'
43                                                    );
44                                                    
45             1                                  8   $w = new WatchProcesslist(
46                                                       params => 'state:Locked:count:<:10',
47                                                       dbh    => 1,
48                                                       ProcesslistAggregator => $pla,
49                                                    );
50             1                                 28   $w->set_callbacks( show_processlist => \&show_processlist );
51                                                    
52             1                                  6   is(
53                                                       $w->check(),
54                                                       0,
55                                                       'Processlist locked count not ok'
56                                                    );
57                                                       
58             1                                  8   $w = new WatchProcesslist(
59                                                       params => 'db:forest:time:=:533',
60                                                       dbh    => 1,
61                                                       ProcesslistAggregator => $pla,
62                                                    );
63             1                                 27   $w->set_callbacks( show_processlist => \&show_processlist );
64                                                    
65             1                                  4   is(
66                                                       $w->check(),
67                                                       1,
68                                                       'Processlist db time ok'
69                                                    );
70                                                    
71             1                                  7   is_deeply(
72                                                       [ $w->get_last_check() ],
73                                                       [ '533', '==', '533' ],
74                                                       'get_last_check()'
75                                                    );
76                                                    
77                                                    # ###########################################################################
78                                                    # Online tests.
79                                                    # ###########################################################################
80    ***      1     50                           5   SKIP: {
81             1                                  8      skip 'Cannot connect to sandbox master', 1 unless $dbh;
82                                                    
83             1                                  6      $w = new WatchProcesslist(
84                                                          params => 'command:Binlog Dump:count:=:1',
85                                                          dbh    => $dbh,
86                                                          ProcesslistAggregator => $pla,
87                                                       );
88                                                    
89             1                                 27      is(
90                                                          $w->check(),
91                                                          1,
92                                                          'Processlist count Binlog Dump count ok'
93                                                       );
94                                                    };
95                                                    
96                                                    # #############################################################################
97                                                    # Done.
98                                                    # #############################################################################
99             1                                  4   my $output = '';
100                                                   {
101            1                                  3      local *STDERR;
               1                                  6   
102            1                    1             2      open STDERR, '>', \$output;
               1                                297   
               1                                  5   
               1                                  6   
103            1                                 17      $w->_d('Complete test coverage');
104                                                   }
105                                                   like(
106            1                                 23      $output,
107                                                      qr/Complete test coverage/,
108                                                      '_d() works'
109                                                   );
110   ***      1     50                          16   $sb->wipe_clean($dbh) if $dbh;
111            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
80    ***     50      0      1   unless $dbh
110   ***     50      1      0   if $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine       Count Location              
---------------- ----- ----------------------
BEGIN                1 WatchProcesslist.t:10 
BEGIN                1 WatchProcesslist.t:102
BEGIN                1 WatchProcesslist.t:11 
BEGIN                1 WatchProcesslist.t:12 
BEGIN                1 WatchProcesslist.t:14 
BEGIN                1 WatchProcesslist.t:15 
BEGIN                1 WatchProcesslist.t:16 
BEGIN                1 WatchProcesslist.t:17 
BEGIN                1 WatchProcesslist.t:18 
BEGIN                1 WatchProcesslist.t:19 
BEGIN                1 WatchProcesslist.t:4  
BEGIN                1 WatchProcesslist.t:9  
show_processlist     3 WatchProcesslist.t:28 


