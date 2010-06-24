---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...ErrorLogPatternMatcher.pm   95.2   65.0   50.0  100.0    0.0   58.2   82.4
ErrorLogPatternMatcher.t      100.0   50.0   33.3  100.0    n/a   41.8   93.7
Total                          97.2   60.7   47.4  100.0    0.0  100.0   86.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:58 2010
Finish:       Thu Jun 24 19:32:58 2010

Run:          ErrorLogPatternMatcher.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:59 2010
Finish:       Thu Jun 24 19:32:59 2010

/home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm

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
18                                                    # ErrorLogPatternMatcher package $Revision: 6096 $
19                                                    # ###########################################################################
20                                                    package ErrorLogPatternMatcher;
21                                                    
22             1                    1            98   use strict;
               1                                  3   
               1                                  4   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  7   
26                                                    $Data::Dumper::Indent    = 1;
27                                                    $Data::Dumper::Sortkeys  = 1;
28                                                    $Data::Dumper::Quotekeys = 0;
29                                                    
30    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 12   
31                                                    
32                                                    sub new {
33    ***      3                    3      0     19      my ( $class, %args ) = @_;
34             3                                 27      my $self = {
35                                                          %args,
36                                                          patterns => [],
37                                                          compiled => [],
38                                                          level    => [],
39                                                          name     => [],
40                                                       };
41             3                                 24      return bless $self, $class;
42                                                    }
43                                                    
44                                                    sub add_patterns {
45    ***     30                   30      0    107      my ( $self, $patterns ) = @_;
46            30                                113      foreach my $p ( @$patterns ) {
47    ***     30     50     50                  261         next unless $p && scalar @$p;
48            30                                149         my ($name, $level, $regex) = @$p;
49            30                                 92         push @{$self->{names}},    $name;
              30                                125   
50            30                                 78         push @{$self->{levels}},   $level;
              30                                112   
51            30                                 78         push @{$self->{patterns}}, $regex;
              30                                114   
52            30                                 76         push @{$self->{compiled}}, qr/$regex/;
              30                                557   
53            30                                114         MKDEBUG && _d('Added new pattern:', $name, $level, $regex,
54                                                             $self->{compiled}->[-1]);
55                                                       }
56            30                                100      return;
57                                                    }
58                                                    
59                                                    sub load_patterns_file {
60    ***      1                    1      0      4      my ( $self, $fh ) = @_;
61             1                                  6      local $INPUT_RECORD_SEPARATOR = '';
62             1                                  3      my %seen;
63             1                                  2      my $pattern;
64             1                                265      while ( defined($pattern = <$fh>) ) {
65             2                                 28         my ($name, $level, $regex) = split("\n", $pattern);
66    ***      2     50     33                   53         if ( !($name && $level && $regex) ) {
      ***                   33                        
67    ***      0                                  0            warn "Pattern missing name, level or regex:\n$pattern";
68    ***      0                                  0            next;
69                                                          }
70    ***      2     50                          18         if ( $seen{$name}++ ) {
71    ***      0                                  0            warn "Duplicate pattern: $name";
72    ***      0                                  0            next;
73                                                          }
74             2                                 22         $self->add_patterns( [[$name, $level, $regex]] );
75                                                       }
76             1                                  6      return;
77                                                    }
78                                                    
79                                                    sub reset_patterns {
80    ***      1                    1      0      4      my ( $self ) = @_;
81             1                                  4      $self->{names}    = [];
82             1                                  5      $self->{levels}   = [];
83             1                                  4      $self->{patterns} = [];
84             1                                  4      $self->{compiled} = [];
85             1                                  8      MKDEBUG && _d('Reset patterns');
86             1                                  3      return;
87                                                    }
88                                                    
89                                                    sub patterns {
90    ***      3                    3      0     11      my ( $self ) = @_;
91             3                                  8      return @{$self->{patterns}};
               3                                 19   
92                                                    }
93                                                    
94                                                    sub names {
95    ***      2                    2      0      8      my ( $self ) = @_;
96             2                                  5      return @{$self->{names}};
               2                                 12   
97                                                    }
98                                                    
99                                                    sub levels {
100   ***      2                    2      0      8      my ( $self ) = @_;
101            2                                  6      return @{$self->{levels}};
               2                                 11   
102                                                   }
103                                                   
104                                                   sub match {
105   ***     42                   42      0    189      my ( $self, %args ) = @_;
106           42                                152      my @required_args = qw(event);
107           42                                532      foreach my $arg ( @required_args ) {
108   ***     42     50                         206         die "I need a $arg argument" unless $args{$arg};
109                                                      }
110           42                                142      my $event = @args{@required_args};
111           42                                137      my $err   = $event->{arg};
112   ***     42     50                         144      return unless $err;
113                                                   
114                                                      # If there's a query, let QueryRewriter fingerprint it.   
115           42    100    100                  264      if ( $self->{QueryRewriter}
116                                                           && (my ($query) = $err =~ m/Statement: (.+)$/) ) {
117            3                                 17         $query = $self->{QueryRewriter}->fingerprint($query);
118            3                                409         $err =~ s/Statement: .+$/Statement: $query/;
119                                                      }
120                                                   
121           42                                138      my $compiled = $self->{compiled};
122           42                                133      my $n        = (scalar @$compiled) - 1;
123           42                                 91      my $pno;
124                                                      PATTERN:
125           42                                151      for my $i ( 0..$n ) {
126          408    100                        2086         if ( $err =~ m/$compiled->[$i]/ ) {
127           14                                 36            $pno = $i;
128           14                                 38            last PATTERN;
129                                                         } 
130                                                      }
131                                                   
132           42    100                         151      if ( defined $pno ) {
133           14                                 30         MKDEBUG && _d($err, 'matches', $self->{patterns}->[$pno]);
134           14                                 54         $event->{New_pattern} = 'No';
135           14                                 43         $event->{Pattern_no}  = $pno;
136                                                   
137                                                         # Set Level if missing and we know it.
138   ***     14     50     33                   77         if ( !$event->{Level} && $self->{levels}->[$pno] ) {
139   ***      0                                  0            $event->{Level} = $self->{levels}->[$pno];
140                                                         }
141                                                      }
142                                                      else {
143           28                                 60         MKDEBUG && _d('New pattern');
144           28                                109         my $regex = $self->fingerprint($err);
145           28                                100         my $name  = substr($err, 0, 160);
146           28                                179         $self->add_patterns( [ [$name, $event->{Level}, $regex] ] );
147           28                                123         $event->{New_pattern} = 'Yes';
148           28                                 64         $event->{Pattern_no}  = (scalar @{$self->{patterns}}) - 1;
              28                                143   
149                                                      }
150                                                   
151           42                                206      $event->{Pattern} = $self->{patterns}->[ $event->{Pattern_no} ];
152                                                   
153           42                                316      return $event;
154                                                   }
155                                                   
156                                                   sub fingerprint {
157   ***     28                   28      0    121      my ( $self, $err ) = @_;
158                                                   
159                                                      # Escape special regex characters like ( and ) so they
160                                                      # are literal matches in the compiled pattern.
161           28                                303      $err =~ s/([\(\)\[\].+?*\{\}])/\\$1/g;
162                                                   
163                                                      # Abstract the error message.
164           28                                307      $err =~ s/\b\d+\b/\\d+/g;              # numbers
165           28                                 86      $err =~ s/\b0x[0-9a-zA-Z]+\b/0x\\S+/g; # hex values
166                                                   
167           28                                341      return $err;
168                                                   }
169                                                   
170                                                   sub _d {
171            1                    1             8      my ($package, undef, $line) = caller 0;
172   ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                  9   
173            1                                  5           map { defined $_ ? $_ : 'undef' }
174                                                           @_;
175            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
176                                                   }
177                                                   
178                                                   1;
179                                                   
180                                                   # ###########################################################################
181                                                   # End ErrorLogPatternMatcher package
182                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
47    ***     50      0     30   unless $p and scalar @$p
66    ***     50      0      2   if (not $name && $level && $regex)
70    ***     50      0      2   if ($seen{$name}++)
108   ***     50      0     42   unless $args{$arg}
112   ***     50      0     42   unless $err
115          100      3     39   if ($$self{'QueryRewriter'} and my($query) = $err =~ /Statement: (.+)$/)
126          100     14    394   if ($err =~ /$$compiled[$i]/)
132          100     14     28   if (defined $pno) { }
138   ***     50      0     14   if (not $$event{'Level'} and $$self{'levels'}[$pno])
172   ***     50      2      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
47    ***     50      0     30   $p and scalar @$p

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
66    ***     33      0      0      2   $name && $level
      ***     33      0      0      2   $name && $level && $regex
