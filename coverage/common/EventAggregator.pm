---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/EventAggregator.pm   97.1   78.7   82.4   96.6    n/a  100.0   90.2
Total                          97.1   78.7   82.4   96.6    n/a  100.0   90.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          EventAggregator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:01:46 2009
Finish:       Sat Aug 29 15:01:54 2009

/home/daniel/dev/maatkit/common/EventAggregator.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2009 Percona Inc.
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
18                                                    # EventAggregator package $Revision: 4462 $
19                                                    # ###########################################################################
20                                                    package EventAggregator;
21                                                    
22             1                    1             7   use strict;
               1                                  3   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  5   
25                                                    
26                                                    # ###########################################################################
27                                                    # Set up some constants for bucketing values.  It is impossible to keep all
28                                                    # values seen in memory, but putting them into logarithmically scaled buckets
29                                                    # and just incrementing the bucket each time works, although it is imprecise.
30                                                    # See http://code.google.com/p/maatkit/wiki/EventAggregatorInternals.
31                                                    # ###########################################################################
32             1                    1             7   use constant MKDEBUG      => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
33             1                    1             6   use constant BUCK_SIZE    => 1.05;
               1                                  6   
               1                                  5   
34             1                    1             5   use constant BASE_LOG     => log(BUCK_SIZE);
               1                                  3   
               1                                  4   
35             1                    1             6   use constant BASE_OFFSET  => abs(1 - log(0.000001) / BASE_LOG); # 284.1617969
               1                                  2   
               1                                  5   
36             1                    1             6   use constant NUM_BUCK     => 1000;
               1                                  2   
               1                                  5   
37             1                    1             6   use constant MIN_BUCK     => .000001;
               1                                  2   
               1                                  4   
