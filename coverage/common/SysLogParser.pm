---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/SysLogParser.pm   90.0   62.5   75.0   85.7    0.0   73.5   81.6
SysLogParser.t                100.0   50.0   33.3  100.0    n/a   26.5   92.9
Total                          94.5   58.3   68.4   93.3    0.0  100.0   86.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:28 2010
Finish:       Thu Jun 24 19:37:28 2010

Run:          SysLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:30 2010
Finish:       Thu Jun 24 19:37:30 2010

/home/daniel/dev/maatkit/common/SysLogParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010 Baron Schwartz.
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
18                                                    # SysLogParser package $Revision: 5831 $
19                                                    # ###########################################################################
20                                                    package SysLogParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  6   
               1                                  7   
25             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  6   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
28                                                    
29                                                    # This regex matches the message number, line number, and content of a syslog
30                                                    # message:
31                                                    # 2008 Jan  9 16:16:34 hostname postgres[30059]: [13-2] ...content...
32                                                    my $syslog_regex = qr{\A.*\w+\[\d+\]: \[(\d+)-(\d+)\] (.*)\Z};
33                                                    
34                                                    # This class generates currying functions that wrap around a standard
35                                                    # log-parser's next_event() and tell() function pointers.  The wrappers behave
36                                                    # the same way, except that they'll return entire syslog events, instead of
37                                                    # lines at a time.  To use it, do the following:
38                                                    #
39                                                    # sub parse_event {
40                                                    #    my ($self, %args) = @_;
41                                                    #    my ($next_event, $tell, $is_syslog) = SysLogParser::make_closures(%args);
42                                                    #    # ... write your code to use the $next_event and $tell here...
43                                                    # }
44                                                    #
45                                                    # If the log isn't in syslog format, $is_syslog will be false and you'll get
46                                                    # back simple wrappers around the $next_event and $tell functions.  (They still
47                                                    # have to be wrapped, because to find out whether the log is in syslog format,
48                                                    # the first line has to be examined.)
49                                                    sub new {
50    ***      1                    1      0      8      my ( $class ) = @_;
51             1                                  4      my $self = {};
52             1                                 12      return bless $self, $class;
53                                                    }
54                                                    
55                                                    # This method is here so that SysLogParser can be used and tested in its own
56                                                    # right.  However, its ability to generate wrapper functions probably means that
57                                                    # it should be used as a translation layer, not directly.  You can use this code
58                                                    # as an example of how to integrate this into other packages.
59                                                    sub parse_event {
60    ***      5                    5      0    198      my ( $self, %args ) = @_;
61             5                                 26      my ( $next_event, $tell, $is_syslog ) = $self->generate_wrappers(%args);
62             5                                 20      return $next_event->();
63                                                    }
64                                                    
65                                                    # This is an example of how a class can seamlessly put a syslog translation
66                                                    # layer underneath itself.
67                                                    sub generate_wrappers {
68    ***      8                    8      0     42      my ( $self, %args ) = @_;
69                                                    
70                                                       # Reset everything, just in case some cruft was left over from a previous use
71                                                       # of this object.  The object has stateful closures.  If this isn't done,
72                                                       # then they'll keep reading from old filehandles.  The sanity check is based
73                                                       # on the memory address of the closure!
74             8    100    100                   78      if ( ($self->{sanity} || '') ne "$args{next_event}" ){
75             4                                 10         MKDEBUG && _d("Clearing and recreating internal state");
76             4                                 23         @{$self}{qw(next_event tell is_syslog)} = $self->make_closures(%args);
               4                                 20   
77             4                                 15         $self->{sanity} = "$args{next_event}";
78                                                       }
79                                                    
80                                                       # Return the wrapper functions!
81             8                                 54      return @{$self}{qw(next_event tell is_syslog)};
               8                                 51   
82                                                    }
83                                                    
84                                                    # Make the closures!  The $args{misc}->{new_event_test} is an optional
85                                                    # subroutine reference, which tells the wrapper when to consider a line part of
86                                                    # a new event, in syslog format, even when it's technically the same syslog
87                                                    # event.  See the test for samples/pg-syslog-002.txt for an example.  This
88                                                    # argument should be passed in via the call to parse_event().  Ditto for
89                                                    # 'line_filter', which is some processing code to run on every line of content
90                                                    # in an event.
91                                                    sub make_closures {
92    ***      4                    4      0     22      my ( $self, %args ) = @_;
93                                                    
94                                                       # The following variables will be referred to in the manufactured
95                                                       # subroutines, making them proper closures.
96             4                                 17      my $next_event     = $args{'next_event'};
97             4                                 12      my $tell           = $args{'tell'};
98             4                                 16      my $new_event_test = $args{'misc'}->{'new_event_test'};
99             4                                 17      my $line_filter    = $args{'misc'}->{'line_filter'};
100                                                   
101                                                      # The first thing to do is get a line from the log and see if it's from
102                                                      # syslog.
103            4                                 16      my $test_line = $next_event->();
104            4                                 50      MKDEBUG && _d('Read first sample/test line:', $test_line);
105                                                   
106                                                      # If it's syslog, we have to generate a moderately elaborate wrapper
107                                                      # function.
108   ***      4     50     33                  109      if ( defined $test_line && $test_line =~ m/$syslog_regex/o ) {
109                                                   
110                                                         # Within syslog-parsing subroutines, we'll use LLSP (low-level syslog
111                                                         # parser) as a MKDEBUG line prefix.
112            4                                 12         MKDEBUG && _d('This looks like a syslog line, MKDEBUG prefix=LLSP');
113                                                   
114                                                         # Grab the interesting bits out of the test line, and save the result.
115            4                                 80         my ($msg_nr, $line_nr, $content) = $test_line =~ m/$syslog_regex/o;
116            4                                 19         my @pending = ($test_line);
117            4                                  9         my $last_msg_nr = $msg_nr;
118            4                                 11         my $pos_in_log  = 0;
119                                                   
120                                                         # Generate the subroutine for getting a full log message without syslog
121                                                         # breaking it across multiple lines.
122                                                         my $new_next_event = sub {
123           15                   15            34            MKDEBUG && _d('LLSP: next_event()');
124                                                   
125                                                            # Keeping the pos_in_log variable right is a bit tricky!  In general,
126                                                            # we have to tell() the filehandle before trying to read from it,
127                                                            # getting the position before the data we've just read.  The simple
128                                                            # rule is that when we push something onto @pending, which we almost
129                                                            # always do, then $pos_in_log should point to the beginning of that
130                                                            # saved content in the file.
131           15                                 35            MKDEBUG && _d('LLSP: Current virtual $fh position:', $pos_in_log);
132           15                                 39            my $new_pos = 0;
133                                                   
134                                                            # @arg_lines is where we store up the content we're about to return.
135                                                            # It contains $content; @pending contains a single saved $line.
136           15                                 37            my @arg_lines;
137                                                   
138                                                            # Here we actually examine lines until we have found a complete event.
139           15                                 34            my $line;
140                                                            LINE:
141           15           100                   88            while (
142                                                               defined($line = shift @pending)
143                                                               || do {
144                                                                  # Save $new_pos, because when we hit EOF we can't $tell->()
145                                                                  # anymore.
146           29                                 72                  eval { $new_pos = -1; $new_pos = $tell->() };
              29                                 74   
              29                                 99   
147           29                                136                  defined($line = $next_event->());
148                                                               }
149                                                            ) {
150           39                                156               MKDEBUG && _d('LLSP: Line:', $line);
151                                                   
152                                                               # Parse the line.
153           39                                680               ($msg_nr, $line_nr, $content) = $line =~ m/$syslog_regex/o;
154   ***     39     50    100                  355               if ( !$msg_nr ) {
      ***           100     66                        
                    100                               
155   ***      0                                  0                  die "Can't parse line: $line";
156                                                               }
157                                                   
158                                                               # The message number has changed -- thus, new message.
159                                                               elsif ( $msg_nr != $last_msg_nr ) {
160           10                                 20                  MKDEBUG && _d('LLSP: $msg_nr', $last_msg_nr, '=>', $msg_nr);
161           10                                 26                  $last_msg_nr = $msg_nr;
162           10                                 30                  last LINE;
163                                                               }
164                                                   
165                                                               # Or, the caller gave us a custom new_event_test and it is true --
166                                                               # thus, also new message.
167                                                               elsif ( @arg_lines && $new_event_test && $new_event_test->($content) ) {
168            1                                  2                  MKDEBUG && _d('LLSP: $new_event_test matches');
169            1                                  3                  last LINE;
170                                                               }
171                                                   
172                                                               # Otherwise it's part of the current message; put it onto the list
173                                                               # of lines pending.  We have to translate characters that syslog has
174                                                               # munged.  Some translate TAB into the literal characters '^I' and
175                                                               # some, rsyslog on Debian anyway, seem to translate all whitespace
176                                                               # control characters into an octal string representing the character
177                                                               # code.
178                                                               # Example: #011FROM pg_catalog.pg_class c
179           28                                115               $content =~ s/#(\d{3})/chr(oct($1))/ge;
              11                                 62   
180           28                                 75               $content =~ s/\^I/\t/g;
181           28    100                         102               if ( $line_filter ) {
182           13                                 29                  MKDEBUG && _d('LLSP: applying $line_filter');
183           13                                 46                  $content = $line_filter->($content);
184                                                               }
185                                                   
186           28                                181               push @arg_lines, $content;
187                                                            }
188           15                                 70            MKDEBUG && _d('LLSP: Exited while-loop after finding a complete entry');
189                                                   
190                                                            # Mash the pending stuff together to return it.
191           15    100                          80            my $psql_log_event = @arg_lines ? join('', @arg_lines) : undef;
192           15                                 33            MKDEBUG && _d('LLSP: Final log entry:', $psql_log_event);
193                                                   
194                                                            # Save the new content into @pending for the next time.  $pos_in_log
195                                                            # must also be updated to whatever $new_pos is.
196           15    100                          53            if ( defined $line ) {
197           11                                 24               MKDEBUG && _d('LLSP: Saving $line:', $line);
198           11                                 36               @pending = $line;
199           11                                 26               MKDEBUG && _d('LLSP: $pos_in_log:', $pos_in_log, '=>', $new_pos);
200           11                                 33               $pos_in_log = $new_pos;
201                                                            }
202                                                            else {
203                                                               # We hit the end of the file.
204            4                                  8               MKDEBUG && _d('LLSP: EOF reached');
205            4                                 13               @pending     = ();
206            4                                 11               $last_msg_nr = 0;
207                                                            }
208                                                   
209           15                                 94            return $psql_log_event;
210            4                                 42         };
211                                                   
212                                                         # Create the closure for $tell->();
213                                                         my $new_tell = sub {
214           10                   10            23            MKDEBUG && _d('LLSP: tell()', $pos_in_log);
215           10                                 57            return $pos_in_log;
216            4                                 22         };
217                                                   
218            4                                 26         return ($new_next_event, $new_tell, 1);
219                                                      }
220                                                   
221                                                      # This is either at EOF already, or it's not syslog format.
222                                                      else {
223                                                   
224                                                         # Within plain-log-parsing subroutines, we'll use PLAIN as a MKDEBUG
225                                                         # line prefix.
226   ***      0                                  0         MKDEBUG && _d('Plain log, or we are at EOF; MKDEBUG prefix=PLAIN');
227                                                   
228                                                         # The @pending array is really only needed to return the one line we
229                                                         # already read as a test.  Too bad we can't just push it back onto the
230                                                         # log.  TODO: maybe we can test whether the filehandle is seekable and
231                                                         # seek back to the start, then just return the unwrapped functions?
232   ***      0      0                           0         my @pending = defined $test_line ? ($test_line) : ();
233                                                   
234                                                         my $new_next_event = sub {
235   ***      0                    0             0            MKDEBUG && _d('PLAIN: next_event(); @pending:', scalar @pending);
236   ***      0      0                           0            return @pending ? shift @pending : $next_event->();
237   ***      0                                  0         };
238                                                         my $new_tell = sub {
239   ***      0                    0             0            MKDEBUG && _d('PLAIN: tell(); @pending:', scalar @pending);
240   ***      0      0                           0            return @pending ? 0 : $tell->();
241   ***      0                                  0         };
242   ***      0                                  0         return ($new_next_event, $new_tell, 0);
243                                                      }
244                                                   }
245                                                   
246                                                   sub _d {
247            1                    1             8      my ($package, undef, $line) = caller 0;
248   ***      2     50                           9      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 10   
249            1                                  4           map { defined $_ ? $_ : 'undef' }
250                                                           @_;
251            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
252                                                   }
253                                                   
254                                                   1;
255                                                   
256                                                   # ###########################################################################
257                                                   # End SysLogParser package
258                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
74           100      4      4   if (($$self{'sanity'} || '') ne "$args{'next_event'}")
108   ***     50      4      0   if (defined $test_line and $test_line =~ /$syslog_regex/o) { }
154   ***     50      0     39   if (not $msg_nr) { }
             100     10     29   elsif ($msg_nr != $last_msg_nr) { }
             100      1     28   elsif (@arg_lines and $new_event_test and &$new_event_test($content)) { }
