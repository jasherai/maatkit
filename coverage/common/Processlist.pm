---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/Processlist.pm   89.8   84.4   58.8   84.2    0.0   89.7   77.9
Processlist.t                 100.0   75.0   33.3  100.0    n/a   10.3   97.7
Total                          93.7   83.8   58.1   92.5    0.0  100.0   83.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:44 2010
Finish:       Thu Jun 24 19:35:44 2010

Run:          Processlist.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:45 2010
Finish:       Thu Jun 24 19:35:45 2010

/home/daniel/dev/maatkit/common/Processlist.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2009 Baron Schwartz.
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
18                                                    # Processlist package $Revision: 6187 $
19                                                    # ###########################################################################
20                                                    package Processlist;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  8   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  5   
               1                                  9   
25                                                    
26             1                    1             6   use Data::Dumper;
               1                                  3   
               1                                  6   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 14   
32                                                    use constant {
33             1                                 12      ID      => 0,
34                                                       USER    => 1,
35                                                       HOST    => 2,
36                                                       DB      => 3,
37                                                       COMMAND => 4,
38                                                       TIME    => 5,
39                                                       STATE   => 6,
40                                                       INFO    => 7,
41                                                       START   => 8, # Calculated start time of statement
42                                                       ETIME   => 9, # Exec time of SHOW PROCESSLIST (margin of error in START)
43                                                       FSEEN   => 10, # First time ever seen
44             1                    1             6   };
               1                                  2   
