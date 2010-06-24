---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/WatchStatus.pm   82.2   50.0   54.2   85.0    0.0   86.4   69.4
WatchStatus.t                 100.0   50.0   33.3  100.0    n/a   13.6   95.3
Total                          89.6   50.0   51.9   91.2    0.0  100.0   78.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:38:58 2010
Finish:       Thu Jun 24 19:38:58 2010

Run:          WatchStatus.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:39:00 2010
Finish:       Thu Jun 24 19:39:00 2010

/home/daniel/dev/maatkit/common/WatchStatus.pm

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
18                                                    # WatchStatus package $Revision: 5401 $
19                                                    # ###########################################################################
20                                                    package WatchStatus;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24                                                    
25             1                    1             5   use English qw(-no_match_vars);
               1                                  6   
               1                                  8   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 19   
28                                                    
29                                                    sub new {
30    ***      7                    7      0     54      my ( $class, %args ) = @_;
31             7                                 30      foreach my $arg ( qw(params) ) {
32    ***      7     50                          43         die "I need a $arg argument" unless $args{$arg};
33                                                       }
34                                                    
35             7                                 17      my $check_sub;
36             7                                 18      my %extra_args;
37             7                                 19      eval {
38             7                                 35         ($check_sub, %extra_args) = parse_params($args{params});
39                                                       };
40    ***      7     50                          31      die "Error parsing parameters $args{params}: $EVAL_ERROR" if $EVAL_ERROR;
41                                                    
42             7                                 78      my $self = {
43                                                          %extra_args,
44                                                          %args,
45                                                          check_sub => $check_sub,
46                                                          callbacks => {
47                                                             show_status        => \&_show_status,
48                                                             show_innodb_status => \&_show_innodb_status,
49                                                             show_slave_status  => \&_show_slave_status,
50                                                          },
51                                                       };
52             7                                 55      return bless $self, $class;
53                                                    }
54                                                    
55                                                    sub parse_params {
56    ***      8                    8      0     32      my ( $params ) = @_;
57             8                                 50      my ( $stats, $var, $cmp, $thresh ) = split(':', $params);
58             8                                 28      $stats = lc $stats;
59             8                                 62      MKDEBUG && _d('Parsed', $params, 'as', $stats, $var, $cmp, $thresh);
60    ***      8     50                          30      die "No stats parameter; expected status, innodb or slave" unless $stats;
61    ***      8     50    100                   84      die "Invalid stats: $stats; expected status, innodb or slave"
      ***                   66                        
62                                                          unless $stats eq 'status' || $stats eq 'innodb' || $stats eq 'slave';
63    ***      8     50                          26      die "No var parameter" unless $var;
64    ***      8     50                          30      die "No comparison parameter; expected >, < or =" unless $cmp;
65    ***      8     50    100                   83      die "Invalid comparison: $cmp; expected >, < or ="
      ***                   66                        
66                                                          unless $cmp eq '<' || $cmp eq '>' || $cmp eq '=';
67    ***      8     50                          30      die "No threshold value (N)" unless defined $thresh;
68                                                    
69                                                       # User probably doesn't care that = and == mean different things
70                                                       # in a programming language; just do what they expect.
71             8    100                          35      $cmp = '==' if $cmp eq '=';
72                                                    
73             8                                109      my @lines = (
74                                                          'sub {',
75                                                          '   my ( $self, %args ) = @_;',
76                                                          "   my \$val = \$self->_get_val_from_$stats('$var', %args);",
77                                                          "   MKDEBUG && _d('Current $stats:$var =', \$val);",
78                                                          "   \$self->_save_last_check(\$val, '$cmp', '$thresh');",
79                                                          "   return \$val $cmp $thresh ? 1 : 0;",
80                                                          '}',
81                                                       );
82                                                    
83                                                       # Make the subroutine.
84             8                                 45      my $code = join("\n", @lines);
85             8                                 21      MKDEBUG && _d('OK sub:', @lines);
86    ***      8     50                         802      my $check_sub = eval $code
87                                                          or die "Error compiling subroutine code:\n$code\n$EVAL_ERROR";
88                                                    
89                                                       # If getting InnoDB stats, we will need an InnoDBStatusParser obj.
90                                                       # For this to work the InnoDBStatusParser module needs to be in the
91                                                       # same file as this module.  Since this module is created generically,
92                                                       # caller (mk-loadavg) doesn't know what extra args/modules we need,
93                                                       # so we create them ourself.
94             8                                 24      my %args;
95             8                                 20      my $innodb_status_parser;
96             8    100                          33      if ( $stats eq 'innodb' ) {
97             3                                  9         eval {
98             3                                  6            $innodb_status_parser = new InnoDBStatusParser();
99                                                          };
100            3                                  9         MKDEBUG && $EVAL_ERROR && _d('Cannot create an InnoDBStatusParser object:', $EVAL_ERROR);
101            3                                 12         $args{InnoDBStatusParser} = $innodb_status_parser;
102                                                      }
103                                                   
104            8                                 65      return $check_sub, %args;
105                                                   }
106                                                   
107                                                   sub uses_dbh {
108   ***      0                    0      0      0      return 1;
109                                                   }
110                                                   
111                                                   sub set_dbh {
112   ***      0                    0      0      0      my ( $self, $dbh ) = @_;
113   ***      0                                  0      $self->{dbh} = $dbh;
114                                                   }
115                                                   
116                                                   sub set_callbacks {
117   ***      4                    4      0     21      my ( $self, %callbacks ) = @_;
118            4                                 19      foreach my $func ( keys %callbacks ) {
119   ***      4     50                          23         die "Callback $func does not exist"
120                                                            unless exists $self->{callbacks}->{$func};
121            4                                 17         $self->{callbacks}->{$func} = $callbacks{$func};
122            4                                 15         MKDEBUG && _d('Set new callback for', $func);
123                                                      }
124            4                                 13      return;
125                                                   }
126                                                   
127                                                   sub check {
128   ***      9                    9      0     37      my ( $self, %args ) = @_;
129            9                                 45      return $self->{check_sub}->(@_);
130                                                   }
131                                                   
132                                                   # Returns all of SHOW STATUS or just the status for var if given.
133                                                   sub _show_status {
134            1                    1             4      my ( $dbh, $var, %args ) = @_;
135   ***      1     50                           5      if ( $var ) {
136            1                                  3         my (undef, $val)
137                                                            = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$var'");
138            1                                542         return $val;
139                                                      }
140                                                      else {
141   ***      0                                  0         return $dbh->selectall_hashref("SHOW /*!50002 GLOBAL*/ STATUS", 'Variable_name');
142                                                      }
143                                                   }
144                                                   
145                                                   # Returns the value for var from SHOW STATUS.
146                                                   sub _get_val_from_status {
147            3                    3            14      my ( $self, $var, %args ) = @_;
148   ***      3     50                          13      die "I need a var argument" unless $var;
149            3                                 21      return $self->{callbacks}->{show_status}->($self->{dbh}, $var, %args);
150                                                   
151                                                   #   if ( $args{incstatus} ) {
152                                                   #      sleep(1);
153                                                   #      my (undef, $status2)
154                                                   #         = $dbh->selectrow_array("SHOW /*!50002 GLOBAL*/ STATUS LIKE '$args{metric}'");
155                                                   #      return $status2 - $status1;
156                                                   #   }
157                                                   #   else {
158                                                   #      return $status1;
159                                                   #   }
160                                                   
161                                                   }
162                                                   
163                                                   sub _show_innodb_status {
164            1                    1             5      my ( $dbh, %args ) = @_;
165                                                      # TODO: http://code.google.com/p/maatkit/issues/detail?id=789
166            1                                  3      my @text = $dbh->selectrow_array("SHOW INNODB STATUS");
167   ***      1            33                  478      return $text[2] || $text[0];
168                                                   }
169                                                   
170                                                   # Returns the highest value for var from SHOW INNODB STATUS.
171                                                   sub _get_val_from_innodb {
172            3                    3            16      my ( $self, $var, %args ) = @_;
173   ***      3     50                          14      die "I need a var argument" unless $var;
174            3                                 11      my $is = $self->{InnoDBStatusParser};
175   ***      3     50                          13      die "No InnoDBStatusParser object" unless $is;
176                                                   
177            3                                 24      my $status_text = $self->{callbacks}->{show_innodb_status}->($self->{dbh}, %args);
178            3                                 23      my $idb_stats   = $is->parse($status_text);
179                                                   
180            3                               7449      my $val = 0;
181                                                      SECTION:
182            3                                 21      foreach my $section ( keys %$idb_stats ) {
183            9    100                          53         next SECTION unless exists $idb_stats->{$section}->[0]->{$var};
184            3                                  7         MKDEBUG && _d('Found', $var, 'in section', $section);
185                                                   
186                                                         # Each section should be an arrayref.  Go through each set of vars
187                                                         # and find the highest var that we're checking.
188            3                                  9         foreach my $vars ( @{$idb_stats->{$section}} ) {
               3                                 12   
189            3                                  7            MKDEBUG && _d($var, '=', $vars->{$var});
190   ***      3     50     33                   43            $val = $vars->{$var} && $vars->{$var} > $val ? $vars->{$var} : $val;
191                                                         }
192            3                                  8         MKDEBUG && _d('Highest', $var, '=', $val);
193            3                                 10         last SECTION;
194                                                      }
195            3                                 98      return $val;
196                                                   }
197                                                   
198                                                   sub _show_slave_status {
199            1                    1             4      my ( $dbh, $var, %args ) = @_;
200            1                                  3      return $dbh->selectrow_hashref("SHOW SLAVE STATUS")->{$var};
201                                                   }
202                                                   
203                                                   # Returns the value for var from SHOW SLAVE STATUS.
204                                                   sub _get_val_from_slave {
205            3                    3            12      my ( $self, $var, %args ) = @_;
206   ***      3     50                          14      die "I need a var argument" unless $var;
207            3                                 20      return $self->{callbacks}->{show_slave_status}->($self->{dbh}, $var, %args);
208                                                   }
209                                                   
210                                                   # Calculates average query time by the Trevor Price method.
211                                                   sub trevorprice {
212   ***      0                    0      0      0      my ( $self, $dbh, %args ) = @_;
213   ***      0      0                           0      die "I need a dbh argument" unless $dbh;
214   ***      0             0                    0      my $num_samples = $args{samples} || 100;
215   ***      0                                  0      my $num_running = 0;
216   ***      0                                  0      my $start = time();
217   ***      0                                  0      my (undef, $status1)
218                                                         = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
219   ***      0                                  0      for ( 1 .. $num_samples ) {
220   ***      0                                  0         my $pl = $dbh->selectall_arrayref('SHOW PROCESSLIST', { Slice => {} });
221   ***      0             0                    0         my $running = grep { ($_->{Command} || '') eq 'Query' } @$pl;
      ***      0                                  0   
222   ***      0                                  0         $num_running += $running - 1;
223                                                      }
224   ***      0                                  0      my $time = time() - $start;
225   ***      0      0                           0      return 0 unless $time;
226   ***      0                                  0      my (undef, $status2)
227                                                         = $dbh->selectrow_array('SHOW /*!50002 GLOBAL*/ STATUS LIKE "Questions"');
228   ***      0                                  0      my $qps = ($status2 - $status1) / $time;
229   ***      0      0                           0      return 0 unless $qps;
230   ***      0                                  0      return ($num_running / $num_samples) / $qps;
231                                                   }
232                                                   
233                                                   sub _save_last_check {
234            9                    9            46      my ( $self, @args ) = @_;
235            9                                 46      $self->{last_check} = [ @args ];
236            9                                 34      return;
237                                                   }
238                                                   
239                                                   sub get_last_check {
240   ***      1                    1      0      4      my ( $self ) = @_;
241            1                                  3      return @{ $self->{last_check} };
               1                                 16   
242                                                   }
243                                                   
244                                                   sub _d {
245            1                    1             8      my ($package, undef, $line) = caller 0;
246   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  9   
               2                                 11   
247            1                                  4           map { defined $_ ? $_ : 'undef' }
248                                                           @_;
249            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
250                                                   }
251                                                   
252                                                   1;
253                                                   
254                                                   # ###########################################################################
255                                                   # End WatchStatus package
256                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
32    ***     50      0      7   unless $args{$arg}
40    ***     50      0      7   if $EVAL_ERROR
60    ***     50      0      8   unless $stats
61    ***     50      0      8   unless $stats eq 'status' or $stats eq 'innodb' or $stats eq 'slave'
63    ***     50      0      8   unless $var
64    ***     50      0      8   unless $cmp
65    ***     50      0      8   unless $cmp eq '<' or $cmp eq '>' or $cmp eq '='
67    ***     50      0      8   unless defined $thresh
71           100      1      7   if $cmp eq '='
86    ***     50      0      8   unless my $check_sub = eval $code
96           100      3      5   if ($stats eq 'innodb')
119   ***     50      0      4   unless exists $$self{'callbacks'}{$func}
135   ***     50      1      0   if ($var) { }
148   ***     50      0      3   unless $var
173   ***     50      0      3   unless $var
175   ***     50      0      3   unless $is
183          100      6      3   unless exists $$idb_stats{$section}[0]{$var}
190   ***     50      3      0   $$vars{$var} && $$vars{$var} > $val ? :
206   ***     50      0      3   unless $var
213   ***      0      0      0   unless $dbh
225   ***      0      0      0   unless $time
229   ***      0      0      0   unless $qps
246   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
190   ***     33      0      0      3   $$vars{$var} && $$vars{$var} > $val

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0
214   ***      0      0      0   $args{'samples'} || 100
221   ***      0      0      0   $$_{'Command'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
61           100      3      3      2   $stats eq 'status' or $stats eq 'innodb'
      ***     66      6      2      0   $stats eq 'status' or $stats eq 'innodb' or $stats eq 'slave'
65           100      1      6      1   $cmp eq '<' or $cmp eq '>'
      ***     66      7      1      0   $cmp eq '<' or $cmp eq '>' or $cmp eq '='
167   ***     33      1      0      0   $text[2] || $text[0]


Covered Subroutines
-------------------

Subroutine           Count Pod Location                                          
-------------------- ----- --- --------------------------------------------------
BEGIN                    1     /home/daniel/dev/maatkit/common/WatchStatus.pm:22 
BEGIN                    1     /home/daniel/dev/maatkit/common/WatchStatus.pm:23 
BEGIN                    1     /home/daniel/dev/maatkit/common/WatchStatus.pm:25 
BEGIN                    1     /home/daniel/dev/maatkit/common/WatchStatus.pm:27 
_d                       1     /home/daniel/dev/maatkit/common/WatchStatus.pm:245
_get_val_from_innodb     3     /home/daniel/dev/maatkit/common/WatchStatus.pm:172
_get_val_from_slave      3     /home/daniel/dev/maatkit/common/WatchStatus.pm:205
_get_val_from_status     3     /home/daniel/dev/maatkit/common/WatchStatus.pm:147
_save_last_check         9     /home/daniel/dev/maatkit/common/WatchStatus.pm:234
_show_innodb_status      1     /home/daniel/dev/maatkit/common/WatchStatus.pm:164
_show_slave_status       1     /home/daniel/dev/maatkit/common/WatchStatus.pm:199
_show_status             1     /home/daniel/dev/maatkit/common/WatchStatus.pm:134
check                    9   0 /home/daniel/dev/maatkit/common/WatchStatus.pm:128
get_last_check           1   0 /home/daniel/dev/maatkit/common/WatchStatus.pm:240
new                      7   0 /home/daniel/dev/maatkit/common/WatchStatus.pm:30 
parse_params             8   0 /home/daniel/dev/maatkit/common/WatchStatus.pm:56 
set_callbacks            4   0 /home/daniel/dev/maatkit/common/WatchStatus.pm:117

Uncovered Subroutines
---------------------

Subroutine           Count Pod Location                                          
-------------------- ----- --- --------------------------------------------------
set_dbh                  0   0 /home/daniel/dev/maatkit/common/WatchStatus.pm:112
trevorprice              0   0 /home/daniel/dev/maatkit/common/WatchStatus.pm:212
uses_dbh                 0   0 /home/daniel/dev/maatkit/common/WatchStatus.pm:108


WatchStatus.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            39      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            11   use Test::More tests => 12;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use WatchStatus;
               1                                  3   
               1                                 10   
15             1                    1            10   use DSNParser;
               1                                  3   
               1                                 11   
16             1                    1            14   use Sandbox;
               1                                  3   
               1                                 10   
17             1                    1            12   use InnoDBStatusParser;
               1                                  4   
               1                                 41   
18             1                    1            15   use MaatkitTest;
               1                                  5   
               1                                 38   
19                                                    
20             1                                 12   my $is  = new InnoDBStatusParser();
21             1                                 27   my $dp  = new DSNParser(opts=>$dsn_opts);
22             1                                246   my $sb  = new Sandbox(basedir => '/tmp', DSNParser => $dp);
23             1                                 51   my $dbh = $sb->get_dbh_for('slave1');
24                                                    
25             1                                374   my $status;
26                                                    
27                                                    sub show_status {
28             2                    2             9      my ( $dbh, $var, %args ) = @_;
29             2                                 13      return $status->{$var}->{Value};
30                                                    }
31                                                    sub show_innodb_status {
32             2                    2             9      my ( $dbh, $var, %args ) = @_;
33             2                                 16      return $status;
34                                                    }
35                                                    sub show_slave_status {
36             2                    2             9      my ( $dbh, $var, %args ) = @_;
37             2                                 12      return $status->{$var};
38                                                    }
39                                                    
40                                                    # ###########################################################################
41                                                    # Test watching SHOW STATUS.
42                                                    # ###########################################################################
43             1                                 13   my $w = new WatchStatus(
44                                                       params => 'status:Uptime:>:10',
45                                                       dbh    => 1,
46                                                    );
47             1                                  8   $w->set_callbacks( show_status => \&show_status );
48                                                    
49             1                                  6   $status = {
50                                                      Uptime => {
51                                                        Value => '9693',
52                                                        Variable_name => 'Uptime'
53                                                      },
54                                                    };
55                                                    
56             1                                  6   is(
57                                                       $w->check(),
58                                                       1,
59                                                       'Uptime ok'
60                                                    );
61                                                    
62             1                                 12   $status = {
63                                                      Uptime => {
64                                                        Value => '5',
65                                                        Variable_name => 'Uptime'
66                                                      },
67                                                    };
68                                                    
69             1                                  7   is(
70                                                       $w->check(),
71                                                       0,
72                                                       'Uptime not ok'
73                                                    );
74                                                    
75                                                    # ###########################################################################
76                                                    # Test watching SHOW INNODB STATUS.
77                                                    # ###########################################################################
78             1                                 26   $w = new WatchStatus(
79                                                       params => 'innodb:Innodb_buffer_pool_pages_free:>:10',
80                                                       dbh    => 1,
81                                                       InnoDBStatusParser => $is,
82                                                    );
83             1                                 38   $w->set_callbacks( show_innodb_status => \&show_innodb_status );
84                                                    
85             1                                  9   $status = load_file('common/t/samples/is001.txt');
86                                                    
87             1                                 14   is(
88                                                       $w->check(),
89                                                       1,
90                                                       'InnoDB status ok'
91                                                    );
92                                                    
93             1                                 11   $w = new WatchStatus(
94                                                       params => 'innodb:Innodb_buffer_pool_pages_free:>:500',
95                                                       dbh    => 1,
96                                                       InnoDBStatusParser => $is,
97                                                    );
98             1                                 19   $w->set_callbacks( show_innodb_status => \&show_innodb_status );
99                                                    
100            1                                  5   is(
101                                                      $w->check(),
102                                                      0,
103                                                      'InnoDB status not ok'
104                                                   );
105                                                   
106                                                   # ###########################################################################
107                                                   # Test watching SHOW INNODB STATUS.
108                                                   # ###########################################################################
109            1                                  7   $w = new WatchStatus(
110                                                      params => 'slave:Seconds_Behind_Master:<:60',
111                                                      dbh    => 1,
112                                                   );
113            1                                 21   $w->set_callbacks( show_slave_status => \&show_slave_status );
114                                                   
115            1                                  6   $status = {
116                                                     Seconds_Behind_Master => '50',
117                                                   };
118                                                   
119            1                                  5   is(
120                                                      $w->check(),
121                                                      1,
122                                                      'Slave status ok'
123                                                   );
124                                                   
125            1                                  6   $status = {
126                                                     Seconds_Behind_Master => '61',
127                                                   };
128                                                   
129            1                                  6   is(
130                                                      $w->check(),
131                                                      0,
132                                                      'Slave status not ok'
133                                                   );
134                                                   
135            1                                  6   is_deeply(
136                                                      [ $w->get_last_check() ],
137                                                      [ '61', '<', '60' ],
138                                                      'get_last_check()'
139                                                   );
140                                                   
141                                                   # ###########################################################################
142                                                   # Online tests.
143                                                   # ###########################################################################
144   ***      1     50                           4   SKIP: {
145            1                                  9      skip 'Cannot connect to sandbox slave', 3 unless $dbh;
146                                                   
147            1                                  6      $w = new WatchStatus(
148                                                         params => 'status:Uptime:>:5',
149                                                         dbh    => $dbh,
150                                                      );
151            1                                 19      is(
152                                                         $w->check(),
153                                                         1,
154                                                         'Status ok (online)'
155                                                      );
156                                                   
157            1                                  8      $w = new WatchStatus(
158                                                         params => 'InnoDB:Innodb_buffer_pool_pages_total:>:1',
159                                                         dbh    => $dbh,
160                                                         InnoDBStatusParser => $is,
161                                                      );
162            1                                 19      is(
163                                                         $w->check(),
164                                                         1,
165                                                         'InnoDB status ok (online)'
166                                                      );
167                                                   
168            1                                  7      $w = new WatchStatus(
169                                                         params => 'slave:Last_Errno:=:0',
170                                                         dbh    => $dbh,
171                                                      );
172            1                                 20      is(
173                                                         $w->check(),
174                                                         1,
175                                                         'Slave status ok (online)'
176                                                      );
177                                                   };
178                                                   
179                                                   # ###########################################################################
180                                                   # Test parsing params.
181                                                   # ###########################################################################
182            1                                  4   my $param = 'status:Threads_connected:>:16';
183            1                                  3   eval{
184            1                                  5      WatchStatus::parse_params($param);
185                                                   };
186            1                                  7   is(
187                                                      $EVAL_ERROR,
188                                                      '',
189                                                      "Parses param: $param"
190                                                   );
191                                                   
192                                                   # #############################################################################
193                                                   # Done.
194                                                   # #############################################################################
195            1                                  4   my $output = '';
196                                                   {
197            1                                  3      local *STDERR;
               1                                  6   
198            1                    1             2      open STDERR, '>', \$output;
               1                                282   
               1                                  2   
               1                                  8   
199            1                                 18      $w->_d('Complete test coverage');
200                                                   }
201                                                   like(
202            1                                 23      $output,
203                                                      qr/Complete test coverage/,
204                                                      '_d() works'
205                                                   );
206   ***      1     50                          12   $sb->wipe_clean($dbh) if $dbh;
207            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
144   ***     50      0      1   unless $dbh
206   ***     50      1      0   if $dbh


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine         Count Location         
------------------ ----- -----------------
BEGIN                  1 WatchStatus.t:10 
BEGIN                  1 WatchStatus.t:11 
BEGIN                  1 WatchStatus.t:12 
BEGIN                  1 WatchStatus.t:14 
BEGIN                  1 WatchStatus.t:15 
BEGIN                  1 WatchStatus.t:16 
BEGIN                  1 WatchStatus.t:17 
BEGIN                  1 WatchStatus.t:18 
BEGIN                  1 WatchStatus.t:198
BEGIN                  1 WatchStatus.t:4  
BEGIN                  1 WatchStatus.t:9  
show_innodb_status     2 WatchStatus.t:32 
show_slave_status      2 WatchStatus.t:36 
show_status            2 WatchStatus.t:28 


