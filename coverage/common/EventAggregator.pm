---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/EventAggregator.pm   97.0   77.7   82.4   96.6    n/a  100.0   89.9
Total                          97.0   77.7   82.4   96.6    n/a  100.0   89.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          EventAggregator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:51:40 2009
Finish:       Fri Jul 31 18:51:47 2009

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
18                                                    # EventAggregator package $Revision: 4131 $
19                                                    # ###########################################################################
20                                                    package EventAggregator;
21                                                    
22             1                    1             7   use strict;
               1                                  2   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  4   
25                                                    
26                                                    # ###########################################################################
27                                                    # Set up some constants for bucketing values.  It is impossible to keep all
28                                                    # values seen in memory, but putting them into logarithmically scaled buckets
29                                                    # and just incrementing the bucket each time works, although it is imprecise.
30                                                    # See http://code.google.com/p/maatkit/wiki/EventAggregatorInternals.
31                                                    # ###########################################################################
32             1                    1             6   use constant MKDEBUG      => $ENV{MKDEBUG};
               1                                  2   
               1                                  7   
33             1                    1             6   use constant BUCK_SIZE    => 1.05;
               1                                  2   
               1                                  4   
34             1                    1             6   use constant BASE_LOG     => log(BUCK_SIZE);
               1                                  2   
               1                                  4   
35             1                    1             5   use constant BASE_OFFSET  => abs(1 - log(0.000001) / BASE_LOG); # 284.1617969
               1                                  3   
               1                                  4   