45                                                    
46                                                    # Arugments:
47                                                    #   * MasterSlave  ojb: used to find, skip replication threads
48                                                    sub new {
49    ***      3                    3      0     17      my ( $class, %args ) = @_;
50             3                                 11      foreach my $arg ( qw(MasterSlave) ) {
51    ***      3     50                          18         die "I need a $arg argument" unless $args{$arg};
52                                                       }
53             3                                 30      my $self = {
54                                                          %args,
55                                                          prev_rows => [],
56                                                          new_rows  => [],
57                                                          curr_row  => undef,
58                                                          prev_row  => undef,
59                                                       };
60             3                                 24      return bless $self, $class;
61                                                    }
62                                                    
63                                                    # This method accepts a $code coderef, which is typically going to return SHOW
64                                                    # FULL PROCESSLIST, and an array of callbacks.  The $code coderef can be any
65                                                    # subroutine that can return an array of arrayrefs that have the same structure
66                                                    # as SHOW FULL PRCESSLIST (see the defined constants above).  When it sees a
67                                                    # query complete, it turns the query into an "event" and calls the callbacks
68                                                    # with it.  It may find more than one event per call.  It also expects a $misc
69                                                    # hashref, which it will use to maintain state in the caller's namespace across
70                                                    # calls.  It expects this hashref to have the following:
71                                                    #
72                                                    #  my $misc = { prev => [], time => time(), etime => ? };
73                                                    #
74                                                    # Where etime is how long SHOW FULL PROCESSLIST took to execute.
75                                                    #
76                                                    # Each event is a hashref of attribute => value pairs like:
77                                                    #
78                                                    #  my $event = {
79                                                    #     ts  => '',    # Timestamp
80                                                    #     id  => '',    # Connection ID
81                                                    #     arg => '',    # Argument to the command
82                                                    #     other attributes...
83                                                    #  };
84                                                    #
85                                                    # Returns the number of events it finds.
86                                                    #
87                                                    # Technical details: keeps the previous run's processes in an array, gets the
88                                                    # current processes, and iterates through them, comparing prev and curr.  There
89                                                    # are several cases:
90                                                    #
91                                                    # 1) Connection is in curr, not in prev.  This is a new connection.  Calculate
92                                                    #    the time at which the statement must have started to execute.  Save this as
93                                                    #    a property of the event.
94                                                    # 2) Connection is in curr and prev, and the statement is the same, and the
95                                                    #    current time minus the start time of the event in prev matches the Time
96                                                    #    column of the curr.  This is the same statement we saw last time we looked
97                                                    #    at this connection, so do nothing.
98                                                    # 3) Same as 2) but the Info is different.  Then sometime between the prev
99                                                    #    and curr snapshots, that statement finished.  Assume it finished
100                                                   #    immediately after we saw it last time.  Fire the event handlers.
101                                                   #    TODO: if the statement is now running something else or Sleep for a certain
102                                                   #    time, then that shows the max end time of the last statement.  If it's 10s
103                                                   #    later and it's now been Sleep for 8s, then it might have ended up to 8s
104                                                   #    ago.
105                                                   # 4) Connection went away, or Info went NULL.  Same as 3).
106                                                   #
107                                                   # The default MySQL server has one-second granularity in the Time column.  This
108                                                   # means that a statement that starts at X.9 seconds shows 0 seconds for only 0.1
109                                                   # second.  A statement that starts at X.0 seconds shows 0 secs for a second, and
110                                                   # 1 second up until it has actually been running 2 seconds.  This makes it
111                                                   # tricky to determine when a statement has been re-issued.  Further, this
112                                                   # program and MySQL may have some clock skew.  Even if they are running on the
113                                                   # same machine, it's possible that at X.999999 seconds we get the time, and at
114                                                   # X+1.000001 seconds we get the snapshot from MySQL.  (Fortunately MySQL doesn't
115                                                   # re-evaluate now() for every process, or that would cause even more problems.)
116                                                   # And a query that's issued to MySQL may stall for any amount of time before
117                                                   # it's executed, making even more skew between the times.
118                                                   #
119                                                   # As a result of all this, this program assumes that the time it is passed in
120                                                   # $misc is measured consistently *after* calling SHOW PROCESSLIST, and is
121                                                   # measured with high precision (not second-level precision, which would
122                                                   # introduce an extra second of possible error in each direction).  That is a
123                                                   # convention that's up to the caller to follow.  One worst case is this:
124                                                   #
125                                                   #  * The processlist measures time at 100.01 and it's 100.
126                                                   #  * We measure the time.  It says 100.02.
127                                                   #  * A query was started at 90.  Processlist says Time=10.
128                                                   #  * We calculate that the query was started at 90.02.
129                                                   #  * Processlist measures it at 100.998 and it's 100.
130                                                   #  * We measure time again, it says 100.999.
131                                                   #  * Time has passed, but the Time column still says 10.
132                                                   #
133                                                   # Another:
134                                                   #
135                                                   #  * We get the processlist, then the time.
136                                                   #  * A second later we get the processlist, but it takes 2 sec to fetch.
137                                                   #  * We measure the time and it looks like 3 sec have passed, but ps says only
138                                                   #    one has passed.  (This is why $misc->{etime} is necessary).
139                                                   #
140                                                   # What should we do?  Well, the key thing to notice here is that a new statement
141                                                   # has started if a) the Time column actually decreases since we last saw the
142                                                   # process, or b) the Time column does not increase for 2 seconds, plus the etime
143                                                   # of the first and second measurements combined!
144                                                   #
145                                                   # The $code shouldn't return itself, e.g. if it's a PROCESSLIST you should
146                                                   # filter out $dbh->{mysql_thread_id}.
147                                                   #
148                                                   # TODO: unresolved issues are
149                                                   # 1) What about Lock_time?  It's unclear if a query starts at 100, unlocks at
150                                                   #    105 and completes at 110, is it 5s lock and 5s exec?  Or 5s lock, 10s exec?
151                                                   #    This code should match that behavior.
152                                                   # 2) What about splitting the difference?  If I see a query now with 0s, and one
153                                                   #    second later I look and see it's gone, should I split the middle and say it
154                                                   #    ran for .5s?
155                                                   # 3) I think user/host needs to do user/host/ip, really.  And actually, port
156                                                   #    will show up in the processlist -- make that a property too.
157                                                   # 4) It should put cmd => Query, cmd => Admin, or whatever
158                                                   sub parse_event {
159   ***     12                   12      0     55      my ( $self, %args ) = @_;
160           12                                 44      my @required_args = qw(misc);
161           12                                 39      foreach my $arg ( @required_args ) {
162   ***     12     50                          65         die "I need a $arg argument" unless $args{$arg};
163                                                      }
164           12                                 46      my ($misc) = @args{@required_args};
165                                                   
166                                                      # The code callback should return an arrayref of events from the proclist.
167           12                                 41      my $code = $misc->{code};
168   ***     12     50                          43      die "I need a code arg to misc" unless $code;
169                                                   
170                                                      # If there are current rows from the last time we were called, continue
171                                                      # using/parsing them.  Else, try to get new rows from $code.  Else, the
172                                                      # proecesslist is probably empty so do nothing.
173           12                                 27      my @curr;
174   ***     12     50                          49      if ( $self->{curr_rows} ) {
175   ***      0                                  0         MKDEBUG && _d('Current rows from last call');
176   ***      0                                  0         @curr = @{$self->{curr_rows}};
      ***      0                                  0   
177                                                      }
178                                                      else {
179           12                                 39         my $rows = $code->();
180           12    100    100                   87         if ( $rows && scalar @$rows ) {
181            8                                 18            MKDEBUG && _d('Got new current rows');
182            8                                 47            @curr = sort { $a->[ID] <=> $b->[ID] } @$rows;
      ***      0                                  0   
183                                                         }
184                                                         else {
185            4                                 11            MKDEBUG && _d('No current rows');
186                                                         }
187                                                      }
188                                                   
189   ***     12            50                   31      my @prev = @{$self->{prev_rows} ||= []};
              12                                 63   
190   ***     12            50                   36      my @new  = @{$self->{new_rows}  ||= []};; # Becomes next invocation's @prev
              12                                 57   
191           12                                 41      my $curr = $self->{curr_row}; # Rows from each source
192           12                                 36      my $prev = $self->{prev_row};
193           12                                 27      my $event;
194                                                   
195           12                                 27      MKDEBUG && _d('Rows:', scalar @prev, 'prev,', scalar @curr, 'current');
196                                                   
197           12    100    100                   96      if ( !$curr && @curr ) {
198            8                                 16         MKDEBUG && _d('Fetching row from curr');
199            8                                 25         $curr = shift @curr;
200                                                      }
201   ***     12    100     66                   90      if ( !$prev && @prev ) {
202            4                                  8         MKDEBUG && _d('Fetching row from prev');
203            4                                 13         $prev = shift @prev;
204                                                      }
205   ***     12    100     66                   68      if ( $curr || $prev ) {
206                                                         # In each of the if/elses, something must be undef'ed to prevent
207                                                         # infinite looping.
208   ***      9    100     66                  169         if ( $curr && $prev && $curr->[ID] == $prev->[ID] ) {
                    100    100                        
      ***                   66                        
      ***                   66                        
      ***                   66                        
209            3                                  7            MKDEBUG && _d('$curr and $prev are the same cxn');
210                                                            # Or, if its start time seems to be after the start time of
211                                                            # the previously seen one, it's also a new query.
212   ***      3     50                          22            my $fudge = $curr->[TIME] =~ m/\D/ ? 0.001 : 1; # Micro-precision?
213            3                                  7            my $is_new = 0;
214   ***      3     50                          15            if ( $prev->[INFO] ) {
215   ***      3    100     66                   86               if (!$curr->[INFO] || $prev->[INFO] ne $curr->[INFO]) {
      ***            50     33                        
      ***           100     33                        
      ***                   66                        
216                                                                  # This is a different query or a new query
217            1                                  2                  MKDEBUG && _d('$curr has a new query');
218            1                                  3                  $is_new = 1;
219                                                               }
220                                                               elsif (defined $curr->[TIME] && $curr->[TIME] < $prev->[TIME]) {
221   ***      0                                  0                  MKDEBUG && _d('$curr time is less than $prev time');
222   ***      0                                  0                  $is_new = 1;
223                                                               }
224                                                               elsif ( $curr->[INFO] && defined $curr->[TIME]
225                                                                       && $misc->{time} - $curr->[TIME] - $prev->[START]
226                                                                          - $prev->[ETIME] - $misc->{etime} > $fudge
227                                                               ) {
228            1                                  2                  MKDEBUG && _d('$curr has same query that restarted');
229            1                                  3                  $is_new = 1;
230                                                               }
231            3    100                          17               if ( $is_new ) {
232            2                                  9                  $event = $self->make_event($prev, $misc->{time});
233                                                               }
234                                                            }
235            3    100                          13            if ( $curr->[INFO] ) {
236   ***      2    100     66                   18               if ( $prev->[INFO] && !$is_new ) {
237            1                                  3                  MKDEBUG && _d('Pushing old history item back onto $prev');
238            1                                  6                  push @new, [ @$prev ];
239                                                               }
240                                                               else {
241            1                                  2                  MKDEBUG && _d('Pushing new history item onto $prev');
242            1                                 16                  push @new,
243                                                                     [ @$curr, int($misc->{time} - $curr->[TIME]),
244                                                                        $misc->{etime}, $misc->{time} ];
245                                                               }
246                                                            }
247            3                                 10            $curr = $prev = undef; # Fetch another from each.
248                                                         }
249                                                         # The row in the prev doesn't exist in the curr.  Fire an event.
250                                                         elsif ( !$curr
251                                                                 || ($curr && $prev && $curr->[ID] > $prev->[ID]) ) {
252            1                                  3            MKDEBUG && _d('$curr is not in $prev');
253            1                                  6            $event = $self->make_event($prev, $misc->{time});
254            1                                  3            $prev = undef;
255                                                         }
256                                                         # The row in curr isn't in prev; start a new event.
257                                                         else { # This else must be entered, to prevent infinite loops.
258            5                                 13            MKDEBUG && _d('$prev is not in $curr');
259   ***      5    100     66                   51            if ( $curr->[INFO] && defined $curr->[TIME] ) {
260            3                                  7               MKDEBUG && _d('Pushing new history item onto $prev');
261            3                                 34               push @new,
262                                                                  [ @$curr, int($misc->{time} - $curr->[TIME]),
263                                                                     $misc->{etime}, $misc->{time} ];
264                                                            }
265            5                                 15            $curr = undef; # No infinite loops.
266                                                         }
267                                                      }
268                                                   
269           12                                 52      $self->{prev_rows} = \@new;
270           12                                 48      $self->{prev_row}  = $prev;
271   ***     12     50                          50      $self->{curr_rows} = scalar @curr ? \@curr : undef;
272           12                                 37      $self->{curr_row}  = $curr;
273                                                   
274           12                                 57      return $event;
275                                                   }
276                                                   
277                                                   # The exec time of the query is the max of the time from the processlist, or the
278                                                   # time during which we've actually observed the query running.  In case two
279                                                   # back-to-back queries executed as the same one and we weren't able to tell them
280                                                   # apart, their time will add up, which is kind of what we want.
281                                                   sub make_event {
282   ***      3                    3      0     14      my ( $self, $row, $time ) = @_;
283            3                                 11      my $Query_time = $row->[TIME];
284            3    100                          19      if ( $row->[TIME] < $time - $row->[FSEEN] ) {
285            1                                  4         $Query_time = $time - $row->[FSEEN];
286                                                      }
287            3                                 33      my $event = {
288                                                         id         => $row->[ID],
289                                                         db         => $row->[DB],
290                                                         user       => $row->[USER],
291                                                         host       => $row->[HOST],
292                                                         arg        => $row->[INFO],
293                                                         bytes      => length($row->[INFO]),
294                                                         ts         => Transformers::ts($row->[START] + $row->[TIME]), # Query END time
295                                                         Query_time => $Query_time,
296                                                         Lock_time  => 0,               # TODO
297                                                      };
298            3                                166      MKDEBUG && _d('Properties of event:', Dumper($event));
299            3                                 12      return $event;
300                                                   }
301                                                   
302                                                   sub _get_rows {
303            8                    8            32      my ( $self ) = @_;
304            8                                 34      my %rows = map { $_ => $self->{$_} }
              32                                150   
305                                                         qw(prev_rows new_rows curr_row prev_row);
306            8                                 71      return \%rows;
307                                                   }
308                                                   
309                                                   # Accepts a PROCESSLIST and a specification of filters to use against it.
310                                                   # Returns queries that match the filters.  The standard process properties
311                                                   # are: Id, User, Host, db, Command, Time, State, Info.  These are used for
312                                                   # ignore and match.
313                                                   #
314                                                   # Possible find_spec are:
315                                                   #   * only_oldest  Match the oldest running query
316                                                   #   * busy_time    Match queries that have been Command=Query for longer than
317                                                   #                  this time
318                                                   #   * idle_time    Match queries that have been Command=Sleep for longer than
319                                                   #                  this time
320                                                   #   * ignore       A hashref of properties => regex patterns to ignore
321                                                   #   * match        A hashref of properties => regex patterns to match
322                                                   #
323                                                   sub find {
324   ***      7                    7      0   9523      my ( $self, $proclist, %find_spec ) = @_;
325            7                                 19      MKDEBUG && _d('find specs:', Dumper(\%find_spec));
326            7                                 37      my $ms  = $self->{MasterSlave};
327            7                                 20      my $all = $find_spec{all};
328            7                                 17      my @matches;
329                                                      QUERY:
330            7                                 26      foreach my $query ( @$proclist ) {
331          129                                268         MKDEBUG && _d('Checking query', Dumper($query));
332          129                                330         my $matched = 0;
333                                                   
334                                                         # Don't allow matching replication threads.
335          129    100    100                  849         if (    !$find_spec{replication_threads}
336                                                              && $ms->is_replication_thread($query) ) {
337            4                                199            MKDEBUG && _d('Skipping replication thread');
338            4                                 16            next QUERY;
339                                                         }
340                                                   
341                                                         # Match special busy_time.
342   ***    125    100     50                 4953         if ( $find_spec{busy_time} && ($query->{Command} || '') eq 'Query' ) {
                           100                        
343            4    100                          21            if ( $query->{Time} < $find_spec{busy_time} ) {
344            1                                  2               MKDEBUG && _d("Query isn't running long enough");
345            1                                  4               next QUERY;
346                                                            }
347            3                                  6            MKDEBUG && _d('Exceeds busy time');
348            3                                  8            $matched++;
349                                                         }
350                                                   
351                                                         # Match special idle_time.
352   ***    124    100     50                 1069         if ( $find_spec{idle_time} && ($query->{Command} || '') eq 'Sleep' ) {
                           100                        
353           23    100                         115            if ( $query->{Time} < $find_spec{idle_time} ) {
354           22                                 44               MKDEBUG && _d("Query isn't idle long enough");
355           22                                 64               next QUERY;
356                                                            }
357            1                                  2            MKDEBUG && _d('Exceeds idle time');
358            1                                  2            $matched++;
359                                                         }
360                                                    
361                                                         PROPERTY:
362          102                                379         foreach my $property ( qw(Id User Host db State Command Info) ) {
363          710                               2046            my $filter = "_find_match_$property";
364          710    100    100                 3557            if ( defined $find_spec{ignore}->{$property}
365                                                                 && $self->$filter($query, $find_spec{ignore}->{$property}) ) {
366            2                                  5               MKDEBUG && _d('Query matches ignore', $property, 'spec');
367            2                                  8               next QUERY;
368                                                            }
369          708    100                        3145            if ( defined $find_spec{match}->{$property} ) {
370            7    100                          37               if ( !$self->$filter($query, $find_spec{match}->{$property}) ) {
371            3                                  6                  MKDEBUG && _d('Query does not match', $property, 'spec');
372            3                                 11                  next QUERY;
373                                                               }
374            4                                 10               MKDEBUG && _d('Query matches', $property, 'spec');
375            4                                 18               $matched++;
376                                                            }
377                                                         }
378           97    100    100                  679         if ( $matched || $all ) {
379            6                                 15            MKDEBUG && _d("Query matched one or more specs, adding");
380            6                                 17            push @matches, $query;
381            6                                 21            next QUERY;
382                                                         }
383           91                                240         MKDEBUG && _d('Query does not match any specs, ignoring');
384                                                      } # QUERY
385                                                   
386            7    100    100                   50      if ( @matches && $find_spec{only_oldest} ) {
387            2                                 11         my ( $oldest ) = reverse sort { $a->{Time} <=> $b->{Time} } @matches;
      ***      0                                  0   
388            2                                  6         MKDEBUG && _d('Oldest query:', Dumper($oldest));
389            2                                 12         @matches = $oldest;
390                                                      }
391                                                   
392            7                                 54      return @matches;
393                                                   }
394                                                   
395                                                   sub _find_match_Id {
396            5                    5            20      my ( $self, $query, $property ) = @_;
397   ***      5            33                   84      return defined $property && defined $query->{Id} && $query->{Id} == $property;
      ***                   33                        
398                                                   }
399                                                   
400                                                   sub _find_match_User {
401            7                    7            27      my ( $self, $query, $property ) = @_;
402   ***      7            33                  136      return defined $property && defined $query->{User}
      ***                   66                        
403                                                         && $query->{User} =~ m/$property/;
404                                                   }
405                                                   
406                                                   sub _find_match_Host {
407   ***      0                    0             0      my ( $self, $query, $property ) = @_;
408   ***      0             0                    0      return defined $property && defined $query->{Host}
      ***                    0                        
409                                                         && $query->{Host} =~ m/$property/;
410                                                   }
411                                                   
412                                                   sub _find_match_db {
413   ***      0                    0             0      my ( $self, $query, $property ) = @_;
414   ***      0             0                    0      return defined $property && defined $query->{db}
      ***                    0                        
415                                                         && $query->{db} =~ m/$property/;
416                                                   }
417                                                   
418                                                   sub _find_match_State {
419            6                    6            23      my ( $self, $query, $property ) = @_;
420   ***      6            33                  101      return defined $property && defined $query->{State}
      ***                   66                        
421                                                         && $query->{State} =~ m/$property/;
422                                                   }
423                                                   
424                                                   sub _find_match_Command {
425            9                    9            35      my ( $self, $query, $property ) = @_;
426   ***      9            33                  144      return defined $property && defined $query->{Command}
      ***                   66                        
427                                                         && $query->{Command} =~ m/$property/;
428                                                   }
429                                                   
430                                                   sub _find_match_Info {
431            4                    4            17      my ( $self, $query, $property ) = @_;
432   ***      4            33                   86      return defined $property && defined $query->{Info}
      ***                   66                        
433                                                         && $query->{Info} =~ m/$property/;
434                                                   }
435                                                   
436                                                   sub _d {
437   ***      0                    0                    my ($package, undef, $line) = caller 0;
438   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
439   ***      0                                              map { defined $_ ? $_ : 'undef' }
440                                                           @_;
441   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
442                                                   }
443                                                   
444                                                   1;
445                                                   
446                                                   # ###########################################################################
447                                                   # End Processlist package
448                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
51    ***     50      0      3   unless $args{$arg}
162   ***     50      0     12   unless $args{$arg}
168   ***     50      0     12   unless $code
174   ***     50      0     12   if ($$self{'curr_rows'}) { }
180          100      8      4   if ($rows and scalar @$rows) { }
197          100      8      4   if (not $curr and @curr)
201          100      4      8   if (not $prev and @prev)
205          100      9      3   if ($curr or $prev)
208          100      3      6   if ($curr and $prev and $$curr[0] == $$prev[0]) { }
             100      1      5   elsif (not $curr or $curr and $prev and $$curr[0] > $$prev[0]) { }
