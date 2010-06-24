---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/EventAggregator.pm   92.9   73.2   71.9   97.4    0.0   94.6   82.9
EventAggregator.t             100.0   92.9   33.3  100.0    n/a    5.4   98.9
Total                          95.2   74.4   70.9   98.1    0.0  100.0   86.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:01 2010
Finish:       Thu Jun 24 19:33:01 2010

Run:          EventAggregator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:33:03 2010
Finish:       Thu Jun 24 19:33:05 2010

/home/daniel/dev/maatkit/common/EventAggregator.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2010 Percona Inc.
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
18                                                    # EventAggregator package $Revision: 6309 $
19                                                    # ###########################################################################
20                                                    package EventAggregator;
21                                                    
22             1                    1             9   use strict;
               1                                  2   
               1                                 90   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25             1                    1             7   use List::Util qw(min max);
               1                                  2   
               1                                 12   
26             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  8   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31                                                    # ###########################################################################
32                                                    # Set up some constants for bucketing values.  It is impossible to keep all
33                                                    # values seen in memory, but putting them into logarithmically scaled buckets
34                                                    # and just incrementing the bucket each time works, although it is imprecise.
35                                                    # See http://code.google.com/p/maatkit/wiki/EventAggregatorInternals.
36                                                    # ###########################################################################
37    ***      1            50      1             6   use constant MKDEBUG      => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 12   
38             1                    1             6   use constant BUCK_SIZE    => 1.05;
               1                                  2   
               1                                  5   
39             1                    1             6   use constant BASE_LOG     => log(BUCK_SIZE);
               1                                  2   
               1                                  4   
40             1                    1             6   use constant BASE_OFFSET  => abs(1 - log(0.000001) / BASE_LOG); # 284.1617969
               1                                  2   
               1                                  4   
41             1                    1             5   use constant NUM_BUCK     => 1000;
               1                                  2   
               1                                  4   
42             1                    1             6   use constant MIN_BUCK     => .000001;
               1                                  2   
               1                                  4   
43                                                    
44                                                    # Used in buckets_of() to map buckets of log10 to log1.05 buckets.
45                                                    my @buck_vals = map { bucket_value($_); } (0..NUM_BUCK-1);
46                                                    
47                                                    # The best way to see how to use this is to look at the .t file.
48                                                    #
49                                                    # %args is a hash containing:
50                                                    # groupby      The name of the property to group/aggregate by.
51                                                    # attributes   An optional hashref.  Each key is the name of an element to
52                                                    #              aggregate.  And the values of those elements are arrayrefs of the
53                                                    #              values to pull from the hashref, with any second or subsequent
54                                                    #              values being fallbacks for the first in case it's not defined.
55                                                    #              If no attributes are given, then all attributes in events will
56                                                    #              be aggregated.
57                                                    # ignore_attributes  An option arrayref.  These attributes are ignored only if
58                                                    #                    they are auto-detected.  This list does not apply to
59                                                    #                    explicitly given attributes.
60                                                    # worst        The name of an element which defines the "worst" hashref in its
61                                                    #              class.  If this is Query_time, then each class will contain
62                                                    #              a sample that holds the event with the largest Query_time.
63                                                    # unroll_limit If this many events have been processed and some handlers haven't
64                                                    #              been generated yet (due to lack of sample data) unroll the loop
65                                                    #              anyway.  Defaults to 1000.
66                                                    # attrib_limit Sanity limit for attribute values.  If the value exceeds the
67                                                    #              limit, use the last-seen for this class; if none, then 0.
68                                                    # type_for     A hashref of attribute names and types.
69                                                    sub new {
70    ***     21                   21      0    174      my ( $class, %args ) = @_;
71            21                                143      foreach my $arg ( qw(groupby worst) ) {
72    ***     42     50                         221         die "I need a $arg argument" unless $args{$arg};
73                                                       }
74            21           100                  155      my $attributes = $args{attributes} || {};
75             3                                 29      my $self = {
76                                                          groupby        => $args{groupby},
77                                                          detect_attribs => scalar keys %$attributes == 0 ? 1 : 0,
78                                                          all_attribs    => [ keys %$attributes ],
79                                                          ignore_attribs => {
80             3                                 12            map  { $_ => $args{attributes}->{$_} }
81            21                                219            grep { $_ ne $args{groupby} }
82            42                                295            @{$args{ignore_attributes}}
83                                                          },
84                                                          attributes     => {
85            43                                175            map  { $_ => $args{attributes}->{$_} }
86            42                                217            grep { $_ ne $args{groupby} }
87                                                             keys %$attributes
88                                                          },
89                                                          alt_attribs    => {
90            42                                127            map  { $_ => make_alt_attrib(@{$args{attributes}->{$_}}) }
              43                                170   
91            21    100                         464            grep { $_ ne $args{groupby} }
92                                                             keys %$attributes
93                                                          },
94                                                          worst        => $args{worst},
95                                                          unroll_limit => $args{unroll_limit} || 1000,
96                                                          attrib_limit => $args{attrib_limit},
97                                                          result_classes => {},
98                                                          result_globals => {},
99                                                          result_samples => {},
100                                                         class_metrics  => {},
101                                                         global_metrics => {},
102                                                         n_events       => 0,
103                                                         unrolled_loops => undef,
104           21    100    100                  212         type_for       => { %{$args{type_for} || { Query_time => 'num' }} },
105                                                      };
106           21                                219      return bless $self, $class;
107                                                   }
108                                                   
109                                                   # Delete all collected data, but don't delete things like the generated
110                                                   # subroutines.  Resetting aggregated data is an interesting little exercise.
111                                                   # The generated functions that do aggregation have private namespaces with
112                                                   # references to some of the data.  Thus, they will not necessarily do as
113                                                   # expected if the stored data is simply wiped out.  Instead, it needs to be
114                                                   # zeroed out without replacing the actual objects.
115                                                   sub reset_aggregated_data {
116   ***      1                    1      0      4      my ( $self ) = @_;
117            1                                  4      foreach my $class ( values %{$self->{result_classes}} ) {
               1                                  7   
118            1                                  5         foreach my $attrib ( values %$class ) {
119            2                                 10            delete @{$attrib}{keys %$attrib};
               2                                 14   
120                                                         }
121                                                      }
122            1                                  3      foreach my $class ( values %{$self->{result_globals}} ) {
               1                                  6   
123            2                                  9         delete @{$class}{keys %$class};
               2                                  9   
124                                                      }
125            1                                  3      delete @{$self->{result_samples}}{keys %{$self->{result_samples}}};
               1                                  4   
               1                                  5   
126            1                                  5      $self->{n_events} = 0;
127                                                   }
128                                                   
129                                                   # Aggregate an event hashref's properties.  Code is built on the fly to do this,
130                                                   # based on the values being passed in.  After code is built for every attribute
131                                                   # (or 50 events are seen and we decide to give up) the little bits of code get
132                                                   # unrolled into a whole subroutine to handle events.  For that reason, you can't
133                                                   # re-use an instance.
134                                                   sub aggregate {
135   ***   1708                 1708      0 175741      my ( $self, $event ) = @_;
136                                                   
137         1708                               6705      my $group_by = $event->{$self->{groupby}};
138         1708    100                        6378      return unless defined $group_by;
139                                                   
140         1706                               4913      $self->{n_events}++;
141         1706                               3641      MKDEBUG && _d('event', $self->{n_events});
142                                                   
143                                                      # Run only unrolled loops if available.
144         1706    100                        7860      return $self->{unrolled_loops}->($self, $event, $group_by)
145                                                         if $self->{unrolled_loops};
146                                                   
147                                                      # For the first unroll_limit events, auto-detect new attribs and
148                                                      # run attrib handlers.
149         1268    100                        5631      if ( $self->{n_events} <= $self->{unroll_limit} ) {
150                                                   
151         1265    100                        5471         $self->add_new_attributes($event) if $self->{detect_attribs};
152                                                   
153         1265                               6051         ATTRIB:
154         1265                               3242         foreach my $attrib ( keys %{$self->{attributes}} ) {
155                                                   
156                                                            # Attrib auto-detection can add a lot of attributes which some events
157                                                            # may or may not have.  Aggregating a nonexistent attrib is wasteful,
158                                                            # so we check that the attrib or one of its alternates exists.  If
159                                                            # one does, then we leave attrib alone because the handler sub will
160                                                            # also check alternates.
161         4618    100                       19116            if ( !exists $event->{$attrib} ) {
162           18                                 44               MKDEBUG && _d("attrib doesn't exist in event:", $attrib);
163           18                                 93               my $alt_attrib = $self->{alt_attribs}->{$attrib}->($event);
164           18                                127               MKDEBUG && _d('alt attrib:', $alt_attrib);
165           18    100                          87               next ATTRIB unless $alt_attrib;
166                                                            }
167                                                   
168                                                            # The value of the attribute ( $group_by ) may be an arrayref.
169                                                            GROUPBY:
170         4601    100                       18160            foreach my $val ( ref $group_by ? @$group_by : ($group_by) ) {
171         4603           100                26086               my $class_attrib  = $self->{result_classes}->{$val}->{$attrib} ||= {};
172         4603           100                22186               my $global_attrib = $self->{result_globals}->{$attrib} ||= {};
173         4603                              14623               my $samples       = $self->{result_samples};
174         4603                              16330               my $handler = $self->{handlers}->{ $attrib };
175         4603    100                       16876               if ( !$handler ) {
176          113                                785                  $handler = $self->make_handler(
177                                                                     $attrib,
178                                                                     $event,
179                                                                     wor => $self->{worst} eq $attrib,
180                                                                     alt => $self->{attributes}->{$attrib},
181                                                                  );
182          113                                554                  $self->{handlers}->{$attrib} = $handler;
183                                                               }
184   ***   4603     50                       16003               next GROUPBY unless $handler;
185         4603           100                18076               $samples->{$val} ||= $event; # Initialize to the first event.
186         4603                              20129               $handler->($event, $class_attrib, $global_attrib, $samples, $group_by);
187                                                            }
188                                                         }
189                                                      }
190                                                      else {
191                                                         # After unroll_limit events, unroll the loops.
192            3                                 18         $self->_make_unrolled_loops($event);
193                                                         # Run unrolled loops here once.  Next time, they'll be ran
194                                                         # before this if-else.
195            3                                 20         $self->{unrolled_loops}->($self, $event, $group_by);
196                                                      }
197                                                   
198         1268                               8540      return;
199                                                   }
200                                                   
201                                                   sub _make_unrolled_loops {
202            3                    3            14      my ( $self, $event ) = @_;
203                                                   
204            3                                 14      my $group_by = $event->{$self->{groupby}};
205                                                   
206                                                      # All attributes have handlers, so let's combine them into one faster sub.
207                                                      # Start by getting direct handles to the location of each data store and
208                                                      # thing that would otherwise be looked up via hash keys.
209            3                                 10      my @attrs   = grep { $self->{handlers}->{$_} } keys %{$self->{attributes}};
              31                                151   
               3                                 21   
210            3                                 20      my $globs   = $self->{result_globals}; # Global stats for each
211            3                                 10      my $samples = $self->{result_samples};
212                                                   
213                                                      # Now the tricky part -- must make sure only the desired variables from
214                                                      # the outer scope are re-used, and any variables that should have their
215                                                      # own scope are declared within the subroutine.
216   ***      3     50                          27      my @lines = (
217                                                         'my ( $self, $event, $group_by ) = @_;',
218                                                         'my ($val, $class, $global, $idx);',
219                                                         (ref $group_by ? ('foreach my $group_by ( @$group_by ) {') : ()),
220                                                         # Create and get each attribute's storage
221                                                         'my $temp = $self->{result_classes}->{ $group_by }
222                                                            ||= { map { $_ => { } } @attrs };',
223                                                         '$samples->{$group_by} ||= $event;', # Always start with the first.
224                                                      );
225            3                                 23      foreach my $i ( 0 .. $#attrs ) {
226                                                         # Access through array indexes, it's faster than hash lookups
227           31                                278         push @lines, (
228                                                            '$class  = $temp->{\''  . $attrs[$i] . '\'};',
229                                                            '$global = $globs->{\'' . $attrs[$i] . '\'};',
230                                                            $self->{unrolled_for}->{$attrs[$i]},
231                                                         );
232                                                      }
233   ***      3     50                          15      if ( ref $group_by ) {
234   ***      0                                  0         push @lines, '}'; # Close the loop opened above
235                                                      }
236            3                                 12      @lines = map { s/^/   /gm; $_ } @lines; # Indent for debugging
             105                                694   
             105                                431   
237            3                                 31      unshift @lines, 'sub {';
238            3                                 10      push @lines, '}';
239                                                   
240                                                      # Make the subroutine.
241            3                                 79      my $code = join("\n", @lines);
242            3                                  8      MKDEBUG && _d('Unrolled subroutine:', @lines);
243            3                               4445      my $sub = eval $code;
244   ***      3     50                          19      die $EVAL_ERROR if $EVAL_ERROR;
245            3                                 13      $self->{unrolled_loops} = $sub;
246                                                   
247            3                                 21      return;
248                                                   }
249                                                   
250                                                   # Return the aggregated results.
251                                                   sub results {
252   ***     23                   23      0     93      my ( $self ) = @_;
253                                                      return {
254           23                                396         classes => $self->{result_classes},
255                                                         globals => $self->{result_globals},
256                                                         samples => $self->{result_samples},
257                                                      };
258                                                   }
259                                                   
260                                                   sub set_results {
261   ***      1                    1      0      4      my ( $self, $results ) = @_;
262            1                                  6      $self->{result_classes} = $results->{classes};
263            1                                  5      $self->{result_globals} = $results->{globals};
264            1                                  5      $self->{result_samples} = $results->{samples};
265            1                                  3      return;
266                                                   }
267                                                   
268                                                   sub stats {
269   ***      2                    2      0      7      my ( $self ) = @_;
270                                                      return {
271            2                                 11         classes => $self->{class_metrics},
272                                                         globals => $self->{global_metrics},
273                                                      };
274                                                   }
275                                                   
276                                                   # Return the attributes that this object is tracking, and their data types, as
277                                                   # a hashref of name => type.
278                                                   sub attributes {
279   ***      3                    3      0     12      my ( $self ) = @_;
280            3                                 29      return $self->{type_for};
281                                                   }
282                                                   
283                                                   sub set_attribute_types {
284   ***      1                    1      0      5      my ( $self, $attrib_types ) = @_;
285            1                                  5      $self->{type_for} = $attrib_types;
286            1                                  3      return;
287                                                   }
288                                                   
289                                                   # Returns the type of the attribute (as decided by the aggregation process,
290                                                   # which inspects the values).
291                                                   sub type_for {
292   ***    130                  130      0    544      my ( $self, $attrib ) = @_;
293          130                               1444      return $self->{type_for}->{$attrib};
294                                                   }
295                                                   
296                                                   # Make subroutines that do things with events.
297                                                   #
298                                                   # $attrib: the name of the attrib (Query_time, Rows_read, etc)
299                                                   # $event:  a sample event
300                                                   # %args:
301                                                   #     min => keep min for this attrib (default except strings)
302                                                   #     max => keep max (default except strings)
303                                                   #     sum => keep sum (default for numerics)
304                                                   #     cnt => keep count (default except strings)
305                                                   #     unq => keep all unique values per-class (default for strings and bools)
306                                                   #     all => keep a bucketed list of values seen per class (default for numerics)
307                                                   #     glo => keep stats globally as well as per-class (default)
308                                                   #     trf => An expression to transform the value before working with it
309                                                   #     wor => Whether to keep worst-samples for this attrib (default no)
310                                                   #     alt => Arrayref of other name(s) for the attribute, like db => Schema.
311                                                   #
312                                                   # The bucketed list works this way: each range of values from MIN_BUCK in
313                                                   # increments of BUCK_SIZE (that is 5%) we consider a bucket.  We keep NUM_BUCK
314                                                   # buckets.  The upper end of the range is more than 1.5e15 so it should be big
315                                                   # enough for almost anything.  The buckets are accessed by a log base BUCK_SIZE,
316                                                   # so floor(log(N)/log(BUCK_SIZE)).  The smallest bucket's index is -284. We
317                                                   # shift all values up 284 so we have values from 0 to 999 that can be used as
318                                                   # array indexes.  A value that falls into a bucket simply increments the array
319                                                   # entry.  We do NOT use POSIX::floor() because it is too expensive.
320                                                   #
321                                                   # This eliminates the need to keep and sort all values to calculate median,
322                                                   # standard deviation, 95th percentile etc.  Thus the memory usage is bounded by
323                                                   # the number of distinct aggregated values, not the number of events.
324                                                   #
325                                                   # Return value:
326                                                   # a subroutine with this signature:
327                                                   #    my ( $event, $class, $global ) = @_;
328                                                   # where
329                                                   #  $event   is the event
330                                                   #  $class   is the container to store the aggregated values
331                                                   #  $global  is is the container to store the globally aggregated values
332                                                   sub make_handler {
333   ***    113                  113      0    771      my ( $self, $attrib, $event, %args ) = @_;
334   ***    113     50                         489      die "I need an attrib" unless defined $attrib;
335          113                                315      my ($val) = grep { defined $_ } map { $event->{$_} } @{ $args{alt} };
             114                                444   
             114                                479   
             113                                446   
336          113                                329      my $is_array = 0;
337   ***    113     50                         457      if (ref $val eq 'ARRAY') {
338   ***      0                                  0         $is_array = 1;
339   ***      0                                  0         $val      = $val->[0];
340                                                      }
341   ***    113     50                         408      return unless defined $val; # Can't decide type if it's undef.
342                                                   
343                                                      # Ripped off from Regexp::Common::number and modified.
344          113                                600      my $float_re = qr{[+-]?(?:(?=\d|[.])\d+(?:[.])\d{0,})(?:E[+-]?\d+)?}i;
345          113    100                         509      my $type = $self->type_for($attrib)         ? $self->type_for($attrib)
                    100                               
                    100                               
346                                                               : $val  =~ m/^(?:\d+|$float_re)$/o ? 'num'
347                                                               : $val  =~ m/^(?:Yes|No)$/         ? 'bool'
348                                                               :                                    'string';
349          113                                277      MKDEBUG && _d('Type for', $attrib, 'is', $type,
350                                                         '(sample:', $val, '), is array:', $is_array);
351          113                                457      $self->{type_for}->{$attrib} = $type;
352                                                   
353          113    100                        2371      %args = ( # Set up defaults
                    100                               
                    100                               
                    100                               
354                                                         min => 1,
355                                                         max => 1,
356                                                         sum => $type =~ m/num|bool/    ? 1 : 0,
357                                                         cnt => 1,
358                                                         unq => $type =~ m/bool|string/ ? 1 : 0,
359                                                         all => $type eq 'num'          ? 1 : 0,
360                                                         glo => 1,
361                                                         trf => ($type eq 'bool') ? q{(($val || '') eq 'Yes') ? 1 : 0} : undef,
362                                                         wor => 0,
363                                                         alt => [],
364                                                         %args,
365                                                      );
366                                                   
367          113                                692      my @lines = ("# type: $type"); # Lines of code for the subroutine
368          113    100                         477      if ( $args{trf} ) {
369           16                                 79         push @lines, q{$val = } . $args{trf} . ';';
370                                                      }
371                                                   
372          113                                390      foreach my $place ( qw($class $global) ) {
373          226                                533         my @tmp;
374   ***    226     50                         887         if ( $args{min} ) {
375          226    100                         866            my $op   = $type eq 'num' ? '<' : 'lt';
376          226                                932            push @tmp, (
377                                                               'PLACE->{min} = $val if !defined PLACE->{min} || $val '
378                                                                  . $op . ' PLACE->{min};',
379                                                            );
380                                                         }
381   ***    226     50                         888         if ( $args{max} ) {
382          226    100                         805            my $op = ($type eq 'num') ? '>' : 'gt';
383          226                                882            push @tmp, (
384                                                               'PLACE->{max} = $val if !defined PLACE->{max} || $val '
385                                                                  . $op . ' PLACE->{max};',
386                                                            );
387                                                         }
388          226    100                         882         if ( $args{sum} ) {
389          164                                509            push @tmp, 'PLACE->{sum} += $val;';
390                                                         }
391   ***    226     50                         853         if ( $args{cnt} ) {
392          226                                703            push @tmp, '++PLACE->{cnt};';
393                                                         }
394          226    100                         879         if ( $args{all} ) {
395          132                                507            push @tmp, (
396                                                               'exists PLACE->{all} or PLACE->{all} = {};',
397                                                               '++PLACE->{all}->{ EventAggregator::bucket_idx($val) };',
398                                                            );
399                                                         }
400          226                                729         push @lines, map { s/PLACE/$place/g; $_ } @tmp;
            1106                               5464   
            1106                               4079   
401                                                      }
402                                                   
403                                                      # We only save unique/worst values for the class, not globally.
404          113    100                         494      if ( $args{unq} ) {
405           47                                154         push @lines, '++$class->{unq}->{$val};';
406                                                      }
407          113    100                         443      if ( $args{wor} ) {
408   ***     13     50                          58         my $op = $type eq 'num' ? '>=' : 'ge';
409           13                                 66         push @lines, (
410                                                            'if ( $val ' . $op . ' ($class->{max} || 0) ) {',
411                                                            '   $samples->{$group_by} = $event;',
412                                                            '}',
413                                                         );
414                                                      }
415                                                   
416                                                      # Handle broken Query_time like 123.124345.8382 (issue 234).
417          113                                274      my @broken_query_time;
418          113    100                         419      if ( $attrib eq 'Query_time' ) {
419           14                                 68         push @broken_query_time, (
420                                                            '$val =~ s/^(\d+(?:\.\d+)?).*/$1/;',
421                                                            '$event->{\''.$attrib.'\'} = $val;',
422                                                         );
423                                                      }
424                                                   
425                                                      # Make sure the value is constrained to legal limits.  If it's out of bounds,
426                                                      # just use the last-seen value for it.
427          113                                267      my @limit;
428   ***    113    100     66                 1173      if ( $args{all} && $type eq 'num' && $self->{attrib_limit} ) {
                           100                        
429            1                                  7         push @limit, (
430                                                            "if ( \$val > $self->{attrib_limit} ) {",
431                                                            '   $val = $class->{last} ||= 0;',
432                                                            '}',
433                                                            '$class->{last} = $val;',
434                                                         );
435                                                      }
436                                                   
437                                                      # Save the code for later, as part of an "unrolled" subroutine.
438            1                                  7      my @unrolled = (
439                                                         "\$val = \$event->{'$attrib'};",
440                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
441          114                                549         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
442          113                                445            grep { $_ ne $attrib } @{$args{alt}}),
            1353                               5058   
443                                                         'defined $val && do {',
444   ***    113     50                         520         ( map { s/^/   /gm; $_ } (@broken_query_time, @limit, @lines) ), # Indent for debugging
      ***   1353     50                        5179   
445                                                         '};',
446                                                         ($is_array ? ('}') : ()),
447                                                      );
448          113                               1153      $self->{unrolled_for}->{$attrib} = join("\n", @unrolled);
449                                                   
450                                                      # Build a subroutine with the code.
451            1                                  8      unshift @lines, (
452                                                         'sub {',
453                                                         'my ( $event, $class, $global, $samples, $group_by ) = @_;',
454                                                         'my ($val, $idx);', # NOTE: define all variables here
455                                                         "\$val = \$event->{'$attrib'};",
456          114                                810         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
457   ***    113     50                         502            grep { $_ ne $attrib } @{$args{alt}}),
      ***    113     50                         411   
