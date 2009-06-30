---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/EventAggregator.pm   96.6   75.7   80.0   96.4    n/a  100.0   88.7
Total                          96.6   75.7   80.0   96.4    n/a  100.0   88.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          EventAggregator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Jun 30 16:30:17 2009
Finish:       Tue Jun 30 16:30:23 2009

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
18                                                    # EventAggregator package $Revision: 4023 $
19                                                    # ###########################################################################
20                                                    package EventAggregator;
21                                                    
22             1                    1             8   use strict;
               1                                  3   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  4   
25                                                    
26                                                    # ###########################################################################
27                                                    # Set up some constants for bucketing values.  It is impossible to keep all
28                                                    # values seen in memory, but putting them into logarithmically scaled buckets
29                                                    # and just incrementing the bucket each time works, although it is imprecise.
30                                                    # See http://code.google.com/p/maatkit/wiki/EventAggregatorInternals.
31                                                    # ###########################################################################
32             1                    1             5   use constant MKDEBUG      => $ENV{MKDEBUG};
               1                                  3   
               1                                  6   
33             1                    1             5   use constant BUCK_SIZE    => 1.05;
               1                                  3   
               1                                  4   
34             1                    1             6   use constant BASE_LOG     => log(BUCK_SIZE);
               1                                  2   
               1                                  4   
35             1                    1             5   use constant BASE_OFFSET  => abs(1 - log(0.000001) / BASE_LOG); # 284.1617969
               1                                  3   
               1                                  4   
36             1                    1             6   use constant NUM_BUCK     => 1000;
               1                                  2   
               1                                  4   
