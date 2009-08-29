---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/Processlist.pm   89.7   88.5   55.9   83.3    n/a  100.0   77.3
Total                          89.7   88.5   55.9   83.3    n/a  100.0   77.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Processlist.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:28 2009
Finish:       Sat Aug 29 15:03:28 2009

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
18                                                    # Processlist package $Revision: 4584 $
19                                                    # ###########################################################################
20                                                    package Processlist;
21                                                    
22             1                    1             8   use strict;
               1                                  2   
               1                                  7   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                 11   
25                                                    
26             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  7   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
32                                                    use constant {
33             1                                 13      ID      => 0,
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
46                                                    sub new {
47             3                    3            37      my ( $class ) = @_;
48             3                                 25      bless {}, $class;
49                                                    }
50                                                    
51                                                    # This method accepts a $code coderef, which is typically going to return SHOW
52                                                    # FULL PROCESSLIST, and an array of callbacks.  The $code coderef can be any
53                                                    # subroutine that can return an array of arrayrefs that have the same structure
54                                                    # as SHOW FULL PRCESSLIST (see the defined constants above).  When it sees a
55                                                    # query complete, it turns the query into an "event" and calls the callbacks
56                                                    # with it.  It may find more than one event per call.  It also expects a $misc
57                                                    # hashref, which it will use to maintain state in the caller's namespace across
58                                                    # calls.  It expects this hashref to have the following:
59                                                    #
60                                                    #  my $misc = { prev => [], time => time(), etime => ? };
61                                                    #
62                                                    # Where etime is how long SHOW FULL PROCESSLIST took to execute.
63                                                    #
64                                                    # Each event is a hashref of attribute => value pairs like:
65                                                    #
66                                                    #  my $event = {
67                                                    #     ts  => '',    # Timestamp
68                                                    #     id  => '',    # Connection ID
69                                                    #     arg => '',    # Argument to the command
70                                                    #     other attributes...
71                                                    #  };
72                                                    #
73                                                    # Returns the number of events it finds.
74                                                    #
75                                                    # Technical details: keeps the previous run's processes in an array, gets the
76                                                    # current processes, and iterates through them, comparing prev and curr.  There
77                                                    # are several cases:
78                                                    #
79                                                    # 1) Connection is in curr, not in prev.  This is a new connection.  Calculate
80                                                    #    the time at which the statement must have started to execute.  Save this as
81                                                    #    a property of the event.
82                                                    # 2) Connection is in curr and prev, and the statement is the same, and the
83                                                    #    current time minus the start time of the event in prev matches the Time
84                                                    #    column of the curr.  This is the same statement we saw last time we looked
85                                                    #    at this connection, so do nothing.
86                                                    # 3) Same as 2) but the Info is different.  Then sometime between the prev
87                                                    #    and curr snapshots, that statement finished.  Assume it finished
88                                                    #    immediately after we saw it last time.  Fire the event handlers.
89                                                    #    TODO: if the statement is now running something else or Sleep for a certain
90                                                    #    time, then that shows the max end time of the last statement.  If it's 10s
91                                                    #    later and it's now been Sleep for 8s, then it might have ended up to 8s
92                                                    #    ago.
93                                                    # 4) Connection went away, or Info went NULL.  Same as 3).
94                                                    #
95                                                    # The default MySQL server has one-second granularity in the Time column.  This
96                                                    # means that a statement that starts at X.9 seconds shows 0 seconds for only 0.1
97                                                    # second.  A statement that starts at X.0 seconds shows 0 secs for a second, and
98                                                    # 1 second up until it has actually been running 2 seconds.  This makes it
99                                                    # tricky to determine when a statement has been re-issued.  Further, this
100                                                   # program and MySQL may have some clock skew.  Even if they are running on the
101                                                   # same machine, it's possible that at X.999999 seconds we get the time, and at
102                                                   # X+1.000001 seconds we get the snapshot from MySQL.  (Fortunately MySQL doesn't
103                                                   # re-evaluate now() for every process, or that would cause even more problems.)
104                                                   # And a query that's issued to MySQL may stall for any amount of time before
105                                                   # it's executed, making even more skew between the times.
106                                                   #
107                                                   # As a result of all this, this program assumes that the time it is passed in
108                                                   # $misc is measured consistently *after* calling SHOW PROCESSLIST, and is
109                                                   # measured with high precision (not second-level precision, which would
110                                                   # introduce an extra second of possible error in each direction).  That is a
111                                                   # convention that's up to the caller to follow.  One worst case is this:
112                                                   #
113                                                   #  * The processlist measures time at 100.01 and it's 100.
114                                                   #  * We measure the time.  It says 100.02.
115                                                   #  * A query was started at 90.  Processlist says Time=10.
116                                                   #  * We calculate that the query was started at 90.02.
117                                                   #  * Processlist measures it at 100.998 and it's 100.
118                                                   #  * We measure time again, it says 100.999.
119                                                   #  * Time has passed, but the Time column still says 10.
120                                                   #
121                                                   # Another:
122                                                   #
123                                                   #  * We get the processlist, then the time.
124                                                   #  * A second later we get the processlist, but it takes 2 sec to fetch.
125                                                   #  * We measure the time and it looks like 3 sec have passed, but ps says only
126                                                   #    one has passed.  (This is why $misc->{etime} is necessary).
127                                                   #
128                                                   # What should we do?  Well, the key thing to notice here is that a new statement
129                                                   # has started if a) the Time column actually decreases since we last saw the
130                                                   # process, or b) the Time column does not increase for 2 seconds, plus the etime
131                                                   # of the first and second measurements combined!
132                                                   #
133                                                   # The $code shouldn't return itself, e.g. if it's a PROCESSLIST you should
134                                                   # filter out $dbh->{mysql_thread_id}.
135                                                   #
136                                                   # TODO: unresolved issues are
137                                                   # 1) What about Lock_time?  It's unclear if a query starts at 100, unlocks at
138                                                   #    105 and completes at 110, is it 5s lock and 5s exec?  Or 5s lock, 10s exec?
139                                                   #    This code should match that behavior.
140                                                   # 2) What about splitting the difference?  If I see a query now with 0s, and one
141                                                   #    second later I look and see it's gone, should I split the middle and say it
142                                                   #    ran for .5s?
143                                                   # 3) I think user/host needs to do user/host/ip, really.  And actually, port
144                                                   #    will show up in the processlist -- make that a property too.
145                                                   # 4) It should put cmd => Query, cmd => Admin, or whatever
146                                                   sub parse_event {
147            9                    9           403      my ( $self, $code, $misc, @callbacks ) = @_;
148            9                                 29      my $num_events = 0;
149                                                   
150            9                                 32      my @curr = sort { $a->[ID] <=> $b->[ID] } @{$code->()};
      ***      0                                  0   
               9                                 32   
151   ***      9            50                  152      my @prev = @{$misc->{prev} ||= []};
               9                                 56   
152            9                                 25      my @new; # Will become next invocation's @prev
153            9                                 26      my ($curr, $prev); # Rows from each source
154                                                   
155   ***      9            33                   26      do {
      ***                   66                        
      ***                   66                        
156           10    100    100                  106         if ( !$curr && @curr ) {
157            8                                 19            MKDEBUG && _d('Fetching row from curr');
158            8                                 25            $curr = shift @curr;
159                                                         }
160   ***     10    100     66                   86         if ( !$prev && @prev ) {
161            4                                 11            MKDEBUG && _d('Fetching row from prev');
162            4                                 12            $prev = shift @prev;
163                                                         }
164   ***     10    100     66                   68         if ( $curr || $prev ) {
165                                                            # In each of the if/elses, something must be undef'ed to prevent
166                                                            # infinite looping.
167   ***      9    100     66                  182            if ( $curr && $prev && $curr->[ID] == $prev->[ID] ) {
                    100    100                        
      ***                   66                        
      ***                   66                        
      ***                   66                        
168            3                                  8               MKDEBUG && _d('$curr and $prev are the same cxn');
169                                                               # Or, if its start time seems to be after the start time of
170                                                               # the previously seen one, it's also a new query.
171   ***      3     50                          22               my $fudge = $curr->[TIME] =~ m/\D/ ? 0.001 : 1; # Micro-precision?
172            3                                  9               my $is_new = 0;
173   ***      3     50                          16               if ( $prev->[INFO] ) {
174   ***      3    100     66                   91                  if (!$curr->[INFO] || $prev->[INFO] ne $curr->[INFO]) {
      ***            50     33                        
      ***           100     33                        
      ***                   66                        
175                                                                     # This is a different query or a new query
176            1                                  9                     MKDEBUG && _d('$curr has a new query');
177            1                                  3                     $is_new = 1;
178                                                                  }
179                                                                  elsif (defined $curr->[TIME] && $curr->[TIME] < $prev->[TIME]) {
180   ***      0                                  0                     MKDEBUG && _d('$curr time is less than $prev time');
181   ***      0                                  0                     $is_new = 1;
182                                                                  }
183                                                                  elsif ( $curr->[INFO] && defined $curr->[TIME]
184                                                                     && $misc->{time} - $curr->[TIME] - $prev->[START]
185                                                                        - $prev->[ETIME] - $misc->{etime} > $fudge
186                                                                  ) {
187            1                                  2                     MKDEBUG && _d('$curr has same query that restarted');
188            1                                  3                     $is_new = 1;
189                                                                  }
190            3    100                          14                  if ( $is_new ) {
191            2                                 12                     fire_event( $prev, $misc->{time}, @callbacks );
192                                                                  }
193                                                               }
194            3    100                          44               if ( $curr->[INFO] ) {
195   ***      2    100     66                   23                  if ( $prev->[INFO] && !$is_new ) {
196            1                                  7                     MKDEBUG && _d('Pushing old history item back onto $prev');
197            1                                  8                     push @new, [ @$prev ];
198                                                                  }
199                                                                  else {
200            1                                  3                     MKDEBUG && _d('Pushing new history item onto $prev');
201            1                                 16                     push @new,
202                                                                        [ @$curr, int($misc->{time} - $curr->[TIME]),
203                                                                           $misc->{etime}, $misc->{time} ];
204                                                                  }
205                                                               }
206            3                                 62               $curr = $prev = undef; # Fetch another from each.
207                                                            }
208                                                            # The row in the prev doesn't exist in the curr.  Fire an event.
209                                                            elsif ( !$curr
210                                                                  || ( $curr && $prev && $curr->[ID] > $prev->[ID] )) {
211            1                                  3               MKDEBUG && _d('$curr is not in $prev');
212            1                                  6               fire_event( $prev, $misc->{time}, @callbacks );
213            1                                 24               $prev = undef;
214                                                            }
215                                                            # The row in curr isn't in prev; start a new event.
216                                                            else { # This else must be entered, to prevent infinite loops.
217            5                                 13               MKDEBUG && _d('$prev is not in $curr');
218   ***      5    100     66                   41               if ( $curr->[INFO] && defined $curr->[TIME] ) {
219            3                                  6                  MKDEBUG && _d('Pushing new history item onto $prev');
220            3                                 31                  push @new,
221                                                                     [ @$curr, int($misc->{time} - $curr->[TIME]),
222                                                                        $misc->{etime}, $misc->{time} ];
223                                                               }
224            5                                 97               $curr = undef; # No infinite loops.
225                                                            }
226                                                         }
227                                                      } while ( @curr || @prev || $curr || $prev );
228                                                   
229            9                                 31      @{$misc->{prev}} = @new;
               9                                 46   
230                                                   
231            9                                 39      return $num_events;
232                                                   }
233                                                   
234                                                   # The exec time of the query is the max of the time from the processlist, or the
235                                                   # time during which we've actually observed the query running.  In case two
236                                                   # back-to-back queries executed as the same one and we weren't able to tell them
237                                                   # apart, their time will add up, which is kind of what we want.
238                                                   sub fire_event {
239            3                    3            16      my ( $row, $time, @callbacks ) = @_;
240            3                                 12      my $Query_time = $row->[TIME];
241            3    100                          19      if ( $row->[TIME] < $time - $row->[FSEEN] ) {
242            1                                  4         $Query_time = $time - $row->[FSEEN];
243                                                      }
244            3                                136      my $event = {
245                                                         id         => $row->[ID],
246                                                         db         => $row->[DB],
247                                                         user       => $row->[USER],
248                                                         host       => $row->[HOST],
249                                                         arg        => $row->[INFO],
250                                                         bytes      => length($row->[INFO]),
251                                                         ts         => Transformers::ts($row->[START] + $row->[TIME]), # Query END time
252                                                         Query_time => $Query_time,
253                                                         Lock_time  => 0,               # TODO
254                                                      };
255            3                                 19      foreach my $callback ( @callbacks ) {
256   ***      3     50                          15         last unless $event = $callback->($event);
257                                                      }
258                                                   }
259                                                   
260                                                   # Accepts a PROCESSLIST and a specification of filters to use against it.
261                                                   # Returns queries that match the filters.  The standard process properties
262                                                   # are: Id, User, Host, db, Command, Time, State, Info.  These are used for
263                                                   # ignore and match.
264                                                   #
265                                                   # Possible find_spec are:
266                                                   #   * only_oldest  Match the oldest running query
267                                                   #   * busy_time    Match queries that have been Command=Query for longer than
268                                                   #                  this time
269                                                   #   * idle_time    Match queries that have been Command=Sleep for longer than
270                                                   #                  this time
271                                                   #   * ignore       A hashref of properties => regex patterns to ignore
272                                                   #   * match        A hashref of properties => regex patterns to match
273                                                   #
274                                                   sub find {
275            3                    3           236      my ( $self, $proclist, %find_spec ) = @_;
276            3                                  9      MKDEBUG && _d('find specs:', Dumper(\%find_spec));
277            3                                  8      my @matches;
278                                                      QUERY:
279            3                                 13      foreach my $query ( @$proclist ) {
280          123                                251         MKDEBUG && _d('Checking query', Dumper($query));
281          123                               9005         my $matched = 0;
282                                                   
283                                                         # Match special busy_time.
284   ***    123    100     50                  655         if ( $find_spec{busy_time} && ($query->{Command} || '') eq 'Query' ) {
                           100                        
285            4    100                          21            if ( $query->{Time} < $find_spec{busy_time} ) {
286            1                                  2               MKDEBUG && _d("Query isn't running long enough");
287            1                                  3               next QUERY;
288                                                            }
289            3                                  6            MKDEBUG && _d('Exceeds busy time');
290            3                                 10            $matched++;
291                                                         }
292                                                   
293                                                         # Match special idle_time.
294   ***    122    100     50                 2974         if ( $find_spec{idle_time} && ($query->{Command} || '') eq 'Sleep' ) {
                           100                        
295           23    100                         128            if ( $query->{Time} < $find_spec{idle_time} ) {
296           22                                 46               MKDEBUG && _d("Query isn't idle long enough");
297           22                                 67               next QUERY;
298                                                            }
299            1                                  4            MKDEBUG && _d('Exceeds idle time');
300            1                                  4            $matched++;
301                                                         }
302                                                   
303                                                         PROPERTY:
304          100                                353         foreach my $property ( qw(Id User Host db State Command Info) ) {
305          684                               1979            my $filter = "_find_match_$property";
306          684    100    100                 3457            if ( defined $find_spec{ignore}->{$property}
307                                                                 && $self->$filter($query, $find_spec{ignore}->{$property}) ) {
308            4                                  9               MKDEBUG && _d('Query matches ignore', $property, 'spec');
309            4                                 14               next QUERY;
310                                                            }
311          680    100                        3029            if ( defined $find_spec{match}->{$property} ) {
312            6    100                          31               if ( !$self->$filter($query, $find_spec{match}->{$property}) ) {
313            3                                  7                  MKDEBUG && _d('Query does not match', $property, 'spec');
314            3                                 10                  next QUERY;
315                                                               }
316            3                                  6               MKDEBUG && _d('Query matches', $property, 'spec');
317            3                                 10               $matched++;
318                                                            }
319                                                         }
320           93    100                         343         if ( $matched ) {
321            2                                  7            MKDEBUG && _d("Query matched one or more specs, adding");
322            2                                  6            push @matches, $query;
323            2                                 10            next QUERY;
324                                                         }
325           91                                251         MKDEBUG && _d('Query does not match any specs, ignoring');
326                                                      } # QUERY
327                                                   
328   ***      3    100     66                   26      if ( @matches && $find_spec{only_oldest} ) {
329            2                                 18         my ( $oldest ) = reverse sort { $a->{Time} <=> $b->{Time} } @matches;
      ***      0                                  0   
330            2                                  5         MKDEBUG && _d('Oldest query:', Dumper($oldest));
331            2                                 10         @matches = $oldest;
332                                                      }
333                                                   
334            3                                 38      return @matches;
335                                                   }
336                                                   
337                                                   sub _find_match_Id {
338            8                    8            30      my ( $self, $query, $property ) = @_;
339   ***      8            33                  129      return defined $property && defined $query->{Id} && $query->{Id} == $property;
      ***                   66                        
340                                                   }
341                                                   
342                                                   sub _find_match_User {
343            8                    8            30      my ( $self, $query, $property ) = @_;
344   ***      8            33                  138      return defined $property && defined $query->{User}
      ***                   66                        
345                                                         && $query->{User} =~ m/$property/;
346                                                   }
347                                                   
348                                                   sub _find_match_Host {
349   ***      0                    0             0      my ( $self, $query, $property ) = @_;
350   ***      0             0                    0      return defined $property && defined $query->{Host}
      ***                    0                        
351                                                         && $query->{Host} =~ m/$property/;
352                                                   }
353                                                   
354                                                   sub _find_match_db {
355   ***      0                    0             0      my ( $self, $query, $property ) = @_;
356   ***      0             0                    0      return defined $property && defined $query->{db}
      ***                    0                        
357                                                         && $query->{db} =~ m/$property/;
358                                                   }
359                                                   
360                                                   sub _find_match_State {
361            7                    7            26      my ( $self, $query, $property ) = @_;
362   ***      7            33                  123      return defined $property && defined $query->{State}
      ***                   66                        
363                                                         && $query->{State} =~ m/$property/;
364                                                   }
365                                                   
366                                                   sub _find_match_Command {
367           10                   10            39      my ( $self, $query, $property ) = @_;
368   ***     10            33                  164      return defined $property && defined $query->{Command}
      ***                   66                        
369                                                         && $query->{Command} =~ m/$property/;
370                                                   }
371                                                   
372                                                   sub _find_match_Info {
373            2                    2             7      my ( $self, $query, $property ) = @_;
374   ***      2            33                   35      return defined $property && defined $query->{Info}
      ***                   66                        
375                                                         && $query->{Info} =~ m/$property/;
376                                                   }
377                                                   
378                                                   sub _d {
379   ***      0                    0                    my ($package, undef, $line) = caller 0;
380   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
381   ***      0                                              map { defined $_ ? $_ : 'undef' }
382                                                           @_;
383   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
384                                                   }
385                                                   
386                                                   1;
387                                                   
388                                                   # ###########################################################################
389                                                   # End Processlist package
390                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
156          100      8      2   if (not $curr and @curr)
160          100      4      6   if (not $prev and @prev)
164          100      9      1   if ($curr or $prev)
167          100      3      6   if ($curr and $prev and $$curr[0] == $$prev[0]) { }
             100      1      5   elsif (not $curr or $curr and $prev and $$curr[0] > $$prev[0]) { }
171   ***     50      0      3   $$curr[5] =~ /\D/ ? :
173   ***     50      3      0   if ($$prev[7])
174          100      1      2   if (not $$curr[7] or $$prev[7] ne $$curr[7]) { }
      ***     50      0      2   elsif (defined $$curr[5] and $$curr[5] < $$prev[5]) { }
             100      1      1   elsif ($$curr[7] and defined $$curr[5] and $$misc{'time'} - $$curr[5] - $$prev[8] - $$prev[9] - $$misc{'etime'} > $fudge) { }
190          100      2      1   if ($is_new)
194          100      2      1   if ($$curr[7])
195          100      1      1   if ($$prev[7] and not $is_new) { }
218          100      3      2   if ($$curr[7] and defined $$curr[5])
241          100      1      2   if ($$row[5] < $time - $$row[10])
256   ***     50      0      3   unless $event = &$callback($event)
284          100      4    119   if ($find_spec{'busy_time'} and ($$query{'Command'} || '') eq 'Query')
285          100      1      3   if ($$query{'Time'} < $find_spec{'busy_time'})
294          100     23     99   if ($find_spec{'idle_time'} and ($$query{'Command'} || '') eq 'Sleep')
295          100     22      1   if ($$query{'Time'} < $find_spec{'idle_time'})
306          100      4    680   if (defined $find_spec{'ignore'}{$property} and $self->$filter($query, $find_spec{'ignore'}{$property}))
311          100      6    674   if (defined $find_spec{'match'}{$property})
312          100      3      3   if (not $self->$filter($query, $find_spec{'match'}{$property}))
320          100      2     91   if ($matched)
328          100      2      1   if (@matches and $find_spec{'only_oldest'})
380   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
156          100      1      1      8   not $curr and @curr
160   ***     66      0      6      4   not $prev and @prev
167   ***     66      0      5      4   $curr and $prev
             100      5      1      3   $curr and $prev and $$curr[0] == $$prev[0]
      ***     66      0      5      1   $curr and $prev
      ***     66      5      0      1   $curr and $prev and $$curr[0] > $$prev[0]
174   ***     33      0      2      0   defined $$curr[5] and $$curr[5] < $$prev[5]
      ***     33      0      0      2   $$curr[7] and defined $$curr[5]
      ***     66      0      1      1   $$curr[7] and defined $$curr[5] and $$misc{'time'} - $$curr[5] - $$prev[8] - $$prev[9] - $$misc{'etime'} > $fudge
195   ***     66      0      1      1   $$prev[7] and not $is_new
218   ***     66      2      0      3   $$curr[7] and defined $$curr[5]
284          100    113      6      4   $find_spec{'busy_time'} and ($$query{'Command'} || '') eq 'Query'
294          100      9     90     23   $find_spec{'idle_time'} and ($$query{'Command'} || '') eq 'Sleep'
306          100    655     25      4   defined $find_spec{'ignore'}{$property} and $self->$filter($query, $find_spec{'ignore'}{$property})
328   ***     66      1      0      2   @matches and $find_spec{'only_oldest'}
339   ***     33      0      0      8   defined $property && defined $$query{'Id'}
      ***     66      0      7      1   defined $property && defined $$query{'Id'} && $$query{'Id'} == $property
344   ***     33      0      0      8   defined $property && defined $$query{'User'}
      ***     66      0      7      1   defined $property && defined $$query{'User'} && $$query{'User'} =~ /$property/
350   ***      0      0      0      0   defined $property && defined $$query{'Host'}
      ***      0      0      0      0   defined $property && defined $$query{'Host'} && $$query{'Host'} =~ /$property/
356   ***      0      0      0      0   defined $property && defined $$query{'db'}
      ***      0      0      0      0   defined $property && defined $$query{'db'} && $$query{'db'} =~ /$property/
362   ***     33      0      0      7   defined $property && defined $$query{'State'}
      ***     66      0      6      1   defined $property && defined $$query{'State'} && $$query{'State'} =~ /$property/
368   ***     33      0      0     10   defined $property && defined $$query{'Command'}
      ***     66      0      7      3   defined $property && defined $$query{'Command'} && $$query{'Command'} =~ /$property/
374   ***     33      0      0      2   defined $property && defined $$query{'Info'}
      ***     66      0      1      1   defined $property && defined $$query{'Info'} && $$query{'Info'} =~ /$property/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
151   ***     50      9      0   $$misc{'prev'} ||= []
284   ***     50     10      0   $$query{'Command'} || ''
294   ***     50    113      0   $$query{'Command'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
155   ***     33      0      0     10   @curr or @prev
      ***     66      0      1      9   @curr or @prev or $curr
      ***     66      1      0      9   @curr or @prev or $curr or $prev
164   ***     66      9      0      1   $curr or $prev
167   ***     66      0      1      5   not $curr or $curr and $prev and $$curr[0] > $$prev[0]
174   ***     66      1      0      2   not $$curr[7] or $$prev[7] ne $$curr[7]


Covered Subroutines
-------------------

Subroutine          Count Location                                          
------------------- ----- --------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:22 
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:23 
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:24 
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:26 
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:31 
BEGIN                   1 /home/daniel/dev/maatkit/common/Processlist.pm:44 
_find_match_Command    10 /home/daniel/dev/maatkit/common/Processlist.pm:367
_find_match_Id          8 /home/daniel/dev/maatkit/common/Processlist.pm:338
_find_match_Info        2 /home/daniel/dev/maatkit/common/Processlist.pm:373
_find_match_State       7 /home/daniel/dev/maatkit/common/Processlist.pm:361
_find_match_User        8 /home/daniel/dev/maatkit/common/Processlist.pm:343
find                    3 /home/daniel/dev/maatkit/common/Processlist.pm:275
fire_event              3 /home/daniel/dev/maatkit/common/Processlist.pm:239
new                     3 /home/daniel/dev/maatkit/common/Processlist.pm:47 
parse_event             9 /home/daniel/dev/maatkit/common/Processlist.pm:147

Uncovered Subroutines
---------------------

Subroutine          Count Location                                          
------------------- ----- --------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/Processlist.pm:379
_find_match_Host        0 /home/daniel/dev/maatkit/common/Processlist.pm:349
_find_match_db          0 /home/daniel/dev/maatkit/common/Processlist.pm:355


