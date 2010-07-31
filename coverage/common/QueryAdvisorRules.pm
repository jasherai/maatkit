---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...mmon/QueryAdvisorRules.pm   99.4   96.5   78.1  100.0    0.0   49.3   94.1
QueryAdvisorRules.t            96.2   62.5   33.3   93.3    n/a   50.7   88.4
Total                          98.3   93.6   72.6   97.6    0.0  100.0   92.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jul  8 23:13:56 2010
Finish:       Thu Jul  8 23:13:56 2010

Run:          QueryAdvisorRules.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jul  8 23:13:57 2010
Finish:       Thu Jul  8 23:13:57 2010

/home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm

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
18                                                    # QueryAdvisorRules package $Revision: 6679 $
19                                                    # ###########################################################################
20                                                    package QueryAdvisorRules;
21             1                    1             4   use base 'AdvisorRules';
               1                                  3   
               1                                 17   
22                                                    
23             1                    1             6   use strict;
               1                                  2   
               1                                 42   
24             1                    1             9   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
25             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
26    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 19   
27                                                    
28                                                    sub new {
29    ***      2                    2      0     13      my ( $class, %args ) = @_;
30             2                                 42      my $self = $class->SUPER::new(%args);
31             2                                 83      @{$self->{rules}} = $self->get_rules();
               2                                 17   
32             2                                 11      MKDEBUG && _d(scalar @{$self->{rules}}, "rules");
33             2                                 10      return $self;
34                                                    }
35                                                    
36                                                    # Each rules is a hashref with two keys:
37                                                    #   * id       Unique PREFIX.NUMBER for the rule.  The prefix is three chars
38                                                    #              which hints to the nature of the rule.  See example below.
39                                                    #   * code     Coderef to check rule, returns undef if rule does not match,
40                                                    #              else returns the string pos near where the rule matches or 0
41                                                    #              to indicate it doesn't know the pos.  The code is passed a\
42                                                    #              single arg: a hashref event.
43                                                    sub get_rules {
44                                                       return
45                                                       {
46                                                          id   => 'ALI.001',      # Implicit alias
47                                                          code => sub {
48            47                   47          1361            my ( %args ) = @_;
49            47                                170            my $event  = $args{event};
50            47                                169            my $struct = $event->{query_struct};
51            47           100                  337            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
                           100                        
52            47    100                         185            return unless $tbls;
53            46                                170            foreach my $tbl ( @$tbls ) {
54    ***     50     50     66                  336               return 0 if $tbl->{alias} && !$tbl->{explicit_alias};
55                                                             }
56            46                                174            my $cols = $struct->{columns};
57            46    100                         177            return unless $cols;
58            39                                142            foreach my $col ( @$cols ) {
59            42    100    100                  276               return 0 if $col->{alias} && !$col->{explicit_alias};
60                                                             }
61            37                                171            return;
62                                                          },
63                                                       },
64                                                       {
65                                                          id   => 'ALI.002',      # tbl.* alias
66                                                          code => sub {
67            47                   47           769            my ( %args ) = @_;
68            47                                165            my $event = $args{event};
69            47                                189            my $cols  = $event->{query_struct}->{columns};
70            47    100                         180            return unless $cols;
71            40                                134            foreach my $col ( @$cols ) {
72    ***     43    100     66                  371               return 0 if $col->{db} && $col->{name } eq '*' &&  $col->{alias};
      ***                   66                        
73                                                             }
74            39                                162            return;
75                                                          },
76                                                       },
77                                                       {
78                                                          id   => 'ALI.003',      # tbl AS tbl
79                                                          code => sub {
80            47                   47           719            my ( %args ) = @_;
81            47                                166            my $event  = $args{event};
82            47                                161            my $struct = $event->{query_struct};
83            47           100                  295            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
                           100                        
84            47    100                         171            return unless $tbls;
85            46                                178            foreach my $tbl ( @$tbls ) {
86            50    100    100                  351               return 0 if $tbl->{alias} && $tbl->{alias} eq $tbl->{name};
87                                                             }
88            45                                160            my $cols = $struct->{columns};
89            45    100                         198            return unless $cols;
90            38                                126            foreach my $col ( @$cols ) {
91            41    100    100                  290               return 0 if $col->{alias} && $col->{alias} eq $col->{name};
92                                                             }
93            37                                156            return;
94                                                          },
95                                                       },
96                                                       {
97                                                          id   => 'ARG.001',      # col = '%foo'
98                                                          code => sub {
99            47                   47           747            my ( %args ) = @_;
100           47                                162            my $event = $args{event};
101           47    100                         264            return 0 if $event->{arg} =~ m/[\'\"][\%\_]./;
102           43                                163            return;
103                                                         },
104                                                      },
105                                                      {
106                                                         id   => 'ARG.002',      # LIKE w/o wildcard
107                                                         code => sub {
108           47                   47           747            my ( %args ) = @_;
109           47                                169            my $event = $args{event};        
110                                                            # TODO: this pattern doesn't handle spaces.
111           47                                373            my @like_args = $event->{arg} =~ m/\bLIKE\s+(\S+)/gi;
112           47                                181            foreach my $arg ( @like_args ) {
113            5    100                          32               return 0 if $arg !~ m/[%_]/;
114                                                            }
115           45                                189            return;
116                                                         },
117                                                      },
118                                                      {
119                                                         id   => 'CLA.001',      # SELECT w/o WHERE
120                                                         code => sub {
121           47                   47           738            my ( %args ) = @_;
122           47                                187            my $event = $args{event};
123   ***     47    100     50                  321            return unless ($event->{query_struct}->{type} || '') eq 'select';
124           40    100                         198            return unless $event->{query_struct}->{from};
125           39    100                         188            return 0 unless $event->{query_struct}->{where};
126           38                                157            return;
127                                                         },
128                                                      },
129                                                      {
130                                                         id   => 'CLA.002',      # ORDER BY RAND()
131                                                         code => sub {
132           47                   47           729            my ( %args ) = @_;
133           47                                163            my $event   = $args{event};
134           47                                185            my $orderby = $event->{query_struct}->{order_by};
135           47    100                         233            return unless $orderby;
136            4                                 16            foreach my $col ( @$orderby ) {
137            4    100                          27               return 0 if $col =~ m/RAND\([^\)]*\)/i;
138                                                            }
139            2                                  9            return;
140                                                         },
141                                                      },
142                                                      {
143                                                         id   => 'CLA.003',      # LIMIT w/ OFFSET
144                                                         code => sub {
145           47                   47           726            my ( %args ) = @_;
146           47                                160            my $event = $args{event};
147           47    100                         286            return unless $event->{query_struct}->{limit};
148            4    100                          28            return unless defined $event->{query_struct}->{limit}->{offset};
149            2                                  9            return 0;
150                                                         },
151                                                      },
152                                                      {
153                                                         id   => 'CLA.004',      # GROUP BY <number>
154                                                         code => sub {
155           47                   47           721            my ( %args ) = @_;
156           47                                158            my $event   = $args{event};
157           47                                192            my $groupby = $event->{query_struct}->{group_by};
158           47    100                         227            return unless $groupby;
159            3                                  9            foreach my $col ( @{$groupby->{columns}} ) {
               3                                 13   
160            4    100                          30               return 0 if $col =~ m/^\d+\b/;
161                                                            }
162            2                                 10            return;
163                                                         },
164                                                      },
165                                                      {
166                                                         id   => 'COL.001',      # SELECT *
167                                                         code => sub {
168           47                   47           697            my ( %args ) = @_;
169           47                                169            my $event = $args{event};
170   ***     47    100     50                  304            return unless ($event->{query_struct}->{type} || '') eq 'select';
171           40                                155            my $cols = $event->{query_struct}->{columns};
172   ***     40     50                         136            return unless $cols;
173           40                                146            foreach my $col ( @$cols ) {
174           43    100                         251               return 0 if $col->{name} eq '*';
175                                                            }
176           38                                166            return;
177                                                         },
178                                                      },
179                                                      {
180                                                         id   => 'COL.002',      # INSERT w/o (cols) def
181                                                         code => sub {
182           47                   47           717            my ( %args ) = @_;
183           47                                163            my $event = $args{event};
184   ***     47            50                  253            my $type  = $event->{query_struct}->{type} || '';
185   ***     47    100     66                  496            return unless $type eq 'insert' || $type eq 'replace';
186   ***      2     50                          15            return 0 unless $event->{query_struct}->{columns};
187   ***      0                                  0            return;
188                                                         },
189                                                      },
190                                                      {
191                                                         id   => 'LIT.001',      # IP as string
192                                                         code => sub {
193           47                   47           730            my ( %args ) = @_;
194           47                                163            my $event = $args{event};
195           47    100                         251            if ( $event->{arg} =~ m/['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/gc ) {
196   ***      1            50                    8               return (pos $event->{arg}) || 0;
197                                                            }
198           46                                180            return;
199                                                         },
200                                                      },
201                                                      {
202                                                         id   => 'LIT.002',      # Date not quoted
203                                                         code => sub {
204           47                   47           702            my ( %args ) = @_;
205           47                                156            my $event = $args{event};
206                                                            # YYYY-MM-DD
207           47    100                         245            if ( $event->{arg} =~ m/(?<!['"\w-])\d{4}-\d{1,2}-\d{1,2}\b/gc ) {
208   ***      4            50                   29               return (pos $event->{arg}) || 0;
209                                                            }
210                                                            # YY-MM-DD
211           43    100                         209            if ( $event->{arg} =~ m/(?<!['"\w\d-])\d{2}-\d{1,2}-\d{1,2}\b/gc ) {
212   ***      3            50                   23               return (pos $event->{arg}) || 0;
213                                                            }
214           40                                157            return;
215                                                         },
216                                                      },
217                                                      {
218                                                         id   => 'KWR.001',      # SQL_CALC_FOUND_ROWS
219                                                         code => sub {
220           47                   47           774            my ( %args ) = @_;
221           47                                162            my $event = $args{event};
222           47    100                         291            return 0 if $event->{query_struct}->{keywords}->{sql_calc_found_rows};
223           46                                173            return;
224                                                         },
225                                                      },
226                                                      {
227                                                         id   => 'JOI.001',      # comma and ansi joins
228                                                         code => sub {
229           47                   47           701            my ( %args ) = @_;
230           47                                159            my $event  = $args{event};
231           47                                157            my $struct = $event->{query_struct};
232           47           100                  304            my $tbls   = $struct->{from} || $struct->{into} || $struct->{tables};
                           100                        
233           47    100                         167            return unless $tbls;
234           46                                124            my $comma_join = 0;
235           46                                126            my $ansi_join  = 0;
236           46                                170            foreach my $tbl ( @$tbls ) {
237           50    100                         206               if ( $tbl->{join} ) {
238            5    100                          23                  if ( $tbl->{join}->{ansi} ) {
239            3                                 11                     $ansi_join = 1;
240                                                                  }
241                                                                  else {
242            2                                  6                     $comma_join = 1;
243                                                                  }
244                                                               }
245           50    100    100                  300               return 0 if $comma_join && $ansi_join;
246                                                            }
247           45                                193            return;
248                                                         },
249                                                      },
250                                                      {
251                                                         id   => 'RES.001',      # non-deterministic GROUP BY
252                                                         code => sub {
253           47                   47           736            my ( %args ) = @_;
254           47                                164            my $event = $args{event};
255   ***     47    100     50                  313            return unless ($event->{query_struct}->{type} || '') eq 'select';
256           40                                155            my $groupby = $event->{query_struct}->{group_by};
257           40    100                         195            return unless $groupby;
258                                                            # Only check GROUP BY column names, not numbers.  GROUP BY number
259                                                            # is handled in CLA.004.
260            3                                 15            my %groupby_col = map { $_ => 1 }
               4                                 20   
261            3                                 12                              grep { m/^[^\d]+\b/ }
262            3                                 10                              @{$groupby->{columns}};
263            3    100                          20            return unless scalar %groupby_col;
264            2                                  9            my $cols = $event->{query_struct}->{columns};
265                                                            # All SELECT cols must be in GROUP BY cols clause.
266                                                            # E.g. select a, b, c from tbl group by a; -- non-deterministic
267            2                                  8            foreach my $col ( @$cols ) {
268            4    100                          22               return 0 unless $groupby_col{ $col->{name} };
269                                                            }
270            1                                  6            return;
271                                                         },
272                                                      },
273                                                      {
274                                                         id   => 'RES.002',      # non-deterministic LIMIT w/o ORDER BY
275                                                         code => sub {
276           47                   47           697            my ( %args ) = @_;
277           47                                160            my $event = $args{event};
278           47    100                         286            return unless $event->{query_struct}->{limit};
279                                                            # If query doesn't use tables then this check isn't applicable.
280   ***      4    100     66                   41            return unless    $event->{query_struct}->{from}
      ***                   66                        
281                                                                            || $event->{query_struct}->{into}
282                                                                            || $event->{query_struct}->{tables};
283            3    100                          18            return 0 unless $event->{query_struct}->{order_by};
284            2                                  7            return;
285                                                         },
286                                                      },
287                                                      {
288                                                         id   => 'STA.001',      # != instead of <>
289                                                         code => sub {
290           47                   47           737            my ( %args ) = @_;
291           47                                182            my $event = $args{event};
292           47    100                         232            return 0 if $event->{arg} =~ m/!=/;
293           46                                179            return;
294                                                         },
295                                                      },
296                                                      {
297                                                         id   => 'SUB.001',      # IN(<subquery>)
298                                                         code => sub {
299           47                   47           703            my ( %args ) = @_;
300           47                                159            my $event = $args{event};
301           47    100                         340            if ( $event->{arg} =~ m/\bIN\s*\(\s*SELECT\b/gi ) {
302            1                                  7               return pos $event->{arg};
303                                                            }
304           46                                172            return;
305                                                         },
306                                                      },
307   ***      5                    5      0    536   };
308                                                   
309                                                   1;
310                                                   
311                                                   # ###########################################################################
312                                                   # End QueryAdvisorRules package
313                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
52           100      1     46   unless $tbls
54    ***     50      0     50   if $$tbl{'alias'} and not $$tbl{'explicit_alias'}
57           100      7     39   unless $cols
59           100      2     40   if $$col{'alias'} and not $$col{'explicit_alias'}
70           100      7     40   unless $cols
72           100      1     42   if $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
84           100      1     46   unless $tbls
86           100      1     49   if $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
89           100      7     38   unless $cols
91           100      1     40   if $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
101          100      4     43   if $$event{'arg'} =~ /[\'\"][\%\_]./
113          100      2      3   if not $arg =~ /[%_]/
123          100      7     40   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
124          100      1     39   unless $$event{'query_struct'}{'from'}
125          100      1     38   unless $$event{'query_struct'}{'where'}
135          100     43      4   unless $orderby
137          100      2      2   if $col =~ /RAND\([^\)]*\)/i
147          100     43      4   unless $$event{'query_struct'}{'limit'}
148          100      2      2   unless defined $$event{'query_struct'}{'limit'}{'offset'}
158          100     44      3   unless $groupby
160          100      1      3   if $col =~ /^\d+\b/
170          100      7     40   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
172   ***     50      0     40   unless $cols
174          100      2     41   if $$col{'name'} eq '*'
185          100     45      2   unless $type eq 'insert' or $type eq 'replace'
186   ***     50      2      0   unless $$event{'query_struct'}{'columns'}
195          100      1     46   if ($$event{'arg'} =~ /['"]\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/cg)
207          100      4     43   if ($$event{'arg'} =~ /(?<!['"\w-])\d{4}-\d{1,2}-\d{1,2}\b/cg)
211          100      3     40   if ($$event{'arg'} =~ /(?<!['"\w\d-])\d{2}-\d{1,2}-\d{1,2}\b/cg)
222          100      1     46   if $$event{'query_struct'}{'keywords'}{'sql_calc_found_rows'}
233          100      1     46   unless $tbls
237          100      5     45   if ($$tbl{'join'})
238          100      3      2   if ($$tbl{'join'}{'ansi'}) { }
245          100      1     49   if $comma_join and $ansi_join
255          100      7     40   unless ($$event{'query_struct'}{'type'} || '') eq 'select'
257          100     37      3   unless $groupby
263          100      1      2   unless scalar %groupby_col
268          100      1      3   unless $groupby_col{$$col{'name'}}
278          100     43      4   unless $$event{'query_struct'}{'limit'}
280          100      1      3   unless $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'} or $$event{'query_struct'}{'tables'}
283          100      1      2   unless $$event{'query_struct'}{'order_by'}
292          100      1     46   if $$event{'arg'} =~ /!=/
301          100      1     46   if ($$event{'arg'} =~ /\bIN\s*\(\s*SELECT\b/gi)


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
54    ***     66     47      3      0   $$tbl{'alias'} and not $$tbl{'explicit_alias'}
59           100     39      1      2   $$col{'alias'} and not $$col{'explicit_alias'}
72    ***     66     42      0      1   $$col{'db'} and $$col{'name'} eq '*'
      ***     66     42      0      1   $$col{'db'} and $$col{'name'} eq '*' and $$col{'alias'}
86           100     47      2      1   $$tbl{'alias'} and $$tbl{'alias'} eq $$tbl{'name'}
91           100     38      2      1   $$col{'alias'} and $$col{'alias'} eq $$col{'name'}
245          100     47      2      1   $comma_join and $ansi_join

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0
123   ***     50     47      0   $$event{'query_struct'}{'type'} || ''
170   ***     50     47      0   $$event{'query_struct'}{'type'} || ''
184   ***     50     47      0   $$event{'query_struct'}{'type'} || ''
196   ***     50      1      0   pos $$event{'arg'} || 0
208   ***     50      4      0   pos $$event{'arg'} || 0
212   ***     50      3      0   pos $$event{'arg'} || 0
255   ***     50     47      0   $$event{'query_struct'}{'type'} || ''

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
51           100     41      2      4   $$struct{'from'} || $$struct{'into'}
             100     43      3      1   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
83           100     41      2      4   $$struct{'from'} || $$struct{'into'}
             100     43      3      1   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
185   ***     66      2      0     45   $type eq 'insert' or $type eq 'replace'
232          100     41      2      4   $$struct{'from'} || $$struct{'into'}
             100     43      3      1   $$struct{'from'} || $$struct{'into'} || $$struct{'tables'}
280   ***     66      3      0      1   $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'}
      ***     66      3      0      1   $$event{'query_struct'}{'from'} or $$event{'query_struct'}{'into'} or $$event{'query_struct'}{'tables'}


Covered Subroutines
-------------------

Subroutine Count Pod Location                                                             
---------- ----- --- ---------------------------------------------------------------------
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:21 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:23 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:24 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:25 
BEGIN          1     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:26 
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:108
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:121
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:132
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:145
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:155
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:168
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:182
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:193
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:204
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:220
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:229
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:253
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:276
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:290
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:299
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:48 
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:67 
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:80 
__ANON__      47     /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:99 
get_rules      5   0 /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:307
new            2   0 /home/daniel/dev/maatkit/working-copy/common/QueryAdvisorRules.pm:29 


QueryAdvisorRules.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            33      die "The MAATKIT_WORKING_COPY environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
5                                                           unless $ENV{MAATKIT_WORKING_COPY} && -d $ENV{MAATKIT_WORKING_COPY};
6              1                                  8      unshift @INC, "$ENV{MAATKIT_WORKING_COPY}/common";
7                                                     };
8                                                     
9              1                    1            12   use strict;
               1                                  2   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
11             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
12             1                    1            10   use Test::More tests => 58;
               1                                  3   
               1                                  9   
13                                                    
14             1                    1            13   use MaatkitTest;
               1                                  4   
               1                                 40   
15             1                    1            16   use PodParser;
               1                                  3   
               1                                  9   
16             1                    1            10   use AdvisorRules;
               1                                  4   
               1                                 11   
17             1                    1            10   use QueryAdvisorRules;
               1                                  3   
               1                                 11   
18             1                    1            11   use Advisor;
               1                                  3   
               1                                 10   
19             1                    1            20   use SQLParser;
               1                                  3   
               1                                 12   
20                                                    
21                                                    # This test should just test that the QueryAdvisor module conforms to the
22                                                    # expected interface:
23                                                    #   - It has a get_rules() method that returns a list of hashrefs:
24                                                    #     ({ID => 'ID', code => $code}, {ID => ..... }, .... )
25                                                    #   - It has a load_rule_info() method that accepts a list of hashrefs, which
26                                                    #     we'll use to load rule info from POD.  Our built-in rule module won't
27                                                    #     store its own rule info.  But plugins supplied by users should.
28                                                    #   - It has a get_rule_info() method that accepts an ID and returns a hashref:
29                                                    #     {ID => 'ID', Severity => 'NOTE|WARN|CRIT', Description => '......'}
30             1                                  9   my $p   = new PodParser();
31             1                                 37   my $qar = new QueryAdvisorRules(PodParser => $p);
32                                                    
33             1                                  5   my @rules = $qar->get_rules();
34             1                                  9   ok(
35                                                       scalar @rules,
36                                                       'Returns array of rules'
37                                                    );
38                                                    
39             1                                  4   my $rules_ok = 1;
40             1                                  5   foreach my $rule ( @rules ) {
41    ***     19     50     33                  261      if (    !$rule->{id}
      ***                   33                        
42                                                            || !$rule->{code}
43                                                            || (ref $rule->{code} ne 'CODE') )
44                                                       {
45    ***      0                                  0         $rules_ok = 0;
46    ***      0                                  0         last;
47                                                       }
48                                                    }
49                                                    ok(
50             1                                  5      $rules_ok,
51                                                       'All rules are proper'
52                                                    );
53                                                    
54                                                    # QueryAdvisorRules.pm has more rules than mqa-rule-LIT.001.pod so to avoid
55                                                    # "There is no info" errors we remove all but LIT.001.
56             1                                  4   @rules = grep { $_->{id} eq 'LIT.001' } @rules;
              19                                177   
57                                                    
58                                                    # Test that we can load rule info from POD.  Make a sample POD file that has a
59                                                    # single sample rule definition for LIT.001 or something.
60             1                                 28   $qar->load_rule_info(
61                                                       rules    => \@rules,
62                                                       file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
63                                                       section  => 'RULES',
64                                                    );
65                                                    
66                                                    # We shouldn't be able to load the same rule info twice.
67                                                    throws_ok(
68                                                       sub {
69             1                    1            21         $qar->load_rule_info(
70                                                             rules    => \@rules,
71                                                             file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
72                                                             section  => 'RULES',
73                                                          );
74                                                       },
75             1                                105      qr/Rule \S+ is already defined/,
76                                                       'Duplicate rule info is caught'
77                                                    );
78                                                    
79                                                    # Test that we can now get a hashref as described above.
80             1                                 20   is_deeply(
81                                                       $qar->get_rule_info('LIT.001'),
82                                                       {  id          => 'LIT.001',
83                                                          severity    => 'note',
84                                                          description => "IP address used as string.  The string literal looks like an IP address but is not used inside INET_ATON().  WHERE ip='127.0.0.1' is better as ip=INET_ATON('127.0.0.1') if the column is numeric.",
85                                                       },
86                                                       'get_rule_info(LIT.001) works',
87                                                    );
88                                                    
89                                                    # Test getting a nonexistent rule.
90             1                                 13   is(
91                                                       $qar->get_rule_info('BAR.002'),
92                                                       undef,
93                                                       "get_rule_info() nonexistent rule"
94                                                    );
95                                                    
96             1                                 12   is(
97                                                       $qar->get_rule_info(),
98                                                       undef,
99                                                       "get_rule_info(undef)"
100                                                   );
101                                                   
102                                                   # Add a rule for which there is no POD info and test that it's not allowed.
103                                                   push @rules, {
104                                                      id   => 'FOO.001',
105   ***      0                    0             0      code => sub { return },
106            1                                 11   };
107            1                                 12   $qar->_reset_rule_info();  # else we'll get "cannot redefine rule" error
108                                                   throws_ok (
109                                                      sub {
110            1                    1            19         $qar->load_rule_info(
111                                                            rules    => \@rules,
112                                                            file     => "$trunk/common/t/samples/pod/mqa-rule-LIT.001.pod",
113                                                            section  => 'RULES',
114                                                         );
115                                                      },
116            1                                 29      qr/There is no info for rule FOO.001/,
117                                                      "Doesn't allow rules without info",
118                                                   );
119                                                   
120                                                   # ###########################################################################
121                                                   # Test cases for the rules themselves.
122                                                   # ###########################################################################
123            1                                175   my @cases = (
124                                                      {  name   => 'IP address not inside INET_ATON, plus SELECT * is used',
125                                                         query  => 'SELECT * FROM tbl WHERE ip="127.0.0.1"',
126                                                         advice => [qw(COL.001 LIT.001)],
127                                                         pos    => [0, 37],
128                                                      },
129                                                      {  name   => 'Date literal not quoted',
130                                                         query  => 'SELECT col FROM tbl WHERE col < 2001-01-01',
131                                                         advice => [qw(LIT.002)],
132                                                      },
133                                                      {  name   => 'Aliases without AS keyword',
134                                                         query  => 'SELECT a b FROM tbl',
135                                                         advice => [qw(ALI.001 CLA.001)],
136                                                      },
137                                                      {  name   => 'tbl.* alias',
138                                                         query  => 'SELECT tbl.* foo FROM bar WHERE id=1',
139                                                         advice => [qw(ALI.001 ALI.002 COL.001)],
140                                                      },
141                                                      {  name   => 'tbl as tbl',
142                                                         query  => 'SELECT col FROM tbl AS tbl WHERE id',
143                                                         advice => [qw(ALI.003)],
144                                                      },
145                                                      {  name   => 'col as col',
146                                                         query  => 'SELECT col AS col FROM tbl AS `my tbl` WHERE id',
147                                                         advice => [qw(ALI.003)],
148                                                      },
149                                                      {  name   => 'Blind INSERT',
150                                                         query  => 'INSERT INTO tbl VALUES(1),(2)',
151                                                         advice => [qw(COL.002)],
152                                                      },
153                                                      {  name   => 'Blind INSERT',
154                                                         query  => 'INSERT tbl VALUE (1)',
155                                                         advice => [qw(COL.002)],
156                                                      },
157                                                      {  name   => 'SQL_CALC_FOUND_ROWS',
158                                                         query  => 'SELECT SQL_CALC_FOUND_ROWS col FROM tbl AS alias WHERE id=1',
159                                                         advice => [qw(KWR.001)],
160                                                      },
161                                                      {  name   => 'All comma joins ok',
162                                                         query  => 'SELECT col FROM tbl1, tbl2 WHERE tbl1.id=tbl2.id',
163                                                         advice => [],
164                                                      },
165                                                      {  name   => 'All ANSI joins ok',
166                                                         query  => 'SELECT col FROM tbl1 JOIN tbl2 USING(id) WHERE tbl1.id>10',
167                                                         advice => [],
168                                                      },
169                                                      {  name   => 'Mix comman/ANSI joins',
170                                                         query  => 'SELECT col FROM tbl, tbl1 JOIN tbl2 USING(id) WHERE tbl.d>10',
171                                                         advice => [qw(JOI.001)],
172                                                      },
173                                                      {  name   => 'Non-deterministic GROUP BY',
174                                                         query  => 'select a, b, c from tbl where foo group by a',
175                                                         advice => [qw(RES.001)],
176                                                      },
177                                                      {  name   => 'Non-deterministic LIMIT w/o ORDER BY',
178                                                         query  => 'select a, b from tbl where foo limit 10 group by a, b',
179                                                         advice => [qw(RES.002)],
180                                                      },
181                                                      {  name   => 'ORDER BY RAND()',
182                                                         query  => 'select a from t where id order by rand()',
183                                                         advice => [qw(CLA.002)],
184                                                      },
185                                                      {  name   => 'ORDER BY RAND(N)',
186                                                         query  => 'select a from t where id order by rand(123)',
187                                                         advice => [qw(CLA.002)],
188                                                      },
189                                                      {  name   => 'LIMIT w/ OFFSET does not scale',
190                                                         query  => 'select a from t where i limit 10, 10 order by a',
191                                                         advice => [qw(CLA.003)],
192                                                      },
193                                                      {  name   => 'LIMIT w/ OFFSET does not scale',
194                                                         query  => 'select a from t where i limit 10 OFFSET 10 order by a',
195                                                         advice => [qw(CLA.003)],
196                                                      },
197                                                      {  name   => 'Leading %wildcard',
198                                                         query  => 'select a from t where i="%hm"',
199                                                         advice => [qw(ARG.001)],
200                                                      },
201                                                      {  name   => 'Leading _wildcard',
202                                                         query  => 'select a from t where i="_hm"',
203                                                         advice => [qw(ARG.001)],
204                                                      },
205                                                      {  name   => 'Leading "% wildcard"',
206                                                         query  => 'select a from t where i="% eh "',
207                                                         advice => [qw(ARG.001)],
208                                                      },
209                                                      {  name   => 'Leading "_ wildcard"',
210                                                         query  => 'select a from t where i="_ eh "',
211                                                         advice => [qw(ARG.001)],
212                                                      },
213                                                      {  name   => 'GROUP BY number',
214                                                         query  => 'select a from t where i group by 1',
215                                                         advice => [qw(CLA.004)],
216                                                      },
217                                                      {  name   => '!= instead of <>',
218                                                         query  => 'select a from t where i != 2',
219                                                         advice => [qw(STA.001)],
220                                                      },
221                                                      {  name   => "LIT.002 doesn't match",
222                                                         query  => "update foo.bar set biz = '91848182522'",
223                                                         advice => [],
224                                                      },
225                                                      {  name   => "LIT.002 doesn't match",
226                                                         query  => "update db2.tuningdetail_21_265507 inner join db1.gonzo using(g) set n.c1 = a.c1, n.w3 = a.w3",
227                                                         advice => [],
228                                                      },
229                                                      {  name   => "LIT.002 doesn't match",
230                                                         query  => "UPDATE db4.vab3concept1upload
231                                                                    SET    vab3concept1id = '91848182522'
232                                                                    WHERE  vab3concept1upload='6994465'",
233                                                         advice => [],
234                                                      },
235                                                      {  name   => "LIT.002 at end of query",
236                                                         query  => "select c from t where d=2006-10-10",
237                                                         advice => [qw(LIT.002)],
238                                                      },
239                                                      {  name   => "LIT.002 5 digits doesn't match",
240                                                         query  => "select c from t where d=12345",
241                                                         advice => [],
242                                                      },
243                                                      {  name   => "LIT.002 7 digits doesn't match",
244                                                         query  => "select c from t where d=1234567",
245                                                         advice => [],
246                                                      },
247                                                      {  name   => "SELECT var LIMIT",
248                                                         query  => "select \@\@version_comment limit 1 ",
249                                                         advice => [],
250                                                      },
251                                                      {  name   => "Date with time",
252                                                         query  => "select c from t where d > 2010-03-15 09:09:09",
253                                                         advice => [qw(LIT.002)],
254                                                      },
255                                                      {  name   => "Date with time and subseconds",
256                                                         query  => "select c from t where d > 2010-03-15 09:09:09.123456",
257                                                         advice => [qw(LIT.002)],
258                                                      },
259                                                      {  name   => "Date with time doesn't match",
260                                                         query  => "select c from t where d > '2010-03-15 09:09:09'",
261                                                         advice => [qw()],
262                                                      },
263                                                      {  name   => "Date with time and subseconds doesn't match",
264                                                         query  => "select c from t where d > '2010-03-15 09:09:09.123456'",
265                                                         advice => [qw()],
266                                                      },
267                                                      {  name   => "Short date",
268                                                         query  => "select c from t where d=73-03-15",
269                                                         advice => [qw(LIT.002)],
270                                                      },
271                                                      {  name   => "Short date with time",
272                                                         query  => "select c from t where d > 73-03-15 09:09:09",
273                                                         advice => [qw(LIT.002)],
274                                                         pos    => [34],
275                                                      },
276                                                      {  name   => "Short date with time and subseconds",
277                                                         query  => "select c from t where d > 73-03-15 09:09:09.123456",
278                                                         advice => [qw(LIT.002)],
279                                                      },
280                                                      {  name   => "Short date with time doesn't match",
281                                                         query  => "select c from t where d > '73-03-15 09:09:09'",
282                                                         advice => [qw()],
283                                                      },
284                                                      {  name   => "Short date with time and subseconds doesn't match",
285                                                         query  => "select c from t where d > '73-03-15 09:09:09.123456'",
286                                                         advice => [qw()],
287                                                      },
288                                                      {  name   => "LIKE without wildcard",
289                                                         query  => "select c from t where i like 'lamp'",
290                                                         advice => [qw(ARG.002)],
291                                                      },
292                                                      {  name   => "LIKE without wildcard, 2nd arg",
293                                                         query  => "select c from t where i like 'lamp%' or like 'foo'",
294                                                         advice => [qw(ARG.002)],
295                                                      },
296                                                      {  name   => "LIKE with wildcard %",
297                                                         query  => "select c from t where i like 'lamp%'",
298                                                         advice => [qw()],
299                                                      },
300                                                      {  name   => "LIKE with wildcard _",
301                                                         query  => "select c from t where i like 'lamp_'",
302                                                         advice => [qw()],
303                                                      },
304                                                      {  name   => "Issue 946: LIT.002 false-positive",
305                                                         query  => "delete from t where d in('MD6500-26', 'MD6500-21-22', 'MD6214')",
306                                                         advice => [qw()],
307                                                      },
308                                                      {  name   => "Issue 946: LIT.002 false-positive",
309                                                         query  => "delete from t where d in('FS-8320-0-2', 'FS-800-6')",
310                                                         advice => [qw()],
311                                                      },
312                                                   # This matches LIT.002 but unless the regex gets really complex or
313                                                   # we do this rule another way, this will have to remain an exception.
314                                                   #   {  name   => "Issue 946: LIT.002 false-positive",
315                                                   #      query  => "select c from t where c='foo 2010-03-17 bar'",
316                                                   #      advice => [qw()],
317                                                   #   },
318                                                   
319                                                      {  name   => "IN(subquer)",
320                                                         query  => "select c from t where i in(select d from z where 1)",
321                                                         advice => [qw(SUB.001)],
322                                                         pos    => [33],
323                                                      },
324                                                      
325                                                   );
326                                                   
327                                                   # Run the test cases.
328            1                                 15   $qar = new QueryAdvisorRules(PodParser => $p);
329            1                                133   $qar->load_rule_info(
330                                                      rules   => [ $qar->get_rules() ],
331                                                      file    => "$trunk/mk-query-advisor/mk-query-advisor",
332                                                      section => 'RULES',
333                                                   );
334                                                   
335            1                                754   my $adv = new Advisor(match_type => "pos");
336            1                                 48   $adv->load_rules($qar);
337            1                                489   $adv->load_rule_info($qar);
338                                                   
339            1                                674   my $sp = new SQLParser();
340                                                   
341            1                                 26   foreach my $test ( @cases ) {
342           47                                293      my $query_struct = $sp->parse($test->{query});
343           47                              29064      my $event = {
344                                                         arg          => $test->{query},
345                                                         query_struct => $query_struct,
346                                                      };
347           47                                277      my ($ids, $pos) = $adv->run_rules(event=>$event);
348           47                                989      is_deeply(
349                                                         $ids,
350                                                         $test->{advice},
351                                                         $test->{name},
352                                                      );
353                                                   
354           47    100                         363      if ( $test->{pos} ) {
355            3                                 21         is_deeply(
356                                                            $pos,
357                                                            $test->{pos},
358                                                            "$test->{name} matched near pos"
359                                                         );
360                                                      }
361                                                   
362                                                      # To help me debug.
363   ***     47     50                         523      die if $test->{stop};
364                                                   }
365                                                   
366                                                   # #############################################################################
367                                                   # Done.
368                                                   # #############################################################################
369            1                                  4   my $output = '';
370                                                   {
371            1                                  2      local *STDERR;
               1                                  8   
372            1                    1             2      open STDERR, '>', \$output;
               1                                320   
               1                                  3   
               1                                  7   
373            1                                 17      $p->_d('Complete test coverage');
374                                                   }
375                                                   like(
376            1                                 15      $output,
377                                                      qr/Complete test coverage/,
378                                                      '_d() works'
379                                                   );
380            1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
4     ***     50      0      1   unless $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}
41    ***     50      0     19   if (not $$rule{'id'} or not $$rule{'code'} or ref $$rule{'code'} ne 'CODE')
354          100      3     44   if ($$test{'pos'})
363   ***     50      0     47   if $$test{'stop'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
4     ***     33      0      0      1   $ENV{'MAATKIT_WORKING_COPY'} and -d $ENV{'MAATKIT_WORKING_COPY'}

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
41    ***     33      0      0     19   not $$rule{'id'} or not $$rule{'code'}
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
BEGIN          1 QueryAdvisorRules.t:19 
BEGIN          1 QueryAdvisorRules.t:372
BEGIN          1 QueryAdvisorRules.t:4  
BEGIN          1 QueryAdvisorRules.t:9  
__ANON__       1 QueryAdvisorRules.t:110
__ANON__       1 QueryAdvisorRules.t:69 

Uncovered Subroutines
---------------------

Subroutine Count Location               
---------- ----- -----------------------
__ANON__       0 QueryAdvisorRules.t:105


