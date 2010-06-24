---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...it/common/QueryAdvisor.pm   71.9   50.0   50.0   80.0    0.0   45.8   64.1
...mmon/QueryAdvisorRules.pm   24.9    6.9    3.0   30.0    0.0   34.1   16.2
QueryAdvisor.t                100.0   50.0   33.3  100.0    n/a   20.2   95.6
Total                          48.6   15.1    5.6   55.8    0.0  100.0   35.1
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:51 2010
Finish:       Thu Jun 24 19:35:51 2010

Run:          QueryAdvisor.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:52 2010
Finish:       Thu Jun 24 19:35:52 2010

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
18                                                    # QueryAdvisor package $Revision: 6029 $
19                                                    # ###########################################################################
20                                                    package QueryAdvisor;
21                                                    
22             1                    1             5   use strict;
               1                                  3   
               1                                  5   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  5   
25                                                    
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 13   
27                                                    
28                                                    # Arguments:
29                                                    #   * ignore_rules  hashref: rule IDs to ignore
30                                                    sub new {
31    ***      2                    2      0     12      my ( $class, %args ) = @_;
32             2                                 10      foreach my $arg ( qw() ) {
33    ***      0      0                           0         die "I need a $arg argument" unless $args{$arg};
34                                                       }
35                                                    
36             2                                 16      my $self = {
37                                                          %args,
38                                                          rules          => [],  # Rules from all advisor modules.
39                                                          rule_index_for => {},  # Maps rules by ID to their array index in $rules.
40                                                          rule_info      => {},  # ID, severity, description, etc. for each rule.
41                                                       };
42                                                    
43             2                                 15      return bless $self, $class;
44                                                    }
45                                                    
46                                                    # Load rules from the given advisor module.  Will die on duplicate
47                                                    # rule IDs.
48                                                    sub load_rules {
49    ***      3                    3      0     12      my ( $self, $advisor ) = @_;
50    ***      3     50                          13      return unless $advisor;
51             3                                  8      MKDEBUG && _d('Loading rules from', ref $advisor);
52                                                    
53                                                       # Starting index value in rules arrayref for these rules.
54                                                       # This is >0 if rules from other advisor modules have
55                                                       # already been loaded.
56             3                                  8      my $i = scalar @{$self->{rules}};
               3                                 12   
57                                                    
58                                                       RULE:
59             3                                 23      foreach my $rule ( $advisor->get_rules() ) {
60            39                                113         my $id = $rule->{id};
61            39    100                         172         if ( $self->{ignore_rules}->{uc $id} ) {
62             1                                  2            MKDEBUG && _d("Ignoring rule", $id);
63             1                                  4            next RULE;
64                                                          }
65            38    100                         161         die "Rule $id already exists and cannot be redefined"
66                                                             if defined $self->{rule_index_for}->{$id};
67            37                                 86         push @{$self->{rules}}, $rule;
              37                                121   
68            37                                177         $self->{rule_index_for}->{$id} = $i++;
69                                                       }
70                                                    
71             2                                 15      return;
72                                                    }
73                                                    
74                                                    sub load_rule_info {
75    ***      3                    3      0     11      my ( $self, $advisor ) = @_;
76    ***      3     50                          13      return unless $advisor;
77             3                                252      MKDEBUG && _d('Loading rule info from', ref $advisor);
78             3                                 11      my $rules = $self->{rules};
79             3                                 10      foreach my $rule ( @$rules ) {
80            38                                120         my $id = $rule->{id};
81    ***     38     50                         166         if ( $self->{ignore_rules}->{uc $id} ) {
82                                                             # This shouldn't happen.  load_rules() should keep any ignored
83                                                             # rules out of $self->{rules}.
84    ***      0                                  0            die "Rule $id was loaded but should be ignored";
85                                                          }
86            38                                147         my $rule_info = $advisor->get_rule_info($id);
87    ***     38     50                         126         next unless $rule_info;
88            38    100                         171         die "Info for rule $id already exists and cannot be redefined"
89                                                             if $self->{rule_info}->{$id};
90            37                                160         $self->{rule_info}->{$id} = $rule_info;
91                                                       }
92             2                                  7      return;
93                                                    }
94                                                    
95                                                    sub run_rules {
96    ***      0                    0      0      0      my ( $self, $event ) = @_;
97    ***      0                                  0      my @matched_rules;
98    ***      0                                  0      my @matched_pos;
99    ***      0                                  0      my $rules = $self->{rules};
100   ***      0                                  0      foreach my $rule ( @$rules ) {
101   ***      0      0                           0         if ( defined(my $pos = $rule->{code}->($event)) ) {
102   ***      0                                  0            MKDEBUG && _d('Matches rule', $rule->{id}, 'near pos', $pos);
103   ***      0                                  0            push @matched_rules, $rule->{id};
104   ***      0                                  0            push @matched_pos,   $pos;
105                                                         }
106                                                      }
107   ***      0                                  0      return \@matched_rules, \@matched_pos;
108                                                   };
109                                                   
110                                                   sub get_rule_info {
111   ***      2                    2      0      9      my ( $self, $id ) = @_;
112   ***      2     50                           9      return unless $id;
113            2                                 22      return $self->{rule_info}->{$id};
114                                                   }
115                                                   
116                                                   sub _d {
117   ***      0                    0                    my ($package, undef, $line) = caller 0;
118   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
119   ***      0                                              map { defined $_ ? $_ : 'undef' }
120                                                           @_;
121   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
122                                                   }
123                                                   
124                                                   1;
125                                                   
126                                                   # ###########################################################################
127                                                   # End QueryAdvisor package
128                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
33    ***      0      0      0   unless $args{$arg}
50    ***     50      0      3   unless $advisor
61           100      1     38   if ($$self{'ignore_rules'}{uc $id})
65           100      1     37   if defined $$self{'rule_index_for'}{$id}
76    ***     50      0      3   unless $advisor
81    ***     50      0     38   if ($$self{'ignore_rules'}{uc $id})
87    ***     50      0     38   unless $rule_info
88           100      1     37   if $$self{'rule_info'}{$id}
101   ***      0      0      0   if (defined(my $pos = $$rule{'code'}($event)))
112   ***     50      0      2   unless $id
118   ***      0      0      0   defined $_ ? :


