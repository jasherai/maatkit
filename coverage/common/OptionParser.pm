---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/OptionParser.pm   93.6   83.1   91.4   94.7    n/a  100.0   90.2
Total                          93.6   83.1   91.4   94.7    n/a  100.0   90.2
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          OptionParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Jun 13 19:36:52 2009
Finish:       Sat Jun 13 19:36:53 2009

/home/daniel/dev/maatkit/common/OptionParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2009 Baron Schwartz.
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
18                                                    # OptionParser package $Revision: 3695 $
19                                                    # ###########################################################################
20                                                    package OptionParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             9   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24                                                    
25             1                    1            10   use Getopt::Long;
               1                                  3   
               1                                  9   
26             1                    1             9   use List::Util qw(max);
               1                                  2   
               1                                 12   
27             1                    1             7   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
28                                                    
29             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
30                                                    
31                                                    my $POD_link_re = '[LC]<"?([^">]+)"?>';
32                                                    
33                                                    my %attributes = (
34                                                       'type'       => 1,
35                                                       'short form' => 1,
36                                                       'group'      => 1,
37                                                       'default'    => 1,
38                                                       'cumulative' => 1,
39                                                       'negatable'  => 1,
40                                                    );
41                                                    
42                                                    sub new {
43            33                   33           241      my ( $class, %args ) = @_;
44            33                                135      foreach my $arg ( qw(description) ) {
45    ***     33     50                         201         die "I need a $arg argument" unless $args{$arg};
46                                                       }
47            33                                296      my ($program_name) = $PROGRAM_NAME =~ m/([.A-Za-z-]+)$/;
48    ***     33            50                  136      $program_name ||= $PROGRAM_NAME;
49                                                    
50            33    100    100                 1358      my $self = {
                           100                        
51                                                          description    => $args{description},
52                                                          prompt         => $args{prompt} || '<options>',
53                                                          strict         => (exists $args{strict} ? $args{strict} : 1),
54                                                          dp             => $args{dp}     || undef,
55                                                          program_name   => $program_name,
56                                                          opts           => {},
57                                                          got_opts       => 0,
58                                                          short_opts     => {},
59                                                          defaults       => {},
60                                                          groups         => {},
61                                                          allowed_groups => {},
62                                                          errors         => [],
63                                                          rules          => [],  # desc of rules for --help
64                                                          mutex          => [],  # rule: opts are mutually exclusive
65                                                          atleast1       => [],  # rule: at least one opt is required
66                                                          disables       => {},  # rule: opt disables other opts 
67                                                          defaults_to    => {},  # rule: opt defaults to value of other opt
68                                                          default_files  => [
69                                                             "/etc/maatkit/maatkit.conf",
70                                                             "/etc/maatkit/$program_name.conf",
71                                                             "$ENV{HOME}/.maatkit.conf",
72                                                             "$ENV{HOME}/.$program_name.conf",
73                                                          ],
74                                                       };
75            33                                270      return bless $self, $class;
76                                                    }
77                                                    
78                                                    # Read and parse POD OPTIONS in file or current script if
79                                                    # no file is given. This sub must be called before get_opts();
80                                                    sub get_specs {
81             3                    3            14      my ( $self, $file ) = @_;
82             3                                 17      my @specs = $self->_pod_to_specs($file);
83             2                                 28      $self->_parse_specs(@specs);
84             2                                  7      return;
85                                                    }
86                                                    
87                                                    # Returns the program's defaults files.
88                                                    sub get_defaults_files {
89             6                    6            22      my ( $self ) = @_;
90             6                                 18      return @{$self->{default_files}};
               6                                 57   
91                                                    }
92                                                    
93                                                    # Parse command line options from the OPTIONS section of the POD in the
94                                                    # given file. If no file is given, the currently running program's POD
95                                                    # is parsed.
96                                                    # Returns an array of hashrefs which is usually passed to _parse_specs().
97                                                    # Each hashref in the array corresponds to one command line option from
98                                                    # the POD. Each hashref has the structure:
99                                                    #    {
100                                                   #       spec  => GetOpt::Long specification,
101                                                   #       desc  => short description for --help
102                                                   #       group => option group (default: 'default')
103                                                   #    }
104                                                   sub _pod_to_specs {
105            8                    8            38      my ( $self, $file ) = @_;
106   ***      8            50                   38      $file ||= __FILE__;
107   ***      8     50                         286      open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
108                                                   
109            8                                102      my %types = (
110                                                         string => 's', # standard Getopt type
111                                                         'int'  => 'i', # standard Getopt type
112                                                         float  => 'f', # standard Getopt type
113                                                         Hash   => 'H', # hash, formed from a comma-separated list
114                                                         hash   => 'h', # hash as above, but only if a value is given
115                                                         Array  => 'A', # array, similar to Hash
116                                                         array  => 'a', # array, similar to hash
117                                                         DSN    => 'd', # DSN, as provided by a DSNParser which is in $self->{dp}
118                                                         size   => 'z', # size with kMG suffix (powers of 2^10)
119                                                         'time' => 'm', # time, with an optional suffix of s/h/m/d
120                                                      );
121            8                                 34      my @specs = ();
122            8                                 24      my @rules = ();
123            8                                 19      my $para;
124                                                   
125                                                      # Read a paragraph at a time from the file.  Skip everything until options
126                                                      # are reached...
127            8                                 46      local $INPUT_RECORD_SEPARATOR = '';
128            8                                145      while ( $para = <$fh> ) {
129           65    100                         399         next unless $para =~ m/^=head1 OPTIONS/;
130            7                                 20         last;
131                                                      }
132                                                   
133                                                      # ... then read any option rules...
134            8                                 65      while ( $para = <$fh> ) {
135            8    100                          42         last if $para =~ m/^=over/;
136            1                                  5         chomp $para;
137            1                                 10         $para =~ s/\s+/ /g;
138            1                                 50         $para =~ s/$POD_link_re/$1/go;
139            1                                  3         MKDEBUG && _d('Option rule:', $para);
140            1                                  8         push @rules, $para;
141                                                      }
142                                                   
143            8    100                          28      die 'POD has no OPTIONS section' unless $para;
144                                                   
145                                                      # ... then start reading options.
146            7                                 20      do {
147           44    100                         267         if ( my ($option) = $para =~ m/^=item --(.*)/ ) {
148           37                                109            chomp $para;
149           37                                 77            MKDEBUG && _d($para);
150           37                                 88            my %attribs;
151                                                   
152           37                                126            $para = <$fh>; # read next paragraph, possibly attributes
153                                                   
154           37    100                         140            if ( $para =~ m/: / ) { # attributes
155           32                                141               $para =~ s/\s+\Z//g;
156           42                                185               %attribs = map {
157           32                                140                     my ( $attrib, $val) = split(/: /, $_);
158           42    100                         181                     die "Unrecognized attribute for --$option: $attrib"
159                                                                        unless $attributes{$attrib};
160           41                                208                     ($attrib, $val);
161                                                                  } split(/; /, $para);
162           31    100                         131               if ( $attribs{'short form'} ) {
163            6                                 28                  $attribs{'short form'} =~ s/-//;
164                                                               }
165           31                                121               $para = <$fh>; # read next paragraph, probably short help desc
166                                                            }
167                                                            else {
168            5                                 14               MKDEBUG && _d('Option has no attributes');
169                                                            }
170                                                   
171                                                            # Remove extra spaces and POD formatting (L<"">).
172           36                                181            $para =~ s/\s+\Z//g;
173           36                                162            $para =~ s/\s+/ /g;
174           36                                132            $para =~ s/$POD_link_re/$1/go;
175                                                   
176                                                            # Take the first period-terminated sentence as the option's short help
177                                                            # description.
178           36                                129            $para =~ s/\.(?:\n.*| [A-Z].*|\Z)//s;
179           36                                 84            MKDEBUG && _d('Short help:', $para);
180                                                   
181           36    100                         144            die "No description after option spec $option" if $para =~ m/^=item/;
182                                                   
183                                                            # Change [no]foo to foo and set negatable attrib. See issue 140.
184           35    100                         160            if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
185            1                                  3               $option = $base_option;
186            1                                  4               $attribs{'negatable'} = 1;
187                                                            }
188                                                   
189           35    100                         538            push @specs, {
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
190                                                               spec  => $option
191                                                                  . ($attribs{'short form'} ? '|' . $attribs{'short form'} : '' )
192                                                                  . ($attribs{'negatable'}  ? '!'                          : '' )
193                                                                  . ($attribs{'cumulative'} ? '+'                          : '' )
194                                                                  . ($attribs{'type'}       ? '=' . $types{$attribs{type}} : '' ),
195                                                               desc  => $para
196                                                                  . ($attribs{default} ? " (default $attribs{default})" : ''),
197                                                               group => ($attribs{'group'} ? $attribs{'group'} : 'default'),
198                                                            };
199                                                         }
200           42                                225         while ( $para = <$fh> ) {
201   ***     56     50                         185            last unless $para;
202                                                   
203                                                            # The 'allowed with' hack that was here was removed.
204                                                            # Groups need to be used instead. So, this new OptionParser
205                                                            # module will not work with mk-table-sync.
206                                                   
207           56    100                         204            if ( $para =~ m/^=head1/ ) {
208            5                                 15               $para = undef; # Can't 'last' out of a do {} block.
209            5                                 27               last;
210                                                            }
211           51    100                         317            last if $para =~ m/^=item --/;
212                                                         }
213                                                      } while ( $para );
214                                                   
215            5    100                          23      die 'No valid specs in POD OPTIONS' unless @specs;
216                                                   
217            4                                 42      close $fh;
218            4                                 14      return @specs, @rules;
219                                                   }
220                                                   
221                                                   # Parse an array of option specs and rules (usually the return value of
222                                                   # _pod_to_spec()). Each option spec is parsed and the following attributes
223                                                   # pairs are added to its hashref:
224                                                   #    short         => the option's short key (-A for --charset)
225                                                   #    is_cumulative => true if the option is cumulative
226                                                   #    is_negatable  => true if the option is negatable
227                                                   #    is_required   => true if the option is required
228                                                   #    type          => the option's type (see %types in _pod_to_spec() above)
229                                                   #    got           => true if the option was given explicitly on the cmd line
230                                                   #    value         => the option's value
231                                                   #
232                                                   sub _parse_specs {
233           32                   32           174      my ( $self, @specs ) = @_;
234           32                                108      my %disables; # special rule that requires deferred checking
235                                                   
236           32                                128      foreach my $opt ( @specs ) {
237          119    100                         417         if ( ref $opt ) { # It's an option spec, not a rule.
238                                                            MKDEBUG && _d('Parsing opt spec:',
239          108                                248               map { ($_, '=>', $opt->{$_}) } keys %$opt);
240                                                   
241          108                                747            my ( $long, $short ) = $opt->{spec} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
242   ***    108     50                         440            if ( !$long ) {
243                                                               # This shouldn't happen.
244   ***      0                                  0               die "Cannot parse long option from spec $opt->{spec}";
245                                                            }
246          108                               1287            $opt->{long} = $long;
247                                                   
248   ***    108     50                         490            die "Duplicate long option --$long" if exists $self->{opts}->{$long};
249          108                                423            $self->{opts}->{$long} = $opt;
250                                                   
251          108    100                         431            if ( length $long == 1 ) {
252            5                                 11               MKDEBUG && _d('Long opt', $long, 'looks like short opt');
253            5                                 21               $self->{short_opts}->{$long} = $long;
254                                                            }
255                                                   
256          108    100                         352            if ( $short ) {
257   ***     39     50                         172               die "Duplicate short option -$short"
258                                                                  if exists $self->{short_opts}->{$short};
259           39                                159               $self->{short_opts}->{$short} = $long;
260           39                                134               $opt->{short} = $short;
261                                                            }
262                                                            else {
263           69                                246               $opt->{short} = undef;
264                                                            }
265                                                   
266          108    100                         583            $opt->{is_negatable}  = $opt->{spec} =~ m/!/        ? 1 : 0;
267          108    100                         569            $opt->{is_cumulative} = $opt->{spec} =~ m/\+/       ? 1 : 0;
268          108    100                         538            $opt->{is_required}   = $opt->{desc} =~ m/required/ ? 1 : 0;
269                                                   
270          108           100                  513            $opt->{group} ||= 'default';
271          108                                548            $self->{groups}->{ $opt->{group} }->{$long} = 1;
272                                                   
273          108                                342            $opt->{value} = undef;
274          108                                340            $opt->{got}   = 0;
275                                                   
276          108                                531            my ( $type ) = $opt->{spec} =~ m/=(.)/;
277          108                                388            $opt->{type} = $type;
278          108                                245            MKDEBUG && _d($long, 'type:', $type);
279                                                   
280   ***    108     50    100                  866            if ( $type && $type eq 'd' && !$self->{dp} ) {
      ***                   66                        
281   ***      0                                  0               die "$opt->{long} is type DSN (d) but no dp argument "
282                                                                  . "was given when this OptionParser object was created";
283                                                            }
284                                                   
285                                                            # Option has a non-Getopt type: HhAadzm (see %types in
286                                                            # _pod_to_spec() above). For these, use Getopt type 's'.
287          108    100    100                  817            $opt->{spec} =~ s/=./=s/ if ( $type && $type =~ m/[HhAadzm]/ );
288                                                   
289                                                            # Option has a default value if its desc says 'default' or 'default X'.
290                                                            # These defaults from the POD may be overridden by later calls
291                                                            # to set_defaults().
292          108    100                         601            if ( (my ($def) = $opt->{desc} =~ m/default\b(?: ([^)]+))?/) ) {
293                                                               # This allows "default yes" for negatable opts. See issue 404.
294           17    100                          73               if ( $opt->{is_negatable} ) {
295   ***      1      0                           6                  $def = $def eq 'yes' ? 1
      ***            50                               
296                                                                       : $def eq 'no'  ? 0
297                                                                       : $def;
298                                                               }
299           17    100                          84               $self->{defaults}->{$long} = defined $def ? $def : 1;
300           17                                 42               MKDEBUG && _d($long, 'default:', $def);
301                                                            }
302                                                   
303                                                            # Handle special behavior for --config.
304          108    100                         419            if ( $long eq 'config' ) {
305            5                                 27               $self->{defaults}->{$long} = join(',', $self->get_defaults_files());
306                                                            }
307                                                   
308                                                            # Option disable another option if its desc says 'disable'.
309          108    100                         540            if ( (my ($dis) = $opt->{desc} =~ m/(disables .*)/) ) {
310                                                               # Defer checking till later because of possible forward references.
311            3                                 10               $disables{$long} = $dis;
312            3                                 12               MKDEBUG && _d('Deferring check of disables rule for', $opt, $dis);
313                                                            }
314                                                   
315                                                            # Save the option.
316          108                                511            $self->{opts}->{$long} = $opt;
317                                                         }
318                                                         else { # It's an option rule, not a spec.
319           11                                 30            MKDEBUG && _d('Parsing rule:', $opt); 
320           11                                 28            push @{$self->{rules}}, $opt;
              11                                 47   
321           11                                 54            my @participants = $self->_get_participants($opt);
322            9                                 29            my $rule_ok = 0;
323                                                   
324            9    100                          75            if ( $opt =~ m/mutually exclusive|one and only one/ ) {
325            4                                 12               $rule_ok = 1;
326            4                                 11               push @{$self->{mutex}}, \@participants;
               4                                 18   
327            4                                 17               MKDEBUG && _d(@participants, 'are mutually exclusive');
328                                                            }
329            9    100                          60            if ( $opt =~ m/at least one|one and only one/ ) {
330            4                                 13               $rule_ok = 1;
331            4                                 10               push @{$self->{atleast1}}, \@participants;
               4                                 17   
332            4                                 11               MKDEBUG && _d(@participants, 'require at least one');
333                                                            }
334            9    100                          38            if ( $opt =~ m/default to/ ) {
335            2                                  7               $rule_ok = 1;
336                                                               # Example: "DSN values in L<"--dest"> default to values
337                                                               # from L<"--source">."
338            2                                  9               $self->{defaults_to}->{$participants[0]} = $participants[1];
339            2                                  5               MKDEBUG && _d($participants[0], 'defaults to', $participants[1]);
340                                                            }
341            9    100                          39            if ( $opt =~ m/restricted to option groups/ ) {
342            1                                  3               $rule_ok = 1;
343            1                                  7               my ($groups) = $opt =~ m/groups ([\w\s\,]+)/;
344            1                                  7               my @groups = split(',', $groups);
345            1                                  8               %{$self->{allowed_groups}->{$participants[0]}} = map {
               4                                 14   
346            1                                  3                  s/\s+//;
347            4                                 13                  $_ => 1;
348                                                               } @groups;
349                                                            }
350                                                   
351   ***      9     50                          52            die "Unrecognized option rule: $opt" unless $rule_ok;
352                                                         }
353                                                      }
354                                                   
355                                                      # Check forward references in 'disables' rules.
356           30                                179      foreach my $long ( keys %disables ) {
357                                                         # _get_participants() will check that each opt exists.
358            2                                 12         my @participants = $self->_get_participants($disables{$long});
359            1                                  5         $self->{disables}->{$long} = \@participants;
360            1                                  4         MKDEBUG && _d('Option', $long, 'disables', @participants);
361                                                      }
362                                                   
363           29                                129      return; 
364                                                   }
365                                                   
366                                                   # Returns an array of long option names in str. This is used to
367                                                   # find the "participants" of option rules (i.e. the options to
368                                                   # which a rule applies).
369                                                   sub _get_participants {
370           15                   15            68      my ( $self, $str ) = @_;
371           15                                 53      my @participants;
372           15                                129      foreach my $long ( $str =~ m/--(?:\[no\])?([\w-]+)/g ) {
373           32    100                         145         die "Option --$long does not exist while processing rule $str"
374                                                            unless exists $self->{opts}->{$long};
375           29                                111         push @participants, $long;
376                                                      }
377           12                                 29      MKDEBUG && _d('Participants for', $str, ':', @participants);
378           12                                 75      return @participants;
379                                                   }
380                                                   
381                                                   # Returns a copy of the internal opts hash.
382                                                   sub opts {
383            4                    4            18      my ( $self ) = @_;
384            4                                 12      my %opts = %{$self->{opts}};
               4                                 42   
385            4                                 76      return %opts;
386                                                   }
387                                                   
388                                                   # Return a simplified option=>value hash like the original
389                                                   # %opts hash frequently used scripts. Some subs in other
390                                                   # modules, like DSNParser::get_cxn_params(), expect this
391                                                   # kind of hash.
392                                                   sub opt_values {
393            1                    1             5      my ( $self ) = @_;
394           12    100                          60      my %opts = map {
395            1                                  8         my $opt = $self->{opts}->{$_}->{short} ? $self->{opts}->{$_}->{short}
396                                                                 : $_;
397           12                                 63         $opt => $self->{opts}->{$_}->{value}
398            1                                  4      } keys %{$self->{opts}};
399            1                                 14      return %opts;
400                                                   }
401                                                   
402                                                   # Returns a copy of the internal short_opts hash.
403                                                   sub short_opts {
404            1                    1             5      my ( $self ) = @_;
405            1                                  4      my %short_opts = %{$self->{short_opts}};
               1                                  7   
406            1                                  7      return %short_opts;
407                                                   }
408                                                   
409                                                   sub set_defaults {
410            5                    5            30      my ( $self, %defaults ) = @_;
411            5                                 25      $self->{defaults} = {};
412            5                                 27      foreach my $long ( keys %defaults ) {
413            3    100                          16         die "Cannot set default for nonexistent option $long"
414                                                            unless exists $self->{opts}->{$long};
415            2                                  9         $self->{defaults}->{$long} = $defaults{$long};
416            2                                  8         MKDEBUG && _d('Default val for', $long, ':', $defaults{$long});
417                                                      }
418            4                                 16      return;
419                                                   }
420                                                   
421                                                   sub get_defaults {
422            3                    3            12      my ( $self ) = @_;
423            3                                 19      return $self->{defaults};
424                                                   }
425                                                   
426                                                   sub get_groups {
427            1                    1             5      my ( $self ) = @_;
428            1                                 16      return $self->{groups};
429                                                   }
430                                                   
431                                                   # Getopt::Long calls this sub for each opt it finds on the
432                                                   # cmd line. We have to do this in order to know which opts
433                                                   # were "got" on the cmd line.
434                                                   sub _set_option {
435           63                   63           269      my ( $self, $opt, $val ) = @_;
436   ***     63      0                         155      my $long = exists $self->{opts}->{$opt}       ? $opt
      ***            50                               
437                                                               : exists $self->{short_opts}->{$opt} ? $self->{short_opts}->{$opt}
438                                                               : die "Getopt::Long gave a nonexistent option: $opt";
439                                                   
440                                                      # Reassign $opt.
441           63                                127      $opt = $self->{opts}->{$long};
442           63    100                         309      if ( $opt->{is_cumulative} ) {
443            8                                 25         $opt->{value}++;
444                                                      }
445                                                      else {
446           55                                193         $opt->{value} = $val;
447                                                      }
448           63                                208      $opt->{got} = 1;
449           63                                235      MKDEBUG && _d('Got option', $long, '=', $val);
450                                                   }
451                                                   
452                                                   # Get options on the command line (ARGV) according to the option specs
453                                                   # and enforce option rules. Option values are saved internally in
454                                                   # $self->{opts} and accessed later by get(), got() and set().
455                                                   sub get_opts {
456           55                   55           253      my ( $self ) = @_; 
457                                                   
458                                                      # Reset opts. 
459           55                                169      foreach my $long ( keys %{$self->{opts}} ) {
              55                                380   
460          200                                789         $self->{opts}->{$long}->{got} = 0;
461          200    100                        1681         $self->{opts}->{$long}->{value}
                    100                               
462                                                            = exists $self->{defaults}->{$long}       ? $self->{defaults}->{$long}
463                                                            : $self->{opts}->{$long}->{is_cumulative} ? 0
464                                                            : undef;
465                                                      }
466           55                                227      $self->{got_opts} = 0;
467                                                   
468                                                      # Reset errors.
469           55                                215      $self->{errors} = [];
470                                                   
471                                                      # --config is special-case; parse them manually and remove them from @ARGV
472           55    100    100                  478      if ( @ARGV && $ARGV[0] eq "--config" ) {
473            4                                 13         shift @ARGV;
474            4                                 18         $self->_set_option('config', shift @ARGV);
475                                                      }
476           55    100                         270      if ( $self->has('config') ) {
477            6                                 18         my @extra_args;
478            6                                 30         foreach my $filename ( split(',', $self->get('config')) ) {
479                                                            # Try to open the file.  If it was set explicitly, it's an error if it
480                                                            # can't be opened, but the built-in defaults are to be ignored if they
481                                                            # can't be opened.
482           13                                 34            eval {
483           13                                 60               push @ARGV, $self->_read_config_file($filename);
484                                                            };
485           13    100                          86            if ( $EVAL_ERROR ) {
486            9    100                          35               if ( $self->got('config') ) {
487            1                                  2                  die $EVAL_ERROR;
488                                                               }
489                                                               elsif ( MKDEBUG ) {
490                                                                  _d($EVAL_ERROR);
491                                                               }
492                                                            }
493                                                         }
494            5                                 22         unshift @ARGV, @extra_args;
495                                                      }
496                                                   
497           54                                316      Getopt::Long::Configure('no_ignore_case', 'bundling');
498                                                      GetOptions(
499                                                         # Make Getopt::Long specs for each option with custom handler subs.
500          193                   59          1469         map    { $_->{spec} => sub { $self->_set_option(@_); } }
              59                                273   
             198                                813   
501           54                                255         grep   { $_->{long} ne 'config' } # --config is handled specially above.
502           54    100                         173         values %{$self->{opts}}
503                                                      ) or $self->save_error('Error parsing options');
504                                                   
505   ***     54     50     66                  683      if ( exists $self->{opts}->{version} && $self->{opts}->{version}->{got} ) {
506   ***      0      0                           0         printf("%s  Ver %s Distrib %s Changeset %s\n",
507                                                            $self->{program_name}, $main::VERSION, $main::DISTRIB, $main::SVN_REV)
508                                                               or die "Cannot print: $OS_ERROR";
509   ***      0                                  0         exit 0;
510                                                      }
511                                                   
512           54    100    100                  285      if ( @ARGV && $self->{strict} ) {
513            1                                  7         $self->save_error("Unrecognized command-line options @ARGV");
514                                                      }
515                                                   
516                                                      # Check mutex options.
517           54                                153      foreach my $mutex ( @{$self->{mutex}} ) {
              54                                300   
518            6                                 22         my @set = grep { $self->{opts}->{$_}->{got} } @$mutex;
              15                                 70   
519            6    100                          36         if ( @set > 1 ) {
520            5                                 39            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               3                                 12   
521            3                                 19                         @{$mutex}[ 0 .. scalar(@$mutex) - 2] )
522                                                                    . ' and --'.$self->{opts}->{$mutex->[-1]}->{long}
523                                                                    . ' are mutually exclusive.';
524            3                                 14            $self->save_error($err);
525                                                         }
526                                                      }
527                                                   
528           54                                148      foreach my $required ( @{$self->{atleast1}} ) {
              54                                239   
529            4                                 14         my @set = grep { $self->{opts}->{$_}->{got} } @$required;
              12                                 56   
530            4    100                          22         if ( @set == 0 ) {
531            4                                 31            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               2                                  8   
532            2                                 14                         @{$required}[ 0 .. scalar(@$required) - 2] )
533                                                                    .' or --'.$self->{opts}->{$required->[-1]}->{long};
534            2                                 13            $self->save_error("Specify at least one of $err");
535                                                         }
536                                                      }
537                                                   
538           54                                150      foreach my $long ( keys %{$self->{opts}} ) {
              54                                282   
539          198                                699         my $opt = $self->{opts}->{$long};
540          198    100                         962         if ( $opt->{got} ) {
                    100                               
541                                                            # Rule: opt disables other opts.
542           58    100                         262            if ( exists $self->{disables}->{$long} ) {
543            1                                  3               my @disable_opts = @{$self->{disables}->{$long}};
               1                                  5   
544            1                                  5               map { $self->{opts}->{$_}->{value} = undef; } @disable_opts;
               1                                  5   
545            1                                  3               MKDEBUG && _d('Unset options', @disable_opts,
546                                                                  'because', $long,'disables them');
547                                                            }
548                                                   
549                                                            # Group restrictions.
550           58    100                         288            if ( exists $self->{allowed_groups}->{$long} ) {
551                                                               # This option is only allowed with other options from
552                                                               # certain groups.  Check that no options from restricted
553                                                               # groups were gotten.
554                                                   
555           10                                 46               my @restricted_groups = grep {
556            2                                 12                  !exists $self->{allowed_groups}->{$long}->{$_}
557            2                                  5               } keys %{$self->{groups}};
558                                                   
559            2                                  7               my @restricted_opts;
560            2                                  6               foreach my $restricted_group ( @restricted_groups ) {
561            2                                 12                  RESTRICTED_OPT:
562            2                                  6                  foreach my $restricted_opt (
563                                                                     keys %{$self->{groups}->{$restricted_group}} )
564                                                                  {
565            4    100                          20                     next RESTRICTED_OPT if $restricted_opt eq $long;
566            2    100                          14                     push @restricted_opts, $restricted_opt
567                                                                        if $self->{opts}->{$restricted_opt}->{got};
568                                                                  }
569                                                               }
570                                                   
571            2    100                           9               if ( @restricted_opts ) {
572            1                                  3                  my $err;
573   ***      1     50                           6                  if ( @restricted_opts == 1 ) {
574            1                                  3                     $err = "--$restricted_opts[0]";
575                                                                  }
576                                                                  else {
577   ***      0                                  0                     $err = join(', ',
578   ***      0                                  0                               map { "--$self->{opts}->{$_}->{long}" }
579   ***      0                                  0                               grep { $_ } 
580                                                                               @restricted_opts[0..scalar(@restricted_opts) - 2]
581                                                                            )
582                                                                          . ' or --'.$self->{opts}->{$restricted_opts[-1]}->{long};
583                                                                  }
584            1                                  8                  $self->save_error("--$long is not allowed with $err");
585                                                               }
586                                                            }
587                                                   
588                                                         }
589                                                         elsif ( $opt->{is_required} ) { 
590            3                                 19            $self->save_error("Required option --$long must be specified");
591                                                         }
592                                                   
593          198                                737         $self->_validate_type($opt);
594                                                      }
595                                                   
596           54                                225      $self->{got_opts} = 1;
597           54                                171      return;
598                                                   }
599                                                   
600                                                   sub _validate_type {
601          198                  198           675      my ( $self, $opt ) = @_;
602   ***    198    100     66                 1685      return unless $opt && $opt->{type};
603          113                                381      my $val = $opt->{value};
604                                                   
605          113    100    100                 2584      if ( $val && $opt->{type} eq 'm' ) {
                    100    100                        
                    100    100                        
                    100    100                        
                    100    100                        
                           100                        
                           100                        
606            8                                 21         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a time value');
607            8                                 59         my ( $num, $suffix ) = $val =~ m/(\d+)([a-z])?$/;
608                                                         # The suffix defaults to 's' unless otherwise specified.
609            8    100                          36         if ( !$suffix ) {
610            5                                 26            my ( $s ) = $opt->{desc} =~ m/\(suffix (.)\)/;
611            5           100                   24            $suffix = $s || 's';
612            5                                 12            MKDEBUG && _d('No suffix given; using', $suffix, 'for',
613                                                               $opt->{long}, '(value:', $val, ')');
614                                                         }
615            8    100                          37         if ( $suffix =~ m/[smhd]/ ) {
616            7    100                          44            $val = $suffix eq 's' ? $num            # Seconds
                    100                               
                    100                               
617                                                                 : $suffix eq 'm' ? $num * 60       # Minutes
618                                                                 : $suffix eq 'h' ? $num * 3600     # Hours
619                                                                 :                  $num * 86400;   # Days
620            7                                 23            $opt->{value} = $val;
621            7                                 20            MKDEBUG && _d('Setting option', $opt->{long}, 'to', $val);
622                                                         }
623                                                         else {
624            1                                  8            $self->save_error("Invalid time suffix for --$opt->{long}");
625                                                         }
626                                                      }
627                                                      elsif ( $val && $opt->{type} eq 'd' ) {
628            5                                 14         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a DSN');
629            5                                 23         my $from_key = $self->{defaults_to}->{ $opt->{long} };
630            5                                 16         my $default = {};
631            5    100                          20         if ( $from_key ) {
632            2                                  5            MKDEBUG && _d($opt->{long}, 'DSN copies from', $from_key, 'DSN');
633            2                                 19            $default = $self->{dp}->parse(
634                                                               $self->{dp}->as_string($self->{opts}->{$from_key}->{value}) );
635                                                         }
636            5                                 39         $opt->{value} = $self->{dp}->parse($val, $default);
637                                                      }
638                                                      elsif ( $val && $opt->{type} eq 'z' ) {
639            6                                 13         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a size value');
640            6                                 37         my %factor_for = (k => 1_024, M => 1_048_576, G => 1_073_741_824);
641            6                                 48         my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
642            6    100                          25         if ( defined $num ) {
643            5    100                          20            if ( $factor ) {
644            4                                 18               $num *= $factor_for{$factor};
645            4                                 10               MKDEBUG && _d('Setting option', $opt->{y},
646                                                                  'to num', $num, '* factor', $factor);
647                                                            }
648            5           100                   43            $opt->{value} = ($pre || '') . $num;
649                                                         }
650                                                         else {
651            1                                  7            $self->save_error("Invalid size for --$opt->{long}");
652                                                         }
653                                                      }
654                                                      elsif ( $opt->{type} eq 'H' || (defined $val && $opt->{type} eq 'h') ) {
655            6           100                   53         $opt->{value} = { map { $_ => 1 } split(',', ($val || '')) };
               4                                 19   
656                                                      }
657                                                      elsif ( $opt->{type} eq 'A' || (defined $val && $opt->{type} eq 'a') ) {
658           15           100                  172         $opt->{value} = [ split(/(?<!\\),/, ($val || '')) ];
659                                                      }
660                                                      else {
661           73                                199         MKDEBUG && _d('Nothing to validate for option',
662                                                            $opt->{long}, 'type', $opt->{type}, 'value', $val);
663                                                      }
664                                                   
665          113                                416      return;
666                                                   }
667                                                   
668                                                   # Get an option's value. The option can be either a
669                                                   # short or long name (e.g. -A or --charset).
670                                                   sub get {
671           65                   65           304      my ( $self, $opt ) = @_;
672           65    100                         363      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
673           65    100    100                  622      die "Option $opt does not exist"
674                                                         unless $long && exists $self->{opts}->{$long};
675           62                                599      return $self->{opts}->{$long}->{value};
676                                                   }
677                                                   
678                                                   # Returns true if the option was given explicitly on the
679                                                   # command line; returns false if not. The option can be
680                                                   # either short or long name (e.g. -A or --charset).
681                                                   sub got {
682           31                   31           138      my ( $self, $opt ) = @_;
683           31    100                         147      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
684           31    100    100                  282      die "Option $opt does not exist"
685                                                         unless $long && exists $self->{opts}->{$long};
686           29                                208      return $self->{opts}->{$long}->{got};
687                                                   }
688                                                   
689                                                   # Returns true if the option exists.
690                                                   sub has {
691           62                   62           290      my ( $self, $opt ) = @_;
692           62    100                         341      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
693           62    100                         508      return defined $long ? exists $self->{opts}->{$long} : 0;
694                                                   }
695                                                   
696                                                   # Set an option's value. The option can be either a
697                                                   # short or long name (e.g. -A or --charset). The value
698                                                   # can be any scalar, ref, or undef. No type checking
699                                                   # is done so becareful to not set, for example, an integer
700                                                   # option with a DSN.
701                                                   sub set {
702            5                    5            29      my ( $self, $opt, $val ) = @_;
703            5    100                          28      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
704            5    100    100                   40      die "Option $opt does not exist"
705                                                         unless $long && exists $self->{opts}->{$long};
706            3                                 14      $self->{opts}->{$long}->{value} = $val;
707            3                                 10      return;
708                                                   }
709                                                   
710                                                   # Save an error message to be reported later by calling usage_or_errors()
711                                                   # (or errors()--mostly for testing).
712                                                   sub save_error {
713           15                   15            69      my ( $self, $error ) = @_;
714           15                                 46      push @{$self->{errors}}, $error;
              15                                 84   
715                                                   }
716                                                   
717                                                   # Return arrayref of errors (mostly for testing).
718                                                   sub errors {
719           13                   13            57      my ( $self ) = @_;
720           13                                103      return $self->{errors};
721                                                   }
722                                                   
723                                                   sub prompt {
724           11                   11            43      my ( $self ) = @_;
725           11                                 81      return "Usage: $PROGRAM_NAME $self->{prompt}\n";
726                                                   }
727                                                   
728                                                   sub descr {
729           11                   11            43      my ( $self ) = @_;
730   ***     11            50                  114      my $descr  = $self->{program_name} . ' ' . ($self->{description} || '')
731                                                                 . "  For more details, please use the --help option, "
732                                                                 . "or try 'perldoc $PROGRAM_NAME' "
733                                                                 . "for complete documentation.";
734           11                                117      $descr = join("\n", $descr =~ m/(.{0,80})(?:\s+|$)/g);
735           11                                 98      $descr =~ s/ +$//mg;
736           11                                 73      return $descr;
737                                                   }
738                                                   
739                                                   sub usage_or_errors {
740   ***      0                    0             0      my ( $self ) = @_;
741   ***      0      0                           0      if ( $self->{opts}->{help}->{got} ) {
      ***      0      0                           0   
742   ***      0      0                           0         print $self->print_usage() or die "Cannot print usage: $OS_ERROR";
743   ***      0                                  0         exit 0;
744                                                      }
745                                                      elsif ( scalar @{$self->{errors}} ) {
746   ***      0      0                           0         print $self->print_errors() or die "Cannot print errors: $OS_ERROR";
747   ***      0                                  0         exit 0;
748                                                      }
749   ***      0                                  0      return;
750                                                   }
751                                                   
752                                                   # Explains what errors were found while processing command-line arguments and
753                                                   # gives a brief overview so you can get more information.
754                                                   sub print_errors {
755            1                    1             5      my ( $self ) = @_;
756            1                                  6      my $usage = $self->prompt() . "\n";
757   ***      1     50                           3      if ( (my @errors = @{$self->{errors}}) ) {
               1                                  8   
758            1                                  6         $usage .= join("\n  * ", 'Errors in command-line arguments:', @errors)
759                                                                 . "\n";
760                                                      }
761            1                                  6      return $usage . "\n" . $self->descr();
762                                                   }
763                                                   
764                                                   # Prints out command-line help.  The format is like this:
765                                                   # --foo  -F   Description of --foo
766                                                   # --bars -B   Description of --bar
767                                                   # --longopt   Description of --longopt
768                                                   # Note that the short options are aligned along the right edge of their longest
769                                                   # long option, but long options that don't have a short option are allowed to
770                                                   # protrude past that.
771                                                   sub print_usage {
772           10                   10            46      my ( $self ) = @_;
773   ***     10     50                          54      die "Run get_opts() before print_usage()" unless $self->{got_opts};
774           10                                 30      my @opts = values %{$self->{opts}};
              10                                 54   
775                                                   
776                                                      # Find how wide the widest long option is.
777           32    100                         225      my $maxl = max(
778           10                                 42         map { length($_->{long}) + ($_->{is_negatable} ? 4 : 0) }
779                                                         @opts);
780                                                   
781                                                      # Find how wide the widest option with a short option is.
782   ***     12     50                          81      my $maxs = max(0,
783           10                                 55         map { length($_) + ($self->{opts}->{$_}->{is_negatable} ? 4 : 0) }
784           10                                 38         values %{$self->{short_opts}});
785                                                   
786                                                      # Find how wide the 'left column' (long + short opts) is, and therefore how
787                                                      # much space to give options and how much to give descriptions.
788           10                                 50      my $lcol = max($maxl, ($maxs + 3));
789           10                                 34      my $rcol = 80 - $lcol - 6;
790           10                                 49      my $rpad = ' ' x ( 80 - $rcol );
791                                                   
792                                                      # Adjust the width of the options that have long and short both.
793           10                                 42      $maxs = max($lcol - 3, $maxs);
794                                                   
795                                                      # Format and return the options.
796           10                                 50      my $usage = $self->descr() . "\n" . $self->prompt();
797                                                   
798                                                      # Sort groups alphabetically but make 'default' first.
799           10                                 34      my @groups = reverse sort grep { $_ ne 'default'; } keys %{$self->{groups}};
              14                                 80   
              10                                 52   
800           10                                 40      push @groups, 'default';
801                                                   
802           10                                 41      foreach my $group ( reverse @groups ) {
803           14    100                          74         $usage .= "\n".($group eq 'default' ? 'Options' : $group).":\n\n";
804           14                                 51         foreach my $opt (
              22                                 99   
805           64                                239            sort { $a->{long} cmp $b->{long} }
806                                                            grep { $_->{group} eq $group }
807                                                            @opts )
808                                                         {
809           32    100                         180            my $long  = $opt->{is_negatable} ? "[no]$opt->{long}" : $opt->{long};
810           32                                103            my $short = $opt->{short};
811           32                                116            my $desc  = $opt->{desc};
812                                                            # Expand suffix help for time options.
813           32    100    100                  251            if ( $opt->{type} && $opt->{type} eq 'm' ) {
814            2                                  9               my ($s) = $desc =~ m/\(suffix (.)\)/;
815            2           100                    9               $s    ||= 's';
816            2                                  9               $desc =~ s/\s+\(suffix .\)//;
817            2                                  8               $desc .= ".  Optional suffix s=seconds, m=minutes, h=hours, "
818                                                                      . "d=days; if no suffix, $s is used.";
819                                                            }
820                                                            # Wrap long descriptions
821           32                                471            $desc = join("\n$rpad", grep { $_ } $desc =~ m/(.{0,$rcol})(?:\s+|$)/g);
              69                                231   
822           32                                154            $desc =~ s/ +$//mg;
823           32    100                         105            if ( $short ) {
824           12                                 90               $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
825                                                            }
826                                                            else {
827           20                                146               $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
828                                                            }
829                                                         }
830                                                      }
831                                                   
832           10    100                          31      if ( (my @rules = @{$self->{rules}}) ) {
              10                                 91   
833            4                                 12         $usage .= "\nRules:\n\n";
834            4                                 19         $usage .= join("\n", map { "  $_" } @rules) . "\n";
               4                                 23   
835                                                      }
836           10    100                          48      if ( $self->{dp} ) {
837            2                                 16         $usage .= "\n" . $self->{dp}->usage();
838                                                      }
839           10                                 35      $usage .= "\nOptions and values after processing arguments:\n\n";
840           10                                 19      foreach my $opt ( sort { $a->{long} cmp $b->{long} } @opts ) {
              34                                125   
841           32                                121         my $val   = $opt->{value};
842           32           100                  184         my $type  = $opt->{type} || '';
843           32                                191         my $bool  = $opt->{spec} =~ m/^[\w-]+(?:\|[\w-])?!?$/;
844           32    100                         229         $val      = $bool                     ? ( $val ? 'TRUE' : 'FALSE' )
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
845                                                                   : !defined $val             ? '(No value)'
846                                                                   : $type eq 'd'              ? $self->{dp}->as_string($val)
847                                                                   : $type =~ m/H|h/           ? join(',', sort keys %$val)
848                                                                   : $type =~ m/A|a/           ? join(',', @$val)
849                                                                   :                             $val;
850           32                                202         $usage .= sprintf("  --%-${lcol}s  %s\n", $opt->{long}, $val);
851                                                      }
852           10                                106      return $usage;
853                                                   }
854                                                   
855                                                   # Tries to prompt and read the answer without echoing the answer to the
856                                                   # terminal.  This isn't really related to this package, but it's too handy not
857                                                   # to put here.  OK, it's related, it gets config information from the user.
858                                                   sub prompt_noecho {
859   ***      0      0             0             0      shift @_ if ref $_[0] eq __PACKAGE__;
860   ***      0                                  0      my ( $prompt ) = @_;
861   ***      0                                  0      local $OUTPUT_AUTOFLUSH = 1;
862   ***      0      0                           0      print $prompt
863                                                         or die "Cannot print: $OS_ERROR";
864   ***      0                                  0      my $response;
865   ***      0                                  0      eval {
866   ***      0                                  0         require Term::ReadKey;
867   ***      0                                  0         Term::ReadKey::ReadMode('noecho');
868   ***      0                                  0         chomp($response = <STDIN>);
869   ***      0                                  0         Term::ReadKey::ReadMode('normal');
870   ***      0      0                           0         print "\n"
871                                                            or die "Cannot print: $OS_ERROR";
872                                                      };
873   ***      0      0                           0      if ( $EVAL_ERROR ) {
874   ***      0                                  0         die "Cannot read response; is Term::ReadKey installed? $EVAL_ERROR";
875                                                      }
876   ***      0                                  0      return $response;
877                                                   }
878                                                   
879                                                   # This is debug code I want to run for all tools, and this is a module I
880                                                   # certainly include in all tools, but otherwise there's no real reason to put
881                                                   # it here.
882                                                   if ( MKDEBUG ) {
883                                                      print '# ', $^X, ' ', $], "\n";
884                                                      my $uname = `uname -a`;
885                                                      if ( $uname ) {
886                                                         $uname =~ s/\s+/ /g;
887                                                         print "# $uname\n";
888                                                      }
889                                                      printf("# %s  Ver %s Distrib %s Changeset %s line %d\n",
890                                                         $PROGRAM_NAME, ($main::VERSION || ''), ($main::DISTRIB || ''),
891                                                         ($main::SVN_REV || ''), __LINE__);
892                                                      print('# Arguments: ',
893                                                         join(' ', map { my $a = "_[$_]_"; $a =~ s/\n/\n# /g; $a; } @ARGV), "\n");
894                                                   }
895                                                   
896                                                   # Reads a configuration file and returns it as a list.  Inspired by
897                                                   # Config::Tiny.
898                                                   sub _read_config_file {
899           14                   14            62      my ( $self, $filename ) = @_;
900           14    100                         211      open my $fh, "<", $filename or die "Cannot open $filename: $OS_ERROR\n";
901            5                                 15      my @args;
902            5                                 16      my $prefix = '--';
903            5                                 16      my $parse  = 1;
904                                                   
905                                                      LINE:
906            5                                 74      while ( my $line = <$fh> ) {
907           23                                 61         chomp $line;
908                                                         # Skip comments and empty lines
909           23    100                         125         next LINE if $line =~ m/^\s*(?:\#|\;|$)/;
910                                                         # Remove inline comments
911           19                                 60         $line =~ s/\s+#.*$//g;
912                                                         # Remove whitespace
913           19                                 95         $line =~ s/^\s+|\s+$//g;
914                                                         # Watch for the beginning of the literal values (not to be interpreted as
915                                                         # options)
916           19    100                          72         if ( $line eq '--' ) {
917            4                                 13            $prefix = '';
918            4                                  8            $parse  = 0;
919            4                                 20            next LINE;
920                                                         }
921   ***     15    100     66                  156         if ( $parse
      ***            50                               
922                                                            && (my($opt, $arg) = $line =~ m/^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/)
923                                                         ) {
924            8                                 29            push @args, grep { defined $_ } ("$prefix$opt", $arg);
              16                                 84   
925                                                         }
926                                                         elsif ( $line =~ m/./ ) {
927            7                                 50            push @args, $line;
928                                                         }
929                                                         else {
930   ***      0                                  0            die "Syntax error in file $filename at line $INPUT_LINE_NUMBER";
931                                                         }
932                                                      }
933            5                                 36      close $fh;
934            5                                 13      return @args;
935                                                   }
936                                                   
937                                                   # Reads the next paragraph from the POD after the magical regular expression is
938                                                   # found in the text.
939                                                   sub read_para_after {
940            2                    2            10      my ( $self, $file, $regex ) = @_;
941   ***      2     50                          50      open my $fh, "<", $file or die "Can't open $file: $OS_ERROR";
942            2                                 11      local $INPUT_RECORD_SEPARATOR = '';
943            2                                  5      my $para;
944            2                                 27      while ( $para = <$fh> ) {
945            6    100                          36         next unless $para =~ m/^=pod$/m;
946            2                                  6         last;
947                                                      }
948            2                                 10      while ( $para = <$fh> ) {
949            7    100                          46         next unless $para =~ m/$regex/;
950            2                                  5         last;
951                                                      }
952            2                                  8      $para = <$fh>;
953            2                                  5      chomp($para);
954   ***      2     50                          19      close $fh or die "Can't close $file: $OS_ERROR";
955            2                                  6      return $para;
956                                                   }
957                                                   
958                                                   # Returns a lightweight clone of ourself.  Currently, only the basic
959                                                   # opts are copied.  This is used for stuff like "final opts" in
960                                                   # mk-table-checksum.
961                                                   sub clone {
962            1                    1             4      my ( $self ) = @_;
963                                                   
964                                                      # Deep-copy contents of hashrefs; do not just copy the refs. 
965            3                                 10      my %clone = map {
966            1                                  4         my $hashref  = $self->{$_};
967            3                                  8         my $val_copy = {};
968            3                                 16         foreach my $key ( keys %$hashref ) {
969            5                                 17            my $ref = ref $hashref->{$key};
970            3                                 32            $val_copy->{$key} = !$ref           ? $hashref->{$key}
971   ***      0                                  0                              : $ref eq 'HASH'  ? { %{$hashref->{$key}} }
972   ***      5      0                          26                              : $ref eq 'ARRAY' ? [ @{$hashref->{$key}} ]
      ***            50                               
                    100                               
973                                                                              : $hashref->{$key};
974                                                         }
975            3                                 17         $_ => $val_copy;
976                                                      } qw(opts short_opts defaults);
977                                                   
978                                                      # Re-assign scalar values.
979            1                                  4      foreach my $scalar ( qw(got_opts) ) {
980            1                                  5         $clone{$scalar} = $self->{$scalar};
981                                                      }
982                                                   
983            1                                  6      return bless \%clone;     
984                                                   }
985                                                   
986                                                   sub _d {
987            1                    1             8      my ($package, undef, $line) = caller 0;
988   ***      2     50                          13      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 11   
989            1                                  5           map { defined $_ ? $_ : 'undef' }
990                                                           @_;
991            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
992                                                   }
993                                                   
994                                                   1;
995                                                   
996                                                   # ###########################################################################
997                                                   # End OptionParser package
998                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***     50      0     33   unless $args{$arg}
50           100      1     32   exists $args{'strict'} ? :
107   ***     50      0      8   unless open my $fh, '<', $file
129          100     58      7   unless $para =~ /^=head1 OPTIONS/
135          100      7      1   if $para =~ /^=over/
143          100      1      7   unless $para
147          100     37      7   if (my($option) = $para =~ /^=item --(.*)/)
154          100     32      5   if ($para =~ /: /) { }
158          100      1     41   unless $attributes{$attrib}
162          100      6     25   if ($attribs{'short form'})
181          100      1     35   if $para =~ /^=item/
184          100      1     34   if (my($base_option) = $option =~ /^\[no\](.*)/)
189          100      6     29   $attribs{'short form'} ? :
             100      3     32   $attribs{'negatable'} ? :
             100      2     33   $attribs{'cumulative'} ? :
             100     23     12   $attribs{'type'} ? :
             100      2     33   $attribs{'default'} ? :
             100      6     29   $attribs{'group'} ? :
201   ***     50      0     56   unless $para
207          100      5     51   if ($para =~ /^=head1/)
211          100     37     14   if $para =~ /^=item --/
215          100      1      4   unless @specs
237          100    108     11   if (ref $opt) { }
242   ***     50      0    108   if (not $long)
248   ***     50      0    108   if exists $$self{'opts'}{$long}
251          100      5    103   if (length $long == 1)
256          100     39     69   if ($short) { }
257   ***     50      0     39   if exists $$self{'short_opts'}{$short}
266          100      7    101   $$opt{'spec'} =~ /!/ ? :
267          100      4    104   $$opt{'spec'} =~ /\+/ ? :
268          100      3    105   $$opt{'desc'} =~ /required/ ? :
280   ***     50      0    108   if ($type and $type eq 'd' and not $$self{'dp'})
287          100     43     65   if $type and $type =~ /[HhAadzm]/
292          100     17     91   if (my($def) = $$opt{'desc'} =~ /default\b(?: ([^)]+))?/)
294          100      1     16   if ($$opt{'is_negatable'})
295   ***      0      0      0   $def eq 'no' ? :
      ***     50      1      0   $def eq 'yes' ? :
299          100     16      1   defined $def ? :
304          100      5    103   if ($long eq 'config')
309          100      3    105   if (my($dis) = $$opt{'desc'} =~ /(disables .*)/)
324          100      4      5   if ($opt =~ /mutually exclusive|one and only one/)
329          100      4      5   if ($opt =~ /at least one|one and only one/)
334          100      2      7   if ($opt =~ /default to/)
341          100      1      8   if ($opt =~ /restricted to option groups/)
351   ***     50      0      9   unless $rule_ok
373          100      3     29   unless exists $$self{'opts'}{$long}
394          100      2     10   $$self{'opts'}{$_}{'short'} ? :
413          100      1      2   unless exists $$self{'opts'}{$long}
436   ***      0      0      0   exists $$self{'short_opts'}{$opt} ? :
      ***     50     63      0   exists $$self{'opts'}{$opt} ? :
442          100      8     55   if ($$opt{'is_cumulative'}) { }
461          100     15    157   $$self{'opts'}{$long}{'is_cumulative'} ? :
             100     28    172   exists $$self{'defaults'}{$long} ? :
472          100      4     51   if (@ARGV and $ARGV[0] eq '--config')
476          100      6     49   if ($self->has('config'))
485          100      9      4   if ($EVAL_ERROR)
486          100      1      8   $self->got('config') ? :
502          100      3     51   unless GetOptions map({$$_{'spec'}, sub {
	$self->_set_option(@_);
}
;} grep({$$_{'long'} ne 'config';} values %{$$self{'opts'};}))
505   ***     50      0     54   if (exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'})
506   ***      0      0      0   unless printf "%s  Ver %s Distrib %s Changeset %s\n", $$self{'program_name'}, $main::VERSION, $main::DISTRIB, $main::SVN_REV
512          100      1     53   if (@ARGV and $$self{'strict'})
519          100      3      3   if (@set > 1)
530          100      2      2   if (@set == 0)
540          100     58    140   if ($$opt{'got'}) { }
             100      3    137   elsif ($$opt{'is_required'}) { }
542          100      1     57   if (exists $$self{'disables'}{$long})
550          100      2     56   if (exists $$self{'allowed_groups'}{$long})
565          100      2      2   if $restricted_opt eq $long
566          100      1      1   if $$self{'opts'}{$restricted_opt}{'got'}
571          100      1      1   if (@restricted_opts)
573   ***     50      1      0   if (@restricted_opts == 1) { }
602          100     85    113   unless $opt and $$opt{'type'}
605          100      8    105   if ($val and $$opt{'type'} eq 'm') { }
             100      5    100   elsif ($val and $$opt{'type'} eq 'd') { }
             100      6     94   elsif ($val and $$opt{'type'} eq 'z') { }
             100      6     88   elsif ($$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h') { }
             100     15     73   elsif ($$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a') { }
609          100      5      3   if (not $suffix)
615          100      7      1   if ($suffix =~ /[smhd]/) { }
616          100      2      1   $suffix eq 'h' ? :
             100      2      3   $suffix eq 'm' ? :
             100      2      5   $suffix eq 's' ? :
631          100      2      3   if ($from_key)
642          100      5      1   if (defined $num) { }
643          100      4      1   if ($factor)
672          100     18     47   length $opt == 1 ? :
673          100      3     62   unless $long and exists $$self{'opts'}{$long}
683          100      4     27   length $opt == 1 ? :
684          100      2     29   unless $long and exists $$self{'opts'}{$long}
692          100      2     60   length $opt == 1 ? :
693          100     61      1   defined $long ? :
703          100      2      3   length $opt == 1 ? :
704          100      2      3   unless $long and exists $$self{'opts'}{$long}
741   ***      0      0      0   if ($$self{'opts'}{'help'}{'got'}) { }
      ***      0      0      0   elsif (scalar @{$$self{'errors'};}) { }
742   ***      0      0      0   unless print $self->print_usage
746   ***      0      0      0   unless print $self->print_errors
757   ***     50      1      0   if (my(@errors) = @{$$self{'errors'};})
773   ***     50      0     10   unless $$self{'got_opts'}
777          100      3     29   $$_{'is_negatable'} ? :
782   ***     50      0     12   $$self{'opts'}{$_}{'is_negatable'} ? :
803          100     10      4   $group eq 'default' ? :
809          100      3     29   $$opt{'is_negatable'} ? :
813          100      2     30   if ($$opt{'type'} and $$opt{'type'} eq 'm')
823          100     12     20   if ($short) { }
832          100      4      6   if (my(@rules) = @{$$self{'rules'};})
836          100      2      8   if ($$self{'dp'})
844          100      1     10   $val ? :
             100      6      1   $type =~ /A|a/ ? :
             100      2      7   $type =~ /H|h/ ? :
             100      2      9   $type eq 'd' ? :
             100     10     11   !defined($val) ? :
             100     11     21   $bool ? :
859   ***      0      0      0   if ref $_[0] eq 'OptionParser'
862   ***      0      0      0   unless print $prompt
870   ***      0      0      0   unless print "\n"
873   ***      0      0      0   if ($EVAL_ERROR)
900          100      9      5   unless open my $fh, '<', $filename
909          100      4     19   if $line =~ /^\s*(?:\#|\;|$)/
916          100      4     15   if ($line eq '--')
921          100      8      7   if ($parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/) { }
      ***     50      7      0   elsif ($line =~ /./) { }
941   ***     50      0      2   unless open my $fh, '<', $file
945          100      4      2   unless $para =~ /^=pod$/m
949          100      5      2   unless $para =~ /$regex/
954   ***     50      0      2   unless close $fh
972   ***      0      0      0   $ref eq 'ARRAY' ? :
      ***     50      3      0   $ref eq 'HASH' ? :
             100      2      3   !$ref ? :
988   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
280          100     46     55      7   $type and $type eq 'd'
      ***     66    101      7      0   $type and $type eq 'd' and not $$self{'dp'}
287          100     46     19     43   $type and $type =~ /[HhAadzm]/
472          100     15     36      4   @ARGV and $ARGV[0] eq '--config'
505   ***     66     51      3      0   exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'}
512          100     51      2      1   @ARGV and $$self{'strict'}
602   ***     66      0     85    113   $opt and $$opt{'type'}
605          100     65     40      8   $val and $$opt{'type'} eq 'm'
             100     65     35      5   $val and $$opt{'type'} eq 'd'
             100     65     29      6   $val and $$opt{'type'} eq 'z'
             100     61     27      1   defined $val and $$opt{'type'} eq 'h'
             100     57     16      2   defined $val and $$opt{'type'} eq 'a'
673          100      1      2     62   $long and exists $$self{'opts'}{$long}
684          100      1      1     29   $long and exists $$self{'opts'}{$long}
704          100      1      1      3   $long and exists $$self{'opts'}{$long}
813          100     12     18      2   $$opt{'type'} and $$opt{'type'} eq 'm'
921   ***     66      7      0      8   $parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
48    ***     50     33      0   $program_name ||= $PROGRAM_NAME
50           100      2     31   $args{'prompt'} || '<options>'
             100      7     26   $args{'dp'} || undef
106   ***     50      8      0   $file ||= '../OptionParser.pm'
270          100     49     59   $$opt{'group'} ||= 'default'
611          100      4      1   $s || 's'
648          100      2      3   $pre || ''
655          100      2      4   $val || ''
658          100     11      4   $val || ''
730   ***     50     11      0   $$self{'description'} || ''
815          100      1      1   $s ||= 's'
842          100     20     12   $$opt{'type'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
605          100      5      1     88   $$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h'
             100     13      2     73   $$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a'


Covered Subroutines
-------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
BEGIN                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:22 
BEGIN                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:23 
BEGIN                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:25 
BEGIN                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:26 
BEGIN                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:27 
BEGIN                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:29 
__ANON__              59 /home/daniel/dev/maatkit/common/OptionParser.pm:500
_d                     1 /home/daniel/dev/maatkit/common/OptionParser.pm:987
_get_participants     15 /home/daniel/dev/maatkit/common/OptionParser.pm:370
_parse_specs          32 /home/daniel/dev/maatkit/common/OptionParser.pm:233
_pod_to_specs          8 /home/daniel/dev/maatkit/common/OptionParser.pm:105
_read_config_file     14 /home/daniel/dev/maatkit/common/OptionParser.pm:899
_set_option           63 /home/daniel/dev/maatkit/common/OptionParser.pm:435
_validate_type       198 /home/daniel/dev/maatkit/common/OptionParser.pm:601
clone                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:962
descr                 11 /home/daniel/dev/maatkit/common/OptionParser.pm:729
errors                13 /home/daniel/dev/maatkit/common/OptionParser.pm:719
get                   65 /home/daniel/dev/maatkit/common/OptionParser.pm:671
get_defaults           3 /home/daniel/dev/maatkit/common/OptionParser.pm:422
get_defaults_files     6 /home/daniel/dev/maatkit/common/OptionParser.pm:89 
get_groups             1 /home/daniel/dev/maatkit/common/OptionParser.pm:427
get_opts              55 /home/daniel/dev/maatkit/common/OptionParser.pm:456
get_specs              3 /home/daniel/dev/maatkit/common/OptionParser.pm:81 
got                   31 /home/daniel/dev/maatkit/common/OptionParser.pm:682
has                   62 /home/daniel/dev/maatkit/common/OptionParser.pm:691
new                   33 /home/daniel/dev/maatkit/common/OptionParser.pm:43 
opt_values             1 /home/daniel/dev/maatkit/common/OptionParser.pm:393
opts                   4 /home/daniel/dev/maatkit/common/OptionParser.pm:383
print_errors           1 /home/daniel/dev/maatkit/common/OptionParser.pm:755
print_usage           10 /home/daniel/dev/maatkit/common/OptionParser.pm:772
prompt                11 /home/daniel/dev/maatkit/common/OptionParser.pm:724
read_para_after        2 /home/daniel/dev/maatkit/common/OptionParser.pm:940
save_error            15 /home/daniel/dev/maatkit/common/OptionParser.pm:713
set                    5 /home/daniel/dev/maatkit/common/OptionParser.pm:702
set_defaults           5 /home/daniel/dev/maatkit/common/OptionParser.pm:410
short_opts             1 /home/daniel/dev/maatkit/common/OptionParser.pm:404

Uncovered Subroutines
---------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
prompt_noecho          0 /home/daniel/dev/maatkit/common/OptionParser.pm:859
usage_or_errors        0 /home/daniel/dev/maatkit/common/OptionParser.pm:740


