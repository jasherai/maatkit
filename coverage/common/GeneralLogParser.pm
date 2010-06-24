---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...ommon/GeneralLogParser.pm   89.8   73.3   63.6   87.5    0.0   90.7   82.7
GeneralLogParser.t            100.0   50.0   33.3  100.0    n/a    9.3   93.3
Total                          92.4   71.9   57.1   94.1    0.0  100.0   85.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:20 2010
Finish:       Thu Jun 24 19:33:20 2010

Run:          GeneralLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:21 2010
Finish:       Thu Jun 24 19:33:22 2010

/home/daniel/dev/maatkit/common/GeneralLogParser.pm

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
18                                                    # GeneralLogParser package $Revision: 6054 $
19                                                    # ###########################################################################
20                                                    package GeneralLogParser;
21                                                    
22             1                    1             4   use strict;
               1                                  3   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                 10   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
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
33                                                    sub new {
34    ***      1                    1      0      4      my ( $class ) = @_;
35             1                                  7      my $self = {
36                                                          pending => [],
37                                                          db_for  => {},
38                                                       };
39             1                                 12      return bless $self, $class;
40                                                    }
41                                                    
42                                                    my $genlog_line_1= qr{
43                                                       \A
44                                                       (?:(\d{6}\s+\d{1,2}:\d\d:\d\d))? # Timestamp
45                                                       \s+
46                                                       (?:\s*(\d+))                     # Thread ID
47                                                       \s
48                                                       (\w+)                            # Command
49                                                       \s+
50                                                       (.*)                             # Argument
51                                                       \Z
52                                                    }xs;
53                                                    
54                                                    # This method accepts an open filehandle, a callback function, and a mode
55                                                    # (slow, log, undef).  It reads events from the filehandle and calls the
56                                                    # callback with each event.
57                                                    sub parse_event {
58    ***     19                   19      0    610      my ( $self, %args ) = @_;
59            19                                 81      my @required_args = qw(next_event tell);
60            19                                 60      foreach my $arg ( @required_args ) {
61    ***     38     50                         171         die "I need a $arg argument" unless $args{$arg};
62                                                       }
63            19                                 75      my ($next_event, $tell) = @args{@required_args};
64                                                    
65            19                                 58      my $pending = $self->{pending};
66            19                                 58      my $db_for  = $self->{db_for};
67            19                                 45      my $line;
68            19                                 71      my $pos_in_log = $tell->();
69                                                       LINE:
70            19           100                  225      while (
71                                                             defined($line = shift @$pending)
72                                                          or defined($line = $next_event->())
73                                                       ) {
74            16                                260         MKDEBUG && _d($line);
75            16                                170         my ($ts, $thread_id, $cmd, $arg) = $line =~ m/$genlog_line_1/;
76    ***     16     50     33                  136         if ( !($thread_id && $cmd) ) {
77    ***      0                                  0            MKDEBUG && _d('Not start of general log event');
78    ***      0                                  0            next;
79                                                          }
80                                                          # Don't save cmd or arg yet, we may need to modify them later.
81            16                                 73         my @properties = ('pos_in_log', $pos_in_log, 'ts', $ts,
82                                                             'Thread_id', $thread_id);
83                                                    
84            16                                 57         $pos_in_log = $tell->();
85                                                    
86            16                                118         @$pending = ();
87            16    100                          60         if ( $cmd eq 'Query' ) {
88                                                             # There may be more lines to this query.  Read lines until
89                                                             # the next id/cmd is found.  Append these lines to this
90                                                             # event's arg, push the next id/cmd to pending.
91             6                                 18            my $done = 0;
92             6                                 15            do {
93            26                                 92               $line = $next_event->();
94            26    100                         383               if ( $line ) {
95            25                                689                  my (undef, $next_thread_id, $next_cmd)
96                                                                      = $line =~ m/$genlog_line_1/;
97    ***     25    100     66                  128                  if ( $next_thread_id && $next_cmd ) {
98             5                                 11                     MKDEBUG && _d('Event done');
99             5                                 12                     $done = 1;
100            5                                 30                     push @$pending, $line;
101                                                                  }
102                                                                  else {
103           20                                 43                     MKDEBUG && _d('More arg:', $line);
104           20                                105                     $arg .= $line;
105                                                                  }
106                                                               }
107                                                               else {
108            1                                  3                  MKDEBUG && _d('No more lines');
109            1                                  5                  $done = 1;
110                                                               }
111                                                            } until ( $done );
112                                                   
113            6                                 19            chomp $arg;
114            6                                 25            push @properties, 'cmd', 'Query', 'arg', $arg;
115            6                                 24            push @properties, 'bytes', length($properties[-1]);
116            6    100                          29            push @properties, 'db', $db_for->{$thread_id} if $db_for->{$thread_id};
117                                                         }
118                                                         else {
119                                                            # If it's not a query it's some admin command.
120           10                                 68            push @properties, 'cmd', 'Admin';
121                                                   
122           10    100                          44            if ( $cmd eq 'Connect' ) {
                    100                               
123   ***      4     50                          18               if ( $arg =~ m/^Access denied/ ) {
124                                                                  # administrator command: Access denied for user ...
125   ***      0                                  0                  $cmd = $arg;
126                                                               }
127                                                               else {
128                                                                  # The Connect command may or may not be followed by 'on'.
129                                                                  # When it is, 'on' may or may not be followed by a database.
130            4                                 32                  my ($user, undef, $db) = $arg =~ /(\S+)/g;
131            4                                 12                  my $host;
132            4                                 22                  ($user, $host) = split(/@/, $user);
133            4                                 12                  MKDEBUG && _d('Connect', $user, '@', $host, 'on', $db);
134                                                   
135   ***      4     50                          21                  push @properties, 'user', $user if $user;
136   ***      4     50                          18                  push @properties, 'host', $host if $host;
137            4    100                          16                  push @properties, 'db',   $db   if $db;
138            4                                 18                  $db_for->{$thread_id} = $db;
139                                                               }
140                                                            }
141                                                            elsif ( $cmd eq 'Init' ) {
142                                                               # The full command is "Init DB" so arg starts with "DB"
143                                                               # because our regex expects single word commands.
144            2                                  6               $cmd = 'Init DB';
145            2                                 11               $arg =~ s/^DB\s+//;
146            2                                 10               my ($db) = $arg =~ /(\S+)/;
147            2                                  6               MKDEBUG && _d('Init DB:', $db);
148   ***      2     50                           9               push @properties, 'db',   $db   if $db;
149            2                                  9               $db_for->{$thread_id} = $db;
150                                                            }
151                                                   
152           10                                 39            push @properties, 'arg', "administrator command: $cmd";
153           10                                 38            push @properties, 'bytes', length($properties[-1]);
154                                                         }
155                                                   
156                                                         # The Query_time attrib is expected by mk-query-digest but
157                                                         # general logs have no Query_time so we fake it.
158           16                                 50         push @properties, 'Query_time', 0;
159                                                   
160                                                         # Don't dump $event; want to see full dump of all properties,
161                                                         # and after it's been cast into a hash, duplicated keys will
162                                                         # be gone.
163           16                                 32         MKDEBUG && _d('Properties of event:', Dumper(\@properties));
164           16                                119         my $event = { @properties };
165           16                                127         return $event;
166                                                      } # LINE
167                                                   
168            3                                 64      @{$self->{pending}} = ();
               3                                 12   
169            3    100                          17      $args{oktorun}->(0) if $args{oktorun};
170            3                                 20      return;
171                                                   }
172                                                   
173                                                   sub _d {
174   ***      0                    0                    my ($package, undef, $line) = caller 0;
175   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
176   ***      0                                              map { defined $_ ? $_ : 'undef' }
177                                                           @_;
178   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
179                                                   }
180                                                   
181                                                   1;
182                                                   
183                                                   # ###########################################################################
184                                                   # End GeneralLogParser package
185                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
61    ***     50      0     38   unless $args{$arg}
76    ***     50      0     16   if (not $thread_id && $cmd)
87           100      6     10   if ($cmd eq 'Query') { }
94           100     25      1   if ($line) { }
97           100      5     20   if ($next_thread_id and $next_cmd) { }
116          100      4      2   if $$db_for{$thread_id}
122          100      4      6   if ($cmd eq 'Connect') { }
             100      2      4   elsif ($cmd eq 'Init') { }