458                                                         'return unless defined $val;',
459                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
460                                                         @broken_query_time,
461                                                         @limit,
462                                                         ($is_array ? ('}') : ()),
463                                                      );
464          113                                371      push @lines, '}';
465          113                                647      my $code = join("\n", @lines);
466          113                                505      $self->{code_for}->{$attrib} = $code;
467                                                   
468          113                                249      MKDEBUG && _d('Metric handler for', $attrib, ':', @lines);
469          113                              20846      my $sub = eval join("\n", @lines);
470   ***    113     50                         496      die if $EVAL_ERROR;
471          113                               1268      return $sub;
472                                                   }
473                                                   
474                                                   # Returns the bucket number for the given val. Buck numbers are zero-indexed,
475                                                   # so although there are 1,000 buckets (NUM_BUCK), 999 is the greatest idx.
476                                                   # *** Notice that this sub is not a class method, so either call it
477                                                   # from inside this module like bucket_idx() or outside this module
478                                                   # like EventAggregator::bucket_idx(). ***
479                                                   # TODO: could export this by default to avoid having to specific packge::.
480                                                   sub bucket_idx {
481   ***   7955                 7955      0  28743      my ( $val ) = @_;
482         7955    100                       36419      return 0 if $val < MIN_BUCK;
483         6471                              25405      my $idx = int(BASE_OFFSET + log($val)/BASE_LOG);
484         6471    100                       41922      return $idx > (NUM_BUCK-1) ? (NUM_BUCK-1) : $idx;
485                                                   }
486                                                   
487                                                   # Returns the value for the given bucket.
488                                                   # The value of each bucket is the first value that it covers. So the value
489                                                   # of bucket 1 is 0.000001000 because it covers [0.000001000, 0.000001050).
490                                                   #
491                                                   # *** Notice that this sub is not a class method, so either call it
492                                                   # from inside this module like bucket_idx() or outside this module
493                                                   # like EventAggregator::bucket_value(). ***
494                                                   # TODO: could export this by default to avoid having to specific packge::.
495                                                   sub bucket_value {
496   ***   1007                 1007      0   3041      my ( $bucket ) = @_;
497         1007    100                        3554      return 0 if $bucket == 0;
498   ***   1005     50     33                 7294      die "Invalid bucket: $bucket" if $bucket < 0 || $bucket > (NUM_BUCK-1);
499                                                      # $bucket - 1 because buckets are shifted up by 1 to handle zero values.
500         1005                               4589      return (BUCK_SIZE**($bucket-1)) * MIN_BUCK;
501                                                   }
502                                                   
503                                                   # Map the 1,000 base 1.05 buckets to 8 base 10 buckets. Returns an array
504                                                   # of 1,000 buckets, the value of each represents its index in an 8 bucket
505                                                   # base 10 array. For example: base 10 bucket 0 represents vals (0, 0.000010),
506                                                   # and base 1.05 buckets 0..47 represent vals (0, 0.000010401). So the first
507                                                   # 48 elements of the returned array will have 0 as their values. 
508                                                   # TODO: right now it's hardcoded to buckets of 10, in the future maybe not.
509                                                   {
510                                                      my @buck_tens;
511                                                      sub buckets_of {
512   ***      1     50             1      0      7         return @buck_tens if @buck_tens;
513                                                   
514                                                         # To make a more precise map, we first set the starting values for
515                                                         # each of the 8 base 10 buckets. 
516            1                                  3         my $start_bucket  = 0;
517            1                                  4         my @base10_starts = (0);
518            1                                  4         map { push @base10_starts, (10**$_)*MIN_BUCK } (1..7);
               7                                 30   
519                                                   
520                                                         # Then find the base 1.05 buckets that correspond to each
521                                                         # base 10 bucket. The last value in each bucket's range belongs
522                                                         # to the next bucket, so $next_bucket-1 represents the real last
523                                                         # base 1.05 bucket in which the base 10 bucket's range falls.
524            1                                  8         for my $base10_bucket ( 0..($#base10_starts-1) ) {
525            7                                 30            my $next_bucket = bucket_idx( $base10_starts[$base10_bucket+1] );
526            7                                 16            MKDEBUG && _d('Base 10 bucket', $base10_bucket, 'maps to',
527                                                               'base 1.05 buckets', $start_bucket, '..', $next_bucket-1);
528            7                                 25            for my $base1_05_bucket ($start_bucket..($next_bucket-1)) {
529          331                               1039               $buck_tens[$base1_05_bucket] = $base10_bucket;
530                                                            }
531            7                                 23            $start_bucket = $next_bucket;
532                                                         }
533                                                   
534                                                         # Map all remaining base 1.05 buckets to base 10 bucket 7 which
535                                                         # is for vals > 10.
536            1                                 31         map { $buck_tens[$_] = 7 } ($start_bucket..(NUM_BUCK-1));
             669                               2176   
537                                                   
538            1                                124         return @buck_tens;
539                                                      }
540                                                   }
541                                                   
542                                                   # Calculate 95%, stddev and median for numeric attributes in the
543                                                   # global and classes stores that have all values (1k buckets).
544                                                   # Save the metrics in global_metrics and class_metrics.
545                                                   sub calculate_statistical_metrics {
546   ***      2                    2      0      9      my ( $self ) = @_;
547            2                                 10      my $classes        = $self->{result_classes};
548            2                                  7      my $globals        = $self->{result_globals};
549            2                                  7      my $class_metrics  = $self->{class_metrics};
550            2                                  7      my $global_metrics = $self->{global_metrics};
551            2                                  5      MKDEBUG && _d('Calculating statistical_metrics');
552            2                                 14      foreach my $attrib ( keys %$globals ) {
553            4    100                          22         if ( exists $globals->{$attrib}->{all} ) {
554            3                                 23            $global_metrics->{$attrib}
555                                                               = $self->_calc_metrics(
556                                                                  $globals->{$attrib}->{all},
557                                                                  $globals->{$attrib},
558                                                               );
559                                                         }
560                                                   
561            4                                 20         foreach my $class ( keys %$classes ) {
562           11    100                          63            if ( exists $classes->{$class}->{$attrib}->{all} ) {
563            9                                 58               $class_metrics->{$class}->{$attrib}
564                                                                  = $self->_calc_metrics(
565                                                                     $classes->{$class}->{$attrib}->{all},
566                                                                     $classes->{$class}->{$attrib}
567                                                                  );
568                                                            }
569                                                         }
570                                                      }
571                                                   
572            2                                 12      return;
573                                                   }
574                                                   
575                                                   # Given a hashref of vals, returns a hashref with the following
576                                                   # statistical metrics:
577                                                   #
578                                                   #    pct_95    => top bucket value in the 95th percentile
579                                                   #    cutoff    => How many values fall into the 95th percentile
580                                                   #    stddev    => of all values
581                                                   #    median    => of all values
582                                                   #
583                                                   # The vals hashref represents the buckets as per the above (see the comments
584                                                   # at the top of this file).  $args should contain cnt, min and max properties.
585                                                   sub _calc_metrics {
586           22                   22            93      my ( $self, $vals, $args ) = @_;
587           22                                125      my $statistical_metrics = {
588                                                         pct_95    => 0,
589                                                         stddev    => 0,
590                                                         median    => 0,
591                                                         cutoff    => undef,
592                                                      };
593                                                   
594                                                      # These cases might happen when there is nothing to get from the event, for
595                                                      # example, processlist sniffing doesn't gather Rows_examined, so $args won't
596                                                      # have {cnt} or other properties.
597           22    100    100                  326      return $statistical_metrics
                           100                        
598                                                         unless defined $vals && %$vals && $args->{cnt};
599                                                   
600                                                      # Return accurate metrics for some cases.
601           19                                 68      my $n_vals = $args->{cnt};
602           19    100    100                  175      if ( $n_vals == 1 || $args->{max} == $args->{min} ) {
                    100                               
603   ***      8            50                   37         my $v      = $args->{max} || 0;
604   ***      8     50                          47         my $bucket = int(6 + ( log($v > 0 ? $v : MIN_BUCK) / log(10)));
605   ***      8     50                          40         $bucket    = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
606                                                         return {
607            8                                 75            pct_95 => $v,
608                                                            stddev => 0,
609                                                            median => $v,
610                                                            cutoff => $n_vals,
611                                                         };
612                                                      }
613                                                      elsif ( $n_vals == 2 ) {
614            3                                 14         foreach my $v ( $args->{min}, $args->{max} ) {
615   ***      6    100     66                   58            my $bucket = int(6 + ( log($v && $v > 0 ? $v : MIN_BUCK) / log(10)));
616   ***      6     50                          33            $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
617                                                         }
618   ***      3            50                   15         my $v      = $args->{max} || 0;
619            3           100                   23         my $mean = (($args->{min} || 0) + $v) / 2;
620                                                         return {
621            3                                 35            pct_95 => $v,
622                                                            stddev => sqrt((($v - $mean) ** 2) *2),
623                                                            median => $mean,
624                                                            cutoff => $n_vals,
625                                                         };
626                                                      }
627                                                   
628                                                      # Determine cutoff point for 95% if there are at least 10 vals.  Cutoff
629                                                      # serves also for the number of vals left in the 95%.  E.g. with 50 vals
630                                                      # the cutoff is 47 which means there are 47 vals: 0..46.  $cutoff is NOT
631                                                      # an array index.
632            8    100                          43      my $cutoff = $n_vals >= 10 ? int ( $n_vals * 0.95 ) : $n_vals;
633            8                                 27      $statistical_metrics->{cutoff} = $cutoff;
634                                                   
635                                                      # Calculate the standard deviation and median of all values.
636            8                                 29      my $total_left = $n_vals;
637            8                                 25      my $top_vals   = $n_vals - $cutoff; # vals > 95th
638            8                                 21      my $sum_excl   = 0;
639            8                                 21      my $sum        = 0;
640            8                                 25      my $sumsq      = 0;
641            8                                 33      my $mid        = int($n_vals / 2);
642            8                                 23      my $median     = 0;
643            8                                 22      my $prev       = NUM_BUCK-1; # Used for getting median when $cutoff is odd
644            8                                 21      my $bucket_95  = 0; # top bucket in 95th
645                                                   
646            8                                 17      MKDEBUG && _d('total vals:', $total_left, 'top vals:', $top_vals, 'mid:', $mid);
647                                                   
648                                                      # In ancient times we kept an array of 1k buckets for each numeric
649                                                      # attrib.  Each such array cost 32_300 bytes of memory (that's not
650                                                      # a typo; yes, it was verified).  But measurements showed that only
651                                                      # 1% of the buckets were used on average, meaning 99% of 32_300 was
652                                                      # wasted.  Now we store only the used buckets in a hashref which we
653                                                      # map to a 1k bucket array for processing, so we don't have to tinker
654                                                      # with the delitcate code below.
655                                                      # http://code.google.com/p/maatkit/issues/detail?id=866
656            8                                 59      my @buckets = map { 0 } (0..NUM_BUCK-1);
            8000                              22605   
657            8                                476      map { $buckets[$_] = $vals->{$_} } keys %$vals;
            1025                               4113   
658            8                                104      $vals = \@buckets;  # repoint vals from given hashref to our array
659                                                   
660                                                      BUCKET:
661            8                                 49      for my $bucket ( reverse 0..(NUM_BUCK-1) ) {
662         8000                              22832         my $val = $vals->[$bucket];
663         8000    100                       30057         next BUCKET unless $val; 
664                                                   
665           27                                 71         $total_left -= $val;
666           27                                 75         $sum_excl   += $val;
667           27    100    100                  180         $bucket_95   = $bucket if !$bucket_95 && $sum_excl > $top_vals;
668                                                   
669           27    100    100                  188         if ( !$median && $total_left <= $mid ) {
670   ***      8     50     66                   80            $median = (($cutoff % 2) || ($val > 1)) ? $buck_vals[$bucket]
671                                                                    : ($buck_vals[$bucket] + $buck_vals[$prev]) / 2;
672                                                         }
673                                                   
674           27                                118         $sum    += $val * $buck_vals[$bucket];
675           27                                100         $sumsq  += $val * ($buck_vals[$bucket]**2);
676           27                                 84         $prev   =  $bucket;
677                                                      }
678                                                   
679            8                                 41      my $var      = $sumsq/$n_vals - ( ($sum/$n_vals) ** 2 );
680            8    100                          46      my $stddev   = $var > 0 ? sqrt($var) : 0;
681   ***      8            50                   70      my $maxstdev = (($args->{max} || 0) - ($args->{min} || 0)) / 2;
                           100                        
682   ***      8     50                          32      $stddev      = $stddev > $maxstdev ? $maxstdev : $stddev;
683                                                   
684            8                                 19      MKDEBUG && _d('sum:', $sum, 'sumsq:', $sumsq, 'stddev:', $stddev,
685                                                         'median:', $median, 'prev bucket:', $prev,
686                                                         'total left:', $total_left, 'sum excl', $sum_excl,
687                                                         'bucket 95:', $bucket_95, $buck_vals[$bucket_95]);
688                                                   
689            8                                 28      $statistical_metrics->{stddev} = $stddev;
690            8                                 30      $statistical_metrics->{pct_95} = $buck_vals[$bucket_95];
691            8                                 25      $statistical_metrics->{median} = $median;
692                                                   
693            8                                182      return $statistical_metrics;
694                                                   }
695                                                   
696                                                   # Return a hashref of the metrics for some attribute, pre-digested.
697                                                   # %args is:
698                                                   #  attrib => the attribute to report on
699                                                   #  where  => the value of the fingerprint for the attrib
700                                                   sub metrics {
701   ***      2                    2      0     13      my ( $self, %args ) = @_;
702            2                                 10      foreach my $arg ( qw(attrib where) ) {
703   ***      4     50                          19         die "I need a $arg argument" unless $args{$arg};
704                                                      }
705            2                                  7      my $attrib = $args{attrib};
706            2                                  7      my $where   = $args{where};
707                                                   
708            2                                  9      my $stats      = $self->results();
709            2                                  8      my $metrics    = $self->stats();
710            2                                 11      my $store      = $stats->{classes}->{$where}->{$attrib};
711            2                                 10      my $global_cnt = $stats->{globals}->{$attrib}->{cnt};
712                                                   
713                                                      return {
714   ***      2    100     66                  109         cnt    => $store->{cnt},
      ***           100     66                        
                           100                        
                           100                        
      ***                   50                        
715                                                         pct    => $global_cnt && $store->{cnt} ? $store->{cnt} / $global_cnt : 0,
716                                                         sum    => $store->{sum},
717                                                         min    => $store->{min},
718                                                         max    => $store->{max},
719                                                         avg    => $store->{sum} && $store->{cnt} ? $store->{sum} / $store->{cnt} : 0,
720                                                         median => $metrics->{classes}->{$where}->{$attrib}->{median} || 0,
721                                                         pct_95 => $metrics->{classes}->{$where}->{$attrib}->{pct_95} || 0,
722                                                         stddev => $metrics->{classes}->{$where}->{$attrib}->{stddev} || 0,
723                                                      };
724                                                   }
725                                                   
726                                                   # Find the top N or top % event keys, in sorted order, optionally including
727                                                   # outliers (ol_...) that are notable for some reason.  %args looks like this:
728                                                   #
729                                                   #  attrib      order-by attribute (usually Query_time)
730                                                   #  orderby     order-by aggregate expression (should be numeric, usually sum)
731                                                   #  total       include events whose summed attribs are <= this number...
732                                                   #  count       ...or this many events, whichever is less...
733                                                   #  ol_attrib   ...or events where the 95th percentile of this attribute...
734                                                   #  ol_limit    ...is greater than this value, AND...
735                                                   #  ol_freq     ...the event occurred at least this many times.
736                                                   # The return value is a list of arrayrefs.  Each arrayref is the event key and
737                                                   # an explanation of why it was included (top|outlier).
738                                                   sub top_events {
739   ***      3                    3      0     32      my ( $self, %args ) = @_;
740            3                                 16      my $classes = $self->{result_classes};
741           15                                 95      my @sorted = reverse sort { # Sorted list of $groupby values
742           16                                 77         $classes->{$a}->{$args{attrib}}->{$args{orderby}}
743                                                            <=> $classes->{$b}->{$args{attrib}}->{$args{orderby}}
744                                                         } grep {
745                                                            # Defensive programming
746            3                                 16            defined $classes->{$_}->{$args{attrib}}->{$args{orderby}}
747                                                         } keys %$classes;
748            3                                 21      my @chosen;
749            3                                 11      my ($total, $count) = (0, 0);
750            3                                 12      foreach my $groupby ( @sorted ) {
751                                                         # Events that fall into the top criterion for some reason
752           15    100    100                  252         if ( 
      ***           100     66                        
                           100                        
                           100                        
                           100                        
753                                                            (!$args{total} || $total < $args{total} )
754                                                            && ( !$args{count} || $count < $args{count} )
755                                                         ) {
756            6                                 26            push @chosen, [$groupby, 'top'];
757                                                         }
758                                                   
759                                                         # Events that are notable outliers
760                                                         elsif ( $args{ol_attrib} && (!$args{ol_freq}
761                                                            || $classes->{$groupby}->{$args{ol_attrib}}->{cnt} >= $args{ol_freq})
762                                                         ) {
763            5                                 26            my $stats = $self->{class_metrics}->{$groupby}->{$args{ol_attrib}};
764   ***      5    100     50                   40            if ( ($stats->{pct_95} || 0) >= $args{ol_limit} ) {
765            3                                 14               push @chosen, [$groupby, 'outlier'];
766                                                            }
767                                                         }
768                                                   
769           15                                 74         $total += $classes->{$groupby}->{$args{attrib}}->{$args{orderby}};
770           15                                 45         $count++;
771                                                      }
772            3                                 32      return @chosen;
773                                                   }
774                                                   
775                                                   # Adds all new attributes in $event to $self->{attributes}.
776                                                   sub add_new_attributes {
777   ***    240                  240      0    910      my ( $self, $event ) = @_;
778   ***    240     50                         977      return unless $event;
779                                                   
780           81                                214      map {
781         3788    100    100                34629         my $attrib = $_;
782           81                                362         $self->{attributes}->{$attrib}  = [$attrib];
783           81                                277         $self->{alt_attribs}->{$attrib} = make_alt_attrib($attrib);
784           81                                202         push @{$self->{all_attribs}}, $attrib;
              81                                332   
785           81                                255         MKDEBUG && _d('Added new attribute:', $attrib);
786                                                      }
787                                                      grep {
788          240                               1577         $_ ne $self->{groupby}
789                                                         && !exists $self->{attributes}->{$_}
790                                                         && !exists $self->{ignore_attribs}->{$_}
791                                                      }
792                                                      keys %$event;
793                                                   
794          240                               1185      return;
795                                                   }
796                                                   
797                                                   # Returns an arrayref of all the attributes that were either given
798                                                   # explicitly to new() or that were auto-detected.
799                                                   sub get_attributes {
800   ***      1                    1      0      4      my ( $self ) = @_;
801            1                                 15      return $self->{all_attribs};
802                                                   }
803                                                   
804                                                   sub events_processed {
805   ***      1                    1      0      4      my ( $self ) = @_;
806            1                                  7      return $self->{n_events};
807                                                   }
808                                                   
809                                                   sub make_alt_attrib {
810   ***    123                  123      0    483      my ( @attribs ) = @_;
811                                                   
812          123                                383      my $attrib = shift @attribs;  # Primary attribute.
813          123    100            17          1118      return sub {} unless @attribs;  # No alternates.
              17                                 47   
814                                                   
815            1                                  3      my @lines;
816            1                                  4      push @lines, 'sub { my ( $event ) = @_; my $alt_attrib;';
817            1                                  8      push @lines, map  {
818            1                                  4            "\$alt_attrib = '$_' if !defined \$alt_attrib "
819                                                            . "&& exists \$event->{'$_'};"
820                                                         } @attribs;
821            1                                  3      push @lines, 'return $alt_attrib; }';
822            1                                  3      MKDEBUG && _d('alt attrib sub for', $attrib, ':', @lines);
823            1                                 89      my $sub = eval join("\n", @lines);
824   ***      1     50                           5      die if $EVAL_ERROR;
825            1                                 18      return $sub;
826                                                   }
827                                                   
828                                                   # Merge/add the given arrayref of EventAggregator objects.
829                                                   # Returns a new EventAggregator obj.
830                                                   sub merge {
831   ***      1                    1      0      6      my ( @ea_objs ) = @_;
832            1                                  3      MKDEBUG && _d('Merging', scalar @ea_objs, 'ea');
833   ***      1     50                           5      return unless scalar @ea_objs;
834                                                   
835                                                      # If all the ea don't have the same groupby and worst then adding
836                                                      # them will produce a nonsensical result.  (Maybe not if worst
837                                                      # differs but certainly if groupby differs).  And while checking this...
838            1                                  8      my $ea1   = shift @ea_objs;
839            1                                  5      my $r1    = $ea1->results;
840            1                                  4      my $worst = $ea1->{worst};  # for merging, finding worst sample
841                                                   
842                                                      # ...get all attributes and their types to properly initialize the
843                                                      # returned ea obj;
844            1                                  4      my %attrib_types = %{ $ea1->attributes() };
               1                                  5   
845                                                   
846            1                                 11      foreach my $ea ( @ea_objs ) {
847   ***      1     50                           9         die "EventAggregator objects have different groupby: "
848                                                            . "$ea1->{groupby} and $ea->{groupby}"
849                                                            unless $ea1->{groupby} eq $ea->{groupby};
850   ***      1     50                           6         die "EventAggregator objects have different worst: "
851                                                            . "$ea1->{worst} and $ea->{worst}"
852                                                            unless $ea1->{worst} eq $ea->{worst};
853                                                         
854            1                                  5         my $attrib_types = $ea->attributes();
855            6    100                          41         map {
856            1                                  6            $attrib_types{$_} = $attrib_types->{$_}
857                                                               unless exists $attrib_types{$_};
858                                                         } keys %$attrib_types;
859                                                      }
860                                                   
861                                                      # First, deep copy the first ea obj.  Do not shallow copy, do deep copy
862                                                      # so the returned ea is truly its own obj and does not point to data
863                                                      # structs in one of the given ea.
864            1                                  7      my $r_merged = {
865                                                         classes => {},
866                                                         globals => _deep_copy_attribs($r1->{globals}),
867                                                         samples => {},
868                                                      };
869            1                                  6      map {
870            1                                  5         $r_merged->{classes}->{$_}
871                                                            = _deep_copy_attribs($r1->{classes}->{$_});
872                                                   
873            1                                 16         @{$r_merged->{samples}->{$_}}{keys %{$r1->{samples}->{$_}}}
               1                                  6   
               1                                  7   
874            1                                 11            = values %{$r1->{samples}->{$_}};
875            1                                  4      } keys %{$r1->{classes}};
876                                                   
877                                                      # Then, merge/add the other eas.  r1* is the eventual return val.
878                                                      # r2* is the current ea being merged/added into r1*.
879            1                                 10      for my $i ( 0..$#ea_objs ) {
880            1                                  3         MKDEBUG && _d('Merging ea obj', ($i + 1));
881            1                                  5         my $r2 = $ea_objs[$i]->results;
882                                                   
883                                                         # Descend into each class (e.g. unique query/fingerprint), each
884                                                         # attribute (e.g. Query_time, etc.), and then each attribute
885                                                         # value (e.g. min, max, etc.).  If either a class or attrib is
886                                                         # missing in one of the results, deep copy the extant class/attrib;
887                                                         # if both exist, add/merge the results.
888            1                                  4         eval {
889            1                                  6            CLASS:
890            1                                  3            foreach my $class ( keys %{$r2->{classes}} ) {
891            1                                  4               my $r1_class = $r_merged->{classes}->{$class};
892            1                                  5               my $r2_class = $r2->{classes}->{$class};
893                                                   
894   ***      1     50     33                   22               if ( $r1_class && $r2_class ) {
      ***             0                               
895                                                                  # Class exists in both results.  Add/merge all their attributes.
896                                                                  CLASS_ATTRIB:
897            1                                  6                  foreach my $attrib ( keys %$r2_class ) {
898            6                                 14                     MKDEBUG && _d('merge', $attrib);
899   ***      6    100     66                   61                     if ( $r1_class->{$attrib} && $r2_class->{$attrib} ) {
      ***            50                               
900            5                                 31                        _add_attrib_vals($r1_class->{$attrib}, $r2_class->{$attrib});
901                                                                     }
902                                                                     elsif ( !$r1_class->{$attrib} ) {
903            1                                  2                     MKDEBUG && _d('copy', $attrib);
904            1                                  5                        $r1_class->{$attrib} =
905                                                                           _deep_copy_attrib_vals($r2_class->{$attrib})
906                                                                     }
907                                                                  }
908                                                               }
909                                                               elsif ( !$r1_class ) {
910                                                                  # Class is missing in r1; deep copy it from r2.
911   ***      0                                  0                  MKDEBUG && _d('copy class');
912   ***      0                                  0                  $r_merged->{classes}->{$class} = _deep_copy_attribs($r2_class);
913                                                               }
914                                                   
915                                                               # Update the worst sample if either the r2 sample is worst than
916                                                               # the r1 or there's no such sample in r1.
917            1                                  4               my $new_worst_sample;
918   ***      1     50     33                   14               if ( $r_merged->{samples}->{$class} && $r2->{samples}->{$class} ) {
      ***             0                               
919   ***      1     50                          11                  if (   $r2->{samples}->{$class}->{$worst}
920                                                                       > $r_merged->{samples}->{$class}->{$worst} ) {
921            1                                  5                     $new_worst_sample = $r2->{samples}->{$class}
922                                                                  }
923                                                               }
924                                                               elsif ( !$r_merged->{samples}->{$class} ) {
925   ***      0                                  0                  $new_worst_sample = $r2->{samples}->{$class};
926                                                               }
927                                                               # Events don't have references to other data structs
928                                                               # so we don't have to worry about doing a deep copy.
929   ***      1     50                           5               if ( $new_worst_sample ) {
930            1                                  2                  MKDEBUG && _d('New worst sample:', $worst, '=',
931                                                                     $new_worst_sample->{$worst}, 'item:', substr($class, 0, 100));
932            1                                  3                  my %new_sample;
933            1                                 18                  @new_sample{keys %$new_worst_sample}
934                                                                     = values %$new_worst_sample;
935            1                                 11                  $r_merged->{samples}->{$class} = \%new_sample;
936                                                               }
937                                                            }
938                                                         };
939   ***      1     50                           6         if ( $EVAL_ERROR ) {
940   ***      0                                  0            warn "Error merging class/sample: $EVAL_ERROR";
941                                                         }
942                                                   
943                                                         # Same as above but for the global attribs/vals.
944            1                                  3         eval {
945            1                                  3            GLOBAL_ATTRIB:
946                                                            MKDEBUG && _d('Merging global attributes');
947            1                                  3            foreach my $attrib ( keys %{$r2->{globals}} ) {
               1                                  7   
948            6                                 26               my $r1_global = $r_merged->{globals}->{$attrib};
949            6                                 24               my $r2_global = $r2->{globals}->{$attrib};
950                                                   
951   ***      6    100     66                   56               if ( $r1_global && $r2_global ) {
      ***            50                               
952                                                                  # Global attrib exists in both results.  Add/merge all its values.
953            5                                 15                  MKDEBUG && _d('merge', $attrib);
954            5                                 20                  _add_attrib_vals($r1_global, $r2_global);
955                                                               }
956                                                               elsif ( !$r1_global ) {
957                                                                  # Global attrib is missing in r1; deep cpoy it from r2 global.
958            1                                  3                  MKDEBUG && _d('copy', $attrib);
959            1                                  5                  $r_merged->{globals}->{$attrib}
960                                                                     = _deep_copy_attrib_vals($r2_global);
961                                                               }
962                                                            }
963                                                         };
964   ***      1     50                           8         if ( $EVAL_ERROR ) {
965   ***      0                                  0            warn "Error merging globals: $EVAL_ERROR";
966                                                         }
967                                                      }
968                                                   
969                                                      # Create a new EventAggregator obj, initialize it with the summed results,
970                                                      # and return it.
971            7                                 39      my $ea_merged = new EventAggregator(
972                                                         groupby    => $ea1->{groupby},
973                                                         worst      => $ea1->{worst},
974            1                                  8         attributes => { map { $_=>[$_] } keys %attrib_types },
975                                                      );
976            1                                  9      $ea_merged->set_results($r_merged);
977            1                                  6      $ea_merged->set_attribute_types(\%attrib_types);
978            1                                  7      return $ea_merged;
979                                                   }
980                                                   
981                                                   # Adds/merges vals2 attrib values into vals1.
982                                                   sub _add_attrib_vals {
983           10                   10            38      my ( $vals1, $vals2 ) = @_;
984                                                   
985                                                      # Assuming both sets of values are the same attribute (that's the caller
986                                                      # responsibility), each should have the same values (min, max, unq, etc.)
987           10                                 60      foreach my $val ( keys %$vals1 ) {
988           43                                147         my $val1 = $vals1->{$val};
989           43                                148         my $val2 = $vals2->{$val};
990                                                   
991   ***     43    100     66                  420         if ( (!ref $val1) && (!ref $val2) ) {
      ***            50     33                        
      ***            50     33                        
992                                                            # min, max, cnt, sum should never be undef.
993   ***     36     50     33                  306            die "undefined $val value" unless defined $val1 && defined $val2;
994                                                   
995                                                            # Value is scalar but return unless it's numeric.
996                                                            # Only numeric values have "sum".
997           36    100                         156            my $is_num = exists $vals1->{sum} ? 1 : 0;
998           36    100                         167            if ( $val eq 'max' ) {
                    100                               
999           10    100                          34               if ( $is_num ) {
1000  ***      6     50                          37                  $vals1->{$val} = $val1 > $val2  ? $val1 : $val2;
1001                                                              }
1002                                                              else {
1003           4    100                          25                  $vals1->{$val} = $val1 gt $val2 ? $val1 : $val2;
1004                                                              }
1005                                                           }
1006                                                           elsif ( $val eq 'min' ) {
1007          10    100                          33               if ( $is_num ) {
1008  ***      6     50                          39                  $vals1->{$val} = $val1 < $val2  ? $val1 : $val2;
1009                                                              }
1010                                                              else {
1011           4    100                          29                  $vals1->{$val} = $val1 lt $val2 ? $val1 : $val2;
1012                                                              }
1013                                                           }
1014                                                           else {
1015          16                                 77               $vals1->{$val} += $val2;
1016                                                           }
1017                                                        }
1018                                                        elsif ( (ref $val1 eq 'ARRAY') && (ref $val2 eq 'ARRAY') ) {
1019                                                           # Value is an arrayref, so it should be 1k buckets.
1020                                                           # Should never be empty.
1021  ***      0      0      0                    0            die "Empty $val arrayref" unless @$val1 && @$val2;
1022  ***      0                                  0            my $n_buckets = (scalar @$val1) - 1;
1023  ***      0                                  0            for my $i ( 0..$n_buckets ) {
1024  ***      0                                  0               $vals1->{$val}->[$i] += $val2->[$i];
1025                                                           }
1026                                                        }
1027                                                        elsif ( (ref $val1 eq 'HASH')  && (ref $val2 eq 'HASH')  ) {
1028                                                           # Value is a hashref, probably for unq string occurences.
1029                                                           # Should never be empty.
1030  ***      7     50     33                   78            die "Empty $val hashref" unless %$val1 and %$val2;
1031           7                                 39            map { $vals1->{$val}->{$_} += $val2->{$_} } keys %$val2;
               7                                 48   
1032                                                        }
1033                                                        else {
1034                                                           # This shouldn't happen.
1035  ***      0                                  0            MKDEBUG && _d('vals1:', Dumper($vals1));
1036  ***      0                                  0            MKDEBUG && _d('vals2:', Dumper($vals2));
1037  ***      0                                  0            die "$val type mismatch";
1038                                                        }
1039                                                     }
1040                                                  
1041          10                                 47      return;
1042                                                  }
1043                                                  
1044                                                  # These _deep_copy_* subs only go 1 level deep because, so far,
1045                                                  # no ea data struct has a ref any deeper.
1046                                                  sub _deep_copy_attribs {
1047           2                    2             9      my ( $attribs ) = @_;
1048           2                                  7      my $copy = {};
1049           2                                 11      foreach my $attrib ( keys %$attribs ) {
1050          12                                 55         $copy->{$attrib} = _deep_copy_attrib_vals($attribs->{$attrib});
1051                                                     }
1052           2                                 13      return $copy;
1053                                                  }
1054                                                  
1055                                                  sub _deep_copy_attrib_vals {
1056          14                   14            56      my ( $vals ) = @_;
1057          14                                 37      my $copy;
1058  ***     14     50                          61      if ( ref $vals eq 'HASH' ) {
1059          14                                 56         $copy = {};
1060          14                                 77         foreach my $val ( keys %$vals ) {
1061  ***     63     50                         247            if ( my $ref_type = ref $val ) {
1062  ***      0      0                           0               if ( $ref_type eq 'ARRAY' ) {
      ***             0                               
1063  ***      0                                  0                  my $n_elems = (scalar @$val) - 1;
1064  ***      0                                  0                  $copy->{$val} = [ map { undef } ( 0..$n_elems ) ];
      ***      0                                  0   
1065  ***      0                                  0                  for my $i ( 0..$n_elems ) {
1066  ***      0                                  0                     $copy->{$val}->[$i] = $vals->{$val}->[$i];
1067                                                                 }
1068                                                              }
1069                                                              elsif ( $ref_type eq 'HASH' ) {
1070  ***      0                                  0                  $copy->{$val} = {};
1071  ***      0                                  0                  map { $copy->{$val}->{$_} += $vals->{$val}->{$_} }
      ***      0                                  0   
1072  ***      0                                  0                     keys %{$vals->{$val}}
1073                                                              }
1074                                                              else {
1075  ***      0                                  0                  die "I don't know how to deep copy a $ref_type reference";
1076                                                              }
1077                                                           }
1078                                                           else {
1079          63                                301               $copy->{$val} = $vals->{$val};
1080                                                           }
1081                                                        }
1082                                                     }
1083                                                     else {
1084  ***      0                                  0         $copy = $vals;
1085                                                     }
1086          14                                 77      return $copy;
1087                                                  }
1088                                                  
1089                                                  sub _d {
1090  ***      0                    0                    my ($package, undef, $line) = caller 0;
1091  ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
1092  ***      0                                              map { defined $_ ? $_ : 'undef' }
1093                                                          @_;
1094  ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
1095                                                  }
1096                                                  
1097                                                  1;
1098                                                  
1099                                                  # ###########################################################################
1100                                                  # End EventAggregator package
1101                                                  # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
72    ***     50      0     42   unless $args{$arg}
91           100     20      1   unless $args{'type_for'}
104          100      7     14   scalar keys %$attributes == 0 ? :
138          100      2   1706   unless defined $group_by
144          100    438   1268   if $$self{'unrolled_loops'}
149          100   1265      3   if ($$self{'n_events'} <= $$self{'unroll_limit'}) { }
151          100    240   1025   if $$self{'detect_attribs'}
161          100     18   4600   if (not exists $$event{$attrib})
165          100     17      1   unless $alt_attrib
170          100      4   4597   ref $group_by ? :
175          100    113   4490   if (not $handler)
184   ***     50      0   4603   unless $handler
216   ***     50      0      3   ref $group_by ? :
233   ***     50      0      3   if (ref $group_by)
244   ***     50      0      3   if $EVAL_ERROR
334   ***     50      0    113   unless defined $attrib
337   ***     50      0    113   if (ref $val eq 'ARRAY')
341   ***     50      0    113   unless defined $val
345          100     16     31   $val =~ /^(?:Yes|No)$/ ? :
             100     52     47   $val =~ /^(?:\d+|$float_re)$/o ? :
             100     14     99   $self->type_for($attrib) ? :
353          100     82     31   $type =~ /num|bool/ ? :
             100     47     66   $type =~ /bool|string/ ? :
             100     66     47   $type eq 'num' ? :
             100     16     97   $type eq 'bool' ? :
368          100     16     97   if ($args{'trf'})
374   ***     50    226      0   if ($args{'min'})
375          100    132     94   $type eq 'num' ? :
381   ***     50    226      0   if ($args{'max'})
382          100    132     94   $type eq 'num' ? :
388          100    164     62   if ($args{'sum'})
391   ***     50    226      0   if ($args{'cnt'})
394          100    132     94   if ($args{'all'})
404          100     47     66   if ($args{'unq'})
407          100     13    100   if ($args{'wor'})
408   ***     50     13      0   $type eq 'num' ? :
418          100     14     99   if ($attrib eq 'Query_time')
428          100      1    112   if ($args{'all'} and $type eq 'num' and $$self{'attrib_limit'})
444   ***     50      0    113   $is_array ? :
      ***     50      0    113   $is_array ? :
457   ***     50      0    113   $is_array ? :
      ***     50      0    113   $is_array ? :
470   ***     50      0    113   if $EVAL_ERROR
482          100   1484   6471   if $val < 1e-06
484          100      1   6470   $idx > 999 ? :
497          100      2   1005   if $bucket == 0
498   ***     50      0   1005   if $bucket < 0 or $bucket > 999
512   ***     50      0      1   if @buck_tens
553          100      3      1   if (exists $$globals{$attrib}{'all'})
562          100      9      2   if (exists $$classes{$class}{$attrib}{'all'})
597          100      3     19   unless defined $vals and %$vals and $$args{'cnt'}
602          100      8     11   if ($n_vals == 1 or $$args{'max'} == $$args{'min'}) { }
             100      3      8   elsif ($n_vals == 2) { }
604   ***     50      8      0   $v > 0 ? :
605   ***     50      0      8   $bucket < 0 ? :
      ***     50      0      8   $bucket > 7 ? :
615          100      5      1   $v && $v > 0 ? :
616   ***     50      0      6   $bucket < 0 ? :
      ***     50      0      6   $bucket > 7 ? :
632          100      5      3   $n_vals >= 10 ? :
663          100   7973     27   unless $val
667          100      8     19   if not $bucket_95 and $sum_excl > $top_vals
669          100      8     19   if (not $median and $total_left <= $mid)
670   ***     50      8      0   $cutoff % 2 || $val > 1 ? :
680          100      6      2   $var > 0 ? :
682   ***     50      0      8   $stddev > $maxstdev ? :
703   ***     50      0      4   unless $args{$arg}
714          100      1      1   $global_cnt && $$store{'cnt'} ? :
             100      1      1   $$store{'sum'} && $$store{'cnt'} ? :
752          100      6      9   if (!$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}) { }
             100      5      4   elsif ($args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}) { }
