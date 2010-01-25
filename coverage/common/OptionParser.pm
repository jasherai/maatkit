---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/OptionParser.pm   93.5   83.5   86.0   94.6    0.0   92.8   87.4
OptionParser.t                100.0   50.0   33.3  100.0    n/a    7.2   97.5
Total                          96.5   83.2   78.7   95.7    0.0  100.0   90.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Mon Jan 25 17:16:43 2010
Finish:       Mon Jan 25 17:16:43 2010

Run:          OptionParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Mon Jan 25 17:16:45 2010
Finish:       Mon Jan 25 17:16:46 2010

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
18                                                    # OptionParser package $Revision: 5525 $
19                                                    # ###########################################################################
20                                                    package OptionParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  5   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  9   
               1                                  8   
24                                                    
25             1                    1             8   use Getopt::Long;
               1                                  3   
               1                                  6   
26             1                    1             6   use List::Util qw(max);
               1                                  2   
               1                                 11   
27             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
28                                                    
29    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 13   
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
43    ***     36                   36      0    325      my ( $class, %args ) = @_;
44            36                                193      foreach my $arg ( qw(description) ) {
45    ***     36     50                         265         die "I need a $arg argument" unless $args{$arg};
46                                                       }
47            36                                395      my ($program_name) = $PROGRAM_NAME =~ m/([.A-Za-z-]+)$/;
48    ***     36            50                  372      $program_name ||= $PROGRAM_NAME;
49    ***     36            33                  372      my $home = $ENV{HOME} || $ENV{HOMEPATH} || $ENV{USERPROFILE} || '.';
      ***                   33                        
      ***                   50                        
