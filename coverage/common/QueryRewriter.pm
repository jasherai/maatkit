---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/QueryRewriter.pm   92.2   84.5   53.3   93.8    n/a  100.0   87.8
Total                          92.2   84.5   53.3   93.8    n/a  100.0   87.8
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryRewriter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Sat Aug 29 15:03:40 2009
Finish:       Sat Aug 29 15:03:40 2009

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
18                                                    # QueryRewriter package $Revision: 4569 $
19                                                    # ###########################################################################
20             1                    1             8   use strict;
               1                                  2   
               1                                 10   
21             1                    1           107   use warnings FATAL => 'all';
               1                                  2   
               1                                 10   
22                                                    
23                                                    package QueryRewriter;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  3   
               1                                  8   
26                                                    
27             1                    1             6   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  3   
               1                                 11   
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
50                                                    
51                                                    sub new {
52             1                    1            14      my ( $class, %args ) = @_;
53             1                                  5      my $self = { %args };
54             1                                 12      return bless $self, $class;
55                                                    }
56                                                    
57                                                    # Strips comments out of queries.
58                                                    sub strip_comments {
59             5                    5            29      my ( $self, $query ) = @_;
60             5                                 43      $query =~ s/$olc_re//go;
61             5                                 22      $query =~ s/$mlc_re//go;
62             5                                 46      return $query;
63                                                    }
64                                                    
65                                                    # Shortens long queries by normalizing stuff out of them.  $length is used only
66                                                    # for IN() lists.
67                                                    sub shorten {
68            13                   13            66      my ( $self, $query, $length ) = @_;
69                                                       # Shorten multi-value insert/replace, all the way up to on duplicate key
70                                                       # update if it exists.
71            13                                172      $query =~ s{
72                                                          \A(
73                                                             (?:INSERT|REPLACE)
74                                                             (?:\s+LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)?
75                                                             (?:\s\w+)*\s+\S+\s+VALUES\s*\(.*?\)
76                                                          )
77                                                          \s*,\s*\(.*?(ON\s+DUPLICATE|\Z)}
78                                                          {$1 /*... omitted ...*/$2}xsi;
79                                                    
80                                                       # Shortcut!  Find out if there's an IN() list with values.
81            13    100                         121      return $query unless $query =~ m/IN\s*\(\s*(?!select)/i;
82                                                    
83                                                       # Shorten long IN() lists of literals.  But only if the string is longer than
84                                                       # the $length limit.  Assumption: values don't contain commas or closing
85                                                       # parens inside them.  Assumption: all values are the same length.
86    ***      3    100     66                   55      if ( $length && length($query) > $length ) {
87             2                                 24         my ($left, $mid, $right) = $query =~ m{
88                                                             (\A.*?\bIN\s*\()     # Everything up to the opening of IN list
89                                                             ([^\)]+)             # Contents of the list
90                                                             (\).*\Z)             # The rest of the query
91                                                          }xsi;
92    ***      2     50                          11         if ( $left ) {
93                                                             # Compute how many to keep and try to get rid of the middle of the
94                                                             # list until it's short enough.
95             2                                 18            my $targ = $length - length($left) - length($right);
96             2                                 16            my @vals = split(/,/, $mid);
97             2                                  9            my @left = shift @vals;
98             2                                  5            my @right;
99             2                                  7            my $len  = length($left[0]);
100   ***      2            33                   43            while ( @vals && $len < $targ / 2 ) {
101   ***      0                                  0               $len += length($vals[0]) + 1;
102   ***      0                                  0               push @left, shift @vals;
103                                                            }
104   ***      2            33                   18            while ( @vals && $len < $targ ) {
105   ***      0                                  0               $len += length($vals[-1]) + 1;
106   ***      0                                  0               unshift @right, pop @vals;
107                                                            }
108   ***      2     50                          21            $query = $left . join(',', @left)
109                                                                   . (@right ? ',' : '')
110                                                                   . " /*... omitted " . scalar(@vals) . " items ...*/ "
111                                                                   . join(',', @right) . $right;
112                                                         }
113                                                      }
114                                                   
115            3                                 18      return $query;
116                                                   }
117                                                   
118                                                   # Normalizes variable queries to a "query fingerprint" by abstracting away
119                                                   # parameters, canonicalizing whitespace, etc.  See
120                                                   # http://dev.mysql.com/doc/refman/5.0/en/literals.html for literal syntax.
121                                                   # Note: Any changes to this function must be profiled for speed!  Speed of this
122                                                   # function is critical for mk-log-parser.  There are known bugs in this, but the
123                                                   # balance between maybe-you-get-a-bug and speed favors speed.  See past
124                                                   # revisions of this subroutine for more correct, but slower, regexes.
125                                                   sub fingerprint {
126           35                   35          1466      my ( $self, $query ) = @_;
127                                                   
128                                                      # First, we start with a bunch of special cases that we can optimize because
129                                                      # they are special behavior or because they are really big and we want to
130                                                      # throw them away as early as possible.
131           35    100                         256      $query =~ m#\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `# # mysqldump query
132                                                         && return 'mysqldump';
133                                                      # Matches queries like REPLACE /*foo.bar:3/3*/ INTO checksum.checksum
134           34    100                         627      $query =~ m#/\*\w+\.\w+:[0-9]/[0-9]\*/#     # mk-table-checksum, etc query
135                                                         && return 'maatkit';
136                                                      # Administrator commands appear to be a comment, so return them as-is
137           33    100                         129      $query =~ m/\A# administrator command: /
138                                                         && return $query;
139                                                      # Special-case for stored procedures.
140           32    100                         189      $query =~ m/\A\s*(call\s+\S+)\(/i
141                                                         && return lc($1); # Warning! $1 used, be careful.
142                                                      # mysqldump's INSERT statements will have long values() lists, don't waste
143                                                      # time on them... they also tend to segfault Perl on some machines when you
144                                                      # get to the "# Collapse IN() and VALUES() lists" regex below!
145           31    100                         459      if ( my ($beginning) = $query =~ m/\A((?:INSERT|REPLACE)(?: IGNORE)? INTO .+? VALUES \(.*?\)),\(/i ) {
146            3                                 11         $query = $beginning; # Shorten multi-value INSERT statements ASAP
147                                                      }
148                                                   
149           31                                393      $query =~ s/$olc_re//go;
150           31                                110      $query =~ s/$mlc_re//go;
151           31    100                         153      $query =~ s/\Ause \S+\Z/use ?/i       # Abstract the DB in USE
152                                                         && return $query;
153                                                   
154           30                                100      $query =~ s/\\["']//g;                # quoted strings
155           30                                 83      $query =~ s/".*?"/?/sg;               # quoted strings
156           30                                107      $query =~ s/'.*?'/?/sg;               # quoted strings
157                                                      # This regex is extremely broad in its definition of what looks like a
158                                                      # number.  That is for speed.
159           30                                172      $query =~ s/[0-9+-][0-9a-f.xb+-]*/?/g;# Anything vaguely resembling numbers
160           30                                 97      $query =~ s/[xb.+-]\?/?/g;            # Clean up leftovers
161           30                                 87      $query =~ s/\A\s+//;                  # Chop off leading whitespace
162           30                                105      chomp $query;                         # Kill trailing whitespace
163           30                                111      $query =~ tr[ \n\t\r\f][ ]s;          # Collapse whitespace
164           30                                103      $query = lc $query;
165           30                                 85      $query =~ s/\bnull\b/?/g;             # Get rid of NULLs
166           30                                295      $query =~ s{                          # Collapse IN and VALUES lists
167                                                                  \b(in|values?)(?:[\s,]*\([\s?,]*\))+
168                                                                 }
169                                                                 {$1(?+)}gx;
170           30                                145      $query =~ s{                          # Collapse UNION
171                                                                  \b(select\s.*?)(?:(\sunion(?:\sall)?)\s\1)+
172                                                                 }
173                                                                 {$1 /*repeat$2*/}xg;
174           30                                 95      $query =~ s/\blimit \?(?:, ?\?| offset \?)?/limit ?/; # LIMIT
175                                                      # The following are disabled because of speed issues.  Should we try to
176                                                      # normalize whitespace between and around operators?  My gut feeling is no.
177                                                      # $query =~ s/ , | ,|, /,/g;    # Normalize commas
178                                                      # $query =~ s/ = | =|= /=/g;       # Normalize equals
179                                                      # $query =~ s# [,=+*/-] ?|[,=+*/-] #+#g;    # Normalize operators
180           30                                200      return $query;
181                                                   }
182                                                   
183                                                   # This is kind of like fingerprinting, but it super-fingerprints to something
184                                                   # that shows the query type and the tables/objects it accesses.
185                                                   sub distill {
186           42                   42           239      my ( $self, $query, %args ) = @_;
187   ***     42            33                  425      my $qp = $args{qp} || $self->{QueryParser};
188   ***     42     50                         146      die "I need a qp argument" unless $qp;
189                                                   
190                                                      # Special cases.
191           42    100                         232      $query =~ m/\A\s*call\s+(\S+)\(/i
192                                                         && return "CALL $1"; # Warning! $1 used, be careful.
193           41    100                         161      $query =~ m/\A# administrator/
194                                                         && return "ADMIN";
195           40    100                         175      $query =~ m/\A\s*use\s+/
196                                                         && return "USE";
197           39    100                         175      $query =~ m/\A\s*UNLOCK TABLES/i
198                                                         && return "UNLOCK";
199                                                   
200                                                      # More special cases for data defintion statements.
201                                                      # The two evals are a hack to keep Perl from warning that
202                                                      # "QueryParser::data_def_stmts" used only once: possible typo at...".
203                                                      # Some day we'll group all our common regex together in a packet and
204                                                      # export/import them properly.
205           38                                 96      eval $QueryParser::data_def_stmts;
206           38                                138      eval $QueryParser::tbl_ident;
207           38                                408      my ( $dds ) = $query =~ /^\s*($QueryParser::data_def_stmts)\b/i;
208           38    100                         169      if ( $dds ) {
209            9                                177         my ( $obj ) = $query =~ m/$dds.+(DATABASE|TABLE)\b/i;
210   ***      9     50                          43         $obj = uc $obj if $obj;
211            9                                 19         MKDEBUG && _d('Data def statment:', $dds, $obj);
212            9                                127         my ($db_or_tbl)
213                                                            = $query =~ m/(?:TABLE|DATABASE)\s+($QueryParser::tbl_ident)(\s+.*)?/i;
214            9                                 23         MKDEBUG && _d('Matches db or table:', $db_or_tbl);
215   ***      9     50                          37         $obj .= ($db_or_tbl ? " $db_or_tbl" : '');
216   ***      9     50                          77         return uc($dds) . ($obj ? " $obj" : '');
217                                                      }
218                                                   
219                                                      # First, get the query type -- just extract all the verbs and collapse them
220                                                      # together.
221           29                                733      my @verbs = $query =~ m/\b($verbs)\b/gio;
222           29                                 97      @verbs    = do {
223           29                                 83         my $last = '';
224           29                                108         grep { my $pass = $_ ne $last; $last = $_; $pass } map { uc } @verbs;
              39                                128   
              39                                 97   
              39                                165   
              39                                155   
225                                                      };
226           29                                129      my $verbs = join(q{ }, @verbs);
227           29                                 87      $verbs =~ s/( UNION SELECT)+/ UNION/g;
228                                                   
229                                                      # "Fingerprint" the tables.
230           34                                109      my @tables = map {
231           29                                157         $_ =~ s/`//g;
232           34                                176         $_ =~ s/(_?)[0-9]+/$1?/g;
233           34                                137         $_;
234                                                      } $qp->get_tables($query);
235                                                   
236                                                      # Collapse the table list
237           29                                 89      @tables = do {
238           29                                 83         my $last = '';
239           29                                101         grep { my $pass = $_ ne $last; $last = $_; $pass } @tables;
              34                                102   
              34                                 90   
              34                                133   
240                                                      };
241                                                   
242           29                                110      $query = join(q{ }, $verbs, @tables);
243           29                                187      return $query;
244                                                   }
245                                                   
246                                                   sub convert_to_select {
247           23                   23           119      my ( $self, $query ) = @_;
248           23    100                          97      return unless $query;
249            7                                 38      $query =~ s{
               8                                 39   
250                                                                    \A.*?
251                                                                    update\s+(.*?)
252                                                                    \s+set\b(.*?)
253                                                                    (?:\s*where\b(.*?))?
254                                                                    (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
255                                                                    \Z
256                                                                 }
257                                                                 {__update_to_select($1, $2, $3, $4)}exsi
258            2                                 10         || $query =~ s{
259                                                                       \A.*?
260                                                                       (?:insert|replace)\s+
261                                                                       .*?\binto\b(.*?)\(([^\)]+)\)\s*
262                                                                       values?\s*(\(.*?\))\s*
263                                                                       (?:\blimit\b|on\s*duplicate\s*key.*)?\s*
264                                                                       \Z
265                                                                    }
266                                                                    {__insert_to_select($1, $2, $3)}exsi
267           22    100    100                  572         || $query =~ s{
268                                                                       \A.*?
269                                                                       delete\s+(.*?)
270                                                                       \bfrom\b(.*)
271                                                                       \Z
272                                                                    }
273                                                                    {__delete_to_select($1, $2)}exsi;
274           22                                293      $query =~ s/\s*on\s+duplicate\s+key\s+update.*\Z//si;
275           22                                128      $query =~ s/\A.*?(?=\bSELECT\s*\b)//ism;
276           22                                127      return $query;
277                                                   }
278                                                   
279                                                   sub convert_select_list {
280            2                    2            11      my ( $self, $query ) = @_;
281            2    100                          16      $query =~ s{
               2                                 18   
282                                                                  \A\s*select(.*?)\bfrom\b
283                                                                 }
284                                                                 {$1 =~ m/\*/ ? "select 1 from" : "select isnull(coalesce($1)) from"}exi;
285            2                                 11      return $query;
286                                                   }
287                                                   
288                                                   sub __delete_to_select {
289            2                    2            14      my ( $delete, $join ) = @_;
290            2    100                          13      if ( $join =~ m/\bjoin\b/ ) {
291            1                                  8         return "select 1 from $join";
292                                                      }
293            1                                  7      return "select * from $join";
294                                                   }
295                                                   
296                                                   sub __insert_to_select {
297            8                    8            56      my ( $tbl, $cols, $vals ) = @_;
298            8                                 22      MKDEBUG && _d('Args:', @_);
299            8                                 60      my @cols = split(/,/, $cols);
300            8                                 18      MKDEBUG && _d('Cols:', @cols);
301            8                                 63      $vals =~ s/^\(|\)$//g; # Strip leading/trailing parens
302            8                                206      my @vals = $vals =~ m/($quote_re|[^,]*${bal}[^,]*|[^,]+)/g;
303            8                                 34      MKDEBUG && _d('Vals:', @vals);
304   ***      8     50                          32      if ( @cols == @vals ) {
305           23                                169         return "select * from $tbl where "
306            8                                 74            . join(' and ', map { "$cols[$_]=$vals[$_]" } (0..$#cols));
307                                                      }
308                                                      else {
309   ***      0                                  0         return "select * from $tbl limit 1";
310                                                      }
311                                                   }
312                                                   
313                                                   sub __update_to_select {
314            7                    7            60      my ( $from, $set, $where, $limit ) = @_;
315            7    100                          99      return "select $set from $from "
                    100                               
316                                                         . ( $where ? "where $where" : '' )
317                                                         . ( $limit ? " $limit "      : '' );
318                                                   }
319                                                   
320                                                   sub wrap_in_derived {
321            3                    3            14      my ( $self, $query ) = @_;
322            3    100                          15      return unless $query;
323            2    100                          20      return $query =~ m/\A\s*select/i
324                                                         ? "select 1 from ($query) as x limit 1"
325                                                         : $query;
326                                                   }
327                                                   
328                                                   sub _d {
329   ***      0                    0                    my ($package, undef, $line) = caller 0;
330   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
331   ***      0                                              map { defined $_ ? $_ : 'undef' }
332                                                           @_;
333   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
334                                                   }
335                                                   
336                                                   1;
337                                                   
338                                                   # ###########################################################################
339                                                   # End QueryRewriter package
340                                                   # ###########################################################################


Branches
--------

line  err      %   true  false   branch
----- --- ------ ------ ------   ------
81           100     10      3   unless $query =~ /IN\s*\(\s*(?!select)/i
86           100      2      1   if ($length and length $query > $length)
92    ***     50      2      0   if ($left)
108   ***     50      0      2   @right ? :
131          100      1     34   if $query =~ m[\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `]
134          100      1     33   if $query =~ m[/\*\w+\.\w+:[0-9]/[0-9]\*/]
137          100      1     32   if $query =~ /\A# administrator command: /
140          100      1     31   if $query =~ /\A\s*(call\s+\S+)\(/i
145          100      3     28   if (my($beginning) = $query =~ /\A((?:INSERT|REPLACE)(?: IGNORE)? INTO .+? VALUES \(.*?\)),\(/i)
151          100      1     30   if $query =~ s/\Ause \S+\Z/use ?/i
188   ***     50      0     42   unless $qp
191          100      1     41   if $query =~ /\A\s*call\s+(\S+)\(/i
193          100      1     40   if $query =~ /\A# administrator/
195          100      1     39   if $query =~ /\A\s*use\s+/
197          100      1     38   if $query =~ /\A\s*UNLOCK TABLES/i
208          100      9     29   if ($dds)
210   ***     50      9      0   if $obj
215   ***     50      9      0   $db_or_tbl ? :
216   ***     50      9      0   $obj ? :
248          100      1     22   unless $query
267          100      7     15   unless $query =~ s/
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
281          100      1      1   $1 =~ /\*/ ? :
290          100      1      1   if ($join =~ /\bjoin\b/)
304   ***     50      8      0   if (@cols == @vals) { }
315          100      4      3   $where ? :
             100      1      6   $limit ? :
322          100      1      2   unless $query
323          100      1      1   $query =~ /\A\s*select/i ? :
330   ***      0      0      0   defined $_ ? :


Conditions
----------

and 3 conditions

line  err      %     !l  l&&!r   l&&r   expr
----- --- ------ ------ ------ ------   ----
86    ***     66      0      1      2   $length and length $query > $length
100   ***     33      0      2      0   @vals and $len < $targ / 2
104   ***     33      0      2      0   @vals and $len < $targ

or 3 conditions

line  err      %      l  !l&&r !l&&!r   expr
----- --- ------ ------ ------ ------   ----
187   ***     33      0     42      0   $args{'qp'} || $$self{'QueryParser'}
267          100      7      8      7   $query =~ s/
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
__delete_to_select      2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:289
__insert_to_select      8 /home/daniel/dev/maatkit/common/QueryRewriter.pm:297
__update_to_select      7 /home/daniel/dev/maatkit/common/QueryRewriter.pm:314
convert_select_list     2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:280
convert_to_select      23 /home/daniel/dev/maatkit/common/QueryRewriter.pm:247
distill                42 /home/daniel/dev/maatkit/common/QueryRewriter.pm:186
fingerprint            35 /home/daniel/dev/maatkit/common/QueryRewriter.pm:126
new                     1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:52 
shorten                13 /home/daniel/dev/maatkit/common/QueryRewriter.pm:68 
strip_comments          5 /home/daniel/dev/maatkit/common/QueryRewriter.pm:59 
wrap_in_derived         3 /home/daniel/dev/maatkit/common/QueryRewriter.pm:321

Uncovered Subroutines
---------------------

Subroutine          Count Location                                            
------------------- ----- ----------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/QueryRewriter.pm:329


