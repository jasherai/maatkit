---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/EventAggregator.pm   97.0   77.8   82.4   96.6    n/a  100.0   90.0
Total                          97.0   77.8   82.4   96.6    n/a  100.0   90.0
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          EventAggregator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jul  8 14:37:42 2009
Finish:       Wed Jul  8 14:37:50 2009

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
18                                                    # EventAggregator package $Revision: 4086 $
19                                                    # ###########################################################################
20                                                    package EventAggregator;
21                                                    
22             1                    1            12   use strict;
               1                                  2   
               1                                  9   
23             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                 11   
25                                                    
26                                                    # ###########################################################################
27                                                    # Set up some constants for bucketing values.  It is impossible to keep all
28                                                    # values seen in memory, but putting them into logarithmically scaled buckets
29                                                    # and just incrementing the bucket each time works, although it is imprecise.
30                                                    # See http://code.google.com/p/maatkit/wiki/EventAggregatorInternals.
31                                                    # ###########################################################################
32             1                    1             7   use constant MKDEBUG      => $ENV{MKDEBUG};
               1                                  3   
               1                                 10   
33             1                    1            10   use constant BUCK_SIZE    => 1.05;
               1                                  3   
               1                                  4   
34             1                    1             5   use constant BASE_LOG     => log(BUCK_SIZE);
               1                                  3   
               1                                  4   
35             1                    1             6   use constant BASE_OFFSET  => abs(1 - log(0.000001) / BASE_LOG); # 284.1617969
               1                                  2   
               1                                  4   
