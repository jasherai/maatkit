---------------------------- ------ ------ ------ ------ ------ ------ ------
File                           stmt   bran   cond    sub    pod   time  total
---------------------------- ------ ------ ------ ------ ------ ------ ------
...t/common/QueryRewriter.pm   92.1   83.9   53.3   93.8    n/a  100.0   87.7
Total                          92.1   83.9   53.3   93.8    n/a  100.0   87.7
---------------------------- ------ ------ ------ ------ ------ ------ ------


Run:          QueryRewriter.t
Perl version: 118.53.46.49.48.46.48
OS:           linux
Start:        Fri Jul 31 18:53:17 2009
Finish:       Fri Jul 31 18:53:17 2009

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
18                                                    # QueryRewriter package $Revision: 4281 $
19                                                    # ###########################################################################
20             1                    1             9   use strict;
               1                                  2   
               1                                  7   
21             1                    1           113   use warnings FATAL => 'all';
               1                                  4   
               1                                  9   
22                                                    
23                                                    package QueryRewriter;
24                                                    
25             1                    1             6   use English qw(-no_match_vars);
               1                                  2   
               1                                  7   
26                                                    
27             1                    1             7   use constant MKDEBUG => $ENV{MKDEBUG};
               1                                  2   
               1                                 11   
28                                                    
29                                                    # A list of verbs that can appear in queries.  I know this is incomplete -- it
30                                                    # does not have CREATE, DROP, ALTER, TRUNCATE for example.  But I don't need
31                                                    # those for my client yet.  Other verbs: KILL, LOCK, UNLOCK
32                                                    our $verbs   = qr{^SHOW|^FLUSH|^COMMIT|^ROLLBACK|^BEGIN|SELECT|INSERT
33                                                                      |UPDATE|DELETE|REPLACE|^SET|UNION|^START}xi;
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
52             1                    1            12      my ( $class, %args ) = @_;
53             1                                  5      my $self = { %args };
54             1                                 10      return bless $self, $class;
55                                                    }
56                                                    
57                                                    # Strips comments out of queries.
58                                                    sub strip_comments {
59             5                    5            25      my ( $self, $query ) = @_;
60             5                                 36      $query =~ s/$olc_re//go;
61             5                                 21      $query =~ s/$mlc_re//go;
62             5                                 28      return $query;
63                                                    }
64                                                    
65                                                    # Shortens long queries by normalizing stuff out of them.  $length is used only
66                                                    # for IN() lists.
67                                                    sub shorten {
68            13                   13            62      my ( $self, $query, $length ) = @_;
69                                                       # Shorten multi-value insert/replace, all the way up to on duplicate key
70                                                       # update if it exists.
71            13                                151      $query =~ s{
72                                                          \A(
73                                                             (?:INSERT|REPLACE)
74                                                             (?:\s+LOW_PRIORITY|DELAYED|HIGH_PRIORITY|IGNORE)?
75                                                             (?:\s\w+)*\s+\S+\s+VALUES\s*\(.*?\)
76                                                          )
77                                                          \s*,\s*\(.*?(ON\s+DUPLICATE|\Z)}
78                                                          {$1 /*... omitted ...*/$2}xsi;
79                                                    
80                                                       # Shortcut!  Find out if there's an IN() list with values.
81            13    100                         109      return $query unless $query =~ m/IN\s*\(\s*(?!select)/i;
82                                                    
83                                                       # Shorten long IN() lists of literals.  But only if the string is longer than
84                                                       # the $length limit.  Assumption: values don't contain commas or closing
85                                                       # parens inside them.  Assumption: all values are the same length.
86    ***      3    100     66                   29      if ( $length && length($query) > $length ) {
87             2                                 22         my ($left, $mid, $right) = $query =~ m{
88                                                             (\A.*?\bIN\s*\()     # Everything up to the opening of IN list
89                                                             ([^\)]+)             # Contents of the list
90                                                             (\).*\Z)             # The rest of the query
91                                                          }xsi;
92    ***      2     50                           8         if ( $left ) {
93                                                             # Compute how many to keep and try to get rid of the middle of the
94                                                             # list until it's short enough.
95             2                                 11            my $targ = $length - length($left) - length($right);
96             2                                 19            my @vals = split(/,/, $mid);
97             2                                  9            my @left = shift @vals;
98             2                                  4            my @right;
99             2                                  6            my $len  = length($left[0]);
100   ***      2            33                   42            while ( @vals && $len < $targ / 2 ) {
101   ***      0                                  0               $len += length($vals[0]) + 1;
102   ***      0                                  0               push @left, shift @vals;
103                                                            }
104   ***      2            33                   20            while ( @vals && $len < $targ ) {
105   ***      0                                  0               $len += length($vals[-1]) + 1;
106   ***      0                                  0               unshift @right, pop @vals;
107                                                            }
108   ***      2     50                          19            $query = $left . join(',', @left)
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
126           35                   35          1218      my ( $self, $query ) = @_;
127                                                   
128                                                      # First, we start with a bunch of special cases that we can optimize because
129                                                      # they are special behavior or because they are really big and we want to
130                                                      # throw them away as early as possible.
131           35    100                         233      $query =~ m#\ASELECT /\*!40001 SQL_NO_CACHE \*/ \* FROM `# # mysqldump query
132                                                         && return 'mysqldump';
133                                                      # Matches queries like REPLACE /*foo.bar:3/3*/ INTO checksum.checksum
134           34    100                         620      $query =~ m#/\*\w+\.\w+:[0-9]/[0-9]\*/#     # mk-table-checksum, etc query
135                                                         && return 'maatkit';
136                                                      # Administrator commands appear to be a comment, so return them as-is
137           33    100                         122      $query =~ m/\A# administrator command: /
138                                                         && return $query;
139                                                      # Special-case for stored procedures.
140           32    100                         172      $query =~ m/\A\s*(call\s+\S+)\(/i
141                                                         && return lc($1); # Warning! $1 used, be careful.
142                                                      # mysqldump's INSERT statements will have long values() lists, don't waste
143                                                      # time on them... they also tend to segfault Perl on some machines when you
144                                                      # get to the "# Collapse IN() and VALUES() lists" regex below!
145           31    100                         464      if ( my ($beginning) = $query =~ m/\A((?:INSERT|REPLACE)(?: IGNORE)? INTO .+? VALUES \(.*?\)),\(/i ) {
146            3                                 10         $query = $beginning; # Shorten multi-value INSERT statements ASAP
147                                                      }
148                                                   
149           31                                364      $query =~ s/$olc_re//go;
150           31                                106      $query =~ s/$mlc_re//go;
151           31    100                         152      $query =~ s/\Ause \S+\Z/use ?/i       # Abstract the DB in USE
152                                                         && return $query;
153                                                   
154           30                                 86      $query =~ s/\\["']//g;                # quoted strings
155           30                                 86      $query =~ s/".*?"/?/sg;               # quoted strings
156           30                                 95      $query =~ s/'.*?'/?/sg;               # quoted strings
157                                                      # This regex is extremely broad in its definition of what looks like a
158                                                      # number.  That is for speed.
159           30                                132      $query =~ s/[0-9+-][0-9a-f.xb+-]*/?/g;# Anything vaguely resembling numbers
160           30                                 89      $query =~ s/[xb.+-]\?/?/g;            # Clean up leftovers
161           30                                 89      $query =~ s/\A\s+//;                  # Chop off leading whitespace
162           30                                 82      chomp $query;                         # Kill trailing whitespace
163           30                                100      $query =~ tr[ \n\t\r\f][ ]s;          # Collapse whitespace
164           30                                105      $query = lc $query;
165           30                                 87      $query =~ s/\bnull\b/?/g;             # Get rid of NULLs
166           30                                272      $query =~ s{                          # Collapse IN and VALUES lists
167                                                                  \b(in|values?)(?:[\s,]*\([\s?,]*\))+
168                                                                 }
169                                                                 {$1(?+)}gx;
170           30                                162      $query =~ s{                          # Collapse UNION
171                                                                  \b(select\s.*?)(?:(\sunion(?:\sall)?)\s\1)+
172                                                                 }
173                                                                 {$1 /*repeat$2*/}xg;
174           30                                101      $query =~ s/\blimit \?(?:, ?\?| offset \?)?/limit ?/; # LIMIT
175                                                      # The following are disabled because of speed issues.  Should we try to
176                                                      # normalize whitespace between and around operators?  My gut feeling is no.
177                                                      # $query =~ s/ , | ,|, /,/g;    # Normalize commas
178                                                      # $query =~ s/ = | =|= /=/g;       # Normalize equals
179                                                      # $query =~ s# [,=+*/-] ?|[,=+*/-] #+#g;    # Normalize operators
180           30                                190      return $query;
181                                                   }
182                                                   
183                                                   # This is kind of like fingerprinting, but it super-fingerprints to something
184                                                   # that shows the query type and the tables/objects it accesses.
185                                                   sub distill {
186           39                   39           190      my ( $self, $query, %args ) = @_;
187   ***     39            33                  353      my $qp = $args{qp} || $self->{QueryParser};
188   ***     39     50                         129      die "I need a qp argument" unless $qp;
189                                                   
190                                                      # Special cases.
191           39    100                         196      $query =~ m/\A\s*call\s+(\S+)\(/i
192                                                         && return "CALL $1"; # Warning! $1 used, be careful.
193           38    100                         147      $query =~ m/\A# administrator/
194                                                         && return "ADMIN";
195           37    100                         161      $query =~ m/\A\s*use\s+/
196                                                         && return "USE";
197                                                   
198                                                      # More special cases for data defintion statements.
199                                                      # The two evals are a hack to keep Perl from warning that
200                                                      # "QueryParser::data_def_stmts" used only once: possible typo at...".
201                                                      # Some day we'll group all our common regex together in a packet and
202                                                      # export/import them properly.
203           36                                 91      eval $QueryParser::data_def_stmts;
204           36                                 86      eval $QueryParser::tbl_ident;
205           36                                332      my ( $dds ) = $query =~ /^\s*($QueryParser::data_def_stmts)\b/i;
206           36    100                         133      if ( $dds ) {
207            9                                156         my ( $obj ) = $query =~ m/$dds.+(DATABASE|TABLE)\b/i;
208   ***      9     50                          44         $obj = uc $obj if $obj;
209            9                                 19         MKDEBUG && _d('Data def statment:', $dds, $obj);
210            9                                122         my ($db_or_tbl)
211                                                            = $query =~ m/(?:TABLE|DATABASE)\s+($QueryParser::tbl_ident)(\s+.*)?/i;
212            9                                 22         MKDEBUG && _d('Matches db or table:', $db_or_tbl);
213   ***      9     50                          33         $obj .= ($db_or_tbl ? " $db_or_tbl" : '');
214   ***      9     50                          69         return uc($dds) . ($obj ? " $obj" : '');
215                                                      }
216                                                   
217                                                      # First, get the query type -- just extract all the verbs and collapse them
218                                                      # together.
219           27                                647      my @verbs = $query =~ m/\b($verbs)\b/gio;
220           27                                 79      @verbs    = do {
221           27                                 72         my $last = '';
222           27                                 88         grep { my $pass = $_ ne $last; $last = $_; $pass } map { uc } @verbs;
              37                                111   
              37                                 95   
              37                                154   
              37                                150   
223                                                      };
224           27                                 98      my $verbs = join(q{ }, @verbs);
225           27                                 78      $verbs =~ s/( UNION SELECT)+/ UNION/g;
226                                                   
227                                                      # "Fingerprint" the tables.
228           31                                 96      my @tables = map {
229           27                                127         $_ =~ s/`//g;
230           31                                163         $_ =~ s/(_?)[0-9]+/$1?/g;
231           31                                118         $_;
232                                                      } $qp->get_tables($query);
233                                                   
234                                                      # Collapse the table list
235           27                                 77      @tables = do {
236           27                                 69         my $last = '';
237           27                                 81         grep { my $pass = $_ ne $last; $last = $_; $pass } @tables;
              31                                 92   
              31                                 73   
              31                                117   
238                                                      };
239                                                   
240           27                                 96      $query = join(q{ }, $verbs, @tables);
241           27                                160      return $query;
242                                                   }
243                                                   
244                                                   sub convert_to_select {
245           23                   23           104      my ( $self, $query ) = @_;
246           23    100                          88      return unless $query;
247            7                                 32      $query =~ s{
               8                                 33   
248                                                                    \A.*?
249                                                                    update\s+(.*?)
250                                                                    \s+set\b(.*?)
251                                                                    (?:\s*where\b(.*?))?
252                                                                    (limit\s*[0-9]+(?:\s*,\s*[0-9]+)?)?
253                                                                    \Z
254                                                                 }
255                                                                 {__update_to_select($1, $2, $3, $4)}exsi
256            2                                  7         || $query =~ s{
257                                                                       \A.*?
258                                                                       (?:insert|replace)\s+
259                                                                       .*?\binto\b(.*?)\(([^\)]+)\)\s*
260                                                                       values?\s*(\(.*?\))\s*
261                                                                       (?:\blimit\b|on\s*duplicate\s*key.*)?\s*
262                                                                       \Z
263                                                                    }
264                                                                    {__insert_to_select($1, $2, $3)}exsi
265           22    100    100                  520         || $query =~ s{
266                                                                       \A.*?
267                                                                       delete\s+(.*?)
268                                                                       \bfrom\b(.*)
269                                                                       \Z
270                                                                    }
271                                                                    {__delete_to_select($1, $2)}exsi;
272           22                                305      $query =~ s/\s*on\s+duplicate\s+key\s+update.*\Z//si;
273           22                                128      $query =~ s/\A.*?(?=\bSELECT\s*\b)//ism;
274           22                                140      return $query;
275                                                   }
276                                                   
277                                                   sub convert_select_list {
278            2                    2             8      my ( $self, $query ) = @_;
279            2    100                          16      $query =~ s{
               2                                 16   
280                                                                  \A\s*select(.*?)\bfrom\b
281                                                                 }
282                                                                 {$1 =~ m/\*/ ? "select 1 from" : "select isnull(coalesce($1)) from"}exi;
283            2                                 11      return $query;
284                                                   }
285                                                   
286                                                   sub __delete_to_select {
287            2                    2            13      my ( $delete, $join ) = @_;
288            2    100                          13      if ( $join =~ m/\bjoin\b/ ) {
289            1                                  7         return "select 1 from $join";
290                                                      }
291            1                                  6      return "select * from $join";
292                                                   }
293                                                   
294                                                   sub __insert_to_select {
295            8                    8            51      my ( $tbl, $cols, $vals ) = @_;
296            8                                 24      MKDEBUG && _d('Args:', @_);
297            8                                 41      my @cols = split(/,/, $cols);
298            8                                 18      MKDEBUG && _d('Cols:', @cols);
299            8                                 57      $vals =~ s/^\(|\)$//g; # Strip leading/trailing parens
300            8                                177      my @vals = $vals =~ m/($quote_re|[^,]*${bal}[^,]*|[^,]+)/g;
301            8                                 31      MKDEBUG && _d('Vals:', @vals);
302   ***      8     50                          31      if ( @cols == @vals ) {
303           23                                161         return "select * from $tbl where "
304            8                                 59            . join(' and ', map { "$cols[$_]=$vals[$_]" } (0..$#cols));
305                                                      }
306                                                      else {
307   ***      0                                  0         return "select * from $tbl limit 1";
308                                                      }
309                                                   }
310                                                   
311                                                   sub __update_to_select {
312            7                    7            47      my ( $from, $set, $where, $limit ) = @_;
313            7    100                          91      return "select $set from $from "
                    100                               
314                                                         . ( $where ? "where $where" : '' )
315                                                         . ( $limit ? " $limit "      : '' );
316                                                   }
317                                                   
318                                                   sub wrap_in_derived {
319            3                    3            13      my ( $self, $query ) = @_;
320            3    100                          14      return unless $query;
321            2    100                          19      return $query =~ m/\A\s*select/i
322                                                         ? "select 1 from ($query) as x limit 1"
323                                                         : $query;
324                                                   }
325                                                   
326                                                   sub _d {
327   ***      0                    0                    my ($package, undef, $line) = caller 0;
328   ***      0      0                                  @_ = map { (my $temp = $_) =~ s/\n/\n# /g; $temp; }
      ***      0                                      
      ***      0                                      
329   ***      0                                              map { defined $_ ? $_ : 'undef' }
330                                                           @_;
331   ***      0                                         print STDERR "# $package:$line $PID ", join(' ', @_), "\n";
332                                                   }
333                                                   
334                                                   1;
335                                                   
336                                                   # ###########################################################################
337                                                   # End QueryRewriter package
338                                                   # ###########################################################################


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
188   ***     50      0     39   unless $qp
191          100      1     38   if $query =~ /\A\s*call\s+(\S+)\(/i
193          100      1     37   if $query =~ /\A# administrator/
195          100      1     36   if $query =~ /\A\s*use\s+/
206          100      9     27   if ($dds)
208   ***     50      9      0   if $obj
213   ***     50      9      0   $db_or_tbl ? :
214   ***     50      9      0   $obj ? :
246          100      1     22   unless $query
265          100      7     15   unless $query =~ s/
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
279          100      1      1   $1 =~ /\*/ ? :
288          100      1      1   if ($join =~ /\bjoin\b/)
302   ***     50      8      0   if (@cols == @vals) { }
313          100      4      3   $where ? :
             100      1      6   $limit ? :
320          100      1      2   unless $query
321          100      1      1   $query =~ /\A\s*select/i ? :
328   ***      0      0      0   defined $_ ? :


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
187   ***     33      0     39      0   $args{'qp'} || $$self{'QueryParser'}
265          100      7      8      7   $query =~ s/
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
__delete_to_select      2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:287
__insert_to_select      8 /home/daniel/dev/maatkit/common/QueryRewriter.pm:295
__update_to_select      7 /home/daniel/dev/maatkit/common/QueryRewriter.pm:312
convert_select_list     2 /home/daniel/dev/maatkit/common/QueryRewriter.pm:278
convert_to_select      23 /home/daniel/dev/maatkit/common/QueryRewriter.pm:245
distill                39 /home/daniel/dev/maatkit/common/QueryRewriter.pm:186
fingerprint            35 /home/daniel/dev/maatkit/common/QueryRewriter.pm:126
new                     1 /home/daniel/dev/maatkit/common/QueryRewriter.pm:52 
shorten                13 /home/daniel/dev/maatkit/common/QueryRewriter.pm:68 
strip_comments          5 /home/daniel/dev/maatkit/common/QueryRewriter.pm:59 
wrap_in_derived         3 /home/daniel/dev/maatkit/common/QueryRewriter.pm:319

Uncovered Subroutines
---------------------

Subroutine          Count Location                                            
------------------- ----- ----------------------------------------------------
_d                      0 /home/daniel/dev/maatkit/common/QueryRewriter.pm:327


