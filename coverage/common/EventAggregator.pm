---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...common/EventAggregator.pm   96.5   77.3   79.2   95.7    n/a  100.0   88.7
Total                          96.5   77.3   79.2   95.7    n/a  100.0   88.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          EventAggregator.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:19:40 2009
Finish:       Wed Jun 10 17:19:45 2009

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
18                                                    # EventAggregator package $Revision: 3543 $
19                                                    # ###########################################################################
20                                                    package EventAggregator;
21                                                    
22             1                    1             9   use strict;
               1                                  2   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26                                                    # ###########################################################################
27                                                    # Set up some constants for bucketing values.  It is impossible to keep all
28                                                    # values seen in memory, but putting them into logarithmically scaled buckets
29                                                    # and just incrementing the bucket each time works, although it is imprecise.
30                                                    # See http://code.google.com/p/maatkit/wiki/EventAggregatorInternals.
31                                                    # ###########################################################################
32             1                    1             6   use constant MKDEBUG      => $ENV{MKDEBUG};
               1                                  3   
               1                                  6   
33             1                    1             6   use constant BUCK_SIZE    => 1.05;
               1                                  2   
               1                                  4   
34             1                    1             6   use constant BASE_LOG     => log(BUCK_SIZE);
               1                                  2   
               1                                  4   
35             1                    1             6   use constant BASE_OFFSET  => abs(1 - log(0.000001) / BASE_LOG); # 284.1617969
               1                                  3   
               1                                  4   
