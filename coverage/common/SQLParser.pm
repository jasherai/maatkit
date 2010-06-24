---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/SQLParser.pm   95.1   77.2   81.0   93.1    0.0   93.5   87.3
SQLParser.t                    91.4   50.0   33.3   90.0    n/a    6.5   89.3
Total                          94.1   76.7   75.0   92.3    0.0  100.0   87.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:24 2010
Finish:       Thu Jun 24 19:37:24 2010

Run:          SQLParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:37:26 2010
Finish:       Thu Jun 24 19:37:26 2010

/home/daniel/dev/maatkit/common/SQLParser.pm

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
18                                                    # SQLParser package $Revision: 5945 $
19                                                    # ###########################################################################
20                                                    package SQLParser;
21                                                    
22             1                    1             6   use strict;
               1                                  3   
               1                                 10   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                 11   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  9   
25                                                    
26             1                    1            12   use Data::Dumper;
               1                                  3   
               1                                  6   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 27   
32                                                    
33                                                    # Only these types of statements are parsed.
34                                                    my $allowed_types = qr/(?:
35                                                        DELETE
36                                                       |INSERT
37                                                       |REPLACE
38                                                       |SELECT
39                                                       |UPDATE
40                                                    )/xi;
41                                                    
42                                                    sub new {
43    ***      1                    1      0      5      my ( $class, %args ) = @_;
44             1                                  4      my $self = {
45                                                       };
46             1                                 13      return bless $self, $class;
47                                                    }
48                                                    
49                                                    # Parse the query and return a hashref struct of its parts (keywords,
50                                                    # clauses, subqueries, etc.).  Only queries of $allowed_types are
51                                                    # parsed.  All keys and almost all  vals are lowercase for consistency.
52                                                    # The struct is roughly:
53                                                    # 
54                                                    #   * type       => '',     # one of $allowed_types
55                                                    #   * clauses    => {},     # raw, unparsed text of clauses
56                                                    #   * <clause>   => struct  # parsed clause struct, e.g. from => [<tables>]
57                                                    #   * keywords   => {},     # LOW_PRIORITY, DISTINCT, SQL_CACHE, etc.
58                                                    #   * functions  => {},     # MAX(), SUM(), NOW(), etc.
59                                                    #   * select     => {},     # SELECT struct for INSERT/REPLACE ... SELECT
60                                                    #   * subqueries => [],     # pointers to subquery structs
61                                                    #
62                                                    # It varies, of course, depending on the query.  If something is missing
63                                                    # it means the query doesn't have that part.  E.g. INSERT has an INTO clause
64                                                    # but DELETE does not, and only DELETE and SELECT have FROM clauses.  Each
65                                                    # clause struct is different; see their respective parse_CLAUSE subs.
66                                                    sub parse {
67    ***     33                   33      0    157      my ( $self, $query ) = @_;
68    ***     33     50                         122      return unless $query;
69                                                    
70                                                       # Flatten and clean query.
71            33                                134      $query = $self->clean_query($query);
72                                                    
73                                                       # Remove first word, should be the statement type.  The parse_TYPE subs
74                                                       # expect that this is already removed.
75            33                                 86      my $type;
76    ***     33     50                         173      if ( $query =~ s/^(\w+)\s+// ) {
77            33                                137         $type = lc $1;
78            33                                126         MKDEBUG && _d('Query type:', $type);
79    ***     33     50                         334         if ( $type !~ m/$allowed_types/i ) {
80    ***      0                                  0            return;
81                                                          }
82                                                       }
83                                                       else {
84    ***      0                                  0         MKDEBUG && _d('No first word/type');
85    ***      0                                  0         return;
86                                                       }
87                                                    
88                                                       # If query has any subqueries, remove/save them and replace them.
89                                                       # They'll be parsed later, after the main outer query.
90            33                                 79      my @subqueries;
91            33    100                         135      if ( $query =~ m/(\(SELECT )/i ) {
92             2                                  5         MKDEBUG && _d('Removing subqueries');
93             2                                 11         @subqueries = $self->remove_subqueries($query);
94             2                                  8         $query      = shift @subqueries;
95                                                       }
96                                                    
97                                                       # Parse raw text parts from query.  The parse_TYPE subs only do half
98                                                       # the work: parsing raw text parts of clauses, tables, functions, etc.
99                                                       # Since these parts are invariant (e.g. a LIMIT clause is same for any
100                                                      # type of SQL statement) they are parsed later via other parse_CLAUSE
101                                                      # subs, instead of parsing them individually in each parse_TYPE sub.
102           33                                106      my $parse_func = "parse_$type";
103           33                                153      my $struct     = $self->$parse_func($query);
104   ***     33     50                         133      if ( !$struct ) {
105   ***      0                                  0         MKDEBUG && _d($parse_func, 'failed to parse query');
106   ***      0                                  0         return;
107                                                      }
108           33                                109      $struct->{type} = $type;
109           33                                136      $self->_parse_clauses($struct);
110                                                      # TODO: parse functions
111                                                   
112           33    100                         127      if ( @subqueries ) {
113            2                                  6         MKDEBUG && _d('Parsing subqueries');
114            2                                  8         foreach my $subquery ( @subqueries ) {
115            5                                 26            my $subquery_struct = $self->parse($subquery->{query});
116            5                                 31            @{$subquery_struct}{keys %$subquery} = values %$subquery;
               5                                 34   
117            5                                 13            push @{$struct->{subqueries}}, $subquery_struct;
               5                                 26   
118                                                         }
119                                                      }
120                                                   
121           33                                 68      MKDEBUG && _d('Query struct:', Dumper($struct));
122           33                                141      return $struct;
123                                                   }
124                                                   
125                                                   sub _parse_clauses {
126           34                   34           122      my ( $self, $struct ) = @_;
127                                                      # Parse raw text of clauses and functions.
128           34                                 95      foreach my $clause ( keys %{$struct->{clauses}} ) {
              34                                199   
129                                                         # Rename/remove clauses with space in their names, like ORDER BY.
130           92    100                         415         if ( $clause =~ m/ / ) {
131            7                                 40            (my $clause_no_space = $clause) =~ s/ /_/g;
132            7                                 38            $struct->{clauses}->{$clause_no_space} = $struct->{clauses}->{$clause};
133            7                                 29            delete $struct->{clauses}->{$clause};
134            7                                 22            $clause = $clause_no_space;
135                                                         }
136                                                   
137           92                                296         my $parse_func     = "parse_$clause";
138           92                                493         $struct->{$clause} = $self->$parse_func($struct->{clauses}->{$clause});
139                                                   
140           92    100                         414         if ( $clause eq 'select' ) {
141            1                                  3            MKDEBUG && _d('Parsing subquery clauses');
142            1                                  7            $self->_parse_clauses($struct->{select});
143                                                         }
144                                                      }
145           34                                111      return;
146                                                   }
147                                                   
148                                                   sub clean_query {
149   ***     50                   50      0    228      my ( $self, $query ) = @_;
150   ***     50     50                         207      return unless $query;
151                                                   
152                                                      # Whitespace and comments.
153           50                                169      $query =~ s/^\s*--.*$//gm;  # -- comments
154           50                                379      $query =~ s/\s+/ /g;        # extra spaces/flatten
155           50                                167      $query =~ s!/\*.*?\*/!!g;   # /* comments */
156           50                                159      $query =~ s/^\s+//;         # leading spaces
157           50                                254      $query =~ s/\s+$//;         # trailing spaces
158                                                   
159                                                      # Add spaces between important tokens to help the parse_* subs.
160           50                                378      $query =~ s/\b(VALUE(?:S)?)\(/$1 (/i;
161           50                                342      $query =~ s/\bON\(/on (/gi;
162           50                                322      $query =~ s/\bUSING\(/using (/gi;
163                                                   
164                                                      # Start of (SELECT subquery).
165           50                                178      $query =~ s/\(\s+SELECT\s+/(SELECT /gi;
166                                                   
167           50                                242      return $query;
168                                                   }
169                                                   
170                                                   # This sub is called by the parse_TYPE subs except parse_insert.
171                                                   # It does two things: remove, save the given keywords, all of which
172                                                   # should appear at the beginning of the query; and, save (but not
173                                                   # remove) the given clauses.  The query should start with the values
174                                                   # for the first clause because the query's first word was removed
175                                                   # in parse().  So for "SELECT cols FROM ...", the query given here
176                                                   # is "cols FROM ..." where "cols" belongs to the first clause "columns".
177                                                   # Then the query is walked clause-by-clause, saving each.
178                                                   sub _parse_query {
179           23                   23           129      my ( $self, $query, $keywords, $first_clause, $clauses ) = @_;
180   ***     23     50                          94      return unless $query;
181           23                                 68      my $struct = {};
182                                                   
183                                                      # Save, remove keywords.
184           23                                351      1 while $query =~ s/$keywords\s+/$struct->{keywords}->{lc $1}=1, ''/gie;
               3                                 33   
185                                                   
186                                                      # Go clausing.
187           23                                407      my @clause = grep { defined $_ }
             130                                444   
188                                                         ($query =~ m/\G(.+?)(?:$clauses\s+|\Z)/gci);
189                                                   
190           23                                116      my $clause = $first_clause,
191                                                      my $value  = shift @clause;
192           23                                130      $struct->{clauses}->{$clause} = $value;
193           23                                 50      MKDEBUG && _d('Clause:', $clause, $value);
194                                                   
195                                                      # All other clauses.
196           23                                 95      while ( @clause ) {
197           42                                119         $clause = shift @clause;
198           42                                114         $value  = shift @clause;
199           42                                170         $struct->{clauses}->{lc $clause} = $value;
200           42                                153         MKDEBUG && _d('Clause:', $clause, $value);
201                                                      }
202                                                   
203           23                                112      ($struct->{unknown}) = ($query =~ m/\G(.+)/);
204                                                   
205           23                                129      return $struct;
206                                                   }
207                                                   
208                                                   sub parse_delete {
209   ***      7                    7      0     31      my ( $self, $query ) = @_;
210   ***      7     50                          38      if ( $query =~ s/FROM\s+//i ) {
211            7                                 38         my $keywords = qr/(LOW_PRIORITY|QUICK|IGNORE)/i;
212            7                                 25         my $clauses  = qr/(FROM|WHERE|ORDER BY|LIMIT)/i;
213            7                                 31         return $self->_parse_query($query, $keywords, 'from', $clauses);
214                                                      }
215                                                      else {
216   ***      0                                  0         die "DELETE without FROM: $query";
217                                                      }
218                                                   }
219                                                   
220                                                   sub parse_insert {
221   ***     11                   11      0     53      my ( $self, $query ) = @_;
222   ***     11     50                          47      return unless $query;
223           11                                 33      my $struct = {};
224                                                   
225                                                      # Save, remove keywords.
226           11                                 53      my $keywords   = qr/(LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)/i;
227           11                                138      1 while $query =~ s/$keywords\s+/$struct->{keywords}->{lc $1}=1, ''/gie;
      ***      0                                  0   
228                                                   
229                                                      # Parse INTO clause.  Literal "INTO" is optional.
230   ***     11     50                         409      if ( my @into = ($query =~ m/
231                                                               (?:INTO\s+)?            # INTO, optional
232                                                               (.+?)\s+                # table ref
233                                                               (\([^\)]+\)\s+)?        # column list, optional
234                                                               (VALUE.?|SET|SELECT)\s+ # start of next caluse
235                                                            /xgci)
236                                                      ) {
237           11                                 36         my $tbl  = shift @into;  # table ref
238           11                                 56         $struct->{clauses}->{into} = $tbl;
239           11                                 22         MKDEBUG && _d('Clause: into', $tbl);
240                                                   
241           11                                 31         my $cols = shift @into;  # columns, maybe
242           11    100                          37         if ( $cols ) {
243            4                                 20            $cols =~ s/[\(\)]//g;
244            4                                 18            $struct->{clauses}->{columns} = $cols;
245            4                                 10            MKDEBUG && _d('Clause: columns', $cols);
246                                                         }
247                                                   
248           11                                 34         my $next_clause = lc(shift @into);  # VALUES, SET or SELECT
249   ***     11     50                          41         die "INSERT/REPLACE without clause after table: $query"
250                                                            unless $next_clause;
251           11    100                          43         $next_clause = 'values' if $next_clause eq 'value';
252           11                                 88         my ($values, $on) = ($query =~ m/\G(.+?)(ON|\Z)/gci);
253   ***     11     50                          50         die "INSERT/REPLACE without values: $query" unless $values;
254           11                                 46         $struct->{clauses}->{$next_clause} = $values;
255           11                                 25         MKDEBUG && _d('Clause:', $next_clause, $values);
256                                                   
257           11    100                          42         if ( $on ) {
258            2                                 11            ($values) = ($query =~ m/ON DUPLICATE KEY UPDATE (.+)/i);
259   ***      2     50                           9            die "No values after ON DUPLICATE KEY UPDATE: $query" unless $values;
260            2                                  8            $struct->{clauses}->{on_duplicate} = $values;
261            2                                  6            MKDEBUG && _d('Clause: on duplicate key update', $values);
262                                                         }
263                                                      }
264                                                   
265                                                      # Save any leftovers.  If there are any, parsing missed something.
266           11                                 54      ($struct->{unknown}) = ($query =~ m/\G(.+)/);
267                                                   
268           11                                 68      return $struct;
269                                                   }
270                                                   {
271                                                      # Suppress warnings like "Name "SQLParser::parse_set" used only once:
272                                                      # possible typo at SQLParser.pm line 480." caused by the fact that we
273                                                      # don't call these aliases directly, they're called indirectly using
274                                                      # $parse_func, hence Perl can't see their being called a compile time.
275            1                    1             8      no warnings;
               1                                  2   
               1                                  8   
276                                                      # INSERT and REPLACE are so similar that they are both parsed
277                                                      # in parse_insert().
278                                                      *parse_replace = \&parse_insert;
279                                                   }
280                                                   
281                                                   sub parse_select {
282   ***     14                   14      0     63      my ( $self, $query ) = @_;
283                                                   
284                                                      # Keywords are expected to be at the start of the query, so these
285                                                      # that appear at the end are handled separately.  Afaik, SELECT is
286                                                      # only statement with optional keywords at the end.  Also, these
287                                                      # appear to be the only keywords with spaces instead of _.
288           14                                 41      my @keywords;
289           14                                 69      my $final_keywords = qr/(FOR UPDATE|LOCK IN SHARE MODE)/i; 
290           14                                168      1 while $query =~ s/\s+$final_keywords/(push @keywords, $1), ''/gie;
               1                                 13   
291                                                   
292           14                                 60      my $keywords = qr/(
293                                                          ALL
294                                                         |DISTINCT
295                                                         |DISTINCTROW
296                                                         |HIGH_PRIORITY
297                                                         |STRAIGHT_JOIN
298                                                         |SQL_SMALL_RESULT
299                                                         |SQL_BIG_RESULT
300                                                         |SQL_BUFFER_RESULT
301                                                         |SQL_CACHE
302                                                         |SQL_NO_CACHE
303                                                         |SQL_CALC_FOUND_ROWS
304                                                      )/xi;
305           14                                 43      my $clauses = qr/(
306                                                          FROM
307                                                         |WHERE
308                                                         |GROUP\sBY
309                                                         |HAVING
310                                                         |ORDER\sBY
311                                                         |LIMIT
312                                                         |PROCEDURE
313                                                         |INTO OUTFILE
314                                                      )/xi;
315           14                                 64      my $struct = $self->_parse_query($query, $keywords, 'columns', $clauses);
316                                                   
317                                                      # Add final keywords, if any.
318           14                                 43      map { s/ /_/g; $struct->{keywords}->{lc $_} = 1; } @keywords;
               1                                  6   
               1                                  6   
319                                                   
320           14                                 90      return $struct;
321                                                   }
322                                                   
323                                                   sub parse_update {
324   ***      2                    2      0     12      my $keywords = qr/(LOW_PRIORITY|IGNORE)/i;
325            2                                  8      my $clauses  = qr/(SET|WHERE|ORDER BY|LIMIT)/i;
326            2                                 10      return _parse_query(@_, $keywords, 'tables', $clauses);
327                                                   
328                                                   }
329                                                   
330                                                   # Parse a FROM clause, a.k.a. the table references.  Returns an arrayref
331                                                   # of hashrefs, one hashref for each table.  Each hashref is like:
332                                                   #
333                                                   #   {
334                                                   #     name           => 't2',  -- this table's real name
335                                                   #     alias          => 'b',   -- table's alias, if any
336                                                   #     explicit_alias => 1,     -- if explicitly aliased with AS
337                                                   #     join  => {               -- if joined to another table, all but first
338                                                   #                              -- table are because comma implies INNER JOIN
339                                                   #       to         => 't1',    -- table name on left side of join  
340                                                   #       type       => '',      -- right, right, inner, outer, cross, natural
341                                                   #       condition  => 'using', -- on or using, if applicable
342                                                   #       predicates => '(id) ', -- stuff after on or using, if applicable
343                                                   #       ansi       => 1,       -- true of ANSI JOIN, i.e. true if not implicit
344                                                   #     },                       -- INNER JOIN due to follow a comma
345                                                   #   },
346                                                   #
347                                                   # Tables are listed in the order that they appear.  Currently, subqueries
348                                                   # and nested joins are not handled.
349                                                   sub parse_from {
350   ***     49                   49      0    186      my ( $self, $from ) = @_;
351   ***     49     50                         187      return unless $from;
352           49                                111      MKDEBUG && _d('FROM clause:', $from);
353                                                   
354                                                      # This method tokenize the FROM clause into "things".  Each thing
355                                                      # is one of either a:
356                                                      #   * table ref, including alias
357                                                      #   * JOIN syntax word
358                                                      #   * ON or USING (condition)
359                                                      #   * ON|USING predicates text
360                                                      # So it is not word-by-word; it's thing-by-thing in one pass.
361                                                      # Currently, the ON|USING predicates are not parsed further.
362                                                   
363           49                                116      my @tbls;  # All parsed tables.
364           49                                103      my $tbl;   # This gets pushed to @tbls when it's set.  It may not be
365                                                                 # all the time if, for example, $pending_tbl is being built.
366                                                   
367                                                      # These vars are used when parsing an explicit/ANSI JOIN statement.
368           49                                106      my $pending_tbl;         
369           49                                132      my $state      = undef;  
370           49                                128      my $join       = '';  # JOIN syntax words, without JOIN; becomes type
371           49                                121      my $joinno     = 0;   # join number for debugging
372           49                                118      my $redo       = 0;   # save $pending_tbl, redo loop for new JOIN
373                                                   
374                                                      # These vars help detect "comma joins", e.g. "tbl1, tbl2", which are
375                                                      # treated by MySQL as implicit INNER JOIN.  See below.
376           49                                118      my $join_back  = 0;
377           49                                133      my $last_thing = '';
378                                                   
379           49                                234      my $join_delim
380                                                         = qr/,|INNER|CROSS|STRAIGHT_JOIN|LEFT|RIGHT|OUTER|NATURAL|JOIN|ON|USING/i;
381           49                                174      my $next_tbl
382                                                         = qr/,|INNER|CROSS|STRAIGHT_JOIN|LEFT|RIGHT|OUTER|NATURAL|JOIN/i;
383                                                   
384           49                                535      foreach my $thing ( split(/\s*($join_delim)\s+/io, $from) ) {
385          128    100                         437         next unless $thing;
386          121                                252         MKDEBUG && _d('Table thing:', $thing, 'state:', $state); 
387                                                   
388          121    100    100                 1076         if ( !$state && $thing !~ m/$join_delim/i ) {
389           55                                117            MKDEBUG && _d('Table factor');
390           55                                216            $tbl = { $self->parse_identifier($thing) };
391                                                            
392                                                            # Non-ANSI implicit INNER join to previous table, e.g. "tbl1, tbl2".
393                                                            # Manual says: "INNER JOIN and , (comma) are semantically equivalent
394                                                            # in the absence of a join condition".
395           55    100    100                  463            $join_back = 1 if ($last_thing || '') eq ',';
396                                                         }
397                                                         else {
398                                                            # Should be starting or continuing an explicit JOIN.
399           66    100                         274            if ( !$state ) {
                    100                               
      ***            50                               
400           26                                 64               $joinno++;
401           26                                 52               MKDEBUG && _d('JOIN', $joinno, 'start');
402           26                                 87               $join .= ' ' . lc $thing;
403           26    100                         107               if ( $join =~ m/join$/ ) {
404           13                                 52                  $join =~ s/ join$//;
405           13                                 39                  $join =~ s/^\s+//;
406           13                                 28                  MKDEBUG && _d('JOIN', $joinno, 'type:', $join);
407           13                                 42                  my $last_tbl = $tbls[-1];
408   ***     13     50                          45                  die "Invalid syntax: $from\n"
409                                                                     . "JOIN without preceding table reference" unless $last_tbl;
410           13                                 88                  $pending_tbl->{join} = {
411                                                                     to   => $last_tbl->{name},
412                                                                     type => $join,
413                                                                     ansi => 1,
414                                                                  };
415           13                                 36                  $join    = '';
416           13                                 41                  $state   = 'join tbl';
417                                                               }
418                                                            }
419                                                            elsif ( $state eq 'join tbl' ) {
420                                                               # Table for this join (i.e. tbl to right of JOIN).
421           13                                 49               my %tbl_ref = $self->parse_identifier($thing);
422           13                                 62               @{$pending_tbl}{keys %tbl_ref} = values %tbl_ref;
              13                                 52   
423           13                                 46               $state = 'join condition';
424                                                            }
425                                                            elsif ( $state eq 'join condition' ) {
426           27    100                         206               if ( $thing =~ m/$next_tbl/io ) {
                    100                               
427            3                                  6                  MKDEBUG && _d('JOIN', $joinno, 'end');
428            3                                  9                  $tbl  = $pending_tbl;
429            3                                  9                  $redo = 1;  # save $pending_tbl then redo this new JOIN
430                                                               }
431                                                               elsif ( $thing =~ m/ON|USING/i ) {
432           12                                 27                  MKDEBUG && _d('JOIN', $joinno, 'codition');
433           12                                 60                  $pending_tbl->{join}->{condition} = lc $thing;
434                                                               }
435                                                               else {
436           12                                 25                  MKDEBUG && _d('JOIN', $joinno, 'predicate');
437           12                                 63                  $pending_tbl->{join}->{predicates} .= "$thing ";
438                                                               }
439                                                            }
440                                                            else {
441   ***      0                                  0               die "Unknown state '$state' parsing JOIN syntax: $from";
442                                                            }
443                                                         }
444                                                   
445          121                                316         $last_thing = $thing;
446                                                   
447          121    100                         372         if ( $tbl ) {
448           58    100                         198            if ( $join_back ) {
449            6                                 18               my $prev_tbl = $tbls[-1];
450   ***      6     50                          26               if ( $tbl->{join} ) {
451   ***      0                                  0                  die "Cannot implicitly join $tbl->{name} to $prev_tbl->{name} "
452                                                                     . "because it is already joined to $tbl->{join}->{to}";
453                                                               }
454            6                                 40               $tbl->{join} = {
455                                                                  to   => $prev_tbl->{name},
456                                                                  type => 'inner',
457                                                                  ansi => 0,
458                                                               }
459                                                            }
460           58                                179            push @tbls, $tbl;
461           58                                146            $tbl         = undef;
462           58                                140            $state       = undef;
463           58                                136            $pending_tbl = undef;
464           58                                150            $join        = '';
465           58                                155            $join_back   = 0;
466                                                         }
467                                                         else {
468           63                                135            MKDEBUG && _d('Table pending:', Dumper($pending_tbl));
469                                                         }
470          121    100                         508         if ( $redo ) {
471            3                                  6            MKDEBUG && _d("Redoing this thing");
472            3                                  8            $redo = 0;
473            3                                  9            redo;
474                                                         }
475                                                      }
476                                                   
477                                                      # Save the final JOIN which was end by the end of the FROM clause
478                                                      # rather than by the start of a new JOIN.
479           49    100                         190      if ( $pending_tbl ) {
480           10                                 33         push @tbls, $pending_tbl;
481                                                      }
482                                                   
483           49                                100      MKDEBUG && _d('Parsed tables:', Dumper(\@tbls));
484           49                                347      return \@tbls;
485                                                   }
486                                                   
487                                                   # Parse a table ref like "tbl", "tbl alias" or "tbl AS alias", where
488                                                   # tbl can be optionally "db." qualified.  Also handles FORCE|USE|IGNORE
489                                                   # INDEX hints.  Does not handle "FOR JOIN" hint because "JOIN" here gets
490                                                   # confused with the "JOIN" thing in parse_from().
491                                                   sub parse_identifier {
492   ***    108                  108      0    417      my ( $self, $tbl_ref ) = @_;
493          108                                266      my %tbl;
494          108                                228      MKDEBUG && _d('Identifier string:', $tbl_ref);
495                                                   
496                                                      # First, check for an index hint.  Remove and save it if present.
497          108                                236      my $index_hint;
498          108    100                         461      if ( $tbl_ref =~ s/
499                                                            \s+(
500                                                               (?:FORCE|USE|INGORE)\s
501                                                               (?:INDEX|KEY)
502                                                               \s*\([^\)]+\)\s*
503                                                            )//xi)
504                                                      {
505            5                                 10         MKDEBUG && _d('Index hint:', $1);
506            5                                 27         $tbl{index_hint} = $1;
507                                                      }
508                                                   
509          108                                447      my $tbl_ident = qr/
510                                                         (?:`[^`]+`|[\w*]+)       # `something`, or something
511                                                         (?:                      # optionally followed by either
512                                                            \.(?:`[^`]+`|[\w*]+)  #   .`something` or .something, or
513                                                            |\([^\)]*\)           #   (function stuff)  (e.g. NOW())
514                                                         )?             
515                                                      /x;
516                                                   
517   ***    108     50                        1024      my @words = map { s/`//g if defined; $_; } $tbl_ref =~ m/($tbl_ident)/g;
             162                                693   
             162                                655   
518                                                      # tbl ref:  tbl AS foo
519                                                      # words:      0  1   2
520          108                                290      MKDEBUG && _d('Identifier words:', @words);
521                                                   
522                                                      # Real table name with optional db. qualifier.
523          108                                659      my ($db, $tbl) = $words[0] =~ m/(?:(.+?)\.)?(.+)$/;
524          108    100                         433      $tbl{db}   = $db if $db;
525          108                                350      $tbl{name} = $tbl;
526                                                   
527                                                      # Alias.
528          108    100                         470      if ( $words[2] ) {
                    100                               
529   ***     18     50     50                  114         die "Bad identifier: $tbl_ref" unless ($words[1] || '') =~ m/AS/i;
530           18                                 58         $tbl{alias}          = $words[2];
531           18                                 59         $tbl{explicit_alias} = 1;
532                                                      }
533                                                      elsif ( $words[1] ) {
534           18                                 63         $tbl{alias} = $words[1];
535                                                      }
536                                                   
537          108                                947      return %tbl;
538                                                   }
539                                                   {
540            1                    1             8      no warnings;  # Why? See same line above.
               1                                  2   
               1                                  5   
541                                                      *parse_into   = \&parse_from;
542                                                      *parse_tables = \&parse_from;
543                                                   }
544                                                   
545                                                   # For now this just chops a WHERE clause into its predicates.
546                                                   # We do not handled nested conditions, operator precedence, etc.
547                                                   # Predicates are separated by either AND or OR.  Since either
548                                                   # of those words can appear in an argval (e.g. c="me or him")
549                                                   # and AND is used with BETWEEN, we have to parse carefully.
550                                                   sub parse_where {
551   ***     14                   14      0     58      my ( $self, $where ) = @_;
552           14                                 57      return $where;
553                                                   }
554                                                   
555                                                   sub parse_having {
556   ***      0                    0      0      0      my ( $self, $having ) = @_;
557                                                      # TODO
558   ***      0                                  0      return $having;
559                                                   }
560                                                   
561                                                   # [ORDER BY {col_name | expr | position} [ASC | DESC], ...]
562                                                   sub parse_order_by {
563   ***     11                   11      0     51      my ( $self, $order_by ) = @_;
564   ***     11     50                          43      return unless $order_by;
565           11                                 24      MKDEBUG && _d('Parse ORDER BY', $order_by);
566                                                      # They don't have to be cols, they can be expressions or positions;
567                                                      # we call them all cols for simplicity.
568           11                                 51      my @cols = map { s/^\s+//; s/\s+$//; $_ } split(',', $order_by);
              13                                 51   
              13                                 55   
              13                                 57   
569           11                                 72      return \@cols;
570                                                   }
571                                                   
572                                                   # [LIMIT {[offset,] row_count | row_count OFFSET offset}]
573                                                   sub parse_limit {
574   ***      9                    9      0     44      my ( $self, $limit ) = @_;
575   ***      9     50                          39      return unless $limit;
576            9                                 38      my $struct = {
577                                                         row_count => undef,
578                                                      };
579            9    100                          40      if ( $limit =~ m/(\S+)\s+OFFSET\s+(\S+)/i ) {
580            2                                 17         $struct->{explicit_offset} = 1;
581            2                                 13         $struct->{row_count}       = $1;
582            2                                  9         $struct->{offset}          = $2;
583                                                      }
584                                                      else {
585            7                                 49         my ($offset, $cnt) = $limit =~ m/(?:(\S+),\s+)?(\S+)/i;
586            7                                 26         $struct->{row_count} = $cnt;
587            7    100                          37         $struct->{offset}    = $offset if defined $offset;
588                                                      }
589            9                                 44      return $struct;
590                                                   }
591                                                   
592                                                   # Parses the list of values after, e.g., INSERT tbl VALUES (...), (...).
593                                                   # Does not currently parse each set of values; it just splits the list.
594                                                   sub parse_values {
595   ***      8                    8      0     32      my ( $self, $values ) = @_;
596   ***      8     50                          32      return unless $values;
597                                                      # split(',', $values) will not work (without some kind of regex
598                                                      # look-around assertion) because there are commas inside the sets
599                                                      # of values.
600            8                                 55      my @vals = ($values =~ m/\([^\)]+\)/g);
601            8                                 36      return \@vals;
602                                                   }
603                                                   
604                                                   # Split any comma-separated list of values, removing leading
605                                                   # and trailing spaces.
606                                                   sub parse_csv {
607   ***     26                   26      0    101      my ( $self, $vals ) = @_;
608   ***     26     50                          95      return unless $vals;
609           26                                109      my @vals = map { s/^\s+//; s/\s+$//; $_ } split(',', $vals);
              35                                116   
              35                                119   
              35                                142   
610           26                                129      return \@vals;
611                                                   }
612                                                   {
613            1                    1             6      no warnings;  # Why? See same line above.
               1                                  3   
               1                                  4   
614                                                      *parse_set          = \&parse_csv;
615                                                      *parse_on_duplicate = \&parse_csv;
616                                                   }
617                                                   
618                                                   sub parse_columns {
619   ***     18                   18      0     75      my ( $self, $cols ) = @_;
620           25                                106      my @cols = map {
621           18                                 70         my %ref = $self->parse_identifier($_);
622           25                                113         \%ref;
623           18                                 52      } @{ $self->parse_csv($cols) };
624           18                                 90      return \@cols;
625                                                   }
626                                                   
627                                                   # GROUP BY {col_name | expr | position} [ASC | DESC], ... [WITH ROLLUP]
628                                                   sub parse_group_by {
629   ***      2                    2      0      9      my ( $self, $group_by ) = @_;
630            2                                  8      my $with_rollup = $group_by =~ s/\s+WITH ROLLUP\s*//i;
631            2                                  8      my $struct = {
632                                                         columns => $self->parse_csv($group_by),
633                                                      };
634   ***      2     50                           8      $struct->{with_rollup} = 1 if $with_rollup;
635            2                                  9      return $struct;
636                                                   }
637                                                   
638                                                   # Remove subqueries from query, return modified query and list of subqueries.
639                                                   # Each subquery is replaced with the special token __SQn__ where n is the
640                                                   # subquery's ID.  Subqueries are parsed and removed in to out, last to first;
641                                                   # i.e. the last, inner-most subquery is ID 0 and the first, outermost
642                                                   # subquery has the greatest ID.  Each subquery ID corresponds to its index in
643                                                   # the list of returned subquery hashrefs after the modified query.  __SQ2__
644                                                   # is subqueries[2].  Each hashref is like:
645                                                   #   * query    Subquery text
646                                                   #   * context  scalar, list or identifier
647                                                   #   * nested   (optional) 1 if nested
648                                                   # This sub does not handle UNION and it expects to that subqueries start
649                                                   # with "(SELECT ".  See SQLParser.t for examples.
650                                                   sub remove_subqueries {
651   ***      9                    9      0     43      my ( $self, $query ) = @_;
652                                                   
653                                                      # Find starting pos of all subqueries.
654            9                                 26      my @start_pos;
655            9                                 54      while ( $query =~ m/(\(SELECT )/gi ) {
656           20                                 82         my $pos = (pos $query) - (length $1);
657           20                                102         push @start_pos, $pos;
658                                                      }
659                                                   
660                                                      # Starting with the inner-most, last subquery, find ending pos of
661                                                      # all subqueries.  This is done by counting open and close parentheses
662                                                      # until all are closed.  The last closing ) should close the ( that
663                                                      # opened the subquery.  No sane regex can help us here for cases like:
664                                                      # (select max(id) from t where col in(1,2,3) and foo='(bar)').
665            9                                 33      @start_pos = reverse @start_pos;
666            9                                 21      my @end_pos;
667            9                                 61      for my $i ( 0..$#start_pos ) {
668           20                                 55         my $closed = 0;
669           20                                 74         pos $query = $start_pos[$i];
670           20                                 91         while ( $query =~ m/([\(\)])/cg ) {
671           82                                235            my $c = $1;
672           82    100                         308            $closed += ($c eq '(' ? 1 : -1);
673           82    100                         392            last unless $closed;
674                                                         }
675           20                                 78         push @end_pos, pos $query;
676                                                      }
677                                                   
678                                                      # Replace each subquery with a __SQn__ token.
679            9                                 25      my @subqueries;
680            9                                 24      my $len_adj = 0;
681            9                                 24      my $n    = 0;
682            9                                 36      for my $i ( 0..$#start_pos ) {
683           20                                 47         MKDEBUG && _d('Query:', $query);
684           20                                 56         my $offset = $start_pos[$i];
685           20                                 78         my $len    = $end_pos[$i] - $start_pos[$i] - $len_adj;
686           20                                 40         MKDEBUG && _d("Subquery $n start", $start_pos[$i],
687                                                               'orig end', $end_pos[$i], 'adj', $len_adj, 'adj end',
688                                                               $offset + $len, 'len', $len);
689                                                   
690           20                                 60         my $struct   = {};
691           20                                 77         my $token    = '__SQ' . $n . '__';
692           20                                 84         my $subquery = substr($query, $offset, $len, $token);
693           20                                 42         MKDEBUG && _d("Subquery $n:", $subquery);
694                                                   
695                                                         # Adjust len for next outer subquery.  This is required because the
696                                                         # subqueries' start/end pos are found relative to one another, so
697                                                         # when a subquery is replaced with its shorter __SQn__ token the end
698                                                         # pos for the other subqueries decreases.  The token is shorter than
699                                                         # any valid subquery so the end pos should only decrease.
700           20                                 66         my $outer_start = $start_pos[$i + 1];
701           20                                 60         my $outer_end   = $end_pos[$i + 1];
702   ***     20    100     66                  240         if (    $outer_start && ($outer_start < $start_pos[$i])
      ***                   66                        
                           100                        
703                                                              && $outer_end   && ($outer_end   > $end_pos[$i]) ) {
704            7                                 17            MKDEBUG && _d("Subquery $n nested in next subquery");
705            7                                 23            $len_adj += $len - length $token;
706            7                                 30            $struct->{nested} = $i + 1;
707                                                         }
708                                                         else {
709           13                                 30            MKDEBUG && _d("Subquery $n not nested");
710           13                                 36            $len_adj = 0;
711           13    100    100                  102            if ( $subqueries[-1] && $subqueries[-1]->{nested} ) {
712            4                                 10               MKDEBUG && _d("Outermost subquery");
713                                                            }
714                                                         }
715                                                   
716                                                         # Get subquery context: scalar, list or identifier.
717           20    100                        1058         if ( $query =~ m/(?:=|>|<|>=|<=|<>|!=|<=>)\s*$token/ ) {
                    100                               
718            5                                 22            $struct->{context} = 'scalar';
719                                                         }
720                                                         elsif ( $query =~ m/\b(?:IN|ANY|SOME|ALL|EXISTS)\s*$token/i ) {
721                                                            # Add ( ) around __SQn__ for things like "IN(__SQn__)"
722                                                            # unless they're already there.
723   ***      9     50                         113            if ( $query !~ m/\($token\)/ ) {
724            9                                109               $query =~ s/$token/\($token\)/;
725            9    100                          43               $len_adj -= 2 if $struct->{nested};
726                                                            }
727            9                                 39            $struct->{context} = 'list';
728                                                         }
729                                                         else {
730                                                            # If the subquery is not preceded by an operator (=, >, etc.)
731                                                            # or IN(), EXISTS(), etc. then it should be an indentifier,
732                                                            # either a derived table or column.
733            6                                 27            $struct->{context} = 'identifier';
734                                                         }
735           20                                 47         MKDEBUG && _d("Subquery $n context:", $struct->{context});
736                                                   
737                                                         # Remove ( ) around subquery so it can be parsed by a parse_TYPE sub.
738           20                                 90         $subquery =~ s/^\s*\(//;
739           20                                109         $subquery =~ s/\s*\)\s*$//;
740                                                   
741                                                         # Save subquery to struct after modifications above.
742           20                                 73         $struct->{query} = $subquery;
743           20                                 59         push @subqueries, $struct;
744           20                                 77         $n++;
745                                                      }
746                                                   
747            9                                 86      return $query, @subqueries;
748                                                   }
749                                                   
750                                                   sub _d {
751   ***      0                    0                    my ($package, undef, $line) = caller 0;
752   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
753   ***      0                                              map { defined $_ ? $_ : 'undef' }
754                                                           @_;
755   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
756                                                   }
757                                                   
758                                                   1;
759                                                   
760                                                   # ###########################################################################
761                                                   # End SQLParser package
762                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
68    ***     50      0     33   unless $query
76    ***     50     33      0   if ($query =~ s/^(\w+)\s+//) { }
79    ***     50      0     33   if (not $type =~ /$allowed_types/i)
91           100      2     31   if ($query =~ /(\(SELECT )/i)
104   ***     50      0     33   if (not $struct)
112          100      2     31   if (@subqueries)
130          100      7     85   if ($clause =~ / /)
140          100      1     91   if ($clause eq 'select')
150   ***     50      0     50   unless $query
180   ***     50      0     23   unless $query
210   ***     50      7      0   if ($query =~ s/FROM\s+//i) { }
222   ***     50      0     11   unless $query
230   ***     50     11      0   if (my(@into) = $query =~ /
            (?:INTO\s+)?            # INTO, optional
            (.+?)\s+                # table ref
            (\([^\)]+\)\s+)?        # column list, optional
            (VALUE.?|SET|SELECT)\s+ # start of next caluse
         /cgix)
242          100      4      7   if ($cols)
249   ***     50      0     11   unless $next_clause
251          100      5      6   if $next_clause eq 'value'
253   ***     50      0     11   unless $values
257          100      2      9   if ($on)
259   ***     50      0      2   unless $values
351   ***     50      0     49   unless $from
385          100      7    121   unless $thing
388          100     55     66   if (not $state and not $thing =~ /$join_delim/i) { }
395          100      6     49   if ($last_thing || '') eq ','
399          100     26     40   if (not $state) { }
             100     13     27   elsif ($state eq 'join tbl') { }
      ***     50     27      0   elsif ($state eq 'join condition') { }
403          100     13     13   if ($join =~ /join$/)
408   ***     50      0     13   unless $last_tbl
426          100      3     24   if ($thing =~ /$next_tbl/io) { }
             100     12     12   elsif ($thing =~ /ON|USING/i) { }
447          100     58     63   if ($tbl) { }
448          100      6     52   if ($join_back)
450   ***     50      0      6   if ($$tbl{'join'})
470          100      3    118   if ($redo)
479          100     10     39   if ($pending_tbl)
498          100      5    103   if ($tbl_ref =~ s/
         \s+(
            (?:FORCE|USE|INGORE)\s
            (?:INDEX|KEY)
            \s*\([^\)]+\)\s*
         )//xi)
517   ***     50    162      0   if defined $_
524          100     14     94   if $db
528          100     18     90   if ($words[2]) { }
             100     18     72   elsif ($words[1]) { }
529   ***     50      0     18   unless ($words[1] || '') =~ /AS/i
564   ***     50      0     11   unless $order_by
575   ***     50      0      9   unless $limit
579          100      2      7   if ($limit =~ /(\S+)\s+OFFSET\s+(\S+)/i) { }
587          100      2      5   if defined $offset
596   ***     50      0      8   unless $values
608   ***     50      0     26   unless $vals
634   ***     50      0      2   if $with_rollup
672          100     41     41   $c eq '(' ? :
673          100     20     62   unless $closed
702          100      7     13   if ($outer_start and $outer_start < $start_pos[$i] and $outer_end and $outer_end > $end_pos[$i]) { }
711          100      4      9   if ($subqueries[-1] and $subqueries[-1]{'nested'})
717          100      5     15   if ($query =~ /(?:=|>|<|>=|<=|<>|!=|<=>)\s*$token/) { }
             100      9      6   elsif ($query =~ /\b(?:IN|ANY|SOME|ALL|EXISTS)\s*$token/i) { }
723   ***     50      9      0   if (not $query =~ /\($token\)/)
725          100      3      6   if $$struct{'nested'}
752   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
388          100     40     26     55   not $state and not $thing =~ /$join_delim/i
702   ***     66      9      0     11   $outer_start and $outer_start < $start_pos[$i]
      ***     66      9      0     11   $outer_start and $outer_start < $start_pos[$i] and $outer_end
             100      9      4      7   $outer_start and $outer_start < $start_pos[$i] and $outer_end and $outer_end > $end_pos[$i]
711          100      5      4      4   $subqueries[-1] and $subqueries[-1]{'nested'}

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
395          100      6     49   $last_thing || ''
529   ***     50     18      0   $words[1] || ''


Covered Subroutines
-------------------

Subroutine        Count Pod Location                                        
----------------- ----- --- ------------------------------------------------
BEGIN                 1     /home/daniel/dev/maatkit/common/SQLParser.pm:22 
BEGIN                 1     /home/daniel/dev/maatkit/common/SQLParser.pm:23 
BEGIN                 1     /home/daniel/dev/maatkit/common/SQLParser.pm:24 
BEGIN                 1     /home/daniel/dev/maatkit/common/SQLParser.pm:26 
BEGIN                 1     /home/daniel/dev/maatkit/common/SQLParser.pm:275
BEGIN                 1     /home/daniel/dev/maatkit/common/SQLParser.pm:31 
BEGIN                 1     /home/daniel/dev/maatkit/common/SQLParser.pm:540
BEGIN                 1     /home/daniel/dev/maatkit/common/SQLParser.pm:613
_parse_clauses       34     /home/daniel/dev/maatkit/common/SQLParser.pm:126
_parse_query         23     /home/daniel/dev/maatkit/common/SQLParser.pm:179
clean_query          50   0 /home/daniel/dev/maatkit/common/SQLParser.pm:149
new                   1   0 /home/daniel/dev/maatkit/common/SQLParser.pm:43 
parse                33   0 /home/daniel/dev/maatkit/common/SQLParser.pm:67 
parse_columns        18   0 /home/daniel/dev/maatkit/common/SQLParser.pm:619
parse_csv            26   0 /home/daniel/dev/maatkit/common/SQLParser.pm:607
parse_delete          7   0 /home/daniel/dev/maatkit/common/SQLParser.pm:209
parse_from           49   0 /home/daniel/dev/maatkit/common/SQLParser.pm:350
parse_group_by        2   0 /home/daniel/dev/maatkit/common/SQLParser.pm:629
parse_identifier    108   0 /home/daniel/dev/maatkit/common/SQLParser.pm:492
parse_insert         11   0 /home/daniel/dev/maatkit/common/SQLParser.pm:221
parse_limit           9   0 /home/daniel/dev/maatkit/common/SQLParser.pm:574
parse_order_by       11   0 /home/daniel/dev/maatkit/common/SQLParser.pm:563
parse_select         14   0 /home/daniel/dev/maatkit/common/SQLParser.pm:282
parse_update          2   0 /home/daniel/dev/maatkit/common/SQLParser.pm:324
parse_values          8   0 /home/daniel/dev/maatkit/common/SQLParser.pm:595
parse_where          14   0 /home/daniel/dev/maatkit/common/SQLParser.pm:551
remove_subqueries     9   0 /home/daniel/dev/maatkit/common/SQLParser.pm:651

Uncovered Subroutines
---------------------

Subroutine        Count Pod Location                                        
----------------- ----- --- ------------------------------------------------
_d                    0     /home/daniel/dev/maatkit/common/SQLParser.pm:751
parse_having          0   0 /home/daniel/dev/maatkit/common/SQLParser.pm:556


SQLParser.t

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
               1                                  5   
10             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  5   
11                                                    
12             1                    1            12   use Test::More tests => 86;
               1                                  3   
               1                                  9   
13             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                 21   
14                                                    
15             1                    1            11   use MaatkitTest;
               1                                  7   
               1                                 38   
16             1                    1            15   use SQLParser;
               1                                  3   
               1                                 10   
17                                                    
18             1                                  8   my $sp = new SQLParser();
19                                                    
20                                                    # #############################################################################
21                                                    # WHERE where_condition
22                                                    # #############################################################################
23             1                                  7   SKIP: {
24             1                                  3      skip 'Work in progress', 0;
25                                                    sub test_where {
26    ***      0                    0             0      my ( $where, $struct ) = @_;
27    ***      0                                  0      is_deeply(
28                                                          $sp->parse_where($where),
29                                                          $struct,
30                                                          "WHERE $where"
31                                                       );
32                                                    };
33                                                    
34    ***      0                                  0   test_where(
35                                                       'i=1',
36                                                       ['i=1'],
37                                                    );
38                                                    
39    ***      0                                  0   test_where(
40                                                       'i=1 and foo="bar"',
41                                                       [
42                                                          'i=1',
43                                                          'foo="bar"',
44                                                       ],
45                                                    );
46                                                    
47    ***      0                                  0   test_where(
48                                                       '(i=1 and foo="bar")',
49                                                       [
50                                                          'i=1',
51                                                          'foo="bar"',
52                                                       ],
53                                                    );
54                                                    
55    ***      0                                  0   test_where(
56                                                       '(i=1) and (foo="bar")',
57                                                       [
58                                                          'i=1',
59                                                          'foo="bar"',
60                                                       ],
61                                                    );
62                                                    
63    ***      0                                  0   test_where(
64                                                       'i= 1 and foo ="bar" and j = 2',
65                                                       [
66                                                          'i= 1',
67                                                          'foo ="bar"',
68                                                          'j = 2',
69                                                       ],
70                                                    );
71                                                    
72    ***      0                                  0   test_where(
73                                                       'i=1 and foo="i have spaces and a keyword!"',
74                                                       [
75                                                          'i=1',
76                                                          'foo="i have spaces and a keyword!"',
77                                                       ],
78                                                    );
79                                                    
80    ***      0                                  0   test_where(
81                                                       'i="this and this" or j="that and that" and k="and or and" and z=1',
82                                                       [
83                                                          'i="this and"',
84                                                          'j="and that"',
85                                                          'k="and or oh my"',
86                                                          'z=1',
87                                                       ],
88                                                    );
89                                                    
90    ***      0                                  0   test_where(
91                                                       'i="this and this" or j in ("and", "or") and x is not null',
92                                                       [
93                                                          'i="this and"',
94                                                          'j="and that"',
95                                                          'k="and or oh my"',
96                                                          'z=1',
97                                                       ],
98                                                    );
99                                                    }
100                                                   
101                                                   # #############################################################################
102                                                   # Whitespace and comments.
103                                                   # #############################################################################
104                                                   is(
105            1                                 69      $sp->clean_query(' /* leading comment */select *
106                                                         from tbl where /* comment */ id=1  /*trailing comment*/ '
107                                                      ),
108                                                      'select * from tbl where  id=1',
109                                                      'Remove extra whitespace and comment blocks'
110                                                   );
111                                                   
112            1                                  7   is(
113                                                      $sp->clean_query('/*
114                                                         leading comment
115                                                         on multiple lines
116                                                   */ select * from tbl where /* another
117                                                   silly comment */ id=1
118                                                   /*trailing comment
119                                                   also on mutiple lines*/ '
120                                                      ),
121                                                      'select * from tbl where  id=1',
122                                                      'Remove multi-line comment blocks'
123                                                   );
124                                                   
125            1                                  6   is(
126                                                      $sp->clean_query('-- SQL style      
127                                                      -- comments
128                                                      --
129                                                   
130                                                     
131                                                   select now()
132                                                   '
133                                                      ),
134                                                      'select now()',
135                                                      'Remove multiple -- comment lines and blank lines'
136                                                   );
137                                                   
138                                                   
139                                                   # #############################################################################
140                                                   # Add space between key tokens.
141                                                   # #############################################################################
142            1                                  6   is(
143                                                      $sp->clean_query('insert into t value(1)'),
144                                                      'insert into t value (1)',
145                                                      'Add space VALUE (cols)'
146                                                   );
147                                                   
148            1                                  6   is(
149                                                      $sp->clean_query('insert into t values(1)'),
150                                                      'insert into t values (1)',
151                                                      'Add space VALUES (cols)'
152                                                   );
153                                                   
154            1                                  5   is(
155                                                      $sp->clean_query('select * from a join b on(foo)'),
156                                                      'select * from a join b on (foo)',
157                                                      'Add space ON (conditions)'
158                                                   );
159                                                   
160            1                                  6   is(
161                                                      $sp->clean_query('select * from a join b on(foo) join c on(bar)'),
162                                                      'select * from a join b on (foo) join c on (bar)',
163                                                      'Add space multiple ON (conditions)'
164                                                   );
165                                                   
166            1                                  5   is(
167                                                      $sp->clean_query('select * from a join b using(foo)'),
168                                                      'select * from a join b using (foo)',
169                                                      'Add space using (conditions)'
170                                                   );
171                                                   
172            1                                  6   is(
173                                                      $sp->clean_query('select * from a join b using(foo) join c using(bar)'),
174                                                      'select * from a join b using (foo) join c using (bar)',
175                                                      'Add space multiple USING (conditions)'
176                                                   );
177                                                   
178            1                                  8   is(
179                                                      $sp->clean_query('select * from a join b using(foo) join c on(bar)'),
180                                                      'select * from a join b using (foo) join c on (bar)',
181                                                      'Add space USING and ON'
182                                                   );
183                                                   
184                                                   # ###########################################################################
185                                                   # ORDER BY
186                                                   # ###########################################################################
187            1                                  8   is_deeply(
188                                                      $sp->parse_order_by('foo'),
189                                                      [qw(foo)],
190                                                      'ORDER BY foo'
191                                                   );
192            1                                 10   is_deeply(
193                                                      $sp->parse_order_by('foo'),
194                                                      [qw(foo)],
195                                                      'order by foo'
196                                                   );
197            1                                  9   is_deeply(
198                                                      $sp->parse_order_by('foo, bar'),
199                                                      [qw(foo bar)],
200                                                      'order by foo, bar'
201                                                   );
202            1                                  9   is_deeply(
203                                                      $sp->parse_order_by('foo asc, bar'),
204                                                      ['foo asc', 'bar'],
205                                                      'order by foo asc, bar'
206                                                   );
207            1                                  9   is_deeply(
208                                                      $sp->parse_order_by('1'),
209                                                      [qw(1)],
210                                                      'ORDER BY 1'
211                                                   );
212            1                                  9   is_deeply(
213                                                      $sp->parse_order_by('RAND()'),
214                                                      ['RAND()'],
215                                                      'ORDER BY RAND()'
216                                                   );
217                                                   
218                                                   # ###########################################################################
219                                                   # LIMIT
220                                                   # ###########################################################################
221            1                                 10   is_deeply(
222                                                      $sp->parse_limit('1'),
223                                                      { row_count => 1, },
224                                                      'LIMIT 1'
225                                                   );
226            1                                 10   is_deeply(
227                                                      $sp->parse_limit('1, 2'),
228                                                      { row_count => 2,
229                                                        offset    => 1,
230                                                      },
231                                                      'LIMIT 1, 2'
232                                                   );
233            1                                 12   is_deeply(
234                                                      $sp->parse_limit('5 OFFSET 10'),
235                                                      { row_count       => 5,
236                                                        offset          => 10,
237                                                        explicit_offset => 1,
238                                                      },
239                                                      'LIMIT 5 OFFSET 10'
240                                                   );
241                                                   
242                                                   
243                                                   # ###########################################################################
244                                                   # FROM table_references
245                                                   # ###########################################################################
246                                                   sub test_from {
247           17                   17            71      my ( $from, $struct ) = @_;
248           17                                 88      is_deeply(
249                                                         $sp->parse_from($from),
250                                                         $struct,
251                                                         "FROM $from"
252                                                      );
253                                                   };
254                                                   
255            1                                 15   test_from(
256                                                      'tbl',
257                                                      [ { name => 'tbl', } ],
258                                                   );
259                                                   
260            1                                 13   test_from(
261                                                      'tbl ta',
262                                                      [ { name  => 'tbl', alias => 'ta', }  ],
263                                                   );
264                                                   
265            1                                 14   test_from(
266                                                      'tbl AS ta',
267                                                      [ { name           => 'tbl',
268                                                          alias          => 'ta',
269                                                          explicit_alias => 1,
270                                                      } ],
271                                                   );
272                                                   
273            1                                 18   test_from(
274                                                      't1, t2',
275                                                      [
276                                                         { name => 't1', },
277                                                         {
278                                                            name => 't2',
279                                                            join => {
280                                                               to    => 't1',
281                                                               type  => 'inner',
282                                                               ansi  => 0,
283                                                            },
284                                                         }
285                                                      ],
286                                                   );
287                                                   
288            1                                 21   test_from(
289                                                      't1 a, t2 as b',
290                                                      [
291                                                         { name  => 't1',
292                                                           alias => 'a',
293                                                         },
294                                                         {
295                                                           name           => 't2',
296                                                           alias          => 'b',
297                                                           explicit_alias => 1,
298                                                           join           => {
299                                                               to   => 't1',
300                                                               type => 'inner',
301                                                               ansi => 0,
302                                                            },
303                                                         }
304                                                      ],
305                                                   );
306                                                   
307                                                   
308            1                                 22   test_from(
309                                                      't1 JOIN t2 ON t1.id=t2.id',
310                                                      [
311                                                         {
312                                                            name => 't1',
313                                                         },
314                                                         {
315                                                            name => 't2',
316                                                            join => {
317                                                               to         => 't1',
318                                                               type       => '',
319                                                               condition  => 'on',
320                                                               predicates => 't1.id=t2.id ',
321                                                               ansi       => 1,
322                                                            },
323                                                         }
324                                                      ],
325                                                   );
326                                                   
327            1                                 21   test_from(
328                                                      't1 a JOIN t2 as b USING (id)',
329                                                      [
330                                                         {
331                                                            name  => 't1',
332                                                            alias => 'a',
333                                                         },
334                                                         {
335                                                            name  => 't2',
336                                                            alias => 'b',
337                                                            explicit_alias => 1,
338                                                            join  => {
339                                                               to         => 't1',
340                                                               type       => '',
341                                                               condition  => 'using',
342                                                               predicates => '(id) ',
343                                                               ansi       => 1,
344                                                            },
345                                                         },
346                                                      ],
347                                                   );
348                                                   
349            1                                 27   test_from(
350                                                      't1 JOIN t2 ON t1.id=t2.id JOIN t3 ON t1.id=t3.id',
351                                                      [
352                                                         {
353                                                            name  => 't1',
354                                                         },
355                                                         {
356                                                            name  => 't2',
357                                                            join  => {
358                                                               to         => 't1',
359                                                               type       => '',
360                                                               condition  => 'on',
361                                                               predicates => 't1.id=t2.id ',
362                                                               ansi       => 1,
363                                                            },
364                                                         },
365                                                         {
366                                                            name  => 't3',
367                                                            join  => {
368                                                               to         => 't2',
369                                                               type       => '',
370                                                               condition  => 'on',
371                                                               predicates => 't1.id=t3.id ',
372                                                               ansi       => 1,
373                                                            },
374                                                         },
375                                                      ],
376                                                   );
377                                                   
378            1                                 25   test_from(
379                                                      't1 AS a LEFT JOIN t2 b ON a.id = b.id',
380                                                      [
381                                                         {
382                                                            name  => 't1',
383                                                            alias => 'a',
384                                                            explicit_alias => 1,
385                                                         },
386                                                         {
387                                                            name  => 't2',
388                                                            alias => 'b',
389                                                            join  => {
390                                                               to         => 't1',
391                                                               type       => 'left',
392                                                               condition  => 'on',
393                                                               predicates => 'a.id = b.id ',
394                                                               ansi       => 1,
395                                                            },
396                                                         },
397                                                      ],
398                                                   );
399                                                   
400            1                                 22   test_from(
401                                                      't1 a NATURAL RIGHT OUTER JOIN t2 b',
402                                                      [
403                                                         {
404                                                            name  => 't1',
405                                                            alias => 'a',
406                                                         },
407                                                         {
408                                                            name  => 't2',
409                                                            alias => 'b',
410                                                            join  => {
411                                                               to   => 't1',
412                                                               type => 'natural right outer',
413                                                               ansi => 1,
414                                                            },
415                                                         },
416                                                      ],
417                                                   );
418                                                   
419                                                   # http://pento.net/2009/04/03/join-and-comma-precedence/
420            1                                 47   test_from(
421                                                      'a, b LEFT JOIN c ON c.c = a.a',
422                                                      [
423                                                         {
424                                                            name  => 'a',
425                                                         },
426                                                         {
427                                                            name  => 'b',
428                                                            join  => {
429                                                               to   => 'a',
430                                                               type => 'inner',
431                                                               ansi => 0,
432                                                            },
433                                                         },
434                                                         {
435                                                            name  => 'c',
436                                                            join  => {
437                                                               to         => 'b',
438                                                               type       => 'left',
439                                                               condition  => 'on',
440                                                               predicates => 'c.c = a.a ',
441                                                               ansi       => 1, 
442                                                            },
443                                                         },
444                                                      ],
445                                                   );
446                                                   
447            1                                 28   test_from(
448                                                      'a, b, c CROSS JOIN d USING (id)',
449                                                      [
450                                                         {
451                                                            name  => 'a',
452                                                         },
453                                                         {
454                                                            name  => 'b',
455                                                            join  => {
456                                                               to   => 'a',
457                                                               type => 'inner',
458                                                               ansi => 0,
459                                                            },
460                                                         },
461                                                         {
462                                                            name  => 'c',
463                                                            join  => {
464                                                               to   => 'b',
465                                                               type => 'inner',
466                                                               ansi => 0,
467                                                            },
468                                                         },
469                                                         {
470                                                            name  => 'd',
471                                                            join  => {
472                                                               to         => 'c',
473                                                               type       => 'cross',
474                                                               condition  => 'using',
475                                                               predicates => '(id) ',
476                                                               ansi       => 1, 
477                                                            },
478                                                         },
479                                                      ],
480                                                   );
481                                                   
482                                                   # Index hints.
483            1                                 19   test_from(
484                                                      'tbl FORCE INDEX (foo)',
485                                                      [
486                                                         {
487                                                            name       => 'tbl',
488                                                            index_hint => 'FORCE INDEX (foo)',
489                                                         }
490                                                      ]
491                                                   );
492                                                   
493            1                                 13   test_from(
494                                                      'tbl USE INDEX(foo)',
495                                                      [
496                                                         {
497                                                            name       => 'tbl',
498                                                            index_hint => 'USE INDEX(foo)',
499                                                         }
500                                                      ]
501                                                   );
502                                                   
503            1                                 13   test_from(
504                                                      'tbl FORCE KEY(foo)',
505                                                      [
506                                                         {
507                                                            name       => 'tbl',
508                                                            index_hint => 'FORCE KEY(foo)',
509                                                         }
510                                                      ]
511                                                   );
512                                                   
513            1                                 14   test_from(
514                                                      'tbl t FORCE KEY(foo)',
515                                                      [
516                                                         {
517                                                            name       => 'tbl',
518                                                            alias      => 't',
519                                                            index_hint => 'FORCE KEY(foo)',
520                                                         }
521                                                      ]
522                                                   );
523                                                   
524            1                                 15   test_from(
525                                                      'tbl AS t FORCE KEY(foo)',
526                                                      [
527                                                         {
528                                                            name           => 'tbl',
529                                                            alias          => 't',
530                                                            explicit_alias => 1,
531                                                            index_hint     => 'FORCE KEY(foo)',
532                                                         }
533                                                      ]
534                                                   );
535                                                   
536                                                   # #############################################################################
537                                                   # parse_identifier()
538                                                   # #############################################################################
539                                                   sub test_parse_identifier {
540           15                   15            66      my ( $tbl, $struct ) = @_;
541           15                                 77      my %s = $sp->parse_identifier($tbl);
542           15                                 80      is_deeply(
543                                                         \%s,
544                                                         $struct,
545                                                         $tbl
546                                                      );
547           15                                103      return;
548                                                   }
549                                                   
550            1                                 14   test_parse_identifier('tbl',
551                                                      { name => 'tbl', }
552                                                   );
553                                                   
554            1                                  7   test_parse_identifier('tbl a',
555                                                      { name => 'tbl', alias => 'a', }
556                                                   );
557                                                   
558            1                                  7   test_parse_identifier('tbl as a',
559                                                      { name => 'tbl', alias => 'a', explicit_alias => 1, }
560                                                   );
561                                                   
562            1                                  8   test_parse_identifier('tbl AS a',
563                                                      { name => 'tbl', alias => 'a', explicit_alias => 1, }
564                                                   );
565                                                   
566            1                                  8   test_parse_identifier('db.tbl',
567                                                      { name => 'tbl', db => 'db', }
568                                                   );
569                                                   
570            1                                  8   test_parse_identifier('db.tbl a',
571                                                      { name => 'tbl', db => 'db', alias => 'a', }
572                                                   );
573                                                   
574            1                                  9   test_parse_identifier('db.tbl AS a',
575                                                      { name => 'tbl', db => 'db', alias => 'a', explicit_alias => 1, }
576                                                   );
577                                                   
578                                                   
579            1                                  7   test_parse_identifier('`tbl`',
580                                                      { name => 'tbl', }
581                                                   );
582                                                   
583            1                                  7   test_parse_identifier('`tbl` `a`',
584                                                      { name => 'tbl', alias => 'a', }
585                                                   );
586                                                   
587            1                                  8   test_parse_identifier('`tbl` as `a`',
588                                                      { name => 'tbl', alias => 'a', explicit_alias => 1, }
589                                                   );
590                                                   
591            1                                  9   test_parse_identifier('`tbl` AS `a`',
592                                                      { name => 'tbl', alias => 'a', explicit_alias => 1, }
593                                                   );
594                                                   
595            1                                  8   test_parse_identifier('`db`.`tbl`',
596                                                      { name => 'tbl', db => 'db', }
597                                                   );
598                                                   
599            1                                 10   test_parse_identifier('`db`.`tbl` `a`',
600                                                      { name => 'tbl', db => 'db', alias => 'a', }
601                                                   );
602                                                   
603            1                                  9   test_parse_identifier('`db`.`tbl` AS `a`',
604                                                      { name => 'tbl', db => 'db', alias => 'a', explicit_alias => 1, }
605                                                   );
606                                                   
607            1                                  8   test_parse_identifier('db.* foo',
608                                                      { name => '*', db => 'db', alias => 'foo' }
609                                                   );
610                                                   
611                                                   # #############################################################################
612                                                   # Subqueries.
613                                                   # #############################################################################
614                                                   
615            1                                  5   my $query = "DELETE FROM t1
616                                                   WHERE s11 > ANY
617                                                   (SELECT COUNT(*) /* no hint */ FROM t2 WHERE NOT EXISTS
618                                                      (SELECT * FROM t3 WHERE ROW(5*t2.s1,77)=
619                                                         (SELECT 50,11*s1 FROM
620                                                            (SELECT * FROM t5) AS t5
621                                                         )
622                                                      )
623                                                   )";
624            1                                  7   my @subqueries = $sp->remove_subqueries($sp->clean_query($query));
625            1                                 18   is_deeply(
626                                                      \@subqueries,
627                                                      [
628                                                         'DELETE FROM t1 WHERE s11 > ANY (__SQ3__)',
629                                                         {
630                                                            query   => 'SELECT * FROM t5',
631                                                            context => 'identifier',
632                                                            nested  => 1,
633                                                         },
634                                                         {
635                                                            query   => 'SELECT 50,11*s1 FROM __SQ0__ AS t5',
636                                                            context => 'scalar',
637                                                            nested  => 2,
638                                                         },
639                                                         {
640                                                            query   => 'SELECT * FROM t3 WHERE ROW(5*t2.s1,77)= __SQ1__',
641                                                            context => 'list',
642                                                            nested  => 3,
643                                                         },
644                                                         {
645                                                            query   => 'SELECT COUNT(*)  FROM t2 WHERE NOT EXISTS (__SQ2__)',
646                                                            context => 'list',
647                                                         }
648                                                      ],
649                                                      'DELETE with nested subqueries'
650                                                   );
651                                                   
652            1                                 10   $query = "select col from tbl
653                                                             where id=(select max(id) from tbl2 where foo='bar') limit 1";
654            1                                  8   @subqueries = $sp->remove_subqueries($sp->clean_query($query));
655            1                                 10   is_deeply(
656                                                      \@subqueries,
657                                                      [
658                                                         'select col from tbl where id=__SQ0__ limit 1',
659                                                         {
660                                                            query   => "select max(id) from tbl2 where foo='bar'",
661                                                            context => 'scalar',
662                                                         },
663                                                      ],
664                                                      'Subquery as scalar'
665                                                   );
666                                                   
667            1                                  9   $query = "select col from tbl
668                                                             where id=(select max(id) from tbl2 where foo='bar') and col in(select foo from tbl3) limit 1";
669            1                                  6   @subqueries = $sp->remove_subqueries($sp->clean_query($query));
670            1                                 11   is_deeply(
671                                                      \@subqueries,
672                                                      [
673                                                         'select col from tbl where id=__SQ1__ and col in(__SQ0__) limit 1',
674                                                         {
675                                                            query   => "select foo from tbl3",
676                                                            context => 'list',
677                                                         },
678                                                         {
679                                                            query   => "select max(id) from tbl2 where foo='bar'",
680                                                            context => 'scalar',
681                                                         },
682                                                      ],
683                                                      'Subquery as scalar and IN()'
684                                                   );
685                                                   
686            1                                  9   $query = "SELECT NOW() AS a1, (SELECT f1(5)) AS a2";
687            1                                  6   @subqueries = $sp->remove_subqueries($sp->clean_query($query));
688            1                                  8   is_deeply(
689                                                      \@subqueries,
690                                                      [
691                                                         'SELECT NOW() AS a1, __SQ0__ AS a2',
692                                                         {
693                                                            query   => "SELECT f1(5)",
694                                                            context => 'identifier',
695                                                         },
696                                                      ],
697                                                      'Subquery as SELECT column'
698                                                   );
699                                                   
700            1                                  9   $query = "SELECT DISTINCT store_type FROM stores s1
701                                                   WHERE NOT EXISTS (
702                                                   SELECT * FROM cities WHERE NOT EXISTS (
703                                                   SELECT * FROM cities_stores
704                                                   WHERE cities_stores.city = cities.city
705                                                   AND cities_stores.store_type = stores.store_type))";
706            1                                  6   @subqueries = $sp->remove_subqueries($sp->clean_query($query));
707            1                                 12   is_deeply(
708                                                      \@subqueries,
709                                                      [
710                                                         'SELECT DISTINCT store_type FROM stores s1 WHERE NOT EXISTS (__SQ1__)',
711                                                         {
712                                                            query   => "SELECT * FROM cities_stores WHERE cities_stores.city = cities.city AND cities_stores.store_type = stores.store_type",
713                                                            context => 'list',
714                                                            nested  => 1,
715                                                         },
716                                                         {
717                                                            query   => "SELECT * FROM cities WHERE NOT EXISTS (__SQ0__)",
718                                                            context => 'list',
719                                                         },
720                                                      ],
721                                                      'Two nested NOT EXISTS subqueries'
722                                                   );
723                                                   
724            1                                  9   $query = "select col from tbl
725                                                             where id=(select max(id) from tbl2 where foo='bar')
726                                                             and col in(select foo from
727                                                               (select b from fn where id=1
728                                                                  and b > any(select a from a)
729                                                               )
730                                                            ) limit 1";
731            1                                  6   @subqueries = $sp->remove_subqueries($sp->clean_query($query));
732            1                                 15   is_deeply(
733                                                      \@subqueries,
734                                                      [
735                                                         'select col from tbl where id=__SQ3__ and col in(__SQ2__) limit 1',
736                                                         {
737                                                            query   => 'select a from a',
738                                                            context => 'list',
739                                                            nested  => 1,
740                                                         },
741                                                         {
742                                                            query   => 'select b from fn where id=1 and b > any(__SQ0__)',
743                                                            context => 'identifier',
744                                                            nested  => 2,
745                                                         },
746                                                         {
747                                                            query   => 'select foo from __SQ1__',
748                                                            context => 'list',
749                                                         },
750                                                         {
751                                                            query   => 'select max(id) from tbl2 where foo=\'bar\'',
752                                                            context => 'scalar',
753                                                         },
754                                                      ],
755                                                      'Mutiple and nested subqueries'
756                                                   );
757                                                   
758            1                                 12   $query = "select (select now()) from universe";
759            1                                  7   @subqueries = $sp->remove_subqueries($sp->clean_query($query));
760            1                                  9   is_deeply(
761                                                      \@subqueries,
762                                                      [
763                                                         'select __SQ0__ from universe',
764                                                         {
765                                                            query   => 'select now()',
766                                                            context => 'identifier',
767                                                         },
768                                                      ],
769                                                      'Subquery as non-aliased column identifier'
770                                                   );
771                                                   
772                                                   # #############################################################################
773                                                   # Test parsing full queries.
774                                                   # #############################################################################
775                                                   
776            1                                432   my @cases = (
777                                                   
778                                                      # ########################################################################
779                                                      # DELETE
780                                                      # ########################################################################
781                                                      {  name   => 'DELETE FROM',
782                                                         query  => 'DELETE FROM tbl',
783                                                         struct => {
784                                                            type    => 'delete',
785                                                            clauses => { from => 'tbl', },
786                                                            from    => [ { name => 'tbl', } ],
787                                                            unknown => undef,
788                                                         },
789                                                      },
790                                                      {  name   => 'DELETE FROM WHERE',
791                                                         query  => 'DELETE FROM tbl WHERE id=1',
792                                                         struct => {
793                                                            type    => 'delete',
794                                                            clauses => { 
795                                                               from  => 'tbl ',
796                                                               where => 'id=1',
797                                                            },
798                                                            from    => [ { name => 'tbl', } ],
799                                                            where   => 'id=1',
800                                                            unknown => undef,
801                                                         },
802                                                      },
803                                                      {  name   => 'DELETE FROM LIMIT',
804                                                         query  => 'DELETE FROM tbl LIMIT 5',
805                                                         struct => {
806                                                            type    => 'delete',
807                                                            clauses => {
808                                                               from  => 'tbl ',
809                                                               limit => '5',
810                                                            },
811                                                            from    => [ { name => 'tbl', } ],
812                                                            limit   => {
813                                                               row_count => 5,
814                                                            },
815                                                            unknown => undef,
816                                                         },
817                                                      },
818                                                      {  name   => 'DELETE FROM ORDER BY',
819                                                         query  => 'DELETE FROM tbl ORDER BY foo',
820                                                         struct => {
821                                                            type    => 'delete',
822                                                            clauses => {
823                                                               from     => 'tbl ',
824                                                               order_by => 'foo',
825                                                            },
826                                                            from     => [ { name => 'tbl', } ],
827                                                            order_by => [qw(foo)],
828                                                            unknown  => undef,
829                                                         },
830                                                      },
831                                                      {  name   => 'DELETE FROM WHERE LIMIT',
832                                                         query  => 'DELETE FROM tbl WHERE id=1 LIMIT 3',
833                                                         struct => {
834                                                            type    => 'delete',
835                                                            clauses => { 
836                                                               from  => 'tbl ',
837                                                               where => 'id=1 ',
838                                                               limit => '3',
839                                                            },
840                                                            from    => [ { name => 'tbl', } ],
841                                                            where   => 'id=1 ',
842                                                            limit   => {
843                                                               row_count => 3,
844                                                            },
845                                                            unknown => undef,
846                                                         },
847                                                      },
848                                                      {  name   => 'DELETE FROM WHERE ORDER BY',
849                                                         query  => 'DELETE FROM tbl WHERE id=1 ORDER BY id',
850                                                         struct => {
851                                                            type    => 'delete',
852                                                            clauses => { 
853                                                               from     => 'tbl ',
854                                                               where    => 'id=1 ',
855                                                               order_by => 'id',
856                                                            },
857                                                            from     => [ { name => 'tbl', } ],
858                                                            where    => 'id=1 ',
859                                                            order_by => [qw(id)],
860                                                            unknown  => undef,
861                                                         },
862                                                      },
863                                                      {  name   => 'DELETE FROM WHERE ORDER BY LIMIT',
864                                                         query  => 'DELETE FROM tbl WHERE id=1 ORDER BY id ASC LIMIT 1 OFFSET 3',
865                                                         struct => {
866                                                            type    => 'delete',
867                                                            clauses => { 
868                                                               from     => 'tbl ',
869                                                               where    => 'id=1 ',
870                                                               order_by => 'id ASC ',
871                                                               limit    => '1 OFFSET 3',
872                                                            },
873                                                            from    => [ { name => 'tbl', } ],
874                                                            where   => 'id=1 ',
875                                                            order_by=> ['id ASC'],
876                                                            limit   => {
877                                                               row_count       => 1,
878                                                               offset          => 3,
879                                                               explicit_offset => 1,
880                                                            },
881                                                            unknown => undef,
882                                                         },
883                                                      },
884                                                   
885                                                      # ########################################################################
886                                                      # INSERT
887                                                      # ########################################################################
888                                                      {  name   => 'INSERT INTO VALUES',
889                                                         query  => 'INSERT INTO tbl VALUES (1,"foo")',
890                                                         struct => {
891                                                            type    => 'insert',
892                                                            clauses => { 
893                                                               into   => 'tbl',
894                                                               values => '(1,"foo")',
895                                                            },
896                                                            into   => [ { name => 'tbl', } ],
897                                                            values => [ '(1,"foo")', ],
898                                                            unknown => undef,
899                                                         },
900                                                      },
901                                                      {  name   => 'INSERT VALUE',
902                                                         query  => 'INSERT tbl VALUE (1,"foo")',
903                                                         struct => {
904                                                            type    => 'insert',
905                                                            clauses => { 
906                                                               into   => 'tbl',
907                                                               values => '(1,"foo")',
908                                                            },
909                                                            into   => [ { name => 'tbl', } ],
910                                                            values => [ '(1,"foo")', ],
911                                                            unknown => undef,
912                                                         },
913                                                      },
914                                                      {  name   => 'INSERT INTO cols VALUES',
915                                                         query  => 'INSERT INTO db.tbl (id, name) VALUE (2,"bob")',
916                                                         struct => {
917                                                            type    => 'insert',
918                                                            clauses => { 
919                                                               into    => 'db.tbl',
920                                                               columns => 'id, name ',
921                                                               values  => '(2,"bob")',
922                                                            },
923                                                            into    => [ { name => 'tbl', db => 'db' } ],
924                                                            columns => [ { name => 'id' }, { name => 'name' } ],
925                                                            values  => [ '(2,"bob")', ],
926                                                            unknown => undef,
927                                                         },
928                                                      },
929                                                      {  name   => 'INSERT INTO VALUES ON DUPLICATE',
930                                                         query  => 'INSERT INTO tbl VALUE (3,"bob") ON DUPLICATE KEY UPDATE col1=9',
931                                                         struct => {
932                                                            type    => 'insert',
933                                                            clauses => { 
934                                                               into         => 'tbl',
935                                                               values       => '(3,"bob") ',
936                                                               on_duplicate => 'col1=9',
937                                                            },
938                                                            into         => [ { name => 'tbl', } ],
939                                                            values       => [ '(3,"bob")', ],
940                                                            on_duplicate => ['col1=9',],
941                                                            unknown      => undef,
942                                                         },
943                                                      },
944                                                      {  name   => 'INSERT INTO SET',
945                                                         query  => 'INSERT INTO tbl SET id=1, foo=NULL',
946                                                         struct => {
947                                                            type    => 'insert',
948                                                            clauses => { 
949                                                               into => 'tbl',
950                                                               set  => 'id=1, foo=NULL',
951                                                            },
952                                                            into    => [ { name => 'tbl', } ],
953                                                            set     => ['id=1', 'foo=NULL',],
954                                                            unknown => undef,
955                                                         },
956                                                      },
957                                                      {  name   => 'INSERT INTO SET ON DUPLICATE',
958                                                         query  => 'INSERT INTO tbl SET i=3 ON DUPLICATE KEY UPDATE col1=9',
959                                                         struct => {
960                                                            type    => 'insert',
961                                                            clauses => { 
962                                                               into         => 'tbl',
963                                                               set          => 'i=3 ',
964                                                               on_duplicate => 'col1=9',
965                                                            },
966                                                            into         => [ { name => 'tbl', } ],
967                                                            set          => ['i=3',],
968                                                            on_duplicate => ['col1=9',],
969                                                            unknown      => undef,
970                                                         },
971                                                      },
972                                                      {  name   => 'INSERT ... SELECT',
973                                                         query  => 'INSERT INTO tbl (col) SELECT id FROM tbl2 WHERE id > 100',
974                                                         struct => {
975                                                            type    => 'insert',
976                                                            clauses => { 
977                                                               into    => 'tbl',
978                                                               columns => 'col ',
979                                                               select  => 'id FROM tbl2 WHERE id > 100',
980                                                            },
981                                                            into         => [ { name => 'tbl', } ],
982                                                            columns      => [ { name => 'col' } ],
983                                                            select       => {
984                                                               clauses => { 
985                                                                  columns => 'id ',
986                                                                  from    => 'tbl2 ',
987                                                                  where   => 'id > 100',
988                                                               },
989                                                               columns => [ { name => 'id' } ],
990                                                               from    => [ { name => 'tbl2', } ],
991                                                               where   => 'id > 100',
992                                                               unknown => undef,
993                                                            },
994                                                            unknown      => undef,
995                                                         },
996                                                      },
997                                                      {  name   => 'INSERT INTO VALUES()',
998                                                         query  => 'INSERT INTO db.tbl (id, name) VALUES(2,"bob")',
999                                                         struct => {
1000                                                           type    => 'insert',
1001                                                           clauses => { 
1002                                                              into    => 'db.tbl',
1003                                                              columns => 'id, name ',
1004                                                              values  => '(2,"bob")',
1005                                                           },
1006                                                           into    => [ { name => 'tbl', db => 'db' } ],
1007                                                           columns => [ { name => 'id' }, { name => 'name' } ],
1008                                                           values  => [ '(2,"bob")', ],
1009                                                           unknown => undef,
1010                                                        },
1011                                                     },
1012                                                  
1013                                                     # ########################################################################
1014                                                     # REPLACE
1015                                                     # ########################################################################
1016                                                     # REPLACE are parsed by parse_insert() so if INSERT is well-tested we
1017                                                     # shouldn't need to test REPLACE much.
1018                                                     {  name   => 'REPLACE INTO VALUES',
1019                                                        query  => 'REPLACE INTO tbl VALUES (1,"foo")',
1020                                                        struct => {
1021                                                           type    => 'replace',
1022                                                           clauses => { 
1023                                                              into   => 'tbl',
1024                                                              values => '(1,"foo")',
1025                                                           },
1026                                                           into   => [ { name => 'tbl', } ],
1027                                                           values => [ '(1,"foo")', ],
1028                                                           unknown => undef,
1029                                                        },
1030                                                     },
1031                                                     {  name   => 'REPLACE VALUE',
1032                                                        query  => 'REPLACE tbl VALUE (1,"foo")',
1033                                                        struct => {
1034                                                           type    => 'replace',
1035                                                           clauses => { 
1036                                                              into   => 'tbl',
1037                                                              values => '(1,"foo")',
1038                                                           },
1039                                                           into   => [ { name => 'tbl', } ],
1040                                                           values => [ '(1,"foo")', ],
1041                                                           unknown => undef,
1042                                                        },
1043                                                     },
1044                                                     {  name   => 'REPLACE INTO cols VALUES',
1045                                                        query  => 'REPLACE INTO db.tbl (id, name) VALUE (2,"bob")',
1046                                                        struct => {
1047                                                           type    => 'replace',
1048                                                           clauses => { 
1049                                                              into    => 'db.tbl',
1050                                                              columns => 'id, name ',
1051                                                              values  => '(2,"bob")',
1052                                                           },
1053                                                           into    => [ { name => 'tbl', db => 'db' } ],
1054                                                           columns => [ { name => 'id' }, { name => 'name' } ],
1055                                                           values  => [ '(2,"bob")', ],
1056                                                           unknown => undef,
1057                                                        },
1058                                                     },
1059                                                  
1060                                                     # ########################################################################
1061                                                     # SELECT
1062                                                     # ########################################################################
1063                                                     {  name   => 'SELECT',
1064                                                        query  => 'SELECT NOW()',
1065                                                        struct => {
1066                                                           type    => 'select',
1067                                                           clauses => { 
1068                                                              columns => 'NOW()',
1069                                                           },
1070                                                           columns => [ { name => 'NOW()' } ],
1071                                                           unknown => undef,
1072                                                        },
1073                                                     },
1074                                                     {  name   => 'SELECT FROM',
1075                                                        query  => 'SELECT col1, col2 FROM tbl',
1076                                                        struct => {
1077                                                           type    => 'select',
1078                                                           clauses => { 
1079                                                              columns => 'col1, col2 ',
1080                                                              from    => 'tbl',
1081                                                           },
1082                                                           columns => [ { name => 'col1' }, { name => 'col2' } ],
1083                                                           from    => [ { name => 'tbl', } ],
1084                                                           unknown => undef,
1085                                                        },
1086                                                     },
1087                                                     {  name   => 'SELECT FROM JOIN WHERE GROUP BY ORDER BY LIMIT',
1088                                                        query  => '/* nonsensical but covers all the basic clauses */
1089                                                           SELECT t1.col1 a, t1.col2 as b
1090                                                           FROM tbl1 t1
1091                                                              LEFT JOIN tbl2 AS t2 ON t1.id = t2.id
1092                                                           WHERE
1093                                                              t2.col IS NOT NULL
1094                                                              AND t2.name = "bob"
1095                                                           GROUP BY a, b
1096                                                           ORDER BY t2.name ASC
1097                                                           LIMIT 100, 10
1098                                                        ',
1099                                                        struct => {
1100                                                           type    => 'select',
1101                                                           clauses => { 
1102                                                              columns  => 't1.col1 a, t1.col2 as b ',
1103                                                              from     => 'tbl1 t1 LEFT JOIN tbl2 AS t2 ON t1.id = t2.id ',
1104                                                              where    => 't2.col IS NOT NULL AND t2.name = "bob" ',
1105                                                              group_by => 'a, b ',
1106                                                              order_by => 't2.name ASC ',
1107                                                              limit    => '100, 10',
1108                                                           },
1109                                                           columns => [ { name => 'col1', db => 't1', alias => 'a' },
1110                                                                        { name => 'col2', db => 't1', alias => 'b',
1111                                                                          explicit_alias => 1 } ],
1112                                                           from    => [
1113                                                              {
1114                                                                 name  => 'tbl1',
1115                                                                 alias => 't1',
1116                                                              },
1117                                                              {
1118                                                                 name  => 'tbl2',
1119                                                                 alias => 't2',
1120                                                                 explicit_alias => 1,
1121                                                                 join  => {
1122                                                                    to        => 'tbl1',
1123                                                                    type      => 'left',
1124                                                                    condition => 'on',
1125                                                                    predicates=> 't1.id = t2.id  ',
1126                                                                    ansi      => 1,
1127                                                                 },
1128                                                              },
1129                                                           ],
1130                                                           where    => 't2.col IS NOT NULL AND t2.name = "bob" ',
1131                                                           group_by => { columns => [qw(a b)], },
1132                                                           order_by => ['t2.name ASC'],
1133                                                           limit    => {
1134                                                              row_count => 10,
1135                                                              offset    => 100,
1136                                                           },
1137                                                           unknown => undef,
1138                                                        },
1139                                                     },
1140                                                     {  name   => 'SELECT FROM JOIN ON() JOIN USING() WHERE',
1141                                                        query  => 'SELECT t1.col1 a, t1.col2 as b
1142                                                  
1143                                                           FROM tbl1 t1
1144                                                  
1145                                                              JOIN tbl2 AS t2 ON(t1.id = t2.id)
1146                                                  
1147                                                              JOIN tbl3 t3 USING(id) 
1148                                                  
1149                                                           WHERE
1150                                                              t2.col IS NOT NULL',
1151                                                        struct => {
1152                                                           type    => 'select',
1153                                                           clauses => { 
1154                                                              columns  => 't1.col1 a, t1.col2 as b ',
1155                                                              from     => 'tbl1 t1 JOIN tbl2 AS t2 on (t1.id = t2.id) JOIN tbl3 t3 using (id) ',
1156                                                              where    => 't2.col IS NOT NULL',
1157                                                           },
1158                                                           columns => [ { name => 'col1', db => 't1', alias => 'a' },
1159                                                                        { name => 'col2', db => 't1', alias => 'b',
1160                                                                          explicit_alias => 1 } ],
1161                                                           from    => [
1162                                                              {
1163                                                                 name  => 'tbl1',
1164                                                                 alias => 't1',
1165                                                              },
1166                                                              {
1167                                                                 name  => 'tbl2',
1168                                                                 alias => 't2',
1169                                                                 explicit_alias => 1,
1170                                                                 join  => {
1171                                                                    to        => 'tbl1',
1172                                                                    type      => '',
1173                                                                    condition => 'on',
1174                                                                    predicates=> '(t1.id = t2.id) ',
1175                                                                    ansi      => 1,
1176                                                                 },
1177                                                              },
1178                                                              {
1179                                                                 name  => 'tbl3',
1180                                                                 alias => 't3',
1181                                                                 join  => {
1182                                                                    to        => 'tbl2',
1183                                                                    type      => '',
1184                                                                    condition => 'using',
1185                                                                    predicates=> '(id)  ',
1186                                                                    ansi      => 1,
1187                                                                 },
1188                                                              },
1189                                                           ],
1190                                                           where    => 't2.col IS NOT NULL',
1191                                                           unknown => undef,
1192                                                        },
1193                                                     },
1194                                                     {  name   => 'SELECT keywords',
1195                                                        query  => 'SELECT all high_priority SQL_CALC_FOUND_ROWS NOW() LOCK IN SHARE MODE',
1196                                                        struct => {
1197                                                           type     => 'select',
1198                                                           clauses  => { 
1199                                                              columns => 'NOW()',
1200                                                           },
1201                                                           columns  => [ { name => 'NOW()' } ],
1202                                                           keywords => {
1203                                                              all                 => 1,
1204                                                              high_priority       => 1,
1205                                                              sql_calc_found_rows => 1,
1206                                                              lock_in_share_mode  => 1,
1207                                                           },
1208                                                           unknown  => undef,
1209                                                        },
1210                                                     },
1211                                                     { name   => 'SELECT * FROM WHERE',
1212                                                       query  => 'SELECT * FROM tbl WHERE ip="127.0.0.1"',
1213                                                       struct => {
1214                                                           type     => 'select',
1215                                                           clauses  => { 
1216                                                              columns => '* ',
1217                                                              from    => 'tbl ',
1218                                                              where   => 'ip="127.0.0.1"',
1219                                                           },
1220                                                           columns  => [ { name => '*' } ],
1221                                                           from     => [ { name => 'tbl' } ],
1222                                                           where    => 'ip="127.0.0.1"',
1223                                                           unknown  => undef,
1224                                                        },
1225                                                     },
1226                                                     { name    => 'SELECT with simple subquery',
1227                                                       query   => 'select * from t where id in(select col from t2) where i=1',
1228                                                       struct  => {
1229                                                           type    => 'select',
1230                                                           clauses => { 
1231                                                              columns => '* ',
1232                                                              from    => 't ',
1233                                                              where   => 'i=1',
1234                                                           },
1235                                                           columns    => [ { name => '*' } ],
1236                                                           from       => [ { name => 't' } ],
1237                                                           where      => 'i=1',
1238                                                           unknown    => undef,
1239                                                           subqueries => [
1240                                                              {
1241                                                                 query   => 'select col from t2',
1242                                                                 context => 'list',
1243                                                                 type    => 'select',
1244                                                                 clauses => { 
1245                                                                    columns => 'col ',
1246                                                                    from    => 't2',
1247                                                                 },
1248                                                                 columns    => [ { name => 'col' } ],
1249                                                                 from       => [ { name => 't2' } ],
1250                                                                 unknown    => undef,
1251                                                              },
1252                                                           ],
1253                                                        },
1254                                                     },
1255                                                     { name    => 'Complex SELECT, multiple JOIN and subqueries',
1256                                                       query   => 'select now(), (select foo from bar where id=1)
1257                                                                   from t1, t2 join (select * from sqt1) as t3 using (`select`)
1258                                                                   join t4 on t4.id=t3.id 
1259                                                                   where c1 > any(select col2 as z from sqt2 zz
1260                                                                      where sqtc<(select max(col) from l where col<100))
1261                                                                   and s in ("select", "tricky") or s <> "select"
1262                                                                   group by 1 limit 10',
1263                                                        struct => {
1264                                                           type       => 'select',
1265                                                           clauses    => { 
1266                                                              columns  => 'now(), __SQ3__ ',
1267                                                              from     => 't1, t2 join __SQ2__ as t3 using (`select`) join t4 on t4.id=t3.id ',
1268                                                              where    => 'c1 > any(__SQ1__) and s in ("select", "tricky") or s <> "select" ',
1269                                                              group_by => '1 ',
1270                                                              limit    => '10',
1271                                                           },
1272                                                           columns    => [ { name => 'now()' }, { name => '__SQ3__' } ],
1273                                                           from       => [
1274                                                              {
1275                                                                 name => 't1',
1276                                                              },
1277                                                              {
1278                                                                 name => 't2',
1279                                                                 join => {
1280                                                                    to   => 't1',
1281                                                                    ansi => 0,
1282                                                                    type => 'inner',
1283                                                                 },
1284                                                              },
1285                                                              {
1286                                                                 name  => '__SQ2__',
1287                                                                 alias => 't3',
1288                                                                 explicit_alias => 1,
1289                                                                 join  => {
1290                                                                    to   => 't2',
1291                                                                    ansi => 1,
1292                                                                    type => '',
1293                                                                    predicates => '(`select`) ',
1294                                                                    condition  => 'using',
1295                                                                 },
1296                                                              },
1297                                                              {
1298                                                                 name => 't4',
1299                                                                 join => {
1300                                                                    to   => '__SQ2__',
1301                                                                    ansi => 1,
1302                                                                    type => '',
1303                                                                    predicates => 't4.id=t3.id  ',
1304                                                                    condition  => 'on',
1305                                                                 },
1306                                                              },
1307                                                           ],
1308                                                           where      => 'c1 > any(__SQ1__) and s in ("select", "tricky") or s <> "select" ',
1309                                                           limit      => { row_count => 10 },
1310                                                           group_by   => { columns => ['1'], },
1311                                                           unknown    => undef,
1312                                                           subqueries => [
1313                                                              {
1314                                                                 clauses => {
1315                                                                    columns => 'max(col) ',
1316                                                                    from    => 'l ',
1317                                                                    where   => 'col<100'
1318                                                                 },
1319                                                                 columns => [ { name => 'max(col)' } ],
1320                                                                 context => 'scalar',
1321                                                                 from    => [ { name => 'l' } ],
1322                                                                 nested  => 1,
1323                                                                 query   => 'select max(col) from l where col<100',
1324                                                                 type    => 'select',
1325                                                                 unknown => undef,
1326                                                                 where   => 'col<100'
1327                                                              },
1328                                                              {
1329                                                                 clauses  => {
1330                                                                    columns => 'col2 as z ',
1331                                                                    from    => 'sqt2 zz ',
1332                                                                    where   => 'sqtc<__SQ0__'
1333                                                                 },
1334                                                                 columns => [
1335                                                                    { alias => 'z', explicit_alias => 1, name => 'col2' }
1336                                                                 ],
1337                                                                 context  => 'list',
1338                                                                 from     => [ { alias => 'zz', name => 'sqt2' } ],
1339                                                                 query    => 'select col2 as z from sqt2 zz where sqtc<__SQ0__',
1340                                                                 type     => 'select',
1341                                                                 unknown  => undef,
1342                                                                 where    => 'sqtc<__SQ0__'
1343                                                              },
1344                                                              {
1345                                                                 clauses  => {
1346                                                                    columns => '* ',
1347                                                                    from    => 'sqt1'
1348                                                                 },
1349                                                                 columns  => [ { name => '*' } ],
1350                                                                 context  => 'identifier',
1351                                                                 from     => [ { name => 'sqt1' } ],
1352                                                                 query    => 'select * from sqt1',
1353                                                                 type     => 'select',
1354                                                                 unknown  => undef
1355                                                              },
1356                                                              {
1357                                                                 clauses  => {
1358                                                                 columns  => 'foo ',
1359                                                                    from  => 'bar ',
1360                                                                    where => 'id=1'
1361                                                                 },
1362                                                                 columns  => [ { name => 'foo' } ],
1363                                                                 context  => 'identifier',
1364                                                                 from     => [ { name => 'bar' } ],
1365                                                                 query    => 'select foo from bar where id=1',
1366                                                                 type     => 'select',
1367                                                                 unknown  => undef,
1368                                                                 where    => 'id=1'
1369                                                              },
1370                                                           ],
1371                                                        },
1372                                                     },
1373                                                  
1374                                                     # ########################################################################
1375                                                     # UPDATE
1376                                                     # ########################################################################
1377                                                     {  name   => 'UPDATE SET',
1378                                                        query  => 'UPDATE tbl SET col=1',
1379                                                        struct => {
1380                                                           type    => 'update',
1381                                                           clauses => { 
1382                                                              tables => 'tbl ',
1383                                                              set    => 'col=1',
1384                                                           },
1385                                                           tables  => [ { name => 'tbl', } ],
1386                                                           set     => ['col=1'],
1387                                                           unknown => undef,
1388                                                        },
1389                                                     },
1390                                                     {  name   => 'UPDATE SET WHERE ORDER BY LIMIT',
1391                                                        query  => 'UPDATE tbl AS t SET foo=NULL WHERE foo IS NOT NULL ORDER BY id LIMIT 10',
1392                                                        struct => {
1393                                                           type    => 'update',
1394                                                           clauses => { 
1395                                                              tables   => 'tbl AS t ',
1396                                                              set      => 'foo=NULL ',
1397                                                              where    => 'foo IS NOT NULL ',
1398                                                              order_by => 'id ',
1399                                                              limit    => '10',
1400                                                           },
1401                                                           tables   => [ { name => 'tbl', alias => 't', explicit_alias => 1, } ],
1402                                                           set      => ['foo=NULL'],
1403                                                           where    => 'foo IS NOT NULL ',
1404                                                           order_by => ['id'],
1405                                                           limit    => { row_count => 10 },
1406                                                           unknown => undef,
1407                                                        },
1408                                                     },
1409                                                  );
1410                                                  
1411           1                                 12   foreach my $test ( @cases ) {
1412          28                                436      my $struct = $sp->parse($test->{query});
1413          28                                162      is_deeply(
1414                                                        $struct,
1415                                                        $test->{struct},
1416                                                        $test->{name},
1417                                                     );
1418                                                  }
1419                                                  
1420                                                  # #############################################################################
1421                                                  # Done.
1422                                                  # #############################################################################
1423           1                                  3   exit;


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

Subroutine            Count Location       
--------------------- ----- ---------------
BEGIN                     1 SQLParser.t:10 
BEGIN                     1 SQLParser.t:12 
BEGIN                     1 SQLParser.t:13 
BEGIN                     1 SQLParser.t:15 
BEGIN                     1 SQLParser.t:16 
BEGIN                     1 SQLParser.t:4  
BEGIN                     1 SQLParser.t:9  
test_from                17 SQLParser.t:247
test_parse_identifier    15 SQLParser.t:540

Uncovered Subroutines
---------------------

Subroutine            Count Location       
--------------------- ----- ---------------
test_where                0 SQLParser.t:26 


