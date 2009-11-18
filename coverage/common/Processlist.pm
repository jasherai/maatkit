---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/Processlist.pm   89.3   85.0   56.6   84.2    n/a  100.0   78.2
Total                          89.3   85.0   56.6   84.2    n/a  100.0   78.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          Processlist.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Nov 18 18:44:37 2009
Finish:       Wed Nov 18 18:44:38 2009

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
               1                                  3   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
25                                                    
26             1                    1             7   use Data::Dumper;
               1                                  2   
               1                                  7   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
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
44             1                    1             7   };
               1                                  3   
45                                                    
46                                                    sub new {
47             3                    3            28      my ( $class, %args ) = @_;
48             3                                 26      my $self = {
49                                                          prev_rows => [],
50                                                          new_rows  => [],
51                                                          curr_row  => undef,
52                                                          prev_row  => undef,
53                                                       };
54             3                                 23      return bless $self, $class;
55                                                    }
56                                                    
57                                                    # This method accepts a $code coderef, which is typically going to return SHOW
58                                                    # FULL PROCESSLIST, and an array of callbacks.  The $code coderef can be any
59                                                    # subroutine that can return an array of arrayrefs that have the same structure
60                                                    # as SHOW FULL PRCESSLIST (see the defined constants above).  When it sees a
61                                                    # query complete, it turns the query into an "event" and calls the callbacks
62                                                    # with it.  It may find more than one event per call.  It also expects a $misc
63                                                    # hashref, which it will use to maintain state in the caller's namespace across
64                                                    # calls.  It expects this hashref to have the following:
65                                                    #
66                                                    #  my $misc = { prev => [], time => time(), etime => ? };
67                                                    #
68                                                    # Where etime is how long SHOW FULL PROCESSLIST took to execute.
69                                                    #
70                                                    # Each event is a hashref of attribute => value pairs like:
71                                                    #
72                                                    #  my $event = {
73                                                    #     ts  => '',    # Timestamp
74                                                    #     id  => '',    # Connection ID
75                                                    #     arg => '',    # Argument to the command
76                                                    #     other attributes...
77                                                    #  };
78                                                    #
79                                                    # Returns the number of events it finds.
80                                                    #
81                                                    # Technical details: keeps the previous run's processes in an array, gets the
82                                                    # current processes, and iterates through them, comparing prev and curr.  There
83                                                    # are several cases:
84                                                    #
85                                                    # 1) Connection is in curr, not in prev.  This is a new connection.  Calculate
86                                                    #    the time at which the statement must have started to execute.  Save this as
87                                                    #    a property of the event.
88                                                    # 2) Connection is in curr and prev, and the statement is the same, and the
89                                                    #    current time minus the start time of the event in prev matches the Time
90                                                    #    column of the curr.  This is the same statement we saw last time we looked
91                                                    #    at this connection, so do nothing.
92                                                    # 3) Same as 2) but the Info is different.  Then sometime between the prev
93                                                    #    and curr snapshots, that statement finished.  Assume it finished
94                                                    #    immediately after we saw it last time.  Fire the event handlers.
95                                                    #    TODO: if the statement is now running something else or Sleep for a certain
96                                                    #    time, then that shows the max end time of the last statement.  If it's 10s
97                                                    #    later and it's now been Sleep for 8s, then it might have ended up to 8s
98                                                    #    ago.
99                                                    # 4) Connection went away, or Info went NULL.  Same as 3).
100                                                   #
101                                                   # The default MySQL server has one-second granularity in the Time column.  This
102                                                   # means that a statement that starts at X.9 seconds shows 0 seconds for only 0.1
103                                                   # second.  A statement that starts at X.0 seconds shows 0 secs for a second, and
104                                                   # 1 second up until it has actually been running 2 seconds.  This makes it
105                                                   # tricky to determine when a statement has been re-issued.  Further, this
106                                                   # program and MySQL may have some clock skew.  Even if they are running on the
107                                                   # same machine, it's possible that at X.999999 seconds we get the time, and at
108                                                   # X+1.000001 seconds we get the snapshot from MySQL.  (Fortunately MySQL doesn't
109                                                   # re-evaluate now() for every process, or that would cause even more problems.)
110                                                   # And a query that's issued to MySQL may stall for any amount of time before
111                                                   # it's executed, making even more skew between the times.
112                                                   #
113                                                   # As a result of all this, this program assumes that the time it is passed in
114                                                   # $misc is measured consistently *after* calling SHOW PROCESSLIST, and is
115                                                   # measured with high precision (not second-level precision, which would
116                                                   # introduce an extra second of possible error in each direction).  That is a
117                                                   # convention that's up to the caller to follow.  One worst case is this:
118                                                   #
119                                                   #  * The processlist measures time at 100.01 and it's 100.
120                                                   #  * We measure the time.  It says 100.02.
121                                                   #  * A query was started at 90.  Processlist says Time=10.
122                                                   #  * We calculate that the query was started at 90.02.
123                                                   #  * Processlist measures it at 100.998 and it's 100.
124                                                   #  * We measure time again, it says 100.999.
125                                                   #  * Time has passed, but the Time column still says 10.
126                                                   #
127                                                   # Another:
128                                                   #
129                                                   #  * We get the processlist, then the time.
130                                                   #  * A second later we get the processlist, but it takes 2 sec to fetch.
131                                                   #  * We measure the time and it looks like 3 sec have passed, but ps says only
132                                                   #    one has passed.  (This is why $misc->{etime} is necessary).
133                                                   #
134                                                   # What should we do?  Well, the key thing to notice here is that a new statement
135                                                   # has started if a) the Time column actually decreases since we last saw the
136                                                   # process, or b) the Time column does not increase for 2 seconds, plus the etime
137                                                   # of the first and second measurements combined!
138                                                   #
139                                                   # The $code shouldn't return itself, e.g. if it's a PROCESSLIST you should
140                                                   # filter out $dbh->{mysql_thread_id}.
141                                                   #
142                                                   # TODO: unresolved issues are
143                                                   # 1) What about Lock_time?  It's unclear if a query starts at 100, unlocks at
144                                                   #    105 and completes at 110, is it 5s lock and 5s exec?  Or 5s lock, 10s exec?
145                                                   #    This code should match that behavior.
146                                                   # 2) What about splitting the difference?  If I see a query now with 0s, and one
147                                                   #    second later I look and see it's gone, should I split the middle and say it
148                                                   #    ran for .5s?
149                                                   # 3) I think user/host needs to do user/host/ip, really.  And actually, port
150                                                   #    will show up in the processlist -- make that a property too.
151                                                   # 4) It should put cmd => Query, cmd => Admin, or whatever
152                                                   sub parse_event {
153           12                   12           317      my ( $self, %args ) = @_;
154           12                                 44      my @required_args = qw(misc);
155           12                                 37      foreach my $arg ( @required_args ) {
156   ***     12     50                          65         die "I need a $arg argument" unless $args{$arg};
157                                                      }
158           12                                 54      my ($misc) = @args{@required_args};
159                                                   
160                                                      # The code callback should return an arrayref of events from the proclist.
161           12                                 42      my $code = $misc->{code};
162   ***     12     50                          44      die "I need a code arg to misc" unless $code;
163                                                   
164                                                      # If there are current rows from the last time we were called, continue
165                                                      # using/parsing them.  Else, try to get new rows from $code.  Else, the
166                                                      # proecesslist is probably empty so do nothing.
167           12                                 30      my @curr;
168   ***     12     50                          46      if ( $self->{curr_rows} ) {
169   ***      0                                  0         MKDEBUG && _d('Current rows from last call');
170   ***      0                                  0         @curr = @{$self->{curr_rows}};
      ***      0                                  0   
171                                                      }
172                                                      else {
173           12                                 43         my $rows = $code->();
174           12    100    100                  172         if ( $rows && scalar @$rows ) {
175            8                                 17            MKDEBUG && _d('Got new current rows');
176            8                                 50            @curr = sort { $a->[ID] <=> $b->[ID] } @$rows;
      ***      0                                  0   
177                                                         }
178                                                         else {
179            4                                 14            MKDEBUG && _d('No current rows');
180                                                         }
181                                                      }
182                                                   
183   ***     12            50                   42      my @prev = @{$self->{prev_rows} ||= []};
              12                                 65   
184   ***     12            50                   31      my @new  = @{$self->{new_rows}  ||= []};; # Becomes next invocation's @prev
              12                                 62   
185           12                                 37      my $curr = $self->{curr_row}; # Rows from each source
186           12                                 37      my $prev = $self->{prev_row};
187           12                                 26      my $event;
188                                                   
189           12                                 26      MKDEBUG && _d('Rows:', scalar @prev, 'prev,', scalar @curr, 'current');
190                                                   
191           12    100    100                  124      if ( !$curr && @curr ) {
192            8                                 18         MKDEBUG && _d('Fetching row from curr');
193            8                                 25         $curr = shift @curr;
194                                                      }
195   ***     12    100     66                   92      if ( !$prev && @prev ) {
196            4                                 10         MKDEBUG && _d('Fetching row from prev');
197            4                                 11         $prev = shift @prev;
198                                                      }
199   ***     12    100     66                   63      if ( $curr || $prev ) {
200                                                         # In each of the if/elses, something must be undef'ed to prevent
201                                                         # infinite looping.
202   ***      9    100     66                  170         if ( $curr && $prev && $curr->[ID] == $prev->[ID] ) {
                    100    100                        
      ***                   66                        
      ***                   66                        
      ***                   66                        
203            3                                  7            MKDEBUG && _d('$curr and $prev are the same cxn');
204                                                            # Or, if its start time seems to be after the start time of
205                                                            # the previously seen one, it's also a new query.
206   ***      3     50                          18            my $fudge = $curr->[TIME] =~ m/\D/ ? 0.001 : 1; # Micro-precision?
207            3                                  9            my $is_new = 0;
208   ***      3     50                          14            if ( $prev->[INFO] ) {
209   ***      3    100     66                   72               if (!$curr->[INFO] || $prev->[INFO] ne $curr->[INFO]) {
      ***            50     33                        
      ***           100     33                        
      ***                   66                        
210                                                                  # This is a different query or a new query
211            1                                  2                  MKDEBUG && _d('$curr has a new query');
212            1                                 14                  $is_new = 1;
213                                                               }
214                                                               elsif (defined $curr->[TIME] && $curr->[TIME] < $prev->[TIME]) {
215   ***      0                                  0                  MKDEBUG && _d('$curr time is less than $prev time');
216   ***      0                                  0                  $is_new = 1;
217                                                               }
218                                                               elsif ( $curr->[INFO] && defined $curr->[TIME]
219                                                                       && $misc->{time} - $curr->[TIME] - $prev->[START]
220                                                                          - $prev->[ETIME] - $misc->{etime} > $fudge
221                                                               ) {
222            1                                  2                  MKDEBUG && _d('$curr has same query that restarted');
223            1                                  3                  $is_new = 1;
224                                                               }
225            3    100                          13               if ( $is_new ) {
226            2                                 10                  $event = $self->make_event($prev, $misc->{time});
227                                                               }
228                                                            }
229            3    100                          18            if ( $curr->[INFO] ) {
230   ***      2    100     66                   19               if ( $prev->[INFO] && !$is_new ) {
231            1                                  3                  MKDEBUG && _d('Pushing old history item back onto $prev');
232            1                                  7                  push @new, [ @$prev ];
233                                                               }
234                                                               else {
235            1                                  2                  MKDEBUG && _d('Pushing new history item onto $prev');
236            1                                 10                  push @new,
237                                                                     [ @$curr, int($misc->{time} - $curr->[TIME]),
238                                                                        $misc->{etime}, $misc->{time} ];
239                                                               }
240                                                            }
241            3                                 11            $curr = $prev = undef; # Fetch another from each.
242                                                         }
243                                                         # The row in the prev doesn't exist in the curr.  Fire an event.
244                                                         elsif ( !$curr
245                                                                 || ($curr && $prev && $curr->[ID] > $prev->[ID]) ) {
246            1                                  2            MKDEBUG && _d('$curr is not in $prev');
247            1                                  9            $event = $self->make_event($prev, $misc->{time});
248            1                                  3            $prev = undef;
249                                                         }
250                                                         # The row in curr isn't in prev; start a new event.
251                                                         else { # This else must be entered, to prevent infinite loops.
252            5                                 11            MKDEBUG && _d('$prev is not in $curr');
253   ***      5    100     66                   43            if ( $curr->[INFO] && defined $curr->[TIME] ) {
254            3                                  8               MKDEBUG && _d('Pushing new history item onto $prev');
255            3                                 29               push @new,
256                                                                  [ @$curr, int($misc->{time} - $curr->[TIME]),
257                                                                     $misc->{etime}, $misc->{time} ];
258                                                            }
259            5                                 15            $curr = undef; # No infinite loops.
260                                                         }
261                                                      }
262                                                   
263           12                                 51      $self->{prev_rows} = \@new;
264           12                                 48      $self->{prev_row}  = $prev;
265   ***     12     50                          59      $self->{curr_rows} = scalar @curr ? \@curr : undef;
266           12                                 37      $self->{curr_row}  = $curr;
267                                                   
268           12                                 61      return $event;
269                                                   }
270                                                   
271                                                   # The exec time of the query is the max of the time from the processlist, or the
272                                                   # time during which we've actually observed the query running.  In case two
273                                                   # back-to-back queries executed as the same one and we weren't able to tell them
274                                                   # apart, their time will add up, which is kind of what we want.
275                                                   sub make_event {
276            3                    3            16      my ( $self, $row, $time ) = @_;
277            3                                 11      my $Query_time = $row->[TIME];
278            3    100                          18      if ( $row->[TIME] < $time - $row->[FSEEN] ) {
279            1                                  4         $Query_time = $time - $row->[FSEEN];
280                                                      }
281            3                                 34      my $event = {
282                                                         id         => $row->[ID],
283                                                         db         => $row->[DB],
284                                                         user       => $row->[USER],
285                                                         host       => $row->[HOST],
286                                                         arg        => $row->[INFO],
287                                                         bytes      => length($row->[INFO]),
288                                                         ts         => Transformers::ts($row->[START] + $row->[TIME]), # Query END time
289                                                         Query_time => $Query_time,
290                                                         Lock_time  => 0,               # TODO
291                                                      };
292            3                                  9      MKDEBUG && _d('Properties of event:', Dumper($event));
293            3                                 11      return $event;
294                                                   }
295                                                   
296                                                   sub _get_rows {
297            8                    8            66      my ( $self ) = @_;
298            8                                 28      my %rows = map { $_ => $self->{$_} }
              32                                153   
299                                                         qw(prev_rows new_rows curr_row prev_row);
300            8                                 87      return \%rows;
301                                                   }
302                                                   
303                                                   # Accepts a PROCESSLIST and a specification of filters to use against it.
304                                                   # Returns queries that match the filters.  The standard process properties
305                                                   # are: Id, User, Host, db, Command, Time, State, Info.  These are used for
306                                                   # ignore and match.
307                                                   #
308                                                   # Possible find_spec are:
309                                                   #   * only_oldest  Match the oldest running query
310                                                   #   * busy_time    Match queries that have been Command=Query for longer than
311                                                   #                  this time
312                                                   #   * idle_time    Match queries that have been Command=Sleep for longer than
313                                                   #                  this time
314                                                   #   * ignore       A hashref of properties => regex patterns to ignore
315                                                   #   * match        A hashref of properties => regex patterns to match
316                                                   #
317                                                   sub find {
318            3                    3           165      my ( $self, $proclist, %find_spec ) = @_;
319            3                                  9      MKDEBUG && _d('find specs:', Dumper(\%find_spec));
320            3                                  8      my @matches;
321                                                      QUERY:
322            3                                 12      foreach my $query ( @$proclist ) {
323          123                                242         MKDEBUG && _d('Checking query', Dumper($query));
324          123                                309         my $matched = 0;
325                                                   
326                                                         # Match special busy_time.
327   ***    123    100     50                  643         if ( $find_spec{busy_time} && ($query->{Command} || '') eq 'Query' ) {
                           100                        
328            4    100                          21            if ( $query->{Time} < $find_spec{busy_time} ) {
329            1                                  6               MKDEBUG && _d("Query isn't running long enough");
330            1                                  4               next QUERY;
331                                                            }
332            3                                  7            MKDEBUG && _d('Exceeds busy time');
333            3                                  9            $matched++;
334                                                         }
335                                                   
336                                                         # Match special idle_time.
337   ***    122    100     50                 1143         if ( $find_spec{idle_time} && ($query->{Command} || '') eq 'Sleep' ) {
                           100                        
338           23    100                         114            if ( $query->{Time} < $find_spec{idle_time} ) {
339           22                                 45               MKDEBUG && _d("Query isn't idle long enough");
340           22                                 62               next QUERY;
341                                                            }
342            1                                  3            MKDEBUG && _d('Exceeds idle time');
343            1                                  3            $matched++;
344                                                         }
345                                                   
346                                                         PROPERTY:
347          100                                344         foreach my $property ( qw(Id User Host db State Command Info) ) {
348          684                               2059            my $filter = "_find_match_$property";
349          684    100    100                 3506            if ( defined $find_spec{ignore}->{$property}
350                                                                 && $self->$filter($query, $find_spec{ignore}->{$property}) ) {
351            4                                  9               MKDEBUG && _d('Query matches ignore', $property, 'spec');
352            4                                 14               next QUERY;
353                                                            }
354          680    100                        3135            if ( defined $find_spec{match}->{$property} ) {
355            6    100                          35               if ( !$self->$filter($query, $find_spec{match}->{$property}) ) {
356            3                                  7                  MKDEBUG && _d('Query does not match', $property, 'spec');
357            3                                 11                  next QUERY;
358                                                               }
359            3                                  9               MKDEBUG && _d('Query matches', $property, 'spec');
360            3                                  9               $matched++;
361                                                            }
362                                                         }
363           93    100                         323         if ( $matched ) {
364            2                                  5            MKDEBUG && _d("Query matched one or more specs, adding");
365            2                                  6            push @matches, $query;
366            2                                  8            next QUERY;
367                                                         }
368           91                                234         MKDEBUG && _d('Query does not match any specs, ignoring');
369                                                      } # QUERY
370                                                   
371   ***      3    100     66                   32      if ( @matches && $find_spec{only_oldest} ) {
372            2                                 15         my ( $oldest ) = reverse sort { $a->{Time} <=> $b->{Time} } @matches;
      ***      0                                  0   
373            2                                  4         MKDEBUG && _d('Oldest query:', Dumper($oldest));
374            2                                  9         @matches = $oldest;
375                                                      }
376                                                   
377            3                                 32      return @matches;
378                                                   }
379                                                   
380                                                   sub _find_match_Id {
381            8                    8            30      my ( $self, $query, $property ) = @_;
382   ***      8            33                  133      return defined $property && defined $query->{Id} && $query->{Id} == $property;
      ***                   66                        
383                                                   }
384                                                   
385                                                   sub _find_match_User {
386            8                    8            29      my ( $self, $query, $property ) = @_;
387   ***      8            33                  136      return defined $property && defined $query->{User}
      ***                   66                        
388                                                         && $query->{User} =~ m/$property/;
389                                                   }
390                                                   
391                                                   sub _find_match_Host {
392   ***      0                    0             0      my ( $self, $query, $property ) = @_;
393   ***      0             0                    0      return defined $property && defined $query->{Host}
      ***                    0                        
394                                                         && $query->{Host} =~ m/$property/;
395                                                   }
396                                                   
397                                                   sub _find_match_db {
398   ***      0                    0             0      my ( $self, $query, $property ) = @_;
399   ***      0             0                    0      return defined $property && defined $query->{db}
      ***                    0                        
400                                                         && $query->{db} =~ m/$property/;
401                                                   }
402                                                   
403                                                   sub _find_match_State {
404            7                    7            28      my ( $self, $query, $property ) = @_;
405   ***      7            33                  115      return defined $property && defined $query->{State}
      ***                   66                        
406                                                         && $query->{State} =~ m/$property/;
407                                                   }
408                                                   
409                                                   sub _find_match_Command {
410           10                   10            40      my ( $self, $query, $property ) = @_;
411   ***     10            33                  171      return defined $property && defined $query->{Command}
      ***                   66                        
412                                                         && $query->{Command} =~ m/$property/;
413                                                   }
414                                                   
415                                                   sub _find_match_Info {
416            2                    2             8      my ( $self, $query, $property ) = @_;
417   ***      2            33                   35      return defined $property && defined $query->{Info}
      ***                   66                        
418                                                         && $query->{Info} =~ m/$property/;
419                                                   }
420                                                   
421                                                   sub _d {
422   ***      0                    0                    my ($package, undef, $line) = caller 0;
423   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
424   ***      0                                              map { defined $_ ? $_ : 'undef' }
425                                                           @_;
426   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
427                                                   }
428                                                   
429                                                   1;
430                                                   
431                                                   # ###########################################################################
432                                                   # End Processlist package
433                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
156   ***     50      0     12   unless $args{$arg}
162   ***     50      0     12   unless $code
168   ***     50      0     12   if ($$self{'curr_rows'}) { }
174          100      8      4   if ($rows and scalar @$rows) { }
191          100      8      4   if (not $curr and @curr)
195          100      4      8   if (not $prev and @prev)
199          100      9      3   if ($curr or $prev)
202          100      3      6   if ($curr and $prev and $$curr[0] == $$prev[0]) { }
             100      1      5   elsif (not $curr or $curr and $prev and $$curr[0] > $$prev[0]) { }
