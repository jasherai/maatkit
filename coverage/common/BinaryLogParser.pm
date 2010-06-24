---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/BinaryLogParser.pm   92.1   90.9   81.8   87.5    0.0   97.7   89.9
BinaryLogParser.t             100.0   50.0   33.3  100.0    n/a    2.3   92.9
Total                          93.7   89.1   71.4   93.8    0.0  100.0   90.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:03 2010
Finish:       Thu Jun 24 19:32:03 2010

Run:          BinaryLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:32:05 2010
Finish:       Thu Jun 24 19:32:05 2010

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
18                                                    # BinaryLogParser package $Revision: 5358 $
19                                                    # ###########################################################################
20                                                    package BinaryLogParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                 11   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24             1                    1            10   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
25                                                    
26             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  7   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
32                                                    
33                                                    sub new {
34    ***      1                    1      0      5      my ( $class, %args ) = @_;
35             1                                  6      my $self = {
36                                                          delim     => undef,
37                                                          delim_len => 0,
38                                                       };
39             1                                 12      return bless $self, $class;
40                                                    }
41                                                    
42                                                    my $binlog_line_1 = qr/at (\d+)$/m;
43                                                    my $binlog_line_2 = qr/^#(\d{6}\s+\d{1,2}:\d\d:\d\d)\s+server\s+id\s+(\d+)\s+end_log_pos\s+(\d+)\s+(\S+)\s*([^\n]*)$/m;
44                                                    my $binlog_line_2_rest = qr/thread_id=(\d+)\s+exec_time=(\d+)\s+error_code=(\d+)/m;
45                                                    
46                                                    # This method accepts an open filehandle and a callback function.  It reads
47                                                    # events from the filehandle and calls the callback with each event.
48                                                    sub parse_event {
49    ***     18                   18      0    588      my ( $self, %args ) = @_;
50            18                                 77      my @required_args = qw(next_event tell);
51            18                                 56      foreach my $arg ( @required_args ) {
52    ***     36     50                         165         die "I need a $arg argument" unless $args{$arg};
53                                                       }
54            18                                 76      my ($next_event, $tell) = @args{@required_args};
55                                                    
56            18                                 81      local $INPUT_RECORD_SEPARATOR = ";\n#";
57            18                                 71      my $pos_in_log = $tell->();
58            18                                130      my $stmt;
59            18                                 85      my ($delim, $delim_len) = ($self->{delim}, $self->{delim_len});
60                                                    
61                                                       EVENT:
62            18                                 72      while ( defined($stmt = $next_event->()) ) {
63            20                              13506         my @properties = ('pos_in_log', $pos_in_log);
64            20                                 65         my ($ts, $sid, $end, $type, $rest);
65            20                                 75         $pos_in_log = $tell->();
66            20                                202         $stmt =~ s/;\n#?\Z//;
67                                                    
68            20                                 51         my ( $got_offset, $got_hdr );
69            20                                 55         my $pos = 0;
70            20                                 53         my $len = length($stmt);
71            20                                 82         my $found_arg = 0;
72                                                          LINE:
73            20                                110         while ( $stmt =~ m/^(.*)$/mg ) { # /g requires scalar match.
74            80                                231            $pos     = pos($stmt);  # Be careful not to mess this up!
75            80                                288            my $line = $1;          # Necessary for /g and pos() to work.
76            80    100                         376            $line    =~ s/$delim// if $delim;
77            80                                177            MKDEBUG && _d($line);
78                                                    
79            80    100                         312            if ( $line =~ m/^\/\*.+\*\/;/ ) {
80             8                                 20               MKDEBUG && _d('Comment line');
81             8                                 50               next LINE;
82                                                             }
83                                                     
84            72    100                         256            if ( $line =~ m/^DELIMITER/m ) {
85             4                                 25               my ( $del ) = $line =~ m/^DELIMITER (\S*)$/m;
86             4    100                          20               if ( $del ) {
87             3                                 12                  $self->{delim_len} = $delim_len = length $del;
88             3                                 14                  $self->{delim}     = $delim     = quotemeta $del;
89             3                                  9                  MKDEBUG && _d('delimiter:', $delim);
90                                                                }
91                                                                else {
92                                                                   # Because of the line $stmt =~ s/;\n#?\Z//; above, setting
93                                                                   # the delimiter back to normal like "DELIMITER ;" appear as
94                                                                   # "DELIMITER ".
95             1                                  2                  MKDEBUG && _d('Delimiter reset to ;');
96             1                                  5                  $self->{delim}     = $delim     = undef;
97             1                                  4                  $self->{delim_len} = $delim_len = 0;
98                                                                }
99             4                                 25               next LINE;
100                                                            }
101                                                   
102           68    100                         241            next LINE if $line =~ m/End of log file/;
103                                                   
104                                                            # Match the beginning of an event in the binary log.
105           66    100    100                  669            if ( !$got_offset && (my ( $offset ) = $line =~ m/$binlog_line_1/m) ) {
                    100    100                        
                    100                               
106           15                                 35               MKDEBUG && _d('Got the at offset line');
107           15                                 49               push @properties, 'offset', $offset;
108           15                                120               $got_offset++;
109                                                            }
110                                                   
111                                                            # Match the 2nd line of binary log header, after "# at OFFSET".
112                                                            elsif ( !$got_hdr && $line =~ m/^#(\d{6}\s+\d{1,2}:\d\d:\d\d)/ ) {
113           15                                166               ($ts, $sid, $end, $type, $rest) = $line =~ m/$binlog_line_2/m;
114           15                                 45               MKDEBUG && _d('Got the header line; type:', $type, 'rest:', $rest);
115           15                                 70               push @properties, 'cmd', 'Query', 'ts', $ts, 'server_id', $sid,
116                                                                  'end_log_pos', $end;
117           15                                 83               $got_hdr++;
118                                                            }
119                                                   
120                                                            # Handle meta-data lines.
121                                                            elsif ( $line =~ m/^(?:#|use |SET)/i ) {
122                                                   
123                                                               # Include the current default database given by 'use <db>;'  Again
124                                                               # as per the code in sql/log.cc this is case-sensitive.
125           20    100                         182               if ( my ( $db ) = $line =~ m/^use ([^;]+)/ ) {
                    100                               
126            2                                  5                  MKDEBUG && _d("Got a default database:", $db);
127            2                                 14                  push @properties, 'db', $db;
128                                                               }
129                                                   
130                                                               # Some things you might see in the log output, as printed by
131                                                               # sql/log.cc (this time the SET is uppercaes, and again it is
132                                                               # case-sensitive).
133                                                               # SET timestamp=foo;
134                                                               # SET timestamp=foo,insert_id=123;
135                                                               # SET insert_id=123;
136                                                               elsif ( my ($setting) = $line =~ m/^SET\s+([^;]*)/ ) {
137           17                                 37                  MKDEBUG && _d("Got some setting:", $setting);
138           17                                214                  push @properties, map { s/\s+//; lc } split(/,|\s*=\s*/, $setting);
              50                                129   
              50                                247   
139                                                               }
140                                                   
141                                                            }
142                                                            else {
143                                                               # This isn't a meta-data line.  It's the first line of the
144                                                               # whole query. Grab from here to the end of the string and
145                                                               # put that into the 'arg' for the event.  Then we are done.
146                                                               # Note that if this line really IS the query but we skip in
147                                                               # the 'if' above because it looks like meta-data, later
148                                                               # we'll remedy that.
149           16                                 34               MKDEBUG && _d("Got the query/arg line at pos", $pos);
150           16                                 38               $found_arg++;
151   ***     16    100     66                  113               if ( $got_offset && $got_hdr ) {
152           14    100                          61                  if ( $type eq 'Xid' ) {
                    100                               
                    100                               
153            3                                 18                     my ($xid) = $rest =~ m/(\d+)/;
154            3                                 12                     push @properties, 'Xid', $xid;
155                                                                  }
156                                                                  elsif ( $type eq 'Query' ) {
157            9                                 80                     my ($i, $t, $c) = $rest =~ m/$binlog_line_2_rest/m;
158            9                                 49                     push @properties, 'Thread_id', $i, 'Query_time', $t,
159                                                                                       'error_code', $c;
160                                                                  }
161                                                                  elsif ( $type eq 'Start:' ) {
162                                                                     # These are lines like "#090722  7:21:41 server id 12345
163                                                                     # end_log_pos 98 Start: binlog v 4, server v 5.0.82-log
164                                                                     # created 090722  7:21:41 at startup".  They may or may
165                                                                     # not have a statement after them (ROLLBACK can follow
166                                                                     # this line), so we do not want to skip these types.
167            1                                  3                     MKDEBUG && _d("Binlog start");
168                                                                  }
169                                                                  else {
170            1                                  2                     MKDEBUG && _d('Unknown event type:', $type);
171            1                                  6                     next EVENT;
172                                                                  }
173                                                               }
174                                                               else {
175            2                                  5                  MKDEBUG && _d("It's not a query/arg, it's just some SQL fluff");
176            2                                 12                  push @properties, 'cmd', 'Query', 'ts', undef;
177                                                               }
178                                                   
179                                                               # Removing delimiters alters the length of $stmt, so we account
180                                                               # for this in our substr() offset.  If $pos is equal to the length
181                                                               # of $stmt, then this $line is the whole $arg (i.e. one line
182                                                               # query).  In this case, we go back the $delim_len that was
183                                                               # removed from this $line.  Otherwise, there are more lines to
184                                                               # this arg so a delimiter has not yet been removed (it remains
185                                                               # somewhere in $arg, at least at the end).  Therefore, we do not
186                                                               # go back any extra.
187           15    100                          59               my $delim_len = ($pos == length($stmt) ? $delim_len : 0);
188           15                                 64               my $arg = substr($stmt, $pos - length($line) - $delim_len);
189                                                   
190           15    100                          88               $arg =~ s/$delim// if $delim; # Remove the delimiter.
191                                                   
192                                                               # Sometimes DELIMITER appears at the end of an arg, so we have
193                                                               # to catch it again.  Queries in this arg before this new
194                                                               # DELIMITER should have the old delim, which is why we still
195                                                               # remove it in the previous line.
196           15    100                          59               if ( $arg =~ m/^DELIMITER/m ) {
197            1                                  6                  my ( $del ) = $arg =~ m/^DELIMITER (\S*)$/m;
198   ***      1     50                           5                  if ( $del ) {
199   ***      0                                  0                     $self->{delim_len} = $delim_len = length $del;
200   ***      0                                  0                     $self->{delim}     = $delim     = quotemeta $del;
201   ***      0                                  0                     MKDEBUG && _d('delimiter:', $delim);
202                                                                  }
203                                                                  else {
204            1                                  2                     MKDEBUG && _d('Delimiter reset to ;');
205            1                                  3                     $del       = ';';
206            1                                  4                     $self->{delim}     = $delim     = undef;
207            1                                  4                     $self->{delim_len} = $delim_len = 0;
208                                                                  }
209                                                   
210            1                                  5                  $arg =~ s/^DELIMITER.*$//m;  # Remove DELIMITER from arg.
211                                                               }
212                                                   
213           15                                 50               $arg =~ s/;$//gm;  # Ensure ending ; are gone.
214           15                                 87               $arg =~ s/\s+$//;  # Remove trailing spaces and newlines.
215                                                   
216           15                                 69               push @properties, 'arg', $arg, 'bytes', length($arg);
217           15                                 40               last LINE;
218                                                            }
219                                                         } # LINE
220                                                   
221           19    100                          63         if ( $found_arg ) {
222                                                            # Don't dump $event; want to see full dump of all properties, and after
223                                                            # it's been cast into a hash, duplicated keys will be gone.
224           15                                 31            MKDEBUG && _d('Properties of event:', Dumper(\@properties));
225           15                                126            my $event = { @properties };
226           15                                147            return $event;
227                                                         }
228                                                         else {
229            4                                 20            MKDEBUG && _d('Event had no arg');
230                                                         }
231                                                      } # EVENT
232                                                   
233            3    100                          62      $args{oktorun}->(0) if $args{oktorun};
234            3                                 23      return;
235                                                   }
236                                                   
237                                                   sub _d {
238   ***      0                    0                    my ($package, undef, $line) = caller 0;
239   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
240   ***      0                                              map { defined $_ ? $_ : 'undef' }
241                                                           @_;
242   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
243                                                   }
244                                                   
245                                                   1;
246                                                   
247                                                   # ###########################################################################
248                                                   # End BinaryLogParser package
249                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
52    ***     50      0     36   unless $args{$arg}
76           100     67     13   if $delim
79           100      8     72   if ($line =~ m[^/\*.+\*/;])
84           100      4     68   if ($line =~ /^DELIMITER/m)
86           100      3      1   if ($del) { }
102          100      2     66   if $line =~ /End of log file/
105          100     15     51   if (not $got_offset and my($offset) = $line =~ /$binlog_line_1/m) { }
             100     15     36   elsif (not $got_hdr and $line =~ /^#(\d{6}\s+\d{1,2}:\d\d:\d\d)/) { }
             100     20     16   elsif ($line =~ /^(?:#|use |SET)/i) { }
125          100      2     18   if (my($db) = $line =~ /^use ([^;]+)/) { }
             100     17      1   elsif (my($setting) = $line =~ /^SET\s+([^;]*)/) { }
151          100     14      2   if ($got_offset and $got_hdr) { }
152          100      3     11   if ($type eq 'Xid') { }
             100      9      2   elsif ($type eq 'Query') { }
             100      1      1   elsif ($type eq 'Start:') { }
187          100      5     10   $pos == length $stmt ? :
190          100     13      2   if $delim
196          100      1     14   if ($arg =~ /^DELIMITER/m)
198   ***     50      0      1   if ($del) { }
221          100     15      4   if ($found_arg) { }
233          100      1      2   if $args{'oktorun'}
239   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
105          100     49      2     15   not $got_offset and my($offset) = $line =~ /$binlog_line_1/m
             100     34      2     15   not $got_hdr and $line =~ /^#(\d{6}\s+\d{1,2}:\d\d:\d\d)/
151   ***     66      2      0     14   $got_offset and $got_hdr

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine  Count Pod Location                                              
----------- ----- --- ------------------------------------------------------
BEGIN           1     /home/daniel/dev/maatkit/common/BinaryLogParser.pm:22 
BEGIN           1     /home/daniel/dev/maatkit/common/BinaryLogParser.pm:23 
BEGIN           1     /home/daniel/dev/maatkit/common/BinaryLogParser.pm:24 
BEGIN           1     /home/daniel/dev/maatkit/common/BinaryLogParser.pm:26 
BEGIN           1     /home/daniel/dev/maatkit/common/BinaryLogParser.pm:31 
new             1   0 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:34 
parse_event    18   0 /home/daniel/dev/maatkit/common/BinaryLogParser.pm:49 

Uncovered Subroutines
---------------------

Subroutine  Count Pod Location                                              
----------- ----- --- ------------------------------------------------------
_d              0     /home/daniel/dev/maatkit/common/BinaryLogParser.pm:238


BinaryLogParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 7;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            11   use BinaryLogParser;
               1                                  3   
               1                                 10   
15             1                    1            12   use MaatkitTest;
               1                                  5   
               1                                 36   
16                                                    
17             1                                  9   my $p = new BinaryLogParser();
18                                                    
19             1                                  3   my $oktorun = 1;
20             1                                  4   my $sample  = "common/t/samples/binlogs/";
21                                                    
22                                                    test_log_parser(
23                                                       parser  => $p,
24                                                       file    => $sample."binlog001.txt",
25             1                    1             4      oktorun => sub { $oktorun = $_[0]; },
26             1                                113      result  => [
27                                                      {
28                                                        '@@session.character_set_client' => '8',
29                                                        '@@session.collation_connection' => '8',
30                                                        '@@session.collation_server' => '8',
31                                                        '@@session.foreign_key_checks' => '1',
32                                                        '@@session.sql_auto_is_null' => '1',
33                                                        '@@session.sql_mode' => '0',
34                                                        '@@session.time_zone' => '\'system\'',
35                                                        '@@session.unique_checks' => '1',
36                                                        Query_time => '20664',
37                                                        Thread_id => '104168',
38                                                        arg => 'BEGIN',
39                                                        bytes => 5,
40                                                        cmd => 'Query',
41                                                        end_log_pos => '498006652',
42                                                        error_code => '0',
43                                                        offset => '498006722',
44                                                        pos_in_log => 146,
45                                                        server_id => '21',
46                                                        timestamp => '1197046970',
47                                                        ts => '071207 12:02:50'
48                                                      },
49                                                      {
50                                                        Query_time => '20675',
51                                                        Thread_id => '104168',
52                                                        arg => 'update test3.tblo as o
53                                                             inner join test3.tbl2 as e on o.animal = e.animal and o.oid = e.oid
54                                                          set e.tblo = o.tblo,
55                                                              e.col3 = o.col3
56                                                          where e.tblo is null',
57                                                        bytes => 179,
58                                                        cmd => 'Query',
59                                                        db => 'test1',
60                                                        end_log_pos => '278',
61                                                        error_code => '0',
62                                                        offset => '498006789',
63                                                        pos_in_log => 605,
64                                                        server_id => '21',
65                                                        timestamp => '1197046927',
66                                                        ts => '071207 12:02:07'
67                                                      },
68                                                      {
69                                                        Query_time => '20704',
70                                                        Thread_id => '104168',
71                                                        arg => 'replace into test4.tbl9(tbl5, day, todo, comment)
72                                                     select distinct o.tbl5, date(o.col3), \'misc\', right(\'foo\', 50)
73                                                          from test3.tblo as o
74                                                             inner join test3.tbl2 as e on o.animal = e.animal and o.oid = e.oid
75                                                          where e.tblo is not null
76                                                             and o.col1 > 0
77                                                             and o.tbl2 is null
78                                                             and o.col3 >= date_sub(current_date, interval 30 day)',
79                                                        bytes => 363,
80                                                        cmd => 'Query',
81                                                        end_log_pos => '836',
82                                                        error_code => '0',
83                                                        offset => '498007067',
84                                                        pos_in_log => 953,
85                                                        server_id => '21',
86                                                        timestamp => '1197046928',
87                                                        ts => '071207 12:02:08'
88                                                      },
89                                                      {
90                                                        Query_time => '20664',
91                                                        Thread_id => '104168',
92                                                        arg => 'update test3.tblo as o inner join test3.tbl2 as e
93                                                     on o.animal = e.animal and o.oid = e.oid
94                                                          set o.tbl2 = e.tbl2,
95                                                              e.col9 = now()
96                                                          where o.tbl2 is null',
97                                                        bytes => 170,
98                                                        cmd => 'Query',
99                                                        end_log_pos => '1161',
100                                                       error_code => '0',
101                                                       offset => '498007625',
102                                                       pos_in_log => 1469,
103                                                       server_id => '21',
104                                                       timestamp => '1197046970',
105                                                       ts => '071207 12:02:50'
106                                                     },
107                                                     {
108                                                       Xid => '4584956',
109                                                       arg => 'COMMIT',
110                                                       bytes => 6,
111                                                       cmd => 'Query',
112                                                       end_log_pos => '498007840',
113                                                       offset => '498007950',
114                                                       pos_in_log => 1793,
115                                                       server_id => '21',
116                                                       ts => '071207 12:02:50'
117                                                     },
118                                                     {
119                                                       Query_time => '20661',
120                                                       Thread_id => '103374',
121                                                       arg => 'insert into test1.tbl6
122                                                         (day, tbl5, misccol9type, misccol9, metric11, metric12, secs)
123                                                         values
124                                                         (convert_tz(current_timestamp,\'EST5EDT\',\'PST8PDT\'), \'239\', \'foo\', \'bar\', 1, \'1\', \'16.3574378490448\')
125                                                         on duplicate key update metric11 = metric11 + 1,
126                                                            metric12 = metric12 + values(metric12), secs = secs + values(secs)',
127                                                       bytes => 341,
128                                                       cmd => 'Query',
129                                                       end_log_pos => '417',
130                                                       error_code => '0',
131                                                       offset => '498007977',
132                                                       pos_in_log => 1889,
133                                                       server_id => '21',
134                                                       timestamp => '1197046973',
135                                                       ts => '071207 12:02:53'
136                                                     },
137                                                     {
138                                                       Xid => '4584964',
139                                                       arg => 'COMMIT',
140                                                       bytes => 6,
141                                                       cmd => 'Query',
142                                                       end_log_pos => '498008284',
143                                                       offset => '498008394',
144                                                       pos_in_log => 2383,
145                                                       server_id => '21',
146                                                       ts => '071207 12:02:53'
147                                                     },
148                                                     {
149                                                       Query_time => '20661',
150                                                       Thread_id => '103374',
151                                                       arg => 'update test2.tbl8
152                                                         set last2metric1 = last1metric1, last2time = last1time,
153                                                            last1metric1 = last0metric1, last1time = last0time,
154                                                            last0metric1 = ondeckmetric1, last0time = now()
155                                                         where tbl8 in (10800712)',
156                                                       bytes => 228,
157                                                       cmd => 'Query',
158                                                       end_log_pos => '314',
159                                                       error_code => '0',
160                                                       offset => '498008421',
161                                                       pos_in_log => 2479,
162                                                       server_id => '21',
163                                                       timestamp => '1197046973',
164                                                       ts => '071207 12:02:53'
165                                                     },
166                                                     {
167                                                       Xid => '4584965',
168                                                       arg => 'COMMIT',
169                                                       bytes => 6,
170                                                       cmd => 'Query',
171                                                       end_log_pos => '498008625',
172                                                       offset => '498008735',
173                                                       pos_in_log => 2860,
174                                                       server_id => '21',
175                                                       ts => '071207 12:02:53'
176                                                     },
177                                                     {
178                                                       arg => 'ROLLBACK /* added by mysqlbinlog */
179                                                   /*!50003 SET COMPLETION_TYPE=@OLD_COMPLETION_TYPE*/',
180                                                       bytes => 87,
181                                                       cmd => 'Query',
182                                                       pos_in_log => 3066,
183                                                       ts => undef
184                                                     }
185                                                   ]
186                                                   );
187                                                   
188            1                                 72   is(
189                                                      $oktorun,
190                                                      0,
191                                                      'Sets oktorun'
192                                                   );
193                                                   
194            1                                 48   test_log_parser(
195                                                      parser => $p,
196                                                      file   => $sample."binlog002.txt",
197                                                      result => [
198                                                     {
199                                                       arg => 'ROLLBACK',
200                                                       bytes => 8,
201                                                       cmd => 'Query',
202                                                       end_log_pos => '98',
203                                                       offset => '4',
204                                                       pos_in_log => 146,
205                                                       server_id => '12345',
206                                                       ts => '090722  7:21:41'
207                                                     },
208                                                     {
209                                                       '@@session.character_set_client' => '8',
210                                                       '@@session.collation_connection' => '8',
211                                                       '@@session.collation_server' => '8',
212                                                       '@@session.foreign_key_checks' => '1',
213                                                       '@@session.sql_auto_is_null' => '1',
214                                                       '@@session.sql_mode' => '0',
215                                                       '@@session.unique_checks' => '1',
216                                                       Query_time => '0',
217                                                       Thread_id => '3',
218                                                       arg => 'create database d',
219                                                       bytes => 17,
220                                                       cmd => 'Query',
221                                                       end_log_pos => '175',
222                                                       error_code => '0',
223                                                       offset => '98',
224                                                       pos_in_log => 381,
225                                                       server_id => '12345',
226                                                       timestamp => '1248268919',
227                                                       ts => '090722  7:21:59'
228                                                     },
229                                                     {
230                                                       Query_time => '0',
231                                                       Thread_id => '3',
232                                                       arg => 'create table foo (i int)',
233                                                       bytes => 24,
234                                                       cmd => 'Query',
235                                                       db => 'd',
236                                                       end_log_pos => '259',
237                                                       error_code => '0',
238                                                       offset => '175',
239                                                       pos_in_log => 795,
240                                                       server_id => '12345',
241                                                       timestamp => '1248268936',
242                                                       ts => '090722  7:22:16'
243                                                     },
244                                                     {
245                                                       Query_time => '0',
246                                                       Thread_id => '3',
247                                                       arg => 'insert foo values (1),(2)',
248                                                       bytes => 25,
249                                                       cmd => 'Query',
250                                                       end_log_pos => '344',
251                                                       error_code => '0',
252                                                       offset => '259',
253                                                       pos_in_log => 973,
254                                                       server_id => '12345',
255                                                       timestamp => '1248268944',
256                                                       ts => '090722  7:22:24'
257                                                     },
258                                                     {
259                                                       arg => 'ROLLBACK /* added by mysqlbinlog */
260                                                   /*!50003 SET COMPLETION_TYPE=@OLD_COMPLETION_TYPE*/',
261                                                       bytes => 87,
262                                                       cmd => 'Query',
263                                                       pos_in_log => 1152,
264                                                       ts => undef
265                                                     }
266                                                      ]
267                                                   );
268                                                   
269                                                   # #############################################################################
270                                                   # Issue 606: Unknown event type Rotate at ./mk-slave-prefetch
271                                                   # #############################################################################
272            1                                 42   test_log_parser(
273                                                      parser => $p,
274                                                      file   => $sample."binlog006.txt",
275                                                      result => [],
276                                                   );
277                                                   
278                                                   # #############################################################################
279                                                   # Done.
280                                                   # #############################################################################
281            1                                  3   exit;


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
BEGIN          1 BinaryLogParser.t:10
BEGIN          1 BinaryLogParser.t:11
BEGIN          1 BinaryLogParser.t:12
BEGIN          1 BinaryLogParser.t:14
BEGIN          1 BinaryLogParser.t:15
BEGIN          1 BinaryLogParser.t:4 
BEGIN          1 BinaryLogParser.t:9 
__ANON__       1 BinaryLogParser.t:25


