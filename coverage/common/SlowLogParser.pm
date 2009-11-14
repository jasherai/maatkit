---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/SlowLogParser.pm  100.0   93.8   83.3  100.0    n/a  100.0   95.9
Total                         100.0   93.8   83.3  100.0    n/a  100.0   95.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          SlowLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Nov 14 23:32:06 2009
Finish:       Sat Nov 14 23:32:07 2009

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
22             1                    1            14   use strict;
               1                                  3   
               1                                 10   
23             1                    1            11   use warnings FATAL => 'all';
               1                                  3   
               1                                 20   
24             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                 12   
25             1                    1            11   use Data::Dumper;
               1                                  3   
               1                                 12   
26                                                    
27             1                    1            11   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 19   
28                                                    
29                                                    sub new {
30             2                    2           101      my ( $class ) = @_;
31             2                                 17      my $self = {
32                                                          pending => [],
33                                                       };
34             2                                 31      return bless $self, $class;
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
74            74                   74          7700      my ( $self, %args ) = @_;
75            74                                490      my @required_args = qw(fh);
76            74                                429      foreach my $arg ( @required_args ) {
77    ***     74     50                         726         die "I need a $arg argument" unless $args{$arg};
78                                                       }
79            74                                437      my $fh = @args{@required_args};
80                                                    
81                                                       # Read a whole stmt at a time.  But, to make things even more fun, sometimes
82                                                       # part of the log entry might continue past the separator.  In these cases we
83                                                       # peek ahead (see code below.)  We do it this way because in the general
84                                                       # case, reading line-by-line is too slow, and the special-case code is
85                                                       # acceptable.  And additionally, the line terminator doesn't work for all
86                                                       # cases; the header lines might follow a statement, causing the paragraph
87                                                       # slurp to grab more than one statement at a time.
88            74                                404      my $pending = $self->{pending};
89            74                                578      local $INPUT_RECORD_SEPARATOR = ";\n#";
90            74                                399      my $trimlen    = length($INPUT_RECORD_SEPARATOR);
91            74                                393      my $pos_in_log = tell($fh);
92            74                                283      my $stmt;
93                                                    
94                                                       EVENT:
95            74           100                 2151      while ( (defined($stmt = shift @$pending) or defined($stmt = <$fh>)) ) {
96            54                                402         my @properties = ('cmd', 'Query', 'pos_in_log', $pos_in_log);
97            54                                279         $pos_in_log = tell($fh);
98                                                    
99                                                          # If there were such lines in the file, we may have slurped > 1 event.
100                                                         # Delete the lines and re-split if there were deletes.  This causes the
101                                                         # pos_in_log to be inaccurate, but that's really okay.
102           54    100                        1185         if ( $stmt =~ s/$slow_log_hd_line//go ){ # Throw away header lines in log
103            4                                 65            my @chunks = split(/$INPUT_RECORD_SEPARATOR/o, $stmt);
104            4    100                          39            if ( @chunks > 1 ) {
105            1                                  4               MKDEBUG && _d("Found multiple chunks");
106            1                                  6               $stmt = shift @chunks;
107            1                                  8               unshift @$pending, @chunks;
108                                                            }
109                                                         }
110                                                   
111                                                         # There might not be a leading '#' because $INPUT_RECORD_SEPARATOR will
112                                                         # have gobbled that up.  And the end may have all/part of the separator.
113           54    100                         505         $stmt = '#' . $stmt unless $stmt =~ m/\A#/;
114           54                                491         $stmt =~ s/;\n#?\Z//;
115                                                   
116                                                         # The beginning of a slow-query-log event should be something like
117                                                         # # Time: 071015 21:43:52
118                                                         # Or, it might look like this, sometimes at the end of the Time: line:
119                                                         # # User@Host: root[root] @ localhost []
120                                                   
121                                                         # The following line contains variables intended to be sure we do
122                                                         # particular things once and only once, for those regexes that will
123                                                         # match only one line per event, so we don't keep trying to re-match
124                                                         # regexes.
125           54                                295         my ($got_ts, $got_uh, $got_ac, $got_db, $got_set, $got_embed);
126           54                                214         my $pos = 0;
127           54                                232         my $len = length($stmt);
128           54                                222         my $found_arg = 0;
129                                                         LINE:
130           54                                511         while ( $stmt =~ m/^(.*)$/mg ) { # /g is important, requires scalar match.
131          332                               1533            $pos     = pos($stmt);  # Be careful not to mess this up!
132          332                               1878            my $line = $1;          # Necessary for /g and pos() to work.
133          332                               1072            MKDEBUG && _d($line);
134                                                   
135                                                            # Handle meta-data lines.  These are case-sensitive.  If they appear in
136                                                            # the log with a different case, they are from a user query, not from
137                                                            # something printed out by sql/log.cc.
138          332    100                        2522            if ($line =~ m/^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) {
139                                                   
140                                                               # Maybe it's the beginning of the slow query log event.  XXX
141                                                               # something to know: Perl profiling reports this line as the hot
142                                                               # spot for any of the conditions in the whole if/elsif/elsif
143                                                               # construct.  So if this line looks "hot" then profile each
144                                                               # condition separately.
145          285    100    100                 9636               if ( !$got_ts && (my ( $time ) = $line =~ m/$slow_log_ts_line/o)) {
                    100    100                        
      ***           100     66                        
                    100    100                        
      ***           100     66                        
                    100                               
146           24                                 77                  MKDEBUG && _d("Got ts", $time);
147           24                                138                  push @properties, 'ts', $time;
148           24                                 98                  ++$got_ts;
149                                                                  # The User@Host might be concatenated onto the end of the Time.
150   ***     24    100     66                  540                  if ( !$got_uh
151                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
152                                                                  ) {
153           10                                 45                     MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
154           10                                 80                     push @properties, 'user', $user, 'host', $host, 'ip', $ip;
155           10                                 51                     ++$got_uh;
156                                                                  }
157                                                               }
158                                                   
159                                                               # Maybe it's the user/host line of a slow query log
160                                                               # # User@Host: root[root] @ localhost []
161                                                               elsif ( !$got_uh
162                                                                     && ( my ( $user, $host, $ip ) = $line =~ m/$slow_log_uh_line/o )
163                                                               ) {
164           42                                141                  MKDEBUG && _d("Got user, host, ip", $user, $host, $ip);
165           42                                369                  push @properties, 'user', $user, 'host', $host, 'ip', $ip;
166           42                                182                  ++$got_uh;
167                                                               }
168                                                   
169                                                               # A line that looks like meta-data but is not:
170                                                               # # administrator command: Quit;
171                                                               elsif (!$got_ac && $line =~ m/^# (?:administrator command:.*)$/) {
172            4                                 16                  MKDEBUG && _d("Got admin command");
173            4                                 42                  push @properties, 'cmd', 'Admin', 'arg', $line;
174            4                                 26                  push @properties, 'bytes', length($properties[-1]);
175            4                                 15                  ++$found_arg;
176            4                                 18                  ++$got_ac;
177                                                               }
178                                                   
179                                                               # Maybe it's the timing line of a slow query log, or another line
180                                                               # such as that... they typically look like this:
181                                                               # # Query_time: 2  Lock_time: 0  Rows_sent: 1  Rows_examined: 0
182                                                               elsif ( $line =~ m/^# +[A-Z][A-Za-z_]+: \S+/ ) { # Make the test cheap!
183          161                                548                  MKDEBUG && _d("Got some line with properties");
184                                                                  # I tried using split, but coping with the above bug makes it
185                                                                  # slower than a complex regex match.
186          161                               3162                  my @temp = $line =~ m/(\w+):\s+(\S+|\Z)/g;
187          161                               1584                  push @properties, @temp;
188                                                               }
189                                                   
190                                                               # Include the current default database given by 'use <db>;'  Again
191                                                               # as per the code in sql/log.cc this is case-sensitive.
192                                                               elsif ( !$got_db && (my ( $db ) = $line =~ m/^use ([^;]+)/ ) ) {
193           20                                 71                  MKDEBUG && _d("Got a default database:", $db);
194           20                                128                  push @properties, 'db', $db;
195           20                                 85                  ++$got_db;
196                                                               }
197                                                   
198                                                               # Some things you might see in the log output, as printed by
199                                                               # sql/log.cc (this time the SET is uppercaes, and again it is
200                                                               # case-sensitive).
201                                                               # SET timestamp=foo;
202                                                               # SET timestamp=foo,insert_id=123;
203                                                               # SET insert_id=123;
204                                                               elsif (!$got_set && (my ($setting) = $line =~ m/^SET\s+([^;]*)/)) {
205                                                                  # Note: this assumes settings won't be complex things like
206                                                                  # SQL_MODE, which as of 5.0.51 appears to be true (see sql/log.cc,
207                                                                  # function MYSQL_LOG::write(THD, char*, uint, time_t)).
208            5                                 16                  MKDEBUG && _d("Got some setting:", $setting);
209            5                                100                  push @properties, split(/,|\s*=\s*/, $setting);
210            5                                 23                  ++$got_set;
211                                                               }
212                                                   
213                                                               # Handle pathological special cases. The "# administrator command"
214                                                               # is one example: it can come AFTER lines that are not commented,
215                                                               # so it looks like it belongs to the next event, and it won't be
216                                                               # in $stmt. Profiling shows this is an expensive if() so we do
217                                                               # this only if we've seen the user/host line.
218          285    100    100                 5791               if ( !$found_arg && $pos == $len ) {
219            3                                 11                  MKDEBUG && _d("Did not find arg, looking for special cases");
220            3                                 24                  local $INPUT_RECORD_SEPARATOR = ";\n";
221            3    100                          29                  if ( defined(my $l = <$fh>) ) {
222            2                                 11                     chomp $l;
223            2                                 12                     MKDEBUG && _d("Found admin statement", $l);
224            2                                 18                     push @properties, 'cmd', 'Admin', 'arg', '#' . $l;
225            2                                 13                     push @properties, 'bytes', length($properties[-1]);
226            2                                 26                     $found_arg++;
227                                                                  }
228                                                                  else {
229                                                                     # Unrecoverable -- who knows what happened.  This is possible,
230                                                                     # for example, if someone does something like "head -c 10000
231                                                                     # /path/to/slow.log | mk-log-parser".  Or if there was a
232                                                                     # server crash and the file has no newline.
233            1                                  5                     MKDEBUG && _d("I can't figure out what to do with this line");
234            1                                 29                     next EVENT;
235                                                                  }
236                                                               }
237                                                            }
238                                                            else {
239                                                               # This isn't a meta-data line.  It's the first line of the
240                                                               # whole query. Grab from here to the end of the string and
241                                                               # put that into the 'arg' for the event.  Then we are done.
242                                                               # Note that if this line really IS the query but we skip in
243                                                               # the 'if' above because it looks like meta-data, later
244                                                               # we'll remedy that.
245           47                                155               MKDEBUG && _d("Got the query/arg line");
246           47                                333               my $arg = substr($stmt, $pos - length($line));
247           47                                340               push @properties, 'arg', $arg, 'bytes', length($arg);
248                                                               # Handle embedded attributes.
249   ***     47    100     66                  591               if ( $args{misc} && $args{misc}->{embed}
      ***                   66                        
250                                                                  && ( my ($e) = $arg =~ m/($args{misc}->{embed})/)
251                                                               ) {
252            1                                 25                  push @properties, $e =~ m/$args{misc}->{capture}/g;
253                                                               }
254           47                                227               last LINE;
255                                                            }
256                                                         }
257                                                   
258                                                         # Don't dump $event; want to see full dump of all properties, and after
259                                                         # it's been cast into a hash, duplicated keys will be gone.
260           53                                173         MKDEBUG && _d('Properties of event:', Dumper(\@properties));
261           53                               1146         my $event = { @properties };
262           53                               1047         return $event;
263                                                      }
264           21                                291      return;
265                                                   }
266                                                   
267                                                   sub _d {
268            1                    1            44      my ($package, undef, $line) = caller 0;
269   ***      2     50                          14      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 27   
270            1                                  9           map { defined $_ ? $_ : 'undef' }
271                                                           @_;
272            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
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
77    ***     50      0     74   unless $args{$arg}
102          100      4     50   if ($stmt =~ s/$slow_log_hd_line//go)
104          100      1      3   if (@chunks > 1)
113          100     33     21   unless $stmt =~ /\A#/
138          100    285     47   if ($line =~ /^(?:#|use |SET (?:last_insert_id|insert_id|timestamp))/o) { }
145          100     24    261   if (not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o) { }
             100     42    219   elsif (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o) { }
             100      4    215   elsif (not $got_ac and $line =~ /^# (?:administrator command:.*)$/) { }
             100    161     54   elsif ($line =~ /^# +[A-Z][A-Za-z_]+: \S+/) { }
             100     20     34   elsif (not $got_db and my($db) = $line =~ /^use ([^;]+)/) { }
             100      5     29   elsif (not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/) { }
150          100     10     14   if (not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o)
218          100      3    282   if (not $found_arg and $pos == $len)
221          100      2      1   if (defined(my $l = <$fh>)) { }
249          100      1     46   if ($args{'misc'} and $args{'misc'}{'embed'} and my($e) = $arg =~ /($args{'misc'}{'embed'})/)
269   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
145          100     90    171     24   not $got_ts and my($time) = $line =~ /$slow_log_ts_line/o
             100    215      4     42   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
      ***     66      0    215      4   not $got_ac and $line =~ /^# (?:administrator command:.*)$/
             100      2     32     20   not $got_db and my($db) = $line =~ /^use ([^;]+)/
      ***     66      0     29      5   not $got_set and my($setting) = $line =~ /^SET\s+([^;]*)/
150   ***     66      0     14     10   not $got_uh and my($user, $host, $ip) = $line =~ /$slow_log_uh_line/o
218          100      4    278      3   not $found_arg and $pos == $len
249   ***     66     46      0      1   $args{'misc'} and $args{'misc'}{'embed'}
      ***     66     46      0      1   $args{'misc'} and $args{'misc'}{'embed'} and my($e) = $arg =~ /($args{'misc'}{'embed'})/

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
95           100      1     53     21   defined($stmt = shift @$pending) or defined($stmt = <$fh>)


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
parse_event    74 /home/daniel/dev/maatkit/common/SlowLogParser.pm:74 


