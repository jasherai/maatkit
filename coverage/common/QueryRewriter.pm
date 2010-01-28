---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/QueryRewriter.pm   96.0   88.2   70.0   94.7    n/a   53.8   92.1
QueryRewriter.t               100.0   50.0   33.3  100.0    n/a   46.2   98.5
Total                          98.1   87.2   65.2   96.4    n/a  100.0   94.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          -e
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jan 27 16:35:42 2010
Finish:       Wed Jan 27 16:35:42 2010

Run:          QueryRewriter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Wed Jan 27 16:35:43 2010
Finish:       Wed Jan 27 16:35:44 2010

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
18                                                    # QueryRewriter package $Revision: 5538 $
19                                                    # ###########################################################################
20             1                    1             5   use strict;
               1                                  2   
               1                                  6   
21             1                    1             7   use warnings FATAL => 'all';
               1                                  2   
               1                                 15   
22                                                    
23                                                    package QueryRewriter;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  8   
26                                                    
27    ***      1            50      1             7   use constant MKDEBUG => $ENV{MKDEBUG} || 0;
               1                                  7   
               1                                 25   
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
53                                                    my $no_tables = "false";
54                                                    
55                                                    sub new {
56             1                    1             6      my ( $class, %args ) = @_;
57             1                                  9      my $self = { %args };
58             1                                 12      return bless $self, $class;
59                                                    }
60                                                    
61                                                    # Strips comments out of queries.
62                                                    sub strip_comments {
63           151                  151           624      my ( $self, $query ) = @_;
64    ***    151     50                         604      return unless $query;
65           151                                746      $query =~ s/$olc_re//go;
66           151                                512      $query =~ s/$mlc_re//go;
67           151    100                         838      if ( $query =~ m/$vlc_rf/i ) { # contains show + version
68             2                                 15         $query =~ s/$vlc_re//go;
69                                                       }
70           151                                625      return $query;
71                                                    }
72                                                    
73                                                    # Shortens long queries by normalizing stuff out of them.  $length is used only
74                                                    # for IN() lists.  If $length is given, the query is shortened if it's longer
75                                                    # than that.
76                                                    sub shorten {
77            14                   14           114      my ( $self, $query, $length ) = @_;
78                                                       # Shorten multi-value insert/replace, all the way up to on duplicate key
79                                                       # update if it exists.
80            14                                170      $query =~ s{
81                                                          \A(
82                                                             (?:INSERT|REPLACE)
83                                                             (?:\s+LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)?
84                                                             (?:\s\w+)*\s+\S+\s+VALUES\s*\(.*?\)
85                                                          )
86                                                          \s*,\s*\(.*?(ON\s+DUPLICATE|\Z)}
87                                                          {$1 /*... omitted ...*/$2}xsi;
88                                                    
89                                                       # Shortcut!  Find out if there's an IN() list with values.
90            14    100                         122      return $query unless $query =~ m/IN\s*\(\s*(?!select)/i;
91                                                    
92                                                       # Shorten long IN() lists of literals.  But only if the string is longer than
93                                                       # the $length limit.  Assumption: values don't contain commas or closing
94                                                       # parens inside them.
95             4                                 11      my $last_length  = 0;
96             4                                 12      my $query_length = length($query);
97    ***      4            66                   67      while (
      ***                   66                        
                           100                        
98                                                          $length          > 0
99                                                          && $query_length > $length
100                                                         && $query_length < ( $last_length || $query_length + 1 )
101                                                      ) {
102            3                                  9         $last_length = $query_length;
103            3                                 57         $query =~ s{
104            4                                 18            (\bIN\s*\()    # The opening of an IN list
105                                                            ([^\)]+)       # Contents of the list, assuming no item contains paren
106                                                            (?=\))           # Close of the list
107                                                         }
108                                                         {
109                                                            $1 . __shorten($2)
110                                                         }gexsi;
111                                                      }
112                                                   
113            4                                 96      return $query;
114                                                   }
115                                                   
116                                                   # Used by shorten().  The argument is the stuff inside an IN() list.  The
117                                                   # argument might look like this:
118                                                   #  1,2,3,4,5,6
119                                                   # Or, if this is a second or greater iteration, it could even look like this:
120                                                   #  /*... omitted 5 items ...*/ 6,7,8,9
121                                                   # In the second case, we need to trim out 6,7,8 and increment "5 items" to "8
122                                                   # items".  We assume that the values in the list don't contain commas; if they
123                                                   # do, the results could be a little bit wrong, but who cares.  We keep the first
124                                                   # 20 items because we don't want to nuke all the samples from the query, we just
125                                                   # want to shorten it.
126                                                   sub __shorten {
127            4                    4            84      my ( $snippet ) = @_;
128            4                               1980      my @vals = split(/,/, $snippet);
129            4    100                         334      return $snippet unless @vals > 20;
130            3                                 21      my @keep = splice(@vals, 0, 20);  # Remove and save the first 20 items
131                                                      return
132            3                                614         join(',', @keep)
133                                                         . "/*... omitted "
134                                                         . scalar(@vals)
135                                                         . " items ...*/";
136                                                   }
137                                                   
138                                                   # Normalizes variable queries to a "query fingerprint" by abstracting away
139                                                   # parameters, canonicalizing whitespace, etc.  See
140                                                   # http://dev.mysql.com/doc/refman/5.0/en/literals.html for literal syntax.
141                                                   # Note: Any changes to this function must be profiled for speed!  Speed of this
142                                                   # function is critical for mk-log-parser.  There are known bugs in this, but the
143                                                   # balance between maybe-you-get-a-bug and speed favors speed.  See past
144                                                   # revisions of this subroutine for more correct, but slower, regexes.
145                                                   sub fingerprint {
146           37                   37          6627      my ( $self, $query ) = @_;
147                                                   
148                                                      # First, we start with a bunch of special cases that we can optimize because
149                                                      # they are special behavior or because they are really big and we want to
150                                                      # throw them away as early as possible.
151           37    100                         444      $query =~ m#\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `# # mysqldump query
152                                                         && return 'mysqldump';
153                                                      # Matches queries like REPLACE /*foo.bar:3/3*/ INTO checksum.checksum
154           36    100                        2527      $query =~ m#/\*\w+\.\w+:[0-9]/[0-9]\*/#     # mk-table-checksum, etc query
155                                                         && return 'maatkit';
156                                                      # Administrator commands appear to be a comment, so return them as-is
157           35    100                         136      $query =~ m/\A# administrator command: /
158                                                         && return $query;
159                                                      # Special-case for stored procedures.
160           34    100                         208      $query =~ m/\A\s*(call\s+\S+)\(/i
161                                                         && return lc($1); # Warning! $1 used, be careful.
162                                                      # mysqldump's INSERT statements will have long values() lists, don't waste
163                                                      # time on them... they also tend to segfault Perl on some machines when you
164                                                      # get to the "# Collapse IN() and VALUES() lists" regex below!
165           33    100                        2644      if ( my ($beginning) = $query =~ m/\A((?:INSERT|REPLACE)(?: IGNORE)?\s+INTO.+?VALUES\s*\(.*?\))\s*,\s*\(/is ) {
166            6                                 27         $query = $beginning; # Shorten multi-value INSERT statements ASAP
167                                                      }
168                                                   
169           33                                418      $query =~ s/$olc_re//go;
170           33                                114      $query =~ s/$mlc_re//go;
171           33    100                         184      $query =~ s/\Ause \S+\Z/use ?/i       # Abstract the DB in USE
172                                                         && return $query;
173                                                   
174           32                                 96      $query =~ s/\\["']//g;                # quoted strings
175           32                                 93      $query =~ s/".*?"/?/sg;               # quoted strings
176           32                                119      $query =~ s/'.*?'/?/sg;               # quoted strings
177                                                      # This regex is extremely broad in its definition of what looks like a
178                                                      # number.  That is for speed.
179           32                                148      $query =~ s/[0-9+-][0-9a-f.xb+-]*/?/g;# Anything vaguely resembling numbers
180           32                                110      $query =~ s/[xb.+-]\?/?/g;            # Clean up leftovers
181           32                                107      $query =~ s/\A\s+//;                  # Chop off leading whitespace
182           32                                 95      chomp $query;                         # Kill trailing whitespace
183           32                                115      $query =~ tr[ \n\t\r\f][ ]s;          # Collapse whitespace
184           32                                117      $query = lc $query;
185           32                                106      $query =~ s/\bnull\b/?/g;             # Get rid of NULLs
186           32                                497      $query =~ s{                          # Collapse IN and VALUES lists
187                                                                  \b(in|values?)(?:[\s,]*\([\s?,]*\))+
188                                                                 }
189                                                                 {$1(?+)}gx;
190           32                                158      $query =~ s{                          # Collapse UNION
191                                                                  \b(select\s.*?)(?:(\sunion(?:\sall)?)\s\1)+
192                                                                 }
193                                                                 {$1 /*repeat$2*/}xg;
194           32                                108      $query =~ s/\blimit \?(?:, ?\?| offset \?)?/limit ?/; # LIMIT
195                                                      # The following are disabled because of speed issues.  Should we try to
196                                                      # normalize whitespace between and around operators?  My gut feeling is no.
197                                                      # $query =~ s/ , | ,|, /,/g;    # Normalize commas
198                                                      # $query =~ s/ = | =|= /=/g;       # Normalize equals
199                                                      # $query =~ s# [,=+*/-] ?|[,=+*/-] #+#g;    # Normalize operators
200           32                                244      return $query;
201                                                   }
202                                                   
203                                                   # Gets the verbs from an SQL query, such as SELECT, UPDATE, etc.
204                                                   sub distill_verbs {
205          154                  154           630      my ( $self, $query ) = @_;
206                                                   
207                                                      # Simple verbs that normally don't have comments, extra clauses, etc.
208          154    100                         853      $query =~ m/\A\s*call\s+(\S+)\(/i && return "CALL $1";
209          153    100                         660      $query =~ m/\A\s*use\s+/          && return "USE";
210          152    100                         589      $query =~ m/\A\s*UNLOCK TABLES/i  && return "UNLOCK";
211          151    100                         590      $query =~ m/\A\s*xa\s+(\S+)/i     && return "XA_$1";
212                                                   
213          147    100                         506      if ( $query =~ m/\A# administrator command:/ ) {
214            1                                  6         $query =~ s/# administrator command:/ADMIN/go;
215            1                                  3         $query = uc $query;
216            1                                  7         return $query;
217                                                      }
218                                                   
219                                                      # All other, more complex verbs. 
220          146                                550      $query = $self->strip_comments($query);
221                                                   
222                                                      # SHOW statements are either 2 or 3 words: SHOW, $what[0], and
223                                                      # maybe $what[1].  E.g. "SHOW TABLES" or "SHOW SLAVE STATUS".  There's
224                                                      # a few common keywords that may be in place $what[0], so we remove
225                                                      # them first.  Then there's some keywords that signify extra clauses
226                                                      # that may be in place of $what[1] and since these clauses are at the
227                                                      # end of the statement, we remove everything from the clause onward.
228          146    100                         740      if ( $query =~ m/\A\s*SHOW\s+/i ) {
229          106                                238         MKDEBUG && _d($query);
230                                                   
231                                                         # Remove common keywords.
232          106                                423         $query =~ s/\s+(?:GLOBAL|SESSION|FULL|STORAGE|ENGINE)\b/ /ig;
233                                                         # This should be in the regex above but Perl doesn't seem to match
234                                                         # COUNT\(.+\) properly when it's grouped.
235          106                                349         $query =~ s/\s+COUNT\(.+\)//ig;
236                                                   
237                                                         # Remove clause keywords and everything after.
238          106                                328         $query =~ s/\s+(?:FOR|FROM|LIKE|WHERE|LIMIT).+//msi;
239                                                   
240                                                         # Get $what[0] and maybe $what[1];
241          106                                717         my @what = $query =~ m/SHOW\s+(\S+)(?:\s+(\S+))?/i;
242          106                                272         MKDEBUG && _d('SHOW', @what);
243                                                   
244          106                                329         @what = map { uc $_ } grep { defined $_ } @what; 
             147                                622   
             212                                679   
245          106    100                         734         return "SHOW $what[0]" . ($what[1] ? " $what[1]" : '');
246                                                      }
247                                                   
248                                                      # Data defintion statements verbs like CREATE and ALTER.
249                                                      # The two evals are a hack to keep Perl from warning that
250                                                      # "QueryParser::data_def_stmts" used only once: possible typo at...".
251                                                      # Some day we'll group all our common regex together in a packet and
252                                                      # export/import them properly.
253           40                                 97      eval $QueryParser::data_def_stmts;
254           40                                 99      eval $QueryParser::tbl_ident;
255           40                                403      my ( $dds ) = $query =~ /^\s*($QueryParser::data_def_stmts)\b/i;
256   ***     40    100     66                  244      if ( $dds && $no_tables eq "false" ) {
257            9                                170         my ( $obj ) = $query =~ m/$dds.+(DATABASE|TABLE)\b/i;
258   ***      9     50                          44         $obj = uc $obj if $obj;
259            9                                 20         MKDEBUG && _d('Data def statment:', $dds, 'obj:', $obj);
260            9                                122         my ($db_or_tbl)
261                                                            = $query =~ m/(?:TABLE|DATABASE)\s+($QueryParser::tbl_ident)(\s+.*)?/i;
262            9                                 23         MKDEBUG && _d('Matches db or table:', $db_or_tbl);
263   ***      9     50                          62         return uc($dds . ($obj ? " $obj" : '')), $db_or_tbl;
264                                                      }
265                                                   
266                                                      # All other verbs, like SELECT, INSERT, UPDATE, etc.  First, get
267                                                      # the query type -- just extract all the verbs and collapse them
268                                                      # together.
269           31                                746      my @verbs = $query =~ m/\b($verbs)\b/gio;
270           31                                 98      @verbs    = do {
271           31                                 90         my $last = '';
272           31                                 98         grep { my $pass = $_ ne $last; $last = $_; $pass } map { uc } @verbs;
              41                                127   
              41                                106   
              41                                175   
              41                                164   
273                                                      };
274           31                                117      my $verbs = join(q{ }, @verbs);
275           31                                 90      $verbs =~ s/( UNION SELECT)+/ UNION/g;
276                                                   
277           31                                134      return $verbs;
278                                                   }
279                                                   
280                                                   sub __distill_tables {
281          154                  154           751      my ( $self, $query, $table, %args ) = @_;
282   ***    154            33                 1383      my $qp = $args{QueryParser} || $self->{QueryParser};
283   ***    154     50                         537      die "I need a QueryParser argument" unless $qp;
284                                                   
285                                                      # "Fingerprint" the tables.
286           42                                134      my @tables = map {
287           42                               2746         $_ =~ s/`//g;
288           42                                220         $_ =~ s/(_?)[0-9]+/$1?/g;
289           42                                178         $_;
290          154                                742      } grep { defined $_ } $qp->get_tables($query);
291                                                   
292          154    100                        5716      push @tables, $table if $table;
293                                                   
294                                                      # Collapse the table list
295          154                                360      @tables = do {
296          154                                420         my $last = '';
297          154                                479         grep { my $pass = $_ ne $last; $last = $_; $pass } @tables;
              51                                161   
              51                                134   
              51                                192   
298                                                      };
299                                                   
300          154                                605      return @tables;
301                                                   }
302                                                   
303                                                   # This is kind of like fingerprinting, but it super-fingerprints to something
304                                                   # that shows the query type and the tables/objects it accesses.
305                                                   sub distill {
306          157                  157           802      my ( $self, $query, %args ) = @_;
307                                                   
308                                                      # if its a show , try to overwrite some predef expressions
309          157                               1894      my %queries_to_replace = (
310                                                   	   # Match This					   => # replace to this
311                                                   	   'SHOW COLUMNS'                => 'SHOW COLUMNS',
312                                                   	   'SHOW CREATE SCHEMA'          => 'SHOW CREATE DATABASE',
313                                                   	   'SHOW ENGINE innodb status'   => 'SHOW INNODB STATUS',
314                                                   	   'SHOW ENGINE ndb status'		=> 'SHOW NDB STATUS',
315                                                   	   'SHOW KEYS'                   => 'SHOW INDEXES',
316                                                   	   'SHOW SCHEMAS'                => 'SHOW DATABASES',
317                                                   	   'SHOW DATABASES'              => 'SHOW DATABASES',
318                                                   	   'SHOW TABLES'                 => 'SHOW TABLES',
319                                                   	   'SHOW TABLE STATUS'           => 'SHOW TABLE STATUS',
320                                                   	   'SHOW FULL COLUMNS'           => 'SHOW COLUMNS',
321                                                   	   'SHOW INDEX'                  => 'SHOW INDEX',
322                                                   	   'SHOW TRIGGERS'               => 'SHOW TRIGGERS',
323                                                   	   'SHOW OPEN TABLES'            => 'SHOW OPEN TABLES',
324                                                      );
325                                                   
326          157                                839   	foreach my $key2 ( keys %queries_to_replace ) {
327         2041    100                       17240   		if ( $query =~ m/$key2/ ) {
328                                                   			#	print "im matched\n";
329                                                   			#	print "kveri na' : $query\n";
330           45                                158   			$query = $queries_to_replace{$key2};
331                                                   			#	print "and na'v $query\n";
332           45                                150   			$no_tables = "true";
333                                                   		}
334                                                   		else {
335         1996                               6638   			$no_tables = "false";
336                                                   		}
337                                                   	}
338                                                   
339                                                   
340          157    100                         730      if ( $args{generic} ) {
341                                                         # Do a generic distillation which returns the first two words
342                                                         # of a simple "cmd arg" query, like memcached and HTTP stuff.
343            3                                 22         my ($cmd, $arg) = $query =~ m/^(\S+)\s+(\S+)/;
344   ***      3     50                          13         return '' unless $cmd;
345   ***      3     50                          15         $query = (uc $cmd) . ($arg ? " $arg" : '');
346                                                      }
347                                                      else {
348                                                         # distill_verbs() may return a table if it's a special statement
349                                                         # like TRUNCATE TABLE foo.  __distill_tables() handles some but not
350                                                         # all special statements so we pass it this special table in case
351                                                         # it's a statement it can't handle.  If it can handle it, it will
352                                                         # eliminate any duplicate tables.
353          154                                681         my ($verbs, $table)  = $self->distill_verbs($query, %args);
354          154                                745         my @tables           = $self->__distill_tables($query, $table, %args);
355          154    100                         610         if ( $no_tables eq "false" ) {
356          149                                614   	       $query          = join(q{ }, $verbs, @tables); 
357                                                   	  } 
358                                                   	  else {
359            5                                 22   	       $query          = join(q{ }, $verbs);
360                                                   	  }
361                                                      }
362                                                      
363          157    100                         638      if ( $args{trf} ) {
364            3                                 15         $query = $args{trf}->($query, %args);
365                                                      }
366                                                   
367          157                               1345      return $query;
368                                                   }
369                                                   
370                                                   sub convert_to_select {
371           23                   23           110      my ( $self, $query ) = @_;
372           23    100                          93      return unless $query;
373            7                                 43      $query =~ s{
               8                                 35   
374                                                                    \A.*?
375                                                                    update\s+(.*?)
376                                                                    \s+set\b(.*?)
377                                                                    (?:\s*where\b(.*?))?
378                                                                    (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
379                                                                    \Z
380                                                                 }
381                                                                 {__update_to_select($1, $2, $3, $4)}exsi
382            2                                  9         || $query =~ s{
383                                                                       \A.*?
384                                                                       (?:insert|replace)\s+
385                                                                       .*?\binto\b(.*?)\(([^\)]+)\)\s*
386                                                                       values?\s*(\(.*?\))\s*
387                                                                       (?:\blimit\b|on\s*duplicate\s*key.*)?\s*
388                                                                       \Z
389                                                                    }
390                                                                    {__insert_to_select($1, $2, $3)}exsi
391           22    100    100                  532         || $query =~ s{
392                                                                       \A.*?
393                                                                       delete\s+(.*?)
394                                                                       \bfrom\b(.*)
395                                                                       \Z
396                                                                    }
397                                                                    {__delete_to_select($1, $2)}exsi;
398           22                                288      $query =~ s/\s*on\s+duplicate\s+key\s+update.*\Z//si;
399           22                                122      $query =~ s/\A.*?(?=\bSELECT\s*\b)//ism;
400           22                                128      return $query;
401                                                   }
402                                                   
403                                                   sub convert_select_list {
404            2                    2            10      my ( $self, $query ) = @_;
405            2    100                          16      $query =~ s{
               2                                 17   
406                                                                  \A\s*select(.*?)\bfrom\b
407                                                                 }
408                                                                 {$1 =~ m/\*/ ? "select 1 from" : "select isnull(coalesce($1)) from"}exi;
409            2                                 12      return $query;
410                                                   }
411                                                   
412                                                   sub __delete_to_select {
413            2                    2            12      my ( $delete, $join ) = @_;
414            2    100                          13      if ( $join =~ m/\bjoin\b/ ) {
415            1                                  7         return "select 1 from $join";
416                                                      }
417            1                                  6      return "select * from $join";
418                                                   }
419                                                   
420                                                   sub __insert_to_select {
421            8                    8            52      my ( $tbl, $cols, $vals ) = @_;
422            8                                 24      MKDEBUG && _d('Args:', @_);
423            8                                 40      my @cols = split(/,/, $cols);
424            8                                 19      MKDEBUG && _d('Cols:', @cols);
425            8                                 58      $vals =~ s/^\(|\)$//g; # Strip leading/trailing parens
426            8                                180      my @vals = $vals =~ m/($quote_re|[^,]*${bal}[^,]*|[^,]+)/g;
427            8                                 31      MKDEBUG && _d('Vals:', @vals);
428   ***      8     50                          32      if ( @cols == @vals ) {
429           23                                164         return "select * from $tbl where "
430            8                                 62            . join(' and ', map { "$cols[$_]=$vals[$_]" } (0..$#cols));
431                                                      }
432                                                      else {
433   ***      0                                  0         return "select * from $tbl limit 1";
434                                                      }
435                                                   }
436                                                   
437                                                   sub __update_to_select {
438            7                    7            52      my ( $from, $set, $where, $limit ) = @_;
439            7    100                          95      return "select $set from $from "
                    100                               
440                                                         . ( $where ? "where $where" : '' )
441                                                         . ( $limit ? " $limit "      : '' );
442                                                   }
443                                                   
444                                                   sub wrap_in_derived {
445            3                    3            13      my ( $self, $query ) = @_;
446            3    100                          17      return unless $query;
447            2    100                          20      return $query =~ m/\A\s*select/i
448                                                         ? "select 1 from ($query) as x limit 1"
449                                                         : $query;
450                                                   }
451                                                   
452                                                   sub _d {
453   ***      0                    0                    my ($package, undef, $line) = caller 0;
454   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
455   ***      0                                              map { defined $_ ? $_ : 'undef' }
456                                                           @_;
457   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
458                                                   }
459                                                   
460                                                   1;
461                                                   
462                                                   # ###########################################################################
463                                                   # End QueryRewriter package
464                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
64    ***     50      0    151   unless $query
67           100      2    149   if ($query =~ /$vlc_rf/i)
90           100     10      4   unless $query =~ /IN\s*\(\s*(?!select)/i
129          100      1      3   unless @vals > 20
151          100      1     36   if $query =~ m[\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `]
154          100      1     35   if $query =~ m[/\*\w+\.\w+:[0-9]/[0-9]\*/]
157          100      1     34   if $query =~ /\A# administrator command: /
160          100      1     33   if $query =~ /\A\s*(call\s+\S+)\(/i
165          100      6     27   if (my($beginning) = $query =~ /\A((?:INSERT|REPLACE)(?: IGNORE)?\s+INTO.+?VALUES\s*\(.*?\))\s*,\s*\(/is)
171          100      1     32   if $query =~ s/\Ause \S+\Z/use ?/i
208          100      1    153   if $query =~ /\A\s*call\s+(\S+)\(/i
209          100      1    152   if $query =~ /\A\s*use\s+/
210          100      1    151   if $query =~ /\A\s*UNLOCK TABLES/i
211          100      4    147   if $query =~ /\A\s*xa\s+(\S+)/i
213          100      1    146   if ($query =~ /\A# administrator command:/)
228          100    106     40   if ($query =~ /\A\s*SHOW\s+/i)
245          100     41     65   $what[1] ? :
256          100      9     31   if ($dds and $no_tables eq 'false')
258   ***     50      9      0   if $obj
263   ***     50      9      0   $obj ? :
283   ***     50      0    154   unless $qp
292          100      9    145   if $table
327          100     45   1996   if ($query =~ /$key2/) { }
340          100      3    154   if ($args{'generic'}) { }
344   ***     50      0      3   unless $cmd
345   ***     50      3      0   $arg ? :
355          100    149      5   if ($no_tables eq 'false') { }
363          100      3    154   if ($args{'trf'})
372          100      1     22   unless $query
391          100      7     15   unless $query =~ s/
                 \A.*?
                 update\s+(.*?)
                 \s+set\b(.*?)
                 (?:\s*where\b(.*?))?
                 (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
                 \Z
              /__update_to_select($1, $2, $3, $4);/eisx or $query =~ s/
                    \A.*?
                    (?:insert|replace)\s+
                    .*?\binto\b(.*?)\(([^\)]+)\)\s*
                    values?\s*(\(.*?\))\s*
                    (?:\blimit\b|on\s*duplicate\s*key.*)?\s*
                    \Z
                 /__insert_to_select($1, $2, $3);/eisx
405          100      1      1   $1 =~ /\*/ ? :
414          100      1      1   if ($join =~ /\bjoin\b/)
428   ***     50      8      0   if (@cols == @vals) { }
439          100      4      3   $where ? :
             100      1      6   $limit ? :
446          100      1      2   unless $query
447          100      1      1   $query =~ /\A\s*select/i ? :
454   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
97    ***     66      0      1      6   $length > 0 and $query_length > $length
             100      1      3      3   $length > 0 and $query_length > $length and $query_length < ($last_length || $query_length + 1)
256   ***     66     31      0      9   $dds and $no_tables eq 'false'

or 2 conditions

line  err      %      l     !l   expr
----- --- ------ ------ ------   ----
27    ***     50      0      1   $ENV{'MKDEBUG'} || 0

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
97    ***     66      3      3      0   $last_length || $query_length + 1
282   ***     33      0    154      0   $args{'QueryParser'} || $$self{'QueryParser'}
391          100      7      8      7   $query =~ s/
                 \A.*?
                 update\s+(.*?)
                 \s+set\b(.*?)
                 (?:\s*where\b(.*?))?
                 (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
                 \Z
              /__update_to_select($1, $2, $3, $4);/eisx or $query =~ s/
                    \A.*?
                    (?:insert|replace)\s+
                    .*?\binto\b(.*?)\(([^\)]+)\)\s*
                    values?\s*(\(.*?\))\s*
                    (?:\blimit\b|on\s*duplicate\s*key.*)?\s*
                    \Z
                 /__insert_to_select($1, $2, $3);/eisx


Covered Subroutines
-------------------

Subroutine          Count Location                                            
------------------- ----- ----------------------------------------------------
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:20 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:21 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:25 
BEGIN                   1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:27 
__delete_to_select      2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:413
__distill_tables      154 /home/daniel/dev/maatkit/common/QueryRewriter.pm:281
__insert_to_select      8 /home/daniel/dev/maatkit/common/QueryRewriter.pm:421
__shorten               4 /home/daniel/dev/maatkit/common/QueryRewriter.pm:127
__update_to_select      7 /home/daniel/dev/maatkit/common/QueryRewriter.pm:438
convert_select_list     2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:404
convert_to_select      23 /home/daniel/dev/maatkit/common/QueryRewriter.pm:371
distill               157 /home/daniel/dev/maatkit/common/QueryRewriter.pm:306
distill_verbs         154 /home/daniel/dev/maatkit/common/QueryRewriter.pm:205
fingerprint            37 /home/daniel/dev/maatkit/common/QueryRewriter.pm:146
new                     1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:56 
shorten                14 /home/daniel/dev/maatkit/common/QueryRewriter.pm:77 
strip_comments        151 /home/daniel/dev/maatkit/common/QueryRewriter.pm:63 
wrap_in_derived         3 /home/daniel/dev/maatkit/common/QueryRewriter.pm:445

Uncovered Subroutines
---------------------

Subroutine          Count Location                                            
------------------- ----- ----------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/QueryRewriter.pm:453


QueryRewriter.t

line  err   stmt   bran   cond    sub    pod   time   code
1                                                     #!/usr/bin/perl
2                                                     
3                                                     
4                                                     BEGIN {
5     ***      1     50     33      1            40      die "The MAATKIT_TRUNK environment variable is not set.  See http://code.google.com/p/maatkit/wiki/Testing"
6                                                           unless $ENV{MAATKIT_TRUNK} && -d $ENV{MAATKIT_TRUNK};
7              1                                 36      unshift @INC, "$ENV{MAATKIT_TRUNK}/common";
8                                                     };
9                                                     
10             1                    1            14   use strict;
               1                                  2   
               1                                  7   
11             1                    1             8   use warnings FATAL => 'all';
               1                                  2   
               1                                  7   
12             1                    1            15   use English qw(-no_match_vars);
               1                                  3   
               1                                 12   
13             1                    1            17   use Test::More tests => 241;
               1                                  2   
               1                                 12   
14                                                    
15             1                    1            30   use QueryRewriter;
               1                                  3   
               1                                 18   
16             1                    1            17   use QueryParser;
               1                                  3   
               1                                 33   
17             1                    1            15   use MaatkitTest;
               1                                  3   
               1                                 12   
18                                                    
19             1                                 10   my $qp = new QueryParser();
20             1                                 24   my $qr  = new QueryRewriter(QueryParser=>$qp);
21                                                    
22             1                                  6   is(
23                                                       $qr->strip_comments("select \n--bar\n foo"),
24                                                       "select \n\n foo",
25                                                       'Removes one-line comments',
26                                                    );
27                                                    
28             1                                  6   is(
29                                                       $qr->strip_comments("select foo--bar\nfoo"),
30                                                       "select foo\nfoo",
31                                                       'Removes one-line comments without running them together',
32                                                    );
33                                                    
34             1                                  7   is(
35                                                       $qr->strip_comments("select foo -- bar"),
36                                                       "select foo ",
37                                                       'Removes one-line comments at end of line',
38                                                    );
39                                                    
40             1                                  7   is(
41                                                       $qr->fingerprint(
42                                                          q{UPDATE groups_search SET  charter = '   -------3\'\' XXXXXXXXX.\n    \n    -----------------------------------------------------', show_in_list = 'Y' WHERE group_id='aaaaaaaa'}),
43                                                       'update groups_search set charter = ?, show_in_list = ? where group_id=?',
44                                                       'complex comments',
45                                                    );
46                                                    
47             1                                  6   is(
48                                                       $qr->fingerprint("SELECT /*!40001 SQL_NO_CACHE */ * FROM `film`"),
49                                                       "mysqldump",
50                                                       'Fingerprints all mysqldump SELECTs together',
51                                                    );
52                                                    
53             1                                  9   is(
54                                                       $qr->distill("SELECT /*!40001 SQL_NO_CACHE */ * FROM `film`"),
55                                                       "SELECT film",
56                                                       'Distills mysqldump SELECTs to selects',
57                                                    );
58                                                    
59             1                                  7   is(
60                                                       $qr->fingerprint("CALL foo(1, 2, 3)"),
61                                                       "call foo",
62                                                       'Fingerprints stored procedure calls specially',
63                                                    );
64                                                    
65             1                                  8   is(
66                                                       $qr->distill("CALL foo(1, 2, 3)"),
67                                                       "CALL foo",
68                                                       'Distills stored procedure calls specially',
69                                                    );
70                                                    
71             1                                  7   is(
72                                                       $qr->fingerprint('# administrator command: Init DB'),
73                                                       '# administrator command: Init DB',
74                                                       'Fingerprints admin commands as themselves',
75                                                    );
76                                                    
77             1                                  7   is(
78                                                       $qr->fingerprint(
79                                                          q{REPLACE /*foo.bar:3/3*/ INTO checksum.checksum (db, tbl, }
80                                                          .q{chunk, boundaries, this_cnt, this_crc) SELECT 'foo', 'bar', }
81                                                          .q{2 AS chunk_num, '`id` >= 2166633', COUNT(*) AS cnt, }
82                                                          .q{LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `id`, `created_by`, }
83                                                          .q{`created_date`, `updated_by`, `updated_date`, `ppc_provider`, }
84                                                          .q{`account_name`, `provider_account_id`, `campaign_name`, }
85                                                          .q{`provider_campaign_id`, `adgroup_name`, `provider_adgroup_id`, }
86                                                          .q{`provider_keyword_id`, `provider_ad_id`, `foo`, `reason`, }
87                                                          .q{`foo_bar_bazz_id`, `foo_bar_baz`, CONCAT(ISNULL(`created_by`), }
88                                                          .q{ISNULL(`created_date`), ISNULL(`updated_by`), ISNULL(`updated_date`), }
89                                                          .q{ISNULL(`ppc_provider`), ISNULL(`account_name`), }
90                                                          .q{ISNULL(`provider_account_id`), ISNULL(`campaign_name`), }
91                                                          .q{ISNULL(`provider_campaign_id`), ISNULL(`adgroup_name`), }
92                                                          .q{ISNULL(`provider_adgroup_id`), ISNULL(`provider_keyword_id`), }
93                                                          .q{ISNULL(`provider_ad_id`), ISNULL(`foo`), ISNULL(`reason`), }
94                                                          .q{ISNULL(`foo_base_foo_id`), ISNULL(`fooe_foo_id`)))) AS UNSIGNED)), 10, }
95                                                          .q{16)) AS crc FROM `foo`.`bar` USE INDEX (`PRIMARY`) WHERE }
96                                                          .q{(`id` >= 2166633); }),
97                                                       'maatkit',
98                                                       'Fingerprints mk-table-checksum queries together',
99                                                    );
100                                                   
101            1                                  6   is(
102                                                      $qr->distill(
103                                                         q{REPLACE /*foo.bar:3/3*/ INTO checksum.checksum (db, tbl, }
104                                                         .q{chunk, boundaries, this_cnt, this_crc) SELECT 'foo', 'bar', }
105                                                         .q{2 AS chunk_num, '`id` >= 2166633', COUNT(*) AS cnt, }
106                                                         .q{LOWER(CONV(BIT_XOR(CAST(CRC32(CONCAT_WS('#', `id`, `created_by`, }
107                                                         .q{`created_date`, `updated_by`, `updated_date`, `ppc_provider`, }
108                                                         .q{`account_name`, `provider_account_id`, `campaign_name`, }
109                                                         .q{`provider_campaign_id`, `adgroup_name`, `provider_adgroup_id`, }
110                                                         .q{`provider_keyword_id`, `provider_ad_id`, `foo`, `reason`, }
111                                                         .q{`foo_bar_bazz_id`, `foo_bar_baz`, CONCAT(ISNULL(`created_by`), }
112                                                         .q{ISNULL(`created_date`), ISNULL(`updated_by`), ISNULL(`updated_date`), }
113                                                         .q{ISNULL(`ppc_provider`), ISNULL(`account_name`), }
114                                                         .q{ISNULL(`provider_account_id`), ISNULL(`campaign_name`), }
115                                                         .q{ISNULL(`provider_campaign_id`), ISNULL(`adgroup_name`), }
116                                                         .q{ISNULL(`provider_adgroup_id`), ISNULL(`provider_keyword_id`), }
117                                                         .q{ISNULL(`provider_ad_id`), ISNULL(`foo`), ISNULL(`reason`), }
118                                                         .q{ISNULL(`foo_base_foo_id`), ISNULL(`fooe_foo_id`)))) AS UNSIGNED)), 10, }
119                                                         .q{16)) AS crc FROM `foo`.`bar` USE INDEX (`PRIMARY`) WHERE }
120                                                         .q{(`id` >= 2166633); }),
121                                                      'REPLACE SELECT checksum.checksum foo.bar',
122                                                      'Distills mk-table-checksum query',
123                                                   );
124                                                   
125            1                                  7   is(
126                                                      $qr->fingerprint("use `foo`"),
127                                                      "use ?",
128                                                      'Removes identifier from USE',
129                                                   );
130                                                   
131            1                                  6   is(
132                                                      $qr->distill("use `foo`"),
133                                                      "USE",
134                                                      'distills USE',
135                                                   );
136                                                   
137            1                                  6   is(
138                                                      $qr->fingerprint("select \n--bar\n foo"),
139                                                      "select foo",
140                                                      'Removes one-line comments in fingerprints',
141                                                   );
142                                                   
143            1                                  6   is(
144                                                      $qr->distill("select \n--bar\n foo"),
145                                                      "SELECT",
146                                                      'distills queries from DUAL',
147                                                   );
148                                                   
149            1                                  7   is(
150                                                      $qr->fingerprint("select foo--bar\nfoo"),
151                                                      "select foo foo",
152                                                      'Removes one-line comments in fingerprint without mushing things together',
153                                                   );
154                                                   
155            1                                  6   is(
156                                                      $qr->fingerprint("select foo -- bar\n"),
157                                                      "select foo ",
158                                                      'Removes one-line EOL comments in fingerprints',
159                                                   );
160                                                   
161                                                   # This one is too expensive!
162                                                   #is(
163                                                   #   $qr->fingerprint(
164                                                   #      "select a,b ,c , d from tbl where a=5 or a = 5 or a=5 or a =5"),
165                                                   #   "select a, b, c, d from tbl where a=? or a=? or a=? or a=?",
166                                                   #   "Normalizes commas and equals",
167                                                   #);
168                                                   
169            1                                  6   is(
170                                                      $qr->fingerprint("select null, 5.001, 5001. from foo"),
171                                                      "select ?, ?, ? from foo",
172                                                      "Handles bug from perlmonks thread 728718",
173                                                   );
174                                                   
175            1                                223   is(
176                                                      $qr->distill("select null, 5.001, 5001. from foo"),
177                                                      "SELECT foo",
178                                                      "distills simple select",
179                                                   );
180                                                   
181            1                                  7   is(
182                                                      $qr->fingerprint("select 'hello', '\nhello\n', \"hello\", '\\'' from foo"),
183                                                      "select ?, ?, ?, ? from foo",
184                                                      "Handles quoted strings",
185                                                   );
186                                                   
187            1                                  6   is(
188                                                      $qr->distill("select 'hello', '\nhello\n', \"hello\", '\\'' from foo"),
189                                                      "SELECT foo",
190                                                      "distills with quoted strings",
191                                                   );
192                                                   
193            1                                  6   is(
194                                                      $qr->fingerprint("select 'hello'\n"),
195                                                      "select ?",
196                                                      "Handles trailing newline",
197                                                   );
198                                                   
199                                                   # This is a known deficiency, fixes seem to be expensive though.
200            1                                  9   is(
201                                                      $qr->fingerprint("select '\\\\' from foo"),
202                                                      "select '\\ from foo",
203                                                      "Does not handle all quoted strings",
204                                                   );
205                                                   
206            1                                  6   is(
207                                                      $qr->fingerprint("select   foo"),
208                                                      "select foo",
209                                                      'Collapses whitespace',
210                                                   );
211                                                   
212            1                                  6   is(
213                                                      $qr->strip_comments("select /*\nhello!*/ 1"),
214                                                      'select  1',
215                                                      'Stripped star comment',
216                                                   );
217                                                   
218            1                                  5   is(
219                                                      $qr->strip_comments('select /*!40101 hello*/ 1'),
220                                                      'select /*!40101 hello*/ 1',
221                                                      'Left version star comment',
222                                                   );
223                                                   
224            1                                  6   is(
225                                                      $qr->fingerprint('SELECT * from foo where a = 5'),
226                                                      'select * from foo where a = ?',
227                                                      'Lowercases, replaces integer',
228                                                   );
229                                                   
230            1                                  7   is(
231                                                      $qr->fingerprint('select 0e0, +6e-30, -6.00 from foo where a = 5.5 or b=0.5 or c=.5'),
232                                                      'select ?, ?, ? from foo where a = ? or b=? or c=?',
233                                                      'Floats',
234                                                   );
235                                                   
236            1                                  7   is(
237                                                      $qr->fingerprint("select 0x0, x'123', 0b1010, b'10101' from foo"),
238                                                      'select ?, ?, ?, ? from foo',
239                                                      'Hex/bit',
240                                                   );
241                                                   
242            1                                  6   is(
243                                                      $qr->fingerprint(" select  * from\nfoo where a = 5"),
244                                                      'select * from foo where a = ?',
245                                                      'Collapses whitespace',
246                                                   );
247                                                   
248            1                                  6   is(
249                                                      $qr->fingerprint("select * from foo where a in (5) and b in (5, 8,9 ,9 , 10)"),
250                                                      'select * from foo where a in(?+) and b in(?+)',
251                                                      'IN lists',
252                                                   );
253                                                   
254            1                                  7   is(
255                                                      $qr->fingerprint("select foo_1 from foo_2_3"),
256                                                      'select foo_? from foo_?_?',
257                                                      'Numeric table names',
258                                                   );
259                                                   
260            1                                  7   is(
261                                                      $qr->distill("select foo_1 from foo_2_3"),
262                                                      'SELECT foo_?_?',
263                                                      'distills numeric table names',
264                                                   );
265                                                   
266                                                   # 123f00 => ?oo because f "looks like it could be a number".
267            1                                  9   is(
268                                                      $qr->fingerprint("select 123foo from 123foo", { prefixes => 1 }),
269                                                      'select ?oo from ?oo',
270                                                      'Numeric table name prefixes',
271                                                   );
272                                                   
273            1                                  9   is(
274                                                      $qr->fingerprint("select 123_foo from 123_foo", { prefixes => 1 }),
275                                                      'select ?_foo from ?_foo',
276                                                      'Numeric table name prefixes with underscores',
277                                                   );
278                                                   
279            1                                  8   is(
280                                                      $qr->fingerprint("insert into abtemp.coxed select foo.bar from foo"),
281                                                      'insert into abtemp.coxed select foo.bar from foo',
282                                                      'A string that needs no changes',
283                                                   );
284                                                   
285            1                                  7   is(
286                                                      $qr->distill("insert into abtemp.coxed select foo.bar from foo"),
287                                                      'INSERT SELECT abtemp.coxed foo',
288                                                      'distills insert/select',
289                                                   );
290                                                   
291            1                                 21   is(
292                                                      $qr->fingerprint('insert into foo(a, b, c) values(2, 4, 5)'),
293                                                      'insert into foo(a, b, c) values(?+)',
294                                                      'VALUES lists',
295                                                   );
296                                                   
297            1                                  6   is(
298                                                      $qr->distill('insert into foo(a, b, c) values(2, 4, 5)'),
299                                                      'INSERT foo',
300                                                      'distills value lists',
301                                                   );
302                                                   
303            1                                  9   is(
304                                                      $qr->fingerprint('insert into foo(a, b, c) values(2, 4, 5) , (2,4,5)'),
305                                                      'insert into foo(a, b, c) values(?+)',
306                                                      'VALUES lists with multiple ()',
307                                                   );
308                                                   
309            1                                  7   is(
310                                                      $qr->fingerprint('insert into foo(a, b, c) value(2, 4, 5)'),
311                                                      'insert into foo(a, b, c) value(?+)',
312                                                      'VALUES lists with VALUE()',
313                                                   );
314                                                   
315            1                                  7   is(
316                                                      $qr->fingerprint('select * from foo limit 5'),
317                                                      'select * from foo limit ?',
318                                                      'limit alone',
319                                                   );
320                                                   
321            1                                  7   is(
322                                                      $qr->fingerprint('select * from foo limit 5, 10'),
323                                                      'select * from foo limit ?',
324                                                      'limit with comma-offset',
325                                                   );
326                                                   
327            1                                  6   is(
328                                                      $qr->fingerprint('select * from foo limit 5 offset 10'),
329                                                      'select * from foo limit ?',
330                                                      'limit with offset',
331                                                   );
332                                                   
333            1                                  6   is(
334                                                      $qr->fingerprint('select 1 union select 2 union select 4'),
335                                                      'select ? /*repeat union*/',
336                                                      'union fingerprints together',
337                                                   );
338                                                   
339            1                                  7   is(
340                                                      $qr->distill('select 1 union select 2 union select 4'),
341                                                      'SELECT UNION',
342                                                      'union distills together',
343                                                   );
344                                                   
345            1                                  7   is(
346                                                      $qr->fingerprint('select 1 union all select 2 union all select 4'),
347                                                      'select ? /*repeat union all*/',
348                                                      'union all fingerprints together',
349                                                   );
350                                                   
351            1                                  7   is(
352                                                      $qr->fingerprint(
353                                                         q{select * from (select 1 union all select 2 union all select 4) as x }
354                                                         . q{join (select 2 union select 2 union select 3) as y}),
355                                                      q{select * from (select ? /*repeat union all*/) as x }
356                                                         . q{join (select ? /*repeat union*/) as y},
357                                                      'union all fingerprints together',
358                                                   );
359                                                   
360            1                                  7   is($qr->convert_to_select(), undef, 'No query');
361                                                   
362            1                                  6   is(
363                                                      $qr->convert_to_select(
364                                                         'replace into foo select * from bar',
365                                                      ),
366                                                      'select * from bar',
367                                                      'replace select',
368                                                   );
369                                                   
370            1                                  6   is(
371                                                      $qr->convert_to_select(
372                                                         'replace into foo select`faz` from bar',
373                                                      ),
374                                                      'select`faz` from bar',
375                                                      'replace select',
376                                                   );
377                                                   
378            1                                  8   is(
379                                                      $qr->convert_to_select(
380                                                         'insert into foo(a, b, c) values(1, 3, 5)',
381                                                      ),
382                                                      'select * from  foo where a=1 and  b= 3 and  c= 5',
383                                                      'insert',
384                                                   );
385                                                   
386            1                                  8   is(
387                                                      $qr->convert_to_select(
388                                                         'insert ignore into foo(a, b, c) values(1, 3, 5)',
389                                                      ),
390                                                      'select * from  foo where a=1 and  b= 3 and  c= 5',
391                                                      'insert ignore',
392                                                   );
393                                                   
394            1                                  6   is(
395                                                      $qr->convert_to_select(
396                                                         'insert into foo(a, b, c) value(1, 3, 5)',
397                                                      ),
398                                                      'select * from  foo where a=1 and  b= 3 and  c= 5',
399                                                      'insert with VALUE()',
400                                                   );
401                                                   
402            1                                  6   is(
403                                                      $qr->convert_to_select(
404                                                         'replace into foo(a, b, c) values(1, 3, 5) on duplicate key update foo=bar',
405                                                      ),
406                                                      'select * from  foo where a=1 and  b= 3 and  c= 5',
407                                                      'replace with ODKU',
408                                                   );
409                                                   
410            1                                  7   is(
411                                                      $qr->distill(
412                                                         'replace into foo(a, b, c) values(1, 3, 5) on duplicate key update foo=bar',
413                                                      ),
414                                                      'REPLACE UPDATE foo',
415                                                      'distills ODKU',
416                                                   );
417                                                   
418            1                                  7   is(
419                                                      $qr->convert_to_select(
420                                                         'replace into foo(a, b, c) values(now(), "3", 5)',
421                                                      ),
422                                                      'select * from  foo where a=now() and  b= "3" and  c= 5',
423                                                      'replace with complicated expressions',
424                                                   );
425                                                   
426            1                                  6   is(
427                                                      $qr->convert_to_select(
428                                                         'replace into foo(a, b, c) values(current_date - interval 1 day, "3", 5)',
429                                                      ),
430                                                      'select * from  foo where a=current_date - interval 1 day and  b= "3" and  c= 5',
431                                                      'replace with complicated expressions',
432                                                   );
433                                                   
434            1                                  7   is(
435                                                      $qr->convert_to_select(
436                                                         'insert into foo select * from bar join baz using (bat)',
437                                                      ),
438                                                      'select * from bar join baz using (bat)',
439                                                      'insert select',
440                                                   );
441                                                   
442            1                                  6   is(
443                                                      $qr->distill(
444                                                         'insert into foo select * from bar join baz using (bat)',
445                                                      ),
446                                                      'INSERT SELECT foo bar baz',
447                                                      'distills insert select',
448                                                   );
449                                                   
450            1                                  6   is(
451                                                      $qr->convert_to_select(
452                                                         'insert into foo select * from bar where baz=bat on duplicate key update',
453                                                      ),
454                                                      'select * from bar where baz=bat',
455                                                      'insert select on duplicate key update',
456                                                   );
457                                                   
458            1                                  7   is(
459                                                      $qr->convert_to_select(
460                                                         'update foo set bar=baz where bat=fiz',
461                                                      ),
462                                                      'select  bar=baz from foo where  bat=fiz',
463                                                      'update set',
464                                                   );
465                                                   
466            1                                  6   is(
467                                                      $qr->distill(
468                                                         'update foo set bar=baz where bat=fiz',
469                                                      ),
470                                                      'UPDATE foo',
471                                                      'distills update',
472                                                   );
473                                                   
474            1                                  7   is(
475                                                      $qr->convert_to_select(
476                                                         'update foo inner join bar using(baz) set big=little',
477                                                      ),
478                                                      'select  big=little from foo inner join bar using(baz) ',
479                                                      'delete inner join',
480                                                   );
481                                                   
482            1                                  7   is(
483                                                      $qr->distill(
484                                                         'update foo inner join bar using(baz) set big=little',
485                                                      ),
486                                                      'UPDATE foo bar',
487                                                      'distills update-multi',
488                                                   );
489                                                   
490            1                                  7   is(
491                                                      $qr->convert_to_select(
492                                                         'update foo set bar=baz limit 50',
493                                                      ),
494                                                      'select  bar=baz  from foo  limit 50 ',
495                                                      'update with limit',
496                                                   );
497                                                   
498            1                                  6   is(
499                                                      $qr->convert_to_select(
500                                                   q{UPDATE foo.bar
501                                                   SET    whereproblem= '3364', apple = 'fish'
502                                                   WHERE  gizmo='5091'}
503                                                      ),
504                                                      q{select     whereproblem= '3364', apple = 'fish' from foo.bar where   gizmo='5091'},
505                                                      'unknown issue',
506                                                   );
507                                                   
508            1                                  7   is(
509                                                      $qr->convert_to_select(
510                                                         'delete from foo where bar = baz',
511                                                      ),
512                                                      'select * from  foo where bar = baz',
513                                                      'delete',
514                                                   );
515                                                   
516            1                                  6   is(
517                                                      $qr->distill(
518                                                         'delete from foo where bar = baz',
519                                                      ),
520                                                      'DELETE foo',
521                                                      'distills delete',
522                                                   );
523                                                   
524                                                   # Insanity...
525            1                                  7   is(
526                                                      $qr->convert_to_select('
527                                                   update db2.tbl1 as p
528                                                      inner join (
529                                                         select p2.col1, p2.col2
530                                                         from db2.tbl1 as p2
531                                                            inner join db2.tbl3 as ba
532                                                               on p2.col1 = ba.tbl3
533                                                         where col4 = 0
534                                                         order by priority desc, col1, col2
535                                                         limit 10
536                                                      ) as chosen on chosen.col1 = p.col1
537                                                         and chosen.col2 = p.col2
538                                                      set p.col4 = 149945'),
539                                                      'select  p.col4 = 149945 from db2.tbl1 as p
540                                                      inner join (
541                                                         select p2.col1, p2.col2
542                                                         from db2.tbl1 as p2
543                                                            inner join db2.tbl3 as ba
544                                                               on p2.col1 = ba.tbl3
545                                                         where col4 = 0
546                                                         order by priority desc, col1, col2
547                                                         limit 10
548                                                      ) as chosen on chosen.col1 = p.col1
549                                                         and chosen.col2 = p.col2 ',
550                                                      'SELECT in the FROM clause',
551                                                   );
552                                                   
553            1                                  7   is(
554                                                      $qr->distill('
555                                                   update db2.tbl1 as p
556                                                      inner join (
557                                                         select p2.col1, p2.col2
558                                                         from db2.tbl1 as p2
559                                                            inner join db2.tbl3 as ba
560                                                               on p2.col1 = ba.tbl3
561                                                         where col4 = 0
562                                                         order by priority desc, col1, col2
563                                                         limit 10
564                                                      ) as chosen on chosen.col1 = p.col1
565                                                         and chosen.col2 = p.col2
566                                                      set p.col4 = 149945'),
567                                                      'UPDATE SELECT db?.tbl?',
568                                                      'distills complex subquery',
569                                                   );
570                                                   
571            1                                  6   is(
572                                                      $qr->convert_to_select(q{INSERT INTO foo.bar (col1, col2, col3)
573                                                          VALUES ('unbalanced(', 'val2', 3)}),
574                                                      q{select * from  foo.bar  where col1='unbalanced(' and  }
575                                                      . q{col2= 'val2' and  col3= 3},
576                                                      'unbalanced paren inside a string in VALUES',
577                                                   );
578                                                   
579            1                                  7   is(
580                                                      $qr->convert_to_select(q{delete foo.bar b from foo.bar b left join baz.bat c on a=b where nine>eight}),
581                                                      'select 1 from  foo.bar b left join baz.bat c on a=b where nine>eight',
582                                                      'Do not select * from a join',
583                                                   );
584                                                   
585            1                                  6   is(
586                                                      $qr->distill(q{delete foo.bar b from foo.bar b left join baz.bat c on a=b where nine>eight}),
587                                                      'DELETE foo.bar baz.bat',
588                                                      'distills and then collapses same tables',
589                                                   );
590                                                   
591            1                                  7   is (
592                                                      $qr->convert_to_select(q{
593                                                   REPLACE DELAYED INTO
594                                                   `db1`.`tbl2`(`col1`,col2)
595                                                   VALUES ('617653','2007-09-11')}),
596                                                      qq{select * from \n`db1`.`tbl2` where `col1`='617653' and col2='2007-09-11'},
597                                                      'replace delayed',
598                                                   );
599                                                   
600            1                                  6   is (
601                                                      $qr->distill(q{
602                                                   REPLACE DELAYED INTO
603                                                   `db1`.`tbl2`(`col1`,col2)
604                                                   VALUES ('617653','2007-09-11')}),
605                                                      'REPLACE db?.tbl?',
606                                                      'distills replace-delayed',
607                                                   );
608                                                   
609            1                                  6   is(
610                                                      $qr->convert_to_select(
611                                                         'select * from tbl where id = 1'
612                                                      ),
613                                                      'select * from tbl where id = 1',
614                                                      'Does not convert select to select',
615                                                   );
616                                                   
617            1                                  7   is($qr->wrap_in_derived(), undef, 'Cannot wrap undef');
618                                                   
619            1                                  7   is(
620                                                      $qr->wrap_in_derived(
621                                                         'select * from foo',
622                                                      ),
623                                                      'select 1 from (select * from foo) as x limit 1',
624                                                      'wrap in derived table',
625                                                   );
626                                                   
627            1                                  7   is(
628                                                      $qr->wrap_in_derived('set timestamp=134'),
629                                                      'set timestamp=134',
630                                                      'Do not wrap non-SELECT queries',
631                                                   );
632                                                   
633            1                                  6   is(
634                                                      $qr->distill('set timestamp=134'),
635                                                      'SET',
636                                                      'distills set',
637                                                   );
638                                                   
639            1                                  7   is(
640                                                      $qr->convert_select_list('select * from tbl'),
641                                                      'select 1 from tbl',
642                                                      'Star to one',
643                                                   );
644                                                   
645            1                                  6   is(
646                                                      $qr->convert_select_list('select a, b, c from tbl'),
647                                                      'select isnull(coalesce( a, b, c )) from tbl',
648                                                      'column list to isnull/coalesce'
649                                                   );
650                                                   
651            1                                  7   is(
652                                                      $qr->convert_to_select("UPDATE tbl SET col='wherex'WHERE crazy=1"),
653                                                      "select  col='wherex' from tbl where  crazy=1",
654                                                      "update with SET col='wherex'WHERE"
655                                                   );
656                                                   
657            1                                  8   is($qr->convert_to_select(
658                                                      q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
659                                                      . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
660                                                      . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
661                                                      . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
662                                                      . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
663                                                      . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
664                                                      . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )}),
665                                                      "select  GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME='Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59' from GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU where  PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1 AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0 AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )",
666                                                      'update with no space between quoted string and where (issue 168)'
667                                                   );
668                                                   
669            1                                  7   is($qr->distill(
670                                                      q{UPDATE GARDEN_CLUPL PL, GARDENJOB GC, APLTRACT_GARDENPLANT ABU SET }
671                                                      . q{GC.MATCHING_POT = 5, GC.LAST_GARDENPOT = 5, GC.LAST_NAME=}
672                                                      . q{'Rotary', GC.LAST_BUCKET='Pail', GC.LAST_UPDATE='2008-11-27 04:00:59'WHERE}
673                                                      . q{ PL.APLTRACT_GARDENPLANT_ID = GC.APLTRACT_GARDENPLANT_ID AND PL.}
674                                                      . q{APLTRACT_GARDENPLANT_ID = ABU.ID AND GC.MATCHING_POT = 0 AND GC.PERFORM_DIG=1}
675                                                      . q{ AND ABU.DIG = 6 AND ( ((SOIL-COST) > -80.0}
676                                                      . q{ AND BUGS < 60.0 AND (SOIL-COST) < 200.0) AND POTS < 10.0 )}),
677                                                      'UPDATE GARDEN_CLUPL GARDENJOB APLTRACT_GARDENPLANT',
678                                                      'distills where there is alias and comma-join',
679                                                   );
680                                                   
681            1                                  7   is(
682                                                      $qr->distill(q{SELECT STRAIGHT_JOIN distinct foo, bar FROM A, B, C}),
683                                                      'SELECT A B C',
684                                                      'distill with STRAIGHT_JOIN',
685                                                   );
686                                                   
687            1                                  6   is(
688                                                      $qr->distill(
689                                                         'replace into checksum.checksum select `last_update`, `foo` from foo.foo'),
690                                                      'REPLACE SELECT checksum.checksum foo.foo',
691                                                      'distill with reserved words');
692                                                   
693            1                                  7   is($qr->distill('SHOW STATUS'), 'SHOW STATUS', 'distill SHOW STATUS');
694                                                   
695            1                                  6   is($qr->distill('commit'), 'COMMIT', 'distill COMMIT');
696                                                   
697            1                                  6   is($qr->distill('FLUSH TABLES WITH READ LOCK'), 'FLUSH', 'distill FLUSH');
698                                                   
699            1                                  7   is($qr->distill('BEGIN'), 'BEGIN', 'distill BEGIN');
700                                                   
701            1                                  6   is($qr->distill('start'), 'START', 'distill START');
702                                                   
703            1                                  8   is($qr->distill('ROLLBACK'), 'ROLLBACK', 'distill ROLLBACK');
704                                                   
705            1                                  8   is(
706                                                      $qr->shorten("insert into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
707                                                      "insert into t(a,b,c) values(a,b,c) /*... omitted ...*/",
708                                                      "shorten simple insert",
709                                                   );
710                                                   
711            1                                  6   is(
712                                                      $qr->shorten("insert low_priority into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
713                                                      "insert low_priority into t(a,b,c) values(a,b,c) /*... omitted ...*/",
714                                                      "shorten low_priority simple insert",
715                                                   );
716                                                   
717            1                                  7   is(
718                                                      $qr->shorten("insert delayed into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
719                                                      "insert delayed into t(a,b,c) values(a,b,c) /*... omitted ...*/",
720                                                      "shorten delayed simple insert",
721                                                   );
722                                                   
723            1                                  6   is(
724                                                      $qr->shorten("insert high_priority into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
725                                                      "insert high_priority into t(a,b,c) values(a,b,c) /*... omitted ...*/",
726                                                      "shorten high_priority simple insert",
727                                                   );
728                                                   
729            1                                  6   is(
730                                                      $qr->shorten("insert ignore into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
731                                                      "insert ignore into t(a,b,c) values(a,b,c) /*... omitted ...*/",
732                                                      "shorten ignore simple insert",
733                                                   );
734                                                   
735            1                                  7   is(
736                                                      $qr->shorten("insert high_priority ignore into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
737                                                      "insert high_priority ignore into t(a,b,c) values(a,b,c) /*... omitted ...*/",
738                                                      "shorten high_priority ignore simple insert",
739                                                   );
740                                                   
741            1                                  7   is(
742                                                      $qr->shorten("replace low_priority into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
743                                                      "replace low_priority into t(a,b,c) values(a,b,c) /*... omitted ...*/",
744                                                      "shorten replace low_priority",
745                                                   );
746                                                   
747            1                                  7   is(
748                                                      $qr->shorten("replace delayed into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i)"),
749                                                      "replace delayed into t(a,b,c) values(a,b,c) /*... omitted ...*/",
750                                                      "shorten replace delayed",
751                                                   );
752                                                   
753            1                                  6   is(
754                                                      $qr->shorten("insert into t(a,b,c) values(a,b,c),(d,e,f),(g,h,i) on duplicate key update a = b"),
755                                                      "insert into t(a,b,c) values(a,b,c) /*... omitted ...*/on duplicate key update a = b",
756                                                      "shorten insert ... odku",
757                                                   );
758                                                   
759            1                               1433   is(
760                                                      $qr->shorten(
761                                                         "select * from a where b in(" . join(',', 1..60) . ") and "
762                                                            . "a in(" . join(',', 1..5000) . ")", 1),
763                                                      "select * from a where b in(" . join(',', 1..20) . "/*... omitted 40 items ...*/)"
764                                                         . " and a in(" . join(',', 1..20) . "/*... omitted 4980 items ...*/)",
765                                                      "shorten two IN() lists of numbers",
766                                                   );
767                                                   
768            1                                  8   is(
769                                                      $qr->shorten("select * from a", 1),
770                                                      "select * from a",
771                                                      "Does not shorten strings it does not match",
772                                                   );
773                                                   
774            1                                 34   is(
775                                                      $qr->shorten("select * from a where b in(". join(',', 1..100) . ")", 1024),
776                                                      "select * from a where b in(". join(',', 1..100) . ")",
777                                                      "shorten IN() list numbers but not those that are already short enough",
778                                                   );
779                                                   
780            1                                 50   is(
781                                                      $qr->shorten("select * from a where b in(" . join(',', 1..100) . "'a,b')", 1),
782                                                      "select * from a where b in(" . join(',', 1..20) . "/*... omitted 81 items ...*/)",
783                                                      "Test case to document that commas are expected to mess up omitted count",
784                                                   );
785                                                   
786            1                                 35   is(
787                                                      $qr->shorten("select * from a where b in(1, 'a)b', " . join(',', 1..100) . ")", 1),
788                                                      "select * from a where b in(1, 'a)b', " . join(',', 1..100) . ")",
789                                                      "Test case to document that parens are expected to prevent shortening",
790                                                   );
791                                                   
792            1                                  9   is(
793                                                      $qr->distill('create database foo'),
794                                                      'CREATE DATABASE foo',
795                                                      'distills create database'
796                                                   );
797            1                                  7   is(
798                                                      $qr->distill('create table foo'),
799                                                      'CREATE TABLE foo',
800                                                      'distills create table'
801                                                   );
802            1                                  7   is(
803                                                      $qr->distill('alter database foo'),
804                                                      'ALTER DATABASE foo',
805                                                      'distills alter database'
806                                                   );
807            1                                  7   is(
808                                                      $qr->distill('alter table foo'),
809                                                      'ALTER TABLE foo',
810                                                      'distills alter table'
811                                                   );
812            1                                  7   is(
813                                                      $qr->distill('drop database foo'),
814                                                      'DROP DATABASE foo',
815                                                      'distills drop database'
816                                                   );
817            1                                  7   is(
818                                                      $qr->distill('drop table foo'),
819                                                      'DROP TABLE foo',
820                                                      'distills drop table'
821                                                   );
822            1                                  7   is(
823                                                      $qr->distill('rename database foo'),
824                                                      'RENAME DATABASE foo',
825                                                      'distills rename database'
826                                                   );
827            1                                  6   is(
828                                                      $qr->distill('rename table foo'),
829                                                      'RENAME TABLE foo',
830                                                      'distills rename table'
831                                                   );
832            1                                  7   is(
833                                                      $qr->distill('truncate table foo'),
834                                                      'TRUNCATE TABLE foo',
835                                                      'distills truncate table'
836                                                   );
837                                                   
838                                                   # Test generic distillation for memcached, http, etc.
839                                                   my $trf = sub {
840            3                    3            14      my ( $query ) = @_;
841            3                                 26      $query =~ s/(\S+ \S+?)(?:[?;].+)/$1/;
842            3                                 14      return $query;
843            1                                  9   };
844                                                   
845            1                                  7   is(
846                                                      $qr->distill('get percona.com/', generic => 1, trf => $trf),
847                                                      'GET percona.com/',
848                                                      'generic distill HTTP get'
849                                                   );
850                                                   
851            1                                  8   is(
852                                                      $qr->distill('get percona.com/page.html?some=thing', generic => 1, trf => $trf),
853                                                      'GET percona.com/page.html',
854                                                      'generic distill HTTP get with args'
855                                                   );
856                                                   
857            1                                  8   is(
858                                                      $qr->distill('put percona.com/contacts.html', generic => 1, trf => $trf),
859                                                      'PUT percona.com/contacts.html',
860                                                      'generic distill HTTP put'
861                                                   );
862                                                   
863                                                   # #############################################################################
864                                                   # Issue 322: mk-query-digest segfault before report
865                                                   # #############################################################################
866            1                                 12   is(
867                                                      $qr->fingerprint( load_file('common/t/samples/huge_replace_into_values.txt') ),
868                                                      q{replace into `film_actor` values(?+)},
869                                                      'huge replace into values() (issue 322)',
870                                                   );
871            1                                 37   is(
872                                                      $qr->fingerprint( load_file('common/t/samples/huge_insert_ignore_into_values.txt') ),
873                                                      q{insert ignore into `film_actor` values(?+)},
874                                                      'huge insert ignore into values() (issue 322)',
875                                                   );
876            1                                 10   is(
877                                                      $qr->fingerprint( load_file('common/t/samples/huge_explicit_cols_values.txt') ),
878                                                      q{insert into foo (a,b,c,d,e,f,g,h) values(?+)},
879                                                      'huge insert with explicit columns before values() (issue 322)',
880                                                   );
881                                                   
882                                                   # Those ^ aren't huge enough.  This one is 1.2M large. 
883            1                              35636   my $huge_insert = `zcat $trunk/common/t/samples/slow039.txt.gz | tail -n 1`;
884            1                                 47   is(
885                                                      $qr->fingerprint($huge_insert),
886                                                      q{insert into the_universe values(?+)},
887                                                      'truly huge insert 1/2 (issue 687)'
888                                                   );
889            1                              34853   $huge_insert = `zcat $trunk/common/t/samples/slow040.txt.gz | tail -n 2`;
890            1                                 47   is(
891                                                      $qr->fingerprint($huge_insert),
892                                                      q{insert into the_universe values(?+)},
893                                                      'truly huge insert 2/2 (issue 687)'
894                                                   );
895                                                   
896                                                   # #############################################################################
897                                                   # Issue 563: Lock tables is not distilled
898                                                   # #############################################################################
899            1                                 12   is(
900                                                      $qr->distill('LOCK TABLES foo WRITE'),
901                                                      'LOCK foo',
902                                                      'distills lock tables'
903                                                   );
904            1                                 11   is(
905                                                      $qr->distill('LOCK TABLES foo READ, bar WRITE'),
906                                                      'LOCK foo bar',
907                                                      'distills lock tables (2 tables)'
908                                                   );
909            1                                 10   is(
910                                                      $qr->distill('UNLOCK TABLES'),
911                                                      'UNLOCK',
912                                                      'distills unlock tables'
913                                                   );
914                                                   
915                                                   # #############################################################################
916                                                   #  Issue 712: Queries not handled by "distill"
917                                                   # #############################################################################
918            1                                  6   is(
919                                                      $qr->distill('XA START 0x123'),
920                                                      'XA_START',
921                                                      'distills xa start'
922                                                   );
923            1                                  6   is(
924                                                      $qr->distill('XA PREPARE 0x123'),
925                                                      'XA_PREPARE',
926                                                      'distills xa prepare'
927                                                   );
928            1                                  7   is(
929                                                      $qr->distill('XA COMMIT 0x123'),
930                                                      'XA_COMMIT',
931                                                      'distills xa commit'
932                                                   );
933            1                                  7   is(
934                                                      $qr->distill('XA END 0x123'),
935                                                      'XA_END',
936                                                      'distills xa end'
937                                                   );
938                                                   
939            1                                  6   is(
940                                                      $qr->distill("/* mysql-connector-java-5.1-nightly-20090730 ( Revision: \${svn.Revision} ) */SHOW VARIABLES WHERE Variable_name ='language' OR Variable_name =
941                                                      'net_write_timeout' OR Variable_name = 'interactive_timeout' OR
942                                                      Variable_name = 'wait_timeout' OR Variable_name = 'character_set_client' OR
943                                                      Variable_name = 'character_set_connection' OR Variable_name =
944                                                      'character_set' OR Variable_name = 'character_set_server' OR Variable_name
945                                                      = 'tx_isolation' OR Variable_name = 'transaction_isolation' OR
946                                                      Variable_name = 'character_set_results' OR Variable_name = 'timezone' OR
947                                                      Variable_name = 'time_zone' OR Variable_name = 'system_time_zone' OR
948                                                      Variable_name = 'lower_case_table_names' OR Variable_name =
949                                                      'max_allowed_packet' OR Variable_name = 'net_buffer_length' OR
950                                                      Variable_name = 'sql_mode' OR Variable_name = 'query_cache_type' OR
951                                                      Variable_name = 'query_cache_size' OR Variable_name = 'init_connect'"),
952                                                      'SHOW VARIABLES',
953                                                      'distills /* comment */SHOW VARIABLES'
954                                                   );
955                                                   
956                                                   # This is a list of all the types of syntax for SHOW on
957                                                   # http://dev.mysql.com/doc/refman/5.0/en/show.html
958            1                                105   my %status_tests = (
959                                                      'SHOW BINARY LOGS'                           => 'SHOW BINARY LOGS',
960                                                      'SHOW BINLOG EVENTS in "log_name"'           => 'SHOW BINLOG EVENTS',
961                                                      'SHOW CHARACTER SET LIKE "pattern"'          => 'SHOW CHARACTER SET',
962                                                      'SHOW COLLATION WHERE "something"'           => 'SHOW COLLATION',
963                                                      'SHOW COLUMNS FROM tbl'                      => 'SHOW COLUMNS',
964                                                      'SHOW FULL COLUMNS FROM tbl'                 => 'SHOW COLUMNS',
965                                                      'SHOW COLUMNS FROM tbl in db'                => 'SHOW COLUMNS',
966                                                      'SHOW COLUMNS FROM tbl IN db LIKE "pattern"' => 'SHOW COLUMNS',
967                                                      'SHOW CREATE DATABASE db_name'               => 'SHOW CREATE DATABASE',
968                                                      'SHOW CREATE SCHEMA db_name'                 => 'SHOW CREATE DATABASE',
969                                                      'SHOW CREATE FUNCTION func'                  => 'SHOW CREATE FUNCTION',
970                                                      'SHOW CREATE PROCEDURE proc'                 => 'SHOW CREATE PROCEDURE',
971                                                      'SHOW CREATE TABLE tbl_name'                 => 'SHOW CREATE TABLE',
972                                                      'SHOW CREATE VIEW vw_name'                   => 'SHOW CREATE VIEW',
973                                                      'SHOW DATABASES'                             => 'SHOW DATABASES',
974                                                      'SHOW SCHEMAS'                               => 'SHOW DATABASES',
975                                                      'SHOW DATABASES LIKE "pattern"'              => 'SHOW DATABASES',
976                                                      'SHOW DATABASES WHERE foo=bar'               => 'SHOW DATABASES',
977                                                      'SHOW ENGINE ndb status'                     => 'SHOW NDB STATUS',
978                                                      'SHOW ENGINE innodb status'                  => 'SHOW INNODB STATUS',
979                                                      'SHOW ENGINES'                               => 'SHOW ENGINES',
980                                                      'SHOW STORAGE ENGINES'                       => 'SHOW ENGINES',
981                                                      'SHOW ERRORS'                                => 'SHOW ERRORS',
982                                                      'SHOW ERRORS limit 5'                        => 'SHOW ERRORS',
983                                                      'SHOW COUNT(*) ERRORS'                       => 'SHOW ERRORS',
984                                                      'SHOW FUNCTION CODE func'                    => 'SHOW FUNCTION CODE',
985                                                      'SHOW FUNCTION STATUS'                       => 'SHOW FUNCTION STATUS',
986                                                      'SHOW FUNCTION STATUS LIKE "pattern"'        => 'SHOW FUNCTION STATUS',
987                                                      'SHOW FUNCTION STATUS WHERE foo=bar'         => 'SHOW FUNCTION STATUS',
988                                                      'SHOW GRANTS'                                => 'SHOW GRANTS',
989                                                      'SHOW GRANTS FOR user@localhost'             => 'SHOW GRANTS',
990                                                      'SHOW INDEX'                                 => 'SHOW INDEX',
991                                                      'SHOW INDEXES'                               => 'SHOW INDEX',
992                                                      'SHOW KEYS'                                  => 'SHOW INDEX',
993                                                      'SHOW INDEX FROM tbl'                        => 'SHOW INDEX',
994                                                      'SHOW INDEX FROM tbl IN db'                  => 'SHOW INDEX',
995                                                      'SHOW INDEX IN tbl FROM db'                  => 'SHOW INDEX',
996                                                      'SHOW INNODB STATUS'                         => 'SHOW INNODB STATUS',
997                                                      'SHOW LOGS'                                  => 'SHOW LOGS',
998                                                      'SHOW MASTER STATUS'                         => 'SHOW MASTER STATUS',
999                                                      'SHOW MUTEX STATUS'                          => 'SHOW MUTEX STATUS',
1000                                                     'SHOW OPEN TABLES'                           => 'SHOW OPEN TABLES',
1001                                                     'SHOW OPEN TABLES FROM db'                   => 'SHOW OPEN TABLES',
1002                                                     'SHOW OPEN TABLES IN db'                     => 'SHOW OPEN TABLES',
1003                                                     'SHOW OPEN TABLES IN db LIKE "pattern"'      => 'SHOW OPEN TABLES',
1004                                                     'SHOW OPEN TABLES IN db WHERE foo=bar'       => 'SHOW OPEN TABLES',
1005                                                     'SHOW OPEN TABLES WHERE foo=bar'             => 'SHOW OPEN TABLES',
1006                                                     'SHOW PRIVILEGES'                            => 'SHOW PRIVILEGES',
1007                                                     'SHOW PROCEDURE CODE proc'                   => 'SHOW PROCEDURE CODE',
1008                                                     'SHOW PROCEDURE STATUS'                      => 'SHOW PROCEDURE STATUS',
1009                                                     'SHOW PROCEDURE STATUS LIKE "pattern"'       => 'SHOW PROCEDURE STATUS',
1010                                                     'SHOW PROCEDURE STATUS WHERE foo=bar'        => 'SHOW PROCEDURE STATUS',
1011                                                     'SHOW PROCESSLIST'                           => 'SHOW PROCESSLIST',
1012                                                     'SHOW FULL PROCESSLIST'                      => 'SHOW PROCESSLIST',
1013                                                     'SHOW PROFILE'                               => 'SHOW PROFILE',
1014                                                     'SHOW PROFILES'                              => 'SHOW PROFILES',
1015                                                     'SHOW PROFILES CPU FOR QUERY 1'              => 'SHOW PROFILES CPU',
1016                                                     'SHOW SLAVE HOSTS'                           => 'SHOW SLAVE HOSTS',
1017                                                     'SHOW SLAVE STATUS'                          => 'SHOW SLAVE STATUS',
1018                                                     'SHOW STATUS'                                => 'SHOW STATUS',
1019                                                     'SHOW GLOBAL STATUS'                         => 'SHOW STATUS',
1020                                                     'SHOW SESSION STATUS'                        => 'SHOW STATUS',
1021                                                     'SHOW STATUS LIKE "pattern"'                 => 'SHOW STATUS',
1022                                                     'SHOW STATUS WHERE foo=bar'                  => 'SHOW STATUS',
1023                                                     'SHOW TABLE STATUS'                          => 'SHOW TABLE STATUS',
1024                                                     'SHOW TABLE STATUS FROM db_name'             => 'SHOW TABLE STATUS',
1025                                                     'SHOW TABLE STATUS IN db_name'               => 'SHOW TABLE STATUS',
1026                                                     'SHOW TABLE STATUS LIKE "pattern"'           => 'SHOW TABLE STATUS',
1027                                                     'SHOW TABLE STATUS WHERE foo=bar'            => 'SHOW TABLE STATUS',
1028                                                     'SHOW TABLES'                                => 'SHOW TABLES',
1029                                                     'SHOW FULL TABLES'                           => 'SHOW TABLES',
1030                                                     'SHOW TABLES FROM db'                        => 'SHOW TABLES',
1031                                                     'SHOW TABLES IN db'                          => 'SHOW TABLES',
1032                                                     'SHOW TABLES LIKE "pattern"'                 => 'SHOW TABLES',
1033                                                     'SHOW TABLES FROM db LIKE "pattern"'         => 'SHOW TABLES',
1034                                                     'SHOW TABLES WHERE foo=bar'                  => 'SHOW TABLES',
1035                                                     'SHOW TRIGGERS'                              => 'SHOW TRIGGERS',
1036                                                     'SHOW TRIGGERS IN db'                        => 'SHOW TRIGGERS',
1037                                                     'SHOW TRIGGERS FROM db'                      => 'SHOW TRIGGERS',
1038                                                     'SHOW TRIGGERS LIKE "pattern"'               => 'SHOW TRIGGERS',
1039                                                     'SHOW TRIGGERS WHERE foo=bar'                => 'SHOW TRIGGERS',
1040                                                     'SHOW VARIABLES'                             => 'SHOW VARIABLES',
1041                                                     'SHOW GLOBAL VARIABLES'                      => 'SHOW VARIABLES',
1042                                                     'SHOW SESSION VARIABLES'                     => 'SHOW VARIABLES',
1043                                                     'SHOW VARIABLES LIKE "pattern"'              => 'SHOW VARIABLES',
1044                                                     'SHOW VARIABLES WHERE foo=bar'               => 'SHOW VARIABLES',
1045                                                     'SHOW WARNINGS'                              => 'SHOW WARNINGS',
1046                                                     'SHOW WARNINGS LIMIT 5'                      => 'SHOW WARNINGS',
1047                                                     'SHOW COUNT(*) WARNINGS'                     => 'SHOW WARNINGS',
1048                                                  );
1049                                                  
1050           1                                 18   foreach my $key ( keys %status_tests ) {
1051          89                                486      is($qr->distill($key), $status_tests{$key}, "distills $key");
1052                                                  }
1053                                                  
1054                                                  is(
1055           1                                 16      $qr->distill('SHOW SLAVE STATUS'),
1056                                                     'SHOW SLAVE STATUS',
1057                                                     'distills SHOW SLAVE STATUS'
1058                                                  );
1059           1                                  7   is(
1060                                                     $qr->distill('SHOW INNODB STATUS'),
1061                                                     'SHOW INNODB STATUS',
1062                                                     'distills SHOW INNODB STATUS'
1063                                                  );
1064           1                                  6   is(
1065                                                     $qr->distill('SHOW CREATE TABLE'),
1066                                                     'SHOW CREATE TABLE',
1067                                                     'distills SHOW CREATE TABLE'
1068                                                  );
1069                                                  
1070           1                                 11   my @show = qw(COLUMNS GRANTS INDEX STATUS TABLES TRIGGERS WARNINGS);
1071           1                                  4   foreach my $show ( @show ) {
1072           7                                 39      is(
1073                                                        $qr->distill("SHOW $show"),
1074                                                        "SHOW $show",
1075                                                        "distills SHOW $show"
1076                                                     );
1077                                                  }
1078                                                  
1079                                                  # #############################################################################
1080                                                  #  Issue 735: mk-query-digest doesn't distill query correctly
1081                                                  # #############################################################################
1082                                                  
1083                                                  is( 
1084           1                                  7   	$qr->distill('SHOW /*!50002 GLOBAL */ STATUS'),
1085                                                  	'SHOW STATUS',
1086                                                  	"distills SHOW STATUS"
1087                                                  );
1088                                                  
1089           1                                  8   is( 
1090                                                  	$qr->distill('SHOW /*!50002 ENGINE */ INNODB STATUS'),
1091                                                  	'SHOW INNODB STATUS',
1092                                                  	"distills SHOW INNODB STATUS"
1093                                                  );
1094                                                  
1095           1                                  7   is( 
1096                                                  	$qr->distill('SHOW MASTER LOGS'),
1097                                                  	'SHOW MASTER LOGS',
1098                                                  	"distills SHOW MASTER LOGS"
1099                                                  );
1100                                                  
1101           1                                  6   is( 
1102                                                  	$qr->distill('SHOW GLOBAL STATUS'),
1103                                                  	'SHOW STATUS',
1104                                                  	"distills SHOW GLOBAL STATUS"
1105                                                  );
1106                                                  
1107           1                                  6   is( 
1108                                                  	$qr->distill('SHOW GLOBAL VARIABLES'),
1109                                                  	'SHOW VARIABLES',
1110                                                  	"distills SHOW VARIABLES"
1111                                                  );
1112                                                  
1113           1                                  7   is( 
1114                                                  	$qr->distill('# administrator command: Statistics'),
1115                                                  	'ADMIN STATISTICS',
1116                                                  	"distills ADMIN STATISTICS"
1117                                                  );
1118                                                  
1119                                                  # #############################################################################
1120                                                  # Issue 781: mk-query-digest doesn't distill or extract tables properly
1121                                                  # #############################################################################
1122                                                  
1123           1                                  6   is( 
1124                                                  	$qr->distill("SELECT `id` FROM (`field`) WHERE `id` = '10000016228434112371782015185031'"),
1125                                                  	'SELECT field',
1126                                                  	'distills SELECT clm from (`tbl`)'
1127                                                  );
1128                                                  
1129           1                                  7   is(  
1130                                                  	$qr->distill("INSERT INTO (`jedi_forces`) (name, side, email) values ('Anakin Skywalker', 'jedi', 'anakin_skywalker_at_jedi.sw')"),
1131                                                  	'INSERT jedi_forces',
1132                                                  	'distills INSERT INTO (`tbl`)' 
1133                                                  );
1134                                                  
1135           1                                  6   is(  
1136                                                  	$qr->distill("UPDATE (`jedi_forces`) set side = 'dark' and name = 'Lord Vader' where name = 'Anakin Skywalker'"),
1137                                                  	'UPDATE jedi_forces',
1138                                                  	'distills UPDATE (`tbl`)'
1139                                                  );
1140                                                  
1141           1                                  4   exit;
1142                                                   


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
__ANON__       3 QueryRewriter.t:840


