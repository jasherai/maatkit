---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/OptionParser.pm   93.5   83.7   86.5   94.6    n/a  100.0   89.9
Total                          93.5   83.7   86.5   94.6    n/a  100.0   89.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          OptionParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:22 2009
Finish:       Sat Aug 29 15:03:22 2009

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
18                                                    # OptionParser package $Revision: 4489 $
19                                                    # ###########################################################################
20                                                    package OptionParser;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  8   
24                                                    
25             1                    1            10   use Getopt::Long;
               1                                  4   
               1                                  8   
26             1                    1             9   use List::Util qw(max);
               1                                  3   
               1                                 12   
27             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
28                                                    
29             1                    1             9   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
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
43            34                   34           262      my ( $class, %args ) = @_;
44            34                                143      foreach my $arg ( qw(description) ) {
45    ***     34     50                         223         die "I need a $arg argument" unless $args{$arg};
46                                                       }
47            34                                334      my ($program_name) = $PROGRAM_NAME =~ m/([.A-Za-z-]+)$/;
48    ***     34            50                  148      $program_name ||= $PROGRAM_NAME;
49    ***     34            33                  303      my $home = $ENV{HOME} || $ENV{HOMEPATH} || $ENV{USERPROFILE} || '.';
      ***                   33                        
      ***                   50                        
