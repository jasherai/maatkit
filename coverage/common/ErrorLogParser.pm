---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
.../common/ErrorLogParser.pm   93.3   90.0   78.6   87.5    0.0   97.9   89.5
ErrorLogParser.t              100.0   50.0   33.3  100.0    n/a    2.1   95.2
Total                          95.7   87.5   70.6   94.1    0.0  100.0   91.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:54 2010
Finish:       Thu Jun 24 19:32:54 2010

Run:          ErrorLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:55 2010
Finish:       Thu Jun 24 19:32:56 2010

/home/daniel/dev/maatkit/common/ErrorLogParser.pm

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
18                                                    # ErrorLogParser package $Revision: 6004 $
19                                                    # ###########################################################################
20                                                    package ErrorLogParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             9   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25                                                    
26             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  7   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 14   
32                                                    
33                                                    my $ts = qr/(\d{6}\s{1,2}[\d:]+)\s*/;
34                                                    my $ml = qr{\A(?:
35                                                       InnoDB:\s
36                                                       |-\smysqld\sgot\ssignal
37                                                       |Status\sinformation
38                                                       |Memory\sstatus
39                                                    )}x;
40                                                    
41                                                    sub new {
42    ***      1                    1      0      5      my ( $class, %args ) = @_;
43             1                                  6      my $self = {
44                                                          %args,
45                                                          pending => [],
46                                                       };
47             1                                 12      return bless $self, $class;
48                                                    }
49                                                    
50                                                    sub parse_event {
51    ***     71                   71      0   2038      my ( $self, %args ) = @_;
52            71                                359      my @required_args = qw(fh);
53            71                                250      foreach my $arg ( @required_args ) {
54    ***     71     50                         372         die "I need a $arg argument" unless $args{$arg};
55                                                       }
56            71                                276      my ($fh) = @args{@required_args};
57                                                    
58            71                                226      my $pending = $self->{pending};
59                                                    
60            71                                229      my $pos_in_log = tell($fh);
61            71                                161      my $line;
62                                                       EVENT:
63            71           100                33733      while ( defined($line = shift @$pending) or defined($line = <$fh>) ) {
64            71    100                         492         next if $line =~ m/^\s*$/;  # lots of blank lines in error logs
65            62                                183         chomp $line;
66            62                                264         my @properties = ('pos_in_log', $pos_in_log);
67            62                                215         $pos_in_log = tell($fh);
68                                                    
69                                                          # timestamp
70            62    100                         593         if ( my ($ts) = $line =~ /^$ts/o ) {
71            53                                127            MKDEBUG && _d('Got ts:', $ts);
72            53                                199            push @properties, 'ts', $ts;
73            53                                671            $line =~ s/^$ts//;
74                                                          }
75                                                    
76                                                          # Level: error, warning, info or unknown
77            62                                173         my $level;
78            62    100                         428         if ( ($level) = $line =~ /\[((?:ERROR|Warning|Note))\]/ ) {
79            26    100                         153            $level = $level =~ m/error/i   ? 'error'
                    100                               
80                                                                    : $level =~ m/warning/i ? 'warning'
81                                                                    :                         'info';
82                                                          }
83                                                          else {
84            36                                109            $level = 'unknown';
85                                                          }
86            62                                167         MKDEBUG && _d('Level:', $level);
87            62                                218         push @properties, 'Level', $level;
88                                                    
89                                                          # A special case error
90            62    100                         304         if ( my ($level) = $line =~ /InnoDB: Error/ ) {
91             1                                  3            MKDEBUG && _d('Got serious InnoDB error');
92             1                                  7            push @properties, 'Level', 'error';
93                                                          }
94                                                    
95                                                          # Collapse whitespace after removing stuff above.
96            62                                223         $line =~ s/^\s+//;
97            62                                278         $line =~ s/\s{2,}/ /;
98            62                                311         $line =~ s/\s+$//;
99                                                    
100                                                         # Handle multi-line error messagess.  There are several types: debug
101                                                         # messages from 'mysqladmin debug', crash and stack trace, and InnoDB.
102                                                         # InnoDB prints multi-line messages like:
103                                                         #   080821 19:14:12  InnoDB: Database was not shut down normally!
104                                                         #   InnoDB: Starting crash recovery.
105                                                         # We strip off the InnoDB: prefix after the first line, and keep going
106                                                         # until we find a line that begins a new message.
107                                                   
108           62    100                         444         if ( $line =~ m/$ml/o ) {
                    100                               
                    100                               
109           20                                 48            MKDEBUG && _d('Multi-line message:', $line);
110           20                                 75            $line =~ s/- //; # Trim "- msyqld got signal" special case.
111           20                                 52            my $next_line;
112           20           100                  282            while ( defined($next_line = <$fh>)
113                                                                    && $next_line !~ m/^$ts/o ) {
114         3313                               8380               chomp $next_line;
115         3313    100                       15671               next if $next_line eq '';
116         2980                               8143               $next_line =~ s/^InnoDB: //; # InnoDB special-case.
117         2980                              30565               $line     .= " " . $next_line;
118                                                            }
119           20                                 45            MKDEBUG && _d('Pending next line:', $next_line);
120           20                                 88            push @$pending, $next_line;
121                                                         }
122                                                         # Multi-line query for errors like "[ERROR] Slave SQL: Error ... Query:"
123                                                         elsif ( $line =~ m/\bQuery: '/ ) {
124            1                                  3            MKDEBUG && _d('Error query:', $line);
125            1                                  3            my $next_line;
126            1                                  3            my $last_line = 0;
127   ***      1            66                   19            while ( !$last_line && defined($next_line = <$fh>) ) {
128            3                                  7               chomp $next_line;
129            3                                  9               MKDEBUG && _d('Error query:', $next_line);
130            3                                  9               $line     .= $next_line;
131            3    100                          34               $last_line = 1 if $next_line =~ m/, Error_code:/;
132                                                            }
133                                                         }
134                                                   		# Multi-line query to fix issue 921, innodb error message: [ERROR] Cannot find table
135                                                         elsif ( $line =~ m/\bCannot find table/) {
136            1                                  3            MKDEBUG && _d('Special Multiline message:', $line);
137            1                                  3            my $next_line;
138            1                                  3            my $last_line = 0;
139   ***      1            66                   19            while ( !$last_line && defined($next_line = <$fh>) ) {
140            7                                 17               chomp $next_line;
141            7                                 15               MKDEBUG && _d('Pending next line:', $next_line);
142            7                                 19   				$line     .= ' ';
143            7                                 18               $line     .= $next_line;
144            7    100                          64               $last_line = 1 if $next_line =~ m/\bhow you can resolve the problem/;	      
145                                                            }
146                                                         }
147                                                   
148                                                         # Save the error line.
149           62                                174         chomp $line;
150           62                                376         push @properties, 'arg', $line;
151                                                   
152                                                         # Don't dump $event; want to see full dump of all properties, and after
153                                                         # it's been cast into a hash, duplicated keys will be gone.
154           62                                133         MKDEBUG && _d('Properties of event:', Dumper(\@properties));
155           62                                476         my $event = { @properties };
156           62                                553         return $event;
157                                                   
158                                                      } # EVENT
159                                                   
160            9                                 31      @$pending = ();
161            9    100                          46      $args{oktorun}->(0) if $args{oktorun};
162            9                                 62      return;
163                                                   }
164                                                   
165                                                   sub _d {
166   ***      0                    0                    my ($package, undef, $line) = caller 0;
167   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
168   ***      0                                              map { defined $_ ? $_ : 'undef' }
169                                                           @_;
170   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
171                                                   }
172                                                   
173                                                   1;
174                                                   
175                                                   # ###########################################################################
176                                                   # End ErrorLogParser package
177                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
54    ***     50      0     71   unless $args{$arg}
64           100      9     62   if $line =~ /^\s*$/
70           100     53      9   if (my($ts) = $line =~ /^$ts/o)
78           100     26     36   if (($level) = $line =~ /\[((?:ERROR|Warning|Note))\]/) { }
79           100      7     10   $level =~ /warning/i ? :
             100      9     17   $level =~ /error/i ? :
