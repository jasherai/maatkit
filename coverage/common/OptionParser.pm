---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/OptionParser.pm   92.3   82.6   91.4   92.1    n/a  100.0   89.3
Total                          92.3   82.6   91.4   92.1    n/a  100.0   89.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          OptionParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jun 10 17:20:41 2009
Finish:       Wed Jun 10 17:20:41 2009

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
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  9   
24                                                    
25             1                    1            10   use Getopt::Long;
               1                                  4   
               1                                  8   
26             1                    1             8   use List::Util qw(max);
               1                                  2   
               1                                 19   
27             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  9   
28                                                    
29             1                    1             8   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 10   
30                                                    
31                                                    my $POD_link_re = '[LC]<"?([^">]+)"?>';
32                                                    
33                                                    sub new {
34            32                   32           240      my ( $class, %args ) = @_;
35            32                                147      foreach my $arg ( qw(description) ) {
36    ***     32     50                         207         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38            32                                294      my ($program_name) = $PROGRAM_NAME =~ m/([.A-Za-z-]+)$/;
39    ***     32            50                  136      $program_name ||= $PROGRAM_NAME;
40                                                    
41            32    100    100                 1287      my $self = {
                           100                        
42                                                          description    => $args{description},
43                                                          prompt         => $args{prompt} || '<options>',
44                                                          strict         => (exists $args{strict} ? $args{strict} : 1),
45                                                          dp             => $args{dp}     || undef,
46                                                          program_name   => $program_name,
47                                                          opts           => {},
48                                                          got_opts       => 0,
49                                                          short_opts     => {},
50                                                          defaults       => {},
51                                                          groups         => {},
52                                                          allowed_groups => {},
53                                                          errors         => [],
54                                                          rules          => [],  # desc of rules for --help
55                                                          mutex          => [],  # rule: opts are mutually exclusive
56                                                          atleast1       => [],  # rule: at least one opt is required
57                                                          disables       => {},  # rule: opt disables other opts 
58                                                          defaults_to    => {},  # rule: opt defaults to value of other opt
59                                                          default_files  => [
60                                                             "/etc/maatkit/maatkit.conf",
61                                                             "/etc/maatkit/$program_name.conf",
62                                                             "$ENV{HOME}/.maatkit.conf",
63                                                             "$ENV{HOME}/.$program_name.conf",
64                                                          ],
65                                                       };
66            32                                261      return bless $self, $class;
67                                                    }
68                                                    
69                                                    # Read and parse POD OPTIONS in file or current script if
70                                                    # no file is given. This sub must be called before get_opts();
71                                                    sub get_specs {
72             2                    2             9      my ( $self, $file ) = @_;
73             2                                 11      my @specs = $self->_pod_to_specs($file);
74             2                                 27      $self->_parse_specs(@specs);
75             2                                  8      return;
76                                                    }
77                                                    
78                                                    # Returns the program's defaults files.
79                                                    sub get_defaults_files {
80             6                    6            22      my ( $self ) = @_;
81             6                                 20      return @{$self->{default_files}};
               6                                 56   
82                                                    }
83                                                    
84                                                    # Parse command line options from the OPTIONS section of the POD in the
85                                                    # given file. If no file is given, the currently running program's POD
86                                                    # is parsed.
87                                                    # Returns an array of hashrefs which is usually passed to _parse_specs().
88                                                    # Each hashref in the array corresponds to one command line option from
89                                                    # the POD. Each hashref has the structure:
90                                                    #    {
91                                                    #       spec  => GetOpt::Long specification,
92                                                    #       desc  => short description for --help
93                                                    #       group => option group (default: 'default')
94                                                    #    }
95                                                    sub _pod_to_specs {
96             7                    7            33      my ( $self, $file ) = @_;
97    ***      7            50                   30      $file ||= __FILE__;
98    ***      7     50                         258      open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
99                                                    
100            7                                 95      my %types = (
101                                                         string => 's', # standard Getopt type
102                                                         'int'  => 'i', # standard Getopt type
103                                                         float  => 'f', # standard Getopt type
104                                                         Hash   => 'H', # hash, formed from a comma-separated list
105                                                         hash   => 'h', # hash as above, but only if a value is given
106                                                         Array  => 'A', # array, similar to Hash
107                                                         array  => 'a', # array, similar to hash
108                                                         DSN    => 'd', # DSN, as provided by a DSNParser which is in $self->{dp}
109                                                         size   => 'z', # size with kMG suffix (powers of 2^10)
110                                                         'time' => 'm', # time, with an optional suffix of s/h/m/d
111                                                      );
112            7                                 23      my @specs = ();
113            7                                 18      my @rules = ();
114            7                                 17      my $para;
115                                                   
116                                                      # Read a paragraph at a time from the file.  Skip everything until options
117                                                      # are reached...
118            7                                 37      local $INPUT_RECORD_SEPARATOR = '';
119            7                               1528      while ( $para = <$fh> ) {
120           61    100                         613         next unless $para =~ m/^=head1 OPTIONS/;
121            6                                 29         last;
122                                                      }
123                                                   
124                                                      # ... then read any option rules...
125            7                                 60      while ( $para = <$fh> ) {
126            7    100                         114         last if $para =~ m/^=over/;
127            1                                  7         chomp $para;
128            1                                 14         $para =~ s/\s+/ /g;
129            1                                 58         $para =~ s/$POD_link_re/$1/go;
130            1                                  4         MKDEBUG && _d('Option rule:', $para);
131            1                                 15         push @rules, $para;
132                                                      }
133                                                   
134            7    100                          39      die 'POD has no OPTIONS section' unless $para;
135                                                   
136                                                      # ... then start reading options.
137            6                                 25      do {
138           42    100                         311         if ( my ($option) = $para =~ m/^=item --(.*)/ ) {
139           36                                103            chomp $para;
140           36                                 88            MKDEBUG && _d($para);
141           36                                 86            my %attribs;
142                                                   
143           36                                135            $para = <$fh>; # read next paragraph, possibly attributes
144                                                   
145           36    100                         151            if ( $para =~ m/: / ) { # attributes
146           31                                141               $para =~ s/\s+\Z//g;
147           31                                144               %attribs = map { split(/: /, $_) } split(/; /, $para);
              41                                217   
148           31    100                         153               if ( $attribs{'short form'} ) {
149            6                                 28                  $attribs{'short form'} =~ s/-//;
150                                                               }
151           31                                134               $para = <$fh>; # read next paragraph, probably short help desc
152                                                            }
153                                                            else {
154            5                                 19               MKDEBUG && _d('Option has no attributes');
155                                                            }
156                                                   
157                                                            # Remove extra spaces and POD formatting (L<"">).
158           36                                197            $para =~ s/\s+\Z//g;
159           36                                163            $para =~ s/\s+/ /g;
160           36                                144            $para =~ s/$POD_link_re/$1/go;
161                                                   
162                                                            # Take the first period-terminated sentence as the option's short help
163                                                            # description.
164           36                                150            $para =~ s/\.(?:\n.*| [A-Z].*|\Z)//s;
165           36                                 81            MKDEBUG && _d('Short help:', $para);
166                                                   
167           36    100                         147            die "No description after option spec $option" if $para =~ m/^=item/;
168                                                   
169                                                            # Change [no]foo to foo and set negatable attrib. See issue 140.
170           35    100                         160            if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
171            1                                  3               $option = $base_option;
172            1                                  4               $attribs{'negatable'} = 1;
173                                                            }
174                                                   
175           35    100                         585            push @specs, {
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
176                                                               spec  => $option
177                                                                  . ($attribs{'short form'} ? '|' . $attribs{'short form'} : '' )
178                                                                  . ($attribs{'negatable'}  ? '!'                          : '' )
179                                                                  . ($attribs{'cumulative'} ? '+'                          : '' )
180                                                                  . ($attribs{'type'}       ? '=' . $types{$attribs{type}} : '' ),
181                                                               desc  => $para
182                                                                  . ($attribs{default} ? " (default $attribs{default})" : ''),
183                                                               group => ($attribs{'group'} ? $attribs{'group'} : 'default'),
184                                                            };
185                                                         }
186           41                                247         while ( $para = <$fh> ) {
187   ***     55     50                         193            last unless $para;
188                                                   
189                                                            # The 'allowed with' hack that was here was removed.
190                                                            # Groups need to be used instead. So, this new OptionParser
191                                                            # module will not work with mk-table-sync.
192                                                   
193           55    100                         224            if ( $para =~ m/^=head1/ ) {
194            5                                 20               $para = undef; # Can't 'last' out of a do {} block.
195            5                                 26               last;
196                                                            }
197           50    100                         335            last if $para =~ m/^=item --/;
198                                                         }
199                                                      } while ( $para );
200                                                   
201            5    100                          20      die 'No valid specs in POD OPTIONS' unless @specs;
202                                                   
203            4                                 43      close $fh;
204            4                                 13      return @specs, @rules;
205                                                   }
206                                                   
207                                                   # Parse an array of option specs and rules (usually the return value of
208                                                   # _pod_to_spec()). Each option spec is parsed and the following attributes
209                                                   # pairs are added to its hashref:
210                                                   #    short         => the option's short key (-A for --charset)
211                                                   #    is_cumulative => true if the option is cumulative
212                                                   #    is_negatable  => true if the option is negatable
213                                                   #    is_required   => true if the option is required
214                                                   #    type          => the option's type (see %types in _pod_to_spec() above)
215                                                   #    got           => true if the option was given explicitly on the cmd line
216                                                   #    value         => the option's value
217                                                   #
218                                                   sub _parse_specs {
219           32                   32           179      my ( $self, @specs ) = @_;
220           32                                 97      my %disables; # special rule that requires deferred checking
221                                                   
222           32                                134      foreach my $opt ( @specs ) {
223          119    100                         434         if ( ref $opt ) { # It's an option spec, not a rule.
224                                                            MKDEBUG && _d('Parsing opt spec:',
225          108                                244               map { ($_, '=>', $opt->{$_}) } keys %$opt);
226                                                   
227          108                                760            my ( $long, $short ) = $opt->{spec} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
228   ***    108     50                         446            if ( !$long ) {
229                                                               # This shouldn't happen.
230   ***      0                                  0               die "Cannot parse long option from spec $opt->{spec}";
231                                                            }
232          108                                390            $opt->{long} = $long;
233                                                   
234   ***    108     50                         513            die "Duplicate long option --$long" if exists $self->{opts}->{$long};
235          108                                437            $self->{opts}->{$long} = $opt;
236                                                   
237          108    100                         421            if ( length $long == 1 ) {
238            5                                 10               MKDEBUG && _d('Long opt', $long, 'looks like short opt');
239            5                                 23               $self->{short_opts}->{$long} = $long;
240                                                            }
241                                                   
242          108    100                         338            if ( $short ) {
243   ***     39     50                         186               die "Duplicate short option -$short"
244                                                                  if exists $self->{short_opts}->{$short};
245           39                                162               $self->{short_opts}->{$short} = $long;
246           39                                139               $opt->{short} = $short;
247                                                            }
248                                                            else {
249           69                                250               $opt->{short} = undef;
250                                                            }
251                                                   
252          108    100                         570            $opt->{is_negatable}  = $opt->{spec} =~ m/!/        ? 1 : 0;
253          108    100                         535            $opt->{is_cumulative} = $opt->{spec} =~ m/\+/       ? 1 : 0;
254          108    100                         544            $opt->{is_required}   = $opt->{desc} =~ m/required/ ? 1 : 0;
255                                                   
256          108           100                  572            $opt->{group} ||= 'default';
257          108                                533            $self->{groups}->{ $opt->{group} }->{$long} = 1;
258                                                   
259          108                                338            $opt->{value} = undef;
260          108                                356            $opt->{got}   = 0;
261                                                   
262          108                                564            my ( $type ) = $opt->{spec} =~ m/=(.)/;
263          108                                385            $opt->{type} = $type;
264          108                                229            MKDEBUG && _d($long, 'type:', $type);
265                                                   
266   ***    108     50    100                  884            if ( $type && $type eq 'd' && !$self->{dp} ) {
      ***                   66                        
267   ***      0                                  0               die "$opt->{long} is type DSN (d) but no dp argument "
268                                                                  . "was given when this OptionParser object was created";
269                                                            }
270                                                   
271                                                            # Option has a non-Getopt type: HhAadzm (see %types in
272                                                            # _pod_to_spec() above). For these, use Getopt type 's'.
273          108    100    100                  797            $opt->{spec} =~ s/=./=s/ if ( $type && $type =~ m/[HhAadzm]/ );
274                                                   
275                                                            # Option has a default value if its desc says 'default' or 'default X'.
276                                                            # These defaults from the POD may be overridden by later calls
277                                                            # to set_defaults().
278          108    100                         624            if ( (my ($def) = $opt->{desc} =~ m/default\b(?: ([^)]+))?/) ) {
279                                                               # This allows "default yes" for negatable opts. See issue 404.
280           17    100                          75               if ( $opt->{is_negatable} ) {
281   ***      1      0                           6                  $def = $def eq 'yes' ? 1
      ***            50                               
282                                                                       : $def eq 'no'  ? 0
283                                                                       : $def;
284                                                               }
285           17    100                          90               $self->{defaults}->{$long} = defined $def ? $def : 1;
286           17                                 46               MKDEBUG && _d($long, 'default:', $def);
287                                                            }
288                                                   
289                                                            # Handle special behavior for --config.
290          108    100                         409            if ( $long eq 'config' ) {
291            5                                 26               $self->{defaults}->{$long} = join(',', $self->get_defaults_files());
292                                                            }
293                                                   
294                                                            # Option disable another option if its desc says 'disable'.
295          108    100                         532            if ( (my ($dis) = $opt->{desc} =~ m/(disables .*)/) ) {
296                                                               # Defer checking till later because of possible forward references.
297            3                                 11               $disables{$long} = $dis;
298            3                                  7               MKDEBUG && _d('Deferring check of disables rule for', $opt, $dis);
299                                                            }
300                                                   
301                                                            # Save the option.
302          108                                515            $self->{opts}->{$long} = $opt;
303                                                         }
304                                                         else { # It's an option rule, not a spec.
305           11                                 27            MKDEBUG && _d('Parsing rule:', $opt); 
306           11                                 27            push @{$self->{rules}}, $opt;
              11                                 53   
307           11                                 54            my @participants = $self->_get_participants($opt);
308            9                                 30            my $rule_ok = 0;
309                                                   
310            9    100                          77            if ( $opt =~ m/mutually exclusive|one and only one/ ) {
311            4                                 11               $rule_ok = 1;
312            4                                 11               push @{$self->{mutex}}, \@participants;
               4                                 18   
313            4                                 10               MKDEBUG && _d(@participants, 'are mutually exclusive');
314                                                            }
315            9    100                          63            if ( $opt =~ m/at least one|one and only one/ ) {
316            4                                 13               $rule_ok = 1;
317            4                                  9               push @{$self->{atleast1}}, \@participants;
               4                                 20   
318            4                                 11               MKDEBUG && _d(@participants, 'require at least one');
319                                                            }
320            9    100                          42            if ( $opt =~ m/default to/ ) {
321            2                                  7               $rule_ok = 1;
322                                                               # Example: "DSN values in L<"--dest"> default to values
323                                                               # from L<"--source">."
324            2                                 10               $self->{defaults_to}->{$participants[0]} = $participants[1];
325            2                                  7               MKDEBUG && _d($participants[0], 'defaults to', $participants[1]);
326                                                            }
327            9    100                          38            if ( $opt =~ m/restricted to option groups/ ) {
328            1                                  3               $rule_ok = 1;
329            1                                  7               my ($groups) = $opt =~ m/groups ([\w\s\,]+)/;
330            1                                  6               my @groups = split(',', $groups);
331            1                                  9               %{$self->{allowed_groups}->{$participants[0]}} = map {
               4                                 13   
332            1                                  4                  s/\s+//;
333            4                                 13                  $_ => 1;
334                                                               } @groups;
335                                                            }
336                                                   
337   ***      9     50                          50            die "Unrecognized option rule: $opt" unless $rule_ok;
338                                                         }
339                                                      }
340                                                   
341                                                      # Check forward references in 'disables' rules.
342           30                                183      foreach my $long ( keys %disables ) {
343                                                         # _get_participants() will check that each opt exists.
344            2                                 12         my @participants = $self->_get_participants($disables{$long});
345            1                                  8         $self->{disables}->{$long} = \@participants;
346            1                                  4         MKDEBUG && _d('Option', $long, 'disables', @participants);
347                                                      }
348                                                   
349           29                                140      return; 
350                                                   }
351                                                   
352                                                   # Returns an array of long option names in str. This is used to
353                                                   # find the "participants" of option rules (i.e. the options to
354                                                   # which a rule applies).
355                                                   sub _get_participants {
356           15                   15            72      my ( $self, $str ) = @_;
357           15                                 50      my @participants;
358           15                                135      foreach my $long ( $str =~ m/--(?:\[no\])?([\w-]+)/g ) {
359           32    100                         142         die "Option --$long does not exist while processing rule $str"
360                                                            unless exists $self->{opts}->{$long};
361           29                                112         push @participants, $long;
362                                                      }
363           12                                 34      MKDEBUG && _d('Participants for', $str, ':', @participants);
364           12                                 72      return @participants;
365                                                   }
366                                                   
367                                                   # Returns a copy of the internal opts hash.
368                                                   sub opts {
369            4                    4            17      my ( $self ) = @_;
370            4                                 13      my %opts = %{$self->{opts}};
               4                                 41   
371            4                                 71      return %opts;
372                                                   }
373                                                   
374                                                   # Return a simplified option=>value hash like the original
375                                                   # %opts hash frequently used scripts. Some subs in other
376                                                   # modules, like DSNParser::get_cxn_params(), expect this
377                                                   # kind of hash.
378                                                   sub opt_values {
379            1                    1             6      my ( $self ) = @_;
380           12    100                          61      my %opts = map {
381            1                                  9         my $opt = $self->{opts}->{$_}->{short} ? $self->{opts}->{$_}->{short}
382                                                                 : $_;
383           12                                 62         $opt => $self->{opts}->{$_}->{value}
384            1                                  3      } keys %{$self->{opts}};
385            1                                 14      return %opts;
386                                                   }
387                                                   
388                                                   # Returns a copy of the internal short_opts hash.
389                                                   sub short_opts {
390            1                    1             4      my ( $self ) = @_;
391            1                                  3      my %short_opts = %{$self->{short_opts}};
               1                                  7   
392            1                                 19      return %short_opts;
393                                                   }
394                                                   
395                                                   sub set_defaults {
396            5                    5            29      my ( $self, %defaults ) = @_;
397            5                                 25      $self->{defaults} = {};
398            5                                 43      foreach my $long ( keys %defaults ) {
399            3    100                          17         die "Cannot set default for nonexistent option $long"
400                                                            unless exists $self->{opts}->{$long};
401            2                                 10         $self->{defaults}->{$long} = $defaults{$long};
402            2                                  7         MKDEBUG && _d('Default val for', $long, ':', $defaults{$long});
403                                                      }
404            4                                 16      return;
405                                                   }
406                                                   
407                                                   sub get_defaults {
408            3                    3            13      my ( $self ) = @_;
409            3                                 19      return $self->{defaults};
410                                                   }
411                                                   
412                                                   sub get_groups {
413            1                    1             5      my ( $self ) = @_;
414            1                                 15      return $self->{groups};
415                                                   }
416                                                   
417                                                   # Getopt::Long calls this sub for each opt it finds on the
418                                                   # cmd line. We have to do this in order to know which opts
419                                                   # were "got" on the cmd line.
420                                                   sub _set_option {
421           63                   63           268      my ( $self, $opt, $val ) = @_;
422   ***     63      0                         161      my $long = exists $self->{opts}->{$opt}       ? $opt
      ***            50                               
423                                                               : exists $self->{short_opts}->{$opt} ? $self->{short_opts}->{$opt}
424                                                               : die "Getopt::Long gave a nonexistent option: $opt";
425                                                   
426                                                      # Reassign $opt.
427           63                                126      $opt = $self->{opts}->{$long};
428           63    100                         332      if ( $opt->{is_cumulative} ) {
429            8                                 26         $opt->{value}++;
430                                                      }
431                                                      else {
432           55                                203         $opt->{value} = $val;
433                                                      }
434           63                                217      $opt->{got} = 1;
435           63                                221      MKDEBUG && _d('Got option', $long, '=', $val);
436                                                   }
437                                                   
438                                                   # Get options on the command line (ARGV) according to the option specs
439                                                   # and enforce option rules. Option values are saved internally in
440                                                   # $self->{opts} and accessed later by get(), got() and set().
441                                                   sub get_opts {
442           55                   55           237      my ( $self ) = @_; 
443                                                   
444                                                      # Reset opts. 
445           55                                187      foreach my $long ( keys %{$self->{opts}} ) {
              55                                375   
446          200                                812         $self->{opts}->{$long}->{got} = 0;
447          200    100                        1748         $self->{opts}->{$long}->{value}
                    100                               
448                                                            = exists $self->{defaults}->{$long}       ? $self->{defaults}->{$long}
449                                                            : $self->{opts}->{$long}->{is_cumulative} ? 0
450                                                            : undef;
451                                                      }
452           55                                216      $self->{got_opts} = 0;
453                                                   
454                                                      # Reset errors.
455           55                                214      $self->{errors} = [];
456                                                   
457                                                      # --config is special-case; parse them manually and remove them from @ARGV
458           55    100    100                  494      if ( @ARGV && $ARGV[0] eq "--config" ) {
459            4                                 11         shift @ARGV;
460            4                                 20         $self->_set_option('config', shift @ARGV);
461                                                      }
462           55    100                         290      if ( $self->has('config') ) {
463            6                                 17         my @extra_args;
464            6                                 30         foreach my $filename ( split(',', $self->get('config')) ) {
465                                                            # Try to open the file.  If it was set explicitly, it's an error if it
466                                                            # can't be opened, but the built-in defaults are to be ignored if they
467                                                            # can't be opened.
468           13                                 34            eval {
469           13                                 64               push @ARGV, $self->_read_config_file($filename);
470                                                            };
471           13    100                          96            if ( $EVAL_ERROR ) {
472            9    100                          37               if ( $self->got('config') ) {
473            1                                  2                  die $EVAL_ERROR;
474                                                               }
475                                                               elsif ( MKDEBUG ) {
476                                                                  _d($EVAL_ERROR);
477                                                               }
478                                                            }
479                                                         }
480            5                                 25         unshift @ARGV, @extra_args;
481                                                      }
482                                                   
483           54                                327      Getopt::Long::Configure('no_ignore_case', 'bundling');
484                                                      GetOptions(
485                                                         # Make Getopt::Long specs for each option with custom handler subs.
486          193                   59          1480         map    { $_->{spec} => sub { $self->_set_option(@_); } }
              59                                280   
             198                                802   
487           54                                269         grep   { $_->{long} ne 'config' } # --config is handled specially above.
488           54    100                         165         values %{$self->{opts}}
489                                                      ) or $self->save_error('Error parsing options');
490                                                   
491   ***     54     50     66                  703      if ( exists $self->{opts}->{version} && $self->{opts}->{version}->{got} ) {
492   ***      0      0                           0         printf("%s  Ver %s Distrib %s Changeset %s\n",
493                                                            $self->{program_name}, $main::VERSION, $main::DISTRIB, $main::SVN_REV)
494                                                               or die "Cannot print: $OS_ERROR";
495   ***      0                                  0         exit 0;
496                                                      }
497                                                   
498           54    100    100                  308      if ( @ARGV && $self->{strict} ) {
499            1                                  7         $self->save_error("Unrecognized command-line options @ARGV");
500                                                      }
501                                                   
502                                                      # Check mutex options.
503           54                                154      foreach my $mutex ( @{$self->{mutex}} ) {
              54                                282   
504            6                                 23         my @set = grep { $self->{opts}->{$_}->{got} } @$mutex;
              15                                 73   
505            6    100                          30         if ( @set > 1 ) {
506            5                                 44            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               3                                 10   
507            3                                 20                         @{$mutex}[ 0 .. scalar(@$mutex) - 2] )
508                                                                    . ' and --'.$self->{opts}->{$mutex->[-1]}->{long}
509                                                                    . ' are mutually exclusive.';
510            3                                 15            $self->save_error($err);
511                                                         }
512                                                      }
513                                                   
514           54                                158      foreach my $required ( @{$self->{atleast1}} ) {
              54                                240   
515            4                                 16         my @set = grep { $self->{opts}->{$_}->{got} } @$required;
              12                                 55   
516            4    100                          23         if ( @set == 0 ) {
517            4                                 30            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               2                                  8   
518            2                                 15                         @{$required}[ 0 .. scalar(@$required) - 2] )
519                                                                    .' or --'.$self->{opts}->{$required->[-1]}->{long};
520            2                                 14            $self->save_error("Specify at least one of $err");
521                                                         }
522                                                      }
523                                                   
524           54                                153      foreach my $long ( keys %{$self->{opts}} ) {
              54                                271   
525          198                                719         my $opt = $self->{opts}->{$long};
526          198    100                        1032         if ( $opt->{got} ) {
                    100                               
527                                                            # Rule: opt disables other opts.
528           58    100                         269            if ( exists $self->{disables}->{$long} ) {
529            1                                  3               my @disable_opts = @{$self->{disables}->{$long}};
               1                                 10   
530            1                                  4               map { $self->{opts}->{$_}->{value} = undef; } @disable_opts;
               1                                  5   
531            1                                  3               MKDEBUG && _d('Unset options', @disable_opts,
532                                                                  'because', $long,'disables them');
533                                                            }
534                                                   
535                                                            # Group restrictions.
536           58    100                         293            if ( exists $self->{allowed_groups}->{$long} ) {
537                                                               # This option is only allowed with other options from
538                                                               # certain groups.  Check that no options from restricted
539                                                               # groups were gotten.
540                                                   
541           10                                 44               my @restricted_groups = grep {
542            2                                 11                  !exists $self->{allowed_groups}->{$long}->{$_}
543            2                                  6               } keys %{$self->{groups}};
544                                                   
545            2                                  7               my @restricted_opts;
546            2                                  8               foreach my $restricted_group ( @restricted_groups ) {
547            2                                 11                  RESTRICTED_OPT:
548            2                                  6                  foreach my $restricted_opt (
549                                                                     keys %{$self->{groups}->{$restricted_group}} )
550                                                                  {
551            4    100                          22                     next RESTRICTED_OPT if $restricted_opt eq $long;
552            2    100                          12                     push @restricted_opts, $restricted_opt
553                                                                        if $self->{opts}->{$restricted_opt}->{got};
554                                                                  }
555                                                               }
556                                                   
557            2    100                           9               if ( @restricted_opts ) {
558            1                                  2                  my $err;
559   ***      1     50                           5                  if ( @restricted_opts == 1 ) {
560            1                                  4                     $err = "--$restricted_opts[0]";
561                                                                  }
562                                                                  else {
563   ***      0                                  0                     $err = join(', ',
564   ***      0                                  0                               map { "--$self->{opts}->{$_}->{long}" }
565   ***      0                                  0                               grep { $_ } 
566                                                                               @restricted_opts[0..scalar(@restricted_opts) - 2]
567                                                                            )
568                                                                          . ' or --'.$self->{opts}->{$restricted_opts[-1]}->{long};
569                                                                  }
570            1                                  8                  $self->save_error("--$long is not allowed with $err");
571                                                               }
572                                                            }
573                                                   
574                                                         }
575                                                         elsif ( $opt->{is_required} ) { 
576            3                                 18            $self->save_error("Required option --$long must be specified");
577                                                         }
578                                                   
579          198                                762         $self->_validate_type($opt);
580                                                      }
581                                                   
582           54                                221      $self->{got_opts} = 1;
583           54                                186      return;
584                                                   }
585                                                   
586                                                   sub _validate_type {
587          198                  198           696      my ( $self, $opt ) = @_;
588   ***    198    100     66                 1706      return unless $opt && $opt->{type};
589          113                                370      my $val = $opt->{value};
590                                                   
591          113    100    100                 2586      if ( $val && $opt->{type} eq 'm' ) {
                    100    100                        
                    100    100                        
                    100    100                        
                    100    100                        
                           100                        
                           100                        
592            8                                 22         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a time value');
593            8                                 59         my ( $num, $suffix ) = $val =~ m/(\d+)([a-z])?$/;
594                                                         # The suffix defaults to 's' unless otherwise specified.
595            8    100                          36         if ( !$suffix ) {
596            5                                 26            my ( $s ) = $opt->{desc} =~ m/\(suffix (.)\)/;
597            5           100                   25            $suffix = $s || 's';
598            5                                 13            MKDEBUG && _d('No suffix given; using', $suffix, 'for',
599                                                               $opt->{long}, '(value:', $val, ')');
600                                                         }
601            8    100                          38         if ( $suffix =~ m/[smhd]/ ) {
602            7    100                          48            $val = $suffix eq 's' ? $num            # Seconds
                    100                               
                    100                               
603                                                                 : $suffix eq 'm' ? $num * 60       # Minutes
604                                                                 : $suffix eq 'h' ? $num * 3600     # Hours
605                                                                 :                  $num * 86400;   # Days
606            7                                 26            $opt->{value} = $val;
607            7                                 18            MKDEBUG && _d('Setting option', $opt->{long}, 'to', $val);
608                                                         }
609                                                         else {
610            1                                  8            $self->save_error("Invalid time suffix for --$opt->{long}");
611                                                         }
612                                                      }
613                                                      elsif ( $val && $opt->{type} eq 'd' ) {
614            5                                 11         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a DSN');
615            5                                 28         my $from_key = $self->{defaults_to}->{ $opt->{long} };
616            5                                 16         my $default = {};
617            5    100                          21         if ( $from_key ) {
618            2                                  4            MKDEBUG && _d($opt->{long}, 'DSN copies from', $from_key, 'DSN');
619            2                                 22            $default = $self->{dp}->parse(
620                                                               $self->{dp}->as_string($self->{opts}->{$from_key}->{value}) );
621                                                         }
622            5                                 35         $opt->{value} = $self->{dp}->parse($val, $default);
623                                                      }
624                                                      elsif ( $val && $opt->{type} eq 'z' ) {
625            6                                 15         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a size value');
626            6                                 34         my %factor_for = (k => 1_024, M => 1_048_576, G => 1_073_741_824);
627            6                                 47         my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
628            6    100                          25         if ( defined $num ) {
629            5    100                          25            if ( $factor ) {
630            4                                 21               $num *= $factor_for{$factor};
631            4                                 10               MKDEBUG && _d('Setting option', $opt->{y},
632                                                                  'to num', $num, '* factor', $factor);
633                                                            }
634            5           100                   45            $opt->{value} = ($pre || '') . $num;
635                                                         }
636                                                         else {
637            1                                  7            $self->save_error("Invalid size for --$opt->{long}");
638                                                         }
639                                                      }
640                                                      elsif ( $opt->{type} eq 'H' || (defined $val && $opt->{type} eq 'h') ) {
641            6           100                   56         $opt->{value} = { map { $_ => 1 } split(',', ($val || '')) };
               4                                 19   
642                                                      }
643                                                      elsif ( $opt->{type} eq 'A' || (defined $val && $opt->{type} eq 'a') ) {
644           15           100                  157         $opt->{value} = [ split(/(?<!\\),/, ($val || '')) ];
645                                                      }
646                                                      else {
647           73                                161         MKDEBUG && _d('Nothing to validate for option',
648                                                            $opt->{long}, 'type', $opt->{type}, 'value', $val);
649                                                      }
650                                                   
651          113                                422      return;
652                                                   }
653                                                   
654                                                   # Get an option's value. The option can be either a
655                                                   # short or long name (e.g. -A or --charset).
656                                                   sub get {
657           65                   65           302      my ( $self, $opt ) = @_;
658           65    100                         381      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
659           65    100    100                  667      die "Option $opt does not exist"
660                                                         unless $long && exists $self->{opts}->{$long};
661           62                                614      return $self->{opts}->{$long}->{value};
662                                                   }
663                                                   
664                                                   # Returns true if the option was given explicitly on the
665                                                   # command line; returns false if not. The option can be
666                                                   # either short or long name (e.g. -A or --charset).
667                                                   sub got {
668           31                   31           150      my ( $self, $opt ) = @_;
669           31    100                         153      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
670           31    100    100                  288      die "Option $opt does not exist"
671                                                         unless $long && exists $self->{opts}->{$long};
672           29                                218      return $self->{opts}->{$long}->{got};
673                                                   }
674                                                   
675                                                   # Returns true if the option exists.
676                                                   sub has {
677           62                   62           304      my ( $self, $opt ) = @_;
678           62    100                         342      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
679           62    100                         513      return defined $long ? exists $self->{opts}->{$long} : 0;
680                                                   }
681                                                   
682                                                   # Set an option's value. The option can be either a
683                                                   # short or long name (e.g. -A or --charset). The value
684                                                   # can be any scalar, ref, or undef. No type checking
685                                                   # is done so becareful to not set, for example, an integer
686                                                   # option with a DSN.
687                                                   sub set {
688            5                    5            27      my ( $self, $opt, $val ) = @_;
689            5    100                          28      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
690            5    100    100                   37      die "Option $opt does not exist"
691                                                         unless $long && exists $self->{opts}->{$long};
692            3                                 13      $self->{opts}->{$long}->{value} = $val;
693            3                                 10      return;
694                                                   }
695                                                   
696                                                   # Save an error message to be reported later by calling usage_or_errors()
697                                                   # (or errors()--mostly for testing).
698                                                   sub save_error {
699           15                   15            71      my ( $self, $error ) = @_;
700           15                                 45      push @{$self->{errors}}, $error;
              15                                 79   
701                                                   }
702                                                   
703                                                   # Return arrayref of errors (mostly for testing).
704                                                   sub errors {
705           13                   13            54      my ( $self ) = @_;
706           13                                103      return $self->{errors};
707                                                   }
708                                                   
709                                                   sub prompt {
710           11                   11            43      my ( $self ) = @_;
711           11                                 80      return "Usage: $PROGRAM_NAME $self->{prompt}\n";
712                                                   }
713                                                   
714                                                   sub descr {
715           11                   11            40      my ( $self ) = @_;
716   ***     11            50                  117      my $descr  = $self->{program_name} . ' ' . ($self->{description} || '')
717                                                                 . "  For more details, please use the --help option, "
718                                                                 . "or try 'perldoc $PROGRAM_NAME' "
719                                                                 . "for complete documentation.";
720           11                                170      $descr = join("\n", $descr =~ m/(.{0,80})(?:\s+|$)/g);
721           11                                 97      $descr =~ s/ +$//mg;
722           11                                 77      return $descr;
723                                                   }
724                                                   
725                                                   sub usage_or_errors {
726   ***      0                    0             0      my ( $self ) = @_;
727   ***      0      0                           0      if ( $self->{opts}->{help}->{got} ) {
      ***      0      0                           0   
728   ***      0      0                           0         print $self->print_usage() or die "Cannot print usage: $OS_ERROR";
729   ***      0                                  0         exit 0;
730                                                      }
731                                                      elsif ( scalar @{$self->{errors}} ) {
732   ***      0      0                           0         print $self->print_errors() or die "Cannot print errors: $OS_ERROR";
733   ***      0                                  0         exit 0;
734                                                      }
735   ***      0                                  0      return;
736                                                   }
737                                                   
738                                                   # Explains what errors were found while processing command-line arguments and
739                                                   # gives a brief overview so you can get more information.
740                                                   sub print_errors {
741            1                    1             4      my ( $self ) = @_;
742            1                                  5      my $usage = $self->prompt() . "\n";
743   ***      1     50                          12      if ( (my @errors = @{$self->{errors}}) ) {
               1                                  8   
744            1                                  6         $usage .= join("\n  * ", 'Errors in command-line arguments:', @errors)
745                                                                 . "\n";
746                                                      }
747            1                                  5      return $usage . "\n" . $self->descr();
748                                                   }
749                                                   
750                                                   # Prints out command-line help.  The format is like this:
751                                                   # --foo  -F   Description of --foo
752                                                   # --bars -B   Description of --bar
753                                                   # --longopt   Description of --longopt
754                                                   # Note that the short options are aligned along the right edge of their longest
755                                                   # long option, but long options that don't have a short option are allowed to
756                                                   # protrude past that.
757                                                   sub print_usage {
758           10                   10            42      my ( $self ) = @_;
759   ***     10     50                          54      die "Run get_opts() before print_usage()" unless $self->{got_opts};
760           10                                 28      my @opts = values %{$self->{opts}};
              10                                 59   
761                                                   
762                                                      # Find how wide the widest long option is.
763           32    100                         217      my $maxl = max(
764           10                                 41         map { length($_->{long}) + ($_->{is_negatable} ? 4 : 0) }
765                                                         @opts);
766                                                   
767                                                      # Find how wide the widest option with a short option is.
768   ***     12     50                          75      my $maxs = max(0,
769           10                                 57         map { length($_) + ($self->{opts}->{$_}->{is_negatable} ? 4 : 0) }
770           10                                 37         values %{$self->{short_opts}});
771                                                   
772                                                      # Find how wide the 'left column' (long + short opts) is, and therefore how
773                                                      # much space to give options and how much to give descriptions.
774           10                                 49      my $lcol = max($maxl, ($maxs + 3));
775           10                                 55      my $rcol = 80 - $lcol - 6;
776           10                                 51      my $rpad = ' ' x ( 80 - $rcol );
777                                                   
778                                                      # Adjust the width of the options that have long and short both.
779           10                                 43      $maxs = max($lcol - 3, $maxs);
780                                                   
781                                                      # Format and return the options.
782           10                                 51      my $usage = $self->descr() . "\n" . $self->prompt();
783                                                   
784                                                      # Sort groups alphabetically but make 'default' first.
785           10                                 36      my @groups = reverse sort grep { $_ ne 'default'; } keys %{$self->{groups}};
              14                                 85   
              10                                 52   
786           10                                 46      push @groups, 'default';
787                                                   
788           10                                 37      foreach my $group ( reverse @groups ) {
789           14    100                          71         $usage .= "\n".($group eq 'default' ? 'Options' : $group).":\n\n";
790           14                                 45         foreach my $opt (
              22                                 89   
791           64                                234            sort { $a->{long} cmp $b->{long} }
792                                                            grep { $_->{group} eq $group }
793                                                            @opts )
794                                                         {
795           32    100                         190            my $long  = $opt->{is_negatable} ? "[no]$opt->{long}" : $opt->{long};
796           32                                102            my $short = $opt->{short};
797           32                                112            my $desc  = $opt->{desc};
798                                                            # Expand suffix help for time options.
799           32    100    100                  256            if ( $opt->{type} && $opt->{type} eq 'm' ) {
800            2                                 10               my ($s) = $desc =~ m/\(suffix (.)\)/;
801            2           100                    9               $s    ||= 's';
802            2                                  7               $desc =~ s/\s+\(suffix .\)//;
803            2                                 10               $desc .= ".  Optional suffix s=seconds, m=minutes, h=hours, "
804                                                                      . "d=days; if no suffix, $s is used.";
805                                                            }
806                                                            # Wrap long descriptions
807           32                                449            $desc = join("\n$rpad", grep { $_ } $desc =~ m/(.{0,$rcol})(?:\s+|$)/g);
              69                                251   
808           32                                156            $desc =~ s/ +$//mg;
809           32    100                         102            if ( $short ) {
810           12                                 92               $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
811                                                            }
812                                                            else {
813           20                                157               $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
814                                                            }
815                                                         }
816                                                      }
817                                                   
818           10    100                          32      if ( (my @rules = @{$self->{rules}}) ) {
              10                                 68   
819            4                                 12         $usage .= "\nRules:\n\n";
820            4                                 16         $usage .= join("\n", map { "  $_" } @rules) . "\n";
               4                                 29   
821                                                      }
822           10    100                          49      if ( $self->{dp} ) {
823            2                                 16         $usage .= "\n" . $self->{dp}->usage();
824                                                      }
825           10                                 43      $usage .= "\nOptions and values after processing arguments:\n\n";
826           10                                 19      foreach my $opt ( sort { $a->{long} cmp $b->{long} } @opts ) {
              34                                124   
827           32                                119         my $val   = $opt->{value};
828           32           100                  199         my $type  = $opt->{type} || '';
829           32                                196         my $bool  = $opt->{spec} =~ m/^[\w-]+(?:\|[\w-])?!?$/;
830           32    100                         223         $val      = $bool                     ? ( $val ? 'TRUE' : 'FALSE' )
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
831                                                                   : !defined $val             ? '(No value)'
832                                                                   : $type eq 'd'              ? $self->{dp}->as_string($val)
833                                                                   : $type =~ m/H|h/           ? join(',', sort keys %$val)
834                                                                   : $type =~ m/A|a/           ? join(',', @$val)
835                                                                   :                             $val;
836           32                                220         $usage .= sprintf("  --%-${lcol}s  %s\n", $opt->{long}, $val);
837                                                      }
838           10                                 94      return $usage;
839                                                   }
840                                                   
841                                                   # Tries to prompt and read the answer without echoing the answer to the
842                                                   # terminal.  This isn't really related to this package, but it's too handy not
843                                                   # to put here.  OK, it's related, it gets config information from the user.
844                                                   sub prompt_noecho {
845   ***      0      0             0             0      shift @_ if ref $_[0] eq __PACKAGE__;
846   ***      0                                  0      my ( $prompt ) = @_;
847   ***      0                                  0      local $OUTPUT_AUTOFLUSH = 1;
848   ***      0      0                           0      print $prompt
849                                                         or die "Cannot print: $OS_ERROR";
850   ***      0                                  0      my $response;
851   ***      0                                  0      eval {
852   ***      0                                  0         require Term::ReadKey;
853   ***      0                                  0         Term::ReadKey::ReadMode('noecho');
854   ***      0                                  0         chomp($response = <STDIN>);
855   ***      0                                  0         Term::ReadKey::ReadMode('normal');
856   ***      0      0                           0         print "\n"
857                                                            or die "Cannot print: $OS_ERROR";
858                                                      };
859   ***      0      0                           0      if ( $EVAL_ERROR ) {
860   ***      0                                  0         die "Cannot read response; is Term::ReadKey installed? $EVAL_ERROR";
861                                                      }
862   ***      0                                  0      return $response;
863                                                   }
864                                                   
865                                                   # This is debug code I want to run for all tools, and this is a module I
866                                                   # certainly include in all tools, but otherwise there's no real reason to put
867                                                   # it here.
868                                                   if ( MKDEBUG ) {
869                                                      print '# ', $^X, ' ', $], "\n";
870                                                      my $uname = `uname -a`;
871                                                      if ( $uname ) {
872                                                         $uname =~ s/\s+/ /g;
873                                                         print "# $uname\n";
874                                                      }
875                                                      printf("# %s  Ver %s Distrib %s Changeset %s line %d\n",
876                                                         $PROGRAM_NAME, ($main::VERSION || ''), ($main::DISTRIB || ''),
877                                                         ($main::SVN_REV || ''), __LINE__);
878                                                      print('# Arguments: ',
879                                                         join(' ', map { my $a = "_[$_]_"; $a =~ s/\n/\n# /g; $a; } @ARGV), "\n");
880                                                   }
881                                                   
882                                                   # Reads a configuration file and returns it as a list.  Inspired by
883                                                   # Config::Tiny.
884                                                   sub _read_config_file {
885           14                   14            61      my ( $self, $filename ) = @_;
886           14    100                         183      open my $fh, "<", $filename or die "Cannot open $filename: $OS_ERROR\n";
887            5                                 15      my @args;
888            5                                 16      my $prefix = '--';
889            5                                 16      my $parse  = 1;
890                                                   
891                                                      LINE:
892            5                              16639      while ( my $line = <$fh> ) {
893           23                                 77         chomp $line;
894                                                         # Skip comments and empty lines
895           23    100                         182         next LINE if $line =~ m/^\s*(?:\#|\;|$)/;
896                                                         # Remove inline comments
897           19                                 77         $line =~ s/\s+#.*$//g;
898                                                         # Remove whitespace
899           19                                129         $line =~ s/^\s+|\s+$//g;
900                                                         # Watch for the beginning of the literal values (not to be interpreted as
901                                                         # options)
902           19    100                          85         if ( $line eq '--' ) {
903            4                                 14            $prefix = '';
904            4                                 12            $parse  = 0;
905            4                                 23            next LINE;
906                                                         }
907   ***     15    100     66                  201         if ( $parse
      ***            50                               
908                                                            && (my($opt, $arg) = $line =~ m/^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/)
909                                                         ) {
910            8                                 40            push @args, grep { defined $_ } ("$prefix$opt", $arg);
              16                                104   
911                                                         }
912                                                         elsif ( $line =~ m/./ ) {
913            7                                 60            push @args, $line;
914                                                         }
915                                                         else {
916   ***      0                                  0            die "Syntax error in file $filename at line $INPUT_LINE_NUMBER";
917                                                         }
918                                                      }
919            5                                 43      close $fh;
920            5                                 15      return @args;
921                                                   }
922                                                   
923                                                   # Reads the next paragraph from the POD after the magical regular expression is
924                                                   # found in the text.
925                                                   sub read_para_after {
926            2                    2            10      my ( $self, $file, $regex ) = @_;
927   ***      2     50                          48      open my $fh, "<", $file or die "Can't open $file: $OS_ERROR";
928            2                                 11      local $INPUT_RECORD_SEPARATOR = '';
929            2                                  5      my $para;
930            2                                304      while ( $para = <$fh> ) {
931            6    100                          55         next unless $para =~ m/^=pod$/m;
932            2                                  7         last;
933                                                      }
934            2                                 15      while ( $para = <$fh> ) {
935            7    100                          59         next unless $para =~ m/$regex/;
936            2                                  7         last;
937                                                      }
938            2                                  8      $para = <$fh>;
939            2                                  9      chomp($para);
940   ***      2     50                          25      close $fh or die "Can't close $file: $OS_ERROR";
941            2                                  8      return $para;
942                                                   }
943                                                   
944                                                   # Returns a lightweight clone of ourself.  Currently, only the basic
945                                                   # opts are copied.  This is used for stuff like "final opts" in
946                                                   # mk-table-checksum.
947                                                   sub clone {
948            1                    1             4      my ( $self ) = @_;
949                                                   
950                                                      # Deep-copy contents of hashrefs; do not just copy the refs. 
951            3                                 10      my %clone = map {
952            1                                  5         my $hashref  = $self->{$_};
953            3                                  9         my $val_copy = {};
954            3                                 12         foreach my $key ( keys %$hashref ) {
955            5                                 17            my $ref = ref $hashref->{$key};
956            3                                 37            $val_copy->{$key} = !$ref           ? $hashref->{$key}
957   ***      0                                  0                              : $ref eq 'HASH'  ? { %{$hashref->{$key}} }
958   ***      5      0                          26                              : $ref eq 'ARRAY' ? [ @{$hashref->{$key}} ]
      ***            50                               
                    100                               
959                                                                              : $hashref->{$key};
960                                                         }
961            3                                 16         $_ => $val_copy;
962                                                      } qw(opts short_opts defaults);
963                                                   
964                                                      # Re-assign scalar values.
965            1                                  5      foreach my $scalar ( qw(got_opts) ) {
966            1                                 11         $clone{$scalar} = $self->{$scalar};
967                                                      }
968                                                   
969            1                                  8      return bless \%clone;     
970                                                   }
971                                                   
972                                                   sub _d {
973   ***      0                    0                    my ($package, undef, $line) = caller 0;
974   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
975   ***      0                                              map { defined $_ ? $_ : 'undef' }
976                                                           @_;
977   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
978                                                   }
979                                                   
980                                                   1;
981                                                   
982                                                   # ###########################################################################
983                                                   # End OptionParser package
984                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      0     32   unless $args{$arg}
41           100      1     31   exists $args{'strict'} ? :
98    ***     50      0      7   unless open my $fh, '<', $file
120          100     55      6   unless $para =~ /^=head1 OPTIONS/
126          100      6      1   if $para =~ /^=over/
134          100      1      6   unless $para
138          100     36      6   if (my($option) = $para =~ /^=item --(.*)/)
145          100     31      5   if ($para =~ /: /) { }
148          100      6     25   if ($attribs{'short form'})
167          100      1     35   if $para =~ /^=item/
170          100      1     34   if (my($base_option) = $option =~ /^\[no\](.*)/)
175          100      6     29   $attribs{'short form'} ? :
             100      3     32   $attribs{'negatable'} ? :
             100      2     33   $attribs{'cumulative'} ? :
             100     23     12   $attribs{'type'} ? :
             100      2     33   $attribs{'default'} ? :
             100      6     29   $attribs{'group'} ? :
187   ***     50      0     55   unless $para
193          100      5     50   if ($para =~ /^=head1/)
197          100     36     14   if $para =~ /^=item --/
201          100      1      4   unless @specs
223          100    108     11   if (ref $opt) { }
228   ***     50      0    108   if (not $long)
234   ***     50      0    108   if exists $$self{'opts'}{$long}
237          100      5    103   if (length $long == 1)
242          100     39     69   if ($short) { }
243   ***     50      0     39   if exists $$self{'short_opts'}{$short}
252          100      7    101   $$opt{'spec'} =~ /!/ ? :
253          100      4    104   $$opt{'spec'} =~ /\+/ ? :
254          100      3    105   $$opt{'desc'} =~ /required/ ? :
266   ***     50      0    108   if ($type and $type eq 'd' and not $$self{'dp'})
273          100     43     65   if $type and $type =~ /[HhAadzm]/
278          100     17     91   if (my($def) = $$opt{'desc'} =~ /default\b(?: ([^)]+))?/)
280          100      1     16   if ($$opt{'is_negatable'})
281   ***      0      0      0   $def eq 'no' ? :
      ***     50      1      0   $def eq 'yes' ? :
285          100     16      1   defined $def ? :
290          100      5    103   if ($long eq 'config')
295          100      3    105   if (my($dis) = $$opt{'desc'} =~ /(disables .*)/)
310          100      4      5   if ($opt =~ /mutually exclusive|one and only one/)
315          100      4      5   if ($opt =~ /at least one|one and only one/)
320          100      2      7   if ($opt =~ /default to/)
327          100      1      8   if ($opt =~ /restricted to option groups/)
337   ***     50      0      9   unless $rule_ok
359          100      3     29   unless exists $$self{'opts'}{$long}
380          100      2     10   $$self{'opts'}{$_}{'short'} ? :
399          100      1      2   unless exists $$self{'opts'}{$long}
422   ***      0      0      0   exists $$self{'short_opts'}{$opt} ? :
      ***     50     63      0   exists $$self{'opts'}{$opt} ? :
428          100      8     55   if ($$opt{'is_cumulative'}) { }
447          100     15    157   $$self{'opts'}{$long}{'is_cumulative'} ? :
             100     28    172   exists $$self{'defaults'}{$long} ? :
458          100      4     51   if (@ARGV and $ARGV[0] eq '--config')
462          100      6     49   if ($self->has('config'))
471          100      9      4   if ($EVAL_ERROR)
472          100      1      8   $self->got('config') ? :
488          100      3     51   unless GetOptions map({$$_{'spec'}, sub {
	$self->_set_option(@_);
}
;} grep({$$_{'long'} ne 'config';} values %{$$self{'opts'};}))
491   ***     50      0     54   if (exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'})
492   ***      0      0      0   unless printf "%s  Ver %s Distrib %s Changeset %s\n", $$self{'program_name'}, $main::VERSION, $main::DISTRIB, $main::SVN_REV
498          100      1     53   if (@ARGV and $$self{'strict'})
505          100      3      3   if (@set > 1)
516          100      2      2   if (@set == 0)
526          100     58    140   if ($$opt{'got'}) { }
             100      3    137   elsif ($$opt{'is_required'}) { }
528          100      1     57   if (exists $$self{'disables'}{$long})
536          100      2     56   if (exists $$self{'allowed_groups'}{$long})
551          100      2      2   if $restricted_opt eq $long
552          100      1      1   if $$self{'opts'}{$restricted_opt}{'got'}
557          100      1      1   if (@restricted_opts)
559   ***     50      1      0   if (@restricted_opts == 1) { }
588          100     85    113   unless $opt and $$opt{'type'}
591          100      8    105   if ($val and $$opt{'type'} eq 'm') { }
             100      5    100   elsif ($val and $$opt{'type'} eq 'd') { }
             100      6     94   elsif ($val and $$opt{'type'} eq 'z') { }
             100      6     88   elsif ($$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h') { }
             100     15     73   elsif ($$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a') { }
595          100      5      3   if (not $suffix)
601          100      7      1   if ($suffix =~ /[smhd]/) { }
602          100      2      1   $suffix eq 'h' ? :
             100      2      3   $suffix eq 'm' ? :
             100      2      5   $suffix eq 's' ? :
617          100      2      3   if ($from_key)
628          100      5      1   if (defined $num) { }
629          100      4      1   if ($factor)
658          100     18     47   length $opt == 1 ? :
659          100      3     62   unless $long and exists $$self{'opts'}{$long}
669          100      4     27   length $opt == 1 ? :
670          100      2     29   unless $long and exists $$self{'opts'}{$long}
678          100      2     60   length $opt == 1 ? :
679          100     61      1   defined $long ? :
689          100      2      3   length $opt == 1 ? :
690          100      2      3   unless $long and exists $$self{'opts'}{$long}
727   ***      0      0      0   if ($$self{'opts'}{'help'}{'got'}) { }
      ***      0      0      0   elsif (scalar @{$$self{'errors'};}) { }
728   ***      0      0      0   unless print $self->print_usage
732   ***      0      0      0   unless print $self->print_errors
743   ***     50      1      0   if (my(@errors) = @{$$self{'errors'};})
759   ***     50      0     10   unless $$self{'got_opts'}
763          100      3     29   $$_{'is_negatable'} ? :
768   ***     50      0     12   $$self{'opts'}{$_}{'is_negatable'} ? :
789          100     10      4   $group eq 'default' ? :
795          100      3     29   $$opt{'is_negatable'} ? :
799          100      2     30   if ($$opt{'type'} and $$opt{'type'} eq 'm')
809          100     12     20   if ($short) { }
818          100      4      6   if (my(@rules) = @{$$self{'rules'};})
822          100      2      8   if ($$self{'dp'})
830          100      1     10   $val ? :
             100      6      1   $type =~ /A|a/ ? :
             100      2      7   $type =~ /H|h/ ? :
             100      2      9   $type eq 'd' ? :
             100     10     11   !defined($val) ? :
             100     11     21   $bool ? :
845   ***      0      0      0   if ref $_[0] eq 'OptionParser'
848   ***      0      0      0   unless print $prompt
856   ***      0      0      0   unless print "\n"
859   ***      0      0      0   if ($EVAL_ERROR)
886          100      9      5   unless open my $fh, '<', $filename
895          100      4     19   if $line =~ /^\s*(?:\#|\;|$)/
902          100      4     15   if ($line eq '--')
907          100      8      7   if ($parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/) { }
      ***     50      7      0   elsif ($line =~ /./) { }
927   ***     50      0      2   unless open my $fh, '<', $file
931          100      4      2   unless $para =~ /^=pod$/m
935          100      5      2   unless $para =~ /$regex/
940   ***     50      0      2   unless close $fh
958   ***      0      0      0   $ref eq 'ARRAY' ? :
      ***     50      3      0   $ref eq 'HASH' ? :
             100      2      3   !$ref ? :
974   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
266          100     46     55      7   $type and $type eq 'd'
      ***     66    101      7      0   $type and $type eq 'd' and not $$self{'dp'}
273          100     46     19     43   $type and $type =~ /[HhAadzm]/
458          100     15     36      4   @ARGV and $ARGV[0] eq '--config'
491   ***     66     51      3      0   exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'}
498          100     51      2      1   @ARGV and $$self{'strict'}
588   ***     66      0     85    113   $opt and $$opt{'type'}
591          100     65     40      8   $val and $$opt{'type'} eq 'm'
             100     65     35      5   $val and $$opt{'type'} eq 'd'
             100     65     29      6   $val and $$opt{'type'} eq 'z'
             100     61     27      1   defined $val and $$opt{'type'} eq 'h'
             100     57     16      2   defined $val and $$opt{'type'} eq 'a'
659          100      1      2     62   $long and exists $$self{'opts'}{$long}
670          100      1      1     29   $long and exists $$self{'opts'}{$long}
690          100      1      1      3   $long and exists $$self{'opts'}{$long}
799          100     12     18      2   $$opt{'type'} and $$opt{'type'} eq 'm'
907   ***     66      7      0      8   $parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
39    ***     50     32      0   $program_name ||= $PROGRAM_NAME
41           100      2     30   $args{'prompt'} || '<options>'
             100      7     25   $args{'dp'} || undef
97    ***     50      7      0   $file ||= '../OptionParser.pm'
256          100     49     59   $$opt{'group'} ||= 'default'
597          100      4      1   $s || 's'
634          100      2      3   $pre || ''
641          100      2      4   $val || ''
644          100     11      4   $val || ''
716   ***     50     11      0   $$self{'description'} || ''
801          100      1      1   $s ||= 's'
828          100     20     12   $$opt{'type'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
591          100      5      1     88   $$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h'
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
__ANON__              59 /home/daniel/dev/maatkit/common/OptionParser.pm:486
_get_participants     15 /home/daniel/dev/maatkit/common/OptionParser.pm:356
_parse_specs          32 /home/daniel/dev/maatkit/common/OptionParser.pm:219
_pod_to_specs          7 /home/daniel/dev/maatkit/common/OptionParser.pm:96 
_read_config_file     14 /home/daniel/dev/maatkit/common/OptionParser.pm:885
_set_option           63 /home/daniel/dev/maatkit/common/OptionParser.pm:421
_validate_type       198 /home/daniel/dev/maatkit/common/OptionParser.pm:587
clone                  1 /home/daniel/dev/maatkit/common/OptionParser.pm:948
descr                 11 /home/daniel/dev/maatkit/common/OptionParser.pm:715
errors                13 /home/daniel/dev/maatkit/common/OptionParser.pm:705
get                   65 /home/daniel/dev/maatkit/common/OptionParser.pm:657
get_defaults           3 /home/daniel/dev/maatkit/common/OptionParser.pm:408
get_defaults_files     6 /home/daniel/dev/maatkit/common/OptionParser.pm:80 
get_groups             1 /home/daniel/dev/maatkit/common/OptionParser.pm:413
get_opts              55 /home/daniel/dev/maatkit/common/OptionParser.pm:442
get_specs              2 /home/daniel/dev/maatkit/common/OptionParser.pm:72 
got                   31 /home/daniel/dev/maatkit/common/OptionParser.pm:668
has                   62 /home/daniel/dev/maatkit/common/OptionParser.pm:677
new                   32 /home/daniel/dev/maatkit/common/OptionParser.pm:34 
opt_values             1 /home/daniel/dev/maatkit/common/OptionParser.pm:379
opts                   4 /home/daniel/dev/maatkit/common/OptionParser.pm:369
print_errors           1 /home/daniel/dev/maatkit/common/OptionParser.pm:741
print_usage           10 /home/daniel/dev/maatkit/common/OptionParser.pm:758
prompt                11 /home/daniel/dev/maatkit/common/OptionParser.pm:710
read_para_after        2 /home/daniel/dev/maatkit/common/OptionParser.pm:926
save_error            15 /home/daniel/dev/maatkit/common/OptionParser.pm:699
set                    5 /home/daniel/dev/maatkit/common/OptionParser.pm:688
set_defaults           5 /home/daniel/dev/maatkit/common/OptionParser.pm:396
short_opts             1 /home/daniel/dev/maatkit/common/OptionParser.pm:390

Uncovered Subroutines
---------------------

Subroutine         Count Location                                           
------------------ ----- ---------------------------------------------------
_d                     0 /home/daniel/dev/maatkit/common/OptionParser.pm:973
prompt_noecho          0 /home/daniel/dev/maatkit/common/OptionParser.pm:845
usage_or_errors        0 /home/daniel/dev/maatkit/common/OptionParser.pm:726


