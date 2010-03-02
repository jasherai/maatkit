---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/QueryAdvisor.pm   73.7   44.4   50.0   80.0    0.0    8.7   64.1
...mmon/QueryAdvisorRules.pm   38.4   13.8    2.3   36.7    0.0   77.6   26.9
QueryAdvisor.t                100.0   50.0   33.3  100.0    n/a   13.7   95.3
Total                          55.4   19.3    6.1   59.6    0.0  100.0   42.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Mar  2 15:59:31 2010
Finish:       Tue Mar  2 15:59:31 2010

Run:          QueryAdvisor.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Tue Mar  2 15:59:33 2010
Finish:       Tue Mar  2 15:59:33 2010

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
22             1                    1             5   use strict;
               1                                  2   
               1                                  5   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 12   
27                                                    
28                                                    sub new {
29    ***      1                    1      0      5      my ( $class, %args ) = @_;
30             1                                  4      foreach my $arg ( qw() ) {
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
41             1                                 13      return bless $self, $class;
42                                                    }
43                                                    
44                                                    sub load_rules {
45    ***      2                    2      0      6      my ( $self, $advisor ) = @_;
46    ***      2     50                           9      return unless $advisor;
47             2                                  4      MKDEBUG && _d('Loading rules from', ref $advisor);
48             2                                  5      my $i = scalar @{$self->{rules}};
               2                                  9   
49             2                                  9      foreach my $advisor_rule ( $advisor->get_rules() ) {
50            18                                 51         my $id = $advisor_rule->{id};
51            18    100                          76         die "Rule $id already exists and cannot be redefined"
52                                                             if defined $self->{rule_index_for}->{$id};
53            17                                 38         push @{$self->{rules}}, $advisor_rule;
              17                                 57   
54            17                                 73         $self->{rule_index_for}->{$id} = $i++;
55                                                       }
56             1                                  6      return;
57                                                    }
58                                                    
59                                                    sub load_rule_info {
60    ***      2                    2      0      8      my ( $self, $advisor ) = @_;
61    ***      2     50                           8      return unless $advisor;
62             2                                  6      MKDEBUG && _d('Loading rule info from', ref $advisor);
63             2                                  7      my $rules = $self->{rules};
64             2                                  7      foreach my $rule ( @$rules ) {
65            18                                 66         my $id        = $rule->{id};
66            18                                 70         my $rule_info = $advisor->get_rule_info($id);
67    ***     18     50                          64         next unless $rule_info;
68                                                    
69            18    100                          76         die "Info for rule $id already exists and cannot be redefined"
70                                                             if $self->{rule_info}->{$id};
71                                                    
72            17                                 65         $self->{rule_info}->{$id} = $rule_info;
73                                                       }
74             1                                  4      return;
75                                                    }
76                                                    
77                                                    sub run_rules {
78    ***      0                    0      0      0      my ( $self, %args ) = @_;
79    ***      0                                  0      my @matched_rules;
80    ***      0                                  0      my $rules = $self->{rules};
81    ***      0                                  0      foreach my $rule ( @$rules ) {
82    ***      0      0                           0         if ( $rule->{code}->(%args) ) {
83    ***      0                                  0            MKDEBUG && _d('Matches rule', $rule->{id});
84    ***      0                                  0            push @matched_rules, $rule->{id};
85                                                          }
86                                                       }
87    ***      0                                  0      return sort @matched_rules;
88                                                    };
89                                                    
90                                                    sub get_rule_info {
91    ***      1                    1      0      5      my ( $self, $id ) = @_;
92    ***      1     50                           6      return unless $id;
93             1                                 11      return $self->{rule_info}->{$id};
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
82    ***      0      0      0   if ($$rule{'code'}(%args))
92    ***     50      0      1   unless $id
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
get_rule_info      1   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:91
load_rule_info     2   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:60
load_rules         2   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:45
new                1   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:29

Uncovered Subroutines
---------------------

Subroutine     Count Pod Location                                          
-------------- ----- --- --------------------------------------------------
_d                 0     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:97
run_rules          0   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:78


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
               1                                  2   
               1                                  6   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  3   
               1                                  5   
25                                                    
26             1                    1             7   use Data::Dumper;
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
35             1                                  3      foreach my $arg ( qw(PodParser) ) {
36    ***      1     50                           7         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38                                                    
39             1                                  3      my @rules = get_rules();
40             1                                  5      MKDEBUG && _d(scalar @rules, 'rules');
41                                                    
42             1                                  8      my $self = {
43                                                          %args,
44                                                          rules          => \@rules,
45                                                          rule_index_for => {},
46                                                          rule_info      => {},
47                                                       };
48                                                    
49             1                                  3      my $i = 0;
50             1                                  4      map { $self->{rule_index_for}->{ $_->{id} } = $i++ } @rules;
              17                                 84   
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
262   ***      4                    4      0    378   };
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
274            1                                 18      foreach my $arg ( qw(rules file section) ) {
275   ***      3     50                          15         die "I need a $arg argument" unless $args{$arg};
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
286           18                   18          4107            my ( $para ) = @_;
287           18                                 50            chomp $para;
288           18                                 60            my $rule_info = _parse_rule_info($para);
289           18    100                          65            return unless $rule_info;
290                                                   
291   ***     17     50                          67            die "Rule info does not specify an ID:\n$para"
292                                                               unless $rule_info->{id};
293   ***     17     50                          61            die "Rule info does not specify a severity:\n$para"
294                                                               unless $rule_info->{severity};
295   ***     17     50                          64            die "Rule info does not specify a description:\n$para",
296                                                               unless $rule_info->{description};
297   ***     17     50                          86            die "Rule $rule_info->{id} is not defined"
298                                                               unless defined $self->{rule_index_for}->{ $rule_info->{id} };
299                                                   
300           17                                 52            my $id = $rule_info->{id};
301   ***     17     50                          83            if ( exists $self->{rule_info}->{$id} ) {
302   ***      0                                  0               die "Info for rule $rule_info->{id} already exists "
303                                                                  . "and cannot be redefined"
304                                                            }
305                                                   
306           17                                 69            $self->{rule_info}->{$id} = $rule_info;
307                                                   
308           17                                 58            return;
309                                                         },
310            1                                 15      );
311                                                   
312                                                      # Check that rule info was gotten for each requested rule.
313            1                                 28      foreach my $rule ( @$rules ) {
314   ***     17     50                          87         die "There is no info for rule $rule->{id} in $args{file}"
315                                                            unless $self->{rule_info}->{ $rule->{id} };
316                                                      }
317                                                   
318            1                                  5      return;
319                                                   }
320                                                   
321                                                   sub get_rule_info {
322   ***     18                   18      0     60      my ( $self, $id ) = @_;
323   ***     18     50                          72      return unless $id;
324           18                                 76      return $self->{rule_info}->{$id};
325                                                   }
326                                                   
327                                                   # Called by load_rule_info() to parse a rule paragraph from the POD.
328                                                   sub _parse_rule_info {
329           18                   18            63      my ( $para ) = @_;
330           18    100                          83      return unless $para =~ m/^id:/i;
331           17                                 48      my $rule_info = {};
332           17                                103      my @lines = split("\n", $para);
333           17                                 49      my $line;
334                                                   
335                                                      # First 2 lines should be id and severity.
336           17                                 55      for ( 1..2 ) {
337           34                                 95         $line = shift @lines;
338           34                                 77         MKDEBUG && _d($line);
339           34                                138         $line =~ m/(\w+):\s*(.+)/;
340           34                                200         $rule_info->{lc $1} = uc $2;
341                                                      }
342                                                   
343                                                      # First line of desc.
344           17                                 51      $line = shift @lines;
345           17                                 34      MKDEBUG && _d($line);
346           17                                 69      $line =~ m/(\w+):\s*(.+)/;
347           17                                 52      my $desc        = lc $1;
348           17                                 76      $rule_info->{$desc} = $2;
349                                                      # Rest of desc.
350           17                                 78      while ( my $d = shift @lines ) {
351           11                                 71         $rule_info->{$desc} .= $d;
352                                                      }
353           17                                129      $rule_info->{$desc} =~ s/\s+/ /g;
354           17                                102      $rule_info->{$desc} =~ s/\s+$//;
355                                                   
356           17                                 34      MKDEBUG && _d('Parsed rule info:', Dumper($rule_info));
357           17                                 59      return $rule_info;
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
__ANON__            18     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:286
_parse_rule_info    18     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:329
get_rule_info       18   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:322
get_rules            4   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:262
load_rule_info       1   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:273
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
_reset_rule_info     0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:362


QueryAdvisor.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            48      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
6              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
7                                                     };
8                                                     
9              1                    1            11   use strict;
               1                                  2   
               1                                  6   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11             1                    1            10   use English qw(-no_match_vars);
               1                                  3   
               1                                  7   