36             1                    1             6   use constant NUM_BUCK     => 1000;
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
49                                                    # attributes   A hashref.  Each key is the name of an element to aggregate.
50                                                    #              And the values of those elements are arrayrefs of the
51                                                    #              values to pull from the hashref, with any second or subsequent
52                                                    #              values being fallbacks for the first in case it's not defined.
53                                                    # worst        The name of an element which defines the "worst" hashref in its
54                                                    #              class.  If this is Query_time, then each class will contain
55                                                    #              a sample that holds the event with the largest Query_time.
56                                                    # unroll_limit If this many events have been processed and some handlers haven't
57                                                    #              been generated yet (due to lack of sample data) unroll the loop
58                                                    #              anyway.  Defaults to 50.
59                                                    # attrib_limit Sanity limit for attribute values.  If the value exceeds the
60                                                    #              limit, use the last-seen for this class; if none, then 0.
61                                                    sub new {
62             9                    9           309      my ( $class, %args ) = @_;
63             9                                 71      foreach my $arg ( qw(groupby worst attributes) ) {
64    ***     27     50                         129         die "I need a $arg argument" unless $args{$arg};
65                                                       }
66                                                    
67            18                                243      return bless {
68                                                          groupby      => $args{groupby},
69                                                          attributes   => {
70            19                                 77            map  { $_ => $args{attributes}->{$_} }
71             9                                 50            grep { $_ ne $args{groupby} }
72    ***      9            50                   43            keys %{$args{attributes}}
73                                                          },
74                                                          worst        => $args{worst},
75                                                          unroll_limit => $args{unroll_limit} || 50,
76                                                          attrib_limit => $args{attrib_limit},
77                                                          result_classes => {},
78                                                          result_globals => {},
79                                                          result_samples => {},
80                                                       }, $class;
81                                                    }
82                                                    
83                                                    # Delete all collected data, but don't delete things like the generated
84                                                    # subroutines.  Resetting aggregated data is an interesting little exercise.
85                                                    # The generated functions that do aggregation have private namespaces with
86                                                    # references to some of the data.  Thus, they will not necessarily do as
87                                                    # expected if the stored data is simply wiped out.  Instead, it needs to be
88                                                    # zeroed out without replacing the actual objects.
89                                                    sub reset_aggregated_data {
90             1                    1            14      my ( $self ) = @_;
91             1                                  4      foreach my $class ( values %{$self->{result_classes}} ) {
               1                                  7   
92             1                                  6         foreach my $attrib ( values %$class ) {
93             2                                 10            delete @{$attrib}{keys %$attrib};
               2                                 42   
94                                                          }
95                                                       }
96             1                                  4      foreach my $class ( values %{$self->{result_globals}} ) {
               1                                  6   
97             2                                  8         delete @{$class}{keys %$class};
               2                                 35   
98                                                       }
99             1                                  4      delete @{$self->{result_samples}}{keys %{$self->{result_samples}}};
               1                                  5   
               1                                  6   
100                                                   }
101                                                   
102                                                   # Aggregate an event hashref's properties.  Code is built on the fly to do this,
103                                                   # based on the values being passed in.  After code is built for every attribute
104                                                   # (or 50 events are seen and we decide to give up) the little bits of code get
105                                                   # unrolled into a whole subroutine to handle events.  For that reason, you can't
106                                                   # re-use an instance.
107                                                   sub aggregate {
108         1329                 1329         18382      my ( $self, $event ) = @_;
109                                                   
110         1329                               5225      my $group_by = $event->{$self->{groupby}};
111         1329    100                        4582      return unless defined $group_by;
112                                                   
113                                                      # There might be a specially built sub that handles the work.
114         1327    100                        5350      if ( exists $self->{unrolled_loops} ) {
115         1315                               7505         return $self->{unrolled_loops}->($self, $event, $group_by);
116                                                      }
117                                                   
118           12                                 36      my @attrs = sort keys %{$self->{attributes}};
              12                                127   
119                                                      ATTRIB:
120           12                                 49      foreach my $attrib ( @attrs ) {
121                                                         # The value of the attribute ( $group_by ) may be an arrayref.
122                                                         GROUPBY:
123           29    100                         135         foreach my $val ( ref $group_by ? @$group_by : ($group_by) ) {
124           30           100                  302            my $class_attrib  = $self->{result_classes}->{$val}->{$attrib} ||= {};
125           30           100                  213            my $global_attrib = $self->{result_globals}->{$attrib} ||= {};
126           30                                102            my $samples       = $self->{result_samples};
127           30                                110            my $handler = $self->{handlers}->{ $attrib };
128           30    100                         118            if ( !$handler ) {
129           21                                162               $handler = $self->make_handler(
130                                                                  $attrib,
131                                                                  $event,
132                                                                  wor => $self->{worst} eq $attrib,
133                                                                  alt => $self->{attributes}->{$attrib},
134                                                               );
135           21                                 99               $self->{handlers}->{$attrib} = $handler;
136                                                            }
137           30    100                         124            next GROUPBY unless $handler;
138           27           100                  135            $samples->{$val} ||= $event; # Initialize to the first event.
139           27                                118            $handler->($event, $class_attrib, $global_attrib, $samples, $group_by);
140                                                         }
141                                                      }
142                                                   
143                                                      # Figure out whether we are ready to generate a faster version.
144   ***     12    100     66                  107      if ( $self->{n_queries}++ > 50 # Give up waiting after 50 events.
              29                                194   
145                                                         || !grep {ref $self->{handlers}->{$_} ne 'CODE'} @attrs
146                                                      ) {
147                                                         # All attributes have handlers, so let's combine them into one faster sub.
148                                                         # Start by getting direct handles to the location of each data store and
149                                                         # thing that would otherwise be looked up via hash keys.
150            9                                 34         my @attrs = grep { $self->{handlers}->{$_} } @attrs;
              18                                 87   
151            9                                 35         my $globs = $self->{result_globals}; # Global stats for each
152            9                                 33         my $samples = $self->{result_samples};
153                                                   
154                                                         # Now the tricky part -- must make sure only the desired variables from
155                                                         # the outer scope are re-used, and any variables that should have their
156                                                         # own scope are declared within the subroutine.
157            9    100                          64         my @lines = (
158                                                            'my ( $self, $event, $group_by ) = @_;',
159                                                            'my ($val, $class, $global, $idx);',
160                                                            (ref $group_by ? ('foreach my $group_by ( @$group_by ) {') : ()),
161                                                            # Create and get each attribute's storage
162                                                            'my $temp = $self->{result_classes}->{ $group_by }
163                                                               ||= { map { $_ => { } } @attrs };',
164                                                            '$samples->{$group_by} ||= $event;', # Always start with the first.
165                                                         );
166            9                                 62         foreach my $i ( 0 .. $#attrs ) {
167                                                            # Access through array indexes, it's faster than hash lookups
168           18                                160            push @lines, (
169                                                               '$class  = $temp->{"'  . $attrs[$i] . '"};',
170                                                               '$global = $globs->{"' . $attrs[$i] . '"};',
171                                                               $self->{unrolled_for}->{$attrs[$i]},
172                                                            );
173                                                         }
174            9    100                          41         if ( ref $group_by ) {
175            1                                  4            push @lines, '}'; # Close the loop opened above
176                                                         }
177            9                                 34         @lines = map { s/^/   /gm; $_ } @lines; # Indent for debugging
              92                                504   
              92                                337   
178            9                                 43         unshift @lines, 'sub {';
179            9                                 31         push @lines, '}';
180                                                   
181                                                         # Make the subroutine
182            9                                 63         my $code = join("\n", @lines);
183            9                                 21         MKDEBUG && _d('Unrolled subroutine:', @lines);
184            9                               3095         my $sub = eval $code;
185   ***      9     50                          40         die if $EVAL_ERROR;
186            9                                 76         $self->{unrolled_loops} = $sub;
187                                                      }
188                                                   }
189                                                   
190                                                   # Return the aggregated results.
191                                                   sub results {
192           13                   13          5956      my ( $self ) = @_;
193                                                      return {
194           13                                212         classes => $self->{result_classes},
195                                                         globals => $self->{result_globals},
196                                                         samples => $self->{result_samples},
197                                                      };
198                                                   }
199                                                   
200                                                   # Return the attributes that this object is tracking, and their data types, as
201                                                   # a hashref of name => type.
202                                                   sub attributes {
203            1                    1             4      my ( $self ) = @_;
204            1                                 10      return $self->{type_for};
205                                                   }
206                                                   
207                                                   # Returns the type of the attribute (as decided by the aggregation process,
208                                                   # which inspects the values).
209                                                   sub type_for {
210            2                    2            16      my ( $self, $attrib ) = @_;
211            2                                 18      return $self->{type_for}->{$attrib};
212                                                   }
213                                                   
214                                                   # Make subroutines that do things with events.
215                                                   #
216                                                   # $attrib: the name of the attrib (Query_time, Rows_read, etc)
217                                                   # $event:  a sample event
218                                                   # %args:
219                                                   #     min => keep min for this attrib (default except strings)
220                                                   #     max => keep max (default except strings)
221                                                   #     sum => keep sum (default for numerics)
222                                                   #     cnt => keep count (default except strings)
223                                                   #     unq => keep all unique values per-class (default for strings and bools)
224                                                   #     all => keep a bucketed list of values seen per class (default for numerics)
225                                                   #     glo => keep stats globally as well as per-class (default)
226                                                   #     trf => An expression to transform the value before working with it
227                                                   #     wor => Whether to keep worst-samples for this attrib (default no)
228                                                   #     alt => Arrayref of other name(s) for the attribute, like db => Schema.
229                                                   #
230                                                   # The bucketed list works this way: each range of values from MIN_BUCK in
231                                                   # increments of BUCK_SIZE (that is 5%) we consider a bucket.  We keep NUM_BUCK
232                                                   # buckets.  The upper end of the range is more than 1.5e15 so it should be big
233                                                   # enough for almost anything.  The buckets are accessed by a log base BUCK_SIZE,
234                                                   # so floor(log(N)/log(BUCK_SIZE)).  The smallest bucket's index is -284. We
235                                                   # shift all values up 284 so we have values from 0 to 999 that can be used as
236                                                   # array indexes.  A value that falls into a bucket simply increments the array
237                                                   # entry.  We do NOT use POSIX::floor() because it is too expensive.
238                                                   #
239                                                   # This eliminates the need to keep and sort all values to calculate median,
240                                                   # standard deviation, 95th percentile etc.  Thus the memory usage is bounded by
241                                                   # the number of distinct aggregated values, not the number of events.
242                                                   #
243                                                   # Return value:
244                                                   # a subroutine with this signature:
245                                                   #    my ( $event, $class, $global ) = @_;
246                                                   # where
247                                                   #  $event   is the event
248                                                   #  $class   is the container to store the aggregated values
249                                                   #  $global  is is the container to store the globally aggregated values
250                                                   sub make_handler {
251           21                   21           137      my ( $self, $attrib, $event, %args ) = @_;
252   ***     21     50                          99      die "I need an attrib" unless defined $attrib;
253           21                                 70      my ($val) = grep { defined $_ } map { $event->{$_} } @{ $args{alt} };
              22                                 83   
              22                                 94   
              21                                 80   
254           21                                 69      my $is_array = 0;
255   ***     21     50                          94      if (ref $val eq 'ARRAY') {
256   ***      0                                  0         $is_array = 1;
257   ***      0                                  0         $val      = $val->[0];
258                                                      }
259           21    100                          78      return unless defined $val; # Can't decide type if it's undef.
260                                                   
261                                                      # Ripped off from Regexp::Common::number and modified.
262           18                                123      my $float_re = qr{[+-]?(?:(?=\d|[.])\d+(?:[.])\d{0,})(?:E[+-]?\d+)?}i;
263   ***     18     50                         245      my $type = $val  =~ m/^(?:\d+|$float_re)$/o ? 'num'
                    100                               
264                                                               : $val  =~ m/^(?:Yes|No)$/         ? 'bool'
265                                                               :                                    'string';
266           18                                 40      MKDEBUG && _d('Type for', $attrib, 'is', $type,
267                                                         '(sample:', $val, '), is array:', $is_array);
268           18                                 87      $self->{type_for}->{$attrib} = $type;
269                                                   
270           18    100                         418      %args = ( # Set up defaults
                    100                               
                    100                               
      ***            50                               
271                                                         min => 1,
272                                                         max => 1,
273                                                         sum => $type =~ m/num|bool/    ? 1 : 0,
274                                                         cnt => 1,
275                                                         unq => $type =~ m/bool|string/ ? 1 : 0,
276                                                         all => $type eq 'num'          ? 1 : 0,
277                                                         glo => 1,
278                                                         trf => ($type eq 'bool') ? q{($val || '' eq 'Yes') ? 1 : 0} : undef,
279                                                         wor => 0,
280                                                         alt => [],
281                                                         %args,
282                                                      );
283                                                   
284           18                                112      my @lines = ("# type: $type"); # Lines of code for the subroutine
285   ***     18     50                          79      if ( $args{trf} ) {
286   ***      0                                  0         push @lines, q{$val = } . $args{trf} . ';';
287                                                      }
288                                                   
289           18                                 64      foreach my $place ( qw($class $global) ) {
290           36                                 84         my @tmp;
291   ***     36     50                         154         if ( $args{min} ) {
292           36    100                         182            my $op   = $type eq 'num' ? '<' : 'lt';
293           36                                185            push @tmp, (
294                                                               'PLACE->{min} = $val if !defined PLACE->{min} || $val '
295                                                                  . $op . ' PLACE->{min};',
296                                                            );
297                                                         }
298   ***     36     50                         142         if ( $args{max} ) {
299           36    100                         137            my $op = ($type eq 'num') ? '>' : 'gt';
300           36                                147            push @tmp, (
301                                                               'PLACE->{max} = $val if !defined PLACE->{max} || $val '
302                                                                  . $op . ' PLACE->{max};',
303                                                            );
304                                                         }
305           36    100                         165         if ( $args{sum} ) {
306           22                                 69            push @tmp, 'PLACE->{sum} += $val;';
307                                                         }
308   ***     36     50                         130         if ( $args{cnt} ) {
309           36                                113            push @tmp, '++PLACE->{cnt};';
310                                                         }
311           36    100                         155         if ( $args{all} ) {
312           22                                 81            push @tmp, (
313                                                               'exists PLACE->{all} or PLACE->{all} = [ @buckets ];',
314                                                               '++PLACE->{all}->[ EventAggregator::bucket_idx($val) ];',
315                                                            );
316                                                         }
317           36                                115         push @lines, map { s/PLACE/$place/g; $_ } @tmp;
             174                                850   
             174                                620   
318                                                      }
319                                                   
320                                                      # We only save unique/worst values for the class, not globally.
321           18    100                          80      if ( $args{unq} ) {
322            7                                 27         push @lines, '++$class->{unq}->{$val};';
323                                                      }
324           18    100                          73      if ( $args{wor} ) {
325   ***      4     50                          24         my $op = $type eq 'num' ? '>=' : 'ge';
326            4                                 21         push @lines, (
327                                                            'if ( $val ' . $op . ' ($class->{max} || 0) ) {',
328                                                            '   $samples->{$group_by} = $event;',
329                                                            '}',
330                                                         );
331                                                      }
332                                                   
333                                                      # Make sure the value is constrained to legal limits.  If it's out of bounds,
334                                                      # just use the last-seen value for it.
335           18                                 50      my @limit;
336   ***     18    100     66                  243      if ( $args{all} && $type eq 'num' && $self->{attrib_limit} ) {
                           100                        
337            1                                  8         push @limit, (
338                                                            "if ( \$val > $self->{attrib_limit} ) {",
339                                                            '   $val = $class->{last} ||= 0;',
340                                                            '}',
341                                                            '$class->{last} = $val;',
342                                                         );
343                                                      }
344                                                   
345                                                      # Save the code for later, as part of an "unrolled" subroutine.
346            1                                  7      my @unrolled = (
347                                                         "\$val = \$event->{'$attrib'};",
348                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
349           19                                 88         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
350           18                                 73            grep { $_ ne $attrib } @{$args{alt}}),
             215                                756   
351                                                         'defined $val && do {',
352   ***     18     50                          91         ( map { s/^/   /gm; $_ } (@limit, @lines) ), # Indent for debugging
      ***    215     50                        1386   
353                                                         '};',
354                                                         ($is_array ? ('}') : ()),
355                                                      );
356           18                                202      $self->{unrolled_for}->{$attrib} = join("\n", @unrolled);
357                                                   
358                                                      # Build a subroutine with the code.
359            1                                  9      unshift @lines, (
360                                                         'sub {',
361                                                         'my ( $event, $class, $global, $samples, $group_by ) = @_;',
362                                                         'my ($val, $idx);', # NOTE: define all variables here
363                                                         "\$val = \$event->{'$attrib'};",
364           19                                144         (map { "\$val = \$event->{'$_'} unless defined \$val;" }
365   ***     18     50                          84            grep { $_ ne $attrib } @{$args{alt}}),
      ***     18     50                          71   
366                                                         'return unless defined $val;',
367                                                         ($is_array ? ('foreach my $val ( @$val ) {') : ()),
368                                                         @limit,
369                                                         ($is_array ? ('}') : ()),
370                                                      );
371           18                                 56      push @lines, '}';
372           18                                120      my $code = join("\n", @lines);
373           18                                 85      $self->{code_for}->{$attrib} = $code;
374                                                   
375           18                                 37      MKDEBUG && _d('Metric handler for', $attrib, ':', @lines);
376           18                               3628      my $sub = eval join("\n", @lines);
377   ***     18     50                          74      die if $EVAL_ERROR;
378           18                                221      return $sub;
379                                                   }
380                                                   
381                                                   # Returns the bucket number for the given val. Buck numbers are zero-indexed,
382                                                   # so although there are 1,000 buckets (NUM_BUCK), 999 is the greatest idx.
383                                                   # *** Notice that this sub is not a class method, so either call it
384                                                   # from inside this module like bucket_idx() or outside this module
385                                                   # like EventAggregator::bucket_idx(). ***
386                                                   # TODO: could export this by default to avoid having to specific packge::.
387                                                   sub bucket_idx {
388         2738                 2738         17914      my ( $val ) = @_;
389         2738    100                       10418      return 0 if $val < MIN_BUCK;
390         2728                              10206      my $idx = int(BASE_OFFSET + log($val)/BASE_LOG);
391         2728    100                       16243      return $idx > (NUM_BUCK-1) ? (NUM_BUCK-1) : $idx;
392                                                   }
393                                                   
394                                                   # Returns the value for the given bucket.
395                                                   # The value of each bucket is the first value that it covers. So the value
396                                                   # of bucket 1 is 0.000001000 because it covers [0.000001000, 0.000001050).
397                                                   #
398                                                   # *** Notice that this sub is not a class method, so either call it
399                                                   # from inside this module like bucket_idx() or outside this module
400                                                   # like EventAggregator::bucket_value(). ***
401                                                   # TODO: could export this by default to avoid having to specific packge::.
402                                                   sub bucket_value {
403         1007                 1007          2995      my ( $bucket ) = @_;
404         1007    100                        3553      return 0 if $bucket == 0;
405   ***   1005     50     33                 7375      die "Invalid bucket: $bucket" if $bucket < 0 || $bucket > (NUM_BUCK-1);
406                                                      # $bucket - 1 because buckets are shifted up by 1 to handle zero values.
407         1005                               4687      return (BUCK_SIZE**($bucket-1)) * MIN_BUCK;
408                                                   }
409                                                   
410                                                   # Map the 1,000 base 1.05 buckets to 8 base 10 buckets. Returns an array
411                                                   # of 1,000 buckets, the value of each represents its index in an 8 bucket
412                                                   # base 10 array. For example: base 10 bucket 0 represents vals (0, 0.000010),
413                                                   # and base 1.05 buckets 0..47 represent vals (0, 0.000010401). So the first
414                                                   # 48 elements of the returned array will have 0 as their values. 
415                                                   # TODO: right now it's hardcoded to buckets of 10, in the future maybe not.
416                                                   {
417                                                      my @buck_tens;
418                                                      sub buckets_of {
419   ***      1     50             1             6         return @buck_tens if @buck_tens;
420                                                   
421                                                         # To make a more precise map, we first set the starting values for
422                                                         # each of the 8 base 10 buckets. 
423            1                                  3         my $start_bucket  = 0;
424            1                                  4         my @base10_starts = (0);
425            1                                  4         map { push @base10_starts, (10**$_)*MIN_BUCK } (1..7);
               7                                 29   
426                                                   
427                                                         # Then find the base 1.05 buckets that correspond to each
428                                                         # base 10 bucket. The last value in each bucket's range belongs
429                                                         # to the next bucket, so $next_bucket-1 represents the real last
430                                                         # base 1.05 bucket in which the base 10 bucket's range falls.
431            1                                  7         for my $base10_bucket ( 0..($#base10_starts-1) ) {
432            7                                 28            my $next_bucket = bucket_idx( $base10_starts[$base10_bucket+1] );
433            7                                 15            MKDEBUG && _d('Base 10 bucket $base10_bucket maps to',
434                                                               'base 1.05 buckets', $start_bucket, '..', $next_bucket-1);
435            7                                 25            for my $base1_05_bucket ($start_bucket..($next_bucket-1)) {
436          331                               1016               $buck_tens[$base1_05_bucket] = $base10_bucket;
437                                                            }
438            7                                 25            $start_bucket = $next_bucket;
439                                                         }
440                                                   
441                                                         # Map all remaining base 1.05 buckets to base 10 bucket 7 which
442                                                         # is for vals > 10.
443            1                                 31         map { $buck_tens[$_] = 7 } ($start_bucket..(NUM_BUCK-1));
             669                               2122   
444                                                   
445            1                                124         return @buck_tens;
446                                                      }
447                                                   }
448                                                   
449                                                   # Given an arrayref of vals, returns a hashref with the following
450                                                   # statistical metrics:
451                                                   #
452                                                   #    pct_95    => top bucket value in the 95th percentile
453                                                   #    cutoff    => How many values fall into the 95th percentile
454                                                   #    stddev    => of all values
455                                                   #    median    => of all values
456                                                   #
457                                                   # The vals arrayref is the buckets as per the above (see the comments at the top
458                                                   # of this file).  $args should contain cnt, min and max properties.
459                                                   sub calculate_statistical_metrics {
460           17                   17          4555      my ( $self, $vals, $args ) = @_;
461           17                                105      my $statistical_metrics = {
462                                                         pct_95    => 0,
463                                                         stddev    => 0,
464                                                         median    => 0,
465                                                         cutoff    => undef,
466                                                      };
467                                                   
468                                                      # These cases might happen when there is nothing to get from the event, for
469                                                      # example, processlist sniffing doesn't gather Rows_examined, so $args won't
470                                                      # have {cnt} or other properties.
471           17    100    100                  223      return $statistical_metrics
                           100                        
472                                                         unless defined $vals && @$vals && $args->{cnt};
473                                                   
474                                                      # Return accurate metrics for some cases.
475           13                                 45      my $n_vals = $args->{cnt};
476           13    100    100                  135      if ( $n_vals == 1 || $args->{max} == $args->{min} ) {
                    100                               
477   ***      7            50                   32         my $v      = $args->{max} || 0;
478   ***      7     50                          41         my $bucket = int(6 + ( log($v > 0 ? $v : MIN_BUCK) / log(10)));
479   ***      7     50                          36         $bucket    = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
480                                                         return {
481            7                                 48            pct_95 => $v,
482                                                            stddev => 0,
483                                                            median => $v,
484                                                            cutoff => $n_vals,
485                                                         };
486                                                      }
487                                                      elsif ( $n_vals == 2 ) {
488            1                                  6         foreach my $v ( $args->{min}, $args->{max} ) {
489   ***      2     50     33                   23            my $bucket = int(6 + ( log($v && $v > 0 ? $v : MIN_BUCK) / log(10)));
490   ***      2     50                          14            $bucket = $bucket > 7 ? 7 : $bucket < 0 ? 0 : $bucket;
      ***            50                               
491                                                         }
492   ***      1            50                    8         my $v      = $args->{max} || 0;
493   ***      1            50                    6         my $mean = (($args->{min} || 0) + $v) / 2;
494                                                         return {
495            1                                 14            pct_95 => $v,
496                                                            stddev => sqrt((($v - $mean) ** 2) *2),
497                                                            median => $mean,
498                                                            cutoff => $n_vals,
499                                                         };
500                                                      }
501                                                   
502                                                      # Determine cutoff point for 95% if there are at least 10 vals.  Cutoff
503                                                      # serves also for the number of vals left in the 95%.  E.g. with 50 vals the
504                                                      # cutoff is 47 which means there are 47 vals: 0..46.  $cutoff is NOT an array
505                                                      # index.
506            5    100                          31      my $cutoff = $n_vals >= 10 ? int ( $n_vals * 0.95 ) : $n_vals;
507            5                                 19      $statistical_metrics->{cutoff} = $cutoff;
508                                                   
509                                                      # Calculate the standard deviation and median of all values.
510            5                                 15      my $total_left = $n_vals;
511            5                                 17      my $top_vals   = $n_vals - $cutoff; # vals > 95th
512            5                                 12      my $sum_excl   = 0;
513            5                                 14      my $sum        = 0;
514            5                                 14      my $sumsq      = 0;
515            5                                 19      my $mid        = int($n_vals / 2);
516            5                                 15      my $median     = 0;
517            5                                 13      my $prev       = NUM_BUCK-1; # Used for getting median when $cutoff is odd
518            5                                 14      my $bucket_95  = 0; # top bucket in 95th
519                                                   
520            5                                 12      MKDEBUG && _d('total vals:', $total_left, 'top vals:', $top_vals, 'mid:', $mid);
521                                                   
522                                                      BUCKET:
523            5                                 37      for my $bucket ( reverse 0..(NUM_BUCK-1) ) {
524         5000                              15066         my $val = $vals->[$bucket];
525         5000    100                       18218         next BUCKET unless $val; 
526                                                   
527           19                                 52         $total_left -= $val;
528           19                                 47         $sum_excl   += $val;
529           19    100    100                  134         $bucket_95   = $bucket if !$bucket_95 && $sum_excl > $top_vals;
530                                                   
531           19    100    100                  130         if ( !$median && $total_left <= $mid ) {
532   ***      5     50     66                   48            $median = (($cutoff % 2) || ($val > 1)) ? $buck_vals[$bucket]
533                                                                    : ($buck_vals[$bucket] + $buck_vals[$prev]) / 2;
534                                                         }
535                                                   
536           19                                 69         $sum    += $val * $buck_vals[$bucket];
537           19                                 73         $sumsq  += $val * ($buck_vals[$bucket]**2);
538           19                                 60         $prev   =  $bucket;
539                                                      }
540                                                   
541            5                                 37      my $var      = $sumsq/$n_vals - ( ($sum/$n_vals) ** 2 );
542            5    100                          34      my $stddev   = $var > 0 ? sqrt($var) : 0;
543   ***      5            50                   48      my $maxstdev = (($args->{max} || 0) - ($args->{min} || 0)) / 2;
                           100                        
544   ***      5     50                          20      $stddev      = $stddev > $maxstdev ? $maxstdev : $stddev;
545                                                   
546            5                                 13      MKDEBUG && _d('sum:', $sum, 'sumsq:', $sumsq, 'stddev:', $stddev,
547                                                         'median:', $median, 'prev bucket:', $prev,
548                                                         'total left:', $total_left, 'sum excl', $sum_excl,
549                                                         'bucket 95:', $bucket_95, $buck_vals[$bucket_95]);
550                                                   
551            5                                 22      $statistical_metrics->{stddev} = $stddev;
552            5                                 21      $statistical_metrics->{pct_95} = $buck_vals[$bucket_95];
553            5                                 15      $statistical_metrics->{median} = $median;
554                                                   
555            5                                 31      return $statistical_metrics;
556                                                   }
557                                                   
558                                                   # Return a hashref of the metrics for some attribute, pre-digested.
559                                                   # %args is:
560                                                   #  attrib => the attribute to report on
561                                                   #  where  => the value of the fingerprint for the attrib
562                                                   sub metrics {
563            2                    2            13      my ( $self, %args ) = @_;
564            2                                  9      foreach my $arg ( qw(attrib where) ) {
565   ***      4     50                          20         die "I need a $arg argument" unless $args{$arg};
566                                                      }
567            2                                  8      my $stats = $self->results;
568            2                                 13      my $store = $stats->{classes}->{$args{where}}->{$args{attrib}};
569                                                   
570            2                                 10      my $global_cnt = $stats->{globals}->{$args{attrib}}->{cnt};
571            2                                 12      my $metrics    = $self->calculate_statistical_metrics($store->{all}, $store);
572                                                   
573                                                      return {
574   ***      2    100     66                   73         cnt    => $store->{cnt},
      ***           100     66                        
575                                                         pct    => $global_cnt && $store->{cnt} ? $store->{cnt} / $global_cnt : 0,
576                                                         sum    => $store->{sum},
577                                                         min    => $store->{min},
578                                                         max    => $store->{max},
579                                                         avg    => $store->{sum} && $store->{cnt} ? $store->{sum} / $store->{cnt} : 0,
580                                                         median => $metrics->{median},
581                                                         pct_95 => $metrics->{pct_95},
582                                                         stddev => $metrics->{stddev},
583                                                      };
584                                                   }
585                                                   
586                                                   # Find the top N or top % event keys, in sorted order, optionally including
587                                                   # outliers (ol_...) that are notable for some reason.  %args looks like this:
588                                                   #
589                                                   #  attrib      order-by attribute (usually Query_time)
590                                                   #  orderby     order-by aggregate expression (should be numeric, usually sum)
591                                                   #  total       include events whose summed attribs are <= this number...
592                                                   #  count       ...or this many events, whichever is less...
593                                                   #  ol_attrib   ...or events where the 95th percentile of this attribute...
594                                                   #  ol_limit    ...is greater than this value, AND...
595                                                   #  ol_freq     ...the event occurred at least this many times.
596                                                   # The return value is a list of arrayrefs.  Each arrayref is the event key and
597                                                   # an explanation of why it was included (top|outlier).
598                                                   sub top_events {
599            3                    3            53      my ( $self, %args ) = @_;
600            3                                 12      my $classes = $self->{result_classes};
601           15                                 98      my @sorted = reverse sort { # Sorted list of $groupby values
602           16                                 75         $classes->{$a}->{$args{attrib}}->{$args{orderby}}
603                                                            <=> $classes->{$b}->{$args{attrib}}->{$args{orderby}}
604                                                         } grep {
605                                                            # Defensive programming
606            3                                 16            defined $classes->{$_}->{$args{attrib}}->{$args{orderby}}
607                                                         } keys %$classes;
608            3                                 20      my @chosen;
609            3                                 11      my ($total, $count) = (0, 0);
610            3                                 10      foreach my $groupby ( @sorted ) {
611                                                         # Events that fall into the top criterion for some reason
612           15    100    100                  242         if ( 
      ***           100     66                        
                           100                        
                           100                        
                           100                        
613                                                            (!$args{total} || $total < $args{total} )
614                                                            && ( !$args{count} || $count < $args{count} )
615                                                         ) {
616            6                                 31            push @chosen, [$groupby, 'top'];
617                                                         }
618                                                   
619                                                         # Events that are notable outliers
620                                                         elsif ( $args{ol_attrib} && (!$args{ol_freq}
621                                                            || $classes->{$groupby}->{$args{ol_attrib}}->{cnt} >= $args{ol_freq})
622                                                         ) {
623                                                            # Calculate the 95th percentile of this event's specified attribute.
624            5                                 11            MKDEBUG && _d('Calculating statistical_metrics');
625            5                                 39            my $stats = $self->calculate_statistical_metrics(
626                                                               $classes->{$groupby}->{$args{ol_attrib}}->{all},
627                                                               $classes->{$groupby}->{$args{ol_attrib}}
628                                                            );
629            5    100                          28            if ( $stats->{pct_95} >= $args{ol_limit} ) {
630            3                                 16               push @chosen, [$groupby, 'outlier'];
631                                                            }
632                                                         }
633                                                   
634           15                                 74         $total += $classes->{$groupby}->{$args{attrib}}->{$args{orderby}};
635           15                                 42         $count++;
636                                                      }
637            3                                 26      return @chosen;
638                                                   }
639                                                   
640                                                   sub _d {
641   ***      0                    0                    my ($package, undef, $line) = caller 0;
642   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
643   ***      0                                              map { defined $_ ? $_ : 'undef' }
644                                                           @_;
645   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
646                                                   }
647                                                   
648                                                   1;
649                                                   
650                                                   # ###########################################################################
651                                                   # End EventAggregator package
652                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
64    ***     50      0     27   unless $args{$arg}
111          100      2   1327   unless defined $group_by
114          100   1315     12   if (exists $$self{'unrolled_loops'})
123          100      1     28   ref $group_by ? :
128          100     21      9   if (not $handler)
137          100      3     27   unless $handler
144          100      9      3   if ($$self{'n_queries'}++ > 50 or not grep {ref $$self{'handlers'}{$_} ne 'CODE';} @attrs)
157          100      1      8   ref $group_by ? :
174          100      1      8   if (ref $group_by)
185   ***     50      0      9   if $EVAL_ERROR
252   ***     50      0     21   unless defined $attrib
255   ***     50      0     21   if (ref $val eq 'ARRAY')
259          100      3     18   unless defined $val
263   ***     50      0      7   $val =~ /^(?:Yes|No)$/ ? :
             100     11      7   $val =~ /^(?:\d+|$float_re)$/o ? :
270          100     11      7   $type =~ /num|bool/ ? :
             100      7     11   $type =~ /bool|string/ ? :
             100     11      7   $type eq 'num' ? :
      ***     50      0     18   $type eq 'bool' ? :
285   ***     50      0     18   if ($args{'trf'})
291   ***     50     36      0   if ($args{'min'})
292          100     22     14   $type eq 'num' ? :
298   ***     50     36      0   if ($args{'max'})
299          100     22     14   $type eq 'num' ? :
305          100     22     14   if ($args{'sum'})
308   ***     50     36      0   if ($args{'cnt'})
311          100     22     14   if ($args{'all'})
321          100      7     11   if ($args{'unq'})
324          100      4     14   if ($args{'wor'})
325   ***     50      4      0   $type eq 'num' ? :
336          100      1     17   if ($args{'all'} and $type eq 'num' and $$self{'attrib_limit'})
352   ***     50      0     18   $is_array ? :
      ***     50      0     18   $is_array ? :
365   ***     50      0     18   $is_array ? :
      ***     50      0     18   $is_array ? :
377   ***     50      0     18   if $EVAL_ERROR
389          100     10   2728   if $val < 1e-06
391          100      1   2727   $idx > 999 ? :
404          100      2   1005   if $bucket == 0
405   ***     50      0   1005   if $bucket < 0 or $bucket > 999
419   ***     50      0      1   if @buck_tens
471          100      4     13   unless defined $vals and @$vals and $$args{'cnt'}
476          100      7      6   if ($n_vals == 1 or $$args{'max'} == $$args{'min'}) { }
             100      1      5   elsif ($n_vals == 2) { }
478   ***     50      7      0   $v > 0 ? :
479   ***     50      0      7   $bucket < 0 ? :
      ***     50      0      7   $bucket > 7 ? :
489   ***     50      2      0   $v && $v > 0 ? :
490   ***     50      0      2   $bucket < 0 ? :
      ***     50      0      2   $bucket > 7 ? :
506          100      4      1   $n_vals >= 10 ? :
525          100   4981     19   unless $val
529          100      5     14   if not $bucket_95 and $sum_excl > $top_vals
531          100      5     14   if (not $median and $total_left <= $mid)
532   ***     50      5      0   $cutoff % 2 || $val > 1 ? :
542          100      3      2   $var > 0 ? :
544   ***     50      0      5   $stddev > $maxstdev ? :
565   ***     50      0      4   unless $args{$arg}
574          100      1      1   $global_cnt && $$store{'cnt'} ? :
             100      1      1   $$store{'sum'} && $$store{'cnt'} ? :
612          100      6      9   if (!$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}) { }
             100      5      4   elsif ($args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}) { }
