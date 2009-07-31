---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/Processlist.pm   88.8   88.5   55.9   82.4    n/a  100.0   76.4
Total                          88.8   88.5   55.9   82.4    n/a  100.0   76.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Processlist.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:06 2009
Finish:       Fri Jul 31 18:53:06 2009

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
18                                                    # Processlist package $Revision: 4207 $
19                                                    # ###########################################################################
20                                                    package Processlist;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
25                                                    
26             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
27                                                    use constant {
28             1                                 12      ID      => 0,
29                                                       USER    => 1,
30                                                       HOST    => 2,
31                                                       DB      => 3,
32                                                       COMMAND => 4,
33                                                       TIME    => 5,
34                                                       STATE   => 6,
35                                                       INFO    => 7,
36                                                       START   => 8, # Calculated start time of statement
37                                                       ETIME   => 9, # Exec time of SHOW PROCESSLIST (margin of error in START)
38                                                       FSEEN   => 10, # First time ever seen
39             1                    1             6   };
               1                                  3   
40                                                    
41                                                    sub new {
42             3                    3            35      my ( $class ) = @_;
43             3                                 25      bless {}, $class;
44                                                    }
45                                                    
46                                                    # This method accepts a $code coderef, which is typically going to return SHOW
47                                                    # FULL PROCESSLIST, and an array of callbacks.  The $code coderef can be any
48                                                    # subroutine that can return an array of arrayrefs that have the same structure
49                                                    # as SHOW FULL PRCESSLIST (see the defined constants above).  When it sees a
50                                                    # query complete, it turns the query into an "event" and calls the callbacks
51                                                    # with it.  It may find more than one event per call.  It also expects a $misc
52                                                    # hashref, which it will use to maintain state in the caller's namespace across
53                                                    # calls.  It expects this hashref to have the following:
54                                                    #
55                                                    #  my $misc = { prev => [], time => time(), etime => ? };
56                                                    #
57                                                    # Where etime is how long SHOW FULL PROCESSLIST took to execute.
58                                                    #
59                                                    # Each event is a hashref of attribute => value pairs like:
60                                                    #
61                                                    #  my $event = {
62                                                    #     ts  => '',    # Timestamp
63                                                    #     id  => '',    # Connection ID
64                                                    #     arg => '',    # Argument to the command
65                                                    #     other attributes...
66                                                    #  };
67                                                    #
68                                                    # Returns the number of events it finds.
69                                                    #
70                                                    # Technical details: keeps the previous run's processes in an array, gets the
71                                                    # current processes, and iterates through them, comparing prev and curr.  There
72                                                    # are several cases:
73                                                    #
74                                                    # 1) Connection is in curr, not in prev.  This is a new connection.  Calculate
75                                                    #    the time at which the statement must have started to execute.  Save this as
76                                                    #    a property of the event.
77                                                    # 2) Connection is in curr and prev, and the statement is the same, and the
78                                                    #    current time minus the start time of the event in prev matches the Time
79                                                    #    column of the curr.  This is the same statement we saw last time we looked
80                                                    #    at this connection, so do nothing.
81                                                    # 3) Same as 2) but the Info is different.  Then sometime between the prev
82                                                    #    and curr snapshots, that statement finished.  Assume it finished
83                                                    #    immediately after we saw it last time.  Fire the event handlers.
84                                                    #    TODO: if the statement is now running something else or Sleep for a certain
85                                                    #    time, then that shows the max end time of the last statement.  If it's 10s
86                                                    #    later and it's now been Sleep for 8s, then it might have ended up to 8s
87                                                    #    ago.
88                                                    # 4) Connection went away, or Info went NULL.  Same as 3).
89                                                    #
90                                                    # The default MySQL server has one-second granularity in the Time column.  This
91                                                    # means that a statement that starts at X.9 seconds shows 0 seconds for only 0.1
92                                                    # second.  A statement that starts at X.0 seconds shows 0 secs for a second, and
93                                                    # 1 second up until it has actually been running 2 seconds.  This makes it
94                                                    # tricky to determine when a statement has been re-issued.  Further, this
95                                                    # program and MySQL may have some clock skew.  Even if they are running on the
96                                                    # same machine, it's possible that at X.999999 seconds we get the time, and at
97                                                    # X+1.000001 seconds we get the snapshot from MySQL.  (Fortunately MySQL doesn't
98                                                    # re-evaluate now() for every process, or that would cause even more problems.)
99                                                    # And a query that's issued to MySQL may stall for any amount of time before
100                                                   # it's executed, making even more skew between the times.
101                                                   #
102                                                   # As a result of all this, this program assumes that the time it is passed in
103                                                   # $misc is measured consistently *after* calling SHOW PROCESSLIST, and is
104                                                   # measured with high precision (not second-level precision, which would
105                                                   # introduce an extra second of possible error in each direction).  That is a
106                                                   # convention that's up to the caller to follow.  One worst case is this:
107                                                   #
108                                                   #  * The processlist measures time at 100.01 and it's 100.
109                                                   #  * We measure the time.  It says 100.02.
110                                                   #  * A query was started at 90.  Processlist says Time=10.
111                                                   #  * We calculate that the query was started at 90.02.
112                                                   #  * Processlist measures it at 100.998 and it's 100.
113                                                   #  * We measure time again, it says 100.999.
114                                                   #  * Time has passed, but the Time column still says 10.
115                                                   #
116                                                   # Another:
117                                                   #
118                                                   #  * We get the processlist, then the time.
119                                                   #  * A second later we get the processlist, but it takes 2 sec to fetch.
120                                                   #  * We measure the time and it looks like 3 sec have passed, but ps says only
121                                                   #    one has passed.  (This is why $misc->{etime} is necessary).
122                                                   #
123                                                   # What should we do?  Well, the key thing to notice here is that a new statement
124                                                   # has started if a) the Time column actually decreases since we last saw the
125                                                   # process, or b) the Time column does not increase for 2 seconds, plus the etime
126                                                   # of the first and second measurements combined!
127                                                   #
128                                                   # The $code shouldn't return itself, e.g. if it's a PROCESSLIST you should
129                                                   # filter out $dbh->{mysql_thread_id}.
130                                                   #
131                                                   # TODO: unresolved issues are
132                                                   # 1) What about Lock_time?  It's unclear if a query starts at 100, unlocks at
133                                                   #    105 and completes at 110, is it 5s lock and 5s exec?  Or 5s lock, 10s exec?
134                                                   #    This code should match that behavior.
135                                                   # 2) What about splitting the difference?  If I see a query now with 0s, and one
136                                                   #    second later I look and see it's gone, should I split the middle and say it
137                                                   #    ran for .5s?
138                                                   # 3) I think user/host needs to do user/host/ip, really.  And actually, port
139                                                   #    will show up in the processlist -- make that a property too.
140                                                   # 4) It should put cmd => Query, cmd => Admin, or whatever
141                                                   sub parse_event {
142            9                    9           317      my ( $self, $code, $misc, @callbacks ) = @_;
143            9                                 26      my $num_events = 0;
144                                                   
145            9                                 24      my @curr = sort { $a->[ID] <=> $b->[ID] } @{$code->()};
      ***      0                                  0   
               9                                 30   
146   ***      9            50                  123      my @prev = @{$misc->{prev} ||= []};
               9                                 51   
147            9                                 22      my @new; # Will become next invocation's @prev
148            9                                 25      my ($curr, $prev); # Rows from each source
149                                                   
150   ***      9            33                   21      do {
      ***                   66                        
      ***                   66                        
151           10    100    100                   81         if ( !$curr && @curr ) {
152            8                                 17            MKDEBUG && _d('Fetching row from curr');
153            8                                 24            $curr = shift @curr;
154                                                         }
155   ***     10    100     66                   73         if ( !$prev && @prev ) {
156            4                                  9            MKDEBUG && _d('Fetching row from prev');
157            4                                 13            $prev = shift @prev;
158                                                         }
159   ***     10    100     66                   65         if ( $curr || $prev ) {
160                                                            # In each of the if/elses, something must be undef'ed to prevent
161                                                            # infinite looping.
162   ***      9    100     66                  153            if ( $curr && $prev && $curr->[ID] == $prev->[ID] ) {
                    100    100                        
      ***                   66                        
      ***                   66                        
      ***                   66                        
163            3                                  8               MKDEBUG && _d('$curr and $prev are the same cxn');
164                                                               # Or, if its start time seems to be after the start time of
165                                                               # the previously seen one, it's also a new query.
166   ***      3     50                          18               my $fudge = $curr->[TIME] =~ m/\D/ ? 0.001 : 1; # Micro-precision?
167            3                                  6               my $is_new = 0;
168   ***      3     50                          13               if ( $prev->[INFO] ) {
169   ***      3    100     66                   71                  if (!$curr->[INFO] || $prev->[INFO] ne $curr->[INFO]) {
      ***            50     33                        
      ***           100     33                        
      ***                   66                        
170                                                                     # This is a different query or a new query
171            1                                  2                     MKDEBUG && _d('$curr has a new query');
172            1                                  3                     $is_new = 1;
173                                                                  }
174                                                                  elsif (defined $curr->[TIME] && $curr->[TIME] < $prev->[TIME]) {
175   ***      0                                  0                     MKDEBUG && _d('$curr time is less than $prev time');
176   ***      0                                  0                     $is_new = 1;
177                                                                  }
178                                                                  elsif ( $curr->[INFO] && defined $curr->[TIME]
179                                                                     && $misc->{time} - $curr->[TIME] - $prev->[START]
180                                                                        - $prev->[ETIME] - $misc->{etime} > $fudge
181                                                                  ) {
182            1                                  2                     MKDEBUG && _d('$curr has same query that restarted');
183            1                                  3                     $is_new = 1;
184                                                                  }
185            3    100                          12                  if ( $is_new ) {
186            2                                  9                     fire_event( $prev, $misc->{time}, @callbacks );
187                                                                  }
188                                                               }
189            3    100                          32               if ( $curr->[INFO] ) {
190   ***      2    100     66                   17                  if ( $prev->[INFO] && !$is_new ) {
191            1                                  3                     MKDEBUG && _d('Pushing old history item back onto $prev');
192            1                                 19                     push @new, [ @$prev ];
193                                                                  }
194                                                                  else {
195            1                                  2                     MKDEBUG && _d('Pushing new history item onto $prev');
196            1                                  9                     push @new,
197                                                                        [ @$curr, int($misc->{time} - $curr->[TIME]),
198                                                                           $misc->{etime}, $misc->{time} ];
199                                                                  }
200                                                               }
201            3                                 54               $curr = $prev = undef; # Fetch another from each.
202                                                            }
203                                                            # The row in the prev doesn't exist in the curr.  Fire an event.
204                                                            elsif ( !$curr
205                                                                  || ( $curr && $prev && $curr->[ID] > $prev->[ID] )) {
206            1                                  3               MKDEBUG && _d('$curr is not in $prev');
207            1                                  5               fire_event( $prev, $misc->{time}, @callbacks );
208            1                                 22               $prev = undef;
209                                                            }
210                                                            # The row in curr isn't in prev; start a new event.
211                                                            else { # This else must be entered, to prevent infinite loops.
212            5                                 10               MKDEBUG && _d('$prev is not in $curr');
213   ***      5    100     66                   37               if ( $curr->[INFO] && defined $curr->[TIME] ) {
214            3                                  6                  MKDEBUG && _d('Pushing new history item onto $prev');
215            3                                 26                  push @new,
216                                                                     [ @$curr, int($misc->{time} - $curr->[TIME]),
217                                                                        $misc->{etime}, $misc->{time} ];
218                                                               }
219            5                                 96               $curr = undef; # No infinite loops.
220                                                            }
221                                                         }
222                                                      } while ( @curr || @prev || $curr || $prev );
223                                                   
224            9                                 25      @{$misc->{prev}} = @new;
               9                                 40   
225                                                   
226            9                                 33      return $num_events;
227                                                   }
228                                                   
229                                                   # The exec time of the query is the max of the time from the processlist, or the
230                                                   # time during which we've actually observed the query running.  In case two
231                                                   # back-to-back queries executed as the same one and we weren't able to tell them
232                                                   # apart, their time will add up, which is kind of what we want.
233                                                   sub fire_event {
234            3                    3            15      my ( $row, $time, @callbacks ) = @_;
235            3                                 10      my $Query_time = $row->[TIME];
236            3    100                          18      if ( $row->[TIME] < $time - $row->[FSEEN] ) {
237            1                                  4         $Query_time = $time - $row->[FSEEN];
238                                                      }
239            3                                 44      my $event = {
240                                                         id         => $row->[ID],
241                                                         db         => $row->[DB],
242                                                         user       => $row->[USER],
243                                                         host       => $row->[HOST],
244                                                         arg        => $row->[INFO],
245                                                         bytes      => length($row->[INFO]),
246                                                         ts         => $row->[START] + $row->[TIME], # Query END time
247                                                         Query_time => $Query_time,
248                                                         Lock_time  => 0,               # TODO
249                                                      };
250            3                                 10      foreach my $callback ( @callbacks ) {
251   ***      3     50                          11         last unless $event = $callback->($event);
252                                                      }
253                                                   }
254                                                   
255                                                   # Accepts a PROCESSLIST and a specification of filters to use against it.
256                                                   # Returns queries that match the filters.  The standard process properties
257                                                   # are: Id, User, Host, db, Command, Time, State, Info.  These are used for
258                                                   # ignore and match.
259                                                   #
260                                                   # Possible find_spec are:
261                                                   #   * only_oldest  Match the oldest running query
262                                                   #   * busy_time    Match queries that have been Command=Query for longer than
263                                                   #                  this time
264                                                   #   * idle_time    Match queries that have been Command=Sleep for longer than
265                                                   #                  this time
266                                                   #   * ignore       A hashref of properties => regex patterns to ignore
267                                                   #   * match        A hashref of properties => regex patterns to match
268                                                   #
269                                                   sub find {
270            3                    3           222      my ( $self, $proclist, %find_spec ) = @_;
271            3                                 10      my @matches;
272                                                      QUERY:
273            3                                 12      foreach my $query ( @$proclist ) {
274          123                                309         my $matched = 0;
275                                                   
276                                                         # Match special busy_time.
277   ***    123    100     50                  609         if ( $find_spec{busy_time} && ($query->{Command} || '') eq 'Query' ) {
                           100                        
278            4    100                          23            if ( $query->{Time} < $find_spec{busy_time} ) {
279            1                                 10               MKDEBUG && _d("Query isn't running long enough");
280            1                                  3               next QUERY;
281                                                            }
282            3                                  7            $matched++;
283                                                         }
284                                                   
285                                                         # Match special idle_time.
286   ***    122    100     50                 1076         if ( $find_spec{idle_time} && ($query->{Command} || '') eq 'Sleep' ) {
                           100                        
287           23    100                         108            if ( $query->{Time} < $find_spec{idle_time} ) {
288           22                                 46               MKDEBUG && _d("Query isn't idle long enough");
289           22                                 63               next QUERY;
290                                                            }
291            1                                  4            $matched++;
292                                                         }
293                                                   
294                                                         PROPERTY:
295          100                                348         foreach my $property ( qw(Id User Host db State Command Info) ) {
296          684                               1982            my $filter = "_find_match_$property";
297          684    100    100                 3503            if ( defined $find_spec{ignore}->{$property}
298                                                                 && $self->$filter($query, $find_spec{ignore}->{$property}) ) {
299            4                                  9               MKDEBUG && _d('Query matches ignore', $property, 'filter:',
300                                                                  $find_spec{ignore}->{$property}, '=~', $query->{$property});
301            4                                 14               next QUERY;
302                                                            }
303          680    100                        3015            if ( defined $find_spec{match}->{$property} ) {
304            6    100                          31               if ( !$self->$filter($query, $find_spec{match}->{$property}) ) {
305            3                                  6                  MKDEBUG && _d('Query does not match', $property, 'filter:',
306                                                                     $find_spec{match}->{$property}, '!~', $query->{$property});
307            3                                 12                  next QUERY;
308                                                               }
309            3                                 11               $matched++;
310                                                            }
311                                                         }
312           93    100                         361         if ( $matched ) {
313            2                                  5            MKDEBUG && _d("Query passed all defined filters, adding");
314            2                                 14            push @matches, $query;
315                                                         }
316                                                      } # QUERY
317                                                   
318   ***      3    100     66                   29      if ( @matches && $find_spec{only_oldest} ) {
319            2                                 16         my ( $oldest ) = reverse sort { $a->{Time} <=> $b->{Time} } @matches;
      ***      0                                  0   
320            2                                  9         @matches = $oldest;
321                                                      }
322                                                   
323            3                                 32      return @matches;
324                                                   }
325                                                   
326                                                   sub _find_match_Id {
327            8                    8            29      my ( $self, $query, $property ) = @_;
328   ***      8            33                  141      return defined $property && defined $query->{Id} && $query->{Id} == $property;
      ***                   66                        
329                                                   }
330                                                   
331                                                   sub _find_match_User {
332            8                    8            33      my ( $self, $query, $property ) = @_;
333   ***      8            33                  135      return defined $property && defined $query->{User}
      ***                   66                        
334                                                         && $query->{User} =~ m/$property/;
335                                                   }
336                                                   
337                                                   sub _find_match_Host {
338   ***      0                    0             0      my ( $self, $query, $property ) = @_;
339   ***      0             0                    0      return defined $property && defined $query->{Host}
      ***                    0                        
340                                                         && $query->{Host} =~ m/$property/;
341                                                   }
342                                                   
343                                                   sub _find_match_db {
344   ***      0                    0             0      my ( $self, $query, $property ) = @_;
345   ***      0             0                    0      return defined $property && defined $query->{db}
      ***                    0                        
346                                                         && $query->{db} =~ m/$property/;
347                                                   }
348                                                   
349                                                   sub _find_match_State {
350            7                    7            27      my ( $self, $query, $property ) = @_;
351   ***      7            33                  120      return defined $property && defined $query->{State}
      ***                   66                        
352                                                         && $query->{State} =~ m/$property/;
353                                                   }
354                                                   
355                                                   sub _find_match_Command {
356           10                   10            36      my ( $self, $query, $property ) = @_;
357   ***     10            33                  176      return defined $property && defined $query->{Command}
      ***                   66                        
358                                                         && $query->{Command} =~ m/$property/;
359                                                   }
360                                                   
361                                                   sub _find_match_Info {
362            2                    2            11      my ( $self, $query, $property ) = @_;
363   ***      2            33                   52      return defined $property && defined $query->{Info}
      ***                   66                        
364                                                         && $query->{Info} =~ m/$property/;
365                                                   }
366                                                   
367                                                   sub _d {
368   ***      0                    0                    my ($package, undef, $line) = caller 0;
369   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
370   ***      0                                              map { defined $_ ? $_ : 'undef' }
371                                                           @_;
372   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
373                                                   }
374                                                   
375                                                   1;
376                                                   
377                                                   # ###########################################################################
378                                                   # End Processlist package
379                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
151          100      8      2   if (not $curr and @curr)
155          100      4      6   if (not $prev and @prev)
159          100      9      1   if ($curr or $prev)
162          100      3      6   if ($curr and $prev and $$curr[0] == $$prev[0]) { }
             100      1      5   elsif (not $curr or $curr and $prev and $$curr[0] > $$prev[0]) { }