50                                                    
51            36    100    100                 1591      my $self = {
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
76            36                                300      return bless $self, $class;
77                                                    }
78                                                    
79                                                    # Read and parse POD OPTIONS in file or current script if
80                                                    # no file is given. This sub must be called before get_opts();
81                                                    sub get_specs {
82    ***      6                    6      0     51      my ( $self, $file ) = @_;
83             6                                 51      my @specs = $self->_pod_to_specs($file);
84             5                                206      $self->_parse_specs(@specs);
85             5                                 50      return;
86                                                    }
87                                                    
88                                                    # Returns the program's defaults files.
89                                                    sub get_defaults_files {
90    ***      9                    9      0     43      my ( $self ) = @_;
91             9                                 33      return @{$self->{default_files}};
               9                                120   
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
106           11                   11            65      my ( $self, $file ) = @_;
107   ***     11            50                   57      $file ||= __FILE__;
108   ***     11     50                         690      open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
109                                                   
110           11                                217      my %types = (
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
122           11                                 51      my @specs = ();
123           11                                 45      my @rules = ();
124           11                                 32      my $para;
125                                                   
126                                                      # Read a paragraph at a time from the file.  Skip everything until options
127                                                      # are reached...
128           11                                 91      local $INPUT_RECORD_SEPARATOR = '';
129           11                              49715      while ( $para = <$fh> ) {
130         2973    100                       39329         next unless $para =~ m/^=head1 OPTIONS/;
131           10                                 47         last;
132                                                      }
133                                                   
134                                                      # ... then read any option rules...
135           11                                106      while ( $para = <$fh> ) {
136           21    100                         185         last if $para =~ m/^=over/;
137           11                                 56         chomp $para;
138           11                                142         $para =~ s/\s+/ /g;
139           11                                355         $para =~ s/$POD_link_re/$1/go;
140           11                                 48         MKDEBUG && _d('Option rule:', $para);
141           11                                154         push @rules, $para;
142                                                      }
143                                                   
144           11    100                          63      die 'POD has no OPTIONS section' unless $para;
145                                                   
146                                                      # ... then start reading options.
147           10                                 43      do {
148          232    100                        2467         if ( my ($option) = $para =~ m/^=item --(.*)/ ) {
149          222                                887            chomp $para;
150          222                                661            MKDEBUG && _d($para);
151          222                                735            my %attribs;
152                                                   
153          222                               1255            $para = <$fh>; # read next paragraph, possibly attributes
154                                                   
155          222    100                        1373            if ( $para =~ m/: / ) { # attributes
156          158                               1108               $para =~ s/\s+\Z//g;
157          228                               1623               %attribs = map {
158          158                               1114                     my ( $attrib, $val) = split(/: /, $_);
159          228    100                        1539                     die "Unrecognized attribute for --$option: $attrib"
160                                                                        unless $attributes{$attrib};
161          227                               1759                     ($attrib, $val);
162                                                                  } split(/; /, $para);
163          157    100                        1101               if ( $attribs{'short form'} ) {
164           27                                199                  $attribs{'short form'} =~ s/-//;
165                                                               }
166          157                               1083               $para = <$fh>; # read next paragraph, probably short help desc
167                                                            }
168                                                            else {
169           64                                222               MKDEBUG && _d('Option has no attributes');
170                                                            }
171                                                   
172                                                            # Remove extra spaces and POD formatting (L<"">).
173          221                               2312            $para =~ s/\s+\Z//g;
174          221                               2332            $para =~ s/\s+/ /g;
175          221                               1669            $para =~ s/$POD_link_re/$1/go;
176                                                   
177                                                            # Take the first period-terminated sentence as the option's short help
178                                                            # description.
179          221                               1316            $para =~ s/\.(?:\n.*| [A-Z].*|\Z)//s;
180          221                                666            MKDEBUG && _d('Short help:', $para);
181                                                   
182          221    100                        1639            die "No description after option spec $option" if $para =~ m/^=item/;
183                                                   
184                                                            # Change [no]foo to foo and set negatable attrib. See issue 140.
185          220    100                        1632            if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
186           11                                 49               $option = $base_option;
187           11                                 70               $attribs{'negatable'} = 1;
188                                                            }
189                                                   
190          220    100                        6035            push @specs, {
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
201          230                               2509         while ( $para = <$fh> ) {
202   ***    688     50                        3730            last unless $para;
203                                                   
204                                                            # The 'allowed with' hack that was here was removed.
205                                                            # Groups need to be used instead. So, this new OptionParser
206                                                            # module will not work with mk-table-sync.
207                                                   
208          688    100                        3976            if ( $para =~ m/^=head1/ ) {
209            8                                 32               $para = undef; # Can't 'last' out of a do {} block.
210            8                                 53               last;
211                                                            }
212          680    100                        7114            last if $para =~ m/^=item --/;
213                                                         }
214                                                      } while ( $para );
215                                                   
216            8    100                          41      die 'No valid specs in POD OPTIONS' unless @specs;
217                                                   
218            7                                100      close $fh;
219            7                                 29      return @specs, @rules;
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
234           35                   35           244      my ( $self, @specs ) = @_;
235           35                                121      my %disables; # special rule that requires deferred checking
236                                                   
237           35                                146      foreach my $opt ( @specs ) {
238          316    100                        1532         if ( ref $opt ) { # It's an option spec, not a rule.
239                                                            MKDEBUG && _d('Parsing opt spec:',
240          294                                881               map { ($_, '=>', $opt->{$_}) } keys %$opt);
241                                                   
242          294                               3608            my ( $long, $short ) = $opt->{spec} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
243   ***    294     50                        1707            if ( !$long ) {
244                                                               # This shouldn't happen.
245   ***      0                                  0               die "Cannot parse long option from spec $opt->{spec}";
246                                                            }
247          294                               1437            $opt->{long} = $long;
248                                                   
249   ***    294     50                        1875            die "Duplicate long option --$long" if exists $self->{opts}->{$long};
250          294                               1685            $self->{opts}->{$long} = $opt;
251                                                   
252          294    100                        1559            if ( length $long == 1 ) {
253            5                                 11               MKDEBUG && _d('Long opt', $long, 'looks like short opt');
254            5                                 21               $self->{short_opts}->{$long} = $long;
255                                                            }
256                                                   
257          294    100                        1258            if ( $short ) {
258   ***     60     50                         337               die "Duplicate short option -$short"
259                                                                  if exists $self->{short_opts}->{$short};
260           60                                300               $self->{short_opts}->{$short} = $long;
261           60                                242               $opt->{short} = $short;
262                                                            }
263                                                            else {
264          234                               1172               $opt->{short} = undef;
265                                                            }
266                                                   
267          294    100                        2227            $opt->{is_negatable}  = $opt->{spec} =~ m/!/        ? 1 : 0;
268          294    100                        2033            $opt->{is_cumulative} = $opt->{spec} =~ m/\+/       ? 1 : 0;
269          294    100                        2170            $opt->{is_required}   = $opt->{desc} =~ m/required/ ? 1 : 0;
270                                                   
271          294           100                 1713            $opt->{group} ||= 'default';
272          294                               2049            $self->{groups}->{ $opt->{group} }->{$long} = 1;
273                                                   
274          294                               1235            $opt->{value} = undef;
275          294                               1266            $opt->{got}   = 0;
276                                                   
277          294                               2063            my ( $type ) = $opt->{spec} =~ m/=(.)/;
278          294                               1412            $opt->{type} = $type;
279          294                                817            MKDEBUG && _d($long, 'type:', $type);
280                                                   
281   ***    294     50    100                 3493            if ( $type && $type eq 'd' && !$self->{dp} ) {
      ***                   66                        
282   ***      0                                  0               die "$opt->{long} is type DSN (d) but no dp argument "
283                                                                  . "was given when this OptionParser object was created";
284                                                            }
285                                                   
286                                                            # Option has a non-Getopt type: HhAadzm (see %types in
287                                                            # _pod_to_spec() above). For these, use Getopt type 's'.
288          294    100    100                 3009            $opt->{spec} =~ s/=./=s/ if ( $type && $type =~ m/[HhAadzm]/ );
289                                                   
290                                                            # Option has a default value if its desc says 'default' or 'default X'.
291                                                            # These defaults from the POD may be overridden by later calls
292                                                            # to set_defaults().
293          294    100                        2476            if ( (my ($def) = $opt->{desc} =~ m/default\b(?: ([^)]+))?/) ) {
294           65    100                         551               $self->{defaults}->{$long} = defined $def ? $def : 1;
295           65                                208               MKDEBUG && _d($long, 'default:', $def);
296                                                            }
297                                                   
298                                                            # Handle special behavior for --config.
299          294    100                        1605            if ( $long eq 'config' ) {
300            8                                 55               $self->{defaults}->{$long} = join(',', $self->get_defaults_files());
301                                                            }
302                                                   
303                                                            # Option disable another option if its desc says 'disable'.
304          294    100                        2083            if ( (my ($dis) = $opt->{desc} =~ m/(disables .*)/) ) {
305                                                               # Defer checking till later because of possible forward references.
306            4                                 15               $disables{$long} = $dis;
307            4                                 15               MKDEBUG && _d('Deferring check of disables rule for', $opt, $dis);
308                                                            }
309                                                   
310                                                            # Save the option.
311          294                               1951            $self->{opts}->{$long} = $opt;
312                                                         }
313                                                         else { # It's an option rule, not a spec.
314           22                                 74            MKDEBUG && _d('Parsing rule:', $opt); 
315           22                                 75            push @{$self->{rules}}, $opt;
              22                                135   
316           22                                140            my @participants = $self->_get_participants($opt);
317           20                                 81            my $rule_ok = 0;
318                                                   
319           20    100                         216            if ( $opt =~ m/mutually exclusive|one and only one/ ) {
320           10                                 38               $rule_ok = 1;
321           10                                 34               push @{$self->{mutex}}, \@participants;
              10                                 61   
322           10                                 31               MKDEBUG && _d(@participants, 'are mutually exclusive');
323                                                            }
324           20    100                         173            if ( $opt =~ m/at least one|one and only one/ ) {
325            5                                 19               $rule_ok = 1;
326            5                                 15               push @{$self->{atleast1}}, \@participants;
               5                                 26   
327            5                                 15               MKDEBUG && _d(@participants, 'require at least one');
328                                                            }
329           20    100                         123            if ( $opt =~ m/default to/ ) {
330            6                                 26               $rule_ok = 1;
331                                                               # Example: "DSN values in L<"--dest"> default to values
332                                                               # from L<"--source">."
333            6                                 49               $self->{defaults_to}->{$participants[0]} = $participants[1];
334            6                                 19               MKDEBUG && _d($participants[0], 'defaults to', $participants[1]);
335                                                            }
336           20    100                         110            if ( $opt =~ m/restricted to option groups/ ) {
337            1                                  3               $rule_ok = 1;
338            1                                  7               my ($groups) = $opt =~ m/groups ([\w\s\,]+)/;
339            1                                  8               my @groups = split(',', $groups);
340            1                                  8               %{$self->{allowed_groups}->{$participants[0]}} = map {
               4                                 13   
341            1                                  4                  s/\s+//;
342            4                                 14                  $_ => 1;
343                                                               } @groups;
344                                                            }
345                                                   
346   ***     20     50                         134            die "Unrecognized option rule: $opt" unless $rule_ok;
347                                                         }
348                                                      }
349                                                   
350                                                      # Check forward references in 'disables' rules.
351           33                                175      foreach my $long ( keys %disables ) {
352                                                         # _get_participants() will check that each opt exists.
353            3                                 19         my @participants = $self->_get_participants($disables{$long});
354            2                                 14         $self->{disables}->{$long} = \@participants;
355            2                                 10         MKDEBUG && _d('Option', $long, 'disables', @participants);
356                                                      }
357                                                   
358           32                                150      return; 
359                                                   }
360                                                   
361                                                   # Returns an array of long option names in str. This is used to
362                                                   # find the "participants" of option rules (i.e. the options to
363                                                   # which a rule applies).
364                                                   sub _get_participants {
365           27                   27           154      my ( $self, $str ) = @_;
366           27                                 89      my @participants;
367           27                                286      foreach my $long ( $str =~ m/--(?:\[no\])?([\w-]+)/g ) {
368           56    100                         345         die "Option --$long does not exist while processing rule $str"
369                                                            unless exists $self->{opts}->{$long};
370           53                                282         push @participants, $long;
371                                                      }
372           24                                 76      MKDEBUG && _d('Participants for', $str, ':', @participants);
373           24                                185      return @participants;
374                                                   }
375                                                   
376                                                   # Returns a copy of the internal opts hash.
377                                                   sub opts {
378   ***      4                    4      0     18      my ( $self ) = @_;
379            4                                 12      my %opts = %{$self->{opts}};
               4                                 37   
380            4                                 73      return %opts;
381                                                   }
382                                                   
383                                                   # Returns a copy of the internal short_opts hash.
384                                                   sub short_opts {
385   ***      1                    1      0      5      my ( $self ) = @_;
386            1                                  3      my %short_opts = %{$self->{short_opts}};
               1                                  9   
387            1                                  8      return %short_opts;
388                                                   }
389                                                   
390                                                   sub set_defaults {
391   ***      5                    5      0     25      my ( $self, %defaults ) = @_;
392            5                                 24      $self->{defaults} = {};
393            5                                 26      foreach my $long ( keys %defaults ) {
394            3    100                          13         die "Cannot set default for nonexistent option $long"
395                                                            unless exists $self->{opts}->{$long};
396            2                                  9         $self->{defaults}->{$long} = $defaults{$long};
397            2                                  7         MKDEBUG && _d('Default val for', $long, ':', $defaults{$long});
398                                                      }
399            4                                 15      return;
400                                                   }
401                                                   
402                                                   sub get_defaults {
403   ***      3                    3      0     11      my ( $self ) = @_;
404            3                                 18      return $self->{defaults};
405                                                   }
406                                                   
407                                                   sub get_groups {
408   ***      1                    1      0      4      my ( $self ) = @_;
409            1                                 20      return $self->{groups};
410                                                   }
411                                                   
412                                                   # Getopt::Long calls this sub for each opt it finds on the
413                                                   # cmd line. We have to do this in order to know which opts
414                                                   # were "got" on the cmd line.
415                                                   sub _set_option {
416           77                   77           381      my ( $self, $opt, $val ) = @_;
417   ***     77      0                         200      my $long = exists $self->{opts}->{$opt}       ? $opt
      ***            50                               
418                                                               : exists $self->{short_opts}->{$opt} ? $self->{short_opts}->{$opt}
419                                                               : die "Getopt::Long gave a nonexistent option: $opt";
420                                                   
421                                                      # Reassign $opt.
422           77                                184      $opt = $self->{opts}->{$long};
423           77    100                        1107      if ( $opt->{is_cumulative} ) {
424            8                                 29         $opt->{value}++;
425                                                      }
426                                                      else {
427           69                                278         $opt->{value} = $val;
428                                                      }
429           77                                260      $opt->{got} = 1;
430           77                                317      MKDEBUG && _d('Got option', $long, '=', $val);
431                                                   }
432                                                   
433                                                   # Get options on the command line (ARGV) according to the option specs
434                                                   # and enforce option rules. Option values are saved internally in
435                                                   # $self->{opts} and accessed later by get(), got() and set().
436                                                   sub get_opts {
437   ***     58                   58      0    269      my ( $self ) = @_; 
438                                                   
439                                                      # Reset opts. 
440           58                                176      foreach my $long ( keys %{$self->{opts}} ) {
              58                                473   
441          568                               3113         $self->{opts}->{$long}->{got} = 0;
442          568    100                        6316         $self->{opts}->{$long}->{value}
                    100                               
443                                                            = exists $self->{defaults}->{$long}       ? $self->{defaults}->{$long}
444                                                            : $self->{opts}->{$long}->{is_cumulative} ? 0
445                                                            : undef;
446                                                      }
447           58                                257      $self->{got_opts} = 0;
448                                                   
449                                                      # Reset errors.
450           58                                248      $self->{errors} = [];
451                                                   
452                                                      # --config is special-case; parse them manually and remove them from @ARGV
453           58    100    100                  558      if ( @ARGV && $ARGV[0] eq "--config" ) {
454            4                                 12         shift @ARGV;
455            4                                 20         $self->_set_option('config', shift @ARGV);
456                                                      }
457           58    100                         273      if ( $self->has('config') ) {
458           12                                 43         my @extra_args;
459           12                                100         foreach my $filename ( split(',', $self->get('config')) ) {
460                                                            # Try to open the file.  If it was set explicitly, it's an error if it
461                                                            # can't be opened, but the built-in defaults are to be ignored if they
462                                                            # can't be opened.
463           37                                139            eval {
464           37                                246               push @extra_args, $self->_read_config_file($filename);
465                                                            };
466           37    100                         311            if ( $EVAL_ERROR ) {
467           32    100                         171               if ( $self->got('config') ) {
468            1                                  2                  die $EVAL_ERROR;
469                                                               }
470                                                               elsif ( MKDEBUG ) {
471                                                                  _d($EVAL_ERROR);
472                                                               }
473                                                            }
474                                                         }
475           11                                 71         unshift @ARGV, @extra_args;
476                                                      }
477                                                   
478           57                                325      Getopt::Long::Configure('no_ignore_case', 'bundling');
479                                                      GetOptions(
480                                                         # Make Getopt::Long specs for each option with custom handler subs.
481          555                   73          4955         map    { $_->{spec} => sub { $self->_set_option(@_); } }
              73                             187015   
             566                               2951   
482           57                                312         grep   { $_->{long} ne 'config' } # --config is handled specially above.
483           57    100                        6821         values %{$self->{opts}}
484                                                      ) or $self->save_error('Error parsing options');
485                                                   
486   ***     57     50     66                12145      if ( exists $self->{opts}->{version} && $self->{opts}->{version}->{got} ) {
487   ***      0      0                           0         printf("%s  Ver %s Distrib %s Changeset %s\n",
488                                                            $self->{program_name}, $main::VERSION, $main::DISTRIB, $main::SVN_REV)
489                                                               or die "Cannot print: $OS_ERROR";
490   ***      0                                  0         exit 0;
491                                                      }
492                                                   
493           57    100    100                  335      if ( @ARGV && $self->{strict} ) {
494            1                                  8         $self->save_error("Unrecognized command-line options @ARGV");
495                                                      }
496                                                   
497                                                      # Check mutex options.
498           57                                151      foreach my $mutex ( @{$self->{mutex}} ) {
              57                                317   
499           18                                 83         my @set = grep { $self->{opts}->{$_}->{got} } @$mutex;
              39                                247   
500           18    100                         122         if ( @set > 1 ) {
501            5                                 38            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               3                                 12   
502            3                                 19                         @{$mutex}[ 0 .. scalar(@$mutex) - 2] )
503                                                                    . ' and --'.$self->{opts}->{$mutex->[-1]}->{long}
504                                                                    . ' are mutually exclusive.';
505            3                                 14            $self->save_error($err);
506                                                         }
507                                                      }
508                                                   
509           57                                167      foreach my $required ( @{$self->{atleast1}} ) {
              57                                271   
510            6                                 26         my @set = grep { $self->{opts}->{$_}->{got} } @$required;
              18                                100   
511            6    100                          39         if ( @set == 0 ) {
512            6                                 51            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               3                                 15   
513            3                                 22                         @{$required}[ 0 .. scalar(@$required) - 2] )
514                                                                    .' or --'.$self->{opts}->{$required->[-1]}->{long};
515            3                                 20            $self->save_error("Specify at least one of $err");
516                                                         }
517                                                      }
518                                                   
519           57                                166      foreach my $long ( keys %{$self->{opts}} ) {
              57                                386   
520          566                               8229         my $opt = $self->{opts}->{$long};
521          566    100                        4139         if ( $opt->{got} ) {
                    100                               
522                                                            # Rule: opt disables other opts.
523           71    100                         365            if ( exists $self->{disables}->{$long} ) {
524            1                                  3               my @disable_opts = @{$self->{disables}->{$long}};
               1                                  6   
525            1                                  4               map { $self->{opts}->{$_}->{value} = undef; } @disable_opts;
               1                                  4   
526            1                                  3               MKDEBUG && _d('Unset options', @disable_opts,
527                                                                  'because', $long,'disables them');
528                                                            }
529                                                   
530                                                            # Group restrictions.
531           71    100                         393            if ( exists $self->{allowed_groups}->{$long} ) {
532                                                               # This option is only allowed with other options from
533                                                               # certain groups.  Check that no options from restricted
534                                                               # groups were gotten.
535                                                   
536           10                                 46               my @restricted_groups = grep {
537            2                                 12                  !exists $self->{allowed_groups}->{$long}->{$_}
538            2                                  6               } keys %{$self->{groups}};
539                                                   
540            2                                  6               my @restricted_opts;
541            2                                  8               foreach my $restricted_group ( @restricted_groups ) {
542            2                                 11                  RESTRICTED_OPT:
543            2                                  4                  foreach my $restricted_opt (
544                                                                     keys %{$self->{groups}->{$restricted_group}} )
545                                                                  {
546            4    100                          22                     next RESTRICTED_OPT if $restricted_opt eq $long;
547            2    100                          13                     push @restricted_opts, $restricted_opt
548                                                                        if $self->{opts}->{$restricted_opt}->{got};
549                                                                  }
550                                                               }
551                                                   
552            2    100                           9               if ( @restricted_opts ) {
553            1                                  4                  my $err;
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
565            1                                  7                  $self->save_error("--$long is not allowed with $err");
566                                                               }
567                                                            }
568                                                   
569                                                         }
570                                                         elsif ( $opt->{is_required} ) { 
571            3                                 16            $self->save_error("Required option --$long must be specified");
572                                                         }
573                                                   
574          566                               2729         $self->_validate_type($opt);
575                                                      }
576                                                   
577           57                                277      $self->{got_opts} = 1;
578           57                                185      return;
579                                                   }
580                                                   
581                                                   sub _validate_type {
582          566                  566          2604      my ( $self, $opt ) = @_;
583   ***    566    100     66                 6887      return unless $opt && $opt->{type};
584          347                               1447      my $val = $opt->{value};
585                                                   
586          347    100    100                15492      if ( $val && $opt->{type} eq 'm' ) {  # type time
                    100    100                        
                    100    100                        
                    100    100                        
                    100    100                        
                           100                        
                           100                        
587           15                                 43         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a time value');
588           15                                175         my ( $prefix, $num, $suffix ) = $val =~ m/([+-]?)(\d+)([a-z])?$/;
589                                                         # The suffix defaults to 's' unless otherwise specified.
590           15    100                          89         if ( !$suffix ) {
591            7                                 40            my ( $s ) = $opt->{desc} =~ m/\(suffix (.)\)/;
592            7           100                   61            $suffix = $s || 's';
593            7                                 23            MKDEBUG && _d('No suffix given; using', $suffix, 'for',
594                                                               $opt->{long}, '(value:', $val, ')');
595                                                         }
596           15    100                          91         if ( $suffix =~ m/[smhd]/ ) {
597           14    100                          87            $val = $suffix eq 's' ? $num            # Seconds
                    100                               
                    100                               
598                                                                 : $suffix eq 'm' ? $num * 60       # Minutes
599                                                                 : $suffix eq 'h' ? $num * 3600     # Hours
600                                                                 :                  $num * 86400;   # Days
601           14           100                  156            $opt->{value} = ($prefix || '') . $val;
602           14                                 46            MKDEBUG && _d('Setting option', $opt->{long}, 'to', $val);
603                                                         }
604                                                         else {
605            1                                  6            $self->save_error("Invalid time suffix for --$opt->{long}");
606                                                         }
607                                                      }
608                                                      elsif ( $val && $opt->{type} eq 'd' ) {  # type DSN
609           10                                 27         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a DSN');
610                                                         # DSN vals for this opt may come from 3 places, in order of precedence:
611                                                         # the opt itself, the defaults to/copies from opt (prev), or
612                                                         # --host, --port, etc. (defaults).
613           10                                 50         my $prev = {};
614           10                                 52         my $from_key = $self->{defaults_to}->{ $opt->{long} };
615           10    100                          47         if ( $from_key ) {
616            4                                 11            MKDEBUG && _d($opt->{long}, 'DSN copies from', $from_key, 'DSN');
617            4                                 20            $prev = $self->{opts}->{$from_key}->{value};
618                                                         }
619           10                                 77         my $defaults = $self->{dp}->parse_options($self);
620           10                               1542         $opt->{value} = $self->{dp}->parse($val, $prev, $defaults);
621                                                      }
622                                                      elsif ( $val && $opt->{type} eq 'z' ) {  # type size
623            6                                 13         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a size value');
624            6                                 30         my %factor_for = (k => 1_024, M => 1_048_576, G => 1_073_741_824);
625            6                                 43         my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
626            6    100                          24         if ( defined $num ) {
627            5    100                          19            if ( $factor ) {
628            4                                 15               $num *= $factor_for{$factor};
629            4                                 19               MKDEBUG && _d('Setting option', $opt->{y},
630                                                                  'to num', $num, '* factor', $factor);
631                                                            }
632            5           100                   42            $opt->{value} = ($pre || '') . $num;
633                                                         }
634                                                         else {
635            1                                  7            $self->save_error("Invalid size for --$opt->{long}");
636                                                         }
637                                                      }
638                                                      elsif ( $opt->{type} eq 'H' || (defined $val && $opt->{type} eq 'h') ) {
639           10           100                  101         $opt->{value} = { map { $_ => 1 } split(',', ($val || '')) };
              24                                151   
640                                                      }
641                                                      elsif ( $opt->{type} eq 'A' || (defined $val && $opt->{type} eq 'a') ) {
642           61           100                  815         $opt->{value} = [ split(/(?<!\\),/, ($val || '')) ];
643                                                      }
644                                                      else {
645          245                                749         MKDEBUG && _d('Nothing to validate for option',
646                                                            $opt->{long}, 'type', $opt->{type}, 'value', $val);
647                                                      }
648                                                   
649          347                               4474      return;
650                                                   }
651                                                   
652                                                   # Get an option's value. The option can be either a
653                                                   # short or long name (e.g. -A or --charset).
654                                                   sub get {
655   ***     98                   98      0    557      my ( $self, $opt ) = @_;
656           98    100                         596      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
657           98    100    100                 1146      die "Option $opt does not exist"
658                                                         unless $long && exists $self->{opts}->{$long};
659           95                                980      return $self->{opts}->{$long}->{value};
660                                                   }
661                                                   
662                                                   # Returns true if the option was given explicitly on the
663                                                   # command line; returns false if not. The option can be
664                                                   # either short or long name (e.g. -A or --charset).
665                                                   sub got {
666   ***     54                   54      0    310      my ( $self, $opt ) = @_;
667           54    100                         308      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
668           54    100    100                  663      die "Option $opt does not exist"
669                                                         unless $long && exists $self->{opts}->{$long};
670           52                                521      return $self->{opts}->{$long}->{got};
671                                                   }
672                                                   
673                                                   # Returns true if the option exists.
674                                                   sub has {
675   ***    145                  145      0   1186      my ( $self, $opt ) = @_;
676          145    100                         805      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
677          145    100                        1167      return defined $long ? exists $self->{opts}->{$long} : 0;
678                                                   }
679                                                   
680                                                   # Set an option's value. The option can be either a
681                                                   # short or long name (e.g. -A or --charset). The value
682                                                   # can be any scalar, ref, or undef. No type checking
683                                                   # is done so becareful to not set, for example, an integer
684                                                   # option with a DSN.
685                                                   sub set {
686   ***      5                    5      0     26      my ( $self, $opt, $val ) = @_;
687            5    100                          26      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
688            5    100    100                   36      die "Option $opt does not exist"
689                                                         unless $long && exists $self->{opts}->{$long};
690            3                                 13      $self->{opts}->{$long}->{value} = $val;
691            3                                 10      return;
692                                                   }
693                                                   
694                                                   # Save an error message to be reported later by calling usage_or_errors()
695                                                   # (or errors()--mostly for testing).
696                                                   sub save_error {
697   ***     16                   16      0   3301      my ( $self, $error ) = @_;
698           16                                 47      push @{$self->{errors}}, $error;
              16                                 93   
699                                                   }
700                                                   
701                                                   # Return arrayref of errors (mostly for testing).
702                                                   sub errors {
703   ***     13                   13      0     54      my ( $self ) = @_;
704           13                                 92      return $self->{errors};
705                                                   }
706                                                   
707                                                   sub prompt {
708   ***     11                   11      0     39      my ( $self ) = @_;
709           11                                 80      return "Usage: $PROGRAM_NAME $self->{prompt}\n";
710                                                   }
711                                                   
712                                                   sub descr {
713   ***     11                   11      0     39      my ( $self ) = @_;
714   ***     11            50                  107      my $descr  = $self->{program_name} . ' ' . ($self->{description} || '')
715                                                                 . "  For more details, please use the --help option, "
716                                                                 . "or try 'perldoc $PROGRAM_NAME' "
717                                                                 . "for complete documentation.";
718                                                      # DONT_BREAK_LINES is set in OptionParser.t so the output can
719                                                      # be tested reliably.
720   ***     11     50                          60      $descr = join("\n", $descr =~ m/(.{0,80})(?:\s+|$)/g)
721                                                         unless $ENV{DONT_BREAK_LINES};
722           11                                 96      $descr =~ s/ +$//mg;
723           11                                 89      return $descr;
724                                                   }
725                                                   
726                                                   sub usage_or_errors {
727   ***      0                    0      0      0      my ( $self ) = @_;
728   ***      0      0                           0      if ( $self->{opts}->{help}->{got} ) {
      ***      0      0                           0   
729   ***      0      0                           0         print $self->print_usage() or die "Cannot print usage: $OS_ERROR";
730   ***      0                                  0         exit 0;
731                                                      }
732                                                      elsif ( scalar @{$self->{errors}} ) {
733   ***      0      0                           0         print $self->print_errors() or die "Cannot print errors: $OS_ERROR";
734   ***      0                                  0         exit 0;
735                                                      }
736   ***      0                                  0      return;
737                                                   }
738                                                   
739                                                   # Explains what errors were found while processing command-line arguments and
740                                                   # gives a brief overview so you can get more information.
741                                                   sub print_errors {
742   ***      1                    1      0      4      my ( $self ) = @_;
743            1                                 10      my $usage = $self->prompt() . "\n";
744   ***      1     50                           3      if ( (my @errors = @{$self->{errors}}) ) {
               1                                  8   
745            1                                  6         $usage .= join("\n  * ", 'Errors in command-line arguments:', @errors)
746                                                                 . "\n";
747                                                      }
748            1                                  5      return $usage . "\n" . $self->descr();
749                                                   }
750                                                   
751                                                   # Prints out command-line help.  The format is like this:
752                                                   # --foo  -F   Description of --foo
753                                                   # --bars -B   Description of --bar
754                                                   # --longopt   Description of --longopt
755                                                   # Note that the short options are aligned along the right edge of their longest
756                                                   # long option, but long options that don't have a short option are allowed to
757                                                   # protrude past that.
758                                                   sub print_usage {
759   ***     10                   10      0     44      my ( $self ) = @_;
760   ***     10     50                          50      die "Run get_opts() before print_usage()" unless $self->{got_opts};
761           10                                 31      my @opts = values %{$self->{opts}};
              10                                 54   
762                                                   
763                                                      # Find how wide the widest long option is.
764           32    100                         212      my $maxl = max(
765           10                                 39         map { length($_->{long}) + ($_->{is_negatable} ? 4 : 0) }
766                                                         @opts);
767                                                   
768                                                      # Find how wide the widest option with a short option is.
769   ***     12     50                          75      my $maxs = max(0,
770           10                                 66         map { length($_) + ($self->{opts}->{$_}->{is_negatable} ? 4 : 0) }
771           10                                 37         values %{$self->{short_opts}});
772                                                   
773                                                      # Find how wide the 'left column' (long + short opts) is, and therefore how
774                                                      # much space to give options and how much to give descriptions.
775           10                                 46      my $lcol = max($maxl, ($maxs + 3));
776           10                                 38      my $rcol = 80 - $lcol - 6;
777           10                                 47      my $rpad = ' ' x ( 80 - $rcol );
778                                                   
779                                                      # Adjust the width of the options that have long and short both.
780           10                                 41      $maxs = max($lcol - 3, $maxs);
781                                                   
782                                                      # Format and return the options.
783           10                                 51      my $usage = $self->descr() . "\n" . $self->prompt();
784                                                   
785                                                      # Sort groups alphabetically but make 'default' first.
786           10                                 37      my @groups = reverse sort grep { $_ ne 'default'; } keys %{$self->{groups}};
              14                                 77   
              10                                 52   
787           10                                 38      push @groups, 'default';
788                                                   
789           10                                 35      foreach my $group ( reverse @groups ) {
790           14    100                          69         $usage .= "\n".($group eq 'default' ? 'Options' : $group).":\n\n";
791           14                                 47         foreach my $opt (
              22                                 84   
792           64                                220            sort { $a->{long} cmp $b->{long} }
793                                                            grep { $_->{group} eq $group }
794                                                            @opts )
795                                                         {
796           32    100                         174            my $long  = $opt->{is_negatable} ? "[no]$opt->{long}" : $opt->{long};
797           32                                 96            my $short = $opt->{short};
798           32                                101            my $desc  = $opt->{desc};
799                                                            # Expand suffix help for time options.
800           32    100    100                  242            if ( $opt->{type} && $opt->{type} eq 'm' ) {
801            2                                  9               my ($s) = $desc =~ m/\(suffix (.)\)/;
802            2           100                    9               $s    ||= 's';
803            2                                  9               $desc =~ s/\s+\(suffix .\)//;
804            2                                  9               $desc .= ".  Optional suffix s=seconds, m=minutes, h=hours, "
805                                                                      . "d=days; if no suffix, $s is used.";
806                                                            }
807                                                            # Wrap long descriptions
808           32                                412            $desc = join("\n$rpad", grep { $_ } $desc =~ m/(.{0,$rcol})(?:\s+|$)/g);
              69                                236   
809           32                                154            $desc =~ s/ +$//mg;
810           32    100                         107            if ( $short ) {
811           12                                 88               $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
812                                                            }
813                                                            else {
814           20                                139               $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
815                                                            }
816                                                         }
817                                                      }
818                                                   
819           10    100                          31      if ( (my @rules = @{$self->{rules}}) ) {
              10                                 66   
820            4                                 11         $usage .= "\nRules:\n\n";
821            4                                 15         $usage .= join("\n", map { "  $_" } @rules) . "\n";
               4                                 21   
822                                                      }
823           10    100                          48      if ( $self->{dp} ) {
824            2                                 14         $usage .= "\n" . $self->{dp}->usage();
825                                                      }
826           10                                309      $usage .= "\nOptions and values after processing arguments:\n\n";
827           10                                 19      foreach my $opt ( sort { $a->{long} cmp $b->{long} } @opts ) {
              34                                122   
828           32                                121         my $val   = $opt->{value};
829           32           100                  170         my $type  = $opt->{type} || '';
830           32                                176         my $bool  = $opt->{spec} =~ m/^[\w-]+(?:\|[\w-])?!?$/;
831           32    100                         219         $val      = $bool                     ? ( $val ? 'TRUE' : 'FALSE' )
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
832                                                                   : !defined $val             ? '(No value)'
833                                                                   : $type eq 'd'              ? $self->{dp}->as_string($val)
834                                                                   : $type =~ m/H|h/           ? join(',', sort keys %$val)
835                                                                   : $type =~ m/A|a/           ? join(',', @$val)
836                                                                   :                             $val;
837           32                                366         $usage .= sprintf("  --%-${lcol}s  %s\n", $opt->{long}, $val);
838                                                      }
839           10                                126      return $usage;
840                                                   }
841                                                   
842                                                   # Tries to prompt and read the answer without echoing the answer to the
843                                                   # terminal.  This isn't really related to this package, but it's too handy not
844                                                   # to put here.  OK, it's related, it gets config information from the user.
845                                                   sub prompt_noecho {
846   ***      0      0             0      0      0      shift @_ if ref $_[0] eq __PACKAGE__;
847   ***      0                                  0      my ( $prompt ) = @_;
848   ***      0                                  0      local $OUTPUT_AUTOFLUSH = 1;
849   ***      0      0                           0      print $prompt
850                                                         or die "Cannot print: $OS_ERROR";
851   ***      0                                  0      my $response;
852   ***      0                                  0      eval {
853   ***      0                                  0         require Term::ReadKey;
854   ***      0                                  0         Term::ReadKey::ReadMode('noecho');
855   ***      0                                  0         chomp($response = <STDIN>);
856   ***      0                                  0         Term::ReadKey::ReadMode('normal');
857   ***      0      0                           0         print "\n"
858                                                            or die "Cannot print: $OS_ERROR";
859                                                      };
860   ***      0      0                           0      if ( $EVAL_ERROR ) {
861   ***      0                                  0         die "Cannot read response; is Term::ReadKey installed? $EVAL_ERROR";
862                                                      }
863   ***      0                                  0      return $response;
864                                                   }
865                                                   
866                                                   # This is debug code I want to run for all tools, and this is a module I
867                                                   # certainly include in all tools, but otherwise there's no real reason to put
868                                                   # it here.
869                                                   if ( MKDEBUG ) {
870                                                      print '# ', $^X, ' ', $], "\n";
871                                                      my $uname = `uname -a`;
872                                                      if ( $uname ) {
873                                                         $uname =~ s/\s+/ /g;
874                                                         print "# $uname\n";
875                                                      }
876                                                      printf("# %s  Ver %s Distrib %s Changeset %s line %d\n",
877                                                         $PROGRAM_NAME, ($main::VERSION || ''), ($main::DISTRIB || ''),
878                                                         ($main::SVN_REV || ''), __LINE__);
879                                                      print('# Arguments: ',
880                                                         join(' ', map { my $a = "_[$_]_"; $a =~ s/\n/\n# /g; $a; } @ARGV), "\n");
881                                                   }
882                                                   
883                                                   # Reads a configuration file and returns it as a list.  Inspired by
884                                                   # Config::Tiny.
885                                                   sub _read_config_file {
886           38                   38           222      my ( $self, $filename ) = @_;
887           38    100                         324      open my $fh, "<", $filename or die "Cannot open $filename: $OS_ERROR\n";
888            6                                 23      my @args;
889            6                                 19      my $prefix = '--';
890            6                                 20      my $parse  = 1;
891                                                   
892                                                      LINE:
893            6                              12266      while ( my $line = <$fh> ) {
894           24                                 83         chomp $line;
895                                                         # Skip comments and empty lines
896           24    100                         190         next LINE if $line =~ m/^\s*(?:\#|\;|$)/;
897                                                         # Remove inline comments
898           20                                 79         $line =~ s/\s+#.*$//g;
899                                                         # Remove whitespace
900           20                                141         $line =~ s/^\s+|\s+$//g;
901                                                         # Watch for the beginning of the literal values (not to be interpreted as
902                                                         # options)
903           20    100                          95         if ( $line eq '--' ) {
904            4                                 13            $prefix = '';
905            4                                 13            $parse  = 0;
906            4                                 25            next LINE;
907                                                         }
908   ***     16    100     66                  267         if ( $parse
      ***            50                               
909                                                            && (my($opt, $arg) = $line =~ m/^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/)
910                                                         ) {
911            9                                 46            push @args, grep { defined $_ } ("$prefix$opt", $arg);
              18                                139   
912                                                         }
913                                                         elsif ( $line =~ m/./ ) {
914            7                                 60            push @args, $line;
915                                                         }
916                                                         else {
917   ***      0                                  0            die "Syntax error in file $filename at line $INPUT_LINE_NUMBER";
918                                                         }
919                                                      }
920            6                                 56      close $fh;
921            6                                 17      return @args;
922                                                   }
923                                                   
924                                                   # Reads the next paragraph from the POD after the magical regular expression is
925                                                   # found in the text.
926                                                   sub read_para_after {
927   ***      2                    2      0     10      my ( $self, $file, $regex ) = @_;
928   ***      2     50                          67      open my $fh, "<", $file or die "Can't open $file: $OS_ERROR";
929            2                                 10      local $INPUT_RECORD_SEPARATOR = '';
930            2                                  5      my $para;
931            2                                271      while ( $para = <$fh> ) {
932            6    100                          54         next unless $para =~ m/^=pod$/m;
933            2                                  8         last;
934                                                      }
935            2                                 15      while ( $para = <$fh> ) {
936            7    100                          59         next unless $para =~ m/$regex/;
937            2                                  8         last;
938                                                      }
939            2                                  9      $para = <$fh>;
940            2                                  9      chomp($para);
941   ***      2     50                          26      close $fh or die "Can't close $file: $OS_ERROR";
942            2                                  6      return $para;
943                                                   }
944                                                   
945                                                   # Returns a lightweight clone of ourself.  Currently, only the basic
946                                                   # opts are copied.  This is used for stuff like "final opts" in
947                                                   # mk-table-checksum.
948                                                   sub clone {
949   ***      1                    1      0      4      my ( $self ) = @_;
950                                                   
951                                                      # Deep-copy contents of hashrefs; do not just copy the refs. 
952            3                                 10      my %clone = map {
953            1                                  4         my $hashref  = $self->{$_};
954            3                                  8         my $val_copy = {};
955            3                                 12         foreach my $key ( keys %$hashref ) {
956            5                                 17            my $ref = ref $hashref->{$key};
957            3                                 32            $val_copy->{$key} = !$ref           ? $hashref->{$key}
958   ***      0                                  0                              : $ref eq 'HASH'  ? { %{$hashref->{$key}} }
959   ***      5      0                          45                              : $ref eq 'ARRAY' ? [ @{$hashref->{$key}} ]
      ***            50                               
                    100                               
960                                                                              : $hashref->{$key};
961                                                         }
962            3                                 15         $_ => $val_copy;
963                                                      } qw(opts short_opts defaults);
964                                                   
965                                                      # Re-assign scalar values.
966            1                                  4      foreach my $scalar ( qw(got_opts) ) {
967            1                                  5         $clone{$scalar} = $self->{$scalar};
968                                                      }
969                                                   
970            1                                  6      return bless \%clone;     
971                                                   }
972                                                   
973                                                   sub _d {
974            1                    1            17      my ($package, undef, $line) = caller 0;
975   ***      2     50                          21      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                 14   
               2                                 19   
976            1                                  9           map { defined $_ ? $_ : 'undef' }
977                                                           @_;
978            1                                  5      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
979                                                   }
980                                                   
981                                                   1;
982                                                   
983                                                   # ###########################################################################
984                                                   # End OptionParser package
985                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
45    ***     50      0     36   unless $args{$arg}
51           100      1     35   exists $args{'strict'} ? :
108   ***     50      0     11   unless open my $fh, '<', $file
130          100   2963     10   unless $para =~ /^=head1 OPTIONS/
136          100     10     11   if $para =~ /^=over/
144          100      1     10   unless $para
148          100    222     10   if (my($option) = $para =~ /^=item --(.*)/)
155          100    158     64   if ($para =~ /: /) { }
159          100      1    227   unless $attributes{$attrib}
163          100     27    130   if ($attribs{'short form'})
182          100      1    220   if $para =~ /^=item/
185          100     11    209   if (my($base_option) = $option =~ /^\[no\](.*)/)
190          100     27    193   $attribs{'short form'} ? :
             100     13    207   $attribs{'negatable'} ? :
             100      2    218   $attribs{'cumulative'} ? :
             100    139     81   $attribs{'type'} ? :
             100     49    171   $attribs{'default'} ? :
             100      6    214   $attribs{'group'} ? :
202   ***     50      0    688   unless $para
208          100      8    680   if ($para =~ /^=head1/)
212          100    222    458   if $para =~ /^=item --/
216          100      1      7   unless @specs
238          100    294     22   if (ref $opt) { }
243   ***     50      0    294   if (not $long)
249   ***     50      0    294   if exists $$self{'opts'}{$long}
252          100      5    289   if (length $long == 1)
257          100     60    234   if ($short) { }
258   ***     50      0     60   if exists $$self{'short_opts'}{$short}
267          100     16    278   $$opt{'spec'} =~ /!/ ? :
268          100      4    290   $$opt{'spec'} =~ /\+/ ? :
269          100      5    289   $$opt{'desc'} =~ /required/ ? :
281   ***     50      0    294   if ($type and $type eq 'd' and not $$self{'dp'})
288          100     96    198   if $type and $type =~ /[HhAadzm]/
293          100     65    229   if (my($def) = $$opt{'desc'} =~ /default\b(?: ([^)]+))?/)
294          100     64      1   defined $def ? :
299          100      8    286   if ($long eq 'config')
304          100      4    290   if (my($dis) = $$opt{'desc'} =~ /(disables .*)/)
319          100     10     10   if ($opt =~ /mutually exclusive|one and only one/)
324          100      5     15   if ($opt =~ /at least one|one and only one/)
329          100      6     14   if ($opt =~ /default to/)
336          100      1     19   if ($opt =~ /restricted to option groups/)
346   ***     50      0     20   unless $rule_ok
368          100      3     53   unless exists $$self{'opts'}{$long}
394          100      1      2   unless exists $$self{'opts'}{$long}
417   ***      0      0      0   exists $$self{'short_opts'}{$opt} ? :
      ***     50     77      0   exists $$self{'opts'}{$opt} ? :
423          100      8     69   if ($$opt{'is_cumulative'}) { }
442          100     15    425   $$self{'opts'}{$long}{'is_cumulative'} ? :
             100    128    440   exists $$self{'defaults'}{$long} ? :
453          100      4     54   if (@ARGV and $ARGV[0] eq '--config')
457          100     12     46   if ($self->has('config'))
466          100     32      5   if ($EVAL_ERROR)
467          100      1     31   $self->got('config') ? :
483          100      3     54   unless GetOptions map({$$_{'spec'}, sub {
	$self->_set_option(@_);
}
;} grep({$$_{'long'} ne 'config';} values %{$$self{'opts'};}))
486   ***     50      0     57   if (exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'})
487   ***      0      0      0   unless printf "%s  Ver %s Distrib %s Changeset %s\n", $$self{'program_name'}, $main::VERSION, $main::DISTRIB, $main::SVN_REV
493          100      1     56   if (@ARGV and $$self{'strict'})
500          100      3     15   if (@set > 1)
511          100      3      3   if (@set == 0)
521          100     71    495   if ($$opt{'got'}) { }
             100      3    492   elsif ($$opt{'is_required'}) { }
523          100      1     70   if (exists $$self{'disables'}{$long})
531          100      2     69   if (exists $$self{'allowed_groups'}{$long})
546          100      2      2   if $restricted_opt eq $long
547          100      1      1   if $$self{'opts'}{$restricted_opt}{'got'}
552          100      1      1   if (@restricted_opts)
554   ***     50      1      0   if (@restricted_opts == 1) { }
583          100    219    347   unless $opt and $$opt{'type'}
586          100     15    332   if ($val and $$opt{'type'} eq 'm') { }
             100     10    322   elsif ($val and $$opt{'type'} eq 'd') { }
             100      6    316   elsif ($val and $$opt{'type'} eq 'z') { }
             100     10    306   elsif ($$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h') { }
             100     61    245   elsif ($$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a') { }
590          100      7      8   if (not $suffix)
596          100     14      1   if ($suffix =~ /[smhd]/) { }
597          100      2      1   $suffix eq 'h' ? :
             100      3      3   $suffix eq 'm' ? :
             100      8      6   $suffix eq 's' ? :
615          100      4      6   if ($from_key)
626          100      5      1   if (defined $num) { }
627          100      4      1   if ($factor)
656          100     42     56   length $opt == 1 ? :
657          100      3     95   unless $long and exists $$self{'opts'}{$long}
667          100      4     50   length $opt == 1 ? :
668          100      2     52   unless $long and exists $$self{'opts'}{$long}
676          100     82     63   length $opt == 1 ? :
677          100     82     63   defined $long ? :
687          100      2      3   length $opt == 1 ? :
688          100      2      3   unless $long and exists $$self{'opts'}{$long}
720   ***     50      0     11   unless $ENV{'DONT_BREAK_LINES'}
728   ***      0      0      0   if ($$self{'opts'}{'help'}{'got'}) { }
      ***      0      0      0   elsif (scalar @{$$self{'errors'};}) { }
729   ***      0      0      0   unless print $self->print_usage
733   ***      0      0      0   unless print $self->print_errors
744   ***     50      1      0   if (my(@errors) = @{$$self{'errors'};})
760   ***     50      0     10   unless $$self{'got_opts'}
764          100      3     29   $$_{'is_negatable'} ? :
769   ***     50      0     12   $$self{'opts'}{$_}{'is_negatable'} ? :
790          100     10      4   $group eq 'default' ? :
796          100      3     29   $$opt{'is_negatable'} ? :
800          100      2     30   if ($$opt{'type'} and $$opt{'type'} eq 'm')
810          100     12     20   if ($short) { }
819          100      4      6   if (my(@rules) = @{$$self{'rules'};})
823          100      2      8   if ($$self{'dp'})
831          100      1     10   $val ? :
             100      6      1   $type =~ /A|a/ ? :
             100      2      7   $type =~ /H|h/ ? :
             100      2      9   $type eq 'd' ? :
             100     10     11   !defined($val) ? :
             100     11     21   $bool ? :
846   ***      0      0      0   if ref $_[0] eq 'OptionParser'
849   ***      0      0      0   unless print $prompt
857   ***      0      0      0   unless print "\n"
860   ***      0      0      0   if ($EVAL_ERROR)
887          100     32      6   unless open my $fh, '<', $filename
896          100      4     20   if $line =~ /^\s*(?:\#|\;|$)/
903          100      4     16   if ($line eq '--')
908          100      9      7   if ($parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/) { }
      ***     50      7      0   elsif ($line =~ /./) { }
928   ***     50      0      2   unless open my $fh, '<', $file
932          100      4      2   unless $para =~ /^=pod$/m
936          100      5      2   unless $para =~ /$regex/
941   ***     50      0      2   unless close $fh
959   ***      0      0      0   $ref eq 'ARRAY' ? :
      ***     50      3      0   $ref eq 'HASH' ? :
             100      2      3   !$ref ? :
975   ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
281          100    114    157     23   $type and $type eq 'd'
      ***     66    271     23      0   $type and $type eq 'd' and not $$self{'dp'}
288          100    114     84     96   $type and $type =~ /[HhAadzm]/
453          100     14     40      4   @ARGV and $ARGV[0] eq '--config'
486   ***     66     48      9      0   exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'}
493          100     54      2      1   @ARGV and $$self{'strict'}
583   ***     66      0    219    347   $opt and $$opt{'type'}
586          100    200    132     15   $val and $$opt{'type'} eq 'm'
             100    200    122     10   $val and $$opt{'type'} eq 'd'
             100    200    116      6   $val and $$opt{'type'} eq 'z'
             100    196    110      1   defined $val and $$opt{'type'} eq 'h'
             100    188     57     22   defined $val and $$opt{'type'} eq 'a'
657          100      1      2     95   $long and exists $$self{'opts'}{$long}
668          100      1      1     52   $long and exists $$self{'opts'}{$long}
688          100      1      1      3   $long and exists $$self{'opts'}{$long}
800          100     12     18      2   $$opt{'type'} and $$opt{'type'} eq 'm'
908   ***     66      7      0      9   $parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
29    ***     50      0      1   $ENV{'MKDEBUG'} || 0
48    ***     50     36      0   $program_name ||= $PROGRAM_NAME
49    ***     50     36      0   $ENV{'HOME'} || $ENV{'HOMEPATH'} || $ENV{'USERPROFILE'} || '.'
51           100      2     34   $args{'prompt'} || '<options>'
             100     11     25   $args{'dp'} || undef
107   ***     50     11      0   $file ||= '/home/daniel/dev/maatkit/common/OptionParser.pm'
271          100    234     60   $$opt{'group'} ||= 'default'
592          100      4      3   $s || 's'
601          100      3     11   $prefix || ''
632          100      2      3   $pre || ''
639          100      6      4   $val || ''
642          100     53      8   $val || ''
714   ***     50     11      0   $$self{'description'} || ''
802          100      1      1   $s ||= 's'
829          100     20     12   $$opt{'type'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
49    ***     33     36      0      0   $ENV{'HOME'} || $ENV{'HOMEPATH'}
      ***     33     36      0      0   $ENV{'HOME'} || $ENV{'HOMEPATH'} || $ENV{'USERPROFILE'}
586          100      9      1    306   $$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h'
             100     39     22    245   $$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a'


Covered Subroutines
-------------------

Subroutine         Count Pod Location                                           
------------------ ----- --- ---------------------------------------------------
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:22 
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:23 
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:25 
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:26 
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:27 
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:29 
__ANON__              73     /home/daniel/dev/maatkit/common/OptionParser.pm:481
_d                     1     /home/daniel/dev/maatkit/common/OptionParser.pm:974
_get_participants     27     /home/daniel/dev/maatkit/common/OptionParser.pm:365
_parse_specs          35     /home/daniel/dev/maatkit/common/OptionParser.pm:234
_pod_to_specs         11     /home/daniel/dev/maatkit/common/OptionParser.pm:106
_read_config_file     38     /home/daniel/dev/maatkit/common/OptionParser.pm:886
_set_option           77     /home/daniel/dev/maatkit/common/OptionParser.pm:416
_validate_type       566     /home/daniel/dev/maatkit/common/OptionParser.pm:582
clone                  1   0 /home/daniel/dev/maatkit/common/OptionParser.pm:949
descr                 11   0 /home/daniel/dev/maatkit/common/OptionParser.pm:713
errors                13   0 /home/daniel/dev/maatkit/common/OptionParser.pm:703
get                   98   0 /home/daniel/dev/maatkit/common/OptionParser.pm:655
get_defaults           3   0 /home/daniel/dev/maatkit/common/OptionParser.pm:403
get_defaults_files     9   0 /home/daniel/dev/maatkit/common/OptionParser.pm:90 
get_groups             1   0 /home/daniel/dev/maatkit/common/OptionParser.pm:408
get_opts              58   0 /home/daniel/dev/maatkit/common/OptionParser.pm:437
get_specs              6   0 /home/daniel/dev/maatkit/common/OptionParser.pm:82 
got                   54   0 /home/daniel/dev/maatkit/common/OptionParser.pm:666
has                  145   0 /home/daniel/dev/maatkit/common/OptionParser.pm:675
new                   36   0 /home/daniel/dev/maatkit/common/OptionParser.pm:43 
opts                   4   0 /home/daniel/dev/maatkit/common/OptionParser.pm:378
print_errors           1   0 /home/daniel/dev/maatkit/common/OptionParser.pm:742
print_usage           10   0 /home/daniel/dev/maatkit/common/OptionParser.pm:759
prompt                11   0 /home/daniel/dev/maatkit/common/OptionParser.pm:708
read_para_after        2   0 /home/daniel/dev/maatkit/common/OptionParser.pm:927
save_error            16   0 /home/daniel/dev/maatkit/common/OptionParser.pm:697
set                    5   0 /home/daniel/dev/maatkit/common/OptionParser.pm:686
set_defaults           5   0 /home/daniel/dev/maatkit/common/OptionParser.pm:391
short_opts             1   0 /home/daniel/dev/maatkit/common/OptionParser.pm:385

Uncovered Subroutines
---------------------

Subroutine         Count Pod Location                                           
------------------ ----- --- ---------------------------------------------------
prompt_noecho          0   0 /home/daniel/dev/maatkit/common/OptionParser.pm:846
usage_or_errors        0   0 /home/daniel/dev/maatkit/common/OptionParser.pm:727


OptionParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1             8   use Test::More tests => 141;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use OptionParser;
               1                                  3   
               1                                 12   
15             1                    1            13   use DSNParser;
               1                                  4   
               1                                 12   
16             1                    1            14   use MaatkitTest;
               1                                  3   
               1                                 11   
17                                                    
18             1                                  9   my $dp = new DSNParser();
19             1                                 92   my $o  = new OptionParser(
20                                                       description  => 'parses command line options.',
21                                                       prompt       => '[OPTIONS]',
22                                                       dp           => $dp,
23                                                    );
24                                                    
25             1                                  6   isa_ok($o, 'OptionParser');
26                                                    
27             1                                  6   my @opt_specs;
28             1                                  3   my %opts;
29                                                    
30                                                    # Prevent print_usage() from breaking lines in the first paragraph
31                                                    # at 80 chars width.  This paragraph contains $PROGRAM_NAME and that
32                                                    # becomes too long when this test is ran from trunk, causing a break.
33                                                    # To make this test path-independent, we don't break lines.  This only
34                                                    # affects testing.
35             1                                 10   $ENV{DONT_BREAK_LINES} = 1;
36                                                    
37                                                    # #############################################################################
38                                                    # Test basic usage.
39                                                    # #############################################################################
40                                                    
41                                                    # Quick test of standard interface.
42             1                                  9   $o->get_specs("$trunk/common/t/samples/pod_sample_01.txt");
43             1                                 10   %opts = $o->opts();
44             1                                  9   ok(
45                                                       exists $opts{help},
46                                                       'get_specs() basic interface'
47                                                    );
48                                                    
49                                                    # More exhaustive test of how the standard interface works internally.
50             1                                 11   $o  = new OptionParser(
51                                                       description  => 'parses command line options.',
52                                                       dp           => $dp,
53                                                    );
54             1                                 16   ok(!$o->has('time'), 'There is no --time yet');
55             1                                  8   @opt_specs = $o->_pod_to_specs("$trunk/common/t/samples/pod_sample_01.txt");
56             1                                 37   is_deeply(
57                                                       \@opt_specs,
58                                                       [
59                                                       { spec=>'database|D=s', group=>'default', desc=>'database string',         },
60                                                       { spec=>'port|p=i',     group=>'default', desc=>'port (default 3306)',     },
61                                                       { spec=>'price=f',    group=>'default', desc=>'price float (default 1.23)' },
62                                                       { spec=>'hash-req=H', group=>'default', desc=>'hash that requires a value' },
63                                                       { spec=>'hash-opt=h', group=>'default', desc=>'hash with an optional value'},
64                                                       { spec=>'array-req=A',group=>'default', desc=>'array that requires a value'},
65                                                       { spec=>'array-opt=a',group=>'default',desc=>'array with an optional value'},
66                                                       { spec=>'host=d',       group=>'default', desc=>'host DSN'           },
67                                                       { spec=>'chunk-size=z', group=>'default', desc=>'chunk size'         },
68                                                       { spec=>'time=m',       group=>'default', desc=>'time'               },
69                                                       { spec=>'help+',        group=>'default', desc=>'help cumulative'    },
70                                                       { spec=>'other!',       group=>'default', desc=>'other negatable'    },
71                                                       ],
72                                                       'Convert POD OPTIONS to opt specs (pod_sample_01.txt)',
73                                                    );
74                                                    
75             1                                 25   $o->_parse_specs(@opt_specs);
76             1                                 31   ok($o->has('time'), 'There is a --time now');
77             1                                  7   %opts = $o->opts();
78             1                                 77   is_deeply(
79                                                       \%opts,
80                                                       {
81                                                          'database'   => {
82                                                             spec           => 'database|D=s',
83                                                             desc           => 'database string',
84                                                             group          => 'default',
85                                                             long           => 'database',
86                                                             short          => 'D',
87                                                             is_cumulative  => 0,
88                                                             is_negatable   => 0,
89                                                             is_required    => 0,
90                                                             type           => 's',
91                                                             got            => 0,
92                                                             value          => undef,
93                                                          },
94                                                          'port'       => {
95                                                             spec           => 'port|p=i',
96                                                             desc           => 'port (default 3306)',
97                                                             group          => 'default',
98                                                             long           => 'port',
99                                                             short          => 'p',
100                                                            is_cumulative  => 0,
101                                                            is_negatable   => 0,
102                                                            is_required    => 0,
103                                                            type           => 'i',
104                                                            got            => 0,
105                                                            value          => undef,
106                                                         },
107                                                         'price'      => {
108                                                            spec           => 'price=f',
109                                                            desc           => 'price float (default 1.23)',
110                                                            group          => 'default',
111                                                            long           => 'price',
112                                                            short          => undef,
113                                                            is_cumulative  => 0,
114                                                            is_negatable   => 0,
115                                                            is_required    => 0,
116                                                            type           => 'f',
117                                                            got            => 0,
118                                                            value          => undef,
119                                                         },
120                                                         'hash-req'   => {
121                                                            spec           => 'hash-req=s',
122                                                            desc           => 'hash that requires a value',
123                                                            group          => 'default',
124                                                            long           => 'hash-req',
125                                                            short          => undef,
126                                                            is_cumulative  => 0,
127                                                            is_negatable   => 0,
128                                                            is_required    => 0,
129                                                            type           => 'H',
130                                                            got            => 0,
131                                                            value          => undef,
132                                                         },
133                                                         'hash-opt'   => {
134                                                            spec           => 'hash-opt=s',
135                                                            desc           => 'hash with an optional value',
136                                                            group          => 'default',
137                                                            long           => 'hash-opt',
138                                                            short          => undef,
139                                                            is_cumulative  => 0,
140                                                            is_negatable   => 0,
141                                                            is_required    => 0,
142                                                            type           => 'h',
143                                                            got            => 0,
144                                                            value          => undef,
145                                                         },
146                                                         'array-req'  => {
147                                                            spec           => 'array-req=s',
148                                                            desc           => 'array that requires a value',
149                                                            group          => 'default',
150                                                            long           => 'array-req',
151                                                            short          => undef,
152                                                            is_cumulative  => 0,
153                                                            is_negatable   => 0,
154                                                            is_required    => 0,
155                                                            type           => 'A',
156                                                            got            => 0,
157                                                            value          => undef,
158                                                         },
159                                                         'array-opt'  => {
160                                                            spec           => 'array-opt=s',
161                                                            desc           => 'array with an optional value',
162                                                            group          => 'default',
163                                                            long           => 'array-opt',
164                                                            short          => undef,
165                                                            is_cumulative  => 0,
166                                                            is_negatable   => 0,
167                                                            is_required    => 0,
168                                                            type           => 'a',
169                                                            got            => 0,
170                                                            value          => undef,
171                                                         },
172                                                         'host'       => {
173                                                            spec           => 'host=s',
174                                                            desc           => 'host DSN',
175                                                            group          => 'default',
176                                                            long           => 'host',
177                                                            short          => undef,
178                                                            is_cumulative  => 0,
179                                                            is_negatable   => 0,
180                                                            is_required    => 0,
181                                                            type           => 'd',
182                                                            got            => 0,
183                                                            value          => undef,
184                                                         },
185                                                         'chunk-size' => {
186                                                            spec           => 'chunk-size=s',
187                                                            desc           => 'chunk size',
188                                                            group          => 'default',
189                                                            long           => 'chunk-size',
190                                                            short          => undef,
191                                                            is_cumulative  => 0,
192                                                            is_negatable   => 0,
193                                                            is_required    => 0,
194                                                            type           => 'z',
195                                                            got            => 0,
196                                                            value          => undef,
197                                                         },
198                                                         'time'       => {
199                                                            spec           => 'time=s',
200                                                            desc           => 'time',
201                                                            group          => 'default',
202                                                            long           => 'time',
203                                                            short          => undef,
204                                                            is_cumulative  => 0,
205                                                            is_negatable   => 0,
206                                                            is_required    => 0,
207                                                            type           => 'm',
208                                                            got            => 0,
209                                                            value          => undef,
210                                                         },
211                                                         'help'       => {
212                                                            spec           => 'help+',
213                                                            desc           => 'help cumulative',
214                                                            group          => 'default',
215                                                            long           => 'help',
216                                                            short          => undef,
217                                                            is_cumulative  => 1,
218                                                            is_negatable   => 0,
219                                                            is_required    => 0,
220                                                            type           => undef,
221                                                            got            => 0,
222                                                            value          => undef,
223                                                         },
224                                                         'other'      => {
225                                                            spec           => 'other!',
226                                                            desc           => 'other negatable',
227                                                            group          => 'default',
228                                                            long           => 'other',
229                                                            short          => undef,
230                                                            is_cumulative  => 0,
231                                                            is_negatable   => 1,
232                                                            is_required    => 0,
233                                                            type           => undef,
234                                                            got            => 0,
235                                                            value          => undef,
236                                                         }
237                                                      },
238                                                      'Parse opt specs'
239                                                   );
240                                                   
241            1                                 34   %opts = $o->short_opts();
242            1                                 31   is_deeply(
243                                                      \%opts,
244                                                      {
245                                                         'D' => 'database',
246                                                         'p' => 'port',
247                                                      },
248                                                      'Short opts => log opts'
249                                                   );
250                                                   
251                                                   # get() single option
252            1                                 12   is(
253                                                      $o->get('database'),
254                                                      undef,
255                                                      'Get valueless long opt'
256                                                   );
257            1                                  5   is(
258                                                      $o->get('p'),
259                                                      undef,
260                                                      'Get valuless short opt'
261                                                   );
262            1                                  5   eval { $o->get('foo'); };
               1                                  4   
263            1                                 18   like(
264                                                      $EVAL_ERROR,
265                                                      qr/Option foo does not exist/,
266                                                      'Die trying to get() nonexistent long opt'
267                                                   );
268            1                                 11   eval { $o->get('x'); };
               1                                  5   
269            1                                  9   like(
270                                                      $EVAL_ERROR,
271                                                      qr/Option x does not exist/,
272                                                      'Die trying to get() nonexistent short opt'
273                                                   );
274                                                   
275                                                   # set()
276            1                                 10   $o->set('database', 'foodb');
277            1                                  5   is(
278                                                      $o->get('database'),
279                                                      'foodb',
280                                                      'Set long opt'
281                                                   );
282            1                                  6   $o->set('p', 12345);
283            1                                  5   is(
284                                                      $o->get('p'),
285                                                      12345,
286                                                      'Set short opt'
287                                                   );
288            1                                  4   eval { $o->set('foo', 123); };
               1                                  5   
289            1                                 10   like(
290                                                      $EVAL_ERROR,
291                                                      qr/Option foo does not exist/,
292                                                      'Die trying to set() nonexistent long opt'
293                                                   );
294            1                                  6   eval { $o->set('x', 123); };
               1                                  6   
295            1                                  9   like(
296                                                      $EVAL_ERROR,
297                                                      qr/Option x does not exist/,
298                                                      'Die trying to set() nonexistent short opt'
299                                                   );
300                                                   
301                                                   # got()
302            1                                  9   @ARGV = qw(--port 12345);
303            1                                  6   $o->get_opts();
304            1                                  6   is(
305                                                      $o->got('port'),
306                                                      1,
307                                                      'Got long opt'
308                                                   );
309            1                                  6   is(
310                                                      $o->got('p'),
311                                                      1,
312                                                      'Got short opt'
313                                                   );
314            1                                  6   is(
315                                                      $o->got('database'),
316                                                      0,
317                                                      'Did not "got" long opt'
318                                                   );
319            1                                  5   is(
320                                                      $o->got('D'),
321                                                      0,
322                                                      'Did not "got" short opt'
323                                                   );
324                                                   
325            1                                  5   eval { $o->got('foo'); };
               1                                 11   
326            1                                 10   like(
327                                                      $EVAL_ERROR,
328                                                      qr/Option foo does not exist/,
329                                                      'Die trying to got() nonexistent long opt',
330                                                   );
331            1                                  6   eval { $o->got('x'); };
               1                                  5   
332            1                                  9   like(
333                                                      $EVAL_ERROR,
334                                                      qr/Option x does not exist/,
335                                                      'Die trying to got() nonexistent short opt',
336                                                   );
337                                                   
338            1                                  8   @ARGV = qw(--bar);
339            1                                  3   eval {
340            1                                  7      local *STDERR;
341            1                                 39      open STDERR, '>', '/dev/null';
342            1                                  6      $o->get_opts();
343            1                                  5      $o->get('bar');
344                                                   };
345            1                                 10   like(
346                                                      $EVAL_ERROR,
347                                                      qr/Option bar does not exist/,
348                                                      'Ignore nonexistent opt given on cmd line'
349                                                   );
350                                                   
351            1                                  9   @ARGV = qw(--port 12345);
352            1                                  4   $o->get_opts();
353            1                                  6   is_deeply(
354                                                      $o->errors(),
355                                                      [],
356                                                      'get_opts() resets errors'
357                                                   );
358                                                   
359            1                                  9   ok(
360                                                      $o->has('D'),
361                                                      'Has short opt' 
362                                                   );
363            1                                  7   ok(
364                                                      !$o->has('X'),
365                                                      'Does not "has" nonexistent short opt'
366                                                   );
367                                                   
368                                                   # #############################################################################
369                                                   # Test hostile, broken usage.
370                                                   # #############################################################################
371            1                                  4   eval { $o->_pod_to_specs("$trunk/common/t/samples/pod_sample_02.txt"); };
               1                                  9   
372            1                                 12   like(
373                                                      $EVAL_ERROR,
374                                                      qr/POD has no OPTIONS section/,
375                                                      'Dies on POD without an OPTIONS section'
376                                                   );
377                                                   
378            1                                  6   eval { $o->_pod_to_specs("$trunk/common/t/samples/pod_sample_03.txt"); };
               1                                  7   
379            1                                 16   like(
380                                                      $EVAL_ERROR,
381                                                      qr/No valid specs in POD OPTIONS/,
382                                                      'Dies on POD with an OPTIONS section but no option items'
383                                                   );
384                                                   
385            1                                  6   eval { $o->_pod_to_specs("$trunk/common/t/samples/pod_sample_04.txt"); };
               1                                  7   
386            1                                  9   like(
387                                                      $EVAL_ERROR,
388                                                      qr/No description after option spec foo/,
389                                                      'Dies on option with no description'
390                                                   );
391                                                   
392                                                   # TODO: more hostile tests: duplicate opts, can't parse long opt from spec,
393                                                   # unrecognized rules, ...
394                                                   
395                                                   # #############################################################################
396                                                   # Test option defaults.
397                                                   # #############################################################################
398            1                                 12   $o = new OptionParser(
399                                                      description  => 'parses command line options.',
400                                                      prompt       => '[OPTIONS]',
401                                                   );
402                                                   # These are dog opt specs. They're used by other tests below.
403            1                                 28   $o->_parse_specs(
404                                                      {
405                                                         spec => 'defaultset!',
406                                                         desc => 'alignment test with a very long thing '
407                                                               . 'that is longer than 80 characters wide '
408                                                               . 'and must be wrapped'
409                                                      },
410                                                      { spec => 'defaults-file|F=s', desc => 'alignment test'  },
411                                                      { spec => 'dog|D=s',           desc => 'Dogs are fun'    },
412                                                      { spec => 'foo!',              desc => 'Foo'             },
413                                                      { spec => 'love|l+',           desc => 'And peace'       },
414                                                   );
415                                                   
416            1                                  7   is_deeply(
417                                                      $o->get_defaults(),
418                                                      {},
419                                                      'No default defaults',
420                                                   );
421                                                   
422            1                                 11   $o->set_defaults(foo => 1);
423            1                                  4   is_deeply(
424                                                      $o->get_defaults(),
425                                                      {
426                                                         foo => 1,
427                                                      },
428                                                      'set_defaults() with values'
429                                                   );
430                                                   
431            1                                  9   $o->set_defaults();
432            1                                  5   is_deeply(
433                                                      $o->get_defaults(),
434                                                      {},
435                                                      'set_defaults() without values unsets defaults'
436                                                   );
437                                                   
438                                                   # We've already tested opt spec parsing,
439                                                   # but we do it again for thoroughness.
440            1                                 11   %opts = $o->opts();
441            1                                 37   is_deeply(
442                                                      \%opts,
443                                                      {
444                                                         'foo'           => {
445                                                            spec           => 'foo!',
446                                                            desc           => 'Foo',
447                                                            group          => 'default',
448                                                            long           => 'foo',
449                                                            short          => undef,
450                                                            is_cumulative  => 0,
451                                                            is_negatable   => 1,
452                                                            is_required    => 0,
453                                                            type           => undef,
454                                                            got            => 0,
455                                                            value          => undef,
456                                                         },
457                                                         'defaultset'    => {
458                                                            spec           => 'defaultset!',
459                                                            desc           => 'alignment test with a very long thing '
460                                                                            . 'that is longer than 80 characters wide '
461                                                                            . 'and must be wrapped',
462                                                            group          => 'default',
463                                                            long           => 'defaultset',
464                                                            short          => undef,
465                                                            is_cumulative  => 0,
466                                                            is_negatable   => 1,
467                                                            is_required    => 0,
468                                                            type           => undef,
469                                                            got            => 0,
470                                                            value          => undef,
471                                                         },
472                                                         'defaults-file' => {
473                                                            spec           => 'defaults-file|F=s',
474                                                            desc           => 'alignment test',
475                                                            group          => 'default',
476                                                            long           => 'defaults-file',
477                                                            short          => 'F',
478                                                            is_cumulative  => 0,
479                                                            is_negatable   => 0,
480                                                            is_required    => 0,
481                                                            type           => 's',
482                                                            got            => 0,
483                                                            value          => undef,
484                                                         },
485                                                         'dog'           => {
486                                                            spec           => 'dog|D=s',
487                                                            desc           => 'Dogs are fun',
488                                                            group          => 'default',
489                                                            long           => 'dog',
490                                                            short          => 'D',
491                                                            is_cumulative  => 0,
492                                                            is_negatable   => 0,
493                                                            is_required    => 0,
494                                                            type           => 's',
495                                                            got            => 0,
496                                                            value          => undef,
497                                                         },
498                                                         'love'          => {
499                                                            spec           => 'love|l+',
500                                                            desc           => 'And peace',
501                                                            group          => 'default',
502                                                            long           => 'love',
503                                                            short          => 'l',
504                                                            is_cumulative  => 1,
505                                                            is_negatable   => 0,
506                                                            is_required    => 0,
507                                                            type           => undef,
508                                                            got            => 0,
509                                                            value          => undef,
510                                                         },
511                                                      },
512                                                      'Parse dog specs'
513                                                   );
514                                                   
515            1                                 17   $o->set_defaults('dog' => 'fido');
516                                                   
517            1                                  4   @ARGV = ();
518            1                                  5   $o->get_opts();
519            1                                  6   is(
520                                                      $o->get('dog'),
521                                                      'fido',
522                                                      'Opt gets default value'
523                                                   );
524            1                                  7   is(
525                                                      $o->got('dog'),
526                                                      0,
527                                                      'Did not "got" opt with default value'
528                                                   );
529                                                   
530            1                                  7   @ARGV = qw(--dog rover);
531            1                                  5   $o->get_opts();
532            1                                  5   is(
533                                                      $o->get('dog'),
534                                                      'rover',
535                                                      'Value given on cmd line overrides default value'
536                                                   );
537                                                   
538            1                                  4   eval { $o->set_defaults('bone' => 1) };
               1                                  6   
539            1                                 11   like(
540                                                      $EVAL_ERROR,
541                                                      qr/Cannot set default for nonexistent option bone/,
542                                                      'Cannot set default for nonexistent option'
543                                                   );
544                                                   
545                                                   # #############################################################################
546                                                   # Test option attributes negatable and cumulative.
547                                                   # #############################################################################
548                                                   
549                                                   # These tests use the dog opt specs from above.
550                                                   
551            1                                  9   @ARGV = qw(--nofoo);
552            1                                  6   $o->get_opts();
553            1                                  6   is(
554                                                      $o->get('foo'),
555                                                      0,
556                                                      'Can negate negatable opt like --nofoo'
557                                                   );
558                                                   
559            1                                  6   @ARGV = qw(--no-foo);
560            1                                  5   $o->get_opts();
561            1                                  5   is(
562                                                      $o->get('foo'),
563                                                      0,
564                                                      'Can negate negatable opt like --no-foo'
565                                                   );
566                                                   
567            1                                  5   @ARGV = qw(--nodog);
568                                                   {
569            1                                  3      local *STDERR;
               1                                  4   
570            1                                 37      open STDERR, '>', '/dev/null';
571            1                                  6      $o->get_opts();
572                                                   }
573                                                   is_deeply(
574            1                                 13      $o->get('dog'),
575                                                      undef,
576                                                      'Cannot negate non-negatable opt'
577                                                   );
578            1                                  9   is_deeply(
579                                                      $o->errors(),
580                                                      ['Error parsing options'],
581                                                      'Trying to negate non-negatable opt sets an error'
582                                                   );
583                                                   
584            1                                  8   @ARGV = ();
585            1                                  6   $o->get_opts();
586            1                                  5   is(
587                                                      $o->get('love'),
588                                                      0,
589                                                      'Cumulative defaults to 0 when not given'
590                                                   );
591                                                   
592            1                                  8   @ARGV = qw(--love -l -l);
593            1                                  5   $o->get_opts();
594            1                                  5   is(
595                                                      $o->get('love'),
596                                                      3,
597                                                      'Cumulative opt val increases (--love -l -l)'
598                                                   );
599            1                                  8   is(
600                                                      $o->got('love'),
601                                                      1,
602                                                      "got('love') when given multiple times short and long"
603                                                   );
604                                                   
605            1                                  5   @ARGV = qw(--love);
606            1                                  6   $o->get_opts();
607            1                                  5   is(
608                                                      $o->got('love'),
609                                                      1,
610                                                      "got('love') long once"
611                                                   );
612                                                   
613            1                                  6   @ARGV = qw(-l);
614            1                                  5   $o->get_opts();
615            1                                  5   is(
616                                                      $o->got('l'),
617                                                      1,
618                                                      "got('l') short once"
619                                                   );
620                                                   
621                                                   # #############################################################################
622                                                   # Test usage output.
623                                                   # #############################################################################
624                                                   
625                                                   # The following one test uses the dog opt specs from above.
626                                                   
627                                                   # Clear values from previous tests.
628            1                                  8   $o->set_defaults();
629            1                                  4   @ARGV = ();
630            1                                  5   $o->get_opts();
631                                                   
632            1                                  6   is(
633                                                      $o->print_usage(),
634                                                   <<EOF
635                                                   OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
636                                                   Usage: $PROGRAM_NAME [OPTIONS]
637                                                   
638                                                   Options:
639                                                   
640                                                     --defaults-file -F  alignment test
641                                                     --[no]defaultset    alignment test with a very long thing that is longer than
642                                                                         80 characters wide and must be wrapped
643                                                     --dog           -D  Dogs are fun
644                                                     --[no]foo           Foo
645                                                     --love          -l  And peace
646                                                   
647                                                   Options and values after processing arguments:
648                                                   
649                                                     --defaults-file     (No value)
650                                                     --defaultset        FALSE
651                                                     --dog               (No value)
652                                                     --foo               FALSE
653                                                     --love              0
654                                                   EOF
655                                                   ,
656                                                      'Options aligned and custom prompt included'
657                                                   );
658                                                   
659            1                                 10   $o = new OptionParser(
660                                                      description  => 'parses command line options.',
661                                                   );
662            1                                 18   $o->_parse_specs(
663                                                      { spec => 'database|D=s',    desc => 'Specify the database for all tables' },
664                                                      { spec => 'nouniquechecks!', desc => 'Set UNIQUE_CHECKS=0 before LOAD DATA INFILE' },
665                                                   );
666            1                                  6   $o->get_opts();
667            1                                  6   is(
668                                                      $o->print_usage(),
669                                                   <<EOF
670                                                   OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
671                                                   Usage: $PROGRAM_NAME <options>
672                                                   
673                                                   Options:
674                                                   
675                                                     --database        -D  Specify the database for all tables
676                                                     --[no]nouniquechecks  Set UNIQUE_CHECKS=0 before LOAD DATA INFILE
677                                                   
678                                                   Options and values after processing arguments:
679                                                   
680                                                     --database            (No value)
681                                                     --nouniquechecks      FALSE
682                                                   EOF
683                                                   ,
684                                                      'Really long option aligns with shorts, and prompt defaults to <options>'
685                                                   );
686                                                   
687                                                   # #############################################################################
688                                                   # Test _get_participants()
689                                                   # #############################################################################
690            1                                  7   $o = new OptionParser(
691                                                      description  => 'parses command line options.',
692                                                   );
693            1                                 19   $o->_parse_specs(
694                                                      { spec => 'foo',      desc => 'opt' },
695                                                      { spec => 'bar-bar!', desc => 'opt' },
696                                                      { spec => 'baz',      desc => 'opt' },
697                                                   );
698            1                                  7   is_deeply(
699                                                      [ $o->_get_participants('L<"--foo"> disables --bar-bar and C<--baz>') ],
700                                                      [qw(foo bar-bar baz)],
701                                                      'Extract option names from a string',
702                                                   );
703                                                   
704            1                                 11   is_deeply(
705                                                      [ $o->_get_participants('L<"--foo"> disables L<"--[no]bar-bar">.') ],
706                                                      [qw(foo bar-bar)],
707                                                      'Extract [no]-negatable option names from a string',
708                                                   );
709                                                   # TODO: test w/ opts that don't exist, or short opts
710                                                   
711                                                   # #############################################################################
712                                                   # Test required options.
713                                                   # #############################################################################
714            1                                 11   $o = new OptionParser(
715                                                      description  => 'parses command line options.',
716                                                      dp           => $dp,
717                                                   );
718            1                                 16   $o->_parse_specs(
719                                                      { spec => 'cat|C=s', desc => 'How to catch the cat; required' }
720                                                   );
721                                                   
722            1                                  5   @ARGV = ();
723            1                                  5   $o->get_opts();
724            1                                  5   is_deeply(
725                                                      $o->errors(),
726                                                      ['Required option --cat must be specified'],
727                                                      'Missing required option sets an error',
728                                                   );
729                                                   
730            1                                 10   is(
731                                                      $o->print_errors(),
732                                                   "Usage: $PROGRAM_NAME <options>
733                                                   
734                                                   Errors in command-line arguments:
735                                                     * Required option --cat must be specified
736                                                   
737                                                   OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.",
738                                                      'Error output includes note about missing required option'
739                                                   );
740                                                   
741            1                                  6   @ARGV = qw(--cat net);
742            1                                  6   $o->get_opts();
743            1                                  6   is(
744                                                      $o->get('cat'),
745                                                      'net',
746                                                      'Required option OK',
747                                                   );
748                                                   
749                                                   # #############################################################################
750                                                   # Test option rules.
751                                                   # #############################################################################
752            1                                  8   $o = new OptionParser(
753                                                      description  => 'parses command line options.',
754                                                   );
755            1                                 17   $o->_parse_specs(
756                                                      { spec => 'ignore|i',  desc => 'Use IGNORE for INSERT statements'         },
757                                                      { spec => 'replace|r', desc => 'Use REPLACE instead of INSERT statements' },
758                                                      '--ignore and --replace are mutually exclusive.',
759                                                   );
760                                                   
761            1                                  5   $o->get_opts();
762            1                                  6   is(
763                                                      $o->print_usage(),
764                                                   <<EOF
765                                                   OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
766                                                   Usage: $PROGRAM_NAME <options>
767                                                   
768                                                   Options:
769                                                   
770                                                     --ignore  -i  Use IGNORE for INSERT statements
771                                                     --replace -r  Use REPLACE instead of INSERT statements
772                                                   
773                                                   Rules:
774                                                   
775                                                     --ignore and --replace are mutually exclusive.
776                                                   
777                                                   Options and values after processing arguments:
778                                                   
779                                                     --ignore      FALSE
780                                                     --replace     FALSE
781                                                   EOF
782                                                   ,
783                                                      'Usage with rules'
784                                                   );
785                                                   
786            1                                  6   @ARGV = qw(--replace);
787            1                                  5   $o->get_opts();
788            1                                  6   is_deeply(
789                                                      $o->errors(),
790                                                      [],
791                                                      '--replace does not trigger an error',
792                                                   );
793                                                   
794            1                                  9   @ARGV = qw(--ignore --replace);
795            1                                  5   $o->get_opts();
796            1                                  5   is_deeply(
797                                                      $o->errors(),
798                                                      ['--ignore and --replace are mutually exclusive.'],
799                                                      'Error set when rule violated',
800                                                   );
801                                                   
802                                                   # These are used several times in the follow tests.
803            1                                 15   my @ird_specs = (
804                                                      { spec => 'ignore|i',   desc => 'Use IGNORE for INSERT statements'         },
805                                                      { spec => 'replace|r',  desc => 'Use REPLACE instead of INSERT statements' },
806                                                      { spec => 'delete|d',   desc => 'Delete'                                   },
807                                                   );
808                                                   
809            1                                 12   $o = new OptionParser(
810                                                      description  => 'parses command line options.',
811                                                   );
812            1                                 17   $o->_parse_specs(
813                                                      @ird_specs,
814                                                      '--ignore, --replace and --delete are mutually exclusive.',
815                                                   );
816            1                                  4   @ARGV = qw(--ignore --replace);
817            1                                  5   $o->get_opts();
818            1                                  5   is_deeply(
819                                                      $o->errors(),
820                                                      ['--ignore, --replace and --delete are mutually exclusive.'],
821                                                      'Error set with long opt name and nice commas when rule violated',
822                                                   );
823                                                   
824            1                                 11   $o = new OptionParser(
825                                                      description  => 'parses command line options.',
826                                                   );
827            1                                 11   eval {
828            1                                  6      $o->_parse_specs(
829                                                         @ird_specs,
830                                                        'Use one and only one of --insert, --replace, or --delete.',
831                                                      );
832                                                   };
833            1                                 11   like(
834                                                      $EVAL_ERROR,
835                                                      qr/Option --insert does not exist/,
836                                                      'Die on using nonexistent option in one-and-only-one rule'
837                                                   );
838                                                   
839            1                                  9   $o = new OptionParser(
840                                                      description  => 'parses command line options.',
841                                                   );
842            1                                 13   $o->_parse_specs(
843                                                      @ird_specs,
844                                                      'Use one and only one of --ignore, --replace, or --delete.',
845                                                   );
846            1                                  5   @ARGV = qw(--ignore --replace);
847            1                                  5   $o->get_opts();
848            1                                  5   is_deeply(
849                                                      $o->errors(),
850                                                      ['--ignore, --replace and --delete are mutually exclusive.'],
851                                                      'Error set with one-and-only-one rule violated',
852                                                   );
853                                                   
854            1                                 11   $o = new OptionParser(
855                                                      description  => 'parses command line options.',
856                                                   );
857            1                                 14   $o->_parse_specs(
858                                                      @ird_specs,
859                                                      'Use one and only one of --ignore, --replace, or --delete.',
860                                                   );
861            1                                  4   @ARGV = ();
862            1                                  5   $o->get_opts();
863            1                                  5   is_deeply(
864                                                      $o->errors(),
865                                                      ['Specify at least one of --ignore, --replace or --delete'],
866                                                      'Error set with one-and-only-one when none specified',
867                                                   );
868                                                   
869            1                                 11   $o = new OptionParser(
870                                                      description  => 'parses command line options.',
871                                                   );
872            1                                 14   $o->_parse_specs(
873                                                      @ird_specs,
874                                                      'Use at least one of --ignore, --replace, or --delete.',
875                                                   );
876            1                                  4   @ARGV = ();
877            1                                  5   $o->get_opts();
878            1                                  6   is_deeply(
879                                                      $o->errors(),
880                                                      ['Specify at least one of --ignore, --replace or --delete'],
881                                                      'Error set with at-least-one when none specified',
882                                                   );
883                                                   
884            1                                 10   $o = new OptionParser(
885                                                      description  => 'parses command line options.',
886                                                   );
887            1                                 14   $o->_parse_specs(
888                                                      @ird_specs,
889                                                      'Use at least one of --ignore, --replace, or --delete.',
890                                                   );
891            1                                  5   @ARGV = qw(-ir);
892            1                                  5   $o->get_opts();
893   ***      1            33                    6   ok(
894                                                      $o->get('ignore') == 1 && $o->get('replace') == 1,
895                                                      'Multiple options OK for at-least-one',
896                                                   );
897            1                    1             8   use Data::Dumper;
               1                                  3   
               1                                  6   
898            1                                  4   $Data::Dumper::Indent=1;
899            1                                  7   $o = new OptionParser(
900                                                      description  => 'parses command line options.',
901                                                   );
902            1                                 16   $o->_parse_specs(
903                                                      { spec => 'foo=i', desc => 'Foo disables --bar'   },
904                                                      { spec => 'bar',   desc => 'Bar (default 1)'      },
905                                                   );
906            1                                  5   @ARGV = qw(--foo 5);
907            1                                  4   $o->get_opts();
908            1                                  5   is_deeply(
909                                                      [ $o->get('foo'),  $o->get('bar') ],
910                                                      [ 5, undef ],
911                                                      '--foo disables --bar',
912                                                   );
913            1                                 11   %opts = $o->opts();
914            1                                 13   is_deeply(
915                                                      $opts{'bar'},
916                                                      {
917                                                         spec          => 'bar',
918                                                         is_required   => 0,
919                                                         value         => undef,
920                                                         is_cumulative => 0,
921                                                         short         => undef,
922                                                         group         => 'default',
923                                                         got           => 0,
924                                                         is_negatable  => 0,
925                                                         desc          => 'Bar (default 1)',
926                                                         long          => 'bar',
927                                                         type          => undef,
928                                                      },
929                                                      'Disabled opt is not destroyed'
930                                                   );
931                                                   
932                                                   # Option can't disable a nonexistent option.
933            1                                 13   $o = new OptionParser(
934                                                      description  => 'parses command line options.',
935                                                   );
936            1                                 10   eval {
937            1                                  9      $o->_parse_specs(
938                                                         { spec => 'foo=i', desc => 'Foo disables --fox' },
939                                                         { spec => 'bar',   desc => 'Bar (default 1)'    },
940                                                      );
941                                                   };
942            1                                 11   like(
943                                                      $EVAL_ERROR,
944                                                      qr/Option --fox does not exist/,
945                                                      'Invalid option name in disable rule',
946                                                   );
947                                                   
948                                                   # Option can't 'allowed with' a nonexistent option.
949            1                                 10   $o = new OptionParser(
950                                                      description  => 'parses command line options.',
951                                                      dp           => $dp,
952                                                   );
953            1                                 11   eval {
954            1                                  8      $o->_parse_specs(
955                                                         { spec => 'foo=i', desc => 'Foo disables --bar' },
956                                                         { spec => 'bar',   desc => 'Bar (default 0)'    },
957                                                         'allowed with --foo: --fox',
958                                                      );
959                                                   };
960            1                                  9   like(
961                                                      $EVAL_ERROR,
962                                                      qr/Option --fox does not exist/,
963                                                      'Invalid option name in \'allowed with\' rule',
964                                                   );
965                                                   
966                                                   # #############################################################################
967                                                   # Test default values encoded in description.
968                                                   # #############################################################################
969            1                                 10   $o = new OptionParser(
970                                                      description  => 'parses command line options.',
971                                                      dp           => $dp,
972                                                   );
973            1                                 22   $o->_parse_specs(
974                                                      { spec => 'foo=i',   desc => 'Foo (default 5)'                 },
975                                                      { spec => 'bar',     desc => 'Bar (default)'                   },
976                                                      { spec => 'price=f', desc => 'Price (default 12345.123456)'    },
977                                                      { spec => 'size=z',  desc => 'Size (default 128M)'             },
978                                                      { spec => 'time=m',  desc => 'Time (default 24h)'              },
979                                                      { spec => 'host=d',  desc => 'Host (default h=127.1,P=12345)'  },
980                                                   );
981            1                                  5   @ARGV = ();
982            1                                  5   $o->get_opts();
983            1                                  6   is(
984                                                      $o->get('foo'),
985                                                      5,
986                                                      'Default integer value encoded in description'
987                                                   );
988            1                                  7   is(
989                                                      $o->get('bar'),
990                                                      1,
991                                                      'Default option enabled encoded in description'
992                                                   );
993            1                                  6   is(
994                                                      $o->get('price'),
995                                                      12345.123456,
996                                                      'Default float value encoded in description'
997                                                   );
998            1                                  7   is(
999                                                      $o->get('size'),
1000                                                     134217728,
1001                                                     'Default size value encoded in description'
1002                                                  );
1003           1                                  7   is(
1004                                                     $o->get('time'),
1005                                                     86400,
1006                                                     'Default time value encoded in description'
1007                                                  );
1008           1                                  6   is_deeply(
1009                                                     $o->get('host'),
1010                                                     {
1011                                                        S => undef,
1012                                                        F => undef,
1013                                                        A => undef,
1014                                                        p => undef,
1015                                                        u => undef,
1016                                                        h => '127.1',
1017                                                        D => undef,
1018                                                        P => '12345'
1019                                                     },
1020                                                     'Default host value encoded in description'
1021                                                  );
1022                                                  
1023           1                                 12   is(
1024                                                     $o->got('foo'),
1025                                                     0,
1026                                                     'Did not "got" --foo with encoded default'
1027                                                  );
1028           1                                  6   is(
1029                                                     $o->got('bar'),
1030                                                     0,
1031                                                     'Did not "got" --bar with encoded default'
1032                                                  );
1033           1                                  7   is(
1034                                                     $o->got('price'),
1035                                                     0,
1036                                                     'Did not "got" --price with encoded default'
1037                                                  );
1038           1                                  7   is(
1039                                                     $o->got('size'),
1040                                                     0,
1041                                                     'Did not "got" --size with encoded default'
1042                                                  );
1043           1                                  6   is(
1044                                                     $o->got('time'),
1045                                                     0,
1046                                                     'Did not "got" --time with encoded default'
1047                                                  );
1048           1                                  6   is(
1049                                                     $o->got('host'),
1050                                                     0,
1051                                                     'Did not "got" --host with encoded default'
1052                                                  );
1053                                                  
1054                                                  # #############################################################################
1055                                                  # Test size option type.
1056                                                  # #############################################################################
1057           1                                  8   $o = new OptionParser(
1058                                                     description  => 'parses command line options.',
1059                                                  );
1060           1                                 25   $o->_parse_specs(
1061                                                     { spec => 'size=z', desc => 'size' }
1062                                                  );
1063                                                  
1064           1                                  5   @ARGV = qw(--size 5k);
1065           1                                  5   $o->get_opts();
1066           1                                  5   is_deeply(
1067                                                     $o->get('size'),
1068                                                     1024*5,
1069                                                     '5K expanded',
1070                                                  );
1071                                                  
1072           1                                 10   @ARGV = qw(--size -5k);
1073           1                                  5   $o->get_opts();
1074           1                                  5   is_deeply(
1075                                                     $o->get('size'),
1076                                                     -1024*5,
1077                                                     '-5K expanded',
1078                                                  );
1079                                                  
1080           1                                  9   @ARGV = qw(--size +5k);
1081           1                                  5   $o->get_opts();
1082           1                                  5   is_deeply(
1083                                                     $o->get('size'),
1084                                                     '+' . (1024*5),
1085                                                     '+5K expanded',
1086                                                  );
1087                                                  
1088           1                                  8   @ARGV = qw(--size 5);
1089           1                                  6   $o->get_opts();
1090           1                                  5   is_deeply(
1091                                                     $o->get('size'),
1092                                                     5,
1093                                                     '5 expanded',
1094                                                  );
1095                                                  
1096           1                                  9   @ARGV = qw(--size 5z);
1097           1                                  6   $o->get_opts();
1098           1                                  5   is_deeply(
1099                                                     $o->errors(),
1100                                                     ['Invalid size for --size'],
1101                                                     'Bad size argument sets an error',
1102                                                  );
1103                                                  
1104                                                  # #############################################################################
1105                                                  # Test time option type.
1106                                                  # #############################################################################
1107           1                                 11   $o = new OptionParser(
1108                                                     description  => 'parses command line options.',
1109                                                  );
1110           1                                 83   $o->_parse_specs(
1111                                                     { spec => 't=m', desc => 'Time'            },
1112                                                     { spec => 's=m', desc => 'Time (suffix s)' },
1113                                                     { spec => 'm=m', desc => 'Time (suffix m)' },
1114                                                     { spec => 'h=m', desc => 'Time (suffix h)' },
1115                                                     { spec => 'd=m', desc => 'Time (suffix d)' },
1116                                                  );
1117                                                  
1118           1                                  8   @ARGV = qw(-t 10 -s 20 -m 30 -h 40 -d 50);
1119           1                                  5   $o->get_opts();
1120           1                                  5   is_deeply(
1121                                                     $o->get('t'),
1122                                                     10,
1123                                                     'Time value with default suffix decoded',
1124                                                  );
1125           1                                  9   is_deeply(
1126                                                     $o->get('s'),
1127                                                     20,
1128                                                     'Time value with s suffix decoded',
1129                                                  );
1130           1                                  9   is_deeply(
1131                                                     $o->get('m'),
1132                                                     30*60,
1133                                                     'Time value with m suffix decoded',
1134                                                  );
1135           1                                  9   is_deeply(
1136                                                     $o->get('h'),
1137                                                     40*3600,
1138                                                     'Time value with h suffix decoded',
1139                                                  );
1140           1                                 10   is_deeply(
1141                                                     $o->get('d'),
1142                                                     50*86400,
1143                                                     'Time value with d suffix decoded',
1144                                                  );
1145                                                  
1146           1                                  9   @ARGV = qw(-d 5m);
1147           1                                  6   $o->get_opts();
1148           1                                  5   is_deeply(
1149                                                     $o->get('d'),
1150                                                     5*60,
1151                                                     'Explicit suffix overrides default suffix'
1152                                                  );
1153                                                  
1154                                                  # Use shorter, simpler specs to test usage for time blurb.
1155           1                                 10   $o = new OptionParser(
1156                                                     description  => 'parses command line options.',
1157                                                  );
1158           1                                 24   $o->_parse_specs(
1159                                                     { spec => 'foo=m', desc => 'Time' },
1160                                                     { spec => 'bar=m', desc => 'Time (suffix m)' },
1161                                                  );
1162           1                                  5   $o->get_opts();
1163           1                                  8   is(
1164                                                     $o->print_usage(),
1165                                                  <<EOF
1166                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1167                                                  Usage: $PROGRAM_NAME <options>
1168                                                  
1169                                                  Options:
1170                                                  
1171                                                    --bar  Time.  Optional suffix s=seconds, m=minutes, h=hours, d=days; if no
1172                                                           suffix, m is used.
1173                                                    --foo  Time.  Optional suffix s=seconds, m=minutes, h=hours, d=days; if no
1174                                                           suffix, s is used.
1175                                                  
1176                                                  Options and values after processing arguments:
1177                                                  
1178                                                    --bar  (No value)
1179                                                    --foo  (No value)
1180                                                  EOF
1181                                                  ,
1182                                                     'Usage for time value');
1183                                                  
1184           1                                  7   @ARGV = qw(--foo 5z);
1185           1                                  5   $o->get_opts();
1186           1                                  6   is_deeply(
1187                                                     $o->errors(),
1188                                                     ['Invalid time suffix for --foo'],
1189                                                     'Bad time argument sets an error',
1190                                                  );
1191                                                  
1192                                                  # #############################################################################
1193                                                  # Test DSN option type.
1194                                                  # #############################################################################
1195           1                                 11   $o = new OptionParser(
1196                                                     description  => 'parses command line options.',
1197                                                     dp           => $dp,
1198                                                  );
1199           1                                 18   $o->_parse_specs(
1200                                                     { spec => 'foo=d', desc => 'DSN foo' },
1201                                                     { spec => 'bar=d', desc => 'DSN bar' },
1202                                                     'DSN values in --foo default to values in --bar if COPY is yes.',
1203                                                  );
1204           1                                  5   $o->get_opts();
1205           1                                  6   is(
1206                                                     $o->print_usage(),
1207                                                  <<EOF
1208                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1209                                                  Usage: $PROGRAM_NAME <options>
1210                                                  
1211                                                  Options:
1212                                                  
1213                                                    --bar  DSN bar
1214                                                    --foo  DSN foo
1215                                                  
1216                                                  Rules:
1217                                                  
1218                                                    DSN values in --foo default to values in --bar if COPY is yes.
1219                                                  
1220                                                  DSN syntax is key=value[,key=value...]  Allowable DSN keys:
1221                                                  
1222                                                    KEY  COPY  MEANING
1223                                                    ===  ====  =============================================
1224                                                    A    yes   Default character set
1225                                                    D    yes   Database to use
1226                                                    F    yes   Only read default options from the given file
1227                                                    P    yes   Port number to use for connection
1228                                                    S    yes   Socket file to use for connection
1229                                                    h    yes   Connect to host
1230                                                    p    yes   Password to use when connecting
1231                                                    u    yes   User for login if not current user
1232                                                  
1233                                                    If the DSN is a bareword, the word is treated as the 'h' key.
1234                                                  
1235                                                  Options and values after processing arguments:
1236                                                  
1237                                                    --bar  (No value)
1238                                                    --foo  (No value)
1239                                                  EOF
1240                                                  ,
1241                                                     'DSN is integrated into help output'
1242                                                  );
1243                                                  
1244           1                                  6   @ARGV = ('--bar', 'D=DB,u=USER,h=localhost', '--foo', 'h=otherhost');
1245           1                                  6   $o->get_opts();
1246           1                                  6   is_deeply(
1247                                                     $o->get('bar'),
1248                                                     {
1249                                                        D => 'DB',
1250                                                        u => 'USER',
1251                                                        S => undef,
1252                                                        F => undef,
1253                                                        P => undef,
1254                                                        h => 'localhost',
1255                                                        p => undef,
1256                                                        A => undef,
1257                                                     },
1258                                                     'DSN parsing on type=d',
1259                                                  );
1260           1                                 11   is_deeply(
1261                                                     $o->get('foo'),
1262                                                     {
1263                                                        D => 'DB',
1264                                                        u => 'USER',
1265                                                        S => undef,
1266                                                        F => undef,
1267                                                        P => undef,
1268                                                        h => 'otherhost',
1269                                                        p => undef,
1270                                                        A => undef,
1271                                                     },
1272                                                     'DSN parsing on type=d inheriting from --bar',
1273                                                  );
1274                                                  
1275           1                                 12   is(
1276                                                     $o->print_usage(),
1277                                                  <<EOF
1278                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1279                                                  Usage: $PROGRAM_NAME <options>
1280                                                  
1281                                                  Options:
1282                                                  
1283                                                    --bar  DSN bar
1284                                                    --foo  DSN foo
1285                                                  
1286                                                  Rules:
1287                                                  
1288                                                    DSN values in --foo default to values in --bar if COPY is yes.
1289                                                  
1290                                                  DSN syntax is key=value[,key=value...]  Allowable DSN keys:
1291                                                  
1292                                                    KEY  COPY  MEANING
1293                                                    ===  ====  =============================================
1294                                                    A    yes   Default character set
1295                                                    D    yes   Database to use
1296                                                    F    yes   Only read default options from the given file
1297                                                    P    yes   Port number to use for connection
1298                                                    S    yes   Socket file to use for connection
1299                                                    h    yes   Connect to host
1300                                                    p    yes   Password to use when connecting
1301                                                    u    yes   User for login if not current user
1302                                                  
1303                                                    If the DSN is a bareword, the word is treated as the 'h' key.
1304                                                  
1305                                                  Options and values after processing arguments:
1306                                                  
1307                                                    --bar  D=DB,h=localhost,u=USER
1308                                                    --foo  D=DB,h=otherhost,u=USER
1309                                                  EOF
1310                                                  ,
1311                                                     'DSN stringified with inheritance into post-processed args'
1312                                                  );
1313                                                  
1314           1                                  8   $o = new OptionParser(
1315                                                     description  => 'parses command line options.',
1316                                                     dp           => $dp,
1317                                                  );
1318           1                                 22   $o->_parse_specs(
1319                                                     { spec => 'foo|f=d', desc => 'DSN foo' },
1320                                                     { spec => 'bar|b=d', desc => 'DSN bar' },
1321                                                     'DSN values in --foo default to values in --bar if COPY is yes.',
1322                                                  );
1323           1                                  5   @ARGV = ('-b', 'D=DB,u=USER,h=localhost', '-f', 'h=otherhost');
1324           1                                  6   $o->get_opts();
1325           1                                  5   is_deeply(
1326                                                     $o->get('f'),
1327                                                     {
1328                                                        D => 'DB',
1329                                                        u => 'USER',
1330                                                        S => undef,
1331                                                        F => undef,
1332                                                        P => undef,
1333                                                        h => 'otherhost',
1334                                                        p => undef,
1335                                                        A => undef,
1336                                                     },
1337                                                     'DSN parsing on type=d inheriting from --bar with short options',
1338                                                  );
1339                                                  
1340                                                  # #############################################################################
1341                                                  # Test [Hh]ash and [Aa]rray option types.
1342                                                  # #############################################################################
1343           1                                 12   $o = new OptionParser(
1344                                                     description  => 'parses command line options.',
1345                                                  );
1346           1                                 25   $o->_parse_specs(
1347                                                     { spec => 'columns|C=H',   desc => 'cols required'       },
1348                                                     { spec => 'tables|t=h',    desc => 'tables optional'     },
1349                                                     { spec => 'databases|d=A', desc => 'databases required'  },
1350                                                     { spec => 'books|b=a',     desc => 'books optional'      },
1351                                                     { spec => 'foo=A',         desc => 'foo (default a,b,c)' },
1352                                                  );
1353                                                  
1354           1                                  4   @ARGV = ();
1355           1                                  5   $o->get_opts();
1356           1                                  6   is_deeply(
1357                                                     $o->get('C'),
1358                                                     {},
1359                                                     'required Hash'
1360                                                  );
1361           1                                 11   is_deeply(
1362                                                     $o->get('t'),
1363                                                     undef,
1364                                                     'optional hash'
1365                                                  );
1366           1                                  8   is_deeply(
1367                                                     $o->get('d'),
1368                                                     [],
1369                                                     'required Array'
1370                                                  );
1371           1                                 10   is_deeply(
1372                                                     $o->get('b'),
1373                                                     undef,
1374                                                     'optional array'
1375                                                  );
1376           1                                  8   is_deeply($o->get('foo'), [qw(a b c)], 'Array got a default');
1377                                                  
1378           1                                 11   @ARGV = ('-C', 'a,b', '-t', 'd,e', '-d', 'f,g', '-b', 'o,p' );
1379           1                                  6   $o->get_opts();
1380           1                                  6   %opts = (
1381                                                     C => $o->get('C'),
1382                                                     t => $o->get('t'),
1383                                                     d => $o->get('d'),
1384                                                     b => $o->get('b'),
1385                                                  );
1386           1                                 19   is_deeply(
1387                                                     \%opts,
1388                                                     {
1389                                                        C => { a => 1, b => 1 },
1390                                                        t => { d => 1, e => 1 },
1391                                                        d => [qw(f g)],
1392                                                        b => [qw(o p)],
1393                                                     },
1394                                                     'Comma-separated lists: all processed when given',
1395                                                  );
1396                                                  
1397           1                                 15   is(
1398                                                     $o->print_usage(),
1399                                                  <<EOF
1400                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1401                                                  Usage: $PROGRAM_NAME <options>
1402                                                  
1403                                                  Options:
1404                                                  
1405                                                    --books     -b  books optional
1406                                                    --columns   -C  cols required
1407                                                    --databases -d  databases required
1408                                                    --foo           foo (default a,b,c)
1409                                                    --tables    -t  tables optional
1410                                                  
1411                                                  Options and values after processing arguments:
1412                                                  
1413                                                    --books         o,p
1414                                                    --columns       a,b
1415                                                    --databases     f,g
1416                                                    --foo           a,b,c
1417                                                    --tables        d,e
1418                                                  EOF
1419                                                  ,
1420                                                     'Lists properly expanded into usage information',
1421                                                  );
1422                                                  
1423                                                  # #############################################################################
1424                                                  # Test groups.
1425                                                  # #############################################################################
1426                                                  
1427           1                                  8   $o = new OptionParser(
1428                                                     description  => 'parses command line options.',
1429                                                  );
1430           1                                 22   $o->get_specs("$trunk/common/t/samples/pod_sample_05.txt");
1431                                                  
1432           1                                  7   is_deeply(
1433                                                     $o->get_groups(),
1434                                                     {
1435                                                        'Help'       => {
1436                                                           'explain-hosts' => 1,
1437                                                           'help'          => 1,
1438                                                           'version'       => 1,
1439                                                        },
1440                                                        'Filter'     => { 'databases'     => 1, },
1441                                                        'Output'     => { 'tab'           => 1, },
1442                                                        'Connection' => { 'defaults-file' => 1, },
1443                                                        'default'    => {
1444                                                           'algorithm' => 1,
1445                                                           'schema'    => 1,
1446                                                        }
1447                                                     },
1448                                                     'get_groups()'
1449                                                  );
1450                                                  
1451           1                                 11   @ARGV = ();
1452           1                                  6   $o->get_opts();
1453           1                                  6   is(
1454                                                     $o->print_usage(),
1455                                                  <<EOF
1456                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1457                                                  Usage: $PROGRAM_NAME <options>
1458                                                  
1459                                                  Options:
1460                                                  
1461                                                    --algorithm         Checksum algorithm (ACCUM|CHECKSUM|BIT_XOR)
1462                                                    --schema            Checksum SHOW CREATE TABLE intead of table data
1463                                                  
1464                                                  Connection:
1465                                                  
1466                                                    --defaults-file -F  Only read mysql options from the given file
1467                                                  
1468                                                  Filter:
1469                                                  
1470                                                    --databases     -d  Only checksum this comma-separated list of databases
1471                                                  
1472                                                  Help:
1473                                                  
1474                                                    --explain-hosts     Explain hosts
1475                                                    --help              Show help and exit
1476                                                    --version           Show version and exit
1477                                                  
1478                                                  Output:
1479                                                  
1480                                                    --tab               Print tab-separated output, not column-aligned output
1481                                                  
1482                                                  Rules:
1483                                                  
1484                                                    --schema is restricted to option groups Connection, Filter, Output, Help.
1485                                                  
1486                                                  Options and values after processing arguments:
1487                                                  
1488                                                    --algorithm         (No value)
1489                                                    --databases         (No value)
1490                                                    --defaults-file     (No value)
1491                                                    --explain-hosts     FALSE
1492                                                    --help              FALSE
1493                                                    --schema            FALSE
1494                                                    --tab               FALSE
1495                                                    --version           FALSE
1496                                                  EOF
1497                                                  ,
1498                                                     'Option groupings usage',
1499                                                  );
1500                                                  
1501           1                                  6   @ARGV = qw(--schema --tab);
1502           1                                  5   $o->get_opts();
1503  ***      1            33                    5   ok(
1504                                                     $o->get('schema') && $o->get('tab'),
1505                                                     'Opt allowed with opt from allowed group'
1506                                                  );
1507                                                  
1508           1                                  7   @ARGV = qw(--schema --algorithm ACCUM);
1509           1                                  7   $o->get_opts();
1510           1                                 11   is_deeply(
1511                                                     $o->errors(),
1512                                                     ['--schema is not allowed with --algorithm'],
1513                                                     'Opt is not allowed with opt from restricted group'
1514                                                  );
1515                                                  
1516                                                  # #############################################################################
1517                                                  # Test clone().
1518                                                  # #############################################################################
1519           1                                 14   $o = new OptionParser(
1520                                                     description  => 'parses command line options.',
1521                                                  );
1522           1                                 39   $o->_parse_specs(
1523                                                     { spec  => 'user=s', desc  => 'User',                         },
1524                                                     { spec  => 'dog|d',    desc  => 'dog option', group => 'Dogs',  },
1525                                                     { spec  => 'cat|c',    desc  => 'cat option', group => 'Cats',  },
1526                                                  );
1527           1                                  5   @ARGV = qw(--user foo --dog);
1528           1                                  5   $o->get_opts();
1529                                                  
1530           1                                  6   my $o_clone = $o->clone();
1531           1                                 12   isa_ok(
1532                                                     $o_clone,
1533                                                     'OptionParser'
1534                                                  );
1535  ***      1            33                    9   ok(
      ***                   33                        
1536                                                     $o_clone->has('user') && $o_clone->has('dog') && $o_clone->has('cat'),
1537                                                     'Clone has same opts'
1538                                                  );
1539                                                  
1540           1                                  8   $o_clone->set('user', 'Bob');
1541           1                                  5   is(
1542                                                     $o->get('user'),
1543                                                     'foo',
1544                                                     'Change to clone does not change original'
1545                                                  );
1546                                                  
1547                                                  # #############################################################################
1548                                                  # Test issues. Any other tests should find their proper place above.
1549                                                  # #############################################################################
1550                                                  
1551                                                  # #############################################################################
1552                                                  # Issue 140: Check that new style =item --[no]foo works like old style:
1553                                                  #    =item --foo
1554                                                  #    negatable: yes
1555                                                  # #############################################################################
1556           1                                  9   @opt_specs = $o->_pod_to_specs("$trunk/common/t/samples/pod_sample_issue_140.txt");
1557           1                                 43   is_deeply(
1558                                                     \@opt_specs,
1559                                                     [
1560                                                        { spec => 'foo',   desc => 'Basic foo',         group => 'default' },
1561                                                        { spec => 'bar!',  desc => 'New negatable bar', group => 'default' },
1562                                                     ],
1563                                                     'New =item --[no]foo style for negatables'
1564                                                  );
1565                                                  
1566                                                  # #############################################################################
1567                                                  # Issue 92: extract a paragraph from POD.
1568                                                  # #############################################################################
1569           1                                 20   is(
1570                                                     $o->read_para_after("$trunk/common/t/samples/pod_sample_issue_92.txt", qr/magic/),
1571                                                     'This is the paragraph, hooray',
1572                                                     'read_para_after'
1573                                                  );
1574                                                  
1575                                                  # The first time I wrote this, I used the /o flag to the regex, which means you
1576                                                  # always get the same thing on each subsequent call no matter what regex you
1577                                                  # pass in.  This is to test and make sure I don't do that again.
1578           1                                 14   is(
1579                                                     $o->read_para_after("$trunk/common/t/samples/pod_sample_issue_92.txt", qr/abracadabra/),
1580                                                     'This is the next paragraph, hooray',
1581                                                     'read_para_after again'
1582                                                  );
1583                                                  
1584                                                  # #############################################################################
1585                                                  # Issue 231: read configuration files
1586                                                  # #############################################################################
1587           1                                 12   is_deeply(
1588                                                     [$o->_read_config_file("$trunk/common/t/samples/config_file_1.conf")],
1589                                                     ['--foo', 'bar', '--verbose', '/path/to/file', 'h=127.1,P=12346'],
1590                                                     'Reads a config file',
1591                                                  );
1592                                                  
1593           1                                 17   $o = new OptionParser(
1594                                                     description  => 'parses command line options.',
1595                                                  );
1596           1                                 29   $o->_parse_specs(
1597                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1598                                                              . 'files (must be the first option on the command line).',  },
1599                                                     { spec  => 'cat=A',    desc  => 'cat option (default a,b)',  },
1600                                                  );
1601                                                  
1602           1                                  6   is_deeply(
1603                                                     [$o->get_defaults_files()],
1604                                                     ["/etc/maatkit/maatkit.conf", "/etc/maatkit/OptionParser.t.conf",
1605                                                        "$ENV{HOME}/.maatkit.conf", "$ENV{HOME}/.OptionParser.t.conf"],
1606                                                     "default options files",
1607                                                  );
1608           1                                 12   ok(!$o->got('config'), 'Did not got --config');
1609                                                  
1610           1                                 11   $o = new OptionParser(
1611                                                     description  => 'parses command line options.',
1612                                                  );
1613           1                                 18   $o->_parse_specs(
1614                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1615                                                              . 'files (must be the first option on the command line).',  },
1616                                                     { spec  => 'cat=A',    desc  => 'cat option (default a,b)',  },
1617                                                  );
1618                                                  
1619           1                                  6   $o->get_opts();
1620           1                                  7   is(
1621                                                     $o->print_usage(),
1622                                                  <<EOF
1623                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1624                                                  Usage: $PROGRAM_NAME <options>
1625                                                  
1626                                                  Options:
1627                                                  
1628                                                    --cat     cat option (default a,b)
1629                                                    --config  Read this comma-separated list of config files (must be the first
1630                                                              option on the command line).
1631                                                  
1632                                                  Options and values after processing arguments:
1633                                                  
1634                                                    --cat     a,b
1635                                                    --config  /etc/maatkit/maatkit.conf,/etc/maatkit/OptionParser.t.conf,$ENV{HOME}/.maatkit.conf,$ENV{HOME}/.OptionParser.t.conf
1636                                                  EOF
1637                                                  ,
1638                                                     'Sets special config file default value',
1639                                                  );
1640                                                  
1641           1                                  6   @ARGV=qw(--config /path/to/config --cat);
1642           1                                  9   $o = new OptionParser(
1643                                                     description  => 'parses command line options.',
1644                                                  );
1645                                                  
1646           1                                 23   $o->_parse_specs(
1647                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1648                                                              . 'files (must be the first option on the command line).',  },
1649                                                     { spec  => 'cat',     desc  => 'cat option',  },
1650                                                  );
1651           1                                  3   eval { $o->get_opts(); };
               1                                  5   
1652           1                                 13   like($EVAL_ERROR, qr/Cannot open/, 'No config file found');
1653                                                  
1654           1                                 13   @ARGV = ('--config',"$trunk/common/t/samples/empty",'--cat');
1655           1                                  8   $o->get_opts();
1656           1                                  6   ok($o->got('config'), 'Got --config');
1657                                                  
1658           1                                  7   is(
1659                                                     $o->print_usage(),
1660                                                  <<EOF
1661                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1662                                                  Usage: $PROGRAM_NAME <options>
1663                                                  
1664                                                  Options:
1665                                                  
1666                                                    --cat     cat option
1667                                                    --config  Read this comma-separated list of config files (must be the first
1668                                                              option on the command line).
1669                                                  
1670                                                  Options and values after processing arguments:
1671                                                  
1672                                                    --cat     TRUE
1673                                                    --config  $trunk/common/t/samples/empty
1674                                                  EOF
1675                                                  ,
1676                                                     'Parses special --config option first',
1677                                                  );
1678                                                  
1679           1                                 10   $o = new OptionParser(
1680                                                     description  => 'parses command line options.',
1681                                                  );
1682           1                                 20   $o->_parse_specs(
1683                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1684                                                        . 'files (must be the first option on the command line).',  },
1685                                                     { spec  => 'cat',     desc  => 'cat option',  },
1686                                                  );
1687                                                  
1688           1                                  5   @ARGV=qw(--cat --config /path/to/config);
1689                                                  {
1690           1                                  3      local *STDERR;
               1                                  4   
1691           1                                 31      open STDERR, '>', '/dev/null';
1692           1                                  5      $o->get_opts();
1693                                                  }
1694                                                  is_deeply(
1695           1                                 14      $o->errors(),
1696                                                     ['Error parsing options', 'Unrecognized command-line options /path/to/config'],
1697                                                     'special --config option not given first',
1698                                                  );
1699                                                  
1700                                                  # And now we can actually get it to read a config file into the options!
1701           1                                 14   $o = new OptionParser(
1702                                                     description  => 'parses command line options.',
1703                                                     strict       => 0,
1704                                                  );
1705           1                                 22   $o->_parse_specs(
1706                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1707                                                        . 'files (must be the first option on the command line).',  },
1708                                                     { spec  => 'foo=s',     desc  => 'foo option',  },
1709                                                     { spec  => 'verbose+',  desc  => 'increase verbosity',  },
1710                                                  );
1711           1                                  6   is($o->{strict}, 0, 'setting strict to 0 worked');
1712                                                  
1713           1                                  8   @ARGV = ('--config', "$trunk/common/t/samples/config_file_1.conf");
1714           1                                  6   $o->get_opts();
1715           1                                  8   is_deeply(
1716                                                     [@ARGV],
1717                                                     ['/path/to/file', 'h=127.1,P=12346'],
1718                                                     'Config file influences @ARGV',
1719                                                  );
1720           1                                 12   ok($o->got('foo'), 'Got --foo');
1721           1                                  7   is($o->get('foo'), 'bar', 'Got --foo value');
1722           1                                  7   ok($o->got('verbose'), 'Got --verbose');
1723           1                                  6   is($o->get('verbose'), 1, 'Got --verbose value');
1724                                                  
1725           1                                 10   @ARGV = ('--config', "$trunk/common/t/samples/config_file_1.conf,$trunk/common/t/samples/config_file_2.conf");
1726           1                                  5   $o->get_opts();
1727           1                                  8   is_deeply(
1728                                                     [@ARGV],
1729                                                     ['/path/to/file', 'h=127.1,P=12346', '/path/to/file'],
1730                                                     'Second config file influences @ARGV',
1731                                                  );
1732           1                                 12   ok($o->got('foo'), 'Got --foo again');
1733           1                                  6   is($o->get('foo'), 'baz', 'Got overridden --foo value');
1734           1                                  9   ok($o->got('verbose'), 'Got --verbose twice');
1735           1                                  7   is($o->get('verbose'), 2, 'Got --verbose value twice');
1736                                                  
1737                                                  # #############################################################################
1738                                                  # Issue 409: OptionParser modifies second value of
1739                                                  # ' -- .*','(\w+): ([^,]+)' for array type opt
1740                                                  # #############################################################################
1741           1                                 10   $o = new OptionParser(
1742                                                     description  => 'parses command line options.',
1743                                                  );
1744           1                                 21   $o->_parse_specs(
1745                                                     { spec => 'foo=a', desc => 'foo' },
1746                                                  );
1747           1                                  6   @ARGV = ('--foo', ' -- .*,(\w+): ([^\,]+)');
1748           1                                  5   $o->get_opts();
1749           1                                  6   is_deeply(
1750                                                     $o->get('foo'),
1751                                                     [
1752                                                        ' -- .*',
1753                                                        '(\w+): ([^\,]+)',
1754                                                     ],
1755                                                     'Array of vals with internal commas (issue 409)'
1756                                                  );
1757                                                  
1758                                                  # #############################################################################
1759                                                  # Issue 349: Make OptionParser die on unrecognized attributes
1760                                                  # #############################################################################
1761           1                                 10   $o = new OptionParser(
1762                                                     description  => 'parses command line options.',
1763                                                  );
1764           1                                 11   eval { $o->get_specs("$trunk/common/t/samples/pod_sample_06.txt"); };
               1                                  7   
1765           1                                 13   like(
1766                                                     $EVAL_ERROR,
1767                                                     qr/Unrecognized attribute for --verbose: culumative/,
1768                                                     'Die on unrecognized attribute'
1769                                                  );
1770                                                  
1771                                                  
1772                                                  # #############################################################################
1773                                                  # Issue 460: mk-archiver does not inherit DSN as documented
1774                                                  # #############################################################################
1775                                                  
1776                                                  # The problem is actually in how OptionParser handles copying DSN vals.
1777           1                                 13   $o = new OptionParser(
1778                                                     description  => 'parses command line options.',
1779                                                     dp           => $dp,
1780                                                  );
1781           1                                 15   $o->_parse_specs(
1782                                                     { spec  => 'source=d',   desc  => 'source',   },
1783                                                     { spec  => 'dest=d',     desc  => 'dest',     },
1784                                                     'DSN values in --dest default to values from --source if COPY is yes.',
1785                                                  );
1786           1                                  6   @ARGV = (
1787                                                     '--source', 'h=127.1,P=12345,D=test,u=bob,p=foo',
1788                                                     '--dest', 'P=12346',
1789                                                  );
1790           1                                  5   $o->get_opts();
1791           1                                  5   my $dest_dsn = $o->get('dest');
1792           1                                 19   is_deeply(
1793                                                     $dest_dsn,
1794                                                     {
1795                                                        A => undef,
1796                                                        D => 'test',
1797                                                        F => undef,
1798                                                        P => '12346',
1799                                                        S => undef,
1800                                                        h => '127.1',
1801                                                        p => 'foo',
1802                                                        u => 'bob',
1803                                                     },
1804                                                     'Copies DSN values correctly (issue 460)'
1805                                                  );
1806                                                  
1807                                                  # #############################################################################
1808                                                  # Issue 248: Add --user, --pass, --host, etc to all tools
1809                                                  # #############################################################################
1810                                                  
1811                                                  # See the 5 cases (i.-v.) at http://groups.google.com/group/maatkit-discuss/browse_thread/thread/f4bf1e659c60f03e
1812                                                  
1813                                                  # case ii.
1814           1                                 22   $o = new OptionParser(
1815                                                     description  => 'parses command line options.',
1816                                                     dp           => $dp,
1817                                                  );
1818           1                                 31   $o->get_specs("$trunk/mk-archiver/mk-archiver");
1819           1                                 13   @ARGV = (
1820                                                     '--source',    'h=127.1,S=/tmp/mysql.socket',
1821                                                     '--port',      '12345',
1822                                                     '--user',      'bob',
1823                                                     '--password',  'foo',
1824                                                     '--socket',    '/tmp/bad.socket',  # should *not* override DSN
1825                                                     '--where',     '1=1',   # required
1826                                                  );
1827           1                                 10   $o->get_opts();
1828           1                                  9   my $src_dsn = $o->get('source');
1829           1                                 21   is_deeply(
1830                                                     $src_dsn,
1831                                                     {
1832                                                        A => undef,
1833                                                        D => undef,
1834                                                        F => undef,
1835                                                        P => '12345',
1836                                                        S => '/tmp/mysql.socket',
1837                                                        h => '127.1',
1838                                                        p => 'foo',
1839                                                        u => 'bob',
1840                                                     },
1841                                                     'DSN opt gets missing vals from --host, --port, etc. (issue 248)',
1842                                                  );
1843                                                  
1844                                                  # Like case ii. but make sure --dest copies u from --source, not --user.
1845           1                                 22   @ARGV = (
1846                                                     '--source',    'h=127.1,u=bob',
1847                                                     '--dest',      'h=127.1',
1848                                                     '--user',      'wrong_user',
1849                                                     '--where',     '1=1',   # required
1850                                                  );
1851           1                                 11   $o->get_opts();
1852           1                                  8   $dest_dsn = $o->get('dest');
1853           1                                 22   is_deeply(
1854                                                     $dest_dsn,
1855                                                     {
1856                                                        A => undef,
1857                                                        D => undef,
1858                                                        F => undef,
1859                                                        P => undef,
1860                                                        S => undef,
1861                                                        h => '127.1',
1862                                                        p => undef,
1863                                                        u => 'bob',
1864                                                     },
1865                                                     'Vals from "defaults to" DSN take precedence over defaults (issue 248)'
1866                                                  );
1867                                                  
1868                                                  
1869                                                  # #############################################################################
1870                                                  #  Issue 617: Command line options do no override config file options
1871                                                  # #############################################################################
1872           1                               8037   diag(`echo "iterations=4" > ~/.OptionParser.t.conf`);
1873           1                                251   $o = new OptionParser(
1874                                                     description  => 'parses command line options.',
1875                                                     dp           => $dp,
1876                                                  );
1877           1                                540   $o->get_specs("$trunk/mk-query-digest/mk-query-digest");
1878           1                                 14   @ARGV = (qw(--iterations 9));
1879           1                                 23   $o->get_opts();
1880           1                                 17   is(
1881                                                     $o->get('iterations'),
1882                                                     9,
1883                                                     'Cmd line opt overrides conf (issue 617)'
1884                                                  );
1885           1                              10928   diag(`rm -rf ~/.OptionParser.t.conf`);
1886                                                  
1887                                                  # #############################################################################
1888                                                  #  Issue 623: --since +N does not work in mk-parallel-dump
1889                                                  # #############################################################################
1890                                                  
1891                                                  # time type opts need to allow leading +/-
1892           1                                253   $o = new OptionParser(
1893                                                     description  => 'parses command line options.',
1894                                                     dp           => $dp,
1895                                                  );
1896           1                                599   $o->get_specs("$trunk/mk-query-digest/mk-query-digest");
1897           1                                 15   @ARGV = (qw(--run-time +9));
1898           1                                 28   $o->get_opts();
1899           1                                 14   is(
1900                                                     $o->get('run-time'),
1901                                                     '+9',
1902                                                     '+N time value'
1903                                                  );
1904                                                  
1905           1                                 11   @ARGV = (qw(--run-time -7));
1906           1                                 14   $o->get_opts();
1907           1                                 14   is(
1908                                                     $o->get('run-time'),
1909                                                     '-7',
1910                                                     '-N time value'
1911                                                  );
1912                                                  
1913           1                                 15   @ARGV = (qw(--run-time +1m));
1914           1                                 10   $o->get_opts();
1915           1                                 14   is(
1916                                                     $o->get('run-time'),
1917                                                     '+60',
1918                                                     '+N time value with suffix'
1919                                                  );
1920                                                  
1921                                                  # #############################################################################
1922                                                  # Done.
1923                                                  # #############################################################################
1924           1                                  6   my $output = '';
1925                                                  {
1926           1                                  3      local *STDERR;
               1                                  7   
1927           1                    1             5      open STDERR, '>', \$output;
               1                              15783   
               1                                  4   
               1                                  9   
1928           1                                 47      $o->_d('Complete test coverage');
1929                                                  }
1930                                                  like(
1931           1                                 38      $output,
1932                                                     qr/Complete test coverage/,
1933                                                     '_d() works'
1934                                                  );
1935           1                                  4   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
893   ***     33      0      0      1   $o->get('ignore') == 1 && $o->get('replace') == 1
1503  ***     33      0      0      1   $o->get('schema') && $o->get('tab')
1535  ***     33      0      0      1   $o_clone->has('user') && $o_clone->has('dog')
      ***     33      0      0      1   $o_clone->has('user') && $o_clone->has('dog') && $o_clone->has('cat')


Covered Subroutines
-------------------

Subroutine Count Location           
---------- ----- -------------------
BEGIN          1 OptionParser.t:10  
BEGIN          1 OptionParser.t:11  
BEGIN          1 OptionParser.t:12  
BEGIN          1 OptionParser.t:14  
BEGIN          1 OptionParser.t:15  
BEGIN          1 OptionParser.t:16  
BEGIN          1 OptionParser.t:1927
BEGIN          1 OptionParser.t:4   
BEGIN          1 OptionParser.t:897 
BEGIN          1 OptionParser.t:9   


