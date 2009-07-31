---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/OptionParser.pm   93.6   83.1   86.5   94.7    n/a  100.0   89.8
Total                          93.6   83.1   86.5   94.7    n/a  100.0   89.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          OptionParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:02 2009
Finish:       Fri Jul 31 18:53:02 2009

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
18                                                    # OptionParser package $Revision: 4245 $
19                                                    # ###########################################################################
20                                                    package OptionParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24                                                    
25             1                    1            10   use Getopt::Long;
               1                                  3   
               1                                  8   
26             1                    1             7   use List::Util qw(max);
               1                                  3   
               1                                 10   
27             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
28                                                    
29             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                  9   
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
43            33                   33           323      my ( $class, %args ) = @_;
44            33                                131      foreach my $arg ( qw(description) ) {
45    ***     33     50                         190         die "I need a $arg argument" unless $args{$arg};
46                                                       }
47            33                                276      my ($program_name) = $PROGRAM_NAME =~ m/([.A-Za-z-]+)$/;
48    ***     33            50                  134      $program_name ||= $PROGRAM_NAME;
49    ***     33            33                  266      my $home = $ENV{HOME} || $ENV{HOMEPATH} || $ENV{USERPROFILE} || '.';
      ***                   33                        
      ***                   50                        
50                                                    
51            33    100    100                 1162      my $self = {
                           100                        
52                                                          description    => $args{description},
53                                                          prompt         => $args{prompt} || '<options>',
54                                                          strict         => (exists $args{strict} ? $args{strict} : 1),
55                                                          dp             => $args{dp}     || undef,
56                                                          program_name   => $program_name,
57                                                          opts           => {},
58                                                          got_opts       => 0,
59                                                          short_opts     => {},
60                                                          defaults       => {},
61                                                          groups         => {},
62                                                          allowed_groups => {},
63                                                          errors         => [],
64                                                          rules          => [],  # desc of rules for --help
65                                                          mutex          => [],  # rule: opts are mutually exclusive
66                                                          atleast1       => [],  # rule: at least one opt is required
67                                                          disables       => {},  # rule: opt disables other opts 
68                                                          defaults_to    => {},  # rule: opt defaults to value of other opt
69                                                          default_files  => [
70                                                             "/etc/maatkit/maatkit.conf",
71                                                             "/etc/maatkit/$program_name.conf",
72                                                             "$home/.maatkit.conf",
73                                                             "$home/.$program_name.conf",
74                                                          ],
75                                                       };
76            33                                252      return bless $self, $class;
77                                                    }
78                                                    
79                                                    # Read and parse POD OPTIONS in file or current script if
80                                                    # no file is given. This sub must be called before get_opts();
81                                                    sub get_specs {
82             3                    3            14      my ( $self, $file ) = @_;
83             3                                 17      my @specs = $self->_pod_to_specs($file);
84             2                                 26      $self->_parse_specs(@specs);
85             2                                  9      return;
86                                                    }
87                                                    
88                                                    # Returns the program's defaults files.
89                                                    sub get_defaults_files {
90             6                    6            23      my ( $self ) = @_;
91             6                                 17      return @{$self->{default_files}};
               6                                 58   
92                                                    }
93                                                    
94                                                    # Parse command line options from the OPTIONS section of the POD in the
95                                                    # given file. If no file is given, the currently running program's POD
96                                                    # is parsed.
97                                                    # Returns an array of hashrefs which is usually passed to _parse_specs().
98                                                    # Each hashref in the array corresponds to one command line option from
99                                                    # the POD. Each hashref has the structure:
100                                                   #    {
101                                                   #       spec  => GetOpt::Long specification,
102                                                   #       desc  => short description for --help
103                                                   #       group => option group (default: 'default')
104                                                   #    }
105                                                   sub _pod_to_specs {
106            8                    8            43      my ( $self, $file ) = @_;
107   ***      8            50                   31      $file ||= __FILE__;
108   ***      8     50                         304      open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
109                                                   
110            8                                 99      my %types = (
111                                                         string => 's', # standard Getopt type
112                                                         'int'  => 'i', # standard Getopt type
113                                                         float  => 'f', # standard Getopt type
114                                                         Hash   => 'H', # hash, formed from a comma-separated list
115                                                         hash   => 'h', # hash as above, but only if a value is given
116                                                         Array  => 'A', # array, similar to Hash
117                                                         array  => 'a', # array, similar to hash
118                                                         DSN    => 'd', # DSN, as provided by a DSNParser which is in $self->{dp}
119                                                         size   => 'z', # size with kMG suffix (powers of 2^10)
120                                                         'time' => 'm', # time, with an optional suffix of s/h/m/d
121                                                      );
122            8                                 26      my @specs = ();
123            8                                 20      my @rules = ();
124            8                                 31      my $para;
125                                                   
126                                                      # Read a paragraph at a time from the file.  Skip everything until options
127                                                      # are reached...
128            8                                 46      local $INPUT_RECORD_SEPARATOR = '';
129            8                                178      while ( $para = <$fh> ) {
130           65    100                         392         next unless $para =~ m/^=head1 OPTIONS/;
131            7                                 21         last;
132                                                      }
133                                                   
134                                                      # ... then read any option rules...
135            8                                 43      while ( $para = <$fh> ) {
136            8    100                          35         last if $para =~ m/^=over/;
137            1                                  5         chomp $para;
138            1                                  8         $para =~ s/\s+/ /g;
139            1                                 30         $para =~ s/$POD_link_re/$1/go;
140            1                                  3         MKDEBUG && _d('Option rule:', $para);
141            1                                  8         push @rules, $para;
142                                                      }
143                                                   
144            8    100                          29      die 'POD has no OPTIONS section' unless $para;
145                                                   
146                                                      # ... then start reading options.
147            7                                 21      do {
148           44    100                         270         if ( my ($option) = $para =~ m/^=item --(.*)/ ) {
149           37                                 93            chomp $para;
150           37                                 79            MKDEBUG && _d($para);
151           37                                 89            my %attribs;
152                                                   
153           37                                122            $para = <$fh>; # read next paragraph, possibly attributes
154                                                   
155           37    100                         143            if ( $para =~ m/: / ) { # attributes
156           32                                141               $para =~ s/\s+\Z//g;
157           42                                182               %attribs = map {
158           32                                143                     my ( $attrib, $val) = split(/: /, $_);
159           42    100                         178                     die "Unrecognized attribute for --$option: $attrib"
160                                                                        unless $attributes{$attrib};
161           41                                194                     ($attrib, $val);
162                                                                  } split(/; /, $para);
163           31    100                         129               if ( $attribs{'short form'} ) {
164            6                                 27                  $attribs{'short form'} =~ s/-//;
165                                                               }
166           31                                114               $para = <$fh>; # read next paragraph, probably short help desc
167                                                            }
168                                                            else {
169            5                                 23               MKDEBUG && _d('Option has no attributes');
170                                                            }
171                                                   
172                                                            # Remove extra spaces and POD formatting (L<"">).
173           36                                185            $para =~ s/\s+\Z//g;
174           36                                149            $para =~ s/\s+/ /g;
175           36                                131            $para =~ s/$POD_link_re/$1/go;
176                                                   
177                                                            # Take the first period-terminated sentence as the option's short help
178                                                            # description.
179           36                                128            $para =~ s/\.(?:\n.*| [A-Z].*|\Z)//s;
180           36                                 75            MKDEBUG && _d('Short help:', $para);
181                                                   
182           36    100                         141            die "No description after option spec $option" if $para =~ m/^=item/;
183                                                   
184                                                            # Change [no]foo to foo and set negatable attrib. See issue 140.
185           35    100                         156            if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
186            1                                  3               $option = $base_option;
187            1                                  9               $attribs{'negatable'} = 1;
188                                                            }
189                                                   
190           35    100                         552            push @specs, {
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
191                                                               spec  => $option
192                                                                  . ($attribs{'short form'} ? '|' . $attribs{'short form'} : '' )
193                                                                  . ($attribs{'negatable'}  ? '!'                          : '' )
194                                                                  . ($attribs{'cumulative'} ? '+'                          : '' )
195                                                                  . ($attribs{'type'}       ? '=' . $types{$attribs{type}} : '' ),
196                                                               desc  => $para
197                                                                  . ($attribs{default} ? " (default $attribs{default})" : ''),
198                                                               group => ($attribs{'group'} ? $attribs{'group'} : 'default'),
199                                                            };
200                                                         }
201           42                                228         while ( $para = <$fh> ) {
202   ***     56     50                         188            last unless $para;
203                                                   
204                                                            # The 'allowed with' hack that was here was removed.
205                                                            # Groups need to be used instead. So, this new OptionParser
206                                                            # module will not work with mk-table-sync.
207                                                   
208           56    100                         207            if ( $para =~ m/^=head1/ ) {
209            5                                 16               $para = undef; # Can't 'last' out of a do {} block.
210            5                                 28               last;
211                                                            }
212           51    100                         310            last if $para =~ m/^=item --/;
213                                                         }
214                                                      } while ( $para );
215                                                   
216            5    100                          20      die 'No valid specs in POD OPTIONS' unless @specs;
217                                                   
218            4                                 41      close $fh;
219            4                                 11      return @specs, @rules;
220                                                   }
221                                                   
222                                                   # Parse an array of option specs and rules (usually the return value of
223                                                   # _pod_to_spec()). Each option spec is parsed and the following attributes
224                                                   # pairs are added to its hashref:
225                                                   #    short         => the option's short key (-A for --charset)
226                                                   #    is_cumulative => true if the option is cumulative
227                                                   #    is_negatable  => true if the option is negatable
228                                                   #    is_required   => true if the option is required
229                                                   #    type          => the option's type (see %types in _pod_to_spec() above)
230                                                   #    got           => true if the option was given explicitly on the cmd line
231                                                   #    value         => the option's value
232                                                   #
233                                                   sub _parse_specs {
234           32                   32           173      my ( $self, @specs ) = @_;
235           32                                 90      my %disables; # special rule that requires deferred checking
236                                                   
237           32                                129      foreach my $opt ( @specs ) {
238          119    100                         417         if ( ref $opt ) { # It's an option spec, not a rule.
239                                                            MKDEBUG && _d('Parsing opt spec:',
240          108                                226               map { ($_, '=>', $opt->{$_}) } keys %$opt);
241                                                   
242          108                                736            my ( $long, $short ) = $opt->{spec} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
243   ***    108     50                         442            if ( !$long ) {
244                                                               # This shouldn't happen.
245   ***      0                                  0               die "Cannot parse long option from spec $opt->{spec}";
246                                                            }
247          108                                359            $opt->{long} = $long;
248                                                   
249   ***    108     50                         479            die "Duplicate long option --$long" if exists $self->{opts}->{$long};
250          108                                411            $self->{opts}->{$long} = $opt;
251                                                   
252          108    100                         417            if ( length $long == 1 ) {
253            5                                 17               MKDEBUG && _d('Long opt', $long, 'looks like short opt');
254            5                                 21               $self->{short_opts}->{$long} = $long;
255                                                            }
256                                                   
257          108    100                         328            if ( $short ) {
258   ***     39     50                         182               die "Duplicate short option -$short"
259                                                                  if exists $self->{short_opts}->{$short};
260           39                                153               $self->{short_opts}->{$short} = $long;
261           39                                130               $opt->{short} = $short;
262                                                            }
263                                                            else {
264           69                                238               $opt->{short} = undef;
265                                                            }
266                                                   
267          108    100                         552            $opt->{is_negatable}  = $opt->{spec} =~ m/!/        ? 1 : 0;
268          108    100                         507            $opt->{is_cumulative} = $opt->{spec} =~ m/\+/       ? 1 : 0;
269          108    100                         534            $opt->{is_required}   = $opt->{desc} =~ m/required/ ? 1 : 0;
270                                                   
271          108           100                  501            $opt->{group} ||= 'default';
272          108                                541            $self->{groups}->{ $opt->{group} }->{$long} = 1;
273                                                   
274          108                                410            $opt->{value} = undef;
275          108                                337            $opt->{got}   = 0;
276                                                   
277          108                                545            my ( $type ) = $opt->{spec} =~ m/=(.)/;
278          108                                361            $opt->{type} = $type;
279          108                                240            MKDEBUG && _d($long, 'type:', $type);
280                                                   
281   ***    108     50    100                  845            if ( $type && $type eq 'd' && !$self->{dp} ) {
      ***                   66                        
282   ***      0                                  0               die "$opt->{long} is type DSN (d) but no dp argument "
283                                                                  . "was given when this OptionParser object was created";
284                                                            }
285                                                   
286                                                            # Option has a non-Getopt type: HhAadzm (see %types in
287                                                            # _pod_to_spec() above). For these, use Getopt type 's'.
288          108    100    100                  801            $opt->{spec} =~ s/=./=s/ if ( $type && $type =~ m/[HhAadzm]/ );
289                                                   
290                                                            # Option has a default value if its desc says 'default' or 'default X'.
291                                                            # These defaults from the POD may be overridden by later calls
292                                                            # to set_defaults().
293          108    100                         606            if ( (my ($def) = $opt->{desc} =~ m/default\b(?: ([^)]+))?/) ) {
294                                                               # This allows "default yes" for negatable opts. See issue 404.
295           17    100                          73               if ( $opt->{is_negatable} ) {
296   ***      1      0                           7                  $def = $def eq 'yes' ? 1
      ***            50                               
297                                                                       : $def eq 'no'  ? 0
298                                                                       : $def;
299                                                               }
300           17    100                          85               $self->{defaults}->{$long} = defined $def ? $def : 1;
301           17                                 39               MKDEBUG && _d($long, 'default:', $def);
302                                                            }
303                                                   
304                                                            # Handle special behavior for --config.
305          108    100                         416            if ( $long eq 'config' ) {
306            5                                 30               $self->{defaults}->{$long} = join(',', $self->get_defaults_files());
307                                                            }
308                                                   
309                                                            # Option disable another option if its desc says 'disable'.
310          108    100                         537            if ( (my ($dis) = $opt->{desc} =~ m/(disables .*)/) ) {
311                                                               # Defer checking till later because of possible forward references.
312            3                                 10               $disables{$long} = $dis;
313            3                                  7               MKDEBUG && _d('Deferring check of disables rule for', $opt, $dis);
314                                                            }
315                                                   
316                                                            # Save the option.
317          108                                505            $self->{opts}->{$long} = $opt;
318                                                         }
319                                                         else { # It's an option rule, not a spec.
320           11                                 26            MKDEBUG && _d('Parsing rule:', $opt); 
321           11                                 26            push @{$self->{rules}}, $opt;
              11                                 63   
322           11                                 49            my @participants = $self->_get_participants($opt);
323            9                                 28            my $rule_ok = 0;
324                                                   
325            9    100                          72            if ( $opt =~ m/mutually exclusive|one and only one/ ) {
326            4                                 10               $rule_ok = 1;
327            4                                 10               push @{$self->{mutex}}, \@participants;
               4                                 17   
328            4                                 11               MKDEBUG && _d(@participants, 'are mutually exclusive');
329                                                            }
330            9    100                          57            if ( $opt =~ m/at least one|one and only one/ ) {
331            4                                 10               $rule_ok = 1;
332            4                                 12               push @{$self->{atleast1}}, \@participants;
               4                                 15   
333            4                                 12               MKDEBUG && _d(@participants, 'require at least one');
334                                                            }
335            9    100                          43            if ( $opt =~ m/default to/ ) {
336            2                                  5               $rule_ok = 1;
337                                                               # Example: "DSN values in L<"--dest"> default to values
338                                                               # from L<"--source">."
339            2                                 10               $self->{defaults_to}->{$participants[0]} = $participants[1];
340            2                                  7               MKDEBUG && _d($participants[0], 'defaults to', $participants[1]);
341                                                            }
342            9    100                          37            if ( $opt =~ m/restricted to option groups/ ) {
343            1                                  3               $rule_ok = 1;
344            1                                  6               my ($groups) = $opt =~ m/groups ([\w\s\,]+)/;
345            1                                  7               my @groups = split(',', $groups);
346            1                                  8               %{$self->{allowed_groups}->{$participants[0]}} = map {
               4                                 11   
347            1                                  4                  s/\s+//;
348            4                                 15                  $_ => 1;
349                                                               } @groups;
350                                                            }
351                                                   
352   ***      9     50                          44            die "Unrecognized option rule: $opt" unless $rule_ok;
353                                                         }
354                                                      }
355                                                   
356                                                      # Check forward references in 'disables' rules.
357           30                                157      foreach my $long ( keys %disables ) {
358                                                         # _get_participants() will check that each opt exists.
359            2                                 10         my @participants = $self->_get_participants($disables{$long});
360            1                                  5         $self->{disables}->{$long} = \@participants;
361            1                                  4         MKDEBUG && _d('Option', $long, 'disables', @participants);
362                                                      }
363                                                   
364           29                                122      return; 
365                                                   }
366                                                   
367                                                   # Returns an array of long option names in str. This is used to
368                                                   # find the "participants" of option rules (i.e. the options to
369                                                   # which a rule applies).
370                                                   sub _get_participants {
371           15                   15            62      my ( $self, $str ) = @_;
372           15                                 42      my @participants;
373           15                                132      foreach my $long ( $str =~ m/--(?:\[no\])?([\w-]+)/g ) {
374           32    100                         145         die "Option --$long does not exist while processing rule $str"
375                                                            unless exists $self->{opts}->{$long};
376           29                                109         push @participants, $long;
377                                                      }
378           12                                 46      MKDEBUG && _d('Participants for', $str, ':', @participants);
379           12                                 74      return @participants;
380                                                   }
381                                                   
382                                                   # Returns a copy of the internal opts hash.
383                                                   sub opts {
384            4                    4            18      my ( $self ) = @_;
385            4                                 12      my %opts = %{$self->{opts}};
               4                                 43   
386            4                                 66      return %opts;
387                                                   }
388                                                   
389                                                   # Return a simplified option=>value hash like the original
390                                                   # %opts hash frequently used scripts. Some subs in other
391                                                   # modules, like DSNParser::get_cxn_params(), expect this
392                                                   # kind of hash.
393                                                   sub opt_values {
394            1                    1             4      my ( $self ) = @_;
395           12    100                          59      my %opts = map {
396            1                                  8         my $opt = $self->{opts}->{$_}->{short} ? $self->{opts}->{$_}->{short}
397                                                                 : $_;
398           12                                 58         $opt => $self->{opts}->{$_}->{value}
399            1                                  3      } keys %{$self->{opts}};
400            1                                 13      return %opts;
401                                                   }
402                                                   
403                                                   # Returns a copy of the internal short_opts hash.
404                                                   sub short_opts {
405            1                    1             5      my ( $self ) = @_;
406            1                                  2      my %short_opts = %{$self->{short_opts}};
               1                                  7   
407            1                                 23      return %short_opts;
408                                                   }
409                                                   
410                                                   sub set_defaults {
411            5                    5            28      my ( $self, %defaults ) = @_;
412            5                                 22      $self->{defaults} = {};
413            5                                 28      foreach my $long ( keys %defaults ) {
414            3    100                          17         die "Cannot set default for nonexistent option $long"
415                                                            unless exists $self->{opts}->{$long};
416            2                                  9         $self->{defaults}->{$long} = $defaults{$long};
417            2                                  7         MKDEBUG && _d('Default val for', $long, ':', $defaults{$long});
418                                                      }
419            4                                 15      return;
420                                                   }
421                                                   
422                                                   sub get_defaults {
423            3                    3            12      my ( $self ) = @_;
424            3                                 19      return $self->{defaults};
425                                                   }
426                                                   
427                                                   sub get_groups {
428            1                    1             4      my ( $self ) = @_;
429            1                                 14      return $self->{groups};
430                                                   }
431                                                   
432                                                   # Getopt::Long calls this sub for each opt it finds on the
433                                                   # cmd line. We have to do this in order to know which opts
434                                                   # were "got" on the cmd line.
435                                                   sub _set_option {
436           63                   63           266      my ( $self, $opt, $val ) = @_;
437   ***     63      0                         155      my $long = exists $self->{opts}->{$opt}       ? $opt
      ***            50                               
438                                                               : exists $self->{short_opts}->{$opt} ? $self->{short_opts}->{$opt}
439                                                               : die "Getopt::Long gave a nonexistent option: $opt";
440                                                   
441                                                      # Reassign $opt.
442           63                                133      $opt = $self->{opts}->{$long};
443           63    100                         426      if ( $opt->{is_cumulative} ) {
444            8                                 25         $opt->{value}++;
445                                                      }
446                                                      else {
447           55                                199         $opt->{value} = $val;
448                                                      }
449           63                                204      $opt->{got} = 1;
450           63                                225      MKDEBUG && _d('Got option', $long, '=', $val);
451                                                   }
452                                                   
453                                                   # Get options on the command line (ARGV) according to the option specs
454                                                   # and enforce option rules. Option values are saved internally in
455                                                   # $self->{opts} and accessed later by get(), got() and set().
456                                                   sub get_opts {
457           55                   55           211      my ( $self ) = @_; 
458                                                   
459                                                      # Reset opts. 
460           55                                160      foreach my $long ( keys %{$self->{opts}} ) {
              55                                360   
461          200                                776         $self->{opts}->{$long}->{got} = 0;
462          200    100                        1614         $self->{opts}->{$long}->{value}
                    100                               
463                                                            = exists $self->{defaults}->{$long}       ? $self->{defaults}->{$long}
464                                                            : $self->{opts}->{$long}->{is_cumulative} ? 0
465                                                            : undef;
466                                                      }
467           55                                215      $self->{got_opts} = 0;
468                                                   
469                                                      # Reset errors.
470           55                                201      $self->{errors} = [];
471                                                   
472                                                      # --config is special-case; parse them manually and remove them from @ARGV
473           55    100    100                  453      if ( @ARGV && $ARGV[0] eq "--config" ) {
474            4                                 12         shift @ARGV;
475            4                                 30         $self->_set_option('config', shift @ARGV);
476                                                      }
477           55    100                         234      if ( $self->has('config') ) {
478            6                                 17         my @extra_args;
479            6                                 31         foreach my $filename ( split(',', $self->get('config')) ) {
480                                                            # Try to open the file.  If it was set explicitly, it's an error if it
481                                                            # can't be opened, but the built-in defaults are to be ignored if they
482                                                            # can't be opened.
483           13                                 35            eval {
484           13                                 61               push @ARGV, $self->_read_config_file($filename);
485                                                            };
486           13    100                          81            if ( $EVAL_ERROR ) {
487            9    100                          38               if ( $self->got('config') ) {
488            1                                  3                  die $EVAL_ERROR;
489                                                               }
490                                                               elsif ( MKDEBUG ) {
491                                                                  _d($EVAL_ERROR);
492                                                               }
493                                                            }
494                                                         }
495            5                                 22         unshift @ARGV, @extra_args;
496                                                      }
497                                                   
498           54                                283      Getopt::Long::Configure('no_ignore_case', 'bundling');
499                                                      GetOptions(
500                                                         # Make Getopt::Long specs for each option with custom handler subs.
501          193                   59          1381         map    { $_->{spec} => sub { $self->_set_option(@_); } }
              59                                256   
             198                                971   
502           54                                266         grep   { $_->{long} ne 'config' } # --config is handled specially above.
503           54    100                         156         values %{$self->{opts}}
504                                                      ) or $self->save_error('Error parsing options');
505                                                   
506   ***     54     50     66                  645      if ( exists $self->{opts}->{version} && $self->{opts}->{version}->{got} ) {
507   ***      0      0                           0         printf("%s  Ver %s Distrib %s Changeset %s\n",
508                                                            $self->{program_name}, $main::VERSION, $main::DISTRIB, $main::SVN_REV)
509                                                               or die "Cannot print: $OS_ERROR";
510   ***      0                                  0         exit 0;
511                                                      }
512                                                   
513           54    100    100                  289      if ( @ARGV && $self->{strict} ) {
514            1                                  8         $self->save_error("Unrecognized command-line options @ARGV");
515                                                      }
516                                                   
517                                                      # Check mutex options.
518           54                                146      foreach my $mutex ( @{$self->{mutex}} ) {
              54                                269   
519            6                                 20         my @set = grep { $self->{opts}->{$_}->{got} } @$mutex;
              15                                 70   
520            6    100                          30         if ( @set > 1 ) {
521            5                                 39            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               3                                 12   
522            3                                 16                         @{$mutex}[ 0 .. scalar(@$mutex) - 2] )
523                                                                    . ' and --'.$self->{opts}->{$mutex->[-1]}->{long}
524                                                                    . ' are mutually exclusive.';
525            3                                 13            $self->save_error($err);
526                                                         }
527                                                      }
528                                                   
529           54                                157      foreach my $required ( @{$self->{atleast1}} ) {
              54                                238   
530            4                                 15         my @set = grep { $self->{opts}->{$_}->{got} } @$required;
              12                                 53   
531            4    100                          21         if ( @set == 0 ) {
532            4                                 28            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               2                                  6   
533            2                                 11                         @{$required}[ 0 .. scalar(@$required) - 2] )
534                                                                    .' or --'.$self->{opts}->{$required->[-1]}->{long};
535            2                                 10            $self->save_error("Specify at least one of $err");
536                                                         }
537                                                      }
538                                                   
539           54                                141      foreach my $long ( keys %{$self->{opts}} ) {
              54                                270   
540          198                                727         my $opt = $self->{opts}->{$long};
541          198    100                        1113         if ( $opt->{got} ) {
                    100                               
542                                                            # Rule: opt disables other opts.
543           58    100                         258            if ( exists $self->{disables}->{$long} ) {
544            1                                  3               my @disable_opts = @{$self->{disables}->{$long}};
               1                                  5   
545            1                                  4               map { $self->{opts}->{$_}->{value} = undef; } @disable_opts;
               1                                  5   
546            1                                  2               MKDEBUG && _d('Unset options', @disable_opts,
547                                                                  'because', $long,'disables them');
548                                                            }
549                                                   
550                                                            # Group restrictions.
551           58    100                         290            if ( exists $self->{allowed_groups}->{$long} ) {
552                                                               # This option is only allowed with other options from
553                                                               # certain groups.  Check that no options from restricted
554                                                               # groups were gotten.
555                                                   
556           10                                 44               my @restricted_groups = grep {
557            2                                 10                  !exists $self->{allowed_groups}->{$long}->{$_}
558            2                                  6               } keys %{$self->{groups}};
559                                                   
560            2                                  8               my @restricted_opts;
561            2                                  6               foreach my $restricted_group ( @restricted_groups ) {
562            2                                 11                  RESTRICTED_OPT:
563            2                                  5                  foreach my $restricted_opt (
564                                                                     keys %{$self->{groups}->{$restricted_group}} )
565                                                                  {
566            4    100                          22                     next RESTRICTED_OPT if $restricted_opt eq $long;
567            2    100                          12                     push @restricted_opts, $restricted_opt
568                                                                        if $self->{opts}->{$restricted_opt}->{got};
569                                                                  }
570                                                               }
571                                                   
572            2    100                           8               if ( @restricted_opts ) {
573            1                                  2                  my $err;
574   ***      1     50                           5                  if ( @restricted_opts == 1 ) {
575            1                                  4                     $err = "--$restricted_opts[0]";
576                                                                  }
577                                                                  else {
578   ***      0                                  0                     $err = join(', ',
579   ***      0                                  0                               map { "--$self->{opts}->{$_}->{long}" }
580   ***      0                                  0                               grep { $_ } 
581                                                                               @restricted_opts[0..scalar(@restricted_opts) - 2]
582                                                                            )
583                                                                          . ' or --'.$self->{opts}->{$restricted_opts[-1]}->{long};
584                                                                  }
585            1                                  6                  $self->save_error("--$long is not allowed with $err");
586                                                               }
587                                                            }
588                                                   
589                                                         }
590                                                         elsif ( $opt->{is_required} ) { 
591            3                                 18            $self->save_error("Required option --$long must be specified");
592                                                         }
593                                                   
594          198                                738         $self->_validate_type($opt);
595                                                      }
596                                                   
597           54                                204      $self->{got_opts} = 1;
598           54                                180      return;
599                                                   }
600                                                   
601                                                   sub _validate_type {
602          198                  198           676      my ( $self, $opt ) = @_;
603   ***    198    100     66                 1646      return unless $opt && $opt->{type};
604          113                                359      my $val = $opt->{value};
605                                                   
606          113    100    100                 2498      if ( $val && $opt->{type} eq 'm' ) {
                    100    100                        
                    100    100                        
                    100    100                        
                    100    100                        
                           100                        
                           100                        
607            8                                 20         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a time value');
608            8                                 63         my ( $num, $suffix ) = $val =~ m/(\d+)([a-z])?$/;
609                                                         # The suffix defaults to 's' unless otherwise specified.
610            8    100                          36         if ( !$suffix ) {
611            5                                 29            my ( $s ) = $opt->{desc} =~ m/\(suffix (.)\)/;
612            5           100                  107            $suffix = $s || 's';
613            5                                 15            MKDEBUG && _d('No suffix given; using', $suffix, 'for',
614                                                               $opt->{long}, '(value:', $val, ')');
615                                                         }
616            8    100                          36         if ( $suffix =~ m/[smhd]/ ) {
617            7    100                          54            $val = $suffix eq 's' ? $num            # Seconds
                    100                               
                    100                               
618                                                                 : $suffix eq 'm' ? $num * 60       # Minutes
619                                                                 : $suffix eq 'h' ? $num * 3600     # Hours
620                                                                 :                  $num * 86400;   # Days
621            7                                 23            $opt->{value} = $val;
622            7                                 17            MKDEBUG && _d('Setting option', $opt->{long}, 'to', $val);
623                                                         }
624                                                         else {
625            1                                  7            $self->save_error("Invalid time suffix for --$opt->{long}");
626                                                         }
627                                                      }
628                                                      elsif ( $val && $opt->{type} eq 'd' ) {
629            5                                 13         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a DSN');
630            5                                 20         my $from_key = $self->{defaults_to}->{ $opt->{long} };
631            5                                 15         my $default = {};
632            5    100                          20         if ( $from_key ) {
633            2                                  4            MKDEBUG && _d($opt->{long}, 'DSN copies from', $from_key, 'DSN');
634            2                                 16            $default = $self->{dp}->parse(
635                                                               $self->{dp}->as_string($self->{opts}->{$from_key}->{value}) );
636                                                         }
637            5                                 33         $opt->{value} = $self->{dp}->parse($val, $default);
638                                                      }
639                                                      elsif ( $val && $opt->{type} eq 'z' ) {
640            6                                 14         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a size value');
641            6                                 32         my %factor_for = (k => 1_024, M => 1_048_576, G => 1_073_741_824);
642            6                                 46         my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
643            6    100                          25         if ( defined $num ) {
644            5    100                          24            if ( $factor ) {
645            4                                 14               $num *= $factor_for{$factor};
646            4                                 10               MKDEBUG && _d('Setting option', $opt->{y},
647                                                                  'to num', $num, '* factor', $factor);
648                                                            }
649            5           100                   42            $opt->{value} = ($pre || '') . $num;
650                                                         }
651                                                         else {
652            1                                  6            $self->save_error("Invalid size for --$opt->{long}");
653                                                         }
654                                                      }
655                                                      elsif ( $opt->{type} eq 'H' || (defined $val && $opt->{type} eq 'h') ) {
656            6           100                   45         $opt->{value} = { map { $_ => 1 } split(',', ($val || '')) };
               4                                 19   
657                                                      }
658                                                      elsif ( $opt->{type} eq 'A' || (defined $val && $opt->{type} eq 'a') ) {
659           15           100                  160         $opt->{value} = [ split(/(?<!\\),/, ($val || '')) ];
660                                                      }
661                                                      else {
662           73                                165         MKDEBUG && _d('Nothing to validate for option',
663                                                            $opt->{long}, 'type', $opt->{type}, 'value', $val);
664                                                      }
665                                                   
666          113                                406      return;
667                                                   }
668                                                   
669                                                   # Get an option's value. The option can be either a
670                                                   # short or long name (e.g. -A or --charset).
671                                                   sub get {
672           65                   65           295      my ( $self, $opt ) = @_;
673           65    100                         329      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
674           65    100    100                  583      die "Option $opt does not exist"
675                                                         unless $long && exists $self->{opts}->{$long};
676           62                                565      return $self->{opts}->{$long}->{value};
677                                                   }
678                                                   
679                                                   # Returns true if the option was given explicitly on the
680                                                   # command line; returns false if not. The option can be
681                                                   # either short or long name (e.g. -A or --charset).
682                                                   sub got {
683           31                   31           140      my ( $self, $opt ) = @_;
684           31    100                         146      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
685           31    100    100                  263      die "Option $opt does not exist"
686                                                         unless $long && exists $self->{opts}->{$long};
687           29                                210      return $self->{opts}->{$long}->{got};
688                                                   }
689                                                   
690                                                   # Returns true if the option exists.
691                                                   sub has {
692           62                   62           258      my ( $self, $opt ) = @_;
693           62    100                         299      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
694           62    100                         460      return defined $long ? exists $self->{opts}->{$long} : 0;
695                                                   }
696                                                   
697                                                   # Set an option's value. The option can be either a
698                                                   # short or long name (e.g. -A or --charset). The value
699                                                   # can be any scalar, ref, or undef. No type checking
700                                                   # is done so becareful to not set, for example, an integer
701                                                   # option with a DSN.
702                                                   sub set {
703            5                    5            26      my ( $self, $opt, $val ) = @_;
704            5    100                          26      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
705            5    100    100                   36      die "Option $opt does not exist"
706                                                         unless $long && exists $self->{opts}->{$long};
707            3                                 13      $self->{opts}->{$long}->{value} = $val;
708            3                                  8      return;
709                                                   }
710                                                   
711                                                   # Save an error message to be reported later by calling usage_or_errors()
712                                                   # (or errors()--mostly for testing).
713                                                   sub save_error {
714           15                   15            70      my ( $self, $error ) = @_;
715           15                                 45      push @{$self->{errors}}, $error;
              15                                 79   
716                                                   }
717                                                   
718                                                   # Return arrayref of errors (mostly for testing).
719                                                   sub errors {
720           13                   13            54      my ( $self ) = @_;
721           13                                112      return $self->{errors};
722                                                   }
723                                                   
724                                                   sub prompt {
725           11                   11            42      my ( $self ) = @_;
726           11                                 73      return "Usage: $PROGRAM_NAME $self->{prompt}\n";
727                                                   }
728                                                   
729                                                   sub descr {
730           11                   11            36      my ( $self ) = @_;
731   ***     11            50                  108      my $descr  = $self->{program_name} . ' ' . ($self->{description} || '')
732                                                                 . "  For more details, please use the --help option, "
733                                                                 . "or try 'perldoc $PROGRAM_NAME' "
734                                                                 . "for complete documentation.";
735           11                                120      $descr = join("\n", $descr =~ m/(.{0,80})(?:\s+|$)/g);
736           11                                 94      $descr =~ s/ +$//mg;
737           11                                 72      return $descr;
738                                                   }
739                                                   
740                                                   sub usage_or_errors {
741   ***      0                    0             0      my ( $self ) = @_;
742   ***      0      0                           0      if ( $self->{opts}->{help}->{got} ) {
      ***      0      0                           0   
743   ***      0      0                           0         print $self->print_usage() or die "Cannot print usage: $OS_ERROR";
744   ***      0                                  0         exit 0;
745                                                      }
746                                                      elsif ( scalar @{$self->{errors}} ) {
747   ***      0      0                           0         print $self->print_errors() or die "Cannot print errors: $OS_ERROR";
748   ***      0                                  0         exit 0;
749                                                      }
750   ***      0                                  0      return;
751                                                   }
752                                                   
753                                                   # Explains what errors were found while processing command-line arguments and
754                                                   # gives a brief overview so you can get more information.
755                                                   sub print_errors {
756            1                    1             4      my ( $self ) = @_;
757            1                                  5      my $usage = $self->prompt() . "\n";
758   ***      1     50                           4      if ( (my @errors = @{$self->{errors}}) ) {
               1                                  7   
759            1                                  6         $usage .= join("\n  * ", 'Errors in command-line arguments:', @errors)
760                                                                 . "\n";
761                                                      }
762            1                                  5      return $usage . "\n" . $self->descr();
763                                                   }
764                                                   
765                                                   # Prints out command-line help.  The format is like this:
766                                                   # --foo  -F   Description of --foo
767                                                   # --bars -B   Description of --bar
768                                                   # --longopt   Description of --longopt
769                                                   # Note that the short options are aligned along the right edge of their longest
770                                                   # long option, but long options that don't have a short option are allowed to
771                                                   # protrude past that.
772                                                   sub print_usage {
773           10                   10            44      my ( $self ) = @_;
774   ***     10     50                          50      die "Run get_opts() before print_usage()" unless $self->{got_opts};
775           10                                 24      my @opts = values %{$self->{opts}};
              10                                 54   
776                                                   
777                                                      # Find how wide the widest long option is.
778           32    100                         207      my $maxl = max(
779           10                                 38         map { length($_->{long}) + ($_->{is_negatable} ? 4 : 0) }
780                                                         @opts);
781                                                   
782                                                      # Find how wide the widest option with a short option is.
783   ***     12     50                          74      my $maxs = max(0,
784           10                                 52         map { length($_) + ($self->{opts}->{$_}->{is_negatable} ? 4 : 0) }
785           10                                 34         values %{$self->{short_opts}});
786                                                   
787                                                      # Find how wide the 'left column' (long + short opts) is, and therefore how
788                                                      # much space to give options and how much to give descriptions.
789           10                                 47      my $lcol = max($maxl, ($maxs + 3));
790           10                                 35      my $rcol = 80 - $lcol - 6;
791           10                                 41      my $rpad = ' ' x ( 80 - $rcol );
792                                                   
793                                                      # Adjust the width of the options that have long and short both.
794           10                                 41      $maxs = max($lcol - 3, $maxs);
795                                                   
796                                                      # Format and return the options.
797           10                                 44      my $usage = $self->descr() . "\n" . $self->prompt();
798                                                   
799                                                      # Sort groups alphabetically but make 'default' first.
800           10                                 34      my @groups = reverse sort grep { $_ ne 'default'; } keys %{$self->{groups}};
              14                                 77   
              10                                 51   
801           10                                 36      push @groups, 'default';
802                                                   
803           10                                 40      foreach my $group ( reverse @groups ) {
804           14    100                          66         $usage .= "\n".($group eq 'default' ? 'Options' : $group).":\n\n";
805           14                                 49         foreach my $opt (
              22                                 90   
806           64                                221            sort { $a->{long} cmp $b->{long} }
807                                                            grep { $_->{group} eq $group }
808                                                            @opts )
809                                                         {
810           32    100                         171            my $long  = $opt->{is_negatable} ? "[no]$opt->{long}" : $opt->{long};
811           32                                 97            my $short = $opt->{short};
812           32                                100            my $desc  = $opt->{desc};
813                                                            # Expand suffix help for time options.
814           32    100    100                  252            if ( $opt->{type} && $opt->{type} eq 'm' ) {
815            2                                  9               my ($s) = $desc =~ m/\(suffix (.)\)/;
816            2           100                    9               $s    ||= 's';
817            2                                  8               $desc =~ s/\s+\(suffix .\)//;
818            2                                  9               $desc .= ".  Optional suffix s=seconds, m=minutes, h=hours, "
819                                                                      . "d=days; if no suffix, $s is used.";
820                                                            }
821                                                            # Wrap long descriptions
822           32                                423            $desc = join("\n$rpad", grep { $_ } $desc =~ m/(.{0,$rcol})(?:\s+|$)/g);
              69                                231   
823           32                                153            $desc =~ s/ +$//mg;
824           32    100                         103            if ( $short ) {
825           12                                 89               $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
826                                                            }
827                                                            else {
828           20                                142               $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
829                                                            }
830                                                         }
831                                                      }
832                                                   
833           10    100                          29      if ( (my @rules = @{$self->{rules}}) ) {
              10                                 67   
834            4                                 12         $usage .= "\nRules:\n\n";
835            4                                 16         $usage .= join("\n", map { "  $_" } @rules) . "\n";
               4                                 21   
836                                                      }
837           10    100                          46      if ( $self->{dp} ) {
838            2                                 14         $usage .= "\n" . $self->{dp}->usage();
839                                                      }
840           10                                 33      $usage .= "\nOptions and values after processing arguments:\n\n";
841           10                                 19      foreach my $opt ( sort { $a->{long} cmp $b->{long} } @opts ) {
              34                                118   
842           32                                117         my $val   = $opt->{value};
843           32           100                  169         my $type  = $opt->{type} || '';
844           32                                184         my $bool  = $opt->{spec} =~ m/^[\w-]+(?:\|[\w-])?!?$/;
845           32    100                         221         $val      = $bool                     ? ( $val ? 'TRUE' : 'FALSE' )
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
846                                                                   : !defined $val             ? '(No value)'
847                                                                   : $type eq 'd'              ? $self->{dp}->as_string($val)
848                                                                   : $type =~ m/H|h/           ? join(',', sort keys %$val)
849                                                                   : $type =~ m/A|a/           ? join(',', @$val)
850                                                                   :                             $val;
851           32                                204         $usage .= sprintf("  --%-${lcol}s  %s\n", $opt->{long}, $val);
852                                                      }
853           10                                 98      return $usage;
854                                                   }
855                                                   
856                                                   # Tries to prompt and read the answer without echoing the answer to the
857                                                   # terminal.  This isn't really related to this package, but it's too handy not
858                                                   # to put here.  OK, it's related, it gets config information from the user.
859                                                   sub prompt_noecho {
860   ***      0      0             0             0      shift @_ if ref $_[0] eq __PACKAGE__;
861   ***      0                                  0      my ( $prompt ) = @_;
862   ***      0                                  0      local $OUTPUT_AUTOFLUSH = 1;
863   ***      0      0                           0      print $prompt
864                                                         or die "Cannot print: $OS_ERROR";
865   ***      0                                  0      my $response;
866   ***      0                                  0      eval {
867   ***      0                                  0         require Term::ReadKey;
868   ***      0                                  0         Term::ReadKey::ReadMode('noecho');
869   ***      0                                  0         chomp($response = <STDIN>);
870   ***      0                                  0         Term::ReadKey::ReadMode('normal');
871   ***      0      0                           0         print "\n"
872                                                            or die "Cannot print: $OS_ERROR";
873                                                      };
874   ***      0      0                           0      if ( $EVAL_ERROR ) {
875   ***      0                                  0         die "Cannot read response; is Term::ReadKey installed? $EVAL_ERROR";
876                                                      }
877   ***      0                                  0      return $response;
878                                                   }
879                                                   
880                                                   # This is debug code I want to run for all tools, and this is a module I
881                                                   # certainly include in all tools, but otherwise there's no real reason to put
882                                                   # it here.
883                                                   if ( MKDEBUG ) {
884                                                      print '# ', $^X, ' ', $], "\n";
885                                                      my $uname = `uname -a`;
886                                                      if ( $uname ) {
887                                                         $uname =~ s/\s+/ /g;
888                                                         print "# $uname\n";
889                                                      }
890                                                      printf("# %s  Ver %s Distrib %s Changeset %s line %d\n",
891                                                         $PROGRAM_NAME, ($main::VERSION || ''), ($main::DISTRIB || ''),
892                                                         ($main::SVN_REV || ''), __LINE__);
893                                                      print('# Arguments: ',
894                                                         join(' ', map { my $a = "_[$_]_"; $a =~ s/\n/\n# /g; $a; } @ARGV), "\n");
895                                                   }
896                                                   
897                                                   # Reads a configuration file and returns it as a list.  Inspired by
898                                                   # Config::Tiny.
899                                                   sub _read_config_file {
900           14                   14            60      my ( $self, $filename ) = @_;
901           14    100                         169      open my $fh, "<", $filename or die "Cannot open $filename: $OS_ERROR\n";
902            5                                 14      my @args;
903            5                                 15      my $prefix = '--';
904            5                                 17      my $parse  = 1;
905                                                   
906                                                      LINE:
907            5                                 78      while ( my $line = <$fh> ) {
908           23                                 62         chomp $line;
909                                                         # Skip comments and empty lines
910           23    100                         131         next LINE if $line =~ m/^\s*(?:\#|\;|$)/;
911                                                         # Remove inline comments
912           19                                 61         $line =~ s/\s+#.*$//g;
913                                                         # Remove whitespace
914           19                                 98         $line =~ s/^\s+|\s+$//g;
915                                                         # Watch for the beginning of the literal values (not to be interpreted as
916                                                         # options)
917           19    100                          73         if ( $line eq '--' ) {
918            4                                 11            $prefix = '';
919            4                                 10            $parse  = 0;
920            4                                 18            next LINE;
921                                                         }
922   ***     15    100     66                  153         if ( $parse
      ***            50                               
923                                                            && (my($opt, $arg) = $line =~ m/^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/)
924                                                         ) {
925            8                                 33            push @args, grep { defined $_ } ("$prefix$opt", $arg);
              16                                 82   
926                                                         }
927                                                         elsif ( $line =~ m/./ ) {
928            7                                 51            push @args, $line;
929                                                         }
930                                                         else {
931   ***      0                                  0            die "Syntax error in file $filename at line $INPUT_LINE_NUMBER";
932                                                         }
933                                                      }
934            5                                 35      close $fh;
935            5                                 12      return @args;
936                                                   }
937                                                   
938                                                   # Reads the next paragraph from the POD after the magical regular expression is
939                                                   # found in the text.
940                                                   sub read_para_after {
941            2                    2            12      my ( $self, $file, $regex ) = @_;
942   ***      2     50                          71      open my $fh, "<", $file or die "Can't open $file: $OS_ERROR";
943            2                                 18      local $INPUT_RECORD_SEPARATOR = '';
944            2                                  6      my $para;
945            2                                 38      while ( $para = <$fh> ) {
946            6    100                          39         next unless $para =~ m/^=pod$/m;
947            2                                  6         last;
948                                                      }
949            2                                 11      while ( $para = <$fh> ) {
950            7    100                          47         next unless $para =~ m/$regex/;
951            2                                  7         last;
952                                                      }
953            2                                  6      $para = <$fh>;
954            2                                  7      chomp($para);
955   ***      2     50                          20      close $fh or die "Can't close $file: $OS_ERROR";
956            2                                  6      return $para;
957                                                   }
958                                                   
959                                                   # Returns a lightweight clone of ourself.  Currently, only the basic
960                                                   # opts are copied.  This is used for stuff like "final opts" in
961                                                   # mk-table-checksum.
962                                                   sub clone {
963            1                    1             5      my ( $self ) = @_;
964                                                   
965                                                      # Deep-copy contents of hashrefs; do not just copy the refs. 
966            3                                 10      my %clone = map {
967            1                                  4         my $hashref  = $self->{$_};
968            3                                  8         my $val_copy = {};
969            3                                 12         foreach my $key ( keys %$hashref ) {
970            5                                 16            my $ref = ref $hashref->{$key};
971            3                                 33            $val_copy->{$key} = !$ref           ? $hashref->{$key}
972   ***      0                                  0                              : $ref eq 'HASH'  ? { %{$hashref->{$key}} }
973   ***      5      0                          26                              : $ref eq 'ARRAY' ? [ @{$hashref->{$key}} ]
      ***            50                               
                    100                               
974                                                                              : $hashref->{$key};
975                                                         }
976            3                                 19         $_ => $val_copy;
977                                                      } qw(opts short_opts defaults);
978                                                   
979                                                      # Re-assign scalar values.
980            1                                  4      foreach my $scalar ( qw(got_opts) ) {
981            1                                  6         $clone{$scalar} = $self->{$scalar};
982                                                      }
983                                                   
984            1                                  6      return bless \%clone;     
985                                                   }
986                                                   
987                                                   sub _d {
988            1                    1             8      my ($package, undef, $line) = caller 0;
989   ***      2     50                          12      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  8   
               2                                 12   
990            1                                  4           map { defined $_ ? $_ : 'undef' }
991                                                           @_;
992            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
993                                                   }
994                                                   
995                                                   1;
996                                                   
997                                                   # ###########################################################################
998                                                   # End OptionParser package
999                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***     50      0     33   unless $args{$arg}
51           100      1     32   exists $args{'strict'} ? :
108   ***     50      0      8   unless open my $fh, '<', $file
130          100     58      7   unless $para =~ /^=head1 OPTIONS/
136          100      7      1   if $para =~ /^=over/
144          100      1      7   unless $para
148          100     37      7   if (my($option) = $para =~ /^=item --(.*)/)
155          100     32      5   if ($para =~ /: /) { }
159          100      1     41   unless $attributes{$attrib}
163          100      6     25   if ($attribs{'short form'})
182          100      1     35   if $para =~ /^=item/
185          100      1     34   if (my($base_option) = $option =~ /^\[no\](.*)/)
190          100      6     29   $attribs{'short form'} ? :
             100      3     32   $attribs{'negatable'} ? :
             100      2     33   $attribs{'cumulative'} ? :
             100     23     12   $attribs{'type'} ? :
             100      2     33   $attribs{'default'} ? :
             100      6     29   $attribs{'group'} ? :
202   ***     50      0     56   unless $para
208          100      5     51   if ($para =~ /^=head1/)
212          100     37     14   if $para =~ /^=item --/
216          100      1      4   unless @specs
238          100    108     11   if (ref $opt) { }
243   ***     50      0    108   if (not $long)
249   ***     50      0    108   if exists $$self{'opts'}{$long}
252          100      5    103   if (length $long == 1)
257          100     39     69   if ($short) { }
258   ***     50      0     39   if exists $$self{'short_opts'}{$short}
267          100      7    101   $$opt{'spec'} =~ /!/ ? :
268          100      4    104   $$opt{'spec'} =~ /\+/ ? :
269          100      3    105   $$opt{'desc'} =~ /required/ ? :
281   ***     50      0    108   if ($type and $type eq 'd' and not $$self{'dp'})
288          100     43     65   if $type and $type =~ /[HhAadzm]/
293          100     17     91   if (my($def) = $$opt{'desc'} =~ /default\b(?: ([^)]+))?/)
295          100      1     16   if ($$opt{'is_negatable'})
296   ***      0      0      0   $def eq 'no' ? :
      ***     50      1      0   $def eq 'yes' ? :
300          100     16      1   defined $def ? :
305          100      5    103   if ($long eq 'config')
310          100      3    105   if (my($dis) = $$opt{'desc'} =~ /(disables .*)/)
325          100      4      5   if ($opt =~ /mutually exclusive|one and only one/)
330          100      4      5   if ($opt =~ /at least one|one and only one/)
335          100      2      7   if ($opt =~ /default to/)
342          100      1      8   if ($opt =~ /restricted to option groups/)
352   ***     50      0      9   unless $rule_ok
374          100      3     29   unless exists $$self{'opts'}{$long}
395          100      2     10   $$self{'opts'}{$_}{'short'} ? :
414          100      1      2   unless exists $$self{'opts'}{$long}
437   ***      0      0      0   exists $$self{'short_opts'}{$opt} ? :
      ***     50     63      0   exists $$self{'opts'}{$opt} ? :
443          100      8     55   if ($$opt{'is_cumulative'}) { }
462          100     15    157   $$self{'opts'}{$long}{'is_cumulative'} ? :
             100     28    172   exists $$self{'defaults'}{$long} ? :
473          100      4     51   if (@ARGV and $ARGV[0] eq '--config')
477          100      6     49   if ($self->has('config'))
486          100      9      4   if ($EVAL_ERROR)
487          100      1      8   $self->got('config') ? :
503          100      3     51   unless GetOptions map({$$_{'spec'}, sub {
	$self->_set_option(@_);
}
;} grep({$$_{'long'} ne 'config';} values %{$$self{'opts'};}))
506   ***     50      0     54   if (exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'})
507   ***      0      0      0   unless printf "%s  Ver %s Distrib %s Changeset %s\n", $$self{'program_name'}, $main::VERSION, $main::DISTRIB, $main::SVN_REV
513          100      1     53   if (@ARGV and $$self{'strict'})
520          100      3      3   if (@set > 1)
531          100      2      2   if (@set == 0)
541          100     58    140   if ($$opt{'got'}) { }
             100      3    137   elsif ($$opt{'is_required'}) { }
543          100      1     57   if (exists $$self{'disables'}{$long})
551          100      2     56   if (exists $$self{'allowed_groups'}{$long})
566          100      2      2   if $restricted_opt eq $long
567          100      1      1   if $$self{'opts'}{$restricted_opt}{'got'}
572          100      1      1   if (@restricted_opts)
574   ***     50      1      0   if (@restricted_opts == 1) { }
603          100     85    113   unless $opt and $$opt{'type'}
606          100      8    105   if ($val and $$opt{'type'} eq 'm') { }
             100      5    100   elsif ($val and $$opt{'type'} eq 'd') { }
             100      6     94   elsif ($val and $$opt{'type'} eq 'z') { }
             100      6     88   elsif ($$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h') { }
             100     15     73   elsif ($$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a') { }
610          100      5      3   if (not $suffix)
616          100      7      1   if ($suffix =~ /[smhd]/) { }
617          100      2      1   $suffix eq 'h' ? :
             100      2      3   $suffix eq 'm' ? :
             100      2      5   $suffix eq 's' ? :
632          100      2      3   if ($from_key)
643          100      5      1   if (defined $num) { }
644          100      4      1   if ($factor)
673          100     18     47   length $opt == 1 ? :
674          100      3     62   unless $long and exists $$self{'opts'}{$long}
684          100      4     27   length $opt == 1 ? :
685          100      2     29   unless $long and exists $$self{'opts'}{$long}
693          100      2     60   length $opt == 1 ? :
694          100     61      1   defined $long ? :
704          100      2      3   length $opt == 1 ? :
705          100      2      3   unless $long and exists $$self{'opts'}{$long}
742   ***      0      0      0   if ($$self{'opts'}{'help'}{'got'}) { }
      ***      0      0      0   elsif (scalar @{$$self{'errors'};}) { }
743   ***      0      0      0   unless print $self->print_usage
747   ***      0      0      0   unless print $self->print_errors
758   ***     50      1      0   if (my(@errors) = @{$$self{'errors'};})
774   ***     50      0     10   unless $$self{'got_opts'}
778          100      3     29   $$_{'is_negatable'} ? :
783   ***     50      0     12   $$self{'opts'}{$_}{'is_negatable'} ? :
804          100     10      4   $group eq 'default' ? :
810          100      3     29   $$opt{'is_negatable'} ? :
814          100      2     30   if ($$opt{'type'} and $$opt{'type'} eq 'm')
824          100     12     20   if ($short) { }
833          100      4      6   if (my(@rules) = @{$$self{'rules'};})
837          100      2      8   if ($$self{'dp'})
845          100      1     10   $val ? :
             100      6      1   $type =~ /A|a/ ? :
             100      2      7   $type =~ /H|h/ ? :
             100      2      9   $type eq 'd' ? :
             100     10     11   !defined($val) ? :
             100     11     21   $bool ? :
860   ***      0      0      0   if ref $_[0] eq 'OptionParser'
863   ***      0      0      0   unless print $prompt
871   ***      0      0      0   unless print "\n"
874   ***      0      0      0   if ($EVAL_ERROR)
901          100      9      5   unless open my $fh, '<', $filename
910          100      4     19   if $line =~ /^\s*(?:\#|\;|$)/
917          100      4     15   if ($line eq '--')
922          100      8      7   if ($parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/) { }
      ***     50      7      0   elsif ($line =~ /./) { }
942   ***     50      0      2   unless open my $fh, '<', $file
946          100      4      2   unless $para =~ /^=pod$/m
950          100      5      2   unless $para =~ /$regex/
955   ***     50      0      2   unless close $fh
973   ***      0      0      0   $ref eq 'ARRAY' ? :
      ***     50      3      0   $ref eq 'HASH' ? :
             100      2      3   !$ref ? :
989   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
281          100     46     55      7   $type and $type eq 'd'
      ***     66    101      7      0   $type and $type eq 'd' and not $$self{'dp'}
288          100     46     19     43   $type and $type =~ /[HhAadzm]/
473          100     15     36      4   @ARGV and $ARGV[0] eq '--config'
506   ***     66     51      3      0   exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'}
513          100     51      2      1   @ARGV and $$self{'strict'}
603   ***     66      0     85    113   $opt and $$opt{'type'}
606          100     65     40      8   $val and $$opt{'type'} eq 'm'
             100     65     35      5   $val and $$opt{'type'} eq 'd'
             100     65     29      6   $val and $$opt{'type'} eq 'z'
             100     61     27      1   defined $val and $$opt{'type'} eq 'h'
             100     57     16      2   defined $val and $$opt{'type'} eq 'a'
674          100      1      2     62   $long and exists $$self{'opts'}{$long}
685          100      1      1     29   $long and exists $$self{'opts'}{$long}
705          100      1      1      3   $long and exists $$self{'opts'}{$long}
814          100     12     18      2   $$opt{'type'} and $$opt{'type'} eq 'm'
922   ***     66      7      0      8   $parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
48    ***     50     33      0   $program_name ||= $PROGRAM_NAME
49    ***     50     33      0   $ENV{'HOME'} || $ENV{'HOMEPATH'} || $ENV{'USERPROFILE'} || '.'
51           100      2     31   $args{'prompt'} || '<options>'
             100      7     26   $args{'dp'} || undef
107   ***     50      8      0   $file ||= '../OptionParser.pm'
271          100     49     59   $$opt{'group'} ||= 'default'
612          100      4      1   $s || 's'
649          100      2      3   $pre || ''
656          100      2      4   $val || ''
659          100     11      4   $val || ''
731   ***     50     11      0   $$self{'description'} || ''
816          100      1      1   $s ||= 's'
843          100     20     12   $$opt{'type'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
49    ***     33     33      0      0   $ENV{'HOME'} || $ENV{'HOMEPATH'}
      ***     33     33      0      0   $ENV{'HOME'} || $ENV{'HOMEPATH'} || $ENV{'USERPROFILE'}
606          100      5      1     88   $$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h'
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
__ANON__              59 /home/daniel/dev/maatkit/common/OptionParser.pm:501
_d                     1 /home/daniel/dev/maatkit/common/OptionParser.pm:988
_get_participants     15 /home/daniel/dev/maatkit/common/OptionParser.pm:371
_parse_specs          32 /home/daniel/dev/maatkit/common/OptionParser.pm:234
_pod_to_specs          8 /home/daniel/dev/maatkit/common/OptionParser.pm:106
_read_config_file     14 /home/daniel/dev/maatkit/common/OptionParser.pm:900
_set_option           63 /home/daniel/dev/maatkit/common/OptionParser.pm:436
_validate_type       198 /home/daniel/dev/maatkit/common/OptionParser.pm:602
clone                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:963
descr                 11 /home/daniel/dev/maatkit/common/OptionParser.pm:730
errors                13 /home/daniel/dev/maatkit/common/OptionParser.pm:720
get                   65 /home/daniel/dev/maatkit/common/OptionParser.pm:672
get_defaults           3 /home/daniel/dev/maatkit/common/OptionParser.pm:423
get_defaults_files     6 /home/daniel/dev/maatkit/common/OptionParser.pm:90 
get_groups             1 /home/daniel/dev/maatkit/common/OptionParser.pm:428
get_opts              55 /home/daniel/dev/maatkit/common/OptionParser.pm:457
get_specs              3 /home/daniel/dev/maatkit/common/OptionParser.pm:82 
got                   31 /home/daniel/dev/maatkit/common/OptionParser.pm:683
has                   62 /home/daniel/dev/maatkit/common/OptionParser.pm:692
new                   33 /home/daniel/dev/maatkit/common/OptionParser.pm:43 
opt_values             1 /home/daniel/dev/maatkit/common/OptionParser.pm:394
opts                   4 /home/daniel/dev/maatkit/common/OptionParser.pm:384
print_errors           1 /home/daniel/dev/maatkit/common/OptionParser.pm:756
print_usage           10 /home/daniel/dev/maatkit/common/OptionParser.pm:773
prompt                11 /home/daniel/dev/maatkit/common/OptionParser.pm:725
read_para_after        2 /home/daniel/dev/maatkit/common/OptionParser.pm:941
save_error            15 /home/daniel/dev/maatkit/common/OptionParser.pm:714
set                    5 /home/daniel/dev/maatkit/common/OptionParser.pm:703
set_defaults           5 /home/daniel/dev/maatkit/common/OptionParser.pm:411
short_opts             1 /home/daniel/dev/maatkit/common/OptionParser.pm:405

Uncovered Subroutines
---------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
prompt_noecho          0 /home/daniel/dev/maatkit/common/OptionParser.pm:860
usage_or_errors        0 /home/daniel/dev/maatkit/common/OptionParser.pm:741


