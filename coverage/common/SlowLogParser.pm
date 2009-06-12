---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlowLogParser.pm  100.0   97.2   84.8  100.0    n/a  100.0   96.6
Total                         100.0   97.2   84.8  100.0    n/a  100.0   96.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SlowLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jun 12 21:25:09 2009
Finish:       Fri Jun 12 21:25:09 2009

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
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                 10   
25             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  8   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 14   
28                                                    
29                                                    sub new {
30             2                    2            62      my ( $class ) = @_;
31             2                                 17      bless {}, $class;
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
71            91                   91          4345      my ( $self, $fh, $misc, @callbacks ) = @_;
72            91                                263      my $oktorun_here = 1;
73            91    100                         418      my $oktorun      = $misc->{oktorun} ? $misc->{oktorun} : \$oktorun_here;
74            91                                245      my $num_events   = 0;
75                                                    
76                                                       # Read a whole stmt at a time.  But, to make things even more fun, sometimes
77                                                       # part of the log entry might continue past the separator.  In these cases we
78                                                       # peek ahead (see code below.)  We do it this way because in the general
79                                                       # case, reading line-by-line is too slow, and the special-case code is
80                                                       # acceptable.  And additionally, the line terminator doesn't work for all
81                                                       # cases; the header lines might follow a statement, causing the paragraph
82                                                       # slurp to grab more than one statement at a time.
83            91                                207      my @pending;
84            91                                410      local $INPUT_RECORD_SEPARATOR = ";\n#";
85            91                                291      my $trimlen    = length($INPUT_RECORD_SEPARATOR);
86            91                                287      my $pos_in_log = tell($fh);
87            91                                204      my $stmt;
88                                                    
89                                                       EVENT:
90            91           100                 1661      while ( $$oktorun
                           100                        
91                                                               && (defined($stmt = shift @pending) or defined($stmt = <$fh>)) ) {
92            68                                286         my @properties = ('cmd', 'Query', 'pos_in_log', $pos_in_log);
93            68                                202         $pos_in_log = tell($fh);
94                                                    
95                                                          # If there were such lines in the file, we may have slurped > 1 event.
96                                                          # Delete the lines and re-split if there were deletes.  This causes the
97                                                          # pos_in_log to be inaccurate, but that's really okay.
98            68    100                         829         if ( $stmt =~ s/$slow_log_hd_line//go ){ # Throw away header lines in log
99             5                                 46            my @chunks = split(/$INPUT_RECORD_SEPARATOR/o, $stmt);
100            5    100                          35            if ( @chunks > 1 ) {
101            1                                  3               MKDEBUG && _d("Found multiple chunks");
102            1                                  3               $stmt = shift @chunks;
103            1                                  5               unshift @pending, @chunks;
104                                                            }
105                                                         }
106                                                   
107                                                         # There might not be a leading '#' because $INPUT_RECORD_SEPARATOR will
108                                                         # have gobbled that up.  And the end may have all/part of the separator.
109           68    100                         349         $stmt = '#' . $stmt unless $stmt =~ m/\A#/;
110           68                                344         $stmt =~ s/;\n#?\Z//;
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
121           68                                243         my ($got_ts, $got_uh, $got_ac, $got_db, $got_set, $got_embed);
122           68                                172         my $pos = 0;
123           68                                195         my $len = length($stmt);
124           68                                179         my $found_arg = 0;
125                                                         LINE:
126           68                                373         while ( $stmt =~ m/^(.*)$/mg ) { # /g is important, requires scalar match.
127          435                               1184            $pos     = pos($stmt);  # Be careful not to mess this up!
128          435                               1454            my $line = $1;          # Necessary for /g and pos() to work.
129          435                                956            MKDEBUG && _d($line);
130                                                   
131                                                            # Handle meta-data lines.  These are case-sensitive.  If they appear in
132                                                            # the log with a different case, they are from a user query, not from
133                                                            # something printed out by sql/log.cc.
134          435    100                        1855            if ($line =~ m/^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) {
135                                                   
136                                                               # Maybe it's the beginning of the slow query log event.  XXX
137                                                               # something to know: Perl profiling reports this line as the hot
138                                                               # spot for any of the conditions in the whole if/elsif/elsif
139                                                               # construct.  So if this line looks "hot" then profile each
140                                                               # condition separately.
141          374    100    100                 6612               if ( !$got_ts && (my ( $time ) = $line =~ m/$slow_log_ts_line/o)) {
                    100    100                        
      ***           100     66                        
                    100    100                        
      ***           100     66                        
                    100                               
142           28                                 60                  MKDEBUG && _d("Got ts", $time);
143           28                                 95                  push @properties, 'ts', $time;
144           28                                 74                  ++$got_ts;
145                                                                  # The User@Host might be concatenated onto the end of the Time.
146   ***     28    100     66                  366                  if ( !$got_uh
147                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
148                                                                  ) {
149           12                                 29                     MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
150           12                                 53                     push @properties, 'user', $user, 'host', $host, 'ip', $ip;
151           12                                 40                     ++$got_uh;
152                                                                  }
153                                                               }
154                                                   
155                                                               # Maybe it's the user/host line of a slow query log
156                                                               # # User@Host: root[root] @ localhost []
157                                                               elsif ( !$got_uh
158                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
159                                                               ) {
160           55                                122                  MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
161           55                                248                  push @properties, 'user', $user, 'host', $host, 'ip', $ip;
162           55                                157                  ++$got_uh;
163                                                               }
164                                                   
165                                                               # A line that looks like meta-data but is not:
166                                                               # # administrator command: Quit;
167                                                               elsif (!$got_ac && $line =~ m/^# (?:administrator command:.*)$/) {
168            4                                 10                  MKDEBUG && _d("Got admin command");
169            4                                 19                  push @properties, 'cmd', 'Admin', 'arg', $line;
170            4                                 17                  push @properties, 'bytes', length($properties[-1]);
171            4                                 22                  ++$found_arg;
172            4                                 11                  ++$got_ac;
173                                                               }
174                                                   
175                                                               # Maybe it's the timing line of a slow query log, or another line
176                                                               # such as that... they typically look like this:
177                                                               # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
178                                                               # If issue 234 bites us, we may see something like
179                                                               # Query_time: 18446744073708.796870.000036 so we trim after the
180                                                               # second decimal place for numbers.
181                                                               elsif ( $line =~ m/^# +[A-Z][A-Za-z_]+: \S+/ ) { # Make the test cheap!
182          219                                452                  MKDEBUG && _d("Got some line with properties");
183                                                                  # I tried using split, but coping with the above bug makes it
184                                                                  # slower than a complex regex match.
185          219                               2414                  my @temp = $line =~ m/(\w+):\s+(\d+(?:\.\d+)?|\S+|\Z)/g;
186          219                               1157                  push @properties, @temp;
187                                                               }
188                                                   
189                                                               # Include the current default database given by 'use <db>;'  Again
190                                                               # as per the code in sql/log.cc this is case-sensitive.
191                                                               elsif ( !$got_db && (my ( $db ) = $line =~ m/^use ([^;]+)/ ) ) {
192           26                                 55                  MKDEBUG && _d("Got a default database:", $db);
193           26                                 84                  push @properties, 'db', $db;
194           26                                 68                  ++$got_db;
195                                                               }
196                                                   
197                                                               # Some things you might see in the log output, as printed by
198                                                               # sql/log.cc (this time the SET is uppercaes, and again it is
199                                                               # case-sensitive).
200                                                               # SET timestamp=foo;
201                                                               # SET timestamp=foo,insert_id=123;
202                                                               # SET insert_id=123;
203                                                               elsif (!$got_set && (my ($setting) = $line =~ m/^SET\s+([^;]*)/)) {
204                                                                  # Note: this assumes settings won't be complex things like
205                                                                  # SQL_MODE, which as of 5.0.51 appears to be true (see sql/log.cc,
206                                                                  # function MYSQL_LOG::write(THD, char*, uint, time_t)).
207            8                                 17                  MKDEBUG && _d("Got some setting:", $setting);
208            8                                 97                  push @properties, split(/,|\s*=\s*/, $setting);
209            8                                 23                  ++$got_set;
210                                                               }
211                                                   
212                                                               # Handle pathological special cases. The "# administrator command"
213                                                               # is one example: it can come AFTER lines that are not commented,
214                                                               # so it looks like it belongs to the next event, and it won't be
215                                                               # in $stmt. Profiling shows this is an expensive if() so we do
216                                                               # this only if we've seen the user/host line.
217          374    100    100                 4034               if ( !$found_arg && $pos == $len ) {
218            3                                  6                  MKDEBUG && _d("Did not find arg, looking for special cases");
219            3                                 15                  local $INPUT_RECORD_SEPARATOR = ";\n";
220            3    100                          16                  if ( defined(my $l = <$fh>) ) {
221            2                                  8                     chomp $l;
222            2                                  7                     MKDEBUG && _d("Found admin statement", $l);
223            2                                 11                     push @properties, 'cmd', 'Admin', 'arg', '#' . $l;
224            2                                  8                     push @properties, 'bytes', length($properties[-1]);
225            2                                 15                     $found_arg++;
226                                                                  }
227                                                                  else {
228                                                                     # Unrecoverable -- who knows what happened.  This is possible,
229                                                                     # for example, if someone does something like "head -c 10000
230                                                                     # /path/to/slow.log | mk-log-parser".  Or if there was a
231                                                                     # server crash and the file has no newline.
232            1                                  3                     MKDEBUG && _d("I can't figure out what to do with this line");
233            1                                 17                     next EVENT;
234                                                                  }
235                                                               }
236                                                            }
237                                                            else {
238                                                               # This isn't a meta-data line.  It's the first line of the
239                                                               # whole query. Grab from here to the end of the string and
240                                                               # put that into the 'arg' for the event.  Then we are done.
241                                                               # Note that if this line really IS the query but we skip in
242                                                               # the 'if' above because it looks like meta-data, later
243                                                               # we'll remedy that.
244           61                                152               MKDEBUG && _d("Got the query/arg line");
245           61                                257               my $arg = substr($stmt, $pos - length($line));
246           61                                257               push @properties, 'arg', $arg, 'bytes', length($arg);
247                                                               # Handle embedded attributes.
248   ***     61    100     66                  595               if ( $misc && $misc->{embed}
      ***                   66                        
249                                                                  && ( my ($e) = $arg =~ m/($misc->{embed})/)
250                                                               ) {
251            1                                 13                  push @properties, $e =~ m/$misc->{capture}/g;
252                                                               }
253           61                                190               last LINE;
254                                                            }
255                                                         }
256                                                   
257           67                                146         MKDEBUG && _d('Properties of event:', Dumper(\@properties));
258           67                                782         my $event = { @properties };
259           67                                246         foreach my $callback ( @callbacks ) {
260           74    100                         390            last unless $event = $callback->($event);
261                                                         }
262           67                                744         ++$num_events;
263           67    100                         414         last EVENT unless @pending;
264                                                      }
265           91                               1067      return $num_events;
266                                                   }
267                                                   
268                                                   sub _d {
269            1                    1            22      my ($package, undef, $line) = caller 0;
270   ***      2     50                           8      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 10   
271            1                                  5           map { defined $_ ? $_ : 'undef' }
272                                                           @_;
273            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
274                                                   }
275                                                   
276                                                   1;
277                                                   
278                                                   # ###########################################################################
279                                                   # End SlowLogParser package
280                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
73           100      1     90   $$misc{'oktorun'} ? :
98           100      5     63   if ($stmt =~ s/$slow_log_hd_line//go)
100          100      1      4   if (@chunks > 1)
109          100     44     24   unless $stmt =~ /\A#/
134          100    374     61   if ($line =~ /^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) { }
141          100     28    346   if (not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o) { }
             100     55    291   elsif (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o) { }
             100      4    287   elsif (not $got_ac and $line =~ /^# (?:administrator command:.*)$/) { }
             100    219     68   elsif ($line =~ /^# +[A-Z][A-Za-z_]+: \S+/) { }
             100     26     42   elsif (not $got_db and my($db) = $line =~ /^use ([^;]+)/) { }
             100      8     34   elsif (not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/) { }
146          100     12     16   if (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o)
217          100      3    371   if (not $found_arg and $pos == $len)
220          100      2      1   if (defined(my $l = <$fh>)) { }
248          100      1     60   if ($misc and $$misc{'embed'} and my($e) = $arg =~ /($$misc{'embed'})/)
260          100      3     71   unless $event = &$callback($event)
263          100     66      1   unless @pending
270   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
90           100      1     24     68   $$oktorun and defined($stmt = shift @pending) || defined($stmt = <$fh>)
141          100    103    243     28   not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o
             100    289      2     55   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
      ***     66      0    287      4   not $got_ac and $line =~ /^# (?:administrator command:.*)$/
             100      2     40     26   not $got_db and my($db) = $line =~ /^use ([^;]+)/
      ***     66      0     34      8   not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/
146   ***     66      0     16     12   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
217          100      4    367      3   not $found_arg and $pos == $len
248   ***     66      0     60      1   $misc and $$misc{'embed'}
      ***     66     60      0      1   $misc and $$misc{'embed'} and my($e) = $arg =~ /($$misc{'embed'})/

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
90           100      1     67     24   defined($stmt = shift @pending) || defined($stmt = <$fh>)


Covered Subroutines
-------------------

Subroutine  Count Location                                            
----------- ----- ----------------------------------------------------
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:22 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:23 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:24 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:25 
BEGIN           1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:27 
_d              1 /home/daniel/dev/maatkit/common/SlowLogParser.pm:269
new             2 /home/daniel/dev/maatkit/common/SlowLogParser.pm:30 
parse_event    91 /home/daniel/dev/maatkit/common/SlowLogParser.pm:71 