206   ***     50      0      3   $$curr[5] =~ /\D/ ? :
208   ***     50      3      0   if ($$prev[7])
209          100      1      2   if (not $$curr[7] or $$prev[7] ne $$curr[7]) { }
      ***     50      0      2   elsif (defined $$curr[5] and $$curr[5] < $$prev[5]) { }
             100      1      1   elsif ($$curr[7] and defined $$curr[5] and $$misc{'time'} - $$curr[5] - $$prev[8] - $$prev[9] - $$misc{'etime'} > $fudge) { }
225          100      2      1   if ($is_new)
229          100      2      1   if ($$curr[7])
230          100      1      1   if ($$prev[7] and not $is_new) { }
253          100      3      2   if ($$curr[7] and defined $$curr[5])
265   ***     50      0     12   scalar @curr ? :
278          100      1      2   if ($$row[5] < $time - $$row[10])
327          100      4    119   if ($find_spec{'busy_time'} and ($$query{'Command'} || '') eq 'Query')
328          100      1      3   if ($$query{'Time'} < $find_spec{'busy_time'})
337          100     23     99   if ($find_spec{'idle_time'} and ($$query{'Command'} || '') eq 'Sleep')
338          100     22      1   if ($$query{'Time'} < $find_spec{'idle_time'})
349          100      4    680   if (defined $find_spec{'ignore'}{$property} and $self->$filter($query, $find_spec{'ignore'}{$property}))
354          100      6    674   if (defined $find_spec{'match'}{$property})
355          100      3      3   if (not $self->$filter($query, $find_spec{'match'}{$property}))
363          100      2     91   if ($matched)
371          100      2      1   if (@matches and $find_spec{'only_oldest'})
423   ***      0      0      0   defined $_ ? :