764          100      3      2   if (($$stats{'pct_95'} || 0) >= $args{'ol_limit'})
778   ***     50      0    240   unless $event
781          100     85   3703   if $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}
813          100    122      1   unless @attribs
824   ***     50      0      1   if $EVAL_ERROR
833   ***     50      0      1   unless scalar @ea_objs
847   ***     50      0      1   unless $$ea1{'groupby'} eq $$ea{'groupby'}
850   ***     50      0      1   unless $$ea1{'worst'} eq $$ea{'worst'}
855          100      1      5   unless exists $attrib_types{$_}
894   ***     50      1      0   if ($r1_class and $r2_class) { }
      ***      0      0      0   elsif (not $r1_class) { }
899          100      5      1   if ($$r1_class{$attrib} and $$r2_class{$attrib}) { }
      ***     50      1      0   elsif (not $$r1_class{$attrib}) { }
918   ***     50      1      0   if ($$r_merged{'samples'}{$class} and $$r2{'samples'}{$class}) { }
      ***      0      0      0   elsif (not $$r_merged{'samples'}{$class}) { }
919   ***     50      1      0   if ($$r2{'samples'}{$class}{$worst} > $$r_merged{'samples'}{$class}{$worst})
929   ***     50      1      0   if ($new_worst_sample)
939   ***     50      0      1   if ($EVAL_ERROR)
951          100      5      1   if ($r1_global and $r2_global) { }
      ***     50      1      0   elsif (not $r1_global) { }