36             1                    1             5   use constant NUM_BUCK     => 1000;
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
66                                                    sub new {
67            15                   15           347      my ( $class, %args ) = @_;
68            15                                 70      foreach my $arg ( qw(groupby worst) ) {
69    ***     30     50                         153         die "I need a $arg argument" unless $args{$arg};
70                                                       }
71            15           100                  108      my $attributes = $args{attributes} || {};
72             3                                 39      return bless {
73                                                          groupby        => $args{groupby},
74                                                          detect_attribs => scalar keys %$attributes == 0 ? 1 : 0,
75                                                          all_attribs    => [ keys %$attributes ],
76                                                          ignore_attribs => {
77             3                                 12            map  { $_ => $args{attributes}->{$_} }
78            15                                188            grep { $_ ne $args{groupby} }
79            19                                117            @{$args{ignore_attributes}}
80                                                          },
81                                                          attributes     => {
82            20                                 83            map  { $_ => $args{attributes}->{$_} }
83            19                                101            grep { $_ ne $args{groupby} }
84                                                             keys %$attributes
85                                                          },
86                                                          alt_attribs    => {
87            19                                 59            map  { $_ => make_alt_attrib(@{$args{attributes}->{$_}}) }
              20                                 82   
88            15    100    100                  143            grep { $_ ne $args{groupby} }
89                                                             keys %$attributes
90                                                          },
91                                                          worst        => $args{worst},
92                                                          unroll_limit => $args{unroll_limit} || 1000,
93                                                          attrib_limit => $args{attrib_limit},
94                                                          result_classes => {},
95                                                          result_globals => {},
96                                                          result_samples => {},
97                                                          n_events       => 0,
98                                                          unrolled_loops => undef,
99                                                       }, $class;
100                                                   }
101                                                   
102                                                   # Delete all collected data, but don't delete things like the generated
103                                                   # subroutines.  Resetting aggregated data is an interesting little exercise.
104                                                   # The generated functions that do aggregation have private namespaces with
105                                                   # references to some of the data.  Thus, they will not necessarily do as
106                                                   # expected if the stored data is simply wiped out.  Instead, it needs to be
107                                                   # zeroed out without replacing the actual objects.
108                                                   sub reset_aggregated_data {
109            1                    1            14      my ( $self ) = @_;
110            1                                  3      foreach my $class ( values %{$self->{result_classes}} ) {
               1                                  8   
111            1                                  5         foreach my $attrib ( values %$class ) {
112            2                                 11            delete @{$attrib}{keys %$attrib};
               2                                 42   
113                                                         }
114                                                      }
115            1                                  3      foreach my $class ( values %{$self->{result_globals}} ) {
               1                                  6   
116            2                                  8         delete @{$class}{keys %$class};
               2                                 38   
117                                                      }
118            1                                  4      delete @{$self->{result_samples}}{keys %{$self->{result_samples}}};
               1                                  4   
               1                                  5   
119            1                                  4      $self->{n_events} = 0;
120                                                   }
121                                                   
122                                                   # Aggregate an event hashref's properties.  Code is built on the fly to do this,
123                                                   # based on the values being passed in.  After code is built for every attribute
124                                                   # (or 50 events are seen and we decide to give up) the little bits of code get
125                                                   # unrolled into a whole subroutine to handle events.  For that reason, you can't
126                                                   # re-use an instance.
127                                                   sub aggregate {
128         1700                 1700         22909      my ( $self, $event ) = @_;
129                                                   
130         1700                               6668      my $group_by = $event->{$self->{groupby}};
131         1700    100                        6052      return unless defined $group_by;
132                                                   
133         1698                               4838      $self->{n_events}++;
134         1698                               3538      MKDEBUG && _d('event', $self->{n_events});
135                                                   
136                                                      # Run only unrolled loops if available.
137         1698    100                        8152      return $self->{unrolled_loops}->($self, $event, $group_by)
138                                                         if $self->{unrolled_loops};
139                                                   
140                                                      # For the first unroll_limit events, auto-detect new attribs and
141                                                      # run attrib handlers.
142         1262    100                        5424      if ( $self->{n_events} <= $self->{unroll_limit} ) {
143                                                   
144         1260    100                        5225         $self->add_new_attributes($event) if $self->{detect_attribs};
145                                                   
146         1260                               5846         ATTRIB:
147         1260                               2902         foreach my $attrib ( keys %{$self->{attributes}} ) {
148                                                   
149                                                            # Attrib auto-detection can add a lot of attributes which some events
150                                                            # may or may not have.  Aggregating a nonexistent attrib is wasteful,
151                                                            # so we check that the attrib or one of its alternates exists.  If
152                                                            # one does, then we leave attrib alone because the handler sub will
153                                                            # also check alternates.
154         4577    100                       18457            if ( !exists $event->{$attrib} ) {
155           15                                 33               MKDEBUG && _d("attrib doesn't exist in event:", $attrib);
156           15                                 94               my $alt_attrib = $self->{alt_attribs}->{$attrib}->($event);
157           15                                 32               MKDEBUG && _d('alt attrib:', $alt_attrib);
158           15    100                          87               next ATTRIB unless $alt_attrib;
159                                                            }
160                                                   
161                                                            # The value of the attribute ( $group_by ) may be an arrayref.
162                                                            GROUPBY:
163         4563    100                       17521            foreach my $val ( ref $group_by ? @$group_by : ($group_by) ) {
164         4565           100                24797               my $class_attrib  = $self->{result_classes}->{$val}->{$attrib} ||= {};
165         4565           100                21289               my $global_attrib = $self->{result_globals}->{$attrib} ||= {};
166         4565                              13655               my $samples       = $self->{result_samples};
167         4565                              15829               my $handler = $self->{handlers}->{ $attrib };
168         4565    100                       15853               if ( !$handler ) {
169           75                                552                  $handler = $self->make_handler(
170                                                                     $attrib,
171                                                                     $event,
172                                                                     wor => $self->{worst} eq $attrib,
173                                                                     alt => $self->{attributes}->{$attrib},
174                                                                  );
175           75                                365                  $self->{handlers}->{$attrib} = $handler;
176                                                               }
177   ***   4565     50                       15415               next GROUPBY unless $handler;
178         4565           100                17720               $samples->{$val} ||= $event; # Initialize to the first event.
179         4565                              19252               $handler->($event, $class_attrib, $global_attrib, $samples, $group_by);
180                                                            }
181                                                         }
182                                                      }
183                                                      else {
184                                                         # After unroll_limit events, unroll the loops.
185            2                                  9         $self->_make_unrolled_loops($event);
186                                                         # Run unrolled loops here once.  Next time, they'll be ran
187                                                         # before this if-else.
188            2                                 11         $self->{unrolled_loops}->($self, $event, $group_by);
189                                                      }
190                                                   
191         1262                               7124      return;
192                                                   }
193                                                   
194                                                   sub _make_unrolled_loops {
195            2                    2             8      my ( $self, $event ) = @_;
196                                                   
197            2                                 10      my $group_by = $event->{$self->{groupby}};
198                                                   
199                                                      # All attributes have handlers, so let's combine them into one faster sub.
200                                                      # Start by getting direct handles to the location of each data store and
201                                                      # thing that would otherwise be looked up via hash keys.
202            2                                  7      my @attrs   = grep { $self->{handlers}->{$_} } keys %{$self->{attributes}};
              16                                 65   
               2                                 13   
203            2                                  9      my $globs   = $self->{result_globals}; # Global stats for each
204            2                                  8      my $samples = $self->{result_samples};
205                                                   
206                                                      # Now the tricky part -- must make sure only the desired variables from
207                                                      # the outer scope are re-used, and any variables that should have their
208                                                      # own scope are declared within the subroutine.
209   ***      2     50                          15      my @lines = (
210                                                         'my ( $self, $event, $group_by ) = @_;',
211                                                         'my ($val, $class, $global, $idx);',
212                                                         (ref $group_by ? ('foreach my $group_by ( @$group_by ) {') : ()),
213                                                         # Create and get each attribute's storage
214                                                         'my $temp = $self->{result_classes}->{ $group_by }
215                                                            ||= { map { $_ => { } } @attrs };',
216                                                         '$samples->{$group_by} ||= $event;', # Always start with the first.
217                                                      );
218            2                                 18      foreach my $i ( 0 .. $#attrs ) {
219                                                         # Access through array indexes, it's faster than hash lookups
220           16                                141         push @lines, (
221                                                            '$class  = $temp->{"'  . $attrs[$i] . '"};',
222                                                            '$global = $globs->{"' . $attrs[$i] . '"};',
223                                                            $self->{unrolled_for}->{$attrs[$i]},
224                                                         );
225                                                      }
226   ***      2     50                          10      if ( ref $group_by ) {
227   ***      0                                  0         push @lines, '}'; # Close the loop opened above
228                                                      }
229            2                                  6      @lines = map { s/^/   /gm; $_ } @lines; # Indent for debugging
              56                                355   
              56                                207   
230            2                                 19      unshift @lines, 'sub {';
231            2                                  6      push @lines, '}';
232                                                   
233                                                      # Make the subroutine.
234            2                                 49      my $code = join("\n", @lines);
235            2                                  6      MKDEBUG && _d('Unrolled subroutine:', @lines);
236            2                               2268      my $sub = eval $code;
237   ***      2     50                          11      die $EVAL_ERROR if $EVAL_ERROR;
238            2                                  8      $self->{unrolled_loops} = $sub;
239                                                   
240            2                                 11      return;
241                                                   }
242                                                   
243                                                   # Return the aggregated results.
244                                                   sub results {
245           19                   19          6341      my ( $self ) = @_;
246                                                      return {
247           19                                334         classes => $self->{result_classes},
248                                                         globals => $self->{result_globals},
249                                                         samples => $self->{result_samples},
250                                                      };
251                                                   }
252                                                   
253                                                   # Return the attributes that this object is tracking, and their data types, as
254                                                   # a hashref of name => type.
255                                                   sub attributes {
256            1                    1             3      my ( $self ) = @_;
257            1                                 11      return $self->{type_for};
258                                                   }
259                                                   
260                                                   # Returns the type of the attribute (as decided by the aggregation process,
261                                                   # which inspects the values).
262                                                   sub type_for {
263            2                    2            17      my ( $self, $attrib ) = @_;
264            2                                 17      return $self->{type_for}->{$attrib};
265                                                   }
266                                                   
267                                                   # Make subroutines that do things with events.
268                                                   #
269                                                   # $attrib: the name of the attrib (Query_time, Rows_read, etc)
270                                                   # $event:  a sample event
271                                                   # %args:
272                                                   #     min => keep min for this attrib (default except strings)
273                                                   #     max => keep max (default except strings)
274                                                   #     sum => keep sum (default for numerics)
275                                                   #     cnt => keep count (default except strings)
276                                                   #     unq => keep all unique values per-class (default for strings and bools)
277                                                   #     all => keep a bucketed list of values seen per class (default for numerics)
278                                                   #     glo => keep stats globally as well as per-class (default)
279                                                   #     trf => An expression to transform the value before working with it
280                                                   #     wor => Whether to keep worst-samples for this attrib (default no)
281                                                   #     alt => Arrayref of other name(s) for the attribute, like db => Schema.
282                                                   #
283                                                   # The bucketed list works this way: each range of values from MIN_BUCK in
284                                                   # increments of BUCK_SIZE (that is 5%) we consider a bucket.  We keep NUM_BUCK
285                                                   # buckets.  The upper end of the range is more than 1.5e15 so it should be big
286                                                   # enough for almost anything.  The buckets are accessed by a log base BUCK_SIZE,
287                                                   # so floor(log(N)/log(BUCK_SIZE)).  The smallest bucket's index is -284. We
288                                                   # shift all values up 284 so we have values from 0 to 999 that can be used as
289                                                   # array indexes.  A value that falls into a bucket simply increments the array
290                                                   # entry.  We do NOT use POSIX::floor() because it is too expensive.
291                                                   #
292                                                   # This eliminates the need to keep and sort all values to calculate median,
293                                                   # standard deviation, 95th percentile etc.  Thus the memory usage is bounded by
294                                                   # the number of distinct aggregated values, not the number of events.
295                                                   #
296                                                   # Return value:
297                                                   # a subroutine with this signature:
298                                                   #    my ( $event, $class, $global ) = @_;
299                                                   # where
300                                                   #  $event   is the event
301                                                   #  $class   is the container to store the aggregated values
302                                                   #  $global  is is the container to store the globally aggregated values
303                                                   sub make_handler {
304           75                   75           516      my ( $self, $attrib, $event, %args ) = @_;
305   ***     75     50                         332      die "I need an attrib" unless defined $attrib;
306           75                                214      my ($val) = grep { defined $_ } map { $event->{$_} } @{ $args{alt} };
              76                                288   
              76                                325   
              75                                298   
307           75                                226      my $is_array = 0;
308   ***     75     50                         326      if (ref $val eq 'ARRAY') {
309   ***      0                                  0         $is_array = 1;
310   ***      0                                  0         $val      = $val->[0];
311                                                      }
312   ***     75     50                         289      return unless defined $val; # Can't decide type if it's undef.
313                                                   
314                                                      # Ripped off from Regexp::Common::number and modified.
315           75                                477      my $float_re = qr{[+-]?(?:(?=\d|[.])\d+(?:[.])\d{0,})(?:E[+-]?\d+)?}i;
316           75    100                         928      my $type = $val  =~ m/^(?:\d+|$float_re)$/o ? 'num'
                    100                               
317                                                               : $val  =~ m/^(?:Yes|No)$/         ? 'bool'
318                                                               :                                    'string';
319           75                                165      MKDEBUG && _d('Type for', $attrib, 'is', $type,
320                                                         '(sample:', $val, '), is array:', $is_array);
321           75                                394      $self->{type_for}->{$attrib} = $type;
322                                                   
323           75    100                        1743      %args = ( # Set up defaults
                    100                               
                    100                               
                    100                               
324                                                         min => 1,
325                                                         max => 1,
326                                                         sum => $type =~ m/num|bool/    ? 1 : 0,
327                                                         cnt => 1,
328                                                         unq => $type =~ m/bool|string/ ? 1 : 0,
329                                                         all => $type eq 'num'          ? 1 : 0,
330                                                         glo => 1,
331                                                         trf => ($type eq 'bool') ? q{(($val || '') eq 'Yes') ? 1 : 0} : undef,
332                                                         wor => 0,
333                                                         alt => [],
334                                                         %args,
335                                                      );
336                                                   
337           75                                453      my @lines = ("# type: $type"); # Lines of code for the subroutine
338           75    100                         365      if ( $args{trf} ) {
339           14                                 76         push @lines, q{$val = } . $args{trf} . ';';
340                                                      }
341                                                   
342           75                                274      foreach my $place ( qw($class $global) ) {
343          150                                370         my @tmp;
344   ***    150     50                         627         if ( $args{min} ) {
345          150    100                         604            my $op   = $type eq 'num' ? '<' : 'lt';
346          150                                629            push @tmp, (
347                                                               'PLACE->{min} = $val if !defined PLACE->{min} || $val '
348                                                                  . $op . ' PLACE->{min};',
349                                                            );
350                                                         }
351   ***    150     50                         578         if ( $args{max} ) {
352          150    100                         553            my $op = ($type eq 'num') ? '>' : 'gt';
353          150                                561            push @tmp, (
354                                                               'PLACE->{max} = $val if !defined PLACE->{max} || $val '
355                                                                  . $op . ' PLACE->{max};',
356                                                            );
357                                                         }
358          150    100                         602         if ( $args{sum} ) {
359          112                                337            push @tmp, 'PLACE->{sum} += $val;';
360                                                         }
361   ***    150     50                         584         if ( $args{cnt} ) {
362          150                                457            push @tmp, '++PLACE->{cnt};';
363                                                         }
364          150    100                         554         if ( $args{all} ) {
365           84                                302            push @tmp, (
366                                                               'exists PLACE->{all} or PLACE->{all} = [ @buckets ];',
367                                                               '++PLACE->{all}->[ EventAggregator::bucket_idx($val) ];',
368                                                            );
369                                                         }
370          150                                476         push @lines, map { s/PLACE/$place/g; $_ } @tmp;
             730                               3580   
             730                               2610   
371                                                      }
372                                                   
373                                                      # We only save unique/worst values for the class, not globally.
374           75    100                         351      if ( $args{unq} ) {
375           33                                113         push @lines, '++$class->{unq}->{$val};';
376                                                      }
377           75    100                         332      if ( $args{wor} ) {
378   ***     10     50                          46         my $op = $type eq 'num' ? '>=' : 'ge';
379           10                                 67         push @lines, (
380                                                            'if ( $val ' . $op . ' ($class->{max} || 0) ) {',
381                                                            '   $samples->{$group_by} = $event;',
382                                                            '}',
383                                                         );
384                                                      }
385                                                   
386                                                      # Make sure the value is constrained to legal limits.  If it's out of bounds,
387                                                      # just use the last-seen value for it.
388           75                                202      my @limit;
389   ***     75    100     66                  785      if ( $args{all} && $type eq 'num' && $self->{attrib_limit} ) {
                           100                        
390            1                                  8         push @limit, (
391                                                            "if ( \$val > $self->{attrib_limit} ) {",
392                                                            '   $val = $class->{last} ||= 0;',
393                                                            '}',
394                                                            '$class->{last} = $val;',
395                                                         );
396                                                      }
397                                                   
398                                                      # Save the code for later, as part of an "unrolled" subroutine.
399            1                                  8      my @unrolled = (
400                                                         "\$val = \$event->{'$attrib'};",
401                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
402           76                                363         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
403           75                                282            grep { $_ ne $attrib } @{$args{alt}}),
             886                               3251   
404                                                         'defined $val && do {',
405   ***     75     50                         389         ( map { s/^/   /gm; $_ } (@limit, @lines) ), # Indent for debugging
      ***    886     50                        3293   
406                                                         '};',
407                                                         ($is_array ? ('}') : ()),
408                                                      );
409           75                                757      $self->{unrolled_for}->{$attrib} = join("\n", @unrolled);
410                                                   
411                                                      # Build a subroutine with the code.
412            1                                  9      unshift @lines, (
413                                                         'sub {',
414                                                         'my ( $event, $class, $global, $samples, $group_by ) = @_;',
415                                                         'my ($val, $idx);', # NOTE: define all variables here
416                                                         "\$val = \$event->{'$attrib'};",
417           76                                597         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
418   ***     75     50                         341            grep { $_ ne $attrib } @{$args{alt}}),
      ***     75     50                         294   