Conditions
----------

and 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
174          100      3      9   $rows and scalar @$rows

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
191          100      1      3      8   not $curr and @curr
195   ***     66      0      8      4   not $prev and @prev
202   ***     66      0      5      4   $curr and $prev
             100      5      1      3   $curr and $prev and $$curr[0] == $$prev[0]
      ***     66      0      5      1   $curr and $prev
      ***     66      5      0      1   $curr and $prev and $$curr[0] > $$prev[0]
209   ***     33      0      2      0   defined $$curr[5] and $$curr[5] < $$prev[5]
      ***     33      0      0      2   $$curr[7] and defined $$curr[5]
      ***     66      0      1      1   $$curr[7] and defined $$curr[5] and $$misc{'time'} - $$curr[5] - $$prev[8] - $$prev[9] - $$misc{'etime'} > $fudge
230   ***     66      0      1      1   $$prev[7] and not $is_new
253   ***     66      2      0      3   $$curr[7] and defined $$curr[5]
327          100    113      6      4   $find_spec{'busy_time'} and ($$query{'Command'} || '') eq 'Query'
337          100      9     90     23   $find_spec{'idle_time'} and ($$query{'Command'} || '') eq 'Sleep'
349          100    655     25      4   defined $find_spec{'ignore'}{$property} and $self->$filter($query, $find_spec{'ignore'}{$property})
371   ***     66      1      0      2   @matches and $find_spec{'only_oldest'}
382   ***     33      0      0      8   defined $property && defined $$query{'Id'}
      ***     66      0      7      1   defined $property && defined $$query{'Id'} && $$query{'Id'} == $property