181          100     13     15   if ($line_filter)
191          100     14      1   @arg_lines ? :
196          100     11      4   if (defined $line) { }
232   ***      0      0      0   defined $test_line ? :
236   ***      0      0      0   @pending ? :
240   ***      0      0      0   @pending ? :
248   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
108   ***     33      0      0      4   defined $test_line and $test_line =~ /$syslog_regex/o
154          100     14     14      1   @arg_lines and $new_event_test
      ***     66     28      0      1   @arg_lines and $new_event_test and &$new_event_test($content)

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0
74           100      7      1   $$self{'sanity'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
141          100     14     25      4   defined($line = shift @pending) or do {
	eval {
	do {
	$new_pos = -1;
$new_pos = &$tell()
}
};
defined($line = &$next_event())
}


Covered Subroutines
-------------------

Subroutine        Count Pod Location                                           
----------------- ----- --- ---------------------------------------------------
BEGIN                 1     /home/daniel/dev/maatkit/common/SysLogParser.pm:22 
BEGIN                 1     /home/daniel/dev/maatkit/common/SysLogParser.pm:23 
BEGIN                 1     /home/daniel/dev/maatkit/common/SysLogParser.pm:24 
BEGIN                 1     /home/daniel/dev/maatkit/common/SysLogParser.pm:25 
BEGIN                 1     /home/daniel/dev/maatkit/common/SysLogParser.pm:27 
__ANON__             15     /home/daniel/dev/maatkit/common/SysLogParser.pm:123
__ANON__             10     /home/daniel/dev/maatkit/common/SysLogParser.pm:214
_d                    1     /home/daniel/dev/maatkit/common/SysLogParser.pm:247
generate_wrappers     8   0 /home/daniel/dev/maatkit/common/SysLogParser.pm:68 
make_closures         4   0 /home/daniel/dev/maatkit/common/SysLogParser.pm:92 
new                   1   0 /home/daniel/dev/maatkit/common/SysLogParser.pm:50 
parse_event           5   0 /home/daniel/dev/maatkit/common/SysLogParser.pm:60 

Uncovered Subroutines
---------------------

Subroutine        Count Pod Location                                           
----------------- ----- --- ---------------------------------------------------
__ANON__              0     /home/daniel/dev/maatkit/common/SysLogParser.pm:235
__ANON__              0     /home/daniel/dev/maatkit/common/SysLogParser.pm:239


SysLogParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            38      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            14   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
11             1                    1            13   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1            10   use Test::More tests => 26;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            12   use SysLogParser;
               1                                  3   
               1                                 11   
15             1                    1            16   use MaatkitTest;
               1                                  3   
               1                                 41   
16                                                    
17             1                                  8   my $p = new SysLogParser;
18                                                    
19                                                    # The final line is broken across two lines in the actual log, but it's one
20                                                    # logical event.
21             1                                 10   test_log_parser(
22                                                       parser => $p,
23                                                       file   => 'common/t/samples/pg-syslog-005.txt',
24                                                       result => [
25                                                          '2010-02-10 09:03:26.918 EST c=4b72bcae.d01,u=[unknown],D=[unknown] LOG:  connection received: host=[local]',
26                                                          '2010-02-10 09:03:26.922 EST c=4b72bcae.d01,u=fred,D=fred LOG:  connection authorized: user=fred database=fred',
27                                                          '2010-02-10 09:03:36.645 EST c=4b72bcae.d01,u=fred,D=fred LOG:  duration: 0.627 ms  statement: select 1;',
28                                                          '2010-02-10 09:03:39.075 EST c=4b72bcae.d01,u=fred,D=fred LOG:  disconnection: session time: 0:00:12.159 user=fred database=fred host=[local]',
29                                                       ],
30                                                    );
31                                                    
32                                                    # This test case examines $tell and sees whether it's correct or not.  It also
33                                                    # tests whether we can correctly pass in a callback that lets the caller
34                                                    # override the rules about when a new event is seen.  In this example, we want
35                                                    # to break the last event up into two parts, even though they are the same event
36                                                    # in the syslog entry.
37                                                    {
38             1                                 20      my $file = "$ENV{MAATKIT_TRUNK}/common/t/samples/pg-syslog-002.txt";
               1                                  8   
39             1                                  3      eval {
40    ***      1     50                          42         open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
41                                                          my %parser_args = (
42             6                    6            77            next_event => sub { return <$fh>; },
43             5                    5            27            tell       => sub { return tell($fh);  },
44                                                             fh         => $fh,
45                                                             misc       => {
46                                                                new_event_test => sub {
47                                                                   # A simplified PgLogParser::$log_line_regex
48    ***      1     50             1            14                  defined $_[0] && $_[0] =~ m/STATEMENT/;
49                                                                },
50                                                             }
51             1                                 17         );
52             1                                  9         my ( $next_event, $tell, $is_syslog )
53                                                             = $p->generate_wrappers(%parser_args);
54                                                    
55             1                                  5         is ($tell->(),
56                                                             0,
57                                                             'pg-syslog-002.txt $tell 0 ok');
58             1                                  5         is ($next_event->(),
59                                                             '2010-02-08 09:52:41.526 EST c=4b701056.1dc6,u=fred,D=fred LOG: '
60                                                             . ' statement: select * from pg_stat_bgwriter;',
61                                                             'pg-syslog-002.txt $next_event 0 ok');
62                                                    
63             1                                  6         is ($tell->(),
64                                                             153,
65                                                             'pg-syslog-002.txt $tell 1 ok');
66             1                                  5         is ($next_event->(),
67                                                             '2010-02-08 09:52:41.533 EST c=4b701056.1dc6,u=fred,D=fred LOG:  '
68                                                             . 'duration: 8.309 ms',
69                                                             'pg-syslog-002.txt $next_event 1 ok');
70                                                    
71             1                                  6         is ($tell->(),
72                                                             282,
73                                                             'pg-syslog-002.txt $tell 2 ok');
74             1                                  5         is ($next_event->(),
75                                                             '2010-02-08 09:52:57.807 EST c=4b701056.1dc6,u=fred,D=fred LOG:  '
76                                                             . 'statement: create index ix_a on foo (a);',
77                                                             'pg-syslog-002.txt $next_event 2 ok');
78                                                    
79             1                                  5         is ($tell->(),
80                                                             433,
81                                                             'pg-syslog-002.txt $tell 3 ok');
82             1                                  5         is ($next_event->(),
83                                                             '2010-02-08 09:52:57.864 EST c=4b701056.1dc6,u=fred,D=fred ERROR:  '
84                                                             . 'relation "ix_a" already exists',
85                                                             'pg-syslog-002.txt $next_event 3 ok');
86                                                    
87             1                                  7         is ($tell->(),
88                                                             576,
89                                                             'pg-syslog-002.txt $tell 4 ok');
90             1                                  5         is ($next_event->(),
91                                                             '2010-02-08 09:52:57.864 EST c=4b701056.1dc6,u=fred,D=fred STATEMENT:  '
92                                                             . 'create index ix_a on foo (a);',
93                                                             'pg-syslog-002.txt $next_event 4 ok');
94                                                    
95             1                                 16         close $fh;
96                                                       };
97             1                                  5      is(
98                                                          $EVAL_ERROR,
99                                                          '',
100                                                         "No error on samples/pg-syslog-002.txt",
101                                                      );
102                                                   
103                                                   }
104                                                   
105                                                   # This test case checks a $line_filter, and sees whether lines get proper
106                                                   # newline-munging.
107                                                   {
108            1                                  3      my $file = "$ENV{MAATKIT_TRUNK}/common/t/samples/pg-syslog-003.txt";
               1                                  6   
109            1                                  3      eval {
110   ***      1     50                          40         open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
111                                                         my %parser_args = (
112           14                   14           129            next_event => sub { return <$fh>; },
113           13                   13            56            tell       => sub { return tell($fh);  },
114                                                            fh         => $fh,
115                                                            misc       => {
116                                                               line_filter => sub {
117                                                                  # A simplified PgLogParser::$log_line_regex
118   ***     13     50            13            62                  defined $_[0] && $_[0] =~ s/\A\t/\n/; $_[0];
              13                                 57   
119                                                               },
120                                                            }
121            1                                 17         );
122            1                                  9         my ( $next_event, $tell, $is_syslog )
123                                                            = $p->generate_wrappers(%parser_args);
124                                                   
125            1                                  5         is ($tell->(),
126                                                            0,
127                                                            'pg-syslog-003.txt $tell 0 ok');
128            1                                  5         is ($next_event->(),
129                                                            "2010-02-08 09:53:51.724 EST c=4b701056.1dc6,u=fred,D=fred LOG:  "
130                                                             . "statement: SELECT n.nspname as \"Schema\","
131                                                             . "\n  c.relname as \"Name\","
132                                                             . "\n  CASE c.relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'i' THEN 'index' WHEN 'S' THEN 'sequence' WHEN 's' THEN"
133                                                             . " 'special' END as \"Type\","
134                                                             . "\n  r.rolname as \"Owner\""
135                                                             . "\nFROM pg_catalog.pg_class c"
136                                                             . "\n     JOIN pg_catalog.pg_roles r ON r.oid = c.relowner"
137                                                             . "\n     LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace"
138                                                             . "\nWHERE c.relkind IN ('r','v','S','')"
139                                                             . "\n  AND n.nspname <> 'pg_catalog'"
140                                                             . "\n  AND n.nspname !~ '^pg_toast'"
141                                                             . "\n  AND pg_catalog.pg_table_is_visible(c.oid)"
142                                                             . "\nORDER BY 1,2;",
143                                                            'pg-syslog-003.txt $next_event 0 ok');
144                                                   
145            1                                 12         close $fh;
146                                                      };
147            1                                  5      is(
148                                                         $EVAL_ERROR,
149                                                         '',
150                                                         "No error on samples/pg-syslog-003.txt",
151                                                      );
152                                                   
153                                                   }
154                                                   
155                                                   # This test case checks pos_in_log again, without any filters.
156                                                   {
157            1                                  4      my $file = "$ENV{MAATKIT_TRUNK}/common/t/samples/pg-syslog-005.txt";
               1                                  6   
158            1                                  3      eval {
159   ***      1     50                          29         open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
160                                                         my %parser_args = (
161            6                    6            62            next_event => sub { return <$fh>; },
162            5                    5            22            tell       => sub { return tell($fh);  },
163            1                                 11            fh         => $fh,
164                                                         );
165            1                                  8         my ( $next_event, $tell, $is_syslog )
166                                                            = $p->generate_wrappers(%parser_args);
167                                                   
168            1                                  8         my @pairs = (
169                                                            [0,   '2010-02-10 09:03:26.918 EST c=4b72bcae.d01,u=[unknown],D=[unknown] LOG:  connection received: host=[local]'],
170                                                            [152, '2010-02-10 09:03:26.922 EST c=4b72bcae.d01,u=fred,D=fred LOG:  connection authorized: user=fred database=fred'],
171                                                            [307, '2010-02-10 09:03:36.645 EST c=4b72bcae.d01,u=fred,D=fred LOG:  duration: 0.627 ms  statement: select 1;'],
172                                                            [456, '2010-02-10 09:03:39.075 EST c=4b72bcae.d01,u=fred,D=fred LOG:  disconnection: session time: 0:00:12.159 user=fred database=fred host=[local]'],
173                                                         );
174                                                   
175            1                                  8         foreach my $i ( 0 .. $#pairs) {
176            4                                 15            my $pair = $pairs[$i];
177            4                                 16            is ($tell->(), $pair->[0], "pg-syslog-005.txt \$tell $i ok");
178            4                                 19            is ($next_event->(), $pair->[1], "pg-syslog-005.txt \$next_event $i ok");
179                                                         }
180                                                   
181            1                                 13         close $fh;
182                                                      };
183            1                                  5      is(
184                                                         $EVAL_ERROR,
185                                                         '',
186                                                         "No error on samples/pg-syslog-005.txt",
187                                                      );
188                                                   
189                                                   }
190                                                   
191                                                   # #############################################################################
192                                                   # Done.
193                                                   # #############################################################################
194            1                                  4   my $output = '';
195                                                   {
196            1                                  3      local *STDERR;
               1                                  8   
197            1                    1             2      open STDERR, '>', \$output;
               1                                304   
               1                                  3   
               1                                  7   
198            1                                 19      $p->_d('Complete test coverage');
199                                                   }
200                                                   like(
201            1                                 21      $output,
202                                                      qr/Complete test coverage/,
203                                                      '_d() works'
204                                                   );
205            1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
40    ***     50      0      1   unless open my $fh, '<', $file
48    ***     50      1      0   if defined $_[0]
110   ***     50      0      1   unless open my $fh, '<', $file
118   ***     50     13      0   if defined $_[0]
159   ***     50      0      1   unless open my $fh, '<', $file


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location          
---------- ----- ------------------
BEGIN          1 SysLogParser.t:10 
BEGIN          1 SysLogParser.t:11 
BEGIN          1 SysLogParser.t:12 
BEGIN          1 SysLogParser.t:14 
BEGIN          1 SysLogParser.t:15 
BEGIN          1 SysLogParser.t:197
BEGIN          1 SysLogParser.t:4  
BEGIN          1 SysLogParser.t:9  
__ANON__      14 SysLogParser.t:112
__ANON__      13 SysLogParser.t:113
__ANON__      13 SysLogParser.t:118
__ANON__       6 SysLogParser.t:161
__ANON__       5 SysLogParser.t:162
__ANON__       6 SysLogParser.t:42 
__ANON__       5 SysLogParser.t:43 
__ANON__       1 SysLogParser.t:48 