90           100      1     61   if (my($level) = $line =~ /InnoDB: Error/)
108          100     20     42   if ($line =~ /$ml/o) { }
             100      1     41   elsif ($line =~ /\bQuery: '/) { }
             100      1     40   elsif ($line =~ /\bCannot find table/) { }
115          100    333   2980   if $next_line eq ''
131          100      1      2   if $next_line =~ /, Error_code:/
144          100      1      6   if $next_line =~ /\bhow you can resolve the problem/
161          100      2      7   if $args{'oktorun'}
167   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
112          100      2     18   3313   defined($next_line = <$fh>) and not $next_line =~ /^$ts/o
127   ***     66      1      0      3   not $last_line and defined($next_line = <$fh>)
139   ***     66      1      0      7   not $last_line and defined($next_line = <$fh>)

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
63           100     18     53      9   defined($line = shift @$pending) or defined($line = <$fh>)


Covered Subroutines
-------------------

Subroutine  Count Pod Location                                             
----------- ----- --- -----------------------------------------------------
BEGIN           1     /home/daniel/dev/maatkit/common/ErrorLogParser.pm:22 
BEGIN           1     /home/daniel/dev/maatkit/common/ErrorLogParser.pm:23 
BEGIN           1     /home/daniel/dev/maatkit/common/ErrorLogParser.pm:24 
BEGIN           1     /home/daniel/dev/maatkit/common/ErrorLogParser.pm:26 
BEGIN           1     /home/daniel/dev/maatkit/common/ErrorLogParser.pm:31 
new             1   0 /home/daniel/dev/maatkit/common/ErrorLogParser.pm:42 
parse_event    71   0 /home/daniel/dev/maatkit/common/ErrorLogParser.pm:51 

Uncovered Subroutines
---------------------

Subroutine  Count Pod Location                                             
----------- ----- --- -----------------------------------------------------
_d              0     /home/daniel/dev/maatkit/common/ErrorLogParser.pm:166


ErrorLogParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  3   
               1                                  5   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  4   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 18;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            12   use ErrorLogParser;
               1                                  2   
               1                                 88   
15             1                    1            12   use MaatkitTest;
               1                                  3   
               1                                 53   
16                                                    
17             1                                  8   my $p = new ErrorLogParser();
18                                                    
19             1                                  3   my $oktorun = 1;
20                                                    
21                                                    test_log_parser(
22                                                       parser  => $p,
23                                                       file    => 'common/t/samples/errlogs/errlog001.txt',
24             1                    1             4      oktorun => sub { $oktorun = $_[0]; },
25             1                                138      result  => [
26                                                          {
27                                                           arg        => 'mysqld started',
28                                                           pos_in_log => 0,
29                                                           ts         => '080721 03:03:57',
30                                                           Level      => 'unknown',
31                                                          },
32                                                          {
33                                                           Level      => 'warning',
34                                                           arg        => '[Warning] option \'log_slow_rate_limit\': unsigned value 0 adjusted to 1',
35                                                           pos_in_log => 32,
36                                                           ts         => '080721  3:04:00',
37                                                          },
38                                                          {
39                                                           Level      => 'error',
40                                                           arg        => '[ERROR] /usr/sbin/mysqld: unknown variable \'ssl-key=/opt/mysql.pdns/.cert/server-key.pem\'',
41                                                           pos_in_log => 119,
42                                                           ts         => '080721  3:04:01',
43                                                          },
44                                                          {
45                                                           arg        => 'mysqld ended',
46                                                           pos_in_log => 225,
47                                                           ts         => '080721 03:04:01',
48                                                           Level      => 'unknown',
49                                                          },
50                                                          {
51                                                           arg        => 'mysqld started',
52                                                           pos_in_log => 255,
53                                                           ts         => '080721 03:10:57',
54                                                           Level      => 'unknown',
55                                                          },
56                                                          {
57                                                           Level      => 'warning',
58                                                           arg        => '[Warning] No argument was provided to --log-bin, and --log-bin-index was not used; so replication may break when this MySQL server acts as a master and has his hostname changed!! Please use \'--log-bin=/var/run/mysqld/mysqld-bin\' to avoid this problem.',
59                                                           pos_in_log => 288,
60                                                           ts         => '080721  3:10:58',
61                                                          },
62                                                          {
63                                                           arg        => 'InnoDB: Started; log sequence number 1 3703096531',
64                                                           pos_in_log => 556,
65                                                           ts         => '080721  3:11:08',
66                                                           Level      => 'unknown',
67                                                          },
68                                                          {
69                                                           Level      => 'warning',
70                                                           arg        => '[Warning] Neither --relay-log nor --relay-log-index were used; so replication may break when this MySQL server acts as a slave and has his hostname changed!! Please use \'--relay-log=/var/run/mysqld/mysqld-relay-bin\' to avoid this problem.',
71                                                           pos_in_log => 878,
72                                                           ts         => '080721  3:11:12',
73                                                          },
74                                                          {
75                                                           Level      => 'error',
76                                                           arg        => '[ERROR] Failed to open the relay log \'./srv-relay-bin.000001\' (relay_log_pos 4)',
77                                                           pos_in_log => 878,
78                                                           ts         => '080721  3:11:12',
79                                                          },
80                                                          {
81                                                           Level      => 'error',
82                                                           arg        => '[ERROR] Could not find target log during relay log initialization',
83                                                           pos_in_log => 974,
84                                                           ts         => '080721  3:11:12',
85                                                          },
86                                                          {
87                                                           Level      => 'error',
88                                                           arg        => '[ERROR] Failed to initialize the master info structure',
89                                                           pos_in_log => 1056,
90                                                           ts         => '080721  3:11:12',
91                                                          },
92                                                          {
93                                                           Level      => 'info',
94                                                           arg        => '[Note] /usr/libexec/mysqld: ready for connections.',
95                                                           pos_in_log => 1127,
96                                                           ts         => '080721  3:11:12',
97                                                          },
98                                                          {
99                                                           arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
100                                                          pos_in_log => 1194,
101                                                          Level      => 'unknown',
102                                                         },
103                                                         {
104                                                          Level      => 'info',
105                                                          arg        => '[Note] /usr/libexec/mysqld: Normal shutdown',
106                                                          pos_in_log => 1287,
107                                                          ts         => '080721  9:22:14',
108                                                         },
109                                                         {
110                                                          arg        => 'InnoDB: Starting shutdown...',
111                                                          pos_in_log => 1347,
112                                                          ts         => '080721  9:22:17',
113                                                          Level      => 'unknown',
114                                                         },
115                                                         {
116                                                          arg        => 'InnoDB: Shutdown completed; log sequence number 1 3703096531',
117                                                          pos_in_log => 1472,
118                                                          ts         => '080721  9:22:20',
119                                                          Level      => 'unknown',
120                                                         },
121                                                         {
122                                                          Level      => 'info',
123                                                          arg        => '[Note] /usr/libexec/mysqld: Shutdown complete',
124                                                          pos_in_log => 1534,
125                                                          ts         => '080721  9:22:20',
126                                                         },
127                                                         {
128                                                          arg        => 'mysqld ended',
129                                                          pos_in_log => 1534,
130                                                          ts         => '080721 09:22:22',
131                                                          Level      => 'unknown',
132                                                         },
133                                                         {
134                                                          arg        => 'mysqld started',
135                                                          pos_in_log => 1565,
136                                                          ts         => '080721 09:22:31',
137                                                         Level      => 'unknown',
138                                                         },
139                                                         {
140                                                          arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
141                                                          pos_in_log => 1598,
142                                                          Level      => 'unknown',
143                                                         },
144                                                         {
145                                                          Level      => 'error',
146                                                          arg        => '[ERROR] bdb: log_archive: DB_ARCH_ABS: DB_NOTFOUND: No matching key/data pair found',
147                                                          pos_in_log => 1691,
148                                                          ts         => '080721  9:34:22',
149                                                         },
150                                                         {
151                                                          arg        => 'mysqld started',
152                                                          pos_in_log => 1792,
153                                                          ts         => '080721 09:39:09',
154                                                          Level      => 'unknown',
155                                                         },
156                                                         {
157                                                          arg        => 'InnoDB: Started; log sequence number 1 3703096531',
158                                                          pos_in_log => 1825,
159                                                          ts         => '080721  9:39:14',
160                                                          Level      => 'unknown',
161                                                         },
162                                                         {
163                                                          arg        => 'mysqld started',
164                                                          pos_in_log => 1924,
165                                                          ts         => '080821 19:14:12',
166                                                          Level      => 'unknown',
167                                                         },
168                                                         {
169                                                          pos_in_log => 1924,
170                                                          ts         => '080821 19:14:12',
171                                                          arg        => 'InnoDB: Database was not shut down normally! Starting crash recovery. Reading tablespace information from the .ibd files... Restoring possible half-written data pages from the doublewrite buffer...',
172                                                          Level      => 'unknown',
173                                                         },
174                                                         {
175                                                          pos_in_log => 2237,
176                                                          ts         => '080821 19:14:13',
177                                                          arg        => 'InnoDB: Starting log scan based on checkpoint at log sequence number 1 3703467071. Doing recovery: scanned up to log sequence number 1 3703467081 Last MySQL binlog file position 0 804759240, file name ./srv-bin.000012',
178                                                          Level      => 'unknown',
179                                                         },
180                                                         {
181                                                          arg        => 'InnoDB: Started; log sequence number 1 3703467081',
182                                                          pos_in_log => 2497,
183                                                          ts         => '080821 19:14:13',
184                                                          Level      => 'unknown',
185                                                         },
186                                                         {
187                                                          Level      => 'info',
188                                                          arg        => '[Note] Recovering after a crash using srv-bin',
189                                                          pos_in_log => 2559,
190                                                          ts         => '080821 19:14:13',
191                                                         },
192                                                         {
193                                                          Level      => 'info',
194                                                          arg        => '[Note] Starting crash recovery...',
195                                                          pos_in_log => 2559,
196                                                          ts         => '080821 19:14:23',
197                                                         },
198                                                         {
199                                                          Level      => 'info',
200                                                          arg        => '[Note] Crash recovery finished.',
201                                                          pos_in_log => 2609,
202                                                          ts         => '080821 19:14:23',
203                                                         },
204                                                         {
205                                                          arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
206                                                          pos_in_log => 2657,
207                                                          Level      => 'unknown',
208                                                         },
209                                                         {
210                                                          Level      => 'info',
211                                                          arg        => '[Note] Found 5 of 0 rows when repairing \'./test/a3\'',
212                                                          pos_in_log => 2750,
213                                                          ts         => '080911 18:04:40',
214                                                         },
215                                                         {
216                                                          Level      => 'info',
217                                                          arg        => '[Note] /usr/libexec/mysqld: ready for connections.',
218                                                          pos_in_log => 2818,
219                                                          ts         => '081101  9:17:53',
220                                                         },
221                                                         {
222                                                          arg        => 'Version: \'5.0.45-log\' socket: \'/mnt/data/mysql/mysql.sock\'  port: 3306  Source distribution',
223                                                          pos_in_log => 2886,
224                                                          Level      => 'unknown',
225                                                         },
226                                                         {
227                                                          arg        => 'Number of processes running now: 0',
228                                                          pos_in_log => 2979,
229                                                          Level      => 'unknown',
230                                                         },
231                                                         {
232                                                          arg        => 'mysqld restarted',
233                                                          pos_in_log => 3015,
234                                                          ts         => '081117 16:15:07',
235                                                          Level      => 'unknown',
236                                                         },
237                                                         {
238                                                          pos_in_log => 3049,
239                                                          ts         => '081117 16:15:16',
240                                                          Level      => 'error',
241                                                          arg        => 'InnoDB: Error: cannot allocate 268451840 bytes of memory with malloc! Total allocated memory by InnoDB 8074720 bytes. Operating system errno: 12 Check if you should increase the swap file or ulimits of your operating system. On FreeBSD check you have compiled the OS with a big enough maximum process size. Note that in most 32-bit computers the process memory space is limited to 2 GB or 4 GB. We keep retrying the allocation for 60 seconds... Fatal error: cannot allocate the memory for the buffer pool',
242                                                         },
243                                                         {
244                                                          Level      => 'info',
245                                                          arg        => '[Note] /usr/libexec/mysqld: ready for connections.',
246                                                          pos_in_log => 3718,
247                                                          ts         => '081117 16:32:55',
248                                                         },
249                                                      ],
250                                                   );
251                                                   
252            1                                114   test_log_parser(
253                                                      parser => $p,
254                                                      file   => 'common/t/samples/errlogs/errlog003.txt',
255                                                      result => [
256                                                         {
257                                                            Level       => 'error',
258                                                            arg         => '[ERROR] /usr/sbin/mysqld: Incorrect key file for table \'./bugs_eventum/eventum_note.MYI\'; try to repair it',
259                                                            pos_in_log  => 0,
260                                                            ts          => '090902 10:43:55',
261                                                         },
262                                                         {
263                                                            Level       => 'error',
264                                                            pos_in_log  => 123,
265                                                            ts          => '090902 10:43:55',
266                                                            arg         => '[ERROR] Slave SQL: Error \'Incorrect key file for table \'./bugs_eventum/eventum_note.MYI\'; try to repair it\' on query. Default database: \'bugs_eventum\'. Query: \'DELETE FROM                    bugs_eventum.eventum_note                 WHERE                    not_iss_id IN (384, 385, 101056, 101057, 101058, 101067, 101070, 101156, 101163, 101164, 101175, 101232, 101309, 101433, 101434, 101435, 101436, 101437, 101454, 101476, 101488, 101490, 101506, 101507, 101530, 101531, 101573, 101574, 101575, 101583, 101586, 101587, 101588, 101589, 101590, 101729, 101730, 101791, 101865, 102382)\', Error_code: 126',
267                                                         },
268                                                         {
269                                                            Level       => 'warning',
270                                                            arg         => '[Warning] Slave: Incorrect key file for table \'./bugs_eventum/eventum_note.MYI\'; try to repair it Error_code: 126',
271                                                            pos_in_log  => 747,
272                                                            ts          => '090902 10:43:55'
273                                                         },
274                                                      ]
275                                                   );
276                                                   
277            1                                 32   my $big_arg = <<'EOF';
278                                                   mysqld got signal 6 ;
279                                                   This could be because you hit a bug. It is also possible that this binary
280                                                   or one of the libraries it was linked against is corrupt, improperly built,
281                                                   or misconfigured. This error can also be caused by malfunctioning hardware.
282                                                   We will try our best to scrape up some info that will hopefully help diagnose
283                                                   the problem, but since we have already crashed, something is definitely wrong
284                                                   and this may fail.
285                                                   
286                                                   key_buffer_size=67108864
287                                                   read_buffer_size=131072
288                                                   max_used_connections=2
289                                                   max_threads=128
290                                                   threads_connected=2
291                                                   It is possible that mysqld could use up to 
292                                                   key_buffer_size + (read_buffer_size + sort_buffer_size)*max_threads = 345366 K
293                                                   bytes of memory
294                                                   Hope that's ok; if not, decrease some variables in the equation.
295                                                   
296                                                   thd: 0xf95a8a0
297                                                   Attempting backtrace. You can use the following information to find out
298                                                   where mysqld died. If you see no messages after this, something went
299                                                   terribly wrong...
300                                                   stack_bottom = 0x4e3b0f20 thread_stack 0x40000
301                                                   /usr/sbin/mysqld(my_print_stacktrace+0x35)[0x83bd65]
302                                                   /usr/sbin/mysqld(handle_segfault+0x31d)[0x58dd4d]
303                                                   /lib64/libpthread.so.0[0x2b869c7984c0]
304                                                   /lib64/libc.so.6(gsignal+0x35)[0x2b869d2ad215]
305                                                   /lib64/libc.so.6(abort+0x110)[0x2b869d2aecc0]
306                                                   /usr/sbin/mysqld[0x741e55]
307                                                   /usr/sbin/mysqld[0x742078]
308                                                   /usr/sbin/mysqld[0x744b65]
309                                                   /usr/sbin/mysqld[0x7300a9]
310                                                   /usr/sbin/mysqld[0x728337]
311                                                   /usr/sbin/mysqld[0x7d135e]
312                                                   /usr/sbin/mysqld[0x7d1439]
313                                                   /usr/sbin/mysqld[0x7d1b18]
314                                                   /usr/sbin/mysqld[0x732e45]
315                                                   /usr/sbin/mysqld[0x73690b]
316                                                   /usr/sbin/mysqld[0x70b9b8]
317                                                   /usr/sbin/mysqld(_ZN7handler7ha_openEP8st_tablePKcii+0x3e)[0x66a50e]
318                                                   /usr/sbin/mysqld(_Z21open_table_from_shareP3THDP14st_table_sharePKcjjjP8st_tableb+0x597)[0x5e6cb7]
319                                                   /usr/sbin/mysqld[0x5db6fe]
320                                                   /usr/sbin/mysqld(_Z10open_tableP3THDP10TABLE_LISTP11st_mem_rootPbj+0x59c)[0x5dd0ac]
321                                                   /usr/sbin/mysqld(_Z11open_tablesP3THDPP10TABLE_LISTPjj+0x4cf)[0x5dddcf]
322                                                   /usr/sbin/mysqld(_Z28open_and_lock_tables_derivedP3THDP10TABLE_LISTb+0x67)[0x5de087]
323                                                   /usr/sbin/mysqld[0x684cef]
324                                                   /usr/sbin/mysqld(_Z17mysql_check_tableP3THDP10TABLE_LISTP15st_ha_check_opt+0x5e)[0x685cce]
325                                                   /usr/sbin/mysqld(_Z21mysql_execute_commandP3THD+0x28d8)[0x59d4e8]
326                                                   /usr/sbin/mysqld(_Z11mysql_parseP3THDPKcjPS2_+0x1dc)[0x5a07bc]
327                                                   /usr/sbin/mysqld(_Z16dispatch_command19enum_server_commandP3THDPcj+0xf98)[0x5a1778]
328                                                   /usr/sbin/mysqld(_Z10do_commandP3THD+0xe7)[0x5a1cd7]
329                                                   /usr/sbin/mysqld(handle_one_connection+0x592)[0x594c62]
330                                                   /lib64/libpthread.so.0[0x2b869c790367]
331                                                   /lib64/libc.so.6(clone+0x6d)[0x2b869d34ff7d]
332                                                   Trying to get some variables.
333                                                   Some pointers may be invalid and cause the dump to abort...
334                                                   thd->query at 0xf9b1670 = CHECK TABLE `rates`  FOR UPGRADE
335                                                   thd->thread_id=15
336                                                   thd->killed=NOT_KILLED
337                                                   The manual page at http://dev.mysql.com/doc/mysql/en/crashing.html contains
338                                                   information that should help you find out what is causing the crash.
339                                                   EOF
340            1                                  3   chomp $big_arg;
341            1                                 37   $big_arg =~ s/\n+/ /g;
342                                                   
343            1                                 34   test_log_parser(
344                                                      parser => $p,
345                                                      file   => 'common/t/samples/errlogs/errlog004.txt',
346                                                      result => [
347                                                         {
348                                                            Level       => 'error',
349                                                            arg         => '[ERROR] Error running query, slave SQL thread aborted. Fix the problem, and restart the slave SQL thread with "SLAVE START". We stopped at log \'mpb-bin.000534\' position 47010998',
350                                                            pos_in_log  => 0,
351                                                            ts          => '090902 10:43:55',
352                                                         },
353                                                         {
354                                                            arg         => 'InnoDB: Unable to lock ./timer2/rates.ibd, error: 37',
355                                                            pos_in_log  => 194,
356                                                            Level       => 'unknown',
357                                                         },
358                                                         {
359                                                            arg         => 'InnoDB: Assertion failure in thread 1312495936 in file fil/fil0fil.c line 752 Failing assertion: ret We intentionally generate a memory trap. Submit a detailed bug report to http://bugs.mysql.com. If you get repeated assertion failures or crashes, even immediately after the mysqld startup, there may be corruption in the InnoDB tablespace. Please refer to http://dev.mysql.com/doc/refman/5.1/en/forcing-recovery.html about forcing recovery.',
360                                                            pos_in_log  => 342,
361                                                            ts          => '090902 11:08:43',
362                                                            Level       => 'unknown',
363                                                         },
364                                                         {
365                                                            pos_in_log  => 810,
366                                                            ts          => '090902 11:08:43',
367                                                            arg         => $big_arg,
368                                                            Level       => 'unknown',
369                                                         },
370                                                         {
371                                                            arg         => 'mysqld_safe Number of processes running now: 0',
372                                                            pos_in_log  => 3636,
373                                                            ts          => '090902 11:08:43',
374                                                            Level       => 'unknown',
375                                                         },
376                                                      ]
377                                                   );
378                                                   
379            1                                 28   $big_arg = <<'EOF';
380                                                   Status information:
381                                                   Current dir: /var/lib/mysql/
382                                                   Running threads: 16  Stack size: 262144
383                                                   Current locks:
384                                                   lock: 0x29a90d0:
385                                                   lock: 0x26fb910:
386                                                   lock: 0x28f2ae0:
387                                                   lock: 0x2921e10:
388                                                   lock: 0x22ea900:
389                                                   lock: 0x272b840:
390                                                   lock: 0x2337f80:
391                                                   lock: 0x42ff310:
392                                                   lock: 0x26b35f0:
393                                                   lock: 0x23861f0:
394                                                   lock: 0x26a5ee0:
395                                                   lock: 0x2b02f60:
396                                                   lock: 0x29d37e0:
397                                                   lock: 0x29d2f80:
398                                                   lock: 0x2706e90:
399                                                   lock: 0x22ee350:
400                                                   lock: 0x39bd8b0:
401                                                   lock: 0x28ec500:
402                                                   lock: 0x2a5e8a0:
403                                                   lock: 0x271fd60:
404                                                   lock: 0x39f2c80:
405                                                   lock: 0x29c2730:
406                                                   lock: 0x25227f0:
407                                                   lock: 0x41b6dc0:
408                                                   lock: 0x4207cd0:
409                                                   lock: 0x24a0360:
410                                                   lock: 0x22edcd0:
411                                                   lock: 0x29cd590:
412                                                   lock: 0x29c0140:
413                                                   lock: 0x3a75bf0:
414                                                   lock: 0x390f530:
415                                                   lock: 0x390fd00:
416                                                   lock: 0x3921110:
417                                                   lock: 0x41d6cd0:
418                                                   lock: 0x2346100:
419                                                   lock: 0x22ec870:
420                                                   lock: 0x23a8ea0:
421                                                   lock: 0x26fec60:
422                                                   lock: 0x23878d0:
423                                                   lock: 0x2652ca0:
424                                                   lock: 0x3fe7240:
425                                                   lock: 0x24f5b80:
426                                                   lock: 0x2614a60:
427                                                   lock: 0x41b6550:
428                                                   lock: 0x4199a30:
429                                                   lock: 0x41ba150:
430                                                   lock: 0x4192430:
431                                                   lock: 0x418fcc0:
432                                                   lock: 0x236a480:
433                                                   lock: 0x25bf440:
434                                                   lock: 0x25bbd00:
435                                                   lock: 0x28207b0:
436                                                   lock: 0x2ee33b0:
437                                                   lock: 0x2e1ab50:
438                                                   lock: 0x442f6f0:
439                                                   lock: 0x3ed6fe0:
440                                                   lock: 0x3ed69f0:
441                                                   lock: 0x25c2100:
442                                                   lock: 0x25d3840:
443                                                   lock: 0x3a7c920:
444                                                   lock: 0x3a7d8d0:
445                                                   lock: 0x258f080:
446                                                   lock: 0x2e81d00:
447                                                   lock: 0x3ef3380:
448                                                   lock: 0x408e610:
449                                                   lock: 0x41e1aa0:
450                                                   lock: 0x2561980:
451                                                   lock: 0x41c9c50:
452                                                   lock: 0x3f64c70:
453                                                   lock: 0x252b2f0:
454                                                   lock: 0x252dca0:
455                                                   lock: 0x2e043c0:
456                                                   lock: 0x3fb2e60:
457                                                   lock: 0x3eead10:
458                                                   lock: 0x41a30f0:
459                                                   lock: 0x4155b50:
460                                                   lock: 0x41978f0:
461                                                   lock: 0x28408a0:
462                                                   lock: 0x429bd80:
463                                                   lock: 0x4078490:
464                                                   lock: 0x4195df0:
465                                                   lock: 0x3ac61a0:
466                                                   lock: 0x4172470:
467                                                   lock: 0x3ac4100:
468                                                   lock: 0x41811d0:
469                                                   lock: 0x417ea00:
470                                                   lock: 0x4177730:
471                                                   lock: 0x4175220:
472                                                   lock: 0x416dd20:
473                                                   lock: 0x3a88440:
474                                                   lock: 0x416b3f0:
475                                                   lock: 0x4169e40:
476                                                   lock: 0x4163520:
477                                                   lock: 0x4162200:
478                                                   lock: 0x415f540:
479                                                   lock: 0x4157b60:
480                                                   lock: 0x4156e60:
481                                                   lock: 0x40f9970:
482                                                   lock: 0x3a85800:
483                                                   lock: 0x28c4b00:
484                                                   Key caches:
485                                                   default
486                                                   Buffer_size:      67108864
487                                                   Block_size:           1024
488                                                   Division_limit:        100
489                                                   Age_limit:             300
490                                                   blocks used:         53585
491                                                   not flushed:             0
492                                                   w_requests:       18891286
493                                                   writes:            1329532
494                                                   r_requests:      173889204
495                                                   reads:              462708
496                                                   handler status:
497                                                   read_key:     31268733
498                                                   read_next:  2781246802
499                                                   read_rnd      37994506
500                                                   read_first:     377959
501                                                   write:       292954339
502                                                   delete          128239
503                                                   update:       34140006
504                                                   Table status:
505                                                   Opened tables:       2427
506                                                   Open tables:         1024
507                                                   Open files:          1630
508                                                   Open streams:           0
509                                                   Alarm status:
510                                                   Active alarms:   16
511                                                   Max used alarms: 46
512                                                   Next alarm time: 28699
513                                                   EOF
514            1                                  3   chomp $big_arg;
515            1                                 47   $big_arg =~ s/\n+/ /g;
516                                                   
517            1                                 20   test_log_parser(
518                                                      parser => $p,
519                                                      file   => 'common/t/samples/errlogs/errlog005.txt',
520                                                      result => [
521                                                         {
522                                                            pos_in_log  => 0,
523                                                            arg         => '[Note] /usr/sbin/mysqld: ready for connections.',
524                                                            ts          => '080517  4:20:13',
525                                                            Level       => 'info',
526                                                         },
527                                                         {
528                                                            pos_in_log  => 64,
529                                                            arg         => 'Version: \'5.0.58-enterprise-gpl-mpb-log\' socket: \'/var/lib/mysql/mysql.sock\'  port: 3306  MySQL Enterprise Server (MPB ed.) (GPL)',
530                                                            Level       => 'unknown',
531                                                         },
532                                                         {
533                                                            pos_in_log  => 195,
534                                                            Level       => 'unknown',
535                                                            arg         => $big_arg,
536                                                         },
537                                                         {
538                                                            pos_in_log  => 2873,
539                                                            arg         => '[Warning] \'db\' entry \'test nagios@4fa060606e2d579a\' ignored in --skip-name-resolve mode.',
540                                                            ts          => '080522  8:41:31',
541                                                            Level       => 'warning',
542                                                         },
543                                                      ],
544                                                   );
545                                                   
546            1                                 29   $big_arg = <<'EOF';
547                                                   Memory status:
548                                                   Non-mmapped space allocated from system: 94777344
549                                                   Number of free chunks:			 1359
550                                                   Number of fastbin blocks:		 0
551                                                   Number of mmapped regions:		 17
552                                                   Space in mmapped regions:		 276152320
553                                                   Maximum total allocated space:		 0
554                                                   Space available in freed fastbin blocks: 0
555                                                   Total allocated space:			 41663312
556                                                   Total free space:			 53114032
557                                                   Top-most, releasable space:		 19783856
558                                                   Estimated memory (with thread stack):    375123968
559                                                   Status information:
560                                                   Current dir: /var/lib/mysql/
561                                                   Running threads: 18  Stack size: 262144
562                                                   Current locks:
563                                                   lock: 0x2892460:
564                                                   lock: 0x3a053a0:
565                                                   lock: 0x2534210:
566                                                   lock: 0x27d49e0:
567                                                   lock: 0x2300950:
568                                                   lock: 0x2b5f070:
569                                                   lock: 0x284c2c0:
570                                                   lock: 0x2607f30:
571                                                   lock: 0x28827c0:
572                                                   lock: 0x4388c80:
573                                                   lock: 0x39c2820:
574                                                   lock: 0x2b6c2d0:
575                                                   lock: 0x2d06870:
576                                                   lock: 0x24f1240:
577                                                   lock: 0x29ef700:
578                                                   lock: 0x2b709a0:
579                                                   lock: 0x3a746b0:
580                                                   lock: 0x2c21eb0:
581                                                   lock: 0x29de5a0:
582                                                   lock: 0x23af7f0:
583                                                   lock: 0x2e76160:
584                                                   lock: 0x3fde000:
585                                                   lock: 0x3a05c20:
586                                                   lock: 0x286a1f0:
587                                                   lock: 0x273a660:
588                                                   lock: 0x26d7250:
589                                                   lock: 0x24510a0:
590                                                   lock: 0xe2cdb0:
591                                                   lock: 0x2304710:
592                                                   lock: 0x265af50:
593                                                   lock: 0x30050c0:
594                                                   lock: 0x265a310:
595                                                   lock: 0x25ac7b0:
596                                                   lock: 0x25ab1b0:
597                                                   lock: 0x2a512f0:
598                                                   lock: 0x29a65a0:
599                                                   lock: 0x29460e0:
600                                                   lock: 0x27f0150:
601                                                   lock: 0x2cb0490:
602                                                   lock: 0x41b6e60:
603                                                   lock: 0x41b5da0:
604                                                   lock: 0x303c530:
605                                                   lock: 0x303bc70:
606                                                   lock: 0x23ba210:
607                                                   lock: 0x2d85210:
608                                                   lock: 0x413c6f0:
609                                                   lock: 0x41fa6e0:
610                                                   lock: 0x2face70:
611                                                   lock: 0x2408eb0:
612                                                   lock: 0x3fd7b30:
613                                                   lock: 0x41457e0:
614                                                   lock: 0x2aaad00deb50:
615                                                   lock: 0x2aaad00da840:
616                                                   lock: 0x2aaad00f1060:
617                                                   lock: 0x2aaad0147a10:
618                                                   lock: 0x2aaad00f26b0:
619                                                   lock: 0x3fd3940:
620                                                   lock: 0x3fd13f0:
621                                                   lock: 0x2d6a370:
622                                                   lock: 0x24f4270:
623                                                   lock: 0x4201700:
624                                                   lock: 0x26a5180:
625                                                   lock: 0x2406c90:
626                                                   lock: 0x2d83be0:
627                                                   lock: 0x2d83320:
628                                                   lock: 0x3eb7570:
629                                                   lock: 0x3eb5960:
630                                                   lock: 0x24f1b00:
631                                                   lock: 0x2f28220:
632                                                   lock: 0x2dcbdf0:
633                                                   lock: 0x2d8f880:
634                                                   lock: 0x2d8d380:
635                                                   lock: 0x3eb8b10:
636                                                   lock: 0x2a13550:
637                                                   lock: 0x2a10ef0:
638                                                   lock: 0x4285460:
639                                                   lock: 0x2a0b050:
640                                                   lock: 0x3ec41f0:
641                                                   lock: 0x3ec18c0:
642                                                   lock: 0x3ebeb00:
643                                                   lock: 0x3ebc540:
644                                                   lock: 0x2a07530:
645                                                   lock: 0x2a04500:
646                                                   lock: 0x2a00790:
647                                                   lock: 0x4058050:
648                                                   lock: 0x4054f80:
649                                                   lock: 0x4051dd0:
650                                                   lock: 0x404da00:
651                                                   lock: 0x404b5f0:
652                                                   lock: 0x4049270:
653                                                   lock: 0x4046400:
654                                                   lock: 0x4042a00:
655                                                   lock: 0x403ff50:
656                                                   lock: 0x403cd30:
657                                                   lock: 0x4294aa0:
658                                                   lock: 0x4292650:
659                                                   lock: 0x4290280:
660                                                   lock: 0x428d770:
661                                                   lock: 0x4289d50:
662                                                   lock: 0x42879a0:
663                                                   Key caches:
664                                                   default
665                                                   Buffer_size:      67108864
666                                                   Block_size:           1024
667                                                   Division_limit:        100
668                                                   Age_limit:             300
669                                                   blocks used:         53585
670                                                   not flushed:             0
671                                                   w_requests:        2297322
672                                                   writes:             214388
673                                                   r_requests:       22639665
674                                                   reads:               88496
675                                                   handler status:
676                                                   read_key:     37803208
677                                                   read_next:  3381798717
678                                                   read_rnd      43876818
679                                                   read_first:     446022
680                                                   write:       351416153
681                                                   delete          149508
682                                                   update:       39126089
683                                                   Table status:
684                                                   Opened tables:       3712
685                                                   Open tables:         1024
686                                                   Open files:          1711
687                                                   Open streams:           0
688                                                   Alarm status:
689                                                   Active alarms:   15
690                                                   Max used alarms: 46
691                                                   Next alarm time: 28515
692                                                   Thread database.table_name          Locked/Waiting        Lock_type
693                                                   341759  mpb_wordpress.wp_TABLE_STATILocked - write        Highest priority write lock
694                                                   Memory status:
695                                                   Non-mmapped space allocated from system: 94777344
696                                                   Number of free chunks:			 369
697                                                   Number of fastbin blocks:		 0
698                                                   Number of mmapped regions:		 17
699                                                   Space in mmapped regions:		 276152320
700                                                   Maximum total allocated space:		 0
701                                                   Space available in freed fastbin blocks: 0
702                                                   Total allocated space:			 40545216
703                                                   Total free space:			 54232128
704                                                   Top-most, releasable space:		 27398512
705                                                   Estimated memory (with thread stack):    375648256
706                                                   Status information:
707                                                   Current dir: /var/lib/mysql/
708                                                   Running threads: 17  Stack size: 262144
709                                                   Current locks:
710                                                   lock: 0x41c6080:
711                                                   lock: 0x2a7ab10:
712                                                   lock: 0x29f5ba0:
713                                                   lock: 0x2c56ed0:
714                                                   lock: 0x2d32a00:
715                                                   lock: 0x2810980:
716                                                   lock: 0x22f7980:
717                                                   lock: 0x2892460:
718                                                   lock: 0x3a053a0:
719                                                   lock: 0x2534210:
720                                                   lock: 0x27d49e0:
721                                                   lock: 0x2300950:
722                                                   lock: 0x2b5f070:
723                                                   lock: 0x284c2c0:
724                                                   lock: 0x2607f30:
725                                                   lock: 0x28827c0:
726                                                   lock: 0x4388c80:
727                                                   lock: 0x39c2820:
728                                                   lock: 0x2b6c2d0:
729                                                   lock: 0x2d06870:
730                                                   lock: 0x24f1240:
731                                                   lock: 0x29ef700:
732                                                   lock: 0x2b709a0:
733                                                   lock: 0x3a746b0:
734                                                   lock: 0x2c21eb0:
735                                                   lock: 0x29de5a0:
736                                                   lock: 0x23af7f0:
737                                                   lock: 0x2e76160:
738                                                   lock: 0x3fde000:
739                                                   lock: 0x3a05c20:
740                                                   lock: 0x286a1f0:
741                                                   lock: 0x273a660:
742                                                   lock: 0x26d7250:
743                                                   lock: 0x24510a0:
744                                                   lock: 0xe2cdb0:
745                                                   lock: 0x2304710:
746                                                   lock: 0x265af50:
747                                                   lock: 0x30050c0:
748                                                   lock: 0x265a310:
749                                                   lock: 0x25ac7b0:
750                                                   lock: 0x25ab1b0:
751                                                   lock: 0x2a512f0:
752                                                   lock: 0x29a65a0:
753                                                   lock: 0x29460e0:
754                                                   lock: 0x27f0150:
755                                                   lock: 0x2cb0490:
756                                                   lock: 0x41b6e60:
757                                                   lock: 0x41b5da0:
758                                                   lock: 0x303c530:
759                                                   lock: 0x303bc70:
760                                                   lock: 0x23ba210:
761                                                   lock: 0x2d85210:
762                                                   lock: 0x413c6f0:
763                                                   lock: 0x41fa6e0:
764                                                   lock: 0x2face70:
765                                                   lock: 0x2408eb0:
766                                                   lock: 0x3fd7b30:
767                                                   lock: 0x41457e0:
768                                                   lock: 0x2aaad00deb50:
769                                                   lock: 0x2aaad00da840:
770                                                   lock: 0x2aaad00f1060:
771                                                   lock: 0x2aaad0147a10:
772                                                   lock: 0x2aaad00f26b0:
773                                                   lock: 0x3fd3940:
774                                                   lock: 0x3fd13f0:
775                                                   lock: 0x2d6a370:
776                                                   lock: 0x24f4270:
777                                                   lock: 0x4201700:
778                                                   lock: 0x26a5180:
779                                                   lock: 0x2406c90:
780                                                   lock: 0x2d83be0:
781                                                   lock: 0x2d83320:
782                                                   lock: 0x3eb7570:
783                                                   lock: 0x3eb5960:
784                                                   lock: 0x24f1b00:
785                                                   lock: 0x2f28220:
786                                                   lock: 0x2dcbdf0:
787                                                   lock: 0x2d8f880:
788                                                   lock: 0x2d8d380:
789                                                   lock: 0x3eb8b10:
790                                                   lock: 0x2a13550:
791                                                   lock: 0x2a10ef0:
792                                                   lock: 0x4285460:
793                                                   lock: 0x2a0b050:
794                                                   lock: 0x3ec41f0:
795                                                   lock: 0x3ec18c0:
796                                                   lock: 0x3ebeb00:
797                                                   lock: 0x3ebc540:
798                                                   lock: 0x2a07530:
799                                                   lock: 0x2a04500:
800                                                   lock: 0x2a00790:
801                                                   lock: 0x4058050:
802                                                   lock: 0x4054f80:
803                                                   lock: 0x4051dd0:
804                                                   lock: 0x404da00:
805                                                   lock: 0x404b5f0:
806                                                   lock: 0x4049270:
807                                                   lock: 0x4046400:
808                                                   lock: 0x4042a00:
809                                                   lock: 0x403ff50:
810                                                   Key caches:
811                                                   default
812                                                   Buffer_size:      67108864
813                                                   Block_size:           1024
814                                                   Division_limit:        100
815                                                   Age_limit:             300
816                                                   blocks used:         53585
817                                                   not flushed:             0
818                                                   w_requests:        2300317
819                                                   writes:             216679
820                                                   r_requests:       22692159
821                                                   reads:               88527
822                                                   handler status:
823                                                   read_key:     37853941
824                                                   read_next:  3387042343
825                                                   read_rnd      43886662
826                                                   read_first:     446721
827                                                   write:       351827374
828                                                   delete          149708
829                                                   update:       39127779
830                                                   Table status:
831                                                   Opened tables:       3720
832                                                   Open tables:         1024
833                                                   Open files:          1725
834                                                   Open streams:           0
835                                                   Alarm status:
836                                                   Active alarms:   17
837                                                   Max used alarms: 46
838                                                   Next alarm time: 28463
839                                                   EOF
840            1                                  4   chomp $big_arg;
841            1                                 95   $big_arg =~ s/\n+/ /g;
842                                                   
843            1                                 17   test_log_parser(
844                                                      parser => $p,
845                                                      file   => 'common/t/samples/errlogs/errlog009.txt',
846                                                      result => [
847                                                         {
848                                                            Level       => 'warning',
849                                                            pos_in_log  => '0',
850                                                            arg         => '[Warning] \'db\' entry \'test nagios@4fa060606e2d579a\' ignored in --skip-name-resolve mode.',
851                                                            ts          => '080523  7:26:27',
852                                                         },
853                                                         {
854                                                            pos_in_log  => '105',
855                                                            arg         => $big_arg,
856                                                            Level       => 'unknown',
857                                                         },
858                                                         {
859                                                            Level       => 'warning',
860                                                            pos_in_log  => '6424',
861                                                            arg         => '[Warning] \'db\' entry \'test nagios@4fa060606e2d579a\' ignored in --skip-name-resolve mode.',
862                                                            ts          => '080523  7:26:27',
863                                                         },
864                                                      ],
865                                                   );
866                                                   
867            1                                 34   test_log_parser(
868                                                      parser => $p,
869                                                      file   => 'common/t/samples/errlogs/errlog006.txt',
870                                                      result => [
871                                                            {  Level => 'unknown',
872                                                               ts    => '091119 22:27:11',
873                                                               arg =>
874                                                                  'InnoDB: Warning: cannot find a free slot for an '
875                                                                  . 'undo log. Do you have too many active transactions running '
876                                                                  . 'concurrently?',
877                                                               pos_in_log => '0'
878                                                            },
879                                                            {  Level => 'unknown',
880                                                               ts    => '091119 22:27:11',
881                                                               arg =>
882                                                                  'InnoDB: Warning: cannot find a free slot for an '
883                                                                  . 'undo log. Do you have too many active transactions running '
884                                                                  . 'concurrently?',
885                                                               pos_in_log => '233'
886                                                            },
887                                                      ],
888                                                   );
889                                                   
890            1                                184   $big_arg = <<'EOF';
891                                                   InnoDB: Warning: cannot find a free slot for an undo log. Do you have too
892                                                   many active transactions running concurrently?
893                                                   Warning: a long semaphore wait:
894                                                   --Thread 1808345440 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
895                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
896                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
897                                                   number of readers 0, waiters flag 1
898                                                   Last time read locked in file btr0sea.c line 746
899                                                   Last time write locked in file btr0cur.c line 2184
900                                                   Warning: a long semaphore wait:
901                                                   --Thread 1799514464 has waited at btr0sea.c line 489 for 242.00 seconds the semaphore:
902                                                   X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
903                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
904                                                   number of readers 0, waiters flag 1
905                                                   Last time read locked in file btr0sea.c line 746
906                                                   Last time write locked in file btr0cur.c line 2184
907                                                   Warning: a long semaphore wait:
908                                                   --Thread 1536391520 has waited at lock0lock.c line 3093 for 242.00 seconds the semaphore:
909                                                   Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
910                                                   waiters flag 1
911                                                   Warning: a long semaphore wait:
912                                                   --Thread 1829017952 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
913                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
914                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
915                                                   number of readers 0, waiters flag 1
916                                                   Last time read locked in file btr0sea.c line 746
917                                                   Last time write locked in file btr0cur.c line 2184
918                                                   Warning: a long semaphore wait:
919                                                   --Thread 1598609760 has waited at btr0sea.c line 746 for 242.00 seconds the semaphore:
920                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
921                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
922                                                   number of readers 0, waiters flag 1
923                                                   Last time read locked in file btr0sea.c line 746
924                                                   Last time write locked in file btr0cur.c line 2184
925                                                   Warning: a long semaphore wait:
926                                                   --Thread 1515411808 has waited at srv0srv.c line 1952 for 242.00 seconds the semaphore:
927                                                   Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
928                                                   waiters flag 1
929                                                   Warning: a long semaphore wait:
930                                                   --Thread 1564289376 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
931                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
932                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
933                                                   number of readers 0, waiters flag 1
934                                                   Last time read locked in file btr0sea.c line 746
935                                                   Last time write locked in file btr0cur.c line 2184
936                                                   Warning: a long semaphore wait:
937                                                   --Thread 1597606240 has waited at btr0sea.c line 1383 for 242.00 seconds the semaphore:
938                                                   X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
939                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
940                                                   number of readers 0, waiters flag 1
941                                                   Last time read locked in file btr0sea.c line 746
942                                                   Last time write locked in file btr0cur.c line 2184
943                                                   Warning: a long semaphore wait:
944                                                   --Thread 1628715360 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
945                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
946                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
947                                                   number of readers 0, waiters flag 1
948                                                   Last time read locked in file btr0sea.c line 746
949                                                   Last time write locked in file btr0cur.c line 2184
950                                                   Warning: a long semaphore wait:
951                                                   --Thread 1539602784 has waited at btr0sea.c line 916 for 242.00 seconds the semaphore:
952                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
953                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
954                                                   number of readers 0, waiters flag 1
955                                                   Last time read locked in file btr0sea.c line 746
956                                                   Last time write locked in file btr0cur.c line 2184
957                                                   Warning: a long semaphore wait:
958                                                   --Thread 1598810464 has waited at btr0sea.c line 746 for 242.00 seconds the semaphore:
959                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
960                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
961                                                   number of readers 0, waiters flag 1
962                                                   Last time read locked in file btr0sea.c line 746
963                                                   Last time write locked in file btr0cur.c line 2184
964                                                   Warning: a long semaphore wait:
965                                                   --Thread 1795098976 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
966                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
967                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
968                                                   number of readers 0, waiters flag 1
969                                                   Last time read locked in file btr0sea.c line 746
970                                                   Last time write locked in file btr0cur.c line 2184
971                                                   Warning: a long semaphore wait:
972                                                   --Thread 1565895008 has waited at btr0sea.c line 916 for 242.00 seconds the semaphore:
973                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
974                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
975                                                   number of readers 0, waiters flag 1
976                                                   Last time read locked in file btr0sea.c line 746
977                                                   Last time write locked in file btr0cur.c line 2184
978                                                   Warning: a long semaphore wait:
979                                                   --Thread 1634335072 has waited at row0sel.c line 3326 for 242.00 seconds the semaphore:
980                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
981                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
982                                                   number of readers 0, waiters flag 1
983                                                   Last time read locked in file btr0sea.c line 746
984                                                   Last time write locked in file btr0cur.c line 2184
985                                                   Warning: a long semaphore wait:
986                                                   --Thread 1582954848 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
987                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
988                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
989                                                   number of readers 0, waiters flag 1
990                                                   Last time read locked in file btr0sea.c line 746
991                                                   Last time write locked in file btr0cur.c line 2184
992                                                   Warning: a long semaphore wait:
993                                                   --Thread 1548433760 has waited at btr0sea.c line 746 for 242.00 seconds the semaphore:
994                                                   S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
995                                                   a writer (thread id 1799514464) has reserved it in mode  wait exclusive
996                                                   number of readers 0, waiters flag 1
997                                                   Last time read locked in file btr0sea.c line 746
998                                                   Last time write locked in file btr0cur.c line 2184
999                                                   Warning: a long semaphore wait:
1000                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 242.00 seconds the semaphore:
1001                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1002                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1003                                                  number of readers 0, waiters flag 1
1004                                                  Last time read locked in file btr0sea.c line 746
1005                                                  Last time write locked in file btr0cur.c line 2184
1006                                                  Warning: a long semaphore wait:
1007                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 242.00 seconds the semaphore:
1008                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1009                                                  waiters flag 1
1010                                                  Warning: a long semaphore wait:
1011                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 242.00 seconds the semaphore:
1012                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1013                                                  waiters flag 1
1014                                                  Warning: a long semaphore wait:
1015                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 242.00 seconds the semaphore:
1016                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1017                                                  waiters flag 1
1018                                                  Warning: a long semaphore wait:
1019                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 242.00 seconds the semaphore:
1020                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1021                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1022                                                  number of readers 0, waiters flag 1
1023                                                  Last time read locked in file btr0sea.c line 746
1024                                                  Last time write locked in file btr0cur.c line 2184
1025                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
1026                                                  Pending preads 0, pwrites 0
1027                                                  ###### Diagnostic info printed to the standard error stream
1028                                                  Warning: a long semaphore wait:
1029                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
1030                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1031                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1032                                                  number of readers 0, waiters flag 1
1033                                                  Last time read locked in file btr0sea.c line 746
1034                                                  Last time write locked in file btr0cur.c line 2184
1035                                                  Warning: a long semaphore wait:
1036                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 274.00 seconds the semaphore:
1037                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1038                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1039                                                  number of readers 0, waiters flag 1
1040                                                  Last time read locked in file btr0sea.c line 746
1041                                                  Last time write locked in file btr0cur.c line 2184
1042                                                  Warning: a long semaphore wait:
1043                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 274.00 seconds the semaphore:
1044                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1045                                                  waiters flag 1
1046                                                  Warning: a long semaphore wait:
1047                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
1048                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1049                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1050                                                  number of readers 0, waiters flag 1
1051                                                  Last time read locked in file btr0sea.c line 746
1052                                                  Last time write locked in file btr0cur.c line 2184
1053                                                  Warning: a long semaphore wait:
1054                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 274.00 seconds the semaphore:
1055                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1056                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1057                                                  number of readers 0, waiters flag 1
1058                                                  Last time read locked in file btr0sea.c line 746
1059                                                  Last time write locked in file btr0cur.c line 2184
1060                                                  Warning: a long semaphore wait:
1061                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 274.00 seconds the semaphore:
1062                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1063                                                  waiters flag 1
1064                                                  Warning: a long semaphore wait:
1065                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
1066                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1067                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1068                                                  number of readers 0, waiters flag 1
1069                                                  Last time read locked in file btr0sea.c line 746
1070                                                  Last time write locked in file btr0cur.c line 2184
1071                                                  Warning: a long semaphore wait:
1072                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 274.00 seconds the semaphore:
1073                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1074                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1075                                                  number of readers 0, waiters flag 1
1076                                                  Last time read locked in file btr0sea.c line 746
1077                                                  Last time write locked in file btr0cur.c line 2184
1078                                                  Warning: a long semaphore wait:
1079                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
1080                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1081                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1082                                                  number of readers 0, waiters flag 1
1083                                                  Last time read locked in file btr0sea.c line 746
1084                                                  Last time write locked in file btr0cur.c line 2184
1085                                                  Warning: a long semaphore wait:
1086                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 274.00 seconds the semaphore:
1087                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1088                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1089                                                  number of readers 0, waiters flag 1
1090                                                  Last time read locked in file btr0sea.c line 746
1091                                                  Last time write locked in file btr0cur.c line 2184
1092                                                  Warning: a long semaphore wait:
1093                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 274.00 seconds the semaphore:
1094                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1095                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1096                                                  number of readers 0, waiters flag 1
1097                                                  Last time read locked in file btr0sea.c line 746
1098                                                  Last time write locked in file btr0cur.c line 2184
1099                                                  Warning: a long semaphore wait:
1100                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
1101                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1102                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1103                                                  number of readers 0, waiters flag 1
1104                                                  Last time read locked in file btr0sea.c line 746
1105                                                  Last time write locked in file btr0cur.c line 2184
1106                                                  Warning: a long semaphore wait:
1107                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 274.00 seconds the semaphore:
1108                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1109                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1110                                                  number of readers 0, waiters flag 1
1111                                                  Last time read locked in file btr0sea.c line 746
1112                                                  Last time write locked in file btr0cur.c line 2184
1113                                                  Warning: a long semaphore wait:
1114                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 274.00 seconds the semaphore:
1115                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1116                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1117                                                  number of readers 0, waiters flag 1
1118                                                  Last time read locked in file btr0sea.c line 746
1119                                                  Last time write locked in file btr0cur.c line 2184
1120                                                  Warning: a long semaphore wait:
1121                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
1122                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1123                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1124                                                  number of readers 0, waiters flag 1
1125                                                  Last time read locked in file btr0sea.c line 746
1126                                                  Last time write locked in file btr0cur.c line 2184
1127                                                  Warning: a long semaphore wait:
1128                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 274.00 seconds the semaphore:
1129                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1130                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1131                                                  number of readers 0, waiters flag 1
1132                                                  Last time read locked in file btr0sea.c line 746
1133                                                  Last time write locked in file btr0cur.c line 2184
1134                                                  Warning: a long semaphore wait:
1135                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 274.00 seconds the semaphore:
1136                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1137                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1138                                                  number of readers 0, waiters flag 1
1139                                                  Last time read locked in file btr0sea.c line 746
1140                                                  Last time write locked in file btr0cur.c line 2184
1141                                                  Warning: a long semaphore wait:
1142                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 274.00 seconds the semaphore:
1143                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1144                                                  waiters flag 1
1145                                                  Warning: a long semaphore wait:
1146                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 274.00 seconds the semaphore:
1147                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1148                                                  waiters flag 1
1149                                                  Warning: a long semaphore wait:
1150                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 274.00 seconds the semaphore:
1151                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1152                                                  waiters flag 1
1153                                                  Warning: a long semaphore wait:
1154                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 274.00 seconds the semaphore:
1155                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1156                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1157                                                  number of readers 0, waiters flag 1
1158                                                  Last time read locked in file btr0sea.c line 746
1159                                                  Last time write locked in file btr0cur.c line 2184
1160                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
1161                                                  Pending preads 0, pwrites 0
1162                                                  ###### Diagnostic info printed to the standard error stream
1163                                                  Warning: a long semaphore wait:
1164                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
1165                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1166                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1167                                                  number of readers 0, waiters flag 1
1168                                                  Last time read locked in file btr0sea.c line 746
1169                                                  Last time write locked in file btr0cur.c line 2184
1170                                                  Warning: a long semaphore wait:
1171                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 306.00 seconds the semaphore:
1172                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1173                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1174                                                  number of readers 0, waiters flag 1
1175                                                  Last time read locked in file btr0sea.c line 746
1176                                                  Last time write locked in file btr0cur.c line 2184
1177                                                  Warning: a long semaphore wait:
1178                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 306.00 seconds the semaphore:
1179                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1180                                                  waiters flag 1
1181                                                  Warning: a long semaphore wait:
1182                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
1183                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1184                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1185                                                  number of readers 0, waiters flag 1
1186                                                  Last time read locked in file btr0sea.c line 746
1187                                                  Last time write locked in file btr0cur.c line 2184
1188                                                  Warning: a long semaphore wait:
1189                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 306.00 seconds the semaphore:
1190                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1191                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1192                                                  number of readers 0, waiters flag 1
1193                                                  Last time read locked in file btr0sea.c line 746
1194                                                  Last time write locked in file btr0cur.c line 2184
1195                                                  Warning: a long semaphore wait:
1196                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 306.00 seconds the semaphore:
1197                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1198                                                  waiters flag 1
1199                                                  Warning: a long semaphore wait:
1200                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
1201                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1202                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1203                                                  number of readers 0, waiters flag 1
1204                                                  Last time read locked in file btr0sea.c line 746
1205                                                  Last time write locked in file btr0cur.c line 2184
1206                                                  Warning: a long semaphore wait:
1207                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 306.00 seconds the semaphore:
1208                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1209                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1210                                                  number of readers 0, waiters flag 1
1211                                                  Last time read locked in file btr0sea.c line 746
1212                                                  Last time write locked in file btr0cur.c line 2184
1213                                                  Warning: a long semaphore wait:
1214                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
1215                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1216                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1217                                                  number of readers 0, waiters flag 1
1218                                                  Last time read locked in file btr0sea.c line 746
1219                                                  Last time write locked in file btr0cur.c line 2184
1220                                                  Warning: a long semaphore wait:
1221                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 306.00 seconds the semaphore:
1222                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1223                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1224                                                  number of readers 0, waiters flag 1
1225                                                  Last time read locked in file btr0sea.c line 746
1226                                                  Last time write locked in file btr0cur.c line 2184
1227                                                  Warning: a long semaphore wait:
1228                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 306.00 seconds the semaphore:
1229                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1230                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1231                                                  number of readers 0, waiters flag 1
1232                                                  Last time read locked in file btr0sea.c line 746
1233                                                  Last time write locked in file btr0cur.c line 2184
1234                                                  Warning: a long semaphore wait:
1235                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
1236                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1237                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1238                                                  number of readers 0, waiters flag 1
1239                                                  Last time read locked in file btr0sea.c line 746
1240                                                  Last time write locked in file btr0cur.c line 2184
1241                                                  Warning: a long semaphore wait:
1242                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 306.00 seconds the semaphore:
1243                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1244                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1245                                                  number of readers 0, waiters flag 1
1246                                                  Last time read locked in file btr0sea.c line 746
1247                                                  Last time write locked in file btr0cur.c line 2184
1248                                                  Warning: a long semaphore wait:
1249                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 306.00 seconds the semaphore:
1250                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1251                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1252                                                  number of readers 0, waiters flag 1
1253                                                  Last time read locked in file btr0sea.c line 746
1254                                                  Last time write locked in file btr0cur.c line 2184
1255                                                  Warning: a long semaphore wait:
1256                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
1257                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1258                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1259                                                  number of readers 0, waiters flag 1
1260                                                  Last time read locked in file btr0sea.c line 746
1261                                                  Last time write locked in file btr0cur.c line 2184
1262                                                  Warning: a long semaphore wait:
1263                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 306.00 seconds the semaphore:
1264                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1265                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1266                                                  number of readers 0, waiters flag 1
1267                                                  Last time read locked in file btr0sea.c line 746
1268                                                  Last time write locked in file btr0cur.c line 2184
1269                                                  Warning: a long semaphore wait:
1270                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 306.00 seconds the semaphore:
1271                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1272                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1273                                                  number of readers 0, waiters flag 1
1274                                                  Last time read locked in file btr0sea.c line 746
1275                                                  Last time write locked in file btr0cur.c line 2184
1276                                                  Warning: a long semaphore wait:
1277                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 306.00 seconds the semaphore:
1278                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1279                                                  waiters flag 1
1280                                                  Warning: a long semaphore wait:
1281                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 306.00 seconds the semaphore:
1282                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1283                                                  waiters flag 1
1284                                                  Warning: a long semaphore wait:
1285                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 306.00 seconds the semaphore:
1286                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1287                                                  waiters flag 1
1288                                                  Warning: a long semaphore wait:
1289                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 306.00 seconds the semaphore:
1290                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1291                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1292                                                  number of readers 0, waiters flag 1
1293                                                  Last time read locked in file btr0sea.c line 746
1294                                                  Last time write locked in file btr0cur.c line 2184
1295                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
1296                                                  Pending preads 0, pwrites 0
1297                                                  ###### Diagnostic info printed to the standard error stream
1298                                                  Warning: a long semaphore wait:
1299                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
1300                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1301                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1302                                                  number of readers 0, waiters flag 1
1303                                                  Last time read locked in file btr0sea.c line 746
1304                                                  Last time write locked in file btr0cur.c line 2184
1305                                                  Warning: a long semaphore wait:
1306                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 338.00 seconds the semaphore:
1307                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1308                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1309                                                  number of readers 0, waiters flag 1
1310                                                  Last time read locked in file btr0sea.c line 746
1311                                                  Last time write locked in file btr0cur.c line 2184
1312                                                  Warning: a long semaphore wait:
1313                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 338.00 seconds the semaphore:
1314                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1315                                                  waiters flag 1
1316                                                  Warning: a long semaphore wait:
1317                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
1318                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1319                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1320                                                  number of readers 0, waiters flag 1
1321                                                  Last time read locked in file btr0sea.c line 746
1322                                                  Last time write locked in file btr0cur.c line 2184
1323                                                  Warning: a long semaphore wait:
1324                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 338.00 seconds the semaphore:
1325                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1326                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1327                                                  number of readers 0, waiters flag 1
1328                                                  Last time read locked in file btr0sea.c line 746
1329                                                  Last time write locked in file btr0cur.c line 2184
1330                                                  Warning: a long semaphore wait:
1331                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 338.00 seconds the semaphore:
1332                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1333                                                  waiters flag 1
1334                                                  Warning: a long semaphore wait:
1335                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
1336                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1337                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1338                                                  number of readers 0, waiters flag 1
1339                                                  Last time read locked in file btr0sea.c line 746
1340                                                  Last time write locked in file btr0cur.c line 2184
1341                                                  Warning: a long semaphore wait:
1342                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 338.00 seconds the semaphore:
1343                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1344                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1345                                                  number of readers 0, waiters flag 1
1346                                                  Last time read locked in file btr0sea.c line 746
1347                                                  Last time write locked in file btr0cur.c line 2184
1348                                                  Warning: a long semaphore wait:
1349                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
1350                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1351                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1352                                                  number of readers 0, waiters flag 1
1353                                                  Last time read locked in file btr0sea.c line 746
1354                                                  Last time write locked in file btr0cur.c line 2184
1355                                                  Warning: a long semaphore wait:
1356                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 338.00 seconds the semaphore:
1357                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1358                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1359                                                  number of readers 0, waiters flag 1
1360                                                  Last time read locked in file btr0sea.c line 746
1361                                                  Last time write locked in file btr0cur.c line 2184
1362                                                  Warning: a long semaphore wait:
1363                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 338.00 seconds the semaphore:
1364                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1365                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1366                                                  number of readers 0, waiters flag 1
1367                                                  Last time read locked in file btr0sea.c line 746
1368                                                  Last time write locked in file btr0cur.c line 2184
1369                                                  Warning: a long semaphore wait:
1370                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
1371                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1372                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1373                                                  number of readers 0, waiters flag 1
1374                                                  Last time read locked in file btr0sea.c line 746
1375                                                  Last time write locked in file btr0cur.c line 2184
1376                                                  Warning: a long semaphore wait:
1377                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 338.00 seconds the semaphore:
1378                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1379                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1380                                                  number of readers 0, waiters flag 1
1381                                                  Last time read locked in file btr0sea.c line 746
1382                                                  Last time write locked in file btr0cur.c line 2184
1383                                                  Warning: a long semaphore wait:
1384                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 338.00 seconds the semaphore:
1385                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1386                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1387                                                  number of readers 0, waiters flag 1
1388                                                  Last time read locked in file btr0sea.c line 746
1389                                                  Last time write locked in file btr0cur.c line 2184
1390                                                  Warning: a long semaphore wait:
1391                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
1392                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1393                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1394                                                  number of readers 0, waiters flag 1
1395                                                  Last time read locked in file btr0sea.c line 746
1396                                                  Last time write locked in file btr0cur.c line 2184
1397                                                  Warning: a long semaphore wait:
1398                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 338.00 seconds the semaphore:
1399                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1400                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1401                                                  number of readers 0, waiters flag 1
1402                                                  Last time read locked in file btr0sea.c line 746
1403                                                  Last time write locked in file btr0cur.c line 2184
1404                                                  Warning: a long semaphore wait:
1405                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 338.00 seconds the semaphore:
1406                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1407                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1408                                                  number of readers 0, waiters flag 1
1409                                                  Last time read locked in file btr0sea.c line 746
1410                                                  Last time write locked in file btr0cur.c line 2184
1411                                                  Warning: a long semaphore wait:
1412                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 338.00 seconds the semaphore:
1413                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1414                                                  waiters flag 1
1415                                                  Warning: a long semaphore wait:
1416                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 338.00 seconds the semaphore:
1417                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1418                                                  waiters flag 1
1419                                                  Warning: a long semaphore wait:
1420                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 338.00 seconds the semaphore:
1421                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1422                                                  waiters flag 1
1423                                                  Warning: a long semaphore wait:
1424                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 338.00 seconds the semaphore:
1425                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1426                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1427                                                  number of readers 0, waiters flag 1
1428                                                  Last time read locked in file btr0sea.c line 746
1429                                                  Last time write locked in file btr0cur.c line 2184
1430                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
1431                                                  Pending preads 0, pwrites 0
1432                                                  ###### Diagnostic info printed to the standard error stream
1433                                                  Warning: a long semaphore wait:
1434                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
1435                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1436                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1437                                                  number of readers 0, waiters flag 1
1438                                                  Last time read locked in file btr0sea.c line 746
1439                                                  Last time write locked in file btr0cur.c line 2184
1440                                                  Warning: a long semaphore wait:
1441                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 370.00 seconds the semaphore:
1442                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1443                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1444                                                  number of readers 0, waiters flag 1
1445                                                  Last time read locked in file btr0sea.c line 746
1446                                                  Last time write locked in file btr0cur.c line 2184
1447                                                  Warning: a long semaphore wait:
1448                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 370.00 seconds the semaphore:
1449                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1450                                                  waiters flag 1
1451                                                  Warning: a long semaphore wait:
1452                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
1453                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1454                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1455                                                  number of readers 0, waiters flag 1
1456                                                  Last time read locked in file btr0sea.c line 746
1457                                                  Last time write locked in file btr0cur.c line 2184
1458                                                  Warning: a long semaphore wait:
1459                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 370.00 seconds the semaphore:
1460                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1461                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1462                                                  number of readers 0, waiters flag 1
1463                                                  Last time read locked in file btr0sea.c line 746
1464                                                  Last time write locked in file btr0cur.c line 2184
1465                                                  Warning: a long semaphore wait:
1466                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 370.00 seconds the semaphore:
1467                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1468                                                  waiters flag 1
1469                                                  Warning: a long semaphore wait:
1470                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
1471                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1472                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1473                                                  number of readers 0, waiters flag 1
1474                                                  Last time read locked in file btr0sea.c line 746
1475                                                  Last time write locked in file btr0cur.c line 2184
1476                                                  Warning: a long semaphore wait:
1477                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 370.00 seconds the semaphore:
1478                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1479                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1480                                                  number of readers 0, waiters flag 1
1481                                                  Last time read locked in file btr0sea.c line 746
1482                                                  Last time write locked in file btr0cur.c line 2184
1483                                                  Warning: a long semaphore wait:
1484                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
1485                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1486                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1487                                                  number of readers 0, waiters flag 1
1488                                                  Last time read locked in file btr0sea.c line 746
1489                                                  Last time write locked in file btr0cur.c line 2184
1490                                                  Warning: a long semaphore wait:
1491                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 370.00 seconds the semaphore:
1492                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1493                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1494                                                  number of readers 0, waiters flag 1
1495                                                  Last time read locked in file btr0sea.c line 746
1496                                                  Last time write locked in file btr0cur.c line 2184
1497                                                  Warning: a long semaphore wait:
1498                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 370.00 seconds the semaphore:
1499                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1500                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1501                                                  number of readers 0, waiters flag 1
1502                                                  Last time read locked in file btr0sea.c line 746
1503                                                  Last time write locked in file btr0cur.c line 2184
1504                                                  Warning: a long semaphore wait:
1505                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
1506                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1507                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1508                                                  number of readers 0, waiters flag 1
1509                                                  Last time read locked in file btr0sea.c line 746
1510                                                  Last time write locked in file btr0cur.c line 2184
1511                                                  Warning: a long semaphore wait:
1512                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 370.00 seconds the semaphore:
1513                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1514                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1515                                                  number of readers 0, waiters flag 1
1516                                                  Last time read locked in file btr0sea.c line 746
1517                                                  Last time write locked in file btr0cur.c line 2184
1518                                                  Warning: a long semaphore wait:
1519                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 370.00 seconds the semaphore:
1520                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1521                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1522                                                  number of readers 0, waiters flag 1
1523                                                  Last time read locked in file btr0sea.c line 746
1524                                                  Last time write locked in file btr0cur.c line 2184
1525                                                  Warning: a long semaphore wait:
1526                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
1527                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1528                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1529                                                  number of readers 0, waiters flag 1
1530                                                  Last time read locked in file btr0sea.c line 746
1531                                                  Last time write locked in file btr0cur.c line 2184
1532                                                  Warning: a long semaphore wait:
1533                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 370.00 seconds the semaphore:
1534                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1535                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1536                                                  number of readers 0, waiters flag 1
1537                                                  Last time read locked in file btr0sea.c line 746
1538                                                  Last time write locked in file btr0cur.c line 2184
1539                                                  Warning: a long semaphore wait:
1540                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 370.00 seconds the semaphore:
1541                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1542                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1543                                                  number of readers 0, waiters flag 1
1544                                                  Last time read locked in file btr0sea.c line 746
1545                                                  Last time write locked in file btr0cur.c line 2184
1546                                                  Warning: a long semaphore wait:
1547                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 370.00 seconds the semaphore:
1548                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1549                                                  waiters flag 1
1550                                                  Warning: a long semaphore wait:
1551                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 370.00 seconds the semaphore:
1552                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1553                                                  waiters flag 1
1554                                                  Warning: a long semaphore wait:
1555                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 370.00 seconds the semaphore:
1556                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1557                                                  waiters flag 1
1558                                                  Warning: a long semaphore wait:
1559                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 370.00 seconds the semaphore:
1560                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1561                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1562                                                  number of readers 0, waiters flag 1
1563                                                  Last time read locked in file btr0sea.c line 746
1564                                                  Last time write locked in file btr0cur.c line 2184
1565                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
1566                                                  Pending preads 0, pwrites 0
1567                                                  ###### Diagnostic info printed to the standard error stream
1568                                                  Warning: a long semaphore wait:
1569                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
1570                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1571                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1572                                                  number of readers 0, waiters flag 1
1573                                                  Last time read locked in file btr0sea.c line 746
1574                                                  Last time write locked in file btr0cur.c line 2184
1575                                                  Warning: a long semaphore wait:
1576                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 402.00 seconds the semaphore:
1577                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1578                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1579                                                  number of readers 0, waiters flag 1
1580                                                  Last time read locked in file btr0sea.c line 746
1581                                                  Last time write locked in file btr0cur.c line 2184
1582                                                  Warning: a long semaphore wait:
1583                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 402.00 seconds the semaphore:
1584                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1585                                                  waiters flag 1
1586                                                  Warning: a long semaphore wait:
1587                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
1588                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1589                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1590                                                  number of readers 0, waiters flag 1
1591                                                  Last time read locked in file btr0sea.c line 746
1592                                                  Last time write locked in file btr0cur.c line 2184
1593                                                  Warning: a long semaphore wait:
1594                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 402.00 seconds the semaphore:
1595                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1596                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1597                                                  number of readers 0, waiters flag 1
1598                                                  Last time read locked in file btr0sea.c line 746
1599                                                  Last time write locked in file btr0cur.c line 2184
1600                                                  Warning: a long semaphore wait:
1601                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 402.00 seconds the semaphore:
1602                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1603                                                  waiters flag 1
1604                                                  Warning: a long semaphore wait:
1605                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
1606                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1607                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1608                                                  number of readers 0, waiters flag 1
1609                                                  Last time read locked in file btr0sea.c line 746
1610                                                  Last time write locked in file btr0cur.c line 2184
1611                                                  Warning: a long semaphore wait:
1612                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 402.00 seconds the semaphore:
1613                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1614                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1615                                                  number of readers 0, waiters flag 1
1616                                                  Last time read locked in file btr0sea.c line 746
1617                                                  Last time write locked in file btr0cur.c line 2184
1618                                                  Warning: a long semaphore wait:
1619                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
1620                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1621                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1622                                                  number of readers 0, waiters flag 1
1623                                                  Last time read locked in file btr0sea.c line 746
1624                                                  Last time write locked in file btr0cur.c line 2184
1625                                                  Warning: a long semaphore wait:
1626                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 402.00 seconds the semaphore:
1627                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1628                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1629                                                  number of readers 0, waiters flag 1
1630                                                  Last time read locked in file btr0sea.c line 746
1631                                                  Last time write locked in file btr0cur.c line 2184
1632                                                  Warning: a long semaphore wait:
1633                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 402.00 seconds the semaphore:
1634                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1635                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1636                                                  number of readers 0, waiters flag 1
1637                                                  Last time read locked in file btr0sea.c line 746
1638                                                  Last time write locked in file btr0cur.c line 2184
1639                                                  Warning: a long semaphore wait:
1640                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
1641                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1642                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1643                                                  number of readers 0, waiters flag 1
1644                                                  Last time read locked in file btr0sea.c line 746
1645                                                  Last time write locked in file btr0cur.c line 2184
1646                                                  Warning: a long semaphore wait:
1647                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 402.00 seconds the semaphore:
1648                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1649                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1650                                                  number of readers 0, waiters flag 1
1651                                                  Last time read locked in file btr0sea.c line 746
1652                                                  Last time write locked in file btr0cur.c line 2184
1653                                                  Warning: a long semaphore wait:
1654                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 402.00 seconds the semaphore:
1655                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1656                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1657                                                  number of readers 0, waiters flag 1
1658                                                  Last time read locked in file btr0sea.c line 746
1659                                                  Last time write locked in file btr0cur.c line 2184
1660                                                  Warning: a long semaphore wait:
1661                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
1662                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1663                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1664                                                  number of readers 0, waiters flag 1
1665                                                  Last time read locked in file btr0sea.c line 746
1666                                                  Last time write locked in file btr0cur.c line 2184
1667                                                  Warning: a long semaphore wait:
1668                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 402.00 seconds the semaphore:
1669                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1670                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1671                                                  number of readers 0, waiters flag 1
1672                                                  Last time read locked in file btr0sea.c line 746
1673                                                  Last time write locked in file btr0cur.c line 2184
1674                                                  Warning: a long semaphore wait:
1675                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 402.00 seconds the semaphore:
1676                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1677                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1678                                                  number of readers 0, waiters flag 1
1679                                                  Last time read locked in file btr0sea.c line 746
1680                                                  Last time write locked in file btr0cur.c line 2184
1681                                                  Warning: a long semaphore wait:
1682                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 402.00 seconds the semaphore:
1683                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1684                                                  waiters flag 1
1685                                                  Warning: a long semaphore wait:
1686                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 402.00 seconds the semaphore:
1687                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1688                                                  waiters flag 1
1689                                                  Warning: a long semaphore wait:
1690                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 402.00 seconds the semaphore:
1691                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1692                                                  waiters flag 1
1693                                                  Warning: a long semaphore wait:
1694                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 402.00 seconds the semaphore:
1695                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1696                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1697                                                  number of readers 0, waiters flag 1
1698                                                  Last time read locked in file btr0sea.c line 746
1699                                                  Last time write locked in file btr0cur.c line 2184
1700                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
1701                                                  Pending preads 0, pwrites 0
1702                                                  ###### Diagnostic info printed to the standard error stream
1703                                                  Warning: a long semaphore wait:
1704                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
1705                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1706                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1707                                                  number of readers 0, waiters flag 1
1708                                                  Last time read locked in file btr0sea.c line 746
1709                                                  Last time write locked in file btr0cur.c line 2184
1710                                                  Warning: a long semaphore wait:
1711                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 434.00 seconds the semaphore:
1712                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1713                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1714                                                  number of readers 0, waiters flag 1
1715                                                  Last time read locked in file btr0sea.c line 746
1716                                                  Last time write locked in file btr0cur.c line 2184
1717                                                  Warning: a long semaphore wait:
1718                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 434.00 seconds the semaphore:
1719                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1720                                                  waiters flag 1
1721                                                  Warning: a long semaphore wait:
1722                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
1723                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1724                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1725                                                  number of readers 0, waiters flag 1
1726                                                  Last time read locked in file btr0sea.c line 746
1727                                                  Last time write locked in file btr0cur.c line 2184
1728                                                  Warning: a long semaphore wait:
1729                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 434.00 seconds the semaphore:
1730                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1731                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1732                                                  number of readers 0, waiters flag 1
1733                                                  Last time read locked in file btr0sea.c line 746
1734                                                  Last time write locked in file btr0cur.c line 2184
1735                                                  Warning: a long semaphore wait:
1736                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 434.00 seconds the semaphore:
1737                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1738                                                  waiters flag 1
1739                                                  Warning: a long semaphore wait:
1740                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
1741                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1742                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1743                                                  number of readers 0, waiters flag 1
1744                                                  Last time read locked in file btr0sea.c line 746
1745                                                  Last time write locked in file btr0cur.c line 2184
1746                                                  Warning: a long semaphore wait:
1747                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 434.00 seconds the semaphore:
1748                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1749                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1750                                                  number of readers 0, waiters flag 1
1751                                                  Last time read locked in file btr0sea.c line 746
1752                                                  Last time write locked in file btr0cur.c line 2184
1753                                                  Warning: a long semaphore wait:
1754                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
1755                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1756                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1757                                                  number of readers 0, waiters flag 1
1758                                                  Last time read locked in file btr0sea.c line 746
1759                                                  Last time write locked in file btr0cur.c line 2184
1760                                                  Warning: a long semaphore wait:
1761                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 434.00 seconds the semaphore:
1762                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1763                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1764                                                  number of readers 0, waiters flag 1
1765                                                  Last time read locked in file btr0sea.c line 746
1766                                                  Last time write locked in file btr0cur.c line 2184
1767                                                  Warning: a long semaphore wait:
1768                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 434.00 seconds the semaphore:
1769                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1770                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1771                                                  number of readers 0, waiters flag 1
1772                                                  Last time read locked in file btr0sea.c line 746
1773                                                  Last time write locked in file btr0cur.c line 2184
1774                                                  Warning: a long semaphore wait:
1775                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
1776                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1777                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1778                                                  number of readers 0, waiters flag 1
1779                                                  Last time read locked in file btr0sea.c line 746
1780                                                  Last time write locked in file btr0cur.c line 2184
1781                                                  Warning: a long semaphore wait:
1782                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 434.00 seconds the semaphore:
1783                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1784                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1785                                                  number of readers 0, waiters flag 1
1786                                                  Last time read locked in file btr0sea.c line 746
1787                                                  Last time write locked in file btr0cur.c line 2184
1788                                                  Warning: a long semaphore wait:
1789                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 434.00 seconds the semaphore:
1790                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1791                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1792                                                  number of readers 0, waiters flag 1
1793                                                  Last time read locked in file btr0sea.c line 746
1794                                                  Last time write locked in file btr0cur.c line 2184
1795                                                  Warning: a long semaphore wait:
1796                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
1797                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1798                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1799                                                  number of readers 0, waiters flag 1
1800                                                  Last time read locked in file btr0sea.c line 746
1801                                                  Last time write locked in file btr0cur.c line 2184
1802                                                  Warning: a long semaphore wait:
1803                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 434.00 seconds the semaphore:
1804                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1805                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1806                                                  number of readers 0, waiters flag 1
1807                                                  Last time read locked in file btr0sea.c line 746
1808                                                  Last time write locked in file btr0cur.c line 2184
1809                                                  Warning: a long semaphore wait:
1810                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 434.00 seconds the semaphore:
1811                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1812                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1813                                                  number of readers 0, waiters flag 1
1814                                                  Last time read locked in file btr0sea.c line 746
1815                                                  Last time write locked in file btr0cur.c line 2184
1816                                                  Warning: a long semaphore wait:
1817                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 434.00 seconds the semaphore:
1818                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1819                                                  waiters flag 1
1820                                                  Warning: a long semaphore wait:
1821                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 434.00 seconds the semaphore:
1822                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1823                                                  waiters flag 1
1824                                                  Warning: a long semaphore wait:
1825                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 434.00 seconds the semaphore:
1826                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1827                                                  waiters flag 1
1828                                                  Warning: a long semaphore wait:
1829                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 434.00 seconds the semaphore:
1830                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1831                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1832                                                  number of readers 0, waiters flag 1
1833                                                  Last time read locked in file btr0sea.c line 746
1834                                                  Last time write locked in file btr0cur.c line 2184
1835                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
1836                                                  Pending preads 0, pwrites 0
1837                                                  ###### Diagnostic info printed to the standard error stream
1838                                                  Warning: a long semaphore wait:
1839                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
1840                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1841                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1842                                                  number of readers 0, waiters flag 1
1843                                                  Last time read locked in file btr0sea.c line 746
1844                                                  Last time write locked in file btr0cur.c line 2184
1845                                                  Warning: a long semaphore wait:
1846                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 466.00 seconds the semaphore:
1847                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1848                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1849                                                  number of readers 0, waiters flag 1
1850                                                  Last time read locked in file btr0sea.c line 746
1851                                                  Last time write locked in file btr0cur.c line 2184
1852                                                  Warning: a long semaphore wait:
1853                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 466.00 seconds the semaphore:
1854                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1855                                                  waiters flag 1
1856                                                  Warning: a long semaphore wait:
1857                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
1858                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1859                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1860                                                  number of readers 0, waiters flag 1
1861                                                  Last time read locked in file btr0sea.c line 746
1862                                                  Last time write locked in file btr0cur.c line 2184
1863                                                  Warning: a long semaphore wait:
1864                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 466.00 seconds the semaphore:
1865                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1866                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1867                                                  number of readers 0, waiters flag 1
1868                                                  Last time read locked in file btr0sea.c line 746
1869                                                  Last time write locked in file btr0cur.c line 2184
1870                                                  Warning: a long semaphore wait:
1871                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 466.00 seconds the semaphore:
1872                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1873                                                  waiters flag 1
1874                                                  Warning: a long semaphore wait:
1875                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
1876                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1877                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1878                                                  number of readers 0, waiters flag 1
1879                                                  Last time read locked in file btr0sea.c line 746
1880                                                  Last time write locked in file btr0cur.c line 2184
1881                                                  Warning: a long semaphore wait:
1882                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 466.00 seconds the semaphore:
1883                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1884                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1885                                                  number of readers 0, waiters flag 1
1886                                                  Last time read locked in file btr0sea.c line 746
1887                                                  Last time write locked in file btr0cur.c line 2184
1888                                                  Warning: a long semaphore wait:
1889                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
1890                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1891                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1892                                                  number of readers 0, waiters flag 1
1893                                                  Last time read locked in file btr0sea.c line 746
1894                                                  Last time write locked in file btr0cur.c line 2184
1895                                                  Warning: a long semaphore wait:
1896                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 466.00 seconds the semaphore:
1897                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1898                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1899                                                  number of readers 0, waiters flag 1
1900                                                  Last time read locked in file btr0sea.c line 746
1901                                                  Last time write locked in file btr0cur.c line 2184
1902                                                  Warning: a long semaphore wait:
1903                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 466.00 seconds the semaphore:
1904                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1905                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1906                                                  number of readers 0, waiters flag 1
1907                                                  Last time read locked in file btr0sea.c line 746
1908                                                  Last time write locked in file btr0cur.c line 2184
1909                                                  Warning: a long semaphore wait:
1910                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
1911                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1912                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1913                                                  number of readers 0, waiters flag 1
1914                                                  Last time read locked in file btr0sea.c line 746
1915                                                  Last time write locked in file btr0cur.c line 2184
1916                                                  Warning: a long semaphore wait:
1917                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 466.00 seconds the semaphore:
1918                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1919                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1920                                                  number of readers 0, waiters flag 1
1921                                                  Last time read locked in file btr0sea.c line 746
1922                                                  Last time write locked in file btr0cur.c line 2184
1923                                                  Warning: a long semaphore wait:
1924                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 466.00 seconds the semaphore:
1925                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1926                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1927                                                  number of readers 0, waiters flag 1
1928                                                  Last time read locked in file btr0sea.c line 746
1929                                                  Last time write locked in file btr0cur.c line 2184
1930                                                  Warning: a long semaphore wait:
1931                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
1932                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1933                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1934                                                  number of readers 0, waiters flag 1
1935                                                  Last time read locked in file btr0sea.c line 746
1936                                                  Last time write locked in file btr0cur.c line 2184
1937                                                  Warning: a long semaphore wait:
1938                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 466.00 seconds the semaphore:
1939                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1940                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1941                                                  number of readers 0, waiters flag 1
1942                                                  Last time read locked in file btr0sea.c line 746
1943                                                  Last time write locked in file btr0cur.c line 2184
1944                                                  Warning: a long semaphore wait:
1945                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 466.00 seconds the semaphore:
1946                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1947                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1948                                                  number of readers 0, waiters flag 1
1949                                                  Last time read locked in file btr0sea.c line 746
1950                                                  Last time write locked in file btr0cur.c line 2184
1951                                                  Warning: a long semaphore wait:
1952                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 466.00 seconds the semaphore:
1953                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1954                                                  waiters flag 1
1955                                                  Warning: a long semaphore wait:
1956                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 466.00 seconds the semaphore:
1957                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1958                                                  waiters flag 1
1959                                                  Warning: a long semaphore wait:
1960                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 466.00 seconds the semaphore:
1961                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1962                                                  waiters flag 1
1963                                                  Warning: a long semaphore wait:
1964                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 466.00 seconds the semaphore:
1965                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1966                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1967                                                  number of readers 0, waiters flag 1
1968                                                  Last time read locked in file btr0sea.c line 746
1969                                                  Last time write locked in file btr0cur.c line 2184
1970                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
1971                                                  Pending preads 0, pwrites 0
1972                                                  ###### Diagnostic info printed to the standard error stream
1973                                                  Warning: a long semaphore wait:
1974                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
1975                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1976                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1977                                                  number of readers 0, waiters flag 1
1978                                                  Last time read locked in file btr0sea.c line 746
1979                                                  Last time write locked in file btr0cur.c line 2184
1980                                                  Warning: a long semaphore wait:
1981                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 498.00 seconds the semaphore:
1982                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1983                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1984                                                  number of readers 0, waiters flag 1
1985                                                  Last time read locked in file btr0sea.c line 746
1986                                                  Last time write locked in file btr0cur.c line 2184
1987                                                  Warning: a long semaphore wait:
1988                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 498.00 seconds the semaphore:
1989                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
1990                                                  waiters flag 1
1991                                                  Warning: a long semaphore wait:
1992                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
1993                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
1994                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
1995                                                  number of readers 0, waiters flag 1
1996                                                  Last time read locked in file btr0sea.c line 746
1997                                                  Last time write locked in file btr0cur.c line 2184
1998                                                  Warning: a long semaphore wait:
1999                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 498.00 seconds the semaphore:
2000                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2001                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2002                                                  number of readers 0, waiters flag 1
2003                                                  Last time read locked in file btr0sea.c line 746
2004                                                  Last time write locked in file btr0cur.c line 2184
2005                                                  Warning: a long semaphore wait:
2006                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 498.00 seconds the semaphore:
2007                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2008                                                  waiters flag 1
2009                                                  Warning: a long semaphore wait:
2010                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
2011                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2012                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2013                                                  number of readers 0, waiters flag 1
2014                                                  Last time read locked in file btr0sea.c line 746
2015                                                  Last time write locked in file btr0cur.c line 2184
2016                                                  Warning: a long semaphore wait:
2017                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 498.00 seconds the semaphore:
2018                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2019                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2020                                                  number of readers 0, waiters flag 1
2021                                                  Last time read locked in file btr0sea.c line 746
2022                                                  Last time write locked in file btr0cur.c line 2184
2023                                                  Warning: a long semaphore wait:
2024                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
2025                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2026                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2027                                                  number of readers 0, waiters flag 1
2028                                                  Last time read locked in file btr0sea.c line 746
2029                                                  Last time write locked in file btr0cur.c line 2184
2030                                                  Warning: a long semaphore wait:
2031                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 498.00 seconds the semaphore:
2032                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2033                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2034                                                  number of readers 0, waiters flag 1
2035                                                  Last time read locked in file btr0sea.c line 746
2036                                                  Last time write locked in file btr0cur.c line 2184
2037                                                  Warning: a long semaphore wait:
2038                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 498.00 seconds the semaphore:
2039                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2040                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2041                                                  number of readers 0, waiters flag 1
2042                                                  Last time read locked in file btr0sea.c line 746
2043                                                  Last time write locked in file btr0cur.c line 2184
2044                                                  Warning: a long semaphore wait:
2045                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
2046                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2047                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2048                                                  number of readers 0, waiters flag 1
2049                                                  Last time read locked in file btr0sea.c line 746
2050                                                  Last time write locked in file btr0cur.c line 2184
2051                                                  Warning: a long semaphore wait:
2052                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 498.00 seconds the semaphore:
2053                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2054                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2055                                                  number of readers 0, waiters flag 1
2056                                                  Last time read locked in file btr0sea.c line 746
2057                                                  Last time write locked in file btr0cur.c line 2184
2058                                                  Warning: a long semaphore wait:
2059                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 498.00 seconds the semaphore:
2060                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2061                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2062                                                  number of readers 0, waiters flag 1
2063                                                  Last time read locked in file btr0sea.c line 746
2064                                                  Last time write locked in file btr0cur.c line 2184
2065                                                  Warning: a long semaphore wait:
2066                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
2067                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2068                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2069                                                  number of readers 0, waiters flag 1
2070                                                  Last time read locked in file btr0sea.c line 746
2071                                                  Last time write locked in file btr0cur.c line 2184
2072                                                  Warning: a long semaphore wait:
2073                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 498.00 seconds the semaphore:
2074                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2075                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2076                                                  number of readers 0, waiters flag 1
2077                                                  Last time read locked in file btr0sea.c line 746
2078                                                  Last time write locked in file btr0cur.c line 2184
2079                                                  Warning: a long semaphore wait:
2080                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 498.00 seconds the semaphore:
2081                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2082                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2083                                                  number of readers 0, waiters flag 1
2084                                                  Last time read locked in file btr0sea.c line 746
2085                                                  Last time write locked in file btr0cur.c line 2184
2086                                                  Warning: a long semaphore wait:
2087                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 498.00 seconds the semaphore:
2088                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2089                                                  waiters flag 1
2090                                                  Warning: a long semaphore wait:
2091                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 498.00 seconds the semaphore:
2092                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2093                                                  waiters flag 1
2094                                                  Warning: a long semaphore wait:
2095                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 498.00 seconds the semaphore:
2096                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2097                                                  waiters flag 1
2098                                                  Warning: a long semaphore wait:
2099                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 498.00 seconds the semaphore:
2100                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2101                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2102                                                  number of readers 0, waiters flag 1
2103                                                  Last time read locked in file btr0sea.c line 746
2104                                                  Last time write locked in file btr0cur.c line 2184
2105                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
2106                                                  Pending preads 0, pwrites 0
2107                                                  ###### Diagnostic info printed to the standard error stream
2108                                                  Warning: a long semaphore wait:
2109                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
2110                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2111                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2112                                                  number of readers 0, waiters flag 1
2113                                                  Last time read locked in file btr0sea.c line 746
2114                                                  Last time write locked in file btr0cur.c line 2184
2115                                                  Warning: a long semaphore wait:
2116                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 530.00 seconds the semaphore:
2117                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2118                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2119                                                  number of readers 0, waiters flag 1
2120                                                  Last time read locked in file btr0sea.c line 746
2121                                                  Last time write locked in file btr0cur.c line 2184
2122                                                  Warning: a long semaphore wait:
2123                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 530.00 seconds the semaphore:
2124                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2125                                                  waiters flag 1
2126                                                  Warning: a long semaphore wait:
2127                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
2128                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2129                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2130                                                  number of readers 0, waiters flag 1
2131                                                  Last time read locked in file btr0sea.c line 746
2132                                                  Last time write locked in file btr0cur.c line 2184
2133                                                  Warning: a long semaphore wait:
2134                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 530.00 seconds the semaphore:
2135                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2136                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2137                                                  number of readers 0, waiters flag 1
2138                                                  Last time read locked in file btr0sea.c line 746
2139                                                  Last time write locked in file btr0cur.c line 2184
2140                                                  Warning: a long semaphore wait:
2141                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 530.00 seconds the semaphore:
2142                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2143                                                  waiters flag 1
2144                                                  Warning: a long semaphore wait:
2145                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
2146                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2147                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2148                                                  number of readers 0, waiters flag 1
2149                                                  Last time read locked in file btr0sea.c line 746
2150                                                  Last time write locked in file btr0cur.c line 2184
2151                                                  Warning: a long semaphore wait:
2152                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 530.00 seconds the semaphore:
2153                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2154                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2155                                                  number of readers 0, waiters flag 1
2156                                                  Last time read locked in file btr0sea.c line 746
2157                                                  Last time write locked in file btr0cur.c line 2184
2158                                                  Warning: a long semaphore wait:
2159                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
2160                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2161                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2162                                                  number of readers 0, waiters flag 1
2163                                                  Last time read locked in file btr0sea.c line 746
2164                                                  Last time write locked in file btr0cur.c line 2184
2165                                                  Warning: a long semaphore wait:
2166                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 530.00 seconds the semaphore:
2167                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2168                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2169                                                  number of readers 0, waiters flag 1
2170                                                  Last time read locked in file btr0sea.c line 746
2171                                                  Last time write locked in file btr0cur.c line 2184
2172                                                  Warning: a long semaphore wait:
2173                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 530.00 seconds the semaphore:
2174                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2175                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2176                                                  number of readers 0, waiters flag 1
2177                                                  Last time read locked in file btr0sea.c line 746
2178                                                  Last time write locked in file btr0cur.c line 2184
2179                                                  Warning: a long semaphore wait:
2180                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
2181                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2182                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2183                                                  number of readers 0, waiters flag 1
2184                                                  Last time read locked in file btr0sea.c line 746
2185                                                  Last time write locked in file btr0cur.c line 2184
2186                                                  Warning: a long semaphore wait:
2187                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 530.00 seconds the semaphore:
2188                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2189                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2190                                                  number of readers 0, waiters flag 1
2191                                                  Last time read locked in file btr0sea.c line 746
2192                                                  Last time write locked in file btr0cur.c line 2184
2193                                                  Warning: a long semaphore wait:
2194                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 530.00 seconds the semaphore:
2195                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2196                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2197                                                  number of readers 0, waiters flag 1
2198                                                  Last time read locked in file btr0sea.c line 746
2199                                                  Last time write locked in file btr0cur.c line 2184
2200                                                  Warning: a long semaphore wait:
2201                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
2202                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2203                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2204                                                  number of readers 0, waiters flag 1
2205                                                  Last time read locked in file btr0sea.c line 746
2206                                                  Last time write locked in file btr0cur.c line 2184
2207                                                  Warning: a long semaphore wait:
2208                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 530.00 seconds the semaphore:
2209                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2210                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2211                                                  number of readers 0, waiters flag 1
2212                                                  Last time read locked in file btr0sea.c line 746
2213                                                  Last time write locked in file btr0cur.c line 2184
2214                                                  Warning: a long semaphore wait:
2215                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 530.00 seconds the semaphore:
2216                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2217                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2218                                                  number of readers 0, waiters flag 1
2219                                                  Last time read locked in file btr0sea.c line 746
2220                                                  Last time write locked in file btr0cur.c line 2184
2221                                                  Warning: a long semaphore wait:
2222                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 530.00 seconds the semaphore:
2223                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2224                                                  waiters flag 1
2225                                                  Warning: a long semaphore wait:
2226                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 530.00 seconds the semaphore:
2227                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2228                                                  waiters flag 1
2229                                                  Warning: a long semaphore wait:
2230                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 530.00 seconds the semaphore:
2231                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2232                                                  waiters flag 1
2233                                                  Warning: a long semaphore wait:
2234                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 530.00 seconds the semaphore:
2235                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2236                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2237                                                  number of readers 0, waiters flag 1
2238                                                  Last time read locked in file btr0sea.c line 746
2239                                                  Last time write locked in file btr0cur.c line 2184
2240                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
2241                                                  Pending preads 0, pwrites 0
2242                                                  ###### Diagnostic info printed to the standard error stream
2243                                                  Warning: a long semaphore wait:
2244                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
2245                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2246                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2247                                                  number of readers 0, waiters flag 1
2248                                                  Last time read locked in file btr0sea.c line 746
2249                                                  Last time write locked in file btr0cur.c line 2184
2250                                                  Warning: a long semaphore wait:
2251                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 562.00 seconds the semaphore:
2252                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2253                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2254                                                  number of readers 0, waiters flag 1
2255                                                  Last time read locked in file btr0sea.c line 746
2256                                                  Last time write locked in file btr0cur.c line 2184
2257                                                  Warning: a long semaphore wait:
2258                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 562.00 seconds the semaphore:
2259                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2260                                                  waiters flag 1
2261                                                  Warning: a long semaphore wait:
2262                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
2263                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2264                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2265                                                  number of readers 0, waiters flag 1
2266                                                  Last time read locked in file btr0sea.c line 746
2267                                                  Last time write locked in file btr0cur.c line 2184
2268                                                  Warning: a long semaphore wait:
2269                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 562.00 seconds the semaphore:
2270                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2271                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2272                                                  number of readers 0, waiters flag 1
2273                                                  Last time read locked in file btr0sea.c line 746
2274                                                  Last time write locked in file btr0cur.c line 2184
2275                                                  Warning: a long semaphore wait:
2276                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 562.00 seconds the semaphore:
2277                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2278                                                  waiters flag 1
2279                                                  Warning: a long semaphore wait:
2280                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
2281                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2282                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2283                                                  number of readers 0, waiters flag 1
2284                                                  Last time read locked in file btr0sea.c line 746
2285                                                  Last time write locked in file btr0cur.c line 2184
2286                                                  Warning: a long semaphore wait:
2287                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 562.00 seconds the semaphore:
2288                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2289                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2290                                                  number of readers 0, waiters flag 1
2291                                                  Last time read locked in file btr0sea.c line 746
2292                                                  Last time write locked in file btr0cur.c line 2184
2293                                                  Warning: a long semaphore wait:
2294                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
2295                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2296                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2297                                                  number of readers 0, waiters flag 1
2298                                                  Last time read locked in file btr0sea.c line 746
2299                                                  Last time write locked in file btr0cur.c line 2184
2300                                                  Warning: a long semaphore wait:
2301                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 562.00 seconds the semaphore:
2302                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2303                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2304                                                  number of readers 0, waiters flag 1
2305                                                  Last time read locked in file btr0sea.c line 746
2306                                                  Last time write locked in file btr0cur.c line 2184
2307                                                  Warning: a long semaphore wait:
2308                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 562.00 seconds the semaphore:
2309                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2310                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2311                                                  number of readers 0, waiters flag 1
2312                                                  Last time read locked in file btr0sea.c line 746
2313                                                  Last time write locked in file btr0cur.c line 2184
2314                                                  Warning: a long semaphore wait:
2315                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
2316                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2317                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2318                                                  number of readers 0, waiters flag 1
2319                                                  Last time read locked in file btr0sea.c line 746
2320                                                  Last time write locked in file btr0cur.c line 2184
2321                                                  Warning: a long semaphore wait:
2322                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 562.00 seconds the semaphore:
2323                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2324                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2325                                                  number of readers 0, waiters flag 1
2326                                                  Last time read locked in file btr0sea.c line 746
2327                                                  Last time write locked in file btr0cur.c line 2184
2328                                                  Warning: a long semaphore wait:
2329                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 562.00 seconds the semaphore:
2330                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2331                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2332                                                  number of readers 0, waiters flag 1
2333                                                  Last time read locked in file btr0sea.c line 746
2334                                                  Last time write locked in file btr0cur.c line 2184
2335                                                  Warning: a long semaphore wait:
2336                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
2337                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2338                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2339                                                  number of readers 0, waiters flag 1
2340                                                  Last time read locked in file btr0sea.c line 746
2341                                                  Last time write locked in file btr0cur.c line 2184
2342                                                  Warning: a long semaphore wait:
2343                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 562.00 seconds the semaphore:
2344                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2345                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2346                                                  number of readers 0, waiters flag 1
2347                                                  Last time read locked in file btr0sea.c line 746
2348                                                  Last time write locked in file btr0cur.c line 2184
2349                                                  Warning: a long semaphore wait:
2350                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 562.00 seconds the semaphore:
2351                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2352                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2353                                                  number of readers 0, waiters flag 1
2354                                                  Last time read locked in file btr0sea.c line 746
2355                                                  Last time write locked in file btr0cur.c line 2184
2356                                                  Warning: a long semaphore wait:
2357                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 562.00 seconds the semaphore:
2358                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2359                                                  waiters flag 1
2360                                                  Warning: a long semaphore wait:
2361                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 562.00 seconds the semaphore:
2362                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2363                                                  waiters flag 1
2364                                                  Warning: a long semaphore wait:
2365                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 562.00 seconds the semaphore:
2366                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2367                                                  waiters flag 1
2368                                                  Warning: a long semaphore wait:
2369                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 562.00 seconds the semaphore:
2370                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2371                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2372                                                  number of readers 0, waiters flag 1
2373                                                  Last time read locked in file btr0sea.c line 746
2374                                                  Last time write locked in file btr0cur.c line 2184
2375                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
2376                                                  Pending preads 0, pwrites 0
2377                                                  ###### Diagnostic info printed to the standard error stream
2378                                                  Warning: a long semaphore wait:
2379                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
2380                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2381                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2382                                                  number of readers 0, waiters flag 1
2383                                                  Last time read locked in file btr0sea.c line 746
2384                                                  Last time write locked in file btr0cur.c line 2184
2385                                                  Warning: a long semaphore wait:
2386                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 594.00 seconds the semaphore:
2387                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2388                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2389                                                  number of readers 0, waiters flag 1
2390                                                  Last time read locked in file btr0sea.c line 746
2391                                                  Last time write locked in file btr0cur.c line 2184
2392                                                  Warning: a long semaphore wait:
2393                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 594.00 seconds the semaphore:
2394                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2395                                                  waiters flag 1
2396                                                  Warning: a long semaphore wait:
2397                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
2398                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2399                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2400                                                  number of readers 0, waiters flag 1
2401                                                  Last time read locked in file btr0sea.c line 746
2402                                                  Last time write locked in file btr0cur.c line 2184
2403                                                  Warning: a long semaphore wait:
2404                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 594.00 seconds the semaphore:
2405                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2406                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2407                                                  number of readers 0, waiters flag 1
2408                                                  Last time read locked in file btr0sea.c line 746
2409                                                  Last time write locked in file btr0cur.c line 2184
2410                                                  Warning: a long semaphore wait:
2411                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 594.00 seconds the semaphore:
2412                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2413                                                  waiters flag 1
2414                                                  Warning: a long semaphore wait:
2415                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
2416                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2417                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2418                                                  number of readers 0, waiters flag 1
2419                                                  Last time read locked in file btr0sea.c line 746
2420                                                  Last time write locked in file btr0cur.c line 2184
2421                                                  Warning: a long semaphore wait:
2422                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 594.00 seconds the semaphore:
2423                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2424                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2425                                                  number of readers 0, waiters flag 1
2426                                                  Last time read locked in file btr0sea.c line 746
2427                                                  Last time write locked in file btr0cur.c line 2184
2428                                                  Warning: a long semaphore wait:
2429                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
2430                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2431                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2432                                                  number of readers 0, waiters flag 1
2433                                                  Last time read locked in file btr0sea.c line 746
2434                                                  Last time write locked in file btr0cur.c line 2184
2435                                                  Warning: a long semaphore wait:
2436                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 594.00 seconds the semaphore:
2437                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2438                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2439                                                  number of readers 0, waiters flag 1
2440                                                  Last time read locked in file btr0sea.c line 746
2441                                                  Last time write locked in file btr0cur.c line 2184
2442                                                  Warning: a long semaphore wait:
2443                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 594.00 seconds the semaphore:
2444                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2445                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2446                                                  number of readers 0, waiters flag 1
2447                                                  Last time read locked in file btr0sea.c line 746
2448                                                  Last time write locked in file btr0cur.c line 2184
2449                                                  Warning: a long semaphore wait:
2450                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
2451                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2452                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2453                                                  number of readers 0, waiters flag 1
2454                                                  Last time read locked in file btr0sea.c line 746
2455                                                  Last time write locked in file btr0cur.c line 2184
2456                                                  Warning: a long semaphore wait:
2457                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 594.00 seconds the semaphore:
2458                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2459                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2460                                                  number of readers 0, waiters flag 1
2461                                                  Last time read locked in file btr0sea.c line 746
2462                                                  Last time write locked in file btr0cur.c line 2184
2463                                                  Warning: a long semaphore wait:
2464                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 594.00 seconds the semaphore:
2465                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2466                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2467                                                  number of readers 0, waiters flag 1
2468                                                  Last time read locked in file btr0sea.c line 746
2469                                                  Last time write locked in file btr0cur.c line 2184
2470                                                  Warning: a long semaphore wait:
2471                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
2472                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2473                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2474                                                  number of readers 0, waiters flag 1
2475                                                  Last time read locked in file btr0sea.c line 746
2476                                                  Last time write locked in file btr0cur.c line 2184
2477                                                  Warning: a long semaphore wait:
2478                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 594.00 seconds the semaphore:
2479                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2480                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2481                                                  number of readers 0, waiters flag 1
2482                                                  Last time read locked in file btr0sea.c line 746
2483                                                  Last time write locked in file btr0cur.c line 2184
2484                                                  Warning: a long semaphore wait:
2485                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 594.00 seconds the semaphore:
2486                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2487                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2488                                                  number of readers 0, waiters flag 1
2489                                                  Last time read locked in file btr0sea.c line 746
2490                                                  Last time write locked in file btr0cur.c line 2184
2491                                                  Warning: a long semaphore wait:
2492                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 594.00 seconds the semaphore:
2493                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2494                                                  waiters flag 1
2495                                                  Warning: a long semaphore wait:
2496                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 594.00 seconds the semaphore:
2497                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2498                                                  waiters flag 1
2499                                                  Warning: a long semaphore wait:
2500                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 594.00 seconds the semaphore:
2501                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2502                                                  waiters flag 1
2503                                                  Warning: a long semaphore wait:
2504                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 594.00 seconds the semaphore:
2505                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2506                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2507                                                  number of readers 0, waiters flag 1
2508                                                  Last time read locked in file btr0sea.c line 746
2509                                                  Last time write locked in file btr0cur.c line 2184
2510                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
2511                                                  Pending preads 0, pwrites 0
2512                                                  ###### Diagnostic info printed to the standard error stream
2513                                                  Warning: a long semaphore wait:
2514                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
2515                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2516                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2517                                                  number of readers 0, waiters flag 1
2518                                                  Last time read locked in file btr0sea.c line 746
2519                                                  Last time write locked in file btr0cur.c line 2184
2520                                                  Warning: a long semaphore wait:
2521                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 626.00 seconds the semaphore:
2522                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2523                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2524                                                  number of readers 0, waiters flag 1
2525                                                  Last time read locked in file btr0sea.c line 746
2526                                                  Last time write locked in file btr0cur.c line 2184
2527                                                  Warning: a long semaphore wait:
2528                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 626.00 seconds the semaphore:
2529                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2530                                                  waiters flag 1
2531                                                  Warning: a long semaphore wait:
2532                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
2533                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2534                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2535                                                  number of readers 0, waiters flag 1
2536                                                  Last time read locked in file btr0sea.c line 746
2537                                                  Last time write locked in file btr0cur.c line 2184
2538                                                  Warning: a long semaphore wait:
2539                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 626.00 seconds the semaphore:
2540                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2541                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2542                                                  number of readers 0, waiters flag 1
2543                                                  Last time read locked in file btr0sea.c line 746
2544                                                  Last time write locked in file btr0cur.c line 2184
2545                                                  Warning: a long semaphore wait:
2546                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 626.00 seconds the semaphore:
2547                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2548                                                  waiters flag 1
2549                                                  Warning: a long semaphore wait:
2550                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
2551                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2552                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2553                                                  number of readers 0, waiters flag 1
2554                                                  Last time read locked in file btr0sea.c line 746
2555                                                  Last time write locked in file btr0cur.c line 2184
2556                                                  Warning: a long semaphore wait:
2557                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 626.00 seconds the semaphore:
2558                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2559                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2560                                                  number of readers 0, waiters flag 1
2561                                                  Last time read locked in file btr0sea.c line 746
2562                                                  Last time write locked in file btr0cur.c line 2184
2563                                                  Warning: a long semaphore wait:
2564                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
2565                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2566                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2567                                                  number of readers 0, waiters flag 1
2568                                                  Last time read locked in file btr0sea.c line 746
2569                                                  Last time write locked in file btr0cur.c line 2184
2570                                                  Warning: a long semaphore wait:
2571                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 626.00 seconds the semaphore:
2572                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2573                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2574                                                  number of readers 0, waiters flag 1
2575                                                  Last time read locked in file btr0sea.c line 746
2576                                                  Last time write locked in file btr0cur.c line 2184
2577                                                  Warning: a long semaphore wait:
2578                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 626.00 seconds the semaphore:
2579                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2580                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2581                                                  number of readers 0, waiters flag 1
2582                                                  Last time read locked in file btr0sea.c line 746
2583                                                  Last time write locked in file btr0cur.c line 2184
2584                                                  Warning: a long semaphore wait:
2585                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
2586                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2587                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2588                                                  number of readers 0, waiters flag 1
2589                                                  Last time read locked in file btr0sea.c line 746
2590                                                  Last time write locked in file btr0cur.c line 2184
2591                                                  Warning: a long semaphore wait:
2592                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 626.00 seconds the semaphore:
2593                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2594                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2595                                                  number of readers 0, waiters flag 1
2596                                                  Last time read locked in file btr0sea.c line 746
2597                                                  Last time write locked in file btr0cur.c line 2184
2598                                                  Warning: a long semaphore wait:
2599                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 626.00 seconds the semaphore:
2600                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2601                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2602                                                  number of readers 0, waiters flag 1
2603                                                  Last time read locked in file btr0sea.c line 746
2604                                                  Last time write locked in file btr0cur.c line 2184
2605                                                  Warning: a long semaphore wait:
2606                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
2607                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2608                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2609                                                  number of readers 0, waiters flag 1
2610                                                  Last time read locked in file btr0sea.c line 746
2611                                                  Last time write locked in file btr0cur.c line 2184
2612                                                  Warning: a long semaphore wait:
2613                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 626.00 seconds the semaphore:
2614                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2615                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2616                                                  number of readers 0, waiters flag 1
2617                                                  Last time read locked in file btr0sea.c line 746
2618                                                  Last time write locked in file btr0cur.c line 2184
2619                                                  Warning: a long semaphore wait:
2620                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 626.00 seconds the semaphore:
2621                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2622                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2623                                                  number of readers 0, waiters flag 1
2624                                                  Last time read locked in file btr0sea.c line 746
2625                                                  Last time write locked in file btr0cur.c line 2184
2626                                                  Warning: a long semaphore wait:
2627                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 626.00 seconds the semaphore:
2628                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2629                                                  waiters flag 1
2630                                                  Warning: a long semaphore wait:
2631                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 626.00 seconds the semaphore:
2632                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2633                                                  waiters flag 1
2634                                                  Warning: a long semaphore wait:
2635                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 626.00 seconds the semaphore:
2636                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2637                                                  waiters flag 1
2638                                                  Warning: a long semaphore wait:
2639                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 626.00 seconds the semaphore:
2640                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2641                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2642                                                  number of readers 0, waiters flag 1
2643                                                  Last time read locked in file btr0sea.c line 746
2644                                                  Last time write locked in file btr0cur.c line 2184
2645                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
2646                                                  Pending preads 0, pwrites 0
2647                                                  ###### Diagnostic info printed to the standard error stream
2648                                                  Warning: a long semaphore wait:
2649                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
2650                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2651                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2652                                                  number of readers 0, waiters flag 1
2653                                                  Last time read locked in file btr0sea.c line 746
2654                                                  Last time write locked in file btr0cur.c line 2184
2655                                                  Warning: a long semaphore wait:
2656                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 661.00 seconds the semaphore:
2657                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2658                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2659                                                  number of readers 0, waiters flag 1
2660                                                  Last time read locked in file btr0sea.c line 746
2661                                                  Last time write locked in file btr0cur.c line 2184
2662                                                  Warning: a long semaphore wait:
2663                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 661.00 seconds the semaphore:
2664                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2665                                                  waiters flag 1
2666                                                  Warning: a long semaphore wait:
2667                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
2668                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2669                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2670                                                  number of readers 0, waiters flag 1
2671                                                  Last time read locked in file btr0sea.c line 746
2672                                                  Last time write locked in file btr0cur.c line 2184
2673                                                  Warning: a long semaphore wait:
2674                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 661.00 seconds the semaphore:
2675                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2676                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2677                                                  number of readers 0, waiters flag 1
2678                                                  Last time read locked in file btr0sea.c line 746
2679                                                  Last time write locked in file btr0cur.c line 2184
2680                                                  Warning: a long semaphore wait:
2681                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 661.00 seconds the semaphore:
2682                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2683                                                  waiters flag 1
2684                                                  Warning: a long semaphore wait:
2685                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
2686                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2687                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2688                                                  number of readers 0, waiters flag 1
2689                                                  Last time read locked in file btr0sea.c line 746
2690                                                  Last time write locked in file btr0cur.c line 2184
2691                                                  Warning: a long semaphore wait:
2692                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 661.00 seconds the semaphore:
2693                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2694                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2695                                                  number of readers 0, waiters flag 1
2696                                                  Last time read locked in file btr0sea.c line 746
2697                                                  Last time write locked in file btr0cur.c line 2184
2698                                                  Warning: a long semaphore wait:
2699                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
2700                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2701                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2702                                                  number of readers 0, waiters flag 1
2703                                                  Last time read locked in file btr0sea.c line 746
2704                                                  Last time write locked in file btr0cur.c line 2184
2705                                                  Warning: a long semaphore wait:
2706                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 661.00 seconds the semaphore:
2707                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2708                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2709                                                  number of readers 0, waiters flag 1
2710                                                  Last time read locked in file btr0sea.c line 746
2711                                                  Last time write locked in file btr0cur.c line 2184
2712                                                  Warning: a long semaphore wait:
2713                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 661.00 seconds the semaphore:
2714                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2715                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2716                                                  number of readers 0, waiters flag 1
2717                                                  Last time read locked in file btr0sea.c line 746
2718                                                  Last time write locked in file btr0cur.c line 2184
2719                                                  Warning: a long semaphore wait:
2720                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
2721                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2722                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2723                                                  number of readers 0, waiters flag 1
2724                                                  Last time read locked in file btr0sea.c line 746
2725                                                  Last time write locked in file btr0cur.c line 2184
2726                                                  Warning: a long semaphore wait:
2727                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 661.00 seconds the semaphore:
2728                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2729                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2730                                                  number of readers 0, waiters flag 1
2731                                                  Last time read locked in file btr0sea.c line 746
2732                                                  Last time write locked in file btr0cur.c line 2184
2733                                                  Warning: a long semaphore wait:
2734                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 661.00 seconds the semaphore:
2735                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2736                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2737                                                  number of readers 0, waiters flag 1
2738                                                  Last time read locked in file btr0sea.c line 746
2739                                                  Last time write locked in file btr0cur.c line 2184
2740                                                  Warning: a long semaphore wait:
2741                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
2742                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2743                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2744                                                  number of readers 0, waiters flag 1
2745                                                  Last time read locked in file btr0sea.c line 746
2746                                                  Last time write locked in file btr0cur.c line 2184
2747                                                  Warning: a long semaphore wait:
2748                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 661.00 seconds the semaphore:
2749                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2750                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2751                                                  number of readers 0, waiters flag 1
2752                                                  Last time read locked in file btr0sea.c line 746
2753                                                  Last time write locked in file btr0cur.c line 2184
2754                                                  Warning: a long semaphore wait:
2755                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 661.00 seconds the semaphore:
2756                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2757                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2758                                                  number of readers 0, waiters flag 1
2759                                                  Last time read locked in file btr0sea.c line 746
2760                                                  Last time write locked in file btr0cur.c line 2184
2761                                                  Warning: a long semaphore wait:
2762                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 661.00 seconds the semaphore:
2763                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2764                                                  waiters flag 1
2765                                                  Warning: a long semaphore wait:
2766                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 661.00 seconds the semaphore:
2767                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2768                                                  waiters flag 1
2769                                                  Warning: a long semaphore wait:
2770                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 661.00 seconds the semaphore:
2771                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2772                                                  waiters flag 1
2773                                                  Warning: a long semaphore wait:
2774                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 661.00 seconds the semaphore:
2775                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2776                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2777                                                  number of readers 0, waiters flag 1
2778                                                  Last time read locked in file btr0sea.c line 746
2779                                                  Last time write locked in file btr0cur.c line 2184
2780                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
2781                                                  Pending preads 0, pwrites 0
2782                                                  ###### Diagnostic info printed to the standard error stream
2783                                                  Warning: a long semaphore wait:
2784                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
2785                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2786                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2787                                                  number of readers 0, waiters flag 1
2788                                                  Last time read locked in file btr0sea.c line 746
2789                                                  Last time write locked in file btr0cur.c line 2184
2790                                                  Warning: a long semaphore wait:
2791                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 693.00 seconds the semaphore:
2792                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2793                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2794                                                  number of readers 0, waiters flag 1
2795                                                  Last time read locked in file btr0sea.c line 746
2796                                                  Last time write locked in file btr0cur.c line 2184
2797                                                  Warning: a long semaphore wait:
2798                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 693.00 seconds the semaphore:
2799                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2800                                                  waiters flag 1
2801                                                  Warning: a long semaphore wait:
2802                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
2803                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2804                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2805                                                  number of readers 0, waiters flag 1
2806                                                  Last time read locked in file btr0sea.c line 746
2807                                                  Last time write locked in file btr0cur.c line 2184
2808                                                  Warning: a long semaphore wait:
2809                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 693.00 seconds the semaphore:
2810                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2811                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2812                                                  number of readers 0, waiters flag 1
2813                                                  Last time read locked in file btr0sea.c line 746
2814                                                  Last time write locked in file btr0cur.c line 2184
2815                                                  Warning: a long semaphore wait:
2816                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 693.00 seconds the semaphore:
2817                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2818                                                  waiters flag 1
2819                                                  Warning: a long semaphore wait:
2820                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
2821                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2822                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2823                                                  number of readers 0, waiters flag 1
2824                                                  Last time read locked in file btr0sea.c line 746
2825                                                  Last time write locked in file btr0cur.c line 2184
2826                                                  Warning: a long semaphore wait:
2827                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 693.00 seconds the semaphore:
2828                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2829                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2830                                                  number of readers 0, waiters flag 1
2831                                                  Last time read locked in file btr0sea.c line 746
2832                                                  Last time write locked in file btr0cur.c line 2184
2833                                                  Warning: a long semaphore wait:
2834                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
2835                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2836                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2837                                                  number of readers 0, waiters flag 1
2838                                                  Last time read locked in file btr0sea.c line 746
2839                                                  Last time write locked in file btr0cur.c line 2184
2840                                                  Warning: a long semaphore wait:
2841                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 693.00 seconds the semaphore:
2842                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2843                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2844                                                  number of readers 0, waiters flag 1
2845                                                  Last time read locked in file btr0sea.c line 746
2846                                                  Last time write locked in file btr0cur.c line 2184
2847                                                  Warning: a long semaphore wait:
2848                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 693.00 seconds the semaphore:
2849                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2850                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2851                                                  number of readers 0, waiters flag 1
2852                                                  Last time read locked in file btr0sea.c line 746
2853                                                  Last time write locked in file btr0cur.c line 2184
2854                                                  Warning: a long semaphore wait:
2855                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
2856                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2857                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2858                                                  number of readers 0, waiters flag 1
2859                                                  Last time read locked in file btr0sea.c line 746
2860                                                  Last time write locked in file btr0cur.c line 2184
2861                                                  Warning: a long semaphore wait:
2862                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 693.00 seconds the semaphore:
2863                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2864                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2865                                                  number of readers 0, waiters flag 1
2866                                                  Last time read locked in file btr0sea.c line 746
2867                                                  Last time write locked in file btr0cur.c line 2184
2868                                                  Warning: a long semaphore wait:
2869                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 693.00 seconds the semaphore:
2870                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2871                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2872                                                  number of readers 0, waiters flag 1
2873                                                  Last time read locked in file btr0sea.c line 746
2874                                                  Last time write locked in file btr0cur.c line 2184
2875                                                  Warning: a long semaphore wait:
2876                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
2877                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2878                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2879                                                  number of readers 0, waiters flag 1
2880                                                  Last time read locked in file btr0sea.c line 746
2881                                                  Last time write locked in file btr0cur.c line 2184
2882                                                  Warning: a long semaphore wait:
2883                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 693.00 seconds the semaphore:
2884                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2885                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2886                                                  number of readers 0, waiters flag 1
2887                                                  Last time read locked in file btr0sea.c line 746
2888                                                  Last time write locked in file btr0cur.c line 2184
2889                                                  Warning: a long semaphore wait:
2890                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 693.00 seconds the semaphore:
2891                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2892                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2893                                                  number of readers 0, waiters flag 1
2894                                                  Last time read locked in file btr0sea.c line 746
2895                                                  Last time write locked in file btr0cur.c line 2184
2896                                                  Warning: a long semaphore wait:
2897                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 693.00 seconds the semaphore:
2898                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2899                                                  waiters flag 1
2900                                                  Warning: a long semaphore wait:
2901                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 693.00 seconds the semaphore:
2902                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2903                                                  waiters flag 1
2904                                                  Warning: a long semaphore wait:
2905                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 693.00 seconds the semaphore:
2906                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2907                                                  waiters flag 1
2908                                                  Warning: a long semaphore wait:
2909                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 693.00 seconds the semaphore:
2910                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2911                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2912                                                  number of readers 0, waiters flag 1
2913                                                  Last time read locked in file btr0sea.c line 746
2914                                                  Last time write locked in file btr0cur.c line 2184
2915                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
2916                                                  Pending preads 0, pwrites 0
2917                                                  ###### Diagnostic info printed to the standard error stream
2918                                                  Warning: a long semaphore wait:
2919                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
2920                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2921                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2922                                                  number of readers 0, waiters flag 1
2923                                                  Last time read locked in file btr0sea.c line 746
2924                                                  Last time write locked in file btr0cur.c line 2184
2925                                                  Warning: a long semaphore wait:
2926                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 725.00 seconds the semaphore:
2927                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2928                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2929                                                  number of readers 0, waiters flag 1
2930                                                  Last time read locked in file btr0sea.c line 746
2931                                                  Last time write locked in file btr0cur.c line 2184
2932                                                  Warning: a long semaphore wait:
2933                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 725.00 seconds the semaphore:
2934                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2935                                                  waiters flag 1
2936                                                  Warning: a long semaphore wait:
2937                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
2938                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2939                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2940                                                  number of readers 0, waiters flag 1
2941                                                  Last time read locked in file btr0sea.c line 746
2942                                                  Last time write locked in file btr0cur.c line 2184
2943                                                  Warning: a long semaphore wait:
2944                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 725.00 seconds the semaphore:
2945                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2946                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2947                                                  number of readers 0, waiters flag 1
2948                                                  Last time read locked in file btr0sea.c line 746
2949                                                  Last time write locked in file btr0cur.c line 2184
2950                                                  Warning: a long semaphore wait:
2951                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 725.00 seconds the semaphore:
2952                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
2953                                                  waiters flag 1
2954                                                  Warning: a long semaphore wait:
2955                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
2956                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2957                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2958                                                  number of readers 0, waiters flag 1
2959                                                  Last time read locked in file btr0sea.c line 746
2960                                                  Last time write locked in file btr0cur.c line 2184
2961                                                  Warning: a long semaphore wait:
2962                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 725.00 seconds the semaphore:
2963                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2964                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2965                                                  number of readers 0, waiters flag 1
2966                                                  Last time read locked in file btr0sea.c line 746
2967                                                  Last time write locked in file btr0cur.c line 2184
2968                                                  Warning: a long semaphore wait:
2969                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
2970                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2971                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2972                                                  number of readers 0, waiters flag 1
2973                                                  Last time read locked in file btr0sea.c line 746
2974                                                  Last time write locked in file btr0cur.c line 2184
2975                                                  Warning: a long semaphore wait:
2976                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 725.00 seconds the semaphore:
2977                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2978                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2979                                                  number of readers 0, waiters flag 1
2980                                                  Last time read locked in file btr0sea.c line 746
2981                                                  Last time write locked in file btr0cur.c line 2184
2982                                                  Warning: a long semaphore wait:
2983                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 725.00 seconds the semaphore:
2984                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2985                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2986                                                  number of readers 0, waiters flag 1
2987                                                  Last time read locked in file btr0sea.c line 746
2988                                                  Last time write locked in file btr0cur.c line 2184
2989                                                  Warning: a long semaphore wait:
2990                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
2991                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2992                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
2993                                                  number of readers 0, waiters flag 1
2994                                                  Last time read locked in file btr0sea.c line 746
2995                                                  Last time write locked in file btr0cur.c line 2184
2996                                                  Warning: a long semaphore wait:
2997                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 725.00 seconds the semaphore:
2998                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
2999                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3000                                                  number of readers 0, waiters flag 1
3001                                                  Last time read locked in file btr0sea.c line 746
3002                                                  Last time write locked in file btr0cur.c line 2184
3003                                                  Warning: a long semaphore wait:
3004                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 725.00 seconds the semaphore:
3005                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3006                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3007                                                  number of readers 0, waiters flag 1
3008                                                  Last time read locked in file btr0sea.c line 746
3009                                                  Last time write locked in file btr0cur.c line 2184
3010                                                  Warning: a long semaphore wait:
3011                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
3012                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3013                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3014                                                  number of readers 0, waiters flag 1
3015                                                  Last time read locked in file btr0sea.c line 746
3016                                                  Last time write locked in file btr0cur.c line 2184
3017                                                  Warning: a long semaphore wait:
3018                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 725.00 seconds the semaphore:
3019                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3020                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3021                                                  number of readers 0, waiters flag 1
3022                                                  Last time read locked in file btr0sea.c line 746
3023                                                  Last time write locked in file btr0cur.c line 2184
3024                                                  Warning: a long semaphore wait:
3025                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 725.00 seconds the semaphore:
3026                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3027                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3028                                                  number of readers 0, waiters flag 1
3029                                                  Last time read locked in file btr0sea.c line 746
3030                                                  Last time write locked in file btr0cur.c line 2184
3031                                                  Warning: a long semaphore wait:
3032                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 725.00 seconds the semaphore:
3033                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3034                                                  waiters flag 1
3035                                                  Warning: a long semaphore wait:
3036                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 725.00 seconds the semaphore:
3037                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3038                                                  waiters flag 1
3039                                                  Warning: a long semaphore wait:
3040                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 725.00 seconds the semaphore:
3041                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3042                                                  waiters flag 1
3043                                                  Warning: a long semaphore wait:
3044                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 725.00 seconds the semaphore:
3045                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3046                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3047                                                  number of readers 0, waiters flag 1
3048                                                  Last time read locked in file btr0sea.c line 746
3049                                                  Last time write locked in file btr0cur.c line 2184
3050                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
3051                                                  Pending preads 0, pwrites 0
3052                                                  ###### Diagnostic info printed to the standard error stream
3053                                                  Warning: a long semaphore wait:
3054                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
3055                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3056                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3057                                                  number of readers 0, waiters flag 1
3058                                                  Last time read locked in file btr0sea.c line 746
3059                                                  Last time write locked in file btr0cur.c line 2184
3060                                                  Warning: a long semaphore wait:
3061                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 757.00 seconds the semaphore:
3062                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3063                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3064                                                  number of readers 0, waiters flag 1
3065                                                  Last time read locked in file btr0sea.c line 746
3066                                                  Last time write locked in file btr0cur.c line 2184
3067                                                  Warning: a long semaphore wait:
3068                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 757.00 seconds the semaphore:
3069                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3070                                                  waiters flag 1
3071                                                  Warning: a long semaphore wait:
3072                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
3073                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3074                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3075                                                  number of readers 0, waiters flag 1
3076                                                  Last time read locked in file btr0sea.c line 746
3077                                                  Last time write locked in file btr0cur.c line 2184
3078                                                  Warning: a long semaphore wait:
3079                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 757.00 seconds the semaphore:
3080                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3081                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3082                                                  number of readers 0, waiters flag 1
3083                                                  Last time read locked in file btr0sea.c line 746
3084                                                  Last time write locked in file btr0cur.c line 2184
3085                                                  Warning: a long semaphore wait:
3086                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 757.00 seconds the semaphore:
3087                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3088                                                  waiters flag 1
3089                                                  Warning: a long semaphore wait:
3090                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
3091                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3092                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3093                                                  number of readers 0, waiters flag 1
3094                                                  Last time read locked in file btr0sea.c line 746
3095                                                  Last time write locked in file btr0cur.c line 2184
3096                                                  Warning: a long semaphore wait:
3097                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 757.00 seconds the semaphore:
3098                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3099                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3100                                                  number of readers 0, waiters flag 1
3101                                                  Last time read locked in file btr0sea.c line 746
3102                                                  Last time write locked in file btr0cur.c line 2184
3103                                                  Warning: a long semaphore wait:
3104                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
3105                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3106                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3107                                                  number of readers 0, waiters flag 1
3108                                                  Last time read locked in file btr0sea.c line 746
3109                                                  Last time write locked in file btr0cur.c line 2184
3110                                                  Warning: a long semaphore wait:
3111                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 757.00 seconds the semaphore:
3112                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3113                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3114                                                  number of readers 0, waiters flag 1
3115                                                  Last time read locked in file btr0sea.c line 746
3116                                                  Last time write locked in file btr0cur.c line 2184
3117                                                  Warning: a long semaphore wait:
3118                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 757.00 seconds the semaphore:
3119                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3120                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3121                                                  number of readers 0, waiters flag 1
3122                                                  Last time read locked in file btr0sea.c line 746
3123                                                  Last time write locked in file btr0cur.c line 2184
3124                                                  Warning: a long semaphore wait:
3125                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
3126                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3127                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3128                                                  number of readers 0, waiters flag 1
3129                                                  Last time read locked in file btr0sea.c line 746
3130                                                  Last time write locked in file btr0cur.c line 2184
3131                                                  Warning: a long semaphore wait:
3132                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 757.00 seconds the semaphore:
3133                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3134                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3135                                                  number of readers 0, waiters flag 1
3136                                                  Last time read locked in file btr0sea.c line 746
3137                                                  Last time write locked in file btr0cur.c line 2184
3138                                                  Warning: a long semaphore wait:
3139                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 757.00 seconds the semaphore:
3140                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3141                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3142                                                  number of readers 0, waiters flag 1
3143                                                  Last time read locked in file btr0sea.c line 746
3144                                                  Last time write locked in file btr0cur.c line 2184
3145                                                  Warning: a long semaphore wait:
3146                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
3147                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3148                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3149                                                  number of readers 0, waiters flag 1
3150                                                  Last time read locked in file btr0sea.c line 746
3151                                                  Last time write locked in file btr0cur.c line 2184
3152                                                  Warning: a long semaphore wait:
3153                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 757.00 seconds the semaphore:
3154                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3155                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3156                                                  number of readers 0, waiters flag 1
3157                                                  Last time read locked in file btr0sea.c line 746
3158                                                  Last time write locked in file btr0cur.c line 2184
3159                                                  Warning: a long semaphore wait:
3160                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 757.00 seconds the semaphore:
3161                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3162                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3163                                                  number of readers 0, waiters flag 1
3164                                                  Last time read locked in file btr0sea.c line 746
3165                                                  Last time write locked in file btr0cur.c line 2184
3166                                                  Warning: a long semaphore wait:
3167                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 757.00 seconds the semaphore:
3168                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3169                                                  waiters flag 1
3170                                                  Warning: a long semaphore wait:
3171                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 757.00 seconds the semaphore:
3172                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3173                                                  waiters flag 1
3174                                                  Warning: a long semaphore wait:
3175                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 757.00 seconds the semaphore:
3176                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3177                                                  waiters flag 1
3178                                                  Warning: a long semaphore wait:
3179                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 757.00 seconds the semaphore:
3180                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3181                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3182                                                  number of readers 0, waiters flag 1
3183                                                  Last time read locked in file btr0sea.c line 746
3184                                                  Last time write locked in file btr0cur.c line 2184
3185                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
3186                                                  Pending preads 0, pwrites 0
3187                                                  ###### Diagnostic info printed to the standard error stream
3188                                                  Warning: a long semaphore wait:
3189                                                  --Thread 1808345440 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
3190                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3191                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3192                                                  number of readers 0, waiters flag 1
3193                                                  Last time read locked in file btr0sea.c line 746
3194                                                  Last time write locked in file btr0cur.c line 2184
3195                                                  Warning: a long semaphore wait:
3196                                                  --Thread 1799514464 has waited at btr0sea.c line 489 for 789.00 seconds the semaphore:
3197                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3198                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3199                                                  number of readers 0, waiters flag 1
3200                                                  Last time read locked in file btr0sea.c line 746
3201                                                  Last time write locked in file btr0cur.c line 2184
3202                                                  Warning: a long semaphore wait:
3203                                                  --Thread 1536391520 has waited at lock0lock.c line 3093 for 789.00 seconds the semaphore:
3204                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3205                                                  waiters flag 1
3206                                                  Warning: a long semaphore wait:
3207                                                  --Thread 1829017952 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
3208                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3209                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3210                                                  number of readers 0, waiters flag 1
3211                                                  Last time read locked in file btr0sea.c line 746
3212                                                  Last time write locked in file btr0cur.c line 2184
3213                                                  Warning: a long semaphore wait:
3214                                                  --Thread 1598609760 has waited at btr0sea.c line 746 for 789.00 seconds the semaphore:
3215                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3216                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3217                                                  number of readers 0, waiters flag 1
3218                                                  Last time read locked in file btr0sea.c line 746
3219                                                  Last time write locked in file btr0cur.c line 2184
3220                                                  Warning: a long semaphore wait:
3221                                                  --Thread 1515411808 has waited at srv0srv.c line 1952 for 789.00 seconds the semaphore:
3222                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3223                                                  waiters flag 1
3224                                                  Warning: a long semaphore wait:
3225                                                  --Thread 1564289376 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
3226                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3227                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3228                                                  number of readers 0, waiters flag 1
3229                                                  Last time read locked in file btr0sea.c line 746
3230                                                  Last time write locked in file btr0cur.c line 2184
3231                                                  Warning: a long semaphore wait:
3232                                                  --Thread 1597606240 has waited at btr0sea.c line 1383 for 789.00 seconds the semaphore:
3233                                                  X-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3234                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3235                                                  number of readers 0, waiters flag 1
3236                                                  Last time read locked in file btr0sea.c line 746
3237                                                  Last time write locked in file btr0cur.c line 2184
3238                                                  Warning: a long semaphore wait:
3239                                                  --Thread 1628715360 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
3240                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3241                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3242                                                  number of readers 0, waiters flag 1
3243                                                  Last time read locked in file btr0sea.c line 746
3244                                                  Last time write locked in file btr0cur.c line 2184
3245                                                  Warning: a long semaphore wait:
3246                                                  --Thread 1539602784 has waited at btr0sea.c line 916 for 789.00 seconds the semaphore:
3247                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3248                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3249                                                  number of readers 0, waiters flag 1
3250                                                  Last time read locked in file btr0sea.c line 746
3251                                                  Last time write locked in file btr0cur.c line 2184
3252                                                  Warning: a long semaphore wait:
3253                                                  --Thread 1598810464 has waited at btr0sea.c line 746 for 789.00 seconds the semaphore:
3254                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3255                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3256                                                  number of readers 0, waiters flag 1
3257                                                  Last time read locked in file btr0sea.c line 746
3258                                                  Last time write locked in file btr0cur.c line 2184
3259                                                  Warning: a long semaphore wait:
3260                                                  --Thread 1795098976 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
3261                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3262                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3263                                                  number of readers 0, waiters flag 1
3264                                                  Last time read locked in file btr0sea.c line 746
3265                                                  Last time write locked in file btr0cur.c line 2184
3266                                                  Warning: a long semaphore wait:
3267                                                  --Thread 1565895008 has waited at btr0sea.c line 916 for 789.00 seconds the semaphore:
3268                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3269                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3270                                                  number of readers 0, waiters flag 1
3271                                                  Last time read locked in file btr0sea.c line 746
3272                                                  Last time write locked in file btr0cur.c line 2184
3273                                                  Warning: a long semaphore wait:
3274                                                  --Thread 1634335072 has waited at row0sel.c line 3326 for 789.00 seconds the semaphore:
3275                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3276                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3277                                                  number of readers 0, waiters flag 1
3278                                                  Last time read locked in file btr0sea.c line 746
3279                                                  Last time write locked in file btr0cur.c line 2184
3280                                                  Warning: a long semaphore wait:
3281                                                  --Thread 1582954848 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
3282                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3283                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3284                                                  number of readers 0, waiters flag 1
3285                                                  Last time read locked in file btr0sea.c line 746
3286                                                  Last time write locked in file btr0cur.c line 2184
3287                                                  Warning: a long semaphore wait:
3288                                                  --Thread 1548433760 has waited at btr0sea.c line 746 for 789.00 seconds the semaphore:
3289                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3290                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3291                                                  number of readers 0, waiters flag 1
3292                                                  Last time read locked in file btr0sea.c line 746
3293                                                  Last time write locked in file btr0cur.c line 2184
3294                                                  Warning: a long semaphore wait:
3295                                                  --Thread 1640958304 has waited at btr0sea.c line 916 for 789.00 seconds the semaphore:
3296                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3297                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3298                                                  number of readers 0, waiters flag 1
3299                                                  Last time read locked in file btr0sea.c line 746
3300                                                  Last time write locked in file btr0cur.c line 2184
3301                                                  Warning: a long semaphore wait:
3302                                                  --Thread 1642764640 has waited at trx0trx.c line 715 for 789.00 seconds the semaphore:
3303                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3304                                                  waiters flag 1
3305                                                  Warning: a long semaphore wait:
3306                                                  --Thread 1602824544 has waited at trx0trx.c line 371 for 789.00 seconds the semaphore:
3307                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3308                                                  waiters flag 1
3309                                                  Warning: a long semaphore wait:
3310                                                  --Thread 1643567456 has waited at trx0trx.c line 1609 for 789.00 seconds the semaphore:
3311                                                  Mutex at 0x2a96d8f2b8 created file srv0srv.c line 872, lock var 1
3312                                                  waiters flag 1
3313                                                  Warning: a long semaphore wait:
3314                                                  --Thread 1628916064 has waited at btr0sea.c line 1127 for 789.00 seconds the semaphore:
3315                                                  S-lock on RW-latch at 0x2a96d920b8 created in file btr0sea.c line 139
3316                                                  a writer (thread id 1799514464) has reserved it in mode  wait exclusive
3317                                                  number of readers 0, waiters flag 1
3318                                                  Last time read locked in file btr0sea.c line 746
3319                                                  Last time write locked in file btr0cur.c line 2184
3320                                                  ###### Starts InnoDB Monitor for 30 secs to print diagnostic info:
3321                                                  Pending preads 0, pwrites 0
3322                                                  ###### Diagnostic info printed to the standard error stream
3323                                                  Error: semaphore wait has lasted > 600 seconds
3324                                                  We intentionally crash the server, because it appears to be hung.
3325                                                  EOF
3326           1                                  5   chomp $big_arg;
3327           1                                913   $big_arg =~ s/\n+/ /g;
3328                                                  
3329           1                                127   test_log_parser(
3330                                                     parser => $p,
3331                                                     file   => 'common/t/samples/errlogs/errlog007.txt',
3332                                                     result => [
3333                                                           {  Level => 'unknown',
3334                                                              ts    => '091121 13:17:58',
3335                                                              arg   => 'InnoDB: Warning: cannot find a free slot for an '
3336                                                                 . 'undo log. Do you have too many active transactions running '
3337                                                                 . 'concurrently?',
3338                                                              pos_in_log => '0'
3339                                                           },
3340                                                           {  Level      => 'unknown',
3341                                                              ts         => '091121 13:17:58',
3342                                                              arg        => $big_arg,
3343                                                              pos_in_log => '233',
3344                                                           },
3345                                                           {  Level => 'unknown',
3346                                                              arg =>
3347                                                                 'InnoDB: Assertion failure in thread 1525901664 in file srv0srv.c line 2093 We intentionally generate a memory trap. Submit a detailed bug report to http://bugs.mysql.com. If you get repeated assertion failures or crashes, even immediately after the mysqld startup, there may be corruption in the InnoDB tablespace. Please refer to http://dev.mysql.com/doc/refman/5.0/en/forcing-recovery.html about forcing recovery.',
3348                                                              pos_in_log => '139341',
3349                                                              ts         => '091205  4:49:04',
3350                                                           },
3351                                                        ],
3352                                                  );
3353                                                  
3354           1                                 91   $big_arg = <<'EOF';
3355                                                  mysqld got signal 11;
3356                                                  This could be because you hit a bug. It is also possible that this binary
3357                                                  or one of the libraries it was linked against is corrupt, improperly built,
3358                                                  or misconfigured. This error can also be caused by malfunctioning hardware.
3359                                                  We will try our best to scrape up some info that will hopefully help diagnose
3360                                                  the problem, but since we have already crashed, something is definitely wrong
3361                                                  and this may fail.
3362                                                  
3363                                                  key_buffer_size=16777216
3364                                                  read_buffer_size=1044480
3365                                                  max_used_connections=2101
3366                                                  max_connections=2100
3367                                                  threads_connected=207
3368                                                  It is possible that mysqld could use up to 
3369                                                  key_buffer_size + (read_buffer_size + sort_buffer_size)*max_connections = 6459167 K
3370                                                  bytes of memory
3371                                                  Hope that's ok; if not, decrease some variables in the equation.
3372                                                  
3373                                                  thd=(nil)
3374                                                  Attempting backtrace. You can use the following information to find out
3375                                                  where mysqld died. If you see no messages after this, something went
3376                                                  terribly wrong...
3377                                                  frame pointer is NULL, did you compile with
3378                                                  -fomit-frame-pointer? Aborting backtrace!
3379                                                  The manual page at http://www.mysql.com/doc/en/Crashing.html contains
3380                                                  information that should help you find out what is causing the crash.
3381                                                  
3382                                                  Number of processes running now: 0
3383                                                  EOF
3384           1                                  5   chomp $big_arg;
3385           1                                 18   $big_arg =~ s/\n+/ /g;
3386                                                  
3387           1                                 21   test_log_parser(
3388                                                     parser => $p,
3389                                                     file   => 'common/t/samples/errlogs/errlog008.txt',
3390                                                     result => [
3391                                                           {  Level => 'unknown',
3392                                                              arg =>
3393                                                                 'InnoDB: Assertion failure in thread 1525901664 in file srv0srv.c line 2093 We intentionally generate a memory trap. Submit a detailed bug report to http://bugs.mysql.com. If you get repeated assertion failures or crashes, even immediately after the mysqld startup, there may be corruption in the InnoDB tablespace. Please refer to http://dev.mysql.com/doc/refman/5.0/en/forcing-recovery.html about forcing recovery.',
3394                                                              pos_in_log => '0',
3395                                                              ts         => '091205  4:49:04',
3396                                                           },
3397                                                           {  Level      => 'unknown',
3398                                                              ts         => '091205  4:49:04',
3399                                                              arg        => $big_arg,
3400                                                              pos_in_log => '527',
3401                                                           },
3402                                                           {  Level      => 'unknown',
3403                                                              arg        => 'mysqld restarted',
3404                                                              pos_in_log => '1722',
3405                                                              ts         => '091205 04:49:10'
3406                                                           },
3407                                                     ],
3408                                                  );
3409                                                  
3410                                                  test_log_parser(
3411                                                     parser  => $p,
3412                                                     file    => 'common/t/samples/errlogs/errlog010.txt',
3413           1                    1             4      oktorun => sub { $oktorun = $_[0]; },
3414           1                                 36      result  => [
3415                                                        {
3416                                                         pos_in_log => '0',
3417                                                         ts         => '080816  7:53:17',
3418                                                         Level      => 'error',
3419                                                         arg        => '[ERROR] Cannot find table exampledb/exampletable from the internal data dictionary of InnoDB though the .frm file for the table exists. Maybe you have deleted and recreated InnoDB data files but have forgotten to delete the corresponding .frm files of InnoDB tables, or you have moved .frm files to another database? See http://dev.mysql.com/doc/refman/5.0/en/innodb-troubleshooting.html how you can resolve the problem.',
3420                                                  		},
3421                                                     ],
3422                                                  );
3423                                                  
3424                                                  
3425                                                  
3426                                                  # #############################################################################
3427                                                  # Done.
3428                                                  # #############################################################################
3429           1                                  3   exit;


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
---------- ----- ---------------------
BEGIN          1 ErrorLogParser.t:10  
BEGIN          1 ErrorLogParser.t:11  
BEGIN          1 ErrorLogParser.t:12  
BEGIN          1 ErrorLogParser.t:14  
BEGIN          1 ErrorLogParser.t:15  
BEGIN          1 ErrorLogParser.t:4   
BEGIN          1 ErrorLogParser.t:9   
__ANON__       1 ErrorLogParser.t:24  
__ANON__       1 ErrorLogParser.t:3413


