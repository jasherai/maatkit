---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlowLogParser.pm  100.0   94.1   81.2  100.0    0.0   96.8   94.4
SlowLogParser.t               100.0   50.0   33.3  100.0    n/a    3.2   95.8
Total                         100.0   91.7   77.1  100.0    0.0  100.0   94.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:17 2010
Finish:       Thu Jun 24 19:37:17 2010

Run:          SlowLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:19 2010
Finish:       Thu Jun 24 19:37:19 2010

/home/daniel/dev/maatkit/common/SlowLogParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2009 Baron Schwartz.
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
18                                                    # SlowLogParser package $Revision: 6043 $
19                                                    # ###########################################################################
20                                                    package SlowLogParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  8   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             9   use English qw(-no_match_vars);
               1                                  3   
               1                                  6   
25             1                    1             5   use Data::Dumper;
               1                                  3   
               1                                  7   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
28                                                    
29                                                    sub new {
30    ***      2                    2      0     10      my ( $class ) = @_;
31             2                                 11      my $self = {
32                                                          pending => [],
33                                                       };
34             2                                 18      return bless $self, $class;
35                                                    }
36                                                    
37                                                    my $slow_log_ts_line = qr/^# Time: ([0-9: ]{15})/;
38                                                    my $slow_log_uh_line = qr/# User\@Host: ([^\[]+|\[[^[]+\]).*?@ (\S*) \[(.*)\]/;
39                                                    # These can appear in the log file when it's opened -- for example, when someone
40                                                    # runs FLUSH LOGS or the server starts.
41                                                    # /usr/sbin/mysqld, Version: 5.0.67-0ubuntu6-log ((Ubuntu)). started with:
42                                                    # Tcp port: 3306  Unix socket: /var/run/mysqld/mysqld.sock
43                                                    # Time                 Id Command    Argument
44                                                    # These lines vary depending on OS and whether it's embedded.
45                                                    my $slow_log_hd_line = qr{
46                                                          ^(?:
47                                                          T[cC][pP]\s[pP]ort:\s+\d+ # case differs on windows/unix
48                                                          |
49                                                          [/A-Z].*mysqld,\sVersion.*(?:started\swith:|embedded\slibrary)
50                                                          |
51                                                          Time\s+Id\s+Command
52                                                          ).*\n
53                                                       }xm;
54                                                    
55                                                    # This method accepts an open slow log filehandle and callback functions.
56                                                    # It reads events from the filehandle and calls the callbacks with each event.
57                                                    # It may find more than one event per call.  $misc is some placeholder for the
58                                                    # future and for compatibility with other query sources.
59                                                    #
60                                                    # Each event is a hashref of attribute => value pairs like:
61                                                    #  my $event = {
62                                                    #     ts  => '',    # Timestamp
63                                                    #     id  => '',    # Connection ID
64                                                    #     arg => '',    # Argument to the command
65                                                    #     other attributes...
66                                                    #  };
67                                                    #
68                                                    # Returns the number of events it finds.
69                                                    #
70                                                    # NOTE: If you change anything inside this subroutine, you need to profile
71                                                    # the result.  Sometimes a line of code has been changed from an alternate
72                                                    # form for performance reasons -- sometimes as much as 20x better performance.
73                                                    sub parse_event {
74    ***     77                   77      0   3788      my ( $self, %args ) = @_;
75            77                                359      my @required_args = qw(next_event tell);
76            77                                267      foreach my $arg ( @required_args ) {
77    ***    154     50                         795         die "I need a $arg argument" unless $args{$arg};
78                                                       }
79            77                                351      my ($next_event, $tell) = @args{@required_args};
80                                                    
81                                                       # Read a whole stmt at a time.  But, to make things even more fun, sometimes
82                                                       # part of the log entry might continue past the separator.  In these cases we
83                                                       # peek ahead (see code below.)  We do it this way because in the general
84                                                       # case, reading line-by-line is too slow, and the special-case code is
85                                                       # acceptable.  And additionally, the line terminator doesn't work for all
86                                                       # cases; the header lines might follow a statement, causing the paragraph
87                                                       # slurp to grab more than one statement at a time.
88            77                                269      my $pending = $self->{pending};
89            77                                395      local $INPUT_RECORD_SEPARATOR = ";\n#";
90            77                                252      my $trimlen    = length($INPUT_RECORD_SEPARATOR);
91            77                                313      my $pos_in_log = $tell->();
92            77                                590      my $stmt;
93                                                    
94                                                       EVENT:
95            77           100                  627      while (
96                                                             defined($stmt = shift @$pending)
97                                                          or defined($stmt = $next_event->())
98                                                       ) {
99            56                              42329         my @properties = ('cmd', 'Query', 'pos_in_log', $pos_in_log);
100           56                                246         $pos_in_log = $tell->();
101                                                   
102                                                         # If there were such lines in the file, we may have slurped > 1 event.
103                                                         # Delete the lines and re-split if there were deletes.  This causes the
104                                                         # pos_in_log to be inaccurate, but that's really okay.
105           56    100                        1053         if ( $stmt =~ s/$slow_log_hd_line//go ){ # Throw away header lines in log
106            5                                 63            my @chunks = split(/$INPUT_RECORD_SEPARATOR/o, $stmt);
107            5    100                          33            if ( @chunks > 1 ) {
108            1                                  3               MKDEBUG && _d("Found multiple chunks");
109            1                                  4               $stmt = shift @chunks;
110            1                                  4               unshift @$pending, @chunks;
111                                                            }
112                                                         }
113                                                   
114                                                         # There might not be a leading '#' because $INPUT_RECORD_SEPARATOR will
115                                                         # have gobbled that up.  And the end may have all/part of the separator.
116           56    100                         347         $stmt = '#' . $stmt unless $stmt =~ m/\A#/;
117           56                                301         $stmt =~ s/;\n#?\Z//;
118                                                   
119                                                         # The beginning of a slow-query-log event should be something like
120                                                         # # Time: 071015 21:43:52
121                                                         # Or, it might look like this, sometimes at the end of the Time: line:
122                                                         # # User@Host: root[root] @ localhost []
123                                                   
124                                                         # The following line contains variables intended to be sure we do
125                                                         # particular things once and only once, for those regexes that will
126                                                         # match only one line per event, so we don't keep trying to re-match
127                                                         # regexes.
128           56                                208         my ($got_ts, $got_uh, $got_ac, $got_db, $got_set, $got_embed);
129           56                                161         my $pos = 0;
130           56                                174         my $len = length($stmt);
131           56                                156         my $found_arg = 0;
132                                                         LINE:
133           56                                335         while ( $stmt =~ m/^(.*)$/mg ) { # /g is important, requires scalar match.
134          342                               1013            $pos     = pos($stmt);  # Be careful not to mess this up!
135          342                               1269            my $line = $1;          # Necessary for /g and pos() to work.
136          342                                768            MKDEBUG && _d($line);
137                                                   
138                                                            # Handle meta-data lines.  These are case-sensitive.  If they appear in
139                                                            # the log with a different case, they are from a user query, not from
140                                                            # something printed out by sql/log.cc.
141          342    100                        1567            if ($line =~ m/^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) {
142                                                   
143                                                               # Maybe it's the beginning of the slow query log event.  XXX
144                                                               # something to know: Perl profiling reports this line as the hot
145                                                               # spot for any of the conditions in the whole if/elsif/elsif
146                                                               # construct.  So if this line looks "hot" then profile each
147                                                               # condition separately.
148          293    100    100                 5703               if ( !$got_ts && (my ( $time ) = $line =~ m/$slow_log_ts_line/o)) {
                    100    100                        
      ***           100     66                        
                    100    100                        
      ***           100     66                        
                    100                               
149           26                                 60                  MKDEBUG && _d("Got ts", $time);
150           26                                110                  push @properties, 'ts', $time;
151           26                                 72                  ++$got_ts;
152                                                                  # The User@Host might be concatenated onto the end of the Time.
153   ***     26    100     66                  380                  if ( !$got_uh
154                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
155                                                                  ) {
156           10                                 25                     MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
157           10                                 49                     push @properties, 'user', $user, 'host', $host, 'ip', $ip;
158           10                                 33                     ++$got_uh;
159                                                                  }
160                                                               }
161                                                   
162                                                               # Maybe it's the user/host line of a slow query log
163                                                               # # User@Host: root[root] @ localhost []
164                                                               elsif ( !$got_uh
165                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
166                                                               ) {
167           44                                106                  MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
168           44                                241                  push @properties, 'user', $user, 'host', $host, 'ip', $ip;
169           44                                130                  ++$got_uh;
170                                                               }
171                                                   
172                                                               # A line that looks like meta-data but is not:
173                                                               # # administrator command: Quit;
174                                                               elsif (!$got_ac && $line =~ m/^# (?:administrator command:.*)$/) {
175            4                                 10                  MKDEBUG && _d("Got admin command");
176            4                                 21                  $line =~ s/^#\s+//;  # string leading "# ".
177            4                                 22                  push @properties, 'cmd', 'Admin', 'arg', $line;
178            4                                 19                  push @properties, 'bytes', length($properties[-1]);
179            4                                 10                  ++$found_arg;
180            4                                 13                  ++$got_ac;
181                                                               }
182                                                   
183                                                               # Maybe it's the timing line of a slow query log, or another line
184                                                               # such as that... they typically look like this:
185                                                               # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
186                                                               elsif ( $line =~ m/^# +[A-Z][A-Za-z_]+: \S+/ ) { # Make the test cheap!
187          163                                359                  MKDEBUG && _d("Got some line with properties");
188                                                                  # I tried using split, but coping with the above bug makes it
189                                                                  # slower than a complex regex match.
190          163                               1815                  my @temp = $line =~ m/(\w+):\s+(\S+|\Z)/g;
191          163                                949                  push @properties, @temp;
192                                                               }
193                                                   
194                                                               # Include the current default database given by 'use <db>;'  Again
195                                                               # as per the code in sql/log.cc this is case-sensitive.
196                                                               elsif ( !$got_db && (my ( $db ) = $line =~ m/^use ([^;]+)/ ) ) {
197           22                                 50                  MKDEBUG && _d("Got a default database:", $db);
198           22                                 85                  push @properties, 'db', $db;
199           22                                 64                  ++$got_db;
200                                                               }
201                                                   
202                                                               # Some things you might see in the log output, as printed by
203                                                               # sql/log.cc (this time the SET is uppercaes, and again it is
204                                                               # case-sensitive).
205                                                               # SET timestamp=foo;
206                                                               # SET timestamp=foo,insert_id=123;
207                                                               # SET insert_id=123;
208                                                               elsif (!$got_set && (my ($setting) = $line =~ m/^SET\s+([^;]*)/)) {
209                                                                  # Note: this assumes settings won't be complex things like
210                                                                  # SQL_MODE, which as of 5.0.51 appears to be true (see sql/log.cc,
211                                                                  # function MYSQL_LOG::write(THD, char*, uint, time_t)).
212            5                                 12                  MKDEBUG && _d("Got some setting:", $setting);
213            5                                 55                  push @properties, split(/,|\s*=\s*/, $setting);
214            5                                 14                  ++$got_set;
215                                                               }
216                                                   
217                                                               # Handle pathological special cases. The "# administrator command"
218                                                               # is one example: it can come AFTER lines that are not commented,
219                                                               # so it looks like it belongs to the next event, and it won't be
220                                                               # in $stmt. Profiling shows this is an expensive if() so we do
221                                                               # this only if we've seen the user/host line.
222          293    100    100                 3420               if ( !$found_arg && $pos == $len ) {
223            3                                  9                  MKDEBUG && _d("Did not find arg, looking for special cases");
224            3                                 17                  local $INPUT_RECORD_SEPARATOR = ";\n";
225            3    100                          17                  if ( defined(my $l = $next_event->()) ) {
226            2                                 39                     chomp $l;
227            2                                 10                     $l =~ s/^\s+//;
228            2                                  5                     MKDEBUG && _d("Found admin statement", $l);
229            2                                  8                     push @properties, 'cmd', 'Admin', 'arg', $l;
230            2                                  8                     push @properties, 'bytes', length($properties[-1]);
231            2                                 15                     $found_arg++;
232                                                                  }
233                                                                  else {
234                                                                     # Unrecoverable -- who knows what happened.  This is possible,
235                                                                     # for example, if someone does something like "head -c 10000
236                                                                     # /path/to/slow.log | mk-log-parser".  Or if there was a
237                                                                     # server crash and the file has no newline.
238            1                                 33                     MKDEBUG && _d("I can't figure out what to do with this line");
239            1                                 45                     next EVENT;
240                                                                  }
241                                                               }
242                                                            }
243                                                            else {
244                                                               # This isn't a meta-data line.  It's the first line of the
245                                                               # whole query. Grab from here to the end of the string and
246                                                               # put that into the 'arg' for the event.  Then we are done.
247                                                               # Note that if this line really IS the query but we skip in
248                                                               # the 'if' above because it looks like meta-data, later
249                                                               # we'll remedy that.
250           49                                116               MKDEBUG && _d("Got the query/arg line");
251           49                                224               my $arg = substr($stmt, $pos - length($line));
252           49                                237               push @properties, 'arg', $arg, 'bytes', length($arg);
253                                                               # Handle embedded attributes.
254   ***     49    100     66                  410               if ( $args{misc} && $args{misc}->{embed}
      ***                   66                        
255                                                                  && ( my ($e) = $arg =~ m/($args{misc}->{embed})/)
256                                                               ) {
257            1                                 14                  push @properties, $e =~ m/$args{misc}->{capture}/g;
258                                                               }
259           49                                149               last LINE;
260                                                            }
261                                                         }
262                                                   
263                                                         # Don't dump $event; want to see full dump of all properties, and after
264                                                         # it's been cast into a hash, duplicated keys will be gone.
265           55                                129         MKDEBUG && _d('Properties of event:', Dumper(\@properties));
266           55                                645         my $event = { @properties };
267           55                                644         return $event;
268                                                      } # EVENT
269                                                   
270           22                                502      @$pending = ();
271           22    100                         107      $args{oktorun}->(0) if $args{oktorun};
272           22                                183      return;
273                                                   }
274                                                   
275                                                   sub _d {
276            1                    1            12      my ($package, undef, $line) = caller 0;
277   ***      2     50                          20      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 13   
               2                                 33   
278            1                                  8           map { defined $_ ? $_ : 'undef' }
279                                                           @_;
280            1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
281                                                   }
282                                                   
283                                                   1;
284                                                   
285                                                   # ###########################################################################
286                                                   # End SlowLogParser package
287                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
77    ***     50      0    154   unless $args{$arg}
105          100      5     51   if ($stmt =~ s/$slow_log_hd_line//go)
107          100      1      4   if (@chunks > 1)
116          100     34     22   unless $stmt =~ /\A#/
141          100    293     49   if ($line =~ /^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) { }
148          100     26    267   if (not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o) { }
             100     44    223   elsif (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o) { }
             100      4    219   elsif (not $got_ac and $line =~ /^# (?:administrator command:.*)$/) { }
             100    163     56   elsif ($line =~ /^# +[A-Z][A-Za-z_]+: \S+/) { }
             100     22     34   elsif (not $got_db and my($db) = $line =~ /^use ([^;]+)/) { }
             100      5     29   elsif (not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/) { }
153          100     10     16   if (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o)
222          100      3    290   if (not $found_arg and $pos == $len)
225          100      2      1   if (defined(my $l = &$next_event())) { }
254          100      1     48   if ($args{'misc'} and $args{'misc'}{'embed'} and my($e) = $arg =~ /($args{'misc'}{'embed'})/)
271          100      1     21   if $args{'oktorun'}
277   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
148          100     96    171     26   not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o
             100    219      4     44   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
      ***     66      0    219      4   not $got_ac and $line =~ /^# (?:administrator command:.*)$/
             100      2     32     22   not $got_db and my($db) = $line =~ /^use ([^;]+)/
      ***     66      0     29      5   not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/
153   ***     66      0     16     10   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
222          100      4    286      3   not $found_arg and $pos == $len
254   ***     66     48      0      1   $args{'misc'} and $args{'misc'}{'embed'}
      ***     66     48      0      1   $args{'misc'} and $args{'misc'}{'embed'} and my($e) = $arg =~ /($args{'misc'}{'embed'})/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
95           100      1     55     22   defined($stmt = shift @$pending) or defined($stmt = &$next_event())


Covered Subroutines
-------------------

Subroutine  Count Pod Location                                            
----------- ----- --- ----------------------------------------------------
BEGIN           1     /home/daniel/dev/maatkit/common/SlowLogParser.pm:22 
BEGIN           1     /home/daniel/dev/maatkit/common/SlowLogParser.pm:23 
BEGIN           1     /home/daniel/dev/maatkit/common/SlowLogParser.pm:24 
BEGIN           1     /home/daniel/dev/maatkit/common/SlowLogParser.pm:25 
BEGIN           1     /home/daniel/dev/maatkit/common/SlowLogParser.pm:27 
_d              1     /home/daniel/dev/maatkit/common/SlowLogParser.pm:276
new             2   0 /home/daniel/dev/maatkit/common/SlowLogParser.pm:30 
parse_event    77   0 /home/daniel/dev/maatkit/common/SlowLogParser.pm:74 


SlowLogParser.t

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
11             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            10   use Test::More tests => 46;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            10   use SlowLogParser;
               1                                  2   
               1                                 11   
15             1                    1            12   use MaatkitTest;
               1                                  5   
               1                                 37   
16                                                    
17             1                                  8   my $p = new SlowLogParser;
18                                                    
19                                                    # Check that I can parse a slow log in the default slow log format.
20             1                                 31   test_log_parser(
21                                                       parser => $p,
22                                                       file   => 'common/t/samples/slow001.txt',
23                                                       result => [
24                                                          {  ts            => '071015 21:43:52',
25                                                             user          => 'root',
26                                                             host          => 'localhost',
27                                                             ip            => '',
28                                                             db            => 'test',
29                                                             arg           => 'select sleep(2) from n',
30                                                             Query_time    => 2,
31                                                             Lock_time     => 0,
32                                                             Rows_sent     => 1,
33                                                             Rows_examined => 0,
34                                                             pos_in_log    => 0,
35                                                             bytes         => length('select sleep(2) from n'),
36                                                             cmd           => 'Query',
37                                                          },
38                                                          {  ts            => '071015 21:45:10',
39                                                             db            => 'sakila',
40                                                             user          => 'root',
41                                                             host          => 'localhost',
42                                                             ip            => '',
43                                                             arg           => 'select sleep(2) from test.n',
44                                                             Query_time    => 2,
45                                                             Lock_time     => 0,
46                                                             Rows_sent     => 1,
47                                                             Rows_examined => 0,
48                                                             pos_in_log    => 359,
49                                                             bytes         => length('select sleep(2) from test.n'),
50                                                             cmd           => 'Query',
51                                                          },
52                                                       ],
53                                                    );
54                                                    
55                                                    # This one has complex SET insert_id=34484549,timestamp=1197996507;
56             1                                201   test_log_parser(
57                                                       parser => $p,
58                                                       file   => 'common/t/samples/slow002.txt',
59                                                       result => [
60                                                          {  arg            => 'BEGIN',
61                                                             ts             => '071218 11:48:27',
62                                                             Disk_filesort  => 'No',
63                                                             Merge_passes   => '0',
64                                                             Full_scan      => 'No',
65                                                             Full_join      => 'No',
66                                                             Thread_id      => '10',
67                                                             Tmp_table      => 'No',
68                                                             QC_Hit         => 'No',
69                                                             Rows_examined  => '0',
70                                                             Filesort       => 'No',
71                                                             Query_time     => '0.000012',
72                                                             Disk_tmp_table => 'No',
73                                                             Rows_sent      => '0',
74                                                             Lock_time      => '0.000000',
75                                                             pos_in_log     => 0,
76                                                             cmd            => 'Query',
77                                                             user           => '[SQL_SLAVE]',
78                                                             host           => '',
79                                                             ip             => '',
80                                                             bytes          => 5,
81                                                          },
82                                                          {  db        => 'db1',
83                                                             timestamp => 1197996507,
84                                                             arg       => 'update db2.tuningdetail_21_265507 n
85                                                          inner join db1.gonzo a using(gonzo) 
86                                                          set n.column1 = a.column1, n.word3 = a.word3',
87                                                             Disk_filesort  => 'No',
88                                                             Merge_passes   => '0',
89                                                             Full_scan      => 'Yes',
90                                                             Full_join      => 'No',
91                                                             Thread_id      => '10',
92                                                             Tmp_table      => 'No',
93                                                             QC_Hit         => 'No',
94                                                             Rows_examined  => '62951',
95                                                             Filesort       => 'No',
96                                                             Query_time     => '0.726052',
97                                                             Disk_tmp_table => 'No',
98                                                             Rows_sent      => '0',
99                                                             Lock_time      => '0.000091',
100                                                            pos_in_log     => 332,
101                                                            cmd            => 'Query',
102                                                            user           => '[SQL_SLAVE]',
103                                                            host           => '',
104                                                            ip             => '',
105                                                            bytes          => 129,
106                                                         },
107                                                         {  timestamp => 1197996507,
108                                                            arg       => 'INSERT INTO db3.vendor11gonzo (makef, bizzle)
109                                                   VALUES (\'\', \'Exact\')',
110                                                            InnoDB_IO_r_bytes     => '0',
111                                                            Merge_passes          => '0',
112                                                            Full_join             => 'No',
113                                                            InnoDB_pages_distinct => '24',
114                                                            Filesort              => 'No',
115                                                            InnoDB_queue_wait     => '0.000000',
116                                                            Rows_sent             => '0',
117                                                            Lock_time             => '0.000077',
118                                                            InnoDB_rec_lock_wait  => '0.000000',
119                                                            Full_scan             => 'No',
120                                                            Disk_filesort         => 'No',
121                                                            Thread_id             => '10',
122                                                            Tmp_table             => 'No',
123                                                            QC_Hit                => 'No',
124                                                            Rows_examined         => '0',
125                                                            InnoDB_IO_r_ops       => '0',
126                                                            Disk_tmp_table        => 'No',
127                                                            Query_time            => '0.000512',
128                                                            InnoDB_IO_r_wait      => '0.000000',
129                                                            pos_in_log            => 803,
130                                                            cmd                   => 'Query',
131                                                            user           => '[SQL_SLAVE]',
132                                                            host           => '',
133                                                            ip             => '',
134                                                            bytes          => 66,
135                                                         },
136                                                         {  arg => 'UPDATE db4.vab3concept1upload
137                                                   SET    vab3concept1id = \'91848182522\'
138                                                   WHERE  vab3concept1upload=\'6994465\'',
139                                                            InnoDB_IO_r_bytes     => '0',
140                                                            Merge_passes          => '0',
141                                                            Full_join             => 'No',
142                                                            InnoDB_pages_distinct => '11',
143                                                            Filesort              => 'No',
144                                                            InnoDB_queue_wait     => '0.000000',
145                                                            Rows_sent             => '0',
146                                                            Lock_time             => '0.000028',
147                                                            InnoDB_rec_lock_wait  => '0.000000',
148                                                            Full_scan             => 'No',
149                                                            Disk_filesort         => 'No',
150                                                            Thread_id             => '10',
151                                                            Tmp_table             => 'No',
152                                                            QC_Hit                => 'No',
153                                                            Rows_examined         => '0',
154                                                            InnoDB_IO_r_ops       => '0',
155                                                            Disk_tmp_table        => 'No',
156                                                            Query_time            => '0.033384',
157                                                            InnoDB_IO_r_wait      => '0.000000',
158                                                            pos_in_log            => 1316,
159                                                            cmd                   => 'Query',
160                                                            user           => '[SQL_SLAVE]',
161                                                            host           => '',
162                                                            ip             => '',
163                                                            bytes          => 103,
164                                                         },
165                                                         {  insert_id => 34484549,
166                                                            timestamp => 1197996507,
167                                                            arg       => 'INSERT INTO db1.conch (word3, vid83)
168                                                   VALUES (\'211\', \'18\')',
169                                                            InnoDB_IO_r_bytes     => '0',
170                                                            Merge_passes          => '0',
171                                                            Full_join             => 'No',
172                                                            InnoDB_pages_distinct => '18',
173                                                            Filesort              => 'No',
174                                                            InnoDB_queue_wait     => '0.000000',
175                                                            Rows_sent             => '0',
176                                                            Lock_time             => '0.000027',
177                                                            InnoDB_rec_lock_wait  => '0.000000',
178                                                            Full_scan             => 'No',
179                                                            Disk_filesort         => 'No',
180                                                            Thread_id             => '10',
181                                                            Tmp_table             => 'No',
182                                                            QC_Hit                => 'No',
183                                                            Rows_examined         => '0',
184                                                            InnoDB_IO_r_ops       => '0',
185                                                            Disk_tmp_table        => 'No',
186                                                            Query_time            => '0.000530',
187                                                            InnoDB_IO_r_wait      => '0.000000',
188                                                            pos_in_log            => 1840,
189                                                            cmd                   => 'Query',
190                                                            user           => '[SQL_SLAVE]',
191                                                            host           => '',
192                                                            ip             => '',
193                                                            bytes          => 57,
194                                                         },
195                                                         {  arg => 'UPDATE foo.bar
196                                                   SET    biz = \'91848182522\'',
197                                                            InnoDB_IO_r_bytes     => '0',
198                                                            Merge_passes          => '0',
199                                                            Full_join             => 'No',
200                                                            InnoDB_pages_distinct => '18',
201                                                            Filesort              => 'No',
202                                                            InnoDB_queue_wait     => '0.000000',
203                                                            Rows_sent             => '0',
204                                                            Lock_time             => '0.000027',
205                                                            InnoDB_rec_lock_wait  => '0.000000',
206                                                            Full_scan             => 'No',
207                                                            Disk_filesort         => 'No',
208                                                            Thread_id             => '10',
209                                                            Tmp_table             => 'No',
210                                                            QC_Hit                => 'No',
211                                                            Rows_examined         => '0',
212                                                            InnoDB_IO_r_ops       => '0',
213                                                            Disk_tmp_table        => 'No',
214                                                            Query_time            => '0.000530',
215                                                            InnoDB_IO_r_wait      => '0.000000',
216                                                            pos_in_log            => 2363,
217                                                            cmd                   => 'Query',
218                                                            user           => '[SQL_SLAVE]',
219                                                            host           => '',
220                                                            ip             => '',
221                                                            bytes          => 41,
222                                                         },
223                                                         {  arg => 'UPDATE bizzle.bat
224                                                   SET    boop=\'bop: 899\'
225                                                   WHERE  fillze=\'899\'',
226                                                            timestamp             => 1197996508,
227                                                            InnoDB_IO_r_bytes     => '0',
228                                                            Merge_passes          => '0',
229                                                            Full_join             => 'No',
230                                                            InnoDB_pages_distinct => '18',
231                                                            Filesort              => 'No',
232                                                            InnoDB_queue_wait     => '0.000000',
233                                                            Rows_sent             => '0',
234                                                            Lock_time             => '0.000027',
235                                                            InnoDB_rec_lock_wait  => '0.000000',
236                                                            Full_scan             => 'No',
237                                                            Disk_filesort         => 'No',
238                                                            Thread_id             => '10',
239                                                            Tmp_table             => 'No',
240                                                            QC_Hit                => 'No',
241                                                            Rows_examined         => '0',
242                                                            InnoDB_IO_r_ops       => '0',
243                                                            Disk_tmp_table        => 'No',
244                                                            Query_time            => '0.000530',
245                                                            InnoDB_IO_r_wait      => '0.000000',
246                                                            pos_in_log            => 2825,
247                                                            cmd                   => 'Query',
248                                                            user           => '[SQL_SLAVE]',
249                                                            host           => '',
250                                                            ip             => '',
251                                                            bytes          => 60,
252                                                         },
253                                                         {  arg => 'UPDATE foo.bar
254                                                   SET    biz = \'91848182522\'',
255                                                            InnoDB_IO_r_bytes     => '0',
256                                                            Merge_passes          => '0',
257                                                            Full_join             => 'No',
258                                                            InnoDB_pages_distinct => '18',
259                                                            Filesort              => 'No',
260                                                            InnoDB_queue_wait     => '0.000000',
261                                                            Rows_sent             => '0',
262                                                            Lock_time             => '0.000027',
263                                                            InnoDB_rec_lock_wait  => '0.000000',
264                                                            Full_scan             => 'No',
265                                                            Disk_filesort         => 'No',
266                                                            Thread_id             => '10',
267                                                            Tmp_table             => 'No',
268                                                            QC_Hit                => 'No',
269                                                            Rows_examined         => '0',
270                                                            InnoDB_IO_r_ops       => '0',
271                                                            Disk_tmp_table        => 'No',
272                                                            Query_time            => '0.000530',
273                                                            InnoDB_IO_r_wait      => '0.000000',
274                                                            pos_in_log            => 3332,
275                                                            cmd                   => 'Query',
276                                                            user           => '[SQL_SLAVE]',
277                                                            host           => '',
278                                                            ip             => '',
279                                                            bytes          => 41,
280                                                         },
281                                                      ],
282                                                   );
283                                                   
284                                                   # Microsecond format.
285            1                                 98   test_log_parser(
286                                                      parser => $p,
287                                                      file   => 'common/t/samples/microslow001.txt',
288                                                      result => [
289                                                         {  ts            => '071015 21:43:52',
290                                                            user          => 'root',
291                                                            host          => 'localhost',
292                                                            ip            => '',
293                                                            arg           => "SELECT id FROM users WHERE name='baouong'",
294                                                            Query_time    => '0.000652',
295                                                            Lock_time     => '0.000109',
296                                                            Rows_sent     => 1,
297                                                            Rows_examined => 1,
298                                                            pos_in_log    => 0,
299                                                            cmd           => 'Query',
300                                                            bytes          => 41,
301                                                         },
302                                                         {  ts   => '071015 21:43:52',
303                                                            user => 'root',
304                                                            host => 'localhost',
305                                                            ip   => '',
306                                                            arg =>
307                                                               "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
308                                                            Query_time    => '0.001943',
309                                                            Lock_time     => '0.000145',
310                                                            Rows_sent     => 0,
311                                                            Rows_examined => 0,
312                                                            pos_in_log    => 183,
313                                                            cmd           => 'Query',
314                                                            bytes          => 68,
315                                                         },
316                                                      ],
317                                                   );
318                                                   
319                                                   # A log that starts with a blank line.
320            1                                 46   test_log_parser(
321                                                      parser => $p,
322                                                      file   => 'common/t/samples/slow003.txt',
323                                                      result => [
324                                                            {  Disk_filesort  => 'No',
325                                                               Disk_tmp_table => 'No',
326                                                               Filesort       => 'No',
327                                                               Full_join      => 'No',
328                                                               Full_scan      => 'No',
329                                                               Lock_time      => '0.000000',
330                                                               Merge_passes   => '0',
331                                                               QC_Hit         => 'No',
332                                                               Query_time     => '0.000012',
333                                                               Rows_examined  => '0',
334                                                               Rows_sent      => '0',
335                                                               Thread_id      => '10',
336                                                               Tmp_table      => 'No',
337                                                               arg            => 'BEGIN',
338                                                               cmd            => 'Query',
339                                                               host           => '',
340                                                               ip             => '',
341                                                               pos_in_log     => '0',
342                                                               ts             => '071218 11:48:27',
343                                                               user           => '[SQL_SLAVE]',
344                                                               bytes          => 5,
345                                                            },
346                                                         ],
347                                                   );
348                                                   
349            1                                 37   test_log_parser(
350                                                      parser => $p,
351                                                      file   => 'common/t/samples/slow004.txt',
352                                                      result => [
353                                                            {  Lock_time     => '0',
354                                                               Query_time    => '2',
355                                                               Rows_examined => '0',
356                                                               Rows_sent     => '1',
357                                                               arg => 'select 12_13_foo from (select 12foo from 123_bar) as 123baz',
358                                                               cmd        => 'Query',
359                                                               host       => 'localhost',
360                                                               ip         => '',
361                                                               pos_in_log => '0',
362                                                               ts         => '071015 21:43:52',
363                                                               user       => 'root',
364                                                               bytes      => 59,
365                                                            },
366                                                         ],
367                                                   );
368                                                   
369                                                   # Check a slow log that has tabs in it.
370            1                                 43   test_log_parser(
371                                                      parser => $p,
372                                                      file   => 'common/t/samples/slow005.txt',
373                                                      result => [
374                                                            {  arg            => "foo\nbar\n\t\t\t0 AS counter\nbaz",
375                                                               ts             => '071218 11:48:27',
376                                                               Disk_filesort  => 'No',
377                                                               Merge_passes   => '0',
378                                                               Full_scan      => 'No',
379                                                               Full_join      => 'No',
380                                                               Thread_id      => '10',
381                                                               Tmp_table      => 'No',
382                                                               QC_Hit         => 'No',
383                                                               Rows_examined  => '0',
384                                                               Filesort       => 'No',
385                                                               Query_time     => '0.000012',
386                                                               Disk_tmp_table => 'No',
387                                                               Rows_sent      => '0',
388                                                               Lock_time      => '0.000000',
389                                                               pos_in_log     => 0,
390                                                               cmd            => 'Query',
391                                                               user           => '[SQL_SLAVE]',
392                                                               host           => '',
393                                                               ip             => '',
394                                                               bytes          => 27,
395                                                            },
396                                                         ],
397                                                   );
398                                                   
399                                                   # A bunch of case-sensitive and case-insensitive USE stuff.
400            1                                107   test_log_parser(
401                                                      parser => $p,
402                                                      file   => 'common/t/samples/slow006.txt',
403                                                      result => [
404                                                         {  Disk_filesort  => 'No',
405                                                            Disk_tmp_table => 'No',
406                                                            Filesort       => 'No',
407                                                            Full_join      => 'No',
408                                                            Full_scan      => 'No',
409                                                            Lock_time      => '0.000000',
410                                                            Merge_passes   => '0',
411                                                            QC_Hit         => 'No',
412                                                            Query_time     => '0.000012',
413                                                            Rows_examined  => '0',
414                                                            Rows_sent      => '0',
415                                                            Schema         => 'foo',
416                                                            Thread_id      => '10',
417                                                            Tmp_table      => 'No',
418                                                            arg            => 'SELECT col FROM foo_tbl',
419                                                            cmd            => 'Query',
420                                                            host           => '',
421                                                            ip             => '',
422                                                            pos_in_log     => '0',
423                                                            ts             => '071218 11:48:27',
424                                                            user           => '[SQL_SLAVE]',
425                                                            bytes          => 23,
426                                                         },
427                                                         {  Disk_filesort  => 'No',
428                                                            Disk_tmp_table => 'No',
429                                                            Filesort       => 'No',
430                                                            Full_join      => 'No',
431                                                            Full_scan      => 'No',
432                                                            Lock_time      => '0.000000',
433                                                            Merge_passes   => '0',
434                                                            QC_Hit         => 'No',
435                                                            Query_time     => '0.000012',
436                                                            Rows_examined  => '0',
437                                                            Rows_sent      => '0',
438                                                            Schema         => 'foo',
439                                                            Thread_id      => '10',
440                                                            Tmp_table      => 'No',
441                                                            arg            => 'SELECT col FROM foo_tbl',
442                                                            cmd            => 'Query',
443                                                            host           => '',
444                                                            ip             => '',
445                                                            pos_in_log     => '363',
446                                                            ts             => '071218 11:48:57',
447                                                            user           => '[SQL_SLAVE]',
448                                                            bytes          => 23,
449                                                         },
450                                                         {  Disk_filesort  => 'No',
451                                                            Disk_tmp_table => 'No',
452                                                            Filesort       => 'No',
453                                                            Full_join      => 'No',
454                                                            Full_scan      => 'No',
455                                                            Lock_time      => '0.000000',
456                                                            Merge_passes   => '0',
457                                                            QC_Hit         => 'No',
458                                                            Query_time     => '0.000012',
459                                                            Rows_examined  => '0',
460                                                            Rows_sent      => '0',
461                                                            Thread_id      => '20',
462                                                            Tmp_table      => 'No',
463                                                            arg            => 'SELECT col FROM bar_tbl',
464                                                            cmd            => 'Query',
465                                                            db             => 'bar',
466                                                            host           => '',
467                                                            ip             => '',
468                                                            pos_in_log     => '725',
469                                                            ts             => '071218 11:48:57',
470                                                            user           => '[SQL_SLAVE]',
471                                                            bytes          => 23,
472                                                         },
473                                                         {  Disk_filesort  => 'No',
474                                                            Disk_tmp_table => 'No',
475                                                            Filesort       => 'No',
476                                                            Full_join      => 'No',
477                                                            Full_scan      => 'No',
478                                                            Lock_time      => '0.000000',
479                                                            Merge_passes   => '0',
480                                                            QC_Hit         => 'No',
481                                                            Query_time     => '0.000012',
482                                                            Rows_examined  => '0',
483                                                            Rows_sent      => '0',
484                                                            Schema         => 'bar',
485                                                            Thread_id      => '10',
486                                                            Tmp_table      => 'No',
487                                                            arg            => 'SELECT col FROM bar_tbl',
488                                                            cmd            => 'Query',
489                                                            host           => '',
490                                                            ip             => '',
491                                                            pos_in_log     => '1083',
492                                                            ts             => '071218 11:49:05',
493                                                            user           => '[SQL_SLAVE]',
494                                                            bytes          => 23,
495                                                         },
496                                                         {  Disk_filesort  => 'No',
497                                                            Disk_tmp_table => 'No',
498                                                            Filesort       => 'No',
499                                                            Full_join      => 'No',
500                                                            Full_scan      => 'No',
501                                                            Lock_time      => '0.000000',
502                                                            Merge_passes   => '0',
503                                                            QC_Hit         => 'No',
504                                                            Query_time     => '0.000012',
505                                                            Rows_examined  => '0',
506                                                            Rows_sent      => '0',
507                                                            Thread_id      => '20',
508                                                            Tmp_table      => 'No',
509                                                            arg            => 'SELECT col FROM bar_tbl',
510                                                            cmd            => 'Query',
511                                                            db             => 'bar',
512                                                            host           => '',
513                                                            ip             => '',
514                                                            pos_in_log     => '1445',
515                                                            ts             => '071218 11:49:07',
516                                                            user           => '[SQL_SLAVE]',
517                                                            bytes          => 23,
518                                                         },
519                                                         {  Disk_filesort  => 'No',
520                                                            Disk_tmp_table => 'No',
521                                                            Filesort       => 'No',
522                                                            Full_join      => 'No',
523                                                            Full_scan      => 'No',
524                                                            Lock_time      => '0.000000',
525                                                            Merge_passes   => '0',
526                                                            QC_Hit         => 'No',
527                                                            Query_time     => '0.000012',
528                                                            Rows_examined  => '0',
529                                                            Rows_sent      => '0',
530                                                            Schema         => 'foo',
531                                                            Thread_id      => '30',
532                                                            Tmp_table      => 'No',
533                                                            arg            => 'SELECT col FROM foo_tbl',
534                                                            cmd            => 'Query',
535                                                            host           => '',
536                                                            ip             => '',
537                                                            pos_in_log     => '1803',
538                                                            ts             => '071218 11:49:30',
539                                                            user           => '[SQL_SLAVE]',
540                                                            bytes          => 23,
541                                                         }
542                                                      ],
543                                                   );
544                                                   
545                                                   # Schema
546            1                                139   test_log_parser(
547                                                      parser => $p,
548                                                      file   => 'common/t/samples/slow007.txt',
549                                                      result => [
550                                                         {  Schema         => 'food',
551                                                            arg            => 'SELECT fruit FROM trees',
552                                                            ts             => '071218 11:48:27',
553                                                            Disk_filesort  => 'No',
554                                                            Merge_passes   => '0',
555                                                            Full_scan      => 'No',
556                                                            Full_join      => 'No',
557                                                            Thread_id      => '3',
558                                                            Tmp_table      => 'No',
559                                                            QC_Hit         => 'No',
560                                                            Rows_examined  => '0',
561                                                            Filesort       => 'No',
562                                                            Query_time     => '0.000012',
563                                                            Disk_tmp_table => 'No',
564                                                            Rows_sent      => '0',
565                                                            Lock_time      => '0.000000',
566                                                            pos_in_log     => 0,
567                                                            cmd            => 'Query',
568                                                            user           => '[SQL_SLAVE]',
569                                                            host           => '',
570                                                            ip             => '',
571                                                            bytes          => 23,
572                                                         },
573                                                      ],
574                                                   );
575                                                   
576                                                   # Check for number of events to see that it doesn't just run forever
577                                                   # to the end of the file without returning between events.
578                                                   # Also check it parses commented event (admin cmd).
579            1                                103   test_log_parser(
580                                                      parser     => $p,
581                                                      file       => 'common/t/samples/slow008.txt',
582                                                      num_events => 3,
583                                                      result => [
584                                                         {  'Schema'        => 'db1',
585                                                            'cmd'           => 'Admin',
586                                                            'ip'            => '1.2.3.8',
587                                                            'arg'           => 'administrator command: Quit',
588                                                            'Thread_id'     => '5',
589                                                            'host'          => '',
590                                                            'Rows_examined' => '0',
591                                                            'user'          => 'meow',
592                                                            'Query_time'    => '0.000002',
593                                                            'Lock_time'     => '0.000000',
594                                                            'Rows_sent'     => '0',
595                                                            pos_in_log      => 0,
596                                                            bytes           => 27,
597                                                         },
598                                                         {  'Schema'        => 'db2',
599                                                            'cmd'           => 'Query',
600                                                            'db'            => 'db',
601                                                            'ip'            => '1.2.3.8',
602                                                            arg             => 'SET NAMES utf8',
603                                                            'Thread_id'     => '6',
604                                                            'host'          => '',
605                                                            'Rows_examined' => '0',
606                                                            'user'          => 'meow',
607                                                            'Query_time'    => '0.000899',
608                                                            'Lock_time'     => '0.000000',
609                                                            'Rows_sent'     => '0',
610                                                            pos_in_log      => 221,
611                                                            bytes           => 14,
612                                                         },
613                                                         {  'Schema'        => 'db2',
614                                                            'cmd'           => 'Query',
615                                                            'arg'           => 'SELECT MIN(id),MAX(id) FROM tbl',
616                                                            'ip'            => '1.2.3.8',
617                                                            'Thread_id'     => '6',
618                                                            'host'          => '',
619                                                            'Rows_examined' => '0',
620                                                            'user'          => 'meow',
621                                                            'Query_time'    => '0.018799',
622                                                            'Lock_time'     => '0.009453',
623                                                            'Rows_sent'     => '0',
624                                                            pos_in_log      => 435,
625                                                            bytes           => 31,
626                                                         },
627                                                      ],
628                                                   );
629                                                   
630                                                   # Parse embedded meta-attributes
631            1                                 56   test_log_parser(
632                                                      parser => $p,
633                                                      misc   => { embed   => qr/ -- .*/, capture => qr/(\w+): ([^,]+)/ },
634                                                      file   => 'common/t/samples/slow010.txt',
635                                                      result => [
636                                                         {  Lock_time     => '0',
637                                                            Query_time    => '2',
638                                                            Rows_examined => '0',
639                                                            Rows_sent     => '1',
640                                                            arg           => 'SELECT foo -- file: /user.php, line: 417, url: d217d035a34ac9e693b41d4c2&limit=500&offset=0',
641                                                            cmd           => 'Query',
642                                                            host          => 'localhost',
643                                                            ip            => '',
644                                                            pos_in_log    => '0',
645                                                            ts            => '071015 21:43:52',
646                                                            user          => 'root',
647                                                            file          => '/user.php',
648                                                            line          => '417',
649                                                            url           => 'd217d035a34ac9e693b41d4c2&limit=500&offset=0',
650                                                            bytes         => 91,
651                                                         },
652                                                      ],
653                                                   );
654                                                   
655            1                                 40   $p = new SlowLogParser;
656                                                   
657                                                   # Parses commented event lines after uncommented meta-lines
658            1                                 39   test_log_parser(
659                                                      parser => $p,
660                                                      file   => 'common/t/samples/slow011.txt',
661                                                      result => [
662                                                         {  'Schema'        => 'db1',
663                                                            'arg'           => 'administrator command: Quit',
664                                                            'ip'            => '1.2.3.8',
665                                                            'Thread_id'     => '5',
666                                                            'host'          => '',
667                                                            'Rows_examined' => '0',
668                                                            'user'          => 'meow',
669                                                            'Query_time'    => '0.000002',
670                                                            'Lock_time'     => '0.000000',
671                                                            'Rows_sent'     => '0',
672                                                            pos_in_log      => 0,
673                                                            cmd             => 'Admin',
674                                                            bytes           => 27,
675                                                         },
676                                                         {  'Schema'        => 'db2',
677                                                            'db'            => 'db',
678                                                            'ip'            => '1.2.3.8',
679                                                            arg             => 'SET NAMES utf8',
680                                                            'Thread_id'     => '6',
681                                                            'host'          => '',
682                                                            'Rows_examined' => '0',
683                                                            'user'          => 'meow',
684                                                            'Query_time'    => '0.000899',
685                                                            'Lock_time'     => '0.000000',
686                                                            'Rows_sent'     => '0',
687                                                            pos_in_log      => 221,
688                                                            cmd             => 'Query',
689                                                            bytes           => 14,
690                                                         },
691                                                         {  'Schema'        => 'db2',
692                                                            'db'            => 'db2',
693                                                            'arg'           => 'administrator command: Quit',
694                                                            'ip'            => '1.2.3.8',
695                                                            'Thread_id'     => '7',
696                                                            'host'          => '',
697                                                            'Rows_examined' => '0',
698                                                            'user'          => 'meow',
699                                                            'Query_time'    => '0.018799',
700                                                            'Lock_time'     => '0.009453',
701                                                            'Rows_sent'     => '0',
702                                                            pos_in_log      => 435,
703                                                            cmd             => 'Admin',
704                                                            bytes           => 27,
705                                                         },
706                                                         {  'Schema'        => 'db2',
707                                                            'db'            => 'db',
708                                                            'ip'            => '1.2.3.8',
709                                                            arg             => 'SET NAMES utf8',
710                                                            'Thread_id'     => '9',
711                                                            'host'          => '',
712                                                            'Rows_examined' => '0',
713                                                            'user'          => 'meow',
714                                                            'Query_time'    => '0.000899',
715                                                            'Lock_time'     => '0.000000',
716                                                            'Rows_sent'     => '0',
717                                                            pos_in_log      => 663,
718                                                            cmd             => 'Query',
719                                                            bytes           => 14,
720                                                         }
721                                                      ],
722                                                   );
723                                                   
724                                                   # events that might look like meta data
725            1                                 52   test_log_parser(
726                                                      parser => $p,
727                                                      file   => 'common/t/samples/slow012.txt',
728                                                      result => [
729                                                         {  'Schema'        => 'sab',
730                                                            'arg'           => 'SET autocommit=1',
731                                                            'ip'            => '10.1.250.19',
732                                                            'Thread_id'     => '39387',
733                                                            'host'          => '',
734                                                            'Rows_examined' => '0',
735                                                            'user'          => 'sabapp',
736                                                            'Query_time'    => '0.000018',
737                                                            'Lock_time'     => '0.000000',
738                                                            'Rows_sent'     => '0',
739                                                            pos_in_log      => 0,
740                                                            cmd             => 'Query',
741                                                            bytes           => 16,
742                                                         },
743                                                         {  'Schema'        => 'sab',
744                                                            'arg'           => 'SET autocommit=1',
745                                                            'ip'            => '10.1.250.19',
746                                                            'Thread_id'     => '39387',
747                                                            'host'          => '',
748                                                            'Rows_examined' => '0',
749                                                            'user'          => 'sabapp',
750                                                            'Query_time'    => '0.000018',
751                                                            'Lock_time'     => '0.000000',
752                                                            'Rows_sent'     => '0',
753                                                            pos_in_log      => 172,
754                                                            cmd             => 'Query',
755                                                            bytes           => 16,
756                                                         },
757                                                      ],
758                                                   );
759                                                   
760                                                   # A pathological test case to be sure a crash doesn't happen.  Has a bunch of
761                                                   # "use" and "set" and administrator commands etc.
762            1                                 72   test_log_parser(
763                                                      parser => $p,
764                                                      file   => 'common/t/samples/slow013.txt',
765                                                      result => [
766                                                         {  'Schema'        => 'abc',
767                                                            'cmd'           => 'Query',
768                                                            'arg'           => 'SET autocommit=1',
769                                                            'ip'            => '10.1.250.19',
770                                                            'Thread_id'     => '39796',
771                                                            'host'          => '',
772                                                            'pos_in_log'    => '0',
773                                                            'Rows_examined' => '0',
774                                                            'user'          => 'foo_app',
775                                                            'Query_time'    => '0.000015',
776                                                            'Rows_sent'     => '0',
777                                                            'Lock_time'     => '0.000000',
778                                                            bytes           => 16,
779                                                         },
780                                                         {  'Schema'        => 'test',
781                                                            'db'            => 'test',
782                                                            'cmd'           => 'Query',
783                                                            'arg'           => 'SHOW STATUS',
784                                                            'ip'            => '10.1.12.201',
785                                                            'ts'            => '081127  8:51:20',
786                                                            'Thread_id'     => '39947',
787                                                            'host'          => '',
788                                                            'pos_in_log'    => '174',
789                                                            'Rows_examined' => '226',
790                                                            'Query_time'    => '0.149435',
791                                                            'user'          => 'mytopuser',
792                                                            'Rows_sent'     => '226',
793                                                            'Lock_time'     => '0.000070',
794                                                            bytes           => 11,
795                                                         },
796                                                         {  'Schema'        => 'test',
797                                                            'cmd'           => 'Admin',
798                                                            'arg'           => 'administrator command: Quit',
799                                                            'ip'            => '10.1.12.201',
800                                                            'ts'            => '081127  8:51:21',
801                                                            'Thread_id'     => '39947',
802                                                            'host'          => '',
803                                                            'pos_in_log'    => '385',
804                                                            'Rows_examined' => '0',
805                                                            'Query_time'    => '0.000005',
806                                                            'user'          => 'mytopuser',
807                                                            'Rows_sent'     => '0',
808                                                            'Lock_time'     => '0.000000',
809                                                            bytes           => 27,
810                                                         },
811                                                         {  'Schema'        => 'abc',
812                                                            'db'            => 'abc',
813                                                            'cmd'           => 'Query',
814                                                            'arg'           => 'SET autocommit=0',
815                                                            'ip'            => '10.1.250.19',
816                                                            'Thread_id'     => '39796',
817                                                            'host'          => '',
818                                                            'pos_in_log'    => '600',
819                                                            'Rows_examined' => '0',
820                                                            'user'          => 'foo_app',
821                                                            'Query_time'    => '0.000067',
822                                                            'Rows_sent'     => '0',
823                                                            'Lock_time'     => '0.000000',
824                                                            bytes           => 16,
825                                                         },
826                                                         {  'Schema'        => 'abc',
827                                                            'cmd'           => 'Query',
828                                                            'arg'           => 'commit',
829                                                            'ip'            => '10.1.250.19',
830                                                            'Thread_id'     => '39796',
831                                                            'host'          => '',
832                                                            'pos_in_log'    => '782',
833                                                            'Rows_examined' => '0',
834                                                            'user'          => 'foo_app',
835                                                            'Query_time'    => '0.000015',
836                                                            'Rows_sent'     => '0',
837                                                            'Lock_time'     => '0.000000',
838                                                            bytes           => 6,
839                                                         }
840                                                      ],
841                                                   );
842                                                   
843                                                   # events with a lot of headers
844            1                                 67   test_log_parser(
845                                                      parser => $p,
846                                                      file   => 'common/t/samples/slow014.txt',
847                                                      result => [
848                                                         {  ts            => '071015 21:43:52',
849                                                            cmd           => 'Query',
850                                                            user          => 'root',
851                                                            host          => 'localhost',
852                                                            ip            => '',
853                                                            db            => 'test',
854                                                            arg           => 'select sleep(2) from n',
855                                                            Query_time    => 2,
856                                                            Lock_time     => 0,
857                                                            Rows_sent     => 1,
858                                                            Rows_examined => 0,
859                                                            pos_in_log    => 0,
860                                                            bytes         => 22,
861                                                         },
862                                                         {  ts            => '071015 21:43:52',
863                                                            cmd           => 'Query',
864                                                            user          => 'root',
865                                                            host          => 'localhost',
866                                                            ip            => '',
867                                                            db            => 'test',
868                                                            arg           => 'select sleep(2) from n',
869                                                            Query_time    => 2,
870                                                            Lock_time     => 0,
871                                                            Rows_sent     => 1,
872                                                            Rows_examined => 0,
873                                                            pos_in_log    => 1313,
874                                                            bytes         => 22,
875                                                         },
876                                                      ],
877                                                   );
878                                                   
879                                                   # No error parsing truncated event with no newline
880            1                                 29   test_log_parser(
881                                                      parser => $p,
882                                                      file   => 'common/t/samples/slow015.txt',
883                                                   );
884                                                   
885                                                   # Some more silly stuff with USE meta-data lines.
886            1                                 40   test_log_parser(
887                                                      parser => $p,
888                                                      file   => 'common/t/samples/slow016.txt',
889                                                      result => [
890                                                         {  user          => 'root',
891                                                            cmd           => 'Query',
892                                                            db            => 'user_chos',
893                                                            host          => 'localhost',
894                                                            ip            => '127.0.0.1',
895                                                            Thread_id     => 6997,
896                                                            Schema        => 'user_chos',
897                                                            Query_time    => '0.000020',
898                                                            Lock_time     => '0.000000',
899                                                            Rows_sent     => 0,
900                                                            Rows_examined => 0,
901                                                            Rows_affected => 0,
902                                                            Rows_read     => 1,
903                                                            arg           => 'USE `user_chos`',
904                                                            pos_in_log    => 0,
905                                                            bytes         => 15,
906                                                         },
907                                                         {  user          => 'user_user',
908                                                            cmd           => 'Query',
909                                                            db            => 'user_sfn',
910                                                            host          => 'my-server.myplace.net',
911                                                            ip            => '192.168.100.1',
912                                                            Thread_id     => 6996,
913                                                            Schema        => 'user_sfn',
914                                                            Query_time    => '0.000020',
915                                                            Lock_time     => '0.000000',
916                                                            Rows_sent     => 0,
917                                                            Rows_examined => 0,
918                                                            Rows_affected => 0,
919                                                            Rows_read     => 0,
920                                                            arg           => 'SELECT * FROM moderator',
921                                                            pos_in_log    => 226,
922                                                            bytes         => 23,
923                                                         },
924                                                      ],
925                                                   );
926                                                   
927                                                   # This is fixed in EventAggregator so that we can parse
928                                                   # Client: IP:port because an IP looks like a broken Query_time.
929                                                   # Check that issue 234 doesn't kill us (broken Query_time).
930                                                   #test_log_parser(
931                                                   #   parser => $p,
932                                                   #   file   => 'common/t/samples/slow017.txt',
933                                                   #   result => [
934                                                   #      {  ts            => '081116 15:07:11',
935                                                   #         cmd           => 'Query',
936                                                   #         user          => 'user',
937                                                   #         host          => 'host',
938                                                   #         ip            => '10.1.65.120',
939                                                   #         db            => 'mydb',
940                                                   #         arg           => 'SELECT * FROM mytbl',
941                                                   #         Query_time    => '18446744073708.796870',
942                                                   #         Lock_time     => '0.000036',
943                                                   #         Rows_sent     => 1,
944                                                   #         Rows_examined => 127,
945                                                   #         pos_in_log    => 0,
946                                                   #         bytes         => 19,
947                                                   #      },
948                                                   #   ],
949                                                   #});
950                                                   
951                                                   # common/t/samples/slow018.txt is a test for mk-query-digest.
952                                                   
953                                                   # Has some more combinations of meta-data and explicit query lines and
954                                                   # administrator commands.
955            1                                 58   test_log_parser(
956                                                      parser => $p,
957                                                      file   => 'common/t/samples/slow019.txt',
958                                                      result => [
959                                                         {  Lock_time     => '0.000000',
960                                                            Query_time    => '0.000002',
961                                                            Rows_examined => '3',
962                                                            Rows_sent     => '5',
963                                                            Schema        => 'db1',
964                                                            Thread_id     => '5',
965                                                            arg           => 'administrator command: Quit',
966                                                            cmd           => 'Admin',
967                                                            host          => '',
968                                                            ip            => '1.2.3.8',
969                                                            pos_in_log    => '0',
970                                                            user          => 'meow',
971                                                            bytes         => 27,
972                                                         },
973                                                         {  Lock_time     => '0.000000',
974                                                            Query_time    => '0.000899',
975                                                            Rows_examined => '3',
976                                                            Rows_sent     => '0',
977                                                            Schema        => 'db2',
978                                                            Thread_id     => '6',
979                                                            arg           => 'SET NAMES utf8',
980                                                            cmd           => 'Query',
981                                                            db            => 'db',
982                                                            host          => '',
983                                                            ip            => '1.2.3.8',
984                                                            pos_in_log    => '221',
985                                                            user          => 'meow',
986                                                            bytes         => 14,
987                                                         },
988                                                         {  Lock_time     => '0.009453',
989                                                            Query_time    => '0.018799',
990                                                            Rows_examined => '2',
991                                                            Rows_sent     => '9',
992                                                            Schema        => 'db2',
993                                                            Thread_id     => '7',
994                                                            arg           => 'administrator command: Quit',
995                                                            cmd           => 'Admin',
996                                                            db            => 'db2',
997                                                            host          => '',
998                                                            ip            => '1.2.3.8',
999                                                            pos_in_log    => '435',
1000                                                           user          => 'meow',
1001                                                           bytes         => 27,
1002                                                        }
1003                                                     ],
1004                                                  );
1005                                                  
1006                                                  # Parse files that begin with Windows paths.  It also has TWO lines of
1007                                                  # meta-data.  This is from MySQL 5.1 on Windows.
1008           1                                 46   test_log_parser(
1009                                                     parser => $p,
1010                                                     file   => 'common/t/samples/slow031.txt',
1011                                                     result => [
1012                                                        {  Lock_time     => '0.000000',
1013                                                           Query_time    => '0.453125',
1014                                                           Rows_examined => '2160',
1015                                                           Rows_sent     => '2160',
1016                                                           arg           => 'SELECT * FROM cottages',
1017                                                           cmd           => 'Query',
1018                                                           db            => 'myplace',
1019                                                           host          => 'secure.myplace.co.uk',
1020                                                           ip            => '88.208.248.160',
1021                                                           pos_in_log    => '0',
1022                                                           timestamp     => '1233019414',
1023                                                           ts            => '090127  1:23:34',
1024                                                           user          => 'swuser',
1025                                                           bytes         => 22,
1026                                                        },
1027                                                     ],
1028                                                  );
1029                                                  
1030                                                  # common/t/samples/slow021.txt is for mk-query-digest.  It has an entry without a Time.
1031                                                  
1032                                                  # common/t/samples/slow022.txt has garbled Time entries.
1033           1                                116   test_log_parser(
1034                                                     parser => $p,
1035                                                     file   => 'common/t/samples/slow022.txt',
1036                                                     result => [
1037                                                        {  Disk_filesort  => 'No',
1038                                                           Disk_tmp_table => 'No',
1039                                                           Filesort       => 'No',
1040                                                           Full_join      => 'No',
1041                                                           Full_scan      => 'No',
1042                                                           Lock_time      => '0.000000',
1043                                                           Merge_passes   => '0',
1044                                                           QC_Hit         => 'No',
1045                                                           Query_time     => '0.000012',
1046                                                           Rows_examined  => '0',
1047                                                           Rows_sent      => '0',
1048                                                           Schema         => 'foo',
1049                                                           Thread_id      => '10',
1050                                                           Tmp_table      => 'No',
1051                                                           arg            => 'SELECT col FROM foo_tbl',
1052                                                           cmd            => 'Query',
1053                                                           host           => '',
1054                                                           ip             => '',
1055                                                           pos_in_log     => '0',
1056                                                           user           => '[SQL_SLAVE]',
1057                                                           bytes         => 23,
1058                                                        },
1059                                                        {  Disk_filesort  => 'No',
1060                                                           Disk_tmp_table => 'No',
1061                                                           Filesort       => 'No',
1062                                                           Full_join      => 'No',
1063                                                           Full_scan      => 'No',
1064                                                           Lock_time      => '0.000000',
1065                                                           Merge_passes   => '0',
1066                                                           QC_Hit         => 'No',
1067                                                           Query_time     => '0.000012',
1068                                                           Rows_examined  => '0',
1069                                                           Rows_sent      => '0',
1070                                                           Schema         => 'foo',
1071                                                           Thread_id      => '10',
1072                                                           Tmp_table      => 'No',
1073                                                           arg            => 'SELECT col FROM foo_tbl',
1074                                                           cmd            => 'Query',
1075                                                           host           => '',
1076                                                           ip             => '',
1077                                                           pos_in_log     => '363',
1078                                                           user           => '[SQL_SLAVE]',
1079                                                           bytes         => 23,
1080                                                        },
1081                                                        {  Disk_filesort  => 'No',
1082                                                           Disk_tmp_table => 'No',
1083                                                           Filesort       => 'No',
1084                                                           Full_join      => 'No',
1085                                                           Full_scan      => 'No',
1086                                                           Lock_time      => '0.000000',
1087                                                           Merge_passes   => '0',
1088                                                           QC_Hit         => 'No',
1089                                                           Query_time     => '0.000012',
1090                                                           Rows_examined  => '0',
1091                                                           Rows_sent      => '0',
1092                                                           Thread_id      => '20',
1093                                                           Tmp_table      => 'No',
1094                                                           arg            => 'SELECT col FROM bar_tbl',
1095                                                           cmd            => 'Query',
1096                                                           db             => 'bar',
1097                                                           host           => '',
1098                                                           ip             => '',
1099                                                           pos_in_log     => '725',
1100                                                           user           => '[SQL_SLAVE]',
1101                                                           bytes         => 23,
1102                                                        },
1103                                                        {  Disk_filesort  => 'No',
1104                                                           Disk_tmp_table => 'No',
1105                                                           Filesort       => 'No',
1106                                                           Full_join      => 'No',
1107                                                           Full_scan      => 'No',
1108                                                           Lock_time      => '0.000000',
1109                                                           Merge_passes   => '0',
1110                                                           QC_Hit         => 'No',
1111                                                           Query_time     => '0.000012',
1112                                                           Rows_examined  => '0',
1113                                                           Rows_sent      => '0',
1114                                                           Schema         => 'bar',
1115                                                           Thread_id      => '10',
1116                                                           Tmp_table      => 'No',
1117                                                           arg            => 'SELECT col FROM bar_tbl',
1118                                                           cmd            => 'Query',
1119                                                           host           => '',
1120                                                           ip             => '',
1121                                                           pos_in_log     => '1083',
1122                                                           user           => '[SQL_SLAVE]',
1123                                                           bytes         => 23,
1124                                                        },
1125                                                        {  Disk_filesort  => 'No',
1126                                                           Disk_tmp_table => 'No',
1127                                                           Filesort       => 'No',
1128                                                           Full_join      => 'No',
1129                                                           Full_scan      => 'No',
1130                                                           Lock_time      => '0.000000',
1131                                                           Merge_passes   => '0',
1132                                                           QC_Hit         => 'No',
1133                                                           Query_time     => '0.000012',
1134                                                           Rows_examined  => '0',
1135                                                           Rows_sent      => '0',
1136                                                           Thread_id      => '20',
1137                                                           Tmp_table      => 'No',
1138                                                           arg            => 'SELECT col FROM bar_tbl',
1139                                                           cmd            => 'Query',
1140                                                           db             => 'bar',
1141                                                           host           => '',
1142                                                           ip             => '',
1143                                                           pos_in_log     => '1445',
1144                                                           user           => '[SQL_SLAVE]',
1145                                                           bytes         => 23,
1146                                                        },
1147                                                        {  Disk_filesort  => 'No',
1148                                                           Disk_tmp_table => 'No',
1149                                                           Filesort       => 'No',
1150                                                           Full_join      => 'No',
1151                                                           Full_scan      => 'No',
1152                                                           Lock_time      => '0.000000',
1153                                                           Merge_passes   => '0',
1154                                                           QC_Hit         => 'No',
1155                                                           Query_time     => '0.000012',
1156                                                           Rows_examined  => '0',
1157                                                           Rows_sent      => '0',
1158                                                           Schema         => 'foo',
1159                                                           Thread_id      => '30',
1160                                                           Tmp_table      => 'No',
1161                                                           arg            => 'SELECT col FROM foo_tbl',
1162                                                           cmd            => 'Query',
1163                                                           host           => '',
1164                                                           ip             => '',
1165                                                           pos_in_log     => '1803',
1166                                                           user           => '[SQL_SLAVE]',
1167                                                           bytes         => 23,
1168                                                        },
1169                                                     ],
1170                                                  );
1171                                                  
1172                                                  # common/t/samples/slow025.txt has an empty Schema.
1173           1                                107   test_log_parser(
1174                                                     parser => $p,
1175                                                     file   => 'common/t/samples/slow025.txt',
1176                                                     result => [
1177                                                        {  Lock_time     => '0.000066',
1178                                                           Query_time    => '17.737502',
1179                                                           Rows_examined => '0',
1180                                                           Rows_sent     => '0',
1181                                                           Schema        => '',
1182                                                           Thread_id     => '12342',
1183                                                           arg           => 'SELECT missing_a_schema_above from crash_me',
1184                                                           bytes         => 43,
1185                                                           cmd           => 'Query',
1186                                                           host          => '',
1187                                                           ip            => '10.1.12.30',
1188                                                           pos_in_log    => '0',
1189                                                           ts            => '081126 13:08:25',
1190                                                           user          => 'root'
1191                                                        }
1192                                                     ],
1193                                                  );
1194                                                  
1195                                                  # #############################################################################
1196                                                  # Test a callback chain.
1197                                                  # #############################################################################
1198           1                                 33   my $oktorun = 1;
1199                                                  
1200                                                  test_log_parser(
1201                                                     parser  => $p,
1202                                                     file    => 'common/t/samples/slow001.txt',
1203           1                    1             5      oktorun => sub { $oktorun = $_[0]; },
1204           1                                 37      result => [
1205                                                        {  ts            => '071015 21:43:52',
1206                                                           user          => 'root',
1207                                                           host          => 'localhost',
1208                                                           ip            => '',
1209                                                           db            => 'test',
1210                                                           arg           => 'select sleep(2) from n',
1211                                                           Query_time    => 2,
1212                                                           Lock_time     => 0,
1213                                                           Rows_sent     => 1,
1214                                                           Rows_examined => 0,
1215                                                           pos_in_log    => 0,
1216                                                           bytes         => length('select sleep(2) from n'),
1217                                                           cmd           => 'Query',
1218                                                        },
1219                                                        {  ts            => '071015 21:45:10',
1220                                                           db            => 'sakila',
1221                                                           user          => 'root',
1222                                                           host          => 'localhost',
1223                                                           ip            => '',
1224                                                           arg           => 'select sleep(2) from test.n',
1225                                                           Query_time    => 2,
1226                                                           Lock_time     => 0,
1227                                                           Rows_sent     => 1,
1228                                                           Rows_examined => 0,
1229                                                           pos_in_log    => 359,
1230                                                           bytes         => length('select sleep(2) from test.n'),
1231                                                           cmd           => 'Query',
1232                                                        },
1233                                                     ],
1234                                                  );
1235                                                  
1236           1                                 41   is(
1237                                                     $oktorun,
1238                                                     0,
1239                                                     'Sets oktorun'
1240                                                  );
1241                                                  
1242                                                  # #############################################################################
1243                                                  # Parse "Client: IP:port".
1244                                                  # #############################################################################
1245           1                                 22   test_log_parser(
1246                                                     parser => $p,
1247                                                     file   => 'common/t/samples/slow036.txt',
1248                                                     result => [
1249                                                        {  Lock_time     => '0.000000',
1250                                                           Query_time    => '0.000000',
1251                                                           Rows_examined => '0',
1252                                                           Rows_sent     => '0',
1253                                                           arg           => 'select * from foo',
1254                                                           bytes         => length('select * from foo'),
1255                                                           cmd           => 'Query',
1256                                                           pos_in_log    => '0',
1257                                                           ts            => '071218 11:48:27',
1258                                                           Client        => '127.0.0.1:12345',
1259                                                        }
1260                                                     ],
1261                                                  );
1262                                                  
1263                                                  # #############################################################################
1264                                                  # Done.
1265                                                  # #############################################################################
1266           1                                 42   my $output = '';
1267                                                  {
1268           1                                  4      local *STDERR;
               1                                 12   
1269           1                    1             3      open STDERR, '>', \$output;
               1                                530   
               1                                  4   
               1                                 11   
1270           1                                 28      $p->_d('Complete test coverage');
1271                                                  }
1272                                                  like(
1273           1                                 24      $output,
1274                                                     qr/Complete test coverage/,
1275                                                     '_d() works'
1276                                                  );
1277           1                                  4   exit;


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
---------- ----- --------------------
BEGIN          1 SlowLogParser.t:10  
BEGIN          1 SlowLogParser.t:11  
BEGIN          1 SlowLogParser.t:12  
BEGIN          1 SlowLogParser.t:1269
BEGIN          1 SlowLogParser.t:14  
BEGIN          1 SlowLogParser.t:15  
BEGIN          1 SlowLogParser.t:4   
BEGIN          1 SlowLogParser.t:9   
__ANON__       1 SlowLogParser.t:1203


