---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlowLogParser.pm   93.9   94.1   83.3   87.5    n/a  100.0   91.8
Total                          93.9   94.1   83.3   87.5    n/a  100.0   91.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SlowLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:21:04 2009
Finish:       Wed Jun 10 17:21:04 2009

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
18                                                    # SlowLogParser package $Revision: 3192 $
19                                                    # ###########################################################################
20                                                    package SlowLogParser;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
25             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                 13   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
28                                                    
29                                                    sub new {
30             2                    2            58      my ( $class ) = @_;
31             2                                 19      bless {}, $class;
32                                                    }
33                                                    
34                                                    my $slow_log_ts_line = qr/^# Time: ([0-9: ]{15})/;
35                                                    my $slow_log_uh_line = qr/# User\@Host: ([^\[]+|\[[^[]+\]).*?@ (\S*) \[(.*)\]/;
36                                                    # These can appear in the log file when it's opened -- for example, when someone
37                                                    # runs FLUSH LOGS or the server starts.
38                                                    # /usr/sbin/mysqld, Version: 5.0.67-0ubuntu6-log ((Ubuntu)). started with:
39                                                    # Tcp port: 3306  Unix socket: /var/run/mysqld/mysqld.sock
40                                                    # Time                 Id Command    Argument
41                                                    # These lines vary depending on OS and whether it's embedded.
42                                                    my $slow_log_hd_line = qr{
43                                                          ^(?:
44                                                          T[cC][pP]\s[pP]ort:\s+\d+ # case differs on windows/unix
45                                                          |
46                                                          [/A-Z].*mysqld,\sVersion.*(?:started\swith:|embedded\slibrary)
47                                                          |
48                                                          Time\s+Id\s+Command
49                                                          ).*\n
50                                                       }xm;
51                                                    
52                                                    # This method accepts an open slow log filehandle and callback functions.
53                                                    # It reads events from the filehandle and calls the callbacks with each event.
54                                                    # It may find more than one event per call.  $misc is some placeholder for the
55                                                    # future and for compatibility with other query sources.
56                                                    #
57                                                    # Each event is a hashref of attribute => value pairs like:
58                                                    #  my $event = {
59                                                    #     ts  => '',    # Timestamp
60                                                    #     id  => '',    # Connection ID
61                                                    #     arg => '',    # Argument to the command
62                                                    #     other attributes...
63                                                    #  };
64                                                    #
65                                                    # Returns the number of events it finds.
66                                                    #
67                                                    # NOTE: If you change anything inside this subroutine, you need to profile
68                                                    # the result.  Sometimes a line of code has been changed from an alternate
69                                                    # form for performance reasons -- sometimes as much as 20x better performance.
70                                                    sub parse_event {
71            87                   87          4300      my ( $self, $fh, $misc, @callbacks ) = @_;
72            87                                270      my $num_events = 0;
73                                                    
74                                                       # Read a whole stmt at a time.  But, to make things even more fun, sometimes
75                                                       # part of the log entry might continue past the separator.  In these cases we
76                                                       # peek ahead (see code below.)  We do it this way because in the general
77                                                       # case, reading line-by-line is too slow, and the special-case code is
78                                                       # acceptable.  And additionally, the line terminator doesn't work for all
79                                                       # cases; the header lines might follow a statement, causing the paragraph
80                                                       # slurp to grab more than one statement at a time.
81            87                                199      my @pending;
82            87                                392      local $INPUT_RECORD_SEPARATOR = ";\n#";
83            87                                281      my $trimlen    = length($INPUT_RECORD_SEPARATOR);
84            87                                323      my $pos_in_log = tell($fh);
85            87                                198      my $stmt;
86                                                    
87                                                       EVENT:
88            87           100                 2082      while ( defined($stmt = shift @pending) or defined($stmt = <$fh>) ) {
89            66                                302         my @properties = ('cmd', 'Query', 'pos_in_log', $pos_in_log);
90            66                                206         $pos_in_log = tell($fh);
91                                                    
92                                                          # If there were such lines in the file, we may have slurped > 1 event.
93                                                          # Delete the lines and re-split if there were deletes.  This causes the
94                                                          # pos_in_log to be inaccurate, but that's really okay.
95            66    100                         826         if ( $stmt =~ s/$slow_log_hd_line//go ){ # Throw away header lines in log
96             4                                 38            my @chunks = split(/$INPUT_RECORD_SEPARATOR/o, $stmt);
97             4    100                          24            if ( @chunks > 1 ) {
98             1                                  3               MKDEBUG && _d("Found multiple chunks");
99             1                                  3               $stmt = shift @chunks;
100            1                                  5               unshift @pending, @chunks;
101                                                            }
102                                                         }
103                                                   
104                                                         # There might not be a leading '#' because $INPUT_RECORD_SEPARATOR will
105                                                         # have gobbled that up.  And the end may have all/part of the separator.
106           66    100                         350         $stmt = '#' . $stmt unless $stmt =~ m/\A#/;
107           66                                383         $stmt =~ s/;\n#?\Z//;
108                                                   
109                                                         # The beginning of a slow-query-log event should be something like
110                                                         # # Time: 071015 21:43:52
111                                                         # Or, it might look like this, sometimes at the end of the Time: line:
112                                                         # # User@Host: root[root] @ localhost []
113                                                   
114                                                         # The following line contains variables intended to be sure we do
115                                                         # particular things once and only once, for those regexes that will
116                                                         # match only one line per event, so we don't keep trying to re-match
117                                                         # regexes.
118           66                                228         my ($got_ts, $got_uh, $got_ac, $got_db, $got_set, $got_embed);
119           66                                171         my $pos = 0;
120           66                                194         my $len = length($stmt);
121           66                                164         my $found_arg = 0;
122                                                         LINE:
123           66                                362         while ( $stmt =~ m/^(.*)$/mg ) { # /g is important, requires scalar match.
124          425                               1208            $pos     = pos($stmt);  # Be careful not to mess this up!
125          425                               1455            my $line = $1;          # Necessary for /g and pos() to work.
126          425                                916            MKDEBUG && _d($line);
127                                                   
128                                                            # Handle meta-data lines.  These are case-sensitive.  If they appear in
129                                                            # the log with a different case, they are from a user query, not from
130                                                            # something printed out by sql/log.cc.
131          425    100                        1839            if ($line =~ m/^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) {
132                                                   
133                                                               # Maybe it's the beginning of the slow query log event.  XXX
134                                                               # something to know: Perl profiling reports this line as the hot
135                                                               # spot for any of the conditions in the whole if/elsif/elsif
136                                                               # construct.  So if this line looks "hot" then profile each
137                                                               # condition separately.
138          366    100    100                 6655               if ( !$got_ts && (my ( $time ) = $line =~ m/$slow_log_ts_line/o)) {
                    100    100                        
      ***           100     66                        
                    100    100                        
      ***           100     66                        
                    100                               
139           26                                 57                  MKDEBUG && _d("Got ts", $time);
140           26                                 94                  push @properties, 'ts', $time;
141           26                                 75                  ++$got_ts;
142                                                                  # The User@Host might be concatenated onto the end of the Time.
143   ***     26    100     66                  327                  if ( !$got_uh
144                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
145                                                                  ) {
146           12                                 27                     MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
147           12                                 52                     push @properties, 'user', $user, 'host', $host, 'ip', $ip;
148           12                                 37                     ++$got_uh;
149                                                                  }
150                                                               }
151                                                   
152                                                               # Maybe it's the user/host line of a slow query log
153                                                               # # User@Host: root[root] @ localhost []
154                                                               elsif ( !$got_uh
155                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
156                                                               ) {
157           53                                121                  MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
158           53                                256                  push @properties, 'user', $user, 'host', $host, 'ip', $ip;
159           53                                160                  ++$got_uh;
160                                                               }
161                                                   
162                                                               # A line that looks like meta-data but is not:
163                                                               # # administrator command: Quit;
164                                                               elsif (!$got_ac && $line =~ m/^# (?:administrator command:.*)$/) {
165            4                                 12                  MKDEBUG && _d("Got admin command");
166            4                                 17                  push @properties, 'cmd', 'Admin', 'arg', $line;
167            4                                 16                  push @properties, 'bytes', length($properties[-1]);
168            4                                 10                  ++$found_arg;
169            4                                 11                  ++$got_ac;
170                                                               }
171                                                   
172                                                               # Maybe it's the timing line of a slow query log, or another line
173                                                               # such as that... they typically look like this:
174                                                               # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
175                                                               # If issue 234 bites us, we may see something like
176                                                               # Query_time: 18446744073708.796870.000036 so we trim after the
177                                                               # second decimal place for numbers.
178                                                               elsif ( $line =~ m/^# +[A-Z][A-Za-z_]+: \S+/ ) { # Make the test cheap!
179          217                                469                  MKDEBUG && _d("Got some line with properties");
180                                                                  # I tried using split, but coping with the above bug makes it
181                                                                  # slower than a complex regex match.
182          217                               2385                  my @temp = $line =~ m/(\w+):\s+(\d+(?:\.\d+)?|\S+|\Z)/g;
183          217                               1177                  push @properties, @temp;
184                                                               }
185                                                   
186                                                               # Include the current default database given by 'use <db>;'  Again
187                                                               # as per the code in sql/log.cc this is case-sensitive.
188                                                               elsif ( !$got_db && (my ( $db ) = $line =~ m/^use ([^;]+)/ ) ) {
189           24                                 53                  MKDEBUG && _d("Got a default database:", $db);
190           24                                 84                  push @properties, 'db', $db;
191           24                                 61                  ++$got_db;
192                                                               }
193                                                   
194                                                               # Some things you might see in the log output, as printed by
195                                                               # sql/log.cc (this time the SET is uppercaes, and again it is
196                                                               # case-sensitive).
197                                                               # SET timestamp=foo;
198                                                               # SET timestamp=foo,insert_id=123;
199                                                               # SET insert_id=123;
200                                                               elsif (!$got_set && (my ($setting) = $line =~ m/^SET\s+([^;]*)/)) {
201                                                                  # Note: this assumes settings won't be complex things like
202                                                                  # SQL_MODE, which as of 5.0.51 appears to be true (see sql/log.cc,
203                                                                  # function MYSQL_LOG::write(THD, char*, uint, time_t)).
204            8                                 18                  MKDEBUG && _d("Got some setting:", $setting);
205            8                                 88                  push @properties, split(/,|\s*=\s*/, $setting);
206            8                                 24                  ++$got_set;
207                                                               }
208                                                   
209                                                               # Handle pathological special cases. The "# administrator command"
210                                                               # is one example: it can come AFTER lines that are not commented,
211                                                               # so it looks like it belongs to the next event, and it won't be
212                                                               # in $stmt. Profiling shows this is an expensive if() so we do
213                                                               # this only if we've seen the user/host line.
214          366    100    100                 3997               if ( !$found_arg && $pos == $len ) {
215            3                                  7                  MKDEBUG && _d("Did not find arg, looking for special cases");
216            3                                 17                  local $INPUT_RECORD_SEPARATOR = ";\n";
217            3    100                          17                  if ( defined(my $l = <$fh>) ) {
218            2                                  7                     chomp $l;
219            2                                  5                     MKDEBUG && _d("Found admin statement", $l);
220            2                                  9                     push @properties, 'cmd', 'Admin', 'arg', '#' . $l;
221            2                                  7                     push @properties, 'bytes', length($properties[-1]);
222            2                                 14                     $found_arg++;
223                                                                  }
224                                                                  else {
225                                                                     # Unrecoverable -- who knows what happened.  This is possible,
226                                                                     # for example, if someone does something like "head -c 10000
227                                                                     # /path/to/slow.log | mk-log-parser".  Or if there was a
228                                                                     # server crash and the file has no newline.
229            1                                  3                     MKDEBUG && _d("I can't figure out what to do with this line");
230            1                                 14                     next EVENT;
231                                                                  }
232                                                               }
233                                                            }
234                                                            else {
235                                                               # This isn't a meta-data line.  It's the first line of the
236                                                               # whole query. Grab from here to the end of the string and
237                                                               # put that into the 'arg' for the event.  Then we are done.
238                                                               # Note that if this line really IS the query but we skip in
239                                                               # the 'if' above because it looks like meta-data, later
240                                                               # we'll remedy that.
241           59                                129               MKDEBUG && _d("Got the query/arg line");
242           59                                251               my $arg = substr($stmt, $pos - length($line));
243           59                                245               push @properties, 'arg', $arg, 'bytes', length($arg);
244                                                               # Handle embedded attributes.
245   ***     59    100     66                  387               if ( $misc && $misc->{embed}
      ***                   66                        
246                                                                  && ( my ($e) = $arg =~ m/($misc->{embed})/)
247                                                               ) {
248            1                                 13                  push @properties, $e =~ m/$misc->{capture}/g;
249                                                               }
250           59                                174               last LINE;
251                                                            }
252                                                         }
253                                                   
254           65                                143         MKDEBUG && _d('Properties of event:', Dumper(\@properties));
255           65                                758         my $event = { @properties };
256           65                                233         foreach my $callback ( @callbacks ) {
257           72    100                         393            last unless $event = $callback->($event);
258                                                         }
259           65                                727         ++$num_events;
260           65    100                         442         last EVENT unless @pending;
261                                                      }
262           87                               1016      return $num_events;
263                                                   }
264                                                   
265                                                   sub _d {
266   ***      0                    0                    my ($package, undef, $line) = caller 0;
267   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
268   ***      0                                              map { defined $_ ? $_ : 'undef' }
269                                                           @_;
270   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
271                                                   }
272                                                   
273                                                   1;
274                                                   
275                                                   # ###########################################################################
276                                                   # End SlowLogParser package
277                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
95           100      4     62   if ($stmt =~ s/$slow_log_hd_line//go)
97           100      1      3   if (@chunks > 1)
106          100     43     23   unless $stmt =~ /\A#/
131          100    366     59   if ($line =~ /^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) { }
138          100     26    340   if (not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o) { }
             100     53    287   elsif (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o) { }
             100      4    283   elsif (not $got_ac and $line =~ /^# (?:administrator command:.*)$/) { }
             100    217     66   elsif ($line =~ /^# +[A-Z][A-Za-z_]+: \S+/) { }
             100     24     42   elsif (not $got_db and my($db) = $line =~ /^use ([^;]+)/) { }
             100      8     34   elsif (not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/) { }
143          100     12     14   if (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o)
214          100      3    363   if (not $found_arg and $pos == $len)
217          100      2      1   if (defined(my $l = <$fh>)) { }
245          100      1     58   if ($misc and $$misc{'embed'} and my($e) = $arg =~ /($$misc{'embed'})/)
257          100      3     69   unless $event = &$callback($event)
260          100     64      1   unless @pending
267   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
138          100     97    243     26   not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o
             100    285      2     53   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
      ***     66      0    283      4   not $got_ac and $line =~ /^# (?:administrator command:.*)$/
             100      2     40     24   not $got_db and my($db) = $line =~ /^use ([^;]+)/
      ***     66      0     34      8   not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/
143   ***     66      0     14     12   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
214          100      4    359      3   not $found_arg and $pos == $len
245   ***     66     58      0      1   $misc and $$misc{'embed'}
      ***     66     58      0      1   $misc and $$misc{'embed'} and my($e) = $arg =~ /($$misc{'embed'})/

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
88           100      1     65     23   defined($stmt = shift @pending) or defined($stmt = <$fh>)


Covered Subroutines
-------------------

Subroutine  Count Location                                            
----------- ----- ----------------------------------------------------
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:22 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:23 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:24 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:25 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:27 
new             2 /home/daniel/dev/maatkit/common/SlowLogParser.pm:30 
parse_event    87 /home/daniel/dev/maatkit/common/SlowLogParser.pm:71 

Uncovered Subroutines
---------------------

Subroutine  Count Location                                            
----------- ----- ----------------------------------------------------
_d              0 /home/daniel/dev/maatkit/common/SlowLogParser.pm:266


