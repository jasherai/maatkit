---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/LogParser.pm   92.6   86.8   78.6   88.9    n/a  100.0   88.2
Total                          92.6   86.8   78.6   88.9    n/a  100.0   88.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          LogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:19:53 2009
Finish:       Wed Jun 10 17:19:53 2009

/home/daniel/dev/maatkit/common/LogParser.pm

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
18                                                    # LogParser package $Revision: 3186 $
19                                                    # ###########################################################################
20                                                    package LogParser;
21                                                    
22             1                    1            12   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  8   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25                                                    
26             1                    1            11   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 13   
27                                                    
28                                                    sub new {
29             1                    1            14      my ( $class ) = @_;
30             1                                 13      bless {}, $class;
31                                                    }
32                                                    
33                                                    my $general_log_first_line = qr{
34                                                       \A
35                                                       (?:(\d{6}\s+\d{1,2}:\d\d:\d\d)|\t)? # Timestamp
36                                                       \t
37                                                       (?:\s*(\d+))                        # Thread ID
38                                                       \s
39                                                       (.*)                                # Everything else
40                                                       \Z
41                                                    }xs;
42                                                    
43                                                    my $general_log_any_line = qr{
44                                                       \A(
45                                                          Connect
46                                                          |Field\sList
47                                                          |Init\sDB
48                                                          |Query
49                                                          |Quit
50                                                       )
51                                                       (?:\s+(.*\Z))?
52                                                    }xs;
53                                                    
54                                                    my $slow_log_ts_line = qr/^# Time: (\d{6}\s+\d{1,2}:\d\d:\d\d)/;
55                                                    my $slow_log_uh_line = qr/# User\@Host: ([^\[]+|\[[^[]+\]).*?@ (\S*) \[(.*)\]/;
56                                                    
57                                                    my $binlog_line_1 = qr{^# at (\d+)};
58                                                    my $binlog_line_2 = qr/^#(\d{6}\s+\d{1,2}:\d\d:\d\d)\s+server\s+id\s+(\d+)\s+end_log_pos\s+(\d+)\s+(\S+)\s*([^\n]*)$/;
59                                                    my $binlog_line_2_rest = qr{Query\s+thread_id=(\d+)\s+exec_time=(\d+)\s+error_code=(\d+)};
60                                                    
61                                                    # This method accepts an open filehandle, a callback function, and a mode
62                                                    # (slow, log, undef).  It reads events from the filehandle and calls the
63                                                    # callback with each event.
64                                                    #
65                                                    # Each event looks like this:
66                                                    #  my $event = {
67                                                    #     ts  => '',    # Timestamp
68                                                    #     id  => '',    # Connection ID
69                                                    #     cmd => '',    # Command (type of event)
70                                                    #     arg => '',    # Argument to the command
71                                                    #  };
72                                                    #
73                                                    # Returns true if it was able to find an event.  It auto-detects the log
74                                                    # format most of the time.
75                                                    sub parse_event {
76            50                   50          1355      my ( $self, $fh, $code, $mode ) = @_;
77            50                                131      my $event; # Don't initialize, that'll cause a loop.
78                                                    
79            50                                136      my $done = 0;
80            50                                135      my $type = 0; # 0 = comments, 1 = USE and SET etc, 2 = the actual query
81            50    100                       16843      my $line = defined $self->{last_line} ? $self->{last_line} : <$fh>;
82    ***     50            50                  220      $mode  ||= '';
83                                                    
84                                                       LINE:
85            50           100                  474      while ( !$done && defined $line ) {
86           248                                554         MKDEBUG && _d('type:', $type, $line);
87           248                                686         my $handled_line = 0;
88                                                    
89           248    100    100                 1455         if ( !$mode && $line =~ m/^# [A-Z]/ ) {
90            29                                 67            MKDEBUG && _d('Setting mode to slow log');
91    ***     29            50                  174            $mode ||= 'slow';
92                                                          }
93                                                    
94                                                          # These can appear in the log file when it's opened -- for example, when
95                                                          # someone runs FLUSH LOGS.
96           248    100    100                 2099         if ( $line =~ m/Version:.+ started with:/ ) {
                    100                               
                    100                               
97             2                                  5            MKDEBUG && _d('Chomping out header lines');
98             2                                 12            <$fh>; # Tcp port: etc
99             2                                  9            <$fh>; # Column headers
100            2                                  8            $line = <$fh>;
101            2                                  7            $type = 0;
102            2                                  8            redo LINE;
103                                                         }
104                                                   
105                                                         # Match the beginning of an event in the general log.
106                                                         elsif ( $mode ne 'slow'
107                                                            && (my ( $ts, $id, $rest ) = $line =~ m/$general_log_first_line/s)
108                                                         ) {
109           15                                 32            MKDEBUG && _d('Beginning of general log event');
110           15                                 40            $handled_line = 1;
111           15           100                   55            $mode ||= 'log';
112           15                                 49            $self->{last_line} = undef;
113           15    100                          51            if ( $type == 0 ) {
114           11                                 22               MKDEBUG && _d('Type 0');
115           11                                114               my ( $cmd, $arg ) = $rest =~ m/$general_log_any_line/;
116           11           100                  123               $event = {
                           100                        
117                                                                  ts  => $ts || '',
118                                                                  id  => $id,
119                                                                  cmd => $cmd,
120                                                                  arg => $arg || '',
121                                                               };
122           11    100                          44               if ( $cmd ne 'Query' ) {
123            7                                 14                  MKDEBUG && _d('Not a query, done with this event');
124            7                                 19                  $done = 1;
125            7    100                          35                  chomp $event->{arg} if $event->{arg};
126                                                               }
127           11                                 34               $type = 2;
128                                                            }
129                                                            else {
130                                                               # The last line was the end of the query; this is the beginning of
131                                                               # the next.  Save it for the next round.
132            4                                  9               MKDEBUG && _d('Saving line for next invocation');
133            4                                 15               $self->{last_line} = $line;
134            4                                 13               $done = 1;
135   ***      4     50                          22               chomp $event->{arg} if $event->{arg};
136                                                            }
137                                                         }
138                                                   
139                                                         elsif ( $mode eq 'slow' ) {
140   ***    228    100     66                 4171            if ( $line =~ m/^# No InnoDB statistics available/ ) {
                    100                               
                    100                               
                    100                               
141           18                                 51               $handled_line = 1;
142           18                                 44               MKDEBUG && _d('Ignoring line');
143           18                                 55               $line = <$fh>;
144           18                                 48               $type = 0;
145           18                                160               next LINE;
146                                                            }
147                                                   
148                                                            # Maybe it's the beginning of a slow query log event.
149                                                            # # Time: 071015 21:43:52
150                                                            elsif ( my ( $time ) = $line =~ m/$slow_log_ts_line/ ) {
151           22                                 62               $handled_line = 1;
152           22                                 52               MKDEBUG && _d('Beginning of slow log event');
153           22                                 81               $self->{last_line} = undef;
154           22    100                          87               if ( $type == 0 ) {
155           14                                 54                  MKDEBUG && _d('Type 0');
156           14                                 73                  $event->{ts} = $time;
157                                                                  # The User@Host might be concatenated onto the end of the Time.
158           14    100                         183                  if ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/ ) {
159           10                                 46                     @{$event}{qw(user host ip)} = ($user, $host, $ip);
              10                                 69   
160                                                                  }
161                                                               }
162                                                               else {
163                                                                  # Last line was the end of a query; this is the beginning of the
164                                                                  # next.
165            8                                 21                  MKDEBUG && _d('Saving line for next invocation');
166            8                                 28                  $self->{last_line} = $line;
167            8                                 24                  $done = 1;
168                                                               }
169           22                                 90               $type = 0;
170                                                            }
171                                                   
172                                                            # Maybe it's the user/host line of a slow query log, which could be the
173                                                            # first line of a new event in many cases.
174                                                            # # User@Host: root[root] @ localhost []
175                                                            elsif ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/ ) {
176           30                                 81               $handled_line = 1;
177           30    100                         111               if ( $type == 0 ) {
178           18                                 38                  MKDEBUG && _d('Type 0');
179           18                                 70                  @{$event}{qw(user host ip)} = ($user, $host, $ip);
              18                                118   
180                                                               }
181                                                               else {
182                                                                  # Last line was the end of a query; this is the beginning of the
183                                                                  # next.
184           12                                 26                  MKDEBUG && _d('Saving line for next invocation');
185           12                                 43                  $self->{last_line} = $line;
186           12                                 34                  $done = 1;
187                                                               }
188           30                                116               $type = 0;
189                                                            }
190                                                   
191                                                            # Maybe it's the timing line of a slow query log, or another line such
192                                                            # as that... they typically look like this:
193                                                            # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
194                                                            elsif ( $line =~ m/^# / && (my %hash = $line =~ m/(\w+):\s+(\S+)/g ) ) {
195                                                   
196   ***    107    100     33                  400               if ( $type == 0 ) {
      ***            50                               
197                                                                  # Handle commented events like # administrator command: Quit;
198          106    100                         395                  if ( $line =~ m/^#.+;/ ) {
199            2                                  8                     MKDEBUG && _d('Commented event line ends header');
200                                                                  }
201                                                                  else {
202          104                                274                     $handled_line = 1;
203          104                                230                     MKDEBUG && _d('Splitting line into fields');
204          104                                502                     @{$event}{keys %hash} = values %hash;
             104                                648   
205                                                                  }
206                                                               }
207                                                               elsif ( $type == 1 && $line =~ m/^#.+;/ ) {
208                                                                  # Handle commented event lines preceded by other lines; e.g.:
209                                                                  # USE db;
210                                                                  # # administrator command: Quit;
211            1                                  3                  MKDEBUG && _d('Commented event line after type 1 line');
212            1                                  4                  $handled_line = 0;
213                                                               }
214                                                               else {
215                                                                  # Last line was the end of a query; this is the beginning of the
216                                                                  # next.
217   ***      0                                  0                  $handled_line = 1;
218   ***      0                                  0                  MKDEBUG && _d('Saving line for next invocation');
219   ***      0                                  0                  $self->{last_line} = $line;
220   ***      0                                  0                  $done = 1;
221                                                               }
222          107                                463               $type = 0;
223                                                            }
224                                                         }
225                                                   
226          228    100                         999         if ( !$handled_line ) {
227           57                                207            $event->{cmd} = 'Query';
228           57    100    100                  525            if ( $mode eq 'slow' && $line =~ m/;\s+\Z/ ) {
229           41                                 92               MKDEBUG && _d('Line is the end of a query within event');
230           41    100    100                  409               if ( my ( $db ) = $line =~ m/^use (.*);/i ) {
                    100                               
231            9                                 22                  MKDEBUG && _d('Setting event DB to', $db);
232            9                                 35                  $event->{db} = $db;
233            9                                 30                  $type = 1;
234                                                               }
235                                                               elsif ( $type < 2 && (my ( $setting ) = $line =~ m/^(SET .*);\s+\Z/ ) ) {
236            7                                 17                  MKDEBUG && _d('Setting a property for event');
237            7                                 17                  push @{$event->{settings}}, $setting;
               7                                 36   
238            7                                 23                  $type = 1;
239                                                               }
240                                                               else {
241           25                                 61                  MKDEBUG && _d('Line is a continuation of prev line');
242           25    100                         101                  if ( $line =~ m/^# / ) {
243                                                                     # Example: # administrator command: Quit
244            3                                 10                     MKDEBUG && _d('Line is a commented event line');
245            3                                 35                     $line =~ s/.+: (.+);\n/$1/;
246            3                                 15                     $event->{cmd} = 'Admin';
247                                                                  }
248           25                                104                  $event->{arg} .= $line;
249           25                                 85                  $type = 2;
250                                                               }
251                                                            }
252                                                            else {
253           16                                 34               MKDEBUG && _d('Line is a continuation of prev line');
254           16                                 67               $event->{arg} .= $line;
255           16                                 48               $type = 2;
256                                                            }
257                                                         }
258                                                   
259                                                         # TODO: I think $NR may be misleading because Perl may not distinguish
260                                                         # one file from the next.
261          228                                844         $event->{NR} = $NR;
262                                                   
263          228    100                        2373         $line = <$fh> unless $done;
264                                                      }
265                                                   
266                                                      # If it was EOF, discard the last line so statefulness doesn't interfere with
267                                                      # the next log file.
268           50    100                         218      if ( !defined $line ) {
269           19                                 45         MKDEBUG && _d('EOF found');
270           19                                 74         $self->{last_line} = undef;
271                                                      }
272                                                   
273           50    100    100                  383      if ( $mode && $mode eq 'slow' ) {
274           29                                 73         MKDEBUG && _d('Slow log, trimming');
275           29    100                         200         $event->{arg} =~ s/;\s*\Z// if $event->{arg};
276                                                      }
277                                                   
278   ***     50    100     66                  431      $code->($event) if $event && $code;
279           50                                680      return $event;
280                                                   }
281                                                   
282                                                   # This method accepts an open slow log filehandle and callback functions.
283                                                   # It reads events from the filehandle and calls the callbacks with each event.
284                                                   # It may find more than one event per call.  $misc is some placeholder for the
285                                                   # future and for compatibility with other query sources.
286                                                   #
287                                                   # Each event is a hashref of attribute => value pairs like:
288                                                   #  my $event = {
289                                                   #     ts  => '',    # Timestamp
290                                                   #     id  => '',    # Connection ID
291                                                   #     arg => '',    # Argument to the command
292                                                   #     other attributes...
293                                                   #  };
294                                                   #
295                                                   # Returns the number of events it finds.
296                                                   #
297                                                   # NOTE: If you change anything inside this subroutine, you need to profile
298                                                   # the result.  Sometimes a line of code has been changed from an alternate
299                                                   # form for performance reasons -- sometimes as much as 20x better performance.
300                                                   #
301                                                   # TODO: pass in hooks to let something filter out events as early as possible
302                                                   # without parsing more of them than needed.
303                                                   sub parse_slowlog_event {
304           55                   55          1834      my ( $self, $fh, $misc, @callbacks ) = @_;
305           55                                164      my $num_events = 0;
306                                                   
307                                                      # Read a whole stmt at a time.  But, to make things even more fun, sometimes
308                                                      # part of the log entry might continue past the separator.  In these cases we
309                                                      # peek ahead (see code below.)  We do it this way because in the general
310                                                      # case, reading line-by-line is too slow, and the special-case code is
311                                                      # acceptable.  And additionally, the line terminator doesn't work for all
312                                                      # cases; the header lines might follow a statement, causing the paragraph
313                                                      # slurp to grab more than one statement at a time.
314           55                                131      my @pending;
315           55                                257      local $INPUT_RECORD_SEPARATOR = ";\n#";
316           55                                188      my $trimlen    = length($INPUT_RECORD_SEPARATOR);
317           55                                190      my $pos_in_log = tell($fh);
318           55                                127      my $stmt;
319                                                   
320                                                      EVENT:
321           55           100                 1582      while ( defined($stmt = shift @pending) or defined($stmt = <$fh>) ) {
322           42                                192         my @properties = ('cmd', 'Query', 'pos_in_log', $pos_in_log);
323           42                                138         $pos_in_log = tell($fh);
324                                                   
325                                                         # These can appear in the log file when it's opened -- for example, when
326                                                         # someone runs FLUSH LOGS or the server starts.
327                                                         # /usr/sbin/mysqld, Version: 5.0.67-0ubuntu6-log ((Ubuntu)). started with:
328                                                         # Tcp port: 3306  Unix socket: /var/run/mysqld/mysqld.sock
329                                                         # Time                 Id Command    Argument
330                                                         # If there were such lines in the file, we may have slurped > 1 event.
331                                                         # Delete the lines and re-split if there were deletes.  This causes the
332                                                         # pos_in_log to be inaccurate, but that's really okay.
333           42    100                         421         if ( $stmt =~ s{
334                                                               ^(?:
335                                                               Tcp\sport:\s+\d+
336                                                               |
337                                                               /.*Version.*started
338                                                               |
339                                                               Time\s+Id\s+Command
340                                                               ).*\n
341                                                            }{}gmxo
342                                                         ){
343            2                                 38            my @chunks = split(/$INPUT_RECORD_SEPARATOR/o, $stmt);
344            2    100                          16            if ( @chunks > 1 ) {
345            1                                  4               $stmt = shift @chunks;
346            1                                  6               unshift @pending, @chunks;
347                                                            }
348                                                         }
349                                                   
350                                                         # There might not be a leading '#' because $INPUT_RECORD_SEPARATOR will
351                                                         # have gobbled that up.  And the end may have all/part of the separator.
352           42    100                         236         $stmt = '#' . $stmt unless $stmt =~ m/\A#/;
353           42                                224         $stmt =~ s/;\n#?\Z//;
354                                                   
355                                                         # The beginning of a slow-query-log event should be something like
356                                                         # # Time: 071015 21:43:52
357                                                         # Or, it might look like this, sometimes at the end of the Time: line:
358                                                         # # User@Host: root[root] @ localhost []
359                                                   
360                                                         # The following line contains variables intended to be sure we do
361                                                         # particular things once and only once, for those regexes that will
362                                                         # match only one line per event, so we don't keep trying to re-match
363                                                         # regexes.
364           42                                134         my ($got_ts, $got_uh, $got_ac, $got_db, $got_set);
365           42                                121         my $pos = 0;
366           42                                120         my $len = length($stmt);
367           42                                105         my $found_arg = 0;
368                                                         LINE:
369           42                                266         while ( $stmt =~ m/^(.*)$/mg ) { # /g is important, requires scalar match.
370          259                                756            $pos     = pos($stmt);  # Be careful not to mess this up!
371          259                                910            my $line = $1;          # Necessary for /g and pos() to work.
372                                                   
373                                                            # Handle meta-data lines.
374          259    100                        1176            if ($line =~ m/^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/oi) {
375                                                   
376                                                               # Maybe it's the beginning of the slow query log event.
377          223    100    100                 6078               if ( !$got_ts
      ***           100     66                        
                    100    100                        
      ***           100     66                        
      ***           100     66                        
      ***           100     66                        
                           100                        
      ***                   66                        
      ***                   66                        
      ***                   66                        
378                                                                  && (my ( $time ) = $line =~ m/$slow_log_ts_line/o)
379                                                                  && ++$got_ts
380                                                               ) {
381           20                                 74                  push @properties, 'ts', $time;
382                                                                  # The User@Host might be concatenated onto the end of the Time.
383   ***     20    100     66                  332                  if ( !$got_uh
      ***                   66                        
384                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
385                                                                     && ++$got_uh
386                                                                  ) {
387           11                                 62                     push @properties, 'user', $user, 'host', $host, 'ip', $ip;
388                                                                  }
389                                                               }
390                                                   
391                                                               # Maybe it's the user/host line of a slow query log
392                                                               # # User@Host: root[root] @ localhost []
393                                                               elsif ( !$got_uh
394                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
395                                                                     && ++$got_uh
396                                                               ) {
397           30                                151                  push @properties, 'user', $user, 'host', $host, 'ip', $ip;
398                                                               }
399                                                   
400                                                               # A line that looks like meta-data but is not:
401                                                               # # administrator command: Quit;
402                                                               elsif ( !$got_ac
403                                                                     && $line =~ m/^# (?:administrator command:.*)$/
404                                                                     && ++$got_ac
405                                                               ) {
406            4                                 20                  push @properties, 'cmd', 'Admin', 'arg', $line;
407            4                                 12                  $found_arg++;
408                                                               }
409                                                   
410                                                               # Maybe it's the timing line of a slow query log, or another line
411                                                               # such as that... they typically look like this:
412                                                               # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
413                                                               # If issue 234 bites us, we may see something like
414                                                               # Query_time: 18446744073708.796870.000036 so we match only up to
415                                                               # the second decimal place for numbers.
416                                                               elsif ( my @temp = $line =~ m/(\w+):\s+(\d+(?:\.\d+)?|\S+)/g ) {
417          128                                580                  push @properties, @temp;
418                                                               }
419                                                   
420                                                               # Include the current default database given by 'use <db>;'
421                                                               elsif ( !$got_db
422                                                                     && (my ( $db ) = $line =~ m/^USE ([^;]+)/i )
423                                                                     && ++$got_db
424                                                               ) {
425           15                                 54                  push @properties, 'db', $db;
426                                                               }
427                                                   
428                                                               # Some things you might see in the log output:
429                                                               # set timestamp=foo;
430                                                               # set timestamp=foo,insert_id=bar;
431                                                               # set names utf8;
432                                                               elsif ( !$got_set
433                                                                     && ( my ( $setting ) = $line =~ m/^SET\s+([^;]*)/i )
434                                                                     && ++$got_set
435                                                               ) {
436                                                                  # Note: this assumes settings won't be complex things like
437                                                                  # SQL_MODE, which as of 5.0.51 appears to be true (see sql/log.cc,
438                                                                  # function MYSQL_LOG::write(THD, char*, uint, time_t)).
439            4                                 45                  push @properties, split(/,|\s*=\s*/, $setting);
440                                                               }
441                                                   
442                                                               # Handle pathological special cases. The "# administrator command"
443                                                               # is one example: it can come AFTER lines that are not commented,
444                                                               # so it looks like it belongs to the next event, and it won't be
445                                                               # in $stmt. Profiling shows this is an expensive if() so we do
446                                                               # this only if we've seen the user/host line.
447          223    100    100                 2729               if ( !$found_arg && $pos == $len ) {
448            2                                 11                  local $INPUT_RECORD_SEPARATOR = ";\n";
449            2    100                          14                  if ( defined(my $l = <$fh>) ) {
450            1                                  9                     chomp $l;
451            1                                  7                     push @properties, 'cmd', 'Admin', 'arg', '#' . $l;
452            1                                  7                     $found_arg++;
453                                                                  }
454                                                                  else {
455                                                                     # Unrecoverable -- who knows what happened.  This is possible,
456                                                                     # for example, if someone does something like "head -c 10000
457                                                                     # /path/to/slow.log | mk-log-parser".  Or if there was a
458                                                                     # server crash and the file has no newline.
459            1                                 16                     next EVENT;
460                                                                  }
461                                                               }
462                                                            }
463                                                            else {
464                                                               # This isn't a meta-data line.  It's the first line of the
465                                                               # whole query. Grab from here to the end of the string and
466                                                               # put that into the 'arg' for the event.  Then we are done.
467                                                               # Note that if this line really IS the query but we skip in
468                                                               # the 'if' above because it looks like meta-data, later
469                                                               # we'll remedy that.
470           36                                186               push @properties, 'arg', substr($stmt, $pos - length($line));
471           36                                103               last LINE;
472                                                            }
473                                                         }
474                                                   
475           41                                444         my $event = { @properties };
476           41                                151         foreach my $callback ( @callbacks ) {
477   ***     41     50                         169            last unless $event = $callback->($event);
478                                                         }
479           41                                587         ++$num_events;
480           41    100                         266         last EVENT unless @pending;
481                                                      }
482           55                                460      return $num_events;
483                                                   }
484                                                   
485                                                   # This method accepts an open filehandle and a callback function.  It reads
486                                                   # events from the filehandle and calls the callback with each event.
487                                                   sub parse_binlog_event {
488            3                    3           237      my ( $self, $fh, $code ) = @_;
489            3                                  8      my $event;
490                                                   
491   ***      3            50                   26      my $term  = $self->{term} || ";\n"; # Corresponds to DELIMITER
492            3                                  9      my $tpat  = quotemeta $term;
493            3                                 16      local $RS = $term;
494            3                                233      my $line  = <$fh>;
495                                                   
496   ***      4     50                          15      LINE: {
497            3                                 10         return unless $line;
498                                                   
499                                                         # Catch changes in DELIMITER
500            4    100                          19         if ( $line =~ m/^DELIMITER/m ) {
501            1                                 10            my($del)      = $line =~ m/^DELIMITER ([^\n]+)/m;
502            1                                  5            $self->{term} = $del;
503            1                                  8            local $RS     = $del;
504            1                                  4            $line         = <$fh>; # Throw away DELIMITER line
505            1                                  2            MKDEBUG && _d('New record separator:', $del);
506            1                                  5            redo LINE;
507                                                         }
508                                                   
509                                                         # Throw away the delimiter
510            3                                 35         $line =~ s/$tpat\Z//;
511                                                   
512                                                         # Match the beginning of an event in the binary log.
513            3    100                          23         if ( my ( $offset ) = $line =~ m/$binlog_line_1/m ) {
514            1                                  5            $self->{last_line} = undef;
515            1                                  8            $event = {
516                                                               offset => $offset,
517                                                            };
518            1                                  8            my ( $ts, $sid, $end, $type, $rest ) = $line =~ m/$binlog_line_2/m;
519            1                                  5            @{$event}{qw(ts server_id end type)} = ($ts, $sid, $end, $type);
               1                                  5   
520            1                                  9            (my $arg = $line) =~ s/\n*^#.*\n//gm; # Remove comment lines
521            1                                  3            $event->{arg} = $arg;
522   ***      1      0                           3            if ( $type eq 'Xid' ) {
      ***             0                               
523   ***      0                                  0               my ($xid) = $rest =~ m/(\d+)/;
524   ***      0                                  0               $event->{xid} = $xid;
525                                                            }
526                                                            elsif ( $type eq 'Query' ) {
527   ***      0                                  0               @{$event}{qw(id time code)} = $rest =~ m/$binlog_line_2_rest/;
      ***      0                                  0   
528                                                            }
529                                                            else {
530   ***      0      0                           0               die "Unknown event type $type"
531                                                                  unless $type =~ m/Rotate|Start|Execute_load_query|Append_block|Begin_load_query|Rand|User_var|Intvar/;
532                                                            }
533                                                         }
534                                                         else {
535            2                                 10            $event = {
536                                                               arg => $line,
537                                                            };
538                                                         }
539                                                      }
540                                                   
541                                                      # If it was EOF, discard the terminator so statefulness doesn't interfere with
542                                                      # the next log file.
543   ***      2     50                           9      if ( !defined $line ) {
544   ***      0                                  0         delete $self->{term};
545                                                      }
546                                                   
547   ***      2     50     33                   22      $code->($event) if $event && $code;
548            2                                 34      return $event;
549                                                   }
550                                                   
551                                                   sub _d {
552   ***      0                    0                    my ($package, undef, $line) = caller 0;
553   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
554   ***      0                                              map { defined $_ ? $_ : 'undef' }
555                                                           @_;
556   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
557                                                   }
558                                                   
559                                                   1;
560                                                   
561                                                   # ###########################################################################
562                                                   # End LogParser package
563                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
81           100     24     26   defined $$self{'last_line'} ? :
89           100     29    219   if (not $mode and $line =~ /^# [A-Z]/)
96           100      2    246   if ($line =~ /Version:.+ started with:/) { }
             100     15    231   elsif ($mode ne 'slow' and my($ts, $id, $rest) = $line =~ /$general_log_first_line/s) { }
             100    228      3   elsif ($mode eq 'slow') { }
113          100     11      4   if ($type == 0) { }
122          100      7      4   if ($cmd ne 'Query')
125          100      4      3   if $$event{'arg'}
135   ***     50      4      0   if $$event{'arg'}
140          100     18    210   if ($line =~ /^# No InnoDB statistics available/) { }
             100     22    188   elsif (my($time) = $line =~ /$slow_log_ts_line/) { }
             100     30    158   elsif (my($user, $host, $ip) = $line =~ /$slow_log_uh_line/) { }
             100    107     51   elsif ($line =~ /^# / and my(%hash) = $line =~ /(\w+):\s+(\S+)/g) { }
154          100     14      8   if ($type == 0) { }
158          100     10      4   if (my($user, $host, $ip) = $line =~ /$slow_log_uh_line/)
177          100     18     12   if ($type == 0) { }
196          100    106      1   if ($type == 0) { }
      ***     50      1      0   elsif ($type == 1 and $line =~ /^#.+;/) { }
198          100      2    104   if ($line =~ /^#.+;/) { }
226          100     57    171   if (not $handled_line)
228          100     41     16   if ($mode eq 'slow' and $line =~ /;\s+\Z/) { }
230          100      9     32   if (my($db) = $line =~ /^use (.*);/i) { }
             100      7     25   elsif ($type < 2 and my($setting) = $line =~ /^(SET .*);\s+\Z/) { }
242          100      3     22   if ($line =~ /^# /)
263          100    197     31   unless $done
268          100     19     31   if (not defined $line)
273          100     29     21   if ($mode and $mode eq 'slow')
275          100     26      3   if $$event{'arg'}
278          100     40     10   if $event and $code
333          100      2     40   if ($stmt =~ s[
            ^(?:
            Tcp\sport:\s+\d+
            |
            /.*Version.*started
            |
            Time\s+Id\s+Command
            ).*\n
         ][]gmox)
344          100      1      1   if (@chunks > 1)
352          100     27     15   unless $stmt =~ /\A#/
374          100    223     36   if ($line =~ /^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/io) { }
377          100     20    203   if (not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o and ++$got_ts) { }
             100     30    173   elsif (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o and ++$got_uh) { }
             100      4    169   elsif (not $got_ac and $line =~ /^# (?:administrator command:.*)$/ and ++$got_ac) { }
             100    128     41   elsif (my(@temp) = $line =~ /(\w+):\s+(\d+(?:\.\d+)?|\S+)/g) { }
             100     15     26   elsif (not $got_db and my($db) = $line =~ /^USE ([^;]+)/i and ++$got_db) { }
             100      4     22   elsif (not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/i and ++$got_set) { }
383          100     11      9   if (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o and ++$got_uh)
447          100      2    221   if (not $found_arg and $pos == $len)
449          100      1      1   if (defined(my $l = <$fh>)) { }
477   ***     50      0     41   unless $event = &$callback($event)
480          100     40      1   unless @pending
496   ***     50      0      4   unless $line
500          100      1      3   if ($line =~ /^DELIMITER/m)
513          100      1      2   if (my($offset) = $line =~ /$binlog_line_1/m) { }
522   ***      0      0      0   if ($type eq 'Xid') { }
      ***      0      0      0   elsif ($type eq 'Query') { }
530   ***      0      0      0   unless $type =~ /Rotate|Start|Execute_load_query|Append_block|Begin_load_query|Rand|User_var|Intvar/
543   ***     50      0      2   if (not defined $line)
547   ***     50      2      0   if $event and $code
553   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
85           100     31     19    246   not $done and defined $line
89           100    205     14     29   not $mode and $line =~ /^# [A-Z]/
96           100    228      3     15   $mode ne 'slow' and my($ts, $id, $rest) = $line =~ /$general_log_first_line/s
140   ***     66     51      0    107   $line =~ /^# / and my(%hash) = $line =~ /(\w+):\s+(\S+)/g
196   ***     33      0      0      1   $type == 1 and $line =~ /^#.+;/
228          100      3     13     41   $mode eq 'slow' and $line =~ /;\s+\Z/
230          100      8     17      7   $type < 2 and my($setting) = $line =~ /^(SET .*);\s+\Z/
273          100     10     11     29   $mode and $mode eq 'slow'
278   ***     66     10      0     40   $event and $code
377          100     79    124     20   not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o
      ***     66    203      0     20   not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o and ++$got_ts
             100    171      2     30   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
      ***     66    173      0     30   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o and ++$got_uh
      ***     66      0    169      4   not $got_ac and $line =~ /^# (?:administrator command:.*)$/
      ***     66    169      0      4   not $got_ac and $line =~ /^# (?:administrator command:.*)$/ and ++$got_ac
             100      1     25     15   not $got_db and my($db) = $line =~ /^USE ([^;]+)/i
      ***     66     26      0     15   not $got_db and my($db) = $line =~ /^USE ([^;]+)/i and ++$got_db
      ***     66      0     22      4   not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/i
      ***     66     22      0      4   not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/i and ++$got_set
383   ***     66      0      9     11   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
      ***     66      9      0     11   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o and ++$got_uh
447          100      4    217      2   not $found_arg and $pos == $len
547   ***     33      0      0      2   $event and $code

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
82    ***     50      0     50   $mode ||= ''
91    ***     50      0     29   $mode ||= 'slow'
111          100      4     11   $mode ||= 'log'
116          100      5      6   $ts || ''
             100      8      3   $arg || ''
491   ***     50      0      3   $$self{'term'} || ";\n"

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
321          100      1     41     15   defined($stmt = shift @pending) or defined($stmt = <$fh>)


Covered Subroutines
-------------------

Subroutine          Count Location                                        
------------------- ----- ------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/LogParser.pm:22 
BEGIN                   1 /home/daniel/dev/maatkit/common/LogParser.pm:23 
BEGIN                   1 /home/daniel/dev/maatkit/common/LogParser.pm:24 
BEGIN                   1 /home/daniel/dev/maatkit/common/LogParser.pm:26 
new                     1 /home/daniel/dev/maatkit/common/LogParser.pm:29 
parse_binlog_event      3 /home/daniel/dev/maatkit/common/LogParser.pm:488
parse_event            50 /home/daniel/dev/maatkit/common/LogParser.pm:76 
parse_slowlog_event    55 /home/daniel/dev/maatkit/common/LogParser.pm:304

Uncovered Subroutines
---------------------

Subroutine          Count Location                                        
------------------- ----- ------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/LogParser.pm:552


