---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlowLogParser.pm  100.0   97.2   84.8  100.0    n/a  100.0   96.6
Total                         100.0   97.2   84.8  100.0    n/a  100.0   96.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SlowLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:51 2009
Finish:       Sat Aug 29 15:03:51 2009

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
18                                                    # SlowLogParser package $Revision: 4462 $
19                                                    # ###########################################################################
20                                                    package SlowLogParser;
21                                                    
22             1                    1             8   use strict;
               1                                  3   
               1                                  6   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  6   
               1                                  9   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
25             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  8   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
28                                                    
29                                                    sub new {
30             2                    2            70      my ( $class ) = @_;
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
71            89                   89          4290      my ( $self, $fh, $misc, @callbacks ) = @_;
72            89                               1232      my $oktorun_here = 1;
73            89    100                         403      my $oktorun      = $misc->{oktorun} ? $misc->{oktorun} : \$oktorun_here;
74            89                                225      my $num_events   = 0;
75                                                    
76                                                       # Read a whole stmt at a time.  But, to make things even more fun, sometimes
77                                                       # part of the log entry might continue past the separator.  In these cases we
78                                                       # peek ahead (see code below.)  We do it this way because in the general
79                                                       # case, reading line-by-line is too slow, and the special-case code is
80                                                       # acceptable.  And additionally, the line terminator doesn't work for all
81                                                       # cases; the header lines might follow a statement, causing the paragraph
82                                                       # slurp to grab more than one statement at a time.
83            89                                256      my @pending;
84            89                                411      local $INPUT_RECORD_SEPARATOR = ";\n#";
85            89                                292      my $trimlen    = length($INPUT_RECORD_SEPARATOR);
86            89                                308      my $pos_in_log = tell($fh);
87            89                                218      my $stmt;
88                                                    
89                                                       EVENT:
90            89           100                 1777      while ( $$oktorun
                           100                        
91                                                               && (defined($stmt = shift @pending) or defined($stmt = <$fh>)) ) {
92            66                                304         my @properties = ('cmd', 'Query', 'pos_in_log', $pos_in_log);
93            66                                196         $pos_in_log = tell($fh);
94                                                    
95                                                          # If there were such lines in the file, we may have slurped > 1 event.
96                                                          # Delete the lines and re-split if there were deletes.  This causes the
97                                                          # pos_in_log to be inaccurate, but that's really okay.
98            66    100                         809         if ( $stmt =~ s/$slow_log_hd_line//go ){ # Throw away header lines in log
99             6                                 56            my @chunks = split(/$INPUT_RECORD_SEPARATOR/o, $stmt);
100            6    100                          33            if ( @chunks > 1 ) {
101            1                                  3               MKDEBUG && _d("Found multiple chunks");
102            1                                  3               $stmt = shift @chunks;
103            1                                  6               unshift @pending, @chunks;
104                                                            }
105                                                         }
106                                                   
107                                                         # There might not be a leading '#' because $INPUT_RECORD_SEPARATOR will
108                                                         # have gobbled that up.  And the end may have all/part of the separator.
109           66    100                         366         $stmt = '#' . $stmt unless $stmt =~ m/\A#/;
110           66                                353         $stmt =~ s/;\n#?\Z//;
111                                                   
112                                                         # The beginning of a slow-query-log event should be something like
113                                                         # # Time: 071015 21:43:52
114                                                         # Or, it might look like this, sometimes at the end of the Time: line:
115                                                         # # User@Host: root[root] @ localhost []
116                                                   
117                                                         # The following line contains variables intended to be sure we do
118                                                         # particular things once and only once, for those regexes that will
119                                                         # match only one line per event, so we don't keep trying to re-match
120                                                         # regexes.
121           66                                219         my ($got_ts, $got_uh, $got_ac, $got_db, $got_set, $got_embed);
122           66                                162         my $pos = 0;
123           66                                186         my $len = length($stmt);
124           66                                171         my $found_arg = 0;
125                                                         LINE:
126           66                                362         while ( $stmt =~ m/^(.*)$/mg ) { # /g is important, requires scalar match.
127          425                               1153            $pos     = pos($stmt);  # Be careful not to mess this up!
128          425                               1435            my $line = $1;          # Necessary for /g and pos() to work.
129          425                                909            MKDEBUG && _d($line);
130                                                   
131                                                            # Handle meta-data lines.  These are case-sensitive.  If they appear in
132                                                            # the log with a different case, they are from a user query, not from
133                                                            # something printed out by sql/log.cc.
134          425    100                        1793            if ($line =~ m/^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) {
135                                                   
136                                                               # Maybe it's the beginning of the slow query log event.  XXX
137                                                               # something to know: Perl profiling reports this line as the hot
138                                                               # spot for any of the conditions in the whole if/elsif/elsif
139                                                               # construct.  So if this line looks "hot" then profile each
140                                                               # condition separately.
141          366    100    100                 6598               if ( !$got_ts && (my ( $time ) = $line =~ m/$slow_log_ts_line/o)) {
                    100    100                        
      ***           100     66                        
                    100    100                        
      ***           100     66                        
                    100                               
142           29                                 60                  MKDEBUG && _d("Got ts", $time);
143           29                                 99                  push @properties, 'ts', $time;
144           29                                 74                  ++$got_ts;
145                                                                  # The User@Host might be concatenated onto the end of the Time.
146   ***     29    100     66                  341                  if ( !$got_uh
147                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
148                                                                  ) {
149           11                                 25                     MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
150           11                                 53                     push @properties, 'user', $user, 'host', $host, 'ip', $ip;
151           11                                 32                     ++$got_uh;
152                                                                  }
153                                                               }
154                                                   
155                                                               # Maybe it's the user/host line of a slow query log
156                                                               # # User@Host: root[root] @ localhost []
157                                                               elsif ( !$got_uh
158                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
159                                                               ) {
160           53                                111                  MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
161           53                                251                  push @properties, 'user', $user, 'host', $host, 'ip', $ip;
162           53                                150                  ++$got_uh;
163                                                               }
164                                                   
165                                                               # A line that looks like meta-data but is not:
166                                                               # # administrator command: Quit;
167                                                               elsif (!$got_ac && $line =~ m/^# (?:administrator command:.*)$/) {
168            4                                 11                  MKDEBUG && _d("Got admin command");
169            4                                 19                  push @properties, 'cmd', 'Admin', 'arg', $line;
170            4                                 15                  push @properties, 'bytes', length($properties[-1]);
171            4                                 11                  ++$found_arg;
172            4                                 10                  ++$got_ac;
173                                                               }
174                                                   
175                                                               # Maybe it's the timing line of a slow query log, or another line
176                                                               # such as that... they typically look like this:
177                                                               # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
178                                                               elsif ( $line =~ m/^# +[A-Z][A-Za-z_]+: \S+/ ) { # Make the test cheap!
179          215                                455                  MKDEBUG && _d("Got some line with properties");
180                                                                  # I tried using split, but coping with the above bug makes it
181                                                                  # slower than a complex regex match.
182          215                               2255                  my @temp = $line =~ m/(\w+):\s+(\S+|\Z)/g;
183          215                               1160                  push @properties, @temp;
184                                                               }
185                                                   
186                                                               # Include the current default database given by 'use <db>;'  Again
187                                                               # as per the code in sql/log.cc this is case-sensitive.
188                                                               elsif ( !$got_db && (my ( $db ) = $line =~ m/^use ([^;]+)/ ) ) {
189           25                                 56                  MKDEBUG && _d("Got a default database:", $db);
190           25                                 84                  push @properties, 'db', $db;
191           25                                 69                  ++$got_db;
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
204            9                                 25                  MKDEBUG && _d("Got some setting:", $setting);
205            9                                104                  push @properties, split(/,|\s*=\s*/, $setting);
206            9                                 29                  ++$got_set;
207                                                               }
208                                                   
209                                                               # Handle pathological special cases. The "# administrator command"
210                                                               # is one example: it can come AFTER lines that are not commented,
211                                                               # so it looks like it belongs to the next event, and it won't be
212                                                               # in $stmt. Profiling shows this is an expensive if() so we do
213                                                               # this only if we've seen the user/host line.
214          366    100    100                 3904               if ( !$found_arg && $pos == $len ) {
215            3                                  8                  MKDEBUG && _d("Did not find arg, looking for special cases");
216            3                                 15                  local $INPUT_RECORD_SEPARATOR = ";\n";
217            3    100                          18                  if ( defined(my $l = <$fh>) ) {
218            2                                  6                     chomp $l;
219            2                                  6                     MKDEBUG && _d("Found admin statement", $l);
220            2                                  9                     push @properties, 'cmd', 'Admin', 'arg', '#' . $l;
221            2                                  8                     push @properties, 'bytes', length($properties[-1]);
222            2                                 13                     $found_arg++;
223                                                                  }
224                                                                  else {
225                                                                     # Unrecoverable -- who knows what happened.  This is possible,
226                                                                     # for example, if someone does something like "head -c 10000
227                                                                     # /path/to/slow.log | mk-log-parser".  Or if there was a
228                                                                     # server crash and the file has no newline.
229            1                                  3                     MKDEBUG && _d("I can't figure out what to do with this line");
230            1                                 18                     next EVENT;
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
241           59                                131               MKDEBUG && _d("Got the query/arg line");
242           59                                256               my $arg = substr($stmt, $pos - length($line));
243           59                                242               push @properties, 'arg', $arg, 'bytes', length($arg);
244                                                               # Handle embedded attributes.
245   ***     59    100     66                  613               if ( $misc && $misc->{embed}
      ***                   66                        
246                                                                  && ( my ($e) = $arg =~ m/($misc->{embed})/)
247                                                               ) {
248            1                                 12                  push @properties, $e =~ m/$misc->{capture}/g;
249                                                               }
250           59                                194               last LINE;
251                                                            }
252                                                         }
253                                                   
254                                                         # Don't dump $event; want to see full dump of all properties, and after
255                                                         # it's been cast into a hash, duplicated keys will be gone.
256           65                                135         MKDEBUG && _d('Properties of event:', Dumper(\@properties));
257           65                                821         my $event = { @properties };
258           65                                245         foreach my $callback ( @callbacks ) {
259           72    100                        1629            last unless $event = $callback->($event);
260                                                         }
261           65                                752         ++$num_events;
262           65    100                         428         last EVENT unless @pending;
263                                                      }
264           89                               1076      return $num_events;
265                                                   }
266                                                   
267                                                   sub _d {
268            1                    1            22      my ($package, undef, $line) = caller 0;
269   ***      2     50                           9      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 10   
270            1                                  5           map { defined $_ ? $_ : 'undef' }
271                                                           @_;
272            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
273                                                   }
274                                                   
275                                                   1;
276                                                   
277                                                   # ###########################################################################
278                                                   # End SlowLogParser package
279                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
73           100      1     88   $$misc{'oktorun'} ? :
98           100      6     60   if ($stmt =~ s/$slow_log_hd_line//go)
100          100      1      5   if (@chunks > 1)
109          100     42     24   unless $stmt =~ /\A#/
134          100    366     59   if ($line =~ /^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) { }
141          100     29    337   if (not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o) { }
             100     53    284   elsif (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o) { }
             100      4    280   elsif (not $got_ac and $line =~ /^# (?:administrator command:.*)$/) { }
             100    215     65   elsif ($line =~ /^# +[A-Z][A-Za-z_]+: \S+/) { }
             100     25     40   elsif (not $got_db and my($db) = $line =~ /^use ([^;]+)/) { }
             100      9     31   elsif (not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/) { }
146          100     11     18   if (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o)
214          100      3    363   if (not $found_arg and $pos == $len)
217          100      2      1   if (defined(my $l = <$fh>)) { }
245          100      1     58   if ($misc and $$misc{'embed'} and my($e) = $arg =~ /($$misc{'embed'})/)
259          100      3     69   unless $event = &$callback($event)
262          100     64      1   unless @pending
269   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
90           100      1     24     66   $$oktorun and defined($stmt = shift @pending) || defined($stmt = <$fh>)
141          100    107    230     29   not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o
             100    280      4     53   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
      ***     66      0    280      4   not $got_ac and $line =~ /^# (?:administrator command:.*)$/
             100      3     37     25   not $got_db and my($db) = $line =~ /^use ([^;]+)/
      ***     66      0     31      9   not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/
146   ***     66      0     18     11   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
214          100      4    359      3   not $found_arg and $pos == $len
245   ***     66      0     58      1   $misc and $$misc{'embed'}
      ***     66     58      0      1   $misc and $$misc{'embed'} and my($e) = $arg =~ /($$misc{'embed'})/

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
90           100      1     65     24   defined($stmt = shift @pending) || defined($stmt = <$fh>)


Covered Subroutines
-------------------

Subroutine  Count Location                                            
----------- ----- ----------------------------------------------------
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:22 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:23 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:24 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:25 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:27 
_d              1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:268
new             2 /home/daniel/dev/maatkit/common/SlowLogParser.pm:30 
parse_event    89 /home/daniel/dev/maatkit/common/SlowLogParser.pm:71 