166   ***     50      0      3   $$curr[5] =~ /\D/ ? :
168   ***     50      3      0   if ($$prev[7])
169          100      1      2   if (not $$curr[7] or $$prev[7] ne $$curr[7]) { }
      ***     50      0      2   elsif (defined $$curr[5] and $$curr[5] < $$prev[5]) { }
             100      1      1   elsif ($$curr[7] and defined $$curr[5] and $$misc{'time'} - $$curr[5] - $$prev[8] - $$prev[9] - $$misc{'etime'} > $fudge) { }
185          100      2      1   if ($is_new)
189          100      2      1   if ($$curr[7])
190          100      1      1   if ($$prev[7] and not $is_new) { }
213          100      3      2   if ($$curr[7] and defined $$curr[5])
236          100      1      2   if ($$row[5] < $time - $$row[10])
251   ***     50      0      3   unless $event = &$callback($event)
277          100      4    119   if ($find_spec{'busy_time'} and ($$query{'Command'} || '') eq 'Query')
278          100      1      3   if ($$query{'Time'} < $find_spec{'busy_time'})
286          100     23     99   if ($find_spec{'idle_time'} and ($$query{'Command'} || '') eq 'Sleep')
287          100     22      1   if ($$query{'Time'} < $find_spec{'idle_time'})
297          100      4    680   if (defined $find_spec{'ignore'}{$property} and $self->$filter($query, $find_spec{'ignore'}{$property}))
303          100      6    674   if (defined $find_spec{'match'}{$property})
304          100      3      3   if (not $self->$filter($query, $find_spec{'match'}{$property}))
312          100      2     91   if ($matched)
318          100      2      1   if (@matches and $find_spec{'only_oldest'})
369   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
151          100      1      1      8   not $curr and @curr
155   ***     66      0      6      4   not $prev and @prev
162   ***     66      0      5      4   $curr and $prev
             100      5      1      3   $curr and $prev and $$curr[0] == $$prev[0]
      ***     66      0      5      1   $curr and $prev
      ***     66      5      0      1   $curr and $prev and $$curr[0] > $$prev[0]