12             1                    1             9   use Test::More tests => 4;
               1                                  4   
               1                                 10   
13                                                    
14             1                    1            12   use MaatkitTest;
               1                                  4   
               1                                 11   
15             1                    1            11   use QueryAdvisorRules;
               1                                  2   
               1                                 12   
16             1                    1            10   use QueryAdvisor;
               1                                  3   
               1                                  9   
17             1                    1             9   use PodParser;
               1                                  3   
               1                                 11   
18                                                    
19                                                    # This module's purpose is to run rules and return a list of the IDs of the
20                                                    # triggered rules.  It should be very simple.  (But we don't want to put the two
21                                                    # modules together.  Their purposes are distinct.)
22             1                                  9   my $p   = new PodParser();
23             1                                 33   my $qar = new QueryAdvisorRules(PodParser => $p);
24             1                                  7   my $qa  = new QueryAdvisor();
25                                                    
26                                                    # This should make $qa internally call get_rules() on $qar and save the rules
27                                                    # into its own list.  If the user plugs in his own module, we'd call
28                                                    # load_rules() on that too, and just append the rules (with checks that they
29                                                    # don't redefine any rule IDs).
30             1                                  6   $qa->load_rules($qar);
31                                                    
32                                                    # To test the above, we ask it to load the same rules twice.  It should die with
33                                                    # an error like "Rule LIT.001 already exists, and cannot be redefined"
34                                                    throws_ok (
35             1                    1            15      sub { $qa->load_rules($qar) },
36             1                                 20      qr/Rule \S+ already exists and cannot be redefined/,
37                                                       'Duplicate rules are caught',
38                                                    );
39                                                    
40                                                    # We'll also load the rule info, so we can test $qa->get_rule_info() after the
41                                                    # POD is loaded.
42             1                                524   $qar->load_rule_info(
43                                                       rules   => [ $qar->get_rules() ],
44                                                       file    => "$trunk/mk-query-advisor/mk-query-advisor",
45                                                       section => 'RULES',
46                                                    );
47                                                    
48                                                    # This should make $qa call $qar->get_rule_info('....') for every rule ID it
49                                                    # has, and store the info, and make sure that nothing is redefined.  A user
50                                                    # shouldn't be able to load a plugin that redefines the severity/desc of a
51                                                    # built-in rule.  Maybe we'll provide a way to override that, though by default
52                                                    # we want to warn and be strict.
53             1                                 78   $qa->load_rule_info($qar);
54                                                    
55                                                    # TODO: write a test that the rules are described as defined in the POD of the
56                                                    # tool.  Testing one rule should be enough.
57                                                    
58                                                    # Test that it can't be redefined...
59                                                    throws_ok (
60             1                    1            15      sub { $qa->load_rule_info($qar) },
61             1                                 13      qr/Info for rule \S+ already exists and cannot be redefined/,
62                                                       'Duplicate rule info is caught',
63                                                    );
64                                                    
65             1                                 13   is_deeply(
66                                                       $qa->get_rule_info('ALI.001'),
67                                                       {
68                                                          id          => 'ALI.001',
69                                                          severity    => 'NOTE',
70                                                          description => 'Alias without AS. Explicit column or table aliases like "tbl AS alias" are preferred to implicit aliases like "tbl alias".',
71                                                       },
72                                                       'get_rule_info()'
73                                                    );
74                                                    
75                                                    # #############################################################################
76                                                    # Done.
77                                                    # #############################################################################
78             1                                  9   my $output = '';
79                                                    {
80             1                                  3      local *STDERR;
               1                                  6   
81             1                    1             2      open STDERR, '>', \$output;
               1                                299   
               1                                  2   
               1                                  7   
82             1                                 15      $p->_d('Complete test coverage');
83                                                    }
84                                                    like(
85             1                                 14      $output,
86                                                       qr/Complete test coverage/,
87                                                       '_d() works'
88                                                    );
89             1                                  3   exit;


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
---------- ----- -----------------
BEGIN          1 QueryAdvisor.t:10
BEGIN          1 QueryAdvisor.t:11
BEGIN          1 QueryAdvisor.t:12
BEGIN          1 QueryAdvisor.t:14
BEGIN          1 QueryAdvisor.t:15
BEGIN          1 QueryAdvisor.t:16
BEGIN          1 QueryAdvisor.t:17
BEGIN          1 QueryAdvisor.t:4 
BEGIN          1 QueryAdvisor.t:81
BEGIN          1 QueryAdvisor.t:9 
__ANON__       1 QueryAdvisor.t:35
__ANON__       1 QueryAdvisor.t:60