38                                                    
39                                                    # Used to pre-initialize {all} arrayrefs for event attribs in make_handler.
40                                                    our @buckets  = map { 0 } (0..NUM_BUCK-1);
41                                                    
42                                                    # Used in buckets_of() to map buckets of log10 to log1.05 buckets.
43                                                    my @buck_vals = map { bucket_value($_); } (0..NUM_BUCK-1);
44                                                    
45                                                    # The best way to see how to use this is to look at the .t file.
46                                                    #
47                                                    # %args is a hash containing:
48                                                    # groupby      The name of the property to group/aggregate by.
49                                                    # attributes   An optional hashref.  Each key is the name of an element to
50                                                    #              aggregate.  And the values of those elements are arrayrefs of the
51                                                    #              values to pull from the hashref, with any second or subsequent
52                                                    #              values being fallbacks for the first in case it's not defined.
53                                                    #              If no attributes are given, then all attributes in events will
54                                                    #              be aggregated.
55                                                    # ignore_attributes  An option arrayref.  These attributes are ignored only if
56                                                    #                    they are auto-detected.  This list does not apply to
57                                                    #                    explicitly given attributes.
58                                                    # worst        The name of an element which defines the "worst" hashref in its
59                                                    #              class.  If this is Query_time, then each class will contain
60                                                    #              a sample that holds the event with the largest Query_time.
61                                                    # unroll_limit If this many events have been processed and some handlers haven't
62                                                    #              been generated yet (due to lack of sample data) unroll the loop
63                                                    #              anyway.  Defaults to 1000.
64                                                    # attrib_limit Sanity limit for attribute values.  If the value exceeds the
65                                                    #              limit, use the last-seen for this class; if none, then 0.
66                                                    # type_for     A hashref of attribute names and types.
67                                                    sub new {
68            17                   17           382      my ( $class, %args ) = @_;
69            17                                 87      foreach my $arg ( qw(groupby worst) ) {
70    ***     34     50                         194         die "I need a $arg argument" unless $args{$arg};
71                                                       }
72            17           100                  118      my $attributes = $args{attributes} || {};
73             3                                 30      my $self = {
74                                                          groupby        => $args{groupby},
75                                                          detect_attribs => scalar keys %$attributes == 0 ? 1 : 0,
76                                                          all_attribs    => [ keys %$attributes ],
77                                                          ignore_attribs => {
78             3                                 12            map  { $_ => $args{attributes}->{$_} }
79            17                                174            grep { $_ ne $args{groupby} }
80            21                                122            @{$args{ignore_attributes}}
81                                                          },
82                                                          attributes     => {
83            22                                 94            map  { $_ => $args{attributes}->{$_} }
84            21                                124            grep { $_ ne $args{groupby} }
85                                                             keys %$attributes
86                                                          },
87                                                          alt_attribs    => {
88            21                                 64            map  { $_ => make_alt_attrib(@{$args{attributes}->{$_}}) }
              22                                 86   
89            17    100                         312            grep { $_ ne $args{groupby} }
90                                                             keys %$attributes
91                                                          },
92                                                          worst        => $args{worst},
93                                                          unroll_limit => $args{unroll_limit} || 1000,
94                                                          attrib_limit => $args{attrib_limit},
95                                                          result_classes => {},
96                                                          result_globals => {},
97                                                          result_samples => {},
98                                                          n_events       => 0,
99                                                          unrolled_loops => undef,
100           17    100    100                  180         type_for       => { %{$args{type_for} || { Query_time => 'num' }} },
101                                                      };
102           17                                186      return bless $self, $class;
103                                                   }
104                                                   
105                                                   # Delete all collected data, but don't delete things like the generated
106                                                   # subroutines.  Resetting aggregated data is an interesting little exercise.
107                                                   # The generated functions that do aggregation have private namespaces with
108                                                   # references to some of the data.  Thus, they will not necessarily do as
109                                                   # expected if the stored data is simply wiped out.  Instead, it needs to be
110                                                   # zeroed out without replacing the actual objects.
111                                                   sub reset_aggregated_data {
112            1                    1            15      my ( $self ) = @_;
113            1                                  3      foreach my $class ( values %{$self->{result_classes}} ) {
               1                                  8   
114            1                                  4         foreach my $attrib ( values %$class ) {
115            2                                 10            delete @{$attrib}{keys %$attrib};
               2                                 46   
116                                                         }
117                                                      }
118            1                                  4      foreach my $class ( values %{$self->{result_globals}} ) {
               1                                  6   
119            2                                  9         delete @{$class}{keys %$class};
               2                                 36   
120                                                      }
121            1                                  3      delete @{$self->{result_samples}}{keys %{$self->{result_samples}}};
               1                                  4   
               1                                  5   
122            1                                  5      $self->{n_events} = 0;
123                                                   }
124                                                   
125                                                   # Aggregate an event hashref's properties.  Code is built on the fly to do this,
126                                                   # based on the values being passed in.  After code is built for every attribute
127                                                   # (or 50 events are seen and we decide to give up) the little bits of code get
128                                                   # unrolled into a whole subroutine to handle events.  For that reason, you can't
129                                                   # re-use an instance.
130                                                   sub aggregate {
131         1702                 1702         23492      my ( $self, $event ) = @_;
132                                                   
133         1702                               6682      my $group_by = $event->{$self->{groupby}};
134         1702    100                        5992      return unless defined $group_by;
135                                                   
136         1700                               5140      $self->{n_events}++;
137         1700                               3659      MKDEBUG && _d('event', $self->{n_events});
138                                                   
139                                                      # Run only unrolled loops if available.
140         1700    100                        7700      return $self->{unrolled_loops}->($self, $event, $group_by)
141                                                         if $self->{unrolled_loops};
142                                                   
143                                                      # For the first unroll_limit events, auto-detect new attribs and
144                                                      # run attrib handlers.
145         1264    100                        5541      if ( $self->{n_events} <= $self->{unroll_limit} ) {
146                                                   
147         1262    100                        5228         $self->add_new_attributes($event) if $self->{detect_attribs};
148                                                   
149         1262                               5959         ATTRIB:
150         1262                               3035         foreach my $attrib ( keys %{$self->{attributes}} ) {
151                                                   
152                                                            # Attrib auto-detection can add a lot of attributes which some events
153                                                            # may or may not have.  Aggregating a nonexistent attrib is wasteful,
154                                                            # so we check that the attrib or one of its alternates exists.  If
155                                                            # one does, then we leave attrib alone because the handler sub will
156                                                            # also check alternates.
157         4589    100                       18854            if ( !exists $event->{$attrib} ) {
158           16                                 38               MKDEBUG && _d("attrib doesn't exist in event:", $attrib);
159           16                                 86               my $alt_attrib = $self->{alt_attribs}->{$attrib}->($event);
160           16                                 35               MKDEBUG && _d('alt attrib:', $alt_attrib);
161           16    100                          77               next ATTRIB unless $alt_attrib;
162                                                            }
163                                                   
164                                                            # The value of the attribute ( $group_by ) may be an arrayref.
165                                                            GROUPBY:
166         4574    100                       17178            foreach my $val ( ref $group_by ? @$group_by : ($group_by) ) {
167         4576           100                33374               my $class_attrib  = $self->{result_classes}->{$val}->{$attrib} ||= {};
168         4576           100                22225               my $global_attrib = $self->{result_globals}->{$attrib} ||= {};
169         4576                              13993               my $samples       = $self->{result_samples};
170         4576                              18039               my $handler = $self->{handlers}->{ $attrib };
171         4576    100                       15981               if ( !$handler ) {
172           86                               2240                  $handler = $self->make_handler(
173                                                                     $attrib,
174                                                                     $event,
175                                                                     wor => $self->{worst} eq $attrib,
176                                                                     alt => $self->{attributes}->{$attrib},
177                                                                  );
178           86                                431                  $self->{handlers}->{$attrib} = $handler;
179                                                               }
180   ***   4576     50                       15361               next GROUPBY unless $handler;
181         4576           100                18049               $samples->{$val} ||= $event; # Initialize to the first event.
182         4576                              19722               $handler->($event, $class_attrib, $global_attrib, $samples, $group_by);
183                                                            }
184                                                         }
185                                                      }
186                                                      else {
187                                                         # After unroll_limit events, unroll the loops.
188            2                                 10         $self->_make_unrolled_loops($event);
189                                                         # Run unrolled loops here once.  Next time, they'll be ran
190                                                         # before this if-else.
191            2                                 12         $self->{unrolled_loops}->($self, $event, $group_by);
192                                                      }
193                                                   
194         1264                               7105      return;
195                                                   }
196                                                   
197                                                   sub _make_unrolled_loops {
198            2                    2             8      my ( $self, $event ) = @_;
199                                                   
200            2                                  9      my $group_by = $event->{$self->{groupby}};
201                                                   
202                                                      # All attributes have handlers, so let's combine them into one faster sub.
203                                                      # Start by getting direct handles to the location of each data store and
204                                                      # thing that would otherwise be looked up via hash keys.
205            2                                  6      my @attrs   = grep { $self->{handlers}->{$_} } keys %{$self->{attributes}};
              16                                 66   
               2                                 13   
206            2                                 11      my $globs   = $self->{result_globals}; # Global stats for each
207            2                                  6      my $samples = $self->{result_samples};
208                                                   
209                                                      # Now the tricky part -- must make sure only the desired variables from
210                                                      # the outer scope are re-used, and any variables that should have their
211                                                      # own scope are declared within the subroutine.
212   ***      2     50                          15      my @lines = (
213                                                         'my ( $self, $event, $group_by ) = @_;',
214                                                         'my ($val, $class, $global, $idx);',
215                                                         (ref $group_by ? ('foreach my $group_by ( @$group_by ) {') : ()),
216                                                         # Create and get each attribute's storage
217                                                         'my $temp = $self->{result_classes}->{ $group_by }
218                                                            ||= { map { $_ => { } } @attrs };',
219                                                         '$samples->{$group_by} ||= $event;', # Always start with the first.
220                                                      );
221            2                                 15      foreach my $i ( 0 .. $#attrs ) {
222                                                         # Access through array indexes, it's faster than hash lookups
223           16                                141         push @lines, (
224                                                            '$class  = $temp->{"'  . $attrs[$i] . '"};',
225                                                            '$global = $globs->{"' . $attrs[$i] . '"};',
226                                                            $self->{unrolled_for}->{$attrs[$i]},
227                                                         );
228                                                      }
229   ***      2     50                          10      if ( ref $group_by ) {
230   ***      0                                  0         push @lines, '}'; # Close the loop opened above
231                                                      }
232            2                                 11      @lines = map { s/^/   /gm; $_ } @lines; # Indent for debugging
              56                                359   
              56                                214   
233            2                                 19      unshift @lines, 'sub {';
234            2                                  7      push @lines, '}';
235                                                   
236                                                      # Make the subroutine.
237            2                                 42      my $code = join("\n", @lines);
238            2                                  5      MKDEBUG && _d('Unrolled subroutine:', @lines);
239            2                               2437      my $sub = eval $code;
240   ***      2     50                          11      die $EVAL_ERROR if $EVAL_ERROR;
241            2                                  8      $self->{unrolled_loops} = $sub;
242                                                   
243            2                                 12      return;
244                                                   }
245                                                   
246                                                   # Return the aggregated results.
247                                                   sub results {
248           20                   20          6257      my ( $self ) = @_;
249                                                      return {
250           20                                340         classes => $self->{result_classes},
251                                                         globals => $self->{result_globals},
252                                                         samples => $self->{result_samples},
253                                                      };
254                                                   }
255                                                   
256                                                   # Return the attributes that this object is tracking, and their data types, as
257                                                   # a hashref of name => type.
258                                                   sub attributes {
259            1                    1             5      my ( $self ) = @_;
260            1                                 10      return $self->{type_for};
261                                                   }
262                                                   
263                                                   # Returns the type of the attribute (as decided by the aggregation process,
264                                                   # which inspects the values).
265                                                   sub type_for {
266          101                  101           405      my ( $self, $attrib ) = @_;
267          101                               1254      return $self->{type_for}->{$attrib};
268                                                   }
269                                                   
270                                                   # Make subroutines that do things with events.
271                                                   #
272                                                   # $attrib: the name of the attrib (Query_time, Rows_read, etc)
273                                                   # $event:  a sample event
274                                                   # %args:
275                                                   #     min => keep min for this attrib (default except strings)
276                                                   #     max => keep max (default except strings)
277                                                   #     sum => keep sum (default for numerics)
278                                                   #     cnt => keep count (default except strings)
279                                                   #     unq => keep all unique values per-class (default for strings and bools)
280                                                   #     all => keep a bucketed list of values seen per class (default for numerics)
281                                                   #     glo => keep stats globally as well as per-class (default)
282                                                   #     trf => An expression to transform the value before working with it
283                                                   #     wor => Whether to keep worst-samples for this attrib (default no)
284                                                   #     alt => Arrayref of other name(s) for the attribute, like db => Schema.
285                                                   #
286                                                   # The bucketed list works this way: each range of values from MIN_BUCK in
287                                                   # increments of BUCK_SIZE (that is 5%) we consider a bucket.  We keep NUM_BUCK
288                                                   # buckets.  The upper end of the range is more than 1.5e15 so it should be big
289                                                   # enough for almost anything.  The buckets are accessed by a log base BUCK_SIZE,
290                                                   # so floor(log(N)/log(BUCK_SIZE)).  The smallest bucket's index is -284. We
291                                                   # shift all values up 284 so we have values from 0 to 999 that can be used as
292                                                   # array indexes.  A value that falls into a bucket simply increments the array
293                                                   # entry.  We do NOT use POSIX::floor() because it is too expensive.
294                                                   #
295                                                   # This eliminates the need to keep and sort all values to calculate median,
296                                                   # standard deviation, 95th percentile etc.  Thus the memory usage is bounded by
297                                                   # the number of distinct aggregated values, not the number of events.
298                                                   #
299                                                   # Return value:
300                                                   # a subroutine with this signature:
301                                                   #    my ( $event, $class, $global ) = @_;
302                                                   # where
303                                                   #  $event   is the event
304                                                   #  $class   is the container to store the aggregated values
305                                                   #  $global  is is the container to store the globally aggregated values
306                                                   sub make_handler {
307           86                   86           622      my ( $self, $attrib, $event, %args ) = @_;
308   ***     86     50                         382      die "I need an attrib" unless defined $attrib;
309           86                                244      my ($val) = grep { defined $_ } map { $event->{$_} } @{ $args{alt} };
              87                                327   
              87                                387   
              86                                340   
310           86                                250      my $is_array = 0;
311   ***     86     50                         395      if (ref $val eq 'ARRAY') {
312   ***      0                                  0         $is_array = 1;
313   ***      0                                  0         $val      = $val->[0];
314                                                      }
315   ***     86     50                         359      return unless defined $val; # Can't decide type if it's undef.
316                                                   
317                                                      # Ripped off from Regexp::Common::number and modified.
318           86                                560      my $float_re = qr{[+-]?(?:(?=\d|[.])\d+(?:[.])\d{0,})(?:E[+-]?\d+)?}i;
319           86    100                         366      my $type = $self->type_for($attrib)         ? $self->type_for($attrib)
                    100                               
                    100                               
320                                                               : $val  =~ m/^(?:\d+|$float_re)$/o ? 'num'
321                                                               : $val  =~ m/^(?:Yes|No)$/         ? 'bool'
322                                                               :                                    'string';
323           86                                230      MKDEBUG && _d('Type for', $attrib, 'is', $type,
324                                                         '(sample:', $val, '), is array:', $is_array);
325           86                                360      $self->{type_for}->{$attrib} = $type;
326                                                   
327           86    100                        1927      %args = ( # Set up defaults
                    100                               
                    100                               
                    100                               
328                                                         min => 1,
329                                                         max => 1,
330                                                         sum => $type =~ m/num|bool/    ? 1 : 0,
331                                                         cnt => 1,
332                                                         unq => $type =~ m/bool|string/ ? 1 : 0,
333                                                         all => $type eq 'num'          ? 1 : 0,
334                                                         glo => 1,
335                                                         trf => ($type eq 'bool') ? q{(($val || '') eq 'Yes') ? 1 : 0} : undef,
336                                                         wor => 0,
337                                                         alt => [],
338                                                         %args,
339                                                      );
340                                                   
341           86                                539      my @lines = ("# type: $type"); # Lines of code for the subroutine
342           86    100                         387      if ( $args{trf} ) {
343           14                                 64         push @lines, q{$val = } . $args{trf} . ';';
344                                                      }
345                                                   
346           86                                292      foreach my $place ( qw($class $global) ) {
347          172                                917         my @tmp;
348   ***    172     50                         687         if ( $args{min} ) {
349          172    100                         660            my $op   = $type eq 'num' ? '<' : 'lt';
350          172                                717            push @tmp, (
351                                                               'PLACE->{min} = $val if !defined PLACE->{min} || $val '
352                                                                  . $op . ' PLACE->{min};',
353                                                            );
354                                                         }
355   ***    172     50                         652         if ( $args{max} ) {
356          172    100                        1441            my $op = ($type eq 'num') ? '>' : 'gt';
357          172                                676            push @tmp, (
358                                                               'PLACE->{max} = $val if !defined PLACE->{max} || $val '
359                                                                  . $op . ' PLACE->{max};',
360                                                            );
361                                                         }
362          172    100                         647         if ( $args{sum} ) {
363          122                                364            push @tmp, 'PLACE->{sum} += $val;';
364                                                         }
365   ***    172     50                         663         if ( $args{cnt} ) {
366          172                                504            push @tmp, '++PLACE->{cnt};';
367                                                         }
368          172    100                         658         if ( $args{all} ) {
369           94                                357            push @tmp, (
370                                                               'exists PLACE->{all} or PLACE->{all} = [ @buckets ];',
371                                                               '++PLACE->{all}->[ EventAggregator::bucket_idx($val) ];',
372                                                            );
373                                                         }
374          172                                546         push @lines, map { s/PLACE/$place/g; $_ } @tmp;
             826                               4393   
             826                               2997   
375                                                      }
376                                                   
377                                                      # We only save unique/worst values for the class, not globally.
378           86    100                        1387      if ( $args{unq} ) {
379           39                                139         push @lines, '++$class->{unq}->{$val};';
380                                                      }
381           86    100                         329      if ( $args{wor} ) {
382   ***     11     50                          50         my $op = $type eq 'num' ? '>=' : 'ge';
383           11                                 61         push @lines, (
384                                                            'if ( $val ' . $op . ' ($class->{max} || 0) ) {',
385                                                            '   $samples->{$group_by} = $event;',
386                                                            '}',
387                                                         );
388                                                      }
389                                                   
390                                                      # Handle broken Query_time like 123.124345.8382 (issue 234).
391           86                                218      my @broken_query_time;
392           86    100                         328      if ( $attrib eq 'Query_time' ) {
393           12                                 60         push @broken_query_time, (
394                                                            '$val =~ s/^(\d+(?:\.\d+)?).*/$1/;',
395                                                            '$event->{\''.$attrib.'\'} = $val;',
396                                                         );
397                                                      }
398                                                   
399                                                      # Make sure the value is constrained to legal limits.  If it's out of bounds,
400                                                      # just use the last-seen value for it.
401           86                                215      my @limit;
402   ***     86    100     66                  870      if ( $args{all} && $type eq 'num' && $self->{attrib_limit} ) {
                           100                        
403            1                                  7         push @limit, (
404                                                            "if ( \$val > $self->{attrib_limit} ) {",
405                                                            '   $val = $class->{last} ||= 0;',
406                                                            '}',
407                                                            '$class->{last} = $val;',
408                                                         );
409                                                      }
410                                                   
411                                                      # Save the code for later, as part of an "unrolled" subroutine.
412            1                                  7      my @unrolled = (
413                                                         "\$val = \$event->{'$attrib'};",
414                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
415           87                                412         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
416           86                                322            grep { $_ ne $attrib } @{$args{alt}}),
            1026                               3792   
417                                                         'defined $val && do {',
418   ***     86     50                         443         ( map { s/^/   /gm; $_ } (@broken_query_time, @limit, @lines) ), # Indent for debugging
      ***   1026     50                        3924   
419                                                         '};',
420                                                         ($is_array ? ('}') : ()),
421                                                      );
422           86                                950      $self->{unrolled_for}->{$attrib} = join("\n", @unrolled);
423                                                   
424                                                      # Build a subroutine with the code.
425            1                                  9      unshift @lines, (
426                                                         'sub {',
427                                                         'my ( $event, $class, $global, $samples, $group_by ) = @_;',
428                                                         'my ($val, $idx);', # NOTE: define all variables here
429                                                         "\$val = \$event->{'$attrib'};",
430           87                                931         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
431   ***     86     50                         375            grep { $_ ne $attrib } @{$args{alt}}),
      ***     86     50                         328   
