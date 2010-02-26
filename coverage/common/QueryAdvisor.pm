---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/QueryAdvisor.pm   82.5   50.0   50.0   80.0    0.0    9.5   70.7
...mmon/QueryAdvisorRules.pm   94.1   83.0   68.2   93.3    0.0   47.8   86.8
QueryAdvisor.t                100.0   50.0   33.3  100.0    n/a   42.8   95.9
Total                          93.0   77.2   65.3   92.5    0.0  100.0   85.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Feb 26 18:11:23 2010
Finish:       Fri Feb 26 18:11:23 2010

Run:          QueryAdvisor.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Feb 26 18:11:25 2010
Finish:       Fri Feb 26 18:11:25 2010

/home/daniel/dev/maatkit/common/QueryAdvisor.pm

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
18                                                    # QueryAdvisor package $Revision: 5845 $
19                                                    # ###########################################################################
20                                                    package QueryAdvisor;
21                                                    
22             1                    1             4   use strict;
               1                                  3   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  4   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 13   
27                                                    
28                                                    sub new {
29    ***      1                    1      0      6      my ( $class, %args ) = @_;
30             1                                  5      foreach my $arg ( qw() ) {
31    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
32                                                       }
33                                                    
34             1                                  7      my $self = {
35                                                          %args,
36                                                          rules          => [],  # Rules from all advisor modules.
37                                                          rule_index_for => {},  # Maps rules by ID to their array index in $rules.
38                                                          rule_info      => {},  # ID, severity, description, etc. for each rule.
39                                                       };
40                                                    
41             1                                 10      return bless $self, $class;
42                                                    }
43                                                    
44                                                    sub load_rules {
45    ***      2                    2      0      9      my ( $self, $advisor ) = @_;
46    ***      2     50                           9      return unless $advisor;
47             2                                  5      MKDEBUG && _d('Loading rules from', ref $advisor);
48             2                                  5      my $i = scalar @{$self->{rules}};
               2                                 18   
49             2                                 10      foreach my $advisor_rule ( $advisor->get_rules() ) {
50            18                                 56         my $id = $advisor_rule->{id};
51            18    100                          77         die "Rule $id already exists and cannot be redefined"
52                                                             if defined $self->{rule_index_for}->{$id};
53            17                                 41         push @{$self->{rules}}, $advisor_rule;
              17                                 60   
54            17                                 73         $self->{rule_index_for}->{$id} = $i++;
55                                                       }
56             1                                  6      return;
57                                                    }
58                                                    
59                                                    sub load_rule_info {
60    ***      2                    2      0      8      my ( $self, $advisor ) = @_;
61    ***      2     50                           7      return unless $advisor;
62             2                                  4      MKDEBUG && _d('Loading rule info from', ref $advisor);
63             2                                  8      my $rules = $self->{rules};
64             2                                  7      foreach my $rule ( @$rules ) {
65            18                                 57         my $id        = $rule->{id};
66            18                                 72         my $rule_info = $advisor->get_rule_info($id);
67    ***     18     50                          57         next unless $rule_info;
68                                                    
69            18    100                          75         die "Info for rule $id already exists and cannot be redefined"
70                                                             if $self->{rule_info}->{$id};
71                                                    
72            17                                 73         $self->{rule_info}->{$id} = $rule_info;
73                                                       }
74             1                                  3      return;
75                                                    }
76                                                    
77                                                    sub run_rules {
78    ***     21                   21      0    112      my ( $self, %args ) = @_;
79            21                                 61      my @matched_rules;
80            21                                 68      my $rules = $self->{rules};
81            21                                 77      foreach my $rule ( @$rules ) {
82           357    100                        1732         if ( $rule->{code}->(%args) ) {
83            23                                 48            MKDEBUG && _d('Matches rule', $rule->{id});
84            23                                113            push @matched_rules, $rule->{id};
85                                                          }
86                                                       }
87            21                                156      return sort @matched_rules;
88                                                    };
89                                                    
90                                                    sub get_rule_info {
91    ***      0                    0      0             my ( $self, $id ) = @_;
92    ***      0      0                                  return unless $id;
93    ***      0                                         return $self->{rule_info}->{$id};
94                                                    }
95                                                    
96                                                    sub _d {
97    ***      0                    0                    my ($package, undef, $line) = caller 0;
98    ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
99    ***      0                                              map { defined $_ ? $_ : 'undef' }
100                                                           @_;
101   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
102                                                   }
103                                                   
104                                                   1;
105                                                   
106                                                   # ###########################################################################
107                                                   # End QueryAdvisor package
108                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
31    ***      0      0      0   unless $args{$arg}
46    ***     50      0      2   unless $advisor
51           100      1     17   if defined $$self{'rule_index_for'}{$id}
61    ***     50      0      2   unless $advisor
67    ***     50      0     18   unless $rule_info
69           100      1     17   if $$self{'rule_info'}{$id}
82           100     23    334   if ($$rule{'code'}(%args))
92    ***      0      0      0   unless $id
98    ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine     Count Pod Location                                          
-------------- ----- --- --------------------------------------------------
BEGIN              1     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:22
BEGIN              1     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:23
BEGIN              1     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:24
BEGIN              1     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:26
load_rule_info     2   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:60
load_rules         2   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:45
new                1   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:29
run_rules         21   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:78

