---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/PgLogParser.pm   96.2   82.2   73.5  100.0    0.0   98.2   88.2
PgLogParser.t                 100.0   50.0   33.3  100.0    n/a    1.8   96.1
Total                          97.1   81.5   71.2  100.0    0.0  100.0   89.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:34 2010
Finish:       Thu Jun 24 19:35:34 2010

Run:          PgLogParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:35 2010
Finish:       Thu Jun 24 19:35:35 2010

/home/daniel/dev/maatkit/common/PgLogParser.pm

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
18                                                    # PgLogParser package $Revision: 5835 $
19                                                    # ###########################################################################
20                                                    package PgLogParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  6   
               1                                  8   
25             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  7   
26                                                    
27    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 15   
28                                                    
29                                                    # This regex is partially inspired by one from pgfouine.  But there is no
30                                                    # documentation on the last capture in that regex, so I omit that.  (TODO: that
31                                                    # actually seems to be for CSV logging.)
32                                                    #     (?:[0-9XPFDBLA]{2}[0-9A-Z]{3}:[\s]+)?
33                                                    # Here I constrain to match at least two spaces after the severity level,
34                                                    # because the source code tells me to.  I believe this is controlled in elog.c:
35                                                    # appendStringInfo(&buf, "%s:  ", error_severity(edata->elevel));
36                                                    my $log_line_regex = qr{
37                                                       (LOG|DEBUG|CONTEXT|WARNING|ERROR|FATAL|PANIC|HINT
38                                                        |DETAIL|NOTICE|STATEMENT|INFO|LOCATION)
39                                                       :\s\s+
40                                                       }x;
41                                                    
42                                                    # The following are taken right from the comments in postgresql.conf for
43                                                    # log_line_prefix.
44                                                    my %attrib_name_for = (
45                                                       u => 'user',
46                                                       d => 'db',
47                                                       r => 'host', # With port
48                                                       h => 'host',
49                                                       p => 'Process_id',
50                                                       t => 'ts',
51                                                       m => 'ts',   # With milliseconds
52                                                       i => 'Query_type',
53                                                       c => 'Session_id',
54                                                       l => 'Line_no',
55                                                       s => 'Session_id',
56                                                       v => 'Vrt_trx_id',
57                                                       x => 'Trx_id',
58                                                    );
59                                                    
60                                                    # This class's data structure is a hashref with some statefulness: pending
61                                                    # lines.  This is necessary because we sometimes don't know whether the event is
62                                                    # complete until we read the next line or even several lines, so we store these.
63                                                    #
64                                                    # Another bit of data that's stored in $self is some code to automatically
65                                                    # translate syslog into plain log format.
66                                                    sub new {
67    ***      1                    1      0      4      my ( $class ) = @_;
68             1                                 11      my $self = {
69                                                          pending    => [],
70                                                          is_syslog  => undef,
71                                                          next_event => undef,
72                                                          'tell'     => undef,
73                                                       };
74             1                                 12      return bless $self, $class;
75                                                    }
76                                                    
77                                                    # This method accepts an iterator that contains an open log filehandle.  It
78                                                    # reads events from the filehandle by calling the iterator, and returns the
79                                                    # events.
80                                                    #
81                                                    # Each event is a hashref of attribute => value pairs like:
82                                                    #  my $event = {
83                                                    #     ts  => '',    # Timestamp
84                                                    #     arg => '',    # Argument to the command
85                                                    #     other attributes...
86                                                    #  };
87                                                    #
88                                                    # The log format is ideally prefixed with the following:
89                                                    #
90                                                    #  * timestamp with microseconds
91                                                    #  * session ID, user, database
92                                                    #
93                                                    # The format I'd like to see is something like this:
94                                                    #
95                                                    # 2010-02-08 15:31:48.685 EST c=4b7074b4.985,u=user,D=database LOG:
96                                                    #
97                                                    # However, pgfouine supports user=user, db=database format.  And I think
98                                                    # it should be reasonable to grab pretty much any name=value properties out, and
99                                                    # handle them based on the lower-cased first character of $name, to match the
100                                                   # special values that are possible to give for log_line_prefix. For example, %u
101                                                   # = user, so anything starting with a 'u' should be interpreted as a user.
102                                                   #
103                                                   # In general the log format is rather flexible, and we don't know by looking at
104                                                   # any given line whether it's the last line in the event.  So we often have to
105                                                   # read a line and then decide what to do with the previous line we saw.  Thus we
106                                                   # use 'pending' when necessary but we try to do it as little as possible,
107                                                   # because it's double work to defer and re-parse lines; and we try to defer as
108                                                   # soon as possible so we don't have to do as much work.
109                                                   #
110                                                   # There are 3 categories of lines in a log file, referred to in the code as case
111                                                   # 1/2/3:
112                                                   #
113                                                   # - Those that start a possibly multi-line event
114                                                   # - Those that can continue one
115                                                   # - Those that are neither the start nor the continuation, and thus must be the
116                                                   #   end.
117                                                   #
118                                                   # In cases 1 and 3, we have to check whether information from previous lines has
119                                                   # been accumulated.  If it has, we defer the current line and create the event.
120                                                   # Otherwise we keep going, looking for more lines for the event that begins with
121                                                   # the current line.  Processing the lines is easiest if we arrange the cases in
122                                                   # this order: 2, 1, 3.
123                                                   #
124                                                   # The term "line" is to be interpreted loosely here.  Logs that are in syslog
125                                                   # format might have multi-line "lines" that are handled by the generated
126                                                   # $next_event closure and given back to the main while-loop with newlines in
127                                                   # them.  Therefore, regexes that match "the rest of the line" generally need the
128                                                   # /s flag.
129                                                   sub parse_event {
130   ***     53                   53      0   3657      my ( $self, %args ) = @_;
131           53                                350      my @required_args = qw(next_event tell);
132           53                                247      foreach my $arg ( @required_args ) {
133   ***    106     50                         806         die "I need a $arg argument" unless $args{$arg};
134                                                      }
135                                                   
136                                                      # The subroutine references that wrap the filehandle operations.
137           53                                422      my ( $next_event, $tell, $is_syslog ) = $self->generate_wrappers(%args);
138                                                   
139                                                      # These are the properties for the log event, which will later be used to
140                                                      # create an event hash ref.
141           53                                275      my @properties = ();
142                                                   
143                                                      # Holds the current line being processed, and its position in the log as a
144                                                      # byte offset from the beginning.  In some cases we'll have to reset this
145                                                      # position later.  We'll also have to take a wait-and-see attitude towards
146                                                      # the $pos_in_log, so we use $new_pos to record where we're working in the
147                                                      # log, and $pos_in_log to record where the beginning of the current event
148                                                      # started.
149           53                                309      my ($pos_in_log, $line, $was_pending) = $self->get_line();
150           53                                187      my $new_pos;
151                                                   
152                                                      # Sometimes we need to accumulate some lines and then join them together.
153                                                      # This is used for that.
154           53                                169      my @arg_lines;
155                                                   
156                                                      # This is used to signal that an entire event has been found, and thus exit
157                                                      # the while loop.
158           53                                158      my $done;
159                                                   
160                                                      # This is used to signal that an event's duration has already been found.
161                                                      # See the sample file pg-syslog-001.txt and the test for it.
162           53                                158      my $got_duration;
163                                                   
164                                                      # Before we start, we read and discard lines until we get one with a header.
165                                                      # The only thing we can really count on is that a header line should have
166                                                      # the header in it.  But, we only do this if we aren't in the middle of an
167                                                      # ongoing event, whose first line was pending.
168           53    100    100                 1289      if ( !$was_pending && (!defined $line || $line !~ m/$log_line_regex/o) ) {
      ***                   66                        
169           17                                 57         MKDEBUG && _d('Skipping lines until I find a header');
170           17                                 57         my $found_header;
171                                                         LINE:
172           17                                 68         while (
173                                                            eval {
174           20                                111               ($new_pos, $line) = $self->get_line();
175           20                                155               defined $line;
176                                                            }
177                                                         ) {
178            5    100                          52            if ( $line =~ m/$log_line_regex/o ) {
179            2                                  9               $pos_in_log = $new_pos;
180            2                                  9               last LINE;
181                                                            }
182                                                            else {
183            3                                 11               MKDEBUG && _d('Line was not a header, will fetch another');
184                                                            }
185                                                         }
186           17                                 63         MKDEBUG && _d('Found a header line, now at pos_in_line', $pos_in_log);
187                                                      }
188                                                   
189                                                      # We need to keep the line that begins the event we're parsing.
190           53                                192      my $first_line;
191                                                   
192                                                      # This is for holding the type of the log line, which is important for
193                                                      # choosing the right code to run.
194           53                                166      my $line_type;
195                                                   
196                                                      # Parse each line.
197                                                      LINE:
198           53           100                  667      while ( !$done && defined $line ) {
199                                                   
200                                                         # Throw away the newline ending.
201           97    100                         537         chomp $line unless $is_syslog;
202                                                   
203                                                         # This while loop works with LOG lines.  Other lines, such as ERROR and
204                                                         # so forth, need to be handled outside this loop.  The exception is when
205                                                         # there's nothing in progress in @arg_lines, and the non-LOG line might
206                                                         # just be something we can get relevant info from.
207           97    100    100                 1816         if ( (($line_type) = $line =~ m/$log_line_regex/o) && $line_type ne 'LOG' ) {
208                                                   
209                                                            # There's something in progress, so we abort the loop and let it be
210                                                            # handled specially.
211            5    100                          41            if ( @arg_lines ) {
212            3                                 11               MKDEBUG && _d('Found a non-LOG line, exiting loop');
213            3                                 13               last LINE;
214                                                            }
215                                                   
216                                                            # There's nothing in @arg_lines, so we save what info we can and keep
217                                                            # on going.
218                                                            else {
219            2           100                   15               $first_line ||= $line;
220                                                   
221                                                               # Handle ERROR and STATEMENT lines...
222            2    100                          45               if ( my ($e) = $line =~ m/ERROR:\s+(\S.*)\Z/s ) {
      ***            50                               
223            1                                  5                  push @properties, 'Error_msg', $e;
224            1                                  4                  MKDEBUG && _d('Found an error msg, saving and continuing');
225            1                                  6                  ($new_pos, $line) = $self->get_line();
226            1                                 16                  next LINE;
227                                                               }
228                                                   
229                                                               elsif ( my ($s) = $line =~ m/STATEMENT:\s+(\S.*)\Z/s ) {
230            1                                  8                  push @properties, 'arg', $s, 'cmd', 'Query';
231            1                                  3                  MKDEBUG && _d('Found a statement, finishing up event');
232            1                                  5                  $done = 1;
233            1                                  4                  last LINE;
234                                                               }
235                                                   
236                                                               else {
237   ***      0                                  0                  MKDEBUG && _d("I don't know what to do with this line");
238                                                               }
239                                                            }
240                                                   
241                                                         }
242                                                   
243                                                         # The log isn't just queries.  It also has status and informational lines
244                                                         # in it.  We ignore these, but if we see one that's not recognized, we
245                                                         # warn.  These types of things are better off in mk-error-log.
246           92    100                        1220         if (
247                                                            $line =~ m{
248                                                               Address\sfamily\snot\ssupported\sby\sprotocol
249                                                               |archived\stransaction\slog\sfile
250                                                               |autovacuum:\sprocessing\sdatabase
251                                                               |checkpoint\srecord\sis\sat
252                                                               |checkpoints\sare\soccurring\stoo\sfrequently\s\(
253                                                               |could\snot\sreceive\sdata\sfrom\sclient
254                                                               |database\ssystem\sis\sready
255                                                               |database\ssystem\sis\sshut\sdown
256                                                               |database\ssystem\swas\sshut\sdown
257                                                               |incomplete\sstartup\spacket
258                                                               |invalid\slength\sof\sstartup\spacket
259                                                               |next\sMultiXactId:
260                                                               |next\stransaction\sID:
261                                                               |received\ssmart\sshutdown\srequest
262                                                               |recycled\stransaction\slog\sfile
263                                                               |redo\srecord\sis\sat
264                                                               |removing\sfile\s"
265                                                               |removing\stransaction\slog\sfile\s"
266                                                               |shutting\sdown
267                                                               |transaction\sID\swrap\slimit\sis
268                                                            }x
269                                                         ) {
270                                                            # We get the next line to process and skip the rest of the loop.
271           11                                 35            MKDEBUG && _d('Skipping this line because it matches skip-pattern');
272           11                                 70            ($new_pos, $line) = $self->get_line();
273           11                                170            next LINE;
274                                                         }
275                                                   
276                                                         # Possibly reset $first_line, depending on whether it was determined to be
277                                                         # junk and unset.
278           81           100                  445         $first_line ||= $line;
279                                                   
280                                                         # Case 2: non-header lines, optionally starting with a TAB, are a
281                                                         # continuation of the previous line.
282   ***     81    100     66                 1953         if ( $line !~ m/$log_line_regex/o && @arg_lines ) {
      ***            50                               
283                                                   
284   ***     27     50                         177            if ( !$is_syslog ) {
285                                                               # We need to translate tabs to newlines.  Weirdly, some logs (see
286                                                               # samples/pg-log-005.txt) have newlines without a leading tab.
287                                                               # Maybe it's an older log format.
288           27                                194               $line =~ s/\A\t?/\n/;
289                                                            }
290                                                   
291                                                            # Save the remainder.
292           27                                130            push @arg_lines, $line;
293           27                                 80            MKDEBUG && _d('This was a continuation line');
294                                                         }
295                                                   
296                                                         # Cases 1 and 3: These lines start with some optional meta-data, and then
297                                                         # the $log_line_regex followed by the line's log message.  The message can be
298                                                         # of the form "label: text....".  Examples:
299                                                         # LOG:  duration: 1.565 ms
300                                                         # LOG:  statement: SELECT ....
301                                                         # LOG:  duration: 1.565 ms  statement: SELECT ....
302                                                         # In the above examples, the $label is duration, statement, and duration.
303                                                         elsif (
304                                                            my ( $sev, $label, $rest )
305                                                               = $line =~ m/$log_line_regex(.+?):\s+(.*)\Z/so
306                                                         ) {
307           54                                155            MKDEBUG && _d('Line is case 1 or case 3');
308                                                   
309                                                            # This is either a case 1 or case 3.  If there's previously gathered
310                                                            # data in @arg_lines, it doesn't matter which -- we have to create an
311                                                            # event (a Query event), and we're $done.  This is case 0xdeadbeef.
312           54    100                         429            if ( @arg_lines ) {
                    100                               
313           16                                 58               $done = 1;
314           16                                 47               MKDEBUG && _d('There are saved @arg_lines, we are done');
315                                                   
316                                                               # We shouldn't modify @properties based on $line, because $line
317                                                               # doesn't have anything to do with the stuff in @properties, which
318                                                               # is all related to the previous line(s).  However, there is one
319                                                               # case in which the line could be part of the event: when it's a
320                                                               # plain 'duration' line.  This happens when the statement is logged
321                                                               # on one line, and then the duration is logged afterwards.  If this
322                                                               # is true, then we alter @properties, and we do NOT defer the current
323                                                               # line.
324           16    100    100                  244               if ( $label eq 'duration' && $rest =~ m/[0-9.]+\s+\S+\Z/ ) {
325            9    100                          41                  if ( $got_duration ) {
326                                                                     # Just discard the line.
327            1                                  4                     MKDEBUG && _d('Discarding line, duration already found');
328                                                                  }
329                                                                  else {
330            8                                 51                     push @properties, 'Query_time', $self->duration_to_secs($rest);
331            8                                 33                     MKDEBUG && _d("Line's duration is for previous event:", $rest);
332                                                                  }
333                                                               }
334                                                               else {
335                                                                  # We'll come back to this line later.
336            7                                 42                  $self->pending($new_pos, $line);
337            7                                 27                  MKDEBUG && _d('Deferred line');
338                                                               }
339                                                            }
340                                                   
341                                                            # Here we test for case 1, lines that can start a multi-line event.
342                                                            elsif ( $label =~ m/\A(?:duration|statement|query)\Z/ ) {
343           26                                 80               MKDEBUG && _d('Case 1: start a multi-line event');
344                                                   
345                                                               # If it's a duration, then there might be a statement later on the
346                                                               # same line and the duration applies to that.
347           26    100                         141               if ( $label eq 'duration' ) {
348                                                   
349           12    100                         203                  if (
350                                                                     (my ($dur, $stmt)
351                                                                        = $rest =~ m/([0-9.]+ \S+)\s+(?:statement|query): *(.*)\Z/s)
352                                                                  ) {
353                                                                     # It does, so we'll pull out the Query_time etc now, rather
354                                                                     # than doing it later, when we might end up in the case above
355                                                                     # (case 0xdeadbeef).
356           11                                 85                     push @properties, 'Query_time', $self->duration_to_secs($dur);
357           11                                 45                     $got_duration = 1;
358           11                                 52                     push @arg_lines, $stmt;
359           11                                 46                     MKDEBUG && _d('Duration + statement');
360                                                                  }
361                                                   
362                                                                  else {
363                                                                     # The duration line is just junk.  It's the line after a
364                                                                     # statement, but we never saw the statement (else we'd have
365                                                                     # fallen into 0xdeadbeef above).  Discard this line and adjust
366                                                                     # pos_in_log.  See t/samples/pg-log-002.txt for an example.
367            1                                  4                     $first_line = undef;
368            1                                  6                     ($pos_in_log, $line) = $self->get_line();
369            1                                  5                     MKDEBUG && _d('Line applies to event we never saw, discarding');
370            1                                 13                     next LINE;
371                                                                  }
372                                                               }
373                                                               else {
374                                                                  # This isn't a duration line, it's a statement or query.  Put it
375                                                                  # onto @arg_lines for later and keep going.
376           14                                 65                  push @arg_lines, $rest;
377           14                                 49                  MKDEBUG && _d('Putting onto @arg_lines');
378                                                               }
379                                                            }
380                                                   
381                                                            # Here is case 3, lines that can't be in case 1 or 2.  These surely
382                                                            # terminate any event that's been accumulated, and if there isn't any
383                                                            # such, then we just create an event without the overhead of deferring.
384                                                            else {
385           12                                 60               $done = 1;
386           12                                 32               MKDEBUG && _d('Line is case 3, event is done');
387                                                   
388                                                               # Again, if there's previously gathered data in @arg_lines, we have
389                                                               # to defer the current line (not touching @properties) and revisit it.
390   ***     12     50                          51               if ( @arg_lines ) {
391   ***      0                                  0                  $self->pending($new_pos, $line);
392   ***      0                                  0                  MKDEBUG && _d('There was @arg_lines, putting line to pending');
393                                                               }
394                                                   
395                                                               # Otherwise we can parse the line and put it into @properties.
396                                                               else {
397           12                                 34                  MKDEBUG && _d('No need to defer, process event from this line now');
398           12                                 73                  push @properties, 'cmd', 'Admin', 'arg', $label;
399                                                   
400                                                                  # For some kinds of log lines, we can grab extra meta-data out of
401                                                                  # the end of the line.
402                                                                  # LOG:  connection received: host=[local]
403   ***     12     50                         108                  if ( $label =~ m/\A(?:dis)?connection(?: received| authorized)?\Z/ ) {
404           12                                 75                     push @properties, $self->get_meta($rest);
405                                                                  }
406                                                   
407                                                                  else {
408   ***      0                                  0                     die "I don't understand line $line";
409                                                                  }
410                                                   
411                                                               }
412                                                            }
413                                                   
414                                                         }
415                                                   
416                                                         # If the line isn't case 1, 2, or 3 I don't know what it is.
417                                                         else {
418   ***      0                                  0            die "I don't understand line $line";
419                                                         }
420                                                   
421                                                         # We get the next line to process.
422           80    100                         649         if ( !$done ) {
423           52                                300            ($new_pos, $line) = $self->get_line();
424                                                         }
425                                                      } # LINE
426                                                   
427                                                      # If we're at the end of the file, we finish and tell the caller we're done.
428           53    100                         308      if ( !defined $line ) {
429           21                                 62         MKDEBUG && _d('Line not defined, at EOF; calling oktorun(0) if exists');
430   ***     21     50                         130         $args{oktorun}->(0) if $args{oktorun};
431           21    100                         122         if ( !@arg_lines ) {
432           15                                 46            MKDEBUG && _d('No saved @arg_lines either, we are all done');
433           15                                168            return undef;
434                                                         }
435                                                      }
436                                                   
437                                                      # If we got kicked out of the while loop because of a non-LOG line, we handle
438                                                      # that line here.
439   ***     38    100     66                  464      if ( $line_type && $line_type ne 'LOG' ) {
440            4                                 20         MKDEBUG && _d('Line is not a LOG line');
441                                                   
442                                                         # ERROR lines come in a few flavors.  See t/samples/pg-log-006.txt,
443                                                         # t/samples/pg-syslog-002.txt, and t/samples/pg-syslog-007.txt for some
444                                                         # examples.  The rules seem to be this: if the ERROR is followed by a
445                                                         # STATEMENT, and the STATEMENT's statement matches the query in
446                                                         # @arg_lines, then the STATEMENT message is redundant.  (This can be
447                                                         # caused by various combos of configuration options in postgresql.conf).
448                                                         # However, if the ERROR's STATEMENT line doesn't match what's in
449                                                         # @arg_lines, then the ERROR actually starts a new event.  If the ERROR is
450                                                         # followed by another LOG event, then the ERROR also starts a new event.
451            4    100                          25         if ( $line_type eq 'ERROR' ) {
452            3                                 10            MKDEBUG && _d('Line is ERROR');
453                                                   
454                                                            # If there's already a statement in processing, then put aside the
455                                                            # current line, and peek ahead.
456   ***      3     50                          21            if ( @arg_lines ) {
457            3                                  9               MKDEBUG && _d('There is @arg_lines, will peek ahead one line');
458            3                                 20               my ( $temp_pos, $temp_line ) = $self->get_line();
459            3                                 17               my ( $type, $msg );
460   ***      3    100     33                  322               if (
      ***            50    100                        
      ***                   66                        
      ***                   33                        
461                                                                  defined $temp_line
462                                                                  && ( ($type, $msg) = $temp_line =~ m/$log_line_regex(.*)/o )
463                                                                  && ( $type ne 'STATEMENT' || $msg eq $arg_lines[-1] )
464                                                               ) {
465                                                                  # Looks like the whole thing is pertaining to the current event
466                                                                  # in progress.  Add the error message to the event.
467            2                                  7                  MKDEBUG && _d('Error/statement line pertain to current event');
468            2                                 25                  push @properties, 'Error_msg', $line =~ m/ERROR:\s*(\S.*)\Z/s;
469            2    100                          18                  if ( $type ne 'STATEMENT' ) {
470            1                                  3                     MKDEBUG && _d('Must save peeked line, it is a', $type);
471            1                                  7                     $self->pending($temp_pos, $temp_line);
472                                                                  }
473                                                               }
474                                                               elsif ( defined $temp_line && defined $type ) {
475                                                                  # Looks like the current and next line are about a new event.
476                                                                  # Put them into pending.
477            1                                  4                  MKDEBUG && _d('Error/statement line are a new event');
478            1                                  7                  $self->pending($new_pos, $line);
479            1                                  6                  $self->pending($temp_pos, $temp_line);
480                                                               }
481                                                               else {
482   ***      0                                  0                  MKDEBUG && _d("Unknown line", $line);
483                                                               }
484                                                            }
485                                                         }
486                                                         else {
487            1                                  5            MKDEBUG && _d("Unknown line", $line);
488                                                         }
489                                                      }
490                                                   
491                                                      # If $done is true, then some of the above code decided that the full
492                                                      # event has been found.  If we reached the end of the file, then we might
493                                                      # also have something in @arg_lines, although we didn't find the "line after"
494                                                      # that signals the event was done.  In either case we return an event.  This
495                                                      # should be the only 'return' statement in this block of code.
496   ***     38     50     66                  361      if ( $done || @arg_lines ) {
497           38                                111         MKDEBUG && _d('Making event');
498                                                   
499                                                         # Finish building the event.
500           38                                185         push @properties, 'pos_in_log', $pos_in_log;
501                                                   
502                                                         # Statement/query lines will be in @arg_lines.
503           38    100                         199         if ( @arg_lines ) {
504           25                                 73            MKDEBUG && _d('Assembling @arg_lines: ', scalar @arg_lines);
505           25                                222            push @properties, 'arg', join('', @arg_lines), 'cmd', 'Query';
506                                                         }
507                                                   
508   ***     38     50                         222         if ( $first_line ) {
509                                                            # Handle some meta-data: a timestamp, with optional milliseconds.
510           38    100                         557            if ( my ($ts) = $first_line =~ m/([0-9-]{10} [0-9:.]{8,12})/ ) {
511           31                                 91               MKDEBUG && _d('Getting timestamp', $ts);
512           31                                154               push @properties, 'ts', $ts;
513                                                            }
514                                                   
515                                                            # Find meta-data embedded in the log line prefix, in name=value format.
516   ***     38     50                         632            if ( my ($meta) = $first_line =~ m/(.*?)[A-Z]{3,}:  / ) {
517           38                                110               MKDEBUG && _d('Found a meta-data chunk:', $meta);
518           38                                232               push @properties, $self->get_meta($meta);
519                                                            }
520                                                         }
521                                                   
522                                                         # Dump info about what we've found, but don't dump $event; want to see
523                                                         # full dump of all properties, and after it's been cast into a hash,
524                                                         # duplicated keys will be gone.
525           38                                132         MKDEBUG && _d('Properties of event:', Dumper(\@properties));
526           38                                367         my $event = { @properties };
527   ***     38            50                  336         $event->{bytes} = length($event->{arg} || '');
528           38                                498         return $event;
529                                                      }
530                                                   
531                                                   }
532                                                   
533                                                   # Parses key=value meta-data from the $meta string, and returns a list of event
534                                                   # attribute names and values.
535                                                   sub get_meta {
536   ***     53                   53      0    292      my ( $self, $meta ) = @_;
537           53                                190      my @properties;
538           53                                582      foreach my $set ( $meta =~ m/(\w+=[^, ]+)/g ) {
539           93                                562         my ($key, $val) = split(/=/, $set);
540   ***     93     50     33                  969         if ( $key && $val ) {
541                                                            # The first letter of the name, lowercased, determines the
542                                                            # meaning of the item.
543   ***     93     50                         601            if ( my $prop = $attrib_name_for{lc substr($key, 0, 1)} ) {
544           93                                576               push @properties, $prop, $val;
545                                                            }
546                                                            else {
547   ***      0                                  0               MKDEBUG && _d('Bad meta key', $set);
548                                                            }
549                                                         }
550                                                         else {
551   ***      0                                  0            MKDEBUG && _d("Can't figure out meta from", $set);
552                                                         }
553                                                      }
554           53                                441      return @properties;
555                                                   }
556                                                   
557                                                   # This subroutine abstracts the process and source of getting a line of text and
558                                                   # its position in the log file.  It might get the line of text from the log; it
559                                                   # might get it from the @pending array.  It also does infinite loop checking
560                                                   # TODO.
561                                                   sub get_line {
562   ***    141                  141      0    673      my ( $self ) = @_;
563          141                                751      my ($pos, $line, $was_pending) = $self->pending;
564          141    100                         905      if ( ! defined $line ) {
565          131                                366         MKDEBUG && _d('Got nothing from pending, trying the $fh');
566          131                                562         my ( $next_event, $tell) = @{$self}{qw(next_event tell)};
             131                                737   
567          131                                493         eval {
568          131                                734            $pos  = $tell->();
569          131                               2365            $line = $next_event->();
570                                                         };
571          131                               7089         if ( MKDEBUG && $EVAL_ERROR ) {
572                                                            _d($EVAL_ERROR);
573                                                         }
574                                                      }
575                                                   
576          141                                423      MKDEBUG && _d('Got pos/line:', $pos, $line);
577          141                               1480      return ($pos, $line);
578                                                   }
579                                                   
580                                                   # This subroutine defers and retrieves a line/pos pair.  If you give it an
581                                                   # argument it'll set the stored value.  If not, it'll get one if there is one
582                                                   # and return it.
583                                                   sub pending {
584   ***    155                  155      0   1317      my ( $self, $val, $pos_in_log ) = @_;
585          155                                520      my $was_pending;
586          155                                453      MKDEBUG && _d('In sub pending, val:', $val);
587          155    100                         758      if ( $val ) {
             144    100                        1007   
588           11                                 41         push @{$self->{pending}}, [$val, $pos_in_log];
              11                                 90   
589                                                      }
590                                                      elsif ( @{$self->{pending}} ) {
591           11                                 38         ($val, $pos_in_log) = @{ shift @{$self->{pending}} };
              11                                 35   
              11                                 87   
592           11                                 59         $was_pending = 1;
593                                                      }
594          155                                521      MKDEBUG && _d('Return from pending:', $val, $pos_in_log);
595          155                               1056      return ($val, $pos_in_log, $was_pending);
596                                                   }
597                                                   
598                                                   # This subroutine manufactures subroutines to automatically translate incoming
599                                                   # syslog format into standard log format, to keep the main parse_event free from
600                                                   # having to think about that.  For documentation on how this works, see
601                                                   # SysLogParser.pm.
602                                                   sub generate_wrappers {
603   ***     53                   53      0    429      my ( $self, %args ) = @_;
604                                                   
605                                                      # Reset everything, just in case some cruft was left over from a previous use
606                                                      # of this object.  The object has stateful closures.  If this isn't done,
607                                                      # then they'll keep reading from old filehandles.  The sanity check is based
608                                                      # on the memory address of the closure!
609           53    100    100                  661      if ( ($self->{sanity} || '') ne "$args{next_event}" ){
610           15                                 44         MKDEBUG && _d("Clearing and recreating internal state");
611           15                                 52         eval { require SysLogParser; }; # Required for tests to work.
              15                                139   
612           15                                177         my $sl = new SysLogParser();
613                                                   
614                                                         # We need a special item in %args for syslog parsing.  (This might not be
615                                                         # a syslog log file...)  See the test for t/samples/pg-syslog-002.txt for
616                                                         # an example of when this is needed.
617                                                         $args{misc}->{new_event_test} = sub {
618           47                   47          5956            my ( $content ) = @_;
619   ***     47     50                         305            return unless defined $content;
620           47                                533            return $content =~ m/$log_line_regex/o;
621           15                                508         };
622                                                   
623                                                         # The TAB at the beginning of the line indicates that there's a newline
624                                                         # at the end of the previous line.
625                                                         $args{misc}->{line_filter} = sub {
626           65                   65          3323            my ( $content ) = @_;
627           65                                329            $content =~ s/\A\t/\n/;
628           65                                486            return $content;
629           15                                146         };
630                                                   
631           15                                153         @{$self}{qw(next_event tell is_syslog)} = $sl->make_closures(%args);
              15                              47933   
632           15                                 73         $self->{sanity} = "$args{next_event}";
633                                                      }
634                                                   
635                                                      # Return the wrapper functions!
636           53                                511      return @{$self}{qw(next_event tell is_syslog)};
              53                                584   
637                                                   }
638                                                   
639                                                   # This subroutine converts various formats to seconds.  Examples:
640                                                   # 10.870 ms
641                                                   sub duration_to_secs {
642   ***     22                   22      0    139      my ( $self, $str ) = @_;
643           22                                 79      MKDEBUG && _d('Duration:', $str);
644           22                                158      my ( $num, $suf ) = split(/\s+/, $str);
645           22    100                         150      my $factor = $suf eq 'ms'  ? 1000
                    100                               
646                                                                 : $suf eq 'sec' ? 1
647                                                                 :                 die("Unknown suffix '$suf'");
648           21                                227      return $num / $factor;
649                                                   }
650                                                   
651                                                   sub _d {
652            1                    1            13      my ($package, undef, $line) = caller 0;
653   ***      2     50                          19      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 18   
654            1                                  8           map { defined $_ ? $_ : 'undef' }
655                                                           @_;
656            1                                  6      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
657                                                   }
658                                                   
659                                                   1;
660                                                   
661                                                   # ###########################################################################
662                                                   # End PgLogParser package
663                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
133   ***     50      0    106   unless $args{$arg}
168          100     17     36   if (not $was_pending and !defined($line) || !($line =~ /$log_line_regex/o))
178          100      2      3   if ($line =~ /$log_line_regex/o) { }
201          100     74     23   unless $is_syslog
207          100      5     92   if (($line_type) = $line =~ /$log_line_regex/o and $line_type ne 'LOG')
211          100      3      2   if (@arg_lines) { }
222          100      1      1   if (my($e) = $line =~ /ERROR:\s+(\S.*)\Z/s) { }
      ***     50      1      0   elsif (my($s) = $line =~ /STATEMENT:\s+(\S.*)\Z/s) { }
246          100     11     81   if ($line =~ /
            Address\sfamily\snot\ssupported\sby\sprotocol
            |archived\stransaction\slog\sfile
            |autovacuum:\sprocessing\sdatabase
            |checkpoint\srecord\sis\sat
            |checkpoints\sare\soccurring\stoo\sfrequently\s\(
            |could\snot\sreceive\sdata\sfrom\sclient
            |database\ssystem\sis\sready
            |database\ssystem\sis\sshut\sdown
            |database\ssystem\swas\sshut\sdown
            |incomplete\sstartup\spacket
            |invalid\slength\sof\sstartup\spacket
            |next\sMultiXactId:
            |next\stransaction\sID:
            |received\ssmart\sshutdown\srequest
            |recycled\stransaction\slog\sfile
            |redo\srecord\sis\sat
            |removing\sfile\s"
            |removing\stransaction\slog\sfile\s"
            |shutting\sdown
            |transaction\sID\swrap\slimit\sis
         /x)
282          100     27     54   if (not $line =~ /$log_line_regex/o and @arg_lines) { }
      ***     50     54      0   elsif (my($sev, $label, $rest) = $line =~ /$log_line_regex(.+?):\s+(.*)\Z/so) { }
284   ***     50     27      0   if (not $is_syslog)
312          100     16     38   if (@arg_lines) { }
             100     26     12   elsif ($label =~ /\A(?:duration|statement|query)\Z/) { }
324          100      9      7   if ($label eq 'duration' and $rest =~ /[0-9.]+\s+\S+\Z/) { }
325          100      1      8   if ($got_duration) { }
347          100     12     14   if ($label eq 'duration') { }
349          100     11      1   if (my($dur, $stmt) = $rest =~ /([0-9.]+ \S+)\s+(?:statement|query): *(.*)\Z/s) { }
390   ***     50      0     12   if (@arg_lines) { }
403   ***     50     12      0   if ($label =~ /\A(?:dis)?connection(?: received| authorized)?\Z/) { }
422          100     52     28   if (not $done)
428          100     21     32   if (not defined $line)
430   ***     50      0     21   if $args{'oktorun'}
431          100     15      6   if (not @arg_lines)
439          100      4     34   if ($line_type and $line_type ne 'LOG')
451          100      3      1   if ($line_type eq 'ERROR') { }
456   ***     50      3      0   if (@arg_lines)
460          100      2      1   if (defined $temp_line and ($type, $msg) = $temp_line =~ /$log_line_regex(.*)/o and $type ne 'STATEMENT' || $msg eq $arg_lines[-1]) { }
      ***     50      1      0   elsif (defined $temp_line and defined $type) { }
469          100      1      1   if ($type ne 'STATEMENT')
496   ***     50     38      0   if ($done or @arg_lines)
503          100     25     13   if (@arg_lines)
508   ***     50     38      0   if ($first_line)
510          100     31      7   if (my($ts) = $first_line =~ /([0-9-]{10} [0-9:.]{8,12})/)
516   ***     50     38      0   if (my($meta) = $first_line =~ /(.*?)[A-Z]{3,}:  /)
540   ***     50     93      0   if ($key and $val) { }
543   ***     50     93      0   if (my $prop = $attrib_name_for{lc substr($key, 0, 1)}) { }
564          100    131     10   if (not defined $line)
587          100     11    144   if ($val) { }
             100     11    133   elsif (@{$$self{'pending'};}) { }
609          100     15     38   if (($$self{'sanity'} || '') ne "$args{'next_event'}")
619   ***     50      0     47   unless defined $content
645          100      5      1   $suf eq 'sec' ? :
             100     16      6   $suf eq 'ms' ? :
653   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
168   ***     66      0     36     17   not $was_pending and !defined($line) || !($line =~ /$log_line_regex/o)
198          100     28     21     97   not $done and defined $line
207          100     27     65      5   ($line_type) = $line =~ /$log_line_regex/o and $line_type ne 'LOG'
282   ***     66     54      0     27   not $line =~ /$log_line_regex/o and @arg_lines
324          100      3      4      9   $label eq 'duration' and $rest =~ /[0-9.]+\s+\S+\Z/
439   ***     66      0     34      4   $line_type and $line_type ne 'LOG'
460   ***     33      0      0      3   defined $temp_line and ($type, $msg) = $temp_line =~ /$log_line_regex(.*)/o
      ***     66      0      1      2   defined $temp_line and ($type, $msg) = $temp_line =~ /$log_line_regex(.*)/o and $type ne 'STATEMENT' || $msg eq $arg_lines[-1]
      ***     33      0      0      1   defined $temp_line and defined $type
540   ***     33      0      0     93   $key and $val

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0
219          100      1      1   $first_line ||= $line
278          100     43     38   $first_line ||= $line
527   ***     50     38      0   $$event{'arg'} || ''
609          100     52      1   $$self{'sanity'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
168          100     15      2     36   !defined($line) || !($line =~ /$log_line_regex/o)
460          100      1      1      1   $type ne 'STATEMENT' || $msg eq $arg_lines[-1]
496   ***     66     29      9      0   $done or @arg_lines


Covered Subroutines
-------------------

Subroutine        Count Pod Location                                          
----------------- ----- --- --------------------------------------------------
BEGIN                 1     /home/daniel/dev/maatkit/common/PgLogParser.pm:22 
BEGIN                 1     /home/daniel/dev/maatkit/common/PgLogParser.pm:23 
BEGIN                 1     /home/daniel/dev/maatkit/common/PgLogParser.pm:24 
BEGIN                 1     /home/daniel/dev/maatkit/common/PgLogParser.pm:25 
BEGIN                 1     /home/daniel/dev/maatkit/common/PgLogParser.pm:27 
__ANON__             47     /home/daniel/dev/maatkit/common/PgLogParser.pm:618
__ANON__             65     /home/daniel/dev/maatkit/common/PgLogParser.pm:626
_d                    1     /home/daniel/dev/maatkit/common/PgLogParser.pm:652
duration_to_secs     22   0 /home/daniel/dev/maatkit/common/PgLogParser.pm:642
generate_wrappers    53   0 /home/daniel/dev/maatkit/common/PgLogParser.pm:603
get_line            141   0 /home/daniel/dev/maatkit/common/PgLogParser.pm:562
get_meta             53   0 /home/daniel/dev/maatkit/common/PgLogParser.pm:536
new                   1   0 /home/daniel/dev/maatkit/common/PgLogParser.pm:67 
parse_event          53   0 /home/daniel/dev/maatkit/common/PgLogParser.pm:130
pending             155   0 /home/daniel/dev/maatkit/common/PgLogParser.pm:584


PgLogParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  3   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1             9   use Test::More tests => 41;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use PgLogParser;
               1                                  6   
               1                                 15   
15             1                    1            12   use SysLogParser;
               1                                  3   
               1                                 10   
16             1                    1            11   use MaatkitTest;
               1                                  3   
               1                                 40   
17                                                    
18             1                                  9   my $p = new PgLogParser;
19                                                    
20                                                    # Run some tests of duration_to_secs().
21             1                                  8   my @duration_tests = (
22                                                       ['10.870 ms'     => '0.01087'],
23                                                       ['0.084312 sec'  => '0.084312'],
24                                                    );
25             1                                  4   foreach my $test ( @duration_tests ) {
26             2                                 14      is (
27                                                          $p->duration_to_secs($test->[0]),
28                                                          $test->[1],
29                                                          "Duration for $test->[0] == $test->[1]");
30                                                    }
31                                                    
32                                                    # duration_to_secs() should not accept garbage at the end of its argument.
33                                                    throws_ok (
34                                                       sub {
35             1                    1            15         $p->duration_to_secs('duration: 1.565 ms  statement: SELECT 1');
36                                                       },
37             1                                 24      qr/Unknown suffix/,
38                                                       'duration_to_secs does not like crap at the end',
39                                                    );
40                                                    
41                                                    # Tests of 'pending'.
42             1                                 17   is($p->pending, undef, 'Nothing in pending');
43             1                                  6   is_deeply([$p->pending('foo', 1)], ['foo', 1, undef], 'Store foo in pending');
44             1                                 11   is_deeply([$p->pending], ['foo', 1, 1], 'Get foo from pending');
45             1                                 10   is($p->pending, undef, 'Nothing in pending');
46                                                    
47                                                    # Tests of 'get_meta'
48             1                                 17   my @meta = (
49                                                       ['c=4b7074b4.985,u=fred,D=jim', {
50                                                          Session_id => '4b7074b4.985',
51                                                          user       => 'fred',
52                                                          db         => 'jim',
53                                                       }],
54                                                       ['c=4b7074b4.985, user=fred, db=jim', {
55                                                          Session_id => '4b7074b4.985',
56                                                          user       => 'fred',
57                                                          db         => 'jim',
58                                                       }],
59                                                       ['c=4b7074b4.985 user=fred db=jim', {
60                                                          Session_id => '4b7074b4.985',
61                                                          user       => 'fred',
62                                                          db         => 'jim',
63                                                       }],
64                                                    );
65             1                                  5   foreach my $meta ( @meta ) {
66             3                                 31      is_deeply({$p->get_meta($meta->[0])}, $meta->[1], "Meta for $meta->[0]");
67                                                    }
68                                                    
69                                                    # A simple log of a session.
70                                                    test_log_parser(
71             1                                 48      parser => $p,
72                                                       file   => 'common/t/samples/pg-log-001.txt',
73                                                       result => [
74                                                          {  ts            => '2010-02-08 15:31:48.685',
75                                                             host          => '[local]',
76                                                             db            => '[unknown]',
77                                                             user          => '[unknown]',
78                                                             arg           => 'connection received',
79                                                             Session_id    => '4b7074b4.985',
80                                                             pos_in_log    => 0,
81                                                             bytes         => 19,
82                                                             cmd           => 'Admin',
83                                                          },
84                                                          {  ts            => '2010-02-08 15:31:48.687',
85                                                             user          => 'fred',
86                                                             db            => 'fred',
87                                                             arg           => 'connection authorized',
88                                                             Session_id    => '4b7074b4.985',
89                                                             pos_in_log    => 107,
90                                                             bytes         => 21,
91                                                             cmd           => 'Admin',
92                                                          },
93                                                          {  ts            => '2010-02-08 15:31:50.872',
94                                                             db            => 'fred',
95                                                             user          => 'fred',
96                                                             arg           => 'select 1;',
97                                                             Query_time    => '0.01087',
98                                                             Session_id    => '4b7074b4.985',
99                                                             pos_in_log    => 217,
100                                                            bytes         => length('select 1;'),
101                                                            cmd           => 'Query',
102                                                         },
103                                                         {  ts            => '2010-02-08 15:31:58.515',
104                                                            db            => 'fred',
105                                                            user          => 'fred',
106                                                            arg           => "select\n1;",
107                                                            Query_time    => '0.013918',
108                                                            Session_id    => '4b7074b4.985',
109                                                            pos_in_log    => 384,
110                                                            bytes         => length("select\n1;"),
111                                                            cmd           => 'Query',
112                                                         },
113                                                         {  ts            => '2010-02-08 15:32:06.988',
114                                                            db            => 'fred',
115                                                            user          => 'fred',
116                                                            host          => '[local]',
117                                                            arg           => 'disconnection',
118                                                            Session_id    => '4b7074b4.985',
119                                                            pos_in_log    => 552,
120                                                            bytes         => length('disconnection'),
121                                                            cmd           => 'Admin',
122                                                         },
123                                                      ],
124                                                   );
125                                                   
126                                                   # A log that has no fancy line-prefix with user/db/session info.  It also begins
127                                                   # with an entry whose header is missing.  And it ends with a line that has no
128                                                   # 'duration' line afterwards.
129            1                                 43   test_log_parser(
130                                                      parser => $p,
131                                                      file   => 'common/t/samples/pg-log-002.txt',
132                                                      result => [
133                                                         {  ts            => '2004-05-07 11:58:22',
134                                                            arg           => "SELECT groups.group_name,groups.unix_group_name,\n"
135                                                                              . "\tgroups.type_id,users.user_name,users.realname,\n"
136                                                                              . "\tnews_bytes.forum_id,news_bytes.summary,news_bytes.post_date,news_bytes.details \n"
137                                                                              . "\tFROM users,news_bytes,groups \n"
138                                                                              . "\tWHERE news_bytes.group_id='98' AND news_bytes.is_approved <> '4' \n"
139                                                                              . "\tAND users.user_id=news_bytes.submitted_by \n"
140                                                                              . "\tAND news_bytes.group_id=groups.group_id \n"
141                                                                              . "\tORDER BY post_date DESC LIMIT 10 OFFSET 0",
142                                                            pos_in_log    => 147,
143                                                            bytes         => 404,
144                                                            cmd           => 'Query',
145                                                            Query_time    => '0.00268',
146                                                         },
147                                                         {  ts            => '2004-05-07 11:58:36',
148                                                            arg           => 'begin; select getdatabaseencoding(); commit',
149                                                            cmd           => 'Query',
150                                                            pos_in_log    => 641,
151                                                            bytes         => 43,
152                                                         },
153                                                      ],
154                                                   );
155                                                   
156                                                   # A log that has no line-prefix at all.  It also has durations and statements on
157                                                   # the same line.
158            1                                 50   test_log_parser(
159                                                      parser => $p,
160                                                      file   => 'common/t/samples/pg-log-003.txt',
161                                                      result => [
162                                                         {  arg           => "SELECT * FROM users WHERE user_id='692'",
163                                                            pos_in_log    => 0,
164                                                            bytes         => 39,
165                                                            cmd           => 'Query',
166                                                            Query_time    => '0.001565',
167                                                         },
168                                                         {  arg           => "SELECT groups.group_name,groups.unix_group_name,\n"
169                                                                             . "\t\tgroups.type_id,users.user_name,users.realname,\n"
170                                                                             . "\t\tnews_bytes.forum_id,news_bytes.summary,news_bytes.post_date,news_bytes.details \n"
171                                                                             . "\t\tFROM users,news_bytes,groups \n"
172                                                                             . "\t\tWHERE news_bytes.is_approved=1 \n"
173                                                                             . "\t\tAND users.user_id=news_bytes.submitted_by \n"
174                                                                             . "\t\tAND news_bytes.group_id=groups.group_id \n"
175                                                                             . "\t\tORDER BY post_date DESC LIMIT 5 OFFSET 0",
176                                                            cmd           => 'Query',
177                                                            pos_in_log    => 77,
178                                                            bytes         => 376,
179                                                            Query_time    => '0.00164',
180                                                         },
181                                                         {  arg           => "SELECT total FROM forum_group_list_vw WHERE group_forum_id='4606'",
182                                                            pos_in_log    => 498,
183                                                            bytes         => 65,
184                                                            cmd           => 'Query',
185                                                            Query_time    => '0.000529',
186                                                         },
187                                                      ],
188                                                   );
189                                                   
190                                                   # A simple log of a session.
191            1                                 76   test_log_parser(
192                                                      parser => $p,
193                                                      file   => 'common/t/samples/pg-log-004.txt',
194                                                      result => [
195                                                         {  ts            => '2010-02-10 08:39:56.835',
196                                                            host          => '[local]',
197                                                            db            => '[unknown]',
198                                                            user          => '[unknown]',
199                                                            arg           => 'connection received',
200                                                            Session_id    => '4b72b72c.b44',
201                                                            pos_in_log    => 0,
202                                                            bytes         => 19,
203                                                            cmd           => 'Admin',
204                                                         },
205                                                         {  ts            => '2010-02-10 08:39:56.838',
206                                                            user          => 'fred',
207                                                            db            => 'fred',
208                                                            arg           => 'connection authorized',
209                                                            Session_id    => '4b72b72c.b44',
210                                                            pos_in_log    => 107,
211                                                            bytes         => 21,
212                                                            cmd           => 'Admin',
213                                                         },
214                                                         {  ts            => '2010-02-10 08:40:34.681',
215                                                            db            => 'fred',
216                                                            user          => 'fred',
217                                                            arg           => 'select 1;',
218                                                            Query_time    => '0.001308',
219                                                            Session_id    => '4b72b72c.b44',
220                                                            pos_in_log    => 217,
221                                                            bytes         => length('select 1;'),
222                                                            cmd           => 'Query',
223                                                         },
224                                                         {  ts            => '2010-02-10 08:44:31.368',
225                                                            db            => 'fred',
226                                                            user          => 'fred',
227                                                            host          => '[local]',
228                                                            arg           => 'disconnection',
229                                                            Session_id    => '4b72b72c.b44',
230                                                            pos_in_log    => 321,
231                                                            bytes         => length('disconnection'),
232                                                            cmd           => 'Admin',
233                                                         },
234                                                      ],
235                                                   );
236                                                   
237                                                   # A log that shows that continuation lines don't have to start with a TAB, and
238                                                   # not all queries must be followed by a duration.
239            1                                 65   test_log_parser(
240                                                      parser => $p,
241                                                      file   => 'common/t/samples/pg-log-005.txt',
242                                                      result => [
243                                                         {  ts            => '2004-05-07 12:00:01',
244                                                            arg           => 'begin; select getdatabaseencoding(); commit',
245                                                            pos_in_log    => 0,
246                                                            bytes         => 43,
247                                                            cmd           => 'Query',
248                                                            Query_time    => '0.000801',
249                                                         },
250                                                         {  ts            => '2004-05-07 12:00:01',
251                                                            arg           => "update users set unix_status = 'A' where user_id in (select\n"
252                                                                            . "distinct u.user_id from users u, user_group ug WHERE\n"
253                                                                            . "u.user_id=ug.user_id and ug.cvs_flags='1' and u.status='A')",
254                                                            pos_in_log    => 126,
255                                                            bytes         => 172,
256                                                            cmd           => 'Query',
257                                                         },
258                                                         {  ts            => '2004-05-07 12:00:01',
259                                                            arg           => 'SELECT 1 FROM ONLY "public"."supported_languages" x '
260                                                                              . 'WHERE "language_id" = $1 FOR UPDATE OF x',
261                                                            pos_in_log    => 332,
262                                                            bytes         => 92,
263                                                            cmd           => 'Query',
264                                                         },
265                                                      ],
266                                                   );
267                                                   
268                                                   # A log with an error.
269            1                                 59   test_log_parser(
270                                                      parser => $p,
271                                                      file   => 'common/t/samples/pg-log-006.txt',
272                                                      result => [
273                                                         {  ts            => '2004-05-07 12:01:06',
274                                                            arg           => 'SELECT plugin_id, plugin_name FROM plugins',
275                                                            pos_in_log    => 0,
276                                                            bytes         => 42,
277                                                            cmd           => 'Query',
278                                                            Query_time    => '0.002161',
279                                                         },
280                                                         {  ts            => '2004-05-07 12:01:06',
281                                                            arg           => "SELECT \n\t\t\t\tgroups.type,\n"
282                                                                              . "\t\t\t\tnews_bytes.details \n"
283                                                                              . "\t\t\tFROM \n"
284                                                                              . "\t\t\t\tnews_bytes,\n"
285                                                                              . "\t\t\t\tgroups \n"
286                                                                              . "\t\t\tWHERE \n"
287                                                                              . "\t\t\t\tnews_bytes.group_id=groups.group_id \n"
288                                                                              . "\t\t\tORDER BY \n"
289                                                                              . "\t\t\t\tdate \n"
290                                                                              . "\t\t\tDESC LIMIT 30 OFFSET 0",
291                                                            pos_in_log    => 125,
292                                                            bytes         => 185,
293                                                            cmd           => 'Query',
294                                                            Error_msg     => 'No such attribute groups.type',
295                                                         },
296                                                         {  ts            => '2004-05-07 12:01:06',
297                                                            arg           => 'SELECT plugin_id, plugin_name FROM plugins',
298                                                            pos_in_log    => 412,
299                                                            bytes         => 42,
300                                                            cmd           => 'Query',
301                                                            Query_time    => '0.002161',
302                                                         },
303                                                      ],
304                                                   );
305                                                   
306                                                   # A log with informational messages.
307            1                                 58   test_log_parser(
308                                                      parser => $p,
309                                                      file   => 'common/t/samples/pg-log-007.txt',
310                                                      result => [
311                                                         {  arg           => 'SELECT plugin_id, plugin_name FROM plugins',
312                                                            pos_in_log    => 20,
313                                                            bytes         => 42,
314                                                            cmd           => 'Query',
315                                                            Query_time    => '0.002991',
316                                                         },
317                                                      ],
318                                                   );
319                                                   
320                                                   # Test that meta-data in connection/disconnnection lines is captured.
321            1                                 71   test_log_parser(
322                                                      parser => $p,
323                                                      file   => 'common/t/samples/pg-log-008.txt',
324                                                      result => [
325                                                         {  ts            => '2010-02-08 15:31:48',
326                                                            host          => '[local]',
327                                                            arg           => 'connection received',
328                                                            pos_in_log    => 0,
329                                                            bytes         => 19,
330                                                            cmd           => 'Admin',
331                                                         },
332                                                         {  ts            => '2010-02-08 15:31:48',
333                                                            user          => 'fred',
334                                                            db            => 'fred',
335                                                            arg           => 'connection authorized',
336                                                            pos_in_log    => 64,
337                                                            bytes         => 21,
338                                                            cmd           => 'Admin',
339                                                         },
340                                                         {  ts            => '2010-02-08 15:32:06',
341                                                            db            => 'fred',
342                                                            user          => 'fred',
343                                                            host          => '[local]',
344                                                            arg           => 'disconnection',
345                                                            pos_in_log    => 141,
346                                                            bytes         => length('disconnection'),
347                                                            cmd           => 'Admin',
348                                                         },
349                                                      ],
350                                                   );
351                                                   
352                                                   # Simple sample of syslog output.  It has a complexity: there is a trailing
353                                                   # orphaned duration line, which can appear to be for the statement -- but isn't.
354            1                                 69   test_log_parser(
355                                                      parser => $p,
356                                                      file   => 'common/t/samples/pg-syslog-001.txt',
357                                                      result => [
358                                                         {  pos_in_log    => 0,
359                                                            bytes         => 1193,
360                                                            cmd           => 'Query',
361                                                            Query_time    => '3.617465',
362                                                            arg           => "select t.tid,t.title,m.name,gn.name,to_char( t.retail_reldate, 'mm-dd-yy' ) as retail_reldate,coalesce(s0c100r0.units,0) as"
363                                                                              ." w0c100r0units,'NA' as w0c100r0dollars,'NA' as w0c100r0arp,coalesce(s0c1r0.units,0) as w0c1r0units,'NA' as w0c1r0dollars,'NA' as"
364                                                                              ." w0c1r0arp,coalesce(s0c2r0.units,0) as w0c2r0units,coalesce(s0c2r0.dollars,0) as w0c2r0dollars,arp(s0c2r0.dollars, s0c2r0.units)"
365                                                                              ." as w0c2r0arp from title t left outer join sublabel sl on t.sublabel_rel = sl.key left outer join label s on sl.lid = s.id left"
366                                                                              ." outer join label d on s.did = d.id left outer join sale_200601 s0c100r0 on t.tid = s0c100r0.tid and s0c100r0.week = 200601 and"
367                                                                              ." s0c100r0.channel = 100 and s0c100r0.region = 0 left outer join sale_200601 s0c1r0 on t.tid = s0c1r0.tid and s0c1r0.week ="
368                                                                              ." 200601 and s0c1r0.channel = 1 and s0c1r0.region = 0 left outer join sale_200601 s0c2r0 on t.tid = s0c2r0.tid and s0c2r0.week ="
369                                                                              ." 200601 and s0c2r0.channel = 2 and s0c2r0.region = 0 left outer join media m on t.media = m.key left outer join genre_n gn on"
370                                                                              ." t.genre_n = gn.key where ((((upper(t.title) like '%MATRIX%' or upper(t.artist) like '%MATRIX%') ))) and t.blob in ('L', 'M',"
371                                                                              ." 'R') and t.source_dvd != 'IN' order by t.title asc limit 100",
372                                                         },
373                                                      ],
374                                                   );
375                                                   
376                                                   # Syslog output with a query that has an error.
377            1                                 70   test_log_parser(
378                                                      parser => $p,
379                                                      file   => 'common/t/samples/pg-syslog-002.txt',
380                                                      result => [
381                                                         {  ts            => '2010-02-08 09:52:41.526',
382                                                            pos_in_log    => 0,
383                                                            bytes         => 31,
384                                                            cmd           => 'Query',
385                                                            Query_time    => '0.008309',
386                                                            arg           => "select * from pg_stat_bgwriter;",
387                                                            db            => 'fred',
388                                                            user          => 'fred',
389                                                            Session_id    => '4b701056.1dc6',
390                                                         },
391                                                         {  ts            => '2010-02-08 09:52:57.807',
392                                                            pos_in_log    => 282,
393                                                            bytes         => 29,
394                                                            cmd           => 'Query',
395                                                            arg           => "create index ix_a on foo (a);",
396                                                            Error_msg     => 'relation "ix_a" already exists',
397                                                            db            => 'fred',
398                                                            user          => 'fred',
399                                                            Session_id    => '4b701056.1dc6',
400                                                         },
401                                                      ],
402                                                   );
403                                                   
404                                                   # Syslog output with a query that has newlines *and* a query line that's too
405                                                   # long and is broken across 2 lines in the log.
406            1                                 75   test_log_parser(
407                                                      parser => $p,
408                                                      file   => 'common/t/samples/pg-syslog-003.txt',
409                                                      result => [
410                                                         {  ts            => '2010-02-08 09:53:51.724',
411                                                            pos_in_log    => 0,
412                                                            bytes         => 526,
413                                                            cmd           => 'Query',
414                                                            Query_time    => '0.150472',
415                                                            arg           => "SELECT n.nspname as \"Schema\","
416                                                                            . "\n  c.relname as \"Name\","
417                                                                            . "\n  CASE c.relkind WHEN 'r' THEN 'table' WHEN 'v' THEN 'view' WHEN 'i' THEN 'index' WHEN 'S' THEN 'sequence' WHEN 's' THEN"
418                                                                            . " 'special' END as \"Type\","
419                                                                            . "\n  r.rolname as \"Owner\""
420                                                                            . "\nFROM pg_catalog.pg_class c"
421                                                                            . "\n     JOIN pg_catalog.pg_roles r ON r.oid = c.relowner"
422                                                                            . "\n     LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace"
423                                                                            . "\nWHERE c.relkind IN ('r','v','S','')"
424                                                                            . "\n  AND n.nspname <> 'pg_catalog'"
425                                                                            . "\n  AND n.nspname !~ '^pg_toast'"
426                                                                            . "\n  AND pg_catalog.pg_table_is_visible(c.oid)"
427                                                                            . "\nORDER BY 1,2;",
428                                                            db            => 'fred',
429                                                            user          => 'fred',
430                                                            Session_id    => '4b701056.1dc6',
431                                                         },
432                                                      ],
433                                                   );
434                                                   
435                                                   # Syslog output with a query that has newlines with tabs translated to ^I
436                                                   # characters.
437            1                                 52   test_log_parser(
438                                                      parser => $p,
439                                                      file   => 'common/t/samples/pg-syslog-004.txt',
440                                                      result => [
441                                                         {  pos_in_log    => 0,
442                                                            bytes         => 357,
443                                                            cmd           => 'Query',
444                                                            arg           => "SELECT groups.group_name,groups.unix_group_name,"
445                                                                           . "\n\tgroups.type,users.user_name,users.realname,"
446                                                                           . "\n\tnews_bytes.forum_id,news_bytes.summary,news_bytes.date,news_bytes.details "
447                                                                           . "\n\tFROM users,news_bytes,groups "
448                                                                           . "\n\tWHERE news_bytes.is_approved=1 "
449                                                                           . "\n\tAND users.user_id=news_bytes.submitted_by "
450                                                                           . "\n\tAND news_bytes.group_id=groups.group_id "
451                                                                           . "\n\tORDER BY date DESC LIMIT 10 OFFSET 0",
452                                                         },
453                                                      ],
454                                                   );
455                                                   
456                                                   # This is basically the same as common/t/samples/pg-log-001.txt but it's in
457                                                   # syslog format.  It's interesting and complicated because the disconnect
458                                                   # message is broken across two lines in the file by syslog, although this would
459                                                   # not be done in PostgreSQL's own logging format.
460            1                                123   test_log_parser(
461                                                      parser => $p,
462                                                      file   => 'common/t/samples/pg-syslog-005.txt',
463                                                      result => [
464                                                         {  ts            => '2010-02-10 09:03:26.918',
465                                                            host          => '[local]',
466                                                            db            => '[unknown]',
467                                                            user          => '[unknown]',
468                                                            arg           => 'connection received',
469                                                            Session_id    => '4b72bcae.d01',
470                                                            pos_in_log    => 0,
471                                                            bytes         => 19,
472                                                            cmd           => 'Admin',
473                                                         },
474                                                         {  ts            => '2010-02-10 09:03:26.922',
475                                                            user          => 'fred',
476                                                            db            => 'fred',
477                                                            arg           => 'connection authorized',
478                                                            Session_id    => '4b72bcae.d01',
479                                                            pos_in_log    => 152,
480                                                            bytes         => 21,
481                                                            cmd           => 'Admin',
482                                                         },
483                                                         {  ts            => '2010-02-10 09:03:36.645',
484                                                            db            => 'fred',
485                                                            user          => 'fred',
486                                                            arg           => 'select 1;',
487                                                            Query_time    => '0.000627',
488                                                            Session_id    => '4b72bcae.d01',
489                                                            pos_in_log    => 307,
490                                                            bytes         => length('select 1;'),
491                                                            cmd           => 'Query',
492                                                         },
493                                                         {  ts            => '2010-02-10 09:03:39.075',
494                                                            db            => 'fred',
495                                                            user          => 'fred',
496                                                            host          => '[local]',
497                                                            arg           => 'disconnection',
498                                                            Session_id    => '4b72bcae.d01',
499                                                            pos_in_log    => 456,
500                                                            bytes         => length('disconnection'),
501                                                            cmd           => 'Admin',
502                                                         },
503                                                      ],
504                                                   );
505                                                   
506                                                   # This is interesting because it has a mix of lines that are genuinely broken
507                                                   # with a newline, and thus start with ^I; and lines that are broken by syslog
508                                                   # for being too long.  It has a line that's just too long and is broken in a
509                                                   # place there's no space, which is unusual.  It also starts and ends with a
510                                                   # newline, so it's a good test of whether chomping/trimming is done right.
511            1                                 68   test_log_parser(
512                                                      parser => $p,
513                                                      file   => 'common/t/samples/pg-syslog-006.txt',
514                                                      result => [
515                                                         {  pos_in_log    => 0,
516                                                            bytes         => 657,
517                                                            cmd           => 'Query',
518                                                            Query_time    => '0.117042',
519                                                            arg           => "\ninsert into weblog"
520                                                                           . " (username,remoteid,generalsitearea,refererhost,refererfull,searchterms,cookie,useragent,query,requesteduri,bot,elapsedtime)"
521                                                                           . "\nvalues"
522                                                                           . " (upper('asdfg'),upper('127.0.0.1'),upper(NULL),upper('localhost'),upper('<a href=\"http://localhost/nosymbol-Ameriprise-Financial-Inc-Fun\" target=\"_new\">http://localhost/nosymbol-Ameriprise-Financial-Inc-Fun</a>"
523                                                                           . "d-Buy-Sell-Own-zz-zi125340.html'),upper(NULL),upper('temp-id=s2ByrI6TKLEoDJXG3g3NEBoRWF6Z3t'),upper('Mozilla/4.0 (compatible;"
524                                                                           . " MSIE 7.0; Windows NT 5.2; .NET CLR 1.1.4322; .NET CLR 2.0.50727; .NET CLR"
525                                                                           . " 3.0.04506.30)'),upper(''),upper('/AAON-Aaon-Inc-Stock-Buy-Sell-Own-zz-zs2331501.html'),'f','1')"
526                                                                           . "\n"
527                                                         },
528                                                      ],
529                                                   );
530                                                   
531                                                   # This file has a few different things in it: embedded newline in a string, long
532                                                   # non-broken strings, ERROR line that doesn't describe the previous line but
533                                                   # rather is followed by a STATEMENT line.
534            1                                 93   test_log_parser(
535                                                      parser => $p,
536                                                      file   => 'common/t/samples/pg-syslog-007.txt',
537                                                      result => [
538                                                         {  Query_time => '0.039219',
539                                                            Session_id => '12345',
540                                                            arg =>
541                                                               "select 'a very long sentence a very long sentence a very long "
542                                                               . "sentence a very long sentence a very long sentence a very "
543                                                               . "long sentence a very long sentence ;\n';",
544                                                            bytes      => 159,
545                                                            cmd        => 'Query',
546                                                            db         => 'fred',
547                                                            pos_in_log => 0,
548                                                            ts         => '2010-02-12 06:00:54.566',
549                                                            user       => 'fred'
550                                                         },
551                                                         {  Query_time => '0.000589',
552                                                            Session_id => '12345',
553                                                            arg =>
554                                                               "select 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
555                                                               . "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
556                                                               . "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
557                                                               . "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
558                                                               . "aaaaaaaaaaaaaaaaaaaaaaaa';",
559                                                            bytes      => 280,
560                                                            cmd        => 'Query',
561                                                            db         => 'fred',
562                                                            pos_in_log => '388',
563                                                            ts         => '2010-02-12 06:01:09.854',
564                                                            user       => 'fred',
565                                                         },
566                                                         {
567                                                            Query_time => '0.000556',
568                                                            Session_id => '12345',
569                                                            arg        => "select '\nhello';",
570                                                            bytes      => 16,
571                                                            cmd        => 'Query',
572                                                            db         => 'fred',
573                                                            pos_in_log => '939',
574                                                            ts         => '2010-02-12 06:01:22.860',
575                                                            user       => 'fred'
576                                                         },
577                                                         {  Error_msg  => 'unrecognized configuration parameter "foobar"',
578                                                            Session_id => '12345',
579                                                            arg        => "show foobar;",
580                                                            bytes      => length('show foobar;'),
581                                                            cmd        => 'Query',
582                                                            db         => 'fred',
583                                                            pos_in_log => '1139',
584                                                            ts         => '2010-02-12 06:03:14.307',
585                                                            user       => 'fred',
586                                                         },
587                                                      ],
588                                                   );
589                                                   
590                                                   # #############################################################################
591                                                   # Done.
592                                                   # #############################################################################
593            1                                 55   my $output = '';
594                                                   {
595            1                                  5      local *STDERR;
               1                                 12   
596            1                    1             4      open STDERR, '>', \$output;
               1                                527   
               1                                  4   
               1                                 13   
597            1                                 33      $p->_d('Complete test coverage');
598                                                   }
599                                                   like(
600            1                                 25      $output,
601                                                      qr/Complete test coverage/,
602                                                      '_d() works'
603                                                   );
604            1                                  4   exit;


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
---------- ----- -----------------
BEGIN          1 PgLogParser.t:10 
BEGIN          1 PgLogParser.t:11 
BEGIN          1 PgLogParser.t:12 
BEGIN          1 PgLogParser.t:14 
BEGIN          1 PgLogParser.t:15 
BEGIN          1 PgLogParser.t:16 
BEGIN          1 PgLogParser.t:4  
BEGIN          1 PgLogParser.t:596
BEGIN          1 PgLogParser.t:9  
__ANON__       1 PgLogParser.t:35 


