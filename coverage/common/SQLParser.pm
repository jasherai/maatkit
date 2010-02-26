---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...atkit/common/SQLParser.pm   93.9   73.4   77.8   92.9    0.0   92.3   85.3
SQLParser.t                   100.0   50.0   33.3  100.0    n/a    7.7   96.9
Total                          95.3   72.9   66.7   94.6    0.0  100.0   87.4
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Feb 26 18:17:02 2010
Finish:       Fri Feb 26 18:17:02 2010

Run:          SQLParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Feb 26 18:17:03 2010
Finish:       Fri Feb 26 18:17:03 2010

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
18                                                    # SQLParser package $Revision: 5882 $
19                                                    # ###########################################################################
20                                                    package SQLParser;
21                                                    
22             1                    1             5   use strict;
               1                                  2   
               1                                  6   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
24             1                    1             5   use English qw(-no_match_vars);
               1                                  2   
               1                                  6   
25                                                    
26             1                    1             6   use Data::Dumper;
               1                                  2   
               1                                  4   
27                                                    $Data::Dumper::Indent    = 1;
28                                                    $Data::Dumper::Sortkeys  = 1;
29                                                    $Data::Dumper::Quotekeys = 0;
30                                                    
31    ***      1            50      1             6   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 12   
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
46             1                                 12      return bless $self, $class;
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
67    ***     26                   26      0    127      my ( $self, $query ) = @_;
68    ***     26     50                         102      return unless $query;
69                                                    
70                                                       # Flatten and clean query.
71            26                                 96      $query = $self->clean_query($query);
72                                                    
73                                                       # Remove first word, should be the statement type.  The parse_TYPE subs
74                                                       # expect that this is already removed.
75            26                                 64      my $type;
76    ***     26     50                         136      if ( $query =~ s/^(\w+)\s+// ) {
77            26                                112         $type = lc $1;
78            26                                 56         MKDEBUG && _d('Query type:', $type);
79    ***     26     50                         252         if ( $type !~ m/$allowed_types/i ) {
80    ***      0                                  0            return;
81                                                          }
82                                                       }
83                                                       else {
84    ***      0                                  0         MKDEBUG && _d('No first word/type');
85    ***      0                                  0         return;
86                                                       }
87                                                    
88                                                       # Parse raw text parts from query.  The parse_TYPE subs only do half
89                                                       # the work: parsing raw text parts of clauses, tables, functions, etc.
90                                                       # Since these parts are invariant (e.g. a LIMIT clause is same for any
91                                                       # type of SQL statement) they are parsed later via other parse_CLAUSE
92                                                       # subs, instead of parsing them individually in each parse_TYPE sub.
93            26                                 82      my $parse_func = "parse_$type";
94            26                                124      my $struct     = $self->$parse_func($query);
95    ***     26     50                         101      if ( !$struct ) {
96    ***      0                                  0         MKDEBUG && _d($parse_func, 'failed to parse query');
97    ***      0                                  0         return;
98                                                       }
99            26                                 88      $struct->{type} = $type;
100           26                                 98      $self->_parse_clauses($struct);
101                                                      # TODO: parse functions
102                                                   
103           26                                 57      MKDEBUG && _d('Query struct:', Dumper($struct));
104           26                                107      return $struct;
105                                                   }
106                                                   
107                                                   sub _parse_clauses {
108           27                   27            99      my ( $self, $struct ) = @_;
109                                                      # Parse raw text of clauses and functions.
110           27                                 70      foreach my $clause ( keys %{$struct->{clauses}} ) {
              27                                150   
111                                                         # Rename/remove clauses with space in their names, like ORDER BY.
112           71    100                         279         if ( $clause =~ m/ / ) {
113            6                                 31            (my $clause_no_space = $clause) =~ s/ /_/g;
114            6                                 34            $struct->{clauses}->{$clause_no_space} = $struct->{clauses}->{$clause};
115            6                                 23            delete $struct->{clauses}->{$clause};
116            6                                 19            $clause = $clause_no_space;
117                                                         }
118                                                   
119           71                                218         my $parse_func     = "parse_$clause";
120           71                                386         $struct->{$clause} = $self->$parse_func($struct->{clauses}->{$clause});
121                                                   
122           71    100                         355         if ( $clause eq 'select' ) {
123            1                                  3            MKDEBUG && _d('Parsing subquery clauses');
124            1                                  7            $self->_parse_clauses($struct->{select});
125                                                         }
126                                                      }
127           27                                 84      return;
128                                                   }
129                                                   
130                                                   sub clean_query {
131   ***     36                   36      0    154      my ( $self, $query ) = @_;
132   ***     36     50                         140      return unless $query;
133                                                   
134                                                      # Whitespace and comments.
135           36                                127      $query =~ s/^\s*--.*$//gm;  # -- comments
136           36                                264      $query =~ s/\s+/ /g;        # extra spaces/flatten
137           36                                130      $query =~ s!/\*.*?\*/!!g;   # /* comments */
138           36                                116      $query =~ s/^\s+//;         # leading spaces
139           36                                173      $query =~ s/\s+$//;         # trailing spaces
140                                                   
141                                                      # Add spaces between important tokens to help the parse_* subs.
142           36                                257      $query =~ s/\b(VALUE(?:S)?)\(/$1 (/i;
143           36                                230      $query =~ s/\bON\(/on (/gi;
144           36                                199      $query =~ s/\bUSING\(/using (/gi;
145                                                   
146           36                                172      return $query;
147                                                   }
148                                                   
149                                                   # This sub is called by the parse_TYPE subs except parse_insert.
150                                                   # It does two things: remove, save the given keywords, all of which
151                                                   # should appear at the beginning of the query; and, save (but not
152                                                   # remove) the given clauses.  The query should start with the values
153                                                   # for the first clause because the query's first word was removed
154                                                   # in parse().  So for "SELECT cols FROM ...", the query given here
155                                                   # is "cols FROM ..." where "cols" belongs to the first clause "columns".
156                                                   # Then the query is walked clause-by-clause, saving each.
157                                                   sub _parse_query {
158           16                   16            87      my ( $self, $query, $keywords, $first_clause, $clauses ) = @_;
159   ***     16     50                          67      return unless $query;
160           16                                 52      my $struct = {};
161                                                   
162                                                      # Save, remove keywords.
163           16                                308      1 while $query =~ s/$keywords\s+/$struct->{keywords}->{lc $1}=1, ''/gie;
               3                                 31   
164                                                   
165                                                      # Go clausing.
166           16                                311      my @clause = grep { defined $_ }
              86                                300   
167                                                         ($query =~ m/\G(.+?)(?:$clauses\s+|\Z)/gci);
168                                                   
169           16                                 83      my $clause = $first_clause,
170                                                      my $value  = shift @clause;
171           16                                 79      $struct->{clauses}->{$clause} = $value;
172           16                                 32      MKDEBUG && _d('Clause:', $clause, $value);
173                                                   
174                                                      # All other clauses.
175           16                                 68      while ( @clause ) {
176           27                                 75         $clause = shift @clause;
177           27                                 72         $value  = shift @clause;
178           27                                120         $struct->{clauses}->{lc $clause} = $value;
179           27                                103         MKDEBUG && _d('Clause:', $clause, $value);
180                                                      }
181                                                   
182           16                                 78      ($struct->{unknown}) = ($query =~ m/\G(.+)/);
183                                                   
184           16                                 95      return $struct;
185                                                   }
186                                                   
187                                                   sub parse_delete {
188   ***      7                    7      0     31      my ( $self, $query ) = @_;
189   ***      7     50                          41      if ( $query =~ s/FROM\s+// ) {
190            7                                 38         my $keywords = qr/(LOW_PRIORITY|QUICK|IGNORE)/i;
191            7                                 24         my $clauses  = qr/(FROM|WHERE|ORDER BY|LIMIT)/i;
192            7                                 38         return $self->_parse_query($query, $keywords, 'from', $clauses);
193                                                      }
194                                                      else {
195   ***      0                                  0         die "DELETE without FROM: $query";
196                                                      }
197                                                   }
198                                                   
199                                                   sub parse_insert {
200   ***     11                   11      0     48      my ( $self, $query ) = @_;
201   ***     11     50                          45      return unless $query;
202           11                                 33      my $struct = {};
203                                                   
204                                                      # Save, remove keywords.
205           11                                 55      my $keywords   = qr/(LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)/i;
206           11                                137      1 while $query =~ s/$keywords\s+/$struct->{keywords}->{lc $1}=1, ''/gie;
      ***      0                                  0   
207                                                   
208                                                      # Parse INTO clause.  Literal "INTO" is optional.
209   ***     11     50                         415      if ( my @into = ($query =~ m/
210                                                               (?:INTO\s+)?            # INTO, optional
211                                                               (.+?)\s+                # table ref
212                                                               (\([^\)]+\)\s+)?        # column list, optional
213                                                               (VALUE.?|SET|SELECT)\s+ # start of next caluse
214                                                            /xgci)
215                                                      ) {
216           11                                 35         my $tbl  = shift @into;  # table ref
217           11                                 55         $struct->{clauses}->{into} = $tbl;
218           11                                 22         MKDEBUG && _d('Clause: into', $tbl);
219                                                   
220           11                                 31         my $cols = shift @into;  # columns, maybe
221           11    100                          43         if ( $cols ) {
222            4                                 19            $cols =~ s/[\(\)]//g;
223            4                                 17            $struct->{clauses}->{columns} = $cols;
224            4                                 11            MKDEBUG && _d('Clause: columns', $cols);
225                                                         }
226                                                   
227           11                                 34         my $next_clause = lc(shift @into);  # VALUES, SET or SELECT
228   ***     11     50                          36         die "INSERT/REPLACE without clause after table: $query"
229                                                            unless $next_clause;
230           11    100                          47         $next_clause = 'values' if $next_clause eq 'value';
231           11                                 91         my ($values, $on) = ($query =~ m/\G(.+?)(ON|\Z)/gci);
232   ***     11     50                          48         die "INSERT/REPLACE without values: $query" unless $values;
233           11                                 43         $struct->{clauses}->{$next_clause} = $values;
234           11                                 24         MKDEBUG && _d('Clause:', $next_clause, $values);
235                                                   
236           11    100                          43         if ( $on ) {
237            2                                 10            ($values) = ($query =~ m/ON DUPLICATE KEY UPDATE (.+)/i);
238   ***      2     50                          10            die "No values after ON DUPLICATE KEY UPDATE: $query" unless $values;
239            2                                  9            $struct->{clauses}->{on_duplicate} = $values;
240            2                                  5            MKDEBUG && _d('Clause: on duplicate key update', $values);
241                                                         }
242                                                      }
243                                                   
244                                                      # Save any leftovers.  If there are any, parsing missed something.
245           11                                 56      ($struct->{unknown}) = ($query =~ m/\G(.+)/);
246                                                   
247           11                                 65      return $struct;
248                                                   }
249                                                   {
250                                                      # Suppress warnings like "Name "SQLParser::parse_set" used only once:
251                                                      # possible typo at SQLParser.pm line 480." caused by the fact that we
252                                                      # don't call these aliases directly, they're called indirectly using
253                                                      # $parse_func, hence Perl can't see their being called a compile time.
254            1                    1             8      no warnings;
               1                                  2   
               1                                  7   
255                                                      # INSERT and REPLACE are so similar that they are both parsed
256                                                      # in parse_insert().
257                                                      *parse_replace = \&parse_insert;
258                                                   }
259                                                   
260                                                   sub parse_select {
261   ***      7                    7      0     35      my ( $self, $query ) = @_;
262                                                   
263                                                      # Keywords are expected to be at the start of the query, so these
264                                                      # that appear at the end are handled separately.  Afaik, SELECT is
265                                                      # only statement with optional keywords at the end.  Also, these
266                                                      # appear to be the only keywords with spaces instead of _.
267            7                                 19      my @keywords;
268            7                                 42      my $final_keywords = qr/(FOR UPDATE|LOCK IN SHARE MODE)/i; 
269            7                                106      1 while $query =~ s/\s+$final_keywords/(push @keywords, $1), ''/gie;
               1                                 13   
270                                                   
271            7                                 30      my $keywords = qr/(
272                                                          ALL
273                                                         |DISTINCT
274                                                         |DISTINCTROW
275                                                         |HIGH_PRIORITY
276                                                         |STRAIGHT_JOIN
277                                                         |SQL_SMALL_RESULT
278                                                         |SQL_BIG_RESULT
279                                                         |SQL_BUFFER_RESULT
280                                                         |SQL_CACHE
281                                                         |SQL_NO_CACHE
282                                                         |SQL_CALC_FOUND_ROWS
283                                                      )/xi;
284            7                                 24      my $clauses = qr/(
285                                                          FROM
286                                                         |WHERE
287                                                         |GROUP\sBY
288                                                         |HAVING
289                                                         |ORDER\sBY
290                                                         |LIMIT
291                                                         |PROCEDURE
292                                                         |INTO OUTFILE
293                                                      )/xi;
294            7                                 32      my $struct = $self->_parse_query($query, $keywords, 'columns', $clauses);
295                                                   
296                                                      # Add final keywords, if any.
297            7                                 22      map { s/ /_/g; $struct->{keywords}->{lc $_} = 1; } @keywords;
               1                                  6   
               1                                  6   
298                                                   
299            7                                 49      return $struct;
300                                                   }
301                                                   
302                                                   sub parse_update {
303   ***      2                    2      0     11      my $keywords = qr/(LOW_PRIORITY|IGNORE)/i;
304            2                                  8      my $clauses  = qr/(SET|WHERE|ORDER BY|LIMIT)/i;
305            2                                 10      return _parse_query(@_, $keywords, 'tables', $clauses);
306                                                   
307                                                   }
308                                                   
309                                                   # Parse a FROM clause, a.k.a. the table references.  Returns an arrayref
310                                                   # of hashrefs, one hashref for each table.  Each hashref is like:
311                                                   #
312                                                   #   {
313                                                   #     name           => 't2',  -- this table's real name
314                                                   #     alias          => 'b',   -- table's alias, if any
315                                                   #     explicit_alias => 1,     -- if explicitly aliased with AS
316                                                   #     join  => {               -- if joined to another table, all but first
317                                                   #                              -- table are because comma implies INNER JOIN
318                                                   #       to         => 't1',    -- table name on left side of join  
319                                                   #       type       => '',      -- right, right, inner, outer, cross, natural
320                                                   #       condition  => 'using', -- on or using, if applicable
321                                                   #       predicates => '(id) ', -- stuff after on or using, if applicable
322                                                   #       ansi       => 1,       -- true of ANSI JOIN, i.e. true if not implicit
323                                                   #     },                       -- INNER JOIN due to follow a comma
324                                                   #   },
325                                                   #
326                                                   # Tables are listed in the order that they appear.  Currently, subqueries
327                                                   # and nested joins are not handled.
328                                                   sub parse_from {
329   ***     42                   42      0    157      my ( $self, $from ) = @_;
330   ***     42     50                         164      return unless $from;
331           42                                 95      MKDEBUG && _d('FROM clause:', $from);
332                                                   
333                                                      # This method tokenize the FROM clause into "things".  Each thing
334                                                      # is one of either a:
335                                                      #   * table ref, including alias
336                                                      #   * JOIN syntax word
337                                                      #   * ON or USING (condition)
338                                                      #   * ON|USING predicates text
339                                                      # So it is not word-by-word; it's thing-by-thing in one pass.
340                                                      # Currently, the ON|USING predicates are not parsed further.
341                                                   
342           42                                102      my @tbls;  # All parsed tables.
343           42                                 91      my $tbl;   # This gets pushed to @tbls when it's set.  It may not be
344                                                                 # all the time if, for example, $pending_tbl is being built.
345                                                   
346                                                      # These vars are used when parsing an explicit/ANSI JOIN statement.
347           42                                106      my $pending_tbl;         
348           42                                102      my $state      = undef;  
349           42                                114      my $join       = '';  # JOIN syntax words, without JOIN; becomes type
350           42                                312      my $joinno     = 0;   # join number for debugging
351           42                                102      my $redo       = 0;   # save $pending_tbl, redo loop for new JOIN
352                                                   
353                                                      # These vars help detect "comma joins", e.g. "tbl1, tbl2", which are
354                                                      # treated by MySQL as implicit INNER JOIN.  See below.
355           42                                107      my $join_back  = 0;
356           42                                103      my $last_thing = '';
357                                                   
358           42                                198      my $join_delim
359                                                         = qr/,|INNER|CROSS|STRAIGHT_JOIN|LEFT|RIGHT|OUTER|NATURAL|JOIN|ON|USING/i;
360           42                                141      my $next_tbl
361                                                         = qr/,|INNER|CROSS|STRAIGHT_JOIN|LEFT|RIGHT|OUTER|NATURAL|JOIN/i;
362                                                   
363           42                                473      foreach my $thing ( split(/\s*($join_delim)\s+/io, $from) ) {
364          110    100                         374         next unless $thing;
365          103                                216         MKDEBUG && _d('Table thing:', $thing, 'state:', $state); 
366                                                   
367          103    100    100                  921         if ( !$state && $thing !~ m/$join_delim/i ) {
368           47                                100            MKDEBUG && _d('Table factor');
369           47                                199            $tbl = { $self->parse_identifier($thing) };
370                                                            
371                                                            # Non-ANSI implicit INNER join to previous table, e.g. "tbl1, tbl2".
372                                                            # Manual says: "INNER JOIN and , (comma) are semantically equivalent
373                                                            # in the absence of a join condition".
374           47    100    100                  389            $join_back = 1 if ($last_thing || '') eq ',';
375                                                         }
376                                                         else {
377                                                            # Should be starting or continuing an explicit JOIN.
378           56    100                         247            if ( !$state ) {
                    100                               
      ***            50                               
379           23                                 54               $joinno++;
380           23                                 49               MKDEBUG && _d('JOIN', $joinno, 'start');
381           23                                 76               $join .= ' ' . lc $thing;
382           23    100                         101               if ( $join =~ m/join$/ ) {
383           11                                 45                  $join =~ s/ join$//;
384           11                                 33                  $join =~ s/^\s+//;
385           11                                 24                  MKDEBUG && _d('JOIN', $joinno, 'type:', $join);
386           11                                 36                  my $last_tbl = $tbls[-1];
387   ***     11     50                          37                  die "Invalid syntax: $from\n"
388                                                                     . "JOIN without preceding table reference" unless $last_tbl;
389           11                                 90                  $pending_tbl->{join} = {
390                                                                     to   => $last_tbl->{name},
391                                                                     type => $join,
392                                                                     ansi => 1,
393                                                                  };
394           11                                 28                  $join    = '';
395           11                                 38                  $state   = 'join tbl';
396                                                               }
397                                                            }
398                                                            elsif ( $state eq 'join tbl' ) {
399                                                               # Table for this join (i.e. tbl to right of JOIN).
400           11                                 47               my %tbl_ref = $self->parse_identifier($thing);
401           11                                 50               @{$pending_tbl}{keys %tbl_ref} = values %tbl_ref;
              11                                 48   
402           11                                 38               $state = 'join condition';
403                                                            }
404                                                            elsif ( $state eq 'join condition' ) {
405           22    100                         161               if ( $thing =~ m/$next_tbl/io ) {
                    100                               
406            2                                  6                  MKDEBUG && _d('JOIN', $joinno, 'end');
407            2                                  7                  $tbl  = $pending_tbl;
408            2                                  6                  $redo = 1;  # save $pending_tbl then redo this new JOIN
409                                                               }
410                                                               elsif ( $thing =~ m/ON|USING/i ) {
411           10                                 22                  MKDEBUG && _d('JOIN', $joinno, 'codition');
412           10                                 49                  $pending_tbl->{join}->{condition} = lc $thing;
413                                                               }
414                                                               else {
415           10                                 21                  MKDEBUG && _d('JOIN', $joinno, 'predicate');
416           10                                 52                  $pending_tbl->{join}->{predicates} .= "$thing ";
417                                                               }
418                                                            }
419                                                            else {
420   ***      0                                  0               die "Unknown state '$state' parsing JOIN syntax: $from";
421                                                            }
422                                                         }
423                                                   
424          103                                267         $last_thing = $thing;
425                                                   
426          103    100                         324         if ( $tbl ) {
427           49    100                         161            if ( $join_back ) {
428            5                                 16               my $prev_tbl = $tbls[-1];
429   ***      5     50                          26               if ( $tbl->{join} ) {
430   ***      0                                  0                  die "Cannot implicitly join $tbl->{name} to $prev_tbl->{name} "
431                                                                     . "because it is already joined to $tbl->{join}->{to}";
432                                                               }
433            5                                 31               $tbl->{join} = {
434                                                                  to   => $prev_tbl->{name},
435                                                                  type => 'inner',
436                                                                  ansi => 0,
437                                                               }
438                                                            }
439           49                                155            push @tbls, $tbl;
440           49                                133            $tbl         = undef;
441           49                                122            $state       = undef;
442           49                                114            $pending_tbl = undef;
443           49                                126            $join        = '';
444           49                                127            $join_back   = 0;
445                                                         }
446                                                         else {
447           54                                115            MKDEBUG && _d('Table pending:', Dumper($pending_tbl));
448                                                         }
449          103    100                         421         if ( $redo ) {
450            2                                  6            MKDEBUG && _d("Redoing this thing");
451            2                                  5            $redo = 0;
452            2                                  6            redo;
453                                                         }
454                                                      }
455                                                   
456                                                      # Save the final JOIN which was end by the end of the FROM clause
457                                                      # rather than by the start of a new JOIN.
458           42    100                         171      if ( $pending_tbl ) {
459            9                                 28         push @tbls, $pending_tbl;
460                                                      }
461                                                   
462           42                                 86      MKDEBUG && _d('Parsed tables:', Dumper(\@tbls));
463           42                                298      return \@tbls;
464                                                   }
465                                                   
466                                                   # Parse a table ref like "tbl", "tbl alias" or "tbl AS alias", where
467                                                   # tbl can be optionally "db." qualified.  Also handles FORCE|USE|IGNORE
468                                                   # INDEX hints.  Does not handle "FOR JOIN" hint because "JOIN" here gets
469                                                   # confused with the "JOIN" thing in parse_from().
470                                                   sub parse_identifier {
471   ***     90                   90      0    342      my ( $self, $tbl_ref ) = @_;
472           90                                223      my %tbl;
473           90                                189      MKDEBUG && _d('Identifier string:', $tbl_ref);
474                                                   
475                                                      # First, check for an index hint.  Remove and save it if present.
476           90                                200      my $index_hint;
477           90    100                         381      if ( $tbl_ref =~ s/
478                                                            \s+(
479                                                               (?:FORCE|USE|INGORE)\s
480                                                               (?:INDEX|KEY)
481                                                               \s*\([^\)]+\)\s*
482                                                            )//xi)
483                                                      {
484            5                                 11         MKDEBUG && _d('Index hint:', $1);
485            5                                 26         $tbl{index_hint} = $1;
486                                                      }
487                                                   
488           90                                381      my $tbl_ident = qr/
489                                                         (?:`[^`]+`|[\w*]+)       # `something`, or something
490                                                         (?:                      # optionally followed by either
491                                                            \.(?:`[^`]+`|[\w*]+)  #   .`something` or .something, or
492                                                            |\([^\)]*\)           #   (function stuff)  (e.g. NOW())
493                                                         )?             
494                                                      /x;
495                                                   
496   ***     90     50                         843      my @words = map { s/`//g if defined; $_; } $tbl_ref =~ m/($tbl_ident)/g;
             139                                600   
             139                                536   
497                                                      # tbl ref:  tbl AS foo
498                                                      # words:      0  1   2
499           90                                229      MKDEBUG && _d('Identifier words:', @words);
500                                                   
501                                                      # Real table name with optional db. qualifier.
502           90                                561      my ($db, $tbl) = $words[0] =~ m/(?:(.+?)\.)?(.+)$/;
503           90    100                         361      $tbl{db}   = $db if $db;
504           90                                307      $tbl{name} = $tbl;
505                                                   
506                                                      # Alias.
507           90    100                         374      if ( $words[2] ) {
                    100                               
508   ***     16     50     50                  101         die "Bad identifier: $tbl_ref" unless ($words[1] || '') =~ m/AS/i;
509           16                                 53         $tbl{alias}          = $words[2];
510           16                                 50         $tbl{explicit_alias} = 1;
511                                                      }
512                                                      elsif ( $words[1] ) {
513           17                                 56         $tbl{alias} = $words[1];
514                                                      }
515                                                   
516           90                                775      return %tbl;
517                                                   }
518                                                   {
519            1                    1             8      no warnings;  # Why? See same line above.
               1                                  2   
               1                                  5   
520                                                      *parse_into   = \&parse_from;
521                                                      *parse_tables = \&parse_from;
522                                                   }
523                                                   
524                                                   sub parse_where {
525   ***      9                    9      0     36      my ( $self, $where ) = @_;
526                                                      # TODO
527            9                                 36      return $where;
528                                                   }
529                                                   
530                                                   sub parse_having {
531   ***      0                    0      0      0      my ( $self, $having ) = @_;
532                                                      # TODO
533   ***      0                                  0      return $having;
534                                                   }
535                                                   
536                                                   # [ORDER BY {col_name | expr | position} [ASC | DESC], ...]
537                                                   sub parse_order_by {
538   ***     11                   11      0     48      my ( $self, $order_by ) = @_;
539   ***     11     50                          47      return unless $order_by;
540           11                                 25      MKDEBUG && _d('Parse ORDER BY', $order_by);
541                                                      # They don't have to be cols, they can be expressions or positions;
542                                                      # we call them all cols for simplicity.
543           11                                 48      my @cols = map { s/^\s+//; s/\s+$//; $_ } split(',', $order_by);
              13                                 48   
              13                                 44   
              13                                 53   
544           11                                 64      return \@cols;
545                                                   }
546                                                   
547                                                   # [LIMIT {[offset,] row_count | row_count OFFSET offset}]
548                                                   sub parse_limit {
549   ***      8                    8      0     43      my ( $self, $limit ) = @_;
550   ***      8     50                          33      return unless $limit;
551            8                                 36      my $struct = {
552                                                         row_count => undef,
553                                                      };
554            8    100                          35      if ( $limit =~ m/(\S+)\s+OFFSET\s+(\S+)/i ) {
555            2                                  8         $struct->{explicit_offset} = 1;
556            2                                 10         $struct->{row_count}       = $1;
557            2                                 10         $struct->{offset}          = $2;
558                                                      }
559                                                      else {
560            6                                 46         my ($offset, $cnt) = $limit =~ m/(?:(\S+),\s+)?(\S+)/i;
561            6                                 23         $struct->{row_count} = $cnt;
562            6    100                          29         $struct->{offset}    = $offset if defined $offset;
563                                                      }
564            8                                 39      return $struct;
565                                                   }
566                                                   
567                                                   # Parses the list of values after, e.g., INSERT tbl VALUES (...), (...).
568                                                   # Does not currently parse each set of values; it just splits the list.
569                                                   sub parse_values {
570   ***      8                    8      0     33      my ( $self, $values ) = @_;
571   ***      8     50                          27      return unless $values;
572                                                      # split(',', $values) will not work (without some kind of regex
573                                                      # look-around assertion) because there are commas inside the sets
574                                                      # of values.
575            8                                 52      my @vals = ($values =~ m/\([^\)]+\)/g);
576            8                                 40      return \@vals;
577                                                   }
578                                                   
579                                                   # Split any comma-separated list of values, removing leading
580                                                   # and trailing spaces.
581                                                   sub parse_csv {
582   ***     18                   18      0     67      my ( $self, $vals ) = @_;
583   ***     18     50                          65      return unless $vals;
584           18                                 81      my @vals = map { s/^\s+//; s/\s+$//; $_ } split(',', $vals);
              26                                 87   
              26                                 91   
              26                                111   
585           18                                 89      return \@vals;
586                                                   }
587                                                   {
588            1                    1             7      no warnings;  # Why? See same line above.
               1                                  3   
               1                                  4   
589                                                      *parse_set          = \&parse_csv;
590                                                      *parse_on_duplicate = \&parse_csv;
591                                                   }
592                                                   
593                                                   sub parse_columns {
594   ***     11                   11      0     47      my ( $self, $cols ) = @_;
595           17                                 81      my @cols = map {
596           11                                 42         my %ref = $self->parse_identifier($_);
597           17                                 75         \%ref;
598           11                                 34      } @{ $self->parse_csv($cols) };
599           11                                 55      return \@cols;
600                                                   }
601                                                   
602                                                   # GROUP BY {col_name | expr | position} [ASC | DESC], ... [WITH ROLLUP]
603                                                   sub parse_group_by {
604   ***      1                    1      0      5      my ( $self, $group_by ) = @_;
605            1                                  4      my $with_rollup = $group_by =~ s/\s+WITH ROLLUP\s*//i;
606            1                                  5      my $struct = {
607                                                         columns => $self->parse_csv($group_by),
608                                                      };
609   ***      1     50                           4      $struct->{with_rollup} = 1 if $with_rollup;
610            1                                  5      return $struct;
611                                                   }
612                                                   
613                                                   sub _d {
614   ***      0                    0                    my ($package, undef, $line) = caller 0;
615   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
616   ***      0                                              map { defined $_ ? $_ : 'undef' }
617                                                           @_;
618   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
619                                                   }
620                                                   
621                                                   1;
622                                                   
623                                                   # ###########################################################################
624                                                   # End SQLParser package
625                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
68    ***     50      0     26   unless $query
76    ***     50     26      0   if ($query =~ s/^(\w+)\s+//) { }
79    ***     50      0     26   if (not $type =~ /$allowed_types/i)
95    ***     50      0     26   if (not $struct)
112          100      6     65   if ($clause =~ / /)
122          100      1     70   if ($clause eq 'select')
132   ***     50      0     36   unless $query
159   ***     50      0     16   unless $query
189   ***     50      7      0   if ($query =~ s/FROM\s+//) { }
201   ***     50      0     11   unless $query
209   ***     50     11      0   if (my(@into) = $query =~ /
            (?:INTO\s+)?            # INTO, optional
            (.+?)\s+                # table ref
            (\([^\)]+\)\s+)?        # column list, optional
            (VALUE.?|SET|SELECT)\s+ # start of next caluse
         /cgix)
221          100      4      7   if ($cols)
228   ***     50      0     11   unless $next_clause
230          100      5      6   if $next_clause eq 'value'
232   ***     50      0     11   unless $values
236          100      2      9   if ($on)
238   ***     50      0      2   unless $values
330   ***     50      0     42   unless $from
364          100      7    103   unless $thing
367          100     47     56   if (not $state and not $thing =~ /$join_delim/i) { }
374          100      5     42   if ($last_thing || '') eq ','
378          100     23     33   if (not $state) { }
             100     11     22   elsif ($state eq 'join tbl') { }
      ***     50     22      0   elsif ($state eq 'join condition') { }
382          100     11     12   if ($join =~ /join$/)
387   ***     50      0     11   unless $last_tbl
405          100      2     20   if ($thing =~ /$next_tbl/io) { }
             100     10     10   elsif ($thing =~ /ON|USING/i) { }
426          100     49     54   if ($tbl) { }
427          100      5     44   if ($join_back)
429   ***     50      0      5   if ($$tbl{'join'})
449          100      2    101   if ($redo)
458          100      9     33   if ($pending_tbl)
477          100      5     85   if ($tbl_ref =~ s/
         \s+(
            (?:FORCE|USE|INGORE)\s
            (?:INDEX|KEY)
            \s*\([^\)]+\)\s*
         )//xi)
496   ***     50    139      0   if defined $_
503          100     14     76   if $db
507          100     16     74   if ($words[2]) { }
             100     17     57   elsif ($words[1]) { }
508   ***     50      0     16   unless ($words[1] || '') =~ /AS/i
539   ***     50      0     11   unless $order_by
550   ***     50      0      8   unless $limit
554          100      2      6   if ($limit =~ /(\S+)\s+OFFSET\s+(\S+)/i) { }
562          100      2      4   if defined $offset
571   ***     50      0      8   unless $values
583   ***     50      0     18   unless $vals
609   ***     50      0      1   if $with_rollup
615   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
367          100     33     23     47   not $state and not $thing =~ /$join_delim/i

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
31    ***     50      0      1   $ENV{'MKDEBUG'} || 0
374          100      5     42   $last_thing || ''
508   ***     50     16      0   $words[1] || ''


Covered Subroutines
-------------------

Subroutine       Count Pod Location                                        
---------------- ----- --- ------------------------------------------------
BEGIN                1     /home/daniel/dev/maatkit/common/SQLParser.pm:22 
BEGIN                1     /home/daniel/dev/maatkit/common/SQLParser.pm:23 
BEGIN                1     /home/daniel/dev/maatkit/common/SQLParser.pm:24 
BEGIN                1     /home/daniel/dev/maatkit/common/SQLParser.pm:254
BEGIN                1     /home/daniel/dev/maatkit/common/SQLParser.pm:26 
BEGIN                1     /home/daniel/dev/maatkit/common/SQLParser.pm:31 
BEGIN                1     /home/daniel/dev/maatkit/common/SQLParser.pm:519
BEGIN                1     /home/daniel/dev/maatkit/common/SQLParser.pm:588
_parse_clauses      27     /home/daniel/dev/maatkit/common/SQLParser.pm:108
_parse_query        16     /home/daniel/dev/maatkit/common/SQLParser.pm:158
clean_query         36   0 /home/daniel/dev/maatkit/common/SQLParser.pm:131
new                  1   0 /home/daniel/dev/maatkit/common/SQLParser.pm:43 
parse               26   0 /home/daniel/dev/maatkit/common/SQLParser.pm:67 
parse_columns       11   0 /home/daniel/dev/maatkit/common/SQLParser.pm:594
parse_csv           18   0 /home/daniel/dev/maatkit/common/SQLParser.pm:582
parse_delete         7   0 /home/daniel/dev/maatkit/common/SQLParser.pm:188
parse_from          42   0 /home/daniel/dev/maatkit/common/SQLParser.pm:329
parse_group_by       1   0 /home/daniel/dev/maatkit/common/SQLParser.pm:604
parse_identifier    90   0 /home/daniel/dev/maatkit/common/SQLParser.pm:471
parse_insert        11   0 /home/daniel/dev/maatkit/common/SQLParser.pm:200
parse_limit          8   0 /home/daniel/dev/maatkit/common/SQLParser.pm:549
parse_order_by      11   0 /home/daniel/dev/maatkit/common/SQLParser.pm:538
parse_select         7   0 /home/daniel/dev/maatkit/common/SQLParser.pm:261
parse_update         2   0 /home/daniel/dev/maatkit/common/SQLParser.pm:303
parse_values         8   0 /home/daniel/dev/maatkit/common/SQLParser.pm:570
parse_where          9   0 /home/daniel/dev/maatkit/common/SQLParser.pm:525

Uncovered Subroutines
---------------------

Subroutine       Count Pod Location                                        
---------------- ----- --- ------------------------------------------------
_d                   0     /home/daniel/dev/maatkit/common/SQLParser.pm:614
parse_having         0   0 /home/daniel/dev/maatkit/common/SQLParser.pm:531


SQLParser.t

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
               1                                  3   
               1                                  6   
10             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
11                                                    
12             1                    1            11   use Test::More tests => 77;
               1                                  2   
               1                                  9   
13             1                    1            16   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
14                                                    
15             1                    1             9   use MaatkitTest;
               1                                  3   
               1                                 10   
16             1                    1            13   use SQLParser;
               1                                  4   
               1                                 10   
17                                                    
18             1                                  8   my $sp = new SQLParser();
19                                                    
20                                                    # #############################################################################
21                                                    # Whitespace and comments.
22                                                    # #############################################################################
23             1                                  6   is(
24                                                       $sp->clean_query(' /* leading comment */select *
25                                                          from tbl where /* comment */ id=1  /*trailing comment*/ '
26                                                       ),
27                                                       'select * from tbl where  id=1',
28                                                       'Remove extra whitespace and comment blocks'
29                                                    );
30                                                    
31             1                                  7   is(
32                                                       $sp->clean_query('/*
33                                                          leading comment
34                                                          on multiple lines
35                                                    */ select * from tbl where /* another
36                                                    silly comment */ id=1
37                                                    /*trailing comment
38                                                    also on mutiple lines*/ '
39                                                       ),
40                                                       'select * from tbl where  id=1',
41                                                       'Remove multi-line comment blocks'
42                                                    );
43                                                    
44             1                                  7   is(
45                                                       $sp->clean_query('-- SQL style      
46                                                       -- comments
47                                                       --
48                                                    
49                                                      
50                                                    select now()
51                                                    '
52                                                       ),
53                                                       'select now()',
54                                                       'Remove multiple -- comment lines and blank lines'
55                                                    );
56                                                    
57                                                    
58                                                    # #############################################################################
59                                                    # Add space between key tokens.
60                                                    # #############################################################################
61             1                                  7   is(
62                                                       $sp->clean_query('insert into t value(1)'),
63                                                       'insert into t value (1)',
64                                                       'Add space VALUE (cols)'
65                                                    );
66                                                    
67             1                                  7   is(
68                                                       $sp->clean_query('insert into t values(1)'),
69                                                       'insert into t values (1)',
70                                                       'Add space VALUES (cols)'
71                                                    );
72                                                    
73             1                                  6   is(
74                                                       $sp->clean_query('select * from a join b on(foo)'),
75                                                       'select * from a join b on (foo)',
76                                                       'Add space ON (conditions)'
77                                                    );
78                                                    
79             1                                  7   is(
80                                                       $sp->clean_query('select * from a join b on(foo) join c on(bar)'),
81                                                       'select * from a join b on (foo) join c on (bar)',
82                                                       'Add space multiple ON (conditions)'
83                                                    );
84                                                    
85             1                                  6   is(
86                                                       $sp->clean_query('select * from a join b using(foo)'),
87                                                       'select * from a join b using (foo)',
88                                                       'Add space using (conditions)'
89                                                    );
90                                                    
91             1                                  7   is(
92                                                       $sp->clean_query('select * from a join b using(foo) join c using(bar)'),
93                                                       'select * from a join b using (foo) join c using (bar)',
94                                                       'Add space multiple USING (conditions)'
95                                                    );
96                                                    
97             1                                  8   is(
98                                                       $sp->clean_query('select * from a join b using(foo) join c on(bar)'),
99                                                       'select * from a join b using (foo) join c on (bar)',
100                                                      'Add space USING and ON'
101                                                   );
102                                                   
103                                                   # ###########################################################################
104                                                   # ORDER BY
105                                                   # ###########################################################################
106            1                                  7   is_deeply(
107                                                      $sp->parse_order_by('foo'),
108                                                      [qw(foo)],
109                                                      'ORDER BY foo'
110                                                   );
111            1                                 10   is_deeply(
112                                                      $sp->parse_order_by('foo'),
113                                                      [qw(foo)],
114                                                      'order by foo'
115                                                   );
116            1                                 10   is_deeply(
117                                                      $sp->parse_order_by('foo, bar'),
118                                                      [qw(foo bar)],
119                                                      'order by foo, bar'
120                                                   );
121            1                                 10   is_deeply(
122                                                      $sp->parse_order_by('foo asc, bar'),
123                                                      ['foo asc', 'bar'],
124                                                      'order by foo asc, bar'
125                                                   );
126            1                                 10   is_deeply(
127                                                      $sp->parse_order_by('1'),
128                                                      [qw(1)],
129                                                      'ORDER BY 1'
130                                                   );
131            1                                 10   is_deeply(
132                                                      $sp->parse_order_by('RAND()'),
133                                                      ['RAND()'],
134                                                      'ORDER BY RAND()'
135                                                   );
136                                                   
137                                                   # ###########################################################################
138                                                   # LIMIT
139                                                   # ###########################################################################
140            1                                 11   is_deeply(
141                                                      $sp->parse_limit('1'),
142                                                      { row_count => 1, },
143                                                      'LIMIT 1'
144                                                   );
145            1                                 10   is_deeply(
146                                                      $sp->parse_limit('1, 2'),
147                                                      { row_count => 2,
148                                                        offset    => 1,
149                                                      },
150                                                      'LIMIT 1, 2'
151                                                   );
152            1                                 11   is_deeply(
153                                                      $sp->parse_limit('5 OFFSET 10'),
154                                                      { row_count       => 5,
155                                                        offset          => 10,
156                                                        explicit_offset => 1,
157                                                      },
158                                                      'LIMIT 5 OFFSET 10'
159                                                   );
160                                                   
161                                                   
162                                                   # ###########################################################################
163                                                   # FROM table_references
164                                                   # ###########################################################################
165                                                   sub test_from {
166           17                   17            72      my ( $from, $struct ) = @_;
167           17                                 87      is_deeply(
168                                                         $sp->parse_from($from),
169                                                         $struct,
170                                                         "FROM $from"
171                                                      );
172                                                   };
173                                                   
174            1                                 12   test_from(
175                                                      'tbl',
176                                                      [ { name => 'tbl', } ],
177                                                   );
178                                                   
179            1                                 19   test_from(
180                                                      'tbl ta',
181                                                      [ { name  => 'tbl', alias => 'ta', }  ],
182                                                   );
183                                                   
184            1                                 16   test_from(
185                                                      'tbl AS ta',
186                                                      [ { name           => 'tbl',
187                                                          alias          => 'ta',
188                                                          explicit_alias => 1,
189                                                      } ],
190                                                   );
191                                                   
192            1                                 19   test_from(
193                                                      't1, t2',
194                                                      [
195                                                         { name => 't1', },
196                                                         {
197                                                            name => 't2',
198                                                            join => {
199                                                               to    => 't1',
200                                                               type  => 'inner',
201                                                               ansi  => 0,
202                                                            },
203                                                         }
204                                                      ],
205                                                   );
206                                                   
207            1                                 21   test_from(
208                                                      't1 a, t2 as b',
209                                                      [
210                                                         { name  => 't1',
211                                                           alias => 'a',
212                                                         },
213                                                         {
214                                                           name           => 't2',
215                                                           alias          => 'b',
216                                                           explicit_alias => 1,
217                                                           join           => {
218                                                               to   => 't1',
219                                                               type => 'inner',
220                                                               ansi => 0,
221                                                            },
222                                                         }
223                                                      ],
224                                                   );
225                                                   
226                                                   
227            1                                 22   test_from(
228                                                      't1 JOIN t2 ON t1.id=t2.id',
229                                                      [
230                                                         {
231                                                            name => 't1',
232                                                         },
233                                                         {
234                                                            name => 't2',
235                                                            join => {
236                                                               to         => 't1',
237                                                               type       => '',
238                                                               condition  => 'on',
239                                                               predicates => 't1.id=t2.id ',
240                                                               ansi       => 1,
241                                                            },
242                                                         }
243                                                      ],
244                                                   );
245                                                   
246            1                                 23   test_from(
247                                                      't1 a JOIN t2 as b USING (id)',
248                                                      [
249                                                         {
250                                                            name  => 't1',
251                                                            alias => 'a',
252                                                         },
253                                                         {
254                                                            name  => 't2',
255                                                            alias => 'b',
256                                                            explicit_alias => 1,
257                                                            join  => {
258                                                               to         => 't1',
259                                                               type       => '',
260                                                               condition  => 'using',
261                                                               predicates => '(id) ',
262                                                               ansi       => 1,
263                                                            },
264                                                         },
265                                                      ],
266                                                   );
267                                                   
268            1                                 25   test_from(
269                                                      't1 JOIN t2 ON t1.id=t2.id JOIN t3 ON t1.id=t3.id',
270                                                      [
271                                                         {
272                                                            name  => 't1',
273                                                         },
274                                                         {
275                                                            name  => 't2',
276                                                            join  => {
277                                                               to         => 't1',
278                                                               type       => '',
279                                                               condition  => 'on',
280                                                               predicates => 't1.id=t2.id ',
281                                                               ansi       => 1,
282                                                            },
283                                                         },
284                                                         {
285                                                            name  => 't3',
286                                                            join  => {
287                                                               to         => 't2',
288                                                               type       => '',
289                                                               condition  => 'on',
290                                                               predicates => 't1.id=t3.id ',
291                                                               ansi       => 1,
292                                                            },
293                                                         },
294                                                      ],
295                                                   );
296                                                   
297            1                                 27   test_from(
298                                                      't1 AS a LEFT JOIN t2 b ON a.id = b.id',
299                                                      [
300                                                         {
301                                                            name  => 't1',
302                                                            alias => 'a',
303                                                            explicit_alias => 1,
304                                                         },
305                                                         {
306                                                            name  => 't2',
307                                                            alias => 'b',
308                                                            join  => {
309                                                               to         => 't1',
310                                                               type       => 'left',
311                                                               condition  => 'on',
312                                                               predicates => 'a.id = b.id ',
313                                                               ansi       => 1,
314                                                            },
315                                                         },
316                                                      ],
317                                                   );
318                                                   
319            1                                 21   test_from(
320                                                      't1 a NATURAL RIGHT OUTER JOIN t2 b',
321                                                      [
322                                                         {
323                                                            name  => 't1',
324                                                            alias => 'a',
325                                                         },
326                                                         {
327                                                            name  => 't2',
328                                                            alias => 'b',
329                                                            join  => {
330                                                               to   => 't1',
331                                                               type => 'natural right outer',
332                                                               ansi => 1,
333                                                            },
334                                                         },
335                                                      ],
336                                                   );
337                                                   
338                                                   # http://pento.net/2009/04/03/join-and-comma-precedence/
339            1                                 24   test_from(
340                                                      'a, b LEFT JOIN c ON c.c = a.a',
341                                                      [
342                                                         {
343                                                            name  => 'a',
344                                                         },
345                                                         {
346                                                            name  => 'b',
347                                                            join  => {
348                                                               to   => 'a',
349                                                               type => 'inner',
350                                                               ansi => 0,
351                                                            },
352                                                         },
353                                                         {
354                                                            name  => 'c',
355                                                            join  => {
356                                                               to         => 'b',
357                                                               type       => 'left',
358                                                               condition  => 'on',
359                                                               predicates => 'c.c = a.a ',
360                                                               ansi       => 1, 
361                                                            },
362                                                         },
363                                                      ],
364                                                   );
365                                                   
366            1                                 29   test_from(
367                                                      'a, b, c CROSS JOIN d USING (id)',
368                                                      [
369                                                         {
370                                                            name  => 'a',
371                                                         },
372                                                         {
373                                                            name  => 'b',
374                                                            join  => {
375                                                               to   => 'a',
376                                                               type => 'inner',
377                                                               ansi => 0,
378                                                            },
379                                                         },
380                                                         {
381                                                            name  => 'c',
382                                                            join  => {
383                                                               to   => 'b',
384                                                               type => 'inner',
385                                                               ansi => 0,
386                                                            },
387                                                         },
388                                                         {
389                                                            name  => 'd',
390                                                            join  => {
391                                                               to         => 'c',
392                                                               type       => 'cross',
393                                                               condition  => 'using',
394                                                               predicates => '(id) ',
395                                                               ansi       => 1, 
396                                                            },
397                                                         },
398                                                      ],
399                                                   );
400                                                   
401                                                   # Index hints.
402            1                                 22   test_from(
403                                                      'tbl FORCE INDEX (foo)',
404                                                      [
405                                                         {
406                                                            name       => 'tbl',
407                                                            index_hint => 'FORCE INDEX (foo)',
408                                                         }
409                                                      ]
410                                                   );
411                                                   
412            1                                 15   test_from(
413                                                      'tbl USE INDEX(foo)',
414                                                      [
415                                                         {
416                                                            name       => 'tbl',
417                                                            index_hint => 'USE INDEX(foo)',
418                                                         }
419                                                      ]
420                                                   );
421                                                   
422            1                                 14   test_from(
423                                                      'tbl FORCE KEY(foo)',
424                                                      [
425                                                         {
426                                                            name       => 'tbl',
427                                                            index_hint => 'FORCE KEY(foo)',
428                                                         }
429                                                      ]
430                                                   );
431                                                   
432            1                                 15   test_from(
433                                                      'tbl t FORCE KEY(foo)',
434                                                      [
435                                                         {
436                                                            name       => 'tbl',
437                                                            alias      => 't',
438                                                            index_hint => 'FORCE KEY(foo)',
439                                                         }
440                                                      ]
441                                                   );
442                                                   
443            1                                 16   test_from(
444                                                      'tbl AS t FORCE KEY(foo)',
445                                                      [
446                                                         {
447                                                            name           => 'tbl',
448                                                            alias          => 't',
449                                                            explicit_alias => 1,
450                                                            index_hint     => 'FORCE KEY(foo)',
451                                                         }
452                                                      ]
453                                                   );
454                                                   
455                                                   # #############################################################################
456                                                   # parse_identifier()
457                                                   # #############################################################################
458                                                   sub test_parse_identifier {
459           15                   15            63      my ( $tbl, $struct ) = @_;
460           15                                 77      my %s = $sp->parse_identifier($tbl);
461           15                                 90      is_deeply(
462                                                         \%s,
463                                                         $struct,
464                                                         $tbl
465                                                      );
466           15                                 94      return;
467                                                   }
468                                                   
469            1                                 14   test_parse_identifier('tbl',
470                                                      { name => 'tbl', }
471                                                   );
472                                                   
473            1                                  8   test_parse_identifier('tbl a',
474                                                      { name => 'tbl', alias => 'a', }
475                                                   );
476                                                   
477            1                                  9   test_parse_identifier('tbl as a',
478                                                      { name => 'tbl', alias => 'a', explicit_alias => 1, }
479                                                   );
480                                                   
481            1                                  9   test_parse_identifier('tbl AS a',
482                                                      { name => 'tbl', alias => 'a', explicit_alias => 1, }
483                                                   );
484                                                   
485            1                                  8   test_parse_identifier('db.tbl',
486                                                      { name => 'tbl', db => 'db', }
487                                                   );
488                                                   
489            1                                 25   test_parse_identifier('db.tbl a',
490                                                      { name => 'tbl', db => 'db', alias => 'a', }
491                                                   );
492                                                   
493            1                                 10   test_parse_identifier('db.tbl AS a',
494                                                      { name => 'tbl', db => 'db', alias => 'a', explicit_alias => 1, }
495                                                   );
496                                                   
497                                                   
498            1                                  7   test_parse_identifier('`tbl`',
499                                                      { name => 'tbl', }
500                                                   );
501                                                   
502            1                                  8   test_parse_identifier('`tbl` `a`',
503                                                      { name => 'tbl', alias => 'a', }
504                                                   );
505                                                   
506            1                                  9   test_parse_identifier('`tbl` as `a`',
507                                                      { name => 'tbl', alias => 'a', explicit_alias => 1, }
508                                                   );
509                                                   
510            1                                  9   test_parse_identifier('`tbl` AS `a`',
511                                                      { name => 'tbl', alias => 'a', explicit_alias => 1, }
512                                                   );
513                                                   
514            1                                  8   test_parse_identifier('`db`.`tbl`',
515                                                      { name => 'tbl', db => 'db', }
516                                                   );
517                                                   
518            1                                  9   test_parse_identifier('`db`.`tbl` `a`',
519                                                      { name => 'tbl', db => 'db', alias => 'a', }
520                                                   );
521                                                   
522            1                                  9   test_parse_identifier('`db`.`tbl` AS `a`',
523                                                      { name => 'tbl', db => 'db', alias => 'a', explicit_alias => 1, }
524                                                   );
525                                                   
526            1                                  9   test_parse_identifier('db.* foo',
527                                                      { name => '*', db => 'db', alias => 'foo' }
528                                                   );
529                                                   
530                                                   # #############################################################################
531                                                   # Test parsing full queries.
532                                                   # #############################################################################
533                                                   
534            1                                339   my @cases = (
535                                                   
536                                                      # ########################################################################
537                                                      # DELETE
538                                                      # ########################################################################
539                                                      {  name   => 'DELETE FROM',
540                                                         query  => 'DELETE FROM tbl',
541                                                         struct => {
542                                                            type    => 'delete',
543                                                            clauses => { from => 'tbl', },
544                                                            from    => [ { name => 'tbl', } ],
545                                                            unknown => undef,
546                                                         },
547                                                      },
548                                                      {  name   => 'DELETE FROM WHERE',
549                                                         query  => 'DELETE FROM tbl WHERE id=1',
550                                                         struct => {
551                                                            type    => 'delete',
552                                                            clauses => { 
553                                                               from  => 'tbl ',
554                                                               where => 'id=1',
555                                                            },
556                                                            from    => [ { name => 'tbl', } ],
557                                                            where   => 'id=1',
558                                                            unknown => undef,
559                                                         },
560                                                      },
561                                                      {  name   => 'DELETE FROM LIMIT',
562                                                         query  => 'DELETE FROM tbl LIMIT 5',
563                                                         struct => {
564                                                            type    => 'delete',
565                                                            clauses => {
566                                                               from  => 'tbl ',
567                                                               limit => '5',
568                                                            },
569                                                            from    => [ { name => 'tbl', } ],
570                                                            limit   => {
571                                                               row_count => 5,
572                                                            },
573                                                            unknown => undef,
574                                                         },
575                                                      },
576                                                      {  name   => 'DELETE FROM ORDER BY',
577                                                         query  => 'DELETE FROM tbl ORDER BY foo',
578                                                         struct => {
579                                                            type    => 'delete',
580                                                            clauses => {
581                                                               from     => 'tbl ',
582                                                               order_by => 'foo',
583                                                            },
584                                                            from     => [ { name => 'tbl', } ],
585                                                            order_by => [qw(foo)],
586                                                            unknown  => undef,
587                                                         },
588                                                      },
589                                                      {  name   => 'DELETE FROM WHERE LIMIT',
590                                                         query  => 'DELETE FROM tbl WHERE id=1 LIMIT 3',
591                                                         struct => {
592                                                            type    => 'delete',
593                                                            clauses => { 
594                                                               from  => 'tbl ',
595                                                               where => 'id=1 ',
596                                                               limit => '3',
597                                                            },
598                                                            from    => [ { name => 'tbl', } ],
599                                                            where   => 'id=1 ',
600                                                            limit   => {
601                                                               row_count => 3,
602                                                            },
603                                                            unknown => undef,
604                                                         },
605                                                      },
606                                                      {  name   => 'DELETE FROM WHERE ORDER BY',
607                                                         query  => 'DELETE FROM tbl WHERE id=1 ORDER BY id',
608                                                         struct => {
609                                                            type    => 'delete',
610                                                            clauses => { 
611                                                               from     => 'tbl ',
612                                                               where    => 'id=1 ',
613                                                               order_by => 'id',
614                                                            },
615                                                            from     => [ { name => 'tbl', } ],
616                                                            where    => 'id=1 ',
617                                                            order_by => [qw(id)],
618                                                            unknown  => undef,
619                                                         },
620                                                      },
621                                                      {  name   => 'DELETE FROM WHERE ORDER BY LIMIT',
622                                                         query  => 'DELETE FROM tbl WHERE id=1 ORDER BY id ASC LIMIT 1 OFFSET 3',
623                                                         struct => {
624                                                            type    => 'delete',
625                                                            clauses => { 
626                                                               from     => 'tbl ',
627                                                               where    => 'id=1 ',
628                                                               order_by => 'id ASC ',
629                                                               limit    => '1 OFFSET 3',
630                                                            },
631                                                            from    => [ { name => 'tbl', } ],
632                                                            where   => 'id=1 ',
633                                                            order_by=> ['id ASC'],
634                                                            limit   => {
635                                                               row_count       => 1,
636                                                               offset          => 3,
637                                                               explicit_offset => 1,
638                                                            },
639                                                            unknown => undef,
640                                                         },
641                                                      },
642                                                   
643                                                      # ########################################################################
644                                                      # INSERT
645                                                      # ########################################################################
646                                                      {  name   => 'INSERT INTO VALUES',
647                                                         query  => 'INSERT INTO tbl VALUES (1,"foo")',
648                                                         struct => {
649                                                            type    => 'insert',
650                                                            clauses => { 
651                                                               into   => 'tbl',
652                                                               values => '(1,"foo")',
653                                                            },
654                                                            into   => [ { name => 'tbl', } ],
655                                                            values => [ '(1,"foo")', ],
656                                                            unknown => undef,
657                                                         },
658                                                      },
659                                                      {  name   => 'INSERT VALUE',
660                                                         query  => 'INSERT tbl VALUE (1,"foo")',
661                                                         struct => {
662                                                            type    => 'insert',
663                                                            clauses => { 
664                                                               into   => 'tbl',
665                                                               values => '(1,"foo")',
666                                                            },
667                                                            into   => [ { name => 'tbl', } ],
668                                                            values => [ '(1,"foo")', ],
669                                                            unknown => undef,
670                                                         },
671                                                      },
672                                                      {  name   => 'INSERT INTO cols VALUES',
673                                                         query  => 'INSERT INTO db.tbl (id, name) VALUE (2,"bob")',
674                                                         struct => {
675                                                            type    => 'insert',
676                                                            clauses => { 
677                                                               into    => 'db.tbl',
678                                                               columns => 'id, name ',
679                                                               values  => '(2,"bob")',
680                                                            },
681                                                            into    => [ { name => 'tbl', db => 'db' } ],
682                                                            columns => [ { name => 'id' }, { name => 'name' } ],
683                                                            values  => [ '(2,"bob")', ],
684                                                            unknown => undef,
685                                                         },
686                                                      },
687                                                      {  name   => 'INSERT INTO VALUES ON DUPLICATE',
688                                                         query  => 'INSERT INTO tbl VALUE (3,"bob") ON DUPLICATE KEY UPDATE col1=9',
689                                                         struct => {
690                                                            type    => 'insert',
691                                                            clauses => { 
692                                                               into         => 'tbl',
693                                                               values       => '(3,"bob") ',
694                                                               on_duplicate => 'col1=9',
695                                                            },
696                                                            into         => [ { name => 'tbl', } ],
697                                                            values       => [ '(3,"bob")', ],
698                                                            on_duplicate => ['col1=9',],
699                                                            unknown      => undef,
700                                                         },
701                                                      },
702                                                      {  name   => 'INSERT INTO SET',
703                                                         query  => 'INSERT INTO tbl SET id=1, foo=NULL',
704                                                         struct => {
705                                                            type    => 'insert',
706                                                            clauses => { 
707                                                               into => 'tbl',
708                                                               set  => 'id=1, foo=NULL',
709                                                            },
710                                                            into    => [ { name => 'tbl', } ],
711                                                            set     => ['id=1', 'foo=NULL',],
712                                                            unknown => undef,
713                                                         },
714                                                      },
715                                                      {  name   => 'INSERT INTO SET ON DUPLICATE',
716                                                         query  => 'INSERT INTO tbl SET i=3 ON DUPLICATE KEY UPDATE col1=9',
717                                                         struct => {
718                                                            type    => 'insert',
719                                                            clauses => { 
720                                                               into         => 'tbl',
721                                                               set          => 'i=3 ',
722                                                               on_duplicate => 'col1=9',
723                                                            },
724                                                            into         => [ { name => 'tbl', } ],
725                                                            set          => ['i=3',],
726                                                            on_duplicate => ['col1=9',],
727                                                            unknown      => undef,
728                                                         },
729                                                      },
730                                                      {  name   => 'INSERT ... SELECT',
731                                                         query  => 'INSERT INTO tbl (col) SELECT id FROM tbl2 WHERE id > 100',
732                                                         struct => {
733                                                            type    => 'insert',
734                                                            clauses => { 
735                                                               into    => 'tbl',
736                                                               columns => 'col ',
737                                                               select  => 'id FROM tbl2 WHERE id > 100',
738                                                            },
739                                                            into         => [ { name => 'tbl', } ],
740                                                            columns      => [ { name => 'col' } ],
741                                                            select       => {
742                                                               clauses => { 
743                                                                  columns => 'id ',
744                                                                  from    => 'tbl2 ',
745                                                                  where   => 'id > 100',
746                                                               },
747                                                               columns => [ { name => 'id' } ],
748                                                               from    => [ { name => 'tbl2', } ],
749                                                               where   => 'id > 100',
750                                                               unknown => undef,
751                                                            },
752                                                            unknown      => undef,
753                                                         },
754                                                      },
755                                                      {  name   => 'INSERT INTO VALUES()',
756                                                         query  => 'INSERT INTO db.tbl (id, name) VALUES(2,"bob")',
757                                                         struct => {
758                                                            type    => 'insert',
759                                                            clauses => { 
760                                                               into    => 'db.tbl',
761                                                               columns => 'id, name ',
762                                                               values  => '(2,"bob")',
763                                                            },
764                                                            into    => [ { name => 'tbl', db => 'db' } ],
765                                                            columns => [ { name => 'id' }, { name => 'name' } ],
766                                                            values  => [ '(2,"bob")', ],
767                                                            unknown => undef,
768                                                         },
769                                                      },
770                                                   
771                                                      # ########################################################################
772                                                      # REPLACE
773                                                      # ########################################################################
774                                                      # REPLACE are parsed by parse_insert() so if INSERT is well-tested we
775                                                      # shouldn't need to test REPLACE much.
776                                                      {  name   => 'REPLACE INTO VALUES',
777                                                         query  => 'REPLACE INTO tbl VALUES (1,"foo")',
778                                                         struct => {
779                                                            type    => 'replace',
780                                                            clauses => { 
781                                                               into   => 'tbl',
782                                                               values => '(1,"foo")',
783                                                            },
784                                                            into   => [ { name => 'tbl', } ],
785                                                            values => [ '(1,"foo")', ],
786                                                            unknown => undef,
787                                                         },
788                                                      },
789                                                      {  name   => 'REPLACE VALUE',
790                                                         query  => 'REPLACE tbl VALUE (1,"foo")',
791                                                         struct => {
792                                                            type    => 'replace',
793                                                            clauses => { 
794                                                               into   => 'tbl',
795                                                               values => '(1,"foo")',
796                                                            },
797                                                            into   => [ { name => 'tbl', } ],
798                                                            values => [ '(1,"foo")', ],
799                                                            unknown => undef,
800                                                         },
801                                                      },
802                                                      {  name   => 'REPLACE INTO cols VALUES',
803                                                         query  => 'REPLACE INTO db.tbl (id, name) VALUE (2,"bob")',
804                                                         struct => {
805                                                            type    => 'replace',
806                                                            clauses => { 
807                                                               into    => 'db.tbl',
808                                                               columns => 'id, name ',
809                                                               values  => '(2,"bob")',
810                                                            },
811                                                            into    => [ { name => 'tbl', db => 'db' } ],
812                                                            columns => [ { name => 'id' }, { name => 'name' } ],
813                                                            values  => [ '(2,"bob")', ],
814                                                            unknown => undef,
815                                                         },
816                                                      },
817                                                   
818                                                      # ########################################################################
819                                                      # SELECT
820                                                      # ########################################################################
821                                                      {  name   => 'SELECT',
822                                                         query  => 'SELECT NOW()',
823                                                         struct => {
824                                                            type    => 'select',
825                                                            clauses => { 
826                                                               columns => 'NOW()',
827                                                            },
828                                                            columns => [ { name => 'NOW()' } ],
829                                                            unknown => undef,
830                                                         },
831                                                      },
832                                                      {  name   => 'SELECT FROM',
833                                                         query  => 'SELECT col1, col2 FROM tbl',
834                                                         struct => {
835                                                            type    => 'select',
836                                                            clauses => { 
837                                                               columns => 'col1, col2 ',
838                                                               from    => 'tbl',
839                                                            },
840                                                            columns => [ { name => 'col1' }, { name => 'col2' } ],
841                                                            from    => [ { name => 'tbl', } ],
842                                                            unknown => undef,
843                                                         },
844                                                      },
845                                                      {  name   => 'SELECT FROM JOIN WHERE GROUP BY ORDER BY LIMIT',
846                                                         query  => '/* nonsensical but covers all the basic clauses */
847                                                            SELECT t1.col1 a, t1.col2 as b
848                                                            FROM tbl1 t1
849                                                               LEFT JOIN tbl2 AS t2 ON t1.id = t2.id
850                                                            WHERE
851                                                               t2.col IS NOT NULL
852                                                               AND t2.name = "bob"
853                                                            GROUP BY a, b
854                                                            ORDER BY t2.name ASC
855                                                            LIMIT 100, 10
856                                                         ',
857                                                         struct => {
858                                                            type    => 'select',
859                                                            clauses => { 
860                                                               columns  => 't1.col1 a, t1.col2 as b ',
861                                                               from     => 'tbl1 t1 LEFT JOIN tbl2 AS t2 ON t1.id = t2.id ',
862                                                               where    => 't2.col IS NOT NULL AND t2.name = "bob" ',
863                                                               group_by => 'a, b ',
864                                                               order_by => 't2.name ASC ',
865                                                               limit    => '100, 10',
866                                                            },
867                                                            columns => [ { name => 'col1', db => 't1', alias => 'a' },
868                                                                         { name => 'col2', db => 't1', alias => 'b',
869                                                                           explicit_alias => 1 } ],
870                                                            from    => [
871                                                               {
872                                                                  name  => 'tbl1',
873                                                                  alias => 't1',
874                                                               },
875                                                               {
876                                                                  name  => 'tbl2',
877                                                                  alias => 't2',
878                                                                  explicit_alias => 1,
879                                                                  join  => {
880                                                                     to        => 'tbl1',
881                                                                     type      => 'left',
882                                                                     condition => 'on',
883                                                                     predicates=> 't1.id = t2.id  ',
884                                                                     ansi      => 1,
885                                                                  },
886                                                               },
887                                                            ],
888                                                            where    => 't2.col IS NOT NULL AND t2.name = "bob" ',
889                                                            group_by => { columns => [qw(a b)], },
890                                                            order_by => ['t2.name ASC'],
891                                                            limit    => {
892                                                               row_count => 10,
893                                                               offset    => 100,
894                                                            },
895                                                            unknown => undef,
896                                                         },
897                                                      },
898                                                      {  name   => 'SELECT FROM JOIN ON() JOIN USING() WHERE',
899                                                         query  => 'SELECT t1.col1 a, t1.col2 as b
900                                                   
901                                                            FROM tbl1 t1
902                                                   
903                                                               JOIN tbl2 AS t2 ON(t1.id = t2.id)
904                                                   
905                                                               JOIN tbl3 t3 USING(id) 
906                                                   
907                                                            WHERE
908                                                               t2.col IS NOT NULL',
909                                                         struct => {
910                                                            type    => 'select',
911                                                            clauses => { 
912                                                               columns  => 't1.col1 a, t1.col2 as b ',
913                                                               from     => 'tbl1 t1 JOIN tbl2 AS t2 on (t1.id = t2.id) JOIN tbl3 t3 using (id) ',
914                                                               where    => 't2.col IS NOT NULL',
915                                                            },
916                                                            columns => [ { name => 'col1', db => 't1', alias => 'a' },
917                                                                         { name => 'col2', db => 't1', alias => 'b',
918                                                                           explicit_alias => 1 } ],
919                                                            from    => [
920                                                               {
921                                                                  name  => 'tbl1',
922                                                                  alias => 't1',
923                                                               },
924                                                               {
925                                                                  name  => 'tbl2',
926                                                                  alias => 't2',
927                                                                  explicit_alias => 1,
928                                                                  join  => {
929                                                                     to        => 'tbl1',
930                                                                     type      => '',
931                                                                     condition => 'on',
932                                                                     predicates=> '(t1.id = t2.id) ',
933                                                                     ansi      => 1,
934                                                                  },
935                                                               },
936                                                               {
937                                                                  name  => 'tbl3',
938                                                                  alias => 't3',
939                                                                  join  => {
940                                                                     to        => 'tbl2',
941                                                                     type      => '',
942                                                                     condition => 'using',
943                                                                     predicates=> '(id)  ',
944                                                                     ansi      => 1,
945                                                                  },
946                                                               },
947                                                            ],
948                                                            where    => 't2.col IS NOT NULL',
949                                                            unknown => undef,
950                                                         },
951                                                      },
952                                                      {  name   => 'SELECT keywords',
953                                                         query  => 'SELECT all high_priority SQL_CALC_FOUND_ROWS NOW() LOCK IN SHARE MODE',
954                                                         struct => {
955                                                            type     => 'select',
956                                                            clauses  => { 
957                                                               columns => 'NOW()',
958                                                            },
959                                                            columns  => [ { name => 'NOW()' } ],
960                                                            keywords => {
961                                                               all                 => 1,
962                                                               high_priority       => 1,
963                                                               sql_calc_found_rows => 1,
964                                                               lock_in_share_mode  => 1,
965                                                            },
966                                                            unknown  => undef,
967                                                         },
968                                                      },
969                                                      { name   => 'SELECT * FROM WHERE',
970                                                        query  => 'SELECT * FROM tbl WHERE ip="127.0.0.1"',
971                                                        struct => {
972                                                            type     => 'select',
973                                                            clauses  => { 
974                                                               columns => '* ',
975                                                               from    => 'tbl ',
976                                                               where   => 'ip="127.0.0.1"',
977                                                            },
978                                                            columns  => [ { name => '*' } ],
979                                                            from     => [ { name => 'tbl' } ],
980                                                            where    => 'ip="127.0.0.1"',
981                                                            unknown  => undef,
982                                                         },
983                                                      },
984                                                   
985                                                      # ########################################################################
986                                                      # UPDATE
987                                                      # ########################################################################
988                                                      {  name   => 'UPDATE SET',
989                                                         query  => 'UPDATE tbl SET col=1',
990                                                         struct => {
991                                                            type    => 'update',
992                                                            clauses => { 
993                                                               tables => 'tbl ',
994                                                               set    => 'col=1',
995                                                            },
996                                                            tables  => [ { name => 'tbl', } ],
997                                                            set     => ['col=1'],
998                                                            unknown => undef,
999                                                         },
1000                                                     },
1001                                                     {  name   => 'UPDATE SET WHERE ORDER BY LIMIT',
1002                                                        query  => 'UPDATE tbl AS t SET foo=NULL WHERE foo IS NOT NULL ORDER BY id LIMIT 10',
1003                                                        struct => {
1004                                                           type    => 'update',
1005                                                           clauses => { 
1006                                                              tables   => 'tbl AS t ',
1007                                                              set      => 'foo=NULL ',
1008                                                              where    => 'foo IS NOT NULL ',
1009                                                              order_by => 'id ',
1010                                                              limit    => '10',
1011                                                           },
1012                                                           tables   => [ { name => 'tbl', alias => 't', explicit_alias => 1, } ],
1013                                                           set      => ['foo=NULL'],
1014                                                           where    => 'foo IS NOT NULL ',
1015                                                           order_by => ['id'],
1016                                                           limit    => { row_count => 10 },
1017                                                           unknown => undef,
1018                                                        },
1019                                                     },
1020                                                  );
1021                                                  
1022           1                                 11   foreach my $test ( @cases ) {
1023          26                                365      my $struct = $sp->parse($test->{query});
1024          26                                178      is_deeply(
1025                                                        $struct,
1026                                                        $test->{struct},
1027                                                        $test->{name},
1028                                                     );
1029                                                  }
1030                                                  
1031                                                  # #############################################################################
1032                                                  # Done.
1033                                                  # #############################################################################
1034           1                                  4   exit;


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
test_from                17 SQLParser.t:166
test_parse_identifier    15 SQLParser.t:459