Uncovered Subroutines
---------------------

Subroutine     Count Pod Location                                          
-------------- ----- --- --------------------------------------------------
_d                 0     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:97
get_rule_info      0   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:91


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
               1                                  3   
               1                                  6   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  9   
25                                                    
26             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  5   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 12   
32                                                    
33                                                    sub new {
34    ***      1                    1      0      6      my ( $class, %args ) = @_;
35             1                                  5      foreach my $arg ( qw(PodParser) ) {
36    ***      1     50                           8         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38                                                    
39             1                                  8      my @rules = get_rules();
40             1                                  5      MKDEBUG && _d(scalar @rules, 'rules');
41                                                    
42             1                                 10      my $self = {
43                                                          %args,
44                                                          rules          => \@rules,
45                                                          rule_index_for => {},
46                                                          rule_info      => {},
47                                                       };
48                                                    
49             1                                  4      my $i = 0;
50             1                                  4      map { $self->{rule_index_for}->{ $_->{id} } = $i++ } @rules;
              17                                 92   
51                                                    
52             1                                 15      return bless $self, $class;
53                                                    }
54                                                    
55                                                    sub get_rules {
56                                                       return
57                                                       {
58                                                          id   => 'ALI.001',      # Implicit alias
59                                                          code => sub {
60            21                   21            95            my ( %args ) = @_;
61            21                                 76            my $struct = $args{query_struct};
62    ***     21            66                  130            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                   33                        
63    ***     21     50                          87            return unless $tbls;
64            21                                 83            foreach my $tbl ( @$tbls ) {
65    ***     25     50     66                  168               return 1 if $tbl->{alias} && !$tbl->{explicit_alias};
66                                                             }
67            21                                 71            my $cols = $struct->{columns};
68            21    100                          78            return unless $cols;
69            19                                 60            foreach my $col ( @$cols ) {
70            22    100    100                  148               return 1 if $col->{alias} && !$col->{explicit_alias};
71                                                             }
72            17                                105            return 0;
73                                                          },
74                                                       },
75                                                       {
76                                                          id   => 'ALI.002',      # tbl.* alias
77                                                          code => sub {
78            21                   21            92            my ( %args ) = @_;
79            21                                 83            my $cols = $args{query_struct}->{columns};
80            21    100                          80            return unless $cols;
81            19                                 62            foreach my $col ( @$cols ) {
82    ***     22    100     66                  168               return 1 if $col->{db} && $col->{name } eq '*' &&  $col->{alias};
      ***                   66                        
83                                                             }
84            18                                 99            return 0;
85                                                          },
86                                                       },
87                                                       {
88                                                          id   => 'ALI.003',      # tbl AS tbl
89                                                          code => sub {
90            21                   21            88            my ( %args ) = @_;
91            21                                 68            my $struct = $args{query_struct};
92    ***     21            66                  130            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                   33                        
93    ***     21     50                          68            return unless $tbls;
94            21                                 67            foreach my $tbl ( @$tbls ) {
95            25    100    100                  167               return 1 if $tbl->{alias} && $tbl->{alias} eq $tbl->{name};
96                                                             }
97            20                                 68            my $cols = $struct->{columns};
98            20    100                          74            return unless $cols;
99            18                                 62            foreach my $col ( @$cols ) {
100           21    100    100                  140               return 1 if $col->{alias} && $col->{alias} eq $col->{name};
101                                                            }
102           17                                 96            return 0;
103                                                         },
104                                                      },
105                                                      {
106                                                         id   => 'ARG.001',      # col = '%foo'
107                                                         code => sub {
108           21                   21            88            my ( %args ) = @_;
109           21    100                         112            return 1 if $args{query} =~ m/[\'\"][\%\_]\w/;
110           20                                112            return 0;
111                                                         },
112                                                      },
113                                                      {
114                                                         id   => 'CLA.001',      # SELECT w/o WHERE
115                                                         code => sub {
116           21                   21            90            my ( %args ) = @_;
117           21    100                         115            return 0 unless $args{query_struct}->{type} eq 'select';
118           19    100                          84            return 1 unless $args{query_struct}->{where};
119           18                                 94            return 0;
120                                                         },
121                                                      },
122                                                      {
123                                                         id   => 'CLA.002',      # ORDER BY RAND()
124                                                         code => sub {
125           21                   21            84            my ( %args ) = @_;
126           21                                 82            my $orderby = $args{query_struct}->{order_by};
127           21    100                         127            return unless $orderby;
128            4                                 14            foreach my $col ( @$orderby ) {
129            4    100                          31               return 1 if $col =~ m/RAND\([^\)]*\)/i;
130                                                            }
131            2                                 12            return 0;
132                                                         },
133                                                      },
134                                                      {
135                                                         id   => 'CLA.003',      # LIMIT w/ OFFSET
136                                                         code => sub {
137           21                   21            89            my ( %args ) = @_;
138           21    100                         150            return 0 unless $args{query_struct}->{limit};
139            3    100                          20            return 0 unless defined $args{query_struct}->{limit}->{offset};
140            2                                 12            return 1;
141                                                         },
142                                                      },
143                                                      {
144                                                         id   => 'CLA.004',      # GROUP BY <number>
145                                                         code => sub {
146           21                   21            83            my ( %args ) = @_;
147           21                                 81            my $groupby = $args{query_struct}->{group_by};
148           21    100                         122            return unless $groupby;
149            3                                  8            foreach my $col ( @{$groupby->{columns}} ) {
               3                                 14   
150            4    100                          26               return 1 if $col =~ m/^\d+\b/;
151                                                            }
152            2                                 12            return 0;
153                                                         },
154                                                      },
155                                                      {
156                                                         id   => 'COL.001',      # SELECT *
157                                                         code => sub {
158           21                   21            88            my ( %args ) = @_;
159           21                                 88            my $type = $args{query_struct}->{type} eq 'select';
160           21                                 66            my $cols = $args{query_struct}->{columns};
161           21    100                          82            return unless $cols;
162           19                                 61            foreach my $col ( @$cols ) {
163           22    100                         122               return 1 if $col->{name} eq '*';
164                                                            }
165           17                                 99            return 0;
166                                                         },
167                                                      },
168                                                      {
169                                                         id   => 'COL.002',      # INSERT w/o (cols) def
170                                                         code => sub {
171           21                   21            84            my ( %args ) = @_;
172           21                                 82            my $type = $args{query_struct}->{type};
173   ***     21    100     66                  237            return 0 unless $type eq 'insert' || $type eq 'replace';
174   ***      2     50                          16            return 1 unless $args{query_struct}->{columns};
175   ***      0                                  0            return 0;
176                                                         },
177                                                      },
178                                                      {
179                                                         id   => 'LIT.001',      # IP as string
180                                                         code => sub {
181           21                   21            88            my ( %args ) = @_;
182           21                                150            return $args{query} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/;
183                                                         },
184                                                      },
185                                                      {
186                                                         id   => 'LIT.002',      # Date not quoted
187                                                         code => sub {
188           21                   21            88            my ( %args ) = @_;
189           21                                377            return $args{query} =~ m/[^'"](?:\d{2,4}-\d{1,2}-\d{1,2}|\d{4,6})/;
190                                                         },
191                                                      },
192                                                      {
193                                                         id   => 'KWR.001',      # SQL_CALC_FOUND_ROWS
194                                                         code => sub {
195           21                   21            88            my ( %args ) = @_;
196           21    100                         126            return 1 if $args{query_struct}->{keywords}->{sql_calc_found_rows};
197           20                                105            return 0;
198                                                         },
199                                                      },
200                                                      {
201                                                         id   => 'JOI.001',      # comma and ansi joins
202                                                         code => sub {
203           21                   21            90            my ( %args ) = @_;
204           21                                 69            my $struct = $args{query_struct};
205   ***     21            66                  125            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                   33                        
206   ***     21     50                          77            return unless $tbls;
207           21                                 51            my $comma_join = 0;
208           21                                 57            my $ansi_join  = 0;
209           21                                 66            foreach my $tbl ( @$tbls ) {
210           25    100                         131               if ( $tbl->{join} ) {
211            4    100                          18                  if ( $tbl->{join}->{ansi} ) {
212            2                                  6                     $ansi_join = 1;
213                                                                  }
214                                                                  else {
215            2                                  7                     $comma_join = 1;
216                                                                  }
217                                                               }
218           25    100    100                  147               return 1 if $comma_join && $ansi_join;
219                                                            }
220           20                                112            return 0;
221                                                         },
222                                                      },
223                                                      {
224                                                         id   => 'RES.001',      # non-deterministic GROUP BY
225                                                         code => sub {
226           21                   21            89            my ( %args ) = @_;
227           21    100                         115            return unless $args{query_struct}->{type} eq 'select';
228           19                                 63            my $groupby = $args{query_struct}->{group_by};
229           19    100                         114            return unless $groupby;
230                                                            # Only check GROUP BY column names, not numbers.  GROUP BY number
231                                                            # is handled in CLA.004.
232            3                                 15            my %groupby_col = map { $_ => 1 }
               4                                 18   
233            3                                 11                              grep { m/^[^\d]+\b/ }
234            3                                  9                              @{$groupby->{columns}};
235            3    100                          21            return unless scalar %groupby_col;
236            2                                  8            my $cols = $args{query_struct}->{columns};
237                                                            # All SELECT cols must be in GROUP BY cols clause.
238                                                            # E.g. select a, b, c from tbl group by a; -- non-deterministic
239            2                                  7            foreach my $col ( @$cols ) {
240            4    100                          23               return 1 unless $groupby_col{ $col->{name} };
241                                                            }
242            1                                  6            return 0;
243                                                         },
244                                                      },
245                                                      {
246                                                         id   => 'RES.002',      # non-deterministic LIMIT w/o ORDER BY
247                                                         code => sub {
248           21                   21            88            my ( %args ) = @_;
249           21    100                         160            return 0 unless $args{query_struct}->{limit};
250            3    100                          18            return 1 unless $args{query_struct}->{order_by};
251            2                                 10            return 0;
252                                                         },
253                                                      },
254                                                      {
255                                                         id   => 'STA.001',      # != instead of <>
256                                                         code => sub {
257           21                   21            87            my ( %args ) = @_;
258           21    100                         101            return 1 if $args{query} =~ m/!=/;
259           20                                117            return 0;
260                                                         },
261                                                      },
262   ***      4                    4      0    406   };
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
273   ***      1                    1      0      8      my ( $self, %args ) = @_;
274            1                                  6      foreach my $arg ( qw(rules file section) ) {
275   ***      3     50                          14         die "I need a $arg argument" unless $args{$arg};
276                                                      }
277            1                                  4      my $rules = $args{rules};  # requested/required rules
278            1                                  4      my $p     = $self->{PodParser};
279                                                   
280                                                      # Parse rules and their info from the file's POD, saving
281                                                      # values to %rule_info.  Our trf sub returns nothing so
282                                                      # parse_section() returns nothing.
283                                                      $p->parse_section(
284                                                         %args,
285                                                         trf  => sub {
286           18                   18          4039            my ( $para ) = @_;
287           18                                 51            chomp $para;
288           18                                 58            my $rule_info = _parse_rule_info($para);
289           18    100                          66            return unless $rule_info;
290                                                   
291   ***     17     50                          64            die "Rule info does not specify an ID:\n$para"
292                                                               unless $rule_info->{id};
293   ***     17     50                          69            die "Rule info does not specify a severity:\n$para"
294                                                               unless $rule_info->{severity};
295   ***     17     50                          59            die "Rule info does not specify a description:\n$para",
296                                                               unless $rule_info->{description};
297   ***     17     50                          88            die "Rule $rule_info->{id} is not defined"
298                                                               unless defined $self->{rule_index_for}->{ $rule_info->{id} };
299                                                   
300           17                                 53            my $id = $rule_info->{id};
301   ***     17     50                          78            if ( exists $self->{rule_info}->{$id} ) {
302   ***      0                                  0               die "Info for rule $rule_info->{id} already exists "
303                                                                  . "and cannot be redefined"
304                                                            }
305                                                   
306           17                                 66            $self->{rule_info}->{$id} = $rule_info;
307                                                   
308           17                                281            return;
309                                                         },
310            1                                 22      );
311                                                   
312                                                      # Check that rule info was gotten for each requested rule.
313            1                                 30      foreach my $rule ( @$rules ) {
314   ***     17     50                          87         die "There is no info for rule $rule->{id}"
315                                                            unless $self->{rule_info}->{ $rule->{id} };
316                                                      }
317                                                   
318            1                                  4      return;
319                                                   }
320                                                   
321                                                   sub get_rule_info {
322   ***     18                   18      0     60      my ( $self, $id ) = @_;
323   ***     18     50                          62      return unless $id;
324           18                                 83      return $self->{rule_info}->{$id};
325                                                   }
326                                                   
327                                                   # Called by load_rule_info() to parse a rule paragraph from the POD.
328                                                   sub _parse_rule_info {
329           18                   18            62      my ( $para ) = @_;
330           18    100                          87      return unless $para =~ m/^id:/i;
331           17                                 49      my $rule_info = {};
332           17                                 98      my @lines = split("\n", $para);
333           17                                 46      my $line;
334                                                   
335                                                      # First 2 lines should be id and severity.
336           17                                 78      for ( 1..2 ) {
337           34                                 96         $line = shift @lines;
338           34                                 75         MKDEBUG && _d($line);
339           34                                147         $line =~ m/(\w+):\s*(.+)/;
340           34                                192         $rule_info->{lc $1} = uc $2;
341                                                      }
342                                                   
343                                                      # First line of desc.
344           17                                 52      $line = shift @lines;
345           17                                 38      MKDEBUG && _d($line);
346           17                                 69      $line =~ m/(\w+):\s*(.+)/;
347           17                                 54      my $desc        = lc $1;
348           17                                 69      $rule_info->{$desc} = $2;
349                                                      # Rest of desc.
350           17                                 77      while ( my $d = shift @lines ) {
351           11                                 67         $rule_info->{$desc} .= $d;
352                                                      }
353           17                                130      $rule_info->{$desc} =~ s/\s+/ /g;
354           17                                103      $rule_info->{$desc} =~ s/\s+$//;
355                                                   
356           17                                 36      MKDEBUG && _d('Parsed rule info:', Dumper($rule_info));
357           17                                 63      return $rule_info;
358                                                   }
359                                                   
360                                                   # Used for testing.
361                                                   sub _reset_rule_info {
362   ***      0                    0                    my ( $self ) = @_;
363   ***      0                                         $self->{rule_info} = {};
364   ***      0                                         return;
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
275   ***     50      0      3   unless $args{$arg}
289          100      1     17   unless $rule_info
291   ***     50      0     17   unless $$rule_info{'id'}
293   ***     50      0     17   unless $$rule_info{'severity'}
295   ***     50      0     17   unless $$rule_info{'description'}
297   ***     50      0     17   unless defined $$self{'rule_index_for'}{$$rule_info{'id'}}
301   ***     50      0     17   if (exists $$self{'rule_info'}{$id})
314   ***     50      0     17   unless $$self{'rule_info'}{$$rule{'id'}}
323   ***     50      0     18   unless $id
330          100      1     17   unless $para =~ /^id:/i
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
__ANON__            18     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:286
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:60 
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:78 
__ANON__            21     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:90 
_parse_rule_info    18     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:329
get_rule_info       18   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:322
get_rules            4   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:262
load_rule_info       1   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:273
new                  1   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:34 

Uncovered Subroutines
---------------------

Subroutine       Count Pod Location                                                
---------------- ----- --- --------------------------------------------------------
_d                   0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:368
_reset_rule_info     0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:362


QueryAdvisor.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            32      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  3   
               1                                  5   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11             1                    1            10   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
12             1                    1             9   use Test::More tests => 24;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            13   use MaatkitTest;
               1                                  3   
               1                                 11   
15             1                    1            12   use QueryAdvisorRules;
               1                                  3   
               1                                 13   
16             1                    1            11   use QueryAdvisor;
               1                                  3   
               1                                 10   
17             1                    1             9   use PodParser;
               1                                  3   
               1                                  9   
18             1                    1             9   use SQLParser;
               1                                  4   
               1                                 10   
19                                                    
20                                                    # This module's purpose is to run rules and return a list of the IDs of the
21                                                    # triggered rules.  It should be very simple.  (But we don't want to put the two
22                                                    # modules together.  Their purposes are distinct.)
23             1                                 11   my $p   = new PodParser();
24             1                                 36   my $qar = new QueryAdvisorRules(PodParser => $p);
25             1                                 10   my $qa  = new QueryAdvisor();
26             1                                 10   my $sp  = new SQLParser();
27                                                    
28                                                    # This should make $qa internally call get_rules() on $qar and save the rules
29                                                    # into its own list.  If the user plugs in his own module, we'd call
30                                                    # load_rules() on that too, and just append the rules (with checks that they
31                                                    # don't redefine any rule IDs).
32             1                                 25   $qa->load_rules($qar);
33                                                    
34                                                    # To test the above, we ask it to load the same rules twice.  It should die with
35                                                    # an error like "Rule LIT.001 already exists, and cannot be redefined"
36                                                    throws_ok (
37             1                    1            16      sub { $qa->load_rules($qar) },
38             1                                 18      qr/Rule \S+ already exists and cannot be redefined/,
39                                                       'Duplicate rules are caught',
40                                                    );
41                                                    
42                                                    # We'll also load the rule info, so we can test $qa->get_rule_info() after the
43                                                    # POD is loaded.
44             1                                 19   $qar->load_rule_info(
45                                                       rules   => [ $qar->get_rules() ],
46                                                       file    => "$trunk/mk-query-advisor/mk-query-advisor",
47                                                       section => 'RULES',
48                                                    );
49                                                    
50                                                    # This should make $qa call $qar->get_rule_info('....') for every rule ID it
51                                                    # has, and store the info, and make sure that nothing is redefined.  A user
52                                                    # shouldn't be able to load a plugin that redefines the severity/desc of a
53                                                    # built-in rule.  Maybe we'll provide a way to override that, though by default
54                                                    # we want to warn and be strict.
55             1                                 75   $qa->load_rule_info($qar);
56                                                    
57                                                    # TODO: write a test that the rules are described as defined in the POD of the
58                                                    # tool.  Testing one rule should be enough.
59                                                    
60                                                    # Test that it can't be redefined...
61                                                    throws_ok (
62             1                    1            14      sub { $qa->load_rule_info($qar) },
63             1                                 13      qr/Info for rule \S+ already exists and cannot be redefined/,
64                                                       'Duplicate rule info is caught',
65                                                    );
66                                                    
67                                                    # Test cases for the rules themselves.
68             1                                 68   my @cases = (
69                                                       {  name   => 'IP address not inside INET_ATON, plus SELECT * is used',
70                                                          query  => 'SELECT * FROM tbl WHERE ip="127.0.0.1"',
71                                                          advice => [qw(LIT.001 COL.001)],
72                                                       },
73                                                       {  name   => 'Date literal not quoted',
74                                                          query  => 'SELECT col FROM tbl WHERE col < 2001-01-01',
75                                                          advice => [qw(LIT.002)],
76                                                       },
77                                                       {  name   => 'Aliases without AS keyword',
78                                                          query  => 'SELECT a b FROM tbl',
79                                                          advice => [qw(ALI.001 CLA.001)],
80                                                       },
81                                                       {  name   => 'tbl.* alias',
82                                                          query  => 'SELECT tbl.* foo FROM bar WHERE id=1',
83                                                          advice => [qw(ALI.001 ALI.002 COL.001)],
84                                                       },
85                                                       {  name   => 'tbl as tbl',
86                                                          query  => 'SELECT col FROM tbl AS tbl WHERE id',
87                                                          advice => [qw(ALI.003)],
88                                                       },
89                                                       {  name   => 'col as col',
90                                                          query  => 'SELECT col AS col FROM tbl AS `my tbl` WHERE id',
91                                                          advice => [qw(ALI.003)],
92                                                       },
93                                                       {  name   => 'Blind INSERT',
94                                                          query  => 'INSERT INTO tbl VALUES(1),(2)',
95                                                          advice => [qw(COL.002)],
96                                                       },
97                                                       {  name   => 'Blind INSERT',
98                                                          query  => 'INSERT tbl VALUE (1)',
99                                                          advice => [qw(COL.002)],
100                                                      },
101                                                      {  name   => 'SQL_CALC_FOUND_ROWS',
102                                                         query  => 'SELECT SQL_CALC_FOUND_ROWS col FROM tbl AS alias WHERE id=1',
103                                                         advice => [qw(KWR.001)],
104                                                      },
105                                                      {  name   => 'All comma joins ok',
106                                                         query  => 'SELECT col FROM tbl1, tbl2 WHERE tbl1.id=tbl2.id',
107                                                         advice => [],
108                                                      },
109                                                      {  name   => 'All ANSI joins ok',
110                                                         query  => 'SELECT col FROM tbl1 JOIN tbl2 USING(id) WHERE tbl1.id>10',
111                                                         advice => [],
112                                                      },
113                                                      {  name   => 'Mix comman/ANSI joins',
114                                                         query  => 'SELECT col FROM tbl, tbl1 JOIN tbl2 USING(id) WHERE tbl.d>10',
115                                                         advice => [qw(JOI.001)],
116                                                      },
117                                                      {  name   => 'Non-deterministic GROUP BY',
118                                                         query  => 'select a, b, c from tbl where foo group by a',
119                                                         advice => [qw(RES.001)],
120                                                      },
121                                                      {  name   => 'Non-deterministic LIMIT w/o ORDER BY',
122                                                         query  => 'select a, b from tbl where foo limit 10 group by a, b',
123                                                         advice => [qw(RES.002)],
124                                                      },
125                                                      {  name   => 'ORDER BY RAND()',
126                                                         query  => 'select a from t where id order by rand()',
127                                                         advice => [qw(CLA.002)],
128                                                      },
129                                                      {  name   => 'ORDER BY RAND(N)',
130                                                         query  => 'select a from t where id order by rand(123)',
131                                                         advice => [qw(CLA.002)],
132                                                      },
133                                                      {  name   => 'LIMIT w/ OFFSET does not scale',
134                                                         query  => 'select a from t where i limit 10, 10 order by a',
135                                                         advice => [qw(CLA.003)],
136                                                      },
137                                                      {  name   => 'LIMIT w/ OFFSET does not scale',
138                                                         query  => 'select a from t where i limit 10 OFFSET 10 order by a',
139                                                         advice => [qw(CLA.003)],
140                                                      },
141                                                      {  name   => 'Leading %wildcard',
142                                                         query  => 'select a from t where i="%hm"',
143                                                         advice => [qw(ARG.001)],
144                                                      },
145                                                      {  name   => 'GROUP BY number',
146                                                         query  => 'select a from t where i group by 1',
147                                                         advice => [qw(CLA.004)],
148                                                      },
149                                                      {  name   => '!= instead of <>',
150                                                         query  => 'select a from t where i != 2',
151                                                         advice => [qw(STA.001)],
152                                                      },
153                                                   );
154                                                   
155                                                   # Run the test cases.
156            1                                  5   foreach my $test ( @cases ) {
157           21                                354      my $query_struct = $sp->parse($test->{query});
158           21                              12892      my %args = (
159                                                         query        => $test->{query},
160                                                         query_struct => $query_struct,
161                                                      );
162           21                                153      is_deeply(
163                                                         [ $qa->run_rules(%args) ],
164           21                                129         [ sort @{$test->{advice}} ],
165                                                         $test->{name},
166                                                      );
167                                                   }
168                                                   
169                                                   # #############################################################################
170                                                   # Done.
171                                                   # #############################################################################
172            1                                 16   my $output = '';
173                                                   {
174            1                                  2      local *STDERR;
               1                                  9   
175            1                    1             2      open STDERR, '>', \$output;
               1                                303   
               1                                  3   
               1                                  6   
176            1                                 16      $p->_d('Complete test coverage');
177                                                   }
178                                                   like(
179            1                                 14      $output,
180                                                      qr/Complete test coverage/,
181                                                      '_d() works'
182                                                   );
183            1                                  3   exit;


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


Covered Subroutines
-------------------

Subroutine Count Location          
---------- ----- ------------------
BEGIN          1 QueryAdvisor.t:10 
BEGIN          1 QueryAdvisor.t:11 
BEGIN          1 QueryAdvisor.t:12 
BEGIN          1 QueryAdvisor.t:14 
BEGIN          1 QueryAdvisor.t:15 
BEGIN          1 QueryAdvisor.t:16 
BEGIN          1 QueryAdvisor.t:17 
BEGIN          1 QueryAdvisor.t:175
BEGIN          1 QueryAdvisor.t:18 
BEGIN          1 QueryAdvisor.t:4  
BEGIN          1 QueryAdvisor.t:9  
__ANON__       1 QueryAdvisor.t:37 
__ANON__       1 QueryAdvisor.t:62 


