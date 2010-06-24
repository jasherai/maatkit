---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mmon/QueryAdvisorRules.pm   96.0   91.2   76.1   96.7    0.0   45.1   90.2
QueryAdvisorRules.t            96.1   62.5   33.3   92.9    n/a   54.9   88.0
Total                          96.0   89.1   71.1   95.5    0.0  100.0   89.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:54 2010
Finish:       Thu Jun 24 19:35:54 2010

Run:          QueryAdvisorRules.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:56 2010
Finish:       Thu Jun 24 19:35:56 2010

/home/daniel/dev/maatkit/common/QueryAdvisorRules.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2010 Percona Inc.
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
18                                                    # QueryAdvisorRules package $Revision: 6086 $
19                                                    # ###########################################################################
20                                                    package QueryAdvisorRules;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24             1                    1             7   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26             1                    1             7   use Data::Dumper;
               1                                  3   
               1                                  6   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 13   
32                                                    
33                                                    sub new {
34    ***      2                    2      0     19      my ( $class, %args ) = @_;
35             2                                 10      foreach my $arg ( qw(PodParser) ) {
36    ***      2     50                          16         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38                                                    
39             2                                 11      my @rules = get_rules();
40             2                                 12      MKDEBUG && _d(scalar @rules, 'rules');
41                                                    
42             2                                 18      my $self = {
43                                                          %args,
44                                                          rules     => \@rules,
45                                                          rule_info => {},
46                                                       };
47                                                    
48             2                                 23      return bless $self, $class;
49                                                    }
50                                                    
51                                                    # Each rules is a hashref with two keys:
52                                                    #   * id       Unique PREFIX.NUMBER for the rule.  The prefix is three chars
53                                                    #              which hints to the nature of the rule.  See example below.
54                                                    #   * code     Coderef to check rule, returns undef if rule does not match,
55                                                    #              else returns the string pos near where the rule matches or 0
56                                                    #              to indicate it doesn't know the pos.  The code is passed a\
57                                                    #              single arg: a hashref event.
58                                                    sub get_rules {
59                                                       return
60                                                       {
61                                                          id   => 'ALI.001',      # Implicit alias
62                                                          code => sub {
63            47                   47          1014            my ( $event ) = @_;
64            47                                157            my $struct = $event->{query_struct};
65            47           100                  334            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
                           100                        
66            47    100                         161            return unless $tbls;
67            46                                155            foreach my $tbl ( @$tbls ) {
68    ***     50     50     66                  330               return 0 if $tbl->{alias} && !$tbl->{explicit_alias};
69                                                             }
70            46                                165            my $cols = $struct->{columns};
71            46    100                         176            return unless $cols;
72            39                                137            foreach my $col ( @$cols ) {
73            42    100    100                  262               return 0 if $col->{alias} && !$col->{explicit_alias};
74                                                             }
75            37                                215            return;
76                                                          },
77                                                       },
78                                                       {
79                                                          id   => 'ALI.002',      # tbl.* alias
80                                                          code => sub {
81            47                   47           408            my ( $event ) = @_;
82            47                                187            my $cols = $event->{query_struct}->{columns};
83            47    100                         174            return unless $cols;
84            40                                129            foreach my $col ( @$cols ) {
85    ***     43    100     66                  320               return 0 if $col->{db} && $col->{name } eq '*' &&  $col->{alias};
      ***                   66                        
86                                                             }
87            39                                206            return;
88                                                          },
89                                                       },
90                                                       {
91                                                          id   => 'ALI.003',      # tbl AS tbl
92                                                          code => sub {
93            47                   47           375            my ( $event ) = @_;
94            47                                154            my $struct = $event->{query_struct};
95            47           100                  306            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
                           100                        
96            47    100                         154            return unless $tbls;
97            46                                150            foreach my $tbl ( @$tbls ) {
98            50    100    100                  374               return 0 if $tbl->{alias} && $tbl->{alias} eq $tbl->{name};
99                                                             }
100           45                                152            my $cols = $struct->{columns};
101           45    100                         180            return unless $cols;
102           38                                130            foreach my $col ( @$cols ) {
103           41    100    100                  248               return 0 if $col->{alias} && $col->{alias} eq $col->{name};
104                                                            }
105           37                                201            return;
106                                                         },
107                                                      },
108                                                      {
109                                                         id   => 'ARG.001',      # col = '%foo'
110                                                         code => sub {
111           47                   47           394            my ( $event ) = @_;
112           47    100                         270            return 0 if $event->{arg} =~ m/[\'\"][\%\_]./;
113           43                                222            return;
114                                                         },
115                                                      },
116                                                      {
117                                                         id   => 'ARG.002',      # LIKE w/o wildcard
118                                                         code => sub {
119           47                   47           400            my ( $event ) = @_;
120                                                            # TODO: this pattern doesn't handle spaces.
121           47                                367            my @like_args = $event->{arg} =~ m/\bLIKE\s+(\S+)/gi;
122           47                                165            foreach my $arg ( @like_args ) {
123            5    100                          34               return 0 if $arg !~ m/[%_]/;
124                                                            }
125           45                                244            return;
126                                                         },
127                                                      },
128                                                      {
129                                                         id   => 'CLA.001',      # SELECT w/o WHERE
130                                                         code => sub {
131           47                   47           390            my ( $event ) = @_;
132   ***     47    100     50                  322            return unless ($event->{query_struct}->{type} || '') eq 'select';
133           40    100                         176            return unless $event->{query_struct}->{from};
134           39    100                         170            return 0 unless $event->{query_struct}->{where};
135           38                                191            return;
136                                                         },
137                                                      },
138                                                      {
139                                                         id   => 'CLA.002',      # ORDER BY RAND()
140                                                         code => sub {
141           47                   47           372            my ( $event ) = @_;
142           47                                185            my $orderby = $event->{query_struct}->{order_by};
143           47    100                         286            return unless $orderby;
144            4                                 18            foreach my $col ( @$orderby ) {
145            4    100                          31               return 0 if $col =~ m/RAND\([^\)]*\)/i;
146                                                            }
147            2                                 11            return;
148                                                         },
149                                                      },
150                                                      {
151                                                         id   => 'CLA.003',      # LIMIT w/ OFFSET
152                                                         code => sub {
153           47                   47           379            my ( $event ) = @_;
154           47    100                         324            return unless $event->{query_struct}->{limit};
155            4    100                          30            return unless defined $event->{query_struct}->{limit}->{offset};
156            2                                 12            return 0;
157                                                         },
158                                                      },
159                                                      {
160                                                         id   => 'CLA.004',      # GROUP BY <number>
161                                                         code => sub {
162           47                   47           373            my ( $event ) = @_;
163           47                                178            my $groupby = $event->{query_struct}->{group_by};
164           47    100                         274            return unless $groupby;
165            3                                 10            foreach my $col ( @{$groupby->{columns}} ) {
               3                                 12   
166            4    100                          25               return 0 if $col =~ m/^\d+\b/;
167                                                            }
168            2                                 12            return;
169                                                         },
170                                                      },
171                                                      {
172                                                         id   => 'COL.001',      # SELECT *
173                                                         code => sub {
174           47                   47           351            my ( $event ) = @_;
175   ***     47    100     50                  313            return unless ($event->{query_struct}->{type} || '') eq 'select';
176           40                                153            my $cols = $event->{query_struct}->{columns};
177   ***     40     50                         151            return unless $cols;
178           40                                136            foreach my $col ( @$cols ) {
179           43    100                         230               return 0 if $col->{name} eq '*';
180                                                            }
181           38                                219            return;
182                                                         },
183                                                      },
184                                                      {
185                                                         id   => 'COL.002',      # INSERT w/o (cols) def
186                                                         code => sub {
187           47                   47           379            my ( $event ) = @_;
188   ***     47            50                  231            my $type = $event->{query_struct}->{type} || '';
189   ***     47    100     66                  525            return unless $type eq 'insert' || $type eq 'replace';
190   ***      2     50                          16            return 0 unless $event->{query_struct}->{columns};
191   ***      0                                  0            return;
192                                                         },
193                                                      },
194                                                      {
195                                                         id   => 'LIT.001',      # IP as string
196                                                         code => sub {
197           47                   47           390            my ( $event ) = @_;
198           47    100                         241            if ( $event->{arg} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/gc ) {
199   ***      1            50                    8               return (pos $event->{arg}) || 0;
200                                                            }
201           46                                234            return;
202                                                         },
203                                                      },
204                                                      {
205                                                         id   => 'LIT.002',      # Date not quoted
206                                                         code => sub {
207           47                   47           440            my ( $event ) = @_;
208                                                            # YYYY-MM-DD
209           47    100                         266            if ( $event->{arg} =~ m/(?<!['"\w-])\d{4}-\d{1,2}-\d{1,2}\b/gc ) {
210   ***      4            50                   35               return (pos $event->{arg}) || 0;
211                                                            }
212                                                            # YY-MM-DD
213           43    100                         203            if ( $event->{arg} =~ m/(?<!['"\w\d-])\d{2}-\d{1,2}-\d{1,2}\b/gc ) {
214   ***      3            50                   24               return (pos $event->{arg}) || 0;
215                                                            }
216           40                                197            return;
217                                                         },
218                                                      },
219                                                      {
220                                                         id   => 'KWR.001',      # SQL_CALC_FOUND_ROWS
221                                                         code => sub {
222           47                   47           418            my ( $event ) = @_;
223           47    100                         286            return 0 if $event->{query_struct}->{keywords}->{sql_calc_found_rows};
224           46                                226            return;
225                                                         },
226                                                      },
227                                                      {
228                                                         id   => 'JOI.001',      # comma and ansi joins
229                                                         code => sub {
230           47                   47           356            my ( $event ) = @_;
231           47                                152            my $struct = $event->{query_struct};
232           47           100                  308            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
                           100                        
233           47    100                         155            return unless $tbls;
234           46                                121            my $comma_join = 0;
235           46                                111            my $ansi_join  = 0;
236           46                                151            foreach my $tbl ( @$tbls ) {
237           50    100                         195               if ( $tbl->{join} ) {
238            5    100                          22                  if ( $tbl->{join}->{ansi} ) {
239            3                                 10                     $ansi_join = 1;
240                                                                  }
241                                                                  else {
242            2                                  7                     $comma_join = 1;
243                                                                  }
244                                                               }
245           50    100    100                  284               return 0 if $comma_join && $ansi_join;
246                                                            }
247           45                                255            return;
248                                                         },
249                                                      },
250                                                      {
251                                                         id   => 'RES.001',      # non-deterministic GROUP BY
252                                                         code => sub {
253           47                   47           363            my ( $event ) = @_;
254   ***     47    100     50                  304            return unless ($event->{query_struct}->{type} || '') eq 'select';
255           40                                152            my $groupby = $event->{query_struct}->{group_by};
256           40    100                         237            return unless $groupby;
257                                                            # Only check GROUP BY column names, not numbers.  GROUP BY number
258                                                            # is handled in CLA.004.
259            3                                 22            my %groupby_col = map { $_ => 1 }
               4                                 19   
260            3                                 12                              grep { m/^[^\d]+\b/ }
261            3                                  9                              @{$groupby->{columns}};
262            3    100                          27            return unless scalar %groupby_col;
263            2                                  8            my $cols = $event->{query_struct}->{columns};
264                                                            # All SELECT cols must be in GROUP BY cols clause.
265                                                            # E.g. select a, b, c from tbl group by a; -- non-deterministic
266            2                                  7            foreach my $col ( @$cols ) {
267            4    100                          24               return 0 unless $groupby_col{ $col->{name} };
268                                                            }
269            1                                  6            return;
270                                                         },
271                                                      },
272                                                      {
273                                                         id   => 'RES.002',      # non-deterministic LIMIT w/o ORDER BY
274                                                         code => sub {
275           47                   47           353            my ( $event ) = @_;
276           47    100                         323            return unless $event->{query_struct}->{limit};
277                                                            # If query doesn't use tables then this check isn't applicable.
278   ***      4    100     66                   41            return unless    $event->{query_struct}->{from}
      ***                   66                        
279                                                                            || $event->{query_struct}->{into}
280                                                                            || $event->{query_struct}->{tables};
281            3    100                          19            return 0 unless $event->{query_struct}->{order_by};
282            2                                 10            return;
283                                                         },
284                                                      },
285                                                      {
286                                                         id   => 'STA.001',      # != instead of <>
287                                                         code => sub {
288           47                   47           376            my ( $event ) = @_;
289           47    100                         232            return 0 if $event->{arg} =~ m/!=/;
290           46                                219            return;
291                                                         },
292                                                      },
293                                                      {
294                                                         id   => 'SUB.001',      # IN(<subquery>)
295                                                         code => sub {
296           47                   47           359            my ( $event ) = @_;
297           47    100                         340            if ( $event->{arg} =~ m/\bIN\s*\(\s*SELECT\b/gi ) {
298            1                                  7               return pos $event->{arg};
299                                                            }
300           46                                260            return;
301                                                         },
302                                                      },
303   ***      5                    5      0    562   };
304                                                   
305                                                   # Arguments:
306                                                   #   * file     scalar: file name with POD to parse rules from
307                                                   #   * section  scalar: section name for rule items, should be RULES
308                                                   #   * rules    arrayref: optional list of rules to load info for
309                                                   # Parses rules from the POD section/subsection in file, adding rule
310                                                   # info found therein to %rule_info.  Then checks that rule info
311                                                   # was gotten for all the required rules.
312                                                   sub load_rule_info {
313   ***      4                    4      0     34      my ( $self, %args ) = @_;
314            4                                 23      foreach my $arg ( qw(file section ) ) {
315   ***      8     50                          43         die "I need a $arg argument" unless $args{$arg};
316                                                      }
317   ***      4            33                   24      my $rules = $args{rules} || $self->{rules};
318            4                                 16      my $p     = $self->{PodParser};
319                                                   
320                                                      # Parse rules and their info from the file's POD, saving
321                                                      # values to %rule_info.
322            4                                 31      $p->parse_from_file($args{file});
323            4                                 69      my $rule_items = $p->get_items($args{section});
324            4                                 75      my %seen;
325            4                                 38      foreach my $rule_id ( keys %$rule_items ) {
326           22                                 74         my $rule = $rule_items->{$rule_id};
327   ***     22     50                          98         die "Rule $rule_id has no description" unless $rule->{desc};
328   ***     22     50                          90         die "Rule $rule_id has no severity"    unless $rule->{severity};
329           22    100                          98         die "Rule $rule_id is already defined"
330                                                            if exists $self->{rule_info}->{$rule_id};
331           21                                182         $self->{rule_info}->{$rule_id} = {
332                                                            id          => $rule_id,
333                                                            severity    => $rule->{severity},
334                                                            description => $rule->{desc},
335                                                         };
336                                                      }
337                                                   
338                                                      # Check that rule info was gotten for each requested rule.
339            3                                 16      foreach my $rule ( @$rules ) {
340           22    100                         127         die "There is no info for rule $rule->{id} in $args{file}"
341                                                            unless $self->{rule_info}->{ $rule->{id} };
342                                                      }
343                                                   
344            2                                 14      return;
345                                                   }
346                                                   
347                                                   sub get_rule_info {
348   ***     22                   22      0    508      my ( $self, $id ) = @_;
349           22    100                          84      return unless $id;
350           21                                118      return $self->{rule_info}->{$id};
351                                                   }
352                                                   
353                                                   # Used for testing.
354                                                   sub _reset_rule_info {
355            1                    1             4      my ( $self ) = @_;
356            1                                  6      $self->{rule_info} = {};
357            1                                  8      return;
358                                                   }
359                                                   
360                                                   sub _d {
361   ***      0                    0                    my ($package, undef, $line) = caller 0;
362   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
363   ***      0                                              map { defined $_ ? $_ : 'undef' }
364                                                           @_;
365   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
366                                                   }
367                                                   
368                                                   1;
369                                                   
370                                                   # ###########################################################################
371                                                   # End QueryAdvisorRules package
372                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      0      2   unless $args{$arg}
66           100      1     46   unless $tbls
68    ***     50      0     50   if $$tbl{'alias'} and not $$tbl{'explicit_alias'}
71           100      7     39   unless $cols
73           100      2     40   if $$col{'alias'} and not $$col{'explicit_alias'}
83           100      7     40   unless $cols
85           100      1     42   if $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
96           100      1     46   unless $tbls
98           100      1     49   if $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
101          100      7     38   unless $cols
103          100      1     40   if $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
112          100      4     43   if $$event{'arg'} =~ /[\'\"][\%\_]./
123          100      2      3   if not $arg =~ /[%_]/
132          100      7     40   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
133          100      1     39   unless $$event{'query_struct'}{'from'}
134          100      1     38   unless $$event{'query_struct'}{'where'}
143          100     43      4   unless $orderby
145          100      2      2   if $col =~ /RAND\([^\)]*\)/i
154          100     43      4   unless $$event{'query_struct'}{'limit'}
155          100      2      2   unless defined $$event{'query_struct'}{'limit'}{'offset'}
164          100     44      3   unless $groupby
166          100      1      3   if $col =~ /^\d+\b/
175          100      7     40   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
177   ***     50      0     40   unless $cols
179          100      2     41   if $$col{'name'} eq '*'
189          100     45      2   unless $type eq 'insert' or $type eq 'replace'
190   ***     50      2      0   unless $$event{'query_struct'}{'columns'}
198          100      1     46   if ($$event{'arg'} =~ /['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/cg)
209          100      4     43   if ($$event{'arg'} =~ /(?<!['"\w-])\d{4}-\d{1,2}-\d{1,2}\b/cg)
213          100      3     40   if ($$event{'arg'} =~ /(?<!['"\w\d-])\d{2}-\d{1,2}-\d{1,2}\b/cg)
223          100      1     46   if $$event{'query_struct'}{'keywords'}{'sql_calc_found_rows'}
233          100      1     46   unless $tbls
237          100      5     45   if ($$tbl{'join'})
238          100      3      2   if ($$tbl{'join'}{'ansi'}) { }
245          100      1     49   if $comma_join and $ansi_join
254          100      7     40   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
256          100     37      3   unless $groupby
262          100      1      2   unless scalar %groupby_col
267          100      1      3   unless $groupby_col{$$col{'name'}}
276          100     43      4   unless $$event{'query_struct'}{'limit'}
278          100      1      3   unless $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'} or $$event{'query_struct'}{'tables'}
281          100      1      2   unless $$event{'query_struct'}{'order_by'}
289          100      1     46   if $$event{'arg'} =~ /!=/
297          100      1     46   if ($$event{'arg'} =~ /\bIN\s*\(\s*SELECT\b/gi)
315   ***     50      0      8   unless $args{$arg}
327   ***     50      0     22   unless $$rule{'desc'}
328   ***     50      0     22   unless $$rule{'severity'}
329          100      1     21   if exists $$self{'rule_info'}{$rule_id}
340          100      1     21   unless $$self{'rule_info'}{$$rule{'id'}}
349          100      1     21   unless $id
362   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
68    ***     66     47      3      0   $$tbl{'alias'} and not $$tbl{'explicit_alias'}
73           100     39      1      2   $$col{'alias'} and not $$col{'explicit_alias'}
85    ***     66     42      0      1   $$col{'db'} and $$col{'name'} eq '*'
      ***     66     42      0      1   $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
98           100     47      2      1   $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
103          100     38      2      1   $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
245          100     47      2      1   $comma_join and $ansi_join

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
132   ***     50     47      0   $$event{'query_struct'}{'type'} || ''
175   ***     50     47      0   $$event{'query_struct'}{'type'} || ''
188   ***     50     47      0   $$event{'query_struct'}{'type'} || ''
199   ***     50      1      0   pos $$event{'arg'} || 0
210   ***     50      4      0   pos $$event{'arg'} || 0
214   ***     50      3      0   pos $$event{'arg'} || 0
254   ***     50     47      0   $$event{'query_struct'}{'type'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
65           100     41      2      4   $$struct{'from'} || $$struct{'into'}
             100     43      3      1   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
95           100     41      2      4   $$struct{'from'} || $$struct{'into'}
             100     43      3      1   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
189   ***     66      2      0     45   $type eq 'insert' or $type eq 'replace'
232          100     41      2      4   $$struct{'from'} || $$struct{'into'}
             100     43      3      1   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
278   ***     66      3      0      1   $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'}
      ***     66      3      0      1   $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'} or $$event{'query_struct'}{'tables'}
317   ***     33      4      0      0   $args{'rules'} || $$self{'rules'}


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                                
---------------- ----- --- --------------------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:22 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:23 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:24 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:26 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:31 
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:111
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:119
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:131
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:141
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:153
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:162
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:174
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:187
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:197
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:207
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:222
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:230
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:253
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:275
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:288
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:296
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:63 
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:81 
__ANON__            47     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:93 
_reset_rule_info     1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:355
get_rule_info       22   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:348
get_rules            5   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:303
load_rule_info       4   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:313
new                  2   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:34 

Uncovered Subroutines
---------------------

Subroutine       Count Pod Location                                                
---------------- ----- --- --------------------------------------------------------
_d                   0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:361


QueryAdvisorRules.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
11             1                    1            12   use English qw(-no_match_vars);
               1                                  3   
               1                                  9   
12             1                    1            16   use Test::More tests => 58;
               1                                  3   
               1                                 13   
13                                                    
14             1                    1            19   use MaatkitTest;
               1                                  6   
               1                                 42   
15             1                    1            14   use PodParser;
               1                                  4   
               1                                 11   
16             1                    1            14   use QueryAdvisorRules;
               1                                  3   
               1                                 22   
17             1                    1            14   use QueryAdvisor;
               1                                  4   
               1                                 12   
18             1                    1            14   use SQLParser;
               1                                  3   
               1                                 13   
19                                                    
20                                                    # This test should just test that the QueryAdvisor module conforms to the
21                                                    # expected interface:
22                                                    #   - It has a get_rules() method that returns a list of hashrefs:
23                                                    #     ({ID => 'ID', code => $code}, {ID => ..... }, .... )
24                                                    #   - It has a load_rule_info() method that accepts a list of hashrefs, which
25                                                    #     we'll use to load rule info from POD.  Our built-in rule module won't
26                                                    #     store its own rule info.  But plugins supplied by users should.
27                                                    #   - It has a get_rule_info() method that accepts an ID and returns a hashref:
28                                                    #     {ID => 'ID', Severity => 'NOTE|WARN|CRIT', Description => '......'}
29             1                                 11   my $p   = new PodParser();
30             1                                 45   my $qar = new QueryAdvisorRules(PodParser => $p);
31                                                    
32             1                                  6   my @rules = $qar->get_rules();
33             1                                 12   ok(
34                                                       scalar @rules,
35                                                       'Returns array of rules'
36                                                    );
37                                                    
38             1                                  4   my $rules_ok = 1;
39             1                                  6   foreach my $rule ( @rules ) {
40    ***     19     50     33                  307      if (    !$rule->{id}
      ***                   33                        
41                                                            || !$rule->{code}
42                                                            || (ref $rule->{code} ne 'CODE') )
43                                                       {
44    ***      0                                  0         $rules_ok = 0;
45    ***      0                                  0         last;
46                                                       }
47                                                    }
48                                                    ok(
49             1                                  8      $rules_ok,
50                                                       'All rules are proper'
51                                                    );
52                                                    
53                                                    # QueryAdvisorRules.pm has more rules than mqa-rule-LIT.001.pod so to avoid
54                                                    # "There is no info" errors we remove all but LIT.001.
55             1                                  5   @rules = grep { $_->{id} eq 'LIT.001' } @rules;
              19                                204   
56                                                    
57                                                    # Test that we can load rule info from POD.  Make a sample POD file that has a
58                                                    # single sample rule definition for LIT.001 or something.
59             1                                 17   $qar->load_rule_info(
60                                                       rules    => \@rules,
61                                                       file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
62                                                       section  => 'RULES',
63                                                    );
64                                                    
65                                                    # We shouldn't be able to load the same rule info twice.
66                                                    throws_ok(
67                                                       sub {
68             1                    1            23         $qar->load_rule_info(
69                                                             rules    => \@rules,
70                                                             file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
71                                                             section  => 'RULES',
72                                                          );
73                                                       },
74             1                                 26      qr/Rule \S+ is already defined/,
75                                                       'Duplicate rule info is caught'
76                                                    );
77                                                    
78                                                    # Test that we can now get a hashref as described above.
79             1                                 30   is_deeply(
80                                                       $qar->get_rule_info('LIT.001'),
81                                                       {  id          => 'LIT.001',
82                                                          severity    => 'note',
83                                                          description => "IP address used as string.  The string literal looks like an IP address but is not used inside INET_ATON().  WHERE ip='127.0.0.1' is better as ip=INET_ATON('127.0.0.1') if the column is numeric.",
84                                                       },
85                                                       'get_rule_info(LIT.001) works',
86                                                    );
87                                                    
88                                                    # Test getting a nonexistent rule.
89             1                                 14   is(
90                                                       $qar->get_rule_info('BAR.002'),
91                                                       undef,
92                                                       "get_rule_info() nonexistent rule"
93                                                    );
94                                                    
95             1                                  8   is(
96                                                       $qar->get_rule_info(),
97                                                       undef,
98                                                       "get_rule_info(undef)"
99                                                    );
100                                                   
101                                                   # Add a rule for which there is no POD info and test that it's not allowed.
102                                                   push @rules, {
103                                                      id   => 'FOO.001',
104   ***      0                    0             0      code => sub { return },
105            1                                 11   };
106            1                                 22   $qar->_reset_rule_info();  # else we'll get "cannot redefine rule" error
107                                                   throws_ok (
108                                                      sub {
109            1                    1            24         $qar->load_rule_info(
110                                                            rules    => \@rules,
111                                                            file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
112                                                            section  => 'RULES',
113                                                         );
114                                                      },
115            1                                 17      qr/There is no info for rule FOO.001/,
116                                                      "Doesn't allow rules without info",
117                                                   );
118                                                   
119                                                   # ###########################################################################
120                                                   # Test cases for the rules themselves.
121                                                   # ###########################################################################
122            1                                187   my @cases = (
123                                                      {  name   => 'IP address not inside INET_ATON, plus SELECT * is used',
124                                                         query  => 'SELECT * FROM tbl WHERE ip="127.0.0.1"',
125                                                         advice => [qw(COL.001 LIT.001)],
126                                                         pos    => [0, 37],
127                                                      },
128                                                      {  name   => 'Date literal not quoted',
129                                                         query  => 'SELECT col FROM tbl WHERE col < 2001-01-01',
130                                                         advice => [qw(LIT.002)],
131                                                      },
132                                                      {  name   => 'Aliases without AS keyword',
133                                                         query  => 'SELECT a b FROM tbl',
134                                                         advice => [qw(ALI.001 CLA.001)],
135                                                      },
136                                                      {  name   => 'tbl.* alias',
137                                                         query  => 'SELECT tbl.* foo FROM bar WHERE id=1',
138                                                         advice => [qw(ALI.001 ALI.002 COL.001)],
139                                                      },
140                                                      {  name   => 'tbl as tbl',
141                                                         query  => 'SELECT col FROM tbl AS tbl WHERE id',
142                                                         advice => [qw(ALI.003)],
143                                                      },
144                                                      {  name   => 'col as col',
145                                                         query  => 'SELECT col AS col FROM tbl AS `my tbl` WHERE id',
146                                                         advice => [qw(ALI.003)],
147                                                      },
148                                                      {  name   => 'Blind INSERT',
149                                                         query  => 'INSERT INTO tbl VALUES(1),(2)',
150                                                         advice => [qw(COL.002)],
151                                                      },
152                                                      {  name   => 'Blind INSERT',
153                                                         query  => 'INSERT tbl VALUE (1)',
154                                                         advice => [qw(COL.002)],
155                                                      },
156                                                      {  name   => 'SQL_CALC_FOUND_ROWS',
157                                                         query  => 'SELECT SQL_CALC_FOUND_ROWS col FROM tbl AS alias WHERE id=1',
158                                                         advice => [qw(KWR.001)],
159                                                      },
160                                                      {  name   => 'All comma joins ok',
161                                                         query  => 'SELECT col FROM tbl1, tbl2 WHERE tbl1.id=tbl2.id',
162                                                         advice => [],
163                                                      },
164                                                      {  name   => 'All ANSI joins ok',
165                                                         query  => 'SELECT col FROM tbl1 JOIN tbl2 USING(id) WHERE tbl1.id>10',
166                                                         advice => [],
167                                                      },
168                                                      {  name   => 'Mix comman/ANSI joins',
169                                                         query  => 'SELECT col FROM tbl, tbl1 JOIN tbl2 USING(id) WHERE tbl.d>10',
170                                                         advice => [qw(JOI.001)],
171                                                      },
172                                                      {  name   => 'Non-deterministic GROUP BY',
173                                                         query  => 'select a, b, c from tbl where foo group by a',
174                                                         advice => [qw(RES.001)],
175                                                      },
176                                                      {  name   => 'Non-deterministic LIMIT w/o ORDER BY',
177                                                         query  => 'select a, b from tbl where foo limit 10 group by a, b',
178                                                         advice => [qw(RES.002)],
179                                                      },
180                                                      {  name   => 'ORDER BY RAND()',
181                                                         query  => 'select a from t where id order by rand()',
182                                                         advice => [qw(CLA.002)],
183                                                      },
184                                                      {  name   => 'ORDER BY RAND(N)',
185                                                         query  => 'select a from t where id order by rand(123)',
186                                                         advice => [qw(CLA.002)],
187                                                      },
188                                                      {  name   => 'LIMIT w/ OFFSET does not scale',
189                                                         query  => 'select a from t where i limit 10, 10 order by a',
190                                                         advice => [qw(CLA.003)],
191                                                      },
192                                                      {  name   => 'LIMIT w/ OFFSET does not scale',
193                                                         query  => 'select a from t where i limit 10 OFFSET 10 order by a',
194                                                         advice => [qw(CLA.003)],
195                                                      },
196                                                      {  name   => 'Leading %wildcard',
197                                                         query  => 'select a from t where i="%hm"',
198                                                         advice => [qw(ARG.001)],
199                                                      },
200                                                      {  name   => 'Leading _wildcard',
201                                                         query  => 'select a from t where i="_hm"',
202                                                         advice => [qw(ARG.001)],
203                                                      },
204                                                      {  name   => 'Leading "% wildcard"',
205                                                         query  => 'select a from t where i="% eh "',
206                                                         advice => [qw(ARG.001)],
207                                                      },
208                                                      {  name   => 'Leading "_ wildcard"',
209                                                         query  => 'select a from t where i="_ eh "',
210                                                         advice => [qw(ARG.001)],
211                                                      },
212                                                      {  name   => 'GROUP BY number',
213                                                         query  => 'select a from t where i group by 1',
214                                                         advice => [qw(CLA.004)],
215                                                      },
216                                                      {  name   => '!= instead of <>',
217                                                         query  => 'select a from t where i != 2',
218                                                         advice => [qw(STA.001)],
219                                                      },
220                                                      {  name   => "LIT.002 doesn't match",
221                                                         query  => "update foo.bar set biz = '91848182522'",
222                                                         advice => [],
223                                                      },
224                                                      {  name   => "LIT.002 doesn't match",
225                                                         query  => "update db2.tuningdetail_21_265507 inner join db1.gonzo using(g) set n.c1 = a.c1, n.w3 = a.w3",
226                                                         advice => [],
227                                                      },
228                                                      {  name   => "LIT.002 doesn't match",
229                                                         query  => "UPDATE db4.vab3concept1upload
230                                                                    SET    vab3concept1id = '91848182522'
231                                                                    WHERE  vab3concept1upload='6994465'",
232                                                         advice => [],
233                                                      },
234                                                      {  name   => "LIT.002 at end of query",
235                                                         query  => "select c from t where d=2006-10-10",
236                                                         advice => [qw(LIT.002)],
237                                                      },
238                                                      {  name   => "LIT.002 5 digits doesn't match",
239                                                         query  => "select c from t where d=12345",
240                                                         advice => [],
241                                                      },
242                                                      {  name   => "LIT.002 7 digits doesn't match",
243                                                         query  => "select c from t where d=1234567",
244                                                         advice => [],
245                                                      },
246                                                      {  name   => "SELECT var LIMIT",
247                                                         query  => "select \@\@version_comment limit 1 ",
248                                                         advice => [],
249                                                      },
250                                                      {  name   => "Date with time",
251                                                         query  => "select c from t where d > 2010-03-15 09:09:09",
252                                                         advice => [qw(LIT.002)],
253                                                      },
254                                                      {  name   => "Date with time and subseconds",
255                                                         query  => "select c from t where d > 2010-03-15 09:09:09.123456",
256                                                         advice => [qw(LIT.002)],
257                                                      },
258                                                      {  name   => "Date with time doesn't match",
259                                                         query  => "select c from t where d > '2010-03-15 09:09:09'",
260                                                         advice => [qw()],
261                                                      },
262                                                      {  name   => "Date with time and subseconds doesn't match",
263                                                         query  => "select c from t where d > '2010-03-15 09:09:09.123456'",
264                                                         advice => [qw()],
265                                                      },
266                                                      {  name   => "Short date",
267                                                         query  => "select c from t where d=73-03-15",
268                                                         advice => [qw(LIT.002)],
269                                                      },
270                                                      {  name   => "Short date with time",
271                                                         query  => "select c from t where d > 73-03-15 09:09:09",
272                                                         advice => [qw(LIT.002)],
273                                                         pos    => [34],
274                                                      },
275                                                      {  name   => "Short date with time and subseconds",
276                                                         query  => "select c from t where d > 73-03-15 09:09:09.123456",
277                                                         advice => [qw(LIT.002)],
278                                                      },
279                                                      {  name   => "Short date with time doesn't match",
280                                                         query  => "select c from t where d > '73-03-15 09:09:09'",
281                                                         advice => [qw()],
282                                                      },
283                                                      {  name   => "Short date with time and subseconds doesn't match",
284                                                         query  => "select c from t where d > '73-03-15 09:09:09.123456'",
285                                                         advice => [qw()],
286                                                      },
287                                                      {  name   => "LIKE without wildcard",
288                                                         query  => "select c from t where i like 'lamp'",
289                                                         advice => [qw(ARG.002)],
290                                                      },
291                                                      {  name   => "LIKE without wildcard, 2nd arg",
292                                                         query  => "select c from t where i like 'lamp%' or like 'foo'",
293                                                         advice => [qw(ARG.002)],
294                                                      },
295                                                      {  name   => "LIKE with wildcard %",
296                                                         query  => "select c from t where i like 'lamp%'",
297                                                         advice => [qw()],
298                                                      },
299                                                      {  name   => "LIKE with wildcard _",
300                                                         query  => "select c from t where i like 'lamp_'",
301                                                         advice => [qw()],
302                                                      },
303                                                      {  name   => "Issue 946: LIT.002 false-positive",
304                                                         query  => "delete from t where d in('MD6500-26', 'MD6500-21-22', 'MD6214')",
305                                                         advice => [qw()],
306                                                      },
307                                                      {  name   => "Issue 946: LIT.002 false-positive",
308                                                         query  => "delete from t where d in('FS-8320-0-2', 'FS-800-6')",
309                                                         advice => [qw()],
310                                                      },
311                                                   # This matches LIT.002 but unless the regex gets really complex or
312                                                   # we do this rule another way, this will have to remain an exception.
313                                                   #   {  name   => "Issue 946: LIT.002 false-positive",
314                                                   #      query  => "select c from t where c='foo 2010-03-17 bar'",
315                                                   #      advice => [qw()],
316                                                   #   },
317                                                   
318                                                      {  name   => "IN(subquer)",
319                                                         query  => "select c from t where i in(select d from z where 1)",
320                                                         advice => [qw(SUB.001)],
321                                                         pos    => [33],
322                                                      },
323                                                      
324                                                   );
325                                                   
326                                                   # Run the test cases.
327            1                                 18   $qar = new QueryAdvisorRules(PodParser => $p);
328            1                                127   $qar->load_rule_info(
329                                                      rules   => [ $qar->get_rules() ],
330                                                      file    => "$trunk/mk-query-advisor/mk-query-advisor",
331                                                      section => 'RULES',
332                                                   );
333                                                   
334            1                                144   my $qa = new QueryAdvisor();
335            1                                 54   $qa->load_rules($qar);
336            1                                443   $qa->load_rule_info($qar);
337                                                   
338            1                                 26   my $sp = new SQLParser();
339                                                   
340            1                                 34   foreach my $test ( @cases ) {
341           47                                272      my $query_struct = $sp->parse($test->{query});
342           47                              28141      my $event = {
343                                                         arg          => $test->{query},
344                                                         query_struct => $query_struct,
345                                                      };
346           47                                248      my ($ids, $pos) = $qa->run_rules($event);
347           47                                607      is_deeply(
348                                                         $ids,
349                                                         $test->{advice},
350                                                         $test->{name},
351                                                      );
352                                                   
353           47    100                         344      if ( $test->{pos} ) {
354            3                                 20         is_deeply(
355                                                            $pos,
356                                                            $test->{pos},
357                                                            "$test->{name} matched near pos"
358                                                         );
359                                                      }
360                                                   
361                                                      # To help me debug.
362   ***     47     50                         560      die if $test->{stop};
363                                                   }
364                                                   
365                                                   # #############################################################################
366                                                   # Done.
367                                                   # #############################################################################
368            1                                  4   my $output = '';
369                                                   {
370            1                                  2      local *STDERR;
               1                                  6   
371            1                    1             2      open STDERR, '>', \$output;
               1                                310   
               1                                  3   
               1                                  7   
372            1                                 39      $p->_d('Complete test coverage');
373                                                   }
374                                                   like(
375            1                                 15      $output,
376                                                      qr/Complete test coverage/,
377                                                      '_d() works'
378                                                   );
379            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
40    ***     50      0     19   if (not $$rule{'id'} or not $$rule{'code'} or ref $$rule{'code'} ne 'CODE')
353          100      3     44   if ($$test{'pos'})
362   ***     50      0     47   if $$test{'stop'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
40    ***     33      0      0     19   not $$rule{'id'} or not $$rule{'code'}
      ***     33      0      0     19   not $$rule{'id'} or not $$rule{'code'} or ref $$rule{'code'} ne 'CODE'


Covered Subroutines
-------------------

Subroutine Count Location               
---------- ----- -----------------------
BEGIN          1 QueryAdvisorRules.t:10 
BEGIN          1 QueryAdvisorRules.t:11 
BEGIN          1 QueryAdvisorRules.t:12 
BEGIN          1 QueryAdvisorRules.t:14 
BEGIN          1 QueryAdvisorRules.t:15 
BEGIN          1 QueryAdvisorRules.t:16 
BEGIN          1 QueryAdvisorRules.t:17 
BEGIN          1 QueryAdvisorRules.t:18 
BEGIN          1 QueryAdvisorRules.t:371
BEGIN          1 QueryAdvisorRules.t:4  
BEGIN          1 QueryAdvisorRules.t:9  
__ANON__       1 QueryAdvisorRules.t:109
__ANON__       1 QueryAdvisorRules.t:68 

Uncovered Subroutines
---------------------

Subroutine Count Location               
---------- ----- -----------------------
__ANON__       0 QueryAdvisorRules.t:104