432                                                         'return unless defined $val;',
433                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
434                                                         @broken_query_time,
435                                                         @limit,
436                                                         ($is_array ? ('}') : ()),
437                                                      );
438           86                                289      push @lines, '}';
439           86                                504      my $code = join("\n", @lines);
440           86                                409      $self->{code_for}->{$attrib} = $code;
441                                                   
442           86                                190      MKDEBUG && _d('Metric handler for', $attrib, ':', @lines);
443           86                              18246      my $sub = eval join("\n", @lines);
444   ***     86     50                         387      die if $EVAL_ERROR;
445           86                               1135      return $sub;
446                                                   }
447                                                   
448                                                   # Returns the bucket number for the given val. Buck numbers are zero-indexed,
449                                                   # so although there are 1,000 buckets (NUM_BUCK), 999 is the greatest idx.
450                                                   # *** Notice that this sub is not a class method, so either call it
451                                                   # from inside this module like bucket_idx() or outside this module
452                                                   # like EventAggregator::bucket_idx(). ***
453                                                   # TODO: could export this by default to avoid having to specific packge::.
454                                                   sub bucket_idx {
455         7884                 7884         39837      my ( $val ) = @_;
456         7884    100                       33947      return 0 if $val < MIN_BUCK;
457         6402                              28044      my $idx = int(BASE_OFFSET + log($val)/BASE_LOG);
458         6402    100                       38127      return $idx > (NUM_BUCK-1) ? (NUM_BUCK-1) : $idx;
459                                                   }
460                                                   
461                                                   # Returns the value for the given bucket.
462                                                   # The value of each bucket is the first value that it covers. So the value
463                                                   # of bucket 1 is 0.000001000 because it covers [0.000001000, 0.000001050).
464                                                   #
465                                                   # *** Notice that this sub is not a class method, so either call it
466                                                   # from inside this module like bucket_idx() or outside this module
467                                                   # like EventAggregator::bucket_value(). ***
468                                                   # TODO: could export this by default to avoid having to specific packge::.
469                                                   sub bucket_value {
470         1007                 1007          3105      my ( $bucket ) = @_;
471         1007    100                        3537      return 0 if $bucket == 0;
472   ***   1005     50     33                 7559      die "Invalid bucket: $bucket" if $bucket < 0 || $bucket > (NUM_BUCK-1);
473                                                      # $bucket - 1 because buckets are shifted up by 1 to handle zero values.
474         1005                               5147      return (BUCK_SIZE**($bucket-1)) * MIN_BUCK;
475                                                   }
476                                                   
477                                                   # Map the 1,000 base 1.05 buckets to 8 base 10 buckets. Returns an array
478                                                   # of 1,000 buckets, the value of each represents its index in an 8 bucket
479                                                   # base 10 array. For example: base 10 bucket 0 represents vals (0, 0.000010),
480                                                   # and base 1.05 buckets 0..47 represent vals (0, 0.000010401). So the first
481                                                   # 48 elements of the returned array will have 0 as their values. 
482                                                   # TODO: right now it's hardcoded to buckets of 10, in the future maybe not.
483                                                   {
484                                                      my @buck_tens;
485                                                      sub buckets_of {
486   ***      1     50             1             5         return @buck_tens if @buck_tens;
487                                                   
488                                                         # To make a more precise map, we first set the starting values for
489                                                         # each of the 8 base 10 buckets. 
490            1                                  4         my $start_bucket  = 0;
491            1                                  4         my @base10_starts = (0);
492            1                                  4         map { push @base10_starts, (10**$_)*MIN_BUCK } (1..7);
               7                                 28   
493                                                   
494                                                         # Then find the base 1.05 buckets that correspond to each
495                                                         # base 10 bucket. The last value in each bucket's range belongs
496                                                         # to the next bucket, so $next_bucket-1 represents the real last
497                                                         # base 1.05 bucket in which the base 10 bucket's range falls.
498            1                                  7         for my $base10_bucket ( 0..($#base10_starts-1) ) {
499            7                                 30            my $next_bucket = bucket_idx( $base10_starts[$base10_bucket+1] );
500            7                                 16            MKDEBUG && _d('Base 10 bucket', $base10_bucket, 'maps to',
501                                                               'base 1.05 buckets', $start_bucket, '..', $next_bucket-1);
502            7                                 26            for my $base1_05_bucket ($start_bucket..($next_bucket-1)) {
503          331                               1023               $buck_tens[$base1_05_bucket] = $base10_bucket;
504                                                            }
505            7                                 24            $start_bucket = $next_bucket;
506                                                         }
507                                                   
508                                                         # Map all remaining base 1.05 buckets to base 10 bucket 7 which
509                                                         # is for vals > 10.
510            1                                 30         map { $buck_tens[$_] = 7 } ($start_bucket..(NUM_BUCK-1));
             669                               2135   
511                                                   
512            1                                124         return @buck_tens;
513                                                      }
514                                                   }
515                                                   
516                                                   # Given an arrayref of vals, returns a hashref with the following
517                                                   # statistical metrics:
518                                                   #
519                                                   #    pct_95    => top bucket value in the 95th percentile
520                                                   #    cutoff    => How many values fall into the 95th percentile
521                                                   #    stddev    => of all values
522                                                   #    median    => of all values
523                                                   #
524                                                   # The vals arrayref is the buckets as per the above (see the comments at the top
525                                                   # of this file).  $args should contain cnt, min and max properties.
526                                                   sub calculate_statistical_metrics {
527           17                   17          4338      my ( $self, $vals, $args ) = @_;
528           17                                107      my $statistical_metrics = {
529                                                         pct_95    => 0,
530                                                         stddev    => 0,
531                                                         median    => 0,
532                                                         cutoff    => undef,
533                                                      };
534                                                   
535                                                      # These cases might happen when there is nothing to get from the event, for
536                                                      # example, processlist sniffing doesn't gather Rows_examined, so $args won't
537                                                      # have {cnt} or other properties.
538           17    100    100                  231      return $statistical_metrics
                           100                        
539                                                         unless defined $vals && @$vals && $args->{cnt};
540                                                   
541                                                      # Return accurate metrics for some cases.
542           13                                 42      my $n_vals = $args->{cnt};
543           13    100    100                  131      if ( $n_vals == 1 || $args->{max} == $args->{min} ) {
                    100                               
544   ***      7            50                   31         my $v      = $args->{max} || 0;
545   ***      7     50                         281         my $bucket = int(6 + ( log($v > 0 ? $v : MIN_BUCK) / log(10)));
546   ***      7     50                          35         $bucket    = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
547                                                         return {
548            7                                 58            pct_95 => $v,
549                                                            stddev => 0,
550                                                            median => $v,
551                                                            cutoff => $n_vals,
552                                                         };
553                                                      }
554                                                      elsif ( $n_vals == 2 ) {
555            1                                  6         foreach my $v ( $args->{min}, $args->{max} ) {
556   ***      2     50     33                   27            my $bucket = int(6 + ( log($v && $v > 0 ? $v : MIN_BUCK) / log(10)));
557   ***      2     50                          12            $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
558                                                         }
559   ***      1            50                    7         my $v      = $args->{max} || 0;
560   ***      1            50                    7         my $mean = (($args->{min} || 0) + $v) / 2;
561                                                         return {
562            1                                 16            pct_95 => $v,
563                                                            stddev => sqrt((($v - $mean) ** 2) *2),
564                                                            median => $mean,
565                                                            cutoff => $n_vals,
566                                                         };
567                                                      }
568                                                   
569                                                      # Determine cutoff point for 95% if there are at least 10 vals.  Cutoff
570                                                      # serves also for the number of vals left in the 95%.  E.g. with 50 vals the
571                                                      # cutoff is 47 which means there are 47 vals: 0..46.  $cutoff is NOT an array
572                                                      # index.
573            5    100                          31      my $cutoff = $n_vals >= 10 ? int ( $n_vals * 0.95 ) : $n_vals;
574            5                                 19      $statistical_metrics->{cutoff} = $cutoff;
575                                                   
576                                                      # Calculate the standard deviation and median of all values.
577            5                                 15      my $total_left = $n_vals;
578            5                                 16      my $top_vals   = $n_vals - $cutoff; # vals > 95th
579            5                                 15      my $sum_excl   = 0;
580            5                                 13      my $sum        = 0;
581            5                                 14      my $sumsq      = 0;
582            5                                 23      my $mid        = int($n_vals / 2);
583            5                                 13      my $median     = 0;
584            5                                 15      my $prev       = NUM_BUCK-1; # Used for getting median when $cutoff is odd
585            5                                 13      my $bucket_95  = 0; # top bucket in 95th
586                                                   
587            5                                 12      MKDEBUG && _d('total vals:', $total_left, 'top vals:', $top_vals, 'mid:', $mid);
588                                                   
589                                                      BUCKET:
590            5                                 37      for my $bucket ( reverse 0..(NUM_BUCK-1) ) {
591         5000                              16533         my $val = $vals->[$bucket];
592         5000    100                       30584         next BUCKET unless $val; 
593                                                   
594           19                                 50         $total_left -= $val;
595           19                                 52         $sum_excl   += $val;
596           19    100    100                  135         $bucket_95   = $bucket if !$bucket_95 && $sum_excl > $top_vals;
597                                                   
598           19    100    100                  125         if ( !$median && $total_left <= $mid ) {
599   ***      5     50     66                   50            $median = (($cutoff % 2) || ($val > 1)) ? $buck_vals[$bucket]
600                                                                    : ($buck_vals[$bucket] + $buck_vals[$prev]) / 2;
601                                                         }
602                                                   
603           19                                 72         $sum    += $val * $buck_vals[$bucket];
604           19                                 73         $sumsq  += $val * ($buck_vals[$bucket]**2);
605           19                                 60         $prev   =  $bucket;
606                                                      }
607                                                   
608            5                                 33      my $var      = $sumsq/$n_vals - ( ($sum/$n_vals) ** 2 );
609            5    100                          37      my $stddev   = $var > 0 ? sqrt($var) : 0;
610   ***      5            50                   49      my $maxstdev = (($args->{max} || 0) - ($args->{min} || 0)) / 2;
                           100                        
611   ***      5     50                          21      $stddev      = $stddev > $maxstdev ? $maxstdev : $stddev;
612                                                   
613            5                                 11      MKDEBUG && _d('sum:', $sum, 'sumsq:', $sumsq, 'stddev:', $stddev,
614                                                         'median:', $median, 'prev bucket:', $prev,
615                                                         'total left:', $total_left, 'sum excl', $sum_excl,
616                                                         'bucket 95:', $bucket_95, $buck_vals[$bucket_95]);
617                                                   
618            5                                 21      $statistical_metrics->{stddev} = $stddev;
619            5                                 19      $statistical_metrics->{pct_95} = $buck_vals[$bucket_95];
620            5                                 15      $statistical_metrics->{median} = $median;
621                                                   
622            5                                 32      return $statistical_metrics;
623                                                   }
624                                                   
625                                                   # Return a hashref of the metrics for some attribute, pre-digested.
626                                                   # %args is:
627                                                   #  attrib => the attribute to report on
628                                                   #  where  => the value of the fingerprint for the attrib
629                                                   sub metrics {
630            2                    2            13      my ( $self, %args ) = @_;
631            2                                  8      foreach my $arg ( qw(attrib where) ) {
632   ***      4     50                          21         die "I need a $arg argument" unless $args{$arg};
633                                                      }
634            2                                  9      my $stats = $self->results;
635            2                                 13      my $store = $stats->{classes}->{$args{where}}->{$args{attrib}};
636                                                   
637            2                                 10      my $global_cnt = $stats->{globals}->{$args{attrib}}->{cnt};
638            2                                 13      my $metrics    = $self->calculate_statistical_metrics($store->{all}, $store);
639                                                   
640                                                      return {
641   ***      2    100     66                   68         cnt    => $store->{cnt},
      ***           100     66                        
642                                                         pct    => $global_cnt && $store->{cnt} ? $store->{cnt} / $global_cnt : 0,
643                                                         sum    => $store->{sum},
644                                                         min    => $store->{min},
645                                                         max    => $store->{max},
646                                                         avg    => $store->{sum} && $store->{cnt} ? $store->{sum} / $store->{cnt} : 0,
647                                                         median => $metrics->{median},
648                                                         pct_95 => $metrics->{pct_95},
649                                                         stddev => $metrics->{stddev},
650                                                      };
651                                                   }
652                                                   
653                                                   # Find the top N or top % event keys, in sorted order, optionally including
654                                                   # outliers (ol_...) that are notable for some reason.  %args looks like this:
655                                                   #
656                                                   #  attrib      order-by attribute (usually Query_time)
657                                                   #  orderby     order-by aggregate expression (should be numeric, usually sum)
658                                                   #  total       include events whose summed attribs are <= this number...
659                                                   #  count       ...or this many events, whichever is less...
660                                                   #  ol_attrib   ...or events where the 95th percentile of this attribute...
661                                                   #  ol_limit    ...is greater than this value, AND...
662                                                   #  ol_freq     ...the event occurred at least this many times.
663                                                   # The return value is a list of arrayrefs.  Each arrayref is the event key and
664                                                   # an explanation of why it was included (top|outlier).
665                                                   sub top_events {
666            3                    3            60      my ( $self, %args ) = @_;
667            3                                 14      my $classes = $self->{result_classes};
668           15                                 94      my @sorted = reverse sort { # Sorted list of $groupby values
669           16                                 75         $classes->{$a}->{$args{attrib}}->{$args{orderby}}
670                                                            <=> $classes->{$b}->{$args{attrib}}->{$args{orderby}}
671                                                         } grep {
672                                                            # Defensive programming
673            3                                 17            defined $classes->{$_}->{$args{attrib}}->{$args{orderby}}
674                                                         } keys %$classes;
675            3                                 19      my @chosen;
676            3                                 11      my ($total, $count) = (0, 0);
677            3                                 10      foreach my $groupby ( @sorted ) {
678                                                         # Events that fall into the top criterion for some reason
679           15    100    100                  252         if ( 
      ***           100     66                        
                           100                        
                           100                        
                           100                        
680                                                            (!$args{total} || $total < $args{total} )
681                                                            && ( !$args{count} || $count < $args{count} )
682                                                         ) {
683            6                                 25            push @chosen, [$groupby, 'top'];
684                                                         }
685                                                   
686                                                         # Events that are notable outliers
687                                                         elsif ( $args{ol_attrib} && (!$args{ol_freq}
688                                                            || $classes->{$groupby}->{$args{ol_attrib}}->{cnt} >= $args{ol_freq})
689                                                         ) {
690                                                            # Calculate the 95th percentile of this event's specified attribute.
691            5                                 11            MKDEBUG && _d('Calculating statistical_metrics');
692            5                                 36            my $stats = $self->calculate_statistical_metrics(
693                                                               $classes->{$groupby}->{$args{ol_attrib}}->{all},
694                                                               $classes->{$groupby}->{$args{ol_attrib}}
695                                                            );
696            5    100                          29            if ( $stats->{pct_95} >= $args{ol_limit} ) {
697            3                                 16               push @chosen, [$groupby, 'outlier'];
698                                                            }
699                                                         }
700                                                   
701           15                                 70         $total += $classes->{$groupby}->{$args{attrib}}->{$args{orderby}};
702           15                                 43         $count++;
703                                                      }
704            3                                 27      return @chosen;
705                                                   }
706                                                   
707                                                   # Adds all new attributes in $event to $self->{attributes}.
708                                                   sub add_new_attributes {
709          239                  239           904      my ( $self, $event ) = @_;
710   ***    239     50                         924      return unless $event;
711                                                   
712           66                                178      map {
713         3772    100    100                34739         my $attrib = $_;
714           66                                282         $self->{attributes}->{$attrib}  = [$attrib];
715           66                                261         $self->{alt_attribs}->{$attrib} = make_alt_attrib($attrib);
716           66                                180         push @{$self->{all_attribs}}, $attrib;
              66                                284   
717           66                                208         MKDEBUG && _d('Added new attribute:', $attrib);
718                                                      }
719                                                      grep {
720          239                               1719         $_ ne $self->{groupby}
721                                                         && !exists $self->{attributes}->{$_}
722                                                         && !exists $self->{ignore_attribs}->{$_}
723                                                      }
724                                                      keys %$event;
725                                                   
726          239                               1217      return;
727                                                   }
728                                                   
729                                                   # Returns a list of all the attributes that were either given
730                                                   # explicitly to new() or that were auto-detected.
731                                                   sub get_attributes {
732            1                    1           130      my ( $self ) = @_;
733            1                                  3      return @{$self->{all_attribs}};
               1                                 18   
734                                                   }
735                                                   
736                                                   sub events_processed {
737            1                    1             4      my ( $self ) = @_;
738            1                                  9      return $self->{n_events};
739                                                   }
740                                                   
741                                                   sub make_alt_attrib {
742           87                   87           328      my ( @attribs ) = @_;
743                                                   
744           87                                276      my $attrib = shift @attribs;  # Primary attribute.
745           87    100            15           777      return sub {} unless @attribs;  # No alternates.
              15                                 41   
746                                                   
747            1                                  4      my @lines;
748            1                                  4      push @lines, 'sub { my ( $event ) = @_; my $alt_attrib;';
749            1                                  7      push @lines, map  {
750            1                                  4            "\$alt_attrib = '$_' if !defined \$alt_attrib "
751                                                            . "&& exists \$event->{'$_'};"
752                                                         } @attribs;
753            1                                  4      push @lines, 'return $alt_attrib; }';
754            1                                  3      MKDEBUG && _d('alt attrib sub for', $attrib, ':', @lines);
755            1                                 85      my $sub = eval join("\n", @lines);
756   ***      1     50                           6      die if $EVAL_ERROR;
757            1                                 18      return $sub;
758                                                   }
759                                                   
760                                                   sub _d {
761   ***      0                    0                    my ($package, undef, $line) = caller 0;
762   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
763   ***      0                                              map { defined $_ ? $_ : 'undef' }
764                                                           @_;
765   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
766                                                   }
767                                                   
768                                                   1;
769                                                   
770                                                   # ###########################################################################
771                                                   # End EventAggregator package
772                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
70    ***     50      0     34   unless $args{$arg}
89           100     16      1   unless $args{'type_for'}
100          100      6     11   scalar keys %$attributes == 0 ? :
134          100      2   1700   unless defined $group_by
140          100    436   1264   if $$self{'unrolled_loops'}
145          100   1262      2   if ($$self{'n_events'} <= $$self{'unroll_limit'}) { }
147          100    239   1023   if $$self{'detect_attribs'}
157          100     16   4573   if (not exists $$event{$attrib})
161          100     15      1   unless $alt_attrib
166          100      4   4570   ref $group_by ? :
171          100     86   4490   if (not $handler)
180   ***     50      0   4576   unless $handler
212   ***     50      0      2   ref $group_by ? :
229   ***     50      0      2   if (ref $group_by)
240   ***     50      0      2   if $EVAL_ERROR
308   ***     50      0     86   unless defined $attrib
311   ***     50      0     86   if (ref $val eq 'ARRAY')
315   ***     50      0     86   unless defined $val
319          100     14     25   $val =~ /^(?:Yes|No)$/ ? :
             100     35     39   $val =~ /^(?:\d+|$float_re)$/o ? :
             100     12     74   $self->type_for($attrib) ? :
327          100     61     25   $type =~ /num|bool/ ? :
             100     39     47   $type =~ /bool|string/ ? :
             100     47     39   $type eq 'num' ? :
             100     14     72   $type eq 'bool' ? :
342          100     14     72   if ($args{'trf'})
348   ***     50    172      0   if ($args{'min'})
349          100     94     78   $type eq 'num' ? :
355   ***     50    172      0   if ($args{'max'})
356          100     94     78   $type eq 'num' ? :
362          100    122     50   if ($args{'sum'})
365   ***     50    172      0   if ($args{'cnt'})
368          100     94     78   if ($args{'all'})
378          100     39     47   if ($args{'unq'})
381          100     11     75   if ($args{'wor'})
382   ***     50     11      0   $type eq 'num' ? :
392          100     12     74   if ($attrib eq 'Query_time')
402          100      1     85   if ($args{'all'} and $type eq 'num' and $$self{'attrib_limit'})
418   ***     50      0     86   $is_array ? :
      ***     50      0     86   $is_array ? :
431   ***     50      0     86   $is_array ? :
      ***     50      0     86   $is_array ? :
444   ***     50      0     86   if $EVAL_ERROR
456          100   1482   6402   if $val < 1e-06
458          100      1   6401   $idx > 999 ? :
471          100      2   1005   if $bucket == 0
472   ***     50      0   1005   if $bucket < 0 or $bucket > 999
486   ***     50      0      1   if @buck_tens
538          100      4     13   unless defined $vals and @$vals and $$args{'cnt'}
543          100      7      6   if ($n_vals == 1 or $$args{'max'} == $$args{'min'}) { }
             100      1      5   elsif ($n_vals == 2) { }
545   ***     50      7      0   $v > 0 ? :
546   ***     50      0      7   $bucket < 0 ? :
      ***     50      0      7   $bucket > 7 ? :
556   ***     50      2      0   $v && $v > 0 ? :
557   ***     50      0      2   $bucket < 0 ? :
      ***     50      0      2   $bucket > 7 ? :
573          100      4      1   $n_vals >= 10 ? :
592          100   4981     19   unless $val
596          100      5     14   if not $bucket_95 and $sum_excl > $top_vals
598          100      5     14   if (not $median and $total_left <= $mid)
599   ***     50      5      0   $cutoff % 2 || $val > 1 ? :
609          100      3      2   $var > 0 ? :
611   ***     50      0      5   $stddev > $maxstdev ? :
632   ***     50      0      4   unless $args{$arg}
641          100      1      1   $global_cnt && $$store{'cnt'} ? :
             100      1      1   $$store{'sum'} && $$store{'cnt'} ? :
679          100      6      9   if (!$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}) { }
             100      5      4   elsif ($args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}) { }