212   ***     50      0      3   $$curr[5] =~ /\D/ ? :
214   ***     50      3      0   if ($$prev[7])
215          100      1      2   if (not $$curr[7] or $$prev[7] ne $$curr[7]) { }
      ***     50      0      2   elsif (defined $$curr[5] and $$curr[5] < $$prev[5]) { }
             100      1      1   elsif ($$curr[7] and defined $$curr[5] and $$misc{'time'} - $$curr[5] - $$prev[8] - $$prev[9] - $$misc{'etime'} > $fudge) { }
231          100      2      1   if ($is_new)
235          100      2      1   if ($$curr[7])
236          100      1      1   if ($$prev[7] and not $is_new) { }
259          100      3      2   if ($$curr[7] and defined $$curr[5])
271   ***     50      0     12   scalar @curr ? :
284          100      1      2   if ($$row[5] < $time - $$row[10])
335          100      4    125   if (not $find_spec{'replication_threads'} and $ms->is_replication_thread($query))
342          100      4    121   if ($find_spec{'busy_time'} and ($$query{'Command'} || '') eq 'Query')
343          100      1      3   if ($$query{'Time'} < $find_spec{'busy_time'})
352          100     23    101   if ($find_spec{'idle_time'} and ($$query{'Command'} || '') eq 'Sleep')
353          100     22      1   if ($$query{'Time'} < $find_spec{'idle_time'})
364          100      2    708   if (defined $find_spec{'ignore'}{$property} and $self->$filter($query, $find_spec{'ignore'}{$property}))
369          100      7    701   if (defined $find_spec{'match'}{$property})
370          100      3      4   if (not $self->$filter($query, $find_spec{'match'}{$property}))
378          100      6     91   if ($matched or $all)
386          100      2      5   if (@matches and $find_spec{'only_oldest'})
438   ***      0      0      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
180          100      3      9   $rows and scalar @$rows

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
197          100      1      3      8   not $curr and @curr
201   ***     66      0      8      4   not $prev and @prev
208   ***     66      0      5      4   $curr and $prev
             100      5      1      3   $curr and $prev and $$curr[0] == $$prev[0]
      ***     66      0      5      1   $curr and $prev
      ***     66      5      0      1   $curr and $prev and $$curr[0] > $$prev[0]