37             1                    1            10   use constant MIN_BUCK     => .000001;
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
63                                                    #              anyway.  Defaults to 50.
64                                                    # attrib_limit Sanity limit for attribute values.  If the value exceeds the
65                                                    #              limit, use the last-seen for this class; if none, then 0.
66                                                    sub new {
67            13                   13           343      my ( $class, %args ) = @_;
68            13                                 63      foreach my $arg ( qw(groupby worst) ) {
69    ***     26     50                         133         die "I need a $arg argument" unless $args{$arg};
70                                                       }
71            13           100                   86      my $attributes = $args{attributes} || {};
72             3                                 39      return bless {
73                                                          groupby        => $args{groupby},
74                                                          detect_attribs => scalar keys %$attributes == 0 ? 1 : 0,
75                                                          all_attribs    => [ keys %$attributes ],
76                                                          ignore_attribs => {
77             3                                 12            map  { $_ => $args{attributes}->{$_} }
78            13                                132            grep { $_ ne $args{groupby} }
79            19                                113            @{$args{ignore_attributes}}
80                                                          },
81                                                          attributes     => {
82            20                                 83            map  { $_ => $args{attributes}->{$_} }
83            19                                101            grep { $_ ne $args{groupby} }
84                                                             keys %$attributes
85                                                          },
86                                                          alt_attribs    => {
87            19                                 51            map  { $_ => make_alt_attrib(@{$args{attributes}->{$_}}) }
              20                                 84   
88    ***     13    100     50                  127            grep { $_ ne $args{groupby} }
89                                                             keys %$attributes
90                                                          },
91                                                          worst        => $args{worst},
92                                                          unroll_limit => $args{unroll_limit} || 50,
93                                                          attrib_limit => $args{attrib_limit},
94                                                          result_classes => {},
95                                                          result_globals => {},
96                                                          result_samples => {},
97                                                          n_events       => 0,
98                                                       }, $class;
99                                                    }
100                                                   
101                                                   # Delete all collected data, but don't delete things like the generated
102                                                   # subroutines.  Resetting aggregated data is an interesting little exercise.
103                                                   # The generated functions that do aggregation have private namespaces with
104                                                   # references to some of the data.  Thus, they will not necessarily do as
105                                                   # expected if the stored data is simply wiped out.  Instead, it needs to be
106                                                   # zeroed out without replacing the actual objects.
107                                                   sub reset_aggregated_data {
108            1                    1            14      my ( $self ) = @_;
109            1                                  3      foreach my $class ( values %{$self->{result_classes}} ) {
               1                                  8   
110            1                                  5         foreach my $attrib ( values %$class ) {
111            2                                 10            delete @{$attrib}{keys %$attrib};
               2                                 50   
112                                                         }
113                                                      }
114            1                                  3      foreach my $class ( values %{$self->{result_globals}} ) {
               1                                  7   
115            2                                  9         delete @{$class}{keys %$class};
               2                                 37   
116                                                      }
117            1                                  3      delete @{$self->{result_samples}}{keys %{$self->{result_samples}}};
               1                                  4   
               1                                  5   
118            1                                  4      $self->{n_events} = 0;
119                                                   }
120                                                   
121                                                   # Aggregate an event hashref's properties.  Code is built on the fly to do this,
122                                                   # based on the values being passed in.  After code is built for every attribute
123                                                   # (or 50 events are seen and we decide to give up) the little bits of code get
124                                                   # unrolled into a whole subroutine to handle events.  For that reason, you can't
125                                                   # re-use an instance.
126                                                   sub aggregate {
127         1338                 1338         19004      my ( $self, $event ) = @_;
128                                                   
129         1338                               5046      my $group_by = $event->{$self->{groupby}};
130         1338    100                        4742      return unless defined $group_by;
131                                                   
132                                                      # Auto-detect all attributes.
133         1336    100                        5308      $self->add_new_attributes($event) if $self->{detect_attribs};
134                                                   
135         1336                               3795      $self->{n_events}++;
136                                                   
137                                                      # There might be a specially built sub that handles the work.
138         1336    100                        5245      if ( exists $self->{unrolled_loops} ) {
139         1255                               5374         return $self->{unrolled_loops}->($self, $event, $group_by);
140                                                      }
141                                                   
142           81                                225      my @attrs = keys %{$self->{attributes}};
              81                                424   
143                                                      ATTRIB:
144           81                                302      foreach my $attrib ( @attrs ) {
145                                                   
146                                                         # Attrib auto-detection can add a lot of attributes which some events
147                                                         # may or may not have.  Aggregating a nonexistent attrib is wasteful,
148                                                         # so we check that the attrib or one of its alternates exists.  If
149                                                         # one does, then we leave attrib alone because the handler sub will
150                                                         # also check alternates.
151          152    100                         657         if ( !exists $event->{$attrib} ) {
152            9                                 20            MKDEBUG && _d("attrib doesn't exist in event:", $attrib);
153            9                                 48            my $alt_attrib = $self->{alt_attribs}->{$attrib}->($event);
154            9                                 19            MKDEBUG && _d('alt attrib:', $alt_attrib);
155            9    100                          43            next ATTRIB unless $alt_attrib;
156                                                         }
157                                                   
158                                                         # The value of the attribute ( $group_by ) may be an arrayref.
159                                                         GROUPBY:
160          144    100                         607         foreach my $val ( ref $group_by ? @$group_by : ($group_by) ) {
161          146           100                 1172            my $class_attrib  = $self->{result_classes}->{$val}->{$attrib} ||= {};
162          146           100                  834            my $global_attrib = $self->{result_globals}->{$attrib} ||= {};
163          146                                454            my $samples       = $self->{result_samples};
164          146                                556            my $handler = $self->{handlers}->{ $attrib };
165          146    100                         541            if ( !$handler ) {
166           39                                311               $handler = $self->make_handler(
167                                                                  $attrib,
168                                                                  $event,
169                                                                  wor => $self->{worst} eq $attrib,
170                                                                  alt => $self->{attributes}->{$attrib},
171                                                               );
172           39                                187               $self->{handlers}->{$attrib} = $handler;
173                                                            }
174   ***    146     50                         509            next GROUPBY unless $handler;
175          146           100                  615            $samples->{$val} ||= $event; # Initialize to the first event.
176          146                                654            $handler->($event, $class_attrib, $global_attrib, $samples, $group_by);
177                                                         }
178                                                      }
179                                                   
180                                                      # Figure out whether we are ready to generate a faster, unrolled handler.
181                                                      # This happens either...
182   ***     81    100     66                  930      if ( $self->{n_queries}++ > 50  # ...after 50 events, or
      ***     80            66                  592   
183                                                           || ( # all attribs have handlers and
184                                                                !grep { ref $self->{handlers}->{$_} ne 'CODE' } @attrs
185                                                                # we're not auto-detecting attribs.
186                                                                && !$self->{detect_attribs}
187                                                              ) )
188                                                      {
189                                                         # All attributes have handlers, so let's combine them into one faster sub.
190                                                         # Start by getting direct handles to the location of each data store and
191                                                         # thing that would otherwise be looked up via hash keys.
192            1                                  4         my @attrs   = grep { $self->{handlers}->{$_} } @attrs;
               1                                  6   
193            1                                  5         my $globs   = $self->{result_globals}; # Global stats for each
194            1                                  3         my $samples = $self->{result_samples};
195                                                   
196                                                         # Now the tricky part -- must make sure only the desired variables from
197                                                         # the outer scope are re-used, and any variables that should have their
198                                                         # own scope are declared within the subroutine.
199   ***      1     50                           9         my @lines = (
200                                                            'my ( $self, $event, $group_by ) = @_;',
201                                                            'my ($val, $class, $global, $idx);',
202                                                            (ref $group_by ? ('foreach my $group_by ( @$group_by ) {') : ()),
203                                                            # Create and get each attribute's storage
204                                                            'my $temp = $self->{result_classes}->{ $group_by }
205                                                               ||= { map { $_ => { } } @attrs };',
206                                                            '$samples->{$group_by} ||= $event;', # Always start with the first.
207                                                         );
208            1                                 11         foreach my $i ( 0 .. $#attrs ) {
209                                                            # Access through array indexes, it's faster than hash lookups
210            1                                 14            push @lines, (
211                                                               '$class  = $temp->{"'  . $attrs[$i] . '"};',
212                                                               '$global = $globs->{"' . $attrs[$i] . '"};',
213                                                               $self->{unrolled_for}->{$attrs[$i]},
214                                                            );
215                                                         }
216   ***      1     50                           7         if ( ref $group_by ) {
217   ***      0                                  0            push @lines, '}'; # Close the loop opened above
218                                                         }
219            1                                  3         @lines = map { s/^/   /gm; $_ } @lines; # Indent for debugging
               7                                 42   
               7                                 27   
220            1                                  5         unshift @lines, 'sub {';
221            1                                  4         push @lines, '}';
222                                                   
223                                                         # Make the subroutine
224            1                                  8         my $code = join("\n", @lines);
225            1                                  2         MKDEBUG && _d('Unrolled subroutine:', @lines);
226            1                                328         my $sub = eval $code;
227   ***      1     50                           8         die if $EVAL_ERROR;
228            1                                  6         $self->{unrolled_loops} = $sub;
229                                                      }
230                                                   
231           81                                437      return;
232                                                   }
233                                                   
234                                                   # Return the aggregated results.
235                                                   sub results {
236           19                   19          6227      my ( $self ) = @_;
237                                                      return {
238           19                                318         classes => $self->{result_classes},
239                                                         globals => $self->{result_globals},
240                                                         samples => $self->{result_samples},
241                                                      };
242                                                   }
243                                                   
244                                                   # Return the attributes that this object is tracking, and their data types, as
245                                                   # a hashref of name => type.
246                                                   sub attributes {
247            1                    1             4      my ( $self ) = @_;
248            1                                 10      return $self->{type_for};
249                                                   }
250                                                   
251                                                   # Returns the type of the attribute (as decided by the aggregation process,
252                                                   # which inspects the values).
253                                                   sub type_for {
254            2                    2            16      my ( $self, $attrib ) = @_;
255            2                                 16      return $self->{type_for}->{$attrib};
256                                                   }
257                                                   
258                                                   # Make subroutines that do things with events.
259                                                   #
260                                                   # $attrib: the name of the attrib (Query_time, Rows_read, etc)
261                                                   # $event:  a sample event
262                                                   # %args:
263                                                   #     min => keep min for this attrib (default except strings)
264                                                   #     max => keep max (default except strings)
265                                                   #     sum => keep sum (default for numerics)
266                                                   #     cnt => keep count (default except strings)
267                                                   #     unq => keep all unique values per-class (default for strings and bools)
268                                                   #     all => keep a bucketed list of values seen per class (default for numerics)
269                                                   #     glo => keep stats globally as well as per-class (default)
270                                                   #     trf => An expression to transform the value before working with it
271                                                   #     wor => Whether to keep worst-samples for this attrib (default no)
272                                                   #     alt => Arrayref of other name(s) for the attribute, like db => Schema.
273                                                   #
274                                                   # The bucketed list works this way: each range of values from MIN_BUCK in
275                                                   # increments of BUCK_SIZE (that is 5%) we consider a bucket.  We keep NUM_BUCK
276                                                   # buckets.  The upper end of the range is more than 1.5e15 so it should be big
277                                                   # enough for almost anything.  The buckets are accessed by a log base BUCK_SIZE,
278                                                   # so floor(log(N)/log(BUCK_SIZE)).  The smallest bucket's index is -284. We
279                                                   # shift all values up 284 so we have values from 0 to 999 that can be used as
280                                                   # array indexes.  A value that falls into a bucket simply increments the array
281                                                   # entry.  We do NOT use POSIX::floor() because it is too expensive.
282                                                   #
283                                                   # This eliminates the need to keep and sort all values to calculate median,
284                                                   # standard deviation, 95th percentile etc.  Thus the memory usage is bounded by
285                                                   # the number of distinct aggregated values, not the number of events.
286                                                   #
287                                                   # Return value:
288                                                   # a subroutine with this signature:
289                                                   #    my ( $event, $class, $global ) = @_;
290                                                   # where
291                                                   #  $event   is the event
292                                                   #  $class   is the container to store the aggregated values
293                                                   #  $global  is is the container to store the globally aggregated values
294                                                   sub make_handler {
295           39                   39           258      my ( $self, $attrib, $event, %args ) = @_;
296   ***     39     50                         183      die "I need an attrib" unless defined $attrib;
297           39                                118      my ($val) = grep { defined $_ } map { $event->{$_} } @{ $args{alt} };
              40                                156   
              40                                168   
              39                                156   
298           39                                113      my $is_array = 0;
299   ***     39     50                         156      if (ref $val eq 'ARRAY') {
300   ***      0                                  0         $is_array = 1;
301   ***      0                                  0         $val      = $val->[0];
302                                                      }
303   ***     39     50                         140      return unless defined $val; # Can't decide type if it's undef.
304                                                   
305                                                      # Ripped off from Regexp::Common::number and modified.
306           39                                246      my $float_re = qr{[+-]?(?:(?=\d|[.])\d+(?:[.])\d{0,})(?:E[+-]?\d+)?}i;
307   ***     39     50                         505      my $type = $val  =~ m/^(?:\d+|$float_re)$/o ? 'num'
                    100                               
308                                                               : $val  =~ m/^(?:Yes|No)$/         ? 'bool'
309                                                               :                                    'string';
310           39                                 85      MKDEBUG && _d('Type for', $attrib, 'is', $type,
311                                                         '(sample:', $val, '), is array:', $is_array);
312           39                                175      $self->{type_for}->{$attrib} = $type;
313                                                   
314           39    100                         858      %args = ( # Set up defaults
                    100                               
                    100                               
      ***            50                               
315                                                         min => 1,
316                                                         max => 1,
317                                                         sum => $type =~ m/num|bool/    ? 1 : 0,
318                                                         cnt => 1,
319                                                         unq => $type =~ m/bool|string/ ? 1 : 0,
320                                                         all => $type eq 'num'          ? 1 : 0,
321                                                         glo => 1,
322                                                         trf => ($type eq 'bool') ? q{(($val || '') eq 'Yes') ? 1 : 0} : undef,
323                                                         wor => 0,
324                                                         alt => [],
325                                                         %args,
326                                                      );
327                                                   
328           39                                245      my @lines = ("# type: $type"); # Lines of code for the subroutine
329   ***     39     50                         175      if ( $args{trf} ) {
330   ***      0                                  0         push @lines, q{$val = } . $args{trf} . ';';
331                                                      }
332                                                   
333           39                                146      foreach my $place ( qw($class $global) ) {
334           78                                190         my @tmp;
335   ***     78     50                         351         if ( $args{min} ) {
336           78    100                         308            my $op   = $type eq 'num' ? '<' : 'lt';
337           78                                334            push @tmp, (
338                                                               'PLACE->{min} = $val if !defined PLACE->{min} || $val '
339                                                                  . $op . ' PLACE->{min};',
340                                                            );
341                                                         }
342   ***     78     50                         297         if ( $args{max} ) {
343           78    100                         284            my $op = ($type eq 'num') ? '>' : 'gt';
344           78                                293            push @tmp, (
345                                                               'PLACE->{max} = $val if !defined PLACE->{max} || $val '
346                                                                  . $op . ' PLACE->{max};',
347                                                            );
348                                                         }
349           78    100                         310         if ( $args{sum} ) {
350           44                                134            push @tmp, 'PLACE->{sum} += $val;';
351                                                         }
352   ***     78     50                         285         if ( $args{cnt} ) {
353           78                                225            push @tmp, '++PLACE->{cnt};';
354                                                         }
355           78    100                         290         if ( $args{all} ) {
356           44                                159            push @tmp, (
357                                                               'exists PLACE->{all} or PLACE->{all} = [ @buckets ];',
358                                                               '++PLACE->{all}->[ EventAggregator::bucket_idx($val) ];',
359                                                            );
360                                                         }
361           78                                270         push @lines, map { s/PLACE/$place/g; $_ } @tmp;
             366                               1829   
             366                               1360   
362                                                      }
363                                                   
364                                                      # We only save unique/worst values for the class, not globally.
365           39    100                         179      if ( $args{unq} ) {
366           17                                 70         push @lines, '++$class->{unq}->{$val};';
367                                                      }
368           39    100                         162      if ( $args{wor} ) {
369   ***      8     50                          35         my $op = $type eq 'num' ? '>=' : 'ge';
370            8                                 42         push @lines, (
371                                                            'if ( $val ' . $op . ' ($class->{max} || 0) ) {',
372                                                            '   $samples->{$group_by} = $event;',
373                                                            '}',
374                                                         );
375                                                      }
376                                                   
377                                                      # Make sure the value is constrained to legal limits.  If it's out of bounds,
378                                                      # just use the last-seen value for it.
379           39                                 95      my @limit;
380   ***     39    100     66                  443      if ( $args{all} && $type eq 'num' && $self->{attrib_limit} ) {
                           100                        
381            1                                  8         push @limit, (
382                                                            "if ( \$val > $self->{attrib_limit} ) {",
383                                                            '   $val = $class->{last} ||= 0;',
384                                                            '}',
385                                                            '$class->{last} = $val;',
386                                                         );
387                                                      }
388                                                   
389                                                      # Save the code for later, as part of an "unrolled" subroutine.
390            1                                  6      my @unrolled = (
391                                                         "\$val = \$event->{'$attrib'};",
392                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
393           40                                194         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
394           39                                148            grep { $_ ne $attrib } @{$args{alt}}),
             450                               1634   
395                                                         'defined $val && do {',
396   ***     39     50                         207         ( map { s/^/   /gm; $_ } (@limit, @lines) ), # Indent for debugging
      ***    450     50                        1707   
397                                                         '};',
398                                                         ($is_array ? ('}') : ()),
399                                                      );
400           39                                399      $self->{unrolled_for}->{$attrib} = join("\n", @unrolled);
401                                                   
402                                                      # Build a subroutine with the code.
403            1                                  9      unshift @lines, (
404                                                         'sub {',
405                                                         'my ( $event, $class, $global, $samples, $group_by ) = @_;',
406                                                         'my ($val, $idx);', # NOTE: define all variables here
407                                                         "\$val = \$event->{'$attrib'};",
408           40                                284         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
409   ***     39     50                         205            grep { $_ ne $attrib } @{$args{alt}}),
      ***     39     50                         152   