169   ***     33      0      2      0   defined $$curr[5] and $$curr[5] < $$prev[5]
      ***     33      0      0      2   $$curr[7] and defined $$curr[5]
      ***     66      0      1      1   $$curr[7] and defined $$curr[5] and $$misc{'time'} - $$curr[5] - $$prev[8] - $$prev[9] - $$misc{'etime'} > $fudge
190   ***     66      0      1      1   $$prev[7] and not $is_new
213   ***     66      2      0      3   $$curr[7] and defined $$curr[5]
277          100    113      6      4   $find_spec{'busy_time'} and ($$query{'Command'} || '') eq 'Query'
286          100      9     90     23   $find_spec{'idle_time'} and ($$query{'Command'} || '') eq 'Sleep'
297          100    655     25      4   defined $find_spec{'ignore'}{$property} and $self->$filter($query, $find_spec{'ignore'}{$property})
318   ***     66      1      0      2   @matches and $find_spec{'only_oldest'}
328   ***     33      0      0      8   defined $property && defined $$query{'Id'}
      ***     66      0      7      1   defined $property && defined $$query{'Id'} && $$query{'Id'} == $property
333   ***     33      0      0      8   defined $property && defined $$query{'User'}
      ***     66      0      7      1   defined $property && defined $$query{'User'} && $$query{'User'} =~ /$property/