696          100      3      2   if ($$stats{'pct_95'} >= $args{'ol_limit'})
710   ***     50      0    239   unless $event
713          100     70   3702   if $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}
745          100     86      1   unless @attribs
756   ***     50      0      1   if $EVAL_ERROR
762   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
402   ***     66     39      0     47   $args{'all'} and $type eq 'num'
             100     39     46      1   $args{'all'} and $type eq 'num' and $$self{'attrib_limit'}
538          100      2      1     14   defined $vals and @$vals
             100      3      1     13   defined $vals and @$vals and $$args{'cnt'}
556   ***     33      0      0      2   $v && $v > 0
596          100     11      3      5   not $bucket_95 and $sum_excl > $top_vals
598          100      5      9      5   not $median and $total_left <= $mid
641   ***     66      1      0      1   $global_cnt && $$store{'cnt'}
      ***     66      1      0      1   $$store{'sum'} && $$store{'cnt'}
679          100      6      3      6   !$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}
             100      3      1      5   $args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}
713          100    239   3463     70   $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
72           100     11      6   $args{'attributes'} || {}
100          100      1     16   $args{'unroll_limit'} || 1000
167          100   4433    143   $$self{'result_classes'}{$val}{$attrib} ||= {}
168          100   4490     86   $$self{'result_globals'}{$attrib} ||= {}
181          100   4547     29   $$samples{$val} ||= $event
544   ***     50      7      0   $$args{'max'} || 0
559   ***     50      1      0   $$args{'max'} || 0
560   ***     50      1      0   $$args{'min'} || 0
610   ***     50      5      0   $$args{'max'} || 0
             100      4      1   $$args{'min'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
472   ***     33      0      0   1005   $bucket < 0 or $bucket > 999
543          100      3      4      6   $n_vals == 1 or $$args{'max'} == $$args{'min'}
599   ***     66      2      3      0   $cutoff % 2 || $val > 1
679          100      5      4      6   !$args{'total'} || $total < $args{'total'}
      ***     66      0      6      3   !$args{'count'} || $count < $args{'count'}
             100      3      2      1   !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}


