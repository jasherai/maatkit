---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mmon/QueryAdvisorRules.pm   96.2   86.2   68.2   96.7    0.0   57.0   89.1
QueryAdvisorRules.t            95.9   50.0   33.3   92.9    n/a   43.0   88.1
Total                          96.1   84.7   62.3   95.5    0.0  100.0   88.9
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Mar  2 15:59:40 2010
Finish:       Tue Mar  2 15:59:40 2010

Run:          QueryAdvisorRules.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Mar  2 15:59:42 2010
Finish:       Tue Mar  2 15:59:42 2010

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
18                                                    # QueryAdvisorRules package $Revision: 5904 $
19                                                    # ###########################################################################
20                                                    package QueryAdvisorRules;
21                                                    
22             1                    1             5   use strict;
               1                                  1   
               1                                  9   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  4   
25                                                    
26             1                    1             5   use Data::Dumper;
               1                                  3   
               1                                  5   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 11   
32                                                    
33                                                    sub new {
34    ***      2                    2      0     12      my ( $class, %args ) = @_;
35             2                                  8      foreach my $arg ( qw(PodParser) ) {
36    ***      2     50                          14         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38                                                    
39             2                                  8      my @rules = get_rules();
40             2                                 10      MKDEBUG && _d(scalar @rules, 'rules');
41                                                    
42             2                                 16      my $self = {
43                                                          %args,
44                                                          rules          => \@rules,
45                                                          rule_index_for => {},
46                                                          rule_info      => {},
47                                                       };
48                                                    
49             2                                  6      my $i = 0;
50             2                                  7      map { $self->{rule_index_for}->{ $_->{id} } = $i++ } @rules;
              34                                168   
51                                                    
52             2                                 20      return bless $self, $class;
53                                                    }
54                                                    
55                                                    sub get_rules {
56                                                       return
57                                                       {
58                                                          id   => 'ALI.001',      # Implicit alias
59                                                          code => sub {
60            21                   21           493            my ( %args ) = @_;
61            21                                 74            my $struct = $args{query_struct};
62    ***     21            66                  127            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                   33                        
63    ***     21     50                          76            return unless $tbls;
64            21                                 67            foreach my $tbl ( @$tbls ) {
65    ***     25     50     66                  165               return 1 if $tbl->{alias} && !$tbl->{explicit_alias};
66                                                             }
67            21                                 72            my $cols = $struct->{columns};
68            21    100                          79            return unless $cols;
69            19                                 65            foreach my $col ( @$cols ) {
70            22    100    100                  146               return 1 if $col->{alias} && !$col->{explicit_alias};
71                                                             }
72            17                                106            return 0;
73                                                          },
74                                                       },
75                                                       {
76                                                          id   => 'ALI.002',      # tbl.* alias
77                                                          code => sub {
78            21                   21           216            my ( %args ) = @_;
79            21                                 85            my $cols = $args{query_struct}->{columns};
80            21    100                          81            return unless $cols;
81            19                                 67            foreach my $col ( @$cols ) {
82    ***     22    100     66                  165               return 1 if $col->{db} && $col->{name } eq '*' &&  $col->{alias};
      ***                   66                        
83                                                             }
84            18                                 98            return 0;
85                                                          },
86                                                       },
87                                                       {
88                                                          id   => 'ALI.003',      # tbl AS tbl
89                                                          code => sub {
90            21                   21           200            my ( %args ) = @_;
91            21                                 77            my $struct = $args{query_struct};
92    ***     21            66                  133            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                   33                        
93    ***     21     50                          76            return unless $tbls;
94            21                                 71            foreach my $tbl ( @$tbls ) {
95            25    100    100                  176               return 1 if $tbl->{alias} && $tbl->{alias} eq $tbl->{name};
96                                                             }
97            20                                 67            my $cols = $struct->{columns};
98            20    100                          71            return unless $cols;
99            18                                 52            foreach my $col ( @$cols ) {
100           21    100    100                  135               return 1 if $col->{alias} && $col->{alias} eq $col->{name};
101                                                            }
102           17                                 97            return 0;
103                                                         },
104                                                      },
105                                                      {
106                                                         id   => 'ARG.001',      # col = '%foo'
107                                                         code => sub {
108           21                   21           207            my ( %args ) = @_;
109           21    100                         113            return 1 if $args{query} =~ m/[\'\"][\%\_]\w/;
110           20                                107            return 0;
111                                                         },
112                                                      },
113                                                      {
114                                                         id   => 'CLA.001',      # SELECT w/o WHERE
115                                                         code => sub {
116           21                   21           196            my ( %args ) = @_;
117           21    100                         119            return 0 unless $args{query_struct}->{type} eq 'select';
118           19    100                          87            return 1 unless $args{query_struct}->{where};
119           18                                 97            return 0;
120                                                         },
121                                                      },
122                                                      {
123                                                         id   => 'CLA.002',      # ORDER BY RAND()
124                                                         code => sub {
125           21                   21           188            my ( %args ) = @_;
126           21                                 88            my $orderby = $args{query_struct}->{order_by};
127           21    100                         120            return unless $orderby;
128            4                                 15            foreach my $col ( @$orderby ) {
129            4    100                          29               return 1 if $col =~ m/RAND\([^\)]*\)/i;
130                                                            }
131            2                                 12            return 0;
132                                                         },
133                                                      },
134                                                      {
135                                                         id   => 'CLA.003',      # LIMIT w/ OFFSET
136                                                         code => sub {
137           21                   21           200            my ( %args ) = @_;
138           21    100                         166            return 0 unless $args{query_struct}->{limit};
139            3    100                          20            return 0 unless defined $args{query_struct}->{limit}->{offset};
140            2                                 11            return 1;
141                                                         },
142                                                      },
143                                                      {
144                                                         id   => 'CLA.004',      # GROUP BY <number>
145                                                         code => sub {
146           21                   21           202            my ( %args ) = @_;
147           21                                 82            my $groupby = $args{query_struct}->{group_by};
148           21    100                         124            return unless $groupby;
149            3                                  7            foreach my $col ( @{$groupby->{columns}} ) {
               3                                 14   
150            4    100                          26               return 1 if $col =~ m/^\d+\b/;
151                                                            }
152            2                                 11            return 0;
153                                                         },
154                                                      },
155                                                      {
156                                                         id   => 'COL.001',      # SELECT *
157                                                         code => sub {
158           21                   21           231            my ( %args ) = @_;
159           21                                 91            my $type = $args{query_struct}->{type} eq 'select';
160           21                                 75            my $cols = $args{query_struct}->{columns};
161           21    100                          80            return unless $cols;
162           19                                 64            foreach my $col ( @$cols ) {
163           22    100                         121               return 1 if $col->{name} eq '*';
164                                                            }
165           17                                 96            return 0;
166                                                         },
167                                                      },
168                                                      {
169                                                         id   => 'COL.002',      # INSERT w/o (cols) def
170                                                         code => sub {
171           21                   21           206            my ( %args ) = @_;
172           21                                 87            my $type = $args{query_struct}->{type};
173   ***     21    100     66                  248            return 0 unless $type eq 'insert' || $type eq 'replace';
174   ***      2     50                          16            return 1 unless $args{query_struct}->{columns};
175   ***      0                                  0            return 0;
176                                                         },
177                                                      },
178                                                      {
179                                                         id   => 'LIT.001',      # IP as string
180                                                         code => sub {
181           21                   21           211            my ( %args ) = @_;
182           21                                163            return $args{query} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;
183                                                         },
184                                                      },
185                                                      {
186                                                         id   => 'LIT.002',      # Date not quoted
187                                                         code => sub {
188           21                   21           197            my ( %args ) = @_;
189           21                                382            return $args{query} =~ m/[^'"](?:\d{2,4}-\d{1,2}-\d{1,2}|\d{4,6})/;
190                                                         },
191                                                      },
192                                                      {
193                                                         id   => 'KWR.001',      # SQL_CALC_FOUND_ROWS
194                                                         code => sub {
195           21                   21           205            my ( %args ) = @_;
196           21    100                         130            return 1 if $args{query_struct}->{keywords}->{sql_calc_found_rows};
197           20                                105            return 0;
198                                                         },
199                                                      },
200                                                      {
201                                                         id   => 'JOI.001',      # comma and ansi joins
202                                                         code => sub {
203           21                   21           202            my ( %args ) = @_;
204           21                                 72            my $struct = $args{query_struct};
205   ***     21            66                  161            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                   33                        
206   ***     21     50                          68            return unless $tbls;
207           21                                 54            my $comma_join = 0;
208           21                                 54            my $ansi_join  = 0;
209           21                                 69            foreach my $tbl ( @$tbls ) {
210           25    100                         103               if ( $tbl->{join} ) {
211            4    100                          18                  if ( $tbl->{join}->{ansi} ) {
212            2                                  5                     $ansi_join = 1;
213                                                                  }
214                                                                  else {
215            2                                  6                     $comma_join = 1;
216                                                                  }
217                                                               }
218           25    100    100                  150               return 1 if $comma_join && $ansi_join;
219                                                            }
220           20                                113            return 0;
221                                                         },
222                                                      },
223                                                      {
224                                                         id   => 'RES.001',      # non-deterministic GROUP BY
225                                                         code => sub {
226           21                   21           194            my ( %args ) = @_;
227           21    100                         115            return unless $args{query_struct}->{type} eq 'select';
228           19                                 68            my $groupby = $args{query_struct}->{group_by};
229           19    100                         109            return unless $groupby;
230                                                            # Only check GROUP BY column names, not numbers.  GROUP BY number
231                                                            # is handled in CLA.004.
232            3                                 15            my %groupby_col = map { $_ => 1 }
               4                                 19   
233            3                                 26                              grep { m/^[^\d]+\b/ }
234            3                                 10                              @{$groupby->{columns}};
235            3    100                          21            return unless scalar %groupby_col;
236            2                                  8            my $cols = $args{query_struct}->{columns};
237                                                            # All SELECT cols must be in GROUP BY cols clause.
238                                                            # E.g. select a, b, c from tbl group by a; -- non-deterministic
239            2                                  8            foreach my $col ( @$cols ) {
240            4    100                          23               return 1 unless $groupby_col{ $col->{name} };
241                                                            }
242            1                                  7            return 0;
243                                                         },
244                                                      },
245                                                      {
246                                                         id   => 'RES.002',      # non-deterministic LIMIT w/o ORDER BY
247                                                         code => sub {
248           21                   21           190            my ( %args ) = @_;
249           21    100                         166            return 0 unless $args{query_struct}->{limit};
250            3    100                          16            return 1 unless $args{query_struct}->{order_by};
251            2                                 11            return 0;
252                                                         },
253                                                      },
254                                                      {
255                                                         id   => 'STA.001',      # != instead of <>
256                                                         code => sub {
257           21                   21           190            my ( %args ) = @_;
258           21    100                         102            return 1 if $args{query} =~ m/!=/;
259           20                                115            return 0;
260                                                         },
261                                                      },
262   ***      5                    5      0    472   };
263                                                   
264                                                   # Arguments:
265                                                   #   * rules      arrayref: rules for which info is required
266                                                   #   * file       scalar: file name with POD to parse rules from
267                                                   #   * section    scalar: head1 seciton name in file/POD
268                                                   #   * subsection scalar: (optional) head2 section name in section
269                                                   # Parses rules from the POD section/subsection in file, adding rule
270                                                   # info found therein to %rule_info.  Then checks that rule info
271                                                   # was gotten for all the required rules.
272                                                   sub load_rule_info {
273   ***      4                    4      0     38      my ( $self, %args ) = @_;
274            4                                 15      foreach my $arg ( qw(rules file section) ) {
275   ***     12     50                          56         die "I need a $arg argument" unless $args{$arg};
276                                                      }
277            4                                 16      my $rules = $args{rules};  # requested/required rules
278            4                                 13      my $p     = $self->{PodParser};
279                                                   
280                                                      # Parse rules and their info from the file's POD, saving
281                                                      # values to %rule_info.  Our trf sub returns nothing so
282                                                      # parse_section() returns nothing.
283                                                      $p->parse_section(
284                                                         %args,
285                                                         trf  => sub {
286           24                   24          4907            my ( $para ) = @_;
287           24                                 69            chomp $para;
288           24                                 80            my $rule_info = _parse_rule_info($para);
289           24    100                          95            return unless $rule_info;
290                                                   
291   ***     20     50                          75            die "Rule info does not specify an ID:\n$para"
292                                                               unless $rule_info->{id};
293   ***     20     50                          91            die "Rule info does not specify a severity:\n$para"
294                                                               unless $rule_info->{severity};
295   ***     20     50                          74            die "Rule info does not specify a description:\n$para",
296                                                               unless $rule_info->{description};
297   ***     20     50                         109            die "Rule $rule_info->{id} is not defined"
298                                                               unless defined $self->{rule_index_for}->{ $rule_info->{id} };
299                                                   
300           20                                 61            my $id = $rule_info->{id};
301           20    100                          91            if ( exists $self->{rule_info}->{$id} ) {
302            1                                  3               die "Info for rule $rule_info->{id} already exists "
303                                                                  . "and cannot be redefined"
304                                                            }
305                                                   
306           19                                 68            $self->{rule_info}->{$id} = $rule_info;
307                                                   
308           19                                 67            return;
309                                                         },
310            4                                 46      );
311                                                   
312                                                      # Check that rule info was gotten for each requested rule.
313            3                                 79      foreach my $rule ( @$rules ) {
314           20    100                         106         die "There is no info for rule $rule->{id} in $args{file}"
315                                                            unless $self->{rule_info}->{ $rule->{id} };
316                                                      }
317                                                   
318            2                                  9      return;
319                                                   }
320                                                   
321                                                   sub get_rule_info {
322   ***     20                   20      0    357      my ( $self, $id ) = @_;
323           20    100                          71      return unless $id;
324           19                                 95      return $self->{rule_info}->{$id};
325                                                   }
326                                                   
327                                                   # Called by load_rule_info() to parse a rule paragraph from the POD.
328                                                   sub _parse_rule_info {
329           24                   24            83      my ( $para ) = @_;
330           24    100                         122      return unless $para =~ m/^id:/i;
331           20                                 58      my $rule_info = {};
332           20                                131      my @lines = split("\n", $para);
333           20                                 54      my $line;
334                                                   
335                                                      # First 2 lines should be id and severity.
336           20                                 72      for ( 1..2 ) {
337           40                                110         $line = shift @lines;
338           40                                 90         MKDEBUG && _d($line);
339           40                                169         $line =~ m/(\w+):\s*(.+)/;
340           40                                237         $rule_info->{lc $1} = uc $2;
341                                                      }
342                                                   
343                                                      # First line of desc.
344           20                                 61      $line = shift @lines;
345           20                                 44      MKDEBUG && _d($line);
346           20                                 83      $line =~ m/(\w+):\s*(.+)/;
347           20                                 68      my $desc        = lc $1;
348           20                                 94      $rule_info->{$desc} = $2;
349                                                      # Rest of desc.
350           20                                 92      while ( my $d = shift @lines ) {
351           17                                102         $rule_info->{$desc} .= $d;
352                                                      }
353           20                                172      $rule_info->{$desc} =~ s/\s+/ /g;
354           20                                137      $rule_info->{$desc} =~ s/\s+$//;
355                                                   
356           20                                 43      MKDEBUG && _d('Parsed rule info:', Dumper($rule_info));
357           20                                 68      return $rule_info;
358                                                   }
359                                                   
360                                                   # Used for testing.
361                                                   sub _reset_rule_info {
362            1                    1             4      my ( $self ) = @_;
363            1                                  4      $self->{rule_info} = {};
364            1                                  6      return;
365                                                   }
366                                                   
367                                                   sub _d {
368   ***      0                    0                    my ($package, undef, $line) = caller 0;
369   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
370   ***      0                                              map { defined $_ ? $_ : 'undef' }
371                                                           @_;
372   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
373                                                   }
374                                                   
375                                                   1;
376                                                   
377                                                   # ###########################################################################
378                                                   # End QueryAdvisorRules package
379                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
36    ***     50      0      2   unless $args{$arg}
63    ***     50      0     21   unless $tbls
65    ***     50      0     25   if $$tbl{'alias'} and not $$tbl{'explicit_alias'}
68           100      2     19   unless $cols
70           100      2     20   if $$col{'alias'} and not $$col{'explicit_alias'}
80           100      2     19   unless $cols
82           100      1     21   if $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
93    ***     50      0     21   unless $tbls
95           100      1     24   if $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
98           100      2     18   unless $cols
100          100      1     20   if $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
109          100      1     20   if $args{'query'} =~ /[\'\"][\%\_]\w/
117          100      2     19   unless $args{'query_struct'}{'type'} eq 'select'
118          100      1     18   unless $args{'query_struct'}{'where'}
127          100     17      4   unless $orderby
129          100      2      2   if $col =~ /RAND\([^\)]*\)/i
138          100     18      3   unless $args{'query_struct'}{'limit'}
139          100      1      2   unless defined $args{'query_struct'}{'limit'}{'offset'}
148          100     18      3   unless $groupby
150          100      1      3   if $col =~ /^\d+\b/
161          100      2     19   unless $cols
163          100      2     20   if $$col{'name'} eq '*'
173          100     19      2   unless $type eq 'insert' or $type eq 'replace'
174   ***     50      2      0   unless $args{'query_struct'}{'columns'}
196          100      1     20   if $args{'query_struct'}{'keywords'}{'sql_calc_found_rows'}
206   ***     50      0     21   unless $tbls
210          100      4     21   if ($$tbl{'join'})
211          100      2      2   if ($$tbl{'join'}{'ansi'}) { }
218          100      1     24   if $comma_join and $ansi_join
227          100      2     19   unless $args{'query_struct'}{'type'} eq 'select'
229          100     16      3   unless $groupby
235          100      1      2   unless scalar %groupby_col
240          100      1      3   unless $groupby_col{$$col{'name'}}
249          100     18      3   unless $args{'query_struct'}{'limit'}
250          100      1      2   unless $args{'query_struct'}{'order_by'}
258          100      1     20   if $args{'query'} =~ /!=/
275   ***     50      0     12   unless $args{$arg}
289          100      4     20   unless $rule_info
291   ***     50      0     20   unless $$rule_info{'id'}
293   ***     50      0     20   unless $$rule_info{'severity'}
295   ***     50      0     20   unless $$rule_info{'description'}
297   ***     50      0     20   unless defined $$self{'rule_index_for'}{$$rule_info{'id'}}
301          100      1     19   if (exists $$self{'rule_info'}{$id})
314          100      1     19   unless $$self{'rule_info'}{$$rule{'id'}}
323          100      1     19   unless $id
330          100      4     20   unless $para =~ /^id:/i
369   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
65    ***     66     22      3      0   $$tbl{'alias'} and not $$tbl{'explicit_alias'}
70           100     19      1      2   $$col{'alias'} and not $$col{'explicit_alias'}
82    ***     66     21      0      1   $$col{'db'} and $$col{'name'} eq '*'
      ***     66     21      0      1   $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
95           100     22      2      1   $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
100          100     18      2      1   $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
218          100     22      2      1   $comma_join and $ansi_join

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
62    ***     66     19      2      0   $$struct{'from'} || $$struct{'into'}
      ***     33     21      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
92    ***     66     19      2      0   $$struct{'from'} || $$struct{'into'}
      ***     33     21      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
173   ***     66      2      0     19   $type eq 'insert' or $type eq 'replace'
205   ***     66     19      2      0   $$struct{'from'} || $$struct{'into'}
      ***     33     21      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                                
---------------- ----- --- --------------------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:22 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:23 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:24 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:26 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:31 
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:108
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:116
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:125
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:137
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:146
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:158
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:171
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:181
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:188
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:195
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:203
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:226
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:248
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:257
__ANON__            24     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:286
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:60 
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:78 
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:90 
_parse_rule_info    24     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:329
_reset_rule_info     1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:362
get_rule_info       20   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:322
get_rules            5   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:262
load_rule_info       4   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:273
new                  2   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:34 

Uncovered Subroutines
---------------------

Subroutine       Count Pod Location                                                
---------------- ----- --- --------------------------------------------------------
_d                   0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:368


QueryAdvisorRules.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1            10   use Test::More tests => 29;
               1                                  2   
               1                                  9   
13                                                    
14             1                    1            12   use MaatkitTest;
               1                                  3   
               1                                 10   
15             1                    1            12   use PodParser;
               1                                  2   
               1                                 10   
16             1                    1            10   use QueryAdvisorRules;
               1                                  3   
               1                                 11   
17             1                    1            12   use QueryAdvisor;
               1                                  3   
               1                                 10   
18             1                    1            11   use SQLParser;
               1                                  3   
               1                                 10   
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
29             1                                  9   my $p   = new PodParser();
30             1                                 33   my $qar = new QueryAdvisorRules(PodParser => $p);
31                                                    
32             1                                  4   my @rules = $qar->get_rules();
33             1                                 12   ok(
34                                                       scalar @rules,
35                                                       'Returns array of rules'
36                                                    );
37                                                    
38             1                                  4   my $rules_ok = 1;
39             1                                  5   foreach my $rule ( @rules ) {
40    ***     17     50     33                  218      if (    !$rule->{id}
      ***                   33                        
41                                                            || !$rule->{code}
42                                                            || (ref $rule->{code} ne 'CODE') )
43                                                       {
44    ***      0                                  0         $rules_ok = 0;
45    ***      0                                  0         last;
46                                                       }
47                                                    }
48                                                    ok(
49             1                                  5      $rules_ok,
50                                                       'All rules are proper'
51                                                    );
52                                                    
53                                                    # QueryAdvisorRules.pm has more rules than mqa-rule-LIT.001.pod so to avoid
54                                                    # "There is no info" errors we remove all but LIT.001.
55             1                                  5   @rules = grep { $_->{id} eq 'LIT.001' } @rules;
              17                                137   
56                                                    
57                                                    # Test that we can load rule info from POD.  Make a sample POD file that has a
58                                                    # single sample rule definition for LIT.001 or something.
59             1                                 11   $qar->load_rule_info(
60                                                       rules    => \@rules,
61                                                       file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
62                                                       section  => 'CHECKS',
63                                                    );
64                                                    
65                                                    # We shouldn't be able to load the same rule info twice.
66                                                    throws_ok(
67                                                       sub {
68             1                    1            18         $qar->load_rule_info(
69                                                             rules    => \@rules,
70                                                             file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
71                                                             section  => 'CHECKS',
72                                                          );
73                                                       },
74             1                                 17      qr/Info for rule \S+ already exists and cannot be redefined/,
75                                                       'Duplicate rule info is caught',
76                                                    );
77                                                    
78                                                    # Test that we can now get a hashref as described above.
79             1                                 18   is_deeply(
80                                                       $qar->get_rule_info('LIT.001'),
81                                                       {  id          => 'LIT.001',
82                                                          severity    => 'NOTE',
83                                                          description => "IP address used as string. The string literal looks like an IP address but is not used inside INET_ATON(). WHERE ip='127.0.0.1' is better as ip=INET_ATON('127.0.0.1') if the column is numeric.",
84                                                       },
85                                                       'get_rule_info(LIT.001) works',
86                                                    );
87                                                    
88                                                    # Test getting a nonexistent rule.
89             1                                 18   is(
90                                                       $qar->get_rule_info('BAR.002'),
91                                                       undef,
92                                                       "get_rule_info() nonexistent rule"
93                                                    );
94                                                    
95             1                                  5   is(
96                                                       $qar->get_rule_info(),
97                                                       undef,
98                                                       "get_rule_info(undef)"
99                                                    );
100                                                   
101                                                   # Add a rule for which there is no POD info and test that it's not allowed.
102                                                   push @rules, {
103                                                      id   => 'FOO.001',
104   ***      0                    0             0      code => sub { return },
105            1                                  9   };
106            1                                  6   $qar->_reset_rule_info();  # else we'll get "cannot redefine rule" error
107                                                   throws_ok (
108                                                      sub {
109            1                    1            17         $qar->load_rule_info(
110                                                            rules    => \@rules,
111                                                            file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
112                                                            section  => 'CHECKS',
113                                                         );
114                                                      },
115            1                                 13      qr/There is no info for rule FOO.001/,
116                                                      "Doesn't allow rules without info",
117                                                   );
118                                                   
119                                                   # ###########################################################################
120                                                   # Test cases for the rules themselves.
121                                                   # ###########################################################################
122            1                                 78   my @cases = (
123                                                      {  name   => 'IP address not inside INET_ATON, plus SELECT * is used',
124                                                         query  => 'SELECT * FROM tbl WHERE ip="127.0.0.1"',
125                                                         advice => [qw(LIT.001 COL.001)],
126                                                      },
127                                                      {  name   => 'Date literal not quoted',
128                                                         query  => 'SELECT col FROM tbl WHERE col < 2001-01-01',
129                                                         advice => [qw(LIT.002)],
130                                                      },
131                                                      {  name   => 'Aliases without AS keyword',
132                                                         query  => 'SELECT a b FROM tbl',
133                                                         advice => [qw(ALI.001 CLA.001)],
134                                                      },
135                                                      {  name   => 'tbl.* alias',
136                                                         query  => 'SELECT tbl.* foo FROM bar WHERE id=1',
137                                                         advice => [qw(ALI.001 ALI.002 COL.001)],
138                                                      },
139                                                      {  name   => 'tbl as tbl',
140                                                         query  => 'SELECT col FROM tbl AS tbl WHERE id',
141                                                         advice => [qw(ALI.003)],
142                                                      },
143                                                      {  name   => 'col as col',
144                                                         query  => 'SELECT col AS col FROM tbl AS `my tbl` WHERE id',
145                                                         advice => [qw(ALI.003)],
146                                                      },
147                                                      {  name   => 'Blind INSERT',
148                                                         query  => 'INSERT INTO tbl VALUES(1),(2)',
149                                                         advice => [qw(COL.002)],
150                                                      },
151                                                      {  name   => 'Blind INSERT',
152                                                         query  => 'INSERT tbl VALUE (1)',
153                                                         advice => [qw(COL.002)],
154                                                      },
155                                                      {  name   => 'SQL_CALC_FOUND_ROWS',
156                                                         query  => 'SELECT SQL_CALC_FOUND_ROWS col FROM tbl AS alias WHERE id=1',
157                                                         advice => [qw(KWR.001)],
158                                                      },
159                                                      {  name   => 'All comma joins ok',
160                                                         query  => 'SELECT col FROM tbl1, tbl2 WHERE tbl1.id=tbl2.id',
161                                                         advice => [],
162                                                      },
163                                                      {  name   => 'All ANSI joins ok',
164                                                         query  => 'SELECT col FROM tbl1 JOIN tbl2 USING(id) WHERE tbl1.id>10',
165                                                         advice => [],
166                                                      },
167                                                      {  name   => 'Mix comman/ANSI joins',
168                                                         query  => 'SELECT col FROM tbl, tbl1 JOIN tbl2 USING(id) WHERE tbl.d>10',
169                                                         advice => [qw(JOI.001)],
170                                                      },
171                                                      {  name   => 'Non-deterministic GROUP BY',
172                                                         query  => 'select a, b, c from tbl where foo group by a',
173                                                         advice => [qw(RES.001)],
174                                                      },
175                                                      {  name   => 'Non-deterministic LIMIT w/o ORDER BY',
176                                                         query  => 'select a, b from tbl where foo limit 10 group by a, b',
177                                                         advice => [qw(RES.002)],
178                                                      },
179                                                      {  name   => 'ORDER BY RAND()',
180                                                         query  => 'select a from t where id order by rand()',
181                                                         advice => [qw(CLA.002)],
182                                                      },
183                                                      {  name   => 'ORDER BY RAND(N)',
184                                                         query  => 'select a from t where id order by rand(123)',
185                                                         advice => [qw(CLA.002)],
186                                                      },
187                                                      {  name   => 'LIMIT w/ OFFSET does not scale',
188                                                         query  => 'select a from t where i limit 10, 10 order by a',
189                                                         advice => [qw(CLA.003)],
190                                                      },
191                                                      {  name   => 'LIMIT w/ OFFSET does not scale',
192                                                         query  => 'select a from t where i limit 10 OFFSET 10 order by a',
193                                                         advice => [qw(CLA.003)],
194                                                      },
195                                                      {  name   => 'Leading %wildcard',
196                                                         query  => 'select a from t where i="%hm"',
197                                                         advice => [qw(ARG.001)],
198                                                      },
199                                                      {  name   => 'GROUP BY number',
200                                                         query  => 'select a from t where i group by 1',
201                                                         advice => [qw(CLA.004)],
202                                                      },
203                                                      {  name   => '!= instead of <>',
204                                                         query  => 'select a from t where i != 2',
205                                                         advice => [qw(STA.001)],
206                                                      },
207                                                   );
208                                                   
209                                                   # Run the test cases.
210            1                                 11   $qar = new QueryAdvisorRules(PodParser => $p);
211            1                                 91   $qar->load_rule_info(
212                                                      rules   => [ $qar->get_rules() ],
213                                                      file    => "$trunk/mk-query-advisor/mk-query-advisor",
214                                                      section => 'RULES',
215                                                   );
216                                                   
217            1                                 88   my $qa = new QueryAdvisor();
218            1                                 44   $qa->load_rules($qar);
219            1                                308   $qa->load_rule_info($qar);
220                                                   
221            1                                 23   my $sp = new SQLParser();
222                                                   
223            1                                 23   foreach my $test ( @cases ) {
224           21                                368      my $query_struct = $sp->parse($test->{query});
225           21                              12700      my %args = (
226                                                         query        => $test->{query},
227                                                         query_struct => $query_struct,
228                                                      );
229           21                                321      is_deeply(
230                                                         [ $qa->run_rules(%args) ],
231           21                                123         [ sort @{$test->{advice}} ],
232                                                         $test->{name},
233                                                      );
234                                                   }
235                                                   
236                                                   # #############################################################################
237                                                   # Done.
238                                                   # #############################################################################
239            1                                 15   my $output = '';
240                                                   {
241            1                                  2      local *STDERR;
               1                                  9   
242            1                    1             3      open STDERR, '>', \$output;
               1                                318   
               1                                  2   
               1                                  7   
243            1                                 17      $p->_d('Complete test coverage');
244                                                   }
245                                                   like(
246            1                                 15      $output,
247                                                      qr/Complete test coverage/,
248                                                      '_d() works'
249                                                   );
250            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
40    ***     50      0     17   if (not $$rule{'id'} or not $$rule{'code'} or ref $$rule{'code'} ne 'CODE')


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
40    ***     33      0      0     17   not $$rule{'id'} or not $$rule{'code'}
      ***     33      0      0     17   not $$rule{'id'} or not $$rule{'code'} or ref $$rule{'code'} ne 'CODE'


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
BEGIN          1 QueryAdvisorRules.t:242
BEGIN          1 QueryAdvisorRules.t:4  
BEGIN          1 QueryAdvisorRules.t:9  
__ANON__       1 QueryAdvisorRules.t:109
__ANON__       1 QueryAdvisorRules.t:68 

Uncovered Subroutines
---------------------

Subroutine Count Location               
---------- ----- -----------------------
__ANON__       0 QueryAdvisorRules.t:104


