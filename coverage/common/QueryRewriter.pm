---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/QueryRewriter.pm   96.1   87.8   73.1   95.0    n/a   46.2   92.0
QueryRewriter.t               100.0   50.0   33.3  100.0    n/a   53.8   98.6
Total                          98.1   86.8   69.0   96.6    n/a  100.0   94.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:11 2010
Finish:       Thu Jun 24 19:36:11 2010

Run:          QueryRewriter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Thu Jun 24 19:36:12 2010
Finish:       Thu Jun 24 19:36:13 2010

/home/daniel/dev/maatkit/common/QueryRewriter.pm

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     # This program is copyright 2007-2009 Baron Schwartz.
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
18                                                    # QueryRewriter package $Revision: 6535 $
19                                                    # ###########################################################################
20             1                    1             5   use strict;
               1                                  3   
               1                                  7   
21             1                    1             6   use warnings FATAL => 'all';
               1                                  2   
               1                                  5   
22                                                    
23                                                    package QueryRewriter;
24                                                    
25             1                    1            21   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26                                                    
27    ***      1            50      1             5   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  3   
               1                                 19   
28                                                    
29                                                    # A list of verbs that can appear in queries.  I know this is incomplete -- it
30                                                    # does not have CREATE, DROP, ALTER, TRUNCATE for example.  But I don't need
31                                                    # those for my client yet.  Other verbs: KILL, LOCK, UNLOCK
32                                                    our $verbs   = qr{^SHOW|^FLUSH|^COMMIT|^ROLLBACK|^BEGIN|SELECT|INSERT
33                                                                      |UPDATE|DELETE|REPLACE|^SET|UNION|^START|^LOCK}xi;
34                                                    my $quote_re = qr/"(?:(?!(?<!\\)").)*"|'(?:(?!(?<!\\)').)*'/; # Costly!
35                                                    my $bal;
36                                                    $bal         = qr/
37                                                                      \(
38                                                                      (?:
39                                                                         (?> [^()]+ )    # Non-parens without backtracking
40                                                                         |
41                                                                         (??{ $bal })    # Group with matching parens
42                                                                      )*
43                                                                      \)
44                                                                     /x;
45                                                    
46                                                    # The one-line comment pattern is quite crude.  This is intentional for
47                                                    # performance.  The multi-line pattern does not match version-comments.
48                                                    my $olc_re = qr/(?:--|#)[^'"\r\n]*(?=[\r\n]|\Z)/;  # One-line comments
49                                                    my $mlc_re = qr#/\*[^!].*?\*/#sm;                  # But not /*!version */
50                                                    my $vlc_re = qr#/\*.*?[0-9+].*?\*/#sm;             # For SHOW + /*!version */
51                                                    my $vlc_rf = qr#^(SHOW).*?/\*![0-9+].*?\*/#sm;     # Variation for SHOW
52                                                    
53                                                    
54                                                    sub new {
55             1                    1             7      my ( $class, %args ) = @_;
56             1                                  9      my $self = { %args };
57             1                                 13      return bless $self, $class;
58                                                    }
59                                                    
60                                                    # Strips comments out of queries.
61                                                    sub strip_comments {
62           156                  156           822      my ( $self, $query ) = @_;
63    ***    156     50                         747      return unless $query;
64           156                               1138      $query =~ s/$olc_re//go;
65           156                                689      $query =~ s/$mlc_re//go;
66           156    100                        1413      if ( $query =~ m/$vlc_rf/i ) { # contains show + version
67             2                                 14         $query =~ s/$vlc_re//go;
68                                                       }
69           156                                728      return $query;
70                                                    }
71                                                    
72                                                    # Shortens long queries by normalizing stuff out of them.  $length is used only
73                                                    # for IN() lists.  If $length is given, the query is shortened if it's longer
74                                                    # than that.
75                                                    sub shorten {
76            14                   14           114      my ( $self, $query, $length ) = @_;
77                                                       # Shorten multi-value insert/replace, all the way up to on duplicate key
78                                                       # update if it exists.
79            14                                205      $query =~ s{
80                                                          \A(
81                                                             (?:INSERT|REPLACE)
82                                                             (?:\s+LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)?
83                                                             (?:\s\w+)*\s+\S+\s+VALUES\s*\(.*?\)
84                                                          )
85                                                          \s*,\s*\(.*?(ON\s+DUPLICATE|\Z)}
86                                                          {$1 /*... omitted ...*/$2}xsi;
87                                                    
88                                                       # Shortcut!  Find out if there's an IN() list with values.
89            14    100                         143      return $query unless $query =~ m/IN\s*\(\s*(?!select)/i;
90                                                    
91                                                       # Shorten long IN() lists of literals.  But only if the string is longer than
92                                                       # the $length limit.  Assumption: values don't contain commas or closing
93                                                       # parens inside them.
94             4                                 13      my $last_length  = 0;
95             4                                 14      my $query_length = length($query);
96    ***      4            66                   82      while (
      ***                   66                        
                           100                        
97                                                          $length          > 0
98                                                          && $query_length > $length
99                                                          && $query_length < ( $last_length || $query_length + 1 )
100                                                      ) {
101            3                                  8         $last_length = $query_length;
102            3                                 62         $query =~ s{
103            4                                 30            (\bIN\s*\()    # The opening of an IN list
104                                                            ([^\)]+)       # Contents of the list, assuming no item contains paren
105                                                            (?=\))           # Close of the list
106                                                         }
107                                                         {
108                                                            $1 . __shorten($2)
109                                                         }gexsi;
110                                                      }
111                                                   
112            4                                122      return $query;
113                                                   }
114                                                   
115                                                   # Used by shorten().  The argument is the stuff inside an IN() list.  The
116                                                   # argument might look like this:
117                                                   #  1,2,3,4,5,6
118                                                   # Or, if this is a second or greater iteration, it could even look like this:
119                                                   #  /*... omitted 5 items ...*/ 6,7,8,9
120                                                   # In the second case, we need to trim out 6,7,8 and increment "5 items" to "8
121                                                   # items".  We assume that the values in the list don't contain commas; if they
122                                                   # do, the results could be a little bit wrong, but who cares.  We keep the first
123                                                   # 20 items because we don't want to nuke all the samples from the query, we just
124                                                   # want to shorten it.
125                                                   sub __shorten {
126            4                    4            76      my ( $snippet ) = @_;
127            4                               2076      my @vals = split(/,/, $snippet);
128            4    100                         383      return $snippet unless @vals > 20;
129            3                                 26      my @keep = splice(@vals, 0, 20);  # Remove and save the first 20 items
130                                                      return
131            3                                741         join(',', @keep)
132                                                         . "/*... omitted "
133                                                         . scalar(@vals)
134                                                         . " items ...*/";
135                                                   }
136                                                   
137                                                   # Normalizes variable queries to a "query fingerprint" by abstracting away
138                                                   # parameters, canonicalizing whitespace, etc.  See
139                                                   # http://dev.mysql.com/doc/refman/5.0/en/literals.html for literal syntax.
140                                                   # Note: Any changes to this function must be profiled for speed!  Speed of this
141                                                   # function is critical for mk-log-parser.  There are known bugs in this, but the
142                                                   # balance between maybe-you-get-a-bug and speed favors speed.  See past
143                                                   # revisions of this subroutine for more correct, but slower, regexes.
144                                                   sub fingerprint {
145           39                   39          6684      my ( $self, $query ) = @_;
146                                                   
147                                                      # First, we start with a bunch of special cases that we can optimize because
148                                                      # they are special behavior or because they are really big and we want to
149                                                      # throw them away as early as possible.
150           39    100                         442      $query =~ m#\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `# # mysqldump query
151                                                         && return 'mysqldump';
152                                                      # Matches queries like REPLACE /*foo.bar:3/3*/ INTO checksum.checksum
153           38    100                        2554      $query =~ m#/\*\w+\.\w+:[0-9]/[0-9]\*/#     # mk-table-checksum, etc query
154                                                         && return 'maatkit';
155                                                      # Administrator commands appear to be a comment, so return them as-is
156           37    100                         148      $query =~ m/\Aadministrator command: /
157                                                         && return $query;
158                                                      # Special-case for stored procedures.
159           36    100                         214      $query =~ m/\A\s*(call\s+\S+)\(/i
160                                                         && return lc($1); # Warning! $1 used, be careful.
161                                                      # mysqldump's INSERT statements will have long values() lists, don't waste
162                                                      # time on them... they also tend to segfault Perl on some machines when you
163                                                      # get to the "# Collapse IN() and VALUES() lists" regex below!
164           35    100                        2842      if ( my ($beginning) = $query =~ m/\A((?:INSERT|REPLACE)(?: IGNORE)?\s+INTO.+?VALUES\s*\(.*?\))\s*,\s*\(/is ) {
165            6                                 28         $query = $beginning; # Shorten multi-value INSERT statements ASAP
166                                                      }
167                                                     
168           35                                432      $query =~ s/$olc_re//go;
169           35                                121      $query =~ s/$mlc_re//go;
170           35    100                         175      $query =~ s/\Ause \S+\Z/use ?/i       # Abstract the DB in USE
171                                                         && return $query;
172                                                   
173           34                                116      $query =~ s/\\["']//g;                # quoted strings
174           34                                 95      $query =~ s/".*?"/?/sg;               # quoted strings
175           34                                137      $query =~ s/'.*?'/?/sg;               # quoted strings
176                                                      # This regex is extremely broad in its definition of what looks like a
177                                                      # number.  That is for speed.
178           34                                160      $query =~ s/[0-9+-][0-9a-f.xb+-]*/?/g;# Anything vaguely resembling numbers
179           34                                115      $query =~ s/[xb.+-]\?/?/g;            # Clean up leftovers
180           34                                 99      $query =~ s/\A\s+//;                  # Chop off leading whitespace
181           34                                108      chomp $query;                         # Kill trailing whitespace
182           34                                122      $query =~ tr[ \n\t\r\f][ ]s;          # Collapse whitespace
183           34                                121      $query = lc $query;
184           34                                101      $query =~ s/\bnull\b/?/g;             # Get rid of NULLs
185           34                                514      $query =~ s{                          # Collapse IN and VALUES lists
186                                                                  \b(in|values?)(?:[\s,]*\([\s?,]*\))+
187                                                                 }
188                                                                 {$1(?+)}gx;
189           34                                155      $query =~ s{                          # Collapse UNION
190                                                                  \b(select\s.*?)(?:(\sunion(?:\sall)?)\s\1)+
191                                                                 }
192                                                                 {$1 /*repeat$2*/}xg;
193           34                                112      $query =~ s/\blimit \?(?:, ?\?| offset \?)?/limit ?/; # LIMIT
194                                                      # The following are disabled because of speed issues.  Should we try to
195                                                      # normalize whitespace between and around operators?  My gut feeling is no.
196                                                      # $query =~ s/ , | ,|, /,/g;    # Normalize commas
197                                                      # $query =~ s/ = | =|= /=/g;       # Normalize equals
198                                                      # $query =~ s# [,=+*/-] ?|[,=+*/-] #+#g;    # Normalize operators
199                                                   
200                                                      # Remove ASC keywords from ORDER BY clause so these queries fingerprint
201                                                      # the same:
202                                                      #   SELECT * FROM `products`  ORDER BY name ASC, shape ASC;
203                                                      #   SELECT * FROM `products`  ORDER BY name, shape;
204                                                      # ASC is default so "ORDER BY col ASC" is really the same as just
205                                                      # "ORDER BY col".
206                                                      # http://code.google.com/p/maatkit/issues/detail?id=1030
207           34    100                         207      if ( $query =~ m/\bORDER BY /gi ) {  # Find, anchor on ORDER BY clause
208                                                         # Replace any occurrence of "ASC" after anchor until end of query.
209                                                         # I have verified this with regex debug: it's a single forward pass
210                                                         # without backtracking.  Probably as fast as it gets.
211   ***      2            33                   44         1 while $query =~ s/\G(.+?)\s+ASC/$1/gi && pos $query;
212                                                      }
213                                                   
214           34                                266      return $query;
215                                                   }
216                                                   
217                                                   # Gets the verbs from an SQL query, such as SELECT, UPDATE, etc.
218                                                   sub distill_verbs {
219          159                  159           798      my ( $self, $query ) = @_;
220                                                   
221                                                      # Simple verbs that normally don't have comments, extra clauses, etc.
222          159    100                        1072      $query =~ m/\A\s*call\s+(\S+)\(/i && return "CALL $1";
223          158    100                         759      $query =~ m/\A\s*use\s+/          && return "USE";
224          157    100                         673      $query =~ m/\A\s*UNLOCK TABLES/i  && return "UNLOCK";
225          156    100                         764      $query =~ m/\A\s*xa\s+(\S+)/i     && return "XA_$1";
226                                                   
227          152    100                         644      if ( $query =~ m/\Aadministrator command:/ ) {
228            1                                  5         $query =~ s/administrator command:/ADMIN/;
229            1                                  3         $query = uc $query;
230            1                                  5         return $query;
231                                                      }
232                                                   
233                                                      # All other, more complex verbs. 
234          151                                744      $query = $self->strip_comments($query);
235                                                   
236                                                      # SHOW statements are either 2 or 3 words: SHOW A (B), where A and B
237                                                      # are words; B is optional.  E.g. "SHOW TABLES" or "SHOW SLAVE STATUS". 
238                                                      # There's a few common keywords that may show up in place of A, so we
239                                                      # remove them first.  Then there's some keywords that signify extra clauses
240                                                      # that may show up in place of B and since these clauses are at the
241                                                      # end of the statement, we remove everything from the clause onward.
242          151    100                         927      if ( $query =~ m/\A\s*SHOW\s+/i ) {
243          107                                289         MKDEBUG && _d($query);
244                                                   
245                                                         # Remove common keywords.
246          107                                411         $query = uc $query;
247          107                                668         $query =~ s/\s+(?:GLOBAL|SESSION|FULL|STORAGE|ENGINE)\b/ /g;
248                                                         # This should be in the regex above but Perl doesn't seem to match
249                                                         # COUNT\(.+\) properly when it's grouped.
250          107                                390         $query =~ s/\s+COUNT[^)]+\)//g;
251                                                   
252                                                         # Remove clause keywords and everything after.
253          107                                583         $query =~ s/\s+(?:FOR|FROM|LIKE|WHERE|LIMIT|IN)\b.+//ms;
254                                                   
255                                                         # The query should now be like SHOW A B C ... delete everything after B,
256                                                         # collapse whitespace, and we're done.
257          107                               1359         $query =~ s/\A(SHOW(?:\s+\S+){1,2}).*\Z/$1/s;
258          107                                514         $query =~ s/\s+/ /g;
259          107                                263         MKDEBUG && _d($query);
260          107                                610         return $query;
261                                                      }
262                                                   
263                                                      # Data defintion statements verbs like CREATE and ALTER.
264                                                      # The two evals are a hack to keep Perl from warning that
265                                                      # "QueryParser::data_def_stmts" used only once: possible typo at...".
266                                                      # Some day we'll group all our common regex together in a packet and
267                                                      # export/import them properly.
268           44                                 86      eval $QueryParser::data_def_stmts;
269           44                                 86      eval $QueryParser::tbl_ident;
270           44                                432      my ( $dds ) = $query =~ /^\s*($QueryParser::data_def_stmts)\b/i;
271           44    100                         184      if ( $dds) {
272            9                                186         my ( $obj ) = $query =~ m/$dds.+(DATABASE|TABLE)\b/i;
273   ***      9     50                          45         $obj = uc $obj if $obj;
274            9                                 21         MKDEBUG && _d('Data def statment:', $dds, 'obj:', $obj);
275            9                                138         my ($db_or_tbl)
276                                                            = $query =~ m/(?:TABLE|DATABASE)\s+($QueryParser::tbl_ident)(\s+.*)?/i;
277            9                                 25         MKDEBUG && _d('Matches db or table:', $db_or_tbl);
278   ***      9     50                          68         return uc($dds . ($obj ? " $obj" : '')), $db_or_tbl;
279                                                      }
280                                                   
281                                                      # All other verbs, like SELECT, INSERT, UPDATE, etc.  First, get
282                                                      # the query type -- just extract all the verbs and collapse them
283                                                      # together.
284           35                                902      my @verbs = $query =~ m/\b($verbs)\b/gio;
285           35                                112      @verbs    = do {
286           35                                106         my $last = '';
287           35                                128         grep { my $pass = $_ ne $last; $last = $_; $pass } map { uc } @verbs;
              43                                159   
              43                                117   
              43                                200   
              43                                176   
288                                                      };
289                                                      # This used to be "my $verbs" but older verisons of Perl complain that
290                                                      # ""my" variable $verbs masks earlier declaration in same scope" where
291                                                      # the earlier declaration is our $verbs.
292                                                      # http://code.google.com/p/maatkit/issues/detail?id=957
293           35                                144      my $verb_str = join(q{ }, @verbs);
294           35                                111      $verb_str =~ s/( UNION SELECT)+/ UNION/g;
295                                                   
296           35                                162      return $verb_str;
297                                                   }
298                                                   
299                                                   sub __distill_tables {
300           52                   52           276      my ( $self, $query, $table, %args ) = @_;
301   ***     52            33                  479      my $qp = $args{QueryParser} || $self->{QueryParser};
302   ***     52     50                         191      die "I need a QueryParser argument" unless $qp;
303                                                   
304                                                      # "Fingerprint" the tables.
305           45                                158      my @tables = map {
306           45                               3345         $_ =~ s/`//g;
307           45                                264         $_ =~ s/(_?)[0-9]+/$1?/g;
308           45                                204         $_;
309           52                                280      } grep { defined $_ } $qp->get_tables($query);
310                                                   
311           52    100                        1213      push @tables, $table if $table;
312                                                   
313                                                      # Collapse the table list
314           52                                135      @tables = do {
315           52                                151         my $last = '';
316           52                                168         grep { my $pass = $_ ne $last; $last = $_; $pass } @tables;
              54                                170   
              54                                150   
              54                                224   
317                                                      };
318                                                   
319           52                                247      return @tables;
320                                                   }
321                                                   
322                                                   # This is kind of like fingerprinting, but it super-fingerprints to something
323                                                   # that shows the query type and the tables/objects it accesses.
324                                                   sub distill {
325          162                  162          1069      my ( $self, $query, %args ) = @_;
326                                                   
327          162    100                         829      if ( $args{generic} ) {
328                                                         # Do a generic distillation which returns the first two words
329                                                         # of a simple "cmd arg" query, like memcached and HTTP stuff.
330            3                                 21         my ($cmd, $arg) = $query =~ m/^(\S+)\s+(\S+)/;
331   ***      3     50                          13         return '' unless $cmd;
332   ***      3     50                          17         $query = (uc $cmd) . ($arg ? " $arg" : '');
333                                                      }
334                                                      else {
335                                                         # distill_verbs() may return a table if it's a special statement
336                                                         # like TRUNCATE TABLE foo.  __distill_tables() handles some but not
337                                                         # all special statements so we pass the special table from distill_verbs()
338                                                         # to __distill_tables() in case it's a statement that the latter
339                                                         # can't handle.  If it can handle it, it will eliminate any duplicate
340                                                         # tables.
341          159                               1073         my ($verbs, $table)  = $self->distill_verbs($query, %args);
342                                                   
343          159    100    100                 1824         if ( $verbs && $verbs =~ m/^SHOW/ ) {
344                                                            # Ignore tables for SHOW statements and normalize some
345                                                            # aliases like SCHMEA==DATABASE, KEYS==INDEX.
346          107                                842            my %alias_for = qw(
347                                                               SCHEMA   DATABASE
348                                                               KEYS     INDEX
349                                                               INDEXES  INDEX
350                                                            );
351          107                                583            map { $verbs =~ s/$_/$alias_for{$_}/ } keys %alias_for;
             321                               3752   
352          107                                561            $query = $verbs;
353                                                         }
354                                                         else {
355                                                            # For everything else, distill the tables.
356           52                                282            my @tables = $self->__distill_tables($query, $table, %args);
357           52                                246            $query     = join(q{ }, $verbs, @tables); 
358                                                         } 
359                                                      }
360                                                   
361          162    100                         784      if ( $args{trf} ) {
362            3                                 15         $query = $args{trf}->($query, %args);
363                                                      }
364                                                   
365          162                               1341      return $query;
366                                                   }
367                                                   
368                                                   sub convert_to_select {
369           30                   30           146      my ( $self, $query ) = @_;
370           30    100                         118      return unless $query;
371            7                                 32      $query =~ s{
              11                                 51   
372                                                                    \A.*?
373                                                                    update\s+(.*?)
374                                                                    \s+set\b(.*?)
375                                                                    (?:\s*where\b(.*?))?
376                                                                    (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
377                                                                    \Z
378                                                                 }
379                                                                 {__update_to_select($1, $2, $3, $4)}exsi
380                                                         # INSERT|REPLACE tbl (cols) VALUES (vals)
381            4                                 21         || $query =~ s{
382                                                                       \A.*?
383                                                                       (?:insert(?:\s+ignore)?|replace)\s+
384                                                                       .*?\binto\b(.*?)\(([^\)]+)\)\s*
385                                                                       values?\s*(\(.*?\))\s*
386                                                                       (?:\blimit\b|on\s+duplicate\s+key.*)?\s*
387                                                                       \Z
388                                                                    }
389                                                                    {__insert_to_select($1, $2, $3)}exsi
390                                                         # INSERT|REPLACE tbl SET vals
391            2                                 13         || $query =~ s{
392                                                                       \A.*?
393                                                                       (?:insert(?:\s+ignore)?|replace)\s+
394                                                                       (?:.*?\binto)\b(.*?)\s*
395                                                                       set\s+(.*?)\s*
396                                                                       (?:\blimit\b|on\s+duplicate\s+key.*)?\s*
397                                                                       \Z
398                                                                    }
399                                                                    {__insert_to_select_with_set($1, $2)}exsi
400           29    100    100                  841         || $query =~ s{
                           100                        
401                                                                       \A.*?
402                                                                       delete\s+(.*?)
403                                                                       \bfrom\b(.*)
404                                                                       \Z
405                                                                    }
406                                                                    {__delete_to_select($1, $2)}exsi;
407           29                                354      $query =~ s/\s*on\s+duplicate\s+key\s+update.*\Z//si;
408           29                                155      $query =~ s/\A.*?(?=\bSELECT\s*\b)//ism;
409           29                                174      return $query;
410                                                   }
411                                                   
412                                                   sub convert_select_list {
413            2                    2            13      my ( $self, $query ) = @_;
414            2    100                          18      $query =~ s{
               2                                 21   
415                                                                  \A\s*select(.*?)\bfrom\b
416                                                                 }
417                                                                 {$1 =~ m/\*/ ? "select 1 from" : "select isnull(coalesce($1)) from"}exi;
418            2                                 14      return $query;
419                                                   }
420                                                   
421                                                   sub __delete_to_select {
422            2                    2            14      my ( $delete, $join ) = @_;
423            2    100                          14      if ( $join =~ m/\bjoin\b/ ) {
424            1                                  7         return "select 1 from $join";
425                                                      }
426            1                                  7      return "select * from $join";
427                                                   }
428                                                   
429                                                   sub __insert_to_select {
430           11                   11            77      my ( $tbl, $cols, $vals ) = @_;
431           11                                 28      MKDEBUG && _d('Args:', @_);
432           11                                 55      my @cols = split(/,/, $cols);
433           11                                 28      MKDEBUG && _d('Cols:', @cols);
434           11                                 68      $vals =~ s/^\(|\)$//g; # Strip leading/trailing parens
435           11                                242      my @vals = $vals =~ m/($quote_re|[^,]*${bal}[^,]*|[^,]+)/g;
436           11                                 42      MKDEBUG && _d('Vals:', @vals);
437   ***     11     50                          45      if ( @cols == @vals ) {
438           27                                217         return "select * from $tbl where "
439           11                                 80            . join(' and ', map { "$cols[$_]=$vals[$_]" } (0..$#cols));
440                                                      }
441                                                      else {
442   ***      0                                  0         return "select * from $tbl limit 1";
443                                                      }
444                                                   }
445                                                   
446                                                   sub __insert_to_select_with_set {
447            4                    4            24      my ( $from, $set ) = @_;
448            4                                 29      $set =~ s/,/ and /g;
449            4                                 43      return "select * from $from where $set ";
450                                                   }
451                                                   
452                                                   sub __update_to_select {
453            7                    7            53      my ( $from, $set, $where, $limit ) = @_;
454            7    100                         101      return "select $set from $from "
                    100                               
455                                                         . ( $where ? "where $where" : '' )
456                                                         . ( $limit ? " $limit "      : '' );
457                                                   }
458                                                   
459                                                   sub wrap_in_derived {
460            3                    3            14      my ( $self, $query ) = @_;
461            3    100                          16      return unless $query;
462            2    100                          28      return $query =~ m/\A\s*select/i
463                                                         ? "select 1 from ($query) as x limit 1"
464                                                         : $query;
465                                                   }
466                                                   
467                                                   sub _d {
468   ***      0                    0                    my ($package, undef, $line) = caller 0;
469   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
470   ***      0                                              map { defined $_ ? $_ : 'undef' }
471                                                           @_;
472   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
473                                                   }
474                                                   
475                                                   1;
476                                                   
477                                                   # ###########################################################################
478                                                   # End QueryRewriter package
479                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
63    ***     50      0    156   unless $query
66           100      2    154   if ($query =~ /$vlc_rf/i)
89           100     10      4   unless $query =~ /IN\s*\(\s*(?!select)/i
128          100      1      3   unless @vals > 20
150          100      1     38   if $query =~ m[\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `]
153          100      1     37   if $query =~ m[/\*\w+\.\w+:[0-9]/[0-9]\*/]
156          100      1     36   if $query =~ /\Aadministrator command: /
159          100      1     35   if $query =~ /\A\s*(call\s+\S+)\(/i
164          100      6     29   if (my($beginning) = $query =~ /\A((?:INSERT|REPLACE)(?: IGNORE)?\s+INTO.+?VALUES\s*\(.*?\))\s*,\s*\(/is)
170          100      1     34   if $query =~ s/\Ause \S+\Z/use ?/i
207          100      2     32   if ($query =~ /\bORDER BY /gi)
222          100      1    158   if $query =~ /\A\s*call\s+(\S+)\(/i
223          100      1    157   if $query =~ /\A\s*use\s+/
224          100      1    156   if $query =~ /\A\s*UNLOCK TABLES/i
225          100      4    152   if $query =~ /\A\s*xa\s+(\S+)/i
227          100      1    151   if ($query =~ /\Aadministrator command:/)
242          100    107     44   if ($query =~ /\A\s*SHOW\s+/i)
271          100      9     35   if ($dds)
273   ***     50      9      0   if $obj
278   ***     50      9      0   $obj ? :
302   ***     50      0     52   unless $qp
311          100      9     43   if $table
327          100      3    159   if ($args{'generic'}) { }
331   ***     50      0      3   unless $cmd
332   ***     50      3      0   $arg ? :
343          100    107     52   if ($verbs and $verbs =~ /^SHOW/) { }
361          100      3    159   if ($args{'trf'})
370          100      1     29   unless $query
400          100      7     22   unless $query =~ s/
                 \A.*?
                 update\s+(.*?)
                 \s+set\b(.*?)
                 (?:\s*where\b(.*?))?
                 (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
                 \Z
              /__update_to_select($1, $2, $3, $4);/eisx or $query =~ s/
                    \A.*?
                    (?:insert(?:\s+ignore)?|replace)\s+
                    .*?\binto\b(.*?)\(([^\)]+)\)\s*
                    values?\s*(\(.*?\))\s*
                    (?:\blimit\b|on\s+duplicate\s+key.*)?\s*
                    \Z
                 /__insert_to_select($1, $2, $3);/eisx or $query =~ s/
                    \A.*?
                    (?:insert(?:\s+ignore)?|replace)\s+
                    (?:.*?\binto)\b(.*?)\s*
                    set\s+(.*?)\s*
                    (?:\blimit\b|on\s+duplicate\s+key.*)?\s*
                    \Z
                 /__insert_to_select_with_set($1, $2);/eisx
414          100      1      1   $1 =~ /\*/ ? :
423          100      1      1   if ($join =~ /\bjoin\b/)
437   ***     50     11      0   if (@cols == @vals) { }
454          100      4      3   $where ? :
             100      1      6   $limit ? :
461          100      1      2   unless $query
462          100      1      1   $query =~ /\A\s*select/i ? :
469   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
96    ***     66      0      1      6   $length > 0 and $query_length > $length
             100      1      3      3   $length > 0 and $query_length > $length and $query_length < ($last_length || $query_length + 1)
211   ***     33      0      2      0   $query =~ s/\G(.+?)\s+ASC/$1/gi and pos $query
343          100      2     50    107   $verbs and $verbs =~ /^SHOW/

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
96    ***     66      3      3      0   $last_length || $query_length + 1
301   ***     33      0     52      0   $args{'QueryParser'} || $$self{'QueryParser'}
400          100      7     11     11   $query =~ s/
                 \A.*?
                 update\s+(.*?)
                 \s+set\b(.*?)
                 (?:\s*where\b(.*?))?
                 (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
                 \Z
              /__update_to_select($1, $2, $3, $4);/eisx or $query =~ s/
                    \A.*?
                    (?:insert(?:\s+ignore)?|replace)\s+
                    .*?\binto\b(.*?)\(([^\)]+)\)\s*
                    values?\s*(\(.*?\))\s*
                    (?:\blimit\b|on\s+duplicate\s+key.*)?\s*
                    \Z
                 /__insert_to_select($1, $2, $3);/eisx
             100     18      4      7   $query =~ s/
                 \A.*?
                 update\s+(.*?)
                 \s+set\b(.*?)
                 (?:\s*where\b(.*?))?
                 (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
                 \Z
              /__update_to_select($1, $2, $3, $4);/eisx or $query =~ s/
                    \A.*?
                    (?:insert(?:\s+ignore)?|replace)\s+
                    .*?\binto\b(.*?)\(([^\)]+)\)\s*
                    values?\s*(\(.*?\))\s*
                    (?:\blimit\b|on\s+duplicate\s+key.*)?\s*
                    \Z
                 /__insert_to_select($1, $2, $3);/eisx or $query =~ s/
                    \A.*?
                    (?:insert(?:\s+ignore)?|replace)\s+
                    (?:.*?\binto)\b(.*?)\s*
                    set\s+(.*?)\s*
                    (?:\blimit\b|on\s+duplicate\s+key.*)?\s*
                    \Z
                 /__insert_to_select_with_set($1, $2);/eisx


Covered Subroutines
-------------------

Subroutine                  Count Location                                            
--------------------------- ----- ----------------------------------------------------
BEGIN                           1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:20 
BEGIN                           1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:21 
BEGIN                           1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:25 
BEGIN                           1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:27 
__delete_to_select              2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:422
__distill_tables               52 /home/daniel/dev/maatkit/common/QueryRewriter.pm:300
__insert_to_select             11 /home/daniel/dev/maatkit/common/QueryRewriter.pm:430
__insert_to_select_with_set     4 /home/daniel/dev/maatkit/common/QueryRewriter.pm:447
__shorten                       4 /home/daniel/dev/maatkit/common/QueryRewriter.pm:126
__update_to_select              7 /home/daniel/dev/maatkit/common/QueryRewriter.pm:453
convert_select_list             2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:413
convert_to_select              30 /home/daniel/dev/maatkit/common/QueryRewriter.pm:369
distill                       162 /home/daniel/dev/maatkit/common/QueryRewriter.pm:325
distill_verbs                 159 /home/daniel/dev/maatkit/common/QueryRewriter.pm:219
fingerprint                    39 /home/daniel/dev/maatkit/common/QueryRewriter.pm:145
new                             1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:55 
shorten                        14 /home/daniel/dev/maatkit/common/QueryRewriter.pm:76 
strip_comments                156 /home/daniel/dev/maatkit/common/QueryRewriter.pm:62 
wrap_in_derived                 3 /home/daniel/dev/maatkit/common/QueryRewriter.pm:460

Uncovered Subroutines
---------------------

Subroutine                  Count Location                                            
--------------------------- ----- ----------------------------------------------------
_d                              0 /home/daniel/dev/maatkit/common/QueryRewriter.pm:468


QueryRewriter.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     
4                                                     BEGIN {
5     ***      1     50     33      1            33      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
6                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
7              1                                  7      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
8                                                     };
9                                                     
10             1                    1            10   use strict;
               1                                  3   
               1                                  5   
11             1                    1             6   use warnings FATAL => 'all';
               1                                  3   
               1                                  6   
12             1                    1            11   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
13             1                    1            10   use Test::More tests => 255;
               1                                  2   
               1                                 10   
14                                                    
15             1                    1            11   use QueryRewriter;
               1                                  3   
               1                                 10   
16             1                    1            12   use QueryParser;
               1                                  3   
               1                                 10   
17             1                    1            11   use MaatkitTest;
               1                                  4   
               1                                 41   
18                                                    
19             1                                 16   my $qp = new QueryParser();
20             1                                 28   my $qr = new QueryRewriter(QueryParser=>$qp);
21                                                    
22                                                    # #############################################################################
23                                                    # strip_comments()
24                                                    # #############################################################################
25                                                    
26             1                                  7   is(
27                                                       $qr->strip_comments("select \n--bar\n foo"),
28                                                       "select \n\n foo",
29                                                       'Removes one-line comments',
30                                                    );
31                                                    
32             1                                  7   is(
33                                                       $qr->strip_comments("select foo--bar\nfoo"),
34                                                       "select foo\nfoo",
35                                                       'Removes one-line comments without running them together',
36                                                    );
37                                                    
38             1                                  5   is(
39                                                       $qr->strip_comments("select foo -- bar"),
40                                                       "select foo ",
41                                                       'Removes one-line comments at end of line',
42                                                    );
43                                                    
44             1                                  6   is(
45                                                       $qr->strip_comments("select /*\nhello!*/ 1"),
46                                                       'select  1',
47                                                       'Stripped star comment',
48                                                    );
49                                                    
50             1                                  6   is(
51                                                       $qr->strip_comments('select /*!40101 hello*/ 1'),
52                                                       'select /*!40101 hello*/ 1',
53                                                       'Left version star comment',
54                                                    );
55                                                    
56                                                    # #############################################################################
57                                                    # fingerprint()
58                                                    # #############################################################################
59                                                    
60             1                                  7   is(
61                                                       $qr->fingerprint(
62                                                          q{UPDATE groups_search SET  charter = '   -------3\'\' XXXXXXXXX.\n    \n    -----------------------------------------------------', show_in_list = 'Y' WHERE group_id='aaaaaaaa'}),
63                                                       'update groups_search set charter = ?, show_in_list = ? where group_id=?',
64                                                       'complex comments',
65                                                    );
66                                                    
67             1                                  6   is(
68                                                       $qr->fingerprint("SELECT /*!40001 SQL_NO_CACHE */ * FROM `film`"),
69                                                       "mysqldump",
70                                                       'Fingerprints all mysqldump SELECTs together',
71                                                    );
72                                                    
73             1                                  6   is(
74                                                       $qr->fingerprint("CALL foo(1, 2, 3)"),
75                                                       "call foo",
76                                                       'Fingerprints stored procedure calls specially',
77                                                    );
78                                                    
79                                                    
80             1                                  7   is(
81                                                       $qr->fingerprint('administrator command: Init DB'),
82                                                       'administrator command: Init DB',
83                                                       'Fingerprints admin commands as themselves',
84                                                    );
85                                                    
86             1                                  6   is(
87                                                       $qr->fingerprint(
88                                                          q{REPLACE /*foo.bar:3/3*/ INTO checksum.checksum (db, tbl, }
89                                                          .q{chunk, boundaries, this_cnt, this_crc) SELECT 'foo', 'bar', }
90                                                          .q{2 AS chunk_num, '`id` >= 2166633', COUNT(*) AS cnt, }
91                                                          .q{LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `id`, `created_by`, }
92                                                          .q{`created_date`, `updated_by`, `updated_date`, `ppc_provider`, }
93                                                          .q{`account_name`, `provider_account_id`, `campaign_name`, }
94                                                          .q{`provider_campaign_id`, `adgroup_name`, `provider_adgroup_id`, }
95                                                          .q{`provider_keyword_id`, `provider_ad_id`, `foo`, `reason`, }
96                                                          .q{`foo_bar_bazz_id`, `foo_bar_baz`, CONCAT(ISNULL(`created_by`), }
97                                                          .q{ISNULL(`created_date`), ISNULL(`updated_by`), ISNULL(`updated_date`), }
98                                                          .q{ISNULL(`ppc_provider`), ISNULL(`account_name`), }
99                                                          .q{ISNULL(`provider_account_id`), ISNULL(`campaign_name`), }
100                                                         .q{ISNULL(`provider_campaign_id`), ISNULL(`adgroup_name`), }
101                                                         .q{ISNULL(`provider_adgroup_id`), ISNULL(`provider_keyword_id`), }
102                                                         .q{ISNULL(`provider_ad_id`), ISNULL(`foo`), ISNULL(`reason`), }
103                                                         .q{ISNULL(`foo_base_foo_id`), ISNULL(`fooe_foo_id`)))) AS UNSIGNED)), 10, }
104                                                         .q{16)) AS crc FROM `foo`.`bar` USE INDEX (`PRIMARY`) WHERE }
105                                                         .q{(`id` >= 2166633); }),
106                                                      'maatkit',
107                                                      'Fingerprints mk-table-checksum queries together',
108                                                   );
109                                                   
110            1                                  6   is(
111                                                      $qr->fingerprint("use `foo`"),
112                                                      "use ?",
113                                                      'Removes identifier from USE',
114                                                   );
115                                                   
116            1                                  8   is(
117                                                      $qr->fingerprint("select \n--bar\n foo"),
118                                                      "select foo",
119                                                      'Removes one-line comments in fingerprints',
120                                                   );
121                                                   
122                                                   
123            1                                233   is(
124                                                      $qr->fingerprint("select foo--bar\nfoo"),
125                                                      "select foo foo",
126                                                      'Removes one-line comments in fingerprint without mushing things together',
127                                                   );
128                                                   
129            1                                  6   is(
130                                                      $qr->fingerprint("select foo -- bar\n"),
131                                                      "select foo ",
132                                                      'Removes one-line EOL comments in fingerprints',
133                                                   );
134                                                   
135                                                   # This one is too expensive!
136                                                   #is(
137                                                   #   $qr->fingerprint(
138                                                   #      "select a,b ,c , d from tbl where a=5 or a = 5 or a=5 or a =5"),
139                                                   #   "select a, b, c, d from tbl where a=? or a=? or a=? or a=?",
140                                                   #   "Normalizes commas and equals",
141                                                   #);
142                                                   
143            1                                  5   is(
144                                                      $qr->fingerprint("select null, 5.001, 5001. from foo"),
145                                                      "select ?, ?, ? from foo",
146                                                      "Handles bug from perlmonks thread 728718",
147                                                   );
148                                                   
149            1                                  6   is(
150                                                      $qr->fingerprint("select 'hello', '\nhello\n', \"hello\", '\\'' from foo"),
151                                                      "select ?, ?, ?, ? from foo",
152                                                      "Handles quoted strings",
153                                                   );
154                                                   
155                                                   
156            1                                  5   is(
157                                                      $qr->fingerprint("select 'hello'\n"),
158                                                      "select ?",
159                                                      "Handles trailing newline",
160                                                   );
161                                                   
162                                                   # This is a known deficiency, fixes seem to be expensive though.
163            1                                  6   is(
164                                                      $qr->fingerprint("select '\\\\' from foo"),
165                                                      "select '\\ from foo",
166                                                      "Does not handle all quoted strings",
167                                                   );
168                                                   
169            1                                  5   is(
170                                                      $qr->fingerprint("select   foo"),
171                                                      "select foo",
172                                                      'Collapses whitespace',
173                                                   );
174                                                   
175            1                                  6   is(
176                                                      $qr->fingerprint('SELECT * from foo where a = 5'),
177                                                      'select * from foo where a = ?',
178                                                      'Lowercases, replaces integer',
179                                                   );
180                                                   
181            1                                  7   is(
182                                                      $qr->fingerprint('select 0e0, +6e-30, -6.00 from foo where a = 5.5 or b=0.5 or c=.5'),
183                                                      'select ?, ?, ? from foo where a = ? or b=? or c=?',
184                                                      'Floats',
185                                                   );
186                                                   
187            1                                  6   is(
188                                                      $qr->fingerprint("select 0x0, x'123', 0b1010, b'10101' from foo"),
189                                                      'select ?, ?, ?, ? from foo',
190                                                      'Hex/bit',
191                                                   );
192                                                   
193            1                                  6   is(
194                                                      $qr->fingerprint(" select  * from\nfoo where a = 5"),
195                                                      'select * from foo where a = ?',
196                                                      'Collapses whitespace',
197                                                   );
198                                                   
199            1                                  6   is(
200                                                      $qr->fingerprint("select * from foo where a in (5) and b in (5, 8,9 ,9 , 10)"),
201                                                      'select * from foo where a in(?+) and b in(?+)',
202                                                      'IN lists',
203                                                   );
204                                                   
205            1                                  6   is(
206                                                      $qr->fingerprint("select foo_1 from foo_2_3"),
207                                                      'select foo_? from foo_?_?',
208                                                      'Numeric table names',
209                                                   );
210                                                   
211                                                   # 123f00 => ?oo because f "looks like it could be a number".
212            1                                  7   is(
213                                                      $qr->fingerprint("select 123foo from 123foo", { prefixes => 1 }),
214                                                      'select ?oo from ?oo',
215                                                      'Numeric table name prefixes',
216                                                   );
217                                                   
218            1                                  8   is(
219                                                      $qr->fingerprint("select 123_foo from 123_foo", { prefixes => 1 }),
220                                                      'select ?_foo from ?_foo',
221                                                      'Numeric table name prefixes with underscores',
222                                                   );
223                                                   
224            1                                  7   is(
225                                                      $qr->fingerprint("insert into abtemp.coxed select foo.bar from foo"),
226                                                      'insert into abtemp.coxed select foo.bar from foo',
227                                                      'A string that needs no changes',
228                                                   );
229                                                   
230            1                                  5   is(
231                                                      $qr->fingerprint('insert into foo(a, b, c) values(2, 4, 5)'),
232                                                      'insert into foo(a, b, c) values(?+)',
233                                                      'VALUES lists',
234                                                   );
235                                                   
236                                                   
237            1                                  6   is(
238                                                      $qr->fingerprint('insert into foo(a, b, c) values(2, 4, 5) , (2,4,5)'),
239                                                      'insert into foo(a, b, c) values(?+)',
240                                                      'VALUES lists with multiple ()',
241                                                   );
242                                                   
243            1                                  5   is(
244                                                      $qr->fingerprint('insert into foo(a, b, c) value(2, 4, 5)'),
245                                                      'insert into foo(a, b, c) value(?+)',
246                                                      'VALUES lists with VALUE()',
247                                                   );
248                                                   
249            1                                  5   is(
250                                                      $qr->fingerprint('select * from foo limit 5'),
251                                                      'select * from foo limit ?',
252                                                      'limit alone',
253                                                   );
254                                                   
255            1                                  5   is(
256                                                      $qr->fingerprint('select * from foo limit 5, 10'),
257                                                      'select * from foo limit ?',
258                                                      'limit with comma-offset',
259                                                   );
260                                                   
261            1                                  6   is(
262                                                      $qr->fingerprint('select * from foo limit 5 offset 10'),
263                                                      'select * from foo limit ?',
264                                                      'limit with offset',
265                                                   );
266                                                   
267            1                                  5   is(
268                                                      $qr->fingerprint('select 1 union select 2 union select 4'),
269                                                      'select ? /*repeat union*/',
270                                                      'union fingerprints together',
271                                                   );
272                                                   
273            1                                  5   is(
274                                                      $qr->fingerprint('select 1 union all select 2 union all select 4'),
275                                                      'select ? /*repeat union all*/',
276                                                      'union all fingerprints together',
277                                                   );
278                                                   
279            1                                  6   is(
280                                                      $qr->fingerprint(
281                                                         q{select * from (select 1 union all select 2 union all select 4) as x }
282                                                         . q{join (select 2 union select 2 union select 3) as y}),
283                                                      q{select * from (select ? /*repeat union all*/) as x }
284                                                         . q{join (select ? /*repeat union*/) as y},
285                                                      'union all fingerprints together',
286                                                   );
287                                                   
288                                                   # Issue 322: mk-query-digest segfault before report
289            1                                  8   is(
290                                                      $qr->fingerprint( load_file('common/t/samples/huge_replace_into_values.txt') ),
291                                                      q{replace into `film_actor` values(?+)},
292                                                      'huge replace into values() (issue 322)',
293                                                   );
294            1                                 35   is(
295                                                      $qr->fingerprint( load_file('common/t/samples/huge_insert_ignore_into_values.txt') ),
296                                                      q{insert ignore into `film_actor` values(?+)},
297                                                      'huge insert ignore into values() (issue 322)',
298                                                   );
299            1                                  8   is(
300                                                      $qr->fingerprint( load_file('common/t/samples/huge_explicit_cols_values.txt') ),
301                                                      q{insert into foo (a,b,c,d,e,f,g,h) values(?+)},
302                                                      'huge insert with explicit columns before values() (issue 322)',
303                                                   );
304                                                   
305                                                   # Those ^ aren't huge enough.  This one is 1.2M large. 
306            1                              35339   my $huge_insert = `zcat $trunk/common/t/samples/slow039.txt.gz | tail -n 1`;
307            1                                 45   is(
308                                                      $qr->fingerprint($huge_insert),
309                                                      q{insert into the_universe values(?+)},
310                                                      'truly huge insert 1/2 (issue 687)'
311                                                   );
312            1                              35928   $huge_insert = `zcat $trunk/common/t/samples/slow040.txt.gz | tail -n 2`;
313            1                                 74   is(
314                                                      $qr->fingerprint($huge_insert),
315                                                      q{insert into the_universe values(?+)},
316                                                      'truly huge insert 2/2 (issue 687)'
317                                                   );
318                                                   
319                                                   # Issue 1030: Fingerprint can remove ORDER BY ASC
320            1                                 12   is(
321                                                      $qr->fingerprint(
322                                                         "select c from t where i=1 order by c asc",
323                                                      ),
324                                                      "select c from t where i=? order by c",
325                                                      "Remove ASC from ORDER BY"
326                                                   );
327            1                                  6   is(
328                                                      $qr->fingerprint(
329                                                         "select * from t where i=1 order by a, b ASC, d DESC, e asc",
330                                                      ),
331                                                      "select * from t where i=? order by a, b, d desc, e",
332                                                      "Remove only ASC from ORDER BY"
333                                                   );
334                                                   
335                                                   # #############################################################################
336                                                   # convert_to_select()
337                                                   # #############################################################################
338                                                   
339            1                                 11   is($qr->convert_to_select(), undef, 'No query');
340                                                   
341            1                                  5   is(
342                                                      $qr->convert_to_select(
343                                                         'select * from tbl where id = 1'
344                                                      ),
345                                                      'select * from tbl where id = 1',
346                                                      'Does not convert select to select',
347                                                   );
348                                                   
349            1                                  6   is(
350                                                      $qr->convert_to_select(q{INSERT INTO foo.bar (col1, col2, col3)
351                                                          VALUES ('unbalanced(', 'val2', 3)}),
352                                                      q{select * from  foo.bar  where col1='unbalanced(' and  }
353                                                      . q{col2= 'val2' and  col3= 3},
354                                                      'unbalanced paren inside a string in VALUES',
355                                                   );
356                                                   
357                                                   # convert REPLACE #############################################################
358                                                   
359            1                                  7   is(
360                                                      $qr->convert_to_select(
361                                                         'replace into foo select * from bar',
362                                                      ),
363                                                      'select * from bar',
364                                                      'convert REPLACE SELECT',
365                                                   );
366                                                   
367            1                                  6   is(
368                                                      $qr->convert_to_select(
369                                                         'replace into foo select`faz` from bar',
370                                                      ),
371                                                      'select`faz` from bar',
372                                                      'convert REPLACE SELECT`col`',
373                                                   );
374                                                   
375            1                                  5   is(
376                                                      $qr->convert_to_select(
377                                                         'replace into foo(a, b, c) values(1, 3, 5) on duplicate key update foo=bar',
378                                                      ),
379                                                      'select * from  foo where a=1 and  b= 3 and  c= 5',
380                                                      'convert REPLACE (cols) VALUES ON DUPE KEY',
381                                                   );
382                                                   
383            1                                  6   is(
384                                                      $qr->convert_to_select(
385                                                         'replace into foo(a, b, c) values(now(), "3", 5)',
386                                                      ),
387                                                      'select * from  foo where a=now() and  b= "3" and  c= 5',
388                                                      'convert REPLACE (cols) VALUES (now())',
389                                                   );
390                                                   
391            1                                  9   is(
392                                                      $qr->convert_to_select(
393                                                         'replace into foo(a, b, c) values(current_date - interval 1 day, "3", 5)',
394                                                      ),
395                                                      'select * from  foo where a=current_date - interval 1 day and  b= "3" and  c= 5',
396                                                      'convert REPLACE (cols) VALUES (complex expression)',
397                                                   );
398                                                   
399            1                                  6   is(
400                                                      $qr->convert_to_select(q{
401                                                   REPLACE DELAYED INTO
402                                                   `db1`.`tbl2`(`col1`,col2)
403                                                   VALUES ('617653','2007-09-11')}),
404                                                      qq{select * from \n`db1`.`tbl2` where `col1`='617653' and col2='2007-09-11'},
405                                                      'convert REPLACE DELAYED (cols) VALUES',
406                                                   );
407                                                   
408            1                                  6   is(
409                                                      $qr->convert_to_select(
410                                                         'replace into tbl set col1="a val", col2=123, col3=null',
411                                                      ),
412                                                      'select * from  tbl where col1="a val" and  col2=123 and  col3=null ',
413                                                      'convert REPLACE SET'
414                                                   );
415                                                   
416                                                   # convert INSERT ##############################################################
417                                                   
418            1                                  6   is(
419                                                      $qr->convert_to_select(
420                                                         'insert into foo(a, b, c) values(1, 3, 5)',
421                                                      ),
422                                                      'select * from  foo where a=1 and  b= 3 and  c= 5',
423                                                      'convert INSERT (cols) VALUES',
424                                                   );
425                                                   
426            1                                  7   is(
427                                                      $qr->convert_to_select(
428                                                         'insert into foo(a, b, c) value(1, 3, 5)',
429                                                      ),
430                                                      'select * from  foo where a=1 and  b= 3 and  c= 5',
431                                                      'convert INSERT (cols) VALUE',
432                                                   );
433                                                   
434                                                   # Issue 599: mk-slave-prefetch doesn't parse INSERT IGNORE
435            1                                  6   is(
436                                                      $qr->convert_to_select(
437                                                         'insert ignore into foo(a, b, c) values(1, 3, 5)',
438                                                      ),
439                                                      'select * from  foo where a=1 and  b= 3 and  c= 5',
440                                                      'convert INSERT IGNORE (cols) VALUES',
441                                                   );
442                                                   
443            1                                  6   is(
444                                                      $qr->convert_to_select(
445                                                         'INSERT IGNORE INTO Foo (clm1, clm2) VALUE (1,2)',
446                                                      ),
447                                                      'select * from  Foo  where clm1=1 and  clm2=2',
448                                                      'convert INSERT IGNORE (cols) VALUE',
449                                                   );
450                                                   
451            1                                  6   is(
452                                                      $qr->convert_to_select(
453                                                         'insert into foo select * from bar join baz using (bat)',
454                                                      ),
455                                                      'select * from bar join baz using (bat)',
456                                                      'convert INSERT SELECT',
457                                                   );
458                                                   
459                                                   # Issue 600: mk-slave-prefetch doesn't parse INSERT INTO Table SET c1 = v1,
460                                                   # c2 = v2 ...
461            1                                  7   is(
462                                                      $qr->convert_to_select(
463                                                         "INSERT INTO Table SET c1 = 'v1', c2 = 'v2', c3 = 'v3'",
464                                                      ),
465                                                      "select * from  Table where c1 = 'v1' and  c2 = 'v2' and  c3 = 'v3' ",
466                                                      'convert INSERT SET char cols',
467                                                   );
468                                                   
469            1                                  6   is(
470                                                      $qr->convert_to_select(
471                                                         "INSERT INTO db.tbl SET c1=NULL,c2=42,c3='some value with spaces'",
472                                                      ),
473                                                      "select * from  db.tbl where c1=NULL and c2=42 and c3='some value with spaces' ",
474                                                      'convert INSERT SET NULL col, int col, char col with space',
475                                                   );
476                                                   
477            1                                  5   is(
478                                                      $qr->convert_to_select(
479                                                         'insert into foo (col1) values (1) on duplicate key update',
480                                                      ),
481                                                      'select * from  foo  where col1=1',
482                                                      'convert INSERT (cols) VALUES ON DUPE KEY UPDATE'
483                                                   );
484                                                   
485            1                                  5   is(
486                                                      $qr->convert_to_select(
487                                                         'insert into foo (col1) value (1) on duplicate key update',
488                                                      ),
489                                                      'select * from  foo  where col1=1',
490                                                      'convert INSERT (cols) VALUE ON DUPE KEY UPDATE'
491                                                   );
492                                                   
493            1                                  6   is(
494                                                      $qr->convert_to_select(
495                                                         "insert into tbl set col='foo', col2='some val' on duplicate key update",
496                                                      ),
497                                                      "select * from  tbl where col='foo' and  col2='some val' ",
498                                                      'convert INSERT SET ON DUPE KEY UPDATE',
499                                                   );
500                                                   
501            1                                  6   is(
502                                                      $qr->convert_to_select(
503                                                         'insert into foo select * from bar where baz=bat on duplicate key update',
504                                                      ),
505                                                      'select * from bar where baz=bat',
506                                                      'convert INSERT SELECT ON DUPE KEY UPDATE',
507                                                   );
508                                                   
509                                                   # convert UPDATE ##############################################################
510                                                   
511            1                                  6   is(
512                                                      $qr->convert_to_select(
513                                                         'update foo set bar=baz where bat=fiz',
514                                                      ),
515                                                      'select  bar=baz from foo where  bat=fiz',
516                                                      'update set',
517                                                   );
518                                                   
519            1                                  7   is(
520                                                      $qr->convert_to_select(
521                                                         'update foo inner join bar using(baz) set big=little',
522                                                      ),
523                                                      'select  big=little from foo inner join bar using(baz) ',
524                                                      'delete inner join',
525                                                   );
526                                                   
527            1                                  8   is(
528                                                      $qr->convert_to_select(
529                                                         'update foo set bar=baz limit 50',
530                                                      ),
531                                                      'select  bar=baz  from foo  limit 50 ',
532                                                      'update with limit',
533                                                   );
534                                                   
535            1                                  6   is(
536                                                      $qr->convert_to_select(
537                                                   q{UPDATE foo.bar
538                                                   SET    whereproblem= '3364', apple = 'fish'
539                                                   WHERE  gizmo='5091'}
540                                                      ),
541                                                      q{select     whereproblem= '3364', apple = 'fish' from foo.bar where   gizmo='5091'},
542                                                      'unknown issue',
543                                                   );
544                                                   
545                                                   # Insanity...
546            1                                  5   is(
547                                                      $qr->convert_to_select('
548                                                   update db2.tbl1 as p
549                                                      inner join (
550                                                         select p2.col1, p2.col2
551                                                         from db2.tbl1 as p2
552                                                            inner join db2.tbl3 as ba
553                                                               on p2.col1 = ba.tbl3
554                                                         where col4 = 0
555                                                         order by priority desc, col1, col2
556                                                         limit 10
557                                                      ) as chosen on chosen.col1 = p.col1
558                                                         and chosen.col2 = p.col2
559                                                      set p.col4 = 149945'),
560                                                      'select  p.col4 = 149945 from db2.tbl1 as p
561                                                      inner join (
562                                                         select p2.col1, p2.col2
563                                                         from db2.tbl1 as p2
564                                                            inner join db2.tbl3 as ba
565                                                               on p2.col1 = ba.tbl3
566                                                         where col4 = 0
567                                                         order by priority desc, col1, col2
568                                                         limit 10
569                                                      ) as chosen on chosen.col1 = p.col1
570                                                         and chosen.col2 = p.col2 ',
571                                                      'SELECT in the FROM clause',
572                                                   );
573                                                   
574            1                                  5   is(
575                                                      $qr->convert_to_select("UPDATE tbl SET col='wherex'WHERE crazy=1"),
576                                                      "select  col='wherex' from tbl where  crazy=1",
577                                                      "update with SET col='wherex'WHERE"
578                                                   );
579                                                   
580            1                                  6   is($qr->convert_to_select(
581                                                      q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
582                                                      . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
583                                                      . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
584                                                      . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
585                                                      . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
586                                                      . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
587                                                      . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )}),
588                                                      "select  GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME='Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59' from GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU where  PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1 AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0 AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )",
589                                                      'update with no space between quoted string and where (issue 168)'
590                                                   );
591                                                   
592                                                   # convert DELETE ##############################################################
593                                                   
594            1                                  5   is(
595                                                      $qr->convert_to_select(
596                                                         'delete from foo where bar = baz',
597                                                      ),
598                                                      'select * from  foo where bar = baz',
599                                                      'delete',
600                                                   );
601                                                   
602            1                                  7   is(
603                                                      $qr->convert_to_select(q{delete foo.bar b from foo.bar b left join baz.bat c on a=b where nine>eight}),
604                                                      'select 1 from  foo.bar b left join baz.bat c on a=b where nine>eight',
605                                                      'Do not select * from a join',
606                                                   );
607                                                   
608                                                   # #############################################################################
609                                                   # wrap_in_derived()
610                                                   # #############################################################################
611                                                   
612            1                                  6   is($qr->wrap_in_derived(), undef, 'Cannot wrap undef');
613                                                   
614            1                                  6   is(
615                                                      $qr->wrap_in_derived(
616                                                         'select * from foo',
617                                                      ),
618                                                      'select 1 from (select * from foo) as x limit 1',
619                                                      'wrap in derived table',
620                                                   );
621                                                   
622            1                                  6   is(
623                                                      $qr->wrap_in_derived('set timestamp=134'),
624                                                      'set timestamp=134',
625                                                      'Do not wrap non-SELECT queries',
626                                                   );
627                                                   
628                                                   # #############################################################################
629                                                   # convert_select_list()
630                                                   # #############################################################################
631                                                   
632            1                                  8   is(
633                                                      $qr->convert_select_list('select * from tbl'),
634                                                      'select 1 from tbl',
635                                                      'Star to one',
636                                                   );
637                                                   
638            1                                  7   is(
639                                                      $qr->convert_select_list('select a, b, c from tbl'),
640                                                      'select isnull(coalesce( a, b, c )) from tbl',
641                                                      'column list to isnull/coalesce'
642                                                   );
643                                                   
644                                                   # #############################################################################
645                                                   # shorten()
646                                                   # #############################################################################
647                                                   
648            1                                 11   is(
649                                                      $qr->shorten("insert into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
650                                                      "insert into t(a,b,c) values(a,b,c) /*... omitted ...*/",
651                                                      "shorten simple insert",
652                                                   );
653                                                   
654            1                                  7   is(
655                                                      $qr->shorten("insert low_priority into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
656                                                      "insert low_priority into t(a,b,c) values(a,b,c) /*... omitted ...*/",
657                                                      "shorten low_priority simple insert",
658                                                   );
659                                                   
660            1                                  7   is(
661                                                      $qr->shorten("insert delayed into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
662                                                      "insert delayed into t(a,b,c) values(a,b,c) /*... omitted ...*/",
663                                                      "shorten delayed simple insert",
664                                                   );
665                                                   
666            1                                  7   is(
667                                                      $qr->shorten("insert high_priority into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
668                                                      "insert high_priority into t(a,b,c) values(a,b,c) /*... omitted ...*/",
669                                                      "shorten high_priority simple insert",
670                                                   );
671                                                   
672            1                                  7   is(
673                                                      $qr->shorten("insert ignore into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
674                                                      "insert ignore into t(a,b,c) values(a,b,c) /*... omitted ...*/",
675                                                      "shorten ignore simple insert",
676                                                   );
677                                                   
678            1                                  7   is(
679                                                      $qr->shorten("insert high_priority ignore into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
680                                                      "insert high_priority ignore into t(a,b,c) values(a,b,c) /*... omitted ...*/",
681                                                      "shorten high_priority ignore simple insert",
682                                                   );
683                                                   
684            1                                  7   is(
685                                                      $qr->shorten("replace low_priority into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
686                                                      "replace low_priority into t(a,b,c) values(a,b,c) /*... omitted ...*/",
687                                                      "shorten replace low_priority",
688                                                   );
689                                                   
690            1                                  7   is(
691                                                      $qr->shorten("replace delayed into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
692                                                      "replace delayed into t(a,b,c) values(a,b,c) /*... omitted ...*/",
693                                                      "shorten replace delayed",
694                                                   );
695                                                   
696            1                                  6   is(
697                                                      $qr->shorten("insert into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i) on duplicate key update a = b"),
698                                                      "insert into t(a,b,c) values(a,b,c) /*... omitted ...*/on duplicate key update a = b",
699                                                      "shorten insert ... odku",
700                                                   );
701                                                   
702            1                               1654   is(
703                                                      $qr->shorten(
704                                                         "select * from a where b in(" . join(',', 1..60) . ") and "
705                                                            . "a in(" . join(',', 1..5000) . ")", 1),
706                                                      "select * from a where b in(" . join(',', 1..20) . "/*... omitted 40 items ...*/)"
707                                                         . " and a in(" . join(',', 1..20) . "/*... omitted 4980 items ...*/)",
708                                                      "shorten two IN() lists of numbers",
709                                                   );
710                                                   
711            1                                  9   is(
712                                                      $qr->shorten("select * from a", 1),
713                                                      "select * from a",
714                                                      "Does not shorten strings it does not match",
715                                                   );
716                                                   
717            1                                 47   is(
718                                                      $qr->shorten("select * from a where b in(". join(',', 1..100) . ")", 1024),
719                                                      "select * from a where b in(". join(',', 1..100) . ")",
720                                                      "shorten IN() list numbers but not those that are already short enough",
721                                                   );
722                                                   
723            1                                 44   is(
724                                                      $qr->shorten("select * from a where b in(" . join(',', 1..100) . "'a,b')", 1),
725                                                      "select * from a where b in(" . join(',', 1..20) . "/*... omitted 81 items ...*/)",
726                                                      "Test case to document that commas are expected to mess up omitted count",
727                                                   );
728                                                   
729            1                                 43   is(
730                                                      $qr->shorten("select * from a where b in(1, 'a)b', " . join(',', 1..100) . ")", 1),
731                                                      "select * from a where b in(1, 'a)b', " . join(',', 1..100) . ")",
732                                                      "Test case to document that parens are expected to prevent shortening",
733                                                   );
734                                                   
735                                                   # #############################################################################
736                                                   # distill()
737                                                   # All tests below here are distill() tests.  There's a lot of them.
738                                                   # #############################################################################
739                                                   
740            1                                  8   is(
741                                                      $qr->distill("SELECT /*!40001 SQL_NO_CACHE */ * FROM `film`"),
742                                                      "SELECT film",
743                                                      'Distills mysqldump SELECTs to selects',
744                                                   );
745                                                   
746            1                                  7   is(
747                                                      $qr->distill("CALL foo(1, 2, 3)"),
748                                                      "CALL foo",
749                                                      'Distills stored procedure calls specially',
750                                                   );
751                                                   
752            1                                  8   is(
753                                                      $qr->distill(
754                                                         q{REPLACE /*foo.bar:3/3*/ INTO checksum.checksum (db, tbl, }
755                                                         .q{chunk, boundaries, this_cnt, this_crc) SELECT 'foo', 'bar', }
756                                                         .q{2 AS chunk_num, '`id` >= 2166633', COUNT(*) AS cnt, }
757                                                         .q{LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `id`, `created_by`, }
758                                                         .q{`created_date`, `updated_by`, `updated_date`, `ppc_provider`, }
759                                                         .q{`account_name`, `provider_account_id`, `campaign_name`, }
760                                                         .q{`provider_campaign_id`, `adgroup_name`, `provider_adgroup_id`, }
761                                                         .q{`provider_keyword_id`, `provider_ad_id`, `foo`, `reason`, }
762                                                         .q{`foo_bar_bazz_id`, `foo_bar_baz`, CONCAT(ISNULL(`created_by`), }
763                                                         .q{ISNULL(`created_date`), ISNULL(`updated_by`), ISNULL(`updated_date`), }
764                                                         .q{ISNULL(`ppc_provider`), ISNULL(`account_name`), }
765                                                         .q{ISNULL(`provider_account_id`), ISNULL(`campaign_name`), }
766                                                         .q{ISNULL(`provider_campaign_id`), ISNULL(`adgroup_name`), }
767                                                         .q{ISNULL(`provider_adgroup_id`), ISNULL(`provider_keyword_id`), }
768                                                         .q{ISNULL(`provider_ad_id`), ISNULL(`foo`), ISNULL(`reason`), }
769                                                         .q{ISNULL(`foo_base_foo_id`), ISNULL(`fooe_foo_id`)))) AS UNSIGNED)), 10, }
770                                                         .q{16)) AS crc FROM `foo`.`bar` USE INDEX (`PRIMARY`) WHERE }
771                                                         .q{(`id` >= 2166633); }),
772                                                      'REPLACE SELECT checksum.checksum foo.bar',
773                                                      'Distills mk-table-checksum query',
774                                                   );
775                                                   
776            1                                  7   is(
777                                                      $qr->distill("use `foo`"),
778                                                      "USE",
779                                                      'distills USE',
780                                                   );
781                                                   
782            1                                  6   is(
783                                                      $qr->distill(q{delete foo.bar b from foo.bar b left join baz.bat c on a=b where nine>eight}),
784                                                      'DELETE foo.bar baz.bat',
785                                                      'distills and then collapses same tables',
786                                                   );
787                                                   
788            1                                  7   is(
789                                                      $qr->distill("select \n--bar\n foo"),
790                                                      "SELECT",
791                                                      'distills queries from DUAL',
792                                                   );
793                                                   
794            1                                  6   is(
795                                                      $qr->distill("select null, 5.001, 5001. from foo"),
796                                                      "SELECT foo",
797                                                      "distills simple select",
798                                                   );
799                                                   
800            1                                  7   is(
801                                                      $qr->distill("select 'hello', '\nhello\n', \"hello\", '\\'' from foo"),
802                                                      "SELECT foo",
803                                                      "distills with quoted strings",
804                                                   );
805                                                   
806            1                                  7   is(
807                                                      $qr->distill("select foo_1 from foo_2_3"),
808                                                      'SELECT foo_?_?',
809                                                      'distills numeric table names',
810                                                   );
811                                                   
812            1                                  7   is(
813                                                      $qr->distill("insert into abtemp.coxed select foo.bar from foo"),
814                                                      'INSERT SELECT abtemp.coxed foo',
815                                                      'distills insert/select',
816                                                   );
817                                                   
818            1                                 13   is(
819                                                      $qr->distill('insert into foo(a, b, c) values(2, 4, 5)'),
820                                                      'INSERT foo',
821                                                      'distills value lists',
822                                                   );
823                                                   
824            1                                  8   is(
825                                                      $qr->distill('select 1 union select 2 union select 4'),
826                                                      'SELECT UNION',
827                                                      'distill unions together',
828                                                   );
829                                                   
830            1                                  8   is(
831                                                      $qr->distill(
832                                                         'delete from foo where bar = baz',
833                                                      ),
834                                                      'DELETE foo',
835                                                      'distills delete',
836                                                   );
837                                                   
838            1                                 10   is(
839                                                      $qr->distill('set timestamp=134'),
840                                                      'SET',
841                                                      'distills set',
842                                                   );
843                                                   
844            1                                  8   is(
845                                                      $qr->distill(
846                                                         'replace into foo(a, b, c) values(1, 3, 5) on duplicate key update foo=bar',
847                                                      ),
848                                                      'REPLACE UPDATE foo',
849                                                      'distills ODKU',
850                                                   );
851                                                   
852            1                                  7   is($qr->distill(
853                                                      q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
854                                                      . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
855                                                      . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
856                                                      . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
857                                                      . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
858                                                      . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
859                                                      . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )}),
860                                                      'UPDATE GARDEN_CLUPL GARDENJOB APLTRACT_GARDENPLANT',
861                                                      'distills where there is alias and comma-join',
862                                                   );
863                                                   
864            1                                  6   is(
865                                                      $qr->distill(q{SELECT STRAIGHT_JOIN distinct foo, bar FROM A, B, C}),
866                                                      'SELECT A B C',
867                                                      'distill with STRAIGHT_JOIN',
868                                                   );
869                                                   
870            1                                  6   is (
871                                                      $qr->distill(q{
872                                                   REPLACE DELAYED INTO
873                                                   `db1`.`tbl2`(`col1`,col2)
874                                                   VALUES ('617653','2007-09-11')}),
875                                                      'REPLACE db?.tbl?',
876                                                      'distills replace-delayed',
877                                                   );
878                                                   
879            1                                  7   is(
880                                                      $qr->distill(
881                                                         'update foo inner join bar using(baz) set big=little',
882                                                      ),
883                                                      'UPDATE foo bar',
884                                                      'distills update-multi',
885                                                   );
886                                                   
887            1                                 10   is(
888                                                      $qr->distill('
889                                                   update db2.tbl1 as p
890                                                      inner join (
891                                                         select p2.col1, p2.col2
892                                                         from db2.tbl1 as p2
893                                                            inner join db2.tbl3 as ba
894                                                               on p2.col1 = ba.tbl3
895                                                         where col4 = 0
896                                                         order by priority desc, col1, col2
897                                                         limit 10
898                                                      ) as chosen on chosen.col1 = p.col1
899                                                         and chosen.col2 = p.col2
900                                                      set p.col4 = 149945'),
901                                                      'UPDATE SELECT db?.tbl?',
902                                                      'distills complex subquery',
903                                                   );
904                                                   
905            1                                  7   is(
906                                                      $qr->distill(
907                                                         'replace into checksum.checksum select `last_update`, `foo` from foo.foo'),
908                                                      'REPLACE SELECT checksum.checksum foo.foo',
909                                                      'distill with reserved words');
910                                                   
911            1                                  6   is($qr->distill('SHOW STATUS'), 'SHOW STATUS', 'distill SHOW STATUS');
912                                                   
913            1                                  7   is($qr->distill('commit'), 'COMMIT', 'distill COMMIT');
914                                                   
915            1                                  6   is($qr->distill('FLUSH TABLES WITH READ LOCK'), 'FLUSH', 'distill FLUSH');
916                                                   
917            1                                  7   is($qr->distill('BEGIN'), 'BEGIN', 'distill BEGIN');
918                                                   
919            1                                  6   is($qr->distill('start'), 'START', 'distill START');
920                                                   
921            1                                  6   is($qr->distill('ROLLBACK'), 'ROLLBACK', 'distill ROLLBACK');
922                                                   
923            1                                  7   is(
924                                                      $qr->distill(
925                                                         'insert into foo select * from bar join baz using (bat)',
926                                                      ),
927                                                      'INSERT SELECT foo bar baz',
928                                                      'distills insert select',
929                                                   );
930                                                   
931            1                                  6   is(
932                                                      $qr->distill('create database foo'),
933                                                      'CREATE DATABASE foo',
934                                                      'distills create database'
935                                                   );
936            1                                  7   is(
937                                                      $qr->distill('create table foo'),
938                                                      'CREATE TABLE foo',
939                                                      'distills create table'
940                                                   );
941            1                                  6   is(
942                                                      $qr->distill('alter database foo'),
943                                                      'ALTER DATABASE foo',
944                                                      'distills alter database'
945                                                   );
946            1                                  5   is(
947                                                      $qr->distill('alter table foo'),
948                                                      'ALTER TABLE foo',
949                                                      'distills alter table'
950                                                   );
951            1                                 10   is(
952                                                      $qr->distill('drop database foo'),
953                                                      'DROP DATABASE foo',
954                                                      'distills drop database'
955                                                   );
956            1                                  6   is(
957                                                      $qr->distill('drop table foo'),
958                                                      'DROP TABLE foo',
959                                                      'distills drop table'
960                                                   );
961            1                                  7   is(
962                                                      $qr->distill('rename database foo'),
963                                                      'RENAME DATABASE foo',
964                                                      'distills rename database'
965                                                   );
966            1                                  7   is(
967                                                      $qr->distill('rename table foo'),
968                                                      'RENAME TABLE foo',
969                                                      'distills rename table'
970                                                   );
971            1                                  7   is(
972                                                      $qr->distill('truncate table foo'),
973                                                      'TRUNCATE TABLE foo',
974                                                      'distills truncate table'
975                                                   );
976                                                   
977                                                   # Test generic distillation for memcached, http, etc.
978                                                   my $trf = sub {
979            3                    3            13      my ( $query ) = @_;
980            3                                 30      $query =~ s/(\S+ \S+?)(?:[?;].+)/$1/;
981            3                                 14      return $query;
982            1                                 12   };
983                                                   
984            1                                  8   is(
985                                                      $qr->distill('get percona.com/', generic => 1, trf => $trf),
986                                                      'GET percona.com/',
987                                                      'generic distill HTTP get'
988                                                   );
989                                                   
990            1                                  6   is(
991                                                      $qr->distill('get percona.com/page.html?some=thing', generic => 1, trf => $trf),
992                                                      'GET percona.com/page.html',
993                                                      'generic distill HTTP get with args'
994                                                   );
995                                                   
996            1                                  6   is(
997                                                      $qr->distill('put percona.com/contacts.html', generic => 1, trf => $trf),
998                                                      'PUT percona.com/contacts.html',
999                                                      'generic distill HTTP put'
1000                                                  );
1001                                                  
1002           1                                  6   is(
1003                                                     $qr->distill(
1004                                                        'update foo set bar=baz where bat=fiz',
1005                                                     ),
1006                                                     'UPDATE foo',
1007                                                     'distills update',
1008                                                  );
1009                                                  
1010                                                  # Issue 563: Lock tables is not distilled
1011           1                                  6   is(
1012                                                     $qr->distill('LOCK TABLES foo WRITE'),
1013                                                     'LOCK foo',
1014                                                     'distills lock tables'
1015                                                  );
1016           1                                  5   is(
1017                                                     $qr->distill('LOCK TABLES foo READ, bar WRITE'),
1018                                                     'LOCK foo bar',
1019                                                     'distills lock tables (2 tables)'
1020                                                  );
1021           1                                  5   is(
1022                                                     $qr->distill('UNLOCK TABLES'),
1023                                                     'UNLOCK',
1024                                                     'distills unlock tables'
1025                                                  );
1026                                                  
1027                                                  #  Issue 712: Queries not handled by "distill"
1028           1                                  6   is(
1029                                                     $qr->distill('XA START 0x123'),
1030                                                     'XA_START',
1031                                                     'distills xa start'
1032                                                  );
1033           1                                  5   is(
1034                                                     $qr->distill('XA PREPARE 0x123'),
1035                                                     'XA_PREPARE',
1036                                                     'distills xa prepare'
1037                                                  );
1038           1                                  7   is(
1039                                                     $qr->distill('XA COMMIT 0x123'),
1040                                                     'XA_COMMIT',
1041                                                     'distills xa commit'
1042                                                  );
1043           1                                  6   is(
1044                                                     $qr->distill('XA END 0x123'),
1045                                                     'XA_END',
1046                                                     'distills xa end'
1047                                                  );
1048                                                  
1049           1                                  6   is(
1050                                                     $qr->distill("/* mysql-connector-java-5.1-nightly-20090730 ( Revision: \${svn.Revision} ) */SHOW VARIABLES WHERE Variable_name ='language' OR Variable_name =
1051                                                     'net_write_timeout' OR Variable_name = 'interactive_timeout' OR
1052                                                     Variable_name = 'wait_timeout' OR Variable_name = 'character_set_client' OR
1053                                                     Variable_name = 'character_set_connection' OR Variable_name =
1054                                                     'character_set' OR Variable_name = 'character_set_server' OR Variable_name
1055                                                     = 'tx_isolation' OR Variable_name = 'transaction_isolation' OR
1056                                                     Variable_name = 'character_set_results' OR Variable_name = 'timezone' OR
1057                                                     Variable_name = 'time_zone' OR Variable_name = 'system_time_zone' OR
1058                                                     Variable_name = 'lower_case_table_names' OR Variable_name =
1059                                                     'max_allowed_packet' OR Variable_name = 'net_buffer_length' OR
1060                                                     Variable_name = 'sql_mode' OR Variable_name = 'query_cache_type' OR
1061                                                     Variable_name = 'query_cache_size' OR Variable_name = 'init_connect'"),
1062                                                     'SHOW VARIABLES',
1063                                                     'distills /* comment */SHOW VARIABLES'
1064                                                  );
1065                                                  
1066                                                  # This is a list of all the types of syntax for SHOW on
1067                                                  # http://dev.mysql.com/doc/refman/5.0/en/show.html
1068           1                                108   my %status_tests = (
1069                                                     'SHOW BINARY LOGS'                           => 'SHOW BINARY LOGS',
1070                                                     'SHOW BINLOG EVENTS in "log_name"'           => 'SHOW BINLOG EVENTS',
1071                                                     'SHOW CHARACTER SET LIKE "pattern"'          => 'SHOW CHARACTER SET',
1072                                                     'SHOW COLLATION WHERE "something"'           => 'SHOW COLLATION',
1073                                                     'SHOW COLUMNS FROM tbl'                      => 'SHOW COLUMNS',
1074                                                     'SHOW FULL COLUMNS FROM tbl'                 => 'SHOW COLUMNS',
1075                                                     'SHOW COLUMNS FROM tbl in db'                => 'SHOW COLUMNS',
1076                                                     'SHOW COLUMNS FROM tbl IN db LIKE "pattern"' => 'SHOW COLUMNS',
1077                                                     'SHOW CREATE DATABASE db_name'               => 'SHOW CREATE DATABASE',
1078                                                     'SHOW CREATE SCHEMA db_name'                 => 'SHOW CREATE DATABASE',
1079                                                     'SHOW CREATE FUNCTION func'                  => 'SHOW CREATE FUNCTION',
1080                                                     'SHOW CREATE PROCEDURE proc'                 => 'SHOW CREATE PROCEDURE',
1081                                                     'SHOW CREATE TABLE tbl_name'                 => 'SHOW CREATE TABLE',
1082                                                     'SHOW CREATE VIEW vw_name'                   => 'SHOW CREATE VIEW',
1083                                                     'SHOW DATABASES'                             => 'SHOW DATABASES',
1084                                                     'SHOW SCHEMAS'                               => 'SHOW DATABASES',
1085                                                     'SHOW DATABASES LIKE "pattern"'              => 'SHOW DATABASES',
1086                                                     'SHOW DATABASES WHERE foo=bar'               => 'SHOW DATABASES',
1087                                                     'SHOW ENGINE ndb status'                     => 'SHOW NDB STATUS',
1088                                                     'SHOW ENGINE innodb status'                  => 'SHOW INNODB STATUS',
1089                                                     'SHOW ENGINES'                               => 'SHOW ENGINES',
1090                                                     'SHOW STORAGE ENGINES'                       => 'SHOW ENGINES',
1091                                                     'SHOW ERRORS'                                => 'SHOW ERRORS',
1092                                                     'SHOW ERRORS limit 5'                        => 'SHOW ERRORS',
1093                                                     'SHOW COUNT(*) ERRORS'                       => 'SHOW ERRORS',
1094                                                     'SHOW FUNCTION CODE func'                    => 'SHOW FUNCTION CODE',
1095                                                     'SHOW FUNCTION STATUS'                       => 'SHOW FUNCTION STATUS',
1096                                                     'SHOW FUNCTION STATUS LIKE "pattern"'        => 'SHOW FUNCTION STATUS',
1097                                                     'SHOW FUNCTION STATUS WHERE foo=bar'         => 'SHOW FUNCTION STATUS',
1098                                                     'SHOW GRANTS'                                => 'SHOW GRANTS',
1099                                                     'SHOW GRANTS FOR user@localhost'             => 'SHOW GRANTS',
1100                                                     'SHOW INDEX'                                 => 'SHOW INDEX',
1101                                                     'SHOW INDEXES'                               => 'SHOW INDEX',
1102                                                     'SHOW KEYS'                                  => 'SHOW INDEX',
1103                                                     'SHOW INDEX FROM tbl'                        => 'SHOW INDEX',
1104                                                     'SHOW INDEX FROM tbl IN db'                  => 'SHOW INDEX',
1105                                                     'SHOW INDEX IN tbl FROM db'                  => 'SHOW INDEX',
1106                                                     'SHOW INNODB STATUS'                         => 'SHOW INNODB STATUS',
1107                                                     'SHOW LOGS'                                  => 'SHOW LOGS',
1108                                                     'SHOW MASTER STATUS'                         => 'SHOW MASTER STATUS',
1109                                                     'SHOW MUTEX STATUS'                          => 'SHOW MUTEX STATUS',
1110                                                     'SHOW OPEN TABLES'                           => 'SHOW OPEN TABLES',
1111                                                     'SHOW OPEN TABLES FROM db'                   => 'SHOW OPEN TABLES',
1112                                                     'SHOW OPEN TABLES IN db'                     => 'SHOW OPEN TABLES',
1113                                                     'SHOW OPEN TABLES IN db LIKE "pattern"'      => 'SHOW OPEN TABLES',
1114                                                     'SHOW OPEN TABLES IN db WHERE foo=bar'       => 'SHOW OPEN TABLES',
1115                                                     'SHOW OPEN TABLES WHERE foo=bar'             => 'SHOW OPEN TABLES',
1116                                                     'SHOW PRIVILEGES'                            => 'SHOW PRIVILEGES',
1117                                                     'SHOW PROCEDURE CODE proc'                   => 'SHOW PROCEDURE CODE',
1118                                                     'SHOW PROCEDURE STATUS'                      => 'SHOW PROCEDURE STATUS',
1119                                                     'SHOW PROCEDURE STATUS LIKE "pattern"'       => 'SHOW PROCEDURE STATUS',
1120                                                     'SHOW PROCEDURE STATUS WHERE foo=bar'        => 'SHOW PROCEDURE STATUS',
1121                                                     'SHOW PROCESSLIST'                           => 'SHOW PROCESSLIST',
1122                                                     'SHOW FULL PROCESSLIST'                      => 'SHOW PROCESSLIST',
1123                                                     'SHOW PROFILE'                               => 'SHOW PROFILE',
1124                                                     'SHOW PROFILES'                              => 'SHOW PROFILES',
1125                                                     'SHOW PROFILES CPU FOR QUERY 1'              => 'SHOW PROFILES CPU',
1126                                                     'SHOW SLAVE HOSTS'                           => 'SHOW SLAVE HOSTS',
1127                                                     'SHOW SLAVE STATUS'                          => 'SHOW SLAVE STATUS',
1128                                                     'SHOW STATUS'                                => 'SHOW STATUS',
1129                                                     'SHOW GLOBAL STATUS'                         => 'SHOW STATUS',
1130                                                     'SHOW SESSION STATUS'                        => 'SHOW STATUS',
1131                                                     'SHOW STATUS LIKE "pattern"'                 => 'SHOW STATUS',
1132                                                     'SHOW STATUS WHERE foo=bar'                  => 'SHOW STATUS',
1133                                                     'SHOW TABLE STATUS'                          => 'SHOW TABLE STATUS',
1134                                                     'SHOW TABLE STATUS FROM db_name'             => 'SHOW TABLE STATUS',
1135                                                     'SHOW TABLE STATUS IN db_name'               => 'SHOW TABLE STATUS',
1136                                                     'SHOW TABLE STATUS LIKE "pattern"'           => 'SHOW TABLE STATUS',
1137                                                     'SHOW TABLE STATUS WHERE foo=bar'            => 'SHOW TABLE STATUS',
1138                                                     'SHOW TABLES'                                => 'SHOW TABLES',
1139                                                     'SHOW FULL TABLES'                           => 'SHOW TABLES',
1140                                                     'SHOW TABLES FROM db'                        => 'SHOW TABLES',
1141                                                     'SHOW TABLES IN db'                          => 'SHOW TABLES',
1142                                                     'SHOW TABLES LIKE "pattern"'                 => 'SHOW TABLES',
1143                                                     'SHOW TABLES FROM db LIKE "pattern"'         => 'SHOW TABLES',
1144                                                     'SHOW TABLES WHERE foo=bar'                  => 'SHOW TABLES',
1145                                                     'SHOW TRIGGERS'                              => 'SHOW TRIGGERS',
1146                                                     'SHOW TRIGGERS IN db'                        => 'SHOW TRIGGERS',
1147                                                     'SHOW TRIGGERS FROM db'                      => 'SHOW TRIGGERS',
1148                                                     'SHOW TRIGGERS LIKE "pattern"'               => 'SHOW TRIGGERS',
1149                                                     'SHOW TRIGGERS WHERE foo=bar'                => 'SHOW TRIGGERS',
1150                                                     'SHOW VARIABLES'                             => 'SHOW VARIABLES',
1151                                                     'SHOW GLOBAL VARIABLES'                      => 'SHOW VARIABLES',
1152                                                     'SHOW SESSION VARIABLES'                     => 'SHOW VARIABLES',
1153                                                     'SHOW VARIABLES LIKE "pattern"'              => 'SHOW VARIABLES',
1154                                                     'SHOW VARIABLES WHERE foo=bar'               => 'SHOW VARIABLES',
1155                                                     'SHOW WARNINGS'                              => 'SHOW WARNINGS',
1156                                                     'SHOW WARNINGS LIMIT 5'                      => 'SHOW WARNINGS',
1157                                                     'SHOW COUNT(*) WARNINGS'                     => 'SHOW WARNINGS',
1158                                                     'SHOW COUNT ( *) WARNINGS'                   => 'SHOW WARNINGS',
1159                                                  );
1160                                                  
1161           1                                 18   foreach my $key ( keys %status_tests ) {
1162          90                                749      is($qr->distill($key), $status_tests{$key}, "distills $key");
1163                                                  }
1164                                                  
1165                                                  is(
1166           1                                 15      $qr->distill('SHOW SLAVE STATUS'),
1167                                                     'SHOW SLAVE STATUS',
1168                                                     'distills SHOW SLAVE STATUS'
1169                                                  );
1170           1                                 11   is(
1171                                                     $qr->distill('SHOW INNODB STATUS'),
1172                                                     'SHOW INNODB STATUS',
1173                                                     'distills SHOW INNODB STATUS'
1174                                                  );
1175           1                                  7   is(
1176                                                     $qr->distill('SHOW CREATE TABLE'),
1177                                                     'SHOW CREATE TABLE',
1178                                                     'distills SHOW CREATE TABLE'
1179                                                  );
1180                                                  
1181           1                                 10   my @show = qw(COLUMNS GRANTS INDEX STATUS TABLES TRIGGERS WARNINGS);
1182           1                                  5   foreach my $show ( @show ) {
1183           7                                 38      is(
1184                                                        $qr->distill("SHOW $show"),
1185                                                        "SHOW $show",
1186                                                        "distills SHOW $show"
1187                                                     );
1188                                                  }
1189                                                  
1190                                                  #  Issue 735: mk-query-digest doesn't distill query correctly
1191                                                  is( 
1192           1                                  6   	$qr->distill('SHOW /*!50002 GLOBAL */ STATUS'),
1193                                                  	'SHOW STATUS',
1194                                                  	"distills SHOW STATUS"
1195                                                  );
1196                                                  
1197           1                                  6   is( 
1198                                                  	$qr->distill('SHOW /*!50002 ENGINE */ INNODB STATUS'),
1199                                                  	'SHOW INNODB STATUS',
1200                                                  	"distills SHOW INNODB STATUS"
1201                                                  );
1202                                                  
1203           1                                  6   is( 
1204                                                  	$qr->distill('SHOW MASTER LOGS'),
1205                                                  	'SHOW MASTER LOGS',
1206                                                  	"distills SHOW MASTER LOGS"
1207                                                  );
1208                                                  
1209           1                                  5   is( 
1210                                                  	$qr->distill('SHOW GLOBAL STATUS'),
1211                                                  	'SHOW STATUS',
1212                                                  	"distills SHOW GLOBAL STATUS"
1213                                                  );
1214                                                  
1215           1                                  6   is( 
1216                                                  	$qr->distill('SHOW GLOBAL VARIABLES'),
1217                                                  	'SHOW VARIABLES',
1218                                                  	"distills SHOW VARIABLES"
1219                                                  );
1220                                                  
1221           1                                  9   is( 
1222                                                  	$qr->distill('administrator command: Statistics'),
1223                                                  	'ADMIN STATISTICS',
1224                                                  	"distills ADMIN STATISTICS"
1225                                                  );
1226                                                  
1227                                                  # Issue 781: mk-query-digest doesn't distill or extract tables properly
1228           1                                  5   is( 
1229                                                  	$qr->distill("SELECT `id` FROM (`field`) WHERE `id` = '10000016228434112371782015185031'"),
1230                                                  	'SELECT field',
1231                                                  	'distills SELECT clm from (`tbl`)'
1232                                                  );
1233                                                  
1234           1                                  6   is(  
1235                                                  	$qr->distill("INSERT INTO (`jedi_forces`) (name, side, email) values ('Anakin Skywalker', 'jedi', 'anakin_skywalker_at_jedi.sw')"),
1236                                                  	'INSERT jedi_forces',
1237                                                  	'distills INSERT INTO (`tbl`)' 
1238                                                  );
1239                                                  
1240           1                                  6   is(  
1241                                                  	$qr->distill("UPDATE (`jedi_forces`) set side = 'dark' and name = 'Lord Vader' where name = 'Anakin Skywalker'"),
1242                                                  	'UPDATE jedi_forces',
1243                                                  	'distills UPDATE (`tbl`)'
1244                                                  );
1245                                                  
1246           1                                  6   is(
1247                                                  	$qr->distill("select c from (tbl1 JOIN tbl2 on (id)) where x=y"),
1248                                                  	'SELECT tbl?',
1249                                                  	'distills SELECT (t1 JOIN t2)'
1250                                                  );
1251                                                  
1252           1                                  6   is(
1253                                                  	$qr->distill("insert into (t1) value('a')"),
1254                                                  	'INSERT t?',
1255                                                  	'distills INSERT (tbl)'
1256                                                  );
1257                                                  
1258                                                  # Something that will (should) never distill.
1259           1                                  6   is(
1260                                                  	$qr->distill("-- how /*did*/ `THIS` #happen?"),
1261                                                  	'',
1262                                                  	'distills nonsense'
1263                                                  );
1264                                                  
1265           1                                 43   is(
1266                                                  	$qr->distill("peek tbl poke db"),
1267                                                  	'',
1268                                                  	'distills non-SQL'
1269                                                  );
1270                                                  
1271                                                  # #############################################################################
1272                                                  # Done.
1273                                                  # #############################################################################
1274           1                                  3   exit;


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
5     ***     50      0      1   unless $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
5     ***     33      0      0      1   $ENV{'MAATKIT_TRUNK'} and -d $ENV{'MAATKIT_TRUNK'}


Covered Subroutines
-------------------

Subroutine Count Location           
---------- ----- -------------------
BEGIN          1 QueryRewriter.t:10 
BEGIN          1 QueryRewriter.t:11 
BEGIN          1 QueryRewriter.t:12 
BEGIN          1 QueryRewriter.t:13 
BEGIN          1 QueryRewriter.t:15 
BEGIN          1 QueryRewriter.t:16 
BEGIN          1 QueryRewriter.t:17 
BEGIN          1 QueryRewriter.t:5  
__ANON__       3 QueryRewriter.t:979