Covered Subroutines
-------------------

Subroutine                    Count Location                                              
----------------------------- ----- ------------------------------------------------------
BEGIN                             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:22 
BEGIN                             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:23 
BEGIN                             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:24 
BEGIN                             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:32 
BEGIN                             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:33 
BEGIN                             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:34 
BEGIN                             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:35 
BEGIN                             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:36 
BEGIN                             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:37 
__ANON__                         15 /home/daniel/dev/maatkit/common/EventAggregator.pm:745
_make_unrolled_loops              2 /home/daniel/dev/maatkit/common/EventAggregator.pm:198
add_new_attributes              239 /home/daniel/dev/maatkit/common/EventAggregator.pm:709
aggregate                      1702 /home/daniel/dev/maatkit/common/EventAggregator.pm:131
attributes                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:259
bucket_idx                     7884 /home/daniel/dev/maatkit/common/EventAggregator.pm:455
bucket_value                   1007 /home/daniel/dev/maatkit/common/EventAggregator.pm:470
buckets_of                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:486
calculate_statistical_metrics    17 /home/daniel/dev/maatkit/common/EventAggregator.pm:527
events_processed                  1 /home/daniel/dev/maatkit/common/EventAggregator.pm:737
get_attributes                    1 /home/daniel/dev/maatkit/common/EventAggregator.pm:732
make_alt_attrib                  87 /home/daniel/dev/maatkit/common/EventAggregator.pm:742
make_handler                     86 /home/daniel/dev/maatkit/common/EventAggregator.pm:307
metrics                           2 /home/daniel/dev/maatkit/common/EventAggregator.pm:630
new                              17 /home/daniel/dev/maatkit/common/EventAggregator.pm:68 
reset_aggregated_data             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:112
results                          20 /home/daniel/dev/maatkit/common/EventAggregator.pm:248
top_events                        3 /home/daniel/dev/maatkit/common/EventAggregator.pm:666
type_for                        101 /home/daniel/dev/maatkit/common/EventAggregator.pm:266

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                              
----------------------------- ----- ------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/EventAggregator.pm:761