339   ***      0      0      0      0   defined $property && defined $$query{'Host'}
      ***      0      0      0      0   defined $property && defined $$query{'Host'} && $$query{'Host'} =~ /$property/
345   ***      0      0      0      0   defined $property && defined $$query{'db'}
      ***      0      0      0      0   defined $property && defined $$query{'db'} && $$query{'db'} =~ /$property/
351   ***     33      0      0      7   defined $property && defined $$query{'State'}
      ***     66      0      6      1   defined $property && defined $$query{'State'} && $$query{'State'} =~ /$property/
357   ***     33      0      0     10   defined $property && defined $$query{'Command'}
      ***     66      0      7      3   defined $property && defined $$query{'Command'} && $$query{'Command'} =~ /$property/
363   ***     33      0      0      2   defined $property && defined $$query{'Info'}
      ***     66      0      1      1   defined $property && defined $$query{'Info'} && $$query{'Info'} =~ /$property/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
146   ***     50      9      0   $$misc{'prev'} ||= []
277   ***     50     10      0   $$query{'Command'} || ''
286   ***     50    113      0   $$query{'Command'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
150   ***     33      0      0     10   @curr or @prev
      ***     66      0      1      9   @curr or @prev or $curr
      ***     66      1      0      9   @curr or @prev or $curr or $prev
159   ***     66      9      0      1   $curr or $prev
162   ***     66      0      1      5   not $curr or $curr and $prev and $$curr[0] > $$prev[0]
169   ***     66      1      0      2   not $$curr[7] or $$prev[7] ne $$curr[7]


Covered Subroutines
-------------------

Subroutine          Count Location                                          
------------------- ----- --------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:22 
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:23 
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:24 
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:26 
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:39 
_find_match_Command    10 /home/daniel/dev/maatkit/common/Processlist.pm:356
_find_match_Id          8 /home/daniel/dev/maatkit/common/Processlist.pm:327
_find_match_Info        2 /home/daniel/dev/maatkit/common/Processlist.pm:362
_find_match_State       7 /home/daniel/dev/maatkit/common/Processlist.pm:350
_find_match_User        8 /home/daniel/dev/maatkit/common/Processlist.pm:332
find                    3 /home/daniel/dev/maatkit/common/Processlist.pm:270
fire_event              3 /home/daniel/dev/maatkit/common/Processlist.pm:234
new                     3 /home/daniel/dev/maatkit/common/Processlist.pm:42 
parse_event             9 /home/daniel/dev/maatkit/common/Processlist.pm:142

Uncovered Subroutines
---------------------

Subroutine          Count Location                                          
------------------- ----- --------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/Processlist.pm:368
_find_match_Host        0 /home/daniel/dev/maatkit/common/Processlist.pm:338
_find_match_db          0 /home/daniel/dev/maatkit/common/Processlist.pm:344