964   ***     50      0      1   if ($EVAL_ERROR)
991          100     36      7   if (not ref $val1 and not ref $val2) { }
      ***     50      0      7   elsif (ref $val1 eq 'ARRAY' and ref $val2 eq 'ARRAY') { }
      ***     50      7      0   elsif (ref $val1 eq 'HASH' and ref $val2 eq 'HASH') { }
993   ***     50      0     36   unless defined $val1 and defined $val2
997          100     24     12   exists $$vals1{'sum'} ? :
998          100     10     26   if ($val eq 'max') { }
             100     10     16   elsif ($val eq 'min') { }
999          100      6      4   if ($is_num) { }
1000  ***     50      0      6   $val1 > $val2 ? :
1003         100      2      2   $val1 gt $val2 ? :
1007         100      6      4   if ($is_num) { }
1008  ***     50      6      0   $val1 < $val2 ? :
1011         100      2      2   $val1 lt $val2 ? :
1021  ***      0      0      0   unless @$val1 and @$val2
1030  ***     50      0      7   unless %$val1 and %$val2
1058  ***     50     14      0   if (ref $vals eq 'HASH') { }
1061  ***     50      0     63   if (my $ref_type = ref $val) { }
1062  ***      0      0      0   if ($ref_type eq 'ARRAY') { }
      ***      0      0      0   elsif ($ref_type eq 'HASH') { }
1091  ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
428   ***     66     47      0     66   $args{'all'} and $type eq 'num'
             100     47     65      1   $args{'all'} and $type eq 'num' and $$self{'attrib_limit'}
597          100      1      1     20   defined $vals and %$vals
             100      2      1     19   defined $vals and %$vals and $$args{'cnt'}
615   ***     66      1      0      5   $v && $v > 0
667          100     15      4      8   not $bucket_95 and $sum_excl > $top_vals
669          100      7     12      8   not $median and $total_left <= $mid
714   ***     66      1      0      1   $global_cnt && $$store{'cnt'}
      ***     66      1      0      1   $$store{'sum'} && $$store{'cnt'}
752          100      6      3      6   !$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}
             100      3      1      5   $args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}
781          100    240   3463     85   $_ ne $$self{'groupby'} and not exists $$self{'attributes'}{$_}
894   ***     33      0      0      1   $r1_class and $r2_class
899   ***     66      1      0      5   $$r1_class{$attrib} and $$r2_class{$attrib}
918   ***     33      0      0      1   $$r_merged{'samples'}{$class} and $$r2{'samples'}{$class}
951   ***     66      1      0      5   $r1_global and $r2_global
991   ***     66      7      0     36   not ref $val1 and not ref $val2
      ***     33      7      0      0   ref $val1 eq 'ARRAY' and ref $val2 eq 'ARRAY'
      ***     33      0      0      7   ref $val1 eq 'HASH' and ref $val2 eq 'HASH'
993   ***     33      0      0     36   defined $val1 and defined $val2
1021  ***      0      0      0      0   @$val1 and @$val2
1030  ***     33      0      0      7   %$val1 and %$val2

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
37    ***     50      0      1   $ENV{'MKDEBUG'} || 0
74           100     14      7   $args{'attributes'} || {}
104          100      2     19   $args{'unroll_limit'} || 1000
171          100   4433    170   $$self{'result_classes'}{$val}{$attrib} ||= {}
172          100   4490    113   $$self{'result_globals'}{$attrib} ||= {}
185          100   4571     32   $$samples{$val} ||= $event
603   ***     50      8      0   $$args{'max'} || 0
618   ***     50      3      0   $$args{'max'} || 0
619          100      2      1   $$args{'min'} || 0
681   ***     50      8      0   $$args{'max'} || 0
             100      6      2   $$args{'min'} || 0
714          100      1      1   $$metrics{'classes'}{$where}{$attrib}{'median'} || 0
             100      1      1   $$metrics{'classes'}{$where}{$attrib}{'pct_95'} || 0
      ***     50      0      2   $$metrics{'classes'}{$where}{$attrib}{'stddev'} || 0
764   ***     50      5      0   $$stats{'pct_95'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
498   ***     33      0      0   1005   $bucket < 0 or $bucket > 999
602          100      4      4     11   $n_vals == 1 or $$args{'max'} == $$args{'min'}
670   ***     66      4      4      0   $cutoff % 2 || $val > 1
752          100      5      4      6   !$args{'total'} || $total < $args{'total'}
      ***     66      0      6      3   !$args{'count'} || $count < $args{'count'}
             100      3      2      1   !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}


Covered Subroutines
-------------------

Subroutine                    Count Pod Location                                               
----------------------------- ----- --- -------------------------------------------------------
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:22  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:23  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:24  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:25  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:26  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:37  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:38  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:39  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:40  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:41  
BEGIN                             1     /home/daniel/dev/maatkit/common/EventAggregator.pm:42  
__ANON__                         17     /home/daniel/dev/maatkit/common/EventAggregator.pm:813 
_add_attrib_vals                 10     /home/daniel/dev/maatkit/common/EventAggregator.pm:983 
_calc_metrics                    22     /home/daniel/dev/maatkit/common/EventAggregator.pm:586 
_deep_copy_attrib_vals           14     /home/daniel/dev/maatkit/common/EventAggregator.pm:1056
_deep_copy_attribs                2     /home/daniel/dev/maatkit/common/EventAggregator.pm:1047
_make_unrolled_loops              3     /home/daniel/dev/maatkit/common/EventAggregator.pm:202 
add_new_attributes              240   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:777 
aggregate                      1708   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:135 
attributes                        3   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:279 
bucket_idx                     7955   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:481 
bucket_value                   1007   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:496 
buckets_of                        1   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:512 
calculate_statistical_metrics     2   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:546 
events_processed                  1   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:805 
get_attributes                    1   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:800 
make_alt_attrib                 123   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:810 
make_handler                    113   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:333 
merge                             1   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:831 
metrics                           2   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:701 
new                              21   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:70  
reset_aggregated_data             1   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:116 
results                          23   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:252 
set_attribute_types               1   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:284 
set_results                       1   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:261 
stats                             2   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:269 
top_events                        3   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:739 
type_for                        130   0 /home/daniel/dev/maatkit/common/EventAggregator.pm:292 