123   ***     50      0      4   if ($arg =~ /^Access denied/) { }
135   ***     50      4      0   if $user
136   ***     50      4      0   if $host
137          100      2      2   if $db
148   ***     50      2      0   if $db
169          100      2      1   if $args{'oktorun'}
175   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
76    ***     33      0      0     16   $thread_id && $cmd
97    ***     66     20      0      5   $next_thread_id and $next_cmd

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
70           100      5     11      3   defined($line = shift @$pending) or defined($line = &$next_event())


Covered Subroutines
-------------------

Subroutine  Count Pod Location                                               
----------- ----- --- -------------------------------------------------------
BEGIN           1     /home/daniel/dev/maatkit/common/GeneralLogParser.pm:22 
BEGIN           1     /home/daniel/dev/maatkit/common/GeneralLogParser.pm:23 
BEGIN           1     /home/daniel/dev/maatkit/common/GeneralLogParser.pm:24 
BEGIN           1     /home/daniel/dev/maatkit/common/GeneralLogParser.pm:26 
BEGIN           1     /home/daniel/dev/maatkit/common/GeneralLogParser.pm:31 
new             1   0 /home/daniel/dev/maatkit/common/GeneralLogParser.pm:34 
parse_event    19   0 /home/daniel/dev/maatkit/common/GeneralLogParser.pm:58 