629          100      3      2   if ($$stats{'pct_95'} >= $args{'ol_limit'})
642   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
336   ***     66      7      0     11   $args{'all'} and $type eq 'num'
             100      7     10      1   $args{'all'} and $type eq 'num' and $$self{'attrib_limit'}
471          100      2      1     14   defined $vals and @$vals
             100      3      1     13   defined $vals and @$vals and $$args{'cnt'}
489   ***     33      0      0      2   $v && $v > 0
529          100     11      3      5   not $bucket_95 and $sum_excl > $top_vals
531          100      5      9      5   not $median and $total_left <= $mid
574   ***     66      1      0      1   $global_cnt && $$store{'cnt'}
      ***     66      1      0      1   $$store{'sum'} && $$store{'cnt'}
612          100      6      3      6   !$args{'total'} || $total < $args{'total'} and !$args{'count'} || $count < $args{'count'}
             100      3      1      5   $args{'ol_attrib'} and !$args{'ol_freq'} || $$classes{$groupby}{$args{'ol_attrib'}}{'cnt'} >= $args{'ol_freq'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
72    ***     50      0      9   $args{'unroll_limit'} || 50
124          100      3     27   $$self{'result_classes'}{$val}{$attrib} ||= {}
125          100     12     18   $$self{'result_globals'}{$attrib} ||= {}
138          100     15     12   $$samples{$val} ||= $event
477   ***     50      7      0   $$args{'max'} || 0
492   ***     50      1      0   $$args{'max'} || 0
493   ***     50      1      0   $$args{'min'} || 0
543   ***     50      5      0   $$args{'max'} || 0
             100      4      1   $$args{'min'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
144   ***     66      0      9      3   $$self{'n_queries'}++ > 50 or not grep {ref $$self{'handlers'}{$_} ne 'CODE';} @attrs
405   ***     33      0      0   1005   $bucket < 0 or $bucket > 999
476          100      3      4      6   $n_vals == 1 or $$args{'max'} == $$args{'min'}
532   ***     66      2      3      0   $cutoff % 2 || $val > 1
612          100      5      4      6   !$args{'total'} || $total < $args{'total'}
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
aggregate                      1329 /home/daniel/dev/maatkit/common/EventAggregator.pm:108
attributes                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:203
bucket_idx                     2738 /home/daniel/dev/maatkit/common/EventAggregator.pm:388
bucket_value                   1007 /home/daniel/dev/maatkit/common/EventAggregator.pm:403
buckets_of                        1 /home/daniel/dev/maatkit/common/EventAggregator.pm:419
calculate_statistical_metrics    17 /home/daniel/dev/maatkit/common/EventAggregator.pm:460
make_handler                     21 /home/daniel/dev/maatkit/common/EventAggregator.pm:251
metrics                           2 /home/daniel/dev/maatkit/common/EventAggregator.pm:563
new                               9 /home/daniel/dev/maatkit/common/EventAggregator.pm:62 
reset_aggregated_data             1 /home/daniel/dev/maatkit/common/EventAggregator.pm:90 
results                          13 /home/daniel/dev/maatkit/common/EventAggregator.pm:192
top_events                        3 /home/daniel/dev/maatkit/common/EventAggregator.pm:599
type_for                          2 /home/daniel/dev/maatkit/common/EventAggregator.pm:210

Uncovered Subroutines
---------------------

Subroutine                    Count Location                                              
----------------------------- ----- ------------------------------------------------------
_d                                0 /home/daniel/dev/maatkit/common/EventAggregator.pm:641