36             1                    1             5   use constant NUM_BUCK     => 1000;
               1                                  2   
               1                                  4   
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
68            16                   16           342      my ( $class, %args ) = @_;
69            16                                 75      foreach my $arg ( qw(groupby worst) ) {
70    ***     32     50                         156         die "I need a $arg argument" unless $args{$arg};
71                                                       }
72            16           100                  109      my $attributes = $args{attributes} || {};
73             3                                 27      my $self = {
74                                                          groupby        => $args{groupby},
75                                                          detect_attribs => scalar keys %$attributes == 0 ? 1 : 0,
76                                                          all_attribs    => [ keys %$attributes ],
77                                                          ignore_attribs => {
78             3                                 13            map  { $_ => $args{attributes}->{$_} }
79            16                                149            grep { $_ ne $args{groupby} }
80            21                                123            @{$args{ignore_attributes}}
81                                                          },
82                                                          attributes     => {
83            22                                 90            map  { $_ => $args{attributes}->{$_} }
84            21                                105            grep { $_ ne $args{groupby} }
85                                                             keys %$attributes
86                                                          },
87                                                          alt_attribs    => {
88            21                                 61            map  { $_ => make_alt_attrib(@{$args{attributes}->{$_}}) }
              22                                 83   
89            16    100                         245            grep { $_ ne $args{groupby} }
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
100           16    100    100                  162         type_for       => { %{$args{type_for} || {}} },
101                                                      };
102           16                                178      return bless $self, $class;
103                                                   }
104                                                   
105                                                   # Delete all collected data, but don't delete things like the generated
106                                                   # subroutines.  Resetting aggregated data is an interesting little exercise.
107                                                   # The generated functions that do aggregation have private namespaces with
108                                                   # references to some of the data.  Thus, they will not necessarily do as
109                                                   # expected if the stored data is simply wiped out.  Instead, it needs to be
110                                                   # zeroed out without replacing the actual objects.
111                                                   sub reset_aggregated_data {
112            1                    1            12      my ( $self ) = @_;
113            1                                  3      foreach my $class ( values %{$self->{result_classes}} ) {
               1                                  7   
114            1                                  5         foreach my $attrib ( values %$class ) {
115            2                                  8            delete @{$attrib}{keys %$attrib};
               2                                 41   
116                                                         }
117                                                      }
118            1                                  4      foreach my $class ( values %{$self->{result_globals}} ) {
               1                                  5   
119            2                                  8         delete @{$class}{keys %$class};
               2                                 32   
120                                                      }
121            1                                  4      delete @{$self->{result_samples}}{keys %{$self->{result_samples}}};
               1                                  5   
               1                                  6   
122            1                                  5      $self->{n_events} = 0;
123                                                   }
124                                                   
125                                                   # Aggregate an event hashref's properties.  Code is built on the fly to do this,
126                                                   # based on the values being passed in.  After code is built for every attribute
127                                                   # (or 50 events are seen and we decide to give up) the little bits of code get
128                                                   # unrolled into a whole subroutine to handle events.  For that reason, you can't
129                                                   # re-use an instance.
130                                                   sub aggregate {
131         1701                 1701         22328      my ( $self, $event ) = @_;
132                                                   
133         1701                               6581      my $group_by = $event->{$self->{groupby}};
134         1701    100                        5907      return unless defined $group_by;
135                                                   
136         1699                               4961      $self->{n_events}++;
137         1699                               3572      MKDEBUG && _d('event', $self->{n_events});
138                                                   
139                                                      # Run only unrolled loops if available.
140         1699    100                        7778      return $self->{unrolled_loops}->($self, $event, $group_by)
141                                                         if $self->{unrolled_loops};
142                                                   
143                                                      # For the first unroll_limit events, auto-detect new attribs and
144                                                      # run attrib handlers.
145         1263    100                        5469      if ( $self->{n_events} <= $self->{unroll_limit} ) {
146                                                   
147         1261    100                        5800         $self->add_new_attributes($event) if $self->{detect_attribs};
148                                                   
149         1261                               5834         ATTRIB:
150         1261                               3080         foreach my $attrib ( keys %{$self->{attributes}} ) {
151                                                   
152                                                            # Attrib auto-detection can add a lot of attributes which some events
153                                                            # may or may not have.  Aggregating a nonexistent attrib is wasteful,
154                                                            # so we check that the attrib or one of its alternates exists.  If
155                                                            # one does, then we leave attrib alone because the handler sub will
156                                                            # also check alternates.
157         4579    100                       18514            if ( !exists $event->{$attrib} ) {
158           16                                 37               MKDEBUG && _d("attrib doesn't exist in event:", $attrib);
159           16                                 79               my $alt_attrib = $self->{alt_attribs}->{$attrib}->($event);
160           16                                 35               MKDEBUG && _d('alt attrib:', $alt_attrib);
161           16    100                          76               next ATTRIB unless $alt_attrib;
162                                                            }
163                                                   
164                                                            # The value of the attribute ( $group_by ) may be an arrayref.
165                                                            GROUPBY:
166         4564    100                       17154            foreach my $val ( ref $group_by ? @$group_by : ($group_by) ) {
167         4566           100                25573               my $class_attrib  = $self->{result_classes}->{$val}->{$attrib} ||= {};
168         4566           100                20997               my $global_attrib = $self->{result_globals}->{$attrib} ||= {};
169         4566                              13574               my $samples       = $self->{result_samples};
170         4566                              15554               my $handler = $self->{handlers}->{ $attrib };
171         4566    100                       15760               if ( !$handler ) {
172           76                                508                  $handler = $self->make_handler(
173                                                                     $attrib,
174                                                                     $event,
175                                                                     wor => $self->{worst} eq $attrib,
176                                                                     alt => $self->{attributes}->{$attrib},
177                                                                  );
178           76                                338                  $self->{handlers}->{$attrib} = $handler;
179                                                               }
180   ***   4566     50                       15188               next GROUPBY unless $handler;
181         4566           100                17264               $samples->{$val} ||= $event; # Initialize to the first event.
182         4566                              18953               $handler->($event, $class_attrib, $global_attrib, $samples, $group_by);
183                                                            }
184                                                         }
185                                                      }
186                                                      else {
187                                                         # After unroll_limit events, unroll the loops.
188            2                                 11         $self->_make_unrolled_loops($event);
189                                                         # Run unrolled loops here once.  Next time, they'll be ran
190                                                         # before this if-else.
191            2                                 11         $self->{unrolled_loops}->($self, $event, $group_by);
192                                                      }
193                                                   
194         1263                               7054      return;
195                                                   }
196                                                   
197                                                   sub _make_unrolled_loops {
198            2                    2             9      my ( $self, $event ) = @_;
199                                                   
200            2                                 10      my $group_by = $event->{$self->{groupby}};
201                                                   
202                                                      # All attributes have handlers, so let's combine them into one faster sub.
203                                                      # Start by getting direct handles to the location of each data store and
204                                                      # thing that would otherwise be looked up via hash keys.
205            2                                  6      my @attrs   = grep { $self->{handlers}->{$_} } keys %{$self->{attributes}};
              16                                 65   
               2                                 12   
206            2                                 11      my $globs   = $self->{result_globals}; # Global stats for each
207            2                                  6      my $samples = $self->{result_samples};
208                                                   
209                                                      # Now the tricky part -- must make sure only the desired variables from
210                                                      # the outer scope are re-used, and any variables that should have their
211                                                      # own scope are declared within the subroutine.
212   ***      2     50                          18      my @lines = (
213                                                         'my ( $self, $event, $group_by ) = @_;',
214                                                         'my ($val, $class, $global, $idx);',
215                                                         (ref $group_by ? ('foreach my $group_by ( @$group_by ) {') : ()),
216                                                         # Create and get each attribute's storage
217                                                         'my $temp = $self->{result_classes}->{ $group_by }
218                                                            ||= { map { $_ => { } } @attrs };',
219                                                         '$samples->{$group_by} ||= $event;', # Always start with the first.
220                                                      );
221            2                                 18      foreach my $i ( 0 .. $#attrs ) {
222                                                         # Access through array indexes, it's faster than hash lookups
223           16                                135         push @lines, (
224                                                            '$class  = $temp->{"'  . $attrs[$i] . '"};',
225                                                            '$global = $globs->{"' . $attrs[$i] . '"};',
226                                                            $self->{unrolled_for}->{$attrs[$i]},
227                                                         );
228                                                      }
229   ***      2     50                           9      if ( ref $group_by ) {
230   ***      0                                  0         push @lines, '}'; # Close the loop opened above
231                                                      }
232            2                                  8      @lines = map { s/^/   /gm; $_ } @lines; # Indent for debugging
              56                                360   
              56                                212   
233            2                                 19      unshift @lines, 'sub {';
234            2                                  8      push @lines, '}';
235                                                   
236                                                      # Make the subroutine.
237            2                                 50      my $code = join("\n", @lines);
238            2                                  7      MKDEBUG && _d('Unrolled subroutine:', @lines);
239            2                               2259      my $sub = eval $code;
240   ***      2     50                          12      die $EVAL_ERROR if $EVAL_ERROR;
241            2                                  7      $self->{unrolled_loops} = $sub;
242                                                   
243            2                                 11      return;
244                                                   }
245                                                   
246                                                   # Return the aggregated results.
247                                                   sub results {
248           19                   19          6092      my ( $self ) = @_;
249                                                      return {
250           19                                293         classes => $self->{result_classes},
251                                                         globals => $self->{result_globals},
252                                                         samples => $self->{result_samples},
253                                                      };
254                                                   }
255                                                   
256                                                   # Return the attributes that this object is tracking, and their data types, as
257                                                   # a hashref of name => type.
258                                                   sub attributes {
259            1                    1             5      my ( $self ) = @_;
260            1                                  9      return $self->{type_for};
261                                                   }
262                                                   
263                                                   # Returns the type of the attribute (as decided by the aggregation process,
264                                                   # which inspects the values).
265                                                   sub type_for {
266           79                   79           293      my ( $self, $attrib ) = @_;
267           79                               1047      return $self->{type_for}->{$attrib};
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
307           76                   76           471      my ( $self, $attrib, $event, %args ) = @_;
308   ***     76     50                         323      die "I need an attrib" unless defined $attrib;
309           76                                215      my ($val) = grep { defined $_ } map { $event->{$_} } @{ $args{alt} };
              77                                369   
              77                                311   
              76                                285   
310           76                                259      my $is_array = 0;
311   ***     76     50                         315      if (ref $val eq 'ARRAY') {
312   ***      0                                  0         $is_array = 1;
313   ***      0                                  0         $val      = $val->[0];
314                                                      }
315   ***     76     50                         278      return unless defined $val; # Can't decide type if it's undef.
316                                                   
317                                                      # Ripped off from Regexp::Common::number and modified.
318           76                                433      my $float_re = qr{[+-]?(?:(?=\d|[.])\d+(?:[.])\d{0,})(?:E[+-]?\d+)?}i;
319           76    100                         313      my $type = $self->type_for($attrib)         ? $self->type_for($attrib)
                    100                               
      ***            50                               
320                                                               : $val  =~ m/^(?:\d+|$float_re)$/o ? 'num'
321                                                               : $val  =~ m/^(?:Yes|No)$/         ? 'bool'
322                                                               :                                    'string';
323           76                                191      MKDEBUG && _d('Type for', $attrib, 'is', $type,
324                                                         '(sample:', $val, '), is array:', $is_array);
325           76                                328      $self->{type_for}->{$attrib} = $type;
326                                                   
327           76    100                        1578      %args = ( # Set up defaults
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
341           76                                432      my @lines = ("# type: $type"); # Lines of code for the subroutine
342           76    100                         386      if ( $args{trf} ) {
343           14                                 68         push @lines, q{$val = } . $args{trf} . ';';
344                                                      }
345                                                   
346           76                                257      foreach my $place ( qw($class $global) ) {
347          152                                345         my @tmp;
348   ***    152     50                         592         if ( $args{min} ) {
349          152    100                         636            my $op   = $type eq 'num' ? '<' : 'lt';
350          152                                598            push @tmp, (
351                                                               'PLACE->{min} = $val if !defined PLACE->{min} || $val '
352                                                                  . $op . ' PLACE->{min};',
353                                                            );
354                                                         }
355   ***    152     50                         590         if ( $args{max} ) {
356          152    100                         539            my $op = ($type eq 'num') ? '>' : 'gt';
357          152                                543            push @tmp, (
358                                                               'PLACE->{max} = $val if !defined PLACE->{max} || $val '
359                                                                  . $op . ' PLACE->{max};',
360                                                            );
361                                                         }
362          152    100                         569         if ( $args{sum} ) {
363          112                                330            push @tmp, 'PLACE->{sum} += $val;';
364                                                         }
365   ***    152     50                         556         if ( $args{cnt} ) {
366          152                                448            push @tmp, '++PLACE->{cnt};';
367                                                         }
368          152    100                         563         if ( $args{all} ) {
369           84                                287            push @tmp, (
370                                                               'exists PLACE->{all} or PLACE->{all} = [ @buckets ];',
371                                                               '++PLACE->{all}->[ EventAggregator::bucket_idx($val) ];',
372                                                            );
373                                                         }
374          152                                595         push @lines, map { s/PLACE/$place/g; $_ } @tmp;
             736                               3507   
             736                               2620   
375                                                      }
376                                                   
377                                                      # We only save unique/worst values for the class, not globally.
378           76    100                         331      if ( $args{unq} ) {
379           34                                106         push @lines, '++$class->{unq}->{$val};';
380                                                      }
381           76    100                         286      if ( $args{wor} ) {
382   ***     10     50                          41         my $op = $type eq 'num' ? '>=' : 'ge';
383           10                                 51         push @lines, (
384                                                            'if ( $val ' . $op . ' ($class->{max} || 0) ) {',
385                                                            '   $samples->{$group_by} = $event;',
386                                                            '}',
387                                                         );
388                                                      }
389                                                   
390                                                      # Make sure the value is constrained to legal limits.  If it's out of bounds,
391                                                      # just use the last-seen value for it.
392           76                                182      my @limit;
393   ***     76    100     66                  716      if ( $args{all} && $type eq 'num' && $self->{attrib_limit} ) {
                           100                        
394            1                                  7         push @limit, (
395                                                            "if ( \$val > $self->{attrib_limit} ) {",
396                                                            '   $val = $class->{last} ||= 0;',
397                                                            '}',
398                                                            '$class->{last} = $val;',
399                                                         );
400                                                      }
401                                                   
402                                                      # Save the code for later, as part of an "unrolled" subroutine.
403            1                                  6      my @unrolled = (
404                                                         "\$val = \$event->{'$attrib'};",
405                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
406           77                                348         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
407           76                                275            grep { $_ ne $attrib } @{$args{alt}}),
             894                               3137   
408                                                         'defined $val && do {',
409   ***     76     50                         354         ( map { s/^/   /gm; $_ } (@limit, @lines) ), # Indent for debugging
      ***    894     50                        3259   
410                                                         '};',
411                                                         ($is_array ? ('}') : ()),
412                                                      );
413           76                                750      $self->{unrolled_for}->{$attrib} = join("\n", @unrolled);
414                                                   
415                                                      # Build a subroutine with the code.
416            1                                  8      unshift @lines, (
417                                                         'sub {',
418                                                         'my ( $event, $class, $global, $samples, $group_by ) = @_;',
419                                                         'my ($val, $idx);', # NOTE: define all variables here
420                                                         "\$val = \$event->{'$attrib'};",
421           77                                548         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
422   ***     76     50                         340            grep { $_ ne $attrib } @{$args{alt}}),
      ***     76     50                         274   
423                                                         'return unless defined $val;',
424                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
425                                                         @limit,
426                                                         ($is_array ? ('}') : ()),
427                                                      );
428           76                                234      push @lines, '}';
429           76                                430      my $code = join("\n", @lines);
430           76                                340      $self->{code_for}->{$attrib} = $code;
431                                                   
432           76                                163      MKDEBUG && _d('Metric handler for', $attrib, ':', @lines);
433           76                              13492      my $sub = eval join("\n", @lines);
434   ***     76     50                         318      die if $EVAL_ERROR;
435           76                                829      return $sub;
436                                                   }
437                                                   
438                                                   # Returns the bucket number for the given val. Buck numbers are zero-indexed,
439                                                   # so although there are 1,000 buckets (NUM_BUCK), 999 is the greatest idx.
440                                                   # *** Notice that this sub is not a class method, so either call it
441                                                   # from inside this module like bucket_idx() or outside this module
442                                                   # like EventAggregator::bucket_idx(). ***
443                                                   # TODO: could export this by default to avoid having to specific packge::.
444                                                   sub bucket_idx {
445         7874                 7874         35296      my ( $val ) = @_;
446         7874    100                       33278      return 0 if $val < MIN_BUCK;
447         6396                              24999      my $idx = int(BASE_OFFSET + log($val)/BASE_LOG);
448         6396    100                       36579      return $idx > (NUM_BUCK-1) ? (NUM_BUCK-1) : $idx;
449                                                   }
450                                                   
451                                                   # Returns the value for the given bucket.
452                                                   # The value of each bucket is the first value that it covers. So the value
453                                                   # of bucket 1 is 0.000001000 because it covers [0.000001000, 0.000001050).
454                                                   #
455                                                   # *** Notice that this sub is not a class method, so either call it
456                                                   # from inside this module like bucket_idx() or outside this module
457                                                   # like EventAggregator::bucket_value(). ***
458                                                   # TODO: could export this by default to avoid having to specific packge::.
459                                                   sub bucket_value {
460         1007                 1007          3162      my ( $bucket ) = @_;
461         1007    100                        3570      return 0 if $bucket == 0;
462   ***   1005     50     33                 7312      die "Invalid bucket: $bucket" if $bucket < 0 || $bucket > (NUM_BUCK-1);
463                                                      # $bucket - 1 because buckets are shifted up by 1 to handle zero values.
464         1005                               4534      return (BUCK_SIZE**($bucket-1)) * MIN_BUCK;
465                                                   }
466                                                   
467                                                   # Map the 1,000 base 1.05 buckets to 8 base 10 buckets. Returns an array
468                                                   # of 1,000 buckets, the value of each represents its index in an 8 bucket
469                                                   # base 10 array. For example: base 10 bucket 0 represents vals (0, 0.000010),
470                                                   # and base 1.05 buckets 0..47 represent vals (0, 0.000010401). So the first
471                                                   # 48 elements of the returned array will have 0 as their values. 
472                                                   # TODO: right now it's hardcoded to buckets of 10, in the future maybe not.
473                                                   {
474                                                      my @buck_tens;
475                                                      sub buckets_of {
476   ***      1     50             1             6         return @buck_tens if @buck_tens;
477                                                   
478                                                         # To make a more precise map, we first set the starting values for
479                                                         # each of the 8 base 10 buckets. 
480            1                                  3         my $start_bucket  = 0;
481            1                                  4         my @base10_starts = (0);
482            1                                  3         map { push @base10_starts, (10**$_)*MIN_BUCK } (1..7);
               7                                 30   
483                                                   
484                                                         # Then find the base 1.05 buckets that correspond to each
485                                                         # base 10 bucket. The last value in each bucket's range belongs
486                                                         # to the next bucket, so $next_bucket-1 represents the real last
487                                                         # base 1.05 bucket in which the base 10 bucket's range falls.
488            1                                  6         for my $base10_bucket ( 0..($#base10_starts-1) ) {
489            7                                 29            my $next_bucket = bucket_idx( $base10_starts[$base10_bucket+1] );
490            7                                 15            MKDEBUG && _d('Base 10 bucket', $base10_bucket, 'maps to',
491                                                               'base 1.05 buckets', $start_bucket, '..', $next_bucket-1);
492            7                                 24            for my $base1_05_bucket ($start_bucket..($next_bucket-1)) {
493          331                               1008               $buck_tens[$base1_05_bucket] = $base10_bucket;
494                                                            }
495            7                                 23            $start_bucket = $next_bucket;
496                                                         }
497                                                   
498                                                         # Map all remaining base 1.05 buckets to base 10 bucket 7 which
499                                                         # is for vals > 10.
500            1                                 30         map { $buck_tens[$_] = 7 } ($start_bucket..(NUM_BUCK-1));
             669                               2115   
501                                                   
502            1                                123         return @buck_tens;
503                                                      }
504                                                   }
505                                                   
506                                                   # Given an arrayref of vals, returns a hashref with the following
507                                                   # statistical metrics:
508                                                   #
509                                                   #    pct_95    => top bucket value in the 95th percentile
510                                                   #    cutoff    => How many values fall into the 95th percentile
511                                                   #    stddev    => of all values
512                                                   #    median    => of all values
513                                                   #
514                                                   # The vals arrayref is the buckets as per the above (see the comments at the top
515                                                   # of this file).  $args should contain cnt, min and max properties.
516                                                   sub calculate_statistical_metrics {
517           17                   17          4323      my ( $self, $vals, $args ) = @_;
518           17                                 96      my $statistical_metrics = {
519                                                         pct_95    => 0,
520                                                         stddev    => 0,
521                                                         median    => 0,
522                                                         cutoff    => undef,
523                                                      };
524                                                   
525                                                      # These cases might happen when there is nothing to get from the event, for
526                                                      # example, processlist sniffing doesn't gather Rows_examined, so $args won't
527                                                      # have {cnt} or other properties.
528           17    100    100                  203      return $statistical_metrics
                           100                        
529                                                         unless defined $vals && @$vals && $args->{cnt};
530                                                   
531                                                      # Return accurate metrics for some cases.
532           13                                 45      my $n_vals = $args->{cnt};
533           13    100    100                  120      if ( $n_vals == 1 || $args->{max} == $args->{min} ) {
                    100                               
534   ***      7            50                   30         my $v      = $args->{max} || 0;
535   ***      7     50                          43         my $bucket = int(6 + ( log($v > 0 ? $v : MIN_BUCK) / log(10)));
536   ***      7     50                          33         $bucket    = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
537                                                         return {
538            7                                109            pct_95 => $v,
539                                                            stddev => 0,
540                                                            median => $v,
541                                                            cutoff => $n_vals,
542                                                         };
543                                                      }
544                                                      elsif ( $n_vals == 2 ) {
545            1                                  4         foreach my $v ( $args->{min}, $args->{max} ) {
546   ***      2     50     33                   21            my $bucket = int(6 + ( log($v && $v > 0 ? $v : MIN_BUCK) / log(10)));
547   ***      2     50                          12            $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
548                                                         }
549   ***      1            50                    6         my $v      = $args->{max} || 0;
550   ***      1            50                    6         my $mean = (($args->{min} || 0) + $v) / 2;
551                                                         return {
552            1                                 10            pct_95 => $v,
553                                                            stddev => sqrt((($v - $mean) ** 2) *2),
554                                                            median => $mean,
555                                                            cutoff => $n_vals,
556                                                         };
557                                                      }
558                                                   
559                                                      # Determine cutoff point for 95% if there are at least 10 vals.  Cutoff
560                                                      # serves also for the number of vals left in the 95%.  E.g. with 50 vals the
561                                                      # cutoff is 47 which means there are 47 vals: 0..46.  $cutoff is NOT an array
562                                                      # index.
563            5    100                          29      my $cutoff = $n_vals >= 10 ? int ( $n_vals * 0.95 ) : $n_vals;
564            5                                 16      $statistical_metrics->{cutoff} = $cutoff;
565                                                   
566                                                      # Calculate the standard deviation and median of all values.
567            5                                 14      my $total_left = $n_vals;
568            5                                 15      my $top_vals   = $n_vals - $cutoff; # vals > 95th
569            5                                 12      my $sum_excl   = 0;
570            5                                 12      my $sum        = 0;
571            5                                 14      my $sumsq      = 0;
572            5                                 16      my $mid        = int($n_vals / 2);
573            5                                 14      my $median     = 0;
574            5                                 12      my $prev       = NUM_BUCK-1; # Used for getting median when $cutoff is odd
575            5                                 13      my $bucket_95  = 0; # top bucket in 95th
576                                                   
577            5                                 11      MKDEBUG && _d('total vals:', $total_left, 'top vals:', $top_vals, 'mid:', $mid);
578                                                   
579                                                      BUCKET:
580            5                                 30      for my $bucket ( reverse 0..(NUM_BUCK-1) ) {
581         5000                              14033         my $val = $vals->[$bucket];
582         5000    100                       18616         next BUCKET unless $val; 
583                                                   
584           19                                 49         $total_left -= $val;
585           19                                 51         $sum_excl   += $val;
586           19    100    100                  115         $bucket_95   = $bucket if !$bucket_95 && $sum_excl > $top_vals;
587                                                   
588           19    100    100                  125         if ( !$median && $total_left <= $mid ) {
589   ***      5     50     66                   44            $median = (($cutoff % 2) || ($val > 1)) ? $buck_vals[$bucket]
590                                                                    : ($buck_vals[$bucket] + $buck_vals[$prev]) / 2;
591                                                         }
592                                                   
593           19                                 65         $sum    += $val * $buck_vals[$bucket];
594           19                                 67         $sumsq  += $val * ($buck_vals[$bucket]**2);
595           19                                 59         $prev   =  $bucket;
596                                                      }
597                                                   
598            5                                 27      my $var      = $sumsq/$n_vals - ( ($sum/$n_vals) ** 2 );
599            5    100                          33      my $stddev   = $var > 0 ? sqrt($var) : 0;
600   ***      5            50                   40      my $maxstdev = (($args->{max} || 0) - ($args->{min} || 0)) / 2;
                           100                        
601   ***      5     50                          21      $stddev      = $stddev > $maxstdev ? $maxstdev : $stddev;
602                                                   
603            5                                 12      MKDEBUG && _d('sum:', $sum, 'sumsq:', $sumsq, 'stddev:', $stddev,
604                                                         'median:', $median, 'prev bucket:', $prev,
605                                                         'total left:', $total_left, 'sum excl', $sum_excl,
606                                                         'bucket 95:', $bucket_95, $buck_vals[$bucket_95]);
607                                                   
608            5                                 17      $statistical_metrics->{stddev} = $stddev;
609            5                                 18      $statistical_metrics->{pct_95} = $buck_vals[$bucket_95];
610            5                                 15      $statistical_metrics->{median} = $median;
611                                                   
612            5                                 26      return $statistical_metrics;
613                                                   }
614                                                   
615                                                   # Return a hashref of the metrics for some attribute, pre-digested.
616                                                   # %args is:
617                                                   #  attrib => the attribute to report on
618                                                   #  where  => the value of the fingerprint for the attrib
619                                                   sub metrics {
620            2                    2            13      my ( $self, %args ) = @_;
621            2                                  8      foreach my $arg ( qw(attrib where) ) {
622   ***      4     50                          19         die "I need a $arg argument" unless $args{$arg};
623                                                      }
624            2                                  9      my $stats = $self->results;
625            2                                 12      my $store = $stats->{classes}->{$args{where}}->{$args{attrib}};
626                                                   
627            2                                 10      my $global_cnt = $stats->{globals}->{$args{attrib}}->{cnt};
628            2                                 11      my $metrics    = $self->calculate_statistical_metrics($store->{all}, $store);
629                                                   
630                                                      return {
631   ***      2    100     66                   69         cnt    => $store->{cnt},
      ***           100     66                        
632                                                         pct    => $global_cnt && $store->{cnt} ? $store->{cnt} / $global_cnt : 0,
633                                                         sum    => $store->{sum},
634                                                         min    => $store->{min},
635                                                         max    => $store->{max},
636                                                         avg    => $store->{sum} && $store->{cnt} ? $store->{sum} / $store->{cnt} : 0,
637                                                         median => $metrics->{median},
638                                                         pct_95 => $metrics->{pct_95},
639                                                         stddev => $metrics->{stddev},
640                                                      };
641                                                   }
642                                                   
643                                                   # Find the top N or top % event keys, in sorted order, optionally including
644                                                   # outliers (ol_...) that are notable for some reason.  %args looks like this:
645                                                   #
646                                                   #  attrib      order-by attribute (usually Query_time)
647                                                   #  orderby     order-by aggregate expression (should be numeric, usually sum)
648                                                   #  total       include events whose summed attribs are <= this number...
649                                                   #  count       ...or this many events, whichever is less...
650                                                   #  ol_attrib   ...or events where the 95th percentile of this attribute...
651                                                   #  ol_limit    ...is greater than this value, AND...
652                                                   #  ol_freq     ...the event occurred at least this many times.
653                                                   # The return value is a list of arrayrefs.  Each arrayref is the event key and
654                                                   # an explanation of why it was included (top|outlier).
655                                                   sub top_events {
656            3                    3            52      my ( $self, %args ) = @_;
657            3                                 12      my $classes = $self->{result_classes};
658           15                                 94      my @sorted = reverse sort { # Sorted list of $groupby values
659           16                                 73         $classes->{$a}->{$args{attrib}}->{$args{orderby}}
660                                                            <=> $classes->{$b}->{$args{attrib}}->{$args{orderby}}
661                                                         } grep {
662                                                            # Defensive programming
663            3                                 16            defined $classes->{$_}->{$args{attrib}}->{$args{orderby}}
664                                                         } keys %$classes;
665            3                                 20      my @chosen;
666            3                                 11      my ($total, $count) = (0, 0);
667            3                                 11      foreach my $groupby ( @sorted ) {
668                                                         # Events that fall into the top criterion for some reason
669           15    100    100                  242         if ( 
      ***           100     66                        
                           100                        
                           100                        
                           100                        
670                                                            (!$args{total} || $total < $args{total} )
671                                                            && ( !$args{count} || $count < $args{count} )
672                                                         ) {
673            6                                 24            push @chosen, [$groupby, 'top'];
674                                                         }
675                                                   
676                                                         # Events that are notable outliers
677                                                         elsif ( $args{ol_attrib} && (!$args{ol_freq}
678                                                            || $classes->{$groupby}->{$args{ol_attrib}}->{cnt} >= $args{ol_freq})
679                                                         ) {
680                                                            # Calculate the 95th percentile of this event's specified attribute.
681            5                                 11            MKDEBUG && _d('Calculating statistical_metrics');
682            5                                 36            my $stats = $self->calculate_statistical_metrics(
683                                                               $classes->{$groupby}->{$args{ol_attrib}}->{all},
684                                                               $classes->{$groupby}->{$args{ol_attrib}}
685                                                            );
686            5    100                          26            if ( $stats->{pct_95} >= $args{ol_limit} ) {
687            3                                 17               push @chosen, [$groupby, 'outlier'];
688                                                            }
689                                                         }
690                                                   
691           15                                 72         $total += $classes->{$groupby}->{$args{attrib}}->{$args{orderby}};
692           15                                 44         $count++;
693                                                      }
694            3                                 26      return @chosen;
695                                                   }
696                                                   
697                                                   # Adds all new attributes in $event to $self->{attributes}.
698                                                   sub add_new_attributes {
699          238                  238           896      my ( $self, $event ) = @_;
700   ***    238     50                         927      return unless $event;
701                                                   
702           56                                145      map {
703         3761    100    100                33828         my $attrib = $_;
704           56                                245         $self->{attributes}->{$attrib}  = [$attrib];
705           56                                186         $self->{alt_attribs}->{$attrib} = make_alt_attrib($attrib);
706           56                                141         push @{$self->{all_attribs}}, $attrib;
              56                                214   
707           56                                170         MKDEBUG && _d('Added new attribute:', $attrib);
708                                                      }
709                                                      grep {
710          238                               1633         $_ ne $self->{groupby}
711                                                         && !exists $self->{attributes}->{$_}
712                                                         && !exists $self->{ignore_attribs}->{$_}
713                                                      }
714                                                      keys %$event;
715                                                   
716          238                               1228      return;
717                                                   }
718                                                   
719                                                   # Returns a list of all the attributes that were either given
720                                                   # explicitly to new() or that were auto-detected.
721                                                   sub get_attributes {
722            1                    1           129      my ( $self ) = @_;
723            1                                  3      return @{$self->{all_attribs}};
               1                                 17   
724                                                   }
725                                                   
726                                                   sub events_processed {
727            1                    1             4      my ( $self ) = @_;
728            1                                  7      return $self->{n_events};
729                                                   }
730                                                   
731                                                   sub make_alt_attrib {
732           77                   77           296      my ( @attribs ) = @_;
733                                                   
734           77                                231      my $attrib = shift @attribs;  # Primary attribute.
735           77    100            15           700      return sub {} unless @attribs;  # No alternates.
              15                                 57   
736                                                   
737            1                                  3      my @lines;
738            1                                  4      push @lines, 'sub { my ( $event ) = @_; my $alt_attrib;';
739            1                                  7      push @lines, map  {
740            1                                  3            "\$alt_attrib = '$_' if !defined \$alt_attrib "
741                                                            . "&& exists \$event->{'$_'};"
742                                                         } @attribs;
743            1                                  3      push @lines, 'return $alt_attrib; }';
744            1                                  3      MKDEBUG && _d('alt attrib sub for', $attrib, ':', @lines);
745            1                                 84      my $sub = eval join("\n", @lines);
746   ***      1     50                           5      die if $EVAL_ERROR;
747            1                                 16      return $sub;
748                                                   }
749                                                   
750                                                   sub _d {
751   ***      0                    0                    my ($package, undef, $line) = caller 0;
752   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
753   ***      0                                              map { defined $_ ? $_ : 'undef' }
754                                                           @_;
755   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
756                                                   }
757                                                   
758                                                   1;
759                                                   
760                                                   # ###########################################################################
761                                                   # End EventAggregator package
762                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
70    ***     50      0     32   unless $args{$arg}
89           100     15      1   unless $args{'type_for'}
100          100      5     11   scalar keys %$attributes == 0 ? :
134          100      2   1699   unless defined $group_by
140          100    436   1263   if $$self{'unrolled_loops'}
145          100   1261      2   if ($$self{'n_events'} <= $$self{'unroll_limit'}) { }
147          100    238   1023   if $$self{'detect_attribs'}
157          100     16   4563   if (not exists $$event{$attrib})
161          100     15      1   unless $alt_attrib
166          100      4   4560   ref $group_by ? :
171          100     76   4490   if (not $handler)
180   ***     50      0   4566   unless $handler
212   ***     50      0      2   ref $group_by ? :
229   ***     50      0      2   if (ref $group_by)
240   ***     50      0      2   if $EVAL_ERROR
308   ***     50      0     76   unless defined $attrib
311   ***     50      0     76   if (ref $val eq 'ARRAY')
315   ***     50      0     76   unless defined $val
319          100     14     20   $val =~ /^(?:Yes|No)$/ ? :
             100     42     34   $val =~ /^(?:\d+|$float_re)$/o ? :
      ***     50      0     76   $self->type_for($attrib) ? :
327          100     56     20   $type =~ /num|bool/ ? :
             100     34     42   $type =~ /bool|string/ ? :
             100     42     34   $type eq 'num' ? :
             100     14     62   $type eq 'bool' ? :
342          100     14     62   if ($args{'trf'})
348   ***     50    152      0   if ($args{'min'})
349          100     84     68   $type eq 'num' ? :
355   ***     50    152      0   if ($args{'max'})
356          100     84     68   $type eq 'num' ? :
362          100    112     40   if ($args{'sum'})
365   ***     50    152      0   if ($args{'cnt'})
368          100     84     68   if ($args{'all'})
378          100     34     42   if ($args{'unq'})
381          100     10     66   if ($args{'wor'})
382   ***     50     10      0   $type eq 'num' ? :
393          100      1     75   if ($args{'all'} and $type eq 'num' and $$self{'attrib_limit'})
409   ***     50      0     76   $is_array ? :
      ***     50      0     76   $is_array ? :
422   ***     50      0     76   $is_array ? :
      ***     50      0     76   $is_array ? :
434   ***     50      0     76   if $EVAL_ERROR
446          100   1478   6396   if $val < 1e-06
448          100      1   6395   $idx > 999 ? :
461          100      2   1005   if $bucket == 0
462   ***     50      0   1005   if $bucket < 0 or $bucket > 999
476   ***     50      0      1   if @buck_tens
528          100      4     13   unless defined $vals and @$vals and $$args{'cnt'}
533          100      7      6   if ($n_vals == 1 or $$args{'max'} == $$args{'min'}) { }
             100      1      5   elsif ($n_vals == 2) { }
535   ***     50      7      0   $v > 0 ? :
536   ***     50      0      7   $bucket < 0 ? :
      ***     50      0      7   $bucket > 7 ? :
546   ***     50      2      0   $v && $v > 0 ? :
547   ***     50      0      2   $bucket < 0 ? :
      ***     50      0      2   $bucket > 7 ? :
563          100      4      1   $n_vals >= 10 ? :
582          100   4981     19   unless $val
586          100      5     14   if not $bucket_95 and $sum_excl > $top_vals
588          100      5     14   if (not $median and $total_left <= $mid)
589   ***     50      5      0   $cutoff % 2 || $val > 1 ? :
599          100      3      2   $var > 0 ? :
601   ***     50      0      5   $stddev > $maxstdev ? :
622   ***     50      0      4   unless $args{$arg}
631          100      1      1   $global_cnt && $$store{'cnt'} ? :
             100      1      1   $$store{'sum'} && $$store{'cnt'} ? :
669          100      6      9   if (!$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}) { }
             100      5      4   elsif ($args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}) { }
