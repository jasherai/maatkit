---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/OptionParser.pm   94.3   83.6   84.5   95.2    0.0   96.2   88.0
OptionParser.t                100.0   50.0   33.3  100.0    n/a    3.8   97.7
Total                          96.9   83.3   76.8   96.2    0.0  100.0   91.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:25 2010
Finish:       Thu Jun 24 19:35:25 2010

Run:          OptionParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:27 2010
Finish:       Thu Jun 24 19:35:28 2010

/home/daniel/dev/maatkit/common/OptionParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2010 Baron Schwartz.
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
18                                                    # OptionParser package $Revision: 6322 $
19                                                    # ###########################################################################
20                                                    package OptionParser;
21                                                    
22             1                    1             4   use strict;
               1                                  2   
               1                                  8   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24                                                    
25             1                    1            14   use Getopt::Long;
               1                                  3   
               1                                  6   
26             1                    1             7   use List::Util qw(max);
               1                                  3   
               1                                 10   
27             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
28                                                    
29    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 14   
30                                                    
31                                                    my $POD_link_re = '[LC]<"?([^">]+)"?>';
32                                                    
33                                                    sub new {
34    ***     45                   45      0    353      my ( $class, %args ) = @_;
35            45                                219      foreach my $arg ( qw(description) ) {
36    ***     45     50                         300         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38                                                    
39            45                                437      my ($program_name) = $PROGRAM_NAME =~ m/([.A-Za-z-]+)$/;
40    ***     45            50                  220      $program_name ||= $PROGRAM_NAME;
41    ***     45            33                  429      my $home = $ENV{HOME} || $ENV{HOMEPATH} || $ENV{USERPROFILE} || '.';
      ***                   33                        
      ***                   50                        
42                                                    
43                                                       # Default attributes.
44            45                                372      my %attributes = (
45                                                          'type'       => 1,
46                                                          'short form' => 1,
47                                                          'group'      => 1,
48                                                          'default'    => 1,
49                                                          'cumulative' => 1,
50                                                          'negatable'  => 1,
51                                                       );
52                                                    
53            45                               1975      my $self = {
54                                                          # default args
55                                                          strict            => 1,
56                                                          prompt            => '<options>',
57                                                          head1             => 'OPTIONS',
58                                                          skip_rules        => 0,
59                                                          item              => '--(.*)',
60                                                          attributes        => \%attributes,
61                                                          parse_attributes  => \&_parse_attribs,
62                                                    
63                                                          # override default args
64                                                          %args,
65                                                    
66                                                          # private, not configurable args
67                                                          program_name      => $program_name,
68                                                          opts              => {},
69                                                          got_opts          => 0,
70                                                          short_opts        => {},
71                                                          defaults          => {},
72                                                          groups            => {},
73                                                          allowed_groups    => {},
74                                                          errors            => [],
75                                                          rules             => [],  # desc of rules for --help
76                                                          mutex             => [],  # rule: opts are mutually exclusive
77                                                          atleast1          => [],  # rule: at least one opt is required
78                                                          disables          => {},  # rule: opt disables other opts 
79                                                          defaults_to       => {},  # rule: opt defaults to value of other opt
80                                                          DSNParser         => undef,
81                                                          default_files     => [
82                                                             "/etc/maatkit/maatkit.conf",
83                                                             "/etc/maatkit/$program_name.conf",
84                                                             "$home/.maatkit.conf",
85                                                             "$home/.$program_name.conf",
86                                                          ],
87                                                          types             => {
88                                                             string => 's', # standard Getopt type
89                                                             int    => 'i', # standard Getopt type
90                                                             float  => 'f', # standard Getopt type
91                                                             Hash   => 'H', # hash, formed from a comma-separated list
92                                                             hash   => 'h', # hash as above, but only if a value is given
93                                                             Array  => 'A', # array, similar to Hash
94                                                             array  => 'a', # array, similar to hash
95                                                             DSN    => 'd', # DSN
96                                                             size   => 'z', # size with kMG suffix (powers of 2^10)
97                                                             time   => 'm', # time, with an optional suffix of s/h/m/d
98                                                          },
99                                                       };
100                                                   
101           45                                390      return bless $self, $class;
102                                                   }
103                                                   
104                                                   # Read and parse POD OPTIONS in file or current script if
105                                                   # no file is given. This sub must be called before get_opts();
106                                                   sub get_specs {
107   ***      7                    7      0     38      my ( $self, $file ) = @_;
108   ***      7            50                   30      $file ||= __FILE__;
109            7                                 45      my @specs = $self->_pod_to_specs($file);
110            6                                132      $self->_parse_specs(@specs);
111                                                   
112                                                      # Check file for DSN OPTIONS section.  If present, parse
113                                                      # it and create a DSNParser obj.
114   ***      6     50                         216      open my $fh, "<", $file or die "Cannot open $file: $OS_ERROR";
115            6                                 19      my $contents = do { local $/ = undef; <$fh> };
               6                                 36   
               6                               2397   
116            6                                 37      close $file;
117            6    100                         443      if ( $contents =~ m/^=head1 DSN OPTIONS/m ) {
118            4                                 14         MKDEBUG && _d('Parsing DSN OPTIONS');
119            4                                 36         my $dsn_attribs = {
120                                                            dsn  => 1,
121                                                            copy => 1,
122                                                         };
123                                                         my $parse_dsn_attribs = sub {
124           40                   40           182            my ( $self, $option, $attribs ) = @_;
125           70                                232            map {
126           40                                195               my $val = $attribs->{$_};
127   ***     70     50                         334               if ( $val ) {
128           70    100                         315                  $val    = $val eq 'yes' ? 1
                    100                               
129                                                                          : $val eq 'no'  ? 0
130                                                                          :                 $val;
131           70                                451                  $attribs->{$_} = $val;
132                                                               }
133                                                            } keys %$attribs;
134                                                            return {
135           40                                515               key => $option,
136                                                               %$attribs,
137                                                            };
138            4                                 55         };
139            4                                 49         my $dsn_o = new OptionParser(
140                                                            description       => 'DSN OPTIONS',
141                                                            head1             => 'DSN OPTIONS',
142                                                            dsn               => 0,         # XXX don't infinitely recurse!
143                                                            item              => '\* (.)',  # key opts are a single character
144                                                            skip_rules        => 1,         # no rules before opts
145                                                            attributes        => $dsn_attribs,
146                                                            parse_attributes  => $parse_dsn_attribs,
147                                                         );
148           40                                428         my @dsn_opts = map {
149            4                                 23            my $opts = {
150                                                               key  => $_->{spec}->{key},
151                                                               dsn  => $_->{spec}->{dsn},
152                                                               copy => $_->{spec}->{copy},
153                                                               desc => $_->{desc},
154                                                            };
155           40                                137            $opts;
156                                                         } $dsn_o->_pod_to_specs($file);
157            4                                114         $self->{DSNParser} = DSNParser->new(opts => \@dsn_opts);
158                                                      }
159                                                   
160            6                                 20      return;
161                                                   }
162                                                   
163                                                   sub DSNParser {
164   ***      1                    1      0      4      my ( $self ) = @_;
165            1                                 10      return $self->{DSNParser};
166                                                   };
167                                                   
168                                                   # Returns the program's defaults files.
169                                                   sub get_defaults_files {
170   ***      9                    9      0     35      my ( $self ) = @_;
171            9                                 25      return @{$self->{default_files}};
               9                                 89   
172                                                   }
173                                                   
174                                                   # Parse command line options from the OPTIONS section of the POD in the
175                                                   # given file. If no file is given, the currently running program's POD
176                                                   # is parsed.
177                                                   # Returns an array of hashrefs which is usually passed to _parse_specs().
178                                                   # Each hashref in the array corresponds to one command line option from
179                                                   # the POD. Each hashref has the structure:
180                                                   #    {
181                                                   #       spec  => GetOpt::Long specification,
182                                                   #       desc  => short description for --help
183                                                   #       group => option group (default: 'default')
184                                                   #    }
185                                                   sub _pod_to_specs {
186           16                   16            80      my ( $self, $file ) = @_;
187   ***     16            50                   67      $file ||= __FILE__;
188   ***     16     50                         664      open my $fh, '<', $file or die "Cannot open $file: $OS_ERROR";
189                                                   
190           16                                 70      my @specs = ();
191           16                                 53      my @rules = ();
192           16                                 51      my $para;
193                                                   
194                                                      # Read a paragraph at a time from the file.  Skip everything until options
195                                                      # are reached...
196           16                                108      local $INPUT_RECORD_SEPARATOR = '';
197           16                              33873      while ( $para = <$fh> ) {
198         8629    100                       71056         next unless $para =~ m/^=head1 $self->{head1}/;
199           15                                 66         last;
200                                                      }
201                                                   
202                                                      # ... then read any option rules...
203           16                                126      while ( $para = <$fh> ) {
204           30    100                         177         last if $para =~ m/^=over/;
205           15    100                         100         next if $self->{skip_rules};
206           11                                 37         chomp $para;
207           11                                 87         $para =~ s/\s+/ /g;
208           11                                214         $para =~ s/$POD_link_re/$1/go;
209           11                                 30         MKDEBUG && _d('Option rule:', $para);
210           11                                 94         push @rules, $para;
211                                                      }
212                                                   
213           16    100                          80      die "POD has no $self->{head1} section" unless $para;
214                                                   
215                                                      # ... then start reading options.
216           15                                 55      do {
217          320    100                        2739         if ( my ($option) = $para =~ m/^=item $self->{item}/ ) {
218          273                                746            chomp $para;
219          273                                572            MKDEBUG && _d($para);
220          273                                632            my %attribs;
221                                                   
222          273                                969            $para = <$fh>; # read next paragraph, possibly attributes
223                                                   
224          273    100                        1043            if ( $para =~ m/: / ) { # attributes
225          209                                957               $para =~ s/\s+\Z//g;
226          315                               1443               %attribs = map {
227          209                                945                     my ( $attrib, $val) = split(/: /, $_);
228          315    100                        1573                     die "Unrecognized attribute for --$option: $attrib"
229                                                                        unless $self->{attributes}->{$attrib};
230          314                               1588                     ($attrib, $val);
231                                                                  } split(/; /, $para);
232          208    100                         928               if ( $attribs{'short form'} ) {
233           27                                130                  $attribs{'short form'} =~ s/-//;
234                                                               }
235          208                                907               $para = <$fh>; # read next paragraph, probably short help desc
236                                                            }
237                                                            else {
238           64                                167               MKDEBUG && _d('Option has no attributes');
239                                                            }
240                                                   
241                                                            # Remove extra spaces and POD formatting (L<"">).
242          272                               1589            $para =~ s/\s+\Z//g;
243          272                               1514            $para =~ s/\s+/ /g;
244          272                               1210            $para =~ s/$POD_link_re/$1/go;
245                                                   
246                                                            # Take the first period-terminated sentence as the option's short help
247                                                            # description.
248          272                               1026            $para =~ s/\.(?:\n.*| [A-Z].*|\Z)//s;
249          272                                594            MKDEBUG && _d('Short help:', $para);
250                                                   
251          272    100                        1047            die "No description after option spec $option" if $para =~ m/^=item/;
252                                                   
253                                                            # Change [no]foo to foo and set negatable attrib. See issue 140.
254          271    100                        1237            if ( my ($base_option) =  $option =~ m/^\[no\](.*)/ ) {
255           15                                 40               $option = $base_option;
256           15                                 56               $attribs{'negatable'} = 1;
257                                                            }
258                                                   
259          271    100                        1449            push @specs, {
                    100                               
260                                                               spec  => $self->{parse_attributes}->($self, $option, \%attribs), 
261                                                               desc  => $para
262                                                                  . ($attribs{default} ? " (default $attribs{default})" : ''),
263                                                               group => ($attribs{'group'} ? $attribs{'group'} : 'default'),
264                                                            };
265                                                         }
266          318                               2147         while ( $para = <$fh> ) {
267   ***    783     50                        2579            last unless $para;
268          783    100                        2838            if ( $para =~ m/^=head1/ ) {
269           12                                 40               $para = undef; # Can't 'last' out of a do {} block.
270           12                                 67               last;
271                                                            }
272          771    100                        4738            last if $para =~ m/^=item /;
273                                                         }
274                                                      } while ( $para );
275                                                   
276           13    100                          63      die "No valid specs in $self->{head1}" unless @specs;
277                                                   
278           12                                143      close $fh;
279           12                                 43      return @specs, @rules;
280                                                   }
281                                                   
282                                                   # Parse an array of option specs and rules (usually the return value of
283                                                   # _pod_to_spec()). Each option spec is parsed and the following attributes
284                                                   # pairs are added to its hashref:
285                                                   #    short         => the option's short key (-A for --charset)
286                                                   #    is_cumulative => true if the option is cumulative
287                                                   #    is_negatable  => true if the option is negatable
288                                                   #    is_required   => true if the option is required
289                                                   #    type          => the option's type, one of $self->{types}
290                                                   #    got           => true if the option was given explicitly on the cmd line
291                                                   #    value         => the option's value
292                                                   #
293                                                   sub _parse_specs {
294           40                   40           227      my ( $self, @specs ) = @_;
295           40                                125      my %disables; # special rule that requires deferred checking
296                                                   
297           40                                166      foreach my $opt ( @specs ) {
298          336    100                        1285         if ( ref $opt ) { # It's an option spec, not a rule.
299                                                            MKDEBUG && _d('Parsing opt spec:',
300          311                                680               map { ($_, '=>', $opt->{$_}) } keys %$opt);
301                                                   
302          311                               2143            my ( $long, $short ) = $opt->{spec} =~ m/^([\w-]+)(?:\|([^!+=]*))?/;
303   ***    311     50                        1281            if ( !$long ) {
304                                                               # This shouldn't happen.
305   ***      0                                  0               die "Cannot parse long option from spec $opt->{spec}";
306                                                            }
307          311                               1099            $opt->{long} = $long;
308                                                   
309   ***    311     50                        1429            die "Duplicate long option --$long" if exists $self->{opts}->{$long};
310          311                               1313            $self->{opts}->{$long} = $opt;
311                                                   
312          311    100                        1197            if ( length $long == 1 ) {
313            5                                 12               MKDEBUG && _d('Long opt', $long, 'looks like short opt');
314            5                                 20               $self->{short_opts}->{$long} = $long;
315                                                            }
316                                                   
317          311    100                        1049            if ( $short ) {
318   ***     60     50                         289               die "Duplicate short option -$short"
319                                                                  if exists $self->{short_opts}->{$short};
320           60                                259               $self->{short_opts}->{$short} = $long;
321           60                                207               $opt->{short} = $short;
322                                                            }
323                                                            else {
324          251                                869               $opt->{short} = undef;
325                                                            }
326                                                   
327          311    100                        1886            $opt->{is_negatable}  = $opt->{spec} =~ m/!/        ? 1 : 0;
328          311    100                        1504            $opt->{is_cumulative} = $opt->{spec} =~ m/\+/       ? 1 : 0;
329          311    100                        1646            $opt->{is_required}   = $opt->{desc} =~ m/required/ ? 1 : 0;
330                                                   
331          311           100                 1322            $opt->{group} ||= 'default';
332          311                               1570            $self->{groups}->{ $opt->{group} }->{$long} = 1;
333                                                   
334          311                                987            $opt->{value} = undef;
335          311                                978            $opt->{got}   = 0;
336                                                   
337          311                               1570            my ( $type ) = $opt->{spec} =~ m/=(.)/;
338          311                               1079            $opt->{type} = $type;
339          311                                683            MKDEBUG && _d($long, 'type:', $type);
340                                                   
341                                                            # This check is no longer needed because we'll create a DSNParser
342                                                            # object for ourself if DSN OPTIONS exists in the POD.
343                                                            # if ( $type && $type eq 'd' && !$self->{dp} ) {
344                                                            #   die "$opt->{long} is type DSN (d) but no dp argument "
345                                                            #      . "was given when this OptionParser object was created";
346                                                            # }
347                                                   
348                                                            # Option has a non-Getopt type: HhAadzm.  Use Getopt type 's'.
349          311    100    100                 2451            $opt->{spec} =~ s/=./=s/ if ( $type && $type =~ m/[HhAadzm]/ );
350                                                   
351                                                            # Option has a default value if its desc says 'default' or 'default X'.
352                                                            # These defaults from the POD may be overridden by later calls
353                                                            # to set_defaults().
354          311    100                        1851            if ( (my ($def) = $opt->{desc} =~ m/default\b(?: ([^)]+))?/) ) {
355           74    100                         392               $self->{defaults}->{$long} = defined $def ? $def : 1;
356           74                                177               MKDEBUG && _d($long, 'default:', $def);
357                                                            }
358                                                   
359                                                            # Handle special behavior for --config.
360          311    100                        1218            if ( $long eq 'config' ) {
361            8                                 49               $self->{defaults}->{$long} = join(',', $self->get_defaults_files());
362                                                            }
363                                                   
364                                                            # Option disable another option if its desc says 'disable'.
365          311    100                        1565            if ( (my ($dis) = $opt->{desc} =~ m/(disables .*)/) ) {
366                                                               # Defer checking till later because of possible forward references.
367            4                                 14               $disables{$long} = $dis;
368            4                                 10               MKDEBUG && _d('Deferring check of disables rule for', $opt, $dis);
369                                                            }
370                                                   
371                                                            # Save the option.
372          311                               1459            $self->{opts}->{$long} = $opt;
373                                                         }
374                                                         else { # It's an option rule, not a spec.
375           25                                 69            MKDEBUG && _d('Parsing rule:', $opt); 
376           25                                 76            push @{$self->{rules}}, $opt;
              25                                121   
377           25                                120            my @participants = $self->_get_participants($opt);
378           23                                 77            my $rule_ok = 0;
379                                                   
380           23    100                         199            if ( $opt =~ m/mutually exclusive|one and only one/ ) {
381           10                                 32               $rule_ok = 1;
382           10                                 29               push @{$self->{mutex}}, \@participants;
              10                                 53   
383           10                                 29               MKDEBUG && _d(@participants, 'are mutually exclusive');
384                                                            }
385           23    100                         164            if ( $opt =~ m/at least one|one and only one/ ) {
386            5                                 16               $rule_ok = 1;
387            5                                 14               push @{$self->{atleast1}}, \@participants;
               5                                 24   
388            5                                 12               MKDEBUG && _d(@participants, 'require at least one');
389                                                            }
390           23    100                         131            if ( $opt =~ m/default to/ ) {
391            9                                 32               $rule_ok = 1;
392                                                               # Example: "DSN values in L<"--dest"> default to values
393                                                               # from L<"--source">."
394            9                                 45               $self->{defaults_to}->{$participants[0]} = $participants[1];
395            9                                 29               MKDEBUG && _d($participants[0], 'defaults to', $participants[1]);
396                                                            }
397           23    100                         111            if ( $opt =~ m/restricted to option groups/ ) {
398            1                                  3               $rule_ok = 1;
399            1                                  8               my ($groups) = $opt =~ m/groups ([\w\s\,]+)/;
400            1                                  7               my @groups = split(',', $groups);
401            1                                461               %{$self->{allowed_groups}->{$participants[0]}} = map {
               4                                 18   
402            1                                  4                  s/\s+//;
403            4                                 14                  $_ => 1;
404                                                               } @groups;
405                                                            }
406                                                   
407   ***     23     50                         149            die "Unrecognized option rule: $opt" unless $rule_ok;
408                                                         }
409                                                      }
410                                                   
411                                                      # Check forward references in 'disables' rules.
412           38                                188      foreach my $long ( keys %disables ) {
413                                                         # _get_participants() will check that each opt exists.
414            3                                 17         my @participants = $self->_get_participants($disables{$long});
415            2                                 12         $self->{disables}->{$long} = \@participants;
416            2                                  9         MKDEBUG && _d('Option', $long, 'disables', @participants);
417                                                      }
418                                                   
419           37                                164      return; 
420                                                   }
421                                                   
422                                                   # Returns an array of long option names in str. This is used to
423                                                   # find the "participants" of option rules (i.e. the options to
424                                                   # which a rule applies).
425                                                   sub _get_participants {
426           30                   30           155      my ( $self, $str ) = @_;
427           30                                 92      my @participants;
428           30                                275      foreach my $long ( $str =~ m/--(?:\[no\])?([\w-]+)/g ) {
429           62    100                         329         die "Option --$long does not exist while processing rule $str"
430                                                            unless exists $self->{opts}->{$long};
431           59                                250         push @participants, $long;
432                                                      }
433           27                                 79      MKDEBUG && _d('Participants for', $str, ':', @participants);
434           27                                174      return @participants;
435                                                   }
436                                                   
437                                                   # Returns a copy of the internal opts hash.
438                                                   sub opts {
439   ***      4                    4      0     17      my ( $self ) = @_;
440            4                                 12      my %opts = %{$self->{opts}};
               4                                 44   
441            4                                 73      return %opts;
442                                                   }
443                                                   
444                                                   # Returns a copy of the internal short_opts hash.
445                                                   sub short_opts {
446   ***      1                    1      0      4      my ( $self ) = @_;
447            1                                  3      my %short_opts = %{$self->{short_opts}};
               1                                  8   
448            1                                  9      return %short_opts;
449                                                   }
450                                                   
451                                                   sub set_defaults {
452   ***      5                    5      0     30      my ( $self, %defaults ) = @_;
453            5                                 26      $self->{defaults} = {};
454            5                                 32      foreach my $long ( keys %defaults ) {
455            3    100                          15         die "Cannot set default for nonexistent option $long"
456                                                            unless exists $self->{opts}->{$long};
457            2                                  9         $self->{defaults}->{$long} = $defaults{$long};
458            2                                  7         MKDEBUG && _d('Default val for', $long, ':', $defaults{$long});
459                                                      }
460            4                                 16      return;
461                                                   }
462                                                   
463                                                   sub get_defaults {
464   ***      3                    3      0     11      my ( $self ) = @_;
465            3                                 28      return $self->{defaults};
466                                                   }
467                                                   
468                                                   sub get_groups {
469   ***      1                    1      0      4      my ( $self ) = @_;
470            1                                 16      return $self->{groups};
471                                                   }
472                                                   
473                                                   # Getopt::Long calls this sub for each opt it finds on the
474                                                   # cmd line. We have to do this in order to know which opts
475                                                   # were "got" on the cmd line.
476                                                   sub _set_option {
477           78                   78           376      my ( $self, $opt, $val ) = @_;
478   ***     78      0                         195      my $long = exists $self->{opts}->{$opt}       ? $opt
      ***            50                               
479                                                               : exists $self->{short_opts}->{$opt} ? $self->{short_opts}->{$opt}
480                                                               : die "Getopt::Long gave a nonexistent option: $opt";
481                                                   
482                                                      # Reassign $opt.
483           78                                174      $opt = $self->{opts}->{$long};
484           78    100                         955      if ( $opt->{is_cumulative} ) {
485            8                                 33         $opt->{value}++;
486                                                      }
487                                                      else {
488           70                                269         $opt->{value} = $val;
489                                                      }
490           78                                266      $opt->{got} = 1;
491           78                                308      MKDEBUG && _d('Got option', $long, '=', $val);
492                                                   }
493                                                   
494                                                   # Get options on the command line (ARGV) according to the option specs
495                                                   # and enforce option rules. Option values are saved internally in
496                                                   # $self->{opts} and accessed later by get(), got() and set().
497                                                   sub get_opts {
498   ***     61                   61      0    260      my ( $self ) = @_; 
499                                                   
500                                                      # Reset opts. 
501           61                                195      foreach my $long ( keys %{$self->{opts}} ) {
              61                                525   
502          591                               2531         $self->{opts}->{$long}->{got} = 0;
503          591    100                        5166         $self->{opts}->{$long}->{value}
                    100                               
504                                                            = exists $self->{defaults}->{$long}       ? $self->{defaults}->{$long}
505                                                            : $self->{opts}->{$long}->{is_cumulative} ? 0
506                                                            : undef;
507                                                      }
508           61                                273      $self->{got_opts} = 0;
509                                                   
510                                                      # Reset errors.
511           61                                257      $self->{errors} = [];
512                                                   
513                                                      # --config is special-case; parse them manually and remove them from @ARGV
514           61    100    100                  653      if ( @ARGV && $ARGV[0] eq "--config" ) {
515            4                                 12         shift @ARGV;
516            4                                 18         $self->_set_option('config', shift @ARGV);
517                                                      }
518           61    100                         308      if ( $self->has('config') ) {
519           12                                 37         my @extra_args;
520           12                                 70         foreach my $filename ( split(',', $self->get('config')) ) {
521                                                            # Try to open the file.  If it was set explicitly, it's an error if it
522                                                            # can't be opened, but the built-in defaults are to be ignored if they
523                                                            # can't be opened.
524           37                                106            eval {
525           37                                176               push @extra_args, $self->_read_config_file($filename);
526                                                            };
527           37    100                         240            if ( $EVAL_ERROR ) {
528           32    100                         148               if ( $self->got('config') ) {
529            1                                  2                  die $EVAL_ERROR;
530                                                               }
531                                                               elsif ( MKDEBUG ) {
532                                                                  _d($EVAL_ERROR);
533                                                               }
534                                                            }
535                                                         }
536           11                                 71         unshift @ARGV, @extra_args;
537                                                      }
538                                                   
539           60                                355      Getopt::Long::Configure('no_ignore_case', 'bundling');
540                                                      GetOptions(
541                                                         # Make Getopt::Long specs for each option with custom handler subs.
542          578                   74          4069         map    { $_->{spec} => sub { $self->_set_option(@_); } }
              74                             112254   
             589                               2482   
543           60                                345         grep   { $_->{long} ne 'config' } # --config is handled specially above.
544           60    100                        9188         values %{$self->{opts}}
545                                                      ) or $self->save_error('Error parsing options');
546                                                   
547   ***     60     50     66                13860      if ( exists $self->{opts}->{version} && $self->{opts}->{version}->{got} ) {
548   ***      0      0                           0         printf("%s  Ver %s Distrib %s Changeset %s\n",
549                                                            $self->{program_name}, $main::VERSION, $main::DISTRIB, $main::SVN_REV)
550                                                               or die "Cannot print: $OS_ERROR";
551   ***      0                                  0         exit 0;
552                                                      }
553                                                   
554           60    100    100                  342      if ( @ARGV && $self->{strict} ) {
555            1                                  7         $self->save_error("Unrecognized command-line options @ARGV");
556                                                      }
557                                                   
558                                                      # Check mutex options.
559           60                                175      foreach my $mutex ( @{$self->{mutex}} ) {
              60                                345   
560           18                                 81         my @set = grep { $self->{opts}->{$_}->{got} } @$mutex;
              39                                236   
561           18    100                         111         if ( @set > 1 ) {
562            5                                 40            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               3                                 12   
563            3                                 19                         @{$mutex}[ 0 .. scalar(@$mutex) - 2] )
564                                                                    . ' and --'.$self->{opts}->{$mutex->[-1]}->{long}
565                                                                    . ' are mutually exclusive.';
566            3                                 14            $self->save_error($err);
567                                                         }
568                                                      }
569                                                   
570           60                                169      foreach my $required ( @{$self->{atleast1}} ) {
              60                                302   
571            6                                 25         my @set = grep { $self->{opts}->{$_}->{got} } @$required;
              18                                103   
572            6    100                          35         if ( @set == 0 ) {
573            6                                 48            my $err = join(', ', map { "--$self->{opts}->{$_}->{long}" }
               3                                 13   
574            3                                 22                         @{$required}[ 0 .. scalar(@$required) - 2] )
575                                                                    .' or --'.$self->{opts}->{$required->[-1]}->{long};
576            3                                 19            $self->save_error("Specify at least one of $err");
577                                                         }
578                                                      }
579                                                   
580           60                                190      $self->_check_opts( keys %{$self->{opts}} );
              60                                440   