410                                                         'return unless defined $val;',
411                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
412                                                         @limit,
413                                                         ($is_array ? ('}') : ()),
414                                                      );
415           39                                129      push @lines, '}';
416           39                                230      my $code = join("\n", @lines);
417           39                                198      $self->{code_for}->{$attrib} = $code;
418                                                   
419           39                                102      MKDEBUG && _d('Metric handler for', $attrib, ':', @lines);
420           39                               7524      my $sub = eval join("\n", @lines);
421   ***     39     50                         169      die if $EVAL_ERROR;
422           39                                506      return $sub;
423                                                   }
424                                                   
425                                                   # Returns the bucket number for the given val. Buck numbers are zero-indexed,
426                                                   # so although there are 1,000 buckets (NUM_BUCK), 999 is the greatest idx.
427                                                   # *** Notice that this sub is not a class method, so either call it
428                                                   # from inside this module like bucket_idx() or outside this module
429                                                   # like EventAggregator::bucket_idx(). ***
430                                                   # TODO: could export this by default to avoid having to specific packge::.
431                                                   sub bucket_idx {
432         2794                 2794         17926      my ( $val ) = @_;
433         2794    100                       10675      return 0 if $val < MIN_BUCK;
434         2774                              10396      my $idx = int(BASE_OFFSET + log($val)/BASE_LOG);
435         2774    100                       16430      return $idx > (NUM_BUCK-1) ? (NUM_BUCK-1) : $idx;
436                                                   }
437                                                   
438                                                   # Returns the value for the given bucket.
439                                                   # The value of each bucket is the first value that it covers. So the value
440                                                   # of bucket 1 is 0.000001000 because it covers [0.000001000, 0.000001050).
441                                                   #
442                                                   # *** Notice that this sub is not a class method, so either call it
443                                                   # from inside this module like bucket_idx() or outside this module
444                                                   # like EventAggregator::bucket_value(). ***
445                                                   # TODO: could export this by default to avoid having to specific packge::.
446                                                   sub bucket_value {
447         1007                 1007          2998      my ( $bucket ) = @_;
448         1007    100                        3560      return 0 if $bucket == 0;
449   ***   1005     50     33                 7324      die "Invalid bucket: $bucket" if $bucket < 0 || $bucket > (NUM_BUCK-1);
450                                                      # $bucket - 1 because buckets are shifted up by 1 to handle zero values.
451         1005                               4557      return (BUCK_SIZE**($bucket-1)) * MIN_BUCK;
452                                                   }
453                                                   
454                                                   # Map the 1,000 base 1.05 buckets to 8 base 10 buckets. Returns an array
455                                                   # of 1,000 buckets, the value of each represents its index in an 8 bucket
456                                                   # base 10 array. For example: base 10 bucket 0 represents vals (0, 0.000010),
457                                                   # and base 1.05 buckets 0..47 represent vals (0, 0.000010401). So the first
458                                                   # 48 elements of the returned array will have 0 as their values. 
459                                                   # TODO: right now it's hardcoded to buckets of 10, in the future maybe not.
460                                                   {
461                                                      my @buck_tens;
462                                                      sub buckets_of {
463   ***      1     50             1             5         return @buck_tens if @buck_tens;
464                                                   
465                                                         # To make a more precise map, we first set the starting values for
466                                                         # each of the 8 base 10 buckets. 
467            1                                  4         my $start_bucket  = 0;
468            1                                  4         my @base10_starts = (0);
469            1                                  4         map { push @base10_starts, (10**$_)*MIN_BUCK } (1..7);
               7                                 28   
470                                                   
471                                                         # Then find the base 1.05 buckets that correspond to each
472                                                         # base 10 bucket. The last value in each bucket's range belongs
473                                                         # to the next bucket, so $next_bucket-1 represents the real last
474                                                         # base 1.05 bucket in which the base 10 bucket's range falls.
475            1                                  7         for my $base10_bucket ( 0..($#base10_starts-1) ) {
476            7                                 29            my $next_bucket = bucket_idx( $base10_starts[$base10_bucket+1] );
477            7                                 14            MKDEBUG && _d('Base 10 bucket $base10_bucket maps to',
478                                                               'base 1.05 buckets', $start_bucket, '..', $next_bucket-1);
479            7                                 25            for my $base1_05_bucket ($start_bucket..($next_bucket-1)) {
480          331                                997               $buck_tens[$base1_05_bucket] = $base10_bucket;
481                                                            }
482            7                                 22            $start_bucket = $next_bucket;
483                                                         }
484                                                   
485                                                         # Map all remaining base 1.05 buckets to base 10 bucket 7 which
486                                                         # is for vals > 10.
487            1                                 31         map { $buck_tens[$_] = 7 } ($start_bucket..(NUM_BUCK-1));
             669                               2125   
488                                                   
489            1                                125         return @buck_tens;
490                                                      }
491                                                   }
492                                                   
493                                                   # Given an arrayref of vals, returns a hashref with the following
494                                                   # statistical metrics:
495                                                   #
496                                                   #    pct_95    => top bucket value in the 95th percentile
497                                                   #    cutoff    => How many values fall into the 95th percentile
498                                                   #    stddev    => of all values
499                                                   #    median    => of all values
500                                                   #
501                                                   # The vals arrayref is the buckets as per the above (see the comments at the top
502                                                   # of this file).  $args should contain cnt, min and max properties.
503                                                   sub calculate_statistical_metrics {
504           17                   17          4388      my ( $self, $vals, $args ) = @_;
505           17                                105      my $statistical_metrics = {
506                                                         pct_95    => 0,
507                                                         stddev    => 0,
508                                                         median    => 0,
509                                                         cutoff    => undef,
510                                                      };
511                                                   
512                                                      # These cases might happen when there is nothing to get from the event, for
513                                                      # example, processlist sniffing doesn't gather Rows_examined, so $args won't
514                                                      # have {cnt} or other properties.
515           17    100    100                  222      return $statistical_metrics
                           100                        
516                                                         unless defined $vals && @$vals && $args->{cnt};
517                                                   
518                                                      # Return accurate metrics for some cases.
519           13                                 46      my $n_vals = $args->{cnt};
520           13    100    100                  122      if ( $n_vals == 1 || $args->{max} == $args->{min} ) {
                    100                               
521   ***      7            50                   31         my $v      = $args->{max} || 0;
522   ***      7     50                          42         my $bucket = int(6 + ( log($v > 0 ? $v : MIN_BUCK) / log(10)));
523   ***      7     50                          46         $bucket    = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
524                                                         return {
525            7                                 48            pct_95 => $v,
526                                                            stddev => 0,
527                                                            median => $v,
528                                                            cutoff => $n_vals,
529                                                         };
530                                                      }
531                                                      elsif ( $n_vals == 2 ) {
532            1                                  5         foreach my $v ( $args->{min}, $args->{max} ) {
533   ***      2     50     33                   24            my $bucket = int(6 + ( log($v && $v > 0 ? $v : MIN_BUCK) / log(10)));
534   ***      2     50                          11            $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
535                                                         }
536   ***      1            50                    7         my $v      = $args->{max} || 0;
537   ***      1            50                    6         my $mean = (($args->{min} || 0) + $v) / 2;
538                                                         return {
539            1                                 15            pct_95 => $v,
540                                                            stddev => sqrt((($v - $mean) ** 2) *2),
541                                                            median => $mean,
542                                                            cutoff => $n_vals,
543                                                         };
544                                                      }
545                                                   
546                                                      # Determine cutoff point for 95% if there are at least 10 vals.  Cutoff
547                                                      # serves also for the number of vals left in the 95%.  E.g. with 50 vals the
548                                                      # cutoff is 47 which means there are 47 vals: 0..46.  $cutoff is NOT an array
549                                                      # index.
550            5    100                          34      my $cutoff = $n_vals >= 10 ? int ( $n_vals * 0.95 ) : $n_vals;
551            5                                 17      $statistical_metrics->{cutoff} = $cutoff;
552                                                   
553                                                      # Calculate the standard deviation and median of all values.
554            5                                 15      my $total_left = $n_vals;
555            5                                 15      my $top_vals   = $n_vals - $cutoff; # vals > 95th
556            5                                 13      my $sum_excl   = 0;
557            5                                 14      my $sum        = 0;
558            5                                 14      my $sumsq      = 0;
559            5                                 23      my $mid        = int($n_vals / 2);
560            5                                 13      my $median     = 0;
561            5                                 12      my $prev       = NUM_BUCK-1; # Used for getting median when $cutoff is odd
562            5                                 14      my $bucket_95  = 0; # top bucket in 95th
563                                                   
564            5                                 14      MKDEBUG && _d('total vals:', $total_left, 'top vals:', $top_vals, 'mid:', $mid);
565                                                   
566                                                      BUCKET:
567            5                                 50      for my $bucket ( reverse 0..(NUM_BUCK-1) ) {
568         5000                              13857         my $val = $vals->[$bucket];
569         5000    100                       18065         next BUCKET unless $val; 
570                                                   
571           19                                 48         $total_left -= $val;
572           19                                 54         $sum_excl   += $val;
573           19    100    100                  141         $bucket_95   = $bucket if !$bucket_95 && $sum_excl > $top_vals;
574                                                   
575           19    100    100                  125         if ( !$median && $total_left <= $mid ) {
576   ***      5     50     66                   48            $median = (($cutoff % 2) || ($val > 1)) ? $buck_vals[$bucket]
577                                                                    : ($buck_vals[$bucket] + $buck_vals[$prev]) / 2;
578                                                         }
579                                                   
580           19                                 70         $sum    += $val * $buck_vals[$bucket];
581           19                                 72         $sumsq  += $val * ($buck_vals[$bucket]**2);
582           19                                 59         $prev   =  $bucket;
583                                                      }
584                                                   
585            5                                 35      my $var      = $sumsq/$n_vals - ( ($sum/$n_vals) ** 2 );
586            5    100                          33      my $stddev   = $var > 0 ? sqrt($var) : 0;
587   ***      5            50                   60      my $maxstdev = (($args->{max} || 0) - ($args->{min} || 0)) / 2;
                           100                        
588   ***      5     50                          22      $stddev      = $stddev > $maxstdev ? $maxstdev : $stddev;
589                                                   
590            5                                 11      MKDEBUG && _d('sum:', $sum, 'sumsq:', $sumsq, 'stddev:', $stddev,
591                                                         'median:', $median, 'prev bucket:', $prev,
592                                                         'total left:', $total_left, 'sum excl', $sum_excl,
593                                                         'bucket 95:', $bucket_95, $buck_vals[$bucket_95]);
594                                                   
595            5                                 20      $statistical_metrics->{stddev} = $stddev;
596            5                                 18      $statistical_metrics->{pct_95} = $buck_vals[$bucket_95];
597            5                                 17      $statistical_metrics->{median} = $median;
598                                                   
599            5                                 29      return $statistical_metrics;
600                                                   }
601                                                   
602                                                   # Return a hashref of the metrics for some attribute, pre-digested.
603                                                   # %args is:
604                                                   #  attrib => the attribute to report on
605                                                   #  where  => the value of the fingerprint for the attrib
606                                                   sub metrics {
607            2                    2            12      my ( $self, %args ) = @_;
608            2                                  8      foreach my $arg ( qw(attrib where) ) {
609   ***      4     50                          20         die "I need a $arg argument" unless $args{$arg};
610                                                      }
611            2                                  9      my $stats = $self->results;
612            2                                 11      my $store = $stats->{classes}->{$args{where}}->{$args{attrib}};
613                                                   
614            2                                 12      my $global_cnt = $stats->{globals}->{$args{attrib}}->{cnt};
615            2                                 11      my $metrics    = $self->calculate_statistical_metrics($store->{all}, $store);
616                                                   
617                                                      return {
618   ***      2    100     66                   68         cnt    => $store->{cnt},
      ***           100     66                        
619                                                         pct    => $global_cnt && $store->{cnt} ? $store->{cnt} / $global_cnt : 0,
620                                                         sum    => $store->{sum},
621                                                         min    => $store->{min},
622                                                         max    => $store->{max},
623                                                         avg    => $store->{sum} && $store->{cnt} ? $store->{sum} / $store->{cnt} : 0,
624                                                         median => $metrics->{median},
625                                                         pct_95 => $metrics->{pct_95},
626                                                         stddev => $metrics->{stddev},
627                                                      };
628                                                   }
629                                                   
630                                                   # Find the top N or top % event keys, in sorted order, optionally including
631                                                   # outliers (ol_...) that are notable for some reason.  %args looks like this:
632                                                   #
633                                                   #  attrib      order-by attribute (usually Query_time)
634                                                   #  orderby     order-by aggregate expression (should be numeric, usually sum)
635                                                   #  total       include events whose summed attribs are <= this number...
636                                                   #  count       ...or this many events, whichever is less...
637                                                   #  ol_attrib   ...or events where the 95th percentile of this attribute...
638                                                   #  ol_limit    ...is greater than this value, AND...
639                                                   #  ol_freq     ...the event occurred at least this many times.
640                                                   # The return value is a list of arrayrefs.  Each arrayref is the event key and
641                                                   # an explanation of why it was included (top|outlier).
642                                                   sub top_events {
643            3                    3            55      my ( $self, %args ) = @_;
644            3                                 13      my $classes = $self->{result_classes};
645           15                                 99      my @sorted = reverse sort { # Sorted list of $groupby values
646           16                                 71         $classes->{$a}->{$args{attrib}}->{$args{orderby}}
647                                                            <=> $classes->{$b}->{$args{attrib}}->{$args{orderby}}
648                                                         } grep {
649                                                            # Defensive programming
650            3                                 18            defined $classes->{$_}->{$args{attrib}}->{$args{orderby}}
651                                                         } keys %$classes;
652            3                                 21      my @chosen;
653            3                                 10      my ($total, $count) = (0, 0);
654            3                                 11      foreach my $groupby ( @sorted ) {
655                                                         # Events that fall into the top criterion for some reason
656           15    100    100                  251         if ( 
      ***           100     66                        
                           100                        
                           100                        
                           100                        
657                                                            (!$args{total} || $total < $args{total} )
658                                                            && ( !$args{count} || $count < $args{count} )
659                                                         ) {
660            6                                 71            push @chosen, [$groupby, 'top'];
661                                                         }
662                                                   
663                                                         # Events that are notable outliers
664                                                         elsif ( $args{ol_attrib} && (!$args{ol_freq}
665                                                            || $classes->{$groupby}->{$args{ol_attrib}}->{cnt} >= $args{ol_freq})
666                                                         ) {
667                                                            # Calculate the 95th percentile of this event's specified attribute.
668            5                                 11            MKDEBUG && _d('Calculating statistical_metrics');
669            5                                 36            my $stats = $self->calculate_statistical_metrics(
670                                                               $classes->{$groupby}->{$args{ol_attrib}}->{all},
671                                                               $classes->{$groupby}->{$args{ol_attrib}}
672                                                            );
673            5    100                          28            if ( $stats->{pct_95} >= $args{ol_limit} ) {
674            3                                 16               push @chosen, [$groupby, 'outlier'];
675                                                            }
676                                                         }
677                                                   
678           15                                 70         $total += $classes->{$groupby}->{$args{attrib}}->{$args{orderby}};
679           15                                 44         $count++;
680                                                      }
681            3                                 33      return @chosen;
682                                                   }
683                                                   
684                                                   # Adds all new attributes in $event to $self->{attributes}.
685                                                   sub add_new_attributes {
686            7                    7            29      my ( $self, $event ) = @_;
687   ***      7     50                          34      return unless $event;
688           20                                 88      map {
689           59    100    100                  611         $self->{attributes}->{$_}  = [$_];
690           20                                 75         $self->{alt_attribs}->{$_} = make_alt_attrib($_);
691           20                                 51         push @{$self->{all_attribs}}, $_;
              20                                 76   
692           20                                 55         MKDEBUG && _d('Added new attribute:', $_);
693                                                      }
694                                                      grep {
695            7                                 38         $_ ne $self->{groupby}
696                                                         && !exists $self->{attributes}->{$_}
697                                                         && !exists $self->{ignore_attribs}->{$_}
698                                                      }
699                                                      keys %$event;
700            7                                 29      return;
701                                                   }
702                                                   
703                                                   # Returns a list of all the attributes that were either given
704                                                   # explicitly to new() or that were auto-detected.
705                                                   sub get_attributes {
706            1                    1           133      my ( $self ) = @_;
707            1                                  3      return @{$self->{all_attribs}};
               1                                 17   
708                                                   }
709                                                   
710                                                   sub events_processed {
711            1                    1             4      my ( $self ) = @_;
712            1                                  9      return $self->{n_events};
713                                                   }
714                                                   
715                                                   sub make_alt_attrib {
716           39                   39           146      my ( @attribs ) = @_;
717                                                   
718           39                                128      my $attrib = shift @attribs;  # Primary attribute.
719           39    100             8           497      return sub {} unless @attribs;  # No alternates.
               8                                 23   
720                                                   
721            1                                  3      my @lines;
722            1                                  5      push @lines, 'sub { my ( $event ) = @_; my $alt_attrib;';
723            1                                  8      push @lines, map  {
724            1                                  3            "\$alt_attrib = '$_' if !defined \$alt_attrib "
725                                                            . "&& exists \$event->{'$_'};"
726                                                         } @attribs;
727            1                                  3      push @lines, 'return $alt_attrib; }';
728            1                                  3      MKDEBUG && _d('alt attrib sub for', $attrib, ':', @lines);
729            1                                 83      my $sub = eval join("\n", @lines);
730   ***      1     50                           5      die if $EVAL_ERROR;
731            1                                 26      return $sub;
732                                                   }
733                                                   
734                                                   sub _d {
735   ***      0                    0                    my ($package, undef, $line) = caller 0;
736   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
737   ***      0                                              map { defined $_ ? $_ : 'undef' }
738                                                           @_;
739   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
740                                                   }
741                                                   
742                                                   1;
743                                                   
744                                                   # ###########################################################################
745                                                   # End EventAggregator package
746                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
69    ***     50      0     26   unless $args{$arg}
88           100      3     10   scalar keys %$attributes == 0 ? :
130          100      2   1336   unless defined $group_by
133          100      7   1329   if $$self{'detect_attribs'}
138          100   1255     81   if (exists $$self{'unrolled_loops'})
151          100      9    143   if (not exists $$event{$attrib})
155          100      8      1   unless $alt_attrib
160          100      4    140   ref $group_by ? :
165          100     39    107   if (not $handler)
174   ***     50      0    146   unless $handler
182          100      1     80   if ($$self{'n_queries'}++ > 50 or not grep {ref $$self{'handlers'}{$_} ne 'CODE';} @attrs && !$$self{'detect_attribs'})
199   ***     50      0      1   ref $group_by ? :
216   ***     50      0      1   if (ref $group_by)
227   ***     50      0      1   if $EVAL_ERROR
296   ***     50      0     39   unless defined $attrib
299   ***     50      0     39   if (ref $val eq 'ARRAY')
303   ***     50      0     39   unless defined $val
307   ***     50      0     17   $val =~ /^(?:Yes|No)$/ ? :
             100     22     17   $val =~ /^(?:\d+|$float_re)$/o ? :
314          100     22     17   $type =~ /num|bool/ ? :
             100     17     22   $type =~ /bool|string/ ? :
             100     22     17   $type eq 'num' ? :
      ***     50      0     39   $type eq 'bool' ? :
329   ***     50      0     39   if ($args{'trf'})
335   ***     50     78      0   if ($args{'min'})
336          100     44     34   $type eq 'num' ? :
342   ***     50     78      0   if ($args{'max'})
343          100     44     34   $type eq 'num' ? :
349          100     44     34   if ($args{'sum'})
352   ***     50     78      0   if ($args{'cnt'})
355          100     44     34   if ($args{'all'})
365          100     17     22   if ($args{'unq'})
368          100      8     31   if ($args{'wor'})
369   ***     50      8      0   $type eq 'num' ? :
380          100      1     38   if ($args{'all'} and $type eq 'num' and $$self{'attrib_limit'})
396   ***     50      0     39   $is_array ? :
      ***     50      0     39   $is_array ? :
409   ***     50      0     39   $is_array ? :
      ***     50      0     39   $is_array ? :
421   ***     50      0     39   if $EVAL_ERROR
433          100     20   2774   if $val < 1e-06
435          100      1   2773   $idx > 999 ? :
448          100      2   1005   if $bucket == 0
449   ***     50      0   1005   if $bucket < 0 or $bucket > 999
463   ***     50      0      1   if @buck_tens
515          100      4     13   unless defined $vals and @$vals and $$args{'cnt'}
520          100      7      6   if ($n_vals == 1 or $$args{'max'} == $$args{'min'}) { }
             100      1      5   elsif ($n_vals == 2) { }
522   ***     50      7      0   $v > 0 ? :
523   ***     50      0      7   $bucket < 0 ? :
      ***     50      0      7   $bucket > 7 ? :
533   ***     50      2      0   $v && $v > 0 ? :
534   ***     50      0      2   $bucket < 0 ? :
      ***     50      0      2   $bucket > 7 ? :
550          100      4      1   $n_vals >= 10 ? :
569          100   4981     19   unless $val
573          100      5     14   if not $bucket_95 and $sum_excl > $top_vals
575          100      5     14   if (not $median and $total_left <= $mid)
576   ***     50      5      0   $cutoff % 2 || $val > 1 ? :
586          100      3      2   $var > 0 ? :
588   ***     50      0      5   $stddev > $maxstdev ? :
609   ***     50      0      4   unless $args{$arg}
618          100      1      1   $global_cnt && $$store{'cnt'} ? :
             100      1      1   $$store{'sum'} && $$store{'cnt'} ? :
656          100      6      9   if (!$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}) { }
             100      5      4   elsif ($args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}) { }