Uncovered Subroutines
---------------------

Subroutine                    Count Pod Location                                               
----------------------------- ----- --- -------------------------------------------------------
_d                                0     /home/daniel/dev/maatkit/common/EventAggregator.pm:1090


EventAggregator.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            31      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  5   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  4   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1            10   use Test::More tests => 74;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use QueryRewriter;
               1                                  3   
               1                                 10   
15             1                    1            11   use EventAggregator;
               1                                  3   
               1                                 24   
16             1                    1            16   use QueryParser;
               1                                  3   
               1                                 11   
17             1                    1            11   use SlowLogParser;
               1                                  2   
               1                                 12   
18             1                    1            10   use BinaryLogParser;
               1                                  3   
               1                                 10   
19             1                    1            10   use MaatkitTest;
               1                                  6   
               1                                 41   
20                                                    
21             1                                  9   my $qr = new QueryRewriter();
22             1                                 30   my $qp = new QueryParser();
23             1                                 22   my $p  = new SlowLogParser();
24             1                                 26   my $bp = new BinaryLogParser();
25             1                                 25   my ( $result, $events, $ea, $expected );
26                                                    
27             1                                 18   $ea = new EventAggregator(
28                                                       groupby    => 'fingerprint',
29                                                       worst      => 'Query_time',
30                                                       attributes => {
31                                                          Query_time => [qw(Query_time)],
32                                                          user       => [qw(user)],
33                                                          ts         => [qw(ts)],
34                                                          Rows_sent  => [qw(Rows_sent)],
35                                                       },
36                                                    );
37                                                    
38             1                                 10   isa_ok( $ea, 'EventAggregator' );
39                                                    
40             1                                 33   $events = [
41                                                       {  cmd           => 'Query',
42                                                          user          => 'root',
43                                                          host          => 'localhost',
44                                                          ip            => '',
45                                                          arg           => "SELECT id FROM users WHERE name='foo'",
46                                                          Query_time    => '0.000652',
47                                                          Lock_time     => '0.000109',
48                                                          Rows_sent     => 1,
49                                                          Rows_examined => 1,
50                                                          pos_in_log    => 0,
51                                                       },
52                                                       {  ts   => '071015 21:43:52',
53                                                          cmd  => 'Query',
54                                                          user => 'root',
55                                                          host => 'localhost',
56                                                          ip   => '',
57                                                          arg =>
58                                                             "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
59                                                          Query_time    => '0.001943',
60                                                          Lock_time     => '0.000145',
61                                                          Rows_sent     => 0,
62                                                          Rows_examined => 0,
63                                                          pos_in_log    => 1,
64                                                       },
65                                                       {  ts            => '071015 21:43:52',
66                                                          cmd           => 'Query',
67                                                          user          => 'bob',
68                                                          host          => 'localhost',
69                                                          ip            => '',
70                                                          arg           => "SELECT id FROM users WHERE name='bar'",
71                                                          Query_time    => '0.000682',
72                                                          Lock_time     => '0.000201',
73                                                          Rows_sent     => 1,
74                                                          Rows_examined => 2,
75                                                          pos_in_log    => 5,
76                                                       }
77                                                    ];
78                                                    
79             1                                 45   $result = {
80                                                       'select id from users where name=?' => {
81                                                          Query_time => {
82                                                             min => '0.000652',
83                                                             max => '0.000682',
84                                                             all => {
85                                                                133 => 1,
86                                                                134 => 1,
87                                                             },
88                                                             sum => '0.001334',
89                                                             cnt => 2,
90                                                          },
91                                                          user => {
92                                                             unq => {
93                                                                bob  => 1,
94                                                                root => 1
95                                                             },
96                                                             min => 'bob',
97                                                             max => 'root',
98                                                             cnt => 2,
99                                                          },
100                                                         ts => {
101                                                            min => '071015 21:43:52',
102                                                            max => '071015 21:43:52',
103                                                            unq => { '071015 21:43:52' => 1, },
104                                                            cnt => 1,
105                                                         },
106                                                         Rows_sent => {
107                                                            min => 1,
108                                                            max => 1,
109                                                            all => {
110                                                               284 => 2,
111                                                            },
112                                                            sum => 2,
113                                                            cnt => 2,
114                                                         }
115                                                      },
116                                                      'insert ignore into articles (id, body,)values(?+)' => {
117                                                         Query_time => {
118                                                            min => '0.001943',
119                                                            max => '0.001943',
120                                                            all => {
121                                                               156 => 1,
122                                                            },
123                                                            sum => '0.001943',
124                                                            cnt => 1,
125                                                         },
126                                                         user => {
127                                                            unq => { root => 1 },
128                                                            min => 'root',
129                                                            max => 'root',
130                                                            cnt => 1,
131                                                         },
132                                                         ts => {
133                                                            min => '071015 21:43:52',
134                                                            max => '071015 21:43:52',
135                                                            unq => { '071015 21:43:52' => 1, },
136                                                            cnt => 1,
137                                                         },
138                                                         Rows_sent => {
139                                                            min => 0,
140                                                            max => 0,
141                                                            all => {
142                                                               0 => 1,
143                                                            },
144                                                            sum => 0,
145                                                            cnt => 1,
146                                                         }
147                                                      }
148                                                   };
149                                                   
150            1                                  5   foreach my $event (@$events) {
151            3                                 21      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
152            3                                271      $ea->aggregate($event);
153                                                   }
154                                                   
155            1                                 12   is_deeply( $ea->results->{classes},
156                                                      $result, 'Simple fingerprint aggregation' );
157                                                   
158            1                                 14   is_deeply(
159                                                      $ea->results->{samples},
160                                                      {
161                                                         'select id from users where name=?' => {
162                                                            ts            => '071015 21:43:52',
163                                                            cmd           => 'Query',
164                                                            user          => 'bob',
165                                                            host          => 'localhost',
166                                                            ip            => '',
167                                                            arg           => "SELECT id FROM users WHERE name='bar'",
168                                                            Query_time    => '0.000682',
169                                                            Lock_time     => '0.000201',
170                                                            Rows_sent     => 1,
171                                                            Rows_examined => 2,
172                                                            pos_in_log    => 5,
173                                                            fingerprint   => 'select id from users where name=?',
174                                                         },
175                                                         'insert ignore into articles (id, body,)values(?+)' => {
176                                                            ts   => '071015 21:43:52',
177                                                            cmd  => 'Query',
178                                                            user => 'root',
179                                                            host => 'localhost',
180                                                            ip   => '',
181                                                            arg =>
182                                                               "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
183                                                            Query_time    => '0.001943',
184                                                            Lock_time     => '0.000145',
185                                                            Rows_sent     => 0,
186                                                            Rows_examined => 0,
187                                                            pos_in_log    => 1,
188                                                            fingerprint   => 'insert ignore into articles (id, body,)values(?+)',
189                                                         },
190                                                      },
191                                                      'Worst-in-class samples',
192                                                   );
193                                                   
194            1                                 15   is_deeply(
195                                                      $ea->attributes,
196                                                      {  Query_time => 'num',
197                                                         user       => 'string',
198                                                         ts         => 'string',
199                                                         Rows_sent  => 'num',
200                                                      },
201                                                      'Found attribute types',
202                                                   );
203                                                   
204                                                   # Test with a nonexistent 'worst' attribute.
205            1                                 17   $ea = new EventAggregator(
206                                                      groupby    => 'fingerprint',
207                                                      worst      => 'nonexistent',
208                                                      attributes => {
209                                                         Query_time => [qw(Query_time)],
210                                                         user       => [qw(user)],
211                                                         ts         => [qw(ts)],
212                                                         Rows_sent  => [qw(Rows_sent)],
213                                                      },
214                                                   );
215                                                   
216            1                                176   foreach my $event (@$events) {
217            3                                 19      $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
218            3                                287      $ea->aggregate($event);
219                                                   }
220                                                   
221                                                   is_deeply(
222            1                                  6      $ea->results->{samples},
223                                                      {
224                                                         'select id from users where name=?' => {
225                                                            cmd           => 'Query',
226                                                            user          => 'root',
227                                                            host          => 'localhost',
228                                                            ip            => '',
229                                                            arg           => "SELECT id FROM users WHERE name='foo'",
230                                                            Query_time    => '0.000652',
231                                                            Lock_time     => '0.000109',
232                                                            Rows_sent     => 1,
233                                                            Rows_examined => 1,
234                                                            pos_in_log    => 0,
235                                                            fingerprint   => 'select id from users where name=?',
236                                                         },
237                                                         'insert ignore into articles (id, body,)values(?+)' => {
238                                                            ts   => '071015 21:43:52',
239                                                            cmd  => 'Query',
240                                                            user => 'root',
241                                                            host => 'localhost',
242                                                            ip   => '',
243                                                            arg =>
244                                                               "INSERT IGNORE INTO articles (id, body,)VALUES(3558268,'sample text')",
245                                                            Query_time    => '0.001943',
246                                                            Lock_time     => '0.000145',
247                                                            Rows_sent     => 0,
248                                                            Rows_examined => 0,
249                                                            pos_in_log    => 1,
250                                                            fingerprint   => 'insert ignore into articles (id, body,)values(?+)',
251                                                         },
252                                                      },
253                                                      'Worst-in-class samples default to the first event seen',
254                                                   );
255                                                   
256            1                                 29   $result = {
257                                                      Query_time => {
258                                                         min => '0.000652',
259                                                         max => '0.001943',
260                                                         sum => '0.003277',
261                                                         cnt => 3,
262                                                         all => {
263                                                            133 => 1,
264                                                            134 => 1,
265                                                            156 => 1,
266                                                         },
267                                                      },
268                                                      user => {
269                                                         min => 'bob',
270                                                         max => 'root',
271                                                         cnt => 3,
272                                                      },
273                                                      ts => {
274                                                         min => '071015 21:43:52',
275                                                         max => '071015 21:43:52',
276                                                         cnt => 2,
277                                                      },
278                                                      Rows_sent => {
279                                                         min => 0,
280                                                         max => 1,
281                                                         sum => 2,
282                                                         cnt => 3,
283                                                         all => {
284                                                            0   => 1, 
285                                                            284 => 2,
286                                                         },
287                                                      },
288                                                   };
289                                                   
290            1                                 16   is_deeply( $ea->results->{globals},
291                                                      $result, 'Simple fingerprint aggregation all' );
292                                                   
293                                                   # #############################################################################
294                                                   # Test grouping on user
295                                                   # #############################################################################
296            1                                 17   $ea = new EventAggregator(
297                                                      groupby    => 'user',
298                                                      worst      => 'Query_time',
299                                                      attributes => {
300                                                         Query_time => [qw(Query_time)],
301                                                         user       => [qw(user)], # It should ignore the groupby attribute
302                                                         ts         => [qw(ts)],
303                                                         Rows_sent  => [qw(Rows_sent)],
304                                                      },
305                                                   );
306                                                   
307            1                                221   $result = {
308                                                      classes => {
309                                                         bob => {
310                                                            ts => {
311                                                               min => '071015 21:43:52',
312                                                               max => '071015 21:43:52',
313                                                               unq => { '071015 21:43:52' => 1 },
314                                                               cnt => 1
315                                                            },
316                                                            Query_time => {
317                                                               min    => '0.000682',
318                                                               max    => '0.000682',
319                                                               all => {
320                                                                  134 => 1,
321                                                               },
322                                                               sum => '0.000682',
323                                                               cnt => 1
324                                                            },
325                                                            Rows_sent => {
326                                                               min => 1,
327                                                               max => 1,
328                                                               all => {
329                                                                  284 => 1,
330                                                               },
331                                                               sum => 1,
332                                                               cnt => 1
333                                                            }
334                                                         },
335                                                         root => {
336                                                            ts => {
337                                                               min => '071015 21:43:52',
338                                                               max => '071015 21:43:52',
339                                                               unq => { '071015 21:43:52' => 1 },
340                                                               cnt => 1
341                                                            },
342                                                            Query_time => {
343                                                               min    => '0.000652',
344                                                               max    => '0.001943',
345                                                               all => {
346                                                                  133 => 1,
347                                                                  156 => 1,
348                                                               },
349                                                               sum => '0.002595',
350                                                               cnt => 2
351                                                            },
352                                                            Rows_sent => {
353                                                               min => 0,
354                                                               max => 1,
355                                                               all => {
356                                                                  0   => 1,
357                                                                  284 => 1,
358                                                               },
359                                                               sum => 1,
360                                                               cnt => 2
361                                                            }
362                                                         }
363                                                      },
364                                                      samples => {
365                                                         bob => {
366                                                            cmd           => 'Query',
367                                                            arg           => 'SELECT id FROM users WHERE name=\'bar\'',
368                                                            ip            => '',
369                                                            ts            => '071015 21:43:52',
370                                                            fingerprint   => 'select id from users where name=?',
371                                                            host          => 'localhost',
372                                                            pos_in_log    => 5,
373                                                            Rows_examined => 2,
374                                                            user          => 'bob',
375                                                            Query_time    => '0.000682',
376                                                            Lock_time     => '0.000201',
377                                                            Rows_sent     => 1
378                                                         },
379                                                         root => {
380                                                            cmd => 'Query',
381                                                            arg =>
382                                                               'INSERT IGNORE INTO articles (id, body,)VALUES(3558268,\'sample text\')',
383                                                            ip => '',
384                                                            ts => '071015 21:43:52',
385                                                            fingerprint =>
386                                                               'insert ignore into articles (id, body,)values(?+)',
387                                                            host          => 'localhost',
388                                                            pos_in_log    => 1,
389                                                            Rows_examined => 0,
390                                                            user          => 'root',
391                                                            Query_time    => '0.001943',
392                                                            Lock_time     => '0.000145',
393                                                            Rows_sent     => 0
394                                                         },
395                                                      },
396                                                      globals => {
397                                                         ts => {
398                                                            min => '071015 21:43:52',
399                                                            max => '071015 21:43:52',
400                                                            cnt => 2
401                                                         },
402                                                         Query_time => {
403                                                            min => '0.000652',
404                                                            max => '0.001943',
405                                                            all => {
406                                                               133 => 1,
407                                                               134 => 1,
408                                                               156 => 1,
409                                                            },
410                                                            sum => '0.003277',
411                                                            cnt => 3
412                                                         },
413                                                         Rows_sent => {
414                                                            min => 0,
415                                                            max => 1,
416                                                            all => {
417                                                               0   => 1,
418                                                               284 => 2,
419                                                            },
420                                                            sum => 2,
421                                                            cnt => 3
422                                                         }
423                                                      }
424                                                   };
425                                                   
426            1                                  9   foreach my $event (@$events) {
427            3                                 16      $ea->aggregate($event);
428                                                   }
429                                                   
430            1                                  6   is_deeply( $ea->results, $result, 'user aggregation' );
431                                                   
432            1                                 13   is($ea->type_for('Query_time'), 'num', 'Query_time is numeric');
433            1                                  6   $ea->calculate_statistical_metrics();
434            1                                 10   is_deeply(
435                                                      $ea->metrics(
436                                                         where  => 'bob',
437                                                         attrib => 'Query_time',
438                                                      ),
439                                                      {  pct    => 1/3,
440                                                         sum    => '0.000682',
441                                                         cnt    => 1,
442                                                         min    => '0.000682',
443                                                         max    => '0.000682',
444                                                         avg    => '0.000682',
445                                                         median => '0.000682',
446                                                         stddev => 0,
447                                                         pct_95 => '0.000682',
448                                                      },
449                                                      'Got simple hash of metrics from metrics()',
450                                                   );
451                                                   
452            1                                 13   is_deeply(
453                                                      $ea->metrics(
454                                                         where  => 'foofoofoo',
455                                                         attrib => 'doesnotexist',
456                                                      ),
457                                                      {  pct    => 0,
458                                                         sum    => undef,
459                                                         cnt    => undef,
460                                                         min    => undef,
461                                                         max    => undef,
462                                                         avg    => 0,
463                                                         median => 0,
464                                                         stddev => 0,
465                                                         pct_95 => 0,
466                                                      },
467                                                      'It does not crash on metrics()',
468                                                   );
469                                                   
470                                                   # #############################################################################
471                                                   # Test buckets.
472                                                   # #############################################################################
473                                                   
474                                                   # Given an arrayref of vals, returns an arrayref and hashref of those
475                                                   # vals suitable for passing to calculate_statistical_metrics().
476                                                   sub bucketize {
477            5                    5            21      my ( $vals, $as_hashref ) = @_;
478            5                                 13      my $bucketed;
479            5    100                          18      if ( $as_hashref ) {
480            4                                 13         $bucketed = {};
481                                                      }
482                                                      else {
483            1                                  8         $bucketed = [ map { 0 } (0..999) ]; # TODO: shouldn't hard code this
            1000                               2676   
484                                                      }
485            5                                 36      my ($sum, $max, $min);
486            5                                 18      $max = $min = $vals->[0];
487            5                                 19      foreach my $val ( @$vals ) {
488           42    100                         127         if ( $as_hashref ) {
489           29                                120            $bucketed->{ EventAggregator::bucket_idx($val) }++;
490                                                         }
491                                                         else {
492           13                                 54            $bucketed->[ EventAggregator::bucket_idx($val) ]++;
493                                                         }
494           42    100                         170         $max = $max > $val ? $max : $val;
495           42    100                         136         $min = $min < $val ? $min : $val;
496           42                                133         $sum += $val;
497                                                      }
498            5                                 54      return $bucketed, { sum => $sum, max => $max, min => $min, cnt => scalar @$vals};
499                                                   }
500                                                   
501                                                   sub test_bucket_val {
502            7                    7            30      my ( $bucket, $val ) = @_;
503            7                                 70      my $msg = sprintf 'bucket %d equals %.9f', $bucket, $val;
504            7                                 34      cmp_ok(
505                                                         sprintf('%.9f', EventAggregator::bucket_value($bucket)),
506                                                         '==',
507                                                         $val,
508                                                         $msg
509                                                      );
510            7                                 21      return;
511                                                   }
512                                                   
513                                                   sub test_bucket_idx {
514           18                   18            72      my ( $val, $bucket ) = @_;
515           18                                195      my $msg = sprintf 'val %.8f goes in bucket %d', $val, $bucket;
516           18                                 82      cmp_ok(
517                                                         EventAggregator::bucket_idx($val),
518                                                         '==',
519                                                         $bucket,
520                                                         $msg
521                                                      );
522           18                                 53      return;
523                                                   }
524                                                   
525            1                                 17   test_bucket_idx(0, 0);
526            1                                  4   test_bucket_idx(0.0000001, 0);  # < MIN_BUCK (0.000001)
527            1                                  4   test_bucket_idx(0.000001, 1);   # = MIN_BUCK
528            1                                  5   test_bucket_idx(0.00000104, 1); # last val in bucket 1
529            1                                  5   test_bucket_idx(0.00000105, 2); # first val in bucket 2
530            1                                  5   test_bucket_idx(1, 284);
531            1                                  5   test_bucket_idx(2, 298);
532            1                                  4   test_bucket_idx(3, 306);
533            1                                  5   test_bucket_idx(4, 312);
534            1                                  4   test_bucket_idx(5, 317);
535            1                                  4   test_bucket_idx(6, 320);
536            1                                  4   test_bucket_idx(7, 324);
537            1                                  5   test_bucket_idx(8, 326);
538            1                                  5   test_bucket_idx(9, 329);
539            1                                  5   test_bucket_idx(20, 345);
540            1                                  5   test_bucket_idx(97.356678643, 378);
541            1                                  4   test_bucket_idx(100, 378);
542                                                   
543                                                   #TODO: {
544                                                   #   local $TODO = 'probably a float precision limitation';
545                                                   #   test_bucket_idx(1402556844201353.5, 999); # first val in last bucket
546                                                   #};
547                                                   
548            1                                  4   test_bucket_idx(9000000000000000.0, 999);
549                                                   
550                                                   # These vals are rounded to 9 decimal places, otherwise we'll have
551                                                   # problems with Perl returning stuff like 1.025e-9.
552            1                                  5   test_bucket_val(0, 0);
553            1                                  4   test_bucket_val(1,   0.000001000);
554            1                                  5   test_bucket_val(2,   0.000001050);
555            1                                  4   test_bucket_val(3,   0.000001103);
556            1                                  5   test_bucket_val(10,  0.000001551);
557            1                                  5   test_bucket_val(100, 0.000125239);
558            1                                  4   test_bucket_val(999, 1402556844201353.5);
559                                                   
560          284                                742   is_deeply(
561                                                      [ bucketize( [ 2, 3, 6, 4, 8, 9, 1, 1, 1, 5, 4, 3, 1 ] ) ],
562           13                                 40      [  [  ( map {0} ( 0 .. 283 ) ),
563                                                            4, # 1 -> 284
564            7                                 20            ( map {0} ( 285 .. 297 ) ),
565                                                            1, # 2 -> 298
566            5                                 18            ( map {0} ( 299 .. 305 ) ),
567                                                            2, # 3 -> 306
568          670                               1827            ( map {0} ( 307 .. 311 ) ),
569                                                            2,             # 4 -> 312
570                                                            0, 0, 0, 0,    # 313, 314, 315, 316,
571                                                            1,             # 5 -> 317
572                                                            0, 0,          # 318, 319
573                                                            1,             # 6 -> 320
574                                                            0, 0, 0, 0, 0, # 321, 322, 323, 324, 325
575                                                            1,             # 8 -> 326
576                                                            0, 0,          # 327, 328
577                                                            1,             # 9 -> 329
578            1                                  9            ( map {0} ( 330 .. 999 ) ),
579                                                         ],
580                                                         {  sum => 48,
581                                                            max => 9,
582                                                            min => 1,
583                                                            cnt => 13,
584                                                         },
585                                                      ],
586                                                      'Bucketizes values (values -> buckets)',
587                                                   );
588                                                   
589           48                                129   is_deeply(
590                                                      [ EventAggregator::buckets_of() ],
591                                                      [
592           47                                126         ( map {0} (0..47)    ),
593           47                                126         ( map {1} (48..94)   ),
594           47                                125         ( map {2} (95..141)  ),
595           47                                126         ( map {3} (142..188) ),
596           48                                128         ( map {4} (189..235) ),
597           47                                133         ( map {5} (236..283) ),
598          669                               1838         ( map {6} (284..330) ),
599            1                                 70         ( map {7} (331..999) )
600                                                      ],
601                                                      '8 buckets of base 10'
602                                                   );
603                                                   
604                                                   # #############################################################################
605                                                   # Test statistical metrics: 95%, stddev, and median
606                                                   # #############################################################################
607                                                   
608            1                                 94   $result = $ea->_calc_metrics(
609                                                      bucketize( [ 2, 3, 6, 4, 8, 9, 1, 1, 1, 5, 4, 3, 1 ], 1 ) );
610                                                   # The above bucketize will be bucketized as:
611                                                   # VALUE  BUCKET  VALUE        RANGE                       N VALS  SUM
612                                                   # 1      248     0.992136979  [0.992136979, 1.041743827)  4       3.968547916
613                                                   # 2      298     1.964363355  [1.964363355, 2.062581523)  1       1.964363355
614                                                   # 3      306     2.902259332  [2.902259332, 3.047372299)  2       5.804518664
615                                                   # 4      312     3.889305079  [3.889305079, 4.083770333)  2       7.778610158
616                                                   # 5      317     4.963848363  [4.963848363, 5.212040781)  1       4.963848363
617                                                   # 6      320     5.746274961  [5.746274961, 6.033588710)  1       5.746274961
618                                                   # 8      326     7.700558026  [7.700558026, 8.085585927)  1       7.700558026
619                                                   # 9      329     8.914358484  [8.914358484, 9.360076409)  1       8.914358484
620                                                   #                                                                 -----------
621                                                   #                                                                 46.841079927
622                                                   # I have hand-checked these values and they are correct.
623            1                                 45   is_deeply(
624                                                      $result,
625                                                      {
626                                                         stddev => 2.51982318221967,
627                                                         median => 2.90225933213165,
628                                                         cutoff => 12,
629                                                         pct_95 => 7.70055802567889,
630                                                      },
631                                                      'Calculates statistical metrics'
632                                                   );
633                                                   
634            1                                 13   $result = $ea->_calc_metrics(
635                                                      bucketize( [ 1, 1, 1, 1, 2, 3, 4, 4, 4, 4, 6, 8, 9 ], 1 ) );
636                                                   # The above bucketize will be bucketized as:
637                                                   # VALUE  BUCKET  VALUE        RANGE                       N VALS
638                                                   # 1      248     0.992136979  [0.992136979, 1.041743827)  4
639                                                   # 2      298     1.964363355  [1.964363355, 2.062581523)  1
640                                                   # 3      306     2.902259332  [2.902259332, 3.047372299)  1
641                                                   # 4      312     3.889305079  [3.889305079, 4.083770333)  4
642                                                   # 6      320     5.746274961  [5.746274961, 6.033588710)  1
643                                                   # 8      326     7.700558026  [7.700558026, 8.085585927)  1
644                                                   # 9      329     8.914358484  [8.914358484, 9.360076409)  1
645                                                   #
646                                                   # I have hand-checked these values and they are correct.
647            1                                 14   is_deeply(
648                                                      $result,
649                                                      {
650                                                         stddev => 2.48633263817885,
651                                                         median => 3.88930507895285,
652                                                         cutoff => 12,
653                                                         pct_95 => 7.70055802567889,
654                                                      },
655                                                      'Calculates median when it is halfway between two elements',
656                                                   );
657                                                   
658                                                   # This is a special case: only two values, widely separated.  The median should
659                                                   # be exact (because we pass in min/max) and the stdev should never be bigger
660                                                   # than half the difference between min/max.
661            1                                 12   $result = $ea->_calc_metrics(
662                                                      bucketize( [ 0.000002, 0.018799 ], 1 ) );
663            1                                 10   is_deeply(
664                                                      $result,
665                                                      {  stddev => 0.0132914861659635,
666                                                         median => 0.0094005,
667                                                         cutoff => 2,
668                                                         pct_95 => 0.018799,
669                                                      },
670                                                      'Calculates stats for two-element special case',
671                                                   );
672                                                   
673            1                                 22   $result = $ea->_calc_metrics(undef);
674            1                                  9   is_deeply(
675                                                      $result,
676                                                      {  stddev => 0,
677                                                         median => 0,
678                                                         cutoff => undef,
679                                                         pct_95 => 0,
680                                                      },
681                                                      'Calculates statistical metrics for undef array'
682                                                   );
683                                                   
684            1                                 11   $result = $ea->_calc_metrics( {}, 1 );
685            1                                  9   is_deeply(
686                                                      $result,
687                                                      {  stddev => 0,
688                                                         median => 0,
689                                                         cutoff => undef,
690                                                         pct_95 => 0,
691                                                      },
692                                                      'Calculates statistical metrics for empty hashref'
693                                                   );
694                                                   
695            1                                 13   $result = $ea->_calc_metrics( { 1 => 2 }, {} );
696            1                                  9   is_deeply(
697                                                      $result,
698                                                      {  stddev => 0,
699                                                         median => 0,
700                                                         cutoff => undef,
701                                                         pct_95 => 0,
702                                                      },
703                                                      'Calculates statistical metrics for when $stats missing'
704                                                   );
705                                                   
706            1                                 10   $result = $ea->_calc_metrics( bucketize( [0.9], 1 ) );
707            1                                  9   is_deeply(
708                                                      $result,
709                                                      {  stddev => 0,
710                                                         median => 0.9,
711                                                         cutoff => 1,
712                                                         pct_95 => 0.9,
713                                                      },
714                                                      'Calculates statistical metrics for 1 value'
715                                                   );
716                                                   
717                                                   # #############################################################################
718                                                   # Make sure it doesn't die when I try to parse an event that doesn't have an
719                                                   # expected attribute.
720                                                   # #############################################################################
721            1                                  8   eval { $ea->aggregate( { fingerprint => 'foo' } ); };
               1                                  8   
