---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...kit/common/QueryParser.pm   93.9   73.8   69.2   91.7    n/a  100.0   88.3
Total                          93.9   73.8   69.2   91.7    n/a  100.0   88.3
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryParser.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:32 2009
Finish:       Sat Aug 29 15:03:32 2009

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
18                                                    # QueryParser package $Revision: 4606 $
19                                                    # ###########################################################################
20                                                    package QueryParser;
21                                                    
22             1                    1             9   use strict;
               1                                  2   
               1                                  7   
23             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
24             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  5   
25                                                    
26             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                  7   
27                                                    our $tbl_ident = qr/(?:`[^`]+`|\w+)(?:\.(?:`[^`]+`|\w+))?/;
28                                                    # This regex finds things that look like database.table identifiers, based on
29                                                    # their proximity to keywords.  (?<!KEY\s) is a workaround for ON DUPLICATE KEY
30                                                    # UPDATE, which is usually followed by a column name.
31                                                    our $tbl_regex = qr{
32                                                             \b(?:FROM|JOIN|(?<!KEY\s)UPDATE|INTO) # Words that precede table names
33                                                             \b\s*
34                                                             # Capture the identifier and any number of comma-join identifiers that
35                                                             # follow it, optionally with aliases with or without the AS keyword
36                                                             ($tbl_ident
37                                                                (?: (?:\s+ (?:AS\s+)? \w+)?, \s*$tbl_ident )*
38                                                             )
39                                                          }xio;
40                                                    # This regex is meant to match "derived table" queries, of the form
41                                                    # .. from ( select ...
42                                                    # .. join ( select ...
43                                                    # .. bar join foo, ( select ...
44                                                    # Unfortunately it'll also match this:
45                                                    # select a, b, (select ...
46                                                    our $has_derived = qr{
47                                                          \b(?:FROM|JOIN|,)
48                                                          \s*\(\s*SELECT
49                                                       }xi;
50                                                    
51                                                    # http://dev.mysql.com/doc/refman/5.1/en/sql-syntax-data-definition.html
52                                                    # We treat TRUNCATE as a dds but really it's a data manipulation statement.
53                                                    our $data_def_stmts = qr/(?:CREATE|ALTER|TRUNCATE|DROP|RENAME)/i;
54                                                    
55                                                    sub new {
56             1                    1             9      my ( $class ) = @_;
57             1                                 10      bless {}, $class;
58                                                    }
59                                                    
60                                                    # Returns a list of table names found in the query text.
61                                                    sub get_tables {
62            62                   62           339      my ( $self, $query ) = @_;
63    ***     62     50                         233      return unless $query;
64            62                                156      MKDEBUG && _d('Getting tables for', $query);
65                                                    
66                                                       # Handle CREATE, ALTER, TRUNCATE and DROP TABLE.
67            62                                580      my ( $ddl_stmt ) = $query =~ /^\s*($data_def_stmts)\b/i;
68            62    100                         248      if ( $ddl_stmt ) {
69             9                                 22         MKDEBUG && _d('Special table type:', $ddl_stmt);
70             9                                 34         $query =~ s/IF NOT EXISTS//i;
71             9    100                         106         if ( $query =~ m/$ddl_stmt DATABASE\b/i ) {
72                                                             # Handles CREATE DATABASE, not to be confused with CREATE TABLE.
73             1                                  2            MKDEBUG && _d('Query alters a database, not a table');
74             1                                  7            return ();
75                                                          }
76             8    100    100                  103         if ( $ddl_stmt =~ m/CREATE/i && $query =~ m/$ddl_stmt\b.+?\bSELECT\b/i ) {
77                                                             # Handle CREATE TABLE ... SELECT.  In this case, the real tables
78                                                             # come from the SELECT, not the CREATE.
79             1                                  9            my ($select) = $query =~ m/\b(SELECT\b.+)/i;
80             1                                  2            MKDEBUG && _d('CREATE TABLE ... SELECT:', $select);
81             1                                  9            return $self->get_tables($select);
82                                                          }
83             7                                 95         my ($tbl) = $query =~ m/TABLE\s+($tbl_ident)(\s+.*)?/i;
84             7                                 17         MKDEBUG && _d('Matches table:', $tbl);
85             7                                 51         return ($tbl);
86                                                       }
87                                                    
88                                                       # These keywords may appear between UPDATE or SELECT and the table refs.
89                                                       # They need to be removed so that they are not mistaken for tables.
90            53                                341      $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;
91                                                    
92                                                       # Another special case: LOCK TABLES tbl [[AS] alias] READ|WRITE, etc.
93                                                       # We strip the LOCK TABLES stuff and append "FROM" to fake a SELECT
94                                                       # statement and allow $tbl_regex to match below.
95            53    100                         240      if ( $query =~ /^\s*LOCK TABLES/i ) {
96             7                                 19         MKDEBUG && _d('Special table type: LOCK TABLES');
97             7                                 40         $query =~ s/^(\s*LOCK TABLES\s+)//;
98             7                                 48         $query =~ s/\s+(?:READ|WRITE|LOCAL)+\s*//g;
99             7                                 20         MKDEBUG && _d('Locked tables:', $query);
100            7                                 25         $query = "FROM $query";
101                                                      }
102                                                   
103           53                                174      $query =~ s/\\["']//g;                # quoted strings
104           53                                165      $query =~ s/".*?"/?/sg;               # quoted strings
105           53                                181      $query =~ s/'.*?'/?/sg;               # quoted strings
106                                                   
107           53                                129      my @tables;
108           53                                958      foreach my $tbls ( $query =~ m/$tbl_regex/gio ) {
109           70                                155         MKDEBUG && _d('Match tables:', $tbls);
110           70                                356         foreach my $tbl ( split(',', $tbls) ) {
111                                                            # Remove implicit or explicit (AS) alias.
112           88                                851            $tbl =~ s/\s*($tbl_ident)(\s+.*)?/$1/gio;
113                                                   
114                                                            # Sanity check for cases like when a column is named `from`
115                                                            # and the regex matches junk.  Instead of complex regex to
116                                                            # match around these rarities, this simple check will save us.
117           88    100                         432            if ( $tbl !~ m/[a-zA-Z]/ ) {
118            2                                  4               MKDEBUG && _d('Skipping suspicious table name:', $tbl);
119            2                                  9               next;
120                                                            }
121                                                   
122           86                                452            push @tables, $tbl;
123                                                         }
124                                                      }
125           53                                441      return @tables;
126                                                   }
127                                                   
128                                                   # Returns true if it sees what looks like a "derived table", e.g. a subquery in
129                                                   # the FROM clause.
130                                                   sub has_derived_table {
131            5                    5            22      my ( $self, $query ) = @_;
132                                                      # See the $tbl_regex regex above.
133            5                                 59      my $match = $query =~ m/$has_derived/;
134            5                                 14      MKDEBUG && _d($query, 'has ' . ($match ? 'a' : 'no') . ' derived table');
135            5                                 30      return $match;
136                                                   }
137                                                   
138                                                   # Return a list of tables/databases and the name they're aliased to.
139                                                   sub get_aliases {
140           39                   39           200      my ( $self, $query ) = @_;
141   ***     39     50                         156      return unless $query;
142           39                                 94      my $aliases;
143                                                   
144                                                      # These keywords may appear between UPDATE or SELECT and the table refs.
145                                                      # They need to be removed so that they are not mistaken for tables.
146           39                                287      $query =~ s/ (?:LOW_PRIORITY|IGNORE|STRAIGHT_JOIN)//ig;
147                                                   
148                                                      # These keywords may appear before JOIN. They need to be removed so
149                                                      # that they are not mistaken for implicit aliases of the preceding table.
150           39                                207      $query =~ s/ (?:INNER|OUTER|CROSS|LEFT|RIGHT|NATURAL)//ig;
151                                                   
152                                                      # Get the table references clause and the keyword that starts the clause.
153                                                      # See the comments below for why we need the starting keyword.
154           39                                579      my ($tbl_refs, $from) = $query =~ m{
155                                                         (
156                                                            (FROM|INTO|UPDATE)\b\s*   # Keyword before table refs
157                                                            .+?                       # Table refs
158                                                         )
159                                                         (?:\s+|\z)                   # If the query does not end with the table
160                                                                                      # refs then there must be at least 1 space
161                                                                                      # between the last tbl ref and the next
162                                                                                      # keyword
163                                                         (?:WHERE|ORDER|LIMIT|HAVING|SET|VALUES|\z) # Keyword after table refs
164                                                      }ix;
165                                                   
166                                                      # This shouldn't happen, often at least.
167   ***     39     50     33                  326      die "Failed to parse table references from $query"
168                                                         unless $tbl_refs && $from;
169                                                   
170           39                                 81      MKDEBUG && _d('tbl refs:', $tbl_refs);
171                                                   
172                                                      # These keywords precede a table ref. They signal the start of a table
173                                                      # ref, but to know where the table ref ends we need the after tbl ref
174                                                      # keywords below.
175           39                               2103      my $before_tbl = qr/(?:,|JOIN|\s|$from)+/i;
176                                                   
177                                                      # These keywords signal the end of a table ref and either 1) the start
178                                                      # of another table ref, or 2) the start of an ON|USING part of a JOIN
179                                                      # clause (which we want to skip over), or 3) the end of the string (\z).
180                                                      # We need these after tbl ref keywords so that they are not mistaken
181                                                      # for implicit aliases of the preceding table.
182           39                                141      my $after_tbl  = qr/(?:,|JOIN|ON|USING|\z)/i;
183                                                   
184                                                      # This is required for cases like:
185                                                      #    FROM t1 JOIN t2 ON t1.col1=t2.col2 JOIN t3 ON t2.col3 = t3.col4
186                                                      # Because spaces may precede a tbl and a tbl may end with \z, then
187                                                      # t3.col4 will match as a table. However, t2.col3=t3.col4 will not match.
188           39                                153      $tbl_refs =~ s/ = /=/g;
189                                                   
190           39                               1918      while (
191                                                         $tbl_refs =~ m{
192                                                            $before_tbl\b\s*
193                                                               ( ($tbl_ident) (?:\s+ (?:AS\s+)? (\w+))? )
194                                                            \s*$after_tbl
195                                                         }xgio )
196                                                      {
197           65                                410         my ( $tbl_ref, $db_tbl, $alias ) = ($1, $2, $3);
198           65                                147         MKDEBUG && _d('Match table:', $tbl_ref);
199                                                   
200                                                         # Handle subqueries.
201           65    100                         266         if ( $tbl_ref =~ m/^AS\s+\w+/i ) {
202                                                            # According the the manual
203                                                            # http://dev.mysql.com/doc/refman/5.0/en/unnamed-views.html:
204                                                            # "The [AS] name  clause is mandatory, because every table in a
205                                                            # FROM clause must have a name."
206                                                            # So if the tbl ref begins with 'AS', then we probably have a
207                                                            # subquery.
208            1                                  2            MKDEBUG && _d('Subquery', $tbl_ref);
209            1                                  5            $aliases->{$alias} = undef;
210            1                                  7            next;
211                                                         }
212                                                   
213           64                                360         my ( $db, $tbl ) = $db_tbl =~ m/^(?:(.*?)\.)?(.*)/;
214   ***     64            66                  442         $aliases->{$alias || $tbl} = $tbl;
215           64    100                         658         $aliases->{DATABASE}->{$tbl} = $db if $db;
216                                                      }
217           39                                418      return $aliases;
218                                                   }
219                                                   
220                                                   # Splits a compound statement and returns an array with each sub-statement.
221                                                   # Example:
222                                                   #    INSERT INTO ... SELECT ...
223                                                   # is split into two statements: "INSERT INTO ..." and "SELECT ...".
224                                                   sub split {
225            8                    8            40      my ( $self, $query ) = @_;
226   ***      8     50                          30      return unless $query;
227            8                                 27      $query = clean_query($query);
228            8                                 17      MKDEBUG && _d('Splitting', $query);
229                                                   
230            8                                 48      my $verbs = qr{SELECT|INSERT|UPDATE|DELETE|REPLACE|UNION|CREATE}i;
231                                                   
232                                                      # This splits a statement on the above verbs which means that the verb
233                                                      # gets chopped out.  Capturing the verb (e.g. ($verb)) will retain it,
234                                                      # but then it's disjointed from its statement.  Example: for this query,
235                                                      #   INSERT INTO ... SELECT ...
236                                                      # split returns ('INSERT', 'INTO ...', 'SELECT', '...').  Therefore,
237                                                      # we must re-attach each verb to its statement; we do this later...
238            8                                161      my @split_statements = grep { $_ } split(m/\b($verbs\b(?!(?:\s*\()))/io, $query);
              32                                108   
239                                                   
240            8                                 26      my @statements;
241   ***      8     50                          33      if ( @split_statements == 1 ) {
242                                                         # This happens if the query has no verbs, so it's probably a single
243                                                         # statement.
244   ***      0                                  0         push @statements, $query;
245                                                      }
246                                                      else {
247                                                         # ...Re-attach verbs to their statements.
248                                                         for ( my $i = 0; $i <= $#split_statements; $i += 2 ) {
249           12                                 95            push @statements, $split_statements[$i].$split_statements[$i+1];
250            8                                 21         }
251                                                      }
252                                                   
253                                                      # Wrap stmts in <> to make it more clear where each one begins/ends.
254            8                                 16      MKDEBUG && _d('statements:', map { $_ ? "<$_>" : 'none' } @statements);
255            8                                 92      return @statements;
256                                                   }
257                                                   
258                                                   sub clean_query {
259            9                    9            33      my ( $query ) = @_;
260   ***      9     50                          32      return unless $query;
261            9                                 36      $query =~ s!/\*.*?\*/! !g;  # Remove /* comment blocks */
262            9                                 33      $query =~ s/^\s+//;         # Remove leading spaces
263            9                                 58      $query =~ s/\s+$//;         # Remove trailing spaces
264            9                                 43      $query =~ s/\s{2,}/ /g;     # Remove extra spaces
265            9                                 36      return $query;
266                                                   }
267                                                   
268                                                   sub split_subquery {
269            1                    1             5      my ( $self, $query ) = @_;
270   ***      1     50                           5      return unless $query;
271            1                                  4      $query = clean_query($query);
272            1                                  5      $query =~ s/;$//;
273                                                   
274            1                                  2      my @subqueries;
275            1                                  3      my $sqno = 0;  # subquery number
276            1                                  3      my $pos  = 0;
277            1                                  7      while ( $query =~ m/(\S+)(?:\s+|\Z)/g ) {
278           11                                 31         $pos = pos($query);
279           11                                 35         my $word = $1;
280           11                                 23         MKDEBUG && _d($word, $sqno);
281           11    100                          38         if ( $word =~ m/^\(?SELECT\b/i ) {
282            2                                  8            my $start_pos = $pos - length($word) - 1;
283            2    100                          12            if ( $start_pos ) {
284            1                                  3               $sqno++;
285            1                                  2               MKDEBUG && _d('Subquery', $sqno, 'starts at', $start_pos);
286            1                                 14               $subqueries[$sqno] = {
287                                                                  start_pos => $start_pos,
288                                                                  end_pos   => 0,
289                                                                  len       => 0,
290                                                                  words     => [$word],
291                                                                  lp        => 1, # left parentheses
292                                                                  rp        => 0, # right parentheses
293                                                                  done      => 0,
294                                                               };
295                                                            }
296                                                            else {
297            1                                  7               MKDEBUG && _d('Main SELECT at pos 0');
298                                                            }
299                                                         }
300                                                         else {
301            9    100                          47            next unless $sqno;  # next unless we're in a subquery
302            3                                  6            MKDEBUG && _d('In subquery', $sqno);
303            3                                  8            my $sq = $subqueries[$sqno];
304   ***      3     50                          12            if ( $sq->{done} ) {
305   ***      0                                  0               MKDEBUG && _d('This subquery is done; SQL is for',
306                                                                  ($sqno - 1 ? "subquery $sqno" : "the main SELECT"));
307   ***      0                                  0               next;
308                                                            }
309            3                                  8            push @{$sq->{words}}, $word;
               3                                 13   
310   ***      3            50                   34            my $lp = ($word =~ tr/\(//) || 0;
311            3           100                   17            my $rp = ($word =~ tr/\)//) || 0;
312            3                                  7            MKDEBUG && _d('parentheses left', $lp, 'right', $rp);
313            3    100                          23            if ( ($sq->{lp} + $lp) - ($sq->{rp} + $rp) == 0 ) {
314            1                                  4               my $end_pos = $pos - 1;
315            1                                  5               MKDEBUG && _d('Subquery', $sqno, 'ends at', $end_pos);
316            1                                  4               $sq->{end_pos} = $end_pos;
317            1                                  7               $sq->{len}     = $end_pos - $sq->{start_pos};
318                                                            }
319                                                         }
320                                                      }
321                                                   
322            1                                  8      for my $i ( 1..$#subqueries ) {
323            1                                  3         my $sq = $subqueries[$i];
324   ***      1     50                           5         next unless $sq;
325            1                                  3         $sq->{sql} = join(' ', @{$sq->{words}});
               1                                  6   
326            1                                  9         substr $query,
327                                                            $sq->{start_pos} + 1,  # +1 for (
328                                                            $sq->{len} - 1,        # -1 for )
329                                                            "__subquery_$i";
330                                                      }
331                                                   
332            1                                  5      return $query, map { $_->{sql} } grep { defined $_ } @subqueries;
               1                                 13   
               2                                  7   
333                                                   }
334                                                   
335                                                   sub _d {
336   ***      0                    0                    my ($package, undef, $line) = caller 0;
337   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
338   ***      0                                              map { defined $_ ? $_ : 'undef' }
339                                                           @_;
340   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
341                                                   }
342                                                   
343                                                   1;
344                                                   
345                                                   # ###########################################################################
346                                                   # End QueryParser package
347                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
63    ***     50      0     62   unless $query
68           100      9     53   if ($ddl_stmt)
71           100      1      8   if ($query =~ /$ddl_stmt DATABASE\b/i)
76           100      1      7   if ($ddl_stmt =~ /CREATE/i and $query =~ /$ddl_stmt\b.+?\bSELECT\b/i)
95           100      7     46   if ($query =~ /^\s*LOCK TABLES/i)
117          100      2     86   if (not $tbl =~ /[a-zA-Z]/)
141   ***     50      0     39   unless $query
167   ***     50      0     39   unless $tbl_refs and $from
201          100      1     64   if ($tbl_ref =~ /^AS\s+\w+/i)
215          100      7     57   if $db
226   ***     50      0      8   unless $query
241   ***     50      0      8   if (@split_statements == 1) { }
260   ***     50      0      9   unless $query
270   ***     50      0      1   unless $query
281          100      2      9   if ($word =~ /^\(?SELECT\b/i) { }
283          100      1      1   if ($start_pos) { }
301          100      6      3   unless $sqno
304   ***     50      0      3   if ($$sq{'done'})
313          100      1      2   if ($$sq{'lp'} + $lp - ($$sq{'rp'} + $rp) == 0)
324   ***     50      0      1   unless $sq
337   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
76           100      3      4      1   $ddl_stmt =~ /CREATE/i and $query =~ /$ddl_stmt\b.+?\bSELECT\b/i
167   ***     33      0      0     39   $tbl_refs and $from

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
310   ***     50      0      3   $word =~ tr/(// || 0
311          100      1      2   $word =~ tr/)// || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
214   ***     66     37     27      0   $alias or $tbl


Covered Subroutines
-------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:22 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:23 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:24 
BEGIN                 1 /home/daniel/dev/maatkit/common/QueryParser.pm:26 
clean_query           9 /home/daniel/dev/maatkit/common/QueryParser.pm:259
get_aliases          39 /home/daniel/dev/maatkit/common/QueryParser.pm:140
get_tables           62 /home/daniel/dev/maatkit/common/QueryParser.pm:62 
has_derived_table     5 /home/daniel/dev/maatkit/common/QueryParser.pm:131
new                   1 /home/daniel/dev/maatkit/common/QueryParser.pm:56 
split                 8 /home/daniel/dev/maatkit/common/QueryParser.pm:225
split_subquery        1 /home/daniel/dev/maatkit/common/QueryParser.pm:269

Uncovered Subroutines
---------------------

Subroutine        Count Location                                          
----------------- ----- --------------------------------------------------
_d                    0 /home/daniel/dev/maatkit/common/QueryParser.pm:336