115          100     38      1      3   $$self{'QueryRewriter'} and my($query) = $err =~ /Statement: (.+)$/
138   ***     33     14      0      0   not $$event{'Level'} and $$self{'levels'}[$pno]

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
30    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine         Count Pod Location                                                     
------------------ ----- --- -------------------------------------------------------------
BEGIN                  1     /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:22 
BEGIN                  1     /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:23 
BEGIN                  1     /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:24 
BEGIN                  1     /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:25 
BEGIN                  1     /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:30 
_d                     1     /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:171
add_patterns          30   0 /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:45 
fingerprint           28   0 /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:157
levels                 2   0 /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:100
load_patterns_file     1   0 /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:60 
match                 42   0 /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:105
names                  2   0 /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:95 
new                    3   0 /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:33 
patterns               3   0 /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:90 
reset_patterns         1   0 /home/daniel/dev/maatkit/common/ErrorLogPatternMatcher.pm:80 


ErrorLogPatternMatcher.t

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
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 11;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            12   use QueryRewriter;
               1                                  3   
               1                                 11   
15             1                    1            14   use ErrorLogPatternMatcher;
               1                                  3   
               1                                 11   
16             1                    1            10   use ErrorLogParser;
               1                                  3   
               1                                 10   
17             1                    1            13   use MaatkitTest;
               1                                  3   
               1                                 37   