Uncovered Subroutines
---------------------

Subroutine  Count Pod Location                                               
----------- ----- --- -------------------------------------------------------
_d              0     /home/daniel/dev/maatkit/common/GeneralLogParser.pm:174


GeneralLogParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            13   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            10   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            11   use Test::More tests => 7;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            12   use GeneralLogParser;
               1                                  3   
               1                                 90   
15             1                    1            12   use MaatkitTest;
               1                                  5   
               1                                 37   
16                                                    
17             1                                 11   my $p = new GeneralLogParser();
18                                                    
19             1                                  3   my $oktorun = 1;
20             1                                  4   my $sample  = "common/t/samples/genlogs/";
21                                                    
22                                                    test_log_parser(
23                                                       parser  => $p,
24                                                       file    => $sample.'genlog001.txt',
25             1                    1             4      oktorun => sub { $oktorun = $_[0]; },
26             1                                 55      result  => [
27                                                          {  ts         => '051007 21:55:24',
28                                                             Thread_id  => '42',
29                                                             arg        => 'administrator command: Connect',
30                                                             bytes      => 30,
31                                                             cmd        => 'Admin',
32                                                             db         => 'db1',
33                                                             host       => 'localhost',
34                                                             pos_in_log => 0,
35                                                             user       => 'root',
36                                                             Query_time => 0,
37                                                          },
38                                                          {  ts         => undef,
39                                                             Thread_id  => '42',
40                                                             arg        => 'SELECT foo 
41                                                                             FROM tbl
42                                                                             WHERE col=12345
43                                                                             ORDER BY col',
44                                                             bytes      => 124,
45                                                             cmd        => 'Query',
46                                                             pos_in_log => 58,
47                                                             Query_time => 0,
48                                                             db         => 'db1',
49                                                          },
50                                                          {  ts         => undef,
51                                                             Thread_id  => '42',
52                                                             arg        => 'administrator command: Quit',
53                                                             bytes      => 27,
54                                                             cmd        => 'Admin',
55                                                             pos_in_log => 244,
56                                                             Query_time => 0,
57                                                          },
58                                                          {  ts         => '061226 15:42:36',
59                                                             Thread_id  => '11',
60                                                             arg        => 'administrator command: Connect',
61                                                             bytes      => 30,
62                                                             cmd        => 'Admin',
63                                                             host       => 'localhost',
64                                                             pos_in_log => 244,
65                                                             user       => 'root',
66                                                             Query_time => 0,
67                                                          },
68                                                          {  ts         => undef,
69                                                             Thread_id  => '11',
70                                                             arg        => 'administrator command: Init DB',
71                                                             bytes      => 30,
72                                                             cmd        => 'Admin',
73                                                             db         => 'my_webstats',
74                                                             pos_in_log => 300,
75                                                             Query_time => 0,
76                                                          },
77                                                          {  ts         => undef,
78                                                             Thread_id  => '11',
79                                                             arg        => 'SELECT DISTINCT col FROM tbl WHERE foo=20061219',
80                                                             bytes      => 47,
81                                                             cmd        => 'Query',
82                                                             pos_in_log => 346,
83                                                             Query_time => 0,
84                                                             db         => 'my_webstats',
85                                                          },
86                                                          {  ts         => '061226 16:44:48',
87                                                             Thread_id  => '11',
88                                                             arg        => 'administrator command: Quit',
89                                                             bytes      => 27,
90                                                             cmd        => 'Admin',
91                                                             pos_in_log => 464,
92                                                             Query_time => 0,
93                                                          },
94                                                       ]
95                                                    );
96                                                    
97             1                                 49   is(
98                                                       $oktorun,
99                                                       0,
100                                                      'Sets oktorun'
101                                                   );
102            1                                  4   $oktorun = 1;
103                                                   
104            1                                 19   test_log_parser(
105                                                      parser  => $p,
106                                                      file    => $sample.'genlog002.txt',
107                                                      result  => [
108                                                         {
109                                                            Query_time  => 0,
110                                                            Thread_id   => '51',
111                                                            arg         => 'SELECT category_id
112                                                                   FROM auction_category_map 
113                                                                   WHERE auction_id = \'3015563\'',
114                                                            bytes       => 106,
115                                                            cmd         => 'Query',
116                                                            pos_in_log  => 0,
117                                                            ts          => '100211  0:55:24'
118                                                         },
119                                                         {
120                                                            Query_time  => 0,
121                                                            Thread_id   => '51',
122                                                            arg         => 'SELECT auction_id, auction_title_en AS title, close_time,
123                                                                                            number_of_items_per_lot, 
124                                                                                            replace (replace (thumbnail_url,  \'sm_thumb\', \'carousel\'), \'small_thumb\', \'carousel\') as thumbnail_url,
125                                                                                            replace (replace (thumbnail_url,  \'sm_thumb\', \'tiny_thumb\'), \'small_thumb\', \'tiny_thumb\') as tinythumb_url,
126                                                                                            current_bid
127                                                                   FROM   auction_search
128                                                                   WHERE  platform_flag_1 = 1
129                                                                   AND    close_flag = 0 
130                                                                   AND    close_time >= NOW()
131                                                                   AND    marketplace = \'AR\'
132                                                                   AND auction_id IN (3015562,3028764,3015564,3019075,3015574,2995142,3040162,3015573,2995135,3015578)
133                                                                   ORDER BY close_time ASC
134                                                                   LIMIT 500',
135                                                            bytes       => 858,
136                                                            cmd         => 'Query',
137                                                            pos_in_log  => 237,
138                                                            ts          => undef
139                                                         },
140                                                      ],
141                                                   );
142                                                   
143                                                   
144                                                   # #############################################################################
145                                                   # Issue 972: mk-query-digest genlog timestamp fix
146                                                   # #############################################################################
147                                                   test_log_parser(
148                                                      parser  => $p,
149                                                      file    => $sample.'genlog003.txt',
150            1                    1             4      oktorun => sub { $oktorun = $_[0]; },
151            1                                 68      result  => [
152                                                         {  ts         => '051007   21:55:24',
153                                                            Thread_id  => '42',
154                                                            arg        => 'administrator command: Connect',
155                                                            bytes      => 30,
156                                                            cmd        => 'Admin',
157                                                            db         => 'db1',
158                                                            host       => 'localhost',
159                                                            pos_in_log => 0,
160                                                            user       => 'root',
161                                                            Query_time => 0,
162                                                         },
163                                                         {  ts         => undef,
164                                                            Thread_id  => '42',
165                                                            arg        => 'SELECT foo 
166                                                                            FROM tbl
167                                                                            WHERE col=12345
168                                                                            ORDER BY col',
169                                                            bytes      => 124,
170                                                            cmd        => 'Query',
171                                                            pos_in_log => 60,
172                                                            Query_time => 0,
173                                                            db         => 'db1',
174                                                         },
175                                                         {  ts         => undef,
176                                                            Thread_id  => '42',
177                                                            arg        => 'administrator command: Quit',
178                                                            bytes      => 27,
179                                                            cmd        => 'Admin',
180                                                            pos_in_log => 246,
181                                                            Query_time => 0,
182                                                         },
183                                                         {  ts         => undef,
184                                                            Thread_id  => '11',
185                                                            arg        => 'administrator command: Connect',
186                                                            bytes      => 30,
187                                                            cmd        => 'Admin',
188                                                            host       => 'localhost',
189                                                            pos_in_log => 246,
190                                                            user       => 'root',
191                                                            Query_time => 0,
192                                                         },
193                                                         {  ts         => undef,
194                                                            Thread_id  => '11',
195                                                            arg        => 'administrator command: Init DB',
196                                                            bytes      => 30,
197                                                            cmd        => 'Admin',
198                                                            db         => 'my_webstats',
199                                                            pos_in_log => 302,
200                                                            Query_time => 0,
201                                                         },
202                                                         {  ts         => undef,
203                                                            Thread_id  => '11',
204                                                            arg        => 'SELECT DISTINCT col FROM tbl WHERE foo=20061219',
205                                                            bytes      => 47,
206                                                            cmd        => 'Query',
207                                                            pos_in_log => 348,
208                                                            Query_time => 0,
209                                                            db         => 'my_webstats',
210                                                         },
211                                                         {  ts         => undef,
212                                                            Thread_id  => '11',
213                                                            arg        => 'administrator command: Quit',
214                                                            bytes      => 27,
215                                                            cmd        => 'Admin',
216                                                            pos_in_log => 466,
217                                                            Query_time => 0,
218                                                         },
219                                                      ]
220                                                   );
221                                                   
222                                                   # #############################################################################
223                                                   # Done.
224                                                   # #############################################################################
225            1                                  4   exit;


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
BEGIN          1 GeneralLogParser.t:10 
BEGIN          1 GeneralLogParser.t:11 
BEGIN          1 GeneralLogParser.t:12 
BEGIN          1 GeneralLogParser.t:14 
BEGIN          1 GeneralLogParser.t:15 
BEGIN          1 GeneralLogParser.t:4  
BEGIN          1 GeneralLogParser.t:9  
__ANON__       1 GeneralLogParser.t:150
__ANON__       1 GeneralLogParser.t:25 


