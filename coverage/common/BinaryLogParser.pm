---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/BinaryLogParser.pm   91.9   86.4   83.3   87.5    n/a  100.0   89.7
Total                          91.9   86.4   83.3   87.5    n/a  100.0   89.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          BinaryLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:51:22 2009
Finish:       Fri Jul 31 18:51:22 2009

/home/daniel/dev/maatkit/common/BinaryLogParser.pm

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
18                                                    # BinaryLogParser package $Revision: 4277 $
19                                                    # ###########################################################################
20                                                    package BinaryLogParser;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  6   
23             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                 12   
25                                                    
26             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  7   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 13   
32                                                    
33                                                    sub new {
34             1                    1            11      my ( $class, %args ) = @_;
35             1                                 12      return bless {}, $class;
36                                                    }
37                                                    
38                                                    my $binlog_line_1 = qr/at (\d+)$/m;
39                                                    my $binlog_line_2 = qr/^#(\d{6}\s+\d{1,2}:\d\d:\d\d)\s+server\s+id\s+(\d+)\s+end_log_pos\s+(\d+)\s+(\S+)\s*([^\n]*)$/m;
40                                                    my $binlog_line_2_rest = qr/thread_id=(\d+)\s+exec_time=(\d+)\s+error_code=(\d+)/m;
41                                                    
42                                                    # This method accepts an open filehandle and a callback function.  It reads
43                                                    # events from the filehandle and calls the callback with each event.
44                                                    sub parse_event {
45             4                    4           420      my ( $self, $fh, $misc, @callbacks ) = @_;
46             4                                 13      my $oktorun_here = 1;
47    ***      4     50                          17      my $oktorun      = $misc->{oktorun} ? $misc->{oktorun} : \$oktorun_here;
48             4                                 10      my $num_events   = 0;
49                                                    
50             4                                 18      local $INPUT_RECORD_SEPARATOR = ";\n#";
51             4                                 20      my $pos_in_log = tell($fh);
52             4                                  8      my $stmt;
53             4                                 13      my ($delim, $delim_len) = (undef, 0);
54                                                    
55                                                       EVENT:
56    ***      4            66                   81      while ( $$oktorun && defined($stmt = <$fh>) ) {
57            18                                 63         my @properties = ('pos_in_log', $pos_in_log);
58            18                                 54         my ($ts, $sid, $end, $type, $rest);
59            18                                 54         $pos_in_log = tell($fh);
60            18                                 88         $stmt =~ s/;\n#?\Z//;
61                                                    
62            18                                 50         my ( $got_offset, $got_hdr );
63            18                                 41         my $pos = 0;
64            18                                 48         my $len = length($stmt);
65            18                                 43         my $found_arg = 0;
66                                                          LINE:
67            18                                 89         while ( $stmt =~ m/^(.*)$/mg ) { # /g requires scalar match.
68            74                                194            $pos     = pos($stmt);  # Be careful not to mess this up!
69            74                                243            my $line = $1;          # Necessary for /g and pos() to work.
70            74    100                         347            $line    =~ s/$delim// if $delim;
71            74                                153            MKDEBUG && _d($line);
72                                                    
73            74    100                         282            if ( $line =~ m/^\/\*.+\*\/;/ ) {
74             6                                 13               MKDEBUG && _d('Comment line');
75             6                                 32               next LINE;
76                                                             }
77                                                     
78            68    100                         253            if ( $line =~ m/^DELIMITER/m ) {
79             3                                 19               my ( $del ) = $line =~ m/^DELIMITER (\S*)$/m;
80             3    100                          11               if ( $del ) {
81             2                                  6                  $delim_len = length $del;
82             2                                  6                  $delim     = quotemeta $del;
83             2                                  4                  MKDEBUG && _d('delimiter:', $delim);
84                                                                }
85                                                                else {
86                                                                   # Because of the line $stmt =~ s/;\n#?\Z//; above, setting
87                                                                   # the delimiter back to normal like "DELIMITER ;" appear as
88                                                                   # "DELIMITER ".
89             1                                  2                  MKDEBUG && _d('Delimiter reset to ;');
90             1                                  3                  $delim     = undef;
91             1                                  3                  $delim_len = 0;
92                                                                }
93             3                                 16               next LINE;
94                                                             }
95                                                    
96            65    100                         230            next LINE if $line =~ m/End of log file/;
97                                                    
98                                                             # Match the beginning of an event in the binary log.
99            63    100    100                  608            if ( !$got_offset && (my ( $offset ) = $line =~ m/$binlog_line_1/m) ) {
                    100    100                        
                    100                               
100           14                                 29               MKDEBUG && _d('Got the at offset line');
101           14                                 44               push @properties, 'offset', $offset;
102           14                                 88               $got_offset++;
103                                                            }
104                                                   
105                                                            # Match the 2nd line of binary log header, after "# at OFFSET".
106                                                            elsif ( !$got_hdr && $line =~ m/^#(\d{6}\s+\d{1,2}:\d\d:\d\d)/ ) {
107           14                                149               ($ts, $sid, $end, $type, $rest) = $line =~ m/$binlog_line_2/m;
108           14                                 41               MKDEBUG && _d('Got the header line; type:', $type, 'rest:', $rest);
109           14                                 66               push @properties, 'cmd', 'Query', 'ts', $ts, 'server_id', $sid,
110                                                                  'end_log_pos', $end;
111           14                                 82               $got_hdr++;
112                                                            }
113                                                   
114                                                            # Handle meta-data lines.
115                                                            elsif ( $line =~ m/^(?:#|use |SET)/i ) {
116                                                   
117                                                               # Include the current default database given by 'use <db>;'  Again
118                                                               # as per the code in sql/log.cc this is case-sensitive.
119           20    100                         170               if ( my ( $db ) = $line =~ m/^use ([^;]+)/ ) {
                    100                               
120            2                                  4                  MKDEBUG && _d("Got a default database:", $db);
121            2                                 14                  push @properties, 'db', $db;
122                                                               }
123                                                   
124                                                               # Some things you might see in the log output, as printed by
125                                                               # sql/log.cc (this time the SET is uppercaes, and again it is
126                                                               # case-sensitive).
127                                                               # SET timestamp=foo;
128                                                               # SET timestamp=foo,insert_id=123;
129                                                               # SET insert_id=123;
130                                                               elsif ( my ($setting) = $line =~ m/^SET\s+([^;]*)/ ) {
131           17                                 84                  MKDEBUG && _d("Got some setting:", $setting);
132           17                                215                  push @properties, map { s/\s+//; lc } split(/,|\s*=\s*/, $setting);
              50                                129   
              50                                234   
133                                                               }
134                                                   
135                                                            }
136                                                            else {
137                                                               # This isn't a meta-data line.  It's the first line of the
138                                                               # whole query. Grab from here to the end of the string and
139                                                               # put that into the 'arg' for the event.  Then we are done.
140                                                               # Note that if this line really IS the query but we skip in
141                                                               # the 'if' above because it looks like meta-data, later
142                                                               # we'll remedy that.
143           15                                 31               MKDEBUG && _d("Got the query/arg line at pos", $pos);
144           15                                 37               $found_arg++;
145   ***     15    100     66                  104               if ( $got_offset && $got_hdr ) {
146           13    100                          62                  if ( $type eq 'Xid' ) {
                    100                               
147            3                                 14                     my ($xid) = $rest =~ m/(\d+)/;
148            3                                 12                     push @properties, 'Xid', $xid;
149                                                                  }
150                                                                  elsif ( $type eq 'Query' ) {
151            9                                 78                     my ($i, $t, $c) = $rest =~ m/$binlog_line_2_rest/m;
152            9                                 50                     push @properties, 'Thread_id', $i, 'Query_time', $t,
153                                                                                       'error_code', $c;
154                                                                  }
155                                                                  else {
156   ***      1     50                           9                     die "Unknown event type $type"
157                                                                        unless $type =~ m/Rotate|Start|Execute_load_query|Append_block|Begin_load_query|Rand|User_var|Intvar/;
158                                                                  }
159                                                               }
160                                                               else {
161            2                                  5                  MKDEBUG && _d("It's not a query/arg, it's just some SQL fluff");
162            2                                  8                  push @properties, 'cmd', 'Query', 'ts', undef;
163                                                               }
164                                                   
165                                                               # Removing delimiters alters the length of $stmt, so we account
166                                                               # for this in our substr() offset.  If $pos is equal to the length
167                                                               # of $stmt, then this $line is the whole $arg (i.e. one line
168                                                               # query).  In this case, we go back the $delim_len that was
169                                                               # removed from this $line.  Otherwise, there are more lines to
170                                                               # this arg so a delimiter has not yet been removed (it remains
171                                                               # somewhere in $arg, at least at the end).  Therefore, we do not
172                                                               # go back any extra.
173           15    100                          55               my $delim_len = ($pos == length($stmt) ? $delim_len : 0);
174           15                                 61               my $arg = substr($stmt, $pos - length($line) - $delim_len);
175                                                   
176           15    100                          79               $arg =~ s/$delim// if $delim; # Remove the delimiter.
177                                                   
178                                                               # Sometimes DELIMITER appears at the end of an arg, so we have
179                                                               # to catch it again.  Queries in this arg before this new
180                                                               # DELIMITER should have the old delim, which is why we still
181                                                               # remove it in the previous line.
182           15    100                          58               if ( $arg =~ m/^DELIMITER/m ) {
183            1                                  6                  my ( $del ) = $arg =~ m/^DELIMITER (\S*)$/m;
184   ***      1     50                           5                  if ( $del ) {
185   ***      0                                  0                     $delim_len = length $del;
186   ***      0                                  0                     $delim     = quotemeta $del;
187   ***      0                                  0                     MKDEBUG && _d('delimiter:', $delim);
188                                                                  }
189                                                                  else {
190            1                                  2                     MKDEBUG && _d('Delimiter reset to ;');
191            1                                  3                     $del       = ';';
192            1                                  3                     $delim     = undef;
193            1                                  3                     $delim_len = 0;
194                                                                  }
195                                                   
196            1                                  4                  $arg =~ s/^DELIMITER.*$//m;  # Remove DELIMITER from arg.
197                                                               }
198                                                   
199           15                                 49               $arg =~ s/;$//gm;  # Ensure ending ; are gone.
200           15                                 86               $arg =~ s/\s+$//;  # Remove trailing spaces and newlines.
201                                                   
202           15                                 69               push @properties, 'arg', $arg, 'bytes', length($arg);
203           15                                 38               last LINE;
204                                                            }
205                                                         } # LINE
206                                                   
207           18    100                          57         if ( $found_arg ) {
208                                                            # Don't dump $event; want to see full dump of all properties, and after
209                                                            # it's been cast into a hash, duplicated keys will be gone.
210           15                                 29            MKDEBUG && _d('Properties of event:', Dumper(\@properties));
211           15                                120            my $event = { @properties };
212           15                                 51            foreach my $callback ( @callbacks ) {
213   ***     15     50                          53               last unless $event = $callback->($event);
214                                                            }
215           15                                304            ++$num_events;
216                                                         }
217                                                         else {
218            3                                 38            MKDEBUG && _d('Event had no arg');
219                                                         }
220                                                   
221                                                      } # EVENT
222                                                   
223            4                                 55      return $num_events;
224                                                   }
225                                                   
226                                                   sub _d {
227   ***      0                    0                    my ($package, undef, $line) = caller 0;
228   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
229   ***      0                                              map { defined $_ ? $_ : 'undef' }
230                                                           @_;
231   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
232                                                   }
233                                                   
234                                                   1;
235                                                   
236                                                   # ###########################################################################
237                                                   # End BinaryLogParser package
238                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
47    ***     50      0      4   $$misc{'oktorun'} ? :
70           100     64     10   if $delim
73           100      6     68   if ($line =~ m[^/\*.+\*/;])
78           100      3     65   if ($line =~ /^DELIMITER/m)
80           100      2      1   if ($del) { }
96           100      2     63   if $line =~ /End of log file/
99           100     14     49   if (not $got_offset and my($offset) = $line =~ /$binlog_line_1/m) { }
             100     14     35   elsif (not $got_hdr and $line =~ /^#(\d{6}\s+\d{1,2}:\d\d:\d\d)/) { }
             100     20     15   elsif ($line =~ /^(?:#|use |SET)/i) { }
119          100      2     18   if (my($db) = $line =~ /^use ([^;]+)/) { }
             100     17      1   elsif (my($setting) = $line =~ /^SET\s+([^;]*)/) { }
145          100     13      2   if ($got_offset and $got_hdr) { }
146          100      3     10   if ($type eq 'Xid') { }
             100      9      1   elsif ($type eq 'Query') { }
156   ***     50      0      1   unless $type =~ /Rotate|Start|Execute_load_query|Append_block|Begin_load_query|Rand|User_var|Intvar/
173          100      5     10   $pos == length $stmt ? :
176          100     13      2   if $delim
182          100      1     14   if ($arg =~ /^DELIMITER/m)
184   ***     50      0      1   if ($del) { }
207          100     15      3   if ($found_arg) { }
213   ***     50      0     15   unless $event = &$callback($event)
228   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
56    ***     66      0      4     18   $$oktorun and defined($stmt = <$fh>)
99           100     47      2     14   not $got_offset and my($offset) = $line =~ /$binlog_line_1/m
             100     33      2     14   not $got_hdr and $line =~ /^#(\d{6}\s+\d{1,2}:\d\d:\d\d)/
145   ***     66      2      0     13   $got_offset and $got_hdr


Covered Subroutines
-------------------

Subroutine  Count Location                                              
----------- ----- ------------------------------------------------------
BEGIN           1 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:22 
BEGIN           1 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:23 
BEGIN           1 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:24 
BEGIN           1 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:26 
BEGIN           1 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:31 
new             1 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:34 
parse_event     4 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:45 

Uncovered Subroutines
---------------------

Subroutine  Count Location                                              
----------- ----- ------------------------------------------------------
_d              0 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:227