722            1                                  7   is( $EVAL_ERROR, '', "Handles an undef attrib OK" );
723                                                   
724                                                   # #############################################################################
725                                                   # Issue 184: db OR Schema
726                                                   # #############################################################################
727            1                                 10   $ea = new EventAggregator(
728                                                      groupby => 'arg',
729                                                      attributes => {
730                                                         db => [qw(db Schema)],
731                                                      },
732                                                      worst => 'foo',
733                                                   );
734                                                   
735            1                                176   $events = [
736                                                      {  arg    => "foo1",
737                                                         Schema => 'db1',
738                                                      },
739                                                      {  arg => "foo2",
740                                                         db  => 'db1',
741                                                      },
742                                                   ];
743            1                                 13   foreach my $event (@$events) {
744            2                                 10      $ea->aggregate($event);
745                                                   }
746                                                   
747            1                                  7   is( $ea->results->{classes}->{foo1}->{db}->{min},
748                                                      'db1', 'Gets Schema for db|Schema (issue 184)' );
749                                                   
750            1                                  7   is( $ea->results->{classes}->{foo2}->{db}->{min},
751                                                      'db1', 'Gets db for db|Schema (issue 184)' );
752                                                   
753                                                   # #############################################################################
754                                                   # Make sure large values are kept reasonable.
755                                                   # #############################################################################
756            1                                 13   $ea = new EventAggregator(
757                                                      attributes   => { Rows_read => [qw(Rows_read)], },
758                                                      attrib_limit => 1000,
759                                                      worst        => 'foo',
760                                                      groupby      => 'arg',
761                                                   );
762                                                   
763            1                                 61   $events = [
764                                                      {  arg       => "arg1",
765                                                         Rows_read => 4,
766                                                      },
767                                                      {  arg       => "arg2",
768                                                         Rows_read => 4124524590823728995,
769                                                      },
770                                                      {  arg       => "arg1",
771                                                         Rows_read => 4124524590823728995,
772                                                      },
773                                                   ];
774                                                   
775            1                                  6   foreach my $event (@$events) {
776            3                                 15      $ea->aggregate($event);
777                                                   }
778                                                   
779                                                   $result = {
780            1                                 26      classes => {
781                                                         'arg1' => {
782                                                            Rows_read => {
783                                                               min => 4,
784                                                               max => 4,
785                                                               all => {
786                                                                  312 => 2,
787                                                               },
788                                                               sum    => 8,
789                                                               cnt    => 2,
790                                                               'last' => 4,
791                                                            }
792                                                         },
793                                                         'arg2' => {
794                                                            Rows_read => {
795                                                               min => 0,
796                                                               max => 0,
797                                                               all => {
798                                                                  0 => 1,
799                                                               },
800                                                               sum    => 0,
801                                                               cnt    => 1,
802                                                               'last' => 0,
803                                                            }
804                                                         },
805                                                      },
806                                                      globals => {
807                                                         Rows_read => {
808                                                            min => 0, # Because 'last' is only kept at the class level
809                                                            max => 4,
810                                                            all => {
811                                                               0   => 1,
812                                                               312 => 2,
813                                                            },
814                                                            sum => 8,
815                                                            cnt => 3,
816                                                         },
817                                                      },
818                                                      samples => {
819                                                         arg1 => {
820                                                            arg       => "arg1",
821                                                            Rows_read => 4,
822                                                         },
823                                                         arg2 => {
824                                                            arg       => "arg2",
825                                                            Rows_read => 4124524590823728995,
826                                                         },
827                                                      },
828                                                   };
829                                                   
830            1                                  7   is_deeply( $ea->results, $result, 'Limited attribute values', );
831                                                   
832                                                   # #############################################################################
833                                                   # For issue 171, the enhanced --top syntax, we need to pick events by complex
834                                                   # criteria.  It's too messy to do with a log file, so we'll do it with an event
835                                                   # generator function.
836                                                   # #############################################################################
837                                                   {
838            1                                  9      my $i = 0;
               1                                  4   
839            1                                 11      my @event_specs = (
840                                                         # fingerprint, time, count; 1350 seconds total
841                                                         [ 'event0', 10, 1   ], # An outlier, but happens once
842                                                         [ 'event1', 10, 5   ], # An outlier, but not in top 95%
843                                                         [ 'event2', 2,  500 ], # 1000 seconds total
844                                                         [ 'event3', 1,  500 ], # 500  seconds total
845                                                         [ 'event4', 1,  300 ], # 300  seconds total
846                                                      );
847                                                      sub generate_event {
848                                                         START:
849         1307    100          1307          5915         if ( $i >= $event_specs[0]->[2] ) {
850            5                                 13            shift @event_specs;
851            5                                 15            $i = 0;
852                                                         }
853         1307                               3093         $i++;
854         1307    100                        4479         return undef unless @event_specs;
855                                                         return {
856         1306                               9868            fingerprint => $event_specs[0]->[0],
857                                                            Query_time  => $event_specs[0]->[1],
858                                                         };
859                                                      }
860                                                   }
861                                                   
862            1                                 10   $ea = new EventAggregator(
863                                                      groupby    => 'fingerprint',
864                                                      worst      => 'foo',
865                                                      attributes => {
866                                                         Query_time => [qw(Query_time)],
867                                                      },
868                                                   );
869                                                   
870            1                                 85   while ( my $event = generate_event() ) {
871         1306                               5186      $ea->aggregate($event);
872                                                   }
873            1                                  6   $ea->calculate_statistical_metrics();
874            1                                  3   my @chosen;
875                                                   
876            1                                  9   @chosen = $ea->top_events(
877                                                      groupby => 'fingerprint',
878                                                      attrib  => 'Query_time',
879                                                      orderby => 'sum',
880                                                      total   => 1300,
881                                                      count   => 2,               # Get event2/3 but not event4
882                                                      # Or outlier events that usually take > 5s to execute and happened > 3 times
883                                                      ol_attrib => 'Query_time',
884                                                      ol_limit  => 5,
885                                                      ol_freq   => 3,
886                                                   );
887                                                   
888            1                                 11   is_deeply(
889                                                      \@chosen,
890                                                      [
891                                                         [qw(event2 top)],
892                                                         [qw(event3 top)],
893                                                         [qw(event1 outlier)],
894                                                      ],
895                                                      'Got top events' );
896                                                   
897            1                                 16   @chosen = $ea->top_events(
898                                                      groupby => 'fingerprint',
899                                                      attrib  => 'Query_time',
900                                                      orderby => 'sum',
901                                                      total   => 1300,
902                                                      count   => 2,               # Get event2/3 but not event4
903                                                      # Or outlier events that usually take > 5s to execute
904                                                      ol_attrib => 'Query_time',
905                                                      ol_limit  => 5,
906                                                      ol_freq   => undef,
907                                                   );
908                                                   
909            1                                 11   is_deeply(
910                                                      \@chosen,
911                                                      [
912                                                         [qw(event2 top)],
913                                                         [qw(event3 top)],
914                                                         [qw(event1 outlier)],
915                                                         [qw(event0 outlier)],
916                                                      ],
917                                                      'Got top events with outlier' );
918                                                   
919                                                   # Try to make it fail
920            1                                 11   eval {
921            1                                  9      $ea->aggregate({foo         => 'FAIL'});
922            1                                 13      $ea->aggregate({fingerprint => 'FAIL'});
923                                                      # but not this one -- the caller should eval to catch this.
924                                                      # $ea->aggregate({fingerprint => 'FAIL2', Query_time => 'FAIL' });
925            1                                  7      @chosen = $ea->top_events(
926                                                         groupby => 'fingerprint',
927                                                         attrib  => 'Query_time',
928                                                         orderby => 'sum',
929                                                         count   => 2,
930                                                      );
931                                                   };
932            1                                  6   is($EVAL_ERROR, '', 'It handles incomplete/malformed events');
933                                                   
934            1                                 13   $events = [
935                                                      {  Query_time    => '0.000652',
936                                                         arg           => 'select * from sakila.actor join sakila.film_actor using(actor_id)',
937                                                      },
938                                                      {  Query_time    => '1.000652',
939                                                         arg           => 'select * from sakila.actor',
940                                                      },
941                                                      {  Query_time    => '2.000652',
942                                                         arg           => 'select * from sakila.actor join sakila.film_actor using(actor_id)',
943                                                      },
944                                                      {  Query_time    => '0.000652',
945                                                         arg           => 'select * from sakila.actor',
946                                                      },
947                                                   ];
948                                                   
949            1                                 14   $ea = new EventAggregator(
950                                                      groupby    => 'tables',
951                                                      worst      => 'foo',
952                                                      attributes => {
953                                                         Query_time => [qw(Query_time)],
954                                                      },
955                                                   );
956                                                   
957            1                                212   foreach my $event ( @$events ) {
958            4                                 28      $event->{tables} = [ $qp->get_tables($event->{arg}) ];
959            4                                498      $ea->aggregate($event);
960                                                   }
961                                                   
962                                                   is_deeply(
963            1                                  6      $ea->results,
964                                                      {
965                                                         classes => {
966                                                            'sakila.actor' => {
967                                                               Query_time => {
968                                                                  min => '0.000652',
969                                                                  max => '2.000652',
970                                                                  all => {
971                                                                     133 => 2,
972                                                                     284 => 1,
973                                                                     298 => 1,
974                                                                  },
975                                                                  sum => '3.002608',
976                                                                  cnt => 4,
977                                                               },
978                                                            },
979                                                            'sakila.film_actor' => {
980                                                               Query_time => {
981                                                                  min => '0.000652',
982                                                                  max => '2.000652',
983                                                                  all => {
984                                                                     133 => 1,
985                                                                     298 => 1,
986                                                                  },
987                                                                  sum => '2.001304',
988                                                                  cnt => 2,
989                                                               },
990                                                            },
991                                                         },
992                                                         globals => {
993                                                            Query_time => {
994                                                               min => '0.000652',
995                                                               max => '2.000652',
996                                                               all => {
997                                                                  133 => 3,
998                                                                  284 => 1,
999                                                                  298 => 2,
1000                                                              },
1001                                                              sum => '5.003912',
1002                                                              cnt => 6,
1003                                                           },
1004                                                        },
1005                                                        samples => {
1006                                                           'sakila.actor' => {
1007                                                              Query_time    => '0.000652',
1008                                                              arg           => 'select * from sakila.actor join sakila.film_actor using(actor_id)',
1009                                                              tables        => [qw(sakila.actor sakila.film_actor)],
1010                                                           },
1011                                                           'sakila.film_actor' => {
1012                                                              Query_time    => '0.000652',
1013                                                              arg           => 'select * from sakila.actor join sakila.film_actor using(actor_id)',
1014                                                              tables        => [qw(sakila.actor sakila.film_actor)],
1015                                                           },
1016                                                        },
1017                                                     },
1018                                                     'Aggregation by tables',
1019                                                  );
1020                                                  
1021                                                  # Event attribute with space in name.
1022           1                                 38   $ea = new EventAggregator(
1023                                                     groupby    => 'fingerprint',
1024                                                     worst      => 'Query time',
1025                                                     attributes => {
1026                                                        'Query time' => ['Query time'],
1027                                                     },
1028                                                  );
1029           1                                 99   $events = {
1030                                                     fingerprint  => 'foo',
1031                                                     'Query time' => 123,
1032                                                  };
1033           1                                 13   $ea->aggregate($events);
1034           1                                  6   is(
1035                                                     $ea->results->{classes}->{foo}->{'Query time'}->{min},
1036                                                     123,
1037                                                     'Aggregates attributes with spaces in their names'
1038                                                  );
1039                                                  
1040                                                  # Make sure types can be hinted directly.
1041           1                                 14   $ea = new EventAggregator(
1042                                                     groupby    => 'fingerprint',
1043                                                     worst      => 'Query time',
1044                                                     attributes => {
1045                                                        'Query time' => ['Query time'],
1046                                                        'Schema'     => ['Schema'],
1047                                                     },
1048                                                     type_for => {
1049                                                        Query_time => 'string',
1050                                                     },
1051                                                  );
1052           1                                 58   $events = {
1053                                                     fingerprint  => 'foo',
1054                                                     'Query_time' => 123,
1055                                                     'Schema'     => '',
1056                                                  };
1057           1                                  6   $ea->aggregate($events);
1058           1                                  6   is(
1059                                                     $ea->type_for('Query_time'),
1060                                                     'string',
1061                                                     'Query_time type can be hinted directly',
1062                                                  );
1063                                                  
1064                                                  # #############################################################################
1065                                                  # Issue 323: mk-query-digest does not properly handle logs with an empty Schema:
1066                                                  # #############################################################################
1067           1                                 11   $ea = new EventAggregator(
1068                                                     groupby    => 'fingerprint',
1069                                                     worst      => 'Query time',
1070                                                     attributes => {
1071                                                        'Query time' => ['Query time'],
1072                                                        'Schema'     => ['Schema'],
1073                                                     },
1074                                                  );
1075           1                                 45   $events = {
1076                                                     fingerprint  => 'foo',
1077                                                     'Query time' => 123,
1078                                                     'Schema'     => '',
1079                                                  };
1080           1                                  5   $ea->aggregate($events);
1081           1                                  5   is(
1082                                                     $ea->type_for('Schema'),
1083                                                     'string',
1084                                                     'Empty Schema: (issue 323)'
1085                                                  );
1086                                                  
1087                                                  # #############################################################################
1088                                                  # Issue 321: mk-query-digest stuck in infinite loop while processing log
1089                                                  # #############################################################################
1090                                                  
1091           1                                162   my $bad_vals =
1092                                                     [  580, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1093                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1094                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1095                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1096                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1097                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1098                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1099                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1100                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1101                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1102                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1103                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1104                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1105                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1106                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1107                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 25, 0, 0, 0,
1108                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1109                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1110                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1111                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1112                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1113                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1114                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1115                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1116                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1117                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1118                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1119                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1120                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1121                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1122                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1123                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1124                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1125                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1126                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1127                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1128                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1129                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1130                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1131                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1132                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1133                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1134                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1135                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1136                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1137                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1138                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1139                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1140                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1141                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1142                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1143                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1144                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1145                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1146                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,  0, 0, 0,
1147                                                        0,   0, 0, 0, 0, 0, 0, 0, 0, 0
1148                                                     ];
1149                                                  
1150           1                                  8   my $bad_event = {
1151                                                     min => 0,
1152                                                     max => 1,
1153                                                     last => 1,
1154                                                     sum => 25,
1155                                                     cnt => 605
1156                                                  };
1157                                                  
1158                                                  # Converted for http://code.google.com/p/maatkit/issues/detail?id=866
1159           1                                  4   my $bad_vals_hashref = {};
1160           1                                  2   $bad_vals_hashref->{$_} = $bad_vals->[$_] for 0..999;
               1                               2326   