215   ***     33      0      2      0   defined $$curr[5] and $$curr[5] < $$prev[5]
      ***     33      0      0      2   $$curr[7] and defined $$curr[5]
      ***     66      0      1      1   $$curr[7] and defined $$curr[5] and $$misc{'time'} - $$curr[5] - $$prev[8] - $$prev[9] - $$misc{'etime'} > $fudge
236   ***     66      0      1      1   $$prev[7] and not $is_new
259   ***     66      2      0      3   $$curr[7] and defined $$curr[5]
335          100      1    124      4   not $find_spec{'replication_threads'} and $ms->is_replication_thread($query)
342          100    118      3      4   $find_spec{'busy_time'} and ($$query{'Command'} || '') eq 'Query'
352          100     11     90     23   $find_spec{'idle_time'} and ($$query{'Command'} || '') eq 'Sleep'
364          100    686     22      2   defined $find_spec{'ignore'}{$property} and $self->$filter($query, $find_spec{'ignore'}{$property})
386          100      2      3      2   @matches and $find_spec{'only_oldest'}
397   ***     33      0      0      5   defined $property && defined $$query{'Id'}
      ***     33      0      5      0   defined $property && defined $$query{'Id'} && $$query{'Id'} == $property
402   ***     33      0      0      7   defined $property && defined $$query{'User'}
      ***     66      0      6      1   defined $property && defined $$query{'User'} && $$query{'User'} =~ /$property/