581           60                                259      $self->{got_opts} = 1;
582           60                                204      return;
583                                                   }
584                                                   
585                                                   sub _check_opts {
586           62                   62           461      my ( $self, @long ) = @_;
587           62                                245      my $long_last = scalar @long;
588           62                                275      while ( @long ) {
589           63                                388         foreach my $i ( 0..$#long ) {
590          594                               1951            my $long = $long[$i];
591   ***    594     50                        2147            next unless $long;
592          594                               2354            my $opt  = $self->{opts}->{$long};
593          594    100                        3265            if ( $opt->{got} ) {
                    100                               
594                                                               # Rule: opt disables other opts.
595           77    100                         379               if ( exists $self->{disables}->{$long} ) {
596            1                                  3                  my @disable_opts = @{$self->{disables}->{$long}};
               1                                  6   
597            1                                  3                  map { $self->{opts}->{$_}->{value} = undef; } @disable_opts;
               1                                  6   
598            1                                  2                  MKDEBUG && _d('Unset options', @disable_opts,
599                                                                     'because', $long,'disables them');
600                                                               }
601                                                   
602                                                               # Group restrictions.
603           77    100                         381               if ( exists $self->{allowed_groups}->{$long} ) {
604                                                                  # This option is only allowed with other options from
605                                                                  # certain groups.  Check that no options from restricted
606                                                                  # groups were gotten.
607                                                   
608           10                                 46                  my @restricted_groups = grep {
609            2                                 10                     !exists $self->{allowed_groups}->{$long}->{$_}
610            2                                  6                  } keys %{$self->{groups}};
611                                                   
612            2                                  6                  my @restricted_opts;
613            2                                  7                  foreach my $restricted_group ( @restricted_groups ) {
614            2                                 11                     RESTRICTED_OPT:
615            2                                  5                     foreach my $restricted_opt (
616                                                                        keys %{$self->{groups}->{$restricted_group}} )
617                                                                     {
618            4    100                          22                        next RESTRICTED_OPT if $restricted_opt eq $long;
619            2    100                          12                        push @restricted_opts, $restricted_opt
620                                                                           if $self->{opts}->{$restricted_opt}->{got};
621                                                                     }
622                                                                  }
623                                                   
624            2    100                           8                  if ( @restricted_opts ) {
625            1                                  3                     my $err;
626   ***      1     50                           4                     if ( @restricted_opts == 1 ) {
627            1                                  4                        $err = "--$restricted_opts[0]";
628                                                                     }
629                                                                     else {
630   ***      0                                  0                        $err = join(', ',
631   ***      0                                  0                                  map { "--$self->{opts}->{$_}->{long}" }
632   ***      0                                  0                                  grep { $_ } 
633                                                                                  @restricted_opts[0..scalar(@restricted_opts) - 2]
634                                                                               )
635                                                                             . ' or --'.$self->{opts}->{$restricted_opts[-1]}->{long};
636                                                                     }
637            1                                  7                     $self->save_error("--$long is not allowed with $err");
638                                                                  }
639                                                               }
640                                                   
641                                                            }
642                                                            elsif ( $opt->{is_required} ) { 
643            3                                 22               $self->save_error("Required option --$long must be specified");
644                                                            }
645                                                   
646          594                               2316            $self->_validate_type($opt);
647          594    100                        2263            if ( $opt->{parsed} ) {
648          591                               2320               delete $long[$i];
649                                                            }
650                                                            else {
651            3                                 11               MKDEBUG && _d('Temporarily failed to parse', $long);
652                                                            }
653                                                         }
654                                                   
655           63    100                         305         die "Failed to parse options, possibly due to circular dependencies"
656                                                            if @long == $long_last;
657           62                                293         $long_last = @long;
658                                                      }
659                                                   
660           61                                225      return;
661                                                   }
662                                                   
663                                                   sub _validate_type {
664          594                  594          2192      my ( $self, $opt ) = @_;
665   ***    594     50                        2392      return unless $opt;
666                                                   
667          594    100                        2664      if ( !$opt->{type} ) {
668                                                         # Magic opts like --help and --version.
669          223                                803         $opt->{parsed} = 1;
670          223                                676         return;
671                                                      }
672                                                   
673          371                               1269      my $val = $opt->{value};
674                                                   
675          371    100    100                 9565      if ( $val && $opt->{type} eq 'm' ) {  # type time
                    100    100                        
                    100    100                        
                    100    100                        
                    100    100                        
                           100                        
                           100                        
676           15                                 40         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a time value');
677           15                                147         my ( $prefix, $num, $suffix ) = $val =~ m/([+-]?)(\d+)([a-z])?$/;
678                                                         # The suffix defaults to 's' unless otherwise specified.
679           15    100                          77         if ( !$suffix ) {
680            7                                 36            my ( $s ) = $opt->{desc} =~ m/\(suffix (.)\)/;
681            7           100                   44            $suffix = $s || 's';
682            7                                 17            MKDEBUG && _d('No suffix given; using', $suffix, 'for',
683                                                               $opt->{long}, '(value:', $val, ')');
684                                                         }
685           15    100                          76         if ( $suffix =~ m/[smhd]/ ) {
686           14    100                          80            $val = $suffix eq 's' ? $num            # Seconds
                    100                               
                    100                               
687                                                                 : $suffix eq 'm' ? $num * 60       # Minutes
688                                                                 : $suffix eq 'h' ? $num * 3600     # Hours
689                                                                 :                  $num * 86400;   # Days
690           14           100                  121            $opt->{value} = ($prefix || '') . $val;
691           14                                 43            MKDEBUG && _d('Setting option', $opt->{long}, 'to', $val);
692                                                         }
693                                                         else {
694            1                                  6            $self->save_error("Invalid time suffix for --$opt->{long}");
695                                                         }
696                                                      }
697                                                      elsif ( $val && $opt->{type} eq 'd' ) {  # type DSN
698           15                                 36         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a DSN');
699                                                         # DSN vals for this opt may come from 3 places, in order of precedence:
700                                                         # the opt itself, the defaults to/copies from opt (prev), or
701                                                         # --host, --port, etc. (defaults).
702           15                                 50         my $prev = {};
703           15                                 74         my $from_key = $self->{defaults_to}->{ $opt->{long} };
704           15    100                          60         if ( $from_key ) {
705            8                                 17            MKDEBUG && _d($opt->{long}, 'DSN copies from', $from_key, 'DSN');
706            8    100                          47            if ( $self->{opts}->{$from_key}->{parsed} ) {
707            5                                 25               $prev = $self->{opts}->{$from_key}->{value};
708                                                            }
709                                                            else {
710            3                                  8               MKDEBUG && _d('Cannot parse', $opt->{long}, 'until',
711                                                                  $from_key, 'parsed');
712            3                                 11               return;
713                                                            }
714                                                         }
715           12                                 85         my $defaults = $self->{DSNParser}->parse_options($self);
716           12                               1615         $opt->{value} = $self->{DSNParser}->parse($val, $prev, $defaults);
717                                                      }
718                                                      elsif ( $val && $opt->{type} eq 'z' ) {  # type size
719            7                                 17         MKDEBUG && _d('Parsing option', $opt->{long}, 'as a size value');
720            7                                 38         $self->_parse_size($opt, $val);
721                                                      }
722                                                      elsif ( $opt->{type} eq 'H' || (defined $val && $opt->{type} eq 'h') ) {
723           10           100                   96         $opt->{value} = { map { $_ => 1 } split(/(?<!\\),\s*/, ($val || '')) };
               4                                 20   
724                                                      }
725                                                      elsif ( $opt->{type} eq 'A' || (defined $val && $opt->{type} eq 'a') ) {
726           70           100                  646         $opt->{value} = [ split(/(?<!\\),\s*/, ($val || '')) ];
727                                                      }
728                                                      else {
729          254                                624         MKDEBUG && _d('Nothing to validate for option',
730                                                            $opt->{long}, 'type', $opt->{type}, 'value', $val);
731                                                      }
732                                                   
733          368                               4593      $opt->{parsed} = 1;
734          368                               1083      return;
735                                                   }
736                                                   
737                                                   # Get an option's value. The option can be either a
738                                                   # short or long name (e.g. -A or --charset).
739                                                   sub get {
740   ***    101                  101      0    539      my ( $self, $opt ) = @_;
741          101    100                         580      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
742          101    100    100                 1074      die "Option $opt does not exist"
743                                                         unless $long && exists $self->{opts}->{$long};
744           98                                871      return $self->{opts}->{$long}->{value};
745                                                   }
746                                                   
747                                                   # Returns true if the option was given explicitly on the
748                                                   # command line; returns false if not. The option can be
749                                                   # either short or long name (e.g. -A or --charset).
750                                                   sub got {
751   ***     54                   54      0    256      my ( $self, $opt ) = @_;
752           54    100                         266      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
753           54    100    100                  521      die "Option $opt does not exist"
754                                                         unless $long && exists $self->{opts}->{$long};
755           52                                364      return $self->{opts}->{$long}->{got};
756                                                   }
757                                                   
758                                                   # Returns true if the option exists.
759                                                   sub has {
760   ***    179                  179      0   1445      my ( $self, $opt ) = @_;
761          179    100                         995      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
762          179    100                        1362      return defined $long ? exists $self->{opts}->{$long} : 0;
763                                                   }
764                                                   
765                                                   # Set an option's value. The option can be either a
766                                                   # short or long name (e.g. -A or --charset). The value
767                                                   # can be any scalar, ref, or undef. No type checking
768                                                   # is done so becareful to not set, for example, an integer
769                                                   # option with a DSN.
770                                                   sub set {
771   ***      5                    5      0     24      my ( $self, $opt, $val ) = @_;
772            5    100                          28      my $long = (length $opt == 1 ? $self->{short_opts}->{$opt} : $opt);
773            5    100    100                   35      die "Option $opt does not exist"
774                                                         unless $long && exists $self->{opts}->{$long};
775            3                                 15      $self->{opts}->{$long}->{value} = $val;
776            3                                 10      return;
777                                                   }
778                                                   
779                                                   # Save an error message to be reported later by calling usage_or_errors()
780                                                   # (or errors()--mostly for testing).
781                                                   sub save_error {
782   ***     16                   16      0   3894      my ( $self, $error ) = @_;
783           16                                 55      push @{$self->{errors}}, $error;
              16                                 92   
784                                                   }
785                                                   
786                                                   # Return arrayref of errors (mostly for testing).
787                                                   sub errors {
788   ***     13                   13      0     57      my ( $self ) = @_;
789           13                                 98      return $self->{errors};
790                                                   }
791                                                   
792                                                   sub prompt {
793   ***     12                   12      0     49      my ( $self ) = @_;
794           12                                106      return "Usage: $PROGRAM_NAME $self->{prompt}\n";
795                                                   }
796                                                   
797                                                   sub descr {
798   ***     12                   12      0     47      my ( $self ) = @_;
799   ***     12            50                  137      my $descr  = $self->{program_name} . ' ' . ($self->{description} || '')
800                                                                 . "  For more details, please use the --help option, "
801                                                                 . "or try 'perldoc $PROGRAM_NAME' "
802                                                                 . "for complete documentation.";
803                                                      # DONT_BREAK_LINES is set in OptionParser.t so the output can
804                                                      # be tested reliably.
805   ***     12     50                          71      $descr = join("\n", $descr =~ m/(.{0,80})(?:\s+|$)/g)
806                                                         unless $ENV{DONT_BREAK_LINES};
807           12                                114      $descr =~ s/ +$//mg;
808           12                                 88      return $descr;
809                                                   }
810                                                   
811                                                   sub usage_or_errors {
812   ***      0                    0      0      0      my ( $self ) = @_;
813   ***      0      0                           0      if ( $self->{opts}->{help}->{got} ) {
      ***      0      0                           0   
814   ***      0      0                           0         print $self->print_usage() or die "Cannot print usage: $OS_ERROR";
815   ***      0                                  0         exit 0;
816                                                      }
817                                                      elsif ( scalar @{$self->{errors}} ) {
818   ***      0      0                           0         print $self->print_errors() or die "Cannot print errors: $OS_ERROR";
819   ***      0                                  0         exit 0;
820                                                      }
821   ***      0                                  0      return;
822                                                   }
823                                                   
824                                                   # Explains what errors were found while processing command-line arguments and
825                                                   # gives a brief overview so you can get more information.
826                                                   sub print_errors {
827   ***      1                    1      0      5      my ( $self ) = @_;
828            1                                  6      my $usage = $self->prompt() . "\n";
829   ***      1     50                           4      if ( (my @errors = @{$self->{errors}}) ) {
               1                                 11   
830            1                                 15         $usage .= join("\n  * ", 'Errors in command-line arguments:', @errors)
831                                                                 . "\n";
832                                                      }
833            1                                  8      return $usage . "\n" . $self->descr();
834                                                   }
835                                                   
836                                                   # Prints out command-line help.  The format is like this:
837                                                   # --foo  -F   Description of --foo
838                                                   # --bars -B   Description of --bar
839                                                   # --longopt   Description of --longopt
840                                                   # Note that the short options are aligned along the right edge of their longest
841                                                   # long option, but long options that don't have a short option are allowed to
842                                                   # protrude past that.
843                                                   sub print_usage {
844   ***     11                   11      0     52      my ( $self ) = @_;
845   ***     11     50                          62      die "Run get_opts() before print_usage()" unless $self->{got_opts};
846           11                                 33      my @opts = values %{$self->{opts}};
              11                                 62   
847                                                   
848                                                      # Find how wide the widest long option is.
849           33    100                         241      my $maxl = max(
850           11                                 43         map { length($_->{long}) + ($_->{is_negatable} ? 4 : 0) }
851                                                         @opts);
852                                                   
853                                                      # Find how wide the widest option with a short option is.
854   ***     12     50                          90      my $maxs = max(0,
855           11                                 62         map { length($_) + ($self->{opts}->{$_}->{is_negatable} ? 4 : 0) }
856           11                                 39         values %{$self->{short_opts}});
857                                                   
858                                                      # Find how wide the 'left column' (long + short opts) is, and therefore how
859                                                      # much space to give options and how much to give descriptions.
860           11                                 54      my $lcol = max($maxl, ($maxs + 3));
861           11                                 42      my $rcol = 80 - $lcol - 6;
862           11                                 51      my $rpad = ' ' x ( 80 - $rcol );
863                                                   
864                                                      # Adjust the width of the options that have long and short both.
865           11                                 52      $maxs = max($lcol - 3, $maxs);
866                                                   
867                                                      # Format and return the options.
868           11                                 57      my $usage = $self->descr() . "\n" . $self->prompt();
869                                                   
870                                                      # Sort groups alphabetically but make 'default' first.
871           11                                 48      my @groups = reverse sort grep { $_ ne 'default'; } keys %{$self->{groups}};
              15                                 88   
              11                                 61   
872           11                                 48      push @groups, 'default';
873                                                   
874           11                                 51      foreach my $group ( reverse @groups ) {
875           15    100                          82         $usage .= "\n".($group eq 'default' ? 'Options' : $group).":\n\n";
876           15                                 52         foreach my $opt (
              22                                102   
877           65                                239            sort { $a->{long} cmp $b->{long} }
878                                                            grep { $_->{group} eq $group }
879                                                            @opts )
880                                                         {
881           33    100                         196            my $long  = $opt->{is_negatable} ? "[no]$opt->{long}" : $opt->{long};
882           33                                113            my $short = $opt->{short};
883           33                                118            my $desc  = $opt->{desc};
884                                                            # Expand suffix help for time options.
885           33    100    100                  280            if ( $opt->{type} && $opt->{type} eq 'm' ) {
886            2                                 10               my ($s) = $desc =~ m/\(suffix (.)\)/;
887            2           100                    9               $s    ||= 's';
888            2                                  7               $desc =~ s/\s+\(suffix .\)//;
889            2                                 15               $desc .= ".  Optional suffix s=seconds, m=minutes, h=hours, "
890                                                                      . "d=days; if no suffix, $s is used.";
891                                                            }
892                                                            # Wrap long descriptions
893           33                                517            $desc = join("\n$rpad", grep { $_ } $desc =~ m/(.{0,$rcol})(?:\s+|$)/g);
              71                                266   
894           33                                177            $desc =~ s/ +$//mg;
895           33    100                         116            if ( $short ) {
896           12                                111               $usage .= sprintf("  --%-${maxs}s -%s  %s\n", $long, $short, $desc);
897                                                            }
898                                                            else {
899           21                                163               $usage .= sprintf("  --%-${lcol}s  %s\n", $long, $desc);
900                                                            }
901                                                         }
902                                                      }
903                                                   
904           11    100                          36      if ( (my @rules = @{$self->{rules}}) ) {
              11                                 85   
905            4                                 12         $usage .= "\nRules:\n\n";
906            4                                 17         $usage .= join("\n", map { "  $_" } @rules) . "\n";
               4                                 37   
907                                                      }
908           11    100                          58      if ( $self->{DSNParser} ) {
909            3                                 30         $usage .= "\n" . $self->{DSNParser}->usage();
910                                                      }
911           11                                461      $usage .= "\nOptions and values after processing arguments:\n\n";
912           11                                 27      foreach my $opt ( sort { $a->{long} cmp $b->{long} } @opts ) {
              34                                132   
913           33                                133         my $val   = $opt->{value};
914           33           100                  201         my $type  = $opt->{type} || '';
915           33                                223         my $bool  = $opt->{spec} =~ m/^[\w-]+(?:\|[\w-])?!?$/;
916           33    100                         248         $val      = $bool              ? ( $val ? 'TRUE' : 'FALSE' )
                    100                               
                    100                               
                    100                               
                    100                               
                    100                               
917                                                                   : !defined $val      ? '(No value)'
918                                                                   : $type eq 'd'       ? $self->{DSNParser}->as_string($val)
919                                                                   : $type =~ m/H|h/    ? join(',', sort keys %$val)
920                                                                   : $type =~ m/A|a/    ? join(',', @$val)
921                                                                   :                    $val;
922           33                                444         $usage .= sprintf("  --%-${lcol}s  %s\n", $opt->{long}, $val);
923                                                      }
924           11                                165      return $usage;
925                                                   }
926                                                   
927                                                   # Tries to prompt and read the answer without echoing the answer to the
928                                                   # terminal.  This isn't really related to this package, but it's too handy not
929                                                   # to put here.  OK, it's related, it gets config information from the user.
930                                                   sub prompt_noecho {
931   ***      0      0             0      0      0      shift @_ if ref $_[0] eq __PACKAGE__;
932   ***      0                                  0      my ( $prompt ) = @_;
933   ***      0                                  0      local $OUTPUT_AUTOFLUSH = 1;
934   ***      0      0                           0      print $prompt
935                                                         or die "Cannot print: $OS_ERROR";
936   ***      0                                  0      my $response;
937   ***      0                                  0      eval {
938   ***      0                                  0         require Term::ReadKey;
939   ***      0                                  0         Term::ReadKey::ReadMode('noecho');
940   ***      0                                  0         chomp($response = <STDIN>);
941   ***      0                                  0         Term::ReadKey::ReadMode('normal');
942   ***      0      0                           0         print "\n"
943                                                            or die "Cannot print: $OS_ERROR";
944                                                      };
945   ***      0      0                           0      if ( $EVAL_ERROR ) {
946   ***      0                                  0         die "Cannot read response; is Term::ReadKey installed? $EVAL_ERROR";
947                                                      }
948   ***      0                                  0      return $response;
949                                                   }
950                                                   
951                                                   # This is debug code I want to run for all tools, and this is a module I
952                                                   # certainly include in all tools, but otherwise there's no real reason to put
953                                                   # it here.
954                                                   if ( MKDEBUG ) {
955                                                      print '# ', $^X, ' ', $], "\n";
956                                                      my $uname = `uname -a`;
957                                                      if ( $uname ) {
958                                                         $uname =~ s/\s+/ /g;
959                                                         print "# $uname\n";
960                                                      }
961                                                      printf("# %s  Ver %s Distrib %s Changeset %s line %d\n",
962                                                         $PROGRAM_NAME, ($main::VERSION || ''), ($main::DISTRIB || ''),
963                                                         ($main::SVN_REV || ''), __LINE__);
964                                                      print('# Arguments: ',
965                                                         join(' ', map { my $a = "_[$_]_"; $a =~ s/\n/\n# /g; $a; } @ARGV), "\n");
966                                                   }
967                                                   
968                                                   # Reads a configuration file and returns it as a list.  Inspired by
969                                                   # Config::Tiny.
970                                                   sub _read_config_file {
971           38                   38           169      my ( $self, $filename ) = @_;
972           38    100                         263      open my $fh, "<", $filename or die "Cannot open $filename: $OS_ERROR\n";
973            6                                 17      my @args;
974            6                                 19      my $prefix = '--';
975            6                                 18      my $parse  = 1;
976                                                   
977                                                      LINE:
978            6                                563      while ( my $line = <$fh> ) {
979           24                                 85         chomp $line;
980                                                         # Skip comments and empty lines
981           24    100                         193         next LINE if $line =~ m/^\s*(?:\#|\;|$)/;
982                                                         # Remove inline comments
983           20                                 82         $line =~ s/\s+#.*$//g;
984                                                         # Remove whitespace
985           20                                133         $line =~ s/^\s+|\s+$//g;
986                                                         # Watch for the beginning of the literal values (not to be interpreted as
987                                                         # options)
988           20    100                          96         if ( $line eq '--' ) {
989            4                                 13            $prefix = '';
990            4                                 14            $parse  = 0;
991            4                                 27            next LINE;
992                                                         }
993   ***     16    100     66                  256         if ( $parse
      ***            50                               
994                                                            && (my($opt, $arg) = $line =~ m/^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/)
995                                                         ) {
996            9                                 48            push @args, grep { defined $_ } ("$prefix$opt", $arg);
              18                                133   
997                                                         }
998                                                         elsif ( $line =~ m/./ ) {
999            7                                 63            push @args, $line;
1000                                                        }
1001                                                        else {
1002  ***      0                                  0            die "Syntax error in file $filename at line $INPUT_LINE_NUMBER";
1003                                                        }
1004                                                     }
1005           6                                 44      close $fh;
1006           6                                 17      return @args;
1007                                                  }
1008                                                  
1009                                                  # Reads the next paragraph from the POD after the magical regular expression is
1010                                                  # found in the text.
1011                                                  sub read_para_after {
1012  ***      2                    2      0     11      my ( $self, $file, $regex ) = @_;
1013  ***      2     50                          63      open my $fh, "<", $file or die "Can't open $file: $OS_ERROR";
1014           2                                 12      local $INPUT_RECORD_SEPARATOR = '';
1015           2                                  4      my $para;
1016           2                                236      while ( $para = <$fh> ) {
1017           6    100                          53         next unless $para =~ m/^=pod$/m;
1018           2                                  8         last;
1019                                                     }
1020           2                                 16      while ( $para = <$fh> ) {
1021           7    100                          56         next unless $para =~ m/$regex/;
1022           2                                  7         last;
1023                                                     }
1024           2                                  8      $para = <$fh>;
1025           2                                  8      chomp($para);
1026  ***      2     50                          27      close $fh or die "Can't close $file: $OS_ERROR";
1027           2                                  6      return $para;
1028                                                  }
1029                                                  
1030                                                  # Returns a lightweight clone of ourself.  Currently, only the basic
1031                                                  # opts are copied.  This is used for stuff like "final opts" in
1032                                                  # mk-table-checksum.
1033                                                  sub clone {
1034  ***      1                    1      0      4      my ( $self ) = @_;
1035                                                  
1036                                                     # Deep-copy contents of hashrefs; do not just copy the refs. 
1037           3                                 10      my %clone = map {
1038           1                                  4         my $hashref  = $self->{$_};
1039           3                                 10         my $val_copy = {};
1040           3                                 12         foreach my $key ( keys %$hashref ) {
1041           5                                 17            my $ref = ref $hashref->{$key};
1042           3                                 40            $val_copy->{$key} = !$ref           ? $hashref->{$key}
1043  ***      0                                  0                              : $ref eq 'HASH'  ? { %{$hashref->{$key}} }
1044  ***      5      0                          45                              : $ref eq 'ARRAY' ? [ @{$hashref->{$key}} ]
      ***            50                               
                    100                               
1045                                                                             : $hashref->{$key};
1046                                                        }
1047           3                                 14         $_ => $val_copy;
1048                                                     } qw(opts short_opts defaults);
1049                                                  
1050                                                     # Re-assign scalar values.
1051           1                                  4      foreach my $scalar ( qw(got_opts) ) {
1052           1                                  5         $clone{$scalar} = $self->{$scalar};
1053                                                     }
1054                                                  
1055           1                                  6      return bless \%clone;     
1056                                                  }
1057                                                  
1058                                                  sub _parse_size {
1059           7                    7            31      my ( $self, $opt, $val ) = @_;
1060                                                  
1061                                                     # Special case used by mk-find to do things like --datasize null.
1062  ***      7    100     50                   44      if ( lc($val || '') eq 'null' ) {
1063           1                                  2         MKDEBUG && _d('NULL size for', $opt->{long});
1064           1                                  5         $opt->{value} = 'null';
1065           1                                  3         return;
1066                                                     }
1067                                                  
1068           6                                 31      my %factor_for = (k => 1_024, M => 1_048_576, G => 1_073_741_824);
1069           6                                 47      my ($pre, $num, $factor) = $val =~ m/^([+-])?(\d+)([kMG])?$/;
1070           6    100                          25      if ( defined $num ) {
1071           5    100                          24         if ( $factor ) {
1072           4                                 17            $num *= $factor_for{$factor};
1073           4                                  9            MKDEBUG && _d('Setting option', $opt->{y},
1074                                                              'to num', $num, '* factor', $factor);
1075                                                        }
1076           5           100                   42         $opt->{value} = ($pre || '') . $num;
1077                                                     }
1078                                                     else {
1079           1                                  6         $self->save_error("Invalid size for --$opt->{long}");
1080                                                     }
1081           6                                 24      return;
1082                                                  }
1083                                                  
1084                                                  # Parse the option's attributes and return a GetOpt type.
1085                                                  # E.g. "foo type:int" == "foo=i"; "[no]bar" == "bar!", etc.
1086                                                  sub _parse_attribs {
1087         231                  231           923      my ( $self, $option, $attribs ) = @_;
1088         231                                805      my $types = $self->{types};
1089         231    100                        3652      return $option
                    100                               
                    100                               
                    100                               
1090                                                        . ($attribs->{'short form'} ? '|' . $attribs->{'short form'}   : '' )
1091                                                        . ($attribs->{'negatable'}  ? '!'                              : '' )
1092                                                        . ($attribs->{'cumulative'} ? '+'                              : '' )
1093                                                        . ($attribs->{'type'}       ? '=' . $types->{$attribs->{type}} : '' );
1094                                                  }
1095                                                  
1096                                                  sub _d {
1097           1                    1             8      my ($package, undef, $line) = caller 0;
1098  ***      2     50                          10      @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
               2                                  9   
               2                                 10   
1099           1                                  5           map { defined $_ ? $_ : 'undef' }
1100                                                          @_;
1101           1                                  4      print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
1102                                                  }
1103                                                  
1104                                                  1;
1105                                                  
1106                                                  # ###########################################################################
1107                                                  # End OptionParser package
1108                                                  # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      0     45   unless $args{$arg}
114   ***     50      0      6   unless open my $fh, '<', $file
117          100      4      2   if ($contents =~ /^=head1 DSN OPTIONS/m)
127   ***     50     70      0   if ($val)
128          100      4     32   $val eq 'no' ? :
             100     34     36   $val eq 'yes' ? :
188   ***     50      0     16   unless open my $fh, '<', $file
198          100   8614     15   unless $para =~ /^=head1 $$self{'head1'}/
204          100     15     15   if $para =~ /^=over/
205          100      4     11   if $$self{'skip_rules'}
213          100      1     15   unless $para
217          100    273     47   if (my($option) = $para =~ /^=item $$self{'item'}/)
224          100    209     64   if ($para =~ /: /) { }
228          100      1    314   unless $$self{'attributes'}{$attrib}
232          100     27    181   if ($attribs{'short form'})
251          100      1    271   if $para =~ /^=item/
254          100     15    256   if (my($base_option) = $option =~ /^\[no\](.*)/)
259          100     57    214   $attribs{'default'} ? :
             100      6    265   $attribs{'group'} ? :
267   ***     50      0    783   unless $para
268          100     12    771   if ($para =~ /^=head1/)
272          100    305    466   if $para =~ /^=item /
276          100      1     12   unless @specs
298          100    311     25   if (ref $opt) { }
303   ***     50      0    311   if (not $long)
309   ***     50      0    311   if exists $$self{'opts'}{$long}
312          100      5    306   if (length $long == 1)
317          100     60    251   if ($short) { }
318   ***     50      0     60   if exists $$self{'short_opts'}{$short}
327          100     20    291   $$opt{'spec'} =~ /!/ ? :
328          100      4    307   $$opt{'spec'} =~ /\+/ ? :
329          100      5    306   $$opt{'desc'} =~ /required/ ? :
349          100    106    205   if $type and $type =~ /[HhAadzm]/
354          100     74    237   if (my($def) = $$opt{'desc'} =~ /default\b(?: ([^)]+))?/)
355          100     73      1   defined $def ? :
360          100      8    303   if ($long eq 'config')
365          100      4    307   if (my($dis) = $$opt{'desc'} =~ /(disables .*)/)
380          100     10     13   if ($opt =~ /mutually exclusive|one and only one/)
385          100      5     18   if ($opt =~ /at least one|one and only one/)
390          100      9     14   if ($opt =~ /default to/)
397          100      1     22   if ($opt =~ /restricted to option groups/)
407   ***     50      0     23   unless $rule_ok
429          100      3     59   unless exists $$self{'opts'}{$long}
455          100      1      2   unless exists $$self{'opts'}{$long}
478   ***      0      0      0   exists $$self{'short_opts'}{$opt} ? :
      ***     50     78      0   exists $$self{'opts'}{$opt} ? :
484          100      8     70   if ($$opt{'is_cumulative'}) { }
503          100     15    431   $$self{'opts'}{$long}{'is_cumulative'} ? :
             100    145    446   exists $$self{'defaults'}{$long} ? :
514          100      4     57   if (@ARGV and $ARGV[0] eq '--config')
518          100     12     49   if ($self->has('config'))
527          100     32      5   if ($EVAL_ERROR)
528          100      1     31   $self->got('config') ? :
544          100      3     57   unless GetOptions map({$$_{'spec'}, sub {
	$self->_set_option(@_);
}
;} grep({$$_{'long'} ne 'config';} values %{$$self{'opts'};}))
547   ***     50      0     60   if (exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'})
548   ***      0      0      0   unless printf "%s  Ver %s Distrib %s Changeset %s\n", $$self{'program_name'}, $main::VERSION, $main::DISTRIB, $main::SVN_REV
554          100      1     59   if (@ARGV and $$self{'strict'})
561          100      3     15   if (@set > 1)
572          100      3      3   if (@set == 0)
591   ***     50      0    594   unless $long
593          100     77    517   if ($$opt{'got'}) { }
             100      3    514   elsif ($$opt{'is_required'}) { }
595          100      1     76   if (exists $$self{'disables'}{$long})
603          100      2     75   if (exists $$self{'allowed_groups'}{$long})
618          100      2      2   if $restricted_opt eq $long
619          100      1      1   if $$self{'opts'}{$restricted_opt}{'got'}
624          100      1      1   if (@restricted_opts)
626   ***     50      1      0   if (@restricted_opts == 1) { }
647          100    591      3   if ($$opt{'parsed'}) { }
655          100      1     62   if @long == $long_last
665   ***     50      0    594   unless $opt
667          100    223    371   if (not $$opt{'type'})
675          100     15    356   if ($val and $$opt{'type'} eq 'm') { }
             100     15    341   elsif ($val and $$opt{'type'} eq 'd') { }
             100      7    334   elsif ($val and $$opt{'type'} eq 'z') { }
             100     10    324   elsif ($$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h') { }
             100     70    254   elsif ($$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a') { }
679          100      7      8   if (not $suffix)
685          100     14      1   if ($suffix =~ /[smhd]/) { }
686          100      2      1   $suffix eq 'h' ? :
             100      3      3   $suffix eq 'm' ? :
             100      8      6   $suffix eq 's' ? :
704          100      8      7   if ($from_key)
706          100      5      3   if ($$self{'opts'}{$from_key}{'parsed'}) { }
741          100     42     59   length $opt == 1 ? :
742          100      3     98   unless $long and exists $$self{'opts'}{$long}
752          100      4     50   length $opt == 1 ? :
753          100      2     52   unless $long and exists $$self{'opts'}{$long}
761          100    113     66   length $opt == 1 ? :
762          100     85     94   defined $long ? :
772          100      2      3   length $opt == 1 ? :
773          100      2      3   unless $long and exists $$self{'opts'}{$long}
805   ***     50      0     12   unless $ENV{'DONT_BREAK_LINES'}
813   ***      0      0      0   if ($$self{'opts'}{'help'}{'got'}) { }
      ***      0      0      0   elsif (scalar @{$$self{'errors'};}) { }
814   ***      0      0      0   unless print $self->print_usage
818   ***      0      0      0   unless print $self->print_errors
829   ***     50      1      0   if (my(@errors) = @{$$self{'errors'};})
845   ***     50      0     11   unless $$self{'got_opts'}
849          100      3     30   $$_{'is_negatable'} ? :
854   ***     50      0     12   $$self{'opts'}{$_}{'is_negatable'} ? :
875          100     11      4   $group eq 'default' ? :
881          100      3     30   $$opt{'is_negatable'} ? :
885          100      2     31   if ($$opt{'type'} and $$opt{'type'} eq 'm')
895          100     12     21   if ($short) { }
904          100      4      7   if (my(@rules) = @{$$self{'rules'};})
908          100      3      8   if ($$self{'DSNParser'})
916          100      1     10   $val ? :
             100      6      1   $type =~ /A|a/ ? :
             100      2      7   $type =~ /H|h/ ? :
             100      2      9   $type eq 'd' ? :
             100     11     11   !defined($val) ? :
             100     11     22   $bool ? :
931   ***      0      0      0   if ref $_[0] eq 'OptionParser'
934   ***      0      0      0   unless print $prompt
942   ***      0      0      0   unless print "\n"
945   ***      0      0      0   if ($EVAL_ERROR)
972          100     32      6   unless open my $fh, '<', $filename
981          100      4     20   if $line =~ /^\s*(?:\#|\;|$)/
988          100      4     16   if ($line eq '--')
993          100      9      7   if ($parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/) { }
      ***     50      7      0   elsif ($line =~ /./) { }
1013  ***     50      0      2   unless open my $fh, '<', $file
1017         100      4      2   unless $para =~ /^=pod$/m
1021         100      5      2   unless $para =~ /$regex/
1026  ***     50      0      2   unless close $fh
1044  ***      0      0      0   $ref eq 'ARRAY' ? :
      ***     50      3      0   $ref eq 'HASH' ? :
             100      2      3   !$ref ? :
1062         100      1      6   if (lc($val || '') eq 'null')
1070         100      5      1   if (defined $num) { }
1071         100      4      1   if ($factor)
1089         100     27    204   $$attribs{'short form'} ? :
             100     17    214   $$attribs{'negatable'} ? :
             100      2    229   $$attribs{'cumulative'} ? :
             100    148     83   $$attribs{'type'} ? :
1098  ***     50      2      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
349          100    116     89    106   $type and $type =~ /[HhAadzm]/
514          100     16     41      4   @ARGV and $ARGV[0] eq '--config'
547   ***     66     51      9      0   exists $$self{'opts'}{'version'} and $$self{'opts'}{'version'}{'got'}
554          100     57      2      1   @ARGV and $$self{'strict'}
675          100    209    147     15   $val and $$opt{'type'} eq 'm'
             100    209    132     15   $val and $$opt{'type'} eq 'd'
             100    209    125      7   $val and $$opt{'type'} eq 'z'
             100    201    123      1   defined $val and $$opt{'type'} eq 'h'
             100    193     61     27   defined $val and $$opt{'type'} eq 'a'
742          100      1      2     98   $long and exists $$self{'opts'}{$long}
753          100      1      1     52   $long and exists $$self{'opts'}{$long}
773          100      1      1      3   $long and exists $$self{'opts'}{$long}
885          100     12     19      2   $$opt{'type'} and $$opt{'type'} eq 'm'
993   ***     66      7      0      9   $parse and my($opt, $arg) = $line =~ /^\s*([^=\s]+?)(?:\s*=\s*(.*?)\s*)?$/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
29    ***     50      0      1   $ENV{'MKDEBUG'} || 0
40    ***     50     45      0   $program_name ||= $PROGRAM_NAME
41    ***     50     45      0   $ENV{'HOME'} || $ENV{'HOMEPATH'} || $ENV{'USERPROFILE'} || '.'
108   ***     50      7      0   $file ||= '/home/daniel/dev/maatkit/common/OptionParser.pm'
187   ***     50     16      0   $file ||= '/home/daniel/dev/maatkit/common/OptionParser.pm'
331          100    245     66   $$opt{'group'} ||= 'default'
681          100      4      3   $s || 's'
690          100      3     11   $prefix || ''
723          100      2      8   $val || ''
726          100     62      8   $val || ''
799   ***     50     12      0   $$self{'description'} || ''
887          100      1      1   $s ||= 's'
914          100     21     12   $$opt{'type'} || ''
1062  ***     50      7      0   $val || ''
1076         100      2      3   $pre || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
41    ***     33     45      0      0   $ENV{'HOME'} || $ENV{'HOMEPATH'}
      ***     33     45      0      0   $ENV{'HOME'} || $ENV{'HOMEPATH'} || $ENV{'USERPROFILE'}
675          100      9      1    324   $$opt{'type'} eq 'H' or defined $val and $$opt{'type'} eq 'h'
             100     43     27    254   $$opt{'type'} eq 'A' or defined $val and $$opt{'type'} eq 'a'


Covered Subroutines
-------------------

Subroutine         Count Pod Location                                            
------------------ ----- --- ----------------------------------------------------
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:22  
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:23  
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:25  
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:26  
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:27  
BEGIN                  1     /home/daniel/dev/maatkit/common/OptionParser.pm:29  
DSNParser              1   0 /home/daniel/dev/maatkit/common/OptionParser.pm:164 
__ANON__              40     /home/daniel/dev/maatkit/common/OptionParser.pm:124 
__ANON__              74     /home/daniel/dev/maatkit/common/OptionParser.pm:542 
_check_opts           62     /home/daniel/dev/maatkit/common/OptionParser.pm:586 
_d                     1     /home/daniel/dev/maatkit/common/OptionParser.pm:1097
_get_participants     30     /home/daniel/dev/maatkit/common/OptionParser.pm:426 
_parse_attribs       231     /home/daniel/dev/maatkit/common/OptionParser.pm:1087
_parse_size            7     /home/daniel/dev/maatkit/common/OptionParser.pm:1059
_parse_specs          40     /home/daniel/dev/maatkit/common/OptionParser.pm:294 
_pod_to_specs         16     /home/daniel/dev/maatkit/common/OptionParser.pm:186 
_read_config_file     38     /home/daniel/dev/maatkit/common/OptionParser.pm:971 
_set_option           78     /home/daniel/dev/maatkit/common/OptionParser.pm:477 
_validate_type       594     /home/daniel/dev/maatkit/common/OptionParser.pm:664 
clone                  1   0 /home/daniel/dev/maatkit/common/OptionParser.pm:1034
descr                 12   0 /home/daniel/dev/maatkit/common/OptionParser.pm:798 
errors                13   0 /home/daniel/dev/maatkit/common/OptionParser.pm:788 
get                  101   0 /home/daniel/dev/maatkit/common/OptionParser.pm:740 
get_defaults           3   0 /home/daniel/dev/maatkit/common/OptionParser.pm:464 
get_defaults_files     9   0 /home/daniel/dev/maatkit/common/OptionParser.pm:170 
get_groups             1   0 /home/daniel/dev/maatkit/common/OptionParser.pm:469 
get_opts              61   0 /home/daniel/dev/maatkit/common/OptionParser.pm:498 
get_specs              7   0 /home/daniel/dev/maatkit/common/OptionParser.pm:107 
got                   54   0 /home/daniel/dev/maatkit/common/OptionParser.pm:751 
has                  179   0 /home/daniel/dev/maatkit/common/OptionParser.pm:760 
new                   45   0 /home/daniel/dev/maatkit/common/OptionParser.pm:34  
opts                   4   0 /home/daniel/dev/maatkit/common/OptionParser.pm:439 
print_errors           1   0 /home/daniel/dev/maatkit/common/OptionParser.pm:827 
print_usage           11   0 /home/daniel/dev/maatkit/common/OptionParser.pm:844 
prompt                12   0 /home/daniel/dev/maatkit/common/OptionParser.pm:793 
read_para_after        2   0 /home/daniel/dev/maatkit/common/OptionParser.pm:1012
save_error            16   0 /home/daniel/dev/maatkit/common/OptionParser.pm:782 
set                    5   0 /home/daniel/dev/maatkit/common/OptionParser.pm:771 
set_defaults           5   0 /home/daniel/dev/maatkit/common/OptionParser.pm:452 
short_opts             1   0 /home/daniel/dev/maatkit/common/OptionParser.pm:446 

Uncovered Subroutines
---------------------

Subroutine         Count Pod Location                                            
------------------ ----- --- ----------------------------------------------------
prompt_noecho          0   0 /home/daniel/dev/maatkit/common/OptionParser.pm:931 
usage_or_errors        0   0 /home/daniel/dev/maatkit/common/OptionParser.pm:812 


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
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1            11   use Test::More tests => 147;
               1                                  4   
               1                                  9   
13                                                    
14             1                    1            12   use OptionParser;
               1                                  4   
               1                                 15   
15             1                    1            14   use DSNParser;
               1                                  2   
               1                                 13   
16             1                    1            14   use MaatkitTest;
               1                                  5   
               1                                 38   
17                                                    
18             1                                 15   my $o  = new OptionParser(
19                                                       description  => 'parses command line options.',
20                                                       prompt       => '[OPTIONS]',
21                                                    );
22                                                    
23             1                                  9   isa_ok($o, 'OptionParser');
24                                                    
25             1                                  6   my @opt_specs;
26             1                                  4   my %opts;
27                                                    
28                                                    # Prevent print_usage() from breaking lines in the first paragraph
29                                                    # at 80 chars width.  This paragraph contains $PROGRAM_NAME and that
30                                                    # becomes too long when this test is ran from trunk, causing a break.
31                                                    # To make this test path-independent, we don't break lines.  This only
32                                                    # affects testing.
33             1                                  9   $ENV{DONT_BREAK_LINES} = 1;
34                                                    
35                                                    # Some tests need a DSNParser but we don't provide a POD with a
36                                                    # DSN OPTIONS section that would cause the OptionParser to create
37                                                    # a DSNParser automatically.  So we create the DSNParser manually
38                                                    # and hack it into the OptionParser.
39             1                                 31   my $dsn_opts = [
40                                                       {
41                                                          key => 'A',
42                                                          desc => 'Default character set',
43                                                          dsn  => 'charset',
44                                                          copy => 1,
45                                                       },
46                                                       {
47                                                          key => 'D',
48                                                          desc => 'Database to use',
49                                                          dsn  => 'database',
50                                                          copy => 1,
51                                                       },
52                                                       {
53                                                          key => 'F',
54                                                          desc => 'Only read default options from the given file',
55                                                          dsn  => 'mysql_read_default_file',
56                                                          copy => 1,
57                                                       },
58                                                       {
59                                                          key => 'h',
60                                                          desc => 'Connect to host',
61                                                          dsn  => 'host',
62                                                          copy => 1,
63                                                       },
64                                                       {
65                                                          key => 'p',
66                                                          desc => 'Password to use when connecting',
67                                                          dsn  => 'password',
68                                                          copy => 1,
69                                                       },
70                                                       {
71                                                          key => 'P',
72                                                          desc => 'Port number to use for connection',
73                                                          dsn  => 'port',
74                                                          copy => 1,
75                                                       },
76                                                       {
77                                                          key => 'S',
78                                                          desc => 'Socket file to use for connection',
79                                                          dsn  => 'mysql_socket',
80                                                          copy => 1,
81                                                       },
82                                                       {
83                                                          key => 'u',
84                                                          desc => 'User for login if not current user',
85                                                          dsn  => 'user',
86                                                          copy => 1,
87                                                       },
88                                                    ];
89             1                                 12   my $dp = new DSNParser(opts => $dsn_opts);
90                                                    
91                                                    # #############################################################################
92                                                    # Test basic usage.
93                                                    # #############################################################################
94                                                    
95                                                    # Quick test of standard interface.
96             1                                217   $o->get_specs("$trunk/common/t/samples/pod/pod_sample_01.txt");
97             1                                 18   %opts = $o->opts();
98             1                                  9   ok(
99                                                       exists $opts{help},
100                                                      'get_specs() basic interface'
101                                                   );
102                                                   
103                                                   # More exhaustive test of how the standard interface works internally.
104            1                                 10   $o  = new OptionParser(
105                                                      description  => 'parses command line options.',
106                                                   );
107            1                                 24   ok(!$o->has('time'), 'There is no --time yet');
108            1                                  7   @opt_specs = $o->_pod_to_specs("$trunk/common/t/samples/pod/pod_sample_01.txt");
109            1                                 49   is_deeply(
110                                                      \@opt_specs,
111                                                      [
112                                                      { spec=>'database|D=s', group=>'default', desc=>'database string',         },
113                                                      { spec=>'port|p=i',     group=>'default', desc=>'port (default 3306)',     },
114                                                      { spec=>'price=f',    group=>'default', desc=>'price float (default 1.23)' },
115                                                      { spec=>'hash-req=H', group=>'default', desc=>'hash that requires a value' },
116                                                      { spec=>'hash-opt=h', group=>'default', desc=>'hash with an optional value'},
117                                                      { spec=>'array-req=A',group=>'default', desc=>'array that requires a value'},
118                                                      { spec=>'array-opt=a',group=>'default',desc=>'array with an optional value'},
119                                                      { spec=>'host=d',       group=>'default', desc=>'host DSN'           },
120                                                      { spec=>'chunk-size=z', group=>'default', desc=>'chunk size'         },
121                                                      { spec=>'time=m',       group=>'default', desc=>'time'               },
122                                                      { spec=>'help+',        group=>'default', desc=>'help cumulative'    },
123                                                      { spec=>'other!',       group=>'default', desc=>'other negatable'    },
124                                                      ],
125                                                      'Convert POD OPTIONS to opt specs (pod_sample_01.txt)',
126                                                   );
127                                                   
128            1                                 20   $o->_parse_specs(@opt_specs);
129            1                                  6   ok($o->has('time'), 'There is a --time now');
130            1                                  6   %opts = $o->opts();
131            1                                 77   is_deeply(
132                                                      \%opts,
133                                                      {
134                                                         'database'   => {
135                                                            spec           => 'database|D=s',
136                                                            desc           => 'database string',
137                                                            group          => 'default',
138                                                            long           => 'database',
139                                                            short          => 'D',
140                                                            is_cumulative  => 0,
141                                                            is_negatable   => 0,
142                                                            is_required    => 0,
143                                                            type           => 's',
144                                                            got            => 0,
145                                                            value          => undef,
146                                                         },
147                                                         'port'       => {
148                                                            spec           => 'port|p=i',
149                                                            desc           => 'port (default 3306)',
150                                                            group          => 'default',
151                                                            long           => 'port',
152                                                            short          => 'p',
153                                                            is_cumulative  => 0,
154                                                            is_negatable   => 0,
155                                                            is_required    => 0,
156                                                            type           => 'i',
157                                                            got            => 0,
158                                                            value          => undef,
159                                                         },
160                                                         'price'      => {
161                                                            spec           => 'price=f',
162                                                            desc           => 'price float (default 1.23)',
163                                                            group          => 'default',
164                                                            long           => 'price',
165                                                            short          => undef,
166                                                            is_cumulative  => 0,
167                                                            is_negatable   => 0,
168                                                            is_required    => 0,
169                                                            type           => 'f',
170                                                            got            => 0,
171                                                            value          => undef,
172                                                         },
173                                                         'hash-req'   => {
174                                                            spec           => 'hash-req=s',
175                                                            desc           => 'hash that requires a value',
176                                                            group          => 'default',
177                                                            long           => 'hash-req',
178                                                            short          => undef,
179                                                            is_cumulative  => 0,
180                                                            is_negatable   => 0,
181                                                            is_required    => 0,
182                                                            type           => 'H',
183                                                            got            => 0,
184                                                            value          => undef,
185                                                         },
186                                                         'hash-opt'   => {
187                                                            spec           => 'hash-opt=s',
188                                                            desc           => 'hash with an optional value',
189                                                            group          => 'default',
190                                                            long           => 'hash-opt',
191                                                            short          => undef,
192                                                            is_cumulative  => 0,
193                                                            is_negatable   => 0,
194                                                            is_required    => 0,
195                                                            type           => 'h',
196                                                            got            => 0,
197                                                            value          => undef,
198                                                         },
199                                                         'array-req'  => {
200                                                            spec           => 'array-req=s',
201                                                            desc           => 'array that requires a value',
202                                                            group          => 'default',
203                                                            long           => 'array-req',
204                                                            short          => undef,
205                                                            is_cumulative  => 0,
206                                                            is_negatable   => 0,
207                                                            is_required    => 0,
208                                                            type           => 'A',
209                                                            got            => 0,
210                                                            value          => undef,
211                                                         },
212                                                         'array-opt'  => {
213                                                            spec           => 'array-opt=s',
214                                                            desc           => 'array with an optional value',
215                                                            group          => 'default',
216                                                            long           => 'array-opt',
217                                                            short          => undef,
218                                                            is_cumulative  => 0,
219                                                            is_negatable   => 0,
220                                                            is_required    => 0,
221                                                            type           => 'a',
222                                                            got            => 0,
223                                                            value          => undef,
224                                                         },
225                                                         'host'       => {
226                                                            spec           => 'host=s',
227                                                            desc           => 'host DSN',
228                                                            group          => 'default',
229                                                            long           => 'host',
230                                                            short          => undef,
231                                                            is_cumulative  => 0,
232                                                            is_negatable   => 0,
233                                                            is_required    => 0,
234                                                            type           => 'd',
235                                                            got            => 0,
236                                                            value          => undef,
237                                                         },
238                                                         'chunk-size' => {
239                                                            spec           => 'chunk-size=s',
240                                                            desc           => 'chunk size',
241                                                            group          => 'default',
242                                                            long           => 'chunk-size',
243                                                            short          => undef,
244                                                            is_cumulative  => 0,
245                                                            is_negatable   => 0,
246                                                            is_required    => 0,
247                                                            type           => 'z',
248                                                            got            => 0,
249                                                            value          => undef,
250                                                         },
251                                                         'time'       => {
252                                                            spec           => 'time=s',
253                                                            desc           => 'time',
254                                                            group          => 'default',
255                                                            long           => 'time',
256                                                            short          => undef,
257                                                            is_cumulative  => 0,
258                                                            is_negatable   => 0,
259                                                            is_required    => 0,
260                                                            type           => 'm',
261                                                            got            => 0,
262                                                            value          => undef,
263                                                         },
264                                                         'help'       => {
265                                                            spec           => 'help+',
266                                                            desc           => 'help cumulative',
267                                                            group          => 'default',
268                                                            long           => 'help',
269                                                            short          => undef,
270                                                            is_cumulative  => 1,
271                                                            is_negatable   => 0,
272                                                            is_required    => 0,
273                                                            type           => undef,
274                                                            got            => 0,
275                                                            value          => undef,
276                                                         },
277                                                         'other'      => {
278                                                            spec           => 'other!',
279                                                            desc           => 'other negatable',
280                                                            group          => 'default',
281                                                            long           => 'other',
282                                                            short          => undef,
283                                                            is_cumulative  => 0,
284                                                            is_negatable   => 1,
285                                                            is_required    => 0,
286                                                            type           => undef,
287                                                            got            => 0,
288                                                            value          => undef,
289                                                         }
290                                                      },
291                                                      'Parse opt specs'
292                                                   );
293                                                   
294            1                                 27   %opts = $o->short_opts();
295            1                                  7   is_deeply(
296                                                      \%opts,
297                                                      {
298                                                         'D' => 'database',
299                                                         'p' => 'port',
300                                                      },
301                                                      'Short opts => log opts'
302                                                   );
303                                                   
304                                                   # get() single option
305            1                                 15   is(
306                                                      $o->get('database'),
307                                                      undef,
308                                                      'Get valueless long opt'
309                                                   );
310            1                                  5   is(
311                                                      $o->get('p'),
312                                                      undef,
313                                                      'Get valuless short opt'
314                                                   );
315            1                                  3   eval { $o->get('foo'); };
               1                                  5   
316            1                                 21   like(
317                                                      $EVAL_ERROR,
318                                                      qr/Option foo does not exist/,
319                                                      'Die trying to get() nonexistent long opt'
320                                                   );
321            1                                 12   eval { $o->get('x'); };
               1                                  5   
322            1                                  9   like(
323                                                      $EVAL_ERROR,
324                                                      qr/Option x does not exist/,
325                                                      'Die trying to get() nonexistent short opt'
326                                                   );
327                                                   
328                                                   # set()
329            1                                 12   $o->set('database', 'foodb');
330            1                                  6   is(
331                                                      $o->get('database'),
332                                                      'foodb',
333                                                      'Set long opt'
334                                                   );
335            1                                  6   $o->set('p', 12345);
336            1                                  4   is(
337                                                      $o->get('p'),
338                                                      12345,
339                                                      'Set short opt'
340                                                   );
341            1                                  3   eval { $o->set('foo', 123); };
               1                                  5   
342            1                                  8   like(
343                                                      $EVAL_ERROR,
344                                                      qr/Option foo does not exist/,
345                                                      'Die trying to set() nonexistent long opt'
346                                                   );
347            1                                  7   eval { $o->set('x', 123); };
               1                                  5   
348            1                                  8   like(
349                                                      $EVAL_ERROR,
350                                                      qr/Option x does not exist/,
351                                                      'Die trying to set() nonexistent short opt'
352                                                   );
353                                                   
354                                                   # got()
355            1                                  8   @ARGV = qw(--port 12345);
356            1                                  5   $o->get_opts();
357            1                                  6   is(
358                                                      $o->got('port'),
359                                                      1,
360                                                      'Got long opt'
361                                                   );
362            1                                  6   is(
363                                                      $o->got('p'),
364                                                      1,
365                                                      'Got short opt'
366                                                   );
367            1                                  6   is(
368                                                      $o->got('database'),
369                                                      0,
370                                                      'Did not "got" long opt'
371                                                   );
372            1                                  6   is(
373                                                      $o->got('D'),
374                                                      0,
375                                                      'Did not "got" short opt'
376                                                   );
377                                                   
378            1                                  3   eval { $o->got('foo'); };
               1                                  5   
379            1                                 10   like(
380                                                      $EVAL_ERROR,
381                                                      qr/Option foo does not exist/,
382                                                      'Die trying to got() nonexistent long opt',
383                                                   );
384            1                                  7   eval { $o->got('x'); };
               1                                  6   
385            1                                  7   like(
386                                                      $EVAL_ERROR,
387                                                      qr/Option x does not exist/,
388                                                      'Die trying to got() nonexistent short opt',
389                                                   );
390                                                   
391            1                                  8   @ARGV = qw(--bar);
392            1                                  2   eval {
393            1                                  7      local *STDERR;
394            1                                 40      open STDERR, '>', '/dev/null';
395            1                                  6      $o->get_opts();
396            1                                  5      $o->get('bar');
397                                                   };
398            1                                 10   like(
399                                                      $EVAL_ERROR,
400                                                      qr/Option bar does not exist/,
401                                                      'Ignore nonexistent opt given on cmd line'
402                                                   );
403                                                   
404            1                                  8   @ARGV = qw(--port 12345);
405            1                                  6   $o->get_opts();
406            1                                  5   is_deeply(
407                                                      $o->errors(),
408                                                      [],
409                                                      'get_opts() resets errors'
410                                                   );
411                                                   
412            1                                 10   ok(
413                                                      $o->has('D'),
414                                                      'Has short opt' 
415                                                   );
416            1                                  6   ok(
417                                                      !$o->has('X'),
418                                                      'Does not "has" nonexistent short opt'
419                                                   );
420                                                   
421                                                   # #############################################################################
422                                                   # Test hostile, broken usage.
423                                                   # #############################################################################
424            1                                  4   eval { $o->_pod_to_specs("$trunk/common/t/samples/pod/pod_sample_02.txt"); };
               1                                  8   
425            1                                 15   like(
426                                                      $EVAL_ERROR,
427                                                      qr/POD has no OPTIONS section/,
428                                                      'Dies on POD without an OPTIONS section'
429                                                   );
430                                                   
431            1                                  7   eval { $o->_pod_to_specs("$trunk/common/t/samples/pod/pod_sample_03.txt"); };
               1                                  8   
432            1                                 19   like(
433                                                      $EVAL_ERROR,
434                                                      qr/No valid specs in OPTIONS/,
435                                                      'Dies on POD with an OPTIONS section but no option items'
436                                                   );
437                                                   
438            1                                  6   eval { $o->_pod_to_specs("$trunk/common/t/samples/pod/pod_sample_04.txt"); };
               1                                  6   
439            1                                 10   like(
440                                                      $EVAL_ERROR,
441                                                      qr/No description after option spec foo/,
442                                                      'Dies on option with no description'
443                                                   );
444                                                   
445                                                   # TODO: more hostile tests: duplicate opts, can't parse long opt from spec,
446                                                   # unrecognized rules, ...
447                                                   
448                                                   # #############################################################################
449                                                   # Test option defaults.
450                                                   # #############################################################################
451            1                                 13   $o = new OptionParser(
452                                                      description  => 'parses command line options.',
453                                                      prompt       => '[OPTIONS]',
454                                                   );
455                                                   # These are dog opt specs. They're used by other tests below.
456            1                                 34   $o->_parse_specs(
457                                                      {
458                                                         spec => 'defaultset!',
459                                                         desc => 'alignment test with a very long thing '
460                                                               . 'that is longer than 80 characters wide '
461                                                               . 'and must be wrapped'
462                                                      },
463                                                      { spec => 'defaults-file|F=s', desc => 'alignment test'  },
464                                                      { spec => 'dog|D=s',           desc => 'Dogs are fun'    },
465                                                      { spec => 'foo!',              desc => 'Foo'             },
466                                                      { spec => 'love|l+',           desc => 'And peace'       },
467                                                   );
468                                                   
469            1                                  6   is_deeply(
470                                                      $o->get_defaults(),
471                                                      {},
472                                                      'No default defaults',
473                                                   );
474                                                   
475            1                                 10   $o->set_defaults(foo => 1);
476            1                                  6   is_deeply(
477                                                      $o->get_defaults(),
478                                                      {
479                                                         foo => 1,
480                                                      },
481                                                      'set_defaults() with values'
482                                                   );
483                                                   
484            1                                  9   $o->set_defaults();
485            1                                  5   is_deeply(
486                                                      $o->get_defaults(),
487                                                      {},
488                                                      'set_defaults() without values unsets defaults'
489                                                   );
490                                                   
491                                                   # We've already tested opt spec parsing,
492                                                   # but we do it again for thoroughness.
493            1                                 11   %opts = $o->opts();
494            1                                 42   is_deeply(
495                                                      \%opts,
496                                                      {
497                                                         'foo'           => {
498                                                            spec           => 'foo!',
499                                                            desc           => 'Foo',
500                                                            group          => 'default',
501                                                            long           => 'foo',
502                                                            short          => undef,
503                                                            is_cumulative  => 0,
504                                                            is_negatable   => 1,
505                                                            is_required    => 0,
506                                                            type           => undef,
507                                                            got            => 0,
508                                                            value          => undef,
509                                                         },
510                                                         'defaultset'    => {
511                                                            spec           => 'defaultset!',
512                                                            desc           => 'alignment test with a very long thing '
513                                                                            . 'that is longer than 80 characters wide '
514                                                                            . 'and must be wrapped',
515                                                            group          => 'default',
516                                                            long           => 'defaultset',
517                                                            short          => undef,
518                                                            is_cumulative  => 0,
519                                                            is_negatable   => 1,
520                                                            is_required    => 0,
521                                                            type           => undef,
522                                                            got            => 0,
523                                                            value          => undef,
524                                                         },
525                                                         'defaults-file' => {
526                                                            spec           => 'defaults-file|F=s',
527                                                            desc           => 'alignment test',
528                                                            group          => 'default',
529                                                            long           => 'defaults-file',
530                                                            short          => 'F',
531                                                            is_cumulative  => 0,
532                                                            is_negatable   => 0,
533                                                            is_required    => 0,
534                                                            type           => 's',
535                                                            got            => 0,
536                                                            value          => undef,
537                                                         },
538                                                         'dog'           => {
539                                                            spec           => 'dog|D=s',
540                                                            desc           => 'Dogs are fun',
541                                                            group          => 'default',
542                                                            long           => 'dog',
543                                                            short          => 'D',
544                                                            is_cumulative  => 0,
545                                                            is_negatable   => 0,
546                                                            is_required    => 0,
547                                                            type           => 's',
548                                                            got            => 0,
549                                                            value          => undef,
550                                                         },
551                                                         'love'          => {
552                                                            spec           => 'love|l+',
553                                                            desc           => 'And peace',
554                                                            group          => 'default',
555                                                            long           => 'love',
556                                                            short          => 'l',
557                                                            is_cumulative  => 1,
558                                                            is_negatable   => 0,
559                                                            is_required    => 0,
560                                                            type           => undef,
561                                                            got            => 0,
562                                                            value          => undef,
563                                                         },
564                                                      },
565                                                      'Parse dog specs'
566                                                   );
567                                                   
568            1                                 17   $o->set_defaults('dog' => 'fido');
569                                                   
570            1                                  4   @ARGV = ();
571            1                                  6   $o->get_opts();
572            1                                  7   is(
573                                                      $o->get('dog'),
574                                                      'fido',
575                                                      'Opt gets default value'
576                                                   );
577            1                                  9   is(
578                                                      $o->got('dog'),
579                                                      0,
580                                                      'Did not "got" opt with default value'
581                                                   );
582                                                   
583            1                                  7   @ARGV = qw(--dog rover);
584            1                                  6   $o->get_opts();
585            1                                  8   is(
586                                                      $o->get('dog'),
587                                                      'rover',
588                                                      'Value given on cmd line overrides default value'
589                                                   );
590                                                   
591            1                                  5   eval { $o->set_defaults('bone' => 1) };
               1                                  8   
592            1                                 13   like(
593                                                      $EVAL_ERROR,
594                                                      qr/Cannot set default for nonexistent option bone/,
595                                                      'Cannot set default for nonexistent option'
596                                                   );
597                                                   
598                                                   # #############################################################################
599                                                   # Test option attributes negatable and cumulative.
600                                                   # #############################################################################
601                                                   
602                                                   # These tests use the dog opt specs from above.
603                                                   
604            1                                 12   @ARGV = qw(--nofoo);
605            1                                  7   $o->get_opts();
606            1                                  8   is(
607                                                      $o->get('foo'),
608                                                      0,
609                                                      'Can negate negatable opt like --nofoo'
610                                                   );
611                                                   
612            1                                  7   @ARGV = qw(--no-foo);
613            1                                  7   $o->get_opts();
614            1                                  7   is(
615                                                      $o->get('foo'),
616                                                      0,
617                                                      'Can negate negatable opt like --no-foo'
618                                                   );
619                                                   
620            1                                  7   @ARGV = qw(--nodog);
621                                                   {
622            1                                  3      local *STDERR;
               1                                  5   
623            1                                 45      open STDERR, '>', '/dev/null';
624            1                                  7      $o->get_opts();
625                                                   }
626                                                   is_deeply(
627            1                                 20      $o->get('dog'),
628                                                      undef,
629                                                      'Cannot negate non-negatable opt'
630                                                   );
631            1                                 13   is_deeply(
632                                                      $o->errors(),
633                                                      ['Error parsing options'],
634                                                      'Trying to negate non-negatable opt sets an error'
635                                                   );
636                                                   
637            1                                 10   @ARGV = ();
638            1                                  7   $o->get_opts();
639            1                                  8   is(
640                                                      $o->get('love'),
641                                                      0,
642                                                      'Cumulative defaults to 0 when not given'
643                                                   );
644                                                   
645            1                                  8   @ARGV = qw(--love -l -l);
646            1                                  7   $o->get_opts();
647            1                                  8   is(
648                                                      $o->get('love'),
649                                                      3,
650                                                      'Cumulative opt val increases (--love -l -l)'
651                                                   );
652            1                                  8   is(
653                                                      $o->got('love'),
654                                                      1,
655                                                      "got('love') when given multiple times short and long"
656                                                   );
657                                                   
658            1                                  7   @ARGV = qw(--love);
659            1                                  7   $o->get_opts();
660            1                                  8   is(
661                                                      $o->got('love'),
662                                                      1,
663                                                      "got('love') long once"
664                                                   );
665                                                   
666            1                                  6   @ARGV = qw(-l);
667            1                                  7   $o->get_opts();
668            1                                  8   is(
669                                                      $o->got('l'),
670                                                      1,
671                                                      "got('l') short once"
672                                                   );
673                                                   
674                                                   # #############################################################################
675                                                   # Test usage output.
676                                                   # #############################################################################
677                                                   
678                                                   # The following one test uses the dog opt specs from above.
679                                                   
680                                                   # Clear values from previous tests.
681            1                                  9   $o->set_defaults();
682            1                                  5   @ARGV = ();
683            1                                  7   $o->get_opts();
684                                                   
685            1                                 14   is(
686                                                      $o->print_usage(),
687                                                   <<EOF
688                                                   OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
689                                                   Usage: $PROGRAM_NAME [OPTIONS]
690                                                   
691                                                   Options:
692                                                   
693                                                     --defaults-file -F  alignment test
694                                                     --[no]defaultset    alignment test with a very long thing that is longer than
695                                                                         80 characters wide and must be wrapped
696                                                     --dog           -D  Dogs are fun
697                                                     --[no]foo           Foo
698                                                     --love          -l  And peace
699                                                   
700                                                   Options and values after processing arguments:
701                                                   
702                                                     --defaults-file     (No value)
703                                                     --defaultset        FALSE
704                                                     --dog               (No value)
705                                                     --foo               FALSE
706                                                     --love              0
707                                                   EOF
708                                                   ,
709                                                      'Options aligned and custom prompt included'
710                                                   );
711                                                   
712            1                                 13   $o = new OptionParser(
713                                                      description  => 'parses command line options.',
714                                                   );
715            1                                 30   $o->_parse_specs(
716                                                      { spec => 'database|D=s',    desc => 'Specify the database for all tables' },
717                                                      { spec => 'nouniquechecks!', desc => 'Set UNIQUE_CHECKS=0 before LOAD DATA INFILE' },
718                                                   );
719            1                                  8   $o->get_opts();
720            1                                  8   is(
721                                                      $o->print_usage(),
722                                                   <<EOF
723                                                   OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
724                                                   Usage: $PROGRAM_NAME <options>
725                                                   
726                                                   Options:
727                                                   
728                                                     --database        -D  Specify the database for all tables
729                                                     --[no]nouniquechecks  Set UNIQUE_CHECKS=0 before LOAD DATA INFILE
730                                                   
731                                                   Options and values after processing arguments:
732                                                   
733                                                     --database            (No value)
734                                                     --nouniquechecks      FALSE
735                                                   EOF
736                                                   ,
737                                                      'Really long option aligns with shorts, and prompt defaults to <options>'
738                                                   );
739                                                   
740                                                   # #############################################################################
741                                                   # Test _get_participants()
742                                                   # #############################################################################
743            1                                  9   $o = new OptionParser(
744                                                      description  => 'parses command line options.',
745                                                   );
746            1                                 30   $o->_parse_specs(
747                                                      { spec => 'foo',      desc => 'opt' },
748                                                      { spec => 'bar-bar!', desc => 'opt' },
749                                                      { spec => 'baz',      desc => 'opt' },
750                                                   );
751            1                                  8   is_deeply(
752                                                      [ $o->_get_participants('L<"--foo"> disables --bar-bar and C<--baz>') ],
753                                                      [qw(foo bar-bar baz)],
754                                                      'Extract option names from a string',
755                                                   );
756                                                   
757            1                                 16   is_deeply(
758                                                      [ $o->_get_participants('L<"--foo"> disables L<"--[no]bar-bar">.') ],
759                                                      [qw(foo bar-bar)],
760                                                      'Extract [no]-negatable option names from a string',
761                                                   );
762                                                   # TODO: test w/ opts that don't exist, or short opts
763                                                   
764                                                   # #############################################################################
765                                                   # Test required options.
766                                                   # #############################################################################
767            1                                 15   $o = new OptionParser(
768                                                      description  => 'parses command line options.',
769                                                   );
770            1                                 27   $o->_parse_specs(
771                                                      { spec => 'cat|C=s', desc => 'How to catch the cat; required' }
772                                                   );
773                                                   
774            1                                  5   @ARGV = ();
775            1                                  7   $o->get_opts();
776            1                                  7   is_deeply(
777                                                      $o->errors(),
778                                                      ['Required option --cat must be specified'],
779                                                      'Missing required option sets an error',
780                                                   );
781                                                   
782            1                                 20   is(
783                                                      $o->print_errors(),
784                                                   "Usage: $PROGRAM_NAME <options>
785                                                   
786                                                   Errors in command-line arguments:
787                                                     * Required option --cat must be specified
788                                                   
789                                                   OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.",
790                                                      'Error output includes note about missing required option'
791                                                   );
792                                                   
793            1                                  7   @ARGV = qw(--cat net);
794            1                                  8   $o->get_opts();
795            1                                  7   is(
796                                                      $o->get('cat'),
797                                                      'net',
798                                                      'Required option OK',
799                                                   );
800                                                   
801                                                   # #############################################################################
802                                                   # Test option rules.
803                                                   # #############################################################################
804            1                                  9   $o = new OptionParser(
805                                                      description  => 'parses command line options.',
806                                                   );
807            1                                 29   $o->_parse_specs(
808                                                      { spec => 'ignore|i',  desc => 'Use IGNORE for INSERT statements'         },
809                                                      { spec => 'replace|r', desc => 'Use REPLACE instead of INSERT statements' },
810                                                      '--ignore and --replace are mutually exclusive.',
811                                                   );
812                                                   
813            1                                  7   $o->get_opts();
814            1                                  8   is(
815                                                      $o->print_usage(),
816                                                   <<EOF
817                                                   OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
818                                                   Usage: $PROGRAM_NAME <options>
819                                                   
820                                                   Options:
821                                                   
822                                                     --ignore  -i  Use IGNORE for INSERT statements
823                                                     --replace -r  Use REPLACE instead of INSERT statements
824                                                   
825                                                   Rules:
826                                                   
827                                                     --ignore and --replace are mutually exclusive.
828                                                   
829                                                   Options and values after processing arguments:
830                                                   
831                                                     --ignore      FALSE
832                                                     --replace     FALSE
833                                                   EOF
834                                                   ,
835                                                      'Usage with rules'
836                                                   );
837                                                   
838            1                                  7   @ARGV = qw(--replace);
839            1                                  7   $o->get_opts();
840            1                                  8   is_deeply(
841                                                      $o->errors(),
842                                                      [],
843                                                      '--replace does not trigger an error',
844                                                   );
845                                                   
846            1                                 17   @ARGV = qw(--ignore --replace);
847            1                                  9   $o->get_opts();
848            1                                  5   is_deeply(
849                                                      $o->errors(),
850                                                      ['--ignore and --replace are mutually exclusive.'],
851                                                      'Error set when rule violated',
852                                                   );
853                                                   
854                                                   # These are used several times in the follow tests.
855            1                                 16   my @ird_specs = (
856                                                      { spec => 'ignore|i',   desc => 'Use IGNORE for INSERT statements'         },
857                                                      { spec => 'replace|r',  desc => 'Use REPLACE instead of INSERT statements' },
858                                                      { spec => 'delete|d',   desc => 'Delete'                                   },
859                                                   );
860                                                   
861            1                                  7   $o = new OptionParser(
862                                                      description  => 'parses command line options.',
863                                                   );
864            1                                 25   $o->_parse_specs(
865                                                      @ird_specs,
866                                                      '--ignore, --replace and --delete are mutually exclusive.',
867                                                   );
868            1                                  4   @ARGV = qw(--ignore --replace);
869            1                                  6   $o->get_opts();
870            1                                  5   is_deeply(
871                                                      $o->errors(),
872                                                      ['--ignore, --replace and --delete are mutually exclusive.'],
873                                                      'Error set with long opt name and nice commas when rule violated',
874                                                   );
875                                                   
876            1                                 12   $o = new OptionParser(
877                                                      description  => 'parses command line options.',
878                                                   );
879            1                                 15   eval {
880            1                                  6      $o->_parse_specs(
881                                                         @ird_specs,
882                                                        'Use one and only one of --insert, --replace, or --delete.',
883                                                      );
884                                                   };
885            1                                 11   like(
886                                                      $EVAL_ERROR,
887                                                      qr/Option --insert does not exist/,
888                                                      'Die on using nonexistent option in one-and-only-one rule'
889                                                   );
890                                                   
891            1                                 11   $o = new OptionParser(
892                                                      description  => 'parses command line options.',
893                                                   );
894            1                                 14   $o->_parse_specs(
895                                                      @ird_specs,
896                                                      'Use one and only one of --ignore, --replace, or --delete.',
897                                                   );
898            1                                  4   @ARGV = qw(--ignore --replace);
899            1                                  6   $o->get_opts();
900            1                                 11   is_deeply(
901                                                      $o->errors(),
902                                                      ['--ignore, --replace and --delete are mutually exclusive.'],
903                                                      'Error set with one-and-only-one rule violated',
904                                                   );
905                                                   
906            1                                 12   $o = new OptionParser(
907                                                      description  => 'parses command line options.',
908                                                   );
909            1                                 17   $o->_parse_specs(
910                                                      @ird_specs,
911                                                      'Use one and only one of --ignore, --replace, or --delete.',
912                                                   );
913            1                                  4   @ARGV = ();
914            1                                  6   $o->get_opts();
915            1                                  5   is_deeply(
916                                                      $o->errors(),
917                                                      ['Specify at least one of --ignore, --replace or --delete'],
918                                                      'Error set with one-and-only-one when none specified',
919                                                   );
920                                                   
921            1                                 11   $o = new OptionParser(
922                                                      description  => 'parses command line options.',
923                                                   );
924            1                                 16   $o->_parse_specs(
925                                                      @ird_specs,
926                                                      'Use at least one of --ignore, --replace, or --delete.',
927                                                   );
928            1                                 13   @ARGV = ();
929            1                                  5   $o->get_opts();
930            1                                  5   is_deeply(
931                                                      $o->errors(),
932                                                      ['Specify at least one of --ignore, --replace or --delete'],
933                                                      'Error set with at-least-one when none specified',
934                                                   );
935                                                   
936            1                                 10   $o = new OptionParser(
937                                                      description  => 'parses command line options.',
938                                                   );
939            1                                 16   $o->_parse_specs(
940                                                      @ird_specs,
941                                                      'Use at least one of --ignore, --replace, or --delete.',
942                                                   );
943            1                                  5   @ARGV = qw(-ir);
944            1                                  6   $o->get_opts();
945   ***      1            33                    6   ok(
946                                                      $o->get('ignore') == 1 && $o->get('replace') == 1,
947                                                      'Multiple options OK for at-least-one',
948                                                   );
949            1                    1             8   use Data::Dumper;
               1                                  3   
               1                                  6   
950            1                                 11   $Data::Dumper::Indent=1;
951            1                                 12   $o = new OptionParser(
952                                                      description  => 'parses command line options.',
953                                                   );
954            1                                 20   $o->_parse_specs(
955                                                      { spec => 'foo=i', desc => 'Foo disables --bar'   },
956                                                      { spec => 'bar',   desc => 'Bar (default 1)'      },
957                                                   );
958            1                                  5   @ARGV = qw(--foo 5);
959            1                                  5   $o->get_opts();
960            1                                  6   is_deeply(
961                                                      [ $o->get('foo'),  $o->get('bar') ],
962                                                      [ 5, undef ],
963                                                      '--foo disables --bar',
964                                                   );
965            1                                 12   %opts = $o->opts();
966            1                                 13   is_deeply(
967                                                      $opts{'bar'},
968                                                      {
969                                                         spec          => 'bar',
970                                                         is_required   => 0,
971                                                         value         => undef,
972                                                         is_cumulative => 0,
973                                                         short         => undef,
974                                                         group         => 'default',
975                                                         got           => 0,
976                                                         is_negatable  => 0,
977                                                         desc          => 'Bar (default 1)',
978                                                         long          => 'bar',
979                                                         type          => undef,
980                                                         parsed        => 1,
981                                                      },
982                                                      'Disabled opt is not destroyed'
983                                                   );
984                                                   
985                                                   # Option can't disable a nonexistent option.
986            1                                 14   $o = new OptionParser(
987                                                      description  => 'parses command line options.',
988                                                   );
989            1                                 14   eval {
990            1                                  9      $o->_parse_specs(
991                                                         { spec => 'foo=i', desc => 'Foo disables --fox' },
992                                                         { spec => 'bar',   desc => 'Bar (default 1)'    },
993                                                      );
994                                                   };
995            1                                 11   like(
996                                                      $EVAL_ERROR,
997                                                      qr/Option --fox does not exist/,
998                                                      'Invalid option name in disable rule',
999                                                   );
1000                                                  
1001                                                  # Option can't 'allowed with' a nonexistent option.
1002           1                                 10   $o = new OptionParser(
1003                                                     description  => 'parses command line options.',
1004                                                  );
1005           1                                 15   eval {
1006           1                                  9      $o->_parse_specs(
1007                                                        { spec => 'foo=i', desc => 'Foo disables --bar' },
1008                                                        { spec => 'bar',   desc => 'Bar (default 0)'    },
1009                                                        'allowed with --foo: --fox',
1010                                                     );
1011                                                  };
1012           1                                  9   like(
1013                                                     $EVAL_ERROR,
1014                                                     qr/Option --fox does not exist/,
1015                                                     'Invalid option name in \'allowed with\' rule',
1016                                                  );
1017                                                  
1018                                                  # #############################################################################
1019                                                  # Test default values encoded in description.
1020                                                  # #############################################################################
1021           1                                 10   $o = new OptionParser(
1022                                                     description  => 'parses command line options.',
1023                                                  );
1024                                                  # Hack DSNParser into OptionParser.  This is just for testing.
1025           1                                 15   $o->{DSNParser} = $dp;
1026                                                  
1027           1                                 14   $o->_parse_specs(
1028                                                     { spec => 'foo=i',   desc => 'Foo (default 5)'                 },
1029                                                     { spec => 'bar',     desc => 'Bar (default)'                   },
1030                                                     { spec => 'price=f', desc => 'Price (default 12345.123456)'    },
1031                                                     { spec => 'size=z',  desc => 'Size (default 128M)'             },
1032                                                     { spec => 'time=m',  desc => 'Time (default 24h)'              },
1033                                                     { spec => 'host=d',  desc => 'Host (default h=127.1,P=12345)'  },
1034                                                  );
1035           1                                  4   @ARGV = ();
1036           1                                  6   $o->get_opts();
1037           1                                  5   is(
1038                                                     $o->get('foo'),
1039                                                     5,
1040                                                     'Default integer value encoded in description'
1041                                                  );
1042           1                                  6   is(
1043                                                     $o->get('bar'),
1044                                                     1,
1045                                                     'Default option enabled encoded in description'
1046                                                  );
1047           1                                  7   is(
1048                                                     $o->get('price'),
1049                                                     12345.123456,
1050                                                     'Default float value encoded in description'
1051                                                  );
1052           1                                  7   is(
1053                                                     $o->get('size'),
1054                                                     134217728,
1055                                                     'Default size value encoded in description'
1056                                                  );
1057           1                                  6   is(
1058                                                     $o->get('time'),
1059                                                     86400,
1060                                                     'Default time value encoded in description'
1061                                                  );
1062           1                                  6   is_deeply(
1063                                                     $o->get('host'),
1064                                                     {
1065                                                        S => undef,
1066                                                        F => undef,
1067                                                        A => undef,
1068                                                        p => undef,
1069                                                        u => undef,
1070                                                        h => '127.1',
1071                                                        D => undef,
1072                                                        P => '12345'
1073                                                     },
1074                                                     'Default host value encoded in description'
1075                                                  );
1076                                                  
1077           1                                 11   is(
1078                                                     $o->got('foo'),
1079                                                     0,
1080                                                     'Did not "got" --foo with encoded default'
1081                                                  );
1082           1                                  7   is(
1083                                                     $o->got('bar'),
1084                                                     0,
1085                                                     'Did not "got" --bar with encoded default'
1086                                                  );
1087           1                                  7   is(
1088                                                     $o->got('price'),
1089                                                     0,
1090                                                     'Did not "got" --price with encoded default'
1091                                                  );
1092           1                                  6   is(
1093                                                     $o->got('size'),
1094                                                     0,
1095                                                     'Did not "got" --size with encoded default'
1096                                                  );
1097           1                                  6   is(
1098                                                     $o->got('time'),
1099                                                     0,
1100                                                     'Did not "got" --time with encoded default'
1101                                                  );
1102           1                                  6   is(
1103                                                     $o->got('host'),
1104                                                     0,
1105                                                     'Did not "got" --host with encoded default'
1106                                                  );
1107                                                  
1108                                                  # #############################################################################
1109                                                  # Test size option type.
1110                                                  # #############################################################################
1111           1                                  7   $o = new OptionParser(
1112                                                     description  => 'parses command line options.',
1113                                                  );
1114           1                                 35   $o->_parse_specs(
1115                                                     { spec => 'size=z', desc => 'size' }
1116                                                  );
1117                                                  
1118           1                                  5   @ARGV = qw(--size 5k);
1119           1                                  5   $o->get_opts();
1120           1                                  7   is_deeply(
1121                                                     $o->get('size'),
1122                                                     1024*5,
1123                                                     '5K expanded',
1124                                                  );
1125                                                  
1126           1                                  9   @ARGV = qw(--size -5k);
1127           1                                  6   $o->get_opts();
1128           1                                 44   is_deeply(
1129                                                     $o->get('size'),
1130                                                     -1024*5,
1131                                                     '-5K expanded',
1132                                                  );
1133                                                  
1134           1                                  9   @ARGV = qw(--size +5k);
1135           1                                  5   $o->get_opts();
1136           1                                  5   is_deeply(
1137                                                     $o->get('size'),
1138                                                     '+' . (1024*5),
1139                                                     '+5K expanded',
1140                                                  );
1141                                                  
1142           1                                  9   @ARGV = qw(--size 5);
1143           1                                  6   $o->get_opts();
1144           1                                  6   is_deeply(
1145                                                     $o->get('size'),
1146                                                     5,
1147                                                     '5 expanded',
1148                                                  );
1149                                                  
1150           1                                  9   @ARGV = qw(--size 5z);
1151           1                                  5   $o->get_opts();
1152           1                                  6   is_deeply(
1153                                                     $o->errors(),
1154                                                     ['Invalid size for --size'],
1155                                                     'Bad size argument sets an error',
1156                                                  );
1157                                                  
1158                                                  # #############################################################################
1159                                                  # Test time option type.
1160                                                  # #############################################################################
1161           1                                 12   $o = new OptionParser(
1162                                                     description  => 'parses command line options.',
1163                                                  );
1164           1                                 27   $o->_parse_specs(
1165                                                     { spec => 't=m', desc => 'Time'            },
1166                                                     { spec => 's=m', desc => 'Time (suffix s)' },
1167                                                     { spec => 'm=m', desc => 'Time (suffix m)' },
1168                                                     { spec => 'h=m', desc => 'Time (suffix h)' },
1169                                                     { spec => 'd=m', desc => 'Time (suffix d)' },
1170                                                  );
1171                                                  
1172           1                                  8   @ARGV = qw(-t 10 -s 20 -m 30 -h 40 -d 50);
1173           1                                  5   $o->get_opts();
1174           1                                  6   is_deeply(
1175                                                     $o->get('t'),
1176                                                     10,
1177                                                     'Time value with default suffix decoded',
1178                                                  );
1179           1                                 10   is_deeply(
1180                                                     $o->get('s'),
1181                                                     20,
1182                                                     'Time value with s suffix decoded',
1183                                                  );
1184           1                                  9   is_deeply(
1185                                                     $o->get('m'),
1186                                                     30*60,
1187                                                     'Time value with m suffix decoded',
1188                                                  );
1189           1                                 10   is_deeply(
1190                                                     $o->get('h'),
1191                                                     40*3600,
1192                                                     'Time value with h suffix decoded',
1193                                                  );
1194           1                                 10   is_deeply(
1195                                                     $o->get('d'),
1196                                                     50*86400,
1197                                                     'Time value with d suffix decoded',
1198                                                  );
1199                                                  
1200           1                                  7   @ARGV = qw(-d 5m);
1201           1                                  6   $o->get_opts();
1202           1                                  5   is_deeply(
1203                                                     $o->get('d'),
1204                                                     5*60,
1205                                                     'Explicit suffix overrides default suffix'
1206                                                  );
1207                                                  
1208                                                  # Use shorter, simpler specs to test usage for time blurb.
1209           1                                 10   $o = new OptionParser(
1210                                                     description  => 'parses command line options.',
1211                                                  );
1212           1                                 30   $o->_parse_specs(
1213                                                     { spec => 'foo=m', desc => 'Time' },
1214                                                     { spec => 'bar=m', desc => 'Time (suffix m)' },
1215                                                  );
1216           1                                  6   $o->get_opts();
1217           1                                  7   is(
1218                                                     $o->print_usage(),
1219                                                  <<EOF
1220                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1221                                                  Usage: $PROGRAM_NAME <options>
1222                                                  
1223                                                  Options:
1224                                                  
1225                                                    --bar  Time.  Optional suffix s=seconds, m=minutes, h=hours, d=days; if no
1226                                                           suffix, m is used.
1227                                                    --foo  Time.  Optional suffix s=seconds, m=minutes, h=hours, d=days; if no
1228                                                           suffix, s is used.
1229                                                  
1230                                                  Options and values after processing arguments:
1231                                                  
1232                                                    --bar  (No value)
1233                                                    --foo  (No value)
1234                                                  EOF
1235                                                  ,
1236                                                     'Usage for time value');
1237                                                  
1238           1                                  6   @ARGV = qw(--foo 5z);
1239           1                                  6   $o->get_opts();
1240           1                                  6   is_deeply(
1241                                                     $o->errors(),
1242                                                     ['Invalid time suffix for --foo'],
1243                                                     'Bad time argument sets an error',
1244                                                  );
1245                                                  
1246                                                  # #############################################################################
1247                                                  # Test DSN option type.
1248                                                  # #############################################################################
1249           1                                 12   $o = new OptionParser(
1250                                                     description  => 'parses command line options.',
1251                                                  );
1252                                                  # Hack DSNParser into OptionParser.  This is just for testing.
1253           1                                 18   $o->{DSNParser} = $dp;
1254           1                                 10   $o->_parse_specs(
1255                                                     { spec => 'foo=d', desc => 'DSN foo' },
1256                                                     { spec => 'bar=d', desc => 'DSN bar' },
1257                                                     'DSN values in --foo default to values in --bar if COPY is yes.',
1258                                                  );
1259           1                                  5   $o->get_opts();
1260           1                                  6   is(
1261                                                     $o->print_usage(),
1262                                                  <<EOF
1263                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1264                                                  Usage: $PROGRAM_NAME <options>
1265                                                  
1266                                                  Options:
1267                                                  
1268                                                    --bar  DSN bar
1269                                                    --foo  DSN foo
1270                                                  
1271                                                  Rules:
1272                                                  
1273                                                    DSN values in --foo default to values in --bar if COPY is yes.
1274                                                  
1275                                                  DSN syntax is key=value[,key=value...]  Allowable DSN keys:
1276                                                  
1277                                                    KEY  COPY  MEANING
1278                                                    ===  ====  =============================================
1279                                                    A    yes   Default character set
1280                                                    D    yes   Database to use
1281                                                    F    yes   Only read default options from the given file
1282                                                    P    yes   Port number to use for connection
1283                                                    S    yes   Socket file to use for connection
1284                                                    h    yes   Connect to host
1285                                                    p    yes   Password to use when connecting
1286                                                    u    yes   User for login if not current user
1287                                                  
1288                                                    If the DSN is a bareword, the word is treated as the 'h' key.
1289                                                  
1290                                                  Options and values after processing arguments:
1291                                                  
1292                                                    --bar  (No value)
1293                                                    --foo  (No value)
1294                                                  EOF
1295                                                  ,
1296                                                     'DSN is integrated into help output'
1297                                                  );
1298                                                  
1299           1                                  7   @ARGV = ('--bar', 'D=DB,u=USER,h=localhost', '--foo', 'h=otherhost');
1300           1                                  5   $o->get_opts();
1301           1                                  6   is_deeply(
1302                                                     $o->get('bar'),
1303                                                     {
1304                                                        D => 'DB',
1305                                                        u => 'USER',
1306                                                        S => undef,
1307                                                        F => undef,
1308                                                        P => undef,
1309                                                        h => 'localhost',
1310                                                        p => undef,
1311                                                        A => undef,
1312                                                     },
1313                                                     'DSN parsing on type=d',
1314                                                  );
1315           1                                 12   is_deeply(
1316                                                     $o->get('foo'),
1317                                                     {
1318                                                        D => 'DB',
1319                                                        u => 'USER',
1320                                                        S => undef,
1321                                                        F => undef,
1322                                                        P => undef,
1323                                                        h => 'otherhost',
1324                                                        p => undef,
1325                                                        A => undef,
1326                                                     },
1327                                                     'DSN parsing on type=d inheriting from --bar',
1328                                                  );
1329                                                  
1330           1                                 12   is(
1331                                                     $o->print_usage(),
1332                                                  <<EOF
1333                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1334                                                  Usage: $PROGRAM_NAME <options>
1335                                                  
1336                                                  Options:
1337                                                  
1338                                                    --bar  DSN bar
1339                                                    --foo  DSN foo
1340                                                  
1341                                                  Rules:
1342                                                  
1343                                                    DSN values in --foo default to values in --bar if COPY is yes.
1344                                                  
1345                                                  DSN syntax is key=value[,key=value...]  Allowable DSN keys:
1346                                                  
1347                                                    KEY  COPY  MEANING
1348                                                    ===  ====  =============================================
1349                                                    A    yes   Default character set
1350                                                    D    yes   Database to use
1351                                                    F    yes   Only read default options from the given file
1352                                                    P    yes   Port number to use for connection
1353                                                    S    yes   Socket file to use for connection
1354                                                    h    yes   Connect to host
1355                                                    p    yes   Password to use when connecting
1356                                                    u    yes   User for login if not current user
1357                                                  
1358                                                    If the DSN is a bareword, the word is treated as the 'h' key.
1359                                                  
1360                                                  Options and values after processing arguments:
1361                                                  
1362                                                    --bar  D=DB,h=localhost,u=USER
1363                                                    --foo  D=DB,h=otherhost,u=USER
1364                                                  EOF
1365                                                  ,
1366                                                     'DSN stringified with inheritance into post-processed args'
1367                                                  );
1368                                                  
1369           1                                  8   $o = new OptionParser(
1370                                                     description  => 'parses command line options.',
1371                                                  );
1372                                                  # Hack DSNParser into OptionParser.  This is just for testing.
1373           1                                 21   $o->{DSNParser} = $dp;
1374                                                  
1375           1                                 10   $o->_parse_specs(
1376                                                     { spec => 'foo|f=d', desc => 'DSN foo' },
1377                                                     { spec => 'bar|b=d', desc => 'DSN bar' },
1378                                                     'DSN values in --foo default to values in --bar if COPY is yes.',
1379                                                  );
1380           1                                  5   @ARGV = ('-b', 'D=DB,u=USER,h=localhost', '-f', 'h=otherhost');
1381           1                                  6   $o->get_opts();
1382           1                                  6   is_deeply(
1383                                                     $o->get('f'),
1384                                                     {
1385                                                        D => 'DB',
1386                                                        u => 'USER',
1387                                                        S => undef,
1388                                                        F => undef,
1389                                                        P => undef,
1390                                                        h => 'otherhost',
1391                                                        p => undef,
1392                                                        A => undef,
1393                                                     },
1394                                                     'DSN parsing on type=d inheriting from --bar with short options',
1395                                                  );
1396                                                  
1397                                                  # #############################################################################
1398                                                  # Test [Hh]ash and [Aa]rray option types.
1399                                                  # #############################################################################
1400           1                                 12   $o = new OptionParser(
1401                                                     description  => 'parses command line options.',
1402                                                  );
1403           1                                 30   $o->_parse_specs(
1404                                                     { spec => 'columns|C=H',   desc => 'cols required'       },
1405                                                     { spec => 'tables|t=h',    desc => 'tables optional'     },
1406                                                     { spec => 'databases|d=A', desc => 'databases required'  },
1407                                                     { spec => 'books|b=a',     desc => 'books optional'      },
1408                                                     { spec => 'foo=A',         desc => 'foo (default a,b,c)' },
1409                                                  );
1410                                                  
1411           1                                  3   @ARGV = ();
1412           1                                  6   $o->get_opts();
1413           1                                  5   is_deeply(
1414                                                     $o->get('C'),
1415                                                     {},
1416                                                     'required Hash'
1417                                                  );
1418           1                                  8   is_deeply(
1419                                                     $o->get('t'),
1420                                                     undef,
1421                                                     'optional hash'
1422                                                  );
1423           1                                  8   is_deeply(
1424                                                     $o->get('d'),
1425                                                     [],
1426                                                     'required Array'
1427                                                  );
1428           1                                 10   is_deeply(
1429                                                     $o->get('b'),
1430                                                     undef,
1431                                                     'optional array'
1432                                                  );
1433           1                                  8   is_deeply($o->get('foo'), [qw(a b c)], 'Array got a default');
1434                                                  
1435           1                                 11   @ARGV = ('-C', 'a,b', '-t', 'd, e', '-d', 'f,g', '-b', 'o,p' );
1436           1                                 11   $o->get_opts();
1437           1                                  6   %opts = (
1438                                                     C => $o->get('C'),
1439                                                     t => $o->get('t'),
1440                                                     d => $o->get('d'),
1441                                                     b => $o->get('b'),
1442                                                  );
1443           1                                 14   is_deeply(
1444                                                     \%opts,
1445                                                     {
1446                                                        C => { a => 1, b => 1 },
1447                                                        t => { d => 1, e => 1 },
1448                                                        d => [qw(f g)],
1449                                                        b => [qw(o p)],
1450                                                     },
1451                                                     'Comma-separated lists: all processed when given',
1452                                                  );
1453                                                  
1454           1                                 14   is(
1455                                                     $o->print_usage(),
1456                                                  <<EOF
1457                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1458                                                  Usage: $PROGRAM_NAME <options>
1459                                                  
1460                                                  Options:
1461                                                  
1462                                                    --books     -b  books optional
1463                                                    --columns   -C  cols required
1464                                                    --databases -d  databases required
1465                                                    --foo           foo (default a,b,c)
1466                                                    --tables    -t  tables optional
1467                                                  
1468                                                  Options and values after processing arguments:
1469                                                  
1470                                                    --books         o,p
1471                                                    --columns       a,b
1472                                                    --databases     f,g
1473                                                    --foo           a,b,c
1474                                                    --tables        d,e
1475                                                  EOF
1476                                                  ,
1477                                                     'Lists properly expanded into usage information',
1478                                                  );
1479                                                  
1480                                                  # #############################################################################
1481                                                  # Test groups.
1482                                                  # #############################################################################
1483                                                  
1484           1                                  7   $o = new OptionParser(
1485                                                     description  => 'parses command line options.',
1486                                                  );
1487           1                                 28   $o->get_specs("$trunk/common/t/samples/pod/pod_sample_05.txt");
1488                                                  
1489           1                                 16   is_deeply(
1490                                                     $o->get_groups(),
1491                                                     {
1492                                                        'Help'       => {
1493                                                           'explain-hosts' => 1,
1494                                                           'help'          => 1,
1495                                                           'version'       => 1,
1496                                                        },
1497                                                        'Filter'     => { 'databases'     => 1, },
1498                                                        'Output'     => { 'tab'           => 1, },
1499                                                        'Connection' => { 'defaults-file' => 1, },
1500                                                        'default'    => {
1501                                                           'algorithm' => 1,
1502                                                           'schema'    => 1,
1503                                                        }
1504                                                     },
1505                                                     'get_groups()'
1506                                                  );
1507                                                  
1508           1                                 13   @ARGV = ();
1509           1                                  6   $o->get_opts();
1510           1                                  6   is(
1511                                                     $o->print_usage(),
1512                                                  <<EOF
1513                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1514                                                  Usage: $PROGRAM_NAME <options>
1515                                                  
1516                                                  Options:
1517                                                  
1518                                                    --algorithm         Checksum algorithm (ACCUM|CHECKSUM|BIT_XOR)
1519                                                    --schema            Checksum SHOW CREATE TABLE intead of table data
1520                                                  
1521                                                  Connection:
1522                                                  
1523                                                    --defaults-file -F  Only read mysql options from the given file
1524                                                  
1525                                                  Filter:
1526                                                  
1527                                                    --databases     -d  Only checksum this comma-separated list of databases
1528                                                  
1529                                                  Help:
1530                                                  
1531                                                    --explain-hosts     Explain hosts
1532                                                    --help              Show help and exit
1533                                                    --version           Show version and exit
1534                                                  
1535                                                  Output:
1536                                                  
1537                                                    --tab               Print tab-separated output, not column-aligned output
1538                                                  
1539                                                  Rules:
1540                                                  
1541                                                    --schema is restricted to option groups Connection, Filter, Output, Help.
1542                                                  
1543                                                  Options and values after processing arguments:
1544                                                  
1545                                                    --algorithm         (No value)
1546                                                    --databases         (No value)
1547                                                    --defaults-file     (No value)
1548                                                    --explain-hosts     FALSE
1549                                                    --help              FALSE
1550                                                    --schema            FALSE
1551                                                    --tab               FALSE
1552                                                    --version           FALSE
1553                                                  EOF
1554                                                  ,
1555                                                     'Option groupings usage',
1556                                                  );
1557                                                  
1558           1                                  5   @ARGV = qw(--schema --tab);
1559           1                                  6   $o->get_opts();
1560  ***      1            33                    6   ok(
1561                                                     $o->get('schema') && $o->get('tab'),
1562                                                     'Opt allowed with opt from allowed group'
1563                                                  );
1564                                                  
1565           1                                  5   @ARGV = qw(--schema --algorithm ACCUM);
1566           1                                  5   $o->get_opts();
1567           1                                  5   is_deeply(
1568                                                     $o->errors(),
1569                                                     ['--schema is not allowed with --algorithm'],
1570                                                     'Opt is not allowed with opt from restricted group'
1571                                                  );
1572                                                  
1573                                                  # #############################################################################
1574                                                  # Test clone().
1575                                                  # #############################################################################
1576           1                                 13   $o = new OptionParser(
1577                                                     description  => 'parses command line options.',
1578                                                  );
1579           1                                 43   $o->_parse_specs(
1580                                                     { spec  => 'user=s', desc  => 'User',                         },
1581                                                     { spec  => 'dog|d',    desc  => 'dog option', group => 'Dogs',  },
1582                                                     { spec  => 'cat|c',    desc  => 'cat option', group => 'Cats',  },
1583                                                  );
1584           1                                  5   @ARGV = qw(--user foo --dog);
1585           1                                  5   $o->get_opts();
1586                                                  
1587           1                                 11   my $o_clone = $o->clone();
1588           1                                  7   isa_ok(
1589                                                     $o_clone,
1590                                                     'OptionParser'
1591                                                  );
1592  ***      1            33                   10   ok(
      ***                   33                        
1593                                                     $o_clone->has('user') && $o_clone->has('dog') && $o_clone->has('cat'),
1594                                                     'Clone has same opts'
1595                                                  );
1596                                                  
1597           1                                  6   $o_clone->set('user', 'Bob');
1598           1                                  5   is(
1599                                                     $o->get('user'),
1600                                                     'foo',
1601                                                     'Change to clone does not change original'
1602                                                  );
1603                                                  
1604                                                  # #############################################################################
1605                                                  # Test issues. Any other tests should find their proper place above.
1606                                                  # #############################################################################
1607                                                  
1608                                                  # #############################################################################
1609                                                  # Issue 140: Check that new style =item --[no]foo works like old style:
1610                                                  #    =item --foo
1611                                                  #    negatable: yes
1612                                                  # #############################################################################
1613           1                                  9   @opt_specs = $o->_pod_to_specs("$trunk/common/t/samples/pod/pod_sample_issue_140.txt");
1614           1                                 50   is_deeply(
1615                                                     \@opt_specs,
1616                                                     [
1617                                                        { spec => 'foo',   desc => 'Basic foo',         group => 'default' },
1618                                                        { spec => 'bar!',  desc => 'New negatable bar', group => 'default' },
1619                                                     ],
1620                                                     'New =item --[no]foo style for negatables'
1621                                                  );
1622                                                  
1623                                                  # #############################################################################
1624                                                  # Issue 92: extract a paragraph from POD.
1625                                                  # #############################################################################
1626           1                                 23   is(
1627                                                     $o->read_para_after("$trunk/common/t/samples/pod/pod_sample_issue_92.txt", qr/magic/),
1628                                                     'This is the paragraph, hooray',
1629                                                     'read_para_after'
1630                                                  );
1631                                                  
1632                                                  # The first time I wrote this, I used the /o flag to the regex, which means you
1633                                                  # always get the same thing on each subsequent call no matter what regex you
1634                                                  # pass in.  This is to test and make sure I don't do that again.
1635           1                                 17   is(
1636                                                     $o->read_para_after("$trunk/common/t/samples/pod/pod_sample_issue_92.txt", qr/abracadabra/),
1637                                                     'This is the next paragraph, hooray',
1638                                                     'read_para_after again'
1639                                                  );
1640                                                  
1641                                                  # #############################################################################
1642                                                  # Issue 231: read configuration files
1643                                                  # #############################################################################
1644           1                                 15   is_deeply(
1645                                                     [$o->_read_config_file("$trunk/common/t/samples/config_file_1.conf")],
1646                                                     ['--foo', 'bar', '--verbose', '/path/to/file', 'h=127.1,P=12346'],
1647                                                     'Reads a config file',
1648                                                  );
1649                                                  
1650           1                                 14   $o = new OptionParser(
1651                                                     description  => 'parses command line options.',
1652                                                  );
1653           1                                 32   $o->_parse_specs(
1654                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1655                                                              . 'files (must be the first option on the command line).',  },
1656                                                     { spec  => 'cat=A',    desc  => 'cat option (default a,b)',  },
1657                                                  );
1658                                                  
1659           1                                  5   is_deeply(
1660                                                     [$o->get_defaults_files()],
1661                                                     ["/etc/maatkit/maatkit.conf", "/etc/maatkit/OptionParser.t.conf",
1662                                                        "$ENV{HOME}/.maatkit.conf", "$ENV{HOME}/.OptionParser.t.conf"],
1663                                                     "default options files",
1664                                                  );
1665           1                                 12   ok(!$o->got('config'), 'Did not got --config');
1666                                                  
1667           1                                  7   $o = new OptionParser(
1668                                                     description  => 'parses command line options.',
1669                                                  );
1670           1                                 20   $o->_parse_specs(
1671                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1672                                                              . 'files (must be the first option on the command line).',  },
1673                                                     { spec  => 'cat=A',    desc  => 'cat option (default a,b)',  },
1674                                                  );
1675                                                  
1676           1                                  6   $o->get_opts();
1677           1                                  6   is(
1678                                                     $o->print_usage(),
1679                                                  <<EOF
1680                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1681                                                  Usage: $PROGRAM_NAME <options>
1682                                                  
1683                                                  Options:
1684                                                  
1685                                                    --cat     cat option (default a,b)
1686                                                    --config  Read this comma-separated list of config files (must be the first
1687                                                              option on the command line).
1688                                                  
1689                                                  Options and values after processing arguments:
1690                                                  
1691                                                    --cat     a,b
1692                                                    --config  /etc/maatkit/maatkit.conf,/etc/maatkit/OptionParser.t.conf,$ENV{HOME}/.maatkit.conf,$ENV{HOME}/.OptionParser.t.conf
1693                                                  EOF
1694                                                  ,
1695                                                     'Sets special config file default value',
1696                                                  );
1697                                                  
1698           1                                  6   @ARGV=qw(--config /path/to/config --cat);
1699           1                                  9   $o = new OptionParser(
1700                                                     description  => 'parses command line options.',
1701                                                  );
1702                                                  
1703           1                                 23   $o->_parse_specs(
1704                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1705                                                              . 'files (must be the first option on the command line).',  },
1706                                                     { spec  => 'cat',     desc  => 'cat option',  },
1707                                                  );
1708           1                                  3   eval { $o->get_opts(); };
               1                                  5   
1709           1                                 10   like($EVAL_ERROR, qr/Cannot open/, 'No config file found');
1710                                                  
1711           1                                 10   @ARGV = ('--config',"$trunk/common/t/samples/empty",'--cat');
1712           1                                  6   $o->get_opts();
1713           1                                  6   ok($o->got('config'), 'Got --config');
1714                                                  
1715           1                                  8   is(
1716                                                     $o->print_usage(),
1717                                                  <<EOF
1718                                                  OptionParser.t parses command line options.  For more details, please use the --help option, or try 'perldoc $PROGRAM_NAME' for complete documentation.
1719                                                  Usage: $PROGRAM_NAME <options>
1720                                                  
1721                                                  Options:
1722                                                  
1723                                                    --cat     cat option
1724                                                    --config  Read this comma-separated list of config files (must be the first
1725                                                              option on the command line).
1726                                                  
1727                                                  Options and values after processing arguments:
1728                                                  
1729                                                    --cat     TRUE
1730                                                    --config  $trunk/common/t/samples/empty
1731                                                  EOF
1732                                                  ,
1733                                                     'Parses special --config option first',
1734                                                  );
1735                                                  
1736           1                                  8   $o = new OptionParser(
1737                                                     description  => 'parses command line options.',
1738                                                  );
1739           1                                 23   $o->_parse_specs(
1740                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1741                                                        . 'files (must be the first option on the command line).',  },
1742                                                     { spec  => 'cat',     desc  => 'cat option',  },
1743                                                  );
1744                                                  
1745           1                                  6   @ARGV=qw(--cat --config /path/to/config);
1746                                                  {
1747           1                                  3      local *STDERR;
               1                                  4   
1748           1                                 43      open STDERR, '>', '/dev/null';
1749           1                                  6      $o->get_opts();
1750                                                  }
1751                                                  is_deeply(
1752           1                                 13      $o->errors(),
1753                                                     ['Error parsing options', 'Unrecognized command-line options /path/to/config'],
1754                                                     'special --config option not given first',
1755                                                  );
1756                                                  
1757                                                  # And now we can actually get it to read a config file into the options!
1758           1                                 13   $o = new OptionParser(
1759                                                     description  => 'parses command line options.',
1760                                                     strict       => 0,
1761                                                  );
1762           1                                 25   $o->_parse_specs(
1763                                                     { spec  => 'config=A', desc  => 'Read this comma-separated list of config '
1764                                                        . 'files (must be the first option on the command line).',  },
1765                                                     { spec  => 'foo=s',     desc  => 'foo option',  },
1766                                                     { spec  => 'verbose+',  desc  => 'increase verbosity',  },
1767                                                  );
1768           1                                  7   is($o->{strict}, 0, 'setting strict to 0 worked');
1769                                                  
1770           1                                  7   @ARGV = ('--config', "$trunk/common/t/samples/config_file_1.conf");
1771           1                                  5   $o->get_opts();
1772           1                                 10   is_deeply(
1773                                                     [@ARGV],
1774                                                     ['/path/to/file', 'h=127.1,P=12346'],
1775                                                     'Config file influences @ARGV',
1776                                                  );
1777           1                                 11   ok($o->got('foo'), 'Got --foo');
1778           1                                  6   is($o->get('foo'), 'bar', 'Got --foo value');
1779           1                                  7   ok($o->got('verbose'), 'Got --verbose');
1780           1                                  5   is($o->get('verbose'), 1, 'Got --verbose value');
1781                                                  
1782           1                                  9   @ARGV = ('--config', "$trunk/common/t/samples/config_file_1.conf,$trunk/common/t/samples/config_file_2.conf");
1783           1                                  6   $o->get_opts();
1784           1                                  9   is_deeply(
1785                                                     [@ARGV],
1786                                                     ['/path/to/file', 'h=127.1,P=12346', '/path/to/file'],
1787                                                     'Second config file influences @ARGV',
1788                                                  );
1789           1                                 12   ok($o->got('foo'), 'Got --foo again');
1790           1                                  6   is($o->get('foo'), 'baz', 'Got overridden --foo value');
1791           1                                  6   ok($o->got('verbose'), 'Got --verbose twice');
1792           1                                  6   is($o->get('verbose'), 2, 'Got --verbose value twice');
1793                                                  
1794                                                  # #############################################################################
1795                                                  # Issue 409: OptionParser modifies second value of
1796                                                  # ' -- .*','(\w+): ([^,]+)' for array type opt
1797                                                  # #############################################################################
1798           1                                 10   $o = new OptionParser(
1799                                                     description  => 'parses command line options.',
1800                                                  );
1801           1                                 24   $o->_parse_specs(
1802                                                     { spec => 'foo=a', desc => 'foo' },
1803                                                  );
1804           1                                  6   @ARGV = ('--foo', ' -- .*,(\w+): ([^\,]+)');
1805           1                                  5   $o->get_opts();
1806           1                                  6   is_deeply(
1807                                                     $o->get('foo'),
1808                                                     [
1809                                                        ' -- .*',
1810                                                        '(\w+): ([^\,]+)',
1811                                                     ],
1812                                                     'Array of vals with internal commas (issue 409)'
1813                                                  );
1814                                                  
1815                                                  # #############################################################################
1816                                                  # Issue 349: Make OptionParser die on unrecognized attributes
1817                                                  # #############################################################################
1818           1                                 11   $o = new OptionParser(
1819                                                     description  => 'parses command line options.',
1820                                                  );
1821           1                                 13   eval { $o->get_specs("$trunk/common/t/samples/pod/pod_sample_06.txt"); };
               1                                  7   
1822           1                                 20   like(
1823                                                     $EVAL_ERROR,
1824                                                     qr/Unrecognized attribute for --verbose: culumative/,
1825                                                     'Die on unrecognized attribute'
1826                                                  );
1827                                                  
1828                                                  
1829                                                  # #############################################################################
1830                                                  # Issue 460: mk-archiver does not inherit DSN as documented
1831                                                  # #############################################################################
1832                                                  
1833                                                  # The problem is actually in how OptionParser handles copying DSN vals.
1834           1                                 11   $o = new OptionParser(
1835                                                     description  => 'parses command line options.',
1836                                                  );
1837                                                  # Hack DSNParser into OptionParser.  This is just for testing.
1838           1                                 11   $o->{DSNParser} = $dp;
1839           1                                 10   $o->_parse_specs(
1840                                                     { spec  => 'source=d',   desc  => 'source',   },
1841                                                     { spec  => 'dest=d',     desc  => 'dest',     },
1842                                                     'DSN values in --dest default to values from --source if COPY is yes.',
1843                                                  );
1844           1                                  5   @ARGV = (
1845                                                     '--source', 'h=127.1,P=12345,D=test,u=bob,p=foo',
1846                                                     '--dest', 'P=12346',
1847                                                  );
1848           1                                  6   $o->get_opts();
1849           1                                  6   my $dest_dsn = $o->get('dest');
1850           1                                 12   is_deeply(
1851                                                     $dest_dsn,
1852                                                     {
1853                                                        A => undef,
1854                                                        D => 'test',
1855                                                        F => undef,
1856                                                        P => '12346',
1857                                                        S => undef,
1858                                                        h => '127.1',
1859                                                        p => 'foo',
1860                                                        u => 'bob',
1861                                                     },
1862                                                     'Copies DSN values correctly (issue 460)'
1863                                                  );
1864                                                  
1865                                                  # #############################################################################
1866                                                  # Issue 248: Add --user, --pass, --host, etc to all tools
1867                                                  # #############################################################################
1868                                                  
1869                                                  # See the 5 cases (i.-v.) at http://groups.google.com/group/maatkit-discuss/browse_thread/thread/f4bf1e659c60f03e
1870                                                  
1871                                                  # case ii.
1872           1                                 13   $o = new OptionParser(
1873                                                     description  => 'parses command line options.',
1874                                                  );
1875                                                  # Hack DSNParser into OptionParser.  This is just for testing.
1876           1                                 19   $o->{DSNParser} = $dp;
1877           1                                  6   $o->get_specs("$trunk/mk-archiver/mk-archiver");
1878           1                                 29   @ARGV = (
1879                                                     '--source',    'h=127.1,S=/tmp/mysql.socket',
1880                                                     '--port',      '12345',
1881                                                     '--user',      'bob',
1882                                                     '--password',  'foo',
1883                                                     '--socket',    '/tmp/bad.socket',  # should *not* override DSN
1884                                                     '--where',     '1=1',   # required
1885                                                  );
1886           1                                  7   $o->get_opts();
1887           1                                  8   my $src_dsn = $o->get('source');
1888           1                                 20   is_deeply(
1889                                                     $src_dsn,
1890                                                     {
1891                                                        a => undef,
1892                                                        A => undef,
1893                                                        b => undef,
1894                                                        D => undef,
1895                                                        F => undef,
1896                                                        i => undef,
1897                                                        m => undef,
1898                                                        P => '12345',
1899                                                        S => '/tmp/mysql.socket',
1900                                                        h => '127.1',
1901                                                        p => 'foo',
1902                                                        t => undef,
1903                                                        u => 'bob',
1904                                                     },
1905                                                     'DSN opt gets missing vals from --host, --port, etc. (issue 248)',
1906                                                  );
1907                                                  
1908                                                  # Like case ii. but make sure --dest copies u from --source, not --user.
1909           1                                 19   @ARGV = (
1910                                                     '--source',    'h=127.1,u=bob',
1911                                                     '--dest',      'h=127.1',
1912                                                     '--user',      'wrong_user',
1913                                                     '--where',     '1=1',   # required
1914                                                  );
1915           1                                  8   $o->get_opts();
1916           1                                  5   $dest_dsn = $o->get('dest');
1917           1                                 16   is_deeply(
1918                                                     $dest_dsn,
1919                                                     {
1920                                                        a => undef,
1921                                                        A => undef,
1922                                                        b => undef,
1923                                                        D => undef,
1924                                                        F => undef,
1925                                                        i => undef,
1926                                                        m => undef,
1927                                                        P => undef,
1928                                                        S => undef,
1929                                                        h => '127.1',
1930                                                        p => undef,
1931                                                        t => undef,
1932                                                        u => 'bob',
1933                                                     },
1934                                                     'Vals from "defaults to" DSN take precedence over defaults (issue 248)'
1935                                                  );
1936                                                  
1937                                                  
1938                                                  # #############################################################################
1939                                                  #  Issue 617: Command line options do no override config file options
1940                                                  # #############################################################################
1941           1                               4837   diag(`echo "iterations=4" > ~/.OptionParser.t.conf`);
1942           1                                 26   $o = new OptionParser(
1943                                                     description  => 'parses command line options.',
1944                                                  );
1945           1                                329   $o->get_specs("$trunk/mk-query-digest/mk-query-digest");
1946           1                                 21   @ARGV = (qw(--iterations 9));
1947           1                                 10   $o->get_opts();
1948           1                                  6   is(
1949                                                     $o->get('iterations'),
1950                                                     9,
1951                                                     'Cmd line opt overrides conf (issue 617)'
1952                                                  );
1953           1                               6275   diag(`rm -rf ~/.OptionParser.t.conf`);
1954                                                  
1955                                                  # #############################################################################
1956                                                  #  Issue 623: --since +N does not work in mk-parallel-dump
1957                                                  # #############################################################################
1958                                                  
1959                                                  # time type opts need to allow leading +/-
1960           1                                 25   $o = new OptionParser(
1961                                                     description  => 'parses command line options.',
1962                                                  );
1963           1                                334   $o->get_specs("$trunk/mk-query-digest/mk-query-digest");
1964           1                                 25   @ARGV = (qw(--run-time +9));
1965           1                                 14   $o->get_opts();
1966           1                                 10   is(
1967                                                     $o->get('run-time'),
1968                                                     '+9',
1969                                                     '+N time value'
1970                                                  );
1971                                                  
1972           1                                  9   @ARGV = (qw(--run-time -7));
1973           1                                  6   $o->get_opts();
1974           1                                 11   is(
1975                                                     $o->get('run-time'),
1976                                                     '-7',
1977                                                     '-N time value'
1978                                                  );
1979                                                  
1980           1                                  9   @ARGV = (qw(--run-time +1m));
1981           1                                  5   $o->get_opts();
1982           1                                  6   is(
1983                                                     $o->get('run-time'),
1984                                                     '+60',
1985                                                     '+N time value with suffix'
1986                                                  );
1987                                                  
1988                                                  
1989                                                  # #############################################################################
1990                                                  # Issue 829: maatkit: mk-query-digest.1p : provokes warnings from man
1991                                                  # #############################################################################
1992                                                  # This happens because --ignore-attributes has a really long default
1993                                                  # value like val,val,val.  man can't break this line unless that list
1994                                                  # has spaces like val, val, val.
1995           1                                 11   $o = new OptionParser(
1996                                                     description  => 'parses command line options.',
1997                                                  );
1998           1                                170   $o->_parse_specs(
1999                                                     { spec  => 'foo=a',   desc => 'foo (default arg, cmd, ip, port)' },
2000                                                  );
2001           1                                  4   @ARGV = ();
2002           1                                  5   $o->get_opts();
2003           1                                  7   is_deeply(
2004                                                     $o->get('foo'),
2005                                                     [qw(arg cmd ip port)],
2006                                                     'List vals separated by spaces'
2007                                                  );
2008                                                  
2009                                                  
2010                                                  # #############################################################################
2011                                                  # Issue 940: OptionParser cannot resolve option dependencies
2012                                                  # #############################################################################
2013           1                                 12   $o = new OptionParser(
2014                                                     description  => 'parses command line options.',
2015                                                  );
2016                                                  # Hack DSNParser into OptionParser.  This is just for testing.
2017           1                                 19   $o->{DSNParser} = $dp;
2018           1                                 14   $o->_parse_specs(
2019                                                     { spec => 'foo=d', desc => 'DSN foo' },
2020                                                     { spec => 'bar=d', desc => 'DSN bar' },
2021                                                     'DSN values in --foo default to values in --bar if COPY is yes.',
2022                                                  );
2023                                                  # This simulates what get_opts() does but allows us to call
2024                                                  # _check_opts() manually with foo first.
2025           1                                  7   $o->{opts}->{bar} = {
2026                                                     long  => 'bar',
2027                                                     value => 'D=DB,u=USER,h=localhost',
2028                                                     got   => 1,
2029                                                     type  => 'd',
2030                                                  };
2031           1                                  9   $o->{opts}->{foo} = {
2032                                                     long  => 'foo',
2033                                                     value => 'h=otherhost',
2034                                                     got   => 1,
2035                                                     type  => 'd',
2036                                                  };
2037           1                                  7   $o->_check_opts(qw(foo bar));
2038           1                                  6   is_deeply(
2039                                                     $o->get('foo'),
2040                                                     {
2041                                                        D => 'DB',
2042                                                        u => 'USER',
2043                                                        S => undef,
2044                                                        F => undef,
2045                                                        P => undef,
2046                                                        h => 'otherhost',
2047                                                        p => undef,
2048                                                        A => undef,
2049                                                     },
2050                                                     'Resolves dependency'
2051                                                  );
2052                                                  
2053                                                  # Should die on circular dependency, avoid infinite loop.
2054           1                                 11   $o = new OptionParser(
2055                                                     description  => 'parses command line options.',
2056                                                  );
2057           1                                 26   $o->_parse_specs(
2058                                                     { spec => 'foo=d', desc => 'DSN foo' },
2059                                                     { spec => 'bar=d', desc => 'DSN bar' },
2060                                                     'DSN values in --foo default to values in --bar if COPY is yes.',
2061                                                     'DSN values in --bar default to values in --foo if COPY is yes.',
2062                                                  );
2063           1                                  7   $o->{opts}->{bar} = {
2064                                                     long  => 'bar',
2065                                                     value => 'D=DB,u=USER,h=localhost',
2066                                                     got   => 1,
2067                                                     type  => 'd',
2068                                                  };
2069           1                                  9   $o->{opts}->{foo} = {
2070                                                     long  => 'foo',
2071                                                     value => 'h=otherhost',
2072                                                     got   => 1,
2073                                                     type  => 'd',
2074                                                  };
2075                                                  
2076                                                  throws_ok(
2077           1                    1            17      sub { $o->_check_opts(qw(foo bar)) },
2078           1                                 28      qr/circular dependencies/,
2079                                                     'Dies on circular dependency'
2080                                                  );
2081                                                  
2082                                                  
2083                                                  # #############################################################################
2084                                                  # Issue 344
2085                                                  # #############################################################################
2086           1                                 14   $o = new OptionParser(
2087                                                     description  => 'parses command line options.',
2088                                                  );
2089           1                                 23   $o->_parse_specs(
2090                                                     { spec  => 'foo=z',   desc => 'foo' },
2091                                                  );
2092           1                                  4   @ARGV = qw(--foo null);
2093           1                                  6   $o->get_opts();
2094           1                                  6   is(
2095                                                     $o->get('foo'),
2096                                                     'null',
2097                                                     'NULL size'
2098                                                  );
2099                                                  
2100                                                  # #############################################################################
2101                                                  # Issue 55: Integrate DSN specifications into POD
2102                                                  # #############################################################################
2103           1                                  6   $o = new OptionParser(
2104                                                     description  => 'parses command line options.',
2105                                                  );
2106           1                                 22   $o->get_specs("$trunk/common/t/samples/pod/pod_sample_dsn.txt");
2107                                                  
2108           1                                 12   ok(
2109                                                     $o->DSNParser(),
2110                                                     'Auto-created DNSParser obj'
2111                                                  );
2112                                                  
2113           1                                  5   @ARGV = ();
2114           1                                  7   $o->get_opts();
2115           1                                 13   like(
2116                                                     $o->print_usage(),
2117                                                     qr/z\s+no\s+/,
2118                                                     'copy: no'
2119                                                  );
2120                                                  
2121                                                  # #############################################################################
2122                                                  # Done.
2123                                                  # #############################################################################
2124           1                                  8   my $output = '';
2125                                                  {
2126           1                                  4      local *STDERR;
               1                                  6   
2127           1                    1             3      open STDERR, '>', \$output;
               1                                322   
               1                                  3   
               1                                  7   
2128           1                                 20      $o->_d('Complete test coverage');
2129                                                  }
2130                                                  like(
2131           1                                 15      $output,
2132                                                     qr/Complete test coverage/,
2133                                                     '_d() works'
2134                                                  );
2135           1                                  4   exit;


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
945   ***     33      0      0      1   $o->get('ignore') == 1 && $o->get('replace') == 1
1560  ***     33      0      0      1   $o->get('schema') && $o->get('tab')
1592  ***     33      0      0      1   $o_clone->has('user') && $o_clone->has('dog')
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
BEGIN          1 OptionParser.t:2127
BEGIN          1 OptionParser.t:4   
BEGIN          1 OptionParser.t:9   
BEGIN          1 OptionParser.t:949 
__ANON__       1 OptionParser.t:2077