50                                                    
51            34    100    100                 1260      my $self = {
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
76            34                                283      return bless $self, $class;
77                                                    }
78                                                    
79                                                    # Read and parse POD OPTIONS in file or current script if
80                                                    # no file is given. This sub must be called before get_opts();
81                                                    sub get_specs {
82             4                    4            19      my ( $self, $file ) = @_;
83             4                                 21      my @specs = $self->_pod_to_specs($file);
84             3                                 57      $self->_parse_specs(@specs);
85             3                                 20      return;
86                                                    }
87                                                    
88                                                    # Returns the program's defaults files.
89                                                    sub get_defaults_files {
90             7                    7            27      my ( $self ) = @_;
91             7                                 21      return @{$self->{default_files}};
               7                                 73   
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
106            9                    9            43      my ( $self, $file ) = @_;
107   ***      9            50                   43      $file ||= __FILE__;
108   ***      9     50                         421      open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
109                                                   
110            9                                113      my %types = (
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
122            9                                 30      my @specs = ();
123            9                                 23      my @rules = ();
124            9                                 26      my $para;
125                                                   
126                                                      # Read a paragraph at a time from the file.  Skip everything until options
127                                                      # are reached...
128            9                                 53      local $INPUT_RECORD_SEPARATOR = '';
129            9                                195      while ( $para = <$fh> ) {
130          471    100                        3048         next unless $para =~ m/^=head1 OPTIONS/;
131            8                                 33         last;
132                                                      }
133                                                   
134                                                      # ... then read any option rules...
135            9                                 51      while ( $para = <$fh> ) {
136           17    100                          81         last if $para =~ m/^=over/;
137            9                                 26         chomp $para;
138            9                                 55         $para =~ s/\s+/ /g;
139            9                                153         $para =~ s/$POD_link_re/$1/go;
140            9                                 22         MKDEBUG && _d('Option rule:', $para);
141            9                                 69         push @rules, $para;
142                                                      }
143                                                   
144            9    100                          31      die 'POD has no OPTIONS section' unless $para;
145                                                   
146                                                      # ... then start reading options.
147            8                                 25      do {
148          100    100                         635         if ( my ($option) = $para =~ m/^=item --(.*)/ ) {
149           92                                248            chomp $para;
150           92                                190            MKDEBUG && _d($para);
151           92                                208            my %attribs;
152                                                   
153           92                                314            $para = <$fh>; # read next paragraph, possibly attributes
154                                                   
155           92    100                         327            if ( $para =~ m/: / ) { # attributes
156           58                                265               $para =~ s/\s+\Z//g;
157           80                                400               %attribs = map {
158           58                                260                     my ( $attrib, $val) = split(/: /, $_);
159           80    100                         335                     die "Unrecognized attribute for --$option: $attrib"
160                                                                        unless $attributes{$attrib};
161           79                                376                     ($attrib, $val);
162                                                                  } split(/; /, $para);
163           57    100                         243               if ( $attribs{'short form'} ) {
164           13                                 61                  $attribs{'short form'} =~ s/-//;
165                                                               }
166           57                                223               $para = <$fh>; # read next paragraph, probably short help desc
167                                                            }
168                                                            else {
169           34                                 80               MKDEBUG && _d('Option has no attributes');
170                                                            }
171                                                   
172                                                            # Remove extra spaces and POD formatting (L<"">).
173           91                                489            $para =~ s/\s+\Z//g;
174           91                                434            $para =~ s/\s+/ /g;
175           91                                379            $para =~ s/$POD_link_re/$1/go;
176                                                   
177                                                            # Take the first period-terminated sentence as the option's short help
178                                                            # description.
179           91                                316            $para =~ s/\.(?:\n.*| [A-Z].*|\Z)//s;
180           91                                197            MKDEBUG && _d('Short help:', $para);
181                                                   
182           91    100                         348            die "No description after option spec $option" if $para =~ m/^=item/;
183                                                   
184                                                            # Change [no]foo to foo and set negatable attrib. See issue 140.
185           90    100                         395            if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
186            3                                  9               $option = $base_option;
187            3                                 11               $attribs{'negatable'} = 1;
188                                                            }
189                                                   
190           90    100                        1365            push @specs, {
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
201           98                                590         while ( $para = <$fh> ) {
202   ***    212     50                         672            last unless $para;
203                                                   
204                                                            # The 'allowed with' hack that was here was removed.
205                                                            # Groups need to be used instead. So, this new OptionParser
206                                                            # module will not work with mk-table-sync.
207                                                   
208          212    100                         765            if ( $para =~ m/^=head1/ ) {
209            6                                 19               $para = undef; # Can't 'last' out of a do {} block.
210            6                                 28               last;
211                                                            }
212          206    100                        1244            last if $para =~ m/^=item --/;
213                                                         }
214                                                      } while ( $para );
215                                                   
216            6    100                          23      die 'No valid specs in POD OPTIONS' unless @specs;
217                                                   
218            5                                 60      close $fh;
219            5                                 16      return @specs, @rules;
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
234           33                   33           198      my ( $self, @specs ) = @_;
235           33                                 97      my %disables; # special rule that requires deferred checking
236                                                   
237           33                                129      foreach my $opt ( @specs ) {
238          184    100                         686         if ( ref $opt ) { # It's an option spec, not a rule.
239                                                            MKDEBUG && _d('Parsing opt spec:',
240          164                                353               map { ($_, '=>', $opt->{$_}) } keys %$opt);
241                                                   
242          164                               1139            my ( $long, $short ) = $opt->{spec} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
243   ***    164     50                         682            if ( !$long ) {
244                                                               # This shouldn't happen.
245   ***      0                                  0               die "Cannot parse long option from spec $opt->{spec}";
246                                                            }
247          164                                574            $opt->{long} = $long;
248                                                   
249   ***    164     50                        1208            die "Duplicate long option --$long" if exists $self->{opts}->{$long};
250          164                                666            $self->{opts}->{$long} = $opt;
251                                                   
252          164    100                        2016            if ( length $long == 1 ) {
253            5                                 10               MKDEBUG && _d('Long opt', $long, 'looks like short opt');
254            5                                 20               $self->{short_opts}->{$long} = $long;
255                                                            }
256                                                   
257          164    100                         534            if ( $short ) {
258   ***     46     50                         195               die "Duplicate short option -$short"
259                                                                  if exists $self->{short_opts}->{$short};
260           46                                206               $self->{short_opts}->{$short} = $long;
261           46                                158               $opt->{short} = $short;
262                                                            }
263                                                            else {
264          118                                403               $opt->{short} = undef;
265                                                            }
266                                                   
267          164    100                         848            $opt->{is_negatable}  = $opt->{spec} =~ m/!/        ? 1 : 0;
268          164    100                        2071            $opt->{is_cumulative} = $opt->{spec} =~ m/\+/       ? 1 : 0;
269          164    100                         869            $opt->{is_required}   = $opt->{desc} =~ m/required/ ? 1 : 0;
270                                                   
271          164           100                  748            $opt->{group} ||= 'default';
272          164                                855            $self->{groups}->{ $opt->{group} }->{$long} = 1;
273                                                   
274          164                                510            $opt->{value} = undef;
275          164                                508            $opt->{got}   = 0;
276                                                   
277          164                                819            my ( $type ) = $opt->{spec} =~ m/=(.)/;
278          164                                563            $opt->{type} = $type;
279          164                                360            MKDEBUG && _d($long, 'type:', $type);
280                                                   
281   ***    164     50    100                 1296            if ( $type && $type eq 'd' && !$self->{dp} ) {
      ***                   66                        
282   ***      0                                  0               die "$opt->{long} is type DSN (d) but no dp argument "
283                                                                  . "was given when this OptionParser object was created";
284                                                            }
285                                                   
286                                                            # Option has a non-Getopt type: HhAadzm (see %types in
287                                                            # _pod_to_spec() above). For these, use Getopt type 's'.
288          164    100    100                 1134            $opt->{spec} =~ s/=./=s/ if ( $type && $type =~ m/[HhAadzm]/ );
289                                                   
290                                                            # Option has a default value if its desc says 'default' or 'default X'.
291                                                            # These defaults from the POD may be overridden by later calls
292                                                            # to set_defaults().
293          164    100                        1635            if ( (my ($def) = $opt->{desc} =~ m/default\b(?: ([^)]+))?/) ) {
294           23    100                         119               $self->{defaults}->{$long} = defined $def ? $def : 1;
295           23                                 62               MKDEBUG && _d($long, 'default:', $def);
296                                                            }
297                                                   
298                                                            # Handle special behavior for --config.
299          164    100                        1179            if ( $long eq 'config' ) {
300            6                                 40               $self->{defaults}->{$long} = join(',', $self->get_defaults_files());
301                                                            }
302                                                   
303                                                            # Option disable another option if its desc says 'disable'.
304          164    100                        1803            if ( (my ($dis) = $opt->{desc} =~ m/(disables .*)/) ) {
305                                                               # Defer checking till later because of possible forward references.
306            4                                 15               $disables{$long} = $dis;
307            4                                 11               MKDEBUG && _d('Deferring check of disables rule for', $opt, $dis);
308                                                            }
309                                                   
310                                                            # Save the option.
311          164                               1121            $self->{opts}->{$long} = $opt;
312                                                         }
313                                                         else { # It's an option rule, not a spec.
314           20                                 50            MKDEBUG && _d('Parsing rule:', $opt); 
315           20                                 51            push @{$self->{rules}}, $opt;
              20                                 93   
316           20                                 94            my @participants = $self->_get_participants($opt);
317           18                                 57            my $rule_ok = 0;
318                                                   
319           18    100                         140            if ( $opt =~ m/mutually exclusive|one and only one/ ) {
320           10                                 26               $rule_ok = 1;
321           10                                 27               push @{$self->{mutex}}, \@participants;
              10                                 44   
322           10                                 23               MKDEBUG && _d(@participants, 'are mutually exclusive');
323                                                            }
324           18    100                         114            if ( $opt =~ m/at least one|one and only one/ ) {
325            5                                 17               $rule_ok = 1;
326            5                                 13               push @{$self->{atleast1}}, \@participants;
               5                                 25   
327            5                                 15               MKDEBUG && _d(@participants, 'require at least one');
328                                                            }
329           18    100                          75            if ( $opt =~ m/default to/ ) {
330            4                                 17               $rule_ok = 1;
331                                                               # Example: "DSN values in L<"--dest"> default to values
332                                                               # from L<"--source">."
333            4                                 23               $self->{defaults_to}->{$participants[0]} = $participants[1];
334            4                                 11               MKDEBUG && _d($participants[0], 'defaults to', $participants[1]);
335                                                            }
336           18    100                          70            if ( $opt =~ m/restricted to option groups/ ) {
337            1                                  4               $rule_ok = 1;
338            1                                  7               my ($groups) = $opt =~ m/groups ([\w\s\,]+)/;
339            1                                  6               my @groups = split(',', $groups);
340            1                                  9               %{$self->{allowed_groups}->{$participants[0]}} = map {
               4                                 10   
341            1                                  4                  s/\s+//;
342            4                                 18                  $_ => 1;
343                                                               } @groups;
344                                                            }
345                                                   
346   ***     18     50                          87            die "Unrecognized option rule: $opt" unless $rule_ok;
347                                                         }
348                                                      }
349                                                   
350                                                      # Check forward references in 'disables' rules.
351           31                                186      foreach my $long ( keys %disables ) {
352                                                         # _get_participants() will check that each opt exists.
353            3                                 16         my @participants = $self->_get_participants($disables{$long});
354            2                                 10         $self->{disables}->{$long} = \@participants;
355            2                                  8         MKDEBUG && _d('Option', $long, 'disables', @participants);
356                                                      }
357                                                   
358           30                                130      return; 
359                                                   }
360                                                   
361                                                   # Returns an array of long option names in str. This is used to
362                                                   # find the "participants" of option rules (i.e. the options to
363                                                   # which a rule applies).
364                                                   sub _get_participants {
365           25                   25           131      my ( $self, $str ) = @_;
366           25                                 74      my @participants;
367           25                                204      foreach my $long ( $str =~ m/--(?:\[no\])?([\w-]+)/g ) {
368           52    100                         238         die "Option --$long does not exist while processing rule $str"
369                                                            unless exists $self->{opts}->{$long};
370           49                                183         push @participants, $long;
371                                                      }
372           22                                 60      MKDEBUG && _d('Participants for', $str, ':', @participants);
373           22                                146      return @participants;
374                                                   }
375                                                   
376                                                   # Returns a copy of the internal opts hash.
377                                                   sub opts {
378            4                    4            18      my ( $self ) = @_;
379            4                                 11      my %opts = %{$self->{opts}};
               4                                 40   
380            4                                 71      return %opts;
381                                                   }
382                                                   
383                                                   # Returns a copy of the internal short_opts hash.
384                                                   sub short_opts {
385            1                    1             5      my ( $self ) = @_;
386            1                                  4      my %short_opts = %{$self->{short_opts}};
               1                                 10   
387            1                                 10      return %short_opts;
388                                                   }
389                                                   
390                                                   sub set_defaults {
391            5                    5            30      my ( $self, %defaults ) = @_;
392            5                                 26      $self->{defaults} = {};
393            5                                 29      foreach my $long ( keys %defaults ) {
394            3    100                          15         die "Cannot set default for nonexistent option $long"
395                                                            unless exists $self->{opts}->{$long};
396            2                                 10         $self->{defaults}->{$long} = $defaults{$long};
397            2                                  7         MKDEBUG && _d('Default val for', $long, ':', $defaults{$long});
398                                                      }
399            4                                 15      return;
400                                                   }
401                                                   
402                                                   sub get_defaults {
403            3                    3            11      my ( $self ) = @_;
404            3                                 19      return $self->{defaults};
405                                                   }
406                                                   
407                                                   sub get_groups {
408            1                    1             5      my ( $self ) = @_;
409            1                                 17      return $self->{groups};
410                                                   }
411                                                   
412                                                   # Getopt::Long calls this sub for each opt it finds on the
413                                                   # cmd line. We have to do this in order to know which opts
414                                                   # were "got" on the cmd line.
415                                                   sub _set_option {
416           72                   72           302      my ( $self, $opt, $val ) = @_;
417   ***     72      0                         176      my $long = exists $self->{opts}->{$opt}       ? $opt
      ***            50                               
418                                                               : exists $self->{short_opts}->{$opt} ? $self->{short_opts}->{$opt}
419                                                               : die "Getopt::Long gave a nonexistent option: $opt";
420                                                   
421                                                      # Reassign $opt.
422           72                                152      $opt = $self->{opts}->{$long};
423           72    100                         378      if ( $opt->{is_cumulative} ) {
424            8                                 27         $opt->{value}++;
425                                                      }
426                                                      else {
427           64                                278         $opt->{value} = $val;
428                                                      }
429           72                                226      $opt->{got} = 1;
430           72                                257      MKDEBUG && _d('Got option', $long, '=', $val);
431                                                   }
432                                                   
433                                                   # Get options on the command line (ARGV) according to the option specs
434                                                   # and enforce option rules. Option values are saved internally in
435                                                   # $self->{opts} and accessed later by get(), got() and set().
436                                                   sub get_opts {
437           54                   54           230      my ( $self ) = @_; 
438                                                   
439                                                      # Reset opts. 
440           54                                165      foreach my $long ( keys %{$self->{opts}} ) {
              54                                672   
441          308                               1794         $self->{opts}->{$long}->{got} = 0;
442          308    100                        4558         $self->{opts}->{$long}->{value}
                    100                               
443                                                            = exists $self->{defaults}->{$long}       ? $self->{defaults}->{$long}
444                                                            : $self->{opts}->{$long}->{is_cumulative} ? 0
445                                                            : undef;
446                                                      }
447           54                                245      $self->{got_opts} = 0;
448                                                   
449                                                      # Reset errors.
450           54                                219      $self->{errors} = [];
451                                                   
452                                                      # --config is special-case; parse them manually and remove them from @ARGV
453           54    100    100                  489      if ( @ARGV && $ARGV[0] eq "--config" ) {
454            4                                 13         shift @ARGV;
455            4                                 21         $self->_set_option('config', shift @ARGV);
456                                                      }
457           54    100                         284      if ( $self->has('config') ) {
458            8                                 24         my @extra_args;
459            8                                 45         foreach my $filename ( split(',', $self->get('config')) ) {
460                                                            # Try to open the file.  If it was set explicitly, it's an error if it
461                                                            # can't be opened, but the built-in defaults are to be ignored if they
462                                                            # can't be opened.
463           21                                 56            eval {
464           21                                 99               push @ARGV, $self->_read_config_file($filename);
465                                                            };
466           21    100                         128            if ( $EVAL_ERROR ) {
467           17    100                          65               if ( $self->got('config') ) {
468            1                                  3                  die $EVAL_ERROR;
469                                                               }
470                                                               elsif ( MKDEBUG ) {
471                                                                  _d($EVAL_ERROR);
472                                                               }
473                                                            }
474                                                         }
475            7                                 35         unshift @ARGV, @extra_args;
476                                                      }
477                                                   
478           53                                321      Getopt::Long::Configure('no_ignore_case', 'bundling');
479                                                      GetOptions(
480                                                         # Make Getopt::Long specs for each option with custom handler subs.
481          299                   68          2136         map    { $_->{spec} => sub { $self->_set_option(@_); } }
              68                                337   
             306                               1213   
482           53                                293         grep   { $_->{long} ne 'config' } # --config is handled specially above.
483           53    100                         183         values %{$self->{opts}}
484                                                      ) or $self->save_error('Error parsing options');
485                                                   
486   ***     53     50     66                  832      if ( exists $self->{opts}->{version} && $self->{opts}->{version}->{got} ) {
487   ***      0      0                           0         printf("%s  Ver %s Distrib %s Changeset %s\n",
488                                                            $self->{program_name}, $main::VERSION, $main::DISTRIB, $main::SVN_REV)
489                                                               or die "Cannot print: $OS_ERROR";
490   ***      0                                  0         exit 0;
491                                                      }
492                                                   
493           53    100    100                  299      if ( @ARGV && $self->{strict} ) {
494            1                                  7         $self->save_error("Unrecognized command-line options @ARGV");
495                                                      }
496                                                   
497                                                      # Check mutex options.
498           53                                146      foreach my $mutex ( @{$self->{mutex}} ) {
              53                                300   
499           18                                 62         my @set = grep { $self->{opts}->{$_}->{got} } @$mutex;
              39                                187   
500           18    100                          84         if ( @set > 1 ) {
501            5                                 43            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               3                                 10   
502            3                                 23                         @{$mutex}[ 0 .. scalar(@$mutex) - 2] )
503                                                                    . ' and --'.$self->{opts}->{$mutex->[-1]}->{long}
504                                                                    . ' are mutually exclusive.';
505            3                                 15            $self->save_error($err);
506                                                         }
507                                                      }
508                                                   
509           53                                154      foreach my $required ( @{$self->{atleast1}} ) {
              53                                254   
510            6                                 24         my @set = grep { $self->{opts}->{$_}->{got} } @$required;
              18                                 84   
511            6    100                          31         if ( @set == 0 ) {
512            6                                 46            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               3                                 11   
513            3                                 22                         @{$required}[ 0 .. scalar(@$required) - 2] )
514                                                                    .' or --'.$self->{opts}->{$required->[-1]}->{long};
515            3                                 17            $self->save_error("Specify at least one of $err");
516                                                         }
517                                                      }
518                                                   
519           53                                161      foreach my $long ( keys %{$self->{opts}} ) {
              53                                321   
520          306                               1096         my $opt = $self->{opts}->{$long};
521          306    100                        1508         if ( $opt->{got} ) {
                    100                               
522                                                            # Rule: opt disables other opts.
523           67    100                         303            if ( exists $self->{disables}->{$long} ) {
524            1                                  4               my @disable_opts = @{$self->{disables}->{$long}};
               1                                  5   
525            1                                  4               map { $self->{opts}->{$_}->{value} = undef; } @disable_opts;
               1                                  5   
526            1                                  3               MKDEBUG && _d('Unset options', @disable_opts,
527                                                                  'because', $long,'disables them');
528                                                            }
529                                                   
530                                                            # Group restrictions.
531           67    100                         324            if ( exists $self->{allowed_groups}->{$long} ) {
532                                                               # This option is only allowed with other options from
533                                                               # certain groups.  Check that no options from restricted
534                                                               # groups were gotten.
535                                                   
536           10                                 46               my @restricted_groups = grep {
537            2                                 12                  !exists $self->{allowed_groups}->{$long}->{$_}
538            2                                  8               } keys %{$self->{groups}};
539                                                   
540            2                                  7               my @restricted_opts;
541            2                                  8               foreach my $restricted_group ( @restricted_groups ) {
542            2                                 10                  RESTRICTED_OPT:
543            2                                  5                  foreach my $restricted_opt (
544                                                                     keys %{$self->{groups}->{$restricted_group}} )
545                                                                  {
546            4    100                          22                     next RESTRICTED_OPT if $restricted_opt eq $long;
547            2    100                          13                     push @restricted_opts, $restricted_opt
548                                                                        if $self->{opts}->{$restricted_opt}->{got};
549                                                                  }
550                                                               }
551                                                   
552            2    100                          10               if ( @restricted_opts ) {
553            1                                  3                  my $err;
554   ***      1     50                           5                  if ( @restricted_opts == 1 ) {
555            1                                  4                     $err = "--$restricted_opts[0]";
556                                                                  }
557                                                                  else {
558   ***      0                                  0                     $err = join(', ',
559   ***      0                                  0                               map { "--$self->{opts}->{$_}->{long}" }
560   ***      0                                  0                               grep { $_ } 
561                                                                               @restricted_opts[0..scalar(@restricted_opts) - 2]
562                                                                            )
563                                                                          . ' or --'.$self->{opts}->{$restricted_opts[-1]}->{long};
564                                                                  }
565            1                                  8                  $self->save_error("--$long is not allowed with $err");
566                                                               }
567                                                            }
568                                                   
569                                                         }
570                                                         elsif ( $opt->{is_required} ) { 
571            3                                 19            $self->save_error("Required option --$long must be specified");
572                                                         }
573                                                   
574          306                               1109         $self->_validate_type($opt);
575                                                      }
576                                                   
577           53                                212      $self->{got_opts} = 1;
578           53                                180      return;
579                                                   }
580                                                   
581                                                   sub _validate_type {
582          306                  306          1063      my ( $self, $opt ) = @_;
583   ***    306    100     66                 2601      return unless $opt && $opt->{type};
584          163                                515      my $val = $opt->{value};
585                                                   
586          163    100    100                 3754      if ( $val && $opt->{type} eq 'm' ) {  # type time
                    100    100                        
                    100    100                        
                    100    100                        
                    100    100                        
                           100                        
                           100                        
587            8                                 22         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a time value');
588            8                                 61         my ( $num, $suffix ) = $val =~ m/(\d+)([a-z])?$/;
589                                                         # The suffix defaults to 's' unless otherwise specified.
590            8    100                          35         if ( !$suffix ) {
591            5                                 26            my ( $s ) = $opt->{desc} =~ m/\(suffix (.)\)/;
592            5           100                   24            $suffix = $s || 's';
593            5                                 12            MKDEBUG && _d('No suffix given; using', $suffix, 'for',
594                                                               $opt->{long}, '(value:', $val, ')');
595                                                         }
596            8    100                          37         if ( $suffix =~ m/[smhd]/ ) {
597            7    100                          47            $val = $suffix eq 's' ? $num            # Seconds
                    100                               
                    100                               
598                                                                 : $suffix eq 'm' ? $num * 60       # Minutes
599                                                                 : $suffix eq 'h' ? $num * 3600     # Hours
600                                                                 :                  $num * 86400;   # Days
601            7                                 21            $opt->{value} = $val;
602            7                                 19            MKDEBUG && _d('Setting option', $opt->{long}, 'to', $val);
603                                                         }
604                                                         else {
605            1                                 14            $self->save_error("Invalid time suffix for --$opt->{long}");
606                                                         }
607                                                      }
608                                                      elsif ( $val && $opt->{type} eq 'd' ) {  # type DSN
609           10                                 20         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a DSN');
610                                                         # DSN vals for this opt may come from 3 places, in order of precedence:
611                                                         # the opt itself, the defaults to/copies from opt (prev), or
612                                                         # --host, --port, etc. (defaults).
613           10                                 36         my $prev = {};
614           10                                 47         my $from_key = $self->{defaults_to}->{ $opt->{long} };
615           10    100                          41         if ( $from_key ) {
616            4                                 12            MKDEBUG && _d($opt->{long}, 'DSN copies from', $from_key, 'DSN');
617            4                                 20            $prev = $self->{opts}->{$from_key}->{value};
618                                                         }
619           10                                 66         my $defaults = $self->{dp}->parse_options($self);
620           10                                 46         $opt->{value} = $self->{dp}->parse($val, $prev, $defaults);
621                                                      }
622                                                      elsif ( $val && $opt->{type} eq 'z' ) {  # type size
623            6                                 15         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a size value');
624            6                                 38         my %factor_for = (k => 1_024, M => 1_048_576, G => 1_073_741_824);
625            6                                 51         my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
626            6    100                          27         if ( defined $num ) {
627            5    100                          32            if ( $factor ) {
628            4                                 20               $num *= $factor_for{$factor};
629            4                                 10               MKDEBUG && _d('Setting option', $opt->{y},
630                                                                  'to num', $num, '* factor', $factor);
631                                                            }
632            5           100                   48            $opt->{value} = ($pre || '') . $num;
633                                                         }
634                                                         else {
635            1                                  7            $self->save_error("Invalid size for --$opt->{long}");
636                                                         }
637                                                      }
638                                                      elsif ( $opt->{type} eq 'H' || (defined $val && $opt->{type} eq 'h') ) {
639            6           100                   50         $opt->{value} = { map { $_ => 1 } split(',', ($val || '')) };
               4                                 19   
640                                                      }
641                                                      elsif ( $opt->{type} eq 'A' || (defined $val && $opt->{type} eq 'a') ) {
642           17           100                  190         $opt->{value} = [ split(/(?<!\\),/, ($val || '')) ];
643                                                      }
644                                                      else {
645          116                                271         MKDEBUG && _d('Nothing to validate for option',
646                                                            $opt->{long}, 'type', $opt->{type}, 'value', $val);
647                                                      }
648                                                   
649          163                                574      return;
650                                                   }
651                                                   
652                                                   # Get an option's value. The option can be either a
653                                                   # short or long name (e.g. -A or --charset).
654                                                   sub get {
655           90                   90           423      my ( $self, $opt ) = @_;
656           90    100                         517      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
657           90    100    100                  849      die "Option $opt does not exist"
658                                                         unless $long && exists $self->{opts}->{$long};
659           87                                811      return $self->{opts}->{$long}->{value};
660                                                   }
661                                                   
662                                                   # Returns true if the option was given explicitly on the
663                                                   # command line; returns false if not. The option can be
664                                                   # either short or long name (e.g. -A or --charset).
665                                                   sub got {
666           39                   39           192      my ( $self, $opt ) = @_;
667           39    100                         188      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
668           39    100    100                  358      die "Option $opt does not exist"
669                                                         unless $long && exists $self->{opts}->{$long};
670           37                                274      return $self->{opts}->{$long}->{got};
671                                                   }
672                                                   
673                                                   # Returns true if the option exists.
674                                                   sub has {
675          141                  141           574      my ( $self, $opt ) = @_;
676          141    100                         729      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
677          141    100                         983      return defined $long ? exists $self->{opts}->{$long} : 0;
678                                                   }
679                                                   
680                                                   # Set an option's value. The option can be either a
681                                                   # short or long name (e.g. -A or --charset). The value
682                                                   # can be any scalar, ref, or undef. No type checking
683                                                   # is done so becareful to not set, for example, an integer
684                                                   # option with a DSN.
685                                                   sub set {
686            5                    5           255      my ( $self, $opt, $val ) = @_;
687            5    100                          30      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
688            5    100    100                   38      die "Option $opt does not exist"
689                                                         unless $long && exists $self->{opts}->{$long};
690            3                                 14      $self->{opts}->{$long}->{value} = $val;
691            3                                 10      return;
692                                                   }
693                                                   
694                                                   # Save an error message to be reported later by calling usage_or_errors()
695                                                   # (or errors()--mostly for testing).
696                                                   sub save_error {
697           16                   16            82      my ( $self, $error ) = @_;
698           16                                 44      push @{$self->{errors}}, $error;
              16                                 90   
699                                                   }
700                                                   
701                                                   # Return arrayref of errors (mostly for testing).
702                                                   sub errors {
703           13                   13            59      my ( $self ) = @_;
704           13                                110      return $self->{errors};
705                                                   }
706                                                   
707                                                   sub prompt {
708           11                   11            42      my ( $self ) = @_;
709           11                                 76      return "Usage: $PROGRAM_NAME $self->{prompt}\n";
710                                                   }
711                                                   
712                                                   sub descr {
713           11                   11            42      my ( $self ) = @_;
714   ***     11            50                  123      my $descr  = $self->{program_name} . ' ' . ($self->{description} || '')
715                                                                 . "  For more details, please use the --help option, "
716                                                                 . "or try 'perldoc $PROGRAM_NAME' "
717                                                                 . "for complete documentation.";
718           11                                118      $descr = join("\n", $descr =~ m/(.{0,80})(?:\s+|$)/g);
719           11                                 99      $descr =~ s/ +$//mg;
720           11                                 84      return $descr;
721                                                   }
722                                                   
723                                                   sub usage_or_errors {
724   ***      0                    0             0      my ( $self ) = @_;
725   ***      0      0                           0      if ( $self->{opts}->{help}->{got} ) {
      ***      0      0                           0   
726   ***      0      0                           0         print $self->print_usage() or die "Cannot print usage: $OS_ERROR";
727   ***      0                                  0         exit 0;
728                                                      }
729                                                      elsif ( scalar @{$self->{errors}} ) {
730   ***      0      0                           0         print $self->print_errors() or die "Cannot print errors: $OS_ERROR";
731   ***      0                                  0         exit 0;
732                                                      }
733   ***      0                                  0      return;
734                                                   }
735                                                   
736                                                   # Explains what errors were found while processing command-line arguments and
737                                                   # gives a brief overview so you can get more information.
738                                                   sub print_errors {
739            1                    1             4      my ( $self ) = @_;
740            1                                  4      my $usage = $self->prompt() . "\n";
741   ***      1     50                           4      if ( (my @errors = @{$self->{errors}}) ) {
               1                                  8   
742            1                                  6         $usage .= join("\n  * ", 'Errors in command-line arguments:', @errors)
743                                                                 . "\n";
744                                                      }
745            1                                  6      return $usage . "\n" . $self->descr();
746                                                   }
747                                                   
748                                                   # Prints out command-line help.  The format is like this:
749                                                   # --foo  -F   Description of --foo
750                                                   # --bars -B   Description of --bar
751                                                   # --longopt   Description of --longopt
752                                                   # Note that the short options are aligned along the right edge of their longest
753                                                   # long option, but long options that don't have a short option are allowed to
754                                                   # protrude past that.
755                                                   sub print_usage {
756           10                   10            42      my ( $self ) = @_;
757   ***     10     50                          65      die "Run get_opts() before print_usage()" unless $self->{got_opts};
758           10                                 27      my @opts = values %{$self->{opts}};
              10                                 62   
759                                                   
760                                                      # Find how wide the widest long option is.
761           32    100                         227      my $maxl = max(
762           10                                 37         map { length($_->{long}) + ($_->{is_negatable} ? 4 : 0) }
763                                                         @opts);
764                                                   
765                                                      # Find how wide the widest option with a short option is.
766   ***     12     50                          72      my $maxs = max(0,
767           10                                 54         map { length($_) + ($self->{opts}->{$_}->{is_negatable} ? 4 : 0) }
768           10                                 38         values %{$self->{short_opts}});
769                                                   
770                                                      # Find how wide the 'left column' (long + short opts) is, and therefore how
771                                                      # much space to give options and how much to give descriptions.
772           10                                 49      my $lcol = max($maxl, ($maxs + 3));
773           10                                 36      my $rcol = 80 - $lcol - 6;
774           10                                 44      my $rpad = ' ' x ( 80 - $rcol );
775                                                   
776                                                      # Adjust the width of the options that have long and short both.
777           10                                 46      $maxs = max($lcol - 3, $maxs);
778                                                   
779                                                      # Format and return the options.
780           10                                 50      my $usage = $self->descr() . "\n" . $self->prompt();
781                                                   
782                                                      # Sort groups alphabetically but make 'default' first.
783           10                                 37      my @groups = reverse sort grep { $_ ne 'default'; } keys %{$self->{groups}};
              14                                 84   
              10                                 52   
784           10                                 39      push @groups, 'default';
785                                                   
786           10                                 39      foreach my $group ( reverse @groups ) {
787           14    100                          66         $usage .= "\n".($group eq 'default' ? 'Options' : $group).":\n\n";
788           14                                 49         foreach my $opt (
              22                                 91   
789           64                                222            sort { $a->{long} cmp $b->{long} }
790                                                            grep { $_->{group} eq $group }
791                                                            @opts )
792                                                         {
793           32    100                         192            my $long  = $opt->{is_negatable} ? "[no]$opt->{long}" : $opt->{long};
794           32                                100            my $short = $opt->{short};
795           32                                101            my $desc  = $opt->{desc};
796                                                            # Expand suffix help for time options.
797           32    100    100                  252            if ( $opt->{type} && $opt->{type} eq 'm' ) {
798            2                                  9               my ($s) = $desc =~ m/\(suffix (.)\)/;
799            2           100                    9               $s    ||= 's';
800            2                                  8               $desc =~ s/\s+\(suffix .\)//;
801            2                                  9               $desc .= ".  Optional suffix s=seconds, m=minutes, h=hours, "
802                                                                      . "d=days; if no suffix, $s is used.";
803                                                            }
804                                                            # Wrap long descriptions
805           32                                459            $desc = join("\n$rpad", grep { $_ } $desc =~ m/(.{0,$rcol})(?:\s+|$)/g);
              69                                234   
806           32                                156            $desc =~ s/ +$//mg;
807           32    100                         103            if ( $short ) {
808           12                                 94               $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
809                                                            }
810                                                            else {
811           20                                149               $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
812                                                            }
813                                                         }
814                                                      }
815                                                   
816           10    100                          30      if ( (my @rules = @{$self->{rules}}) ) {
              10                                 66   
817            4                                 13         $usage .= "\nRules:\n\n";
818            4                                 18         $usage .= join("\n", map { "  $_" } @rules) . "\n";
               4                                 29   
819                                                      }
820           10    100                          50      if ( $self->{dp} ) {
821            2                                 15         $usage .= "\n" . $self->{dp}->usage();
822                                                      }
823           10                                 43      $usage .= "\nOptions and values after processing arguments:\n\n";
824           10                                 20      foreach my $opt ( sort { $a->{long} cmp $b->{long} } @opts ) {
              34                                124   
825           32                                120         my $val   = $opt->{value};
826           32           100                  197         my $type  = $opt->{type} || '';
827           32                                188         my $bool  = $opt->{spec} =~ m/^[\w-]+(?:\|[\w-])?!?$/;
828           32    100                         228         $val      = $bool                     ? ( $val ? 'TRUE' : 'FALSE' )
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
829                                                                   : !defined $val             ? '(No value)'
830                                                                   : $type eq 'd'              ? $self->{dp}->as_string($val)
831                                                                   : $type =~ m/H|h/           ? join(',', sort keys %$val)
832                                                                   : $type =~ m/A|a/           ? join(',', @$val)
833                                                                   :                             $val;
834           32                                201         $usage .= sprintf("  --%-${lcol}s  %s\n", $opt->{long}, $val);
835                                                      }
836           10                                119      return $usage;
837                                                   }
838                                                   
839                                                   # Tries to prompt and read the answer without echoing the answer to the
840                                                   # terminal.  This isn't really related to this package, but it's too handy not
841                                                   # to put here.  OK, it's related, it gets config information from the user.
842                                                   sub prompt_noecho {
843   ***      0      0             0             0      shift @_ if ref $_[0] eq __PACKAGE__;
844   ***      0                                  0      my ( $prompt ) = @_;
845   ***      0                                  0      local $OUTPUT_AUTOFLUSH = 1;
846   ***      0      0                           0      print $prompt
847                                                         or die "Cannot print: $OS_ERROR";
848   ***      0                                  0      my $response;
849   ***      0                                  0      eval {
850   ***      0                                  0         require Term::ReadKey;
851   ***      0                                  0         Term::ReadKey::ReadMode('noecho');
852   ***      0                                  0         chomp($response = <STDIN>);
853   ***      0                                  0         Term::ReadKey::ReadMode('normal');
854   ***      0      0                           0         print "\n"
855                                                            or die "Cannot print: $OS_ERROR";
856                                                      };
857   ***      0      0                           0      if ( $EVAL_ERROR ) {
858   ***      0                                  0         die "Cannot read response; is Term::ReadKey installed? $EVAL_ERROR";
859                                                      }
860   ***      0                                  0      return $response;
861                                                   }
862                                                   
863                                                   # This is debug code I want to run for all tools, and this is a module I
864                                                   # certainly include in all tools, but otherwise there's no real reason to put
865                                                   # it here.
866                                                   if ( MKDEBUG ) {
867                                                      print '# ', $^X, ' ', $], "\n";
868                                                      my $uname = `uname -a`;
869                                                      if ( $uname ) {
870                                                         $uname =~ s/\s+/ /g;
871                                                         print "# $uname\n";
872                                                      }
873                                                      printf("# %s  Ver %s Distrib %s Changeset %s line %d\n",
874                                                         $PROGRAM_NAME, ($main::VERSION || ''), ($main::DISTRIB || ''),
875                                                         ($main::SVN_REV || ''), __LINE__);
876                                                      print('# Arguments: ',
877                                                         join(' ', map { my $a = "_[$_]_"; $a =~ s/\n/\n# /g; $a; } @ARGV), "\n");
878                                                   }
879                                                   
880                                                   # Reads a configuration file and returns it as a list.  Inspired by
881                                                   # Config::Tiny.
882                                                   sub _read_config_file {
883           22                   22            95      my ( $self, $filename ) = @_;
884           22    100                         227      open my $fh, "<", $filename or die "Cannot open $filename: $OS_ERROR\n";
885            5                                 14      my @args;
886            5                                 17      my $prefix = '--';
887            5                                 17      my $parse  = 1;
888                                                   
889                                                      LINE:
890            5                                 73      while ( my $line = <$fh> ) {
891           23                                 63         chomp $line;
892                                                         # Skip comments and empty lines
893           23    100                         128         next LINE if $line =~ m/^\s*(?:\#|\;|$)/;
894                                                         # Remove inline comments
895           19                                 64         $line =~ s/\s+#.*$//g;
896                                                         # Remove whitespace
897           19                                100         $line =~ s/^\s+|\s+$//g;
898                                                         # Watch for the beginning of the literal values (not to be interpreted as
899                                                         # options)
900           19    100                          69         if ( $line eq '--' ) {
901            4                                 11            $prefix = '';
902            4                                  9            $parse  = 0;
903            4                                 20            next LINE;
904                                                         }
905   ***     15    100     66                  161         if ( $parse
      ***            50                               
906                                                            && (my($opt, $arg) = $line =~ m/^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/)
907                                                         ) {
908            8                                 30            push @args, grep { defined $_ } ("$prefix$opt", $arg);
              16                                 84   
909                                                         }
910                                                         elsif ( $line =~ m/./ ) {
911            7                                 59            push @args, $line;
912                                                         }
913                                                         else {
914   ***      0                                  0            die "Syntax error in file $filename at line $INPUT_LINE_NUMBER";
915                                                         }
916                                                      }
917            5                                 40      close $fh;
918            5                                 13      return @args;
919                                                   }
920                                                   
921                                                   # Reads the next paragraph from the POD after the magical regular expression is
922                                                   # found in the text.
923                                                   sub read_para_after {
924            2                    2            10      my ( $self, $file, $regex ) = @_;
925   ***      2     50                          79      open my $fh, "<", $file or die "Can't open $file: $OS_ERROR";
926            2                                 13      local $INPUT_RECORD_SEPARATOR = '';
927            2                                  6      my $para;
928            2                                 31      while ( $para = <$fh> ) {
929            6    100                          38         next unless $para =~ m/^=pod$/m;
930            2                                  6         last;
931                                                      }
932            2                                 11      while ( $para = <$fh> ) {
933            7    100                          54         next unless $para =~ m/$regex/;
934            2                                  6         last;
935                                                      }
936            2                                  7      $para = <$fh>;
937            2                                  6      chomp($para);
938   ***      2     50                          20      close $fh or die "Can't close $file: $OS_ERROR";
939            2                                  6      return $para;
940                                                   }
941                                                   
942                                                   # Returns a lightweight clone of ourself.  Currently, only the basic
943                                                   # opts are copied.  This is used for stuff like "final opts" in
944                                                   # mk-table-checksum.
945                                                   sub clone {
946            1                    1             5      my ( $self ) = @_;
947                                                   
948                                                      # Deep-copy contents of hashrefs; do not just copy the refs. 
949            3                                 10      my %clone = map {
950            1                                  5         my $hashref  = $self->{$_};
951            3                                  7         my $val_copy = {};
952            3                                 13         foreach my $key ( keys %$hashref ) {
953            5                                 16            my $ref = ref $hashref->{$key};
954            3                                 34            $val_copy->{$key} = !$ref           ? $hashref->{$key}
955   ***      0                                  0                              : $ref eq 'HASH'  ? { %{$hashref->{$key}} }
956   ***      5      0                          25                              : $ref eq 'ARRAY' ? [ @{$hashref->{$key}} ]
      ***            50                               
                    100                               
957                                                                              : $hashref->{$key};
958                                                         }
959            3                                 16         $_ => $val_copy;
960                                                      } qw(opts short_opts defaults);
961                                                   
962                                                      # Re-assign scalar values.
963            1                                  5      foreach my $scalar ( qw(got_opts) ) {
964            1                                  5         $clone{$scalar} = $self->{$scalar};
965                                                      }
966                                                   
967            1                                  7      return bless \%clone;     
968                                                   }
969                                                   
970                                                   sub _d {
971            1                    1             9      my ($package, undef, $line) = caller 0;
972   ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  7   
               2                                 10   
973            1                                  5           map { defined $_ ? $_ : 'undef' }
974                                                           @_;
975            1                                  3      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
976                                                   }
977                                                   
978                                                   1;
979                                                   
980                                                   # ###########################################################################
981                                                   # End OptionParser package
982                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***     50      0     34   unless $args{$arg}
51           100      1     33   exists $args{'strict'} ? :
108   ***     50      0      9   unless open my $fh, '<', $file
130          100    463      8   unless $para =~ /^=head1 OPTIONS/
136          100      8      9   if $para =~ /^=over/
144          100      1      8   unless $para
148          100     92      8   if (my($option) = $para =~ /^=item --(.*)/)
155          100     58     34   if ($para =~ /: /) { }
159          100      1     79   unless $attributes{$attrib}
163          100     13     44   if ($attribs{'short form'})
182          100      1     90   if $para =~ /^=item/
185          100      3     87   if (my($base_option) = $option =~ /^\[no\](.*)/)
190          100     13     77   $attribs{'short form'} ? :
             100      5     85   $attribs{'negatable'} ? :
             100      2     88   $attribs{'cumulative'} ? :
             100     47     43   $attribs{'type'} ? :
             100      9     81   $attribs{'default'} ? :
             100      6     84   $attribs{'group'} ? :
202   ***     50      0    212   unless $para
208          100      6    206   if ($para =~ /^=head1/)
212          100     92    114   if $para =~ /^=item --/
216          100      1      5   unless @specs
238          100    164     20   if (ref $opt) { }
243   ***     50      0    164   if (not $long)
249   ***     50      0    164   if exists $$self{'opts'}{$long}
252          100      5    159   if (length $long == 1)
257          100     46    118   if ($short) { }
258   ***     50      0     46   if exists $$self{'short_opts'}{$short}
267          100      8    156   $$opt{'spec'} =~ /!/ ? :
268          100      4    160   $$opt{'spec'} =~ /\+/ ? :
269          100      5    159   $$opt{'desc'} =~ /required/ ? :
281   ***     50      0    164   if ($type and $type eq 'd' and not $$self{'dp'})
288          100     50    114   if $type and $type =~ /[HhAadzm]/
293          100     23    141   if (my($def) = $$opt{'desc'} =~ /default\b(?: ([^)]+))?/)
294          100     22      1   defined $def ? :
299          100      6    158   if ($long eq 'config')
304          100      4    160   if (my($dis) = $$opt{'desc'} =~ /(disables .*)/)
319          100     10      8   if ($opt =~ /mutually exclusive|one and only one/)
324          100      5     13   if ($opt =~ /at least one|one and only one/)
329          100      4     14   if ($opt =~ /default to/)
336          100      1     17   if ($opt =~ /restricted to option groups/)
346   ***     50      0     18   unless $rule_ok
368          100      3     49   unless exists $$self{'opts'}{$long}
394          100      1      2   unless exists $$self{'opts'}{$long}
417   ***      0      0      0   exists $$self{'short_opts'}{$opt} ? :
      ***     50     72      0   exists $$self{'opts'}{$opt} ? :
423          100      8     64   if ($$opt{'is_cumulative'}) { }
442          100     15    253   $$self{'opts'}{$long}{'is_cumulative'} ? :
             100     40    268   exists $$self{'defaults'}{$long} ? :
453          100      4     50   if (@ARGV and $ARGV[0] eq '--config')
457          100      8     46   if ($self->has('config'))
466          100     17      4   if ($EVAL_ERROR)
467          100      1     16   $self->got('config') ? :
483          100      3     50   unless GetOptions map({$$_{'spec'}, sub {
	$self->_set_option(@_);
}
;} grep({$$_{'long'} ne 'config';} values %{$$self{'opts'};}))
486   ***     50      0     53   if (exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'})
487   ***      0      0      0   unless printf "%s  Ver %s Distrib %s Changeset %s\n", $$self{'program_name'}, $main::VERSION, $main::DISTRIB, $main::SVN_REV
493          100      1     52   if (@ARGV and $$self{'strict'})
500          100      3     15   if (@set > 1)
511          100      3      3   if (@set == 0)
521          100     67    239   if ($$opt{'got'}) { }
             100      3    236   elsif ($$opt{'is_required'}) { }
523          100      1     66   if (exists $$self{'disables'}{$long})
531          100      2     65   if (exists $$self{'allowed_groups'}{$long})
546          100      2      2   if $restricted_opt eq $long
547          100      1      1   if $$self{'opts'}{$restricted_opt}{'got'}
552          100      1      1   if (@restricted_opts)
554   ***     50      1      0   if (@restricted_opts == 1) { }
583          100    143    163   unless $opt and $$opt{'type'}
586          100      8    155   if ($val and $$opt{'type'} eq 'm') { }
             100     10    145   elsif ($val and $$opt{'type'} eq 'd') { }
             100      6    139   elsif ($val and $$opt{'type'} eq 'z') { }
             100      6    133   elsif ($$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h') { }
             100     17    116   elsif ($$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a') { }
590          100      5      3   if (not $suffix)
596          100      7      1   if ($suffix =~ /[smhd]/) { }
597          100      2      1   $suffix eq 'h' ? :
             100      2      3   $suffix eq 'm' ? :
             100      2      5   $suffix eq 's' ? :
615          100      4      6   if ($from_key)
626          100      5      1   if (defined $num) { }
627          100      4      1   if ($factor)
656          100     42     48   length $opt == 1 ? :
657          100      3     87   unless $long and exists $$self{'opts'}{$long}
667          100      4     35   length $opt == 1 ? :
668          100      2     37   unless $long and exists $$self{'opts'}{$long}
676          100     82     59   length $opt == 1 ? :
677          100     78     63   defined $long ? :
687          100      2      3   length $opt == 1 ? :
688          100      2      3   unless $long and exists $$self{'opts'}{$long}
725   ***      0      0      0   if ($$self{'opts'}{'help'}{'got'}) { }
      ***      0      0      0   elsif (scalar @{$$self{'errors'};}) { }
726   ***      0      0      0   unless print $self->print_usage
730   ***      0      0      0   unless print $self->print_errors
741   ***     50      1      0   if (my(@errors) = @{$$self{'errors'};})
757   ***     50      0     10   unless $$self{'got_opts'}
761          100      3     29   $$_{'is_negatable'} ? :
766   ***     50      0     12   $$self{'opts'}{$_}{'is_negatable'} ? :
787          100     10      4   $group eq 'default' ? :
793          100      3     29   $$opt{'is_negatable'} ? :
797          100      2     30   if ($$opt{'type'} and $$opt{'type'} eq 'm')
807          100     12     20   if ($short) { }
816          100      4      6   if (my(@rules) = @{$$self{'rules'};})
820          100      2      8   if ($$self{'dp'})
828          100      1     10   $val ? :
             100      6      1   $type =~ /A|a/ ? :
             100      2      7   $type =~ /H|h/ ? :
             100      2      9   $type eq 'd' ? :
             100     10     11   !defined($val) ? :
             100     11     21   $bool ? :
843   ***      0      0      0   if ref $_[0] eq 'OptionParser'
846   ***      0      0      0   unless print $prompt
854   ***      0      0      0   unless print "\n"
857   ***      0      0      0   if ($EVAL_ERROR)
884          100     17      5   unless open my $fh, '<', $filename
893          100      4     19   if $line =~ /^\s*(?:\#|\;|$)/
900          100      4     15   if ($line eq '--')
905          100      8      7   if ($parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/) { }
      ***     50      7      0   elsif ($line =~ /./) { }
925   ***     50      0      2   unless open my $fh, '<', $file
929          100      4      2   unless $para =~ /^=pod$/m
933          100      5      2   unless $para =~ /$regex/
938   ***     50      0      2   unless close $fh
956   ***      0      0      0   $ref eq 'ARRAY' ? :
      ***     50      3      0   $ref eq 'HASH' ? :
             100      2      3   !$ref ? :
972   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
281          100     76     77     11   $type and $type eq 'd'
      ***     66    153     11      0   $type and $type eq 'd' and not $$self{'dp'}
288          100     76     38     50   $type and $type =~ /[HhAadzm]/
453          100     14     36      4   @ARGV and $ARGV[0] eq '--config'
486   ***     66     48      5      0   exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'}
493          100     50      2      1   @ARGV and $$self{'strict'}
583   ***     66      0    143    163   $opt and $$opt{'type'}
586          100     91     64      8   $val and $$opt{'type'} eq 'm'
             100     91     54     10   $val and $$opt{'type'} eq 'd'
             100     91     48      6   $val and $$opt{'type'} eq 'z'
             100     87     46      1   defined $val and $$opt{'type'} eq 'h'
             100     83     33      2   defined $val and $$opt{'type'} eq 'a'
657          100      1      2     87   $long and exists $$self{'opts'}{$long}
668          100      1      1     37   $long and exists $$self{'opts'}{$long}
688          100      1      1      3   $long and exists $$self{'opts'}{$long}
797          100     12     18      2   $$opt{'type'} and $$opt{'type'} eq 'm'
905   ***     66      7      0      8   $parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
48    ***     50     34      0   $program_name ||= $PROGRAM_NAME
49    ***     50     34      0   $ENV{'HOME'} || $ENV{'HOMEPATH'} || $ENV{'USERPROFILE'} || '.'
51           100      2     32   $args{'prompt'} || '<options>'
             100      9     25   $args{'dp'} || undef
107   ***     50      9      0   $file ||= '../OptionParser.pm'
271          100    104     60   $$opt{'group'} ||= 'default'
592          100      4      1   $s || 's'
632          100      2      3   $pre || ''
639          100      2      4   $val || ''
642          100     13      4   $val || ''
714   ***     50     11      0   $$self{'description'} || ''
799          100      1      1   $s ||= 's'
826          100     20     12   $$opt{'type'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
49    ***     33     34      0      0   $ENV{'HOME'} || $ENV{'HOMEPATH'}
      ***     33     34      0      0   $ENV{'HOME'} || $ENV{'HOMEPATH'} || $ENV{'USERPROFILE'}
586          100      5      1    133   $$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h'
             100     15      2    116   $$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a'


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
__ANON__              68 /home/daniel/dev/maatkit/common/OptionParser.pm:481
_d                     1 /home/daniel/dev/maatkit/common/OptionParser.pm:971
_get_participants     25 /home/daniel/dev/maatkit/common/OptionParser.pm:365
_parse_specs          33 /home/daniel/dev/maatkit/common/OptionParser.pm:234
_pod_to_specs          9 /home/daniel/dev/maatkit/common/OptionParser.pm:106
_read_config_file     22 /home/daniel/dev/maatkit/common/OptionParser.pm:883
_set_option           72 /home/daniel/dev/maatkit/common/OptionParser.pm:416
_validate_type       306 /home/daniel/dev/maatkit/common/OptionParser.pm:582
clone                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:946
descr                 11 /home/daniel/dev/maatkit/common/OptionParser.pm:713
errors                13 /home/daniel/dev/maatkit/common/OptionParser.pm:703
get                   90 /home/daniel/dev/maatkit/common/OptionParser.pm:655
get_defaults           3 /home/daniel/dev/maatkit/common/OptionParser.pm:403
get_defaults_files     7 /home/daniel/dev/maatkit/common/OptionParser.pm:90 
get_groups             1 /home/daniel/dev/maatkit/common/OptionParser.pm:408
get_opts              54 /home/daniel/dev/maatkit/common/OptionParser.pm:437
get_specs              4 /home/daniel/dev/maatkit/common/OptionParser.pm:82 
got                   39 /home/daniel/dev/maatkit/common/OptionParser.pm:666
has                  141 /home/daniel/dev/maatkit/common/OptionParser.pm:675
new                   34 /home/daniel/dev/maatkit/common/OptionParser.pm:43 
opts                   4 /home/daniel/dev/maatkit/common/OptionParser.pm:378
print_errors           1 /home/daniel/dev/maatkit/common/OptionParser.pm:739
print_usage           10 /home/daniel/dev/maatkit/common/OptionParser.pm:756
prompt                11 /home/daniel/dev/maatkit/common/OptionParser.pm:708
read_para_after        2 /home/daniel/dev/maatkit/common/OptionParser.pm:924
save_error            16 /home/daniel/dev/maatkit/common/OptionParser.pm:697
set                    5 /home/daniel/dev/maatkit/common/OptionParser.pm:686
set_defaults           5 /home/daniel/dev/maatkit/common/OptionParser.pm:391
short_opts             1 /home/daniel/dev/maatkit/common/OptionParser.pm:385

Uncovered Subroutines
---------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
prompt_noecho          0 /home/daniel/dev/maatkit/common/OptionParser.pm:843
usage_or_errors        0 /home/daniel/dev/maatkit/common/OptionParser.pm:724


