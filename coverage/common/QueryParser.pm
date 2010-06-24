---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryParser.pm   76.3   63.9   62.5   76.5    0.0   87.4   70.0
QueryParser.t                 100.0   50.0   33.3  100.0    n/a   12.6   98.0
Total                          85.4   63.5   59.3   84.6    0.0  100.0   78.5
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:58 2010
Finish:       Thu Jun 24 19:35:58 2010

Run:          QueryParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:35:59 2010
Finish:       Thu Jun 24 19:36:00 2010

/home/daniel/dev/maatkit/common/QueryParser.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2008-2009 Percona Inc.
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
18                                                    # QueryParser package $Revision: 6262 $
19                                                    # ###########################################################################
20                                                    package QueryParser;
21                                                    
22             1                    1           126   use strict;
               1                                  3   
               1                                  6   
23             1                    1             5   use warnings FATAL => 'all';
               1                                  2   
               1                                  6   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26    ***      1            50      1            11   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  2   
               1                                 19   
27                                                    our $tbl_ident = qr/(?:`[^`]+`|\w+)(?:\.(?:`[^`]+`|\w+))?/;
28                                                    # This regex finds things that look like database.table identifiers, based on
29                                                    # their proximity to keywords.  (?<!KEY\s) is a workaround for ON DUPLICATE KEY
30                                                    # UPDATE, which is usually followed by a column name.
31                                                    our $tbl_regex = qr{
32                                                             \b(?:FROM|JOIN|(?<!KEY\s)UPDATE|INTO) # Words that precede table names
33                                                             \b\s*
34                                                             \(?                                   # Optional paren around tables
35                                                             # Capture the identifier and any number of comma-join identifiers that
36                                                             # follow it, optionally with aliases with or without the AS keyword
37                                                             ($tbl_ident
38                                                                (?: (?:\s+ (?:AS\s+)? \w+)?, \s*$tbl_ident )*
39                                                             )
40                                                          }xio;
41                                                    # This regex is meant to match "derived table" queries, of the form
42                                                    # .. from ( select ...
43                                                    # .. join ( select ...
44                                                    # .. bar join foo, ( select ...
45                                                    # Unfortunately it'll also match this:
46                                                    # select a, b, (select ...
47                                                    our $has_derived = qr{
48                                                          \b(?:FROM|JOIN|,)
49                                                          \s*\(\s*SELECT
50                                                       }xi;
51                                                    
52                                                    # http://dev.mysql.com/doc/refman/5.1/en/sql-syntax-data-definition.html
53                                                    # We treat TRUNCATE as a dds but really it's a data manipulation statement.
54                                                    our $data_def_stmts = qr/(?:CREATE|ALTER|TRUNCATE|DROP|RENAME)/i;
55                                                    
56                                                    # http://dev.mysql.com/doc/refman/5.1/en/sql-syntax-data-manipulation.html
57                                                    # Data manipulation statements.
58                                                    our $data_manip_stmts = qr/(?:INSERT|UPDATE|DELETE|REPLACE)/i;
59                                                    
60                                                    sub new {
61    ***      1                    1      0      5      my ( $class ) = @_;
62             1                                 12      bless {}, $class;
63                                                    }
64                                                    
65                                                    # Returns a list of table names found in the query text.
66                                                    sub get_tables {
67    ***     68                   68      0    327      my ( $self, $query ) = @_;
68    ***     68     50                         263      return unless $query;
69            68                                151      MKDEBUG && _d('Getting tables for', $query);
70                                                    
71                                                       # Handle CREATE, ALTER, TRUNCATE and DROP TABLE.
72            68                                596      my ( $ddl_stmt ) = $query =~ m/^\s*($data_def_stmts)\b/i;
73            68    100                         249      if ( $ddl_stmt ) {
74            10                                 21         MKDEBUG && _d('Special table type:', $ddl_stmt);
75            10                                 42         $query =~ s/IF NOT EXISTS//i;
76            10    100                         134         if ( $query =~ m/$ddl_stmt DATABASE\b/i ) {
77                                                             # Handles CREATE DATABASE, not to be confused with CREATE TABLE.
78             1                                  2            MKDEBUG && _d('Query alters a database, not a table');
79             1                                  7            return ();
80                                                          }
81             9    100    100                  115         if ( $ddl_stmt =~ m/CREATE/i && $query =~ m/$ddl_stmt\b.+?\bSELECT\b/i ) {
82                                                             # Handle CREATE TABLE ... SELECT.  In this case, the real tables
83                                                             # come from the SELECT, not the CREATE.
84             2                                 18            my ($select) = $query =~ m/\b(SELECT\b.+)/is;
85             2                                  5            MKDEBUG && _d('CREATE TABLE ... SELECT:', $select);
86             2                                 13            return $self->get_tables($select);
87                                                          }
88             7                                 99         my ($tbl) = $query =~ m/TABLE\s+($tbl_ident)(\s+.*)?/i;
89             7                                 16         MKDEBUG && _d('Matches table:', $tbl);
90             7                                 52         return ($tbl);
91                                                       }
92                                                    
93                                                       # These keywords may appear between UPDATE or SELECT and the table refs.
94                                                       # They need to be removed so that they are not mistaken for tables.
95            58                                350      $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;
96                                                    
97                                                       # Another special case: LOCK TABLES tbl [[AS] alias] READ|WRITE, etc.
98                                                       # We strip the LOCK TABLES stuff and append "FROM" to fake a SELECT
99                                                       # statement and allow $tbl_regex to match below.
100           58    100                         251      if ( $query =~ /^\s*LOCK TABLES/i ) {
101            7                                 29         MKDEBUG && _d('Special table type: LOCK TABLES');
102            7                                 42         $query =~ s/^(\s*LOCK TABLES\s+)//;
103            7                                 53         $query =~ s/\s+(?:READ|WRITE|LOCAL)+\s*//g;
104            7                                 19         MKDEBUG && _d('Locked tables:', $query);
105            7                                 26         $query = "FROM $query";
106                                                      }
107                                                   
108           58                                183      $query =~ s/\\["']//g;                # quoted strings
109           58                                169      $query =~ s/".*?"/?/sg;               # quoted strings
110           58                                171      $query =~ s/'.*?'/?/sg;               # quoted strings
111                                                   
112           58                                135      my @tables;
113           58                               1001      foreach my $tbls ( $query =~ m/$tbl_regex/gio ) {
114           77                                170         MKDEBUG && _d('Match tables:', $tbls);
115                                                   
116                                                         # Some queries coming from certain ORM systems will have superfluous
117                                                         # parens around table names, like SELECT * FROM (`mytable`);  We match
118                                                         # these so the table names can be extracted more simply with regexes.  But
119                                                         # in case of subqueries, this can cause us to match SELECT as a table
120                                                         # name, for example, in SELECT * FROM (SELECT ....) AS X;  It's possible
121                                                         # that SELECT is really a table name, but so unlikely that we just skip
122                                                         # this case.
123           77    100                         306         next if $tbls =~ m/\ASELECT\b/i;
124                                                   
125           74                                315         foreach my $tbl ( split(',', $tbls) ) {
126                                                            # Remove implicit or explicit (AS) alias.
127           94                                927            $tbl =~ s/\s*($tbl_ident)(\s+.*)?/$1/gio;
128                                                   
129                                                            # Sanity check for cases like when a column is named `from`
130                                                            # and the regex matches junk.  Instead of complex regex to
131                                                            # match around these rarities, this simple check will save us.
132           94    100                         435            if ( $tbl !~ m/[a-zA-Z]/ ) {
133            2                                  6               MKDEBUG && _d('Skipping suspicious table name:', $tbl);
134            2                                  8               next;
135                                                            }
136                                                   
137           92                                516            push @tables, $tbl;
138                                                         }
139                                                      }
140           58                                465      return @tables;
141                                                   }
142                                                   
143                                                   # Returns true if it sees what looks like a "derived table", e.g. a subquery in
144                                                   # the FROM clause.
145                                                   sub has_derived_table {
146   ***      5                    5      0     23      my ( $self, $query ) = @_;
147                                                      # See the $tbl_regex regex above.
148            5                                 50      my $match = $query =~ m/$has_derived/;
149            5                                 12      MKDEBUG && _d($query, 'has ' . ($match ? 'a' : 'no') . ' derived table');
150            5                                 29      return $match;
151                                                   }
152                                                   
153                                                   # Return a data structure of tables/databases and the name they're aliased to.
154                                                   # Given the following query, SELECT * FROM db.tbl AS foo; the structure is:
155                                                   # { TABLE => { foo => tbl }, DATABASE => { tbl => db } }
156                                                   # If $list is true, then a flat list of tables found in the query is returned
157                                                   # instead.  This is used for things that want to know what tables the query
158                                                   # touches, but don't care about aliases.
159                                                   sub get_aliases {
160   ***     41                   41      0    205      my ( $self, $query, $list ) = @_;
161                                                   
162                                                      # This is the basic result every query must return.
163           41                                212      my $result = {
164                                                         DATABASE => {},
165                                                         TABLE    => {},
166                                                      };
167   ***     41     50                         152      return $result unless $query;
168                                                   
169                                                      # These keywords may appear between UPDATE or SELECT and the table refs.
170                                                      # They need to be removed so that they are not mistaken for tables.
171           41                                251      $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;
172                                                   
173                                                      # These keywords may appear before JOIN. They need to be removed so
174                                                      # that they are not mistaken for implicit aliases of the preceding table.
175           41                                210      $query =~ s/ (?:INNER|OUTER|CROSS|LEFT|RIGHT|NATURAL)//ig;
176                                                   
177                                                      # Get the table references clause and the keyword that starts the clause.
178                                                      # See the comments below for why we need the starting keyword.
179           41                                101      my @tbl_refs;
180           41                                581      my ($tbl_refs, $from) = $query =~ m{
181                                                         (
182                                                            (FROM|INTO|UPDATE)\b\s*   # Keyword before table refs
183                                                            .+?                       # Table refs
184                                                         )
185                                                         (?:\s+|\z)                   # If the query does not end with the table
186                                                                                      # refs then there must be at least 1 space
187                                                                                      # between the last tbl ref and the next
188                                                                                      # keyword
189                                                         (?:WHERE|ORDER|LIMIT|HAVING|SET|VALUES|\z) # Keyword after table refs
190                                                      }ix;
191                                                   
192           41    100                         157      if ( $tbl_refs ) {
193                                                   
194           40    100                         190         if ( $query =~ m/^(?:INSERT|REPLACE)/i ) {
195                                                            # Remove optional columns def from INSERT/REPLACE.
196            3                                 15            $tbl_refs =~ s/\([^\)]+\)\s*//;
197                                                         }
198                                                   
199           40                                 87         MKDEBUG && _d('tbl refs:', $tbl_refs);
200                                                   
201                                                         # These keywords precede a table ref. They signal the start of a table
202                                                         # ref, but to know where the table ref ends we need the after tbl ref
203                                                         # keywords below.
204           40                                536         my $before_tbl = qr/(?:,|JOIN|\s|$from)+/i;
205                                                   
206                                                         # These keywords signal the end of a table ref and either 1) the start
207                                                         # of another table ref, or 2) the start of an ON|USING part of a JOIN
208                                                         # clause (which we want to skip over), or 3) the end of the string (\z).
209                                                         # We need these after tbl ref keywords so that they are not mistaken
210                                                         # for implicit aliases of the preceding table.
211           40                                144         my $after_tbl  = qr/(?:,|JOIN|ON|USING|\z)/i;
212                                                   
213                                                         # This is required for cases like:
214                                                         #    FROM t1 JOIN t2 ON t1.col1=t2.col2 JOIN t3 ON t2.col3 = t3.col4
215                                                         # Because spaces may precede a tbl and a tbl may end with \z, then
216                                                         # t3.col4 will match as a table. However, t2.col3=t3.col4 will not match.
217           40                                144         $tbl_refs =~ s/ = /=/g;
218                                                   
219           40                                579         while (
220                                                            $tbl_refs =~ m{
221                                                               $before_tbl\b\s*
222                                                                  ( ($tbl_ident) (?:\s+ (?:AS\s+)? (\w+))? )
223                                                               \s*$after_tbl
224                                                            }xgio )
225                                                         {
226           67                                397            my ( $tbl_ref, $db_tbl, $alias ) = ($1, $2, $3);
227           67                                157            MKDEBUG && _d('Match table:', $tbl_ref);
228           67                                218            push @tbl_refs, $tbl_ref;
229           67                                295            $alias = $self->trim_identifier($alias);
230                                                   
231                                                            # Handle subqueries.
232           67    100                         270            if ( $tbl_ref =~ m/^AS\s+\w+/i ) {
233                                                               # According to the manual
234                                                               # http://dev.mysql.com/doc/refman/5.0/en/unnamed-views.html:
235                                                               # "The [AS] name  clause is mandatory, because every table in a
236                                                               # FROM clause must have a name."
237                                                               # So if the tbl ref begins with 'AS', then we probably have a
238                                                               # subquery.
239            1                                  3               MKDEBUG && _d('Subquery', $tbl_ref);
240            1                                  4               $result->{TABLE}->{$alias} = undef;
241            1                                 11               next;
242                                                            }
243                                                   
244           66                                389            my ( $db, $tbl ) = $db_tbl =~ m/^(?:(.*?)\.)?(.*)/;
245           66                                254            $db  = $self->trim_identifier($db);
246           66                                239            $tbl = $self->trim_identifier($tbl);
247   ***     66            66                  474            $result->{TABLE}->{$alias || $tbl} = $tbl;
248           66    100                         846            $result->{DATABASE}->{$tbl}        = $db if $db;
249                                                         }
250                                                      }
251                                                      else {
252            1                                  3         MKDEBUG && _d("No tables ref in", $query);
253                                                      }
254                                                   
255           41    100                         139      if ( $list ) {
256                                                         # Return raw text of the tbls without aliases, instead of identifier
257                                                         # mappings.  Include all identifier quotings and such.
258            1                                  9         return \@tbl_refs;
259                                                      }
260                                                      else {
261           40                                276         return $result;
262                                                      }
263                                                   }
264                                                   
265                                                   # Splits a compound statement and returns an array with each sub-statement.
266                                                   # Example:
267                                                   #    INSERT INTO ... SELECT ...
268                                                   # is split into two statements: "INSERT INTO ..." and "SELECT ...".
269                                                   sub split {
270   ***      9                    9      0     41      my ( $self, $query ) = @_;
271   ***      9     50                          35      return unless $query;
272            9                                 37      $query = $self->clean_query($query);
273            9                                 21      MKDEBUG && _d('Splitting', $query);
274                                                   
275            9                                 51      my $verbs = qr{SELECT|INSERT|UPDATE|DELETE|REPLACE|UNION|CREATE}i;
276                                                   
277                                                      # This splits a statement on the above verbs which means that the verb
278                                                      # gets chopped out.  Capturing the verb (e.g. ($verb)) will retain it,
279                                                      # but then it's disjointed from its statement.  Example: for this query,
280                                                      #   INSERT INTO ... SELECT ...
281                                                      # split returns ('INSERT', 'INTO ...', 'SELECT', '...').  Therefore,
282                                                      # we must re-attach each verb to its statement; we do this later...
283            9                                176      my @split_statements = grep { $_ } split(m/\b($verbs\b(?!(?:\s*\()))/io, $query);
              37                                122   
284                                                   
285            9                                 28      my @statements;
286   ***      9     50                          35      if ( @split_statements == 1 ) {
287                                                         # This happens if the query has no verbs, so it's probably a single
288                                                         # statement.
289   ***      0                                  0         push @statements, $query;
290                                                      }
291                                                      else {
292                                                         # ...Re-attach verbs to their statements.
293                                                         for ( my $i = 0; $i <= $#split_statements; $i += 2 ) {
294           14                                 64            push @statements, $split_statements[$i].$split_statements[$i+1];
295                                                   
296                                                            # Variable-width negative look-behind assertions, (?<!), aren't
297                                                            # fully supported so we split ON DUPLICATE KEY UPDATE.  This
298                                                            # puts it back together.
299           14    100    100                  139            if ( $statements[-2] && $statements[-2] =~ m/on duplicate key\s+$/i ) {
300            1                                  8               $statements[-2] .= pop @statements;
301                                                            }
302            9                                 26         }
303                                                      }
304                                                   
305                                                      # Wrap stmts in <> to make it more clear where each one begins/ends.
306            9                                 24      MKDEBUG && _d('statements:', map { $_ ? "<$_>" : 'none' } @statements);
307            9                                 97      return @statements;
308                                                   }
309                                                   
310                                                   sub clean_query {
311   ***     10                   10      0     38      my ( $self, $query ) = @_;
312   ***     10     50                          37      return unless $query;
313           10                                 36      $query =~ s!/\*.*?\*/! !g;  # Remove /* comment blocks */
314           10                                 38      $query =~ s/^\s+//;         # Remove leading spaces
315           10                                 59      $query =~ s/\s+$//;         # Remove trailing spaces
316           10                                 50      $query =~ s/\s{2,}/ /g;     # Remove extra spaces
317           10                                 38      return $query;
318                                                   }
319                                                   
320                                                   sub split_subquery {
321   ***      1                    1      0      5      my ( $self, $query ) = @_;
322   ***      1     50                           5      return unless $query;
323            1                                  4      $query = $self->clean_query($query);
324            1                                  7      $query =~ s/;$//;
325                                                   
326            1                                  2      my @subqueries;
327            1                                  3      my $sqno = 0;  # subquery number
328            1                                  4      my $pos  = 0;
329            1                                  7      while ( $query =~ m/(\S+)(?:\s+|\Z)/g ) {
330           11                                 31         $pos = pos($query);
331           11                                 36         my $word = $1;
332           11                                 23         MKDEBUG && _d($word, $sqno);
333           11    100                          41         if ( $word =~ m/^\(?SELECT\b/i ) {
334            2                                  7            my $start_pos = $pos - length($word) - 1;
335            2    100                           7            if ( $start_pos ) {
336            1                                  3               $sqno++;
337            1                                  3               MKDEBUG && _d('Subquery', $sqno, 'starts at', $start_pos);
338            1                                 14               $subqueries[$sqno] = {
339                                                                  start_pos => $start_pos,
340                                                                  end_pos   => 0,
341                                                                  len       => 0,
342                                                                  words     => [$word],
343                                                                  lp        => 1, # left parentheses
344                                                                  rp        => 0, # right parentheses
345                                                                  done      => 0,
346                                                               };
347                                                            }
348                                                            else {
349            1                                  6               MKDEBUG && _d('Main SELECT at pos 0');
350                                                            }
351                                                         }
352                                                         else {
353            9    100                          45            next unless $sqno;  # next unless we're in a subquery
354            3                                  6            MKDEBUG && _d('In subquery', $sqno);
355            3                                 12            my $sq = $subqueries[$sqno];
356   ***      3     50                          13            if ( $sq->{done} ) {
357   ***      0                                  0               MKDEBUG && _d('This subquery is done; SQL is for',
358                                                                  ($sqno - 1 ? "subquery $sqno" : "the main SELECT"));
359   ***      0                                  0               next;
360                                                            }
361            3                                  7            push @{$sq->{words}}, $word;
               3                                 13   
362   ***      3            50                   32            my $lp = ($word =~ tr/\(//) || 0;
363            3           100                   23            my $rp = ($word =~ tr/\)//) || 0;
364            3                                  7            MKDEBUG && _d('parentheses left', $lp, 'right', $rp);
365            3    100                          25            if ( ($sq->{lp} + $lp) - ($sq->{rp} + $rp) == 0 ) {
366            1                                  3               my $end_pos = $pos - 1;
367            1                                  2               MKDEBUG && _d('Subquery', $sqno, 'ends at', $end_pos);
368            1                                  3               $sq->{end_pos} = $end_pos;
369            1                                  7               $sq->{len}     = $end_pos - $sq->{start_pos};
370                                                            }
371                                                         }
372                                                      }
373                                                   
374            1                                  8      for my $i ( 1..$#subqueries ) {
375            1                                  4         my $sq = $subqueries[$i];
376   ***      1     50                           4         next unless $sq;
377            1                                  2         $sq->{sql} = join(' ', @{$sq->{words}});
               1                                 16   
378            1                                 10         substr $query,
379                                                            $sq->{start_pos} + 1,  # +1 for (
380                                                            $sq->{len} - 1,        # -1 for )
381                                                            "__subquery_$i";
382                                                      }
383                                                   
384            1                                  4      return $query, map { $_->{sql} } grep { defined $_ } @subqueries;
               1                                 13   
               2                                  7   
385                                                   }
386                                                   
387                                                   sub query_type {
388   ***     10                   10      0     48      my ( $self, $query, $qr ) = @_;
389           10                                 61      my ($type, undef) = $qr->distill_verbs($query);
390           10                                195      my $rw;
391           10    100    100                  175      if ( $type =~ m/^SELECT\b/ ) {
                    100                               
392            2                                  7         $rw = 'read';
393                                                      }
394                                                      elsif ( $type =~ m/^$data_manip_stmts\b/
395                                                              || $type =~ m/^$data_def_stmts\b/  ) {
396            6                                 19         $rw = 'write'
397                                                      }
398                                                   
399                                                      return {
400           10                                 93         type => $type,
401                                                         rw   => $rw,
402                                                      }
403                                                   }
404                                                   
405                                                   sub get_columns {
406   ***      0                    0      0      0      my ( $self, $query ) = @_;
407   ***      0                                  0      my $cols = [];
408   ***      0      0                           0      return $cols unless $query;
409   ***      0                                  0      my $cols_def;
410                                                   
411   ***      0      0                           0      if ( $query =~ m/^SELECT/i ) {
      ***             0                               
412   ***      0                                  0         $query =~ s/
413                                                            ^SELECT\s+
414                                                              (?:ALL
415                                                                 |DISTINCT
416                                                                 |DISTINCTROW
417                                                                 |HIGH_PRIORITY
418                                                                 |STRAIGHT_JOIN
419                                                                 |SQL_SMALL_RESULT
420                                                                 |SQL_BIG_RESULT
421                                                                 |SQL_BUFFER_RESULT
422                                                                 |SQL_CACHE
423                                                                 |SQL_NO_CACHE
424                                                                 |SQL_CALC_FOUND_ROWS
425                                                              )\s+
426                                                         /SELECT /xgi;
427   ***      0                                  0         ($cols_def) = $query =~ m/^SELECT\s+(.+?)\s+FROM/i;
428                                                      }
429                                                      elsif ( $query =~ m/^(?:INSERT|REPLACE)/i ) {
430   ***      0                                  0         ($cols_def) = $query =~ m/\(([^\)]+)\)\s*VALUE/i;
431                                                      }
432                                                   
433   ***      0                                  0      MKDEBUG && _d('Columns:', $cols_def);
434   ***      0      0                           0      if ( $cols_def ) {
435   ***      0                                  0         @$cols = split(',', $cols_def);
436   ***      0                                  0         map {
437   ***      0                                  0            my $col = $_;
438   ***      0                                  0            $col = s/^\s+//g;
439   ***      0                                  0            $col = s/\s+$//g;
440   ***      0                                  0            $col;
441                                                         } @$cols;
442                                                      }
443                                                   
444   ***      0                                  0      return $cols;
445                                                   }
446                                                   
447                                                   sub parse {
448   ***      0                    0      0      0      my ( $self, $query ) = @_;
449   ***      0      0                           0      return unless $query;
450   ***      0                                  0      my $parsed = {};
451                                                   
452                                                      # Flatten and clean query.
453   ***      0                                  0      $query =~ s/\n/ /g;
454   ***      0                                  0      $query = $self->clean_query($query);
455                                                   
456   ***      0                                  0      $parsed->{query}   = $query,
457                                                      $parsed->{tables}  = $self->get_aliases($query, 1);
458   ***      0                                  0      $parsed->{columns} = $self->get_columns($query);
459                                                   
460   ***      0                                  0      my ($type) = $query =~ m/^(\w+)/;
461   ***      0                                  0      $parsed->{type} = lc $type;
462                                                   
463                                                      # my @words = $query =~ m/
464                                                      #   [A-Za-z_.]+\(.*?\)+   # Match FUNCTION(...)
465                                                      #   |\(.*?\)+             # Match grouped items
466                                                      #   |"(?:[^"]|\"|"")*"+   # Match double quotes
467                                                      #   |'[^'](?:|\'|'')*'+   #   and single quotes
468                                                      #   |`(?:[^`]|``)*`+      #   and backticks
469                                                      #   |[^ ,]+
470                                                      #   |,
471                                                      #/gx;
472                                                   
473   ***      0                                  0      $parsed->{sub_queries} = [];
474                                                   
475   ***      0                                  0      return $parsed;
476                                                   }
477                                                   
478                                                   # Returns an array of arrayrefs like [db,tbl] for each unique db.tbl
479                                                   # in the query and its subqueries.  db may be undef.
480                                                   sub extract_tables {
481   ***      0                    0      0      0      my ( $self, %args ) = @_;
482   ***      0                                  0      my $query      = $args{query};
483   ***      0                                  0      my $default_db = $args{default_db};
484   ***      0             0                    0      my $q          = $self->{Quoter} || $args{Quoter};
485   ***      0      0                           0      return unless $query;
486   ***      0                                  0      MKDEBUG && _d('Extracting tables');
487   ***      0                                  0      my @tables;
488   ***      0                                  0      my %seen;
489   ***      0                                  0      foreach my $db_tbl ( $self->get_tables($query) ) {
490   ***      0      0                           0         next unless $db_tbl;
491   ***      0      0                           0         next if $seen{$db_tbl}++; # Unique-ify for issue 337.
492   ***      0                                  0         my ( $db, $tbl ) = $q->split_unquote($db_tbl);
493   ***      0             0                    0         push @tables, [ $db || $default_db, $tbl ];
494                                                      }
495   ***      0                                  0      return @tables;
496                                                   }
497                                                   
498                                                   # This is a special trim function that removes whitespace and identifier-quotes
499                                                   # (backticks, in the case of MySQL) from the string.
500                                                   sub trim_identifier {
501   ***    201                  201      0    752      my ($self, $str) = @_;
502          201    100                         837      return unless defined $str;
503          115                                372      $str =~ s/`//g;
504          115                                377      $str =~ s/^\s+//;
505          115                                342      $str =~ s/\s+$//;
506          115                                453      return $str;
507                                                   }
508                                                   
509                                                   sub _d {
510   ***      0                    0                    my ($package, undef, $line) = caller 0;
511   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
512   ***      0                                              map { defined $_ ? $_ : 'undef' }
513                                                           @_;
514   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
515                                                   }
516                                                   
517                                                   1;
518                                                   
519                                                   # ###########################################################################
520                                                   # End QueryParser package
521                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
68    ***     50      0     68   unless $query
73           100     10     58   if ($ddl_stmt)
76           100      1      9   if ($query =~ /$ddl_stmt DATABASE\b/i)
81           100      2      7   if ($ddl_stmt =~ /CREATE/i and $query =~ /$ddl_stmt\b.+?\bSELECT\b/i)
100          100      7     51   if ($query =~ /^\s*LOCK TABLES/i)
123          100      3     74   if $tbls =~ /\ASELECT\b/i
132          100      2     92   if (not $tbl =~ /[a-zA-Z]/)
167   ***     50      0     41   unless $query
192          100     40      1   if ($tbl_refs) { }
194          100      3     37   if ($query =~ /^(?:INSERT|REPLACE)/i)
232          100      1     66   if ($tbl_ref =~ /^AS\s+\w+/i)
248          100      7     59   if $db
255          100      1     40   if ($list) { }
271   ***     50      0      9   unless $query
286   ***     50      0      9   if (@split_statements == 1) { }
299          100      1     13   if ($statements[-2] and $statements[-2] =~ /on duplicate key\s+$/i)
312   ***     50      0     10   unless $query
322   ***     50      0      1   unless $query
333          100      2      9   if ($word =~ /^\(?SELECT\b/i) { }
335          100      1      1   if ($start_pos) { }
353          100      6      3   unless $sqno
356   ***     50      0      3   if ($$sq{'done'})
365          100      1      2   if ($$sq{'lp'} + $lp - ($$sq{'rp'} + $rp) == 0)
376   ***     50      0      1   unless $sq
391          100      2      8   if ($type =~ /^SELECT\b/) { }
             100      6      2   elsif ($type =~ /^$data_manip_stmts\b/ or $type =~ /^$data_def_stmts\b/) { }
408   ***      0      0      0   unless $query
411   ***      0      0      0   if ($query =~ /^SELECT/i) { }
      ***      0      0      0   elsif ($query =~ /^(?:INSERT|REPLACE)/i) { }
434   ***      0      0      0   if ($cols_def)
449   ***      0      0      0   unless $query
485   ***      0      0      0   unless $query
490   ***      0      0      0   unless $db_tbl
491   ***      0      0      0   if $seen{$db_tbl}++
502          100     86    115   unless defined $str
511   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
81           100      3      4      2   $ddl_stmt =~ /CREATE/i and $query =~ /$ddl_stmt\b.+?\bSELECT\b/i
299          100      9      4      1   $statements[-2] and $statements[-2] =~ /on duplicate key\s+$/i

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
26    ***     50      0      1   $ENV{'MKDEBUG'} || 0
362   ***     50      0      3   $word =~ tr/(// || 0
363          100      1      2   $word =~ tr/)// || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
247   ***     66     39     27      0   $alias or $tbl
391          100      3      3      2   $type =~ /^$data_manip_stmts\b/ or $type =~ /^$data_def_stmts\b/
484   ***      0      0      0      0   $$self{'Quoter'} || $args{'Quoter'}
493   ***      0      0      0      0   $db || $default_db


Covered Subroutines
-------------------

Subroutine        Count Pod Location                                          
----------------- ----- --- --------------------------------------------------
BEGIN                 1     /home/daniel/dev/maatkit/common/QueryParser.pm:22 
BEGIN                 1     /home/daniel/dev/maatkit/common/QueryParser.pm:23 
BEGIN                 1     /home/daniel/dev/maatkit/common/QueryParser.pm:24 
BEGIN                 1     /home/daniel/dev/maatkit/common/QueryParser.pm:26 
clean_query          10   0 /home/daniel/dev/maatkit/common/QueryParser.pm:311
get_aliases          41   0 /home/daniel/dev/maatkit/common/QueryParser.pm:160
get_tables           68   0 /home/daniel/dev/maatkit/common/QueryParser.pm:67 
has_derived_table     5   0 /home/daniel/dev/maatkit/common/QueryParser.pm:146
new                   1   0 /home/daniel/dev/maatkit/common/QueryParser.pm:61 
query_type           10   0 /home/daniel/dev/maatkit/common/QueryParser.pm:388
split                 9   0 /home/daniel/dev/maatkit/common/QueryParser.pm:270
split_subquery        1   0 /home/daniel/dev/maatkit/common/QueryParser.pm:321
trim_identifier     201   0 /home/daniel/dev/maatkit/common/QueryParser.pm:501

Uncovered Subroutines
---------------------

Subroutine        Count Pod Location                                          
----------------- ----- --- --------------------------------------------------
_d                    0     /home/daniel/dev/maatkit/common/QueryParser.pm:510
extract_tables        0   0 /home/daniel/dev/maatkit/common/QueryParser.pm:481
get_columns           0   0 /home/daniel/dev/maatkit/common/QueryParser.pm:406
parse                 0   0 /home/daniel/dev/maatkit/common/QueryParser.pm:448


QueryParser.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     BEGIN {
4     ***      1     50     33      1            37      die
5                                                           "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
6                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
7              1                                  8      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
8                                                     }
9                                                     
10             1                    1            14   use strict;
               1                                  2   
               1                                  7   
11             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
12                                                    
13             1                    1            14   use Test::More tests => 135;
               1                                  3   
               1                                 12   
14             1                    1            13   use English qw(-no_match_vars);
               1                                  2   
               1                                 23   
15                                                    
16             1                    1            25   use QueryRewriter;
               1                                  3   
               1                                 17   
17             1                    1            16   use QueryParser;
               1                                  5   
               1                                 18   
18             1                    1            19   use MaatkitTest;
               1                                  3   
               1                                 40   
19                                                    
20             1                                 15   my $qp = new QueryParser;
21             1                                  8   my $qr = new QueryRewriter( QueryParser => $qp );
22                                                    
23             1                                 32   isa_ok( $qp, 'QueryParser' );
24                                                    
25                                                    # A subroutine to make tests easy to write.
26                                                    sub test_query {
27            41                   41           261      my ( $query, $aliases, $tables, $msg, %args ) = @_;
28            41                                339      is_deeply(
29                                                          $qp->get_aliases( $query, $args{list} ),
30                                                          $aliases, "get_aliases: $msg",
31                                                       );
32            41                                495      is_deeply( [ $qp->get_tables($query) ], $tables, "get_tables:  $msg", );
33            41                                333      return;
34                                                    }
35                                                    
36                                                    # #############################################################################
37                                                    # Misc stuff.
38                                                    # #############################################################################
39             1                                 10   is( $qp->trim_identifier('`foo` '), 'foo', 'Trim backticks and spaces' );
40             1                                  6   is( $qp->trim_identifier(' `db`.`t1`'),
41                                                       'db.t1', 'Trim more backticks and spaces' );
42                                                    
43                                                    # #############################################################################
44                                                    # All manner of "normal" SELECT queries.
45                                                    # #############################################################################
46                                                    
47                                                    # 1 table
48             1                                 12   test_query(
49                                                       'SELECT * FROM t1 WHERE id = 1',
50                                                       {  DATABASE => {},
51                                                          TABLE    => { 't1' => 't1', },
52                                                       },
53                                                       [qw(t1)],
54                                                       'one table no alias'
55                                                    );
56                                                    
57             1                                 14   test_query(
58                                                       'SELECT * FROM t1 a WHERE id = 1',
59                                                       {  DATABASE => {},
60                                                          TABLE    => { 'a' => 't1', },
61                                                       },
62                                                       [qw(t1)],
63                                                       'one table implicit alias'
64                                                    );
65                                                    
66             1                                 13   test_query(
67                                                       'SELECT * FROM t1 AS a WHERE id = 1',
68                                                       {  DATABASE => {},
69                                                          TABLE    => { 'a' => 't1', }
70                                                       },
71                                                       [qw(t1)],
72                                                       'one table AS alias'
73                                                    );
74                                                    
75             1                                 13   test_query(
76                                                       'SELECT * FROM t1',
77                                                       {  DATABASE => {},
78                                                          TABLE    => { t1 => 't1', }
79                                                       },
80                                                       [qw(t1)],
81                                                       'one table no alias and no following clauses',
82                                                    );
83                                                    
84                                                    # 2 tables
85             1                                 14   test_query(
86                                                       'SELECT * FROM t1, t2 WHERE id = 1',
87                                                       {  DATABASE => {},
88                                                          TABLE    => {
89                                                             't1' => 't1',
90                                                             't2' => 't2',
91                                                          },
92                                                       },
93                                                       [qw(t1 t2)],
94                                                       'two tables no aliases'
95                                                    );
96                                                    
97             1                                 14   test_query(
98                                                       'SELECT * FROM t1 a, t2 WHERE foo = "bar"',
99                                                       {  DATABASE => {},
100                                                         TABLE    => {
101                                                            a  => 't1',
102                                                            t2 => 't2',
103                                                         },
104                                                      },
105                                                      [qw(t1 t2)],
106                                                      'two tables implicit alias and no alias',
107                                                   );
108                                                   
109            1                                 13   test_query(
110                                                      'SELECT * FROM t1 a, t2 b WHERE id = 1',
111                                                      {  DATABASE => {},
112                                                         TABLE    => {
113                                                            'a' => 't1',
114                                                            'b' => 't2',
115                                                         },
116                                                      },
117                                                      [qw(t1 t2)],
118                                                      'two tables implicit aliases'
119                                                   );
120                                                   
121            1                                 14   test_query(
122                                                      'SELECT * FROM t1 AS a, t2 AS b WHERE id = 1',
123                                                      {  DATABASE => {},
124                                                         TABLE    => {
125                                                            'a' => 't1',
126                                                            'b' => 't2',
127                                                         },
128                                                      },
129                                                      [qw(t1 t2)],
130                                                      'two tables AS aliases'
131                                                   );
132                                                   
133            1                                 15   test_query(
134                                                      'SELECT * FROM t1 AS a, t2 b WHERE id = 1',
135                                                      {  DATABASE => {},
136                                                         TABLE    => {
137                                                            'a' => 't1',
138                                                            'b' => 't2',
139                                                         },
140                                                      },
141                                                      [qw(t1 t2)],
142                                                      'two tables AS alias and implicit alias'
143                                                   );
144                                                   
145            1                                 14   test_query(
146                                                      'SELECT * FROM t1 a, t2 AS b WHERE id = 1',
147                                                      {  DATABASE => {},
148                                                         TABLE    => {
149                                                            'a' => 't1',
150                                                            'b' => 't2',
151                                                         },
152                                                      },
153                                                      [qw(t1 t2)],
154                                                      'two tables implicit alias and AS alias'
155                                                   );
156                                                   
157            1                                 11   test_query(
158                                                      'SELECT * FROM t1 a, t2 AS b WHERE id = 1',
159                                                      [ 't1 a', 't2 AS b', ],
160                                                      [qw(t1 t2)],
161                                                      'two tables implicit alias and AS alias, with alias',
162                                                      list => 1,
163                                                   );
164                                                   
165                                                   # ANSI JOINs
166            1                                 13   test_query(
167                                                      'SELECT * FROM t1 JOIN t2 ON a.id = b.id',
168                                                      {  DATABASE => {},
169                                                         TABLE    => {
170                                                            't1' => 't1',
171                                                            't2' => 't2',
172                                                         },
173                                                      },
174                                                      [qw(t1 t2)],
175                                                      'two tables no aliases JOIN'
176                                                   );
177                                                   
178            1                                 14   test_query(
179                                                      'SELECT * FROM t1 a JOIN t2 b ON a.id = b.id',
180                                                      {  DATABASE => {},
181                                                         TABLE    => {
182                                                            'a' => 't1',
183                                                            'b' => 't2',
184                                                         },
185                                                      },
186                                                      [qw(t1 t2)],
187                                                      'two tables implicit aliases JOIN'
188                                                   );
189                                                   
190            1                                 12   test_query(
191                                                      'SELECT * FROM t1 AS a JOIN t2 as b ON a.id = b.id',
192                                                      {  DATABASE => {},
193                                                         TABLE    => {
194                                                            'a' => 't1',
195                                                            'b' => 't2',
196                                                         },
197                                                      },
198                                                      [qw(t1 t2)],
199                                                      'two tables AS aliases JOIN'
200                                                   );
201                                                   
202            1                                 16   test_query(
203                                                      'SELECT * FROM t1 AS a JOIN t2 b ON a.id=b.id WHERE id = 1',
204                                                      {  DATABASE => {},
205                                                         TABLE    => {
206                                                            a => 't1',
207                                                            b => 't2',
208                                                         },
209                                                      },
210                                                      [qw(t1 t2)],
211                                                      'two tables AS alias and implicit alias JOIN'
212                                                   );
213                                                   
214            1                                 14   test_query(
215                                                      'SELECT * FROM t1 LEFT JOIN t2 ON a.id = b.id',
216                                                      {  DATABASE => {},
217                                                         TABLE    => {
218                                                            't1' => 't1',
219                                                            't2' => 't2',
220                                                         },
221                                                      },
222                                                      [qw(t1 t2)],
223                                                      'two tables no aliases LEFT JOIN'
224                                                   );
225                                                   
226            1                                 14   test_query(
227                                                      'SELECT * FROM t1 a LEFT JOIN t2 b ON a.id = b.id',
228                                                      {  DATABASE => {},
229                                                         TABLE    => {
230                                                            'a' => 't1',
231                                                            'b' => 't2',
232                                                         },
233                                                      },
234                                                      [qw(t1 t2)],
235                                                      'two tables implicit aliases LEFT JOIN'
236                                                   );
237                                                   
238            1                                 15   test_query(
239                                                      'SELECT * FROM t1 AS a LEFT JOIN t2 as b ON a.id = b.id',
240                                                      {  DATABASE => {},
241                                                         TABLE    => {
242                                                            'a' => 't1',
243                                                            'b' => 't2',
244                                                         },
245                                                      },
246                                                      [qw(t1 t2)],
247                                                      'two tables AS aliases LEFT JOIN'
248                                                   );
249                                                   
250            1                                 14   test_query(
251                                                      'SELECT * FROM t1 AS a LEFT JOIN t2 b ON a.id=b.id WHERE id = 1',
252                                                      {  DATABASE => {},
253                                                         TABLE    => {
254                                                            a => 't1',
255                                                            b => 't2',
256                                                         },
257                                                      },
258                                                      [qw(t1 t2)],
259                                                      'two tables AS alias and implicit alias LEFT JOIN'
260                                                   );
261                                                   
262                                                   # 3 tables
263            1                                 17   test_query(
264                                                      'SELECT * FROM t1 JOIN t2 ON t1.col1=t2.col2 JOIN t3 ON t2.col3 = t3.col4 WHERE foo = "bar"',
265                                                      {  DATABASE => {},
266                                                         TABLE    => {
267                                                            t1 => 't1',
268                                                            t2 => 't2',
269                                                            t3 => 't3',
270                                                         },
271                                                      },
272                                                      [qw(t1 t2 t3)],
273                                                      'three tables no aliases JOIN'
274                                                   );
275                                                   
276            1                                 16   test_query(
277                                                      'SELECT * FROM t1 AS a, t2, t3 c WHERE id = 1',
278                                                      {  DATABASE => {},
279                                                         TABLE    => {
280                                                            a  => 't1',
281                                                            t2 => 't2',
282                                                            c  => 't3',
283                                                         },
284                                                      },
285                                                      [qw(t1 t2 t3)],
286                                                      'three tables AS alias, no alias, implicit alias'
287                                                   );
288                                                   
289            1                                 17   test_query(
290                                                      'SELECT * FROM t1 a, t2 b, t3 c WHERE id = 1',
291                                                      {  DATABASE => {},
292                                                         TABLE    => {
293                                                            a => 't1',
294                                                            b => 't2',
295                                                            c => 't3',
296                                                         },
297                                                      },
298                                                      [qw(t1 t2 t3)],
299                                                      'three tables implicit aliases'
300                                                   );
301                                                   
302                                                   # Db-qualified tables
303            1                                 13   test_query(
304                                                      'SELECT * FROM db.t1 AS a WHERE id = 1',
305                                                      {  TABLE      => { 'a'  => 't1', },
306                                                         'DATABASE' => { 't1' => 'db', },
307                                                      },
308                                                      [qw(db.t1)],
309                                                      'one db-qualified table AS alias'
310                                                   );
311                                                   
312            1                                 15   test_query(
313                                                      'SELECT * FROM `db`.`t1` AS a WHERE id = 1',
314                                                      {  TABLE      => { 'a'  => 't1', },
315                                                         'DATABASE' => { 't1' => 'db', },
316                                                      },
317                                                      [qw(`db`.`t1`)],
318                                                      'one db-qualified table AS alias with backticks'
319                                                   );
320                                                   
321                                                   # Other cases
322            1                                 15   test_query(
323                                                      q{SELECT a FROM store_orders_line_items JOIN store_orders},
324                                                      {  DATABASE => {},
325                                                         TABLE    => {
326                                                            store_orders_line_items => 'store_orders_line_items',
327                                                            store_orders            => 'store_orders',
328                                                         },
329                                                      },
330                                                      [qw(store_orders_line_items store_orders)],
331                                                      'Embedded ORDER keyword',
332                                                   );
333                                                   
334                                                   # #############################################################################
335                                                   # Non-SELECT queries.
336                                                   # #############################################################################
337            1                                 15   test_query(
338                                                      'UPDATE foo AS bar SET value = 1 WHERE 1',
339                                                      {  DATABASE => {},
340                                                         TABLE    => { bar => 'foo', },
341                                                      },
342                                                      [qw(foo)],
343                                                      'update with one AS alias',
344                                                   );
345                                                   
346            1                                 14   test_query(
347                                                      'UPDATE IGNORE foo bar SET value = 1 WHERE 1',
348                                                      {  DATABASE => {},
349                                                         TABLE    => { bar => 'foo', },
350                                                      },
351                                                      [qw(foo)],
352                                                      'update ignore with one implicit alias',
353                                                   );
354                                                   
355            1                                 15   test_query(
356                                                      'UPDATE IGNORE bar SET value = 1 WHERE 1',
357                                                      {  DATABASE => {},
358                                                         TABLE    => { bar => 'bar', },
359                                                      },
360                                                      [qw(bar)],
361                                                      'update ignore with one not aliased',
362                                                   );
363                                                   
364            1                                 12   test_query(
365                                                      'UPDATE LOW_PRIORITY baz SET value = 1 WHERE 1',
366                                                      {  DATABASE => {},
367                                                         TABLE    => { baz => 'baz', },
368                                                      },
369                                                      [qw(baz)],
370                                                      'update low_priority with one not aliased',
371                                                   );
372                                                   
373            1                                 13   test_query(
374                                                      'UPDATE LOW_PRIORITY IGNORE bat SET value = 1 WHERE 1',
375                                                      {  DATABASE => {},
376                                                         TABLE    => { bat => 'bat', },
377                                                      },
378                                                      [qw(bat)],
379                                                      'update low_priority ignore with one not aliased',
380                                                   );
381                                                   
382            1                                 14   test_query(
383                                                      'INSERT INTO foo VALUES (1)',
384                                                      {  DATABASE => {},
385                                                         TABLE    => { foo => 'foo', }
386                                                      },
387                                                      [qw(foo)],
388                                                      'insert with one not aliased',
389                                                   );
390                                                   
391            1                                 12   test_query(
392                                                      'INSERT INTO foo VALUES (1) ON DUPLICATE KEY UPDATE bar = 1',
393                                                      {  DATABASE => {},
394                                                         TABLE    => { foo => 'foo', },
395                                                      },
396                                                      [qw(foo)],
397                                                      'insert / on duplicate key update',
398                                                   );
399                                                   
400                                                   # #############################################################################
401                                                   # Non-DMS queries.
402                                                   # #############################################################################
403            1                                 14   test_query(
404                                                      'BEGIN',
405                                                      {  DATABASE => {},
406                                                         TABLE    => {},
407                                                      },
408                                                      [],
409                                                      'BEGIN'
410                                                   );
411                                                   
412                                                   # #############################################################################
413                                                   # Diabolical dbs and tbls with spaces in their names.
414                                                   # #############################################################################
415                                                   
416            1                                 14   test_query(
417                                                      'select * from `my table` limit 1;',
418                                                      {  DATABASE => {},
419                                                         TABLE    => { 'my table' => 'my table', }
420                                                      },
421                                                      ['`my table`'],
422                                                      'one table with space in name, not aliased',
423                                                   );
424                                                   
425            1                                 13   test_query(
426                                                      'select * from `my database`.mytable limit 1;',
427                                                      {  TABLE    => { mytable => 'mytable', },
428                                                         DATABASE => { mytable => 'my database', },
429                                                      },
430                                                      ['`my database`.mytable'],
431                                                      'one db.tbl with space in db, not aliased',
432                                                   );
433                                                   
434            1                                 16   test_query(
435                                                      'select * from `my database`.`my table` limit 1; ',
436                                                      {  TABLE    => { 'my table' => 'my table', },
437                                                         DATABASE => { 'my table' => 'my database', },
438                                                      },
439                                                      ['`my database`.`my table`'],
440                                                      'one db.tbl with space in both db and tbl, not aliased',
441                                                   );
442                                                   
443                                                   # #############################################################################
444                                                   # Issue 185: QueryParser fails to parse table ref for a JOIN ... USING
445                                                   # #############################################################################
446            1                                 16   test_query(
447                                                      'select  n.column1 = a.column1, n.word3 = a.word3 from db2.tuningdetail_21_265507 n inner join db1.gonzo a using(gonzo)',
448                                                      {  TABLE => {
449                                                            'n' => 'tuningdetail_21_265507',
450                                                            'a' => 'gonzo',
451                                                         },
452                                                         'DATABASE' => {
453                                                            'tuningdetail_21_265507' => 'db2',
454                                                            'gonzo'                  => 'db1',
455                                                         },
456                                                      },
457                                                      [qw(db2.tuningdetail_21_265507 db1.gonzo)],
458                                                      'SELECT with JOIN ON and no WHERE (issue 185)'
459                                                   );
460                                                   
461                                                   # #############################################################################
462            1                                 16   test_query(
463                                                      'select 12_13_foo from (select 12foo from 123_bar) as 123baz',
464                                                      {  DATABASE => {},
465                                                         TABLE    => { '123baz' => undef, },
466                                                      },
467                                                      [qw(123_bar)],
468                                                      'Subquery in the FROM clause'
469                                                   );
470                                                   
471            1                                 39   test_query(
472                                                      q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
473                                                         . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
474                                                         . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
475                                                         . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
476                                                         . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
477                                                         . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
478                                                         . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )},
479                                                      {  DATABASE => {},
480                                                         TABLE    => {
481                                                            PL  => 'GARDEN_CLUPL',
482                                                            GC  => 'GARDENJOB',
483                                                            ABU => 'APLTRACT_GARDENPLANT',
484                                                         },
485                                                      },
486                                                      [qw(GARDEN_CLUPL GARDENJOB APLTRACT_GARDENPLANT)],
487                                                      'Gets tables from query with aliases and comma-join',
488                                                   );
489                                                   
490            1                                 17   test_query(
491                                                      q{SELECT count(*) AS count_all FROM `impact_actions`  LEFT OUTER JOIN }
492                                                         . q{recommended_change_events ON (impact_actions.event_id = }
493                                                         . q{recommended_change_events.event_id) LEFT OUTER JOIN }
494                                                         . q{recommended_change_aments ON (impact_actions.ament_id = }
495                                                         . q{recommended_change_aments.ament_id) WHERE (impact_actions.user_id = 71058 }
496                                                   
497                                                         # An old version of the regex used to think , was the precursor to a
498                                                         # table name, so it would pull out 7,8,9,10,11 as table names.
499                                                         . q{AND (impact_actions.action_type IN (4,7,8,9,10,11) AND }
500                                                         . q{(impact_actions.change_id = 2699 OR recommended_change_events.change_id = }
501                                                         . q{2699 OR recommended_change_aments.change_id = 2699)))},
502                                                      {  DATABASE => {},
503                                                         TABLE    => {
504                                                            'impact_actions'            => 'impact_actions',
505                                                            'recommended_change_events' => 'recommended_change_events',
506                                                            'recommended_change_aments' => 'recommended_change_aments',
507                                                         },
508                                                      },
509                                                      [qw(`impact_actions` recommended_change_events recommended_change_aments)],
510                                                      'Does not think IN() list has table names',
511                                                   );
512                                                   
513            1                                 14   test_query(
514                                                      'INSERT INTO my.tbl VALUES("I got this FROM the newspaper today")',
515                                                      {  TABLE    => { 'tbl' => 'tbl', },
516                                                         DATABASE => { 'tbl' => 'my' },
517                                                      },
518                                                      [qw(my.tbl)],
519                                                      'Not confused by quoted string'
520                                                   );
521                                                   
522            1                                 10   is_deeply(
523                                                      [  $qp->get_tables(
524                                                                 q{REPLACE /*foo.bar:3/3*/ INTO checksum.checksum (db, tbl, }
525                                                               . q{chunk, boundaries, this_cnt, this_crc) SELECT 'foo', 'bar', }
526                                                               . q{2 AS chunk_num, '`id` >= 2166633', COUNT(*) AS cnt, }
527                                                               . q{LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `id`, `created_by`, }
528                                                               . q{`created_date`, `updated_by`, `updated_date`, `ppc_provider`, }
529                                                               . q{`account_name`, `provider_account_id`, `campaign_name`, }
530                                                               . q{`provider_campaign_id`, `adgroup_name`, `provider_adgroup_id`, }
531                                                               . q{`provider_keyword_id`, `provider_ad_id`, `foo`, `reason`, }
532                                                               . q{`foo_bar_bazz_id`, `foo_bar_baz`, CONCAT(ISNULL(`created_by`), }
533                                                               . q{ISNULL(`created_date`), ISNULL(`updated_by`), ISNULL(`updated_date`), }
534                                                               . q{ISNULL(`ppc_provider`), ISNULL(`account_name`), }
535                                                               . q{ISNULL(`provider_account_id`), ISNULL(`campaign_name`), }
536                                                               . q{ISNULL(`provider_campaign_id`), ISNULL(`adgroup_name`), }
537                                                               . q{ISNULL(`provider_adgroup_id`), ISNULL(`provider_keyword_id`), }
538                                                               . q{ISNULL(`provider_ad_id`), ISNULL(`foo`), ISNULL(`reason`), }
539                                                               . q{ISNULL(`foo_base_foo_id`), ISNULL(`fooe_foo_id`)))) AS UNSIGNED)), 10, }
540                                                               . q{16)) AS crc FROM `foo`.`bar` USE INDEX (`PRIMARY`) WHERE }
541                                                               . q{(`id` >= 2166633); }
542                                                         )
543                                                      ],
544                                                      [qw(checksum.checksum `foo`.`bar`)],
545                                                      'gets tables from nasty checksum query',
546                                                   );
547                                                   
548            1                                 11   is_deeply(
549                                                      [  $qp->get_tables(q{SELECT STRAIGHT_JOIN distinct foo, bar FROM A, B, C})
550                                                      ],
551                                                      [qw(A B C)],
552                                                      'gets tables from STRAIGHT_JOIN',
553                                                   );
554                                                   
555            1                                 11   is_deeply(
556                                                      [  $qp->get_tables(
557                                                            'replace into checksum.checksum select `last_update`, `foo` from foo.foo'
558                                                         )
559                                                      ],
560                                                      [qw(checksum.checksum foo.foo)],
561                                                      'gets tables with reserved words'
562                                                   );
563                                                   
564            1                                 11   is_deeply(
565                                                      [  $qp->get_tables(
566                                                            'SELECT * FROM (SELECT * FROM foo WHERE UserId = 577854809 ORDER BY foo DESC) q1 GROUP BY foo ORDER BY bar DESC LIMIT 3'
567                                                         )
568                                                      ],
569                                                      [qw(foo)],
570                                                      'get_tables on simple subquery'
571                                                   );
572                                                   
573            1                                 10   is_deeply(
574                                                      [  $qp->get_tables(
575                                                            'INSERT INTO my.tbl VALUES("I got this from the newspaper")')
576                                                      ],
577                                                      [qw(my.tbl)],
578                                                      'Not confused by quoted string'
579                                                   );
580                                                   
581            1                                 14   is_deeply( [ $qp->get_tables('create table db.tbl (i int)') ],
582                                                      [qw(db.tbl)], 'get_tables: CREATE TABLE' );
583                                                   
584            1                                 12   is_deeply( [ $qp->get_tables('create TEMPORARY table db.tbl2 (i int)') ],
585                                                      [qw(db.tbl2)], 'get_tables: CREATE TEMPORARY TABLE' );
586                                                   
587            1                                 10   is_deeply( [ $qp->get_tables('create table if not exists db.tbl (i int)') ],
588                                                      [qw(db.tbl)], 'get_tables: CREATE TABLE IF NOT EXISTS' );
589                                                   
590            1                                 10   is_deeply(
591                                                      [  $qp->get_tables('create TEMPORARY table IF NOT EXISTS db.tbl3 (i int)')
592                                                      ],
593                                                      [qw(db.tbl3)],
594                                                      'get_tables: CREATE TEMPORARY TABLE IF NOT EXISTS'
595                                                   );
596                                                   
597            1                                 10   is_deeply(
598                                                      [  $qp->get_tables(
599                                                            'CREATE TEMPORARY TABLE `foo` AS select * from bar where id = 1')
600                                                      ],
601                                                      [qw(bar)],
602                                                      'get_tables: CREATE TABLE ... SELECT'
603                                                   );
604                                                   
605            1                                 11   is_deeply( [ $qp->get_tables('ALTER TABLE db.tbl ADD COLUMN (j int)') ],
606                                                      [qw(db.tbl)], 'get_tables: ALTER TABLE' );
607                                                   
608            1                                 11   is_deeply( [ $qp->get_tables('DROP TABLE db.tbl') ],
609                                                      [qw(db.tbl)], 'get_tables: DROP TABLE' );
610                                                   
611            1                                 13   is_deeply( [ $qp->get_tables('truncate table db.tbl') ],
612                                                      [qw(db.tbl)], 'get_tables: TRUNCATE TABLE' );
613                                                   
614            1                                 11   is_deeply( [ $qp->get_tables('create database foo') ],
615                                                      [], 'get_tables: CREATE DATABASE (no tables)' );
616                                                   
617            1                                 10   is_deeply(
618                                                      [  $qp->get_tables(
619                                                            'INSERT INTO `foo` (`s`,`from`,`t`,`p`) VALVUES ("not","me","foo",1)'
620                                                         )
621                                                      ],
622                                                      [qw(`foo`)],
623                                                      'Throws out suspicious table names'
624                                                   );
625                                                   
626            1                                 11   ok( $qp->has_derived_table('select * from ( select 1) as x'),
627                                                      'simple derived' );
628            1                                  6   ok( $qp->has_derived_table('select * from a join ( select 1) as x'),
629                                                      'join, derived' );
630            1                                  6   ok( $qp->has_derived_table('select * from a join b, (select 1) as x'),
631                                                      'comma join, derived' );
632            1                                  5   is( $qp->has_derived_table('select * from foo'), '', 'no derived' );
633            1                                  9   is( $qp->has_derived_table('select * from foo where a in(select a from b)'),
634                                                      '', 'no derived on correlated' );
635                                                   
636                                                   # #############################################################################
637                                                   # Test split().
638                                                   # #############################################################################
639            1                                  7   is_deeply(
640                                                      [ $qp->split('SELECT * FROM db.tbl WHERE id = 1') ],
641                                                      [ 'SELECT * FROM db.tbl WHERE id = 1', ],
642                                                      'split 1 statement, SELECT'
643                                                   );
644                                                   
645            1                                  9   my $sql
646                                                      = 'replace into db1.tbl2 (dt, hr) select foo, bar from db2.tbl2 where id = 1 group by foo';
647            1                                  5   is_deeply(
648                                                      [ $qp->split($sql) ],
649                                                      [  'replace into db1.tbl2 (dt, hr) ',
650                                                         'select foo, bar from db2.tbl2 where id = 1 group by foo',
651                                                      ],
652                                                      'split 2 statements, REPLACE ... SELECT'
653                                                   );
654                                                   
655            1                                  8   $sql
656                                                      = 'insert into db1.tbl 1 (dt,hr) select dt,hr from db2.tbl2 where foo = 1';
657            1                                  5   is_deeply(
658                                                      [ $qp->split($sql) ],
659                                                      [  'insert into db1.tbl 1 (dt,hr) ',
660                                                         'select dt,hr from db2.tbl2 where foo = 1',
661                                                      ],
662                                                      'split 2 statements, INSERT ... SELECT'
663                                                   );
664                                                   
665            1                                  9   $sql
666                                                      = 'create table if not exists db.tbl (primary key (lmp), id int not null unique key auto_increment, lmp datetime)';
667            1                                  6   is_deeply( [ $qp->split($sql) ], [ $sql, ], 'split 1 statement, CREATE' );
668                                                   
669            1                                  9   $sql = "select num from db.tbl where replace(col,' ','') = 'foo'";
670            1                                  5   is_deeply( [ $qp->split($sql) ],
671                                                      [ $sql, ], 'split 1 statement, SELECT with REPLACE() function' );
672                                                   
673            1                                  8   $sql = "
674                                                                  INSERT INTO db.tbl (i, t, c, m) VALUES (237527, '', 0, '1 rows')";
675            1                                  6   is_deeply(
676                                                      [ $qp->split($sql) ],
677                                                      [ "INSERT INTO db.tbl (i, t, c, m) VALUES (237527, '', 0, '1 rows')", ],
678                                                      'split 1 statement, INSERT with leading newline and spaces'
679                                                   );
680                                                   
681            1                                  9   $sql = 'create table db1.tbl1 SELECT id FROM db2.tbl2 WHERE time = 46881;';
682            1                                  6   is_deeply(
683                                                      [ $qp->split($sql) ],
684                                                      [  'create table db1.tbl1 ',
685                                                         'SELECT id FROM db2.tbl2 WHERE time = 46881;',
686                                                      ],
687                                                      'split 2 statements, CREATE ... SELECT'
688                                                   );
689                                                   
690            1                                 10   $sql
691                                                      = "/*<font color = 'blue'>MAIN FUNCTION </font><br>*/                 insert into p.b317  (foo) select p.b1927.rtb as pr   /* inner join  pa7.r on pr.pd = c.pd */            inner join m.da on da.hr=p.hr and  da.node=pr.node     ;";
692            1                                  5   is_deeply(
693                                                      [ $qp->split($sql) ],
694                                                      [  'insert into p.b317 (foo) ',
695                                                         'select p.b1927.rtb as pr inner join m.da on da.hr=p.hr and da.node=pr.node ;',
696                                                      ],
697                                                      'split statements with comment blocks'
698                                                   );
699                                                   
700            1                                  8   $sql
701                                                      = "insert into test1.tbl6 (day) values ('monday') on duplicate key update metric11 = metric11 + 1";
702            1                                  6   is_deeply( [ $qp->split($sql) ], [ $sql, ], 'split "on duplicate key"' );
703                                                   
704                                                   # #############################################################################
705                                                   # Test split_subquery().
706                                                   # #############################################################################
707            1                                  9   $sql = 'SELECT * FROM t1 WHERE column1 = (SELECT column1 FROM t2);';
708            1                                 10   is_deeply(
709                                                      [ $qp->split_subquery($sql) ],
710                                                      [  'SELECT * FROM t1 WHERE column1 = (__subquery_1)',
711                                                         '(SELECT column1 FROM t2)',
712                                                      ],
713                                                      'split_subquery() basic'
714                                                   );
715                                                   
716                                                   # #############################################################################
717                                                   # Test query_type().
718                                                   # #############################################################################
719            1                                 12   is_deeply(
720                                                      $qp->query_type( 'select * from foo where id=1', $qr ),
721                                                      {  type => 'SELECT',
722                                                         rw   => 'read',
723                                                      },
724                                                      'query_type() select'
725                                                   );
726            1                                 14   is_deeply(
727                                                      $qp->query_type( '/* haha! */ select * from foo where id=1', $qr ),
728                                                      {  type => 'SELECT',
729                                                         rw   => 'read',
730                                                      },
731                                                      'query_type() select with leading /* comment */'
732                                                   );
733            1                                 12   is_deeply(
734                                                      $qp->query_type( 'insert into foo values (1, 2)', $qr ),
735                                                      {  type => 'INSERT',
736                                                         rw   => 'write',
737                                                      },
738                                                      'query_type() insert'
739                                                   );
740            1                                 12   is_deeply(
741                                                      $qp->query_type( 'delete from foo where bar=1', $qr ),
742                                                      {  type => 'DELETE',
743                                                         rw   => 'write',
744                                                      },
745                                                      'query_type() delete'
746                                                   );
747            1                                 11   is_deeply(
748                                                      $qp->query_type( 'update foo set bar="foo" where 1', $qr ),
749                                                      {  type => 'UPDATE',
750                                                         rw   => 'write',
751                                                      },
752                                                      'query_type() update'
753                                                   );
754            1                                 12   is_deeply(
755                                                      $qp->query_type( 'truncate table bar', $qr ),
756                                                      {  type => 'TRUNCATE TABLE',
757                                                         rw   => 'write',
758                                                      },
759                                                      'query_type() truncate'
760                                                   );
761            1                                 13   is_deeply(
762                                                      $qp->query_type( 'alter table foo add column (i int)', $qr ),
763                                                      {  type => 'ALTER TABLE',
764                                                         rw   => 'write',
765                                                      },
766                                                      'query_type() alter'
767                                                   );
768            1                                 12   is_deeply(
769                                                      $qp->query_type( 'drop table foo', $qr ),
770                                                      {  type => 'DROP TABLE',
771                                                         rw   => 'write',
772                                                      },
773                                                      'query_type() drop'
774                                                   );
775            1                                 11   is_deeply(
776                                                      $qp->query_type( 'show tables', $qr ),
777                                                      {  type => 'SHOW TABLES',
778                                                         rw   => undef,
779                                                      },
780                                                      'query_type() show tables'
781                                                   );
782            1                                 12   is_deeply(
783                                                      $qp->query_type( 'show fields from foo', $qr ),
784                                                      {  type => 'SHOW FIELDS',
785                                                         rw   => undef,
786                                                      },
787                                                      'query_type() show fields'
788                                                   );
789                                                   
790                                                   # #############################################################################
791                                                   # Issue 563: Lock tables is not distilled
792                                                   # #############################################################################
793            1                                 16   is_deeply( [ $qp->get_tables('LOCK TABLES foo READ') ],
794                                                      [qw(foo)], 'LOCK TABLES foo READ' );
795            1                                 17   is_deeply( [ $qp->get_tables('LOCK TABLES foo WRITE') ],
796                                                      [qw(foo)], 'LOCK TABLES foo WRITE' );
797            1                                 12   is_deeply( [ $qp->get_tables('LOCK TABLES foo READ, bar WRITE') ],
798                                                      [qw(foo bar)], 'LOCK TABLES foo READ, bar WRITE' );
799            1                                 13   is_deeply( [ $qp->get_tables('LOCK TABLES foo AS als WRITE') ],
800                                                      [qw(foo)], 'LOCK TABLES foo AS als WRITE' );
801            1                                 18   is_deeply(
802                                                      [ $qp->get_tables('LOCK TABLES foo AS als1 READ, bar AS als2 WRITE') ],
803                                                      [qw(foo bar)], 'LOCK TABLES foo AS als READ, bar AS als2 WRITE' );
804            1                                 11   is_deeply( [ $qp->get_tables('LOCK TABLES foo als WRITE') ],
805                                                      [qw(foo)], 'LOCK TABLES foo als WRITE' );
806            1                                 16   is_deeply( [ $qp->get_tables('LOCK TABLES foo als1 READ, bar als2 WRITE') ],
807                                                      [qw(foo bar)], 'LOCK TABLES foo als READ, bar als2 WRITE' );
808                                                   
809            1                                 10   $sql = "CREATE TEMPORARY TABLE mk_upgrade AS SELECT col1, col2
810                                                           FROM foo, bar
811                                                           WHERE id = 1";
812            1                                 12   is_deeply( [ $qp->get_tables($sql) ],
813                                                      [qw(foo bar)], 'Get tables from special case multi-line query' );
814                                                   
815            1                                 12   is_deeply(
816                                                      [ $qp->get_tables('select * from (`mytable`)') ],
817                                                      [qw(`mytable`)],
818                                                      'Get tables when there are parens around table name (issue 781)',
819                                                   );
820                                                   
821            1                                 11   is_deeply(
822                                                      [ $qp->get_tables('select * from (select * from mytable) t') ],
823                                                      [qw(mytable)], 'Does not consider subquery SELECT as a table (issue 781)',
824                                                   );
825                                                   
826                                                   # #############################################################################
827                                                   # Done.
828                                                   # #############################################################################
829            1                                  3   exit;


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
---------- ----- ----------------
BEGIN          1 QueryParser.t:10
BEGIN          1 QueryParser.t:11
BEGIN          1 QueryParser.t:13
BEGIN          1 QueryParser.t:14
BEGIN          1 QueryParser.t:16
BEGIN          1 QueryParser.t:17
BEGIN          1 QueryParser.t:18
BEGIN          1 QueryParser.t:4 
test_query    41 QueryParser.t:27