419                                                         'return unless defined $val;',
420                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
421                                                         @limit,
422                                                         ($is_array ? ('}') : ()),
423                                                      );
424           75                                240      push @lines, '}';
425           75                                436      my $code = join("\n", @lines);
426           75                                347      $self->{code_for}->{$attrib} = $code;
427                                                   
428           75                                170      MKDEBUG && _d('Metric handler for', $attrib, ':', @lines);
429           75                              14416      my $sub = eval join("\n", @lines);
430   ***     75     50                         339      die if $EVAL_ERROR;
431           75                                914      return $sub;
432                                                   }
433                                                   
434                                                   # Returns the bucket number for the given val. Buck numbers are zero-indexed,
435                                                   # so although there are 1,000 buckets (NUM_BUCK), 999 is the greatest idx.
436                                                   # *** Notice that this sub is not a class method, so either call it
437                                                   # from inside this module like bucket_idx() or outside this module
438                                                   # like EventAggregator::bucket_idx(). ***
439                                                   # TODO: could export this by default to avoid having to specific packge::.
440                                                   sub bucket_idx {
441         7874                 7874         35441      my ( $val ) = @_;
442         7874    100                       32895      return 0 if $val < MIN_BUCK;
443         6396                              25010      my $idx = int(BASE_OFFSET + log($val)/BASE_LOG);
444         6396    100                       36408      return $idx > (NUM_BUCK-1) ? (NUM_BUCK-1) : $idx;
445                                                   }
446                                                   
447                                                   # Returns the value for the given bucket.
448                                                   # The value of each bucket is the first value that it covers. So the value
449                                                   # of bucket 1 is 0.000001000 because it covers [0.000001000, 0.000001050).
450                                                   #
451                                                   # *** Notice that this sub is not a class method, so either call it
452                                                   # from inside this module like bucket_idx() or outside this module
453                                                   # like EventAggregator::bucket_value(). ***
454                                                   # TODO: could export this by default to avoid having to specific packge::.
455                                                   sub bucket_value {
456         1007                 1007          3068      my ( $bucket ) = @_;
457         1007    100                        3604      return 0 if $bucket == 0;
458   ***   1005     50     33                 7405      die "Invalid bucket: $bucket" if $bucket < 0 || $bucket > (NUM_BUCK-1);
459                                                      # $bucket - 1 because buckets are shifted up by 1 to handle zero values.
460         1005                               4727      return (BUCK_SIZE**($bucket-1)) * MIN_BUCK;
461                                                   }
462                                                   
463                                                   # Map the 1,000 base 1.05 buckets to 8 base 10 buckets. Returns an array
464                                                   # of 1,000 buckets, the value of each represents its index in an 8 bucket
465                                                   # base 10 array. For example: base 10 bucket 0 represents vals (0, 0.000010),
466                                                   # and base 1.05 buckets 0..47 represent vals (0, 0.000010401). So the first
467                                                   # 48 elements of the returned array will have 0 as their values. 
468                                                   # TODO: right now it's hardcoded to buckets of 10, in the future maybe not.
469                                                   {
470                                                      my @buck_tens;
471                                                      sub buckets_of {
472   ***      1     50             1             6         return @buck_tens if @buck_tens;
473                                                   
474                                                         # To make a more precise map, we first set the starting values for
475                                                         # each of the 8 base 10 buckets. 
476            1                                  3         my $start_bucket  = 0;
477            1                                  4         my @base10_starts = (0);
478            1                                  4         map { push @base10_starts, (10**$_)*MIN_BUCK } (1..7);
               7                                 29   
479                                                   
480                                                         # Then find the base 1.05 buckets that correspond to each
481                                                         # base 10 bucket. The last value in each bucket's range belongs
482                                                         # to the next bucket, so $next_bucket-1 represents the real last
483                                                         # base 1.05 bucket in which the base 10 bucket's range falls.
484            1                                  6         for my $base10_bucket ( 0..($#base10_starts-1) ) {
485            7                                 42            my $next_bucket = bucket_idx( $base10_starts[$base10_bucket+1] );
486            7                                 16            MKDEBUG && _d('Base 10 bucket', $base10_bucket, 'maps to',
487                                                               'base 1.05 buckets', $start_bucket, '..', $next_bucket-1);
488            7                                 27            for my $base1_05_bucket ($start_bucket..($next_bucket-1)) {
489          331                               1010               $buck_tens[$base1_05_bucket] = $base10_bucket;
490                                                            }
491            7                                 23            $start_bucket = $next_bucket;
492                                                         }
493                                                   
494                                                         # Map all remaining base 1.05 buckets to base 10 bucket 7 which
495                                                         # is for vals > 10.
496            1                                 31         map { $buck_tens[$_] = 7 } ($start_bucket..(NUM_BUCK-1));
             669                               2131   
497                                                   
498            1                                123         return @buck_tens;
499                                                      }
500                                                   }
501                                                   
502                                                   # Given an arrayref of vals, returns a hashref with the following
503                                                   # statistical metrics:
504                                                   #
505                                                   #    pct_95    => top bucket value in the 95th percentile
506                                                   #    cutoff    => How many values fall into the 95th percentile
507                                                   #    stddev    => of all values
508                                                   #    median    => of all values
509                                                   #
510                                                   # The vals arrayref is the buckets as per the above (see the comments at the top
511                                                   # of this file).  $args should contain cnt, min and max properties.
512                                                   sub calculate_statistical_metrics {
513           17                   17         12889      my ( $self, $vals, $args ) = @_;
514           17                                101      my $statistical_metrics = {
515                                                         pct_95    => 0,
516                                                         stddev    => 0,
517                                                         median    => 0,
518                                                         cutoff    => undef,
519                                                      };
520                                                   
521                                                      # These cases might happen when there is nothing to get from the event, for
522                                                      # example, processlist sniffing doesn't gather Rows_examined, so $args won't
523                                                      # have {cnt} or other properties.
524           17    100    100                  228      return $statistical_metrics
                           100                        
525                                                         unless defined $vals && @$vals && $args->{cnt};
526                                                   
527                                                      # Return accurate metrics for some cases.
528           13                                 45      my $n_vals = $args->{cnt};
529           13    100    100                  120      if ( $n_vals == 1 || $args->{max} == $args->{min} ) {
                    100                               
530   ***      7            50                   32         my $v      = $args->{max} || 0;
531   ***      7     50                          49         my $bucket = int(6 + ( log($v > 0 ? $v : MIN_BUCK) / log(10)));
532   ***      7     50                          32         $bucket    = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
533                                                         return {
534            7                                 51            pct_95 => $v,
535                                                            stddev => 0,
536                                                            median => $v,
537                                                            cutoff => $n_vals,
538                                                         };
539                                                      }
540                                                      elsif ( $n_vals == 2 ) {
541            1                                  6         foreach my $v ( $args->{min}, $args->{max} ) {
542   ***      2     50     33                   25            my $bucket = int(6 + ( log($v && $v > 0 ? $v : MIN_BUCK) / log(10)));
543   ***      2     50                          13            $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
544                                                         }
545   ***      1            50                    6         my $v      = $args->{max} || 0;
546   ***      1            50                    7         my $mean = (($args->{min} || 0) + $v) / 2;
547                                                         return {
548            1                                 13            pct_95 => $v,
549                                                            stddev => sqrt((($v - $mean) ** 2) *2),
550                                                            median => $mean,
551                                                            cutoff => $n_vals,
552                                                         };
553                                                      }
554                                                   
555                                                      # Determine cutoff point for 95% if there are at least 10 vals.  Cutoff
556                                                      # serves also for the number of vals left in the 95%.  E.g. with 50 vals the
557                                                      # cutoff is 47 which means there are 47 vals: 0..46.  $cutoff is NOT an array
558                                                      # index.
559            5    100                          36      my $cutoff = $n_vals >= 10 ? int ( $n_vals * 0.95 ) : $n_vals;
560            5                                 19      $statistical_metrics->{cutoff} = $cutoff;
561                                                   
562                                                      # Calculate the standard deviation and median of all values.
563            5                                 15      my $total_left = $n_vals;
564            5                                 16      my $top_vals   = $n_vals - $cutoff; # vals > 95th
565            5                                 15      my $sum_excl   = 0;
566            5                                 11      my $sum        = 0;
567            5                                 13      my $sumsq      = 0;
568            5                                 23      my $mid        = int($n_vals / 2);
569            5                                 14      my $median     = 0;
570            5                                 12      my $prev       = NUM_BUCK-1; # Used for getting median when $cutoff is odd
571            5                                 14      my $bucket_95  = 0; # top bucket in 95th
572                                                   
573            5                                 12      MKDEBUG && _d('total vals:', $total_left, 'top vals:', $top_vals, 'mid:', $mid);
574                                                   
575                                                      BUCKET:
576            5                                 37      for my $bucket ( reverse 0..(NUM_BUCK-1) ) {
577         5000                              15660         my $val = $vals->[$bucket];
578         5000    100                       23770         next BUCKET unless $val; 
579                                                   
580           19                                 51         $total_left -= $val;
581           19                                 52         $sum_excl   += $val;
582           19    100    100                  128         $bucket_95   = $bucket if !$bucket_95 && $sum_excl > $top_vals;
583                                                   
584           19    100    100                  123         if ( !$median && $total_left <= $mid ) {
585   ***      5     50     66                   51            $median = (($cutoff % 2) || ($val > 1)) ? $buck_vals[$bucket]
586                                                                    : ($buck_vals[$bucket] + $buck_vals[$prev]) / 2;
587                                                         }
588                                                   
589           19                                 74         $sum    += $val * $buck_vals[$bucket];
590           19                                 73         $sumsq  += $val * ($buck_vals[$bucket]**2);
591           19                                 61         $prev   =  $bucket;
592                                                      }
593                                                   
594            5                                 30      my $var      = $sumsq/$n_vals - ( ($sum/$n_vals) ** 2 );
595            5    100                          36      my $stddev   = $var > 0 ? sqrt($var) : 0;
596   ***      5            50                   49      my $maxstdev = (($args->{max} || 0) - ($args->{min} || 0)) / 2;
                           100                        
597   ***      5     50                          20      $stddev      = $stddev > $maxstdev ? $maxstdev : $stddev;
598                                                   
599            5                                 12      MKDEBUG && _d('sum:', $sum, 'sumsq:', $sumsq, 'stddev:', $stddev,
600                                                         'median:', $median, 'prev bucket:', $prev,
601                                                         'total left:', $total_left, 'sum excl', $sum_excl,
602                                                         'bucket 95:', $bucket_95, $buck_vals[$bucket_95]);
603                                                   
604            5                                 21      $statistical_metrics->{stddev} = $stddev;
605            5                                 20      $statistical_metrics->{pct_95} = $buck_vals[$bucket_95];
606            5                                 16      $statistical_metrics->{median} = $median;
607                                                   
608            5                                 33      return $statistical_metrics;
609                                                   }
610                                                   
611                                                   # Return a hashref of the metrics for some attribute, pre-digested.
612                                                   # %args is:
613                                                   #  attrib => the attribute to report on
614                                                   #  where  => the value of the fingerprint for the attrib
615                                                   sub metrics {
616            2                    2            14      my ( $self, %args ) = @_;
617            2                                 10      foreach my $arg ( qw(attrib where) ) {
618   ***      4     50                          20         die "I need a $arg argument" unless $args{$arg};
619                                                      }
620            2                                  9      my $stats = $self->results;
621            2                                 13      my $store = $stats->{classes}->{$args{where}}->{$args{attrib}};
622                                                   
623            2                                  9      my $global_cnt = $stats->{globals}->{$args{attrib}}->{cnt};
624            2                                 12      my $metrics    = $self->calculate_statistical_metrics($store->{all}, $store);
625                                                   
626                                                      return {
627   ***      2    100     66                   66         cnt    => $store->{cnt},
      ***           100     66                        
628                                                         pct    => $global_cnt && $store->{cnt} ? $store->{cnt} / $global_cnt : 0,
629                                                         sum    => $store->{sum},
630                                                         min    => $store->{min},
631                                                         max    => $store->{max},
632                                                         avg    => $store->{sum} && $store->{cnt} ? $store->{sum} / $store->{cnt} : 0,
633                                                         median => $metrics->{median},
634                                                         pct_95 => $metrics->{pct_95},
635                                                         stddev => $metrics->{stddev},
636                                                      };
637                                                   }
638                                                   
639                                                   # Find the top N or top % event keys, in sorted order, optionally including
640                                                   # outliers (ol_...) that are notable for some reason.  %args looks like this:
641                                                   #
642                                                   #  attrib      order-by attribute (usually Query_time)
643                                                   #  orderby     order-by aggregate expression (should be numeric, usually sum)
644                                                   #  total       include events whose summed attribs are <= this number...
645                                                   #  count       ...or this many events, whichever is less...
646                                                   #  ol_attrib   ...or events where the 95th percentile of this attribute...
647                                                   #  ol_limit    ...is greater than this value, AND...
648                                                   #  ol_freq     ...the event occurred at least this many times.
649                                                   # The return value is a list of arrayrefs.  Each arrayref is the event key and
650                                                   # an explanation of why it was included (top|outlier).
651                                                   sub top_events {
652            3                    3            57      my ( $self, %args ) = @_;
653            3                                 14      my $classes = $self->{result_classes};
654           15                                 94      my @sorted = reverse sort { # Sorted list of $groupby values
655           16                                 77         $classes->{$a}->{$args{attrib}}->{$args{orderby}}
656                                                            <=> $classes->{$b}->{$args{attrib}}->{$args{orderby}}
657                                                         } grep {
658                                                            # Defensive programming
659            3                                 16            defined $classes->{$_}->{$args{attrib}}->{$args{orderby}}
660                                                         } keys %$classes;
661            3                                 21      my @chosen;
662            3                                 11      my ($total, $count) = (0, 0);
663            3                                 12      foreach my $groupby ( @sorted ) {
664                                                         # Events that fall into the top criterion for some reason
665           15    100    100                  239         if ( 
      ***           100     66                        
                           100                        
                           100                        
                           100                        
666                                                            (!$args{total} || $total < $args{total} )
667                                                            && ( !$args{count} || $count < $args{count} )
668                                                         ) {
669            6                                 24            push @chosen, [$groupby, 'top'];
670                                                         }
671                                                   
672                                                         # Events that are notable outliers
673                                                         elsif ( $args{ol_attrib} && (!$args{ol_freq}
674                                                            || $classes->{$groupby}->{$args{ol_attrib}}->{cnt} >= $args{ol_freq})
675                                                         ) {
676                                                            # Calculate the 95th percentile of this event's specified attribute.
677            5                                 10            MKDEBUG && _d('Calculating statistical_metrics');
678            5                                 36            my $stats = $self->calculate_statistical_metrics(
679                                                               $classes->{$groupby}->{$args{ol_attrib}}->{all},
680                                                               $classes->{$groupby}->{$args{ol_attrib}}
681                                                            );
682            5    100                          27            if ( $stats->{pct_95} >= $args{ol_limit} ) {
683            3                                 15               push @chosen, [$groupby, 'outlier'];
684                                                            }
685                                                         }
686                                                   
687           15                                 74         $total += $classes->{$groupby}->{$args{attrib}}->{$args{orderby}};
688           15                                 44         $count++;
689                                                      }
690            3                                 26      return @chosen;
691                                                   }
692                                                   
693                                                   # Adds all new attributes in $event to $self->{attributes}.
694                                                   sub add_new_attributes {
695          238                  238           920      my ( $self, $event ) = @_;
696   ***    238     50                         990      return unless $event;
697                                                   
698           56                                151      map {
699         3761    100    100                34337         my $attrib = $_;
700           56                                240         $self->{attributes}->{$attrib}  = [$attrib];
701           56                                197         $self->{alt_attribs}->{$attrib} = make_alt_attrib($attrib);
702           56                                147         push @{$self->{all_attribs}}, $attrib;
              56                                215   
703           56                                175         MKDEBUG && _d('Added new attribute:', $attrib);
704                                                      }
705                                                      grep {
706          238                               1790         $_ ne $self->{groupby}
707                                                         && !exists $self->{attributes}->{$_}
708                                                         && !exists $self->{ignore_attribs}->{$_}
709                                                      }
710                                                      keys %$event;
711                                                   
712          238                               1178      return;
713                                                   }
714                                                   
715                                                   # Returns a list of all the attributes that were either given
716                                                   # explicitly to new() or that were auto-detected.
717                                                   sub get_attributes {
718            1                    1           132      my ( $self ) = @_;
719            1                                  3      return @{$self->{all_attribs}};
               1                                 17   
720                                                   }
721                                                   
722                                                   sub events_processed {
723            1                    1             4      my ( $self ) = @_;
724            1                                  7      return $self->{n_events};
725                                                   }
726                                                   
727                                                   sub make_alt_attrib {
728           75                   75           306      my ( @attribs ) = @_;
729                                                   
730           75                                226      my $attrib = shift @attribs;  # Primary attribute.
731           75    100            14           793      return sub {} unless @attribs;  # No alternates.
              14                                 42   
732                                                   
733            1                                  4      my @lines;
734            1                                  3      push @lines, 'sub { my ( $event ) = @_; my $alt_attrib;';
735            1                                  7      push @lines, map  {
736            1                                  4            "\$alt_attrib = '$_' if !defined \$alt_attrib "
737                                                            . "&& exists \$event->{'$_'};"
738                                                         } @attribs;
739            1                                  3      push @lines, 'return $alt_attrib; }';
740            1                                  3      MKDEBUG && _d('alt attrib sub for', $attrib, ':', @lines);
741            1                                 81      my $sub = eval join("\n", @lines);
742   ***      1     50                           5      die if $EVAL_ERROR;
743            1                                 27      return $sub;
744                                                   }
745                                                   
746                                                   sub _d {
747   ***      0                    0                    my ($package, undef, $line) = caller 0;
748   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
749   ***      0                                              map { defined $_ ? $_ : 'undef' }
750                                                           @_;
751   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
752                                                   }
753                                                   
754                                                   1;
755                                                   
756                                                   # ###########################################################################
757                                                   # End EventAggregator package
758                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
69    ***     50      0     30   unless $args{$arg}
88           100      5     10   scalar keys %$attributes == 0 ? :
131          100      2   1698   unless defined $group_by
137          100    436   1262   if $$self{'unrolled_loops'}
142          100   1260      2   if ($$self{'n_events'} <= $$self{'unroll_limit'}) { }
144          100    238   1022   if $$self{'detect_attribs'}
154          100     15   4562   if (not exists $$event{$attrib})
158          100     14      1   unless $alt_attrib
163          100      4   4559   ref $group_by ? :
168          100     75   4490   if (not $handler)
177   ***     50      0   4565   unless $handler
209   ***     50      0      2   ref $group_by ? :
226   ***     50      0      2   if (ref $group_by)
237   ***     50      0      2   if $EVAL_ERROR
305   ***     50      0     75   unless defined $attrib
308   ***     50      0     75   if (ref $val eq 'ARRAY')
312   ***     50      0     75   unless defined $val
316          100     14     19   $val =~ /^(?:Yes|No)$/ ? :
             100     42     33   $val =~ /^(?:\d+|$float_re)$/o ? :
323          100     56     19   $type =~ /num|bool/ ? :
             100     33     42   $type =~ /bool|string/ ? :
             100     42     33   $type eq 'num' ? :
             100     14     61   $type eq 'bool' ? :
338          100     14     61   if ($args{'trf'})
344   ***     50    150      0   if ($args{'min'})
345          100     84     66   $type eq 'num' ? :
351   ***     50    150      0   if ($args{'max'})
352          100     84     66   $type eq 'num' ? :
358          100    112     38   if ($args{'sum'})
361   ***     50    150      0   if ($args{'cnt'})
364          100     84     66   if ($args{'all'})
374          100     33     42   if ($args{'unq'})
377          100     10     65   if ($args{'wor'})
378   ***     50     10      0   $type eq 'num' ? :
389          100      1     74   if ($args{'all'} and $type eq 'num' and $$self{'attrib_limit'})
405   ***     50      0     75   $is_array ? :
      ***     50      0     75   $is_array ? :
418   ***     50      0     75   $is_array ? :
      ***     50      0     75   $is_array ? :
430   ***     50      0     75   if $EVAL_ERROR
442          100   1478   6396   if $val < 1e-06
444          100      1   6395   $idx > 999 ? :
457          100      2   1005   if $bucket == 0
458   ***     50      0   1005   if $bucket < 0 or $bucket > 999
472   ***     50      0      1   if @buck_tens
524          100      4     13   unless defined $vals and @$vals and $$args{'cnt'}
529          100      7      6   if ($n_vals == 1 or $$args{'max'} == $$args{'min'}) { }
             100      1      5   elsif ($n_vals == 2) { }
531   ***     50      7      0   $v > 0 ? :
532   ***     50      0      7   $bucket < 0 ? :
      ***     50      0      7   $bucket > 7 ? :
542   ***     50      2      0   $v && $v > 0 ? :
543   ***     50      0      2   $bucket < 0 ? :
      ***     50      0      2   $bucket > 7 ? :
559          100      4      1   $n_vals >= 10 ? :
578          100   4981     19   unless $val
582          100      5     14   if not $bucket_95 and $sum_excl > $top_vals
584          100      5     14   if (not $median and $total_left <= $mid)
585   ***     50      5      0   $cutoff % 2 || $val > 1 ? :
595          100      3      2   $var > 0 ? :
597   ***     50      0      5   $stddev > $maxstdev ? :
618   ***     50      0      4   unless $args{$arg}
627          100      1      1   $global_cnt && $$store{'cnt'} ? :
             100      1      1   $$store{'sum'} && $$store{'cnt'} ? :
665          100      6      9   if (!$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}) { }
             100      5      4   elsif ($args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}) { }