18                                                    
19             1                                  9   my $qr = new QueryRewriter();
20             1                                 30   my $p  = new ErrorLogParser();
21             1                                 32   my $m  = new ErrorLogPatternMatcher();
22                                                    
23             1                                  7   isa_ok($m, 'ErrorLogPatternMatcher');
24                                                    
25             1                                  6   my $output;
26                                                    
27                                                    sub parse {
28             2                    2             9      my ( $file ) = @_;
29             2                                 12      $file = "$trunk/$file";
30             2                                  6      my @e;
31             2                                  5      my @m;
32    ***      2     50                         106      open my $fh, "<", $file or die $OS_ERROR;
33             2                                 10      my %args = (
34                                                          fh      => $fh,
35                                                       );
36             2                                 18      while ( my $e = $p->parse_event(%args) ) {
37    ***     42     50                        6009         next unless $e;
38            42                                208         push @m, $m->match(
39                                                             event       => $e,
40                                                          );
41                                                       }
42             2                                125      close $fh;
43             2                                  7      return \@m;
44                                                    }
45                                                    
46             1                                  5   is_deeply(
47                                                       parse('common/t/samples/errlogs/errlog001.txt', $p),
48                                                       [
49                                                          {
50                                                            Level        => 'unknown',
51                                                            New_pattern  => 'Yes',
52                                                            Pattern_no   => 0,
53                                                            Pattern      => 'mysqld started',
54                                                            arg          => 'mysqld started',
55                                                            pos_in_log   => 0,
56                                                            ts           => '080721 03:03:57'
57                                                          },
58                                                          {
59                                                            New_pattern  => 'Yes',
60                                                            Level        => 'warning',
61                                                            Pattern_no   => 1,
62                                                            Pattern      => '\[Warning\] option \'log_slow_rate_limit\': unsigned value \d+ adjusted to \d+',
63                                                            arg          => '[Warning] option \'log_slow_rate_limit\': unsigned value 0 adjusted to 1',
64                                                            pos_in_log   => 32,
65                                                            ts           => '080721  3:04:00'
66                                                          },
67                                                          {
68                                                            New_pattern  => 'Yes',
69                                                            Pattern_no   => 2,
70                                                            Pattern      => '\[ERROR\] /usr/sbin/mysqld: unknown variable \'ssl-key=/opt/mysql\.pdns/\.cert/server-key\.pem\'',
71                                                            Level        => 'error',
72                                                            arg          => '[ERROR] /usr/sbin/mysqld: unknown variable \'ssl-key=/opt/mysql.pdns/.cert/server-key.pem\'',
73                                                            pos_in_log   => 119,
74                                                            ts           => '080721  3:04:01'
75                                                          },
76                                                          {
77                                                            New_pattern  => 'Yes',
78                                                            Level        => 'unknown',
79                                                            Pattern_no   => 3,
80                                                            Pattern      => 'mysqld ended',
81                                                            arg          => 'mysqld ended',
82                                                            pos_in_log   => 225,
83                                                            ts           => '080721 03:04:01'
84                                                          },
85                                                          {
86                                                            New_pattern  => 'No',
87                                                            Level        => 'unknown',
88                                                            Pattern_no   => 0,
89                                                            Pattern      => 'mysqld started',
90                                                            arg          => 'mysqld started',
91                                                            pos_in_log   => 255,
92                                                            ts           => '080721 03:10:57'
93                                                          },
94                                                          {
95                                                            New_pattern  => 'Yes',
96                                                            Level        => 'warning',
97                                                            Pattern_no   => 4,
98                                                            Pattern      => '\[Warning\] No argument was provided to --log-bin, and --log-bin-index was not used; so replication may break when this MySQL server acts as a master and has his hostname changed!! Please use \'--log-bin=/var/run/mysqld/mysqld-bin\' to avoid this problem\.',
99                                                            arg          => '[Warning] No argument was provided to --log-bin, and --log-bin-index was not used; so replication may break when this MySQL server acts as a master and has his hostname changed!! Please use \'--log-bin=/var/run/mysqld/mysqld-bin\' to avoid this problem.',
100                                                           pos_in_log   => 288,
101                                                           ts           => '080721  3:10:58'
102                                                         },
103                                                         {
104                                                           New_pattern  => 'Yes',
105                                                           Level        => 'unknown',
106                                                           Pattern_no   => 5,
107                                                           Pattern      => 'InnoDB: Started; log sequence number \d+ \d+',
108                                                           arg          => 'InnoDB: Started; log sequence number 1 3703096531',
109                                                           pos_in_log   => 556,
110                                                           ts           => '080721  3:11:08'
111                                                         },
112                                                         {
113                                                           New_pattern  => 'Yes',
114                                                           Level        => 'warning',
115                                                           Pattern_no   => 6,
116                                                           Pattern      => '\[Warning\] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a slave and has his hostname changed!! Please use \'--relay-log=/var/run/mysqld/mysqld-relay-bin\' to avoid this problem\.',
117                                                           arg          => '[Warning] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a slave and has his hostname changed!! Please use \'--relay-log=/var/run/mysqld/mysqld-relay-bin\' to avoid this problem.',
118                                                           pos_in_log   => 878,
119                                                           ts           => '080721  3:11:12'
120                                                         },
121                                                         {
122                                                           New_pattern  => 'Yes',
123                                                           Pattern_no   => 7,
124                                                           Pattern      => '\[ERROR\] Failed to open the relay log \'\./srv-relay-bin\.\d+\' \(relay_log_pos \d+\)',
125                                                           Level        => 'error',
126                                                           arg          => '[ERROR] Failed to open the relay log \'./srv-relay-bin.000001\' (relay_log_pos 4)',
127                                                           pos_in_log   => 878,
128                                                           ts           => '080721  3:11:12'
129                                                         },
130                                                         {
131                                                           New_pattern  => 'Yes',
132                                                           Pattern_no   => 8,
133                                                           Pattern      => '\[ERROR\] Could not find target log during relay log initialization',
134                                                           Level        => 'error',
135                                                           arg          => '[ERROR] Could not find target log during relay log initialization',
136                                                           pos_in_log   => 974,
137                                                           ts           => '080721  3:11:12'
138                                                         },
139                                                         {
140                                                           New_pattern  => 'Yes',
141                                                           Pattern_no   => 9,
142                                                           Pattern      => '\[ERROR\] Failed to initialize the master info structure',
143                                                           Level        => 'error',
144                                                           arg          => '[ERROR] Failed to initialize the master info structure',
145                                                           pos_in_log   => 1056,
146                                                           ts           => '080721  3:11:12'
147                                                         },
148                                                         {
149                                                           New_pattern  => 'Yes',
150                                                           Level        => 'info',
151                                                           Pattern_no   => 10,
152                                                           Pattern      => '\[Note\] /usr/libexec/mysqld: ready for connections\.',
153                                                           arg          => '[Note] /usr/libexec/mysqld: ready for connections.',
154                                                           pos_in_log   => 1127,
155                                                           ts           => '080721  3:11:12'
156                                                         },
157                                                         {
158                                                           New_pattern  => 'Yes',
159                                                           Level        => 'unknown',
160                                                           Pattern_no   => 11,
161                                                           Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
162                                                           arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
163                                                           pos_in_log   => 1194
164                                                         },
165                                                         {
166                                                           New_pattern  => 'Yes',
167                                                           Level        => 'info',
168                                                           Pattern_no   => 12,
169                                                           Pattern      => '\[Note\] /usr/libexec/mysqld: Normal shutdown',
170                                                           arg          => '[Note] /usr/libexec/mysqld: Normal shutdown',
171                                                           pos_in_log   => 1287,
172                                                           ts           => '080721  9:22:14'
173                                                         },
174                                                         {
175                                                           New_pattern  => 'Yes',
176                                                           Level        => 'unknown',
177                                                           Pattern_no   => 13,
178                                                           Pattern      => 'InnoDB: Starting shutdown\.\.\.',
179                                                           arg          => 'InnoDB: Starting shutdown...',
180                                                           pos_in_log   => 1347,
181                                                           ts           => '080721  9:22:17'
182                                                         },
183                                                         {
184                                                           New_pattern  => 'Yes',
185                                                           Level        => 'unknown',
186                                                           Pattern_no   => 14,
187                                                           Pattern      => 'InnoDB: Shutdown completed; log sequence number \d+ \d+',
188                                                           arg          => 'InnoDB: Shutdown completed; log sequence number 1 3703096531',
189                                                           pos_in_log   => 1472,
190                                                           ts           => '080721  9:22:20'
191                                                         },
192                                                         {
193                                                           New_pattern  => 'Yes',
194                                                           Level        => 'info',
195                                                           Pattern_no   => 15,
196                                                           Pattern      => '\[Note\] /usr/libexec/mysqld: Shutdown complete',
197                                                           arg          => '[Note] /usr/libexec/mysqld: Shutdown complete',
198                                                           pos_in_log   => 1534,
199                                                           ts           => '080721  9:22:20'
200                                                         },
201                                                         {
202                                                           New_pattern  => 'No',
203                                                           Level        => 'unknown',
204                                                           Pattern_no   => 3,
205                                                           Pattern      => 'mysqld ended',
206                                                           arg          => 'mysqld ended',
207                                                           pos_in_log   => 1534,
208                                                           ts           => '080721 09:22:22'
209                                                         },
210                                                         {
211                                                           New_pattern  => 'No',
212                                                           Level        => 'unknown',
213                                                           Pattern_no   => 0,
214                                                           Pattern      => 'mysqld started',
215                                                           arg          => 'mysqld started',
216                                                           pos_in_log   => 1565,
217                                                           ts           => '080721 09:22:31'
218                                                         },
219                                                         {
220                                                           New_pattern  => 'No',
221                                                           Level        => 'unknown',
222                                                           Pattern_no   => 11,
223                                                           Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
224                                                           arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
225                                                           pos_in_log   => 1598
226                                                         },
227                                                         {
228                                                           New_pattern  => 'Yes',
229                                                           Pattern_no   => 16,
230                                                           Pattern      => '\[ERROR\] bdb: log_archive: DB_ARCH_ABS: DB_NOTFOUND: No matching key/data pair found',
231                                                           Level        => 'error',
232                                                           arg          => '[ERROR] bdb: log_archive: DB_ARCH_ABS: DB_NOTFOUND: No matching key/data pair found',
233                                                           pos_in_log   => 1691,
234                                                           ts           => '080721  9:34:22'
235                                                         },
236                                                         {
237                                                           New_pattern  => 'No',
238                                                           Level        => 'unknown',
239                                                           Pattern_no   => 0,
240                                                           Pattern      => 'mysqld started',
241                                                           arg          => 'mysqld started',
242                                                           pos_in_log   => 1792,
243                                                           ts           => '080721 09:39:09'
244                                                         },
245                                                         {
246                                                           New_pattern  => 'No',
247                                                           Level        => 'unknown',
248                                                           Pattern_no   => 5,
249                                                           Pattern      => 'InnoDB: Started; log sequence number \d+ \d+',
250                                                           arg          => 'InnoDB: Started; log sequence number 1 3703096531',
251                                                           pos_in_log   => 1825,
252                                                           ts           => '080721  9:39:14'
253                                                         },
254                                                         { # 23
255                                                           New_pattern  => 'No',
256                                                           Level        => 'unknown',
257                                                           Pattern_no   => 0,
258                                                           Pattern      => 'mysqld started',
259                                                           arg          => 'mysqld started',
260                                                           pos_in_log   => 1924,
261                                                           ts           => '080821 19:14:12'
262                                                         },
263                                                         {
264                                                           New_pattern  => 'Yes',
265                                                           Level        => 'unknown',
266                                                           Pattern_no   => 17,
267                                                           Pattern      => 'InnoDB: Database was not shut down normally! Starting crash recovery\. Reading tablespace information from the \.ibd files\.\.\. Restoring possible half-written data pages from the doublewrite buffer\.\.\.',
268                                                           arg          => 'InnoDB: Database was not shut down normally! Starting crash recovery. Reading tablespace information from the .ibd files... Restoring possible half-written data pages from the doublewrite buffer...',
269                                                           pos_in_log   => 1924,
270                                                           ts           => '080821 19:14:12'
271                                                         },
272                                                         {
273                                                           New_pattern  => 'Yes',
274                                                           Level        => 'unknown',
275                                                           Pattern_no   => 18,
276                                                           Pattern      => 'InnoDB: Starting log scan based on checkpoint at log sequence number \d+ \d+\. Doing recovery: scanned up to log sequence number \d+ \d+ Last MySQL binlog file position \d+ \d+, file name \./srv-bin\.\d+',
277                                                           arg          => 'InnoDB: Starting log scan based on checkpoint at log sequence number 1 3703467071. Doing recovery: scanned up to log sequence number 1 3703467081 Last MySQL binlog file position 0 804759240, file name ./srv-bin.000012',
278                                                           pos_in_log   => 2237,
279                                                           ts           => '080821 19:14:13'
280                                                         },
281                                                         {
282                                                           New_pattern  => 'No',
283                                                           Level        => 'unknown',
284                                                           Pattern_no   => 5,
285                                                           Pattern      => 'InnoDB: Started; log sequence number \d+ \d+',
286                                                           arg          => 'InnoDB: Started; log sequence number 1 3703467081',
287                                                           pos_in_log   => 2497,
288                                                           ts           => '080821 19:14:13'
289                                                         },
290                                                         {
291                                                           New_pattern  => 'Yes',
292                                                           Level        => 'info',
293                                                           Pattern_no   => 19,
294                                                           Pattern      => '\[Note\] Recovering after a crash using srv-bin',
295                                                           arg          => '[Note] Recovering after a crash using srv-bin',
296                                                           pos_in_log   => 2559,
297                                                           ts           => '080821 19:14:13'
298                                                         },
299                                                         {
300                                                           New_pattern  => 'Yes',
301                                                           Level        => 'info',
302                                                           Pattern_no   => 20,
303                                                           Pattern      => '\[Note\] Starting crash recovery\.\.\.',
304                                                           arg          => '[Note] Starting crash recovery...',
305                                                           pos_in_log   => 2559,
306                                                           ts           => '080821 19:14:23'
307                                                         },
308                                                         {
309                                                           New_pattern  => 'Yes',
310                                                           Level        => 'info',
311                                                           Pattern_no   => 21,
312                                                           Pattern      => '\[Note\] Crash recovery finished\.',
313                                                           arg          => '[Note] Crash recovery finished.',
314                                                           pos_in_log   => 2609,
315                                                           ts           => '080821 19:14:23'
316                                                         },
317                                                         {
318                                                           New_pattern  => 'No',
319                                                           Level        => 'unknown',
320                                                           Pattern_no   => 11,
321                                                           Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
322                                                           arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
323                                                           pos_in_log   => 2657
324                                                         },
325                                                         {
326                                                           New_pattern  => 'Yes',
327                                                           Level        => 'info',
328                                                           Pattern_no   => 22,
329                                                           Pattern      => '\[Note\] Found \d+ of \d+ rows when repairing \'\./test/a3\'',
330                                                           arg          => '[Note] Found 5 of 0 rows when repairing \'./test/a3\'',
331                                                           pos_in_log   => 2750,
332                                                           ts           => '080911 18:04:40'
333                                                         },
334                                                         {
335                                                           New_pattern  => 'No',
336                                                           Level        => 'info',
337                                                           Pattern_no   => 10,
338                                                           Pattern      => '\[Note\] /usr/libexec/mysqld: ready for connections\.',
339                                                           arg          => '[Note] /usr/libexec/mysqld: ready for connections.',
340                                                           pos_in_log   => 2818,
341                                                           ts           => '081101  9:17:53'
342                                                         },
343                                                         {
344                                                           New_pattern  => 'No',
345                                                           Level        => 'unknown',
346                                                           Pattern_no   => 11,
347                                                           Pattern      => 'Version: \'\d+\.\d+\.\d+-log\' socket: \'/mnt/data/mysql/mysql\.sock\'  port: \d+  Source distribution',
348                                                           arg          => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
349                                                           pos_in_log   => 2886
350                                                         },
351                                                         { # 34
352                                                           New_pattern  => 'Yes',
353                                                           Level        => 'unknown',
354                                                           Pattern_no   => 23,
355                                                           Pattern      => 'Number of processes running now: \d+',
356                                                           arg          => 'Number of processes running now: 0',
357                                                           pos_in_log   => 2979
358                                                         },
359                                                         {
360                                                           New_pattern  => 'Yes',
361                                                           Level        => 'unknown',
362                                                           Pattern_no   => 24,
363                                                           Pattern      => 'mysqld restarted',
364                                                           arg          => 'mysqld restarted',
365                                                           pos_in_log   => 3015,
366                                                           ts           => '081117 16:15:07'
367                                                         },
368                                                         {
369                                                           New_pattern  => 'Yes',
370                                                           Pattern_no   => 25,
371                                                           Level        => 'error',
372                                                           Pattern      => 'InnoDB: Error: cannot allocate \d+ bytes of memory with malloc! Total allocated memory by InnoDB \d+ bytes\. Operating system errno: \d+ Check if you should increase the swap file or ulimits of your operating system\. On FreeBSD check you have compiled the OS with a big enough maximum process size\. Note that in most \d+-bit computers the process memory space is limited to \d+ GB or \d+ GB\. We keep retrying the allocation for \d+ seconds\.\.\. Fatal error: cannot allocate the memory for the buffer pool',
373                                                           arg          => 'InnoDB: Error: cannot allocate 268451840 bytes of memory with malloc! Total allocated memory by InnoDB 8074720 bytes. Operating system errno: 12 Check if you should increase the swap file or ulimits of your operating system. On FreeBSD check you have compiled the OS with a big enough maximum process size. Note that in most 32-bit computers the process memory space is limited to 2 GB or 4 GB. We keep retrying the allocation for 60 seconds... Fatal error: cannot allocate the memory for the buffer pool',
374                                                           pos_in_log   => 3049,
375                                                           ts           => '081117 16:15:16'
376                                                         },
377                                                         {
378                                                           New_pattern  => 'No',
379                                                           Level        => 'info',
380                                                           Pattern_no   => 10,
381                                                           Pattern      => '\[Note\] /usr/libexec/mysqld: ready for connections\.',
382                                                           arg          => '[Note] /usr/libexec/mysqld: ready for connections.',
383                                                           pos_in_log   => 3718,
384                                                           ts           => '081117 16:32:55'
385                                                         },
386                                                      ],
387                                                      'errlog001.txt'
388                                                   );
389                                                   
390            1                                112   $m = new ErrorLogPatternMatcher(QueryRewriter => $qr);
391            1                                 59   is_deeply(
392                                                      parse('common/t/samples/errlogs/errlog002.txt', $p),
393                                                      [
394                                                         {
395                                                            New_pattern => 'Yes',
396                                                            Level       => 'info',
397                                                            Pattern     => '\[Note\] Slave SQL thread initialized, starting replication in log \'mpb-bin\.\d+\' at position \d+, relay log \'\./web-relay-bin\.\d+\' position: \d+',
398                                                            Pattern_no  => 0,
399                                                            arg         => '[Note] Slave SQL thread initialized, starting replication in log \'mpb-bin.000519\' at position 4, relay log \'./web-relay-bin.000001\' position: 4',
400                                                            pos_in_log  => 0,
401                                                            ts          => '090902  8:15:00'
402                                                         },
403                                                         {
404                                                            New_pattern => 'Yes',
405                                                            Level       => 'warning',
406                                                            Pattern     => '\[Warning\] Statement may not be safe to log in statement format\. Statement: insert ignore into fud\?_search_cache \(srch_query, query_type, expiry, msg_id, n_match\) select \?, \?, \?, msg_id, count\(\*\) as word_count from fud\?_search s inner join fud\?_index i on i\.word_id=s\.id where word in\(\?\+\) group by msg_id order by word_count desc limit \?',
407                                                            Pattern_no  => 1,
408                                                            arg         => '[Warning] Statement may not be safe to log in statement format. Statement: INSERT IGNORE INTO fud26_search_cache (srch_query, query_type, expiry, msg_id, n_match) SELECT \'eb081c4be7a9fd8c5aa647f44e6e6365\', 0, 1250326725, msg_id, count(*) as word_count FROM fud26_search s INNER JOIN fud26_index i ON i.word_id=s.id WHERE word IN(\'ejgkkvqduyhzjqwynkf\') GROUP BY msg_id ORDER BY word_count DESC LIMIT 500',
409                                                            pos_in_log  => 160,
410                                                            ts          => '090902  8:40:46'
411                                                         },
412                                                         {
413                                                            New_pattern => 'No',
414                                                            Level       => 'warning',
415                                                            Pattern     => '\[Warning\] Statement may not be safe to log in statement format\. Statement: insert ignore into fud\?_search_cache \(srch_query, query_type, expiry, msg_id, n_match\) select \?, \?, \?, msg_id, count\(\*\) as word_count from fud\?_search s inner join fud\?_index i on i\.word_id=s\.id where word in\(\?\+\) group by msg_id order by word_count desc limit \?',
416                                                            Pattern_no  => 1,
417                                                            arg         => '[Warning] Statement may not be safe to log in statement format. Statement: INSERT IGNORE INTO fud26_search_cache (srch_query, query_type, expiry, msg_id, n_match) SELECT \'89b76d476dcf711b813a14f8c52df840\', 0, 1250328053, msg_id, count(*) as word_count FROM fud26_search s INNER JOIN fud26_index i ON i.word_id=s.id WHERE word IN(\'heicvrxtljqlth\') GROUP BY msg_id ORDER BY word_count DESC LIMIT 500',
418                                                            pos_in_log  => 579,
419                                                            ts          => '090902  8:40:52'
420                                                         },
421                                                         {
422                                                          New_pattern   => 'No',
423                                                          Level         => 'warning',
424                                                          Pattern       => '\[Warning\] Statement may not be safe to log in statement format\. Statement: insert ignore into fud\?_search_cache \(srch_query, query_type, expiry, msg_id, n_match\) select \?, \?, \?, msg_id, count\(\*\) as word_count from fud\?_search s inner join fud\?_index i on i\.word_id=s\.id where word in\(\?\+\) group by msg_id order by word_count desc limit \?',
425                                                          Pattern_no    => 1,
426                                                          arg           => '[Warning] Statement may not be safe to log in statement format. Statement: INSERT IGNORE INTO fud26_search_cache (srch_query, query_type, expiry, msg_id, n_match) SELECT \'895e2ddda332df8d230a9370f6db2ec4\', 0, 1250333052, msg_id, count(*) as word_count FROM fud26_search s INNER JOIN fud26_index i ON i.word_id=s.id WHERE word IN(\'postgresql\') GROUP BY msg_id ORDER BY word_count DESC LIMIT 500',
427                                                          pos_in_log    => 993,
428                                                          ts            => '090902  8:41:00'
429                                                         },
430                                                      ],
431                                                      'errlog002.txt - fingerprint Statement: query'
432                                                   );
433                                                   
434                                                   # ############################################################################
435                                                   # Load patterns.
436                                                   # ############################################################################
437            1                                 28   $m = new ErrorLogPatternMatcher(QueryRewriter => $qr);
438            1                                 18   my @patterns = $m->patterns;
439            1                                  5   is_deeply(
440                                                      \@patterns,
441                                                      [],
442                                                      'Does not load known patterns by default'
443                                                   );
444                                                   
445   ***      1     50                          50   open my $fh, '<', "$trunk/common/t/samples/errlogs/patterns.txt"
446                                                      or die "Cannot open $trunk/common/t/samples/errlogs/patterns.txt: $OS_ERROR";
447            1                                  6   $m->load_patterns_file($fh);
448            1                                  6   @patterns = $m->patterns;
449            1                                  7   is_deeply(
450                                                      \@patterns,
451                                                      [
452                                                         '^foo',
453                                                         'mysql got signal \d',
454                                                      ],
455                                                      'Load patterns file'
456                                                   );
457                                                   
458            1                                 11   @patterns = $m->names;
459            1                                  7   is(
460                                                      $patterns[0],
461                                                      'pattern1',
462                                                      'names'
463                                                   );
464                                                   
465            1                                  5   @patterns = $m->levels;
466            1                                  6   is(
467                                                      $patterns[0],
468                                                      'info',
469                                                      'levels'
470                                                   );
471                                                   
472                                                   # #############################################################################
473                                                   # Reset patterns.
474                                                   # #############################################################################
475                                                   
476                                                   # This assumes that some patterns have been loaded from above.
477            1                                  7   $m->reset_patterns();
478                                                   
479            1                                  5   @patterns = $m->patterns;
480            1                                  6   is_deeply(
481                                                      \@patterns,
482                                                      [],
483                                                      'Reset patterns'
484                                                   );
485                                                   
486            1                                  9   @patterns = $m->names;
487            1                                  6   is_deeply(
488                                                      \@patterns,
489                                                      [],
490                                                      'Reset names'
491                                                   );
492                                                   
493            1                                  9   @patterns = $m->levels;
494            1                                  6   is_deeply(
495                                                      \@patterns,
496                                                      [],
497                                                      'Reset levels'
498                                                   );
499                                                   
500                                                   # #############################################################################
501                                                   # Done.
502                                                   # #############################################################################
503            1                                  7   $output = '';
504                                                   {
505            1                                  3      local *STDERR;
               1                                  8   
506            1                    1             2      open STDERR, '>', \$output;
               1                                292   
               1                                  3   
               1                                  8   
507            1                                 15      $m->_d('Complete test coverage');
508                                                   }
509                                                   like(
510            1                                 13      $output,
511                                                      qr/Complete test coverage/,
512                                                      '_d() works'
513                                                   );
514            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
32    ***     50      0      2   unless open my $fh, '<', $file
37    ***     50      0     42   unless $e
445   ***     50      0      1   unless open my $fh, '<', "$trunk/common/t/samples/errlogs/patterns.txt"


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location                    
---------- ----- ----------------------------
BEGIN          1 ErrorLogPatternMatcher.t:10 
BEGIN          1 ErrorLogPatternMatcher.t:11 
BEGIN          1 ErrorLogPatternMatcher.t:12 
BEGIN          1 ErrorLogPatternMatcher.t:14 
BEGIN          1 ErrorLogPatternMatcher.t:15 
BEGIN          1 ErrorLogPatternMatcher.t:16 
BEGIN          1 ErrorLogPatternMatcher.t:17 
BEGIN          1 ErrorLogPatternMatcher.t:4  
BEGIN          1 ErrorLogPatternMatcher.t:506
BEGIN          1 ErrorLogPatternMatcher.t:9  
parse          2 ErrorLogPatternMatcher.t:28 