686          100      3      2   if ($$stats{'pct_95'} >= $args{'ol_limit'})
700   ***     50      0    238   unless $event
703          100     60   3701   if $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}
735          100     76      1   unless @attribs
746   ***     50      0      1   if $EVAL_ERROR
752   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
393   ***     66     34      0     42   $args{'all'} and $type eq 'num'
             100     34     41      1   $args{'all'} and $type eq 'num' and $$self{'attrib_limit'}
528          100      2      1     14   defined $vals and @$vals
             100      3      1     13   defined $vals and @$vals and $$args{'cnt'}
546   ***     33      0      0      2   $v && $v > 0
586          100     11      3      5   not $bucket_95 and $sum_excl > $top_vals
588          100      5      9      5   not $median and $total_left <= $mid
631   ***     66      1      0      1   $global_cnt && $$store{'cnt'}
      ***     66      1      0      1   $$store{'sum'} && $$store{'cnt'}
669          100      6      3      6   !$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}
             100      3      1      5   $args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}
703          100    238   3463     60   $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
72           100     11      5   $args{'attributes'} || {}
100          100      1     15   $args{'unroll_limit'} || 1000
167          100   4433    133   $$self{'result_classes'}{$val}{$attrib} ||= {}
168          100   4490     76   $$self{'result_globals'}{$attrib} ||= {}
181          100   4538     28   $$samples{$val} ||= $event
534   ***     50      7      0   $$args{'max'} || 0
549   ***     50      1      0   $$args{'max'} || 0
550   ***     50      1      0   $$args{'min'} || 0
600   ***     50      5      0   $$args{'max'} || 0
             100      4      1   $$args{'min'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
462   ***     33      0      0   1005   $bucket < 0 or $bucket > 999
533          100      3      4      6   $n_vals == 1 or $$args{'max'} == $$args{'min'}
589   ***     66      2      3      0   $cutoff % 2 || $val > 1
669          100      5      4      6   !$args{'total'} || $total < $args{'total'}
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
__ANON__                         15 /home/daniel/dev/maatkit/common/EventAggregator.pm:735
_make_unrolled_loops              2 /home/daniel/dev/maatkit/common/EventAggregator.pm:198
add_new_attributes              238 /home/daniel/dev/maatkit/common/EventAggregator.pm:699
aggregate                      1701 /home/daniel/dev/maatkit/common/EventAggregator.pm:131
attributes                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:259
bucket_idx                     7874 /home/daniel/dev/maatkit/common/EventAggregator.pm:445
bucket_value                   1007 /home/daniel/dev/maatkit/common/EventAggregator.pm:460
buckets_of                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:476
calculate_statistical_metrics    17 /home/daniel/dev/maatkit/common/EventAggregator.pm:517
events_processed                  1 /home/daniel/dev/maatkit/common/EventAggregator.pm:727
get_attributes                    1 /home/daniel/dev/maatkit/common/EventAggregator.pm:722
make_alt_attrib                  77 /home/daniel/dev/maatkit/common/EventAggregator.pm:732
make_handler                     76 /home/daniel/dev/maatkit/common/EventAggregator.pm:307
metrics                           2 /home/daniel/dev/maatkit/common/EventAggregator.pm:620
new                              16 /home/daniel/dev/maatkit/common/EventAggregator.pm:68 
reset_aggregated_data             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:112
results                          19 /home/daniel/dev/maatkit/common/EventAggregator.pm:248
top_events                        3 /home/daniel/dev/maatkit/common/EventAggregator.pm:656
type_for                         79 /home/daniel/dev/maatkit/common/EventAggregator.pm:266

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                              
----------------------------- ----- ------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/EventAggregator.pm:751