682          100      3      2   if ($$stats{'pct_95'} >= $args{'ol_limit'})
696   ***     50      0    238   unless $event
699          100     60   3701   if $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}
731          100     74      1   unless @attribs
742   ***     50      0      1   if $EVAL_ERROR
748   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
389   ***     66     33      0     42   $args{'all'} and $type eq 'num'
             100     33     41      1   $args{'all'} and $type eq 'num' and $$self{'attrib_limit'}
524          100      2      1     14   defined $vals and @$vals
             100      3      1     13   defined $vals and @$vals and $$args{'cnt'}
542   ***     33      0      0      2   $v && $v > 0
582          100     11      3      5   not $bucket_95 and $sum_excl > $top_vals
584          100      5      9      5   not $median and $total_left <= $mid
627   ***     66      1      0      1   $global_cnt && $$store{'cnt'}
      ***     66      1      0      1   $$store{'sum'} && $$store{'cnt'}
665          100      6      3      6   !$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}
             100      3      1      5   $args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}
699          100    238   3463     60   $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
71           100     10      5   $args{'attributes'} || {}
88           100      1     14   $args{'unroll_limit'} || 1000
164          100   4433    132   $$self{'result_classes'}{$val}{$attrib} ||= {}
165          100   4490     75   $$self{'result_globals'}{$attrib} ||= {}
178          100   4538     27   $$samples{$val} ||= $event
530   ***     50      7      0   $$args{'max'} || 0
545   ***     50      1      0   $$args{'max'} || 0
546   ***     50      1      0   $$args{'min'} || 0
596   ***     50      5      0   $$args{'max'} || 0
             100      4      1   $$args{'min'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
458   ***     33      0      0   1005   $bucket < 0 or $bucket > 999
529          100      3      4      6   $n_vals == 1 or $$args{'max'} == $$args{'min'}
585   ***     66      2      3      0   $cutoff % 2 || $val > 1
665          100      5      4      6   !$args{'total'} || $total < $args{'total'}
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
__ANON__                         14 /home/daniel/dev/maatkit/common/EventAggregator.pm:731
_make_unrolled_loops              2 /home/daniel/dev/maatkit/common/EventAggregator.pm:195
add_new_attributes              238 /home/daniel/dev/maatkit/common/EventAggregator.pm:695
aggregate                      1700 /home/daniel/dev/maatkit/common/EventAggregator.pm:128
attributes                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:256
bucket_idx                     7874 /home/daniel/dev/maatkit/common/EventAggregator.pm:441
bucket_value                   1007 /home/daniel/dev/maatkit/common/EventAggregator.pm:456
buckets_of                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:472
calculate_statistical_metrics    17 /home/daniel/dev/maatkit/common/EventAggregator.pm:513
events_processed                  1 /home/daniel/dev/maatkit/common/EventAggregator.pm:723
get_attributes                    1 /home/daniel/dev/maatkit/common/EventAggregator.pm:718
make_alt_attrib                  75 /home/daniel/dev/maatkit/common/EventAggregator.pm:728
make_handler                     75 /home/daniel/dev/maatkit/common/EventAggregator.pm:304
metrics                           2 /home/daniel/dev/maatkit/common/EventAggregator.pm:616
new                              15 /home/daniel/dev/maatkit/common/EventAggregator.pm:67 
reset_aggregated_data             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:109
results                          19 /home/daniel/dev/maatkit/common/EventAggregator.pm:245
top_events                        3 /home/daniel/dev/maatkit/common/EventAggregator.pm:652
type_for                          2 /home/daniel/dev/maatkit/common/EventAggregator.pm:263

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                              
----------------------------- ----- ------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/EventAggregator.pm:747