1161                                                  
1162           1                                 10   $result = $ea->_calc_metrics($bad_vals_hashref, $bad_event);
1163           1                                 21   is_deeply(
1164                                                     $result,
1165                                                     {
1166                                                        stddev => 0.1974696076416,
1167                                                        median => 0,
1168                                                        pct_95 => 0,
1169                                                        cutoff => 574,
1170                                                     },
1171                                                     'statistical metrics with mostly zero values'
1172                                                  );
1173                                                  
1174                                                  # #############################################################################
1175                                                  # Issue 332: mk-query-digest crashes on sqrt of negative number
1176                                                  # #############################################################################
1177           1                                 11   $bad_vals = {
1178                                                     499 => 12,
1179                                                  };
1180           1                                 24   $bad_event = {
1181                                                     min  => 36015,
1182                                                     max  => 36018,
1183                                                     last => 0,
1184                                                     sum  => 432212,
1185                                                     cnt  => 12,
1186                                                  };
1187                                                  
1188           1                                  8   $result = $ea->_calc_metrics($bad_vals, $bad_event);
1189           1                                 11   is_deeply(
1190                                                     $result,
1191                                                     {
1192                                                        stddev => 0,
1193                                                        median => 35667.3576664115,
1194                                                        pct_95 => 35667.3576664115,
1195                                                        cutoff => 11,
1196                                                     },
1197                                                     'float math with big number (issue 332)'
1198                                                  );
1199                                                  
1200           1                                 10   $bad_vals = {
1201                                                     799 => 9,
1202                                                  };
1203           1                                  8   $bad_event = {
1204                                                     min  => 36015, 
1205                                                     max  => 36018,
1206                                                     last => 0,
1207                                                     sum  => 432212,
1208                                                     cnt  => 9,
1209                                                  };
1210                                                  
1211           1                                  7   $result = $ea->_calc_metrics($bad_vals, $bad_event);
1212           1                                 14   is_deeply(
1213                                                     $result,
1214                                                     {
1215                                                        stddev => 0,
1216                                                        median => 81107433250.8976,
1217                                                        pct_95 => 81107433250.8976,
1218                                                        cutoff => 9,
1219                                                     },
1220                                                     'float math with bigger number (issue 332)'
1221                                                  );
1222                                                  
1223           1                                 16   $ea->reset_aggregated_data();
1224           1                                  6   is_deeply(
1225                                                     $ea->results(),
1226                                                     {
1227                                                        classes => {
1228                                                           foo => {
1229                                                              Schema       => {},
1230                                                              'Query time' => {},
1231                                                           }
1232                                                        },
1233                                                        globals => {
1234                                                           Schema       => {},
1235                                                           'Query time' => {},
1236                                                        },
1237                                                        samples => {},
1238                                                     },
1239                                                     'Reset works');
1240                                                  
1241                                                  # #############################################################################
1242                                                  # Issue 396: Make mk-query-digest detect properties of events to output
1243                                                  # #############################################################################
1244           1                                 14   $ea = new EventAggregator(
1245                                                     groupby       => 'arg',
1246                                                     worst         => 'Query_time',
1247                                                  );
1248           1                                116   $events = [
1249                                                     {  arg        => "foo",
1250                                                        Schema     => 'db1',
1251                                                        Query_time => '1.000000',
1252                                                        other_prop => 'trees',
1253                                                     },
1254                                                     {  arg        => "foo",
1255                                                        Schema     => 'db1',
1256                                                        Query_time => '2.000000',
1257                                                        new_prop   => 'The quick brown fox jumps over the lazy dog',
1258                                                     },
1259                                                  ];
1260           1                                  5   foreach my $event ( @$events ) {
1261           2                                 11      $ea->aggregate($event);
1262                                                  }
1263                                                  is_deeply(
1264           1                                  6      $ea->results(),
1265                                                     {
1266                                                        samples => {
1267                                                         foo => {
1268                                                           Schema => 'db1',
1269                                                           new_prop => 'The quick brown fox jumps over the lazy dog',
1270                                                           arg => 'foo',
1271                                                           Query_time => '2.000000'
1272                                                         }
1273                                                        },
1274                                                        classes => {
1275                                                         foo => {
1276                                                           Schema => {
1277                                                             min => 'db1',
1278                                                             max => 'db1',
1279                                                             unq => {
1280                                                               db1 => 2
1281                                                             },
1282                                                             cnt => 2
1283                                                           },
1284                                                           other_prop => {
1285                                                             min => 'trees',
1286                                                             max => 'trees',
1287                                                             unq => {
1288                                                               trees => 1
1289                                                             },
1290                                                             cnt => 1
1291                                                           },
1292                                                           new_prop => {
1293                                                             min => 'The quick brown fox jumps over the lazy dog',
1294                                                             max => 'The quick brown fox jumps over the lazy dog',
1295                                                             unq => {
1296                                                              'The quick brown fox jumps over the lazy dog' => 1,
1297                                                             },
1298                                                             cnt => 1,
1299                                                           },
1300                                                           Query_time => {
1301                                                             min => '1.000000',
1302                                                             max => '2.000000',
1303                                                             all => {
1304                                                                284 => 1,
1305                                                                298 => 1,
1306                                                             },
1307                                                             sum => 3,
1308                                                             cnt => 2
1309                                                           }
1310                                                         }
1311                                                        },
1312                                                        globals => {
1313                                                         Schema => {
1314                                                           min => 'db1',
1315                                                           max => 'db1',
1316                                                           cnt => 2
1317                                                         },
1318                                                         other_prop => {
1319                                                           min => 'trees',
1320                                                           max => 'trees',
1321                                                           cnt => 1
1322                                                         },
1323                                                         new_prop => {
1324                                                           min => 'The quick brown fox jumps over the lazy dog',
1325                                                           max => 'The quick brown fox jumps over the lazy dog',
1326                                                           cnt => 1,
1327                                                         },
1328                                                         Query_time => {
1329                                                           min => '1.000000',
1330                                                           max => '2.000000',
1331                                                           all => {
1332                                                              284 => 1,
1333                                                              298 => 1,
1334                                                           },
1335                                                           sum => 3,
1336                                                           cnt => 2
1337                                                         }
1338                                                        }
1339                                                     },
1340                                                     'Auto-detect attributes if none given',
1341                                                  );
1342                                                  
1343           1                                  7   is_deeply(
1344           1                                 21      [ sort @{$ea->get_attributes()} ],
1345                                                     [qw(Query_time Schema new_prop other_prop)],
1346                                                     'get_attributes()',
1347                                                  );
1348                                                  
1349           1                                 11   is(
1350                                                     $ea->events_processed(),
1351                                                     2,
1352                                                     'events_processed()'
1353                                                  );
1354                                                  
1355           1                                 23   my $only_query_time_results =  {
1356                                                        samples => {
1357                                                         foo => {
1358                                                           Schema => 'db1',
1359                                                           new_prop => 'The quick brown fox jumps over the lazy dog',
1360                                                           arg => 'foo',
1361                                                           Query_time => '2.000000'
1362                                                         }
1363                                                        },
1364                                                        classes => {
1365                                                         foo => {
1366                                                           Query_time => {
1367                                                             min => '1.000000',
1368                                                             max => '2.000000',
1369                                                             all => {
1370                                                                284 => 1,
1371                                                                298 => 1,
1372                                                             },
1373                                                             sum => 3,
1374                                                             cnt => 2
1375                                                           }
1376                                                         }
1377                                                        },
1378                                                        globals => {
1379                                                         Query_time => {
1380                                                           min => '1.000000',
1381                                                           max => '2.000000',
1382                                                           all => {
1383                                                              284 => 1,
1384                                                              298 => 1,
1385                                                           },
1386                                                           sum => 3,
1387                                                           cnt => 2
1388                                                         }
1389                                                        }
1390                                                  };
1391                                                  
1392           1                                  9   $ea = new EventAggregator(
1393                                                     groupby    => 'arg',
1394                                                     worst      => 'Query_time',
1395                                                     attributes => {
1396                                                        Query_time => [qw(Query_time)],
1397                                                     },
1398                                                  );
1399           1                                171   foreach my $event ( @$events ) {
1400           2                                 12      $ea->aggregate($event);
1401                                                  }
1402                                                  is_deeply(
1403           1                                  6      $ea->results(),
1404                                                     $only_query_time_results,
1405                                                     'Do not auto-detect attributes if given explicit attributes',
1406                                                  );
1407                                                  
1408           1                                 13   $ea = new EventAggregator(
1409                                                     groupby           => 'arg',
1410                                                     worst             => 'Query_time',
1411                                                     ignore_attributes => [ qw(new_prop other_prop Schema) ],
1412                                                  );
1413           1                                 66   foreach my $event ( @$events ) {
1414           2                                  9      $ea->aggregate($event);
1415                                                  }
1416                                                  is_deeply(
1417           1                                  5      $ea->results(),
1418                                                     $only_query_time_results,
1419                                                     'Ignore some auto-detected attributes',
1420                                                  );
1421                                                  
1422                                                  # #############################################################################
1423                                                  # Issue 458: mk-query-digest Use of uninitialized value in division (/) at
1424                                                  # line 3805.
1425                                                  # #############################################################################
1426                                                  $ea = new EventAggregator(
1427                                                     groupby           => 'arg',
1428                                                     worst             => 'Query_time',
1429                                                  );
1430                                                  
1431                                                  # The real bug is in QueryReportFormatter, and there's nothing particularly
1432                                                  # interesting about this sample, but we just want to make sure that the
1433                                                  # timestamp prop shows up only in the one event.  The bug is that it appears
1434                                                  # to be in all events by the time we get to QueryReportFormatter.
1435                                                  is_deeply(
1436                                                     parse_file('common/t/samples/slow029.txt', $p, $ea),
1437                                                     [
1438                                                        {
1439                                                         Schema => 'mysql',
1440                                                         bytes => 11,
1441                                                         db => 'mysql',
1442                                                         cmd => 'Query',
1443                                                         arg => 'show status',
1444                                                         ip => '',
1445                                                         Thread_id => '1530316',
1446                                                         host => 'localhost',
1447                                                         pos_in_log => 0,
1448                                                         timestamp => '1241453102',
1449                                                         Rows_examined => '249',
1450                                                         user => 'root',
1451                                                         Query_time => '4.352063',
1452                                                         Rows_sent => '249',
1453                                                         Lock_time => '0.000000'
1454                                                        },
1455                                                        {
1456                                                         Schema => 'pro',
1457                                                         bytes => 179,
1458                                                         db => 'pro',
1459                                                         cmd => 'Query',
1460                                                         arg => 'SELECT * FROM `events`     WHERE (`events`.`id` IN (51118,51129,50893,50567,50817,50834,50608,50815,51023,50903,50820,50003,50890,50673,50596,50553,50618,51103,50578,50732,51021))',
1461                                                         ip => '1.2.3.87',
1462                                                         ts => '090504  9:07:24',
1463                                                         Thread_id => '1695747',
1464                                                         host => 'x03-s00342.x03.domain.com',
1465                                                         pos_in_log => 206,
1466                                                         Rows_examined => '26876',
1467                                                         Query_time => '2.156031',
1468                                                         user => 'dbuser',
1469                                                         Rows_sent => '21',
1470                                                         Lock_time => '0.000000'
1471                                                        },
1472                                                        {
1473                                                         Schema => 'pro',
1474                                                         bytes => 66,
1475                                                         cmd => 'Query',
1476                                                         arg => 'SELECT * FROM `users`     WHERE (email = NULL or new_email = NULL)',
1477                                                         ip => '1.2.3.84',
1478                                                         Thread_id => '1695268',
1479                                                         host => 'x03-s00339.x03.domain.com',
1480                                                         pos_in_log => 602,
1481                                                         Rows_examined => '106242',
1482                                                         user => 'dbuser',
1483                                                         Query_time => '2.060030',
1484                                                         Rows_sent => '0',
1485                                                         Lock_time => '0.000000'
1486                                                        },
1487                                                     ],
1488                                                     'slow029.txt events (issue 458)'
1489                                                  );
1490                                                  
1491                                                  ok(
1492                                                     !exists $ea->results->{samples}->{'SELECT * FROM `users`     WHERE (email = NULL or new_email = NULL)'}->{timestamp}
1493                                                     && !exists $ea->results->{samples}->{'SELECT * FROM `events`     WHERE (`events`.`id` IN (51118,51129,50893,50567,50817,50834,50608,50815,51023,50903,50820,50003,50890,50673,50596,50553,50618,51103,50578,50732,51021))'}->{timestamp}
1494                                                     && exists $ea->results->{samples}->{'show status'}->{timestamp},
1495                                                     'props not auto-vivified (issue 458)',
1496                                                  );
1497                                                  
1498                                                  # #############################################################################
1499                                                  # Issue 514: mk-query-digest does not create handler sub for new auto-detected
1500                                                  # attributes
1501                                                  # #############################################################################
1502                                                  $ea = new EventAggregator(
1503                                                     groupby      => 'arg',
1504                                                     worst        => 'Query_time',
1505                                                  );
1506                                                  # In slow030, event 180 is a new class with new attributes.
1507                                                  parse_file('common/t/samples/slow030.txt', $p, $ea);
1508                                                  ok(
1509                                                     exists $ea->{unrolled_for}->{InnoDB_rec_lock_wait},
1510                                                     'Handler sub created for new attrib; default unroll_limit (issue 514)'
1511                                                  );
1512                                                  ok(
1513                                                     exists $ea->{result_classes}->{'SELECT * FROM bar'}->{InnoDB_IO_r_bytes},
1514                                                     'New event class has new attrib; default unroll_limit(issue 514)'
1515                                                  );
1516                                                  
1517                                                  $ea = new EventAggregator(
1518                                                     groupby      => 'arg',
1519                                                     worst        => 'Query_time',
1520                                                     unroll_limit => 50,
1521                                                  );
1522                                                  parse_file('common/t/samples/slow030.txt', $p, $ea);
1523                                                  ok(
1524                                                     !exists $ea->{unrolled_for}->{InnoDB_rec_lock_wait},
1525                                                     'Handler sub not created for new attrib; unroll_limit=50 (issue 514)'
1526                                                  );
1527                                                  ok(
1528                                                     !exists $ea->{result_classes}->{'SELECT * FROM bar'}->{InnoDB_IO_r_bytes},
1529                                                     'New event class has new attrib; default unroll_limit=50 (issue 514)'
1530                                                  );
1531                                                  
1532                                                  # #############################################################################
1533                                                  # Check that broken Query_time are fixed (issue 234).
1534                                                  # #############################################################################
1535                                                  $events = [
1536                                                     {  cmd           => 'Query',
1537                                                        user          => 'root',
1538                                                        host          => 'localhost',
1539                                                        ip            => '',
1540                                                        arg           => "SELECT id FROM users WHERE name='foo'",
1541                                                        Query_time    => '17.796870.000036',
1542                                                        Lock_time     => '0.000000',
1543                                                        Rows_sent     => 1,
1544                                                        Rows_examined => 1,
1545                                                        pos_in_log    => 0,
1546                                                     },
1547                                                  ];
1548                                                  
1549                                                  $ea = new EventAggregator(
1550                                                     groupby      => 'arg',
1551                                                     worst        => 'Query_time',
1552                                                  );
1553                                                  foreach my $event (@$events) {
1554                                                     $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
1555                                                     $ea->aggregate($event);
1556                                                  }
1557                                                  
1558                                                  is_deeply(
1559                                                     $ea->results->{samples},
1560                                                     {
1561                                                        'SELECT id FROM users WHERE name=\'foo\'' => {
1562                                                           Lock_time => '0.000000',
1563                                                           Query_time => '17.796870',
1564                                                           Rows_examined => 1,
1565                                                           Rows_sent => 1,
1566                                                           arg => 'SELECT id FROM users WHERE name=\'foo\'',
1567                                                           cmd => 'Query',
1568                                                           fingerprint => 'select id from users where name=?',
1569                                                           host => 'localhost',
1570                                                           ip => '',
1571                                                           pos_in_log => 0,
1572                                                           user => 'root'
1573                                                        },
1574                                                     },
1575                                                     'Broken Query_time (issue 234)'
1576                                                  );
1577                                                  
1578                                                  # #############################################################################
1579                                                  # Issue 607: mk-query-digest throws Possible unintended interpolation of
1580                                                  # @session in string
1581                                                  # #############################################################################
1582                                                  $ea = new EventAggregator(
1583                                                     groupby      => 'arg',
1584                                                     worst        => 'Query_time',
1585                                                     unroll_limit => 1,
1586                                                  );
1587                                                  eval {
1588                                                     parse_file('common/t/samples/binlogs/binlog004.txt', $bp, $ea);
1589                                                  };
1590                                                  is(
1591                                                     $EVAL_ERROR,
1592                                                     '',
1593                                                     'No error parsing binlog with @attribs (issue 607)'
1594                                                  );
1595                                                  
1596                                                  # #############################################################################
1597                                                  # merge()
1598                                                  # #############################################################################
1599                                                  my $ea1 = new EventAggregator(
1600                                                     groupby    => 'fingerprint',
1601                                                     worst      => 'Query_time',
1602                                                     attributes => {
1603                                                        Query_time => [qw(Query_time)],
1604                                                        user       => [qw(user)],
1605                                                        ts         => [qw(ts)],
1606                                                        Rows_sent  => [qw(Rows_sent)],
1607                                                        Full_scan  => [qw(Full_scan)],
1608                                                        ea1_only   => [qw(ea1_only)],
1609                                                        ea2_only   => [qw(ea2_only)],
1610                                                     },
1611                                                  );
1612                                                  my $ea2 = new EventAggregator(
1613                                                     groupby    => 'fingerprint',
1614                                                     worst      => 'Query_time',
1615                                                     attributes => {
1616                                                        Query_time => [qw(Query_time)],
1617                                                        user       => [qw(user)],
1618                                                        ts         => [qw(ts)],
1619                                                        Rows_sent  => [qw(Rows_sent)],
1620                                                        Full_scan  => [qw(Full_scan)],
1621                                                        ea1_only   => [qw(ea1_only)],
1622                                                        ea2_only   => [qw(ea2_only)],
1623                                                     },
1624                                                  );
1625                                                  
1626                                                  $events = [
1627                                                     {  ts            => '071015 19:00:00',
1628                                                        cmd           => 'Query',
1629                                                        user          => 'root',
1630                                                        arg           => "SELECT id FROM users WHERE name='foo'",
1631                                                        Query_time    => '0.000652',
1632                                                        Rows_sent     => 1,
1633                                                        pos_in_log    => 0,
1634                                                        Full_scan     => 'No',
1635                                                        ea1_only      => 5,
1636                                                     },
1637                                                  ];
1638                                                  foreach my $event (@$events) {
1639                                                     $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
1640                                                     $ea1->aggregate($event);
1641                                                  }
1642                                                  
1643                                                  $events = [
1644                                                     {  ts            => '071015 21:43:52',
1645                                                        cmd           => 'Query',
1646                                                        user          => 'bob',
1647                                                        arg           => "SELECT id FROM users WHERE name='bar'",
1648                                                        Query_time    => '0.000682',
1649                                                        Rows_sent     => 2,
1650                                                        pos_in_log    => 5,
1651                                                        Full_scan     => 'Yes',
1652                                                        ea2_only      => 7,
1653                                                     }
1654                                                  ];
1655                                                  foreach my $event (@$events) {
1656                                                     $event->{fingerprint} = $qr->fingerprint( $event->{arg} );
1657                                                     $ea2->aggregate($event);
1658                                                  }
1659                                                  
1660                                                  $result = {
1661                                                     classes => {
1662                                                        'select id from users where name=?' => {
1663                                                           Query_time => {
1664                                                              min => '0.000652',
1665                                                              max => '0.000682',
1666                                                              all => {
1667                                                                 133 => 1,
1668                                                                 134 => 1,
1669                                                              },
1670                                                              sum => '0.001334',
1671                                                              cnt => 2,
1672                                                           },
1673                                                           user => {
1674                                                              unq => {
1675                                                                 bob  => 1,
1676                                                                 root => 1
1677                                                              },
1678                                                              min => 'bob',
1679                                                              max => 'root',
1680                                                              cnt => 2,
1681                                                           },
1682                                                           ts => {
1683                                                              min => '071015 19:00:00',
1684                                                              max => '071015 21:43:52',
1685                                                              cnt => 2,
1686                                                              unq => {
1687                                                                 '071015 19:00:00' => 1,
1688                                                                 '071015 21:43:52' => 1,
1689                                                              },
1690                                                           },
1691                                                           Rows_sent => {
1692                                                              min => 1,
1693                                                              max => 2,
1694                                                              all => {
1695                                                                 284 => 1,
1696                                                                 298 => 1,
1697                                                              },
1698                                                              sum => 3,
1699                                                              cnt => 2,
1700                                                           },
1701                                                           Full_scan => {
1702                                                              cnt => 2,
1703                                                              max => 1,
1704                                                              min => 0,
1705                                                              sum => 1,
1706                                                              unq => {
1707                                                                 '0' => 1,
1708                                                                 '1' => 1,
1709                                                              },
1710                                                           },
1711                                                           ea1_only => {
1712                                                              min => '5',
1713                                                              max => '5',
1714                                                              all => { 317 => 1 },
1715                                                              sum => '5',
1716                                                              cnt => 1,
1717                                                           },
1718                                                           ea2_only => {
1719                                                              min => '7',
1720                                                              max => '7',
1721                                                              all => { 324 => 1 },
1722                                                              sum => '7',
1723                                                              cnt => 1,
1724                                                           },
1725                                                        },
1726                                                     },
1727                                                     globals => {
1728                                                        Query_time => {
1729                                                           min => '0.000652',
1730                                                           max => '0.000682',
1731                                                           sum => '0.001334',
1732                                                           cnt => 2,
1733                                                           all => {
1734                                                              133 => 1,
1735                                                              134 => 1,
1736                                                           },
1737                                                        },
1738                                                        user => {
1739                                                           min => 'bob',
1740                                                           max => 'root',
1741                                                           cnt => 2,
1742                                                        },
1743                                                        ts => {
1744                                                           min => '071015 19:00:00',
1745                                                           max => '071015 21:43:52',
1746                                                           cnt => 2,
1747                                                        },
1748                                                        Rows_sent => {
1749                                                           min => 1,
1750                                                           max => 2,
1751                                                           sum => 3,
1752                                                           cnt => 2,
1753                                                           all => {
1754                                                              284 => 1,
1755                                                              298 => 1,
1756                                                           },
1757                                                        },
1758                                                        Full_scan => {
1759                                                           cnt => 2,
1760                                                           max => 1,
1761                                                           min => 0,
1762                                                           sum => 1,
1763                                                        },
1764                                                        ea1_only => {
1765                                                           min => '5',
1766                                                           max => '5',
1767                                                           all => { 317 => 1 },
1768                                                           sum => '5',
1769                                                           cnt => 1,
1770                                                        },
1771                                                        ea2_only => {
1772                                                           min => '7',
1773                                                           max => '7',
1774                                                           all => { 324 => 1 },
1775                                                           sum => '7',
1776                                                           cnt => 1,
1777                                                        },
1778                                                     },
1779                                                     samples => {
1780                                                        'select id from users where name=?' => {
1781                                                           ts            => '071015 21:43:52',
1782                                                           cmd           => 'Query',
1783                                                           user          => 'bob',
1784                                                           arg           => "SELECT id FROM users WHERE name='bar'",
1785                                                           Query_time    => '0.000682',
1786                                                           Rows_sent     => 2,
1787                                                           pos_in_log    => 5,
1788                                                           fingerprint   => 'select id from users where name=?',
1789                                                           Full_scan     => 'Yes',
1790                                                           ea2_only      => 7,
1791                                                        },
1792                                                     },
1793                                                  };
1794                                                  
1795                                                  my $ea3 = EventAggregator::merge($ea1, $ea2);
1796                                                  
1797                                                  is_deeply(
1798                                                     $ea3->results,
1799                                                     $result,
1800                                                     "Merge results"
1801                                                  );
1802                                                  
1803                                                  # #############################################################################
1804                                                  # Done.
1805                                                  # #############################################################################
1806                                                  my $output = '';
1807                                                  {
1808                                                     local *STDERR;
1809                                                     open STDERR, '>', \$output;
1810                                                     $p->_d('Complete test coverage');
1811                                                  }
1812                                                  like(
1813                                                     $output,
1814                                                     qr/Complete test coverage/,
1815                                                     '_d() works'
1816                                                  );
1817                                                  exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
479          100      4      1   if ($as_hashref) { }
488          100     29     13   if ($as_hashref) { }
494          100     16     26   $max > $val ? :
495          100     26     16   $min < $val ? :
849          100      5   1302   if ($i >= $event_specs[0][2])
854          100      1   1306   unless @event_specs


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine      Count Location             
--------------- ----- ---------------------
BEGIN               1 EventAggregator.t:10 
BEGIN               1 EventAggregator.t:11 
BEGIN               1 EventAggregator.t:12 
BEGIN               1 EventAggregator.t:14 
BEGIN               1 EventAggregator.t:15 
BEGIN               1 EventAggregator.t:16 
BEGIN               1 EventAggregator.t:17 
BEGIN               1 EventAggregator.t:18 
BEGIN               1 EventAggregator.t:19 
BEGIN               1 EventAggregator.t:4  
BEGIN               1 EventAggregator.t:9  
bucketize           5 EventAggregator.t:477
generate_event   1307 EventAggregator.t:849
test_bucket_idx    18 EventAggregator.t:514
test_bucket_val     7 EventAggregator.t:502