387   ***     33      0      0      8   defined $property && defined $$query{'User'}
      ***     66      0      7      1   defined $property && defined $$query{'User'} && $$query{'User'} =~ /$property/
393   ***      0      0      0      0   defined $property && defined $$query{'Host'}
      ***      0      0      0      0   defined $property && defined $$query{'Host'} && $$query{'Host'} =~ /$property/
399   ***      0      0      0      0   defined $property && defined $$query{'db'}
      ***      0      0      0      0   defined $property && defined $$query{'db'} && $$query{'db'} =~ /$property/
405   ***     33      0      0      7   defined $property && defined $$query{'State'}
      ***     66      0      6      1   defined $property && defined $$query{'State'} && $$query{'State'} =~ /$property/
411   ***     33      0      0     10   defined $property && defined $$query{'Command'}
      ***     66      0      7      3   defined $property && defined $$query{'Command'} && $$query{'Command'} =~ /$property/
417   ***     33      0      0      2   defined $property && defined $$query{'Info'}
      ***     66      0      1      1   defined $property && defined $$query{'Info'} && $$query{'Info'} =~ /$property/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
183   ***     50     12      0   $$self{'prev_rows'} ||= []
184   ***     50     12      0   $$self{'new_rows'} ||= []
327   ***     50     10      0   $$query{'Command'} || ''
337   ***     50    113      0   $$query{'Command'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
199   ***     66      9      0      3   $curr or $prev
202   ***     66      0      1      5   not $curr or $curr and $prev and $$curr[0] > $$prev[0]
209   ***     66      1      0      2   not $$curr[7] or $$prev[7] ne $$curr[7]


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
_find_match_Command    10 /home/daniel/dev/maatkit/common/Processlist.pm:410
_find_match_Id          8 /home/daniel/dev/maatkit/common/Processlist.pm:381
_find_match_Info        2 /home/daniel/dev/maatkit/common/Processlist.pm:416
_find_match_State       7 /home/daniel/dev/maatkit/common/Processlist.pm:404
_find_match_User        8 /home/daniel/dev/maatkit/common/Processlist.pm:386
_get_rows               8 /home/daniel/dev/maatkit/common/Processlist.pm:297
find                    3 /home/daniel/dev/maatkit/common/Processlist.pm:318
make_event              3 /home/daniel/dev/maatkit/common/Processlist.pm:276
new                     3 /home/daniel/dev/maatkit/common/Processlist.pm:47 
parse_event            12 /home/daniel/dev/maatkit/common/Processlist.pm:153

Uncovered Subroutines
---------------------

Subroutine          Count Location                                          
------------------- ----- --------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/Processlist.pm:422
_find_match_Host        0 /home/daniel/dev/maatkit/common/Processlist.pm:392
_find_match_db          0 /home/daniel/dev/maatkit/common/Processlist.pm:398