Conditions
----------

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0


Covered Subroutines
-------------------

Subroutine     Count Pod Location                                           
-------------- ----- --- ---------------------------------------------------
BEGIN              1     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:22 
BEGIN              1     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:23 
BEGIN              1     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:24 
BEGIN              1     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:26 
get_rule_info      2   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:111
load_rule_info     3   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:75 
load_rules         3   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:49 
new                2   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:31 

Uncovered Subroutines
---------------------

Subroutine     Count Pod Location                                           
-------------- ----- --- ---------------------------------------------------
_d                 0     /home/daniel/dev/maatkit/common/QueryAdvisor.pm:117
run_rules          0   0 /home/daniel/dev/maatkit/common/QueryAdvisor.pm:96 


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
               1                                  3   
               1                                 10   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                 11   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
25                                                    
26             1                    1            12   use Data::Dumper;
               1                                  3   
               1                                  6   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 22   
32                                                    
33                                                    sub new {
34    ***      1                    1      0      5      my ( $class, %args ) = @_;
35             1                                  4      foreach my $arg ( qw(PodParser) ) {
36    ***      1     50                           7         die "I need a $arg argument" unless $args{$arg};
37                                                       }
38                                                    
39             1                                  4      my @rules = get_rules();
40             1                                  9      MKDEBUG && _d(scalar @rules, 'rules');
41                                                    
42             1                                  8      my $self = {
43                                                          %args,
44                                                          rules     => \@rules,
45                                                          rule_info => {},
46                                                       };
47                                                    
48             1                                 12      return bless $self, $class;
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
63    ***      0                    0             0            my ( $event ) = @_;
64    ***      0                                  0            my $struct = $event->{query_struct};
65    ***      0             0                    0            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                    0                        
66    ***      0      0                           0            return unless $tbls;
67    ***      0                                  0            foreach my $tbl ( @$tbls ) {
68    ***      0      0      0                    0               return 0 if $tbl->{alias} && !$tbl->{explicit_alias};
69                                                             }
70    ***      0                                  0            my $cols = $struct->{columns};
71    ***      0      0                           0            return unless $cols;
72    ***      0                                  0            foreach my $col ( @$cols ) {
73    ***      0      0      0                    0               return 0 if $col->{alias} && !$col->{explicit_alias};
74                                                             }
75    ***      0                                  0            return;
76                                                          },
77                                                       },
78                                                       {
79                                                          id   => 'ALI.002',      # tbl.* alias
80                                                          code => sub {
81    ***      0                    0             0            my ( $event ) = @_;
82    ***      0                                  0            my $cols = $event->{query_struct}->{columns};
83    ***      0      0                           0            return unless $cols;
84    ***      0                                  0            foreach my $col ( @$cols ) {
85    ***      0      0      0                    0               return 0 if $col->{db} && $col->{name } eq '*' &&  $col->{alias};
      ***                    0                        
86                                                             }
87    ***      0                                  0            return;
88                                                          },
89                                                       },
90                                                       {
91                                                          id   => 'ALI.003',      # tbl AS tbl
92                                                          code => sub {
93    ***      0                    0             0            my ( $event ) = @_;
94    ***      0                                  0            my $struct = $event->{query_struct};
95    ***      0             0                    0            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                    0                        
96    ***      0      0                           0            return unless $tbls;
97    ***      0                                  0            foreach my $tbl ( @$tbls ) {
98    ***      0      0      0                    0               return 0 if $tbl->{alias} && $tbl->{alias} eq $tbl->{name};
99                                                             }
100   ***      0                                  0            my $cols = $struct->{columns};
101   ***      0      0                           0            return unless $cols;
102   ***      0                                  0            foreach my $col ( @$cols ) {
103   ***      0      0      0                    0               return 0 if $col->{alias} && $col->{alias} eq $col->{name};
104                                                            }
105   ***      0                                  0            return;
106                                                         },
107                                                      },
108                                                      {
109                                                         id   => 'ARG.001',      # col = '%foo'
110                                                         code => sub {
111   ***      0                    0             0            my ( $event ) = @_;
112   ***      0      0                           0            return 0 if $event->{arg} =~ m/[\'\"][\%\_]./;
113   ***      0                                  0            return;
114                                                         },
115                                                      },
116                                                      {
117                                                         id   => 'ARG.002',      # LIKE w/o wildcard
118                                                         code => sub {
119   ***      0                    0             0            my ( $event ) = @_;
120                                                            # TODO: this pattern doesn't handle spaces.
121   ***      0                                  0            my @like_args = $event->{arg} =~ m/\bLIKE\s+(\S+)/gi;
122   ***      0                                  0            foreach my $arg ( @like_args ) {
123   ***      0      0                           0               return 0 if $arg !~ m/[%_]/;
124                                                            }
125   ***      0                                  0            return;
126                                                         },
127                                                      },
128                                                      {
129                                                         id   => 'CLA.001',      # SELECT w/o WHERE
130                                                         code => sub {
131   ***      0                    0             0            my ( $event ) = @_;
132   ***      0      0      0                    0            return unless ($event->{query_struct}->{type} || '') eq 'select';
133   ***      0      0                           0            return unless $event->{query_struct}->{from};
134   ***      0      0                           0            return 0 unless $event->{query_struct}->{where};
135   ***      0                                  0            return;
136                                                         },
137                                                      },
138                                                      {
139                                                         id   => 'CLA.002',      # ORDER BY RAND()
140                                                         code => sub {
141   ***      0                    0             0            my ( $event ) = @_;
142   ***      0                                  0            my $orderby = $event->{query_struct}->{order_by};
143   ***      0      0                           0            return unless $orderby;
144   ***      0                                  0            foreach my $col ( @$orderby ) {
145   ***      0      0                           0               return 0 if $col =~ m/RAND\([^\)]*\)/i;
146                                                            }
147   ***      0                                  0            return;
148                                                         },
149                                                      },
150                                                      {
151                                                         id   => 'CLA.003',      # LIMIT w/ OFFSET
152                                                         code => sub {
153   ***      0                    0             0            my ( $event ) = @_;
154   ***      0      0                           0            return unless $event->{query_struct}->{limit};
155   ***      0      0                           0            return unless defined $event->{query_struct}->{limit}->{offset};
156   ***      0                                  0            return 0;
157                                                         },
158                                                      },
159                                                      {
160                                                         id   => 'CLA.004',      # GROUP BY <number>
161                                                         code => sub {
162   ***      0                    0             0            my ( $event ) = @_;
163   ***      0                                  0            my $groupby = $event->{query_struct}->{group_by};
164   ***      0      0                           0            return unless $groupby;
165   ***      0                                  0            foreach my $col ( @{$groupby->{columns}} ) {
      ***      0                                  0   
166   ***      0      0                           0               return 0 if $col =~ m/^\d+\b/;
167                                                            }
168   ***      0                                  0            return;
169                                                         },
170                                                      },
171                                                      {
172                                                         id   => 'COL.001',      # SELECT *
173                                                         code => sub {
174   ***      0                    0             0            my ( $event ) = @_;
175   ***      0      0      0                    0            return unless ($event->{query_struct}->{type} || '') eq 'select';
176   ***      0                                  0            my $cols = $event->{query_struct}->{columns};
177   ***      0      0                           0            return unless $cols;
178   ***      0                                  0            foreach my $col ( @$cols ) {
179   ***      0      0                           0               return 0 if $col->{name} eq '*';
180                                                            }
181   ***      0                                  0            return;
182                                                         },
183                                                      },
184                                                      {
185                                                         id   => 'COL.002',      # INSERT w/o (cols) def
186                                                         code => sub {
187   ***      0                    0             0            my ( $event ) = @_;
188   ***      0             0                    0            my $type = $event->{query_struct}->{type} || '';
189   ***      0      0      0                    0            return unless $type eq 'insert' || $type eq 'replace';
190   ***      0      0                           0            return 0 unless $event->{query_struct}->{columns};
191   ***      0                                  0            return;
192                                                         },
193                                                      },
194                                                      {
195                                                         id   => 'LIT.001',      # IP as string
196                                                         code => sub {
197   ***      0                    0             0            my ( $event ) = @_;
198   ***      0      0                           0            if ( $event->{arg} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/gc ) {
199   ***      0             0                    0               return (pos $event->{arg}) || 0;
200                                                            }
201   ***      0                                  0            return;
202                                                         },
203                                                      },
204                                                      {
205                                                         id   => 'LIT.002',      # Date not quoted
206                                                         code => sub {
207   ***      0                    0             0            my ( $event ) = @_;
208                                                            # YYYY-MM-DD
209   ***      0      0                           0            if ( $event->{arg} =~ m/(?<!['"\w-])\d{4}-\d{1,2}-\d{1,2}\b/gc ) {
210   ***      0             0                    0               return (pos $event->{arg}) || 0;
211                                                            }
212                                                            # YY-MM-DD
213   ***      0      0                           0            if ( $event->{arg} =~ m/(?<!['"\w\d-])\d{2}-\d{1,2}-\d{1,2}\b/gc ) {
214   ***      0             0                    0               return (pos $event->{arg}) || 0;
215                                                            }
216   ***      0                                  0            return;
217                                                         },
218                                                      },
219                                                      {
220                                                         id   => 'KWR.001',      # SQL_CALC_FOUND_ROWS
221                                                         code => sub {
222   ***      0                    0             0            my ( $event ) = @_;
223   ***      0      0                           0            return 0 if $event->{query_struct}->{keywords}->{sql_calc_found_rows};
224   ***      0                                  0            return;
225                                                         },
226                                                      },
227                                                      {
228                                                         id   => 'JOI.001',      # comma and ansi joins
229                                                         code => sub {
230   ***      0                    0             0            my ( $event ) = @_;
231   ***      0                                  0            my $struct = $event->{query_struct};
232   ***      0             0                    0            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
      ***                    0                        
233   ***      0      0                           0            return unless $tbls;
234   ***      0                                  0            my $comma_join = 0;
235   ***      0                                  0            my $ansi_join  = 0;
236   ***      0                                  0            foreach my $tbl ( @$tbls ) {
237   ***      0      0                           0               if ( $tbl->{join} ) {
238   ***      0      0                           0                  if ( $tbl->{join}->{ansi} ) {
239   ***      0                                  0                     $ansi_join = 1;
240                                                                  }
241                                                                  else {
242   ***      0                                  0                     $comma_join = 1;
243                                                                  }
244                                                               }
245   ***      0      0      0                    0               return 0 if $comma_join && $ansi_join;
246                                                            }
247   ***      0                                  0            return;
248                                                         },
249                                                      },
250                                                      {
251                                                         id   => 'RES.001',      # non-deterministic GROUP BY
252                                                         code => sub {
253   ***      0                    0             0            my ( $event ) = @_;
254   ***      0      0      0                    0            return unless ($event->{query_struct}->{type} || '') eq 'select';
255   ***      0                                  0            my $groupby = $event->{query_struct}->{group_by};
256   ***      0      0                           0            return unless $groupby;
257                                                            # Only check GROUP BY column names, not numbers.  GROUP BY number
258                                                            # is handled in CLA.004.
259   ***      0                                  0            my %groupby_col = map { $_ => 1 }
      ***      0                                  0   
260   ***      0                                  0                              grep { m/^[^\d]+\b/ }
261   ***      0                                  0                              @{$groupby->{columns}};
262   ***      0      0                           0            return unless scalar %groupby_col;
263   ***      0                                  0            my $cols = $event->{query_struct}->{columns};
264                                                            # All SELECT cols must be in GROUP BY cols clause.
265                                                            # E.g. select a, b, c from tbl group by a; -- non-deterministic
266   ***      0                                  0            foreach my $col ( @$cols ) {
267   ***      0      0                           0               return 0 unless $groupby_col{ $col->{name} };
268                                                            }
269   ***      0                                  0            return;
270                                                         },
271                                                      },
272                                                      {
273                                                         id   => 'RES.002',      # non-deterministic LIMIT w/o ORDER BY
274                                                         code => sub {
275   ***      0                    0             0            my ( $event ) = @_;
276   ***      0      0                           0            return unless $event->{query_struct}->{limit};
277                                                            # If query doesn't use tables then this check isn't applicable.
278   ***      0      0      0                    0            return unless    $event->{query_struct}->{from}
      ***                    0                        
279                                                                            || $event->{query_struct}->{into}
280                                                                            || $event->{query_struct}->{tables};
281   ***      0      0                           0            return 0 unless $event->{query_struct}->{order_by};
282   ***      0                                  0            return;
283                                                         },
284                                                      },
285                                                      {
286                                                         id   => 'STA.001',      # != instead of <>
287                                                         code => sub {
288   ***      0                    0             0            my ( $event ) = @_;
289   ***      0      0                           0            return 0 if $event->{arg} =~ m/!=/;
290   ***      0                                  0            return;
291                                                         },
292                                                      },
293                                                      {
294                                                         id   => 'SUB.001',      # IN(<subquery>)
295                                                         code => sub {
296   ***      0                    0             0            my ( $event ) = @_;
297   ***      0      0                           0            if ( $event->{arg} =~ m/\bIN\s*\(\s*SELECT\b/gi ) {
298   ***      0                                  0               return pos $event->{arg};
299                                                            }
300   ***      0                                  0            return;
301                                                         },
302                                                      },
303   ***      5                    5      0    487   };
304                                                   
305                                                   # Arguments:
306                                                   #   * file     scalar: file name with POD to parse rules from
307                                                   #   * section  scalar: section name for rule items, should be RULES
308                                                   #   * rules    arrayref: optional list of rules to load info for
309                                                   # Parses rules from the POD section/subsection in file, adding rule
310                                                   # info found therein to %rule_info.  Then checks that rule info
311                                                   # was gotten for all the required rules.
312                                                   sub load_rule_info {
313   ***      1                    1      0     12      my ( $self, %args ) = @_;
314            1                                  5      foreach my $arg ( qw(file section ) ) {
315   ***      2     50                          12         die "I need a $arg argument" unless $args{$arg};
316                                                      }
317   ***      1            33                    5      my $rules = $args{rules} || $self->{rules};
318            1                                  4      my $p     = $self->{PodParser};
319                                                   
320                                                      # Parse rules and their info from the file's POD, saving
321                                                      # values to %rule_info.
322            1                                  8      $p->parse_from_file($args{file});
323            1                                 17      my $rule_items = $p->get_items($args{section});
324            1                                 18      my %seen;
325            1                                  9      foreach my $rule_id ( keys %$rule_items ) {
326           19                                 56         my $rule = $rule_items->{$rule_id};
327   ***     19     50                          74         die "Rule $rule_id has no description" unless $rule->{desc};
328   ***     19     50                          68         die "Rule $rule_id has no severity"    unless $rule->{severity};
329   ***     19     50                          79         die "Rule $rule_id is already defined"
330                                                            if exists $self->{rule_info}->{$rule_id};
331           19                                143         $self->{rule_info}->{$rule_id} = {
332                                                            id          => $rule_id,
333                                                            severity    => $rule->{severity},
334                                                            description => $rule->{desc},
335                                                         };
336                                                      }
337                                                   
338                                                      # Check that rule info was gotten for each requested rule.
339            1                                  5      foreach my $rule ( @$rules ) {
340   ***     19     50                         100         die "There is no info for rule $rule->{id} in $args{file}"
341                                                            unless $self->{rule_info}->{ $rule->{id} };
342                                                      }
343                                                   
344            1                                  5      return;
345                                                   }
346                                                   
347                                                   sub get_rule_info {
348   ***     38                   38      0    129      my ( $self, $id ) = @_;
349   ***     38     50                         135      return unless $id;
350           38                                170      return $self->{rule_info}->{$id};
351                                                   }
352                                                   
353                                                   # Used for testing.
354                                                   sub _reset_rule_info {
355   ***      0                    0                    my ( $self ) = @_;
356   ***      0                                         $self->{rule_info} = {};
357   ***      0                                         return;
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
36    ***     50      0      1   unless $args{$arg}
66    ***      0      0      0   unless $tbls
68    ***      0      0      0   if $$tbl{'alias'} and not $$tbl{'explicit_alias'}
71    ***      0      0      0   unless $cols
73    ***      0      0      0   if $$col{'alias'} and not $$col{'explicit_alias'}
83    ***      0      0      0   unless $cols
85    ***      0      0      0   if $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
96    ***      0      0      0   unless $tbls
98    ***      0      0      0   if $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
101   ***      0      0      0   unless $cols
103   ***      0      0      0   if $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
112   ***      0      0      0   if $$event{'arg'} =~ /[\'\"][\%\_]./
123   ***      0      0      0   if not $arg =~ /[%_]/
132   ***      0      0      0   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
133   ***      0      0      0   unless $$event{'query_struct'}{'from'}
134   ***      0      0      0   unless $$event{'query_struct'}{'where'}
143   ***      0      0      0   unless $orderby
145   ***      0      0      0   if $col =~ /RAND\([^\)]*\)/i
154   ***      0      0      0   unless $$event{'query_struct'}{'limit'}
155   ***      0      0      0   unless defined $$event{'query_struct'}{'limit'}{'offset'}
164   ***      0      0      0   unless $groupby
166   ***      0      0      0   if $col =~ /^\d+\b/
175   ***      0      0      0   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
177   ***      0      0      0   unless $cols
179   ***      0      0      0   if $$col{'name'} eq '*'
189   ***      0      0      0   unless $type eq 'insert' or $type eq 'replace'
190   ***      0      0      0   unless $$event{'query_struct'}{'columns'}
198   ***      0      0      0   if ($$event{'arg'} =~ /['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/cg)
209   ***      0      0      0   if ($$event{'arg'} =~ /(?<!['"\w-])\d{4}-\d{1,2}-\d{1,2}\b/cg)
213   ***      0      0      0   if ($$event{'arg'} =~ /(?<!['"\w\d-])\d{2}-\d{1,2}-\d{1,2}\b/cg)
223   ***      0      0      0   if $$event{'query_struct'}{'keywords'}{'sql_calc_found_rows'}
233   ***      0      0      0   unless $tbls
237   ***      0      0      0   if ($$tbl{'join'})
238   ***      0      0      0   if ($$tbl{'join'}{'ansi'}) { }
245   ***      0      0      0   if $comma_join and $ansi_join
254   ***      0      0      0   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
256   ***      0      0      0   unless $groupby
262   ***      0      0      0   unless scalar %groupby_col
267   ***      0      0      0   unless $groupby_col{$$col{'name'}}
276   ***      0      0      0   unless $$event{'query_struct'}{'limit'}
278   ***      0      0      0   unless $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'} or $$event{'query_struct'}{'tables'}
281   ***      0      0      0   unless $$event{'query_struct'}{'order_by'}
289   ***      0      0      0   if $$event{'arg'} =~ /!=/
297   ***      0      0      0   if ($$event{'arg'} =~ /\bIN\s*\(\s*SELECT\b/gi)
315   ***     50      0      2   unless $args{$arg}
327   ***     50      0     19   unless $$rule{'desc'}
328   ***     50      0     19   unless $$rule{'severity'}
329   ***     50      0     19   if exists $$self{'rule_info'}{$rule_id}
340   ***     50      0     19   unless $$self{'rule_info'}{$$rule{'id'}}
349   ***     50      0     38   unless $id
362   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
68    ***      0      0      0      0   $$tbl{'alias'} and not $$tbl{'explicit_alias'}
73    ***      0      0      0      0   $$col{'alias'} and not $$col{'explicit_alias'}
85    ***      0      0      0      0   $$col{'db'} and $$col{'name'} eq '*'
      ***      0      0      0      0   $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
98    ***      0      0      0      0   $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
103   ***      0      0      0      0   $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
245   ***      0      0      0      0   $comma_join and $ansi_join

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
132   ***      0      0      0   $$event{'query_struct'}{'type'} || ''
175   ***      0      0      0   $$event{'query_struct'}{'type'} || ''
188   ***      0      0      0   $$event{'query_struct'}{'type'} || ''
199   ***      0      0      0   pos $$event{'arg'} || 0
210   ***      0      0      0   pos $$event{'arg'} || 0
214   ***      0      0      0   pos $$event{'arg'} || 0
254   ***      0      0      0   $$event{'query_struct'}{'type'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
65    ***      0      0      0      0   $$struct{'from'} || $$struct{'into'}
      ***      0      0      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
95    ***      0      0      0      0   $$struct{'from'} || $$struct{'into'}
      ***      0      0      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
189   ***      0      0      0      0   $type eq 'insert' or $type eq 'replace'
232   ***      0      0      0      0   $$struct{'from'} || $$struct{'into'}
      ***      0      0      0      0   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
278   ***      0      0      0      0   $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'}
      ***      0      0      0      0   $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'} or $$event{'query_struct'}{'tables'}
317   ***     33      1      0      0   $args{'rules'} || $$self{'rules'}


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                                
---------------- ----- --- --------------------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:22 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:23 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:24 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:26 
BEGIN                1     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:31 
get_rule_info       38   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:348
get_rules            5   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:303
load_rule_info       1   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:313
new                  1   0 /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:34 

Uncovered Subroutines
---------------------

Subroutine       Count Pod Location                                                
---------------- ----- --- --------------------------------------------------------
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:111
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:119
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:131
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:141
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:153
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:162
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:174
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:187
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:197
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:207
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:222
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:230
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:253
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:275
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:288
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:296
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:63 
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:81 
__ANON__             0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:93 
_d                   0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:361
_reset_rule_info     0     /home/daniel/dev/maatkit/common/QueryAdvisorRules.pm:355


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
               1                                  2   
               1                                  6   
10             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
11             1                    1            15   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
12             1                    1            10   use Test::More tests => 5;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            13   use MaatkitTest;
               1                                  4   
               1                                 36   
15             1                    1            12   use QueryAdvisorRules;
               1                                  3   
               1                                 20   
16             1                    1            14   use QueryAdvisor;
               1                                  4   
               1                                  9   
17             1                    1            15   use PodParser;
               1                                  3   
               1                                  9   
18                                                    
19                                                    # This module's purpose is to run rules and return a list of the IDs of the
20                                                    # triggered rules.  It should be very simple.  (But we don't want to put the two
21                                                    # modules together.  Their purposes are distinct.)
22             1                                  9   my $p   = new PodParser();
23             1                                 36   my $qar = new QueryAdvisorRules(PodParser => $p);
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
36             1                                 17      qr/Rule \S+ already exists and cannot be redefined/,
37                                                       'Duplicate rules are caught',
38                                                    );
39                                                    
40                                                    # We'll also load the rule info, so we can test $qa->get_rule_info() after the
41                                                    # POD is loaded.
42             1                                 20   $qar->load_rule_info(
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
53             1                                104   $qa->load_rule_info($qar);
54                                                    
55                                                    # TODO: write a test that the rules are described as defined in the POD of the
56                                                    # tool.  Testing one rule should be enough.
57                                                    
58                                                    # Test that it can't be redefined...
59                                                    throws_ok (
60             1                    1            15      sub { $qa->load_rule_info($qar) },
61             1                                 16      qr/Info for rule \S+ already exists and cannot be redefined/,
62                                                       'Duplicate rule info is caught',
63                                                    );
64                                                    
65             1                                 12   is_deeply(
66                                                       $qa->get_rule_info('ALI.001'),
67                                                       {
68                                                          id          => 'ALI.001',
69                                                          severity    => 'note',
70                                                          description => 'Aliasing without the AS keyword.  Explicitly using the AS keyword in column or table aliases, such as "tbl AS alias," is more readable than implicit aliases such as "tbl alias".',
71                                                       },
72                                                       'get_rule_info()'
73                                                    );
74                                                    
75                                                    
76                                                    # #############################################################################
77                                                    # Ignore rules.
78                                                    # #############################################################################
79             1                                 14   $qa = new QueryAdvisor(
80                                                       ignore_rules => { 'LIT.002' => 1 },
81                                                    );
82             1                                104   $qa->load_rules($qar);
83             1                                  6   $qa->load_rule_info($qar);
84             1                                  5   is(
85                                                       $qa->get_rule_info('LIT.002'),
86                                                       undef,
87                                                       "Didn't load ignored rule"
88                                                    );
89                                                    
90                                                    # #############################################################################
91                                                    # Done.
92                                                    # #############################################################################
93             1                                  3   my $output = '';
94                                                    {
95             1                                  3      local *STDERR;
               1                                  5   
96             1                    1             3      open STDERR, '>', \$output;
               1                                295   
               1                                  2   
               1                                  7   
97             1                                 16      $p->_d('Complete test coverage');
98                                                    }
99                                                    like(
100            1                                 16      $output,
101                                                      qr/Complete test coverage/,
102                                                      '_d() works'
103                                                   );
104            1                                  4   exit;


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
BEGIN          1 QueryAdvisor.t:9 
BEGIN          1 QueryAdvisor.t:96
__ANON__       1 QueryAdvisor.t:35
__ANON__       1 QueryAdvisor.t:60