408   ***      0      0      0      0   defined $property && defined $$query{'Host'}
      ***      0      0      0      0   defined $property && defined $$query{'Host'} && $$query{'Host'} =~ /$property/
414   ***      0      0      0      0   defined $property && defined $$query{'db'}
      ***      0      0      0      0   defined $property && defined $$query{'db'} && $$query{'db'} =~ /$property/
420   ***     33      0      0      6   defined $property && defined $$query{'State'}
      ***     66      0      5      1   defined $property && defined $$query{'State'} && $$query{'State'} =~ /$property/
426   ***     33      0      0      9   defined $property && defined $$query{'Command'}
      ***     66      0      7      2   defined $property && defined $$query{'Command'} && $$query{'Command'} =~ /$property/
432   ***     33      0      0      4   defined $property && defined $$query{'Info'}
      ***     66      0      2      2   defined $property && defined $$query{'Info'} && $$query{'Info'} =~ /$property/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
189   ***     50     12      0   $$self{'prev_rows'} ||= []
190   ***     50     12      0   $$self{'new_rows'} ||= []
342   ***     50      7      0   $$query{'Command'} || ''
352   ***     50    113      0   $$query{'Command'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
205   ***     66      9      0      3   $curr or $prev
208   ***     66      0      1      5   not $curr or $curr and $prev and $$curr[0] > $$prev[0]
215   ***     66      1      0      2   not $$curr[7] or $$prev[7] ne $$curr[7]
378          100      3      3     91   $matched or $all


Covered Subroutines
-------------------

Subroutine          Count Pod Location                                          
------------------- ----- --- --------------------------------------------------
BEGIN                   1     /home/daniel/dev/maatkit/common/Processlist.pm:22 
BEGIN                   1     /home/daniel/dev/maatkit/common/Processlist.pm:23 
BEGIN                   1     /home/daniel/dev/maatkit/common/Processlist.pm:24 
BEGIN                   1     /home/daniel/dev/maatkit/common/Processlist.pm:26 
BEGIN                   1     /home/daniel/dev/maatkit/common/Processlist.pm:31 
BEGIN                   1     /home/daniel/dev/maatkit/common/Processlist.pm:44 
_find_match_Command     9     /home/daniel/dev/maatkit/common/Processlist.pm:425
_find_match_Id          5     /home/daniel/dev/maatkit/common/Processlist.pm:396
_find_match_Info        4     /home/daniel/dev/maatkit/common/Processlist.pm:431
_find_match_State       6     /home/daniel/dev/maatkit/common/Processlist.pm:419
_find_match_User        7     /home/daniel/dev/maatkit/common/Processlist.pm:401
_get_rows               8     /home/daniel/dev/maatkit/common/Processlist.pm:303
find                    7   0 /home/daniel/dev/maatkit/common/Processlist.pm:324
make_event              3   0 /home/daniel/dev/maatkit/common/Processlist.pm:282
new                     3   0 /home/daniel/dev/maatkit/common/Processlist.pm:49 
parse_event            12   0 /home/daniel/dev/maatkit/common/Processlist.pm:159

Uncovered Subroutines
---------------------

Subroutine          Count Pod Location                                          
------------------- ----- --- --------------------------------------------------
_d                      0     /home/daniel/dev/maatkit/common/Processlist.pm:437
_find_match_Host        0     /home/daniel/dev/maatkit/common/Processlist.pm:407
_find_match_db          0     /home/daniel/dev/maatkit/common/Processlist.pm:413


Processlist.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            31      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            10   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            10   use Test::More tests => 23;
               1                                  3   
               1                                 10   
13                                                    
14             1                    1            12   use Processlist;
               1                                  3   
               1                                 11   
15             1                    1            12   use MaatkitTest;
               1                                  3   
               1                                 36   
16             1                    1            14   use TextResultSetParser;
               1                                  3   
               1                                 14   
17             1                    1            11   use Transformers;
               1                                  3   
               1                                 10   
18             1                    1             9   use MasterSlave;
               1                                  3   
               1                                 14   
19             1                    1             8   use MaatkitTest;
               1                                  3   
               1                                  7   
20                                                    
21             1                                  9   my $ms  = new MasterSlave();
22             1                                 28   my $pl  = new Processlist(MasterSlave=>$ms);
23             1                                  6   my $rsp = new TextResultSetParser();
24                                                    
25             1                                 21   my @events;
26             1                                  3   my $procs;
27                                                    
28                                                    sub parse_n_times {
29             9                    9          2218      my ( $n, %args ) = @_;
30             9                                 30      my @events;
31             9                                 38      for ( 1..$n ) {
32            12                                 73         my $event = $pl->parse_event(misc => \%args);
33            12    100                          62         push @events, $event if $event;
34                                                       }
35             9                                 42      return @events;
36                                                    }
37                                                    
38                                                    # An unfinished query doesn't crash anything.
39                                                    $procs = [
40                                                       [ [1, 'unauthenticated user', 'localhost', undef, 'Connect', undef,
41                                                        'Reading from net', undef] ],
42                                                    ],
43                                                    parse_n_times(
44                                                       3,
45                                                       code  => sub {
46             3                    3            12         return shift @$procs;
47                                                       },
48             1                                 14      time  => Transformers::unix_timestamp('2001-01-01 00:05:00'),
49                                                    );
50             1                                  8   is_deeply($pl->_get_rows()->{prev_rows}, [], 'Prev does not know about undef query');
51             1                                 13   is(scalar @events, 0, 'No events fired from connection in process');
52                                                    
53                                                    # Make a new one to replicate a bug with certainty...
54             1                                  6   $pl = Processlist->new(MasterSlave=>$ms);
55                                                    
56                                                    # An existing sleeping query that goes away doesn't crash anything.
57                                                    parse_n_times(
58                                                       1,
59                                                       code  => sub {
60                                                          return [
61             1                    1             7            [1, 'root', 'localhost', undef, 'Sleep', 7, '', undef],
62                                                          ],
63                                                       },
64             1                                 12      time  => Transformers::unix_timestamp('2001-01-01 00:05:00'),
65                                                    );
66                                                    
67                                                    # And now the connection goes away...
68                                                    parse_n_times(
69                                                       1,
70                                                       code  => sub {
71                                                          return [
72             1                    1             4         ],
73                                                       },
74             1                                 10      time  => Transformers::unix_timestamp('2001-01-01 00:05:01'),
75                                                    );
76                                                    
77             1                                  7   is_deeply($pl->_get_rows()->{prev_rows}, [], 'everything went away');
78             1                                 10   is(scalar @events, 0, 'No events fired from sleeping connection that left');
79                                                    
80                                                    # Make sure there's a fresh start...
81             1                                  6   $pl = Processlist->new(MasterSlave=>$ms);
82                                                    
83                                                    # The initial processlist shows a query in progress.
84                                                    parse_n_times(
85                                                       1,
86                                                       code  => sub {
87                                                          return [
88             1                    1             8            [1, 'root', 'localhost', 'test', 'Query', 2, 'executing', 'query1_1'],
89                                                          ],
90                                                       },
91             1                                 12      time  => Transformers::unix_timestamp('2001-01-01 00:05:00'),
92                                                       etime => .05,
93                                                    );
94                                                    
95                                                    # The $prev array should now show that the query started at time 2 seconds ago
96             1                                  8   is_deeply(
97                                                       $pl->_get_rows()->{prev_rows},
98                                                       [
99                                                          [1, 'root', 'localhost', 'test', 'Query', 2,
100                                                            'executing', 'query1_1',
101                                                            Transformers::unix_timestamp('2001-01-01 00:04:58'), .05,
102                                                            Transformers::unix_timestamp('2001-01-01 00:05:00') ],
103                                                      ],
104                                                      'Prev knows about the query',
105                                                   );
106                                                   
107            1                                 12   is(scalar @events, 0, 'No events fired');
108                                                   
109                                                   # The next processlist shows a new query in progress and the other one is not
110                                                   # there anymore at all.
111            1                                  7   $procs = [
112                                                      [ [2, 'root', 'localhost', 'test', 'Query', 1, 'executing', 'query2_1'] ],
113                                                   ];
114                                                   @events = parse_n_times(
115                                                      2, 
116                                                      code  => sub {
117            2                    2             9         return shift @$procs,
118                                                      },
119            1                                 10      time  => Transformers::unix_timestamp('2001-01-01 00:05:01'),
120                                                      etime => .03,
121                                                   );
122                                                   
123                                                   # The $prev array should not have the first one anymore, just the second one.
124            1                                  7   is_deeply(
125                                                      $pl->_get_rows()->{prev_rows},
126                                                      [
127                                                         [2, 'root', 'localhost', 'test', 'Query', 1,
128                                                            'executing', 'query2_1',
129                                                            Transformers::unix_timestamp('2001-01-01 00:05:00'), .03,
130                                                            Transformers::unix_timestamp('2001-01-01 00:05:01')],
131                                                      ],
132                                                      'Prev forgot disconnected cxn 1, knows about cxn 2',
133                                                   );
134                                                   
135                                                   # And the first query has fired an event.
136            1                                 19   is_deeply(
137                                                      \@events,
138                                                      [  {  db         => 'test',
139                                                            user       => 'root',
140                                                            host       => 'localhost',
141                                                            arg        => 'query1_1',
142                                                            bytes      => 8,
143                                                            ts         => '2001-01-01T00:05:00',
144                                                            Query_time => 2,
145                                                            Lock_time  => 0,
146                                                            id         => 1,
147                                                         },
148                                                      ],
149                                                      'query1_1 fired',
150                                                   );
151                                                   
152                                                   # In this sample, the query on cxn 2 is finished, but the connection is still
153                                                   # open.
154                                                   @events = parse_n_times(
155                                                      1,
156                                                      code  => sub {
157                                                         return [
158            1                    1             7            [ 2, 'root', 'localhost', 'test', 'Sleep', 0, '', undef],
159                                                         ],
160                                                      },
161            1                                 15      time  => Transformers::unix_timestamp('2001-01-01 00:05:02'),
162                                                   );
163                                                   
164                                                   # And so as a result, query2_1 has fired and the prev array is empty.
165            1                                  8   is_deeply(
166                                                      $pl->_get_rows()->{prev_rows},
167                                                      [],
168                                                      'Prev says no queries are active',
169                                                   );
170                                                   
171                                                   # And the first query on cxn 2 has fired an event.
172            1                                 22   is_deeply(
173                                                      \@events,
174                                                      [  {  db         => 'test',
175                                                            user       => 'root',
176                                                            host       => 'localhost',
177                                                            arg        => 'query2_1',
178                                                            bytes      => 8,
179                                                            ts         => '2001-01-01T00:05:01',
180                                                            Query_time => 1,
181                                                            Lock_time  => 0,
182                                                            id         => 2,
183                                                         },
184                                                      ],
185                                                      'query2_1 fired',
186                                                   );
187                                                   
188                                                   # In this sample, cxn 2 is running a query, with a start time at the current
189                                                   # time of 3 secs later
190                                                   @events = parse_n_times(
191                                                      1,
192                                                      code  => sub {
193                                                         return [
194            1                    1             7            [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2'],
195                                                         ],
196                                                      },
197            1                                 17      time  => Transformers::unix_timestamp('2001-01-01 00:05:03'),
198                                                      etime => 3.14159,
199                                                   );
200                                                   
201            1                                  8   is_deeply(
202                                                      $pl->_get_rows()->{prev_rows},
203                                                      [
204                                                         [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2',
205                                                         Transformers::unix_timestamp('2001-01-01 00:05:03'), 3.14159,
206                                                         Transformers::unix_timestamp('2001-01-01 00:05:03') ],
207                                                      ],
208                                                      'Prev says query2_2 just started',
209                                                   );
210                                                   
211                                                   # And there is no event on cxn 2.
212            1                                 12   is_deeply(
213                                                      \@events,
214                                                      [],
215                                                      'query2_2 is not fired yet',
216                                                   );
217                                                   
218                                                   # In this sample, the "same" query is running one second later and this time it
219                                                   # seems to have a start time of 5 secs later, which is not enough to be a new
220                                                   # query.
221                                                   @events = parse_n_times(
222                                                      1,
223                                                      code  => sub {
224                                                         return [
225            1                    1             7            [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2'],
226                                                         ],
227                                                      },
228            1                                 14      time  => Transformers::unix_timestamp('2001-01-01 00:05:05'),
229                                                      etime => 2.718,
230                                                   );
231                                                   
232                                                   # And so as a result, query2_2 has NOT fired, but the prev array contains the
233                                                   # query2_2 still.
234            1                                  7   is_deeply(
235                                                      $pl->_get_rows()->{prev_rows},
236                                                      [
237                                                         [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2',
238                                                         Transformers::unix_timestamp('2001-01-01 00:05:03'), 3.14159,
239                                                         Transformers::unix_timestamp('2001-01-01 00:05:03') ],
240                                                      ],
241                                                      'After query2_2 fired, the prev array has the one starting at 05:03',
242                                                   );
243                                                   
244            1                                 12   is(scalar(@events), 0, 'It did not fire yet');
245                                                   
246                                                   # But wait!  There's another!  And this time we catch it!
247                                                   @events = parse_n_times(
248                                                      1,
249                                                      code  => sub {
250                                                         return [
251            1                    1             7            [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2'],
252                                                         ],
253                                                      },
254            1                                 10      time  => Transformers::unix_timestamp('2001-01-01 00:05:08.500'),
255                                                      etime => 0.123,
256                                                   );
257                                                   
258                                                   # And so as a result, query2_2 has fired and the prev array contains the "new"
259                                                   # query2_2.
260            1                                  7   is_deeply(
261                                                      $pl->_get_rows()->{prev_rows},
262                                                      [
263                                                         [ 2, 'root', 'localhost', 'test', 'Query', 0, 'executing', 'query2_2',
264                                                         Transformers::unix_timestamp('2001-01-01 00:05:08'), 0.123,
265                                                         Transformers::unix_timestamp('2001-01-01 00:05:08.500') ],
266                                                      ],
267                                                      'After query2_2 fired, the prev array has the one starting at 05:08',
268                                                   );
269                                                   
270                                                   # And the query has fired an event.
271            1                                 18   is_deeply(
272                                                      \@events,
273                                                      [  {  db         => 'test',
274                                                            user       => 'root',
275                                                            host       => 'localhost',
276                                                            arg        => 'query2_2',
277                                                            bytes      => 8,
278                                                            ts         => '2001-01-01T00:05:03',
279                                                            Query_time => 5.5,
280                                                            Lock_time  => 0,
281                                                            id         => 2,
282                                                         },
283                                                      ],
284                                                      'query2_2 fired',
285                                                   );
286                                                   
287                                                   # #########################################################################
288                                                   # Tests for "find" functionality.
289                                                   # #########################################################################
290                                                   
291            1                                 34   my %find_spec = (
292                                                      only_oldest  => 1,
293                                                      busy_time    => 60,
294                                                      idle_time    => 0,
295                                                      ignore => {
296                                                         Id       => 5,
297                                                         User     => qr/^system.user$/,
298                                                         State    => qr/Locked/,
299                                                         Command  => qr/Binlog Dump/,
300                                                      },
301                                                      match => {
302                                                         Command  => qr/Query/,
303                                                         Info     => qr/^(?i:select)/,
304                                                      },
305                                                   );
306                                                   
307            1                                 62   my @queries = $pl->find(
308                                                      [  {  'Time'    => '488',
309                                                            'Command' => 'Connect',
310                                                            'db'      => undef,
311                                                            'Id'      => '4',
312                                                            'Info'    => undef,
313                                                            'User'    => 'system user',
314                                                            'State'   => 'Waiting for master to send event',
315                                                            'Host'    => ''
316                                                         },
317                                                         {  'Time'    => '488',
318                                                            'Command' => 'Connect',
319                                                            'db'      => undef,
320                                                            'Id'      => '5',
321                                                            'Info'    => undef,
322                                                            'User'    => 'system user',
323                                                            'State' =>
324                                                               'Has read all relay log; waiting for the slave I/O thread to update it',
325                                                            'Host' => ''
326                                                         },
327                                                         {  'Time'    => '416',
328                                                            'Command' => 'Sleep',
329                                                            'db'      => undef,
330                                                            'Id'      => '7',
331                                                            'Info'    => undef,
332                                                            'User'    => 'msandbox',
333                                                            'State'   => '',
334                                                            'Host'    => 'localhost'
335                                                         },
336                                                         {  'Time'    => '0',
337                                                            'Command' => 'Query',
338                                                            'db'      => undef,
339                                                            'Id'      => '8',
340                                                            'Info'    => 'show full processlist',
341                                                            'User'    => 'msandbox',
342                                                            'State'   => undef,
343                                                            'Host'    => 'localhost:41655'
344                                                         },
345                                                         {  'Time'    => '467',
346                                                            'Command' => 'Binlog Dump',
347                                                            'db'      => undef,
348                                                            'Id'      => '2',
349                                                            'Info'    => undef,
350                                                            'User'    => 'msandbox',
351                                                            'State' =>
352                                                               'Has sent all binlog to slave; waiting for binlog to be updated',
353                                                            'Host' => 'localhost:56246'
354                                                         },
355                                                         {  'Time'    => '91',
356                                                            'Command' => 'Sleep',
357                                                            'db'      => undef,
358                                                            'Id'      => '40',
359                                                            'Info'    => undef,
360                                                            'User'    => 'msandbox',
361                                                            'State'   => '',
362                                                            'Host'    => 'localhost'
363                                                         },
364                                                         {  'Time'    => '91',
365                                                            'Command' => 'Query',
366                                                            'db'      => undef,
367                                                            'Id'      => '41',
368                                                            'Info'    => 'optimize table foo',
369                                                            'User'    => 'msandbox',
370                                                            'State'   => 'Query',
371                                                            'Host'    => 'localhost'
372                                                         },
373                                                         {  'Time'    => '91',
374                                                            'Command' => 'Query',
375                                                            'db'      => undef,
376                                                            'Id'      => '42',
377                                                            'Info'    => 'select * from foo',
378                                                            'User'    => 'msandbox',
379                                                            'State'   => 'Locked',
380                                                            'Host'    => 'localhost'
381                                                         },
382                                                         {  'Time'    => '91',
383                                                            'Command' => 'Query',
384                                                            'db'      => undef,
385                                                            'Id'      => '43',
386                                                            'Info'    => 'select * from foo',
387                                                            'User'    => 'msandbox',
388                                                            'State'   => 'executing',
389                                                            'Host'    => 'localhost'
390                                                         },
391                                                      ],
392                                                      %find_spec,
393                                                   );
394                                                   
395            1                                 18   my $expected = [
396                                                         {  'Time'    => '91',
397                                                            'Command' => 'Query',
398                                                            'db'      => undef,
399                                                            'Id'      => '43',
400                                                            'Info'    => 'select * from foo',
401                                                            'User'    => 'msandbox',
402                                                            'State'   => 'executing',
403                                                            'Host'    => 'localhost'
404                                                         },
405                                                      ];
406                                                   
407            1                                  6   is_deeply(\@queries, $expected, 'Basic find()');
408                                                   
409            1                                 31   %find_spec = (
410                                                      only_oldest  => 1,
411                                                      busy_time    => 1,
412                                                      ignore => {
413                                                         User     => qr/^system.user$/,
414                                                         State    => qr/Locked/,
415                                                         Command  => qr/Binlog Dump/,
416                                                      },
417                                                      match => {
418                                                      },
419                                                   );
420                                                   
421            1                                 13   @queries = $pl->find(
422                                                      [  {  'Time'    => '488',
423                                                            'Command' => 'Sleep',
424                                                            'db'      => undef,
425                                                            'Id'      => '7',
426                                                            'Info'    => undef,
427                                                            'User'    => 'msandbox',
428                                                            'State'   => '',
429                                                            'Host'    => 'localhost'
430                                                         },
431                                                      ],
432                                                      %find_spec,
433                                                   );
434                                                   
435            1                                  8   is(scalar(@queries), 0, 'Did not find any query');
436                                                   
437            1                                 13   %find_spec = (
438                                                      only_oldest  => 1,
439                                                      busy_time    => undef,
440                                                      idle_time    => 15,
441                                                      ignore => {
442                                                      },
443                                                      match => {
444                                                      },
445                                                   );
446            1                                  8   is_deeply(
447                                                      [
448                                                         $pl->find(
449                                                            $rsp->parse(load_file('common/t/samples/pl/recset003.txt')),
450                                                            %find_spec,
451                                                         )
452                                                      ],
453                                                      [
454                                                         {
455                                                            Id    => '29392005',
456                                                            User  => 'remote',
457                                                            Host  => '1.2.3.148:49718',
458                                                            db    => 'happy',
459                                                            Command => 'Sleep',
460                                                            Time  => '17',
461                                                            State => undef,
462                                                            Info  => 'NULL',
463                                                         }
464                                                      ],
465                                                      'idle_time'
466                                                   );
467                                                   
468                                                   # #########################################################################
469                                                   # Tests for "find" functionality.
470                                                   # #########################################################################
471            1                                115   %find_spec = (
472                                                      match => { User => 'msandbox' },
473                                                   );
474            1                                  7   @queries = $pl->find(
475                                                      $rsp->parse(load_file('common/t/samples/pl/recset008.txt')),
476                                                      %find_spec,
477                                                   );
478            1                                  9   ok(
479                                                      @queries == 0,
480                                                      "Doesn't match replication thread by default"
481                                                   );
482                                                   
483            1                                  9   %find_spec = (
484                                                      replication_threads => 1,
485                                                      match => { User => 'msandbox' },
486                                                   );
487            1                                  6   @queries = $pl->find(
488                                                      $rsp->parse(load_file('common/t/samples/pl/recset008.txt')),
489                                                      %find_spec,
490                                                   );
491            1                                  7   ok(
492                                                      @queries == 1,
493                                                      "Matches replication thread"
494                                                   );
495                                                   
496                                                   
497                                                   # #############################################################################
498                                                   # Find "all".
499                                                   # #############################################################################
500            1                                  7   %find_spec = (
501                                                      all => 1,
502                                                   );
503            1                                  6   @queries = $pl->find(
504                                                      $rsp->parse(load_file('common/t/samples/pl/recset002.txt')),
505                                                      %find_spec,
506                                                   );
507                                                   
508            1                                  7   is_deeply(
509                                                      \@queries,
510                                                      $rsp->parse(load_file('common/t/samples/pl/recset002.txt')),
511                                                      "Find all queries"
512                                                   );
513                                                   
514            1                                 14   %find_spec = (
515                                                      all => 1,
516                                                      ignore => { Info => 'foo1' },
517                                                   );
518            1                                  5   @queries = $pl->find(
519                                                      $rsp->parse(load_file('common/t/samples/pl/recset002.txt')),
520                                                      %find_spec,
521                                                   );
522                                                   
523            1                                 12   is_deeply(
524                                                      \@queries,
525                                                      [
526                                                         {
527                                                            Id      => '2',
528                                                            User    => 'user1',
529                                                            Host    => '1.2.3.4:5455',
530                                                            db      => 'foo',
531                                                            Command => 'Query',
532                                                            Time    => '5',
533                                                            State   => 'Locked',
534                                                            Info    => 'select * from foo2;',
535                                                         }
536                                                      ],
537                                                      "Find all queries that aren't ignored"
538                                                   );
539                                                   
540                                                   # #############################################################################
541                                                   # Done.
542                                                   # #############################################################################
543            1                                  2   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
33           100      3      9   if $event


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine    Count Location         
------------- ----- -----------------
BEGIN             1 Processlist.t:10 
BEGIN             1 Processlist.t:11 
BEGIN             1 Processlist.t:12 
BEGIN             1 Processlist.t:14 
BEGIN             1 Processlist.t:15 
BEGIN             1 Processlist.t:16 
BEGIN             1 Processlist.t:17 
BEGIN             1 Processlist.t:18 
BEGIN             1 Processlist.t:19 
BEGIN             1 Processlist.t:4  
BEGIN             1 Processlist.t:9  
__ANON__          2 Processlist.t:117
__ANON__          1 Processlist.t:158
__ANON__          1 Processlist.t:194
__ANON__          1 Processlist.t:225
__ANON__          1 Processlist.t:251
__ANON__          3 Processlist.t:46 
__ANON__          1 Processlist.t:61 
__ANON__          1 Processlist.t:72 
__ANON__          1 Processlist.t:88 
parse_n_times     9 Processlist.t:29 