673          100      3      2   if ($$stats{'pct_95'} >= $args{'ol_limit'})
687   ***     50      0      7   unless $event
689          100     24     35   if $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}
719          100     38      1   unless @attribs
730   ***     50      0      1   if $EVAL_ERROR
736   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
182   ***     66      0      7     73   @attrs && !$$self{'detect_attribs'}
380   ***     66     17      0     22   $args{'all'} and $type eq 'num'
             100     17     21      1   $args{'all'} and $type eq 'num' and $$self{'attrib_limit'}
515          100      2      1     14   defined $vals and @$vals
             100      3      1     13   defined $vals and @$vals and $$args{'cnt'}
533   ***     33      0      0      2   $v && $v > 0
573          100     11      3      5   not $bucket_95 and $sum_excl > $top_vals
575          100      5      9      5   not $median and $total_left <= $mid
618   ***     66      1      0      1   $global_cnt && $$store{'cnt'}
      ***     66      1      0      1   $$store{'sum'} && $$store{'cnt'}
656          100      6      3      6   !$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}
             100      3      1      5   $args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}
689          100      7     28     24   $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
71           100     10      3   $args{'attributes'} || {}
88    ***     50      0     13   $args{'unroll_limit'} || 50
161          100     66     80   $$self{'result_classes'}{$val}{$attrib} ||= {}
162          100    107     39   $$self{'result_globals'}{$attrib} ||= {}
175          100    123     23   $$samples{$val} ||= $event
521   ***     50      7      0   $$args{'max'} || 0
536   ***     50      1      0   $$args{'max'} || 0
537   ***     50      1      0   $$args{'min'} || 0
587   ***     50      5      0   $$args{'max'} || 0
             100      4      1   $$args{'min'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
182   ***     66      1      0     80   $$self{'n_queries'}++ > 50 or not grep {ref $$self{'handlers'}{$_} ne 'CODE';} @attrs && !$$self{'detect_attribs'}
449   ***     33      0      0   1005   $bucket < 0 or $bucket > 999
520          100      3      4      6   $n_vals == 1 or $$args{'max'} == $$args{'min'}
576   ***     66      2      3      0   $cutoff % 2 || $val > 1
656          100      5      4      6   !$args{'total'} || $total < $args{'total'}
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
__ANON__                          8 /home/daniel/dev/maatkit/common/EventAggregator.pm:719
add_new_attributes                7 /home/daniel/dev/maatkit/common/EventAggregator.pm:686
aggregate                      1338 /home/daniel/dev/maatkit/common/EventAggregator.pm:127
attributes                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:247
bucket_idx                     2794 /home/daniel/dev/maatkit/common/EventAggregator.pm:432
bucket_value                   1007 /home/daniel/dev/maatkit/common/EventAggregator.pm:447
buckets_of                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:463
calculate_statistical_metrics    17 /home/daniel/dev/maatkit/common/EventAggregator.pm:504
events_processed                  1 /home/daniel/dev/maatkit/common/EventAggregator.pm:711
get_attributes                    1 /home/daniel/dev/maatkit/common/EventAggregator.pm:706
make_alt_attrib                  39 /home/daniel/dev/maatkit/common/EventAggregator.pm:716
make_handler                     39 /home/daniel/dev/maatkit/common/EventAggregator.pm:295
metrics                           2 /home/daniel/dev/maatkit/common/EventAggregator.pm:607
new                              13 /home/daniel/dev/maatkit/common/EventAggregator.pm:67 
reset_aggregated_data             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:108
results                          19 /home/daniel/dev/maatkit/common/EventAggregator.pm:236
top_events                        3 /home/daniel/dev/maatkit/common/EventAggregator.pm:643
type_for                          2 /home/daniel/dev/maatkit/common/EventAggregator.pm:254

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                              
----------------------------- ----- ------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/EventAggregator.pm:735


