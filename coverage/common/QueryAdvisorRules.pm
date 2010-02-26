---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mmon/QueryAdvisorRules.pm   40.5   17.0    2.3   40.0    0.0   94.6   29.1
QueryAdvisorRules.t            94.7   50.0   33.3   91.7    n/a    5.4   85.4
Total                          53.3   18.4    7.5   54.8    0.0  100.0   39.6
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Feb 26 18:11:31 2010
Finish:       Fri Feb 26 18:11:31 2010

Run:          QueryAdvisorRules.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Feb 26 18:11:33 2010
Finish:       Fri Feb 26 18:11:33 2010

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
18                                                    # QueryAdvisorRules package $Revision: 5883 $
19                                                    # ###########################################################################
20                                                    package QueryAdvisorRules;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                 10   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  1   
               1                                  6   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  4   
25                                                    
26             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  5   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 12   
32                                                    
33                                                    sub new {
34    ***      1                    1      0      6      my ( $class, %args ) = @_;
35             1                                  4      foreach my $arg ( qw(PodParser) ) {
36    ***      1     50                           7         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38                                                    
39             1                                  7      my @rules = get_rules();
40             1                                  6      MKDEBUG && _d(scalar @rules, 'rules');
41                                                    
42             1                                  7      my $self = {
43                                                          %args,
44                                                          rules          => \@rules,
45                                                          rule_index_for => {},
46                                                          rule_info      => {},
47                                                       };
48                                                    
49             1                                  3      my $i = 0;
50             1                                  4      map { $self->{rule_index_for}->{ $_->{id} } = $i++ } @rules;
              17                                 87   
51                                                    
52             1                                 13      return bless $self, $class;
53                                                    }
54                                                    
55                                                    sub get_rules {
56                                                       return
57                                                       {
58                                                          id   => 'ALI.001',      # Implicit alias
59                                                          code => sub {
60    ***      0                    0             0            my ( %args ) = @_;
61    ***      0                                  0            my $struct = $args{query_struct};
62    ***      0             0                    0            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                    0                        
63    ***      0      0                           0            return unless $tbls;
64    ***      0                                  0            foreach my $tbl ( @$tbls ) {
65    ***      0      0      0                    0               return 1 if $tbl->{alias} && !$tbl->{explicit_alias};
66                                                             }
67    ***      0                                  0            my $cols = $struct->{columns};
68    ***      0      0                           0            return unless $cols;
69    ***      0                                  0            foreach my $col ( @$cols ) {
70    ***      0      0      0                    0               return 1 if $col->{alias} && !$col->{explicit_alias};
71                                                             }
72    ***      0                                  0            return 0;
73                                                          },
74                                                       },
75                                                       {
76                                                          id   => 'ALI.002',      # tbl.* alias
77                                                          code => sub {
78    ***      0                    0             0            my ( %args ) = @_;
79    ***      0                                  0            my $cols = $args{query_struct}->{columns};
80    ***      0      0                           0            return unless $cols;
81    ***      0                                  0            foreach my $col ( @$cols ) {
82    ***      0      0      0                    0               return 1 if $col->{db} && $col->{name } eq '*' &&  $col->{alias};
      ***                    0                        
83                                                             }
84    ***      0                                  0            return 0;
85                                                          },
86                                                       },
87                                                       {
88                                                          id   => 'ALI.003',      # tbl AS tbl
89                                                          code => sub {
90    ***      0                    0             0            my ( %args ) = @_;
91    ***      0                                  0            my $struct = $args{query_struct};
92    ***      0             0                    0            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                    0                        
93    ***      0      0                           0            return unless $tbls;
94    ***      0                                  0            foreach my $tbl ( @$tbls ) {
95    ***      0      0      0                    0               return 1 if $tbl->{alias} && $tbl->{alias} eq $tbl->{name};
96                                                             }
97    ***      0                                  0            my $cols = $struct->{columns};
98    ***      0      0                           0            return unless $cols;
99    ***      0                                  0            foreach my $col ( @$cols ) {
100   ***      0      0      0                    0               return 1 if $col->{alias} && $col->{alias} eq $col->{name};
101                                                            }
102   ***      0                                  0            return 0;
103                                                         },
104                                                      },
105                                                      {
106                                                         id   => 'ARG.001',      # col = '%foo'
107                                                         code => sub {
108   ***      0                    0             0            my ( %args ) = @_;
109   ***      0      0                           0            return 1 if $args{query} =~ m/[\'\"][\%\_]\w/;
110   ***      0                                  0            return 0;
111                                                         },
112                                                      },
113                                                      {
114                                                         id   => 'CLA.001',      # SELECT w/o WHERE
115                                                         code => sub {
116   ***      0                    0             0            my ( %args ) = @_;
117   ***      0      0                           0            return 0 unless $args{query_struct}->{type} eq 'select';
118   ***      0      0                           0            return 1 unless $args{query_struct}->{where};
119   ***      0                                  0            return 0;
120                                                         },
121                                                      },
122                                                      {
123                                                         id   => 'CLA.002',      # ORDER BY RAND()
124                                                         code => sub {
125   ***      0                    0             0            my ( %args ) = @_;
126   ***      0                                  0            my $orderby = $args{query_struct}->{order_by};
127   ***      0      0                           0            return unless $orderby;
128   ***      0                                  0            foreach my $col ( @$orderby ) {
129   ***      0      0                           0               return 1 if $col =~ m/RAND\([^\)]*\)/i;
130                                                            }
131   ***      0                                  0            return 0;
132                                                         },
133                                                      },
134                                                      {
135                                                         id   => 'CLA.003',      # LIMIT w/ OFFSET
136                                                         code => sub {
137   ***      0                    0             0            my ( %args ) = @_;
138   ***      0      0                           0            return 0 unless $args{query_struct}->{limit};
139   ***      0      0                           0            return 0 unless defined $args{query_struct}->{limit}->{offset};
140   ***      0                                  0            return 1;
141                                                         },
142                                                      },
143                                                      {
144                                                         id   => 'CLA.004',      # GROUP BY <number>
145                                                         code => sub {
146   ***      0                    0             0            my ( %args ) = @_;
147   ***      0                                  0            my $groupby = $args{query_struct}->{group_by};
148   ***      0      0                           0            return unless $groupby;
149   ***      0                                  0            foreach my $col ( @{$groupby->{columns}} ) {
      ***      0                                  0   
150   ***      0      0                           0               return 1 if $col =~ m/^\d+\b/;
151                                                            }
152   ***      0                                  0            return 0;
153                                                         },
154                                                      },
155                                                      {
156                                                         id   => 'COL.001',      # SELECT *
157                                                         code => sub {
158   ***      0                    0             0            my ( %args ) = @_;
159   ***      0                                  0            my $type = $args{query_struct}->{type} eq 'select';
160   ***      0                                  0            my $cols = $args{query_struct}->{columns};
161   ***      0      0                           0            return unless $cols;
162   ***      0                                  0            foreach my $col ( @$cols ) {
163   ***      0      0                           0               return 1 if $col->{name} eq '*';
164                                                            }
165   ***      0                                  0            return 0;
166                                                         },
167                                                      },
168                                                      {
169                                                         id   => 'COL.002',      # INSERT w/o (cols) def
170                                                         code => sub {
171   ***      0                    0             0            my ( %args ) = @_;
172   ***      0                                  0            my $type = $args{query_struct}->{type};
173   ***      0      0      0                    0            return 0 unless $type eq 'insert' || $type eq 'replace';
174   ***      0      0                           0            return 1 unless $args{query_struct}->{columns};
175   ***      0                                  0            return 0;
176                                                         },
177                                                      },
178                                                      {
179                                                         id   => 'LIT.001',      # IP as string
180                                                         code => sub {
181   ***      0                    0             0            my ( %args ) = @_;
182   ***      0                                  0            return $args{query} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;
183                                                         },
184                                                      },
185                                                      {
186                                                         id   => 'LIT.002',      # Date not quoted
187                                                         code => sub {
188   ***      0                    0             0            my ( %args ) = @_;
189   ***      0                                  0            return $args{query} =~ m/[^'"](?:\d{2,4}-\d{1,2}-\d{1,2}|\d{4,6})/;
190                                                         },
191                                                      },
192                                                      {
193                                                         id   => 'KWR.001',      # SQL_CALC_FOUND_ROWS
194                                                         code => sub {
195   ***      0                    0             0            my ( %args ) = @_;
196   ***      0      0                           0            return 1 if $args{query_struct}->{keywords}->{sql_calc_found_rows};
197   ***      0                                  0            return 0;
198                                                         },
199                                                      },
200                                                      {
201                                                         id   => 'JOI.001',      # comma and ansi joins
202                                                         code => sub {
203   ***      0                    0             0            my ( %args ) = @_;
204   ***      0                                  0            my $struct = $args{query_struct};
205   ***      0             0                    0            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                    0                        
206   ***      0      0                           0            return unless $tbls;
207   ***      0                                  0            my $comma_join = 0;
208   ***      0                                  0            my $ansi_join  = 0;
209   ***      0                                  0            foreach my $tbl ( @$tbls ) {
210   ***      0      0                           0               if ( $tbl->{join} ) {
211   ***      0      0                           0                  if ( $tbl->{join}->{ansi} ) {
212   ***      0                                  0                     $ansi_join = 1;
213                                                                  }
214                                                                  else {
215   ***      0                                  0                     $comma_join = 1;
216                                                                  }
217                                                               }
218   ***      0      0      0                    0               return 1 if $comma_join && $ansi_join;
219                                                            }
220   ***      0                                  0            return 0;
221                                                         },
222                                                      },
223                                                      {
224                                                         id   => 'RES.001',      # non-deterministic GROUP BY
225                                                         code => sub {
226   ***      0                    0             0            my ( %args ) = @_;
227   ***      0      0                           0            return unless $args{query_struct}->{type} eq 'select';
228   ***      0                                  0            my $groupby = $args{query_struct}->{group_by};
229   ***      0      0                           0            return unless $groupby;
230                                                            # Only check GROUP BY column names, not numbers.  GROUP BY number
231                                                            # is handled in CLA.004.
232   ***      0                                  0            my %groupby_col = map { $_ => 1 }
      ***      0                                  0   
233   ***      0                                  0                              grep { m/^[^\d]+\b/ }
234   ***      0                                  0                              @{$groupby->{columns}};
235   ***      0      0                           0            return unless scalar %groupby_col;
236   ***      0                                  0            my $cols = $args{query_struct}->{columns};
237                                                            # All SELECT cols must be in GROUP BY cols clause.
238                                                            # E.g. select a, b, c from tbl group by a; -- non-deterministic
239   ***      0                                  0            foreach my $col ( @$cols ) {
240   ***      0      0                           0               return 1 unless $groupby_col{ $col->{name} };
241                                                            }
242   ***      0                                  0            return 0;
243                                                         },
244                                                      },
245                                                      {
246                                                         id   => 'RES.002',      # non-deterministic LIMIT w/o ORDER BY
247                                                         code => sub {
248   ***      0                    0             0            my ( %args ) = @_;
249   ***      0      0                           0            return 0 unless $args{query_struct}->{limit};
250   ***      0      0                           0            return 1 unless $args{query_struct}->{order_by};
251   ***      0                                  0            return 0;
252                                                         },
253                                                      },
254                                                      {
255                                                         id   => 'STA.001',      # != instead of <>
256                                                         code => sub {
257   ***      0                    0             0            my ( %args ) = @_;
258   ***      0      0                           0            return 1 if $args{query} =~ m/!=/;
259   ***      0                                  0            return 0;
260                                                         },
261                                                      },
262   ***      2                    2      0    196   };
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
273   ***      3                    3      0     21      my ( $self, %args ) = @_;
274            3                                 14      foreach my $arg ( qw(rules file section) ) {
275   ***      9     50                          41         die "I need a $arg argument" unless $args{$arg};
276                                                      }
277            3                                 10      my $rules = $args{rules};  # requested/required rules
278            3                                 11      my $p     = $self->{PodParser};
279                                                   
280                                                      # Parse rules and their info from the file's POD, saving
281                                                      # values to %rule_info.  Our trf sub returns nothing so
282                                                      # parse_section() returns nothing.
283                                                      $p->parse_section(
284                                                         %args,
285                                                         trf  => sub {
286            6                    6         17688            my ( $para ) = @_;
287            6                                 18            chomp $para;
288            6                                 24            my $rule_info = _parse_rule_info($para);
289            6    100                          28            return unless $rule_info;
290                                                   
291   ***      3     50                          21            die "Rule info does not specify an ID:\n$para"
292                                                               unless $rule_info->{id};
293   ***      3     50                          13            die "Rule info does not specify a severity:\n$para"
294                                                               unless $rule_info->{severity};
295   ***      3     50                          13            die "Rule info does not specify a description:\n$para",
296                                                               unless $rule_info->{description};
297   ***      3     50                          17            die "Rule $rule_info->{id} is not defined"
298                                                               unless defined $self->{rule_index_for}->{ $rule_info->{id} };
299                                                   
300            3                                 11            my $id = $rule_info->{id};
301            3    100                          16            if ( exists $self->{rule_info}->{$id} ) {
302            1                                  4               die "Info for rule $rule_info->{id} already exists "
303                                                                  . "and cannot be redefined"
304                                                            }
305                                                   
306            2                                  9            $self->{rule_info}->{$id} = $rule_info;
307                                                   
308            2                                  7            return;
309                                                         },
310            3                                 40      );
311                                                   
312                                                      # Check that rule info was gotten for each requested rule.
313            2                                 60      foreach my $rule ( @$rules ) {
314            3    100                          17         die "There is no info for rule $rule->{id}"
315                                                            unless $self->{rule_info}->{ $rule->{id} };
316                                                      }
317                                                   
318            1                                  5      return;
319                                                   }
320                                                   
321                                                   sub get_rule_info {
322   ***      3                    3      0     13      my ( $self, $id ) = @_;
323            3    100                          15      return unless $id;
324            2                                 19      return $self->{rule_info}->{$id};
325                                                   }
326                                                   
327                                                   # Called by load_rule_info() to parse a rule paragraph from the POD.
328                                                   sub _parse_rule_info {
329            6                    6            21      my ( $para ) = @_;
330            6    100                          36      return unless $para =~ m/^id:/i;
331            3                                 11      my $rule_info = {};
332            3                                 25      my @lines = split("\n", $para);
333            3                                  8      my $line;
334                                                   
335                                                      # First 2 lines should be id and severity.
336            3                                 15      for ( 1..2 ) {
337            6                                 17         $line = shift @lines;
338            6                                 14         MKDEBUG && _d($line);
339            6                                 31         $line =~ m/(\w+):\s*(.+)/;
340            6                                 40         $rule_info->{lc $1} = uc $2;
341                                                      }
342                                                   
343                                                      # First line of desc.
344            3                                 10      $line = shift @lines;
345            3                                  7      MKDEBUG && _d($line);
346            3                                 14      $line =~ m/(\w+):\s*(.+)/;
347            3                                 10      my $desc        = lc $1;
348            3                                 15      $rule_info->{$desc} = $2;
349                                                      # Rest of desc.
350            3                                 14      while ( my $d = shift @lines ) {
351            6                                 37         $rule_info->{$desc} .= $d;
352                                                      }
353            3                                 42      $rule_info->{$desc} =~ s/\s+/ /g;
354            3                                 28      $rule_info->{$desc} =~ s/\s+$//;
355                                                   
356            3                                  7      MKDEBUG && _d('Parsed rule info:', Dumper($rule_info));
357            3                                 12      return $rule_info;
358                                                   }
359                                                   
360                                                   # Used for testing.
361                                                   sub _reset_rule_info {
362            1                    1             4      my ( $self ) = @_;
363            1                                  4      $self->{rule_info} = {};
364            1                                  5      return;
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
36    ***     50      0      1   unless $args{$arg}
63    ***      0      0      0   unless $tbls
65    ***      0      0      0   if $$tbl{'alias'} and not $$tbl{'explicit_alias'}
68    ***      0      0      0   unless $cols
70    ***      0      0      0   if $$col{'alias'} and not $$col{'explicit_alias'}
80    ***      0      0      0   unless $cols
82    ***      0      0      0   if $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
93    ***      0      0      0   unless $tbls
95    ***      0      0      0   if $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
98    ***      0      0      0   unless $cols
100   ***      0      0      0   if $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
109   ***      0      0      0   if $args{'query'} =~ /[\'\"][\%\_]\w/
117   ***      0      0      0   unless $args{'query_struct'}{'type'} eq 'select'
118   ***      0      0      0   unless $args{'query_struct'}{'where'}
127   ***      0      0      0   unless $orderby
129   ***      0      0      0   if $col =~ /RAND\([^\)]*\)/i
138   ***      0      0      0   unless $args{'query_struct'}{'limit'}
139   ***      0      0      0   unless defined $args{'query_struct'}{'limit'}{'offset'}
148   ***      0      0      0   unless $groupby
150   ***      0      0      0   if $col =~ /^\d+\b/
161   ***      0      0      0   unless $cols
163   ***      0      0      0   if $$col{'name'} eq '*'
173   ***      0      0      0   unless $type eq 'insert' or $type eq 'replace'
174   ***      0      0      0   unless $args{'query_struct'}{'columns'}
196   ***      0      0      0   if $args{'query_struct'}{'keywords'}{'sql_calc_found_rows'}
206   ***      0      0      0   unless $tbls
210   ***      0      0      0   if ($$tbl{'join'})
211   ***      0      0      0   if ($$tbl{'join'}{'ansi'}) { }
218   ***      0      0      0   if $comma_join and $ansi_join
227   ***      0      0      0   unless $args{'query_struct'}{'type'} eq 'select'
229   ***      0      0      0   unless $groupby
235   ***      0      0      0   unless scalar %groupby_col
240   ***      0      0      0   unless $groupby_col{$$col{'name'}}
249   ***      0      0      0   unless $args{'query_struct'}{'limit'}
250   ***      0      0      0   unless $args{'query_struct'}{'order_by'}
258   ***      0      0      0   if $args{'query'} =~ /!=/
275   ***     50      0      9   unless $args{$arg}
289          100      3      3   unless $rule_info
291   ***     50      0      3   unless $$rule_info{'id'}
293   ***     50      0      3   unless $$rule_info{'severity'}
295   ***     50      0      3   unless $$rule_info{'description'}
297   ***     50      0      3   unless defined $$self{'rule_index_for'}{$$rule_info{'id'}}
301          100      1      2   if (exists $$self{'rule_info'}{$id})
314          100      1      2   unless $$self{'rule_info'}{$$rule{'id'}}
323          100      1      2   unless $id
330          100      3      3   unless $para =~ /^id:/i
369   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
65    ***      0      0      0      0   $$tbl{'alias'} and not $$tbl{'explicit_alias'}
70    ***      0      0      0      0   $$col{'alias'} and not $$col{'explicit_alias'}
82    ***      0      0      0      0   $$col{'db'} and $$col{'name'} eq '*'
      ***      0      0      0      0   $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
95    ***      0      0      0      0   $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
100   ***      0      0      0      0   $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
218   ***      0      0      0      0   $comma_join and $ansi_join

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
62    ***      0      0      0      0   $$struct{'from'} || $$struct{'into'}
      ***      0      0      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
92    ***      0      0      0      0   $$struct{'from'} || $$struct{'into'}
      ***      0      0      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
173   ***      0      0      0      0   $type eq 'insert' or $type eq 'replace'
205   ***      0      0      0      0   $$struct{'from'} || $$struct{'into'}
      ***      0      0      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                                
---------------- ----- --- --------------------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:22 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:23 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:24 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:26 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:31 
__ANON__             6     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:286
_parse_rule_info     6     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:329
_reset_rule_info     1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:362
get_rule_info        3   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:322
get_rules            2   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:262
load_rule_info       3   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:273
new                  1   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:34 

Uncovered Subroutines
---------------------

Subroutine       Count Pod Location                                                
---------------- ----- --- --------------------------------------------------------
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:108
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:116
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:125
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:137
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:146
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:158
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:171
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:181
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:188
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:195
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:203
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:226
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:248
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:257
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:60 
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:78 
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:90 
_d                   0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:368


QueryAdvisorRules.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More tests => 8;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            11   use MaatkitTest;
               1                                  3   
               1                                 12   
15             1                    1            10   use PodParser;
               1                                  3   
               1                                 11   
16             1                    1             9   use QueryAdvisorRules;
               1                                  3   
               1                                 12   
17                                                    
18                                                    # This test should just test that the QueryAdvisor module conforms to the
19                                                    # expected interface:
20                                                    #   - It has a get_rules() method that returns a list of hashrefs:
21                                                    #     ({ID => 'ID', code => $code}, {ID => ..... }, .... )
22                                                    #   - It has a load_rule_info() method that accepts a list of hashrefs, which
23                                                    #     we'll use to load rule info from POD.  Our built-in rule module won't
24                                                    #     store its own rule info.  But plugins supplied by users should.
25                                                    #   - It has a get_rule_info() method that accepts an ID and returns a hashref:
26                                                    #     {ID => 'ID', Severity => 'NOTE|WARN|CRIT', Description => '......'}
27             1                                  9   my $p   = new PodParser();
28             1                                 32   my $qar = new QueryAdvisorRules(PodParser => $p);
29                                                    
30             1                                  6   my @rules = $qar->get_rules();
31             1                                  9   ok(
32                                                       scalar @rules,
33                                                       'Returns array of rules'
34                                                    );
35                                                    
36             1                                  4   my $rules_ok = 1;
37             1                                  5   foreach my $rule ( @rules ) {
38    ***     17     50     33                  218      if (    !$rule->{id}
      ***                   33                        
39                                                            || !$rule->{code}
40                                                            || (ref $rule->{code} ne 'CODE') )
41                                                       {
42    ***      0                                  0         $rules_ok = 0;
43    ***      0                                  0         last;
44                                                       }
45                                                    }
46                                                    ok(
47             1                                  5      $rules_ok,
48                                                       'All rules are proper'
49                                                    );
50                                                    
51                                                    # QueryAdvisorRules.pm has more rules than mqa-rule-LIT.001.pod so to avoid
52                                                    # "There is no info" errors we remove all but LIT.001.
53             1                                  5   @rules = grep { $_->{id} eq 'LIT.001' } @rules;
              17                                135   
54                                                    
55                                                    # Test that we can load rule info from POD.  Make a sample POD file that has a
56                                                    # single sample rule definition for LIT.001 or something.
57             1                                 11   $qar->load_rule_info(
58                                                       rules    => \@rules,
59                                                       file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
60                                                       section  => 'CHECKS',
61                                                    );
62                                                    
63                                                    # We shouldn't be able to load the same rule info twice.
64                                                    throws_ok(
65                                                       sub {
66             1                    1            19         $qar->load_rule_info(
67                                                             rules    => \@rules,
68                                                             file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
69                                                             section  => 'CHECKS',
70                                                          );
71                                                       },
72             1                                 19      qr/Info for rule \S+ already exists and cannot be redefined/,
73                                                       'Duplicate rule info is caught',
74                                                    );
75                                                    
76                                                    # Test that we can now get a hashref as described above.
77             1                                 17   is_deeply(
78                                                       $qar->get_rule_info('LIT.001'),
79                                                       {  id          => 'LIT.001',
80                                                          severity    => 'NOTE',
81                                                          description => "IP address used as string. The string literal looks like an IP address but is not used inside INET_ATON(). WHERE ip='127.0.0.1' is better as ip=INET_ATON('127.0.0.1') if the column is numeric.",
82                                                       },
83                                                       'get_rule_info(LIT.001) works',
84                                                    );
85                                                    
86                                                    # Test getting a nonexistent rule.
87             1                                 11   is(
88                                                       $qar->get_rule_info('BAR.002'),
89                                                       undef,
90                                                       "get_rule_info() nonexistent rule"
91                                                    );
92                                                    
93             1                                  5   is(
94                                                       $qar->get_rule_info(),
95                                                       undef,
96                                                       "get_rule_info(undef)"
97                                                    );
98                                                    
99                                                    # Add a rule for which there is no POD info and test that it's not allowed.
100                                                   push @rules, {
101                                                      id   => 'FOO.001',
102   ***      0                    0             0      code => sub { return },
103            1                                 10   };
104            1                                  6   $qar->_reset_rule_info();  # else we'll get "cannot redefine rule" error
105                                                   throws_ok (
106                                                      sub {
107            1                    1            17         $qar->load_rule_info(
108                                                            rules    => \@rules,
109                                                            file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
110                                                            section  => 'CHECKS',
111                                                         );
112                                                      },
113            1                                 13      qr/There is no info for rule FOO.001/,
114                                                      "Doesn't allow rules without info",
115                                                   );
116                                                   
117            1                                  9   pop @rules;
118                                                   
119                                                   # #############################################################################
120                                                   # Done.
121                                                   # #############################################################################
122            1                                  6   my $output = '';
123                                                   {
124            1                                  5      local *STDERR;
               1                                  6   
125            1                    1             2      open STDERR, '>', \$output;
               1                                275   
               1                                  3   
               1                                  6   
126            1                                 16      $p->_d('Complete test coverage');
127                                                   }
128                                                   like(
129            1                                 15      $output,
130                                                      qr/Complete test coverage/,
131                                                      '_d() works'
132                                                   );
133            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}
38    ***     50      0     17   if (not $$rule{'id'} or not $$rule{'code'} or ref $$rule{'code'} ne 'CODE')


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
38    ***     33      0      0     17   not $$rule{'id'} or not $$rule{'code'}
      ***     33      0      0     17   not $$rule{'id'} or not $$rule{'code'} or ref $$rule{'code'} ne 'CODE'


Covered Subroutines
-------------------

Subroutine Count Location               
---------- ----- -----------------------
BEGIN          1 QueryAdvisorRules.t:10 
BEGIN          1 QueryAdvisorRules.t:11 
BEGIN          1 QueryAdvisorRules.t:12 
BEGIN          1 QueryAdvisorRules.t:125
BEGIN          1 QueryAdvisorRules.t:14 
BEGIN          1 QueryAdvisorRules.t:15 
BEGIN          1 QueryAdvisorRules.t:16 
BEGIN          1 QueryAdvisorRules.t:4  
BEGIN          1 QueryAdvisorRules.t:9  
__ANON__       1 QueryAdvisorRules.t:107
__ANON__       1 QueryAdvisorRules.t:66 

Uncovered Subroutines
---------------------

Subroutine Count Location               
---------- ----- -----------------------
__ANON__       0 QueryAdvisorRules.t:102


